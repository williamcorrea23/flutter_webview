import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/ads_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/purchases_service.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../about/presentation/pages/about_page.dart';
import '../../domain/navigation_policy.dart';
import '../interstitial_request_coordinator.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/interstitial_consent_dialog.dart';
import '../widgets/offline_page_widget.dart';
import '../widgets/progress_indicator_widget.dart';

/// A per-launch bridge token: 256 bits from the platform CSPRNG, hex encoded.
String _generateBridgeToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Renders [value] as a JavaScript string literal.
///
/// The token is hex, so nothing here can currently need escaping — this exists
/// so that stays true if the generator is ever changed.
String _jsStringLiteral(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
  return "'$escaped'";
}

/// The shim the site calls.
///
/// Top level, and next to nothing else, because it is one half of a contract:
/// every function here must have a matching `addJavaScriptHandler` in
/// [_WebViewPageState._setupJavaScriptHandlers], and the web layer
/// (`lib/native-bridge.ts` in the supabapnew repo) calls these names. It used
/// to be a `const` local inside `build()`, where it was easy to edit one side
/// of the contract without seeing the other.
///
/// Every call carries [token] as its first argument, and the Dart side rejects
/// anything without it. That is the real admission check, because the origin
/// check alone cannot do the job:
///
///  * `window.flutter_inappwebview.callHandler` is installed on Android with
///    `addJavascriptInterface`, which is present in EVERY frame — this shim is
///    only sugar over it.
///  * `InAppWebViewController.getUrl()` reports the MAIN frame, so a call from
///    a foreign frame is checked against the wrong document.
///  * `UserScript.forMainFrameOnly` does not help: it is not implemented in
///    flutter_inappwebview_android at all (grep it — the field never reaches
///    the platform). What DOES work there is `allowedOriginRules`, which
///    scopes injection to our origin, so a frame from anywhere else never
///    receives this object and therefore never learns the token.
///  * And navigation filtering cannot cover everything:
///    `WebViewClient.shouldOverrideUrlLoading` is documented as not being
///    called for POST requests, so a form submitted into a named iframe
///    reaches a genuinely cross-origin frame without passing
///    [NavigationPolicy.allowsSubFrame] at all.
///
/// The token is a per-launch secret, so it also cannot be replayed from a
/// previous session.
String _jsBridgeCode(String token) => '''
(function () {
  var t = ${_jsStringLiteral(token)};
  window.NativeApp = {
    openMaps: function(location) {
      window.flutter_inappwebview.callHandler('openMaps', t, location);
    },
    share: function(content) {
      window.flutter_inappwebview.callHandler('share', t, content);
    },
    call: function(number) {
      window.flutter_inappwebview.callHandler('call', t, number);
    },
    getOfferings: function() {
      return window.flutter_inappwebview.callHandler('getOfferings', t);
    },
    purchaseProduct: function(productId) {
      return window.flutter_inappwebview.callHandler('purchaseProduct', t, productId);
    },
    restorePurchases: function() {
      return window.flutter_inappwebview.callHandler('restorePurchases', t);
    },
    getCustomerInfo: function() {
      return window.flutter_inappwebview.callHandler('getCustomerInfo', t);
    },
    isPremiumActive: function() {
      return window.flutter_inappwebview.callHandler('isPremiumActive', t);
    },
    signInWithGoogle: function() {
      return window.flutter_inappwebview.callHandler('signInWithGoogle', t);
    },
    signInWithEmail: function(email, password) {
      return window.flutter_inappwebview.callHandler('signInWithEmail', t, email, password);
    },
    createAccountWithEmail: function(email, password) {
      return window.flutter_inappwebview.callHandler('createAccountWithEmail', t, email, password);
    },
    sendPasswordReset: function(email) {
      return window.flutter_inappwebview.callHandler('sendPasswordReset', t, email);
    },
    signOut: function() {
      return window.flutter_inappwebview.callHandler('signOut', t);
    },
    getAuthUser: function() {
      return window.flutter_inappwebview.callHandler('getAuthUser', t);
    },
    getIdToken: function(forceRefresh) {
      return window.flutter_inappwebview.callHandler('getIdToken', t, forceRefresh === true);
    }
  };
})();
''';

class WebViewPage extends ConsumerStatefulWidget {
  const WebViewPage({super.key});

  @override
  ConsumerState<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends ConsumerState<WebViewPage> {
  static final Logger _logger = Logger();

  InAppWebViewController? _webViewController;
  late final StreamSubscription<ConnectivityResult> _connectivitySubscription;

  bool _isLoading = true;
  bool _isOffline = false;
  double _loadingProgress = 0.0;
  bool _canGoBack = false;

  final InterstitialRequestCoordinator _interstitialRequests =
      InterstitialRequestCoordinator();

  /// Last URL counted towards the interstitial schedule, so the two callbacks
  /// that report navigation cannot both count the same one.
  String? _lastCountedNavigation;

  /// Set while a hardware Back press is in flight; see [_notifyNavigation].
  bool _suppressNextNavigationAd = false;

  /// Per-launch secret shared only with documents on the allowed origin.
  /// See [_jsBridgeCode] for why the origin check alone is not enough.
  final String _bridgeToken = _generateBridgeToken();

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _setupJavaScriptHandlers() {
    final controller = _webViewController;
    if (controller == null) return;

    final purchasesService = ref.read(purchasesServiceProvider);
    final authService = ref.read(authServiceProvider);

    // Legacy app commands
    controller.addJavaScriptHandler(
      handlerName: 'openMaps',
      callback: (args) async {
        final payload = await _admit(args);
        if (payload == null) return;
        final location = _stringArgument(payload);
        if (location != null) {
          await _launchExternalUrl(
            Uri(scheme: 'geo', query: location).toString(),
          );
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'share',
      callback: (args) async {
        final payload = await _admit(args);
        if (payload == null) return;
        final content = _stringArgument(payload);
        if (content != null) {
          await Share.share(content);
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'call',
      callback: (args) async {
        final payload = await _admit(args);
        if (payload == null) return;
        final number = _stringArgument(payload);
        if (number != null &&
            RegExp(r'^[0-9+()\-\s]{3,32}$').hasMatch(number)) {
          await _launchExternalUrl(Uri(scheme: 'tel', path: number).toString());
        }
      },
    );

    // RevenueCat integration
    controller.addJavaScriptHandler(
      handlerName: 'getOfferings',
      callback: (args) async {
        if (await _admit(args) == null) return <Map<String, dynamic>>[];
        return purchasesService.getOfferings();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'purchaseProduct',
      callback: (args) async {
        final payload = await _admit(args);
        if (payload == null) {
          return {'success': false, 'error': 'Untrusted WebView caller'};
        }
        final packageId = _stringArgument(payload);
        if (packageId == null) {
          return {'success': false, 'error': 'Product identifier is required'};
        }
        final result = await purchasesService.purchasePackage(packageId);
        // Re-query the entitlement so the banner disappears now rather than on
        // the next app launch.
        ref.invalidate(isPremiumProvider);
        return result;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'restorePurchases',
      callback: (args) async {
        final payload = await _admit(args);
        if (payload == null) {
          return {'success': false, 'error': 'Untrusted WebView caller'};
        }
        final result = await purchasesService.restorePurchases();
        ref.invalidate(isPremiumProvider);
        return result;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'getCustomerInfo',
      callback: (args) async {
        final payload = await _admit(args);
        if (payload == null) {
          return {'success': false, 'error': 'Untrusted WebView caller'};
        }
        return purchasesService.getCustomerInfo();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'isPremiumActive',
      callback: (args) async {
        if (await _admit(args) == null) return false;
        return purchasesService.isPremiumActive();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'triggerInterstitialOnAction',
      callback: (args) async {
        if (await _admit(args) == null || !mounted) return false;
        final adsService = ref.read(adsServiceProvider);

        return _interstitialRequests.run(
          canShow: () {
            if (!mounted) return false;
            if (ref.read(isPremiumProvider).value ?? false) return false;
            return adsService.canShowInterstitialOnAction();
          },
          requestConsent: _confirmInterstitialAd,
          showAd: adsService.showInterstitialOnAction,
        );
      },
    );

    // Firebase Auth. Sign-in runs natively because Google refuses OAuth from an
    // embedded WebView (403 disallowed_useragent); see auth_service.dart.
    //
    // None of these handlers call Purchases.logIn themselves. The RevenueCat
    // alias is driven off authStateChanges in identity_sync_service.dart, so
    // that a session restored on launch — which passes through none of these —
    // is identified too.
    controller.addJavaScriptHandler(
      handlerName: 'signInWithGoogle',
      callback: (args) async {
        final payload = await _admit(args);
        if (payload == null) {
          return {'success': false, 'error': 'Untrusted WebView caller'};
        }
        return authService.signInWithGoogle();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'signInWithEmail',
      callback: (args) async {
        final payload = await _admit(args);
        if (payload == null) {
          return {'success': false, 'error': 'Untrusted WebView caller'};
        }
        final creds = _credentialArguments(payload);
        if (creds == null) {
          return {'success': false, 'error': 'Email and password are required'};
        }
        return authService.signInWithEmail(creds.$1, creds.$2);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'createAccountWithEmail',
      callback: (args) async {
        final payload = await _admit(args);
        if (payload == null) {
          return {'success': false, 'error': 'Untrusted WebView caller'};
        }
        final creds = _credentialArguments(payload);
        if (creds == null) {
          return {'success': false, 'error': 'Email and password are required'};
        }
        return authService.createAccountWithEmail(creds.$1, creds.$2);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'sendPasswordReset',
      callback: (args) async {
        final payload = await _admit(args);
        if (payload == null) {
          return {'success': false, 'error': 'Untrusted WebView caller'};
        }
        final email = _stringArgument(payload);
        if (email == null) {
          return {'success': false, 'error': 'Email is required'};
        }
        return authService.sendPasswordReset(email);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'signOut',
      callback: (args) async {
        final payload = await _admit(args);
        if (payload == null) {
          return {'success': false, 'error': 'Untrusted WebView caller'};
        }
        return authService.signOut();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'getAuthUser',
      callback: (args) async {
        if (await _admit(args) == null) return null;
        return authService.describeUser();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'getIdToken',
      callback: (args) async {
        final payload = await _admit(args);
        if (payload == null) return null;
        // payload may carry a forceRefresh flag; absent means "cached is fine".
        final force = payload.isNotEmpty && payload.first == true;
        return authService.getIdToken(forceRefresh: force);
      },
    );
  }

  /// Reads an (email, password) pair from a bridge call.
  ///
  /// Deliberately does NOT reuse _stringArgument: that caps length at 512 and
  /// rejects anything but a lone argument, and silently mangling a credential
  /// would surface as an unexplained auth failure.
  /// The call's real arguments, with the bridge token stripped — or null when
  /// the caller is not entitled to be here.
  ///
  /// Both halves are required and neither is redundant. The token proves the
  /// CALLER received the injected shim, which `allowedOriginRules` grants only
  /// to our origin; the origin check proves the WebView is still displaying
  /// our site and has not been navigated away underneath a stale handler.
  Future<List<dynamic>?> _admit(List<dynamic> args) async {
    if (args.isEmpty || args.first is! String || args.first != _bridgeToken) {
      _logger.w('Bridge call rejected: missing or wrong token');
      return null;
    }
    if (!await _isTrustedBridgeContext()) {
      _logger.w('Bridge call rejected: untrusted origin');
      return null;
    }
    return args.sublist(1);
  }

  (String, String)? _credentialArguments(List<dynamic> args) {
    if (args.length != 2) return null;
    final email = args[0];
    final password = args[1];
    if (email is! String || password is! String) return null;
    if (email.trim().isEmpty || password.isEmpty) return null;
    if (email.length > 320 || password.length > 1024) return null;
    return (email, password);
  }

  String? _stringArgument(List<dynamic> args) {
    if (args.length != 1 || args.first is! String) return null;
    final value = (args.first as String).trim();
    return value.isEmpty || value.length > 512 ? null : value;
  }

  /// Whether the document currently loaded may use the bridge.
  ///
  /// `getUrl()` reports the MAIN frame, which is only a sufficient check
  /// because [NavigationPolicy.allowsSubFrame] refuses to load any frame from
  /// another origin — see the reasoning on that method. Loosen one and this
  /// check stops meaning anything.
  Future<bool> _isTrustedBridgeContext() async {
    final uri = await _webViewController?.getUrl();
    return NavigationPolicy.isTrustedBridgeOrigin(uri);
  }

  Future<void> _launchExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _logger.w('No application can handle URL: $url');
      }
    } catch (e) {
      _logger.w('Failed to launch URL: $url, Error: $e');
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (connectivity) {
        if (!mounted) return;
        final isConnected = connectivity != ConnectivityResult.none;

        if (isConnected && _isOffline) {
          unawaited(_reloadPage());
        }

        setState(() {
          _isOffline = !isConnected;
        });
      },
    );
  }

  void _handleWebViewError() {
    if (!mounted) return;
    setState(() {
      _isOffline = true;
      _isLoading = false;
    });
  }

  Future<void> _reloadPage() async {
    final controller = _webViewController;
    if (controller == null) return;

    setState(() {
      _isLoading = true;
      _isOffline = false;
    });

    try {
      await controller.reload();
    } catch (e) {
      _logger.w('Failed to reload page: $e');
      if (!mounted) return;
      setState(() {
        _isOffline = true;
        _isLoading = false;
      });
    }
  }

  /// Re-reads the WebView's own history depth.
  ///
  /// Called from both `onLoadStop` and `onUpdateVisitedHistory` because the
  /// site is a Next.js App Router SPA: its in-app navigation is `pushState`,
  /// which grows the WebView's history WITHOUT firing `onLoadStop`. Refreshing
  /// only on load stop left `_canGoBack` false for the whole session, so the
  /// hardware back button offered to exit the app from three screens deep.
  Future<void> _refreshCanGoBack() async {
    final controller = _webViewController;
    if (controller == null) return;
    try {
      final canGoBack = await controller.canGoBack();
      if (!mounted || canGoBack == _canGoBack) return;
      setState(() {
        _canGoBack = canGoBack;
      });
    } catch (e) {
      _logger.w('Could not read WebView history state: $e');
    }
  }

  /// Tells the ads service a page was reached, unless the user is Premium.
  ///
  /// Skipped for Premium so interstitials stay suppressed too — gating only the
  /// banner would still show a full-screen ad to a paying user.
  ///
  /// Deduplicated on the committed URL because BOTH `onLoadStop` and
  /// `onUpdateVisitedHistory` call this, and Android's
  /// `doUpdateVisitedHistory` — which is what backs the latter — fires on
  /// ordinary full page loads too, not only on pushState. Count a committed
  /// transition once and only offer an ad after a practice session ends.
  void _notifyNavigation(WebUri? url) {
    // Consumed FIRST, before the dedupe can return early. A hardware Back
    // press commits history too, so without the flag the user could be handed
    // a full-screen interstitial for trying to leave a page — impossible
    // before onUpdateVisitedHistory existed, since SPA history moves fired no
    // callback at all. But reading it after the dedupe left it armed whenever
    // Back landed on the URL already recorded (an SPA pushing a duplicate
    // entry does exactly that), and the next genuine page view was then
    // swallowed in its place.
    final suppressed = _suppressNextNavigationAd;
    _suppressNextNavigationAd = false;

    final key = url?.toString() ?? '';
    if (key == _lastCountedNavigation) return;
    final previous = _lastCountedNavigation;
    _lastCountedNavigation = key;

    if (suppressed) return;
    if (ref.read(isPremiumProvider).value != false) return;
    final ads = ref.read(adsServiceProvider);
    ads.onPageNavigation();
    if (!isPracticeCompletionTransition(previous, key)) return;
    // Do not interrupt the synchronous WebView history callback with a dialog.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_interstitialRequests.run(
        canShow: () =>
            mounted &&
            _lastCountedNavigation == key &&
            ref.read(isPremiumProvider).value == false &&
            ads.canShowInterstitialOnAction(),
        requestConsent: _confirmInterstitialAd,
        showAd: ads.showInterstitialOnAction,
      ));
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<bool> _handleBackPress() async {
    final controller = _webViewController;
    if (controller != null && _canGoBack) {
      _suppressNextNavigationAd = true;
      await controller.goBack();
      // goBack() does not fire onLoadStop for an SPA history entry either, so
      // the flag has to be re-read here or it stays true after reaching the
      // first page.
      await _refreshCanGoBack();
      return false; // Don't exit app
    }

    // On Android, show exit confirmation
    if (Platform.isAndroid) {
      return _showExitConfirmation();
    }

    return false; // Don't exit on iOS
  }

  Future<bool> _showExitConfirmation() async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Do you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmInterstitialAd() async {
    if (!mounted) return false;
    return InterstitialConsentDialog.show(context);
  }

  Future<NavigationActionPolicy> _onNavigation(
    InAppWebViewController controller,
    NavigationAction navigationAction,
  ) async {
    final urlString = navigationAction.request.url?.toString() ?? '';

    // Sub frames are decided separately and far more strictly. This used to be
    // an unconditional ALLOW, which let the page embed an iframe of any origin
    // — and on Android every frame can reach the JS bridge.
    if (!navigationAction.isForMainFrame) {
      return NavigationPolicy.allowsSubFrame(urlString)
          ? NavigationActionPolicy.ALLOW
          : NavigationActionPolicy.CANCEL;
    }

    switch (NavigationPolicy.decideMainFrame(urlString)) {
      case AllowInWebView():
        return NavigationActionPolicy.ALLOW;
      case LoadInstead(url: final url):
        await controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(url)));
        return NavigationActionPolicy.CANCEL;
      case OpenExternally(url: final url):
        await _launchExternalUrl(url);
        return NavigationActionPolicy.CANCEL;
      case BlockNavigation():
        _logger.w('Blocked navigation to: $urlString');
        return NavigationActionPolicy.CANCEL;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remoteConfig = ref.watch(remoteConfigServiceProvider);
    final bannerPlacement = remoteConfig.bannerPlacement;
    // Premium is what the user actually buys ("Remove Ads" on the web
    // subscription page), so it has to gate the banner. It previously did not:
    // ads depended on Remote Config alone and kept showing after a purchase.
    final isPremium = ref.watch(isPremiumProvider).value ?? false;
    final showBannerAd =
        !isPremium && remoteConfig.adsEnabled && remoteConfig.bannerAdsEnabled;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _handleBackPress();
          if (shouldPop && context.mounted) {
            unawaited(SystemNavigator.pop());
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppConstants.appTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload page',
              onPressed: _reloadPage,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'about':
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => const AboutPage(),
                      ),
                    );
                  case 'refresh_config':
                    unawaited(ref.read(remoteConfigServiceProvider).refresh());
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'about',
                  child: Text('About'),
                ),
                const PopupMenuItem(
                  value: 'refresh_config',
                  child: Text('Refresh Config'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isLoading) ProgressIndicatorWidget(progress: _loadingProgress),
            if (showBannerAd && bannerPlacement == 'top')
              const BannerAdWidget(),
            Expanded(
              child: _isOffline
                  ? OfflinePageWidget(onRetry: _reloadPage)
                  : InAppWebView(
                      initialUrlRequest:
                          URLRequest(url: WebUri(AppConfig.primaryUrl)),
                      initialUserScripts: UnmodifiableListView<UserScript>([
                        UserScript(
                          source: _jsBridgeCode(_bridgeToken),
                          injectionTime:
                              UserScriptInjectionTime.AT_DOCUMENT_START,
                          // The token must not reach any other origin. This is
                          // the only knob in 6.1.5 that enforces that:
                          // forMainFrameOnly is unimplemented on Android.
                          allowedOriginRules:
                              NavigationPolicy.bridgeOriginRules,
                        ),
                      ]),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        useShouldOverrideUrlLoading: true,
                        javaScriptCanOpenWindowsAutomatically: false,
                        supportMultipleWindows: false,
                        mediaPlaybackRequiresUserGesture: true,
                        allowsBackForwardNavigationGestures: true,
                        // The shell only ever displays one remote https site.
                        // It has no reason to read the device's filesystem or
                        // content providers, or to mix in plaintext
                        // subresources, so none of that is left switched on for
                        // whatever ends up running in the frame.
                        mixedContentMode:
                            MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
                        allowFileAccess: false,
                        allowContentAccess: false,
                        allowFileAccessFromFileURLs: false,
                        allowUniversalAccessFromFileURLs: false,
                        safeBrowsingEnabled: true,
                      ),
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                        _setupJavaScriptHandlers();
                      },
                      onLoadStart: (controller, url) {
                        if (!mounted) return;
                        setState(() {
                          _isLoading = true;
                          _loadingProgress = 0.0;
                        });
                      },
                      onProgressChanged: (controller, progress) {
                        if (!mounted) return;
                        setState(() {
                          _loadingProgress = progress / 100.0;
                        });
                      },
                      onLoadStop: (controller, url) async {
                        if (!mounted) return;
                        setState(() {
                          _isLoading = false;
                          _loadingProgress = 1.0;
                        });

                        await _refreshCanGoBack();
                        if (!mounted) return;
                        _notifyNavigation(url);
                      },
                      // Fires for pushState/replaceState as well as real loads,
                      // which is the only signal an SPA gives that the user
                      // moved between screens.
                      onUpdateVisitedHistory:
                          (controller, url, isReload) async {
                        if (isReload == true) return;
                        await _refreshCanGoBack();
                        if (!mounted) return;
                        _notifyNavigation(url);
                      },
                      shouldOverrideUrlLoading: _onNavigation,
                      onReceivedError: (controller, request, error) {
                        if (request.isForMainFrame != true) return;
                        _logger.w('WebView error: ${error.description}');
                        _handleWebViewError();
                      },
                    ),
            ),
            if (showBannerAd && bannerPlacement == 'bottom')
              const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}
