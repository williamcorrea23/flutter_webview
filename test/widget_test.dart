import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:usman_sanda_palace/features/webview/presentation/widgets/offline_page_widget.dart';

void main() {
  testWidgets('offline page exposes a working retry action', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OfflinePageWidget(onRetry: () => retried = true),
      ),
    );

    expect(find.text("You're Offline"), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    expect(retried, isTrue);
  });
}
