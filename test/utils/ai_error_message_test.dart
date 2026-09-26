// Tests for the aiErrorMessage helper, which converts raw AI / OpenAI proxy
// exceptions into short, human-readable messages for the UI.
//
// Regression focus: screens previously surfaced raw error.toString() dumps
// (e.g. a full OpenAI 429 JSON payload) or literally interpolated nothing,
// printing garbage like "KAZ AI failedaiErrorMessage(e)". Every failure shown
// to the user should go through this helper so it stays actionable.

import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/utils/ai_error_message.dart';

void main() {
  group('aiErrorMessage', () {
    test('maps OpenAI credit exhaustion (429 credit_balance_exhausted) to an actionable message', () {
      const raw = 'OpenAI error 429: {"error":{"message":"You have no credits '
          'remaining. Add credits to continue using the API at '
          'https://platform.openai.com/settings/organization/billing/",'
          '"type":"insufficient_quota","param":null,"code":"credit_balance_exhausted"}}';
      final message = aiErrorMessage(Exception(raw));
      expect(message, contains('AI is paused'));
      expect(message, contains('no credits remaining'));
      expect(message, contains('platform.openai.com'));
    });

    test('maps generic quota errors to the paused message', () {
      expect(aiErrorMessage(Exception('API quota exceeded. Please check your OpenAI billing.')),
          contains('AI is paused'));
      expect(aiErrorMessage(Exception('insufficient_quota')), contains('AI is paused'));
      expect(
        aiErrorMessage(Exception(
            'You exceeded your current quota, please check your plan and billing details.')),
        contains('AI is paused'));
    });

    test('maps authentication failures to a sign-in message', () {
      final message = aiErrorMessage(Exception('OpenAI API key not accepted. Please check the key.'));
      expect(message, contains('authentication failed'));
      expect(aiErrorMessage(Exception('401 Unauthorized')), contains('authentication failed'));
    });

    test('maps network / timeout failures to a setup message', () {
      expect(aiErrorMessage(Exception('Connection timed out')), contains('Please try again later'));
      expect(aiErrorMessage(Exception('Failed to fetch')), contains('Please try again later'));
      expect(aiErrorMessage(Exception('SocketException: connection refused')),
          contains('Please try again later'));
    });

    test('maps regional blocks to a region message', () {
      final message = aiErrorMessage(Exception('OpenAI error 403: unsupported_country_region_territory'));
      expect(message, contains('not available in your current region'));
    });

    test('collapses unknown errors to a single short line', () {
      final message = aiErrorMessage(Exception('Some very verbose model failure\nwith\nnewlines that should be collapsed onto one line for the toast'));
      expect(message.split('\n').length, 1);
      expect(message.length, lessThanOrEqualTo(200));
    });

    test('never emits the raw helper name (regression for mangled strings)', () {
      // Screens used to display text like 'KAZ AI failedaiErrorMessage(e)' —
      // the literal function name instead of the actual message.
      for (final raw in <String>[
        'KAZ AI failed: ${aiErrorMessage(Exception('boom'))}',
        aiErrorMessage(Exception('boom')),
      ]) {
        expect(raw.contains('aiErrorMessage('), isFalse,
            reason: 'should contain the resolved message, not a raw call: $raw');
      }
    });
  });
}
