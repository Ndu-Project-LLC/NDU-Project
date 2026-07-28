// =============================================================================
// NDU Project — EnvConfigLoader stub (non-web platforms)
// =============================================================================
//
// On iOS/Android/desktop there is no `window.__NDU_ENV` — runtime config is
// compiled in via firebase_options.dart and similar. This stub returns empty
// values so callers can use the same EnvConfigLoader API on every platform
// without `if (kIsWeb)` checks scattered through their code.
// =============================================================================

import 'package:flutter/foundation.dart';

/// No-op implementation used on non-web platforms.
///
/// All accessors return null/empty because runtime env-config injection via
/// `window.__NDU_ENV` is a web-only concept (it relies on a `<script>` tag
/// in index.html that runs before Flutter boots).
class EnvConfigLoader {
  EnvConfigLoader._();

  static bool _loaded = false;

  /// Reads `window.__NDU_ENV` on web; no-op on other platforms.
  /// Safe to call multiple times — only the first call does any work.
  static Future<void> load() async {
    _loaded = true;
    debugPrint('EnvConfigLoader: non-web platform, runtime env-config is empty.');
  }

  static bool get isLoaded => _loaded;

  /// OpenAI API key from `window.__NDU_ENV.OPENAI_API_KEY`.
  /// Always null on non-web. On web, null if the key was not set in
  /// env-config.js (the app then falls back to the Cloud Function proxy).
  static String? get openaiApiKey => null;

  /// Firebase web API key from `window.__NDU_ENV.FIREBASE_API_KEY`.
  /// Always null on non-web. On web, null if not overridden in env-config.js.
  static String? get firebaseApiKey => null;

  /// Build stamp from `window.__NDU_ENV.BUILD_STAMP` — written by the build
  /// pipeline (scripts/stamp_build_version.py) at `flutter build web` time.
  /// Used for cache-busting diagnostics and "what version am I running?" UI.
  static String? get buildStamp => null;

  static bool get hasOpenAiKey =>
      openaiApiKey != null && openaiApiKey!.trim().isNotEmpty;

  static bool get hasFirebaseApiKey =>
      firebaseApiKey != null && firebaseApiKey!.trim().isNotEmpty;

  static bool get hasBuildStamp =>
      buildStamp != null && buildStamp!.trim().isNotEmpty;
}
