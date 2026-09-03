import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logger/logger.dart';

import '../config/app_config.dart';
import 'ad_load_diagnostics.dart';
import 'consent_service.dart';
import 'remote_config_service.dart';

final adsServiceProvider = ChangeNotifierProvider<AdsService>((ref) {
  // ChangeNotifierProvider owns the notifier and calls dispose itself. Adding
  // ref.onDispose(service.dispose) here disposes it twice when the provider
  // container is torn down (and also disposes each native ad twice).
  return AdsService(
    ref.read(remoteConfigServiceProvider),
    ref.read(consentServiceProvider),
  );
});

class AdsService extends ChangeNotifier {
  static final Logger _logger = Logger();

  final RemoteConfigService _remoteConfig;
  final ConsentService _consentService;

  BannerAd? _bannerAd;
  BannerAd? _pendingBannerAd;
  Timer? _bannerTimeout;
  int _bannerGeneration = 0;
  int _interstitialGeneration = 0;
  bool _disposed = false;
  bool _sdkReady = false;
  bool _diagnosticTestBanner = false;
  final bannerDiagnostics = AdLoadDiagnostics();
  final interstitialDiagnostics = AdLoadDiagnostics();
  InterstitialAd? _interstitialAd;

  bool _isInitialized = false;
  int _pageNavigationCount = 0;
  DateTime? _lastInterstitialShown;

  AdsService(this._remoteConfig, this._consentService);

  bool get isInitialized => _isInitialized;
  BannerAd? get bannerAd => _bannerAd;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Wait for consent service to be ready
      if (!_consentService.isInitialized) {
        await _consentService.initialize();
      }

      // Only initialize ads if consent allows and ads are enabled
      if (_consentService.canRequestAds && _remoteConfig.adsEnabled) {
        await _ensureSdkReady();
      }
      await _loadBannerAd();
      await _loadInterstitialAd();

      _isInitialized = true;
      _logger.i(
          'Ads service initialized. Ads enabled: ${_remoteConfig.adsEnabled}');
    } catch (e) {
      if (_disposed) return;
      bannerDiagnostics.failed(
          -1, 'app', 'Ads initialization failed (${e.runtimeType})', null);
      interstitialDiagnostics.failed(
          -1, 'app', 'Ads initialization failed (${e.runtimeType})', null);
      notifyListeners();
      _isInitialized = true; // Mark as initialized even on error
    }
  }

  Future<void> _loadBannerAd() async {
    if (_disposed) return;
    if (!_remoteConfig.adsEnabled ||
        !_remoteConfig.bannerAdsEnabled ||
        !_consentService.canRequestAds) {
      bannerDiagnostics.state =
          !_remoteConfig.adsEnabled || !_remoteConfig.bannerAdsEnabled
              ? 'disabled_by_config'
              : 'consent_blocked';
      notifyListeners();
      return;
    }

    final generation = ++_bannerGeneration;
    try {
      final adUnitId = _getBannerAdUnitId();
      if (adUnitId.isEmpty) {
        bannerDiagnostics.state = 'missing_ad_unit';
        notifyListeners();
        return;
      }
      bannerDiagnostics.begin();
      notifyListeners();
      _bannerTimeout?.cancel();
      _bannerTimeout = Timer(const Duration(seconds: 30), () {
        if (_disposed ||
            generation != _bannerGeneration ||
            _pendingBannerAd == null) {
          return;
        }
        _bannerGeneration++;
        unawaited(_pendingBannerAd!.dispose());
        _pendingBannerAd = null;
        bannerDiagnostics.failed(
            -2,
            'app',
            'No SDK callback within 30 seconds. Retry or compare with a test banner.',
            null);
        notifyListeners();
      });

      final candidate = BannerAd(
        adUnitId: adUnitId,
        size: AdSize.banner,
        request: _buildAdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (_disposed || generation != _bannerGeneration) return;
            _bannerTimeout?.cancel();
            _bannerAd = ad as BannerAd;
            _pendingBannerAd = null;
            bannerDiagnostics.loaded(ad.responseInfo?.responseId);
            notifyListeners();
            _logger.i('Banner ad loaded successfully');
          },
          onAdFailedToLoad: (ad, error) {
            if (_disposed || generation != _bannerGeneration) return;
            _bannerTimeout?.cancel();
            bannerDiagnostics.failed(error.code, error.domain, error.message,
                error.responseInfo?.responseId);
            _logger.w('Banner ad failed: ${bannerDiagnostics.snapshot()}');
            ad.dispose();
            _bannerAd = null;
            _pendingBannerAd = null;
            notifyListeners();
          },
          onAdOpened: (ad) {
            _logger.i('Banner ad opened');
          },
          onAdClosed: (ad) {
            _logger.i('Banner ad closed');
          },
        ),
      );

      _pendingBannerAd = candidate;
      await candidate.load();
    } catch (e) {
      if (_disposed || generation != _bannerGeneration) return;
      _bannerTimeout?.cancel();
      bannerDiagnostics.failed(
          -1, 'app', 'Banner load exception (${e.runtimeType})', null);
      unawaited(_pendingBannerAd?.dispose() ?? Future<void>.value());
      _pendingBannerAd = null;
      notifyListeners();
    }
  }

  Future<void> _loadInterstitialAd() async {
    if (_disposed) return;
    if (!_remoteConfig.adsEnabled ||
        !_remoteConfig.interstitialAdsEnabled ||
        !_consentService.canRequestAds) {
      interstitialDiagnostics.state =
          !_remoteConfig.adsEnabled || !_remoteConfig.interstitialAdsEnabled
              ? 'disabled_by_config'
              : 'consent_blocked';
      notifyListeners();
      return;
    }

    final generation = ++_interstitialGeneration;
    try {
      final adUnitId = _getInterstitialAdUnitId();
      if (adUnitId.isEmpty) {
        interstitialDiagnostics.state = 'missing_ad_unit';
        notifyListeners();
        return;
      }
      interstitialDiagnostics.begin();
      notifyListeners();

      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: _buildAdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (_disposed || generation != _interstitialGeneration) {
              unawaited(ad.dispose());
              return;
            }
            _interstitialAd = ad;
            interstitialDiagnostics.loaded(ad.responseInfo?.responseId);
            notifyListeners();
            _logger.i('Interstitial ad loaded successfully');

            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                _logger.i('Interstitial ad showed full screen');
              },
              onAdDismissedFullScreenContent: (ad) {
                _logger.i('Interstitial ad dismissed');
                unawaited(ad.dispose());
                if (_disposed || generation != _interstitialGeneration) return;
                _interstitialAd = null;
                // Pre-load next interstitial
                unawaited(_loadInterstitialAd());
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                unawaited(ad.dispose());
                if (_disposed || generation != _interstitialGeneration) return;
                _interstitialAd = null;
                unawaited(_loadInterstitialAd());
              },
            );
          },
          onAdFailedToLoad: (error) {
            if (_disposed || generation != _interstitialGeneration) return;
            interstitialDiagnostics.failed(error.code, error.domain,
                error.message, error.responseInfo?.responseId);
            _interstitialAd = null;
            notifyListeners();
          },
        ),
      );
    } catch (e) {
      if (_disposed || generation != _interstitialGeneration) return;
      interstitialDiagnostics.failed(
          -1, 'app', 'Interstitial load exception (${e.runtimeType})', null);
      notifyListeners();
    }
  }

  AdRequest _buildAdRequest() {
    final extras = _consentService.getAdRequestExtras();
    return AdRequest(extras: extras);
  }

  String _getBannerAdUnitId() {
    if (_diagnosticTestBanner || _remoteConfig.adsTestMode || kDebugMode) {
      return Platform.isAndroid
          ? AppConfig.testBannerAdUnitAndroid
          : AppConfig.testBannerAdUnitIOS;
    }

    return Platform.isAndroid
        ? _remoteConfig.bannerAdUnitAndroid
        : _remoteConfig.bannerAdUnitIOS;
  }

  String _getInterstitialAdUnitId() {
    if (_remoteConfig.adsTestMode || kDebugMode) {
      return Platform.isAndroid
          ? AppConfig.testInterstitialAdUnitAndroid
          : AppConfig.testInterstitialAdUnitIOS;
    }

    return Platform.isAndroid
        ? _remoteConfig.interstitialAdUnitAndroid
        : _remoteConfig.interstitialAdUnitIOS;
  }

  void onPageNavigation() {
    _pageNavigationCount++;
  }

  /// Whether an action-triggered interstitial can be shown right now.
  ///
  /// Callers use this before asking for explicit user consent. The show method
  /// repeats the check because the loaded ad or cooldown state may change while
  /// a consent dialog is open.
  bool canShowInterstitialOnAction({bool force = false}) {
    if (_disposed ||
        !_remoteConfig.adsEnabled ||
        !_remoteConfig.interstitialAdsEnabled ||
        !_consentService.canRequestAds ||
        _interstitialAd == null) {
      return false;
    }

    if (!force && _lastInterstitialShown != null) {
      final timeSinceLastAd =
          DateTime.now().difference(_lastInterstitialShown!);
      final minInterval = _remoteConfig.interstitialIntervalSeconds;
      if (timeSinceLastAd.inSeconds < minInterval) return false;
    }

    return true;
  }

  /// Displays an interstitial after a user-initiated action (e.g. AI prompt
  /// response), strictly enforcing the minimum cooldown interval.
  Future<bool> showInterstitialOnAction({bool force = false}) async {
    if (!canShowInterstitialOnAction(force: force)) return false;
    return showInterstitial();
  }

  Future<bool> showInterstitial() async {
    if (!canShowInterstitialOnAction()) return false;
    final ad = _interstitialAd;
    if (ad == null) return false;

    // Reserve this single-use ad before crossing an async boundary. A second
    // bridge or navigation request must not be able to show the same instance.
    _interstitialAd = null;

    try {
      await ad.show();
      _lastInterstitialShown = DateTime.now();
      _logger.i('Interstitial ad shown');
      return true;
    } catch (e) {
      _logger.e('Error showing interstitial ad: $e');
      unawaited(ad.dispose());
      unawaited(_loadInterstitialAd());
      return false;
    }
  }

  Future<void> _ensureSdkReady() async {
    if (_sdkReady) return;
    await MobileAds.instance.initialize();
    _sdkReady = true;
  }

  /// Local to this process: never toggles test ads for production users.
  Future<void> retryBanner({bool useGoogleTestAd = false}) async {
    if (_disposed || (useGoogleTestAd && !AppConfig.diagnosticsEnabled)) return;
    _diagnosticTestBanner = useGoogleTestAd;
    final generation = ++_bannerGeneration;
    _bannerTimeout?.cancel();
    unawaited(_pendingBannerAd?.dispose() ?? Future<void>.value());
    unawaited(_bannerAd?.dispose() ?? Future<void>.value());
    _pendingBannerAd = null;
    _bannerAd = null;
    notifyListeners();
    if (_remoteConfig.adsEnabled &&
        _remoteConfig.bannerAdsEnabled &&
        _consentService.canRequestAds) {
      try {
        await _ensureSdkReady();
      } catch (e) {
        if (_disposed) return;
        bannerDiagnostics.failed(-1, 'app',
            'Ads SDK initialization failed (${e.runtimeType})', null);
        notifyListeners();
        return;
      }
    }
    if (_disposed || generation != _bannerGeneration) return;
    await _loadBannerAd();
  }

  Future<void> refreshAds() async {
    if (_disposed) return;
    _logger.i('Refreshing ads based on new config');

    // Dispose existing ads. Not awaited: disposal is fire-and-forget on the
    // platform side and the reload below must not wait on it.
    _bannerGeneration++;
    _interstitialGeneration++;
    _bannerTimeout?.cancel();
    unawaited(_pendingBannerAd?.dispose() ?? Future<void>.value());
    _pendingBannerAd = null;
    unawaited(_bannerAd?.dispose() ?? Future<void>.value());
    _bannerAd = null;
    notifyListeners();
    unawaited(_interstitialAd?.dispose() ?? Future<void>.value());
    _interstitialAd = null;

    // Reload if ads are enabled
    if (_remoteConfig.adsEnabled && _consentService.canRequestAds) {
      await _ensureSdkReady();
    }
    await _loadBannerAd();
    await _loadInterstitialAd();
  }

  @override
  void dispose() {
    _disposed = true;
    _bannerTimeout?.cancel();
    _bannerGeneration++;
    _interstitialGeneration++;
    _pendingBannerAd?.dispose();
    _pendingBannerAd = null;
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _bannerAd = null;
    _interstitialAd = null;
    super.dispose();
  }

  // Debug info
  Map<String, dynamic> getDebugInfo() {
    return {
      'isInitialized': _isInitialized,
      'adsEnabled': _remoteConfig.adsEnabled,
      'bannerAdsEnabled': _remoteConfig.bannerAdsEnabled,
      'interstitialAdsEnabled': _remoteConfig.interstitialAdsEnabled,
      'testMode': _remoteConfig.adsTestMode,
      'effectiveBannerTestMode':
          _diagnosticTestBanner || _remoteConfig.adsTestMode || kDebugMode,
      'bannerUnit': _getBannerAdUnitId(),
      'bannerPlacement': _remoteConfig.bannerPlacement,
      'canRequestAds': _consentService.canRequestAds,
      'bannerAdLoaded': _bannerAd != null,
      'interstitialAdLoaded': _interstitialAd != null,
      ...bannerDiagnostics
          .snapshot()
          .map((key, value) => MapEntry('banner.$key', value)),
      ...interstitialDiagnostics
          .snapshot()
          .map((key, value) => MapEntry('interstitial.$key', value)),
      'pageNavigationCount': _pageNavigationCount,
      'lastInterstitialShown': _lastInterstitialShown?.toIso8601String(),
    };
  }
}
