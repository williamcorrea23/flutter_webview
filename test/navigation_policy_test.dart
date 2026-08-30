import 'package:flutter_test/flutter_test.dart';
import 'package:master_abap/features/webview/domain/navigation_policy.dart';

/// These cover the app's trust boundary. Everything that passes
/// [NavigationPolicy] can run inside the WebView, and on Android anything
/// inside the WebView — including a nested frame — can reach the JS bridge
/// that starts purchases, creates accounts and hands out Firebase ID tokens.
void main() {
  group('isAllowedDomain', () {
    test('accepts the site itself, in any case', () {
      expect(NavigationPolicy.isAllowedDomain('supabapnew.vercel.app'), isTrue);
      expect(NavigationPolicy.isAllowedDomain('SupABAPNew.Vercel.App'), isTrue);
    });

    test('accepts a subdomain', () {
      expect(
        NavigationPolicy.isAllowedDomain('api.supabapnew.vercel.app'),
        isTrue,
      );
    });

    test('rejects a host that merely ends with the domain text', () {
      // The classic suffix-match hole: without the anchoring dot, an attacker
      // registers evilsupabapnew.vercel.app and inherits the whole bridge.
      expect(
        NavigationPolicy.isAllowedDomain('evilsupabapnew.vercel.app'),
        isFalse,
      );
    });

    test('rejects the domain as a prefix of somewhere else', () {
      expect(
        NavigationPolicy.isAllowedDomain('supabapnew.vercel.app.evil.com'),
        isFalse,
      );
    });

    test('rejects an unrelated host and an empty one', () {
      expect(NavigationPolicy.isAllowedDomain('example.com'), isFalse);
      expect(NavigationPolicy.isAllowedDomain(''), isFalse);
    });
  });

  group('isTrustedBridgeOrigin', () {
    test('accepts https on the allowed domain', () {
      expect(
        NavigationPolicy.isTrustedBridgeOrigin(
          Uri.parse('https://supabapnew.vercel.app/premium'),
        ),
        isTrue,
      );
    });

    test('rejects plain http even on the allowed domain', () {
      expect(
        NavigationPolicy.isTrustedBridgeOrigin(
          Uri.parse('http://supabapnew.vercel.app/'),
        ),
        isFalse,
      );
    });

    test('rejects another origin, and a null url', () {
      expect(
        NavigationPolicy.isTrustedBridgeOrigin(Uri.parse('https://evil.com/')),
        isFalse,
      );
      expect(NavigationPolicy.isTrustedBridgeOrigin(null), isFalse);
    });
  });

  group('bridgeOriginRules', () {
    test('covers every allowed domain and its subdomains', () {
      // These rules decide who receives the bridge token. If they ever stop
      // matching isAllowedDomain, either a legitimate page gets a bridge that
      // rejects everything, or the token reaches an origin navigation refuses.
      expect(
        NavigationPolicy.bridgeOriginRules,
        containsAll(<String>[
          'https://supabapnew.vercel.app',
          'https://*.supabapnew.vercel.app',
        ]),
      );
    });

    test('grants no rule to an origin isAllowedDomain would refuse', () {
      for (final rule in NavigationPolicy.bridgeOriginRules) {
        final host = rule.replaceFirst('https://', '').replaceFirst('*.', '');
        expect(
          NavigationPolicy.isAllowedDomain(host),
          isTrue,
          reason: 'rule "$rule" points at a host navigation would block',
        );
      }
    });

    test('is https-only', () {
      for (final rule in NavigationPolicy.bridgeOriginRules) {
        expect(rule, startsWith('https://'));
      }
    });
  });

  group('allowsSubFrame', () {
    test('allows a frame from the site itself', () {
      expect(
        NavigationPolicy.allowsSubFrame('https://supabapnew.vercel.app/embed'),
        isTrue,
      );
    });

    test('allows about:blank, which is how a frame starts out', () {
      expect(NavigationPolicy.allowsSubFrame('about:blank'), isTrue);
    });

    test('blocks about:srcdoc, which a sandbox attribute makes opaque', () {
      // <iframe sandbox="allow-scripts" srcdoc="..."> does NOT inherit the
      // parent origin — it gets an opaque one — so it is the natural place to
      // render untrusted content, and must not be inside the trusted frame set.
      expect(NavigationPolicy.allowsSubFrame('about:srcdoc'), isFalse);
    });

    test('blocks a frame whose url the platform could not report', () {
      // URLRequest.url is nullable; the caller passes '' for it. Fail closed.
      expect(NavigationPolicy.allowsSubFrame(''), isFalse);
    });

    test('allows a genuinely relative url', () {
      expect(NavigationPolicy.allowsSubFrame('/embed/widget'), isTrue);
    });

    test('blocks a protocol-relative url, which also parses scheme-less', () {
      // //evil.example/x has an empty scheme, like a relative URL, but carries
      // a host — waving all scheme-less URLs through would admit any origin.
      expect(NavigationPolicy.allowsSubFrame('//evil.example/x'), isFalse);
      expect(
        NavigationPolicy.allowsSubFrame('//supabapnew.vercel.app/x'),
        isFalse,
      );
    });

    test('blocks a cross-origin frame', () {
      // The whole point. The bridge is reachable from every frame on Android
      // while getUrl() only ever reports the main frame, so a foreign frame
      // that loads is a foreign frame that can call purchaseProduct.
      expect(NavigationPolicy.allowsSubFrame('https://evil.com/x'), isFalse);
    });

    test('blocks non-https frames and data/javascript urls', () {
      expect(
        NavigationPolicy.allowsSubFrame('http://supabapnew.vercel.app/'),
        isFalse,
      );
      expect(
        NavigationPolicy.allowsSubFrame('data:text/html,<script>1</script>'),
        isFalse,
      );
      expect(
        NavigationPolicy.allowsSubFrame('javascript:alert(1)'),
        isFalse,
      );
    });
  });

  group('decideMainFrame', () {
    test('loads the site in the WebView', () {
      expect(
        NavigationPolicy.decideMainFrame('https://supabapnew.vercel.app/learn'),
        isA<AllowInWebView>(),
      );
    });

    test('upgrades our own http links instead of ejecting to the browser', () {
      final decision =
          NavigationPolicy.decideMainFrame('http://supabapnew.vercel.app/x');
      expect(decision, isA<LoadInstead>());
      expect(
        (decision as LoadInstead).url.toString(),
        'https://supabapnew.vercel.app/x',
      );
    });

    test('sends a foreign web link to the system browser', () {
      expect(
        NavigationPolicy.decideMainFrame('https://example.com/'),
        isA<OpenExternally>(),
      );
    });

    test('sends platform schemes to their handler', () {
      expect(
        NavigationPolicy.decideMainFrame('tel:+5511999999999'),
        isA<OpenExternally>(),
      );
      expect(
        NavigationPolicy.decideMainFrame('mailto:hi@example.com'),
        isA<OpenExternally>(),
      );
      expect(
        NavigationPolicy.decideMainFrame('MAILTO:hi@example.com'),
        isA<OpenExternally>(),
      );
    });

    test('blocks schemes that are neither web nor a known handler', () {
      expect(
        NavigationPolicy.decideMainFrame('javascript:alert(1)'),
        isA<BlockNavigation>(),
      );
      expect(
        NavigationPolicy.decideMainFrame('file:///etc/passwd'),
        isA<BlockNavigation>(),
      );
      expect(
        NavigationPolicy.decideMainFrame('intent://evil#Intent;end'),
        isA<BlockNavigation>(),
      );
      expect(NavigationPolicy.decideMainFrame(''), isA<BlockNavigation>());
    });
  });
}
