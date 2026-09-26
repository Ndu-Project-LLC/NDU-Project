import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/routing/shimmer_page_transition.dart';
import 'package:ndu_project/services/project_intelligence_service.dart';
import 'package:ndu_project/utils/continuity_route_observer.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';

/// Mirrors [AppRouter.main]'s wiring (page names via [shimmerTransitionPage],
/// [ContinuityRouteObserver] attached) but without Firebase/auth redirects, so
/// the continuity-refresh-on-navigation behavior can be exercised headlessly.
GoRouter _testRouter() {
  return GoRouter(
    initialLocation: '/issue-management',
    observers: [ContinuityRouteObserver.instance],
    routes: [
      GoRoute(
        name: 'issue-management',
        path: '/issue-management',
        pageBuilder: (c, s) => shimmerTransitionPage(
          state: s,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => context.push('/lessons-learned'),
                  child: const Text('go to lessons'),
                ),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        name: 'lessons-learned',
        path: '/lessons-learned',
        pageBuilder: (c, s) => shimmerTransitionPage(
          state: s,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => context.push('/dashboard'),
                  child: const Text('go to dashboard'),
                ),
              ),
            ),
          ),
        ),
      ),
      // A non-project route that must NOT trigger a continuity refresh.
      GoRoute(
        name: 'dashboard',
        path: '/dashboard',
        pageBuilder: (c, s) => shimmerTransitionPage(
          state: s,
          child: const Scaffold(body: Center(child: Text('dashboard'))),
        ),
      ),
    ],
  );
}

void main() {
  testWidgets('navigating page-to-page refreshes the continuity snapshot',
      (tester) async {
    final provider = ProjectDataProvider();
    provider.updateProjectData(
      ProjectDataModel().copyWith(projectId: 'proj-1', projectName: 'Test'),
    );
    expect(ProjectDataProvider.active, same(provider));

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _testRouter()),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 800));

    // Initial push to /issue-management already prepared its snapshot.
    var notes = provider.projectData.planningNotes;
    expect(
      notes['${ProjectIntelligenceService.continuityContextPrefix}'
          'issue_management'],
      isNotEmpty,
    );
    expect(
      notes[ProjectIntelligenceService.continuityCheckpointKey],
      'issue_management',
    );

    // Navigate to the next page — snapshot for the destination is refreshed.
    await tester.tap(find.text('go to lessons'));
    await tester.pumpAndSettle(const Duration(milliseconds: 800));

    notes = provider.projectData.planningNotes;
    expect(
      notes['${ProjectIntelligenceService.continuityContextPrefix}'
          'lessons_learned'],
      isNotEmpty,
    );
    expect(
      notes[ProjectIntelligenceService.continuityCheckpointKey],
      'lessons_learned',
    );

    // A non-project route (dashboard) must not touch the continuity keys:
    // the snapshot for the last real checkpoint stays intact.
    await tester.tap(find.text('go to dashboard'));
    await tester.pumpAndSettle(const Duration(milliseconds: 800));

    notes = provider.projectData.planningNotes;
    expect(
      notes.containsKey('${ProjectIntelligenceService.continuityContextPrefix}'
          'dashboard'),
      isFalse,
    );
    expect(
      notes[ProjectIntelligenceService.continuityCheckpointKey],
      'lessons_learned',
    );

    // Drain the debounced autosave timer so the test ends cleanly.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
      'sidebar Next/Back refreshes continuity across phase boundaries',
      (tester) async {
    final provider = ProjectDataProvider();
    provider.updateProjectData(
      ProjectDataModel().copyWith(projectId: 'proj-1', projectName: 'CrossPhase'),
    );
    expect(ProjectDataProvider.active, same(provider));

    await tester.pumpWidget(
      ProjectDataInherited(
        provider: provider,
        child: MaterialApp(
          // Attached for fidelity with AppRouter.main; the Next/Back routes
          // below have no route name, so the refresh comes from
          // PhaseTransitionHelper's explicit prepareForCheckpoint call —
          // exactly like the app's wizard-style sidebar navigation.
          navigatorObservers: [ContinuityRouteObserver.instance],
          home: const _FepSummaryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Next: FEP Summary (Front End Planning) → Project Framework
    // (Planning Phase). Crosses a phase boundary → PhaseTransitionRoute.
    await tester.tap(find.text('Next → Project Framework'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    // The phase-transition overlay announces the destination phase.
    expect(find.text('Entering Planning Phase'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    var notes = provider.projectData.planningNotes;
    expect(
      notes['${ProjectIntelligenceService.continuityContextPrefix}'
          'project_framework'],
      isNotEmpty,
    );
    expect(
      notes[ProjectIntelligenceService.continuityCheckpointKey],
      'project_framework',
    );
    expect(find.text('planning page'), findsOneWidget);

    // Back: Project Framework (Planning Phase) → FEP Summary
    // (Front End Planning). Crosses the boundary in reverse.
    await tester.tap(find.text('← Back to FEP Summary'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Entering Front End Planning'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    notes = provider.projectData.planningNotes;
    expect(
      notes['${ProjectIntelligenceService.continuityContextPrefix}'
          'fep_summary'],
      isNotEmpty,
    );
    expect(
      notes[ProjectIntelligenceService.continuityCheckpointKey],
      'fep_summary',
    );

    // Drain the debounced autosave timer so the test ends cleanly.
    await tester.pump(const Duration(seconds: 3));
  });
}

/// Home page standing in for the Front End Planning – Summary screen.
class _FepSummaryPage extends StatelessWidget {
  const _FepSummaryPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          // Same call the wizard-style Next buttons make, including the
          // source/destination checkpoints so the phase change is detected.
          onPressed: () => PhaseTransitionHelper.pushPhaseAware<void>(
            context: context,
            builder: (_) => const _ProjectFrameworkPage(),
            destinationCheckpoint: 'project_framework',
            sourceCheckpoint: 'fep_summary',
          ),
          child: const Text('Next → Project Framework'),
        ),
      ),
    );
  }
}

/// Destination page standing in for the Planning Phase – Project Framework
/// screen, with the matching Back button.
class _ProjectFrameworkPage extends StatelessWidget {
  const _ProjectFrameworkPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('planning page'),
            TextButton(
              onPressed: () => PhaseTransitionHelper.pushPhaseAware<void>(
                context: context,
                builder: (_) => const _FepSummaryPage(),
                destinationCheckpoint: 'fep_summary',
                sourceCheckpoint: 'project_framework',
              ),
              child: const Text('← Back to FEP Summary'),
            ),
          ],
        ),
      ),
    );
  }
}