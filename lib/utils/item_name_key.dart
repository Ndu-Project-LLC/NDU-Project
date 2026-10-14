/// One canonical form for an item's name, used to decide whether two records
/// are "the same item".
///
/// Imports, regenerations and repeated syncs all mint fresh ids for items the
/// project already holds, so id-based filters never catch the second copy. The
/// app-wide rule is therefore name-based: a project must never hold two items
/// that bear the same name.
///
/// The key is deliberately forgiving so cosmetic differences still count as the
/// same name:
/// - case and surrounding/duplicated whitespace are ignored,
/// - a trailing separator or punctuation is ignored (`"Site prep."` == `"Site prep"`),
/// - an em/en dash or hyphen reads the same (`"Procurement — Vessels"` ==
///   `"Procurement - Vessels"`),
/// - words repeated back-to-back collapse (`"Engineering Engineering Work
///   Package"` == `"Engineering Work Package"`), which is the form older saved
///   records are stored in.
///
/// Everything else is left alone, so genuinely different names
/// (`"Long-Lead Vessels"` vs `"Short-Lead Vessels"`) stay distinct.
library;

/// Canonical comparison key for [name].
///
/// Returns an empty string for a blank name, so callers can treat "unnamed" as
/// one shared bucket instead of comparing whitespace against itself.
String itemNameKey(String name) {
  final words = <String>[];
  for (final raw in name.split(RegExp(r'\s+'))) {
    final word = raw.trim();
    if (word.isEmpty) continue;
    final previous = words.isEmpty ? null : words.last.toLowerCase();
    if (previous == word.toLowerCase()) continue;
    words.add(_stripEdgePunctuation(word.toLowerCase()));
  }
  return words.join(' ');
}

/// Whether two names refer to the same item. Blank names never match anything,
/// including another blank name, so unnamed rows are left alone rather than
/// collapsed into one.
bool isSameItemName(String a, String b) {
  final keyA = itemNameKey(a);
  final keyB = itemNameKey(b);
  if (keyA.isEmpty || keyB.isEmpty) return false;
  return keyA == keyB;
}

/// [items] with repeats of the same [itemNameKey] collapsed to the first.
///
/// [nameOf] supplies each item's display name. Items whose name is blank are
/// always kept — they carry no name to compare, and dropping them would lose
/// real data.
///
/// Used when writing a collection back to storage so records duplicated by an
/// earlier import run are cleaned up in place.
List<T> dedupeItemsByName<T>(Iterable<T> items, String Function(T) nameOf) {
  final seen = <String>{};
  final out = <T>[];
  for (final item in items) {
    final key = itemNameKey(nameOf(item));
    if (key.isEmpty || seen.add(key)) out.add(item);
  }
  return out;
}

/// Drops edge punctuation so `"Vessels."`, `"(Vessels)"` and `"-Vessels-"`
/// compare equal to `"Vessels"`.
String _stripEdgePunctuation(String word) {
  const edge = '.,:;!?"\'()[]{}';
  var out = word;
  while (out.isNotEmpty && edge.contains(out[out.length - 1])) {
    out = out.substring(0, out.length - 1);
  }
  while (out.isNotEmpty && edge.contains(out[0])) {
    out = out.substring(1);
  }
  // Normalise every dash flavour to a single '-'.
  return out.replaceAll(RegExp(r'[‐‑‒–—―−]'), '-');
}