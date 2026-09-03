import 'package:flutter_test/flutter_test.dart';
import 'package:master_abap/core/services/ad_load_diagnostics.dart';
import 'package:master_abap/core/services/remote_config_service.dart';
import 'package:master_abap/features/webview/presentation/interstitial_request_coordinator.dart';

void main() {
  test(
      'interstitial placement is only the trusted practice completion transition',
      () {
    const base = 'https://supabapnew.vercel.app';
    expect(
        isPracticeCompletionTransition(
            '$base/practice', '$base/practice/results'),
        true);
    expect(
        isPracticeCompletionTransition(
            '$base/profile', '$base/practice/results'),
        false);
    expect(
        isPracticeCompletionTransition(null, '$base/practice/results'), false);
    expect(
        isPracticeCompletionTransition(
            '$base/practice/results', '$base/practice'),
        false);
    expect(
        isPracticeCompletionTransition(
            '$base/practice', 'https://untrusted.example/practice/results'),
        false);
    expect(
        isPracticeCompletionTransition(
            'http://supabapnew.vercel.app/practice', '$base/practice/results'),
        false);
  });
  test('loading is not loaded; retries clear stale errors', () {
    final diagnostics = AdLoadDiagnostics()..begin();
    expect(diagnostics.state, 'loading');
    diagnostics.failed(3, 'com.google.android.gms.ads', 'No fill', 'response');
    expect(diagnostics.hint, contains('No fill'));
    diagnostics.begin();
    expect(diagnostics.attempts, 2);
    expect(diagnostics.errorCode, isNull);
    expect(diagnostics.responseId, isNull);
    diagnostics.loaded('success');
    expect(diagnostics.state, 'loaded');
    expect(diagnostics.completedAt, isNotNull);
  });

  test('Android codes are not applied to another error domain', () {
    final diagnostics = AdLoadDiagnostics()
      ..failed(3, 'com.google.admob', 'Other domain', null);
    expect(diagnostics.hint, isNot(contains('No fill')));
  });

  test('diagnostics redact URL, email and credential assignments', () {
    final diagnostics = AdLoadDiagnostics()
      ..failed(
          1,
          'sdk',
          'https://example.com?token=secret person@example.com token=secret',
          null);
    final report = diagnostics.snapshot().toString();
    expect(report, isNot(contains('secret')));
    expect(report, isNot(contains('person@example.com')));
    expect(diagnostics.snapshot().keys, isNot(contains('remoteConfig')));
  });

  test('uses the actual Firebase banner instead of the bundled default', () {
    final remoteKeys = {'banner_ad_id', 'ad_unit_banner'};
    expect(
        resolveRemoteAdKey('ads.banner.adUnitId.android', remoteKeys.contains),
        'banner_ad_id');
    expect(
        resolveRemoteAdKey('ads.enabled', {'show_ads'}.contains), 'show_ads');
  });

  test('explicit modern remote setting takes precedence over legacy alias', () {
    final remoteKeys = {'ads_banner_ad_unit_android', 'banner_ad_id'};
    expect(
        resolveRemoteAdKey('ads.banner.adUnitId.android', remoteKeys.contains),
        'ads_banner_ad_unit_android');
  });

  test('missing remote parameter preserves bundled defaults', () {
    expect(resolveRemoteAdKey('ads.banner.adUnitId.android', (_) => false),
        'ads.banner.adUnitId.android');
    expect(
        resolveRemoteAdKey('ads.interstitial.enabled', {'show_ads'}.contains),
        'ads.interstitial.enabled');
  });
}
