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
  ProjectActivityStatus status = ProjectActivityStatus.pending,
}) =>
    ProjectActivity(
      id: 'activity_custom_$id',
      title: title,
      description: 'Activity description',
      sourceSection: 'quality_management',
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
          builder: (_, __) => Scaffold(
            body: UnifiedPhaseHeader(title: 'Schedule'),
          ),
        ),
        GoRoute(
          path: '/${AppRoutes.projectActivitiesLog}',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('FULL LOG PAGE')),
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

    // 1. The header affordance opens the outstanding-tasks dialog.
    await tester.tap(find.byTooltip('1 assigned outstanding task'));
    await tester.pumpAndSettle();
    expect(find.text('Outstanding tasks (1)'), findsOneWidget);

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

    // 3. The reduced overlay panel must not be what renders.
    expect(
      find.textContaining('Outstanding tasks'),
      findsNothing,
      reason: 'the outstanding-tasks dialog should have been popped',
    );
  });
}
