// Tests for the safe_string utility helpers.
//
// These helpers exist to prevent RangeError crashes from substring calls
// that receive -1 (or other out-of-range values) as the end argument.

import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/utils/safe_string.dart';

void main() {
  group('safeSubstring', () {
    test('returns the full substring for valid args', () {
      expect(safeSubstring('hello', 0, 3), 'hel');
      expect(safeSubstring('hello', 2, 4), 'll');
      expect(safeSubstring('hello', 1, 5), 'ello');
    });

    test('returns the rest when end is null', () {
      expect(safeSubstring('hello', 2), 'llo');
      expect(safeSubstring('hello', 0), 'hello');
      expect(safeSubstring('hello', 5), '');
    });

    test('returns empty string when end is -1 (the production bug)', () {
      // This is the exact pattern that caused the staging crash:
      // RangeError (end): Invalid value: Not in inclusive range 0..N: -1
      expect(safeSubstring('hello', 0, -1), '');
      expect(safeSubstring('a' * 80, 0, -1), '');
      expect(safeSubstring('a' * 117, 0, -1), '');
    });

    test('clamps end to length', () {
      expect(safeSubstring('hello', 0, 100), 'hello');
      expect(safeSubstring('hello', 2, 100), 'llo');
    });

    test('clamps start to 0', () {
      expect(safeSubstring('hello', -5, 3), 'hel');
      expect(safeSubstring('hello', -1, 0), '');
    });

    test('clamps start to length', () {
      expect(safeSubstring('hello', 100), '');
      expect(safeSubstring('hello', 100, 200), '');
    });

    test('returns empty string when start > end', () {
      expect(safeSubstring('hello', 4, 2), '');
      expect(safeSubstring('hello', 3, 0), '');
    });

    test('handles empty input string', () {
      expect(safeSubstring('', 0, 0), '');
      expect(safeSubstring('', 0, 10), '');
      expect(safeSubstring('', 5, 10), '');
      expect(safeSubstring('', 0, -1), '');
    });

    test('handles production-like N values (string lengths 58-117)', () {
      // These are the N values seen in the production RangeError logs.
      for (final length in [58, 60, 66, 68, 75, 76, 77, 80, 81, 85, 89, 94, 95, 99, 107, 110, 113, 117]) {
        final s = 'x' * length;
        expect(safeSubstring(s, 0, -1), '');
        expect(safeSubstring(s, 0, length), s);
        expect(safeSubstring(s, 0, length + 10), s);
      }
    });
  });

  group('safePrefix', () {
    test('returns first n characters', () {
      expect(safePrefix('hello', 3), 'hel');
      expect(safePrefix('hello', 0), '');
      expect(safePrefix('hello', 10), 'hello');
    });

    test('returns empty string for negative n', () {
      expect(safePrefix('hello', -1), '');
      expect(safePrefix('hello', -10), '');
    });

    test('handles empty input', () {
      expect(safePrefix('', 3), '');
      expect(safePrefix('', 0), '');
    });
  });

  group('substringUntil', () {
    test('returns the part before the pattern', () {
      expect(substringUntil('hello world', ' '), 'hello');
      expect(substringUntil('a,b,c', ','), 'a');
      expect(substringUntil('foo@bar.com', '@'), 'foo');
    });

    test('returns empty string when pattern is not found', () {
      // This is the safe replacement for the buggy pattern:
      // value.substring(0, value.indexOf(pattern))  // throws if not found
      expect(substringUntil('hello', ' '), '');
      expect(substringUntil('hello', 'x'), '');
      expect(substringUntil('', 'x'), '');
    });

    test('handles empty pattern', () {
      expect(substringUntil('hello', ''), '');
    });
  });

  group('substringUntilLast', () {
    test('returns the part before the last occurrence', () {
      expect(substringUntilLast('a.b.c.d', '.'), 'a.b.c');
      expect(substringUntilLast('foo@bar.com', '@'), 'foo');
    });

    test('returns empty string when pattern is not found', () {
      expect(substringUntilLast('hello', ' '), '');
      expect(substringUntilLast('hello', 'x'), '');
    });
  });

  group('safeIndexOf', () {
    test('returns the index of the first occurrence', () {
      expect(safeIndexOf('hello', 'l'), 2);
      expect(safeIndexOf('hello', 'l', 3), 3);
      expect(safeIndexOf('hello', 'x'), -1);
    });

    test('returns start for empty pattern', () {
      expect(safeIndexOf('hello', ''), 0);
      expect(safeIndexOf('hello', '', 3), 3);
    });
  });
}
