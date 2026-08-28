// =============================================================================
// NDU Project — Runtime Environment Configuration
// =============================================================================
//
// This file is loaded by index.html BEFORE Flutter boots, so the values below
// are available to Dart via `window.__NDU_ENV` (see lib/services/env_config_loader.dart).
//
// WHY THIS EXISTS
// ---------------
// Runtime values here are visible to anyone who opens browser devtools. Only
// public client configuration belongs in this file. OpenAI credentials are
// stored exclusively in Firebase Secret Manager for the server-side proxy.
//
// DEPLOYMENT
// ----------
// 1. Copy this file to your deployment target alongside index.html.
// 2. Fill in the values below for your environment.
// 3. Serve. The Dart side (EnvConfigLoader) picks them up on app start.
//
// SECURITY NOTES
// --------------
// • Any value in this file IS visible to end users. Only put keys here that
//   are safe to expose (e.g. Firebase web API keys, which are public by
//   design). NEVER put a raw OpenAI key here in production — use the
//   Cloud Function proxy instead.
// • Never put OpenAI or other private server credentials in this file.
// =============================================================================

window.__NDU_ENV = window.__NDU_ENV || {};

// Firebase web API key — OPTIONAL. Leave empty to use the value compiled into
// firebase_options.dart. Only set this if you need to override at runtime
// (e.g. multi-tenant deployments pointing at different Firebase projects).
window.__NDU_ENV.FIREBASE_API_KEY = '';

// Deployment build stamp — used by the cache-busting logic in index.html.
// The build pipeline (scripts/stamp_build_version.py) overwrites this with
// the current epoch seconds on every `flutter build web`.
window.__NDU_ENV.BUILD_STAMP = '1787934696';
