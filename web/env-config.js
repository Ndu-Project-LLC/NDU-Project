// =============================================================================
// NDU Project — Runtime Environment Configuration
// =============================================================================
//
// This file is loaded by index.html BEFORE Flutter boots, so the values below
// are available to Dart via `window.__NDU_ENV` (see lib/services/env_config_loader.dart).
//
// WHY THIS EXISTS
// ---------------
// Hardcoding API keys in Dart source means they end up inside main.dart.js
// after compilation — visible to anyone who opens browser devtools. To keep
// secrets out of the compiled bundle, we ship an EMPTY template here and
// populate it at deploy time (CI/CD pipeline, deploy script, or manual edit
// on the hosting provider).
//
// DEPLOYMENT
// ----------
// 1. Copy this file to your deployment target alongside index.html.
// 2. Fill in the values below for your environment.
// 3. Serve. The Dart side (EnvConfigLoader) picks them up on app start.
//
// FALLBACK
// --------
// If OPENAI_API_KEY is left empty (""), the app uses the Cloud Function
// proxy at SecureAPIConfig.baseUrl (server-side key, never exposed to the
// client). This is the default and recommended mode for production.
//
// SECURITY NOTES
// --------------
// • Any value in this file IS visible to end users. Only put keys here that
//   are safe to expose (e.g. Firebase web API keys, which are public by
//   design). NEVER put a raw OpenAI key here in production — use the
//   Cloud Function proxy instead.
// • For local development, populate this file with your own dev keys and
//   add it to .gitignore so you don't commit personal keys.
// =============================================================================

window.__NDU_ENV = window.__NDU_ENV || {};

// OpenAI API key — OPTIONAL. Leave empty to use the Cloud Function proxy
// (recommended for production so the key stays server-side).
window.__NDU_ENV.OPENAI_API_KEY = '';

// Firebase web API key — OPTIONAL. Leave empty to use the value compiled into
// firebase_options.dart. Only set this if you need to override at runtime
// (e.g. multi-tenant deployments pointing at different Firebase projects).
window.__NDU_ENV.FIREBASE_API_KEY = '';

// Deployment build stamp — used by the cache-busting logic in index.html.
// The build pipeline (scripts/stamp_build_version.py) overwrites this with
// the current epoch seconds on every `flutter build web`.
window.__NDU_ENV.BUILD_STAMP = 'NDU_BUILD_STAMP';
