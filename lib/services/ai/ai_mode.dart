/// AI execution mode.
///
/// The app can run its AI surfaces in two modes:
///
///   * [AiMode.live]  — every AI call goes to the server-side proxy
///     (Firebase `openaiProxy` → self-hosted LLM → OpenAI). This is the
///     production behaviour.
///   * [AiMode.local] — **no network AI at all**. Every AI surface is served
///     by [LocalAiEngine], a deterministic, code-level content generator that
///     produces the same shape of output the model would return. This makes
///     the app fully usable for demos, offline work, CI/E2E runs, and cost-free
///     operation.
///
/// Select the mode at build/run time:
///
///   flutter build web --dart-define=AI_MODE=local
///   flutter run --dart-define=AI_MODE=local
///
/// `live` is the default, so nothing changes unless the flag is passed.
library;

class AiMode {
  AiMode._();

  /// Raw value of the `AI_MODE` dart-define. Accepts `live` (default),
  /// `local`, `no-ai`, `offline` (the last three all mean local generation).
  static const String _raw =
      String.fromEnvironment('AI_MODE', defaultValue: 'live');

  static bool? _override;

  /// Test/demo hook: force local generation on or off at runtime.
  /// Pass `null` to fall back to the compile-time flag.
  static set override(bool? value) => _override = value;

  /// True when AI requests must be answered by [LocalAiEngine] instead of a
  /// remote provider.
  static bool get isLocal {
    if (_override != null) return _override!;
    final value = _raw.trim().toLowerCase();
    return value == 'local' || value == 'no-ai' || value == 'offline';
  }

  /// Human-readable label for diagnostics and UI badges.
  static String get label => isLocal ? 'Local generation' : 'Live AI';
}
