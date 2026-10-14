import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/openai/openai_config.dart';

void main() {
  test('classifies the real OpenAI credit-balance 429 as credits exhausted',
      () {
    const body = '{"error":{"message":"You have no credits remaining. Add '
        'credits to continue using the API at '
        'https://platform.openai.com/settings/organization/billing/.",'
        '"type":"insufficient_quota","param":null,'
        '"code":"credit_balance_exhausted"}}';
    expect(isOpenAiCreditsExhausted(429, body), isTrue);
  });

  test('classifies insufficient_quota 402 as credits exhausted', () {
    expect(
      isOpenAiCreditsExhausted(
          402, '{"error":{"type":"insufficient_quota"}}'),
      isTrue,
    );
  });

  test('treats a transient rate limit as NOT credits exhausted', () {
    expect(
      isOpenAiCreditsExhausted(
          429, '{"error":"Rate limit exceeded","message":"Too many requests"}'),
      isFalse,
    );
  });

  test('ignores non-429/402 statuses', () {
    expect(isOpenAiCreditsExhausted(500, 'credit_balance_exhausted'), isFalse);
    expect(isOpenAiCreditsExhausted(200, ''), isFalse);
  });
}
