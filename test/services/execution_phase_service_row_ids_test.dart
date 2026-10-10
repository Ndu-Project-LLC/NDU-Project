// The project payload is healed app-wide when it is decoded, but the rows the
// app keeps in their own `execution_phase_entries` documents are not — those
// are decoded one loader at a time. A loader that built rows keyed by id
// without healing let a batch seeded from one clock tick share an id, which is
// what scrambled the kanban board's cards. The design canvas and the alignment
// table key rows by id the same way, so their decoders heal too.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/services/execution_phase_service.dart';

void main() {
  group('decodeDesignComponents', () {
    test('components sharing an id come back with distinct ids', () {
      final components = ExecutionPhaseService.decodeDesignComponents([
        for (var i = 0; i < 5; i++) {'id': '1787939312317000', 'name': 'N$i'},
      ]);

      expect(components, hasLength(5));
      expect(components.map((c) => c.id).toSet(), hasLength(5));
      // The first keeps its id, so existing references still resolve.
      expect(components.first.id, '1787939312317000');
    });

    test('clean ids are preserved and junk is skipped, not thrown', () {
      final components = ExecutionPhaseService.decodeDesignComponents([
        {'id': 'c1', 'name': 'A'},
        {'id': 'c2', 'name': 'B'},
        'not a map',
      ]);

      expect(components.map((c) => c.id), ['c1', 'c2']);
      expect(ExecutionPhaseService.decodeDesignComponents(null), isEmpty);
    });
  });

  group('decodeStakeholderAlignmentItems', () {
    test('items sharing an id come back with distinct ids', () {
      final items = ExecutionPhaseService.decodeStakeholderAlignmentItems([
        for (var i = 0; i < 4; i++) {'id': 'dup', 'stakeholderName': 'S$i'},
      ]);

      expect(items, hasLength(4));
      expect(items.map((i) => i.id).toSet(), hasLength(4));
    });

    test('clean ids are preserved and junk is skipped, not thrown', () {
      final items = ExecutionPhaseService.decodeStakeholderAlignmentItems([
        {'id': 'a1', 'stakeholderName': 'A'},
        {'id': 'a2', 'stakeholderName': 'B'},
        42,
      ]);

      expect(items.map((i) => i.id), ['a1', 'a2']);
      expect(
          ExecutionPhaseService.decodeStakeholderAlignmentItems('nope'), isEmpty);
    });
  });
}
