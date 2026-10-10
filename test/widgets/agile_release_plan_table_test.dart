// Guards the Release Plan table the review asked for: the epics the project
// already has, the milestones tied to them, and one row per release and epic —
// all rendered from rows, so no Firestore is needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/agile_release_plan.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/agile_release_scope.dart';
import 'package:ndu_project/widgets/agile_release_plan_table.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
  await tester.pump();
}

void main() {
  final epicA = Epic(id: 'epic-a', title: 'Customer onboarding', wbsId: 'wbs-1');
  final featureA1 = Feature(id: 'feat-a1', epicId: 'epic-a', title: 'Sign up');
  final featuresByEpic = {
    'epic-a': [featureA1],
  };
  final milestones = [
    Milestone(id: 'ms-a', name: 'Onboarding signed off'),
    Milestone(id: 'ms-solo', name: 'Unclaimed review'),
  ];
  final stories = [
    AgileTask(
      id: 's-a1',
      featureId: 'feat-a1',
      epicId: 'epic-a',
      storyPoints: 5,
      milestoneIds: const ['ms-a'],
    ),
  ];

  testWidgets('a release row shows its epic and the auto-linked milestone',
      (tester) async {
    final release = AgileReleasePlan(
      id: 'rel-1',
      releaseLabel: 'Release 1',
      epicIds: const ['epic-a'],
    );
    final rows = AgileReleaseScope.tableRows(
      releases: [release],
      epics: [epicA],
      featuresByEpic: featuresByEpic,
      stories: stories,
      milestones: milestones,
    );
    final epicRows = AgileReleaseScope.epicMilestoneRows(
      epics: [epicA],
      featuresByEpic: featuresByEpic,
      stories: stories,
      milestones: milestones,
    );

    await _pump(
      tester,
      AgileReleasePlanTableView(
        rows: rows,
        epicRows: epicRows,
        unclaimedMilestones: AgileReleaseScope.milestonesOutsideReleases(
          releases: [release],
          epics: [epicA],
          featuresByEpic: featuresByEpic,
          stories: stories,
          milestones: milestones,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Project epics & milestones'), findsOneWidget);
    expect(find.text('Release plan'), findsOneWidget);
    expect(find.text('Release 1'), findsOneWidget);
    expect(find.text('Customer onboarding'), findsNWidgets(2),
        reason: 'once in the project reference, once on the release row');
    expect(find.text('Onboarding signed off'), findsNWidgets(2));
    // The milestone the release does not claim is reported, not hidden.
    expect(
        find.byKey(const ValueKey('release-plan-unclaimed-milestones')),
        findsOneWidget);
    expect(find.textContaining('Unclaimed review'), findsOneWidget);
  });

  testWidgets('a release with no epic still gets an explicit row',
      (tester) async {
    final release = AgileReleasePlan(
      id: 'rel-2',
      releaseLabel: 'Release 2',
      storyIds: const ['s-a1'],
    );
    final rows = AgileReleaseScope.tableRows(
      releases: [release],
      epics: [epicA],
      featuresByEpic: featuresByEpic,
      stories: stories,
      milestones: milestones,
    );

    await _pump(
      tester,
      AgileReleasePlanTableView(rows: rows, epicRows: const []),
    );

    expect(find.text('No epic linked'), findsOneWidget);
    expect(find.text('Release plan'), findsOneWidget);
  });

  testWidgets('nothing to show says so instead of rendering empty tables',
      (tester) async {
    await _pump(
      tester,
      const AgileReleasePlanTableView(rows: [], epicRows: []),
    );

    expect(find.text('Project epics & milestones'), findsNothing);
    expect(find.textContaining('No release plans yet'), findsOneWidget);
  });
}
