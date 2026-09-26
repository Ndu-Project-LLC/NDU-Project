import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/models/project_activity.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';

/// Seed as a custom activity: [ProjectIntelligenceService.rebuildActivityLog]
/// (invoked by `updateProjectData`) only preserves hand-written activities
/// whose ids carry the `activity_custom_` prefix — every other manually
/// seeded entry is dropped from the rebuilt stream.
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

Widget _headerApp({required double width, required Widget header}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 900)),
        child: Scaffold(body: header),
      ),
    );

void main() {
  testWidgets('desktop header lists pending assigned tasks and assignees',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = ProjectDataProvider()
      ..updateProjectData(
        ProjectDataModel().copyWith(projectActivities: [
          _activity(id: 'assigned', title: 'Review test plan', assignedTo: 'Alex'),
          _activity(id: 'unassigned', title: 'Unassigned draft'),
          _activity(
            id: 'done',
            title: 'Completed task',
            assignedTo: 'Sam',
            status: ProjectActivityStatus.implemented,
          ),
        ]),
      );
    addTearDown(provider.dispose);

    await tester.pumpWidget(_headerApp(
      width: 1280,
      header: ProjectDataInherited(
        provider: provider,
        child: const UnifiedPhaseHeader(title: 'Project overview'),
      ),
    ));

    expect(find.text('Tasks (1)'), findsOneWidget);
    await tester.tap(find.byTooltip('1 assigned outstanding task'));
    await tester.pumpAndSettle();
    // Drain the debounced autosave timer that `updateProjectData` scheduled,
    // so the test ends with no pending timers. Must run before the provider's
    // `dispose` teardown fires (disposal cancels the timer but the framework
    // still flags it in test-mode invariant checks).
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Outstanding tasks (1)'), findsOneWidget);
    expect(find.text('Review test plan'), findsOneWidget);
    expect(find.text('Assigned to: Alex'), findsOneWidget);
  });

  testWidgets('mobile header exposes task action without a project provider',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_headerApp(
      width: 390,
      header: const UnifiedPhaseHeader(title: 'Project overview'),
    ));

    expect(find.text('NDUPROJECT'), findsOneWidget);
    expect(find.byTooltip('Open menu'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('0 assigned outstanding tasks'), findsNothing);
  });

  testWidgets('mobile header lists outstanding tasks when project data exists',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = ProjectDataProvider()
      ..updateProjectData(
        ProjectDataModel().copyWith(projectActivities: [
          _activity(
              id: 'assigned', title: 'Inspect sample', assignedTo: 'Jordan'),
        ]),
      );
    addTearDown(provider.dispose);

    await tester.pumpWidget(_headerApp(
      width: 390,
      header: ProjectDataInherited(
        provider: provider,
        child: const UnifiedPhaseHeader(title: 'Project overview'),
      ),
    ));

    expect(find.byTooltip('1 assigned outstanding task'), findsOneWidget);
    await tester.tap(find.byTooltip('1 assigned outstanding task'));
    await tester.pumpAndSettle();
    // Drain the debounced autosave timer (see the desktop test above).
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Inspect sample'), findsOneWidget);
    expect(find.text('Assigned to: Jordan'), findsOneWidget);
  });
}
