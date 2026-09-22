import 'package:flutter_test/flutter_test.dart';
import 'package:master_abap/core/services/usage_time_tracker.dart';

void main() {
  var now = Duration.zero;
  UsageTimeTracker tracker() => UsageTimeTracker(monotonicNow: () => now);

  setUp(() => now = Duration.zero);

  test('counts only foreground time', () {
    final usage = tracker()..setForeground(true);
    now = const Duration(seconds: 40);
    usage.setForeground(false);
    now = const Duration(hours: 2);
    expect(usage.elapsed, const Duration(seconds: 40));
    usage.setForeground(true);
    now += const Duration(seconds: 20);
    expect(usage.elapsed, const Duration(seconds: 60));
  });

  test('repeated lifecycle events do not double count or restart', () {
    final usage = tracker()..setForeground(true);
    now = const Duration(seconds: 30);
    usage.setForeground(true);
    now = const Duration(seconds: 50);
    usage
      ..setForeground(false)
      ..setForeground(false);
    expect(usage.elapsed, const Duration(seconds: 50));
  });

  test('reset starts a new window from the current moment', () {
    final usage = tracker()..setForeground(true);
    now = const Duration(minutes: 5);
    usage.reset();
    expect(usage.elapsed, Duration.zero);
    now += const Duration(seconds: 15);
    expect(usage.elapsed, const Duration(seconds: 15));

    usage
      ..setForeground(false)
      ..reset();
    now += const Duration(minutes: 10);
    expect(usage.elapsed, Duration.zero);
  });
}
