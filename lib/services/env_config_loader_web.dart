// =============================================================================
// NDU Project — EnvConfigLoader (Flutter web implementation)
// =============================================================================
//
// Reads `window.__NDU_ENV` (populated by web/env-config.js, which is loaded
// by index.html BEFORE Flutter boots). Uses dart:js_interop for the modern,
// sound-interop approach that works with both dart2js and dart2wasm.
//
// The shape of `window.__NDU_ENV` is:
//   {
//     "OPENAI_API_KEY": String,   // optional
//     "FIREBASE_API_KEY": String,    // optional
//     "BUILD_STAMP": String          // set by build pipeline
//   }
//
// See web/env-config.js for the canonical documentation of each field.
// =============================================================================

import 'dart:js_interop';

import 'package:flutter/foundation.dart';

/// JS bindings for the `window.__NDU_ENV` object injected by env-config.js.
@JS('__NDU_ENV')
external NduEnv? get _nduEnv;

@JS()
@staticInterop
class NduEnv {}

extension NduEnvExt on NduEnv {
  external String? get OPENAI_API_KEY;
  external String? get FIREBASE_API_KEY;
  external String? get BUILD_STAMP;
}

/// Reads `window.__NDU_ENV` on web. Safe to call on any platform — on non-web
/// the import resolves to env_config_loader_stub.dart which returns nulls.
class EnvConfigLoader {
  EnvConfigLoader._();

  static bool _loaded = false;
  static String? _openaiApiKey;
  static String? _firebaseApiKey;
  static String? _buildStamp;

  /// Reads `window.__NDU_ENV` and caches the values. Idempotent — calling
  /// multiple times is safe; only the first call reads from JS.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      final env = _nduEnv;
      if (env != null) {
        _openaiApiKey = _readString(env.OPENAI_API_KEY);
        _firebaseApiKey = _readString(env.FIREBASE_API_KEY);
        _buildStamp = _readString(env.BUILD_STAMP);
      }
      debugPrint(
        'EnvConfigLoader: loaded __NDU_ENV '
        '(openai=${_mask(_openaiApiKey)}, '
        'firebase=${_mask(_firebaseApiKey)}, '
        'build=${_buildStamp ?? "none"})',
      );
    } catch (e, st) {
      // Never let env-config loading crash app startup — the app has safe
      // fallbacks (Cloud Function proxy for OpenAI, compiled Firebase
      // options for Firebase).
      debugPrint('EnvConfigLoader: failed to read __NDU_ENV — $e\n$st');
    } finally {
      _loaded = true;
    }
  }

  static bool get isLoaded => _loaded;

  static String? get openaiApiKey => _openaiApiKey;
  static String? get firebaseApiKey => _firebaseApiKey;
  static String? get buildStamp => _buildStamp;

  static bool get hasOpenAiKey =>
      _openaiApiKey != null && _openaiApiKey!.trim().isNotEmpty;

  static bool get hasFirebaseApiKey =>
      _firebaseApiKey != null && _firebaseApiKey!.trim().isNotEmpty;

  static bool get hasBuildStamp =>
      _buildStamp != null && _buildStamp!.trim().isNotEmpty;

  /// Converts a nullable JS String to a Dart String, treating empty strings
  /// as null so downstream `hasXxx` checks work intuitively.
  static String? _readString(String? jsValue) {
    if (jsValue == null) return null;
    final trimmed = jsValue.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Masks a key for debug logging — shows first 4 + last 4 chars only.
  static String _mask(String? key) {
    if (key == null || key.isEmpty) return 'none';
    if (key.length <= 8) return '***';
    return '${key.substring(0, 4)}…${key.substring(key.length - 4)}';
  }
}
