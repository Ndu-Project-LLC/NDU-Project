import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/project_intelligence_service.dart';
import 'package:ndu_project/utils/continuity_route_observer.dart';

void main() {
  group('checkpointForRouteName', () {
    test('clean kebab→snake conversions resolve to sidebar checkpoints', () {
      expect(checkpointForRouteName('issue-management'), 'issue_management');
      expect(checkpointForRouteName('lessons-learned'), 'lessons_learned');
      expect(checkpointForRouteName('project-baseline'), 'project_baseline');
      expect(checkpointForRouteName('fep-security'), 'fep_security');
      expect(checkpointForRouteName('schedule'), 'schedule');
      expect(checkpointForRouteName('cost-estimate'), 'cost_estimate');
      expect(checkpointForRouteName('scope-tracking-plan'), 'scope_tracking_plan');
      expect(
        checkpointForRouteName('project-plan-detailed-schedule'),
        'project_plan_detailed_schedule',
      );
      expect(
        checkpointForRouteName('actual-vs-planned-gap-analysis'),
        'actual_vs_planned_gap_analysis',
      );
    });

    test('override map covers route names that do not convert 1:1', () {
      expect(checkpointForRouteName('initiation-phase'), 'business_case');
      expect(checkpointForRouteName('ssher-stacked'), 'ssher');
      expect(checkpointForRouteName('team-training-building'), 'team_training');
      expect(
        checkpointForRouteName('gap-analysis-scope-reconciliation'),
        'gap_analysis_scope_reconcillation', // preserved typo in the sidebar
      );
      expect(
        checkpointForRouteName('project-plan-level-1-schedule'),
        'project_plan_level1_schedule',
      );
      expect(
        checkpointForRouteName('change-management-module'),
        'change_management',
      );
      expect(checkpointForRouteName('risk-tracking-screen'), 'risk_tracking');
      expect(
        checkpointForRouteName('agile-project-hub'),
        'agile_development_iterations',
      );
      expect(checkpointForRouteName('deliverable-roadmap-agile-map-out'),
          'agile_map_out');
    });

    test('non-project routes are skipped (return null)', () {
      for (final name in [
        'dashboard',
        'home',
        'landing',
        'sign-in',
        'create-account',
        'pricing',
        'settings',
        'program-dashboard',
        'portfolio-dashboard',
        'privacy-policy',
        'admin-home',
        'two-factor-verification',
      ]) {
        expect(checkpointForRouteName(name), isNull, reason: name);
      }
      expect(checkpointForRouteName(null), isNull);
      expect(checkpointForRouteName(''), isNull);
      expect(checkpointForRouteName('  '), isNull);
    });
  });

  group('ContinuityRouteObserver', () {
    testWidgets('prepares deterministic context when a project is loaded',
        (tester) async {
      final provider = ProjectDataProvider();
      provider.updateProjectData(
        ProjectDataModel().copyWith(projectId: 'proj-1', projectName: 'Test'),
      );
      expect(ProjectDataProvider.active, same(provider));

      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [ContinuityRouteObserver.instance],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: 'issue-management'),
                  builder: (_) =>
                      const Scaffold(body: Text('issue management page')),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('go'));
      await tester.pump();

      final notes = provider.projectData.planningNotes;
      expect(
        notes[
            '${ProjectIntelligenceService.continuityContextPrefix}issue_management'],
        isNotEmpty,
      );
      expect(
        notes[ProjectIntelligenceService.continuityCheckpointKey],
        'issue_management',
      );

      // Drain the debounced autosave timer so the test ends cleanly.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('does nothing when no project is loaded', (tester) async {
      final provider = ProjectDataProvider();
      expect(ProjectDataProvider.active, same(provider));

      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [ContinuityRouteObserver.instance],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: 'issue-management'),
                  builder: (_) =>
                      const Scaffold(body: Text('issue management page')),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('go'));
      await tester.pump();

      // Empty model → observer bails before marking dirty: no continuity
      // snapshot, no pending autosave timer.
      final notes = provider.projectData.planningNotes;
      expect(
        notes.containsKey(
            '${ProjectIntelligenceService.continuityContextPrefix}issue_management'),
        isFalse,
      );
    });
  });
}