import 'package:flutter/material.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

// Screen Imports
import 'package:ndu_project/screens/project_framework_screen.dart';
import 'package:ndu_project/screens/project_framework_next_screen.dart';
import 'package:ndu_project/wbs/screens/wbs_module_screen.dart';
import 'package:ndu_project/screens/planning_requirements_screen.dart';
import 'package:ndu_project/screens/organization_plan_subsections_screen.dart';
import 'package:ndu_project/screens/team_training_building_screen.dart';
import 'package:ndu_project/screens/stakeholder_management_screen.dart';
import 'package:ndu_project/screens/ssher_stacked_screen.dart';
import 'package:ndu_project/screens/quality_management_screen.dart';
import 'package:ndu_project/screens/execution_plan_screen.dart';
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
import 'package:ndu_project/screens/deliverables_roadmap_screen.dart';
import 'package:ndu_project/screens/deliverable_roadmap_subsections_screen.dart';
import 'package:ndu_project/screens/agile_delivery_model_screen.dart';
import 'package:ndu_project/screens/agile_team_structure_screen.dart';
import 'package:ndu_project/screens/agile_epics_features_screen.dart';
import 'package:ndu_project/screens/agile_sprint_calendar_screen.dart';
import 'package:ndu_project/screens/agile_release_plan_screen.dart';
import 'package:ndu_project/screens/agile_backlog_governance_screen.dart';
import 'package:ndu_project/screens/agile_kanban_config_screen.dart';
import 'package:ndu_project/screens/agile_acceptance_criteria_screen.dart';
import 'package:ndu_project/screens/agile_metrics_planning_screen.dart';
import 'package:ndu_project/screens/agile_scrum_config_screen.dart';
import 'package:ndu_project/screens/agile_capacity_planning_screen.dart';
import 'package:ndu_project/screens/project_plan_screen.dart';
import 'package:ndu_project/screens/project_baseline_screen.dart';

/// Central registry for mapping Planning Phase checkpoints to their corresponding screen widgets.
/// This allows dynamic navigation that automatically follows the sidebar order.
class ProjectRouteRegistry {
  ProjectRouteRegistry._();

  /// Maps Planning Phase checkpoints to their corresponding screen widgets
  static final Map<String, Widget Function()> _screens = {
    'project_framework': () => const ProjectFrameworkScreen(),
    'project_goals_milestones': () => const ProjectFrameworkNextScreen(),
    'work_breakdown_structure': () => const WBSModuleScreen(),
    'requirements': () => const PlanningRequirementsScreen(),
    'organization_roles_responsibilities': () =>
        const OrganizationRolesResponsibilitiesScreen(),
    'organization_raci_matrix': () => const OrganizationRaciMatrixScreen(),
    'organization_staffing_plan': () => const OrganizationStaffingPlanScreen(),
    'team_training': () => const TeamTrainingAndBuildingScreen(),
    'stakeholder_management': () => const StakeholderManagementScreen(),
    'ssher': () => const SsherStackedScreen(),
    'quality_management': () => const QualityManagementScreen(),
    'execution_plan': () => const ExecutionPlanScreen(),
    'design': () => const DesignPlanningScreen(),
    'technology': () => const PlanningTechnologyScreen(),
    'interface_management': () => const InterfaceManagementScreen(),
    'agile_delivery_model': () => const AgileDeliveryModelScreen(),
    'agile_scrum_config': () => const AgileScrumConfigScreen(),
    'agile_capacity_planning': () => const AgileCapacityPlanningScreen(),
    'agile_team_structure': () => const AgileTeamStructureScreen(),
    'agile_kanban_config': () => const AgileKanbanConfigScreen(),
    'agile_epics_features': () => const AgileEpicsFeaturesScreen(),
    'agile_acceptance_criteria': () => const AgileAcceptanceCriteriaScreen(),
    'agile_sprint_calendar': () => const AgileSprintCalendarScreen(),
    'agile_map_out': () => const DeliverableRoadmapAgileMapOutScreen(),
    'agile_release_plan': () => const AgileReleasePlanScreen(),
    'agile_backlog_governance': () => const AgileBacklogGovernanceScreen(),
    'risk_assessment': () => const RiskAssessmentScreen(),
    'contracts': () => const PlanningContractingScreen(),
    'procurement': () => const PlanningProcurementScreen(),
    'schedule': () => const ScheduleModuleScreen(),
    'cost_estimate': () => const CostEstimateScreen(),
    'scope_tracking_plan': () => const ScopeTrackingPlanScreen(),
    'change_management': () => const ChangeManagementModuleScreen(),
    'issue_management': () => const IssueManagementScreen(),
    'lessons_learned': () => const LessonsLearnedScreen(),
    'startup_planning': () => const StartUpPlanningScreen(),
    'deliverable_roadmap': () => const DeliverablesRoadmapScreen(),
    'deliverables_roadmap': () => const DeliverablesRoadmapScreen(),
    'agile_metrics_planning': () => const AgileMetricsPlanningScreen(),
    'project_plan': () => const ProjectPlanScreen(),
    'project_baseline': () => const ProjectBaselineScreen(),
  };

  /// Get a screen widget by checkpoint (with BuildContext for future extensibility)
  static Widget? getScreen(BuildContext? context, String checkpoint) {
    return _screens[checkpoint]?.call();
  }

  /// Get the next accessible screen based on current checkpoint and plan type
  static Widget? getNextScreen(BuildContext context, String currentCheckpoint) {
    final isBasicPlan = ProjectDataHelper.getData(context).isBasicPlanProject;
    final nextItem = SidebarNavigationService.instance
        .getNextAccessibleItem(currentCheckpoint, isBasicPlan);
    return nextItem != null ? getScreen(context, nextItem.checkpoint) : null;
  }

  /// Get all Planning Phase checkpoints in order
  static List<String> getAllPlanningCheckpoints() {
    return _screens.keys.toList();
  }
}
