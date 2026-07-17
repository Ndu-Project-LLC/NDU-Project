import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ndu_project/screens/project_framework_screen.dart';
import 'package:ndu_project/screens/project_framework_next_screen.dart';
import 'package:ndu_project/wbs/screens/wbs_module_screen.dart';
import 'package:ndu_project/screens/planning_requirements_screen.dart';
import 'package:ndu_project/screens/organization_plan_subsections_screen.dart';
import 'package:ndu_project/screens/team_training_building_screen.dart';
import 'package:ndu_project/screens/stakeholder_management_screen.dart';
import 'package:ndu_project/screens/team_management_screen.dart';
import 'package:ndu_project/screens/ssher_stacked_screen.dart';
import 'package:ndu_project/screens/quality_management_screen.dart';
import 'package:ndu_project/screens/execution_plan_screen.dart';
import 'package:ndu_project/screens/execution_plan_solutions_screen.dart';
import 'package:ndu_project/screens/execution_plan_details_screen.dart';
import 'package:ndu_project/screens/execution_enabling_work_plan_screen.dart';
import 'package:ndu_project/screens/execution_issue_management_screen.dart';
import 'package:ndu_project/screens/execution_plan_lessons_learned_screen.dart';
import 'package:ndu_project/screens/execution_plan_best_practices_screen.dart';
import 'package:ndu_project/screens/execution_plan_construction_plan_screen.dart';
import 'package:ndu_project/screens/execution_plan_infrastructure_plan_screen.dart';
import 'package:ndu_project/screens/execution_plan_agile_delivery_plan_screen.dart';
import 'package:ndu_project/screens/execution_plan_stakeholder_identification_screen.dart';
import 'package:ndu_project/screens/execution_plan_interface_management_screen.dart';
import 'package:ndu_project/screens/execution_plan_communication_plan_screen.dart';
import 'package:ndu_project/screens/execution_plan_interface_management_plan_screen.dart';
import 'package:ndu_project/screens/execution_plan_interface_management_overview_screen.dart';
import 'package:ndu_project/screens/design_planning_screen.dart';
import 'package:ndu_project/screens/planning_technology_screen.dart';
import 'package:ndu_project/screens/interface_management_screen.dart';
import 'package:ndu_project/screens/risk_assessment_screen.dart';
import 'package:ndu_project/screens/planning_contracting_screen.dart';
import 'package:ndu_project/screens/planning_procurement_screen.dart';
import 'package:ndu_project/schedule/screens/schedule_module_screen.dart';
import 'package:ndu_project/screens/cost_estimate_screen.dart';
import 'package:ndu_project/screens/scope_tracking_plan_screen.dart';
import 'package:ndu_project/project_controls/screens/change_management_module_screen.dart';
import 'package:ndu_project/screens/issue_management_screen.dart';
import 'package:ndu_project/screens/lessons_learned_screen.dart';
import 'package:ndu_project/screens/startup_planning_screen.dart';
import 'package:ndu_project/screens/startup_planning_subsections_screen.dart';
import 'package:ndu_project/screens/deliverables_roadmap_screen.dart';
import 'package:ndu_project/screens/deliverable_roadmap_subsections_screen.dart';
import 'package:ndu_project/screens/deliverables_roadmap_overview_screen.dart';
import 'package:ndu_project/screens/deliverables_roadmap_detailed_screen.dart';
import 'package:ndu_project/screens/document_review_matrix_screen.dart';
import 'package:ndu_project/screens/agile_acceptance_criteria_screen.dart';
import 'package:ndu_project/screens/agile_kanban_config_screen.dart';
import 'package:ndu_project/screens/agile_metrics_planning_screen.dart';
import 'package:ndu_project/screens/agile_delivery_model_screen.dart';
import 'package:ndu_project/screens/agile_scrum_config_screen.dart';
import 'package:ndu_project/screens/agile_capacity_planning_screen.dart';
import 'package:ndu_project/screens/agile_team_structure_screen.dart';
import 'package:ndu_project/screens/agile_epics_features_screen.dart';
import 'package:ndu_project/screens/agile_stories_backlog_screen.dart';
import 'package:ndu_project/screens/agile_sprint_calendar_screen.dart';
import 'package:ndu_project/screens/agile_release_plan_screen.dart';
import 'package:ndu_project/screens/agile_backlog_governance_screen.dart';
import 'package:ndu_project/screens/project_plan_screen.dart';
import 'package:ndu_project/screens/project_plan_subsections_screen.dart';
import 'package:ndu_project/screens/project_baseline_screen.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/navigation_route_resolver.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';

class PlanningPhaseNavigation {
  static final List<PlanningPage> pages = [
    PlanningPage(
      id: 'project_framework',
      title: 'Project Details',
      builder: (_) => const ProjectFrameworkScreen(),
    ),
    PlanningPage(
      id: 'work_breakdown_structure',
      title: 'Work Breakdown Structure',
      builder: (_) => const WBSModuleScreen(),
    ),
    PlanningPage(
      id: 'project_goals_milestones',
      title: 'Project Goals & Milestones',
      builder: (_) => const ProjectFrameworkNextScreen(),
    ),
    PlanningPage(
      id: 'requirements',
      title: 'Requirements',
      builder: (_) => const PlanningRequirementsScreen(),
    ),
    PlanningPage(
      id: 'organization_roles_responsibilities',
      title: 'Roles and Responsibilities',
      builder: (_) => const OrganizationRolesResponsibilitiesScreen(),
    ),
    PlanningPage(
      id: 'organization_raci_matrix',
      title: 'RACI Matrix',
      builder: (_) => const OrganizationRaciMatrixScreen(),
    ),
    PlanningPage(
      id: 'organization_staffing_plan',
      title: 'Staffing Plan',
      builder: (_) => const OrganizationStaffingPlanScreen(),
    ),
    PlanningPage(
      id: 'team_training',
      title: 'Training & Team Building',
      builder: (_) => const TeamTrainingAndBuildingScreen(),
    ),
    PlanningPage(
      id: 'stakeholder_management',
      title: 'Stakeholder Management',
      builder: (_) => const StakeholderManagementScreen(),
    ),
    PlanningPage(
      id: 'team_management',
      title: 'Team Management',
      builder: (_) => const TeamManagementScreen(),
    ),
    PlanningPage(
      id: 'ssher',
      title: 'SSHER',
      builder: (_) => const SsherStackedScreen(),
    ),
    PlanningPage(
      id: 'quality_management',
      title: 'Quality',
      builder: (_) => const QualityManagementScreen(),
    ),
    PlanningPage(
      id: 'design',
      title: 'Design Planning',
      builder: (_) => const DesignPlanningScreen(),
    ),
    PlanningPage(
      id: 'technology',
      title: 'Technology Planning',
      builder: (_) => const PlanningTechnologyScreen(),
    ),
    PlanningPage(
      id: 'interface_management',
      title: 'Interface Management',
      builder: (_) => const InterfaceManagementScreen(),
    ),
    // Agile Delivery Model Section — before Execution Plan
    PlanningPage(
      id: 'agile_delivery_model',
      title: 'Agile Delivery Model',
      builder: (_) => const AgileDeliveryModelScreen(),
    ),
    PlanningPage(
      id: 'agile_scrum_config',
      title: 'Scrum Configuration',
      builder: (_) => const AgileScrumConfigScreen(),
    ),
    PlanningPage(
      id: 'agile_capacity_planning',
      title: 'Capacity Planning',
      builder: (_) => const AgileCapacityPlanningScreen(),
    ),
    PlanningPage(
      id: 'agile_backlog_governance',
      title: 'Backlog Governance',
      builder: (_) => const AgileBacklogGovernanceScreen(),
    ),
    PlanningPage(
      id: 'agile_team_structure',
      title: 'Agile Team Structure',
      builder: (_) => const AgileTeamStructureScreen(),
    ),
    PlanningPage(
      id: 'agile_kanban_config',
      title: 'Kanban Configuration',
      builder: (_) => const AgileKanbanConfigScreen(),
    ),
    PlanningPage(
      id: 'agile_epics_features',
      title: 'Epics & Features',
      builder: (_) => const AgileEpicsFeaturesScreen(),
    ),
    PlanningPage(
      id: 'agile_stories_backlog',
      title: 'Stories & Backlog Breakdown',
      builder: (_) => const AgileStoriesBacklogScreen(),
    ),
    PlanningPage(
      id: 'agile_acceptance_criteria',
      title: 'Acceptance Criteria Planning',
      builder: (_) => const AgileAcceptanceCriteriaScreen(),
    ),
    PlanningPage(
      id: 'agile_sprint_calendar',
      title: 'Sprint Cadence & Calendar',
      builder: (_) => const AgileSprintCalendarScreen(),
    ),
    PlanningPage(
      id: 'agile_map_out',
      title: 'Agile Map Out',
      builder: (_) => const DeliverableRoadmapAgileMapOutScreen(),
    ),
    PlanningPage(
      id: 'agile_release_plan',
      title: 'Release Plan',
      builder: (_) => const AgileReleasePlanScreen(),
    ),
    PlanningPage(
      id: 'agile_metrics_planning',
      title: 'Agile Metrics Planning',
      builder: (_) => const AgileMetricsPlanningScreen(),
    ),
    // Execution Plan — full flow matching sidebar order
    PlanningPage(
      id: 'execution_plan',
      title: 'Execution Plan Overview',
      builder: (_) => const ExecutionPlanScreen(),
    ),
    PlanningPage(
      id: 'execution_plan_strategy',
      title: 'Executive Plan Strategy',
      builder: (_) => const ExecutionPlanSolutionsScreen(),
    ),
    PlanningPage(
      id: 'execution_plan_details',
      title: 'Execution Plan Details',
      builder: (_) => const ExecutionPlanDetailsScreen(
        activeItemLabel: 'Execution Plan Details',
        showPlanDetails: true,
        showEarlyWorks: false,
      ),
    ),
    PlanningPage(
      id: 'execution_early_works',
      title: 'Execution Early Works',
      builder: (_) => const ExecutionPlanDetailsScreen(
        activeItemLabel: 'Execution Early Works',
        showPlanDetails: false,
        showEarlyWorks: true,
      ),
    ),
    PlanningPage(
      id: 'execution_enabling_work_plan',
      title: 'Enabling Work Plan',
      builder: (_) => const ExecutionEnablingWorkPlanScreen(),
    ),
    PlanningPage(
      id: 'execution_issue_management',
      title: 'Execution Issue Management',
      builder: (_) => const ExecutionIssueManagementScreen(),
    ),
    PlanningPage(
      id: 'execution_plan_stakeholder_identification',
      title: 'Execution Stakeholder Identification',
      builder: (_) => const ExecutionPlanStakeholderIdentificationScreen(),
    ),
    PlanningPage(
      id: 'execution_plan_construction_plan',
      title: 'Construction Plan',
      builder: (_) => const ExecutionPlanConstructionPlanScreen(),
    ),
    PlanningPage(
      id: 'execution_plan_infrastructure_plan',
      title: 'Infrastructure Plan',
      builder: (_) => const ExecutionPlanInfrastructurePlanScreen(),
    ),
    PlanningPage(
      id: 'execution_plan_agile_delivery_plan',
      title: 'Agile Delivery Plan',
      builder: (_) => const ExecutionPlanAgileDeliveryPlanScreen(),
    ),
    PlanningPage(
      id: 'execution_plan_lessons_learned',
      title: 'Execution Lessons Learned',
      builder: (_) => const ExecutionPlanLessonsLearnedScreen(),
    ),
    PlanningPage(
      id: 'execution_plan_best_practices',
      title: 'Best Practices',
      builder: (_) => const ExecutionPlanBestPracticesScreen(),
    ),
    PlanningPage(
      id: 'execution_plan_interface_management',
      title: 'Execution Interface Management',
      builder: (_) => const ExecutionPlanInterfaceManagementScreen(),
    ),
    PlanningPage(
      id: 'execution_plan_communication_plan',
      title: 'Communication Plan',
      builder: (_) => const ExecutionPlanCommunicationPlanScreen(),
    ),
    PlanningPage(
      id: 'execution_plan_interface_management_plan',
      title: 'Execution Interface Management Plan',
      builder: (_) => const ExecutionPlanInterfaceManagementPlanScreen(),
    ),
    PlanningPage(
      id: 'execution_plan_interface_management_overview',
      title: 'Execution Interface Management Overview',
      builder: (_) => const ExecutionPlanInterfaceManagementOverviewScreen(),
    ),
    PlanningPage(
      id: 'deliverables_roadmap_overview',
      title: 'Roadmap Overview',
      builder: (_) => const DeliverablesRoadmapOverviewScreen(),
    ),
    PlanningPage(
      id: 'deliverables_roadmap_detailed',
      title: 'Detailed Deliverables',
      builder: (_) => const DeliverablesRoadmapDetailedScreen(),
    ),
    PlanningPage(
      id: 'document_review_matrix',
      title: 'Document Review Matrix',
      builder: (_) => const DocumentReviewMatrixScreen(),
    ),
    PlanningPage(
      id: 'risk_assessment',
      title: 'Risk Assessment',
      builder: (_) => const RiskAssessmentScreen(),
    ),
    PlanningPage(
      id: 'contracts',
      title: 'Contract Planning',
      builder: (_) => const PlanningContractingScreen(),
    ),
    PlanningPage(
      id: 'procurement',
      title: 'Procurement',
      builder: (_) => const PlanningProcurementScreen(),
    ),
    PlanningPage(
      id: 'schedule',
      title: 'Schedule',
      builder: (_) => const ScheduleModuleScreen(),
    ),
    PlanningPage(
      id: 'cost_estimate',
      title: 'Cost Estimate',
      builder: (_) => const CostEstimateScreen(),
    ),
    PlanningPage(
      id: 'scope_tracking_plan',
      title: 'Scope Tracking Plan',
      builder: (_) => const ScopeTrackingPlanScreen(),
    ),
    PlanningPage(
      id: 'change_management',
      title: 'Change Management',
      builder: (_) => const ChangeManagementModuleScreen(),
    ),
    PlanningPage(
      id: 'issue_management',
      title: 'Issues Management',
      builder: (_) => const IssueManagementScreen(),
    ),
    PlanningPage(
      id: 'lessons_learned',
      title: 'Lessons Learned',
      builder: (_) => const LessonsLearnedScreen(),
    ),
    PlanningPage(
      id: 'startup_planning',
      title: 'Start-up Planning',
      builder: (_) => const StartUpPlanningScreen(),
    ),
    PlanningPage(
      id: 'startup_planning_operations',
      title: 'Operations Plan and Manual',
      builder: (_) => const StartUpPlanningOperationsScreen(),
    ),
    PlanningPage(
      id: 'startup_planning_hypercare',
      title: 'Hypercare Plan',
      builder: (_) => const StartUpPlanningHypercareScreen(),
    ),
    PlanningPage(
      id: 'startup_planning_devops',
      title: 'DevOps',
      builder: (_) => const StartUpPlanningDevOpsScreen(),
    ),
    PlanningPage(
      id: 'startup_planning_closeout',
      title: 'Close Out Plan',
      builder: (_) => const StartUpPlanningCloseOutPlanScreen(),
    ),
    PlanningPage(
      id: 'deliverables_roadmap',
      title: 'Deliverables Roadmap',
      builder: (_) => const DeliverablesRoadmapScreen(),
    ),
    PlanningPage(
      id: 'project_plan',
      title: 'Project Plan',
      builder: (_) => const ProjectPlanScreen(),
    ),
    PlanningPage(
      id: 'project_plan_level1_schedule',
      title: 'Level 1 - Project Schedule',
      builder: (_) => const ProjectPlanLevel1ScheduleScreen(),
    ),
    PlanningPage(
      id: 'project_plan_detailed_schedule',
      title: 'Detailed Project Schedule',
      builder: (_) => const ProjectPlanDetailedScheduleScreen(),
    ),
    PlanningPage(
      id: 'project_plan_condensed_summary',
      title: 'Condensed Project Summary',
      builder: (_) => const ProjectPlanCondensedSummaryScreen(),
    ),
    PlanningPage(
      id: 'project_baseline',
      title: 'Project Baseline',
      builder: (_) => const ProjectBaselineScreen(),
    ),
  ];

  static int getPageIndex(String id) {
    return pages.indexWhere((p) => p.id == id);
  }

  static bool _usesSidebarOrder(String id) {
    return SidebarNavigationService.instance.findItemByCheckpoint(id) != null;
  }

  static SidebarItem? _nextSidebarItem(BuildContext context, String currentId) {
    final isBasicPlan =
        ProjectDataInherited.maybeOf(context)?.projectData.isBasicPlanProject ??
            false;
    return SidebarNavigationService.instance
        .getNextAccessibleItem(currentId, isBasicPlan);
  }

  static SidebarItem? _previousSidebarItem(String currentId) {
    return SidebarNavigationService.instance.getPreviousItem(currentId);
  }

  static Widget? resolvePreviousScreen(BuildContext context, String currentId) {
    if (_usesSidebarOrder(currentId)) {
      final prev = _previousSidebarItem(currentId);
      if (prev == null) return null;
      return NavigationRouteResolver.resolveCheckpointToScreen(
        prev.checkpoint,
        context,
      );
    }

    final prev = previousPage(currentId);
    return prev == null ? null : prev.builder(context);
  }

  static Widget? resolveNextScreen(BuildContext context, String currentId) {
    if (_usesSidebarOrder(currentId)) {
      final next = _nextSidebarItem(context, currentId);
      if (next == null) return null;
      return NavigationRouteResolver.resolveCheckpointToScreen(
        next.checkpoint,
        context,
      );
    }

    final next = nextPage(currentId);
    return next == null ? null : next.builder(context);
  }

  static PlanningPage? previousPage(String currentId) {
    final index = getPageIndex(currentId);
    if (index > 0) return pages[index - 1];
    return null;
  }

  static PlanningPage? nextPage(String currentId) {
    final index = getPageIndex(currentId);
    if (index != -1 && index < pages.length - 1) {
      return pages[index + 1];
    }
    return null;
  }

  static String backLabel(String currentId) {
    if (_usesSidebarOrder(currentId)) {
      final prev = _previousSidebarItem(currentId);
      return prev == null ? 'Back' : 'Back: ${prev.label}';
    }
    final prev = previousPage(currentId);
    return prev == null ? 'Back' : 'Back: ${prev.title}';
  }

  static String nextLabel(String currentId) {
    if (_usesSidebarOrder(currentId)) {
      final next = SidebarNavigationService.instance.getNextItem(currentId);
      return next == null ? 'Next' : 'Next: ${next.label}';
    }
    final next = nextPage(currentId);
    return next == null ? 'Next' : 'Next: ${next.title}';
  }

  static void goToPrevious(BuildContext context, String currentId) {
    // Flush any pending auto-save before navigating
    final provider = ProjectDataInherited.maybeOf(context);
    if (provider != null) {
      unawaited(provider.flushAutoSave());
    }

    if (_usesSidebarOrder(currentId)) {
      final prev = _previousSidebarItem(currentId);
      if (prev != null) {
        final screen = resolvePreviousScreen(context, currentId);
        if (screen != null) {
          Navigator.of(context).push(
            PhaseTransitionHelper.buildRoute(
              context: context,
              builder: (_) => screen,
              destinationCheckpoint: prev.checkpoint,
              sourceCheckpoint: currentId,
            ),
          );
          return;
        }
      }
      Navigator.of(context).maybePop();
      return;
    }

    final prev = previousPage(currentId);
    if (prev != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: prev.builder));
    } else {
      Navigator.of(context).maybePop();
    }
  }

  static void goToNext(BuildContext context, String currentId) {
    // Flush any pending auto-save before navigating
    final provider = ProjectDataInherited.maybeOf(context);
    if (provider != null) {
      unawaited(provider.flushAutoSave());
    }

    if (_usesSidebarOrder(currentId)) {
      final next = _nextSidebarItem(context, currentId);
      if (next != null) {
        final screen = resolveNextScreen(context, currentId);
        if (screen != null) {
          Navigator.of(context).push(
            PhaseTransitionHelper.buildRoute(
              context: context,
              builder: (_) => screen,
              destinationCheckpoint: next.checkpoint,
              sourceCheckpoint: currentId,
            ),
          );
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End of Planning Phase navigation path.')),
      );
      return;
    }

    final next = nextPage(currentId);
    if (next != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: next.builder));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End of Planning Phase navigation path.')),
      );
    }
  }

  static void navigateToNext(BuildContext context, String currentId) {
    final provider = ProjectDataInherited.maybeOf(context);
    if (provider != null) {
      unawaited(provider.flushAutoSave());
    }

    if (_usesSidebarOrder(currentId)) {
      goToNext(context, currentId);
      return;
    }

    int index = getPageIndex(currentId);
    if (index != -1 && index < pages.length - 1) {
      final nextPage = pages[index + 1];
      Navigator.of(context).push(
        MaterialPageRoute(builder: nextPage.builder),
      );
    } else {
      // If last page, maybe go to home or show completion?
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End of Planning Phase navigation path.')),
      );
    }
  }

  static void navigateToPrevious(BuildContext context, String currentId) {
    final provider = ProjectDataInherited.maybeOf(context);
    if (provider != null) {
      unawaited(provider.flushAutoSave());
    }

    if (_usesSidebarOrder(currentId)) {
      goToPrevious(context, currentId);
      return;
    }

    // Usually handled by Navigator.pop, but if we need explicit back flow:
    int index = getPageIndex(currentId);
    if (index > 0) {
      Navigator.of(context).pop();
    }
  }
}

class PlanningPage {
  final String id;
  final String title;
  final WidgetBuilder builder;

  PlanningPage({required this.id, required this.title, required this.builder});
}
