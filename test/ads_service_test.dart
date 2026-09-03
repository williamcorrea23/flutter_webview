import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// SDK instance lookup is used only to simulate native callbacks in tests.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:master_abap/core/services/ads_service.dart';
import 'package:master_abap/core/services/consent_service.dart';
import 'purchases_service_test.dart' show FakeRemoteConfigService;

class AdConfig extends FakeRemoteConfigService {
  bool enabled = true;
  @override
  bool get adsEnabled => enabled;
  @override
  bool get bannerAdsEnabled => true;
  @override
  bool get interstitialAdsEnabled => true;
}

class AdConsent extends ConsentService {
  bool allowed = true;
  @override
  bool get canRequestAds => allowed;
  @override
  bool get isInitialized => true;
  @override
  Map<String, String> getAdRequestExtras() => {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final bannerIds = <int>[];
  final interstitialIds = <int>[];
  var shows = 0;
  setUp(() {
    bannerIds.clear();
    interstitialIds.clear();
    shows = 0;
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      if (call.method == 'MobileAds#initialize') {
        return InitializationStatus({});
      }
      if (call.method == 'loadBannerAd') {
        bannerIds.add(call.arguments['adId'] as int);
      }
      if (call.method == 'loadInterstitialAd') {
        interstitialIds.add(call.arguments['adId'] as int);
      }
      if (call.method == 'showAdWithoutView') shows++;
      return null;
    });
  });
  tearDown(
      () => messenger.setMockMethodCallHandler(instanceManager.channel, null));

  test('provider owns and disposes the ads service exactly once', () {
    final container = ProviderContainer();

    // Materialize the provider so disposal exercises the ChangeNotifier
    // lifecycle rather than only tearing down an unread container.
    container.read(adsServiceProvider);

    expect(container.dispose, returnsNormally);
  });

  test('native banner failure persists diagnostics and retry can recover',
      () async {
    final service = AdsService(AdConfig(), AdConsent());
    addTearDown(service.dispose);
    await service.initialize();
    expect(service.bannerAd, isNull);
    expect(service.bannerDiagnostics.state, 'loading');
    final first = instanceManager.adFor(bannerIds.single) as BannerAd;
    first.listener.onAdFailedToLoad!(
        first, LoadAdError(3, 'com.google.android.gms.ads', 'No fill', null));
    expect(service.bannerDiagnostics.errorCode, 3);
    expect(service.bannerAd, isNull);
    await service.retryBanner();
    final second = instanceManager.adFor(bannerIds.last) as BannerAd;
    second.listener.onAdLoaded!(second);
    expect(service.bannerAd, same(second));
    expect(service.getDebugInfo()['bannerAdLoaded'], true);
    expect(service.bannerDiagnostics.errorCode, isNull);
  });

  testWidgets('banner callback timeout allows retry and ignores late success',
      (tester) async {
    final service = AdsService(AdConfig(), AdConsent());
    addTearDown(service.dispose);
    await service.initialize();
    final pending = instanceManager.adFor(bannerIds.single) as BannerAd;
    await tester.pump(const Duration(seconds: 31));
    expect(service.bannerDiagnostics.errorCode, -2);
    pending.listener.onAdLoaded!(pending);
    expect(service.bannerAd, isNull);
  });

  test(
      'stale banner callback cannot replace new request or notify after disposal',
      () async {
    final service = AdsService(AdConfig(), AdConsent());
    await service.initialize();
    final old = instanceManager.adFor(bannerIds.single) as BannerAd;
    await service.retryBanner();
    old.listener.onAdLoaded!(old);
    expect(service.bannerAd, isNull);
    final latest = instanceManager.adFor(bannerIds.last) as BannerAd;
    service.dispose();
    expect(() => latest.listener.onAdLoaded!(latest), returnsNormally);
  });

  test(
      'consent prevents all requests; global switch suppresses loaded interstitial',
      () async {
    final config = AdConfig();
    final consent = AdConsent()..allowed = false;
    final service = AdsService(config, consent);
    addTearDown(service.dispose);
    await service.initialize();
    expect(bannerIds, isEmpty);
    expect(interstitialIds, isEmpty);
    expect(service.bannerDiagnostics.state, 'consent_blocked');
    consent.allowed = true;
    await service.refreshAds();
    final ad = instanceManager.adFor(interstitialIds.single) as InterstitialAd;
    ad.adLoadCallback.onAdLoaded(ad);
    expect(service.canShowInterstitialOnAction(), true);
    for (var i = 0; i < 10; i++) {
      service.onPageNavigation();
    }
    expect(shows, 0);
    config.enabled = false;
    expect(await service.showInterstitialOnAction(), false);
    expect(shows, 0);
  });
}
