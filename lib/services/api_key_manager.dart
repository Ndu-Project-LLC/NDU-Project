import 'package:flutter/foundation.dart';

/// Compatibility facade retained for screens that initialize KAZ AI.
/// OpenAI credentials are managed exclusively by the server-side proxy.
class ApiKeyManager {
  static bool _isInitialized = false;
  
  /// Initialize the API key securely
  /// Call this method once when your app starts
  static void initializeApiKey() {
    if (!_isInitialized) {
      debugPrint('ApiKeyManager initialized with server-managed credentials.');
      _isInitialized = true;
    }
  }
  
  @Deprecated('OpenAI credentials are managed by the server-side proxy.')
  static void setApiKey(String apiKey) {
    _isInitialized = true;
    debugPrint('ApiKeyManager: ignored client-side API key override.');
  }
  
  /// Check if API key is properly configured
  static bool get isConfigured => true;
  
  /// Clear the API key (for logout or security)
  static void clearApiKey() {
    debugPrint('ApiKeyManager: credentials remain managed by the server.');
  }

  static Future<void> ensureLoadedForSignedInUser() async {
    initializeApiKey();
  }

  @Deprecated('OpenAI credentials are managed by the server-side proxy.')
  static Future<void> persistForCurrentUser(String apiKey) async {
    throw UnsupportedError(
      'OpenAI credentials are managed by the server-side proxy.',
    );
  }

  static Future<void> removeForCurrentUser() async {
    clearApiKey();
  }
}
