import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const String appName = 'Master ABAP';
  static const String primaryDomain = 'supabapnew.vercel.app';
  static const String primaryUrl = 'https://supabapnew.vercel.app/';
  
  // Bundle IDs
  static const String androidBundleId = 'co.supabap.android';
  static const String iosBundleId = 'co.supabap.android';
  
  // Legal
  static const String legalNotice = '© Master ABAP. All Rights Reserved. Developed by Compilemama.';
  
  // Environment
  static bool get isDevelopment => kDebugMode;
  static bool get isProduction => kReleaseMode;
  
  static String get envFileName {
    return isDevelopment ? '.env.development' : '.env.production';
  }
  
  // Firebase
  static String get firebaseProjectId => dotenv.get('FIREBASE_PROJECT_ID', fallback: '');
  
  // Allowed domains for WebView
  static final List<String> allowedDomains = [
    'supabapnew.vercel.app',
    // Add subdomains and CDNs as needed
  ];
  
  // External link patterns (will open in system browser)
  static final List<String> externalLinkPatterns = [
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
  
  // Remote Config defaults
  static const Map<String, dynamic> remoteConfigDefaults = {
    'ads.enabled': true,
    'ads.testMode': true,
    'ads.banner.enabled': true,
    'ads.banner.placement': 'bottom',
    'ads.banner.adUnitId.android': 'ca-app-pub-8785125235072301/5430581499',
    'ads.banner.adUnitId.ios': 'ca-app-pub-3940256099942544/2934735716',
    'ads.interstitial.enabled': false,
    'ads.interstitial.frequency': 3,
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
