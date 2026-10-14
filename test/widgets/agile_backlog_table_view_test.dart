// The backlog table is what the review asked for in place of feature cards:
// "you have to see what the story is, what the feature is, it's coming from it
// and of course the [epic] for each one". It also has to keep showing stories
// that no feature claims — those used to disappear entirely, which is how the
// missing feature → story breakdown went unnoticed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/utils/agile_backlog_table.dart';
import 'package:ndu_project/widgets/agile_backlog_table_view.dart';

BacklogTableRow _row(
  String title, {
  int order = 0,
  String epic = 'Customer onboarding',
  String feature = 'Sign up',
  String priority = 'High',
  int points = 3,
  String readiness = 'Draft',
  String sprint = 'Sprint 1',
  String release = 'R1',
  String wbs = '',
  BacklogUnlinkedReason? unlinked,
  String? missingFeatureId,
}) =>
    BacklogTableRow(
      story: AgileTask(
        id: title,
        featureId: unlinked == null ? 'feat-1' : (missingFeatureId ?? ''),
        userStory: title,
        priority: priority,
        storyPoints: points,
        readinessStatus: readiness,
        plannedSprintId: sprint,
        plannedReleaseId: release,
        wbsId: wbs,
        backlogOrder: order,
      ),
      epicTitle: unlinked == null ? epic : '',
      featureTitle: unlinked == null ? feature : '',
      unlinkedReason: unlinked,
      missingFeatureId: missingFeatureId,
    );

Future<void> _pump(
  WidgetTester tester,
  List<BacklogTableRow> rows, {
  int featuresWithoutStories = 0,
}) async {
  tester.view.physicalSize = const Size(2600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AgileBacklogTableView(
            rows: rows,
            featuresWithoutStories: featuresWithoutStories,
            sprintLabel: (id) => id.isEmpty ? 'Unassigned' : 'Sprint 1',
            releaseLabel: (id) => id.isEmpty ? 'Unassigned' : 'R1',
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('a row carries the story, its feature and its epic',
      (tester) async {
    await _pump(tester, [
      _row('Reset password', wbs: 'wbs-9'),
      _row('Invoice totals', epic: 'Billing', feature: 'Invoices'),
    ]);

    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('Customer onboarding'), findsOneWidget);
    expect(find.text('Invoices'), findsOneWidget);
    expect(find.text('Billing'), findsOneWidget);

    // The header is the owner's ask, verbatim: story, feature, epic.
    for (final heading in const [
      'Epic',
      'Feature',
      'Story',
      'Priority',
      'Points',
      'Readiness',
      'Sprint',
      'Release',
      'WBS',
    ]) {
      expect(find.text(heading), findsWidgets, reason: '$heading column missing');
    }
  });

  testWidgets('a story with no feature is shown in its own group',
      (tester) async {
    await _pump(tester, [
      _row('Reset password'),
      _row('Loose story', unlinked: BacklogUnlinkedReason.none),
    ]);

    expect(find.byKey(const ValueKey('backlog-unlinked-section')), findsOneWidget);
    expect(find.text('1 story no feature claims'), findsOneWidget);
    // The unlinked row is listed, with the reason instead of a blank parent.
    expect(find.text('Loose story'), findsOneWidget);
    expect(find.text('No feature set'), findsOneWidget);
    expect(find.text('Why unlinked'), findsOneWidget);
  });

  testWidgets('a story pointing at a deleted feature says which feature',
      (tester) async {
    await _pump(tester, [
      _row('Stale link',
          unlinked: BacklogUnlinkedReason.missing,
          missingFeatureId: 'feat-deleted'),
    ]);

    expect(find.text('Stale link'), findsOneWidget);
    expect(find.textContaining('feat-deleted'), findsOneWidget);
  });

  testWidgets('features with no stories are called out', (tester) async {
    await _pump(tester, [_row('Reset password')], featuresWithoutStories: 2);

    expect(
      find.textContaining('2 features have no stories yet'),
      findsOneWidget,
    );

    // Singular reads correctly, and nothing is claimed when there is no gap.
    await _pump(tester, [_row('Reset password')], featuresWithoutStories: 1);
    expect(find.textContaining('1 feature has no stories yet'), findsOneWidget);

    await _pump(tester, [_row('Reset password')]);
    expect(find.textContaining('no stories yet'), findsNothing);
  });

  testWidgets('an empty backlog shows the empty message, not an empty table',
      (tester) async {
    await _pump(tester, const []);

    expect(find.textContaining('No stories in the backlog yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('backlog-unlinked-section')), findsNothing);
  });

  testWidgets('no unlinked group when every story is placed', (tester) async {
    await _pump(tester, [_row('Reset password')]);

    expect(find.byKey(const ValueKey('backlog-unlinked-section')), findsNothing);
  });

  testWidgets('the table can prioritise a story, and shows its board column',
      (tester) async {
    AgileTask? movedUp;
    AgileTask? movedDown;

    tester.view.physicalSize = const Size(2600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AgileBacklogTableView(
              rows: [_row('Reset password', order: 2)],
              sprintLabel: (id) => id.isEmpty ? 'Unassigned' : 'Sprint 1',
              releaseLabel: (id) => id.isEmpty ? 'Unassigned' : 'R1',
              onMoveUp: (story) => movedUp = story,
              onMoveDown: (story) => movedDown = story,
              boardLabel: (story) => 'Backlog',
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // The table is the default view, so priority has to be workable here.
    expect(find.text('Order'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('Board'), findsOneWidget);
    expect(find.text('Backlog'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('backlog-up-Reset password')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('backlog-down-Reset password')));
    await tester.pump();

    expect(movedUp?.id, 'Reset password');
    expect(movedDown?.id, 'Reset password');
  });

  testWidgets('no board column when the caller does not supply one',
      (tester) async {
    await _pump(tester, [_row('Reset password')]);

    expect(find.text('Board'), findsNothing);
  });
}
