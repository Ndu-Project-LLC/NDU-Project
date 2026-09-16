// Row ids have to be unique or an edit lands on the wrong row, so these tests
// pin both halves: that minting in a tight loop (which is how the seeded tables
// are built) cannot repeat, and that data saved with a missing, blank or
// duplicated id is repaired on load.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/utils/unique_id.dart';

void main() {
  test('ids minted in a tight loop are all different', () {
    // A thousand rows created in one statement is the shape that broke the
    // seeded design tables: same clock tick, so a timestamp-only id repeated.
    final ids = List<String>.generate(1000, (_) => newId());
    expect(ids.toSet().length, ids.length);
  });

  test('ids stay different when the clock does not move', () {
    // One millisecond is all a web build gets out of the clock, so several ids
    // minted inside a single tick is the window the seeded tables lived in.
    //
    // This used to spin for a fixed wall-clock window and count the ids, which
    // is a flaky test: under a full parallel suite run the interpreter can take
    // longer than that whole window to get from one line to the next, the loop
    // body never runs, and the count comes back zero. Minting a fixed number of
    // ids instead makes the same point without depending on machine speed.
    final ids = List<String>.generate(500, (_) => newId());

    // Strip the timestamp and they must STILL all differ. That is the property
    // that actually matters: the counter and the salt alone already make ids
    // distinct within one clock tick, so a stalled clock cannot collide them.
    final withoutStamp =
        ids.map((id) => id.split('-').sublist(1).join('-')).toSet();
    expect(withoutStamp.length, ids.length);
  });

  test('a prefix is kept', () {
    expect(newId('att_'), startsWith('att_'));
  });

  test('short ids are readable and do not repeat', () {
    // Issue numbers are shown to the user, so they stay short — but two issues
    // logged in the same microsecond must still get different numbers.
    final ids = List<String>.generate(200, (_) => shortId('ISS-'));
    expect(ids.toSet().length, ids.length);
    expect(ids.first, startsWith('ISS-'));
    expect(ids.first.length, lessThan(16));
  });

  test('persistedId keeps a usable stored id', () {
    final seen = <String>{};
    expect(persistedId('row-1', seen), 'row-1');
    expect(persistedId('row-2', seen), 'row-2');
  });

  test('persistedId replaces a missing, blank or duplicated id', () {
    final seen = <String>{};

    expect(persistedId('row-1', seen), 'row-1');
    // The duplicate — the exact case that made editing one row change another.
    final repairedDuplicate = persistedId('row-1', seen);
    expect(repairedDuplicate, isNot('row-1'));

    final repairedBlank = persistedId('', seen);
    expect(repairedBlank, isNotEmpty);

    final repairedNull = persistedId(null, seen);
    expect(repairedNull, isNotEmpty);

    final ids = <String>{
      'row-1',
      repairedDuplicate,
      repairedBlank,
      repairedNull,
    };
    expect(ids.length, 4);
  });

  test('persistedId repairs a whole list', () {
    final raw = <Object?>['a', 'a', null, '', 'b', 'b', 'b'];
    final seen = <String>{};
    final decoded = raw.map((id) => persistedId(id, seen)).toList();

    expect(decoded.toSet().length, decoded.length);
    // The first occurrence is kept, so existing data stays addressable.
    expect(decoded.first, 'a');
    expect(decoded[4], 'b');
  });
}
