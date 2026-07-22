import 'package:flutter_test/flutter_test.dart';
import 'package:usman_sanda_palace/core/services/purchases_service.dart';
import 'package:usman_sanda_palace/core/services/remote_config_service.dart';

class FakeRemoteConfigService implements RemoteConfigService {
  @override
  String get revenueCatApiKeyAndroid => 'goog_fake_key';

  @override
  String get revenueCatApiKeyIOS => 'appl_fake_key';

  @override
  bool get adsEnabled => false;

  @override
  bool get adsTestMode => true;

  @override
  bool get bannerAdsEnabled => false;

  @override
  String get bannerAdUnitAndroid => '';

  @override
  String get bannerAdUnitIOS => '';

  @override
  String get bannerPlacement => 'bottom';

  @override
  int get configVersion => 1;

  @override
  bool get interstitialAdsEnabled => false;

  @override
  String get interstitialAdUnitAndroid => '';

  @override
  String get interstitialAdUnitIOS => '';

  @override
  int get interstitialFrequency => 3;

  @override
  Map<String, dynamic> getAllConfig() => {};

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refresh() async {}
}

void main() {
  group('PurchasesService Tests', () {
    test('Initialization starts false', () {
      final fakeRemoteConfig = FakeRemoteConfigService();
      final purchasesService = PurchasesService(fakeRemoteConfig);
      
      expect(purchasesService.isInitialized, isFalse);
    });
  });
}
