/// Accumulates how long the app has been in the foreground.
///
/// Reads a monotonic clock rather than [DateTime.now]: a wall-clock jump (the
/// user changing the time, an NTP correction) must not grant or erase usage.
class UsageTimeTracker {
  UsageTimeTracker({Duration Function()? monotonicNow})
      : _now = monotonicNow ?? _processElapsed;

  static final Stopwatch _processClock = Stopwatch()..start();
  static Duration _processElapsed() => _processClock.elapsed;

  final Duration Function() _now;
  Duration _accumulated = Duration.zero;
  Duration? _foregroundSince;

  bool get isForeground => _foregroundSince != null;

  Duration get elapsed {
    final since = _foregroundSince;
    return since == null ? _accumulated : _accumulated + (_now() - since);
  }

  void setForeground(bool foreground) {
    if (foreground) {
      _foregroundSince ??= _now();
      return;
    }
    final since = _foregroundSince;
    if (since == null) return;
    _accumulated += _now() - since;
    _foregroundSince = null;
  }

  void reset() {
    _accumulated = Duration.zero;
    if (_foregroundSince != null) _foregroundSince = _now();
  }
}
