// The review: "you can pull them into the Kanban". Every story already appears
// on the board's first column, so pulling one in means moving it out of that
// entry column into the first working column. These pin that rule against the
// project's configured columns, without Firestore.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/services/kanban_config_service.dart';
import 'package:ndu_project/utils/agile_board_pull.dart';

void main() {
  final configured = <String, dynamic>{
    'columns': [
      {'name': 'Intake'},
      {'name': 'Doing'},
      {'name': 'Shipped'},
    ],
  };

  group('with the default board', () {
    test('the entry column is the first default column', () {
      expect(AgileBoardPull.entryColumnId(const {}), 'backlog');
      expect(AgileBoardPull.columnTitle(AgileTask(), const {}), 'Backlog');
    });

    test('pulling a story lands it in the first working column', () {
      final story = AgileTask(id: 's1', userStory: 'Sign up');

      final pulled = AgileBoardPull.pull(story, const {});

      expect(pulled.workflowState, 'ready');
      expect(AgileBoardPull.isOnBoard(pulled, const {}), isTrue);
      expect(AgileBoardPull.columnTitle(pulled, const {}), 'Ready');
      // Everything else about the story is untouched.
      expect(pulled.userStory, 'Sign up');
      expect(pulled.id, 's1');
    });

    test('a story that has never been pulled is not on the board', () {
      expect(AgileBoardPull.isOnBoard(AgileTask(), const {}), isFalse,
          reason: 'a new story defaults to the entry column');
      expect(AgileBoardPull.isOnBoard(AgileTask(workflowState: 'backlog'), const {}),
          isFalse);
    });

    test('an unknown column resolves to the entry column, like the board does',
        () {
      expect(
        AgileBoardPull.columnTitle(
            AgileTask(workflowState: 'nonsense'), const {}),
        'Backlog',
      );
    });

    test('release puts a story back in the entry column', () {
      final pulled = AgileBoardPull.pull(AgileTask(), const {});
      final back = AgileBoardPull.release(pulled, const {});

      expect(back.workflowState, 'backlog');
      expect(AgileBoardPull.isOnBoard(back, const {}), isFalse);
    });
  });

  group('with a configured board', () {
    test('the entry and working columns follow the configuration', () {
      expect(AgileBoardPull.entryColumnId(configured), 'intake');
      expect(AgileBoardPull.workingColumnId(configured), 'doing');
    });

    test('pulling uses the configured column, not the defaults', () {
      final pulled = AgileBoardPull.pull(AgileTask(), configured);

      expect(pulled.workflowState, 'doing');
      expect(AgileBoardPull.columnTitle(pulled, configured), 'Doing');
    });

    test('a one-column board cannot pull a story anywhere', () {
      final single = <String, dynamic>{
        'columns': [
          {'name': 'Everything'},
        ],
      };

      expect(AgileBoardPull.workingColumnId(single), 'everything');
      expect(AgileBoardPull.workingColumnId(single),
          AgileBoardPull.entryColumnId(single));
    });

    test('a malformed column list falls back to the default board', () {
      final malformed = <String, dynamic>{
        'columns': [
          {'wipLimit': 3},
          'not a map',
        ],
      };

      expect(AgileBoardPull.columns(malformed),
          KanbanConfigService.defaultColumns);
      expect(AgileBoardPull.workingColumnId(malformed), 'ready');
    });
  });
}
