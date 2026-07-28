import 'package:flutter/foundation.dart';

/// Runtime OpenAI configuration that avoids hardcoding secrets in source.
/// ApiKeyManager sets and clears the key at runtime; callers read via [apiKey].
class SecureAPIConfig {
  SecureAPIConfig._();

  static String? _apiKey;

  // OpenAI API key — loaded at runtime via ApiKeyManager or environment
  // variable. Do NOT hardcode API keys in source code (GitHub secret
  // scanning will block pushes).
  // Set via: flutter build web --dart-define=OPENAI_API_KEY=sk-...
  static const String _envApiKey = String.fromEnvironment('OPENAI_API_KEY');

  // OpenAI API base URL.
  //
  // In production we use the Firebase Cloud Function proxy (openaiProxy)
  // so the OpenAI API key stays server-side and is never exposed to the
  // client. The proxy forwards OpenAI-format requests directly to
  // api.openai.com with the server-side key.
  //
  // The Cloud Function is deployed at:
  //   https://us-central1-ndu-d3f60.cloudfunctions.net/openaiProxy
  static const String baseUrl =
      'https://us-central1-ndu-d3f60.cloudfunctions.net/openaiProxy';

  // Default model — GPT-4o is OpenAI's smartest model with the best
  // reasoning capabilities. It balances cost and performance excellently:
  // - 2x better reasoning than GPT-4 Turbo
  // - 50% cheaper than GPT-4 Turbo
  // - Supports 128K context window
  // - Multilingual, vision-capable, fast response times
  static const String model = 'gpt-4o';

  /// OpenAI API version header value (not needed for OpenAI, kept for
  /// backward compatibility with code that reads this field).
  static const String openaiApiVersion = '2023-06-01';

  static String? get apiKey => _apiKey ?? (_envApiKey.isEmpty ? null : _envApiKey);
  static bool get hasApiKey => (_apiKey ?? _envApiKey).trim().isNotEmpty == true;

  static void setApiKey(String apiKey) {
    _apiKey = apiKey.trim().isEmpty ? null : apiKey.trim();
    debugPrint('SecureAPIConfig: runtime API key set.');
  }

  static void clearApiKey() {
    _apiKey = null;
    debugPrint('SecureAPIConfig: runtime API key cleared.');
  }
}
