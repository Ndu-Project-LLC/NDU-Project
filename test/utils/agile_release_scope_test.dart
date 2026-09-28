// The review's Release Plan ask: show the epics the project already has, show
// the milestones already identified, tie the milestones to their work
// automatically so the user never re-selects them, and start a new plan blank
// instead of pre-filling it with something that reads as content.
//
// These rules are pure, so they are pinned here rather than through the screen
// (whose Firestore loads never complete under `flutter test`).

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/agile_release_plan.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/agile_release_scope.dart';

void main() {
  final epicA = Epic(id: 'epic-a', title: 'Customer onboarding', wbsId: 'wbs-1');
  final epicB = Epic(id: 'epic-b', title: 'Billing', wbsId: 'wbs-2');
  final epicC = Epic(id: 'epic-c', title: 'Reporting', wbsId: '');
  final featureA1 =
      Feature(id: 'feat-a1', epicId: 'epic-a', title: 'Sign up');
  final featureB1 =
      Feature(id: 'feat-b1', epicId: 'epic-b', title: 'Invoices');

  final epics = [epicA, epicB, epicC];
  final featuresByEpic = {
    'epic-a': [featureA1],
    'epic-b': [featureB1],
  };

  final milestoneA = Milestone(id: 'ms-a', name: 'Onboarding signed off');
  final milestoneB = Milestone(id: 'ms-b', name: 'Billing live');
  final milestoneSolo = Milestone(id: 'ms-solo', name: 'Unclaimed review');
  final milestones = [milestoneA, milestoneB, milestoneSolo];

  final stories = [
    AgileTask(
      id: 's-a1',
      featureId: 'feat-a1',
      epicId: 'epic-a',
      storyPoints: 5,
      milestoneIds: ['ms-a'],
    ),
    AgileTask(
      id: 's-a2',
      featureId: 'feat-a1',
      epicId: 'epic-a',
      storyPoints: 3,
    ),
    AgileTask(
      id: 's-b1',
      featureId: 'feat-b1',
      epicId: 'epic-b',
      storyPoints: 8,
      milestoneIds: ['ms-b'],
    ),
  ];

  AgileReleasePlan releaseOf(List<String> epicIds, {List<String> storyIds = const []}) =>
      AgileReleasePlan(id: 'rel-1', releaseLabel: 'R1', epicIds: epicIds, storyIds: storyIds);

  group('a new plan starts blank', () {
    test('no label, no scope, no date', () {
      final plan = AgileReleaseScope.blankPlan();

      expect(plan.releaseLabel, isEmpty);
      expect(plan.epicIds, isEmpty);
      expect(plan.featureIds, isEmpty);
      expect(plan.storyIds, isEmpty);
      expect(plan.releaseDate, isNull);
    });
  });

  group('the epics a release covers', () {
    test('are the epics it lists', () {
      final release = releaseOf(['epic-b']);
      expect(
        AgileReleaseScope.epicsFor(
                release: release, epics: epics, featuresByEpic: featuresByEpic)
            .map((e) => e.id),
        ['epic-b'],
      );
    });

    test('include the epic reached through a selected feature', () {
      final release = AgileReleasePlan(id: 'r', featureIds: ['feat-a1']);

      expect(
        AgileReleaseScope.scopeEpicIds(
            release: release, featuresByEpic: featuresByEpic),
        {'epic-a'},
        reason: 'picking a feature must pull in the epic above it',
      );
    });
  });

  group('milestones come with the work, not from the user', () {
    test('a story milestone reaches the epic through its feature', () {
      expect(
        AgileReleaseScope.milestoneIdsForEpic(
          epic: epicA,
          featuresByEpic: featuresByEpic,
          stories: stories,
        ),
        {'ms-a'},
      );
    });

    test('a work package on the epic WBS item brings its milestones', () {
      final pkg = WorkPackage(
        id: 'pkg-1',
        wbsItemId: 'wbs-2',
        title: 'Billing build',
        milestoneIds: const ['ms-b'],
      );

      expect(
        AgileReleaseScope.milestoneIdsForEpic(
          epic: epicB,
          featuresByEpic: featuresByEpic,
          stories: const [],
          workPackages: [pkg],
        ),
        {'ms-b'},
        reason: 'the review asked for the WBS item to carry the milestone',
      );
    });

    test('a release shows them without re-selecting', () {
      final release = releaseOf(['epic-b']);

      expect(
        AgileReleaseScope.milestonesForRelease(
          release: release,
          epics: epics,
          featuresByEpic: featuresByEpic,
          stories: stories,
          milestones: milestones,
        ).map((m) => m.name),
        ['Billing live'],
      );
    });

    test('milestones no release claims are reported, not hidden', () {
      final release = releaseOf(['epic-a']);

      expect(
        AgileReleaseScope.milestonesOutsideReleases(
          releases: [release],
          epics: epics,
          featuresByEpic: featuresByEpic,
          stories: stories,
          milestones: milestones,
        ).map((m) => m.name),
        ['Billing live', 'Unclaimed review'],
      );
    });
  });

  group('the release plan table', () {
    test('has one row per release and epic, with that epic\'s numbers', () {
      final release = releaseOf(['epic-a', 'epic-b']);

      final rows = AgileReleaseScope.tableRows(
        releases: [release],
        epics: epics,
        featuresByEpic: featuresByEpic,
        stories: stories,
        milestones: milestones,
      );

      expect(rows.length, 2);
      expect(rows.map((r) => r.epic?.title), ['Customer onboarding', 'Billing']);
      expect(rows.first.milestones.map((m) => m.name), ['Onboarding signed off']);
      expect(rows.first.storyCount, 2,
          reason: 'both stories under the epic are credited when the epic is in scope');
      expect(rows.first.storyPoints, 8);
    });

    test('a release with no epic still gets a row, so it is not invisible', () {
      final release = releaseOf(const [], storyIds: ['s-b1']);

      final rows = AgileReleaseScope.tableRows(
        releases: [release],
        epics: epics,
        featuresByEpic: featuresByEpic,
        stories: stories,
        milestones: milestones,
      );

      expect(rows.length, 1);
      expect(rows.single.epic, isNull);
      expect(rows.single.storyCount, 1);
      expect(rows.single.storyPoints, 8);
    });
  });

  group('the epic/milestone reference', () {
    test('lists every epic with the milestones tied to it', () {
      final rows = AgileReleaseScope.epicMilestoneRows(
        epics: epics,
        featuresByEpic: featuresByEpic,
        stories: stories,
        milestones: milestones,
      );

      expect(rows.map((r) => r.epic.title),
          ['Customer onboarding', 'Billing', 'Reporting']);
      expect(rows.first.milestones.map((m) => m.name), ['Onboarding signed off']);
      expect(rows.last.milestones, isEmpty);
    });
  });
}
