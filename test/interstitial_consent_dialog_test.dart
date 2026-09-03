import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_abap/features/webview/presentation/widgets/interstitial_consent_dialog.dart';

void main() {
  testWidgets('declining the optional ad returns false', (tester) async {
    Future<bool>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              result = InterstitialConsentDialog.show(context);
            },
            child: const Text('Open dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Optional ad'), findsOneWidget);
    expect(
      find.text(
        'A full-screen advertisement may appear between practice sessions. '
        'You can continue without it.',
      ),
      findsOneWidget,
    );
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(await result, isFalse);
  });

  testWidgets('accepting the optional ad returns true', (tester) async {
    Future<bool>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              result = InterstitialConsentDialog.show(context);
            },
            child: const Text('Open dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(await result, isTrue);
  });
}
