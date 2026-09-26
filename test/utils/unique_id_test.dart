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

  group('healRowIds', () {
    test('re-mints duplicates and keeps the first occurrence', () {
      final payload = <String, dynamic>{
        'components': <dynamic>[
          <String, dynamic>{'id': 'same', 'name': 'first'},
          <String, dynamic>{'id': 'same', 'name': 'second'},
          <String, dynamic>{'id': 'same', 'name': 'third'},
        ],
      };

      healRowIds(payload);
      final rows = payload['components'] as List;

      // The first row keeps its id, so anything referencing 'same' still finds
      // it rather than dangling.
      expect((rows[0] as Map)['id'], 'same');
      expect(rows.map((r) => (r as Map)['id']).toSet().length, 3);
      // Only the identity is re-minted; the content is left alone.
      expect(rows.map((r) => (r as Map)['name']).toList(),
          ['first', 'second', 'third']);
    });

    test('reaches rows nested inside maps and lists', () {
      // The real payload is nested like this — executionPhaseData -> sectionData
      // -> <section> -> rows — which is where most of the broken tables live.
      final payload = <String, dynamic>{
        'executionPhaseData': <String, dynamic>{
          'sectionData': <String, dynamic>{
            'compliance': <String, dynamic>{
              'rows': <dynamic>[
                <String, dynamic>{'id': 'dup', 'standard': 'ISO 9001'},
                <String, dynamic>{'id': 'dup', 'standard': 'ISO 27001'},
              ],
            },
          },
        },
      };

      healRowIds(payload);
      final sectionData =
          (payload['executionPhaseData'] as Map)['sectionData'] as Map;
      final rows = (sectionData['compliance'] as Map)['rows'] as List;

      expect((rows[0] as Map)['id'], 'dup');
      expect((rows[1] as Map)['id'], isNot('dup'));
    });

    test('the same id in two different lists is left alone', () {
      final payload = <String, dynamic>{
        'epics': <dynamic>[
          <String, dynamic>{'id': '12'},
        ],
        'tasks': <dynamic>[
          <String, dynamic>{'id': '12'},
        ],
      };

      healRowIds(payload);

      // Ids only have to be unique within a list, so neither of these is a
      // duplicate and neither is re-minted.
      expect((payload['epics'] as List)[0]['id'], '12');
      expect((payload['tasks'] as List)[0]['id'], '12');
    });

    test('a blank id is minted rather than shared', () {
      final payload = <String, dynamic>{
        'rows': <dynamic>[
          <String, dynamic>{'id': ''},
          <String, dynamic>{'id': ''},
          <String, dynamic>{},
        ],
      };

      healRowIds(payload);
      final rows = payload['rows'] as List;
      final minted = rows.map((r) => (r as Map)['id']).whereType<String>();

      // An empty id matches every other empty id, so both rows need one.
      expect(minted.length, 2);
      expect(minted.toSet().length, 2);
      // A row carrying no id at all is left for its decoder to mint.
      expect((rows[2] as Map)['id'], isNull);
    });

    test('ids that are not strings are never rewritten', () {
      final payload = <String, dynamic>{
        'rows': <dynamic>[
          <String, dynamic>{'id': 1},
          <String, dynamic>{'id': 1},
        ],
      };

      healRowIds(payload);

      // Rewriting these would silently turn an int id into a string.
      expect((payload['rows'] as List)[1]['id'], 1);
    });

    test('an already-unique payload is left untouched', () {
      final payload = <String, dynamic>{
        'rows': <dynamic>[
          <String, dynamic>{'id': 'a'},
          <String, dynamic>{'id': 'b'},
        ],
      };

      healRowIds(payload);
      healRowIds(payload);

      expect((payload['rows'] as List)[0]['id'], 'a');
      expect((payload['rows'] as List)[1]['id'], 'b');
    });
  });
}
