/// Defensive string utilities that never throw [RangeError].
///
/// These helpers exist to harden the codebase against `RangeError (end):
/// Invalid value: Not in inclusive range 0..N: -1` crashes that occur when
/// `String.substring` receives an `end` argument of `-1` (typically because
/// `String.indexOf` returned `-1` for a missing substring and the result
/// was used as the `end` argument without a guard).
///
/// All helpers in this file clamp their indices to the valid range
/// `[0, length]` before delegating to the underlying `String` operation,
/// so they never throw — they return an empty string or a clamped slice
/// instead.
library;

/// Returns `value.substring(start, end)` without ever throwing.
///
/// - If `start` is negative, it is clamped to `0`.
/// - If `end` is negative or `null`, the rest of the string from `start`
///   is returned.
/// - If `end` is greater than `value.length`, it is clamped to
///   `value.length`.
/// - If `start > end` (after clamping), an empty string is returned.
///
/// Example:
/// ```dart
/// safeSubstring('hello', 0, -1);   // '' (was: RangeError)
/// safeSubstring('hello', 0, 100);  // 'hello'
/// safeSubstring('hello', 2, 4);    // 'll'
/// safeSubstring('hello', 4, 2);    // ''
/// ```
String safeSubstring(String value, int start, [int? end]) {
  final length = value.length;
  final clampedStart = start < 0 ? 0 : (start > length ? length : start);
  if (end == null) {
    return value.substring(clampedStart);
  }
  var clampedEnd = end < 0 ? 0 : (end > length ? length : end);
  if (clampedEnd < clampedStart) {
    return '';
  }
  return value.substring(clampedStart, clampedEnd);
}

/// Returns the first `n` characters of `value`, or the whole string if it
/// is shorter. Never throws.
///
/// Equivalent to `safeSubstring(value, 0, n)`.
String safePrefix(String value, int n) {
  if (n <= 0) return '';
  return safeSubstring(value, 0, n);
}

/// Returns the index of the first occurrence of `pattern` in `value`,
/// starting at `start`. Returns `-1` if not found. This is just a
/// thin wrapper around `String.indexOf` for naming consistency.
int safeIndexOf(String value, String pattern, [int start = 0]) {
  if (pattern.isEmpty) return start;
  return value.indexOf(pattern, start);
}

/// Calls [safeSubstring] with the result of [value.indexOf] as the `end`.
///
/// This is the safe replacement for the buggy pattern:
/// ```dart
/// value.substring(0, value.indexOf(pattern))  // throws if pattern missing
/// ```
///
/// Returns the empty string if [pattern] is not found.
String substringUntil(String value, String pattern) {
  final idx = value.indexOf(pattern);
  if (idx < 0) return '';
  return safeSubstring(value, 0, idx);
}

/// Calls [safeSubstring] with the result of [value.lastIndexOf] as the `end`.
///
/// Returns the empty string if [pattern] is not found.
String substringUntilLast(String value, String pattern) {
  final idx = value.lastIndexOf(pattern);
  if (idx < 0) return '';
  return safeSubstring(value, 0, idx);
}
