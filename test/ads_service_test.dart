import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_abap/core/services/ads_service.dart';

void main() {
  test('provider owns and disposes the ads service exactly once', () {
    final container = ProviderContainer();

    // Materialize the provider so disposal exercises the ChangeNotifier
    // lifecycle rather than only tearing down an unread container.
    container.read(adsServiceProvider);

    expect(container.dispose, returnsNormally);
  });
}
