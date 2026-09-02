import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:master_abap/core/config/app_config.dart';
import 'package:master_abap/shared/constants/app_constants.dart';

void main() {
  final metadata = <String, String>{
    for (final line
        in File('android/play-release.properties').readAsLinesSync())
      if (line.isNotEmpty && !line.startsWith('#'))
        line.substring(0, line.indexOf('=')):
            line.substring(line.indexOf('=') + 1),
  };

  test('native product identity matches the existing Master ABAP listing', () {
    expect(AppConstants.appName, 'Master ABAP');
    expect(AppConstants.appTitle, AppConstants.appName);
    expect(AppConfig.appName, AppConstants.appName);
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:label="${AppConstants.appName}"'));
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(metadata['applicationId'], 'co.supabap.android');
    expect(gradle, contains('applicationId = "${metadata['applicationId']}"'));
    expect(gradle, contains('namespace = "${metadata['applicationId']}"'));
  });

  test('versionCode is newer than the recorded Play baseline', () {
    final version =
        RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', multiLine: true)
            .firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(version, isNotNull);
    expect(int.parse(metadata['minimumVersionCode']!), greaterThan(20));
    expect(int.parse(version!.group(2)!),
        greaterThanOrEqualTo(int.parse(metadata['minimumVersionCode']!)));
  });

  test('upload key is pinned separately from the Google distribution key', () {
    expect(metadata['uploadCertificateSha256'],
        'FA:0C:F6:AD:3C:0A:2A:A7:47:5E:17:C7:02:B7:15:35:B9:EC:BA:42:47:C4:97:95:A1:A5:FF:04:58:32:F5:B7');
    expect(metadata['appSigningCertificateSha256'],
        'CD:F9:FE:77:74:2E:C3:89:DD:C0:A0:7D:DB:B5:28:FE:26:18:C1:DE:E9:4C:14:70:A9:DC:D8:4F:F3:3E:03:E2');
    expect(metadata['uploadCertificateSha256'],
        isNot(metadata['appSigningCertificateSha256']));
  });

  test('local and CI Firebase files target the published Android package', () {
    for (final path in [
      'google-services.json',
      'android/app/google-services.json'
    ]) {
      final config =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      expect(config['project_info']['project_id'], 'abap-aed31');
      final clients = config['client'] as List<dynamic>;
      final matching = clients.where((dynamic client) =>
          client['client_info']['android_client_info']['package_name'] ==
          metadata['applicationId']);
      expect(matching, hasLength(1));
      expect(matching.single['client_info']['mobilesdk_app_id'],
          '1:838743198796:android:2cfa3b92d3c0241eb6b8e9');
    }
  });

  test('local and CI Firebase configurations remain identical', () {
    expect(
      jsonDecode(File('google-services.json').readAsStringSync()),
      jsonDecode(File('android/app/google-services.json').readAsStringSync()),
    );
  });

  test('Google sign-in includes both Play signers and the existing web client',
      () {
    final config =
        jsonDecode(File('android/app/google-services.json').readAsStringSync());
    final client = (config['client'] as List<dynamic>).singleWhere(
        (dynamic client) =>
            client['client_info']['android_client_info']['package_name'] ==
            metadata['applicationId']);
    final oauthClients = client['oauth_client'] as List<dynamic>;
    final androidClients = oauthClients.where((dynamic oauth) =>
        oauth['client_type'] == 1 &&
        oauth['android_info']['package_name'] == metadata['applicationId']);
    final hashes = androidClients
        .map((dynamic oauth) => oauth['android_info']['certificate_hash']);
    expect(
      hashes,
      contains(metadata['appSigningCertificateSha1']!
          .replaceAll(':', '')
          .toLowerCase()),
    );
    expect(hashes, contains('4795467dc71ff5adfa86a268c6d0c20d4284e1a4'));
    expect(
      hashes,
      contains(metadata['upgradedAppSigningCertificateSha1']!
          .replaceAll(':', '')
          .toLowerCase()),
    );
    expect(
      oauthClients
          .where((dynamic oauth) => oauth['client_type'] == 3)
          .map((dynamic oauth) => oauth['client_id']),
      contains(
          '838743198796-epopl0djnq4f1haj4folka4gjnma7m2b.apps.googleusercontent.com'),
    );
  });
}
