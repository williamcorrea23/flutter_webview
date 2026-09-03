/// In-memory, allowlisted diagnostics. Never includes Remote Config dumps,
/// request extras, account identifiers, or arbitrary exception payloads.
class AdLoadDiagnostics {
  String state = 'not_requested';
  int attempts = 0;
  DateTime? requestedAt;
  DateTime? completedAt;
  int? errorCode;
  String? errorDomain;
  String? errorMessage;
  String? responseId;

  void begin() {
    state = 'loading';
    attempts++;
    requestedAt = DateTime.now().toUtc();
    completedAt = null;
    errorCode = null;
    errorDomain = null;
    errorMessage = null;
    responseId = null;
  }

  void loaded(String? id) {
    state = 'loaded';
    completedAt = DateTime.now().toUtc();
    errorCode = null;
    errorDomain = null;
    errorMessage = null;
    responseId = id;
  }

  void failed(int code, String domain, String message, String? id) {
    state = 'failed';
    completedAt = DateTime.now().toUtc();
    errorCode = code;
    errorDomain = safeText(domain);
    errorMessage = safeText(message);
    responseId = id == null ? null : safeText(id);
  }

  static String safeText(String text) {
    final redacted = text
        .replaceAll(RegExp(r'https?://\S+'), '[URL redacted]')
        .replaceAll(RegExp(r'[\w.+-]+@[\w.-]+'), '[email redacted]')
        .replaceAll(
            RegExp(r'(token|key|password|authorization)\s*[:=]\s*\S+',
                caseSensitive: false),
            '[credential redacted]');
    return redacted.length > 400 ? '${redacted.substring(0, 400)}…' : redacted;
  }

  String get hint {
    if (state != 'failed') return state;
    if (errorDomain != 'com.google.android.gms.ads') {
      return 'Inspect the SDK error domain and message; codes vary by SDK.';
    }
    return switch (errorCode) {
      0 => 'SDK/internal error. Compare with a Google test ad and retry later.',
      1 => 'Invalid request. Check the AdMob app, ad unit and ad format.',
      2 => 'Network error. Check connectivity, private DNS, VPN or filtering.',
      3 => 'No fill. Check AdMob readiness, serving limits and ad inventory.',
      _ => 'Inspect the SDK error message and AdMob console.',
    };
  }

  Map<String, Object?> snapshot() => {
        'state': state,
        'attempts': attempts,
        'requestedAtUtc': requestedAt?.toIso8601String(),
        'completedAtUtc': completedAt?.toIso8601String(),
        'errorCode': errorCode,
        'errorDomain': errorDomain,
        'errorMessage': errorMessage,
        'responseId': responseId,
        'hint': hint,
      };
}
