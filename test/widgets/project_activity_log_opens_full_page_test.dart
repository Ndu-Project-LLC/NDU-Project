import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/models/project_activity.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';

/// Seeded with the `activity_custom_` prefix so
/// [ProjectIntelligenceService.rebuildActivityLog] (invoked by
/// `updateProjectData`) preserves the entry instead of dropping it.
ProjectActivity _activity({
  required String id,
  required String title,
  String? assignedTo,
  String sourceSection = 'quality_management',
  ProjectActivityStatus status = ProjectActivityStatus.pending,
}) =>
    ProjectActivity(
      id: 'activity_custom_$id',
      title: title,
      description: 'Activity description',
      sourceSection: sourceSection,
      phase: 'Planning Phase',
      discipline: 'Quality',
      role: 'Quality Owner',
      assignedTo: assignedTo,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      status: status,
    );

void main() {
  testWidgets(
      'Open activity log navigates to the full activities log page, '
      'not the reduced overlay panel', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = ProjectDataProvider()
      ..updateProjectData(
        ProjectDataModel().copyWith(
          projectId: 'proj-1',
          projectName: 'Fresh Produce Delivery App',
          projectActivities: [
            _activity(id: 'a', title: 'Review test plan', assignedTo: 'Alex'),
          ],
        ),
      );
    addTearDown(provider.dispose);

    // Stand in for the real log page: the routed screen is exercised through
    // a `GoRouter` so `context.push` resolves, exactly as in the app.
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: UnifiedPhaseHeader(title: 'Schedule'),
          ),
        ),
        GoRoute(
          path: '/${AppRoutes.projectActivitiesLog}',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('FULL LOG PAGE')),
          ),
        ),
        GoRoute(
          path: '/${AppRoutes.qualityManagement}',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('QUALITY SCREEN')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProjectDataInherited(
        provider: provider,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // 1. The header affordance opens the outstanding-tasks page.
    await tester.tap(find.byTooltip('1 assigned outstanding task'));
    await tester.pumpAndSettle();
    expect(find.text('Outstanding tasks (1)'), findsOneWidget);
    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'the outstanding tasks should render as a full page, not a dialog',
    );

    // 2. "Open activity log" must route to the full page.
    await tester.tap(find.text('Open activity log'));
    await tester.pumpAndSettle();
    // Drain the debounced autosave the checkpoint update scheduled.
    await tester.pump(const Duration(seconds: 3));

    expect(
      find.text('FULL LOG PAGE'),
      findsOneWidget,
      reason: 'expected navigation to the routed activities log page',
    );

    // 3. The outstanding-tasks page must have been popped.
    expect(
      find.textContaining('Outstanding tasks'),
      findsNothing,
      reason: 'the outstanding-tasks page should have been popped',
    );
  });

  testWidgets('tapping a task row opens the screen that owns the activity',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = ProjectDataProvider()
      ..updateProjectData(
        ProjectDataModel().copyWith(
          projectId: 'proj-1',
          projectName: 'Fresh Produce Delivery App',
          projectActivities: [
            _activity(
              id: 'owned',
              title: 'Review test plan',
              assignedTo: 'Alex',
              // `quality_management` is a known checkpoint, so the row has a
              // source screen to deep-link to.
              sourceSection: 'quality_management',
            ),
            _activity(
              id: 'manual',
              title: 'Hand written note',
              assignedTo: 'Alex',
              sourceSection: 'manual_activity',
            ),
          ],
        ),
      );
    addTearDown(provider.dispose);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: UnifiedPhaseHeader(title: 'Schedule')),
        ),
        GoRoute(
          path: '/${AppRoutes.qualityManagement}',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('QUALITY SCREEN')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProjectDataInherited(
        provider: provider,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.byTooltip('2 assigned outstanding tasks'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    // A mapped source section deep-links to its screen.
    await tester.tap(find.text('Review test plan'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('QUALITY SCREEN'), findsOneWidget);

    // Reopen and check the unmapped source section explains itself instead of
    // navigating somewhere unrelated.
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('2 assigned outstanding tasks'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('Hand written note'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No screen is mapped to "Manual activity"'),
        findsOneWidget);
  });

  testWidgets('search and status filters narrow the task list', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = ProjectDataProvider()
      ..updateProjectData(
        ProjectDataModel().copyWith(
          projectId: 'proj-1',
          projectName: 'Fresh Produce Delivery App',
          projectActivities: [
            _activity(id: 'p1', title: 'Review test plan', assignedTo: 'Alex'),
            _activity(id: 'p2', title: 'Procure quotes', assignedTo: 'Alex'),
            _activity(
              id: 'done',
              title: 'Closed finding',
              assignedTo: 'Alex',
              status: ProjectActivityStatus.implemented,
            ),
          ],
        ),
      );
    addTearDown(provider.dispose);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: UnifiedPhaseHeader(title: 'Schedule')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProjectDataInherited(
        provider: provider,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // 2 pending + 1 implemented, so the badge counts only the pending ones.
    await tester.tap(find.byTooltip('2 assigned outstanding tasks'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    // Default view is the outstanding (pending) set.
    expect(find.text('Review test plan'), findsOneWidget);
    expect(find.text('Procure quotes'), findsOneWidget);
    expect(find.text('Closed finding'), findsNothing);
    expect(find.text('2 of 3 assigned tasks'), findsOneWidget);

    // Search narrows within the pending set.
    await tester.enterText(find.byType(TextField), 'procure');
    await tester.pumpAndSettle();
    expect(find.text('Review test plan'), findsNothing);
    expect(find.text('Procure quotes'), findsOneWidget);
    expect(find.text('1 of 3 assigned tasks'), findsOneWidget);

    // Clearing the search restores the whole pending set.
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('Review test plan'), findsOneWidget);
    expect(find.text('Procure quotes'), findsOneWidget);
    expect(find.text('Closed finding'), findsNothing);

    // The "Implemented" status filter brings the completed task in.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Implemented'));
    await tester.pumpAndSettle();
    expect(find.text('Review test plan'), findsNothing);
    expect(find.text('Closed finding'), findsOneWidget);

    // "All" statuses shows every assigned task.
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.text('Review test plan'), findsOneWidget);
    expect(find.text('Procure quotes'), findsOneWidget);
    expect(find.text('Closed finding'), findsOneWidget);
    expect(find.text('3 assigned tasks'), findsOneWidget);
  });
}
