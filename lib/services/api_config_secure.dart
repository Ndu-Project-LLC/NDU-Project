/// Central, non-secret OpenAI proxy configuration.
class SecureAPIConfig {
  SecureAPIConfig._();

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

}
