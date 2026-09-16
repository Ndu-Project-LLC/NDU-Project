// ─────────────────────────────────────────────────────────────────────────────
// unique_id.dart
//
// Row ids for the editable tables (components, entities, work packages, …).
//
// Why a helper instead of DateTime.now().microsecondsSinceEpoch: ids are minted
// in LOOPS — a dozen seeded rows in one list literal, or a batch import — and
// on the web (and on coarser clocks) `DateTime.now()` only ticks about once a
// millisecond, so every row in that loop received the SAME id. Rows are then
// updated and keyed by id, so an edit landed on the first row that carried the
// id instead of the row the user typed in: typing in one row visibly changed
// another one, and the two rows ended up holding the same text.
//
// [newId] cannot repeat within a process (a monotonic counter is part of the
// value), and [persistedId] heals data that already carries a missing, blank or
// duplicated id, so projects saved before this fix repair themselves on load.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

int _sequence = 0;
final Random _random = Random();

/// A process-unique, collision-resistant id.
///
/// [prefix] is for readable ids (`'att_'`, `'wf_'`); the rest of the value is a
/// timestamp, a counter and a random salt, so two calls in the same microsecond
/// (or in the same millisecond on the web) still differ.
String newId([String prefix = '']) {
  _sequence = (_sequence + 1) & 0xFFFFFF;
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final sequence = _sequence.toRadixString(36).padLeft(4, '0');
  final salt = _random.nextInt(1 << 30).toRadixString(36);
  return '$prefix$stamp-$sequence-$salt';
}

/// A short, readable id for rows that *show* their id — issue numbers, ticket
/// codes. Never repeats within this process, unlike a clock-derived code.
String shortId([String prefix = '']) =>
    '$prefix${newId().split('-')[1].toUpperCase()}';

/// Decodes a persisted row id, minting a fresh one when [raw] is missing, blank
/// or already used by an earlier row in the same list.
///
/// Pass the same [seen] set to every row of one list:
///
/// ```dart
/// final seen = <String>{};
/// return data.map((item) => Row(id: persistedId(item['id'], seen), …));
/// ```
///
/// Rows that share an id can only ever be updated through the first of them, so
/// a duplicate is worse than a new id: the text the user typed would show up in
/// the wrong row.
String persistedId(Object? raw, Set<String> seen) {
  final stored = raw?.toString();
  if (stored == null || stored.isEmpty || !seen.add(stored)) return newId();
  return stored;
}
