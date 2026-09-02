import 'package:flutter/foundation.dart';

import '../../shared/constants/app_constants.dart';

class AppConfig {
  static const String appName = AppConstants.appName;
  static const String primaryUrl = 'https://supabapnew.vercel.app/';

  // Environment
  static bool get isDevelopment => kDebugMode;
  static bool get isProduction => kReleaseMode;

  // Allowed domains for WebView.
  //
  // This list is the app's trust boundary, not a convenience: anything on it
  // may run inside the WebView, in a frame, and therefore reach the JS bridge
  // that exposes purchases, sign-in and the Firebase ID token. Adding a CDN or
  // an analytics host here grants it all of that. See NavigationPolicy.
  static const List<String> allowedDomains = [
    'supabapnew.vercel.app',
  ];

  // External link patterns (will open in system browser)
  static const List<String> externalLinkPatterns = [
    r'^tel:',
    r'^mailto:',
    r'^sms:',
    r'^whatsapp:',
    r'^fb:',
    r'^twitter:',
    r'^instagram:',
    r'^linkedin:',
    r'^youtube:',
    r'^maps:',
    r'^geo:',
  ];

  // Remote Config defaults.
  //
  // The iOS ad unit ids below are Google's TEST units, and the iOS RevenueCat
  // key is a placeholder. That is survivable only while iOS is not shipped —
  // see the UnsupportedError in firebase_options.dart, which makes an iOS
  // build fail loudly rather than run with all three of auth, purchases and ad
  // revenue silently dead.
  static const Map<String, dynamic> remoteConfigDefaults = {
    'ads.enabled': true,
    'ads.testMode': false,
    'ads.banner.enabled': true,
    'ads.banner.placement': 'bottom',
    'ads.banner.adUnitId.android': 'ca-app-pub-8785125235072301/5430581499',
    'ads.banner.adUnitId.ios': 'ca-app-pub-3940256099942544/2934735716',
    'ads.interstitial.enabled': false,
    'ads.interstitial.frequency': 3,
    'ads.interstitial.interval_seconds': 90,
    'ads.interstitial.adUnitId.android': 'ca-app-pub-8785125235072301/9453640886',
    'ads.interstitial.adUnitId.ios': 'ca-app-pub-3940256099942544/4411468910',
    'config.version': 1,
    'revenuecat.apiKey.android': 'goog_FqFNSCJonpAkvKrGrGwaFLKYcZL',
    'revenuecat.apiKey.ios': 'appl_placeholder_api_key_ios',
  };

  // AdMob test unit IDs
  static const String testBannerAdUnitAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String testBannerAdUnitIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const String testInterstitialAdUnitAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String testInterstitialAdUnitIOS = 'ca-app-pub-3940256099942544/4411468910';
}
