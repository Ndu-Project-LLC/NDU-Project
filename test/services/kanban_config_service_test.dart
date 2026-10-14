// The Kanban board and the Kanban Configuration page now read the saved
// workflow columns through KanbanConfigService, so both must agree on the
// stored shape (`{columns: [{name, wipLimit}]}`), on what "no limit" means, and
// on how a column name becomes a card state. These tests pin that contract —
// in particular that a name is written as given, because
// alignStatusesToWorkflow collapses synonyms (Backlog / Ready → To Do) and
// would silently merge two of the owner's columns.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/services/kanban_config_service.dart';

void main() {
  group('wip limits', () {
    test('blank, non-numeric and non-positive input mean no limit', () {
      for (final value in [null, '', '   ', 'abc', 0, -3]) {
        expect(KanbanConfigService.parseWipLimit(value),
            KanbanConfigService.noWipLimit,
            reason: '$value should mean no limit');
      }
    });

    test('a real number survives the round trip', () {
      expect(KanbanConfigService.parseWipLimit(8), 8);
      expect(KanbanConfigService.parseWipLimit('8'), 8);
      expect(KanbanConfigService.parseWipLimit(' 12 '), 12);
    });

    test('the label distinguishes a limit from no limit', () {
      expect(KanbanConfigService.wipLimitLabel(5), '5');
      expect(KanbanConfigService.wipLimitLabel(KanbanConfigService.noWipLimit),
          'No limit');
      expect(KanbanConfigService.isUnlimited(1000), isTrue);
      expect(KanbanConfigService.isUnlimited(5), isFalse);
    });
  });

  group('columns', () {
    test('the default workflow matches the board the user sees', () {
      expect(
        [for (final c in KanbanConfigService.defaultColumns) c.name],
        ['Backlog', 'Ready', 'In Progress', 'In Review', 'Done'],
      );
      expect(KanbanConfigService.defaultColumns.first.wipLimit,
          KanbanConfigService.noWipLimit);
      expect(KanbanConfigService.defaultColumns[1].wipLimit, 8);
    });

    test('stored columns are read in board order, names untouched', () {
      final columns = KanbanConfigService.columnsFromConfig({
        'columns': [
          {'name': 'Backlog', 'wipLimit': 999},
          {'name': 'Ready', 'wipLimit': 8},
          {'name': 'In Progress', 'wipLimit': 5},
        ],
      });

      expect([for (final c in columns) c.name],
          ['Backlog', 'Ready', 'In Progress'],
          reason: 'Backlog and Ready must not be normalised into "To Do"');
      expect(columns[1].wipLimit, 8);
    });

    test('junk entries are skipped rather than rendered as blank columns', () {
      expect(
        KanbanConfigService.columnsFromConfig({
          'columns': [
            {'name': '  '},
            {'wipLimit': 5},
            'not-a-map',
            {'name': 'Done'},
          ],
        }).map((c) => c.name),
        ['Done'],
      );
      expect(KanbanConfigService.columnsFromConfig(const {}), isEmpty);
      expect(KanbanConfigService.columnsFromConfig({'columns': 'nope'}), isEmpty);
    });

    test('column state is derived from the name', () {
      expect(KanbanConfigService.columnIdFor('In Progress'), 'in_progress');
      expect(KanbanConfigService.columnIdFor('Ready for Release'),
          'ready_for_release');
      expect(KanbanConfigService.columnIdFor('  '), 'column');
      expect(KanbanConfigService.columnIdFor('', fallback: 'column_3'),
          'column_3');
    });

    test('a column round-trips through its stored map', () {
      const column = KanbanColumnConfig(name: 'Ready', wipLimit: 8);
      expect(KanbanConfigService.columnsFromConfig({
        'columns': [column.toMap()],
      }), [column]);
      expect(column.copyWith(name: 'Queued').name, 'Queued');
      expect(column.copyWith(name: 'Queued').wipLimit, 8);
    });
  });
}
