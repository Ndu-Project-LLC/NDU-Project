import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/control_account_model.dart';
import 'package:ndu_project/services/planning_phase_context_service.dart';

/// Helper to create a [PlanningScreenContext] with sensible defaults.
PlanningScreenContext _ctx({
  required String screenId,
  String? screenTitle,
  Map<String, String>? summaryData,
  List<String>? keyInsights,
}) {
  return PlanningScreenContext(
    screenId: screenId,
    screenTitle: screenTitle ?? screenId,
    timestamp: DateTime(2025, 1, 15, 10, 30),
    summaryData: summaryData ?? {'Key': 'Value'},
    keyInsights: keyInsights ?? [],
  );
}

void main() {
  // We use a fresh service for each test group to avoid state leakage.
  // Since PlanningPhaseContextService is a singleton, we clear it between tests.
  late PlanningPhaseContextService service;

  setUp(() {
    service = PlanningPhaseContextService.instance;
    service.clearAll();
  });

  // ────────────────────────────────────────────────────────────────────
  // 1. Flow ordering constants
  // ────────────────────────────────────────────────────────────────────
  group('Planning Flow Order', () {
    test('starts with project_framework', () {
      expect(PlanningPhaseContextService.planningFlowOrder.first,
          'project_framework');
    });

    test('ends with project_baseline', () {
      expect(PlanningPhaseContextService.planningFlowOrder.last,
          'project_baseline');
    });

    test('has no duplicate screen IDs', () {
      final ids = PlanningPhaseContextService.planningFlowOrder;
      expect(ids.length, ids.toSet().length,
          reason: 'Planning flow order contains duplicate screen IDs');
    });

    test('contains expected key screens', () {
      final order = PlanningPhaseContextService.planningFlowOrder;
      expect(order, contains('work_breakdown_structure'));
      expect(order, contains('requirements'));
      expect(order, contains('quality_management'));
      expect(order, contains('design'));
      expect(order, contains('technology'));
      expect(order, contains('risk_assessment'));
      expect(order, contains('cost_estimate'));
      expect(order, contains('schedule'));
      expect(order, contains('execution_plan'));
    });

    test('WBS comes before requirements', () {
      final order = PlanningPhaseContextService.planningFlowOrder;
      final wbsIndex = order.indexOf('work_breakdown_structure');
      final reqIndex = order.indexOf('requirements');
      expect(wbsIndex, lessThan(reqIndex));
    });

    test('quality_management comes after organization screens', () {
      final order = PlanningPhaseContextService.planningFlowOrder;
      final orgIndex = order.indexOf('organization_staffing_plan');
      final qualityIndex = order.indexOf('quality_management');
      expect(orgIndex, lessThan(qualityIndex));
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 2. Launch Phase flow ordering
  // ────────────────────────────────────────────────────────────────────
  group('Launch Flow Order', () {
    test('starts with deliver_project_closure', () {
      expect(PlanningPhaseContextService.launchFlowOrder.first,
          'deliver_project_closure');
    });

    test('ends with project_close_out', () {
      expect(PlanningPhaseContextService.launchFlowOrder.last,
          'project_close_out');
    });

    test('has exactly 11 screens', () {
      expect(PlanningPhaseContextService.launchFlowOrder.length, 11);
    });

    test('has no duplicate screen IDs', () {
      final ids = PlanningPhaseContextService.launchFlowOrder;
      expect(ids.length, ids.toSet().length,
          reason: 'Launch flow order contains duplicate screen IDs');
    });

    test('contains all expected launch screens', () {
      final order = PlanningPhaseContextService.launchFlowOrder;
      expect(order, contains('deliver_project_closure'));
      expect(order, contains('transition_to_prod_team'));
      expect(order, contains('fat_mechanical_completion'));
      expect(order, contains('contract_close_out'));
      expect(order, contains('actual_vs_planned_gap_analysis'));
      expect(order, contains('commerce_viability'));
      expect(order, contains('financial_closeout'));
      expect(order, contains('summarize_account_risks'));
      expect(order, contains('benefits_realization'));
      expect(order, contains('demobilize_team'));
      expect(order, contains('project_close_out'));
    });

    test('transition_to_prod_team comes after deliver_project_closure', () {
      final order = PlanningPhaseContextService.launchFlowOrder;
      expect(order.indexOf('deliver_project_closure'),
          lessThan(order.indexOf('transition_to_prod_team')));
    });

    test('fat_mechanical_completion comes after transition_to_prod_team', () {
      final order = PlanningPhaseContextService.launchFlowOrder;
      expect(order.indexOf('transition_to_prod_team'),
          lessThan(order.indexOf('fat_mechanical_completion')));
    });

    test('contract_close_out comes after fat_mechanical_completion', () {
      final order = PlanningPhaseContextService.launchFlowOrder;
      expect(order.indexOf('fat_mechanical_completion'),
          lessThan(order.indexOf('contract_close_out')));
    });

    test('financial_closeout comes after commerce_viability', () {
      final order = PlanningPhaseContextService.launchFlowOrder;
      expect(order.indexOf('commerce_viability'),
          lessThan(order.indexOf('financial_closeout')));
    });

    test('project_close_out is last in the launch flow', () {
      final order = PlanningPhaseContextService.launchFlowOrder;
      expect(order.indexOf('project_close_out'), order.length - 1);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 3. Screen labels
  // ────────────────────────────────────────────────────────────────────
  group('Screen Labels', () {
    test('returns correct label for planning screen', () {
      expect(service.getScreenLabel('project_framework'), 'Project Details');
      expect(service.getScreenLabel('work_breakdown_structure'),
          'Work Breakdown Structure');
      expect(service.getScreenLabel('requirements'), 'Requirements');
      expect(service.getScreenLabel('quality_management'),
          'Quality Management');
      expect(service.getScreenLabel('design'), 'Design Planning');
      expect(service.getScreenLabel('technology'), 'Technology Planning');
    });

    test('returns correct label for launch screen', () {
      expect(service.getScreenLabel('deliver_project_closure'),
          'Launch Readiness Assessment');
      expect(service.getScreenLabel('transition_to_prod_team'),
          'Deployment Transfer, Certification & Release');
      expect(service.getScreenLabel('fat_mechanical_completion'),
          'FAT, Mechanical Completion & Commission Solution');
      expect(service.getScreenLabel('contract_close_out'),
          'Vendor & Contract Closeout');
      expect(service.getScreenLabel('financial_closeout'),
          'Financial Closeout');
      expect(service.getScreenLabel('project_close_out'),
          'Project Closeout');
    });

    test('returns screen ID for unknown screen', () {
      expect(service.getScreenLabel('unknown_screen_id'), 'unknown_screen_id');
    });

    test('all planning flow screens have labels', () {
      for (final screenId in PlanningPhaseContextService.planningFlowOrder) {
        final label = service.getScreenLabel(screenId);
        expect(label, isNot(equals(screenId)),
            reason:
                'Planning screen $screenId should have a human-readable label');
      }
    });

    test('all launch flow screens have labels', () {
      for (final screenId in PlanningPhaseContextService.launchFlowOrder) {
        final label = service.getScreenLabel(screenId);
        expect(label, isNot(equals(screenId)),
            reason:
                'Launch screen $screenId should have a human-readable label');
      }
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 4. Navigation: previous / next screen
  // ────────────────────────────────────────────────────────────────────
  group('Navigation - Previous Screen', () {
    test('returns null for first planning screen', () {
      expect(service.getPreviousScreenId('project_framework'), isNull);
    });

    test('returns null for first launch screen', () {
      expect(service.getPreviousScreenId('deliver_project_closure'), isNull);
    });

    test('returns correct previous screen in planning flow', () {
      expect(service.getPreviousScreenId('work_breakdown_structure'),
          'project_framework');
      expect(service.getPreviousScreenId('requirements'),
          'project_goals_milestones');
      expect(service.getPreviousScreenId('quality_management'), 'ssher');
    });

    test('returns correct previous screen in launch flow', () {
      expect(service.getPreviousScreenId('transition_to_prod_team'),
          'deliver_project_closure');
      expect(service.getPreviousScreenId('fat_mechanical_completion'),
          'transition_to_prod_team');
      expect(service.getPreviousScreenId('contract_close_out'),
          'fat_mechanical_completion');
      expect(service.getPreviousScreenId('project_close_out'),
          'demobilize_team');
    });

    test('returns null for unknown screen', () {
      expect(service.getPreviousScreenId('nonexistent_screen'), isNull);
    });
  });

  group('Navigation - Next Screen', () {
    test('returns correct next screen for last planning screen', () {
      expect(service.getNextScreenId('project_baseline'), isNull);
    });

    test('returns correct next screen for last launch screen', () {
      expect(service.getNextScreenId('project_close_out'), isNull);
    });

    test('returns correct next screen in planning flow', () {
      expect(service.getNextScreenId('project_framework'),
          'work_breakdown_structure');
      expect(service.getNextScreenId('work_breakdown_structure'),
          'project_goals_milestones');
      expect(service.getNextScreenId('ssher'), 'quality_management');
    });

    test('returns correct next screen in launch flow', () {
      expect(service.getNextScreenId('deliver_project_closure'),
          'transition_to_prod_team');
      expect(service.getNextScreenId('transition_to_prod_team'),
          'fat_mechanical_completion');
      expect(service.getNextScreenId('fat_mechanical_completion'),
          'contract_close_out');
      expect(service.getNextScreenId('demobilize_team'),
          'project_close_out');
    });

    test('returns null for unknown screen', () {
      expect(service.getNextScreenId('nonexistent_screen'), isNull);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 5. Context publishing and retrieval
  // ────────────────────────────────────────────────────────────────────
  group('Context Publishing & Retrieval', () {
    test('publishContext stores context for a screen', () {
      final context = _ctx(
        screenId: 'project_framework',
        screenTitle: 'Project Details',
        summaryData: {'Project Name': 'Test Project'},
      );
      service.publishContext(context);

      final retrieved = service.getContext('project_framework');
      expect(retrieved, isNotNull);
      expect(retrieved!.screenId, 'project_framework');
      expect(retrieved.screenTitle, 'Project Details');
      expect(retrieved.summaryData['Project Name'], 'Test Project');
    });

    test('hasContext returns true after publishing', () {
      expect(service.hasContext('project_framework'), isFalse);
      service.publishContext(_ctx(screenId: 'project_framework'));
      expect(service.hasContext('project_framework'), isTrue);
    });

    test('hasContext returns false for unpublished screen', () {
      expect(service.hasContext('unknown_screen'), isFalse);
    });

    test('getContext returns null for unpublished screen', () {
      expect(service.getContext('unknown_screen'), isNull);
    });

    test('publishContext overwrites previous context for same screen', () {
      service.publishContext(_ctx(
        screenId: 'project_framework',
        summaryData: {'Version': '1'},
      ));
      service.publishContext(_ctx(
        screenId: 'project_framework',
        summaryData: {'Version': '2'},
      ));

      final ctx = service.getContext('project_framework');
      expect(ctx!.summaryData['Version'], '2');
    });

    test('publishes multiple screens independently', () {
      service.publishContext(_ctx(
        screenId: 'project_framework',
        summaryData: {'Name': 'Project A'},
      ));
      service.publishContext(_ctx(
        screenId: 'work_breakdown_structure',
        summaryData: {'Nodes': '10'},
      ));

      expect(service.getContext('project_framework')!.summaryData['Name'],
          'Project A');
      expect(
          service
              .getContext('work_breakdown_structure')!.summaryData['Nodes'],
          '10');
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 6. Upstream context resolution
  // ────────────────────────────────────────────────────────────────────
  group('Upstream Contexts', () {
    test('first planning screen has no upstream contexts', () {
      service.publishContext(_ctx(screenId: 'project_framework'));
      final upstream = service.getUpstreamContexts('project_framework');
      expect(upstream, isEmpty);
    });

    test('first launch screen has no upstream contexts', () {
      service.publishContext(_ctx(screenId: 'deliver_project_closure'));
      final upstream =
          service.getUpstreamContexts('deliver_project_closure');
      expect(upstream, isEmpty);
    });

    test('second planning screen gets upstream from first', () {
      service.publishContext(_ctx(screenId: 'project_framework'));
      service.publishContext(_ctx(screenId: 'work_breakdown_structure'));

      final upstream =
          service.getUpstreamContexts('work_breakdown_structure');
      expect(upstream.length, 1);
      expect(upstream.first.screenId, 'project_framework');
    });

    test('third launch screen gets upstream from first two', () {
      service.publishContext(_ctx(screenId: 'deliver_project_closure'));
      service.publishContext(_ctx(screenId: 'transition_to_prod_team'));
      service.publishContext(_ctx(screenId: 'fat_mechanical_completion'));

      final upstream =
          service.getUpstreamContexts('fat_mechanical_completion');
      expect(upstream.length, 2);
      expect(upstream[0].screenId, 'deliver_project_closure');
      expect(upstream[1].screenId, 'transition_to_prod_team');
    });

    test('skips unpublished upstream screens', () {
      service.publishContext(_ctx(screenId: 'project_framework'));
      // project_goals_milestones not published
      service.publishContext(_ctx(screenId: 'requirements'));

      final upstream = service.getUpstreamContexts('requirements');
      expect(upstream.length, 1);
      expect(upstream.first.screenId, 'project_framework');
    });

    test('returns empty list for unknown screen', () {
      final upstream = service.getUpstreamContexts('nonexistent_screen');
      expect(upstream, isEmpty);
    });

    test('launch screens do not include planning upstream contexts', () {
      service.publishContext(_ctx(screenId: 'project_framework'));
      service.publishContext(_ctx(screenId: 'work_breakdown_structure'));

      final upstream =
          service.getUpstreamContexts('transition_to_prod_team');
      expect(upstream, isEmpty,
          reason:
              'Launch phase should only see other launch phase upstreams');
    });

    test('complex mid-flow scenario with sparse publishes', () {
      // Publish screens 1, 3, 5 in the launch flow
      service.publishContext(_ctx(screenId: 'deliver_project_closure'));
      service.publishContext(_ctx(screenId: 'fat_mechanical_completion'));
      service
          .publishContext(_ctx(screenId: 'actual_vs_planned_gap_analysis'));

      // Screen 6 (commerce_viability) should see screens 1, 3, 5
      final upstream =
          service.getUpstreamContexts('commerce_viability');
      expect(upstream.length, 3);
      expect(upstream[0].screenId, 'deliver_project_closure');
      expect(upstream[1].screenId, 'fat_mechanical_completion');
      expect(upstream[2].screenId, 'actual_vs_planned_gap_analysis');
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 7. Upstream summary
  // ────────────────────────────────────────────────────────────────────
  group('Upstream Summary', () {
    test('prefixes keys with screen title to avoid collisions', () {
      service.publishContext(_ctx(
        screenId: 'project_framework',
        screenTitle: 'Project Details',
        summaryData: {'Name': 'Test'},
      ));
      service.publishContext(_ctx(
        screenId: 'work_breakdown_structure',
        screenTitle: 'WBS',
        summaryData: {'Nodes': '5'},
      ));

      final summary =
          service.getUpstreamSummary('project_goals_milestones');
      expect(summary.containsKey('Project Details: Name'), isTrue);
      expect(summary['Project Details: Name'], 'Test');
      expect(summary.containsKey('WBS: Nodes'), isTrue);
      expect(summary['WBS: Nodes'], '5');
    });

    test('returns empty map for first screen', () {
      final summary = service.getUpstreamSummary('project_framework');
      expect(summary, isEmpty);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 8. Banner items
  // ────────────────────────────────────────────────────────────────────
  group('Banner Items', () {
    test('builds correct banner items from upstream contexts', () {
      service.publishContext(_ctx(
        screenId: 'project_framework',
        screenTitle: 'Project Details',
        summaryData: {'Name': 'Test', 'Framework': 'Agile'},
      ));
      service.publishContext(_ctx(
        screenId: 'work_breakdown_structure',
        screenTitle: 'WBS',
        summaryData: {'Nodes': '10'},
      ));

      final items =
          service.buildBannerItems('project_goals_milestones');
      expect(items.length, 3);

      // Check items from Project Details
      final nameItem =
          items.firstWhere((i) => i.label == 'Name');
      expect(nameItem.screenId, 'project_framework');
      expect(nameItem.screenTitle, 'Project Details');
      expect(nameItem.value, 'Test');

      final frameworkItem =
          items.firstWhere((i) => i.label == 'Framework');
      expect(frameworkItem.value, 'Agile');

      // Check item from WBS
      final nodesItem = items.firstWhere((i) => i.label == 'Nodes');
      expect(nodesItem.screenId, 'work_breakdown_structure');
      expect(nodesItem.value, '10');
    });

    test('returns empty list for first screen', () {
      final items = service.buildBannerItems('project_framework');
      expect(items, isEmpty);
    });

    test('banner items preserve order from upstream', () {
      service.publishContext(_ctx(
        screenId: 'deliver_project_closure',
        screenTitle: 'Screen 1',
        summaryData: {'A': '1'},
      ));
      service.publishContext(_ctx(
        screenId: 'transition_to_prod_team',
        screenTitle: 'Screen 2',
        summaryData: {'B': '2'},
      ));

      final items =
          service.buildBannerItems('fat_mechanical_completion');
      expect(items.length, 2);
      expect(items[0].screenId, 'deliver_project_closure');
      expect(items[1].screenId, 'transition_to_prod_team');
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 9. Clear operations
  // ────────────────────────────────────────────────────────────────────
  group('Clear Operations', () {
    test('clearContext removes only the specified screen', () {
      service.publishContext(_ctx(screenId: 'project_framework'));
      service.publishContext(_ctx(screenId: 'work_breakdown_structure'));

      service.clearContext('project_framework');

      expect(service.hasContext('project_framework'), isFalse);
      expect(service.hasContext('work_breakdown_structure'), isTrue);
    });

    test('clearAll removes all contexts', () {
      service.publishContext(_ctx(screenId: 'project_framework'));
      service.publishContext(_ctx(screenId: 'work_breakdown_structure'));
      service.publishContext(_ctx(screenId: 'requirements'));

      service.clearAll();

      expect(service.hasContext('project_framework'), isFalse);
      expect(service.hasContext('work_breakdown_structure'), isFalse);
      expect(service.hasContext('requirements'), isFalse);
    });

    test('clearAll makes upstream empty for all screens', () {
      service.publishContext(_ctx(screenId: 'project_framework'));
      service.publishContext(_ctx(screenId: 'work_breakdown_structure'));

      service.clearAll();

      expect(
          service.getUpstreamContexts('project_goals_milestones'), isEmpty);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 10. PlanningScreenContext data class
  // ────────────────────────────────────────────────────────────────────
  group('PlanningScreenContext', () {
    test('toString includes screenId and summaryData', () {
      final ctx = PlanningScreenContext(
        screenId: 'test_screen',
        screenTitle: 'Test Screen',
        timestamp: DateTime(2025, 1, 1),
        summaryData: {'Key': 'Value'},
      );
      expect(ctx.toString(), contains('test_screen'));
      expect(ctx.toString(), contains('Key'));
    });

    test('defaults to empty summaryData and keyInsights', () {
      final ctx = PlanningScreenContext(
        screenId: 'test',
        screenTitle: 'Test',
        timestamp: DateTime.now(),
      );
      expect(ctx.summaryData, isEmpty);
      expect(ctx.keyInsights, isEmpty);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 11. Flow order integrity checks
  // ────────────────────────────────────────────────────────────────────
  group('Flow Order Integrity', () {
    test('no screen ID appears in both planning and launch flows', () {
      final planningSet =
          PlanningPhaseContextService.planningFlowOrder.toSet();
      final launchSet =
          PlanningPhaseContextService.launchFlowOrder.toSet();
      final overlap = planningSet.intersection(launchSet);
      expect(overlap, isEmpty,
          reason: 'Screen IDs should not appear in both flows: $overlap');
    });

    test('all planning screen IDs have labels', () {
      for (final id in PlanningPhaseContextService.planningFlowOrder) {
        expect(PlanningPhaseContextService.screenLabels.containsKey(id),
            isTrue,
            reason: 'Planning screen $id is missing a label');
      }
    });

    test('all launch screen IDs have labels', () {
      for (final id in PlanningPhaseContextService.launchFlowOrder) {
        expect(
            PlanningPhaseContextService.launchScreenLabels.containsKey(id),
            isTrue,
            reason: 'Launch screen $id is missing a label');
      }
    });

    test('planningFlowOrder and screenLabels have same keys', () {
      final flowIds =
          PlanningPhaseContextService.planningFlowOrder.toSet();
      final labelIds =
          PlanningPhaseContextService.screenLabels.keys.toSet();
      expect(flowIds, equals(labelIds),
          reason:
              'planningFlowOrder and screenLabels should have the same keys');
    });

    test('launchFlowOrder and launchScreenLabels have same keys', () {
      final flowIds =
          PlanningPhaseContextService.launchFlowOrder.toSet();
      final labelIds =
          PlanningPhaseContextService.launchScreenLabels.keys.toSet();
      expect(flowIds, equals(labelIds),
          reason:
              'launchFlowOrder and launchScreenLabels should have the same keys');
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 12. Singleton behavior
  // ────────────────────────────────────────────────────────────────────
  group('Singleton', () {
    test('instance is always the same object', () {
      final a = PlanningPhaseContextService.instance;
      final b = PlanningPhaseContextService.instance;
      expect(identical(a, b), isTrue);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 13. PlanningContextBuilder correctness
  // ────────────────────────────────────────────────────────────────────
  group('PlanningContextBuilder', () {
    late ProjectDataModel sampleData;

    setUp(() {
      sampleData = ProjectDataModel(
        projectName: 'Test Project Alpha',
        overallFramework: 'Agile',
        projectObjective: 'Deliver a world-class project management tool',
        projectGoals: [
          ProjectGoal(name: 'Goal 1', description: 'Desc 1', framework: 'Agile'),
          ProjectGoal(name: 'Goal 2', description: 'Desc 2', framework: 'Scrum'),
        ],
        wbsTree: [
          WorkItem(title: 'Level 0 Node'),
          WorkItem(title: 'Level 0 Node 2'),
        ],
        teamMembers: [
          TeamMember(name: 'Alice', role: 'PM'),
          TeamMember(name: 'Bob', role: 'Dev'),
          TeamMember(name: 'Charlie', role: 'QA'),
        ],
        contractors: [
          Contractor(id: 'c1', name: 'Contractor A'),
        ],
        vendors: [
          Vendor(id: 'v1', name: 'Vendor 1'),
          Vendor(id: 'v2', name: 'Vendor 2'),
        ],
        keyMilestones: [
          Milestone(name: 'M1', comments: 'complete'),
          Milestone(name: 'M2', comments: 'done'),
          Milestone(name: 'M3', comments: 'pending'),
        ],
        planningRequirementItems: [
          PlanningRequirementItem(plannedText: 'Req 1'),
          PlanningRequirementItem(plannedText: 'Req 2'),
        ],
        workPackages: [
          WorkPackage(packageCode: 'WP1'),
        ],
        controlAccounts: [
          ControlAccount(title: 'CA1'),
        ],
        withinScopeItems: [
          PlanningDashboardItem(description: 'Scope A'),
        ],
        outOfScopeItems: [
          PlanningDashboardItem(description: 'Out A'),
          PlanningDashboardItem(description: 'Out B'),
        ],
        technologyDefinitions: [
          {'name': 'Flutter'},
          {'name': 'Firebase'},
        ],
      );
    });

    test('buildProjectDetailsContext extracts project name and framework', () {
      final ctx = PlanningContextBuilder.buildProjectDetailsContext(sampleData);
      expect(ctx.screenId, 'project_framework');
      expect(ctx.screenTitle, 'Project Details');
      expect(ctx.summaryData['Project Name'], 'Test Project Alpha');
      expect(ctx.summaryData['Framework'], 'Agile');
      expect(ctx.summaryData['Goals Count'], '2 goals');
      expect(ctx.keyInsights, contains('Using Agile framework'));
      expect(ctx.keyInsights, contains('2 project goals defined'));
    });

    test('buildProjectDetailsContext truncates long objectives', () {
      final longObjData = sampleData.copyWith(
        projectObjective: 'A' * 100,
      );
      final ctx = PlanningContextBuilder.buildProjectDetailsContext(longObjData);
      expect(ctx.summaryData['Objective']!.length, lessThan(100));
      expect(ctx.summaryData['Objective'], endsWith('...'));
    });

    test('buildProjectDetailsContext falls back to solutionTitle', () {
      final noNameData = sampleData.copyWith(projectName: '');
      final ctx = PlanningContextBuilder.buildProjectDetailsContext(noNameData);
      expect(ctx.summaryData['Project Name'], 'Not set');
    });

    test('buildWBSContext extracts WBS node count', () {
      final ctx = PlanningContextBuilder.buildWBSContext(sampleData);
      expect(ctx.screenId, 'work_breakdown_structure');
      expect(ctx.summaryData['WBS Nodes'], '2 nodes');
      expect(ctx.keyInsights, contains('WBS structure defined with 2 nodes'));
    });

    test('buildRequirementsContext extracts requirement count', () {
      final ctx = PlanningContextBuilder.buildRequirementsContext(sampleData);
      expect(ctx.screenId, 'requirements');
      expect(ctx.summaryData['Requirements Count'], '2 items');
      expect(ctx.keyInsights, contains('2 requirements captured'));
    });

    test('buildAgileDeliveryModelContext extracts delivery data', () {
      final ctx = PlanningContextBuilder.buildAgileDeliveryModelContext(
        sampleData,
        {'framework': 'Scrum', 'sprintLength': '2 weeks', 'estimationMethod': 'Story Points'},
      );
      expect(ctx.screenId, 'agile_delivery_model');
      expect(ctx.summaryData['Framework'], 'Scrum');
      expect(ctx.summaryData['Sprint Length'], '2 weeks');
      expect(ctx.summaryData['Estimation'], 'Story Points');
      expect(ctx.keyInsights, contains('Using Scrum framework'));
    });

    test('buildExecutionPlanContext extracts team size and framework', () {
      final ctx = PlanningContextBuilder.buildExecutionPlanContext(sampleData);
      expect(ctx.screenId, 'execution_plan');
      expect(ctx.summaryData['Team Size'], '3 members');
      expect(ctx.summaryData['Framework'], 'Agile');
    });

    test('buildExecutionWorkPackagesContext extracts package count', () {
      final ctx = PlanningContextBuilder.buildExecutionWorkPackagesContext(sampleData);
      expect(ctx.screenId, 'execution_work_packages');
      expect(ctx.summaryData['Work Packages'], '1 packages');
    });

    test('buildExecutionPlanDetailsContext extracts control account count', () {
      final ctx = PlanningContextBuilder.buildExecutionPlanDetailsContext(sampleData);
      expect(ctx.screenId, 'execution_plan_details');
      expect(ctx.summaryData['Control Accounts'], '1 accounts');
    });

    test('buildLaunchReadinessContext computes completed milestones', () {
      final ctx = PlanningContextBuilder.buildLaunchReadinessContext(sampleData);
      expect(ctx.screenId, 'deliver_project_closure');
      expect(ctx.summaryData['Milestones'], '2 of 3 completed');
      expect(ctx.keyInsights, contains('3 milestones tracked'));
    });

    test('buildDeploymentTransferContext extracts team and contractor counts', () {
      final ctx = PlanningContextBuilder.buildDeploymentTransferContext(sampleData);
      expect(ctx.screenId, 'transition_to_prod_team');
      expect(ctx.summaryData['Team Members'], '3 members');
      expect(ctx.summaryData['Contractors'], '1 contractors');
    });

    test('buildVendorCloseoutContext extracts vendor and contractor counts', () {
      final ctx = PlanningContextBuilder.buildVendorCloseoutContext(sampleData);
      expect(ctx.screenId, 'contract_close_out');
      expect(ctx.summaryData['Vendors'], '2 vendors');
      expect(ctx.summaryData['Contractors'], '1 contractors');
    });

    test('buildScopeReconciliationContext computes scope totals', () {
      final ctx = PlanningContextBuilder.buildScopeReconciliationContext(sampleData);
      expect(ctx.screenId, 'actual_vs_planned_gap_analysis');
      expect(ctx.summaryData['In-Scope Items'], '1 items');
      expect(ctx.summaryData['Out-of-Scope'], '2 items');
      expect(ctx.summaryData['Total Scope Items'], '3 items');
    });

    test('buildHypercareContext extracts vendor count', () {
      final ctx = PlanningContextBuilder.buildHypercareContext(sampleData);
      expect(ctx.screenId, 'commerce_viability');
      expect(ctx.summaryData['Vendors'], '2 under warranty');
    });

    test('buildBenefitsRealizationContext extracts goal count', () {
      final ctx = PlanningContextBuilder.buildBenefitsRealizationContext(sampleData);
      expect(ctx.screenId, 'benefits_realization');
      expect(ctx.summaryData['Project Goals'], '2 goals');
    });

    test('buildDemobilizeContext extracts team size', () {
      final ctx = PlanningContextBuilder.buildDemobilizeContext(sampleData);
      expect(ctx.screenId, 'demobilize_team');
      expect(ctx.summaryData['Team Members'], '3 members');
    });

    test('buildProjectCloseoutContext extracts team and framework', () {
      final ctx = PlanningContextBuilder.buildProjectCloseoutContext(sampleData);
      expect(ctx.screenId, 'project_close_out');
      expect(ctx.summaryData['Framework'], 'Agile');
      expect(ctx.summaryData['Team Size'], '3 members');
    });

    test('buildTechnologyContext extracts technology definitions', () {
      final ctx = PlanningContextBuilder.buildTechnologyContext(sampleData);
      expect(ctx.screenId, 'technology');
      expect(ctx.summaryData['Technology'], contains('Flutter'));
      expect(ctx.summaryData['Technology'], contains('Firebase'));
    });

    test('buildGenericContext includes extra data', () {
      final ctx = PlanningContextBuilder.buildGenericContext(
        screenId: 'custom_screen',
        screenTitle: 'Custom Screen',
        data: sampleData,
        extraData: {'Extra': 'Value'},
      );
      expect(ctx.screenId, 'custom_screen');
      expect(ctx.summaryData['Project Name'], 'Test Project Alpha');
      expect(ctx.summaryData['Extra'], 'Value');
    });

    test('buildGenericContext works without extra data', () {
      final ctx = PlanningContextBuilder.buildGenericContext(
        screenId: 'simple_screen',
        screenTitle: 'Simple',
        data: sampleData,
      );
      expect(ctx.summaryData.length, 2);
      expect(ctx.summaryData.containsKey('Project Name'), isTrue);
      expect(ctx.summaryData.containsKey('Framework'), isTrue);
    });

    test('all context builders produce valid screenId and screenTitle', () {
      final builders = <String, PlanningScreenContext Function()>{
        'project_framework': () => PlanningContextBuilder.buildProjectDetailsContext(sampleData),
        'work_breakdown_structure': () => PlanningContextBuilder.buildWBSContext(sampleData),
        'requirements': () => PlanningContextBuilder.buildRequirementsContext(sampleData),
        'quality_management': () => PlanningContextBuilder.buildQualityContext(sampleData),
        'design': () => PlanningContextBuilder.buildDesignContext(sampleData),
        'technology': () => PlanningContextBuilder.buildTechnologyContext(sampleData),
        'agile_delivery_model': () => PlanningContextBuilder.buildAgileDeliveryModelContext(sampleData, {}),
        'execution_plan': () => PlanningContextBuilder.buildExecutionPlanContext(sampleData),
        'deliver_project_closure': () => PlanningContextBuilder.buildLaunchReadinessContext(sampleData),
        'transition_to_prod_team': () => PlanningContextBuilder.buildDeploymentTransferContext(sampleData),
        'fat_mechanical_completion': () => PlanningContextBuilder.buildFATMechanicalContext(sampleData),
        'contract_close_out': () => PlanningContextBuilder.buildVendorCloseoutContext(sampleData),
        'actual_vs_planned_gap_analysis': () => PlanningContextBuilder.buildScopeReconciliationContext(sampleData),
        'commerce_viability': () => PlanningContextBuilder.buildHypercareContext(sampleData),
        'financial_closeout': () => PlanningContextBuilder.buildFinancialCloseoutContext(sampleData),
        'summarize_account_risks': () => PlanningContextBuilder.buildPerformanceReviewContext(sampleData),
        'benefits_realization': () => PlanningContextBuilder.buildBenefitsRealizationContext(sampleData),
        'demobilize_team': () => PlanningContextBuilder.buildDemobilizeContext(sampleData),
        'project_close_out': () => PlanningContextBuilder.buildProjectCloseoutContext(sampleData),
      };

      for (final entry in builders.entries) {
        final ctx = entry.value();
        expect(ctx.screenId, entry.key,
            reason: 'Builder for ${entry.key} produced wrong screenId: ${ctx.screenId}');
        expect(ctx.screenTitle, isNotEmpty,
            reason: 'Builder for ${entry.key} produced empty screenTitle');
        expect(ctx.summaryData, isNotEmpty,
            reason: 'Builder for ${entry.key} produced empty summaryData');
      }
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 14. ContextBannerItemData data class
  // ────────────────────────────────────────────────────────────────────
  group('ContextBannerItemData', () {
    test('stores all required fields', () {
      final item = ContextBannerItemData(
        screenId: 'test_screen',
        screenTitle: 'Test Screen',
        label: 'Key',
        value: 'Value',
      );
      expect(item.screenId, 'test_screen');
      expect(item.screenTitle, 'Test Screen');
      expect(item.label, 'Key');
      expect(item.value, 'Value');
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 15. Upstream summary with multiple keys per screen
  // ────────────────────────────────────────────────────────────────────
  group('Upstream Summary - Multi-key', () {
    test('handles multiple keys per screen without collision', () {
      service.publishContext(_ctx(
        screenId: 'project_framework',
        screenTitle: 'Project Details',
        summaryData: {'Name': 'Test', 'Framework': 'Agile', 'Goals': '3'},
      ));
      service.publishContext(_ctx(
        screenId: 'work_breakdown_structure',
        screenTitle: 'WBS',
        summaryData: {'Nodes': '10', 'Depth': '3'},
      ));

      final summary = service.getUpstreamSummary('project_goals_milestones');
      expect(summary.length, 5);
      expect(summary['Project Details: Name'], 'Test');
      expect(summary['Project Details: Framework'], 'Agile');
      expect(summary['Project Details: Goals'], '3');
      expect(summary['WBS: Nodes'], '10');
      expect(summary['WBS: Depth'], '3');
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // 16. Full lifecycle: publish → upstream → clear
  // ────────────────────────────────────────────────────────────────────
  group('Full Lifecycle', () {
    test('planning phase: publish sequence builds correct upstream chain',
        () {
      // Simulate a user navigating through the planning phase
      final screens = [
        'project_framework',
        'work_breakdown_structure',
        'project_goals_milestones',
        'requirements',
      ];

      for (final screenId in screens) {
        service.publishContext(_ctx(
          screenId: screenId,
          summaryData: {'Screen': screenId},
        ));
      }

      // Each screen should see all previous screens as upstream
      for (var i = 1; i < screens.length; i++) {
        final upstream = service.getUpstreamContexts(screens[i]);
        expect(upstream.length, i,
            reason:
                '${screens[i]} should have $i upstream contexts, got ${upstream.length}');
      }
    });

    test('launch phase: publish sequence builds correct upstream chain',
        () {
      final screens = [
        'deliver_project_closure',
        'transition_to_prod_team',
        'fat_mechanical_completion',
        'contract_close_out',
        'actual_vs_planned_gap_analysis',
      ];

      for (final screenId in screens) {
        service.publishContext(_ctx(
          screenId: screenId,
          summaryData: {'Screen': screenId},
        ));
      }

      for (var i = 1; i < screens.length; i++) {
        final upstream = service.getUpstreamContexts(screens[i]);
        expect(upstream.length, i);
      }
    });

    test('full launch flow: last screen sees all 10 upstream contexts',
        () {
      for (final screenId in PlanningPhaseContextService.launchFlowOrder) {
        service.publishContext(_ctx(screenId: screenId));
      }

      final upstream =
          service.getUpstreamContexts('project_close_out');
      expect(upstream.length, 10);
    });

    test('clear and republish works correctly', () {
      service.publishContext(_ctx(screenId: 'project_framework'));
      service.publishContext(_ctx(screenId: 'work_breakdown_structure'));

      expect(
          service.getUpstreamContexts('project_goals_milestones').length, 2);

      service.clearAll();

      expect(
          service.getUpstreamContexts('project_goals_milestones').length, 0);

      // Republish
      service.publishContext(_ctx(screenId: 'project_framework'));
      expect(
          service.getUpstreamContexts('work_breakdown_structure').length, 1);
    });
  });
}
