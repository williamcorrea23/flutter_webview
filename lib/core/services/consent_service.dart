import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as google_ads;
import 'package:logger/logger.dart';

final consentServiceProvider = Provider<ConsentService>((ref) {
  return ConsentService();
});

enum ConsentStatus {
  unknown,
  required,
  notRequired,
  obtained,
}

class ConsentService {
  static final Logger _logger = Logger();

  ConsentStatus _consentStatus = ConsentStatus.unknown;
  bool _isInitialized = false;
  bool _canRequestAds = false;

  ConsentStatus get consentStatus => _consentStatus;
  bool get canRequestAds => _canRequestAds;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final information = google_ads.ConsentInformation.instance;
      final completion = Completer<void>();
      var completed = false;

      void complete() {
        if (!completed) {
          completed = true;
          completion.complete();
        }
      }

      Future<void> syncState() async {
        final status = await information.getConsentStatus();
        _consentStatus = switch (status) {
          google_ads.ConsentStatus.notRequired => ConsentStatus.notRequired,
          google_ads.ConsentStatus.obtained => ConsentStatus.obtained,
          google_ads.ConsentStatus.required => ConsentStatus.required,
          google_ads.ConsentStatus.unknown => ConsentStatus.unknown,
        };
        _canRequestAds = await information.canRequestAds();
      }

      information.requestConsentInfoUpdate(
        google_ads.ConsentRequestParameters(),
        () async {
          try {
            await google_ads.ConsentForm.loadAndShowConsentFormIfRequired(
              (error) {
                if (error != null) {
                  _logger.w('Consent form error: ${error.message}');
                }
              },
            );
            await syncState();
          } catch (error) {
            _logger.e('Failed to load consent form: $error');
            _canRequestAds = false;
          } finally {
            complete();
          }
        },
        (error) {
          _logger.e('Failed to update consent information: ${error.message}');
          _canRequestAds = false;
          complete();
        },
      );

      await completion.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _logger.w('Consent information update timed out');
          _canRequestAds = false;
        },
      );
      _isInitialized = true;
      _logger
          .i('Consent service initialized. Can request ads: $_canRequestAds');
    } catch (e) {
      _logger.e('Failed to initialize consent service: $e');
      _canRequestAds = false;
      _isInitialized = true;
    }
  }

  Future<void> resetConsent() async {
    try {
      _consentStatus = ConsentStatus.unknown;
      _canRequestAds = false;
      _isInitialized = false;

      await google_ads.ConsentInformation.instance.reset();
      await initialize();

      _logger.i('Consent reset and re-initialized');
    } catch (e) {
      _logger.e('Failed to reset consent: $e');
    }
  }

  Future<void> showPrivacyOptionsForm() async {
    try {
      await google_ads.ConsentForm.showPrivacyOptionsForm((error) async {
        if (error != null) {
          _logger.w('Privacy options form error: ${error.message}');
        }
        try {
          final information = google_ads.ConsentInformation.instance;
          _canRequestAds = await information.canRequestAds();
          final status = await information.getConsentStatus();
          _consentStatus = switch (status) {
            google_ads.ConsentStatus.notRequired => ConsentStatus.notRequired,
            google_ads.ConsentStatus.obtained => ConsentStatus.obtained,
            google_ads.ConsentStatus.required => ConsentStatus.required,
            google_ads.ConsentStatus.unknown => ConsentStatus.unknown,
          };
        } catch (refreshError) {
          _logger.e('Failed to refresh consent state: $refreshError');
        }
      });
    } catch (e) {
      _logger.e('Error showing privacy options form: $e');
    }
  }

  bool get isPersonalizedAdsAllowed {
    // Check if user has consented to personalized ads
    return _consentStatus == ConsentStatus.obtained ||
        _consentStatus == ConsentStatus.notRequired;
  }

  Map<String, String> getAdRequestExtras() {
    final extras = <String, String>{};

    // For non-personalized ads when consent is not obtained
    if (!isPersonalizedAdsAllowed) {
      extras['npa'] = '1'; // Non-personalized ads
    }

    return extras;
  }
}
