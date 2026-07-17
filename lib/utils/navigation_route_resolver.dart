import 'package:flutter/material.dart';
import 'package:ndu_project/screens/initiation_phase_screen.dart';
import 'package:ndu_project/screens/potential_solutions_screen.dart';
import 'package:ndu_project/screens/risk_identification_screen.dart';
import 'package:ndu_project/screens/it_considerations_screen.dart';
import 'package:ndu_project/screens/infrastructure_considerations_screen.dart';
import 'package:ndu_project/screens/core_stakeholders_screen.dart';
import 'package:ndu_project/screens/cost_analysis_screen.dart';
import 'package:ndu_project/screens/preferred_solution_analysis_screen.dart';
import 'package:ndu_project/screens/front_end_planning_summary.dart';
import 'package:ndu_project/screens/front_end_planning_requirements_screen.dart';
import 'package:ndu_project/screens/front_end_planning_risks_screen.dart';
import 'package:ndu_project/screens/front_end_planning_opportunities_screen.dart';
import 'package:ndu_project/screens/front_end_planning_contract_vendor_quotes_screen.dart';
import 'package:ndu_project/screens/front_end_planning_procurement_screen.dart';
import 'package:ndu_project/screens/planning_procurement_screen.dart';
import 'package:ndu_project/screens/front_end_planning_security.dart';
import 'package:ndu_project/screens/front_end_planning_allowance.dart';
import 'package:ndu_project/screens/front_end_planning_milestone.dart';
import 'package:ndu_project/screens/project_charter_screen.dart';
import 'package:ndu_project/screens/project_activities_log_screen.dart';
import 'package:ndu_project/screens/project_framework_screen.dart';
import 'package:ndu_project/screens/project_framework_next_screen.dart';
import 'package:ndu_project/wbs/screens/wbs_module_screen.dart';
import 'package:ndu_project/screens/planning_requirements_screen.dart';
import 'package:ndu_project/screens/ssher_stacked_screen.dart';
import 'package:ndu_project/project_controls/screens/change_management_module_screen.dart';
import 'package:ndu_project/screens/issue_management_screen.dart';
import 'package:ndu_project/screens/cost_estimate_screen.dart';
import 'package:ndu_project/screens/scope_tracking_plan_screen.dart';
import 'package:ndu_project/screens/planning_contracting_screen.dart';
import 'package:ndu_project/screens/project_plan_screen.dart';
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
import 'package:ndu_project/schedule/screens/schedule_module_screen.dart';
import 'package:ndu_project/screens/design_phase_screen.dart';
import 'package:ndu_project/screens/design_planning_screen.dart';
import 'package:ndu_project/screens/planning_technology_screen.dart';
import 'package:ndu_project/screens/interface_management_screen.dart';
import 'package:ndu_project/screens/startup_planning_screen.dart';
import 'package:ndu_project/screens/startup_planning_subsections_screen.dart';
import 'package:ndu_project/screens/deliverables_roadmap_screen.dart';
import 'package:ndu_project/screens/deliverable_roadmap_subsections_screen.dart';
import 'package:ndu_project/screens/deliverables_roadmap_overview_screen.dart';
import 'package:ndu_project/screens/deliverables_roadmap_detailed_screen.dart';
import 'package:ndu_project/screens/document_review_matrix_screen.dart';
import 'package:ndu_project/screens/project_baseline_screen.dart';
import 'package:ndu_project/screens/project_plan_subsections_screen.dart';
import 'package:ndu_project/screens/organization_plan_subsections_screen.dart';
import 'package:ndu_project/screens/team_management_screen.dart';
import 'package:ndu_project/screens/stakeholder_management_screen.dart';
import 'package:ndu_project/screens/risk_assessment_screen.dart';
import 'package:ndu_project/screens/security_management_screen.dart';
import 'package:ndu_project/screens/quality_management_screen.dart';
import 'package:ndu_project/screens/ui_ux_design_screen.dart';
import 'package:ndu_project/screens/backend_design_screen.dart';
import 'package:ndu_project/screens/engineering_design_screen.dart';
import 'package:ndu_project/screens/technical_alignment_screen.dart';
import 'package:ndu_project/screens/development_set_up_screen.dart';
import 'package:ndu_project/screens/tools_integration_screen.dart';
import 'package:ndu_project/screens/long_lead_equipment_ordering_screen.dart';
import 'package:ndu_project/screens/specialized_design_screen.dart';
import 'package:ndu_project/screens/design_deliverables_screen.dart';
import 'package:ndu_project/screens/staff_team_screen.dart';
import 'package:ndu_project/screens/team_meetings_screen.dart';
import 'package:ndu_project/screens/progress_tracking_screen.dart';
import 'package:ndu_project/screens/contracts_tracking_screen.dart';
import 'package:ndu_project/screens/vendor_tracking_screen.dart';
import 'package:ndu_project/screens/deliverable_status_updates_screen.dart';
import 'package:ndu_project/screens/recurring_deliverables_screen.dart';
import 'package:ndu_project/screens/status_reports_screen.dart';
import 'package:ndu_project/screens/detailed_design_screen.dart';
import 'package:ndu_project/screens/agile_development_iterations_screen.dart';
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
import 'package:ndu_project/screens/scope_tracking_implementation_screen.dart';
import 'package:ndu_project/screens/stakeholder_alignment_screen.dart';
import 'package:ndu_project/screens/update_ops_maintenance_plans_screen.dart';
import 'package:ndu_project/screens/launch_checklist_screen.dart';
import 'package:ndu_project/screens/risk_tracking_screen.dart';
import 'package:ndu_project/screens/scope_completion_screen.dart';
import 'package:ndu_project/screens/gap_analysis_scope_reconcillation_screen.dart';
import 'package:ndu_project/screens/punchlist_actions_screen.dart';
import 'package:ndu_project/screens/technical_debt_management_screen.dart';
import 'package:ndu_project/screens/identify_staff_ops_team_screen.dart';
import 'package:ndu_project/screens/salvage_disposal_team_screen.dart';
import 'package:ndu_project/screens/actual_vs_planned_gap_analysis_screen.dart';
import 'package:ndu_project/screens/finalize_project_screen.dart';
import 'package:ndu_project/screens/deliver_project_closure_screen.dart';
import 'package:ndu_project/screens/transition_to_prod_team_screen.dart';
import 'package:ndu_project/screens/contract_close_out_screen.dart';
import 'package:ndu_project/screens/vendor_account_close_out_screen.dart';
import 'package:ndu_project/screens/summarize_account_risks_screen.dart';
import 'package:ndu_project/screens/project_close_out_screen.dart';
import 'package:ndu_project/screens/demobilize_team_screen.dart';
import 'package:ndu_project/screens/requirements_implementation_screen.dart';
import 'package:ndu_project/screens/technical_development_screen.dart';
import 'package:ndu_project/screens/lessons_learned_screen.dart';
import 'package:ndu_project/screens/team_training_building_screen.dart';
import 'package:ndu_project/screens/execution_plan_interface_management_overview_screen.dart';
import 'package:ndu_project/screens/commerce_viability_screen.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/openai_service_secure.dart';

/// Utility that maps checkpoint strings to screen widgets for dynamic routing
class NavigationRouteResolver {
  NavigationRouteResolver._();

  static const Map<String, String> _checkpointAliases = {
    'fep_contracts': 'fep_contract_vendor_quotes',
    'project_framework_next': 'project_goals_milestones',
    'wbs': 'work_breakdown_structure',
    'execution_plan_outline': 'execution_plan',
    'execution_lessons_learned': 'execution_plan_lessons_learned',
    'execution_best_practices': 'execution_plan_best_practices',
    'execution_construction_plan': 'execution_plan_construction_plan',
    'execution_infrastructure_plan': 'execution_plan_infrastructure_plan',
    'execution_agile_delivery_plan': 'execution_plan_agile_delivery_plan',
    'execution_interface_management': 'execution_plan_interface_management',
    'execution_communication_plan': 'execution_plan_communication_plan',
    'execution_interface_management_plan':
        'execution_plan_interface_management_plan',
    'execution_stakeholder_identification':
        'execution_plan_stakeholder_identification',
    'execution_plan_interface_overview':
        'execution_plan_interface_management_overview',
    'planning_schedule': 'schedule',
    'planning_execution_plan_interface_overview':
        'execution_plan_interface_management_overview',
    'deliverable_roadmap_agile_map_out': 'agile_map_out',
    'agile_delivery_plan': 'agile_delivery_model',
  };

  static String _normalizeCheckpoint(String checkpoint) {
    var normalized = checkpoint.trim();
    if (normalized.isEmpty) return normalized;

    if (normalized.startsWith('execution_execution_')) {
      normalized = normalized.substring('execution_'.length);
    }

    if (normalized.startsWith('planning_')) {
      final withoutPlanningPrefix =
          normalized.substring('planning_'.length).trim();
      final mappedWithoutPrefix = _checkpointAliases[withoutPlanningPrefix];
      if (mappedWithoutPrefix != null && mappedWithoutPrefix.isNotEmpty) {
        normalized = mappedWithoutPrefix;
      } else if (withoutPlanningPrefix.isNotEmpty) {
        normalized = withoutPlanningPrefix;
      }
    }

    return _checkpointAliases[normalized] ?? normalized;
  }

  /// Resolve a checkpoint string to a Widget screen
  /// Returns null if checkpoint is invalid or unknown
  static Widget? resolveCheckpointToScreen(
      String? checkpoint, BuildContext context) {
    if (checkpoint == null) {
      return const InitiationPhaseScreen();
    }
    final normalizedCheckpoint = _normalizeCheckpoint(checkpoint);
    if (normalizedCheckpoint.isEmpty || normalizedCheckpoint == 'initiation') {
      return const InitiationPhaseScreen();
    }

    final provider = ProjectDataInherited.maybeOf(context);
    final projectData = provider?.projectData;

    // Helper to build solution items
    List<AiSolutionItem> buildSolutionItems(ProjectDataModel? data) {
      if (data == null) return [];
      final potential = data.potentialSolutions
          .map((s) => AiSolutionItem(
              title: s.title.trim(), description: s.description.trim()))
          .where((s) => s.title.isNotEmpty || s.description.isNotEmpty)
          .toList();
      if (potential.isNotEmpty) return potential;

      final preferred = data.preferredSolutionAnalysis?.solutionAnalyses
              .map((s) => AiSolutionItem(
                  title: s.solutionTitle.trim(),
                  description: s.solutionDescription.trim()))
              .where((s) => s.title.isNotEmpty || s.description.isNotEmpty)
              .toList() ??
          [];
      if (preferred.isNotEmpty) return preferred;

      final fallbackTitle = data.solutionTitle.trim();
      final fallbackDescription = data.solutionDescription.trim();
      if (fallbackTitle.isNotEmpty || fallbackDescription.isNotEmpty) {
        return [
          AiSolutionItem(title: fallbackTitle, description: fallbackDescription)
        ];
      }

      return [];
    }

    switch (normalizedCheckpoint) {
      // Initiation Phase
      case 'business_case':
        return const InitiationPhaseScreen(scrollToBusinessCase: true);
      case 'potential_solutions':
        return const PotentialSolutionsScreen();
      case 'risk_identification':
        return RiskIdentificationScreen(
          notes: projectData?.notes ?? '',
          solutions: buildSolutionItems(projectData),
          businessCase: projectData?.businessCase ?? '',
        );
      case 'it_considerations':
        return ITConsiderationsScreen(
          notes: projectData?.itConsiderationsData?.notes ??
              projectData?.notes ??
              '',
          solutions: buildSolutionItems(projectData),
        );
      case 'infrastructure_considerations':
        return InfrastructureConsiderationsScreen(
          notes: projectData?.infrastructureConsiderationsData?.notes ??
              projectData?.notes ??
              '',
          solutions: buildSolutionItems(projectData),
        );
      case 'core_stakeholders':
        return CoreStakeholdersScreen(
          notes: projectData?.coreStakeholdersData?.notes ??
              projectData?.notes ??
              '',
          solutions: buildSolutionItems(projectData),
        );
      case 'cost_analysis':
        return CostAnalysisScreen(
          notes: projectData?.notes ?? '',
          solutions: buildSolutionItems(projectData),
        );
      case 'preferred_solution_analysis':
        return PreferredSolutionAnalysisScreen(
          notes: projectData?.preferredSolutionAnalysis?.workingNotes ?? '',
          solutions: buildSolutionItems(projectData),
          businessCase: projectData?.businessCase ?? '',
        );

      // Front End Planning
      case 'fep_summary':
        return const FrontEndPlanningSummaryScreen();
      case 'fep_requirements':
        return const FrontEndPlanningRequirementsScreen();
      case 'fep_risks':
        return const FrontEndPlanningRisksScreen();
      case 'fep_opportunities':
        return const FrontEndPlanningOpportunitiesScreen();
      case 'fep_contract_vendor_quotes':
        return const FrontEndPlanningContractVendorQuotesScreen();
      case 'fep_procurement':
        return const FrontEndPlanningProcurementScreen();
      case 'fep_security':
        return const FrontEndPlanningSecurityScreen();
      case 'fep_allowance':
        return const FrontEndPlanningAllowanceScreen();
      case 'fep_milestone':
        return const FrontEndPlanningMilestoneScreen();
      case 'project_charter':
        return const ProjectCharterScreen();
      case 'project_activities_log':
        return const ProjectActivitiesLogScreen();

      // Planning Phase
      case 'project_framework':
        return const ProjectFrameworkScreen();
      case 'project_goals_milestones':
        return const ProjectFrameworkNextScreen();
      case 'work_breakdown_structure':
        return const WBSModuleScreen();
      case 'requirements':
        return const PlanningRequirementsScreen();
      case 'ssher':
        return const SsherStackedScreen();
      case 'change_management':
        return const ChangeManagementModuleScreen();
      case 'issue_management':
        return const IssueManagementScreen();
      case 'cost_estimate':
        return const CostEstimateScreen();
      case 'scope_tracking_plan':
        return const ScopeTrackingPlanScreen();
      case 'contracts':
        return const PlanningContractingScreen();
      case 'procurement':
        return const PlanningProcurementScreen();
      case 'project_plan':
        return const ProjectPlanScreen();
      case 'project_plan_level1_schedule':
        return const ProjectPlanLevel1ScheduleScreen();
      case 'project_plan_detailed_schedule':
        return const ProjectPlanDetailedScheduleScreen();
      case 'project_plan_condensed_summary':
        return const ProjectPlanCondensedSummaryScreen();
      case 'execution_plan':
        return const ExecutionPlanScreen();
      case 'execution_plan_strategy':
        return const ExecutionPlanSolutionsScreen();
      case 'execution_plan_details':
        return const ExecutionPlanDetailsScreen(
          activeItemLabel: 'Execution Plan Details',
          showPlanDetails: true,
          showEarlyWorks: false,
        );
      case 'execution_early_works':
        return const ExecutionPlanDetailsScreen(
          activeItemLabel: 'Execution Early Works',
          showPlanDetails: false,
          showEarlyWorks: true,
        );
      case 'execution_enabling_work_plan':
        return const ExecutionEnablingWorkPlanScreen();
      case 'execution_issue_management':
        return const ExecutionIssueManagementScreen();
      case 'execution_plan_lessons_learned':
        return const ExecutionPlanLessonsLearnedScreen();
      case 'execution_plan_best_practices':
        return const ExecutionPlanBestPracticesScreen();
      case 'execution_plan_construction_plan':
        return const ExecutionPlanConstructionPlanScreen();
      case 'execution_plan_infrastructure_plan':
        return const ExecutionPlanInfrastructurePlanScreen();
      case 'agile_delivery_model':
        return const AgileDeliveryModelScreen();
      case 'execution_plan_agile_delivery_plan':
        return const ExecutionPlanAgileDeliveryPlanScreen();
      case 'agile_team_structure':
        return const AgileTeamStructureScreen();
      case 'agile_kanban_config':
        return const AgileKanbanConfigScreen();
      case 'agile_acceptance_criteria':
        return const AgileAcceptanceCriteriaScreen();
      case 'agile_epics_features':
        return const AgileEpicsFeaturesScreen();
      case 'agile_sprint_calendar':
        return const AgileSprintCalendarScreen();
      case 'agile_map_out':
        return const DeliverableRoadmapAgileMapOutScreen();
      case 'deliverable_roadmap_agile_map_out':
        return const DeliverableRoadmapAgileMapOutScreen();
      case 'agile_release_plan':
        return const AgileReleasePlanScreen();
      case 'agile_scrum_config':
        return const AgileScrumConfigScreen();
      case 'agile_capacity_planning':
        return const AgileCapacityPlanningScreen();
      case 'agile_backlog_governance':
        return const AgileBacklogGovernanceScreen();
      case 'agile_metrics_planning':
        return const AgileMetricsPlanningScreen();
      case 'deliverables_roadmap_overview':
        return const DeliverablesRoadmapOverviewScreen();
      case 'deliverables_roadmap_detailed':
        return const DeliverablesRoadmapDetailedScreen();
      case 'document_review_matrix':
        return const DocumentReviewMatrixScreen();
      case 'execution_plan_interface_management':
        return const ExecutionPlanInterfaceManagementScreen();
      case 'execution_plan_communication_plan':
        return const ExecutionPlanCommunicationPlanScreen();
      case 'execution_plan_interface_management_plan':
        return const ExecutionPlanInterfaceManagementPlanScreen();
      case 'execution_plan_interface_management_overview':
        return const ExecutionPlanInterfaceManagementOverviewScreen();
      case 'execution_plan_stakeholder_identification':
        return const ExecutionPlanStakeholderIdentificationScreen();
      case 'schedule':
        return const ScheduleModuleScreen();
      case 'design':
        return const DesignPlanningScreen();
      case 'design_management':
        return const DesignPhaseScreen(activeItemLabel: 'Design Management');
      case 'technology':
        return const PlanningTechnologyScreen();
      case 'interface_management':
        return const InterfaceManagementScreen();
      case 'startup_planning':
        return const StartUpPlanningScreen();
      case 'startup_planning_operations':
        return const StartUpPlanningOperationsScreen();
      case 'startup_planning_hypercare':
        return const StartUpPlanningHypercareScreen();
      case 'startup_planning_devops':
        return const StartUpPlanningDevOpsScreen();
      case 'startup_planning_closeout':
        return const StartUpPlanningCloseOutPlanScreen();
      case 'deliverables_roadmap':
      case 'deliverable_roadmap':
        return const DeliverablesRoadmapScreen();
      case 'project_baseline':
        return const ProjectBaselineScreen();
      case 'organization_roles_responsibilities':
        return const OrganizationRolesResponsibilitiesScreen();
      case 'organization_raci_matrix':
        return const OrganizationRaciMatrixScreen();
      case 'organization_staffing_plan':
        return const OrganizationStaffingPlanScreen();
      case 'team_training':
        return const TeamTrainingAndBuildingScreen();
      case 'stakeholder_management':
        return const StakeholderManagementScreen();
      case 'lessons_learned':
        return const LessonsLearnedScreen();
      case 'team_management':
        return const TeamManagementScreen();
      case 'risk_assessment':
        return const RiskAssessmentScreen();
      case 'security_management':
        return const SecurityManagementScreen();
      case 'quality_management':
        return const QualityManagementScreen();

      // Design Phase
      case 'requirements_implementation':
        return const RequirementsImplementationScreen();
      case 'technical_alignment':
        return const TechnicalAlignmentScreen();
      case 'development_set_up':
        return const DevelopmentSetUpScreen();
      case 'ui_ux_design':
        return const UiUxDesignScreen();
      case 'backend_design':
        return const BackendDesignScreen();
      case 'engineering_design':
        return const EngineeringDesignScreen();
      case 'technical_development':
        return const TechnicalDevelopmentScreen();
      case 'tools_integration':
        return const ToolsIntegrationScreen();
      case 'long_lead_equipment_ordering':
        return const LongLeadEquipmentOrderingScreen();
      case 'specialized_design':
        return const SpecializedDesignScreen();
      case 'design_deliverables':
        return const DesignDeliverablesScreen();

      // Execution Phase
      case 'staff_team':
        return const StaffTeamScreen();
      case 'team_meetings':
        return const TeamMeetingsScreen();
      case 'progress_tracking':
        return const ProgressTrackingScreen();
      case 'deliverable_status_updates':
        return const DeliverableStatusUpdatesScreen();
      case 'recurring_deliverables':
        return const RecurringDeliverablesScreen();
      case 'status_reports':
        return const StatusReportsScreen();
      case 'contracts_tracking':
        return const ContractsTrackingScreen();
      case 'vendor_tracking':
        return const VendorTrackingScreen();
      case 'detailed_design':
        return const DetailedDesignScreen();
      case 'agile_development_iterations':
        return const AgileDevelopmentIterationsScreen();
      case 'scope_tracking_implementation':
        return const ScopeTrackingImplementationScreen();
      case 'stakeholder_alignment':
        return const StakeholderAlignmentScreen();
      case 'update_ops_maintenance_plans':
        return const UpdateOpsMaintenancePlansScreen();
      case 'launch_checklist':
        return const LaunchChecklistScreen();
      case 'risk_tracking':
        return const RiskTrackingScreen();
      case 'scope_completion':
        return const ScopeCompletionScreen();
      case 'gap_analysis_scope_reconcillation':
        return const GapAnalysisScopeReconcillationScreen(
            activeItemLabel: 'Gap Analysis and Scope Reconciliation');
      case 'punchlist_actions':
        return const PunchlistActionsScreen();
      case 'technical_debt_management':
        return const TechnicalDebtManagementScreen();
      case 'identify_staff_ops_team':
        return const IdentifyStaffOpsTeamScreen();
      case 'salvage_disposal_team':
        return const SalvageDisposalTeamScreen();
      case 'finalize_project':
        return const FinalizeProjectScreen();

      // Launch Phase
      case 'deliver_project_closure':
        return const DeliverProjectClosureScreen();
      case 'transition_to_prod_team':
        return const TransitionToProdTeamScreen();
      case 'contract_close_out':
        return const ContractCloseOutScreen();
      case 'vendor_account_close_out':
        return const VendorAccountCloseOutScreen();
      case 'summarize_account_risks':
        return const SummarizeAccountRisksScreen();
      case 'commerce_viability':
        return const CommerceViabilityScreen();
      case 'actual_vs_planned_gap_analysis':
        return const ActualVsPlannedGapAnalysisScreen();
      case 'project_close_out':
        return const ProjectCloseOutScreen();
      case 'demobilize_team':
        return const DemobilizeTeamScreen();

      default:
        debugPrint(
            '⚠️ Unknown checkpoint: $checkpoint (normalized: $normalizedCheckpoint), defaulting to InitiationPhaseScreen');
        return const InitiationPhaseScreen();
    }
  }
}
