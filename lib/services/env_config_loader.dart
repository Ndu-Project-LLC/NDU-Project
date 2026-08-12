// =============================================================================
// NDU Project — Runtime Environment Config Loader (interface + stub)
// =============================================================================
//
// Reads public `window.__NDU_ENV` values populated by web/env-config.js.
// Private OpenAI credentials are never exposed through this client config.
//
// On non-web platforms (mobile/desktop), this stub returns empty values —
// those platforms use compile-time config (firebase_options.dart, etc.)
// instead. The web implementation lives in env_config_loader_web.dart and
// is selected via the conditional export below.
//
// =============================================================================

export 'env_config_loader_stub.dart'
    if (dart.library.html) 'env_config_loader_web.dart';
