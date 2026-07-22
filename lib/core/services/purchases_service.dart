import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:logger/logger.dart';

import 'remote_config_service.dart';

final purchasesServiceProvider = Provider<PurchasesService>((ref) {
  final remoteConfig = ref.watch(remoteConfigServiceProvider);
  return PurchasesService(remoteConfig);
});

class PurchasesService {
  static final Logger _logger = Logger();
  final RemoteConfigService _remoteConfig;
  bool _isInitialized = false;

  PurchasesService(this._remoteConfig);

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final androidKey = _remoteConfig.revenueCatApiKeyAndroid;
    final iosKey = _remoteConfig.revenueCatApiKeyIOS;

    if (androidKey.isEmpty || iosKey.isEmpty) {
      _logger.w('RevenueCat API Keys are empty. Skipping initialization.');
      return;
    }

    if (androidKey.contains('placeholder') || iosKey.contains('placeholder')) {
      _logger.w('RevenueCat API Keys are placeholders. Skipping initialization in production.');
      if (kReleaseMode) return;
    }

    try {
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

  /// Check if the user has active premium entitlements.
  Future<bool> isPremiumActive() async {
    if (!_isInitialized) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      // Adjust entitlement ID to match your configuration. Default is 'premium'.
      return customerInfo.entitlements.all['premium']?.isActive ?? false;
    } catch (e) {
      _logger.e('Error checking premium status: $e');
      return false;
    }
  }

  /// Get current offerings.
  Future<List<Map<String, dynamic>>> getOfferings() async {
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
    if (!_isInitialized) {
      return {'success': false, 'error': 'RevenueCat not initialized'};
    }
    try {
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;
      if (currentOffering == null) {
        return {'success': false, 'error': 'No current offerings found'};
      }

      final package = currentOffering.availablePackages.firstWhere(
        (pkg) => pkg.identifier == packageIdentifier,
        orElse: () => throw Exception('Package $packageIdentifier not found'),
      );

      final customerInfo = await Purchases.purchasePackage(package);
      final hasPremium = customerInfo.entitlements.all['premium']?.isActive ?? false;

      return {
        'success': hasPremium,
        'entitlements': customerInfo.entitlements.all.keys.toList(),
      };
    } catch (e) {
      _logger.e('Error purchasing package: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Restore purchases.
  Future<Map<String, dynamic>> restorePurchases() async {
    if (!_isInitialized) {
      return {'success': false, 'error': 'RevenueCat not initialized'};
    }
    try {
      final customerInfo = await Purchases.restorePurchases();
      final hasPremium = customerInfo.entitlements.all['premium']?.isActive ?? false;

      return {
        'success': hasPremium,
        'entitlements': customerInfo.entitlements.all.keys.toList(),
      };
    } catch (e) {
      _logger.e('Error restoring purchases: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get current customer info.
  Future<Map<String, dynamic>> getCustomerInfo() async {
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
