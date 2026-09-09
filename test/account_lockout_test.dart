import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/services/security_services.dart';

void main() {
  setUp(() {
    // Fresh in-memory prefs for every test — the lockout state is device-local
    // SharedPreferences, so this fully isolates the tests from each other.
    SharedPreferences.setMockInitialValues({});
  });

  group('isCredentialErrorCode', () {
    test('classifies wrong-password failures as credential errors', () {
      expect(AccountLockoutService.isCredentialErrorCode('wrong-password'),
          isTrue);
    });

    test('classifies invalid-credential failures as credential errors', () {
      expect(AccountLockoutService.isCredentialErrorCode('invalid-credential'),
          isTrue);
    });

    test('classifies user-not-found failures as credential errors', () {
      expect(AccountLockoutService.isCredentialErrorCode('user-not-found'),
          isTrue);
    });

    test('does NOT classify infrastructure/config errors as credential errors',
        () {
      expect(
          AccountLockoutService.isCredentialErrorCode('network-request-failed'),
          isFalse);
      expect(AccountLockoutService.isCredentialErrorCode('operation-not-allowed'),
          isFalse);
      expect(AccountLockoutService.isCredentialErrorCode('too-many-requests'),
          isFalse);
      expect(AccountLockoutService.isCredentialErrorCode('popup-blocked'),
          isFalse);
      expect(
          AccountLockoutService.isCredentialErrorCode('unauthorized-domain'),
          isFalse);
      expect(AccountLockoutService.isCredentialErrorCode('user-disabled'),
          isFalse);
      expect(AccountLockoutService.isCredentialErrorCode('internal-error'),
          isFalse);
    });

    test('handles null and unknown codes safely', () {
      expect(AccountLockoutService.isCredentialErrorCode(null), isFalse);
      expect(AccountLockoutService.isCredentialErrorCode(''), isFalse);
      expect(
          AccountLockoutService.isCredentialErrorCode('some-unknown-code'),
          isFalse);
    });
  });

  group('recordFailedAttemptForCode', () {
    test('non-credential errors are NOT recorded and never lock the account',
        () async {
      for (final code in [
        'network-request-failed',
        'operation-not-allowed',
        'too-many-requests',
        'popup-blocked',
        'unauthorized-domain',
        null,
      ]) {
        final locked =
            await AccountLockoutService.recordFailedAttemptForCode(code);
        expect(locked, isFalse,
            reason: 'code "$code" must not trigger lockout');
      }

      // Counter untouched by any of the above.
      expect(await AccountLockoutService.getAttemptCount(), 0);
      expect(await AccountLockoutService.isLocked(), isFalse);
    });

    test('credential errors increment the counter but do not lock immediately',
        () async {
      final locked = await AccountLockoutService.recordFailedAttemptForCode(
          'wrong-password');

      expect(locked, isFalse);
      expect(await AccountLockoutService.getAttemptCount(), 1);
      expect(await AccountLockoutService.isLocked(), isFalse);
    });

    test('locks the account on the max-th credential error', () async {
      final maxAttempts = AccountLockoutService.maxAttempts;

      bool locked = false;
      for (var i = 0; i < maxAttempts; i++) {
        locked = await AccountLockoutService.recordFailedAttemptForCode(
            'invalid-credential');
        if (i < maxAttempts - 1) {
          expect(locked, isFalse, reason: 'attempt ${i + 1} must not lock');
        }
      }
      expect(locked, isTrue, reason: 'the 5th credential failure must lock');
      expect(await AccountLockoutService.isLocked(), isTrue);
    });

    test('mixed failures: network outages do not push the user to lockout',
        () async {
      // Simulate a flaky environment: infra failures interleaved with one
      // genuine typo. Only the typo should count.
      await AccountLockoutService.recordFailedAttemptForCode(
          'network-request-failed');
      await AccountLockoutService.recordFailedAttemptForCode('wrong-password');
      await AccountLockoutService.recordFailedAttemptForCode(null);
      await AccountLockoutService.recordFailedAttemptForCode('popup-blocked');
      await AccountLockoutService.recordFailedAttemptForCode('internal-error');

      expect(await AccountLockoutService.getAttemptCount(), 1);

      // Even many infra failures in a row stay harmless.
      for (var i = 0; i < 10; i++) {
        await AccountLockoutService.recordFailedAttemptForCode(
            'network-request-failed');
      }
      expect(await AccountLockoutService.getAttemptCount(), 1);
      expect(await AccountLockoutService.isLocked(), isFalse);
    });

    test('remaining attempts message math stays consistent', () async {
      await AccountLockoutService.recordFailedAttemptForCode(
          'invalid-credential');
      final attempts = await AccountLockoutService.getAttemptCount();
      final remaining = AccountLockoutService.maxAttempts - attempts;
      expect(remaining, AccountLockoutService.maxAttempts - 1);
    });
  });

  group('lockout lifecycle', () {
    test('getRemainingLockout returns positive duration while locked', () async {
      for (var i = 0; i < AccountLockoutService.maxAttempts; i++) {
        await AccountLockoutService.recordFailedAttempt();
      }
      final remaining = await AccountLockoutService.getRemainingLockout();
      expect(remaining, isNotNull);
      expect(remaining!.inMinutes, greaterThanOrEqualTo(14));
      expect(remaining.inMinutes, lessThanOrEqualTo(15));
    });

    test('resetAttempts clears counter and lockout', () async {
      for (var i = 0; i < AccountLockoutService.maxAttempts; i++) {
        await AccountLockoutService.recordFailedAttempt();
      }
      expect(await AccountLockoutService.isLocked(), isTrue);

      await AccountLockoutService.resetAttempts();

      expect(await AccountLockoutService.getAttemptCount(), 0);
      expect(await AccountLockoutService.isLocked(), isFalse);
      expect(await AccountLockoutService.getRemainingLockout(), isNull);
    });

    test('successful sign-in resets the counter (resetAttempts after failures)',
        () async {
      await AccountLockoutService.recordFailedAttemptForCode('wrong-password');
      await AccountLockoutService.recordFailedAttemptForCode('wrong-password');

      // Successful login path calls resetAttempts().
      await AccountLockoutService.resetAttempts();

      // Next single typo should show "4 remaining", not "3".
      await AccountLockoutService.recordFailedAttemptForCode('wrong-password');
      expect(await AccountLockoutService.getAttemptCount(), 1);
      expect(await AccountLockoutService.isLocked(), isFalse);
    });
  });
}
