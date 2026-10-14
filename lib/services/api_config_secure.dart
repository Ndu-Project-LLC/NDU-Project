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

  // Default model — GPT-5.6 Terra balances intelligence and cost, and is
  // OpenAI's recommended workhorse for general-purpose text generation.
  // (GPT-4o / GPT-4o mini were retired in February 2026.)
  // - $2 / MTok input, $12 / MTok output
  // - 1.05M context window
  // - Supports reasoning effort levels none/low/medium/high/xhigh/max
  static const String model = 'gpt-5.6-terra';

  /// OpenAI API version header value (not needed for OpenAI, kept for
  /// backward compatibility with code that reads this field).
  static const String openaiApiVersion = '2023-06-01';

}
