import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/screens/builder_screen.dart';
import 'package:ndu_project/schedule/screens/gantt_screen.dart';
import 'package:ndu_project/schedule/screens/list_view_screen.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';

/// Guards the sections removed from the Schedule Builder: the "Schedule Level
/// Convention" card (the L0…L5—8 legend), the info-only Estimate Basis and
/// Schedule Readiness Rules cards, and the footer note under the activity
/// table. The other Schedule tabs never carried them, so they are checked too.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpBuilder(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final scheduleProvider = ScheduleProvider()
      ..setup(projectName: 'Test Project', deliveryModel: 'WATERFALL');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ScheduleProvider>.value(
              value: scheduleProvider),
          ChangeNotifierProvider<WBSProvider>.value(value: WBSProvider()),
          ChangeNotifierProvider<CostEstimateProvider>.value(
              value: CostEstimateProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BuilderScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the level convention card is gone', (tester) async {
    await pumpBuilder(tester);

    expect(find.text('Schedule Level Convention'), findsNothing);
    expect(find.text('How activity levels map to your delivery model'),
        findsNothing);
    expect(find.text('L0 — L8'), findsNothing);
    expect(find.textContaining('Schedule levels: L0=Project'), findsNothing);
    expect(find.textContaining('Epic / Sub-Deliverable'), findsNothing);
  });

  testWidgets('the info-only cards and footer note are gone', (tester) async {
    await pumpBuilder(tester);

    expect(find.text('Estimate Basis'), findsNothing);
    expect(find.text('Schedule Readiness Rules'), findsNothing);
    expect(find.text('READY TO START'), findsNothing);
    expect(find.textContaining('GATES'), findsNothing);
    expect(
      find.textContaining('populated from your WBS and Work Packages'),
      findsNothing,
    );
  });

  testWidgets('the in-page timeline and activity table are gone',
      (tester) async {
    await pumpBuilder(tester);

    // Both views duplicated the Gantt and List View tabs, so the page no
    // longer renders them; per-activity dates now live in the row editor.
    expect(find.text('Project Timeline'), findsNothing);
    expect(find.text('Activity Schedule'), findsNothing);
  });

  testWidgets('the Builder still renders its live sections', (tester) async {
    await pumpBuilder(tester);

    // The page really rendered, so the assertions above are not vacuous.
    expect(find.byType(BuilderScreen), findsOneWidget);
    expect(find.text('Add Activity'), findsOneWidget);
    expect(find.text('From Work Packages'), findsOneWidget);
    expect(find.text('Activity Tree'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
  });

  testWidgets('the Gantt tab does not render a level convention card',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final scheduleProvider = ScheduleProvider()
      ..setup(projectName: 'Test Project', deliveryModel: 'WATERFALL');

    await tester.pumpWidget(
      ChangeNotifierProvider<ScheduleProvider>.value(
        value: scheduleProvider,
        child: const MaterialApp(
          home: Scaffold(body: GanttScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Schedule Level Convention'), findsNothing);
    expect(find.text('L0 — L8'), findsNothing);
    expect(find.textContaining('Schedule levels: L0=Project'), findsNothing);
  });

  testWidgets('the List View tab does not render a level convention card',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final scheduleProvider = ScheduleProvider()
      ..setup(projectName: 'Test Project', deliveryModel: 'WATERFALL');

    await tester.pumpWidget(
      ChangeNotifierProvider<ScheduleProvider>.value(
        value: scheduleProvider,
        child: const MaterialApp(
          home: Scaffold(body: ListViewScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Schedule Level Convention'), findsNothing);
    expect(find.text('L0 — L8'), findsNothing);
    expect(find.textContaining('Schedule levels: L0=Project'), findsNothing);
  });
}
