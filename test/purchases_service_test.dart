import 'package:flutter_test/flutter_test.dart';
import 'package:master_abap/core/services/purchases_service.dart';
import 'package:master_abap/core/services/remote_config_service.dart';

class FakeRemoteConfigService extends RemoteConfigService {
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

  group('packageMatches', () {
    // The regression this exists for: the web app sends the Google Play
    // product id, the offering identifies packages as $rc_annual/$rc_monthly,
    // and matching on pkg.identifier alone failed every purchase.
    test('matches the Google Play product id the web app actually sends', () {
      expect(
        PurchasesService.packageMatches(
          requested: 'supabap_premium_annual',
          packageIdentifier: r'$rc_annual',
          storeProductIdentifier: 'supabap_premium_annual',
        ),
        isTrue,
      );
    });

    test('matches a product id carrying a Google base-plan suffix', () {
      expect(
        PurchasesService.packageMatches(
          requested: 'supabap_premium_monthly',
          packageIdentifier: r'$rc_monthly',
          storeProductIdentifier: 'supabap_premium_monthly:monthly',
        ),
        isTrue,
      );
    });

    test('still matches the RevenueCat package identifier', () {
      expect(
        PurchasesService.packageMatches(
          requested: r'$rc_annual',
          packageIdentifier: r'$rc_annual',
          storeProductIdentifier: 'supabap_premium_annual',
        ),
        isTrue,
      );
    });

    test('still matches the short aliases', () {
      for (final alias in ['annual', 'yearly', 'Annual']) {
        expect(
          PurchasesService.packageMatches(
            requested: alias,
            packageIdentifier: r'$rc_annual',
            storeProductIdentifier: 'supabap_premium_annual',
          ),
          isTrue,
          reason: 'alias "$alias" should resolve to \$rc_annual',
        );
      }
    });

    test('does not match a different plan', () {
      expect(
        PurchasesService.packageMatches(
          requested: 'supabap_premium_annual',
          packageIdentifier: r'$rc_monthly',
          storeProductIdentifier: 'supabap_premium_monthly:monthly',
        ),
        isFalse,
      );
    });

    test('rejects an empty request rather than matching the first package', () {
      expect(
        PurchasesService.packageMatches(
          requested: '   ',
          packageIdentifier: r'$rc_annual',
          storeProductIdentifier: 'supabap_premium_annual',
        ),
        isFalse,
      );
    });
  });

  group('hasPremium', () {
    test('no active entitlement is not premium', () {
      expect(PurchasesService.hasPremium(const []), isFalse);
    });

    test('recognises the entitlement id the web app checks for', () {
      expect(PurchasesService.hasPremium(const ['entl4959706b0a']), isTrue);
      expect(PurchasesService.hasPremium(const ['premium']), isTrue);
    });

    test('recognises the identifier this file originally shipped with', () {
      expect(
        PurchasesService.hasPremium(
          const ['The Bug Amazing Factory of Apps Pro'],
        ),
        isTrue,
      );
    });

    test('rejects an unlisted active entitlement', () {
      // The seven-app suite may attach other products to the same RevenueCat
      // project. Only SupABAP's explicit entitlement ids may unlock SupABAP.
      expect(PurchasesService.hasPremium(const ['some_other_id']), isFalse);
    });
  });
}
