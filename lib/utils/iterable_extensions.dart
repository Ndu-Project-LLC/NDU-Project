extension IterableExtensions<T> on Iterable<T> {
  /// Returns the first element matching [test], or `null` when none match.
  T? firstOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
