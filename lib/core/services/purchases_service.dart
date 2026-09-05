import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'remote_config_service.dart';

final purchasesServiceProvider = Provider<PurchasesService>((ref) {
  final remoteConfig = ref.read(remoteConfigServiceProvider);
  return PurchasesService(remoteConfig);
});

/// Whether this device currently holds Premium.
///
/// Exists so the ad code can ask. Before this, nothing in the Flutter app read
/// the entitlement at all: `isPremiumActive` was exposed to the WebView as a JS
/// handler and never consulted natively, so the banner and interstitials were
/// gated purely on Remote Config — a user could buy "Remove Ads" and keep
/// seeing ads. Reads false until RevenueCat answers, so ads are suppressed only
/// on a positive confirmation rather than on "not loaded yet".
/// Invalidate after a purchase or restore to re-query.
final isPremiumProvider = FutureProvider<bool>((ref) async {
  return ref.read(purchasesServiceProvider).isPremiumActive();
});

class PurchasesService {
  static final Logger _logger = Logger();

  /// Entitlement identifiers that grant Premium, checked in order.
  ///
  /// Verified against RevenueCat project proj03e9d683 (V2 API, 2026-08-14):
  /// the project defines exactly ONE entitlement —
  ///   id         = entl4959706b0a
  ///   lookup_key = The Bug Amazing Factory of Apps Pro
  /// purchases_flutter keys `customerInfo.entitlements` by the LOOKUP KEY, so
  /// that string is what actually turns up at runtime; `entl4959706b0a` is the
  /// REST object id and only ever appears server-side (the web app's
  /// lib/revenuecat.ts matches on it). Both are listed so this works whichever
  /// side supplies the value, plus 'premium', the token the JS bridge
  /// synthesizes in lib/native-bridge.ts.
  static const List<String> premiumEntitlementIds = [
    'The Bug Amazing Factory of Apps Pro',
    'entl4959706b0a',
    'supsales_premium',
    'premium',
  ];

  final RemoteConfigService _remoteConfig;
  bool _isInitialized = false;
  // Memoized so every read method below can await the SAME in-flight
  // initialize() call instead of racing it. main.dart's _initializeServices()
  // is fired from initState() and not awaited before build() runs, so the
  // WebView (and the JS bridge's first GET_ENTITLEMENTS call) can reach these
  // methods before initialize() finishes. Without this, `_isInitialized` is
  // still false at that moment and isPremiumActive()/restorePurchases() return
  // a plain `false`/`success: false` — indistinguishable from a genuine
  // "checked, not premium" — which the web side (lib/native-bridge.ts in the
  // supabapnew repo) can read as confirmation and use to revoke a real
  // subscriber's Premium.
  Future<void>? _initializeFuture;

  PurchasesService(this._remoteConfig);

  bool get isInitialized => _isInitialized;

  // Delegates to initialize() itself rather than only awaiting an
  // already-started _initializeFuture: a JS call can reach here before
  // main.dart's _initializeServices() has gotten as far as calling
  // initialize() at all (it awaits consent and remote-config init first), in
  // which case _initializeFuture would still be null and there would be
  // nothing to wait on. initialize() is idempotent — see its own memoization.
  Future<void> _ensureInitialized() => initialize();

  static String _packageAlias(String lowercased) {
    return switch (lowercased) {
      'monthly' || r'$rc_monthly' => r'$rc_monthly',
      'yearly' || 'annual' || r'$rc_annual' => r'$rc_annual',
      'lifetime' || r'$rc_lifetime' => r'$rc_lifetime',
      final value => value,
    };
  }

  /// Whether one offering package answers to [requested].
  ///
  /// What the web app sends is NOT necessarily a RevenueCat *package*
  /// identifier: app/premium/page.tsx sends the Google Play product id it got
  /// from /api/revenuecat/catalog (e.g. `supabap_premium_annual`), while the
  /// packages in the offering are identified as `$rc_annual` / `$rc_monthly`.
  /// Matching on `pkg.identifier` alone therefore matched nothing and every
  /// purchase died as "Package supabap_premium_annual not found". Accept the
  /// package identifier, its short alias, and the underlying store product —
  /// so this works whichever form the caller uses, without this file having to
  /// know how the RevenueCat dashboard happens to be configured.
  @visibleForTesting
  static bool packageMatches({
    required String requested,
    required String packageIdentifier,
    required String storeProductIdentifier,
  }) {
    final want = requested.trim().toLowerCase();
    if (want.isEmpty) return false;

    final package = packageIdentifier.trim().toLowerCase();
    if (package == want || package == _packageAlias(want)) return true;

    final product = storeProductIdentifier.trim().toLowerCase();
    if (product == want) return true;
    // Google Play subscriptions surface as "<subscriptionId>:<basePlanId>".
    if (product.split(':').first == want) return true;

    return false;
  }

  /// Whether any of [activeEntitlementIds] grants Premium.
  ///
  /// Fails closed: an entitlement from another app or add-on must never unlock
  /// SupABAP. This matters once all seven apps share RevenueCat infrastructure.
  /// New SupABAP entitlement ids must be added explicitly to
  /// [premiumEntitlementIds] before they can grant access.
  @visibleForTesting
  static bool hasPremium(Iterable<String> activeEntitlementIds) {
    final active = activeEntitlementIds.toSet();
    if (active.isEmpty) return false;

    for (final id in premiumEntitlementIds) {
      if (active.contains(id)) return true;
    }

    _logger.w(
      'Ignoring active entitlements outside premiumEntitlementIds: '
      '${active.toList()}. Add a verified SupABAP identifier explicitly.',
    );
    return false;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    final future = _initializeFuture ??= _doInitialize();
    try {
      await future;
    } finally {
      // Only keep the memoized future on success. Every early return and the
      // catch block inside _doInitialize leave _isInitialized false, and
      // unlike the pre-fix code (which re-ran the whole body on every
      // initialize() call while uninitialized), pinning `future` here forever
      // would stop a later call from retrying — e.g. remote config's keys
      // were still the empty/placeholder defaults on this attempt but arrive
      // for real moments later. This must run here, not inside _doInitialize:
      // when it returns before its first await (the empty-key/placeholder
      // paths), the whole function body — including a `finally` there —
      // would execute synchronously before `??=` assigns its result, so
      // clearing the field from inside it gets immediately clobbered by that
      // assignment. The identical() check avoids clobbering a newer in-flight
      // attempt some other caller has already started in the meantime.
      if (!_isInitialized && identical(_initializeFuture, future)) {
        _initializeFuture = null;
      }
    }
  }

  Future<void> _doInitialize() async {
    try {
      final androidKey = _remoteConfig.revenueCatApiKeyAndroid;
      final iosKey = _remoteConfig.revenueCatApiKeyIOS;

      final currentKey = Platform.isAndroid ? androidKey : iosKey;
      if (currentKey.isEmpty) {
        _logger.w('RevenueCat API Keys are empty. Skipping initialization.');
        return;
      }

      if (currentKey.contains('placeholder')) {
        _logger.w(
            'RevenueCat API Keys are placeholders. Skipping initialization in production.');
        if (kReleaseMode) return;
      }

      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      } else {
        await Purchases.setLogLevel(LogLevel.info);
      }

      late PurchasesConfiguration configuration;
      if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(androidKey);
      } else if (Platform.isIOS) {
        configuration = PurchasesConfiguration(iosKey);
      } else {
        _logger.w('Unsupported platform for RevenueCat.');
        return;
      }

      await Purchases.configure(configuration);
      _isInitialized = true;
      _logger.i('RevenueCat initialized successfully.');
    } catch (e) {
      _logger.e('Error initializing RevenueCat: $e');
    }
  }

  /// Point RevenueCat at [appUserId] — here, the Firebase uid.
  ///
  /// This is deliberately NOT the RevenueCat↔Firebase integration, which is a
  /// paid-plan feature. It is client-side app-user-id aliasing, which the free
  /// plan supports in full: `logIn` transfers the device's anonymous
  /// RevenueCat user onto the identified one, so the entitlement follows the
  /// person instead of the install.
  ///
  /// Without it the SDK stays on its anonymous per-device id forever, which
  /// costs in both directions: a subscriber signing in on a second device sees
  /// no Premium, and — worse — signing out and signing in as somebody else on
  /// the SAME device hands the new account the previous one's Premium, because
  /// nothing about the entitlement was ever tied to who was signed in.
  ///
  /// Never throws: a failure here must not take a successful sign-in down with
  /// it. Returns whether RevenueCat is now actually identified as
  /// [appUserId] — the caller needs to know, because a silent failure would
  /// otherwise be indistinguishable from a switch that worked, and the SDK
  /// would keep answering as whoever it was identified as before.
  Future<bool> logIn(String appUserId) async {
    if (appUserId.isEmpty) return false;
    await _ensureInitialized();
    if (!_isInitialized) return false;
    try {
      final result = await Purchases.logIn(appUserId);
      _logger.i(
        'RevenueCat identified as $appUserId '
        '(created: ${result.created})',
      );
      return true;
    } catch (e) {
      _logger.e('Failed to identify RevenueCat user: $e');
      return false;
    }
  }

  /// Return RevenueCat to an anonymous user, so the next person to sign in on
  /// this device does not inherit the last one's entitlements.
  ///
  /// `Purchases.logOut()` throws when the current user is already anonymous —
  /// the normal state on a fresh install, and after a failed [logIn]. That
  /// case is reported as SUCCESS, because the goal is "not identified as the
  /// previous person" and it is already met; any other failure is a real one
  /// and returns false so the caller can try again.
  Future<bool> logOut() async {
    await _ensureInitialized();
    if (!_isInitialized) return false;
    try {
      await Purchases.logOut();
      _logger.i('RevenueCat returned to an anonymous user');
      return true;
    } on PlatformException catch (e) {
      if (_isAnonymousLogOutError(e)) return true;
      _logger.e('RevenueCat log out failed: $e');
      return false;
    } catch (e) {
      _logger.e('RevenueCat log out failed: $e');
      return false;
    }
  }

  /// Whether [e] is RevenueCat's "you are already anonymous" complaint.
  ///
  /// The parse is guarded because `PurchasesErrorHelper.getErrorCode` is
  /// `num.parse(e.code).round()`, and non-numeric codes genuinely come off this
  /// channel — the Android plugin replies with the literal `invalidArgs`, and
  /// Flutter's own MethodChannel replies with `error` whenever the platform
  /// handler throws. An unguarded call would raise FormatException from inside
  /// the `on PlatformException` clause, where the sibling `catch` cannot catch
  /// it (a throw from one catch clause is not handled by later clauses of the
  /// same try), so it would escape [logOut] — whose only caller,
  /// IdentitySyncService, would then abort before invalidating the premium
  /// provider and leave the previous account's entitlement on screen.
  static bool _isAnonymousLogOutError(PlatformException e) {
    try {
      return PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.logOutWithAnonymousUserError;
    } catch (_) {
      return false;
    }
  }

  /// Check if the user has active premium entitlements.
  Future<bool> isPremiumActive() async {
    await _ensureInitialized();
    if (!_isInitialized) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return hasPremium(customerInfo.entitlements.active.keys);
    } catch (e) {
      _logger.e('Error checking premium status: $e');
      return false;
    }
  }

  /// Get current offerings.
  Future<List<Map<String, dynamic>>> getOfferings() async {
    await _ensureInitialized();
    if (!_isInitialized) return [];
    try {
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;
      if (currentOffering == null) return [];

      return currentOffering.availablePackages.map((package) {
        return {
          'identifier': package.identifier,
          'packageType': package.packageType.toString(),
          'product': {
            'identifier': package.storeProduct.identifier,
            'title': package.storeProduct.title,
            'description': package.storeProduct.description,
            'price': package.storeProduct.price,
            'priceString': package.storeProduct.priceString,
            'currencyCode': package.storeProduct.currencyCode,
          }
        };
      }).toList();
    } catch (e) {
      _logger.e('Error getting offerings: $e');
      return [];
    }
  }

  /// Purchase a package by its identifier.
  Future<Map<String, dynamic>> purchasePackage(String packageIdentifier) async {
    await _ensureInitialized();
    if (!_isInitialized) {
      return {'success': false, 'error': 'RevenueCat not initialized'};
    }
    try {
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;
      if (currentOffering == null) {
        return {'success': false, 'error': 'No current offerings found'};
      }

      Package? package;
      for (final candidate in currentOffering.availablePackages) {
        if (packageMatches(
          requested: packageIdentifier,
          packageIdentifier: candidate.identifier,
          storeProductIdentifier: candidate.storeProduct.identifier,
        )) {
          package = candidate;
          break;
        }
      }

      if (package == null) {
        // Name what WAS on offer — "not found" alone gave no way to tell a bad
        // request from a misconfigured offering.
        final offered = currentOffering.availablePackages
            .map((p) => '${p.identifier}/${p.storeProduct.identifier}')
            .join(', ');
        _logger.e('No package matched "$packageIdentifier". Offered: $offered');
        return {
          'success': false,
          'error': 'Plan "$packageIdentifier" is not available right now.',
        };
      }

      final purchaseResult =
          await Purchases.purchase(PurchaseParams.package(package));
      final customerInfo = purchaseResult.customerInfo;

      return {
        'success': hasPremium(customerInfo.entitlements.active.keys),
        'entitlements': customerInfo.entitlements.active.keys.toList(),
      };
    } catch (e) {
      _logger.e('Error purchasing package: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Restore purchases.
  Future<Map<String, dynamic>> restorePurchases() async {
    await _ensureInitialized();
    if (!_isInitialized) {
      return {'success': false, 'error': 'RevenueCat not initialized'};
    }
    try {
      final customerInfo = await Purchases.restorePurchases();

      return {
        'success': hasPremium(customerInfo.entitlements.active.keys),
        'entitlements': customerInfo.entitlements.active.keys.toList(),
      };
    } catch (e) {
      _logger.e('Error restoring purchases: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get current customer info.
  Future<Map<String, dynamic>> getCustomerInfo() async {
    await _ensureInitialized();
    if (!_isInitialized) {
      return {'success': false, 'error': 'RevenueCat not initialized'};
    }
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return {
        'success': true,
        'originalAppUserId': customerInfo.originalAppUserId,
        'entitlements': customerInfo.entitlements.all.map((key, entitlement) {
          return MapEntry(key, {
            'isActive': entitlement.isActive,
            'identifier': entitlement.identifier,
            'productIdentifier': entitlement.productIdentifier,
            'willRenew': entitlement.willRenew,
            'latestPurchaseDate': entitlement.latestPurchaseDate,
            'expirationDate': entitlement.expirationDate,
          });
        }),
      };
    } catch (e) {
      _logger.e('Error getting customer info: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
