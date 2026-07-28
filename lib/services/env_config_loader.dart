// =============================================================================
// NDU Project — Runtime Environment Config Loader (interface + stub)
// =============================================================================
//
// Reads `window.__NDU_ENV` (populated by web/env-config.js) so that API keys
// and other runtime configuration can be supplied at DEPLOY time without
// recompiling main.dart.js. This keeps secrets out of the compiled bundle.
//
// On non-web platforms (mobile/desktop), this stub returns empty values —
// those platforms use compile-time config (firebase_options.dart, etc.)
// instead. The web implementation lives in env_config_loader_web.dart and
// is selected via the conditional export below.
//
// Usage (see main.dart):
//   await EnvConfigLoader.load();
//   if (EnvConfigLoader.hasOpenAiKey) {
//     ApiKeyManager.setApiKey(EnvConfigLoader.openaiApiKey!);
//   }
// =============================================================================

export 'env_config_loader_stub.dart'
    if (dart.library.html) 'env_config_loader_web.dart';
