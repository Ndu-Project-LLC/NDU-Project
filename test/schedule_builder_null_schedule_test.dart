import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/schedule/screens/builder_screen.dart';
import 'package:ndu_project/schedule/screens/gantt_screen.dart';
import 'package:ndu_project/schedule/screens/list_view_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Schedule Builder null schedule handling', () {
    testWidgets('BuilderScreen shows loading indicator when schedule is null',
        (tester) async {
      // Set up a wide viewport to avoid overflow issues
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Create a ScheduleProvider WITHOUT calling setup() — schedule will be null
      final scheduleProvider = ScheduleProvider();
      final wbsProvider = WBSProvider();
      final costEstimateProvider = CostEstimateProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ScheduleProvider>.value(
                value: scheduleProvider),
            ChangeNotifierProvider<WBSProvider>.value(value: wbsProvider),
            ChangeNotifierProvider<CostEstimateProvider>.value(
                value: costEstimateProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(body: BuilderScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Should show loading indicator instead of crashing
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading schedule...'), findsOneWidget);
      // Should NOT have crashed — no assertion errors
    });

    testWidgets('BuilderScreen does not crash when schedule is null',
        (tester) async {
      // This test specifically verifies no crash occurs
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final scheduleProvider = ScheduleProvider();
      final wbsProvider = WBSProvider();
      final costEstimateProvider = CostEstimateProvider();

      // Should not throw any exceptions
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ScheduleProvider>.value(
                value: scheduleProvider),
            ChangeNotifierProvider<WBSProvider>.value(value: wbsProvider),
            ChangeNotifierProvider<CostEstimateProvider>.value(
                value: costEstimateProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(body: BuilderScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Verify the widget tree rendered without crashing
      expect(find.byType(BuilderScreen), findsOneWidget);
    });
  });

  group('GanttScreen null schedule handling', () {
    testWidgets('GanttScreen shows loading indicator when schedule is null',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final scheduleProvider = ScheduleProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ScheduleProvider>.value(
          value: scheduleProvider,
          child: const MaterialApp(
            home: Scaffold(body: GanttScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Should show loading indicator instead of crashing
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading schedule...'), findsOneWidget);
    });

    testWidgets('GanttScreen does not crash when schedule is null',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final scheduleProvider = ScheduleProvider();

      // Should not throw any exceptions
      await tester.pumpWidget(
        ChangeNotifierProvider<ScheduleProvider>.value(
          value: scheduleProvider,
          child: const MaterialApp(
            home: Scaffold(body: GanttScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(GanttScreen), findsOneWidget);
    });

    testWidgets('GanttScreen renders normally after schedule is set up',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final scheduleProvider = ScheduleProvider();
      scheduleProvider.setup(
        projectName: 'Test Project',
        deliveryModel: 'WATERFALL',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ScheduleProvider>.value(
          value: scheduleProvider,
          child: const MaterialApp(
            home: Scaffold(body: GanttScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Should render the Gantt screen (empty state since no activities with dates)
      expect(find.text('No activities yet'), findsOneWidget);
      expect(find.text('Loading schedule...'), findsNothing);
    });
  });

  group('ListViewScreen null schedule handling', () {
    testWidgets('ListViewScreen shows loading indicator when schedule is null',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final scheduleProvider = ScheduleProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ScheduleProvider>.value(
          value: scheduleProvider,
          child: const MaterialApp(
            home: Scaffold(body: ListViewScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Should show loading indicator instead of crashing
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading schedule...'), findsOneWidget);
    });

    testWidgets('ListViewScreen does not crash when schedule is null',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final scheduleProvider = ScheduleProvider();

      // Should not throw any exceptions
      await tester.pumpWidget(
        ChangeNotifierProvider<ScheduleProvider>.value(
          value: scheduleProvider,
          child: const MaterialApp(
            home: Scaffold(body: ListViewScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(ListViewScreen), findsOneWidget);
    });

    testWidgets('ListViewScreen renders normally after schedule is set up',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final scheduleProvider = ScheduleProvider();
      scheduleProvider.setup(
        projectName: 'Test Project',
        deliveryModel: 'WATERFALL',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ScheduleProvider>.value(
          value: scheduleProvider,
          child: const MaterialApp(
            home: Scaffold(body: ListViewScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Should render the List View screen without loading indicator
      expect(find.byType(ListViewScreen), findsOneWidget);
      expect(find.text('Loading schedule...'), findsNothing);
    });
  });

  group('Schedule screens handle schedule becoming null', () {
    testWidgets('GanttScreen handles schedule being reset to null',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final scheduleProvider = ScheduleProvider();
      scheduleProvider.setup(
        projectName: 'Test Project',
        deliveryModel: 'WATERFALL',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ScheduleProvider>.value(
          value: scheduleProvider,
          child: const MaterialApp(
            home: Scaffold(body: GanttScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Initially renders normally
      expect(find.text('No activities yet'), findsOneWidget);

      // Reset the schedule to null
      scheduleProvider.resetSchedule();
      await tester.pump();
      await tester.pump();

      // Should show loading indicator instead of crashing
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading schedule...'), findsOneWidget);
    });

    testWidgets('ListViewScreen handles schedule being reset to null',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final scheduleProvider = ScheduleProvider();
      scheduleProvider.setup(
        projectName: 'Test Project',
        deliveryModel: 'WATERFALL',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ScheduleProvider>.value(
          value: scheduleProvider,
          child: const MaterialApp(
            home: Scaffold(body: ListViewScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Initially renders normally (with List View content)
      expect(find.byType(ListViewScreen), findsOneWidget);

      // Reset the schedule to null
      scheduleProvider.resetSchedule();
      await tester.pump();
      await tester.pump();

      // Should show loading indicator instead of crashing
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading schedule...'), findsOneWidget);
    });
  });
}
