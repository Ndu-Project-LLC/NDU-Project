// The review asked for the backlog to be prioritised by dragging — "you can
// just drag them up and down to prioritize them" — and to be searchable by
// epic, feature, or story. These pin the pure half of both.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/utils/agile_backlog_order.dart';

AgileTask _story({
  required String id,
  required String featureId,
  int order = 0,
  String title = '',
  String description = '',
  String criteria = '',
}) {
  return AgileTask(
    id: id,
    featureId: featureId,
    backlogOrder: order,
    userStory: title,
    taskDescription: description,
    acceptanceCriteria: criteria,
  );
}

void main() {
  final s1 = _story(id: 's1', featureId: 'fA', order: 1, title: 'Sign up');
  final s2 = _story(id: 's2', featureId: 'fA', order: 2, title: 'Verify');
  final s3 = _story(id: 's3', featureId: 'fA', order: 3, title: 'Welcome');
  final s4 = _story(id: 's4', featureId: 'fB', order: 4, title: 'Card payment');
  final backlog = [s3, s1, s4, s2]; // deliberately unsorted

  List<String> ids(List<AgileTask> stories) =>
      stories.map((story) => story.id).toList();

  List<int> orders(List<AgileTask> stories) =>
      stories.map((story) => story.backlogOrder).toList();

  group('sorted', () {
    test('orders by stored priority, not arrival order', () {
      expect(ids(AgileBacklogOrdering.sorted(backlog)), ['s1', 's2', 's3', 's4']);
    });

    test('an unnumbered backlog keeps its own order instead of shuffling', () {
      final unnumbered = [
        _story(id: 'a', featureId: 'fA'),
        _story(id: 'b', featureId: 'fA'),
        _story(id: 'c', featureId: 'fA'),
      ];

      expect(ids(AgileBacklogOrdering.sorted(unnumbered)), ['a', 'b', 'c']);
    });

    test('forFeature filters and orders in one step', () {
      expect(ids(AgileBacklogOrdering.forFeature(backlog, 'fA')),
          ['s1', 's2', 's3']);
      expect(AgileBacklogOrdering.forFeature(backlog, 'nope'), isEmpty);
    });
  });

  group('adjustedIndex', () {
    test('a downward drop lands one slot too far and is corrected', () {
      expect(AgileBacklogOrdering.adjustedIndex(0, 2), 1);
      expect(AgileBacklogOrdering.adjustedIndex(1, 3), 2);
    });

    test('an upward drop is already correct', () {
      expect(AgileBacklogOrdering.adjustedIndex(2, 0), 0);
    });
  });

  group('moveWithinFeature', () {
    test('drag down inside a feature renumbers that feature', () {
      final result = AgileBacklogOrdering.moveWithinFeature(
        stories: backlog,
        featureId: 'fA',
        oldIndex: 0,
        newIndex: 3,
      );

      expect(ids(result), ['s2', 's3', 's1', 's4']);
      expect(orders(result), [1, 2, 3, 4],
          reason: 'the stored priority, which is what the reload reads');
    });

    test('drag up inside a feature renumbers that feature', () {
      final result = AgileBacklogOrdering.moveWithinFeature(
        stories: backlog,
        featureId: 'fA',
        oldIndex: 2,
        newIndex: 0,
      );

      expect(ids(result), ['s3', 's1', 's2', 's4']);
    });

    test('other features keep their place in the backlog', () {
      final mixed = [
        _story(id: 'other', featureId: 'fB', order: 1),
        _story(id: 'a1', featureId: 'fA', order: 2),
        _story(id: 'a2', featureId: 'fA', order: 3),
      ];

      final result = AgileBacklogOrdering.moveWithinFeature(
        stories: mixed,
        featureId: 'fA',
        oldIndex: 0,
        newIndex: 2,
      );

      expect(ids(result), ['other', 'a2', 'a1'],
          reason: 'the fA block stays where it was; only its internals moved');
    });

    test('a drop back where it started changes nothing', () {
      final result = AgileBacklogOrdering.moveWithinFeature(
        stories: backlog,
        featureId: 'fA',
        oldIndex: 1,
        newIndex: 1,
      );

      expect(ids(result), ['s1', 's2', 's3', 's4']);
    });

    test('an index that no longer exists is ignored, not crashed', () {
      final result = AgileBacklogOrdering.moveWithinFeature(
        stories: backlog,
        featureId: 'fA',
        oldIndex: 7,
        newIndex: 0,
      );

      expect(ids(result), ['s1', 's2', 's3', 's4']);
    });

    test('a feature with no stories is a no-op', () {
      final result = AgileBacklogOrdering.moveWithinFeature(
        stories: backlog,
        featureId: 'fZ',
        oldIndex: 0,
        newIndex: 1,
      );

      expect(ids(result), ['s1', 's2', 's3', 's4']);
    });
  });

  group('nudgeWithinFeature', () {
    test('moves a story one place later', () {
      final result = AgileBacklogOrdering.nudgeWithinFeature(
        stories: backlog,
        storyId: 's1',
        delta: 1,
      );

      expect(ids(result), ['s2', 's1', 's3', 's4']);
      expect(orders(result), [1, 2, 3, 4]);
    });

    test('moves a story one place earlier', () {
      final result = AgileBacklogOrdering.nudgeWithinFeature(
        stories: backlog,
        storyId: 's2',
        delta: -1,
      );

      // s2 swaps with the story above it, and nothing else moves.
      expect(ids(result), ['s2', 's1', 's3', 's4']);
    });

    test('a nudge off the end of the feature is a no-op', () {
      expect(
        ids(AgileBacklogOrdering.nudgeWithinFeature(
            stories: backlog, storyId: 's3', delta: 1)),
        ['s1', 's2', 's3', 's4'],
        reason: 's3 is already last in fA',
      );
      expect(
        ids(AgileBacklogOrdering.nudgeWithinFeature(
            stories: backlog, storyId: 's1', delta: -1)),
        ['s1', 's2', 's3', 's4'],
      );
    });

    test('a story that does not exist changes nothing', () {
      expect(
        ids(AgileBacklogOrdering.nudgeWithinFeature(
            stories: backlog, storyId: 'nope', delta: 1)),
        ['s1', 's2', 's3', 's4'],
      );
    });
  });

  group('matches', () {
    test('reads the story itself', () {
      final story = _story(
        id: 's',
        featureId: 'fA',
        title: 'Sign up with email',
        description: 'Self-serve',
        criteria: '• Password is hashed',
      );

      expect(AgileBacklogOrdering.matches(story, query: 'sign up'), isTrue);
      expect(AgileBacklogOrdering.matches(story, query: 'self-serve'), isTrue);
      expect(AgileBacklogOrdering.matches(story, query: 'hashed'), isTrue);
      expect(AgileBacklogOrdering.matches(story, query: 'zzz'), isFalse);
    });

    test('reads the feature and epic it came from', () {
      final story = _story(id: 's', featureId: 'fA', title: 'Sign up');

      expect(
        AgileBacklogOrdering.matches(story,
            query: 'onboarding', featureTitle: 'Customer onboarding'),
        isTrue,
      );
      expect(
        AgileBacklogOrdering.matches(story, query: 'billing', epicTitle: 'Billing'),
        isTrue,
      );
      expect(
        AgileBacklogOrdering.matches(story,
            query: 'BILLING', epicTitle: 'Billing'),
        isTrue,
        reason: 'search is case-insensitive',
      );
    });

    test('a blank query matches everything', () {
      expect(AgileBacklogOrdering.matches(s1, query: '   '), isTrue);
    });
  });
}
