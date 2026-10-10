// Regression tests for the on-page screen navigator added to the Agile
// Delivery flow (Agile Delivery Model, Scrum Configuration, Capacity
// Planning):
//
//  1. The navigator mirrors the sidebar selector's Agile Delivery screens
//     overall (12 steps, in sidebar order), including Scrum Configuration and
//     Capacity Planning, which have no sidebar entry of their own.
//  2. It marks the current step and badges the upcoming one "NEXT", with an
//     "Up next: …" pill so it is always clear which screens come next.
//  3. Tapping a step calls onStepTap; tapping the current step is a no-op.
//  4. Each of the three screens renders the navigator at the top with the
//     right current step and next-screen hint.
// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/agile_capacity_planning_screen.dart';
import 'package:ndu_project/screens/agile_delivery_model_screen.dart';
import 'package:ndu_project/screens/agile_scrum_config_screen.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/screen_flow_navigator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  const fakeSteps = [
    SidebarItem(checkpoint: 'a', label: 'Alpha'),
    SidebarItem(checkpoint: 'b', label: 'Bravo'),
    SidebarItem(checkpoint: 'c', label: 'Charlie'),
    SidebarItem(checkpoint: 'd', label: 'Delta'),
  ];

  group('ScreenFlowNavigator', () {
    testWidgets('shows the whole flow with current and next steps marked',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScreenFlowNavigator(
                steps: fakeSteps,
                currentCheckpoint: 'b',
                onStepTap: _noopStepTap,
              ),
            ),
          ),
        ),
      );

      // Every screen of the flow is visible at once.
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Bravo'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('Delta'), findsOneWidget);

      // The header states position and the next screen explicitly.
      expect(find.text('Step 2 of 4 · You are here: Bravo'), findsOneWidget);
      expect(find.text('Up next: Charlie'), findsOneWidget);

      // The upcoming step is badged NEXT.
      expect(find.text('NEXT'), findsOneWidget);
    });

    testWidgets('tapping a step calls onStepTap; current step is a no-op',
        (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScreenFlowNavigator(
                steps: fakeSteps,
                currentCheckpoint: 'b',
                onStepTap: (step) => tapped.add(step.checkpoint),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Delta'));
      await tester.pump();
      expect(tapped, ['d']);

      await tester.tap(find.text('Bravo'));
      await tester.pump();
      expect(tapped, ['d'], reason: 'tapping the current step must do nothing');
    });
  });

  test('agileDeliverySteps reflects the selector screens overall', () {
    final steps = PlanningPhaseNavigation.agileDeliverySteps;
    expect(steps.map((s) => s.checkpoint).toList(), [
      'agile_delivery_model',
      'agile_scrum_config',
      'agile_capacity_planning',
      'agile_backlog_governance',
      'agile_team_structure',
      'agile_epics_features',
      'agile_kanban_config',
      'agile_acceptance_criteria',
      'agile_sprint_calendar',
      'agile_release_plan',
      'agile_metrics_planning',
      'agile_map_out',
    ]);

    // The two pages missing from the sidebar selector are present in flow
    // order — right after the first page.
    final labels = steps.map((s) => s.label).toList();
    expect(labels[1], 'Scrum Configuration');
    expect(labels[2], 'Capacity Planning');

    // Kanban Configuration is a breakdown of Epics & Features, not a
    // standalone step before it, and Metrics Planning precedes Agile Map Out
    // so the metrics a dashboard reports are defined before it is mapped.
    expect(
      steps.map((s) => s.checkpoint).toList().indexOf('agile_kanban_config'),
      greaterThan(
          steps.map((s) => s.checkpoint).toList().indexOf('agile_epics_features')),
    );
    expect(
      steps.map((s) => s.checkpoint).toList().indexOf('agile_metrics_planning'),
      lessThan(steps.map((s) => s.checkpoint).toList().indexOf('agile_map_out')),
    );
  });

  group('screen wiring', () {
    Future<void> pumpScreen(WidgetTester tester, Widget screen,
        {Size size = const Size(2000, 1200)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final provider = ProjectDataProvider();
      provider.updateProjectData(ProjectDataModel().copyWith(projectId: 'p1'));

      await tester.pumpWidget(
        ProjectDataInherited(
          provider: provider,
          child: ChangeNotifierProvider<ProjectDataProvider>.value(
            value: provider,
            child: MaterialApp(home: screen),
          ),
        ),
      );
      // Bounded pumps: the screens may kick off auto-AI generation, so
      // pumpAndSettle could spin.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      // The screens load data from Firestore, which has no platform handler
      // under `flutter test` — let the real event loop run so `_isLoading`
      // clears and the content renders.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1500)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    List<Object> takeAllExceptions(WidgetTester tester) {
      final errors = <Object>[];
      Object? error;
      while ((error = tester.takeException()) != null) {
        errors.add(error!);
      }
      return errors;
    }

    testWidgets('first page marks itself and shows Scrum Configuration next',
        (tester) async {
      await pumpScreen(tester, const AgileDeliveryModelScreen());
      expect(takeAllExceptions(tester), isEmpty);

      expect(find.text('Step 1 of 12 · You are here: Agile Delivery Model'),
          findsOneWidget);
      expect(find.text('Up next: Scrum Configuration'), findsOneWidget);
    });

    testWidgets('Scrum Configuration shows the flow and Capacity Planning next',
        (tester) async {
      await pumpScreen(tester, const AgileScrumConfigScreen());
      expect(takeAllExceptions(tester), isEmpty);

      expect(find.text('Step 2 of 12 · You are here: Scrum Configuration'),
          findsOneWidget);
      expect(find.text('Up next: Capacity Planning'), findsOneWidget);
      // The whole route is visible up top, including the previous screen.
      expect(find.text('Agile Delivery Model'), findsWidgets);
    });

    testWidgets('Capacity Planning shows the flow and what follows it',
        (tester) async {
      await pumpScreen(tester, const AgileCapacityPlanningScreen());
      expect(takeAllExceptions(tester), isEmpty);

      expect(find.text('Step 3 of 12 · You are here: Capacity Planning'),
          findsOneWidget);
      expect(find.text('Up next: Backlog Governance'), findsOneWidget);
    });
  });
}

void _noopStepTap(SidebarItem step) {}
