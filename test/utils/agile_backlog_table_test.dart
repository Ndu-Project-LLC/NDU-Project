// The planning backlog table exists because a story only ever appeared inside
// its feature's card — so a story whose feature link was empty or stale
// disappeared from the screen entirely, which is how the missing
// feature → story breakdown went unnoticed. These tests pin the chain the
// review asked to see (story → feature → epic), the ordering, and above all
// that an unlinked story is surfaced rather than dropped.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/utils/agile_backlog_table.dart';

void main() {
  final epicA = Epic(id: 'epic-a', title: 'Customer onboarding');
  final epicB = Epic(id: 'epic-b', title: 'Billing');

  final featureA1 = Feature(id: 'feat-a1', epicId: 'epic-a', title: 'Sign up');
  final featureA2 =
      Feature(id: 'feat-a2', epicId: 'epic-a', title: 'Verify email');
  final featureB1 = Feature(id: 'feat-b1', epicId: 'epic-b', title: 'Invoices');

  final epics = [epicA, epicB];
  final featuresByEpic = {
    'epic-a': [featureA1, featureA2],
    'epic-b': [featureB1],
  };

  AgileTask story(
    String id,
    String featureId, {
    required String title,
    int order = 0,
    String description = '',
    String acceptance = '',
  }) =>
      AgileTask(
        id: id,
        featureId: featureId,
        userStory: title,
        taskDescription: description,
        acceptanceCriteria: acceptance,
        backlogOrder: order,
      );

  group('parent chain', () {
    test('each row carries the feature and the epic it came from', () {
      final rows = AgileBacklogTable.build(
        epics: epics,
        featuresByEpic: featuresByEpic,
        stories: [
          story('s1', 'feat-a2', title: 'Confirm address', order: 1),
        ],
      );

      expect(rows, hasLength(1));
      expect(rows.single.featureTitle, 'Verify email');
      expect(rows.single.epicTitle, 'Customer onboarding');
      expect(rows.single.isUnlinked, isFalse);
    });

    test('an epic with no title still resolves the feature', () {
      final rows = AgileBacklogTable.build(
        epics: [Epic(id: 'epic-a')],
        featuresByEpic: featuresByEpic,
        stories: [story('s1', 'feat-a1', title: 'Sign up form')],
      );

      expect(rows.single.featureTitle, 'Sign up');
      expect(rows.single.epicTitle, '');
    });
  });

  group('unlinked stories', () {
    test('a story with no feature is kept, sorted last', () {
      final rows = AgileBacklogTable.build(
        epics: epics,
        featuresByEpic: featuresByEpic,
        stories: [
          story('orphan', '', title: 'Loose story', order: 0),
          story('linked', 'feat-b1', title: 'Invoice totals', order: 7),
        ],
      );

      expect(rows.map((r) => r.story.id), ['linked', 'orphan'],
          reason: 'a story with no feature must still be listed');
      expect(rows.last.isUnlinked, isTrue);
      expect(rows.last.unlinkedReason, BacklogUnlinkedReason.none);
      expect(rows.last.unlinkedLabel, 'No feature set');
    });

    test('a story pointing at a deleted feature says so', () {
      final rows = AgileBacklogTable.build(
        epics: epics,
        featuresByEpic: featuresByEpic,
        stories: [story('s1', 'feat-deleted', title: 'Stale link')],
      );

      expect(rows.single.isUnlinked, isTrue);
      expect(rows.single.unlinkedReason, BacklogUnlinkedReason.missing);
      expect(rows.single.unlinkedLabel, contains('feat-deleted'));
    });
  });

  group('ordering', () {
    test('rows run epic → feature → backlog order', () {
      final rows = AgileBacklogTable.build(
        epics: epics,
        featuresByEpic: featuresByEpic,
        stories: [
          story('s5', 'feat-b1', title: 'Billing story', order: 1),
          story('s2', 'feat-a1', title: 'Second in feature', order: 2),
          story('s1', 'feat-a1', title: 'First in feature', order: 1),
          story('s3', 'feat-a2', title: 'Other feature', order: 1),
        ],
      );

      expect(rows.map((r) => r.story.id), ['s1', 's2', 's3', 's5']);
    });

    test('equal backlog order falls back to title, not insert order', () {
      final rows = AgileBacklogTable.build(
        epics: epics,
        featuresByEpic: featuresByEpic,
        stories: [
          story('zeta', 'feat-a1', title: 'Zeta'),
          story('alpha', 'feat-a1', title: 'Alpha'),
        ],
      );

      expect(rows.map((r) => r.story.id), ['alpha', 'zeta']);
    });
  });

  group('search', () {
    final stories = [
      story('s1', 'feat-a1', title: 'Reset password'),
      story('s2', 'feat-b1', title: 'Invoice totals', description: 'Tax lines'),
      story('s3', 'feat-a2',
          title: 'Confirm address', acceptance: 'Postcode verified'),
    ];

    List<String> idsFor(String query) => AgileBacklogTable.build(
          epics: epics,
          featuresByEpic: featuresByEpic,
          stories: stories,
          query: query,
        ).map((r) => r.story.id).toList();

    test('matches story text', () {
      expect(idsFor('password'), ['s1']);
    });

    test('matches the description and the acceptance criteria', () {
      expect(idsFor('tax'), ['s2']);
      expect(idsFor('postcode'), ['s3']);
    });

    test('matches the feature and epic the story rolls up to', () {
      expect(idsFor('Invoices'), ['s2']);
      expect(idsFor('Customer onboarding'), ['s1', 's3']);
    });

    test('no match is empty, not everything', () {
      expect(idsFor('nothing here'), isEmpty);
    });
  });

  group('features with no stories', () {
    test('reports the features still to be broken down', () {
      final gaps = AgileBacklogTable.featuresWithoutStories(
        epics: epics,
        featuresByEpic: featuresByEpic,
        stories: [story('s1', 'feat-a1', title: 'Sign up form')],
      );

      expect(gaps.map((f) => f.id), ['feat-a2', 'feat-b1']);
    });

    test('a feature whose only story is unlinked still counts as empty', () {
      final gaps = AgileBacklogTable.featuresWithoutStories(
        epics: epics,
        featuresByEpic: featuresByEpic,
        stories: [story('orphan', '', title: 'Loose story')],
      );

      expect(gaps.map((f) => f.id), ['feat-a1', 'feat-a2', 'feat-b1']);
    });
  });
}
