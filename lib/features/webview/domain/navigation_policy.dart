import '../../../core/config/app_config.dart';

/// What the shell should do with one navigation request.
sealed class NavigationDecision {
  const NavigationDecision();
}

/// Load it in the WebView.
class AllowInWebView extends NavigationDecision {
  const AllowInWebView();
}

/// Cancel this navigation and load [url] instead.
class LoadInstead extends NavigationDecision {
  final Uri url;
  const LoadInstead(this.url);
}

/// Cancel this navigation and hand [url] to the platform (browser, dialer,
/// mail client…).
class OpenExternally extends NavigationDecision {
  final String url;
  const OpenExternally(this.url);
}

/// Drop it.
class BlockNavigation extends NavigationDecision {
  const BlockNavigation();
}

/// The rules deciding what may run inside the WebView.
///
/// Pulled out of the widget so the trust boundary is testable on its own. This
/// is what stands between arbitrary web content and the JS bridge, which
/// exposes purchases, account creation and the Firebase ID token.
class NavigationPolicy {
  const NavigationPolicy._();

  /// Compiled once. The previous code rebuilt every one of these on every
  /// navigation, inside the loop.
  static final List<RegExp> _externalSchemes = AppConfig.externalLinkPatterns
      .map((pattern) => RegExp(pattern, caseSensitive: false))
      .toList(growable: false);

  /// Whether [host] is the site this shell exists to display, or a subdomain
  /// of it.
  ///
  /// The subdomain test is anchored on a dot, so `evilsupabapnew.vercel.app`
  /// does not pass as a subdomain of `supabapnew.vercel.app`.
  static bool isAllowedDomain(String host) {
    final normalizedHost = host.toLowerCase();
    for (final domain in AppConfig.allowedDomains) {
      final normalizedDomain = domain.toLowerCase();
      if (normalizedHost == normalizedDomain ||
          normalizedHost.endsWith('.$normalizedDomain')) {
        return true;
      }
    }
    return false;
  }

  /// Origin rules for `UserScript.allowedOriginRules`, i.e. which documents
  /// are allowed to receive the injected shim and, with it, the bridge token.
  ///
  /// Derived from [AppConfig.allowedDomains] rather than written out, because
  /// these two must never drift: a domain that [isAllowedDomain] admits but
  /// this set omits gets a page that loads and a bridge that rejects every
  /// call, and the reverse hands the token to an origin navigation would have
  /// refused.
  ///
  /// Only Android enforces these, and only when the WebView supports
  /// DOCUMENT_START_SCRIPT. That is not a gap: without that feature
  /// flutter_inappwebview falls back to injecting through
  /// `evaluateJavascript`, which runs in the main frame alone, and on iOS
  /// `UserScript.forMainFrameOnly` (which iOS does implement) already holds.
  static Set<String> get bridgeOriginRules => {
    for (final domain in AppConfig.allowedDomains) ...[
      'https://$domain',
      'https://*.$domain',
    ],
  };

  /// Whether a document at [uri] may reach the native JS bridge.
  static bool isTrustedBridgeOrigin(Uri? uri) {
    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        isAllowedDomain(uri.host);
  }

  /// What to do with a **main frame** navigation to [requestUrl].
  static NavigationDecision decideMainFrame(String requestUrl) {
    final uri = Uri.tryParse(requestUrl);
    if (uri == null || uri.scheme.isEmpty) return const BlockNavigation();

    final scheme = uri.scheme.toLowerCase();

    if (scheme == 'https' && isAllowedDomain(uri.host)) {
      return const AllowInWebView();
    }

    // Our own site reached over plain http: upgrade and keep it in the app.
    // This used to hand the https URL to the system browser, which ejected the
    // user out of the shell — and out of the native session — over what is
    // just a scheme mismatch on a link to ourselves.
    if (scheme == 'http' && isAllowedDomain(uri.host)) {
      return LoadInstead(uri.replace(scheme: 'https'));
    }

    for (final pattern in _externalSchemes) {
      if (pattern.hasMatch(requestUrl)) return OpenExternally(requestUrl);
    }

    if (scheme == 'http' || scheme == 'https') {
      return OpenExternally(requestUrl);
    }

    return const BlockNavigation();
  }

  /// Whether a **sub frame** (iframe) may load [requestUrl].
  ///
  /// Subframes get a stricter rule than the main frame: allowed or dropped,
  /// never "open externally" — an iframe must not be able to fling the user
  /// into the browser or the dialer without a gesture.
  ///
  /// This is the load-bearing half of the bridge's origin check, and the
  /// reason it is not merely tidier than the old blanket
  /// `NavigationActionPolicy.ALLOW`: on Android the flutter_inappwebview
  /// bridge is installed with `addJavascriptInterface`, which is reachable
  /// from EVERY frame in the WebView, while
  /// `InAppWebViewController.getUrl()` only ever reports the MAIN frame's URL.
  /// So a cross-origin iframe could call
  /// `window.flutter_inappwebview.callHandler('purchaseProduct', …)` directly
  /// and satisfy an origin check that was looking somewhere else entirely.
  /// `window.NativeApp` is no defence either: it is only sugar over the same
  /// reachable `callHandler`, and `UserScript.forMainFrameOnly` — which might
  /// have kept it out of subframes — is simply not implemented in
  /// flutter_inappwebview_android. Refusing to load foreign frames keeps every
  /// frame inside the origin the check actually verifies.
  ///
  /// This is one of TWO independent gates, and it is the weaker one, because
  /// it can be bypassed: `WebViewClient.shouldOverrideUrlLoading` is not
  /// invoked for POST requests, so a form submitted into a named iframe never
  /// reaches this method. The gate that does not have that hole is the bridge
  /// token in webview_page.dart, delivered through [bridgeOriginRules].
  ///
  /// flutter_inappwebview 6.2 adds `javaScriptBridgeOriginAllowList`, which
  /// enforces origin at the bridge itself. Adopt it here once 6.2 leaves
  /// beta; until then these two gates are the enforcement points.
  static bool allowsSubFrame(String requestUrl) {
    // Closed by default when there is nothing to judge. `URLRequest.url` is
    // nullable on both platforms and the caller passes '' when it is absent —
    // and '' parses into a Uri with an empty scheme AND an empty host, which
    // the relative-URL rule below would have waved straight through. This is
    // the one branch that carries the whole cross-origin-frame defence, so it
    // must not be the one that defaults to permit.
    if (requestUrl.isEmpty) return false;

    final uri = Uri.tryParse(requestUrl);
    if (uri == null) return false;

    // A scheme-less URL is a relative one: it resolves against the frame's own
    // document and so cannot leave the origin it started from.
    //
    // With ONE exception, which is why this tests the host rather than just
    // waving relative URLs through: a protocol-relative URL like
    // `//evil.example/x` also parses with an empty scheme, and it very much
    // does carry a host. In practice the WebView resolves those before calling
    // here, so this is defence in depth rather than a live hole — but it is
    // one character of difference between "relative" and "any origin at all",
    // and it should not depend on the platform normalising first.
    if (uri.scheme.isEmpty) return uri.host.isEmpty;

    // about:blank is how a freshly created iframe starts out before its real
    // src loads. Allowing it concedes nothing: the parent can only reach into
    // such a frame when they are same-origin, so anything that ends up running
    // there was already running in the parent.
    //
    // about:srcdoc is deliberately NOT allowed, though an earlier revision of
    // this file allowed it on the reasoning above. That reasoning does not
    // survive `<iframe sandbox="allow-scripts" srcdoc="...">`: a sandboxed
    // frame without allow-same-origin gets an OPAQUE origin, not the parent's
    // — and rendering untrusted content in exactly that construct is the
    // normal, correct thing for a learning site to do with a user-submitted
    // snippet. Nothing legitimate is lost: an unsandboxed srcdoc frame is
    // same-origin and can be built with about:blank plus document.write.
    if (requestUrl == 'about:blank') return true;

    return uri.scheme.toLowerCase() == 'https' && isAllowedDomain(uri.host);
  }
}
