// The review called the epic card grid "not very efficient": a feature was only
// visible after selecting its epic. These pin the pure half of the flat list
// view that answers it — ordering, search, and the gaps it has to admit to.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/utils/agile_epic_feature_table.dart';

void main() {
  final epicA = Epic(id: 'epic-a', title: 'Customer onboarding');
  final epicB = Epic(id: 'epic-b', title: 'Billing');
  final epicC = Epic(id: 'epic-c', title: '');

  final featureA1 = Feature(
    id: 'f-a1',
    epicId: 'epic-a',
    title: 'Sign up with email',
    description: 'Self-serve signup',
    priority: 'high',
    storyPointEstimate: 5,
    wbsId: 'wbs-9',
  );
  final featureA2 = Feature(id: 'f-a2', epicId: 'epic-a', title: 'Invite team');
  final featureB1 = Feature(
    id: 'f-b1',
    epicId: 'epic-b',
    title: 'Card payments',
    priority: 'critical',
    storyPointEstimate: 8,
  );

  final featuresByEpic = {
    'epic-a': [featureA1, featureA2],
    'epic-b': [featureB1],
    'epic-c': <Feature>[],
  };

  group('build', () {
    test('orders features epic by epic, in load order', () {
      final rows = AgileEpicFeatureTable.build([epicA, epicB], featuresByEpic);

      expect(rows.map((r) => r.feature.id).toList(),
          ['f-a1', 'f-a2', 'f-b1']);
      expect(rows.first.epicTitle, 'Customer onboarding');
    });

    test('an unnamed epic does not render as a blank cell', () {
      final rows = AgileEpicFeatureTable.build(
          [epicC], {'epic-c': [Feature(id: 'f-c1', epicId: 'epic-c')]});

      expect(rows.single.epicTitle, 'Untitled epic');
    });

    test('a nameless feature reads as something', () {
      final rows = AgileEpicFeatureTable.build(
          [epicA], {'epic-a': [Feature(id: 'f-x', epicId: 'epic-a')]});

      expect(rows.single.title, 'Untitled feature');
    });

    test('features for an epic the screen no longer has are kept, not dropped',
        () {
      final rows = AgileEpicFeatureTable.build(
        [epicA],
        {
          'epic-a': [featureA1],
          'epic-gone': [Feature(id: 'f-g', epicId: 'epic-gone', title: 'Old')],
        },
      );

      expect(rows.length, 2);
      expect(rows.last.epicIsMissing, isTrue);
      expect(rows.last.epicLabel, 'Epic no longer exists');
    });
  });

  group('search', () {
    test('matches feature, epic, priority, status, and WBS link', () {
      final rows = AgileEpicFeatureTable.build([epicA, epicB], featuresByEpic);

      expect(AgileEpicFeatureTable.filter(rows, 'sign up').length, 1);
      expect(AgileEpicFeatureTable.filter(rows, 'self-serve').length, 1,
          reason: 'the description is searchable too');
      expect(AgileEpicFeatureTable.filter(rows, 'billing').length, 1,
          reason: 'the epic name alone should surface its features');
      expect(AgileEpicFeatureTable.filter(rows, 'critical').length, 1);
      expect(AgileEpicFeatureTable.filter(rows, 'wbs-9').length, 1);
    });

    test('is case-insensitive and blank returns everything', () {
      final rows = AgileEpicFeatureTable.build([epicA, epicB], featuresByEpic);

      expect(AgileEpicFeatureTable.filter(rows, 'BILLING').length, 1);
      expect(AgileEpicFeatureTable.filter(rows, '   ').length, 3);
    });

    test('no match returns nothing rather than everything', () {
      final rows = AgileEpicFeatureTable.build([epicA, epicB], featuresByEpic);
      expect(AgileEpicFeatureTable.filter(rows, 'zzz'), isEmpty);
    });
  });

  group('gaps and totals', () {
    test('an epic with no features is reported', () {
      final ids = AgileEpicFeatureTable.epicsWithoutFeatures(
              [epicA, epicB, epicC], featuresByEpic)
          .map((e) => e.id)
          .toList();

      expect(ids, ['epic-c']);
    });

    test('counts distinct epics and sums story points', () {
      final rows = AgileEpicFeatureTable.build([epicA, epicB], featuresByEpic);

      expect(AgileEpicFeatureTable.epicCount(rows), 2);
      expect(AgileEpicFeatureTable.totalPoints(rows), 13);
    });
  });
}
