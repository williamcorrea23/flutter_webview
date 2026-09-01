import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:master_abap/features/webview/presentation/interstitial_request_coordinator.dart';

void main() {
  group('InterstitialRequestCoordinator', () {
    test('does not ask for consent when no ad can be shown', () async {
      final coordinator = InterstitialRequestCoordinator();
      var consentRequested = false;
      var showCalled = false;

      final result = await coordinator.run(
        canShow: () => false,
        requestConsent: () async {
          consentRequested = true;
          return true;
        },
        showAd: () async {
          showCalled = true;
          return true;
        },
      );

      expect(result, isFalse);
      expect(consentRequested, isFalse);
      expect(showCalled, isFalse);
    });

    test('does not show the ad when consent is declined', () async {
      final coordinator = InterstitialRequestCoordinator();
      var showCalled = false;

      final result = await coordinator.run(
        canShow: () => true,
        requestConsent: () async => false,
        showAd: () async {
          showCalled = true;
          return true;
        },
      );

      expect(result, isFalse);
      expect(showCalled, isFalse);
    });

    test('rechecks eligibility after the consent dialog', () async {
      final coordinator = InterstitialRequestCoordinator();
      var canShow = true;
      var showCalled = false;

      final result = await coordinator.run(
        canShow: () => canShow,
        requestConsent: () async {
          canShow = false;
          return true;
        },
        showAd: () async {
          showCalled = true;
          return true;
        },
      );

      expect(result, isFalse);
      expect(showCalled, isFalse);
    });

    test('shares one consent and display flow between concurrent calls',
        () async {
      final coordinator = InterstitialRequestCoordinator();
      final consent = Completer<bool>();
      var consentRequests = 0;
      var showCalls = 0;

      Future<bool> requestConsent() {
        consentRequests++;
        return consent.future;
      }

      Future<bool> showAd() async {
        showCalls++;
        return true;
      }

      final first = coordinator.run(
        canShow: () => true,
        requestConsent: requestConsent,
        showAd: showAd,
      );
      final second = coordinator.run(
        canShow: () => true,
        requestConsent: requestConsent,
        showAd: showAd,
      );

      expect(second, same(first));
      expect(coordinator.isActive, isTrue);
      expect(consentRequests, 1);

      consent.complete(true);
      expect(await Future.wait([first, second]), [true, true]);
      expect(showCalls, 1);
      expect(coordinator.isActive, isFalse);
    });
  });
}
