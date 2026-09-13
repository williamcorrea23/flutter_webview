import '../domain/navigation_policy.dart';

/// Only a completed practice-session transition, never tab browsing or launch.
bool isPracticeCompletionTransition(String? previous, String current) {
  final before = Uri.tryParse(previous ?? '');
  final after = Uri.tryParse(current);
  if (before == null || after == null) return false;

  bool trusted(Uri uri) =>
      uri.scheme.toLowerCase() == 'https' &&
      NavigationPolicy.isAllowedDomain(uri.host);

  if (!trusted(before) || !trusted(after)) return false;

  final beforePath = before.path.endsWith('/') && before.path.length > 1
      ? before.path.substring(0, before.path.length - 1)
      : before.path;
  final afterPath = after.path.endsWith('/') && after.path.length > 1
      ? after.path.substring(0, after.path.length - 1)
      : after.path;

  return beforePath == '/practice' && afterPath == '/practice/results';
}

/// Coordinates action-triggered interstitial requests so only one consent and
/// display flow can be active at a time.
class InterstitialRequestCoordinator {
  Future<bool>? _activeRequest;

  bool get isActive => _activeRequest != null;

  Future<bool> run({
    required bool Function() canShow,
    required Future<bool> Function() requestConsent,
    required Future<bool> Function() showAd,
  }) {
    final activeRequest = _activeRequest;
    if (activeRequest != null) return activeRequest;

    late final Future<bool> request;
    request = _run(
      canShow: canShow,
      requestConsent: requestConsent,
      showAd: showAd,
    ).whenComplete(() {
      if (identical(_activeRequest, request)) {
        _activeRequest = null;
      }
    });
    _activeRequest = request;
    return request;
  }

  Future<bool> _run({
    required bool Function() canShow,
    required Future<bool> Function() requestConsent,
    required Future<bool> Function() showAd,
  }) async {
    if (!canShow()) return false;
    if (!await requestConsent()) return false;

    // Readiness and widget/provider lifecycle can change while the dialog is
    // open, so consent never bypasses a fresh eligibility check.
    if (!canShow()) return false;
    return showAd();
  }
}
