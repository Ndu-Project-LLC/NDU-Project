import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/screens/gantt_screen.dart';

/// Regression tests for the Gantt row builder.
///
/// The product owner reported (2026-09-10) that the Gantt was not showing all
/// of the work packages. Two silent drops were responsible:
///   1. every `ActivityType.summary` node was skipped — and the WBS import
///      classification falls back to `summary`, so unrecognised work packages
///      disappeared outright;
///   2. any activity missing either date was skipped without explanation.
///
/// Containers must instead roll their window up from their descendants, and
/// undated packages must be counted and surfaced.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ScheduleActivity activity({
    required String id,
    required int level,
    required String code,
    required String name,
    required ActivityType type,
    ScheduleDomain domain = ScheduleDomain.engineering,
    DateTime? start,
    DateTime? end,
    double? duration,
    List<ScheduleActivity> children = const [],
  }) {
    return ScheduleActivity(
      id: id,
      level: level,
      code: code,
      name: name,
      type: type,
      domain: domain,
      startDate: start,
      endDate: end,
      duration: duration,
      dependencies: const [],
      aiGenerated: false,
      children: children,
    );
  }

  Future<ScheduleProvider> pumpGantt(
    WidgetTester tester,
    List<ScheduleActivity> activities,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = ScheduleProvider();
    provider.setup(projectName: 'Test Project', deliveryModel: 'WATERFALL');
    provider.setActivities(activities);

    await tester.pumpWidget(
      ChangeNotifierProvider<ScheduleProvider>.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: GanttScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();
    return provider;
  }

  testWidgets('container work packages are drawn with a rolled-up window',
      (tester) async {
    final leaf = activity(
      id: 'l1',
      level: 2,
      code: '1.1',
      name: 'Design Package',
      type: ActivityType.task,
      start: DateTime(2026, 1, 5),
      end: DateTime(2026, 1, 9),
    );
    // A summary-typed container carrying no dates of its own — previously
    // dropped even though it wraps real, dated work.
    final container = activity(
      id: 'c1',
      level: 1,
      code: '1',
      name: 'Engineering Deliverable',
      type: ActivityType.summary,
      children: [leaf],
    );
    final root = activity(
      id: 'root',
      level: 0,
      code: '0',
      name: 'Test Project',
      type: ActivityType.summary,
      children: [container],
    );

    await pumpGantt(tester, [root]);

    expect(find.text('Design Package'), findsOneWidget);
    expect(find.text('Engineering Deliverable'), findsOneWidget);
    // The project root is the schedule itself, never its own row.
    expect(find.text('Test Project'), findsNothing);
    expect(find.text('2 activities displayed. 0 on critical path.'
        ' Use "Run CPM" in the Builder tab to recompute dates and critical path.'),
        findsOneWidget);
  });

  testWidgets('undated work packages are counted, not silently hidden',
      (tester) async {
    final dated = activity(
      id: 'l1',
      level: 1,
      code: '1',
      name: 'Dated Package',
      type: ActivityType.task,
      start: DateTime(2026, 1, 5),
      end: DateTime(2026, 1, 9),
    );
    final undated = activity(
      id: 'l2',
      level: 1,
      code: '2',
      name: 'Undated Package',
      type: ActivityType.task,
      domain: ScheduleDomain.procurement,
    );
    final root = activity(
      id: 'root',
      level: 0,
      code: '0',
      name: 'Test Project',
      type: ActivityType.summary,
      children: [dated, undated],
    );

    await pumpGantt(tester, [root]);

    expect(find.text('Dated Package'), findsOneWidget);
    expect(find.text('Undated Package'), findsNothing);
    expect(find.textContaining('1 work package has no dates yet'),
        findsOneWidget);
  });

  testWidgets('a package with only one date is placed using its duration',
      (tester) async {
    // CPM may not have run yet, so only the start is filled in.
    final partial = activity(
      id: 'l1',
      level: 1,
      code: '1',
      name: 'Partial Dates Package',
      type: ActivityType.task,
      start: DateTime(2026, 2, 1),
      duration: 5,
    );
    final root = activity(
      id: 'root',
      level: 0,
      code: '0',
      name: 'Test Project',
      type: ActivityType.summary,
      children: [partial],
    );

    await pumpGantt(tester, [root]);

    expect(find.text('Partial Dates Package'), findsOneWidget);
    expect(find.textContaining('have no dates yet'), findsNothing);
    // 1 Feb → 5 Feb inclusive.
    expect(find.text('5d'), findsOneWidget);
  });

  testWidgets('a lone dated activity with no children is still drawn',
      (tester) async {
    final only = activity(
      id: 'only',
      level: 0,
      code: '1',
      name: 'Standalone Package',
      type: ActivityType.task,
      start: DateTime(2026, 3, 1),
      end: DateTime(2026, 3, 3),
    );

    await pumpGantt(tester, [only]);

    expect(find.text('Standalone Package'), findsOneWidget);
    expect(find.text('No activities yet'), findsNothing);
  });

  testWidgets('a fully undated tree reports rather than showing empty state',
      (tester) async {
    final root = activity(
      id: 'root',
      level: 0,
      code: '0',
      name: 'Test Project',
      type: ActivityType.summary,
      children: [
        activity(
          id: 'c1',
          level: 1,
          code: '1',
          name: 'Undated Branch',
          type: ActivityType.summary,
          children: [
            activity(
              id: 'l1',
              level: 2,
              code: '1.1',
              name: 'Undated Leaf',
              type: ActivityType.task,
            ),
          ],
        ),
      ],
    );

    await pumpGantt(tester, [root]);

    expect(find.text('No activities yet'), findsOneWidget);
  });
}
