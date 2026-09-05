import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// Match the codec used by the native UMP channel.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';
import 'package:master_abap/core/services/consent_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = MethodChannel('plugins.flutter.io/google_mobile_ads/ump',
      StandardMethodCodec(UserMessagingCodec()));
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets('consent accepted after startup timeout notifies observers',
      (tester) async {
    final form = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'UserMessagingPlatform#loadAndShowConsentFormIfRequired':
          await form.future;
          return null;
        case 'ConsentInformation#getConsentStatus':
          return 3;
        case 'ConsentInformation#canRequestAds':
          return true;
        default:
          return null;
      }
    });
    final service = ConsentService();
    addTearDown(service.dispose);
    var notifications = 0;
    service.addListener(() => notifications++);
    final initialization = service.initialize();
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    await initialization;
    expect(service.canRequestAds, false);
    form.complete();
    await tester.pump();
    expect(service.canRequestAds, true);
    expect(notifications, greaterThan(0));
  });

  test('update failure preserves consent authorized by UMP', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'ConsentInformation#requestConsentInfoUpdate':
          throw PlatformException(code: '1', message: 'Offline');
        case 'ConsentInformation#getConsentStatus':
          return 3;
        case 'ConsentInformation#canRequestAds':
          return true;
        default:
          return null;
      }
    });
    final service = ConsentService();
    addTearDown(service.dispose);
    await service.initialize();
    expect(service.canRequestAds, true);
  });
}
