import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/screens/home_screen.dart';
import 'package:ndu_project/screens/settings_screen.dart';
import 'package:ndu_project/services/auth_nav.dart';
import 'package:ndu_project/screens/initiation_phase_screen.dart';
import 'package:ndu_project/screens/potential_solutions_screen.dart';
import 'package:ndu_project/screens/risk_identification_screen.dart';
import 'package:ndu_project/screens/it_considerations_screen.dart';
import 'package:ndu_project/screens/infrastructure_considerations_screen.dart';
import 'package:ndu_project/screens/core_stakeholders_screen.dart';
import 'package:ndu_project/screens/cost_analysis_screen.dart';
import 'package:ndu_project/cost_estimate/screens/cost_estimate_module_screen.dart';
import 'package:ndu_project/wbs/screens/wbs_module_screen.dart';
import 'package:ndu_project/schedule/screens/schedule_module_screen.dart';
import 'package:ndu_project/screens/scope_tracking_plan_screen.dart';
import 'package:ndu_project/screens/front_end_planning_requirements_screen.dart';
import 'package:ndu_project/screens/front_end_planning_risks_screen.dart';
import 'package:ndu_project/screens/front_end_planning_opportunities_screen.dart';
import 'package:ndu_project/screens/front_end_planning_contract_vendor_quotes_screen.dart';
import 'package:ndu_project/screens/front_end_planning_procurement_screen.dart';
import 'package:ndu_project/screens/planning_procurement_screen.dart';
import 'package:ndu_project/screens/front_end_planning_security.dart';
import 'package:ndu_project/screens/front_end_planning_allowance.dart';
import 'package:ndu_project/screens/front_end_planning_milestone.dart';
import 'package:ndu_project/screens/front_end_planning_summary.dart';
import 'package:ndu_project/screens/project_charter_screen.dart';
import 'package:ndu_project/screens/ssher_stacked_screen.dart';
import 'package:ndu_project/screens/execution_plan_screen.dart';
import 'package:ndu_project/screens/execution_work_packages_screen.dart';
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
import 'package:ndu_project/screens/planning_technology_screen.dart';
import 'package:ndu_project/screens/team_management_screen.dart';
import 'package:ndu_project/screens/planning_contracting_screen.dart';
import 'package:ndu_project/project_controls/screens/change_management_module_screen.dart';
import 'package:ndu_project/screens/project_plan_screen.dart';
import 'package:ndu_project/screens/project_framework_next_screen.dart';
import 'package:ndu_project/screens/project_framework_screen.dart';
import 'package:ndu_project/screens/project_plan_subsections_screen.dart';
import 'package:ndu_project/screens/project_baseline_screen.dart';
import 'package:ndu_project/screens/agile_delivery_model_screen.dart';
import 'package:ndu_project/screens/agile_team_structure_screen.dart';
import 'package:ndu_project/screens/agile_epics_features_screen.dart';
import 'package:ndu_project/screens/agile_sprint_calendar_screen.dart';
import 'package:ndu_project/screens/agile_release_plan_screen.dart';
import 'package:ndu_project/screens/agile_project_baseline_screen.dart';
import 'package:ndu_project/screens/agile_backlog_governance_screen.dart';
import 'package:ndu_project/screens/agile_kanban_config_screen.dart';
import 'package:ndu_project/screens/agile_acceptance_criteria_screen.dart';
import 'package:ndu_project/screens/agile_metrics_planning_screen.dart';
import 'package:ndu_project/screens/stakeholder_management_screen.dart';
import 'package:ndu_project/screens/lessons_learned_screen.dart';
import 'package:ndu_project/screens/team_training_building_screen.dart';
import 'package:ndu_project/screens/design_phase_screen.dart';
import 'package:ndu_project/screens/design_planning_screen.dart';
import 'package:ndu_project/screens/engineering_design_screen.dart';
import 'package:ndu_project/screens/interface_management_screen.dart';
import 'package:ndu_project/screens/startup_planning_screen.dart';
import 'package:ndu_project/screens/design_deliverables_screen.dart';
import 'package:ndu_project/screens/startup_planning_subsections_screen.dart';
import 'package:ndu_project/screens/deliverable_roadmap_subsections_screen.dart';
import 'package:ndu_project/screens/organization_plan_subsections_screen.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:ndu_project/screens/issue_management_screen.dart';
import 'package:ndu_project/screens/risk_assessment_screen.dart';
import 'package:ndu_project/screens/staff_team_screen.dart';
import 'package:ndu_project/screens/team_meetings_screen.dart';
import 'package:ndu_project/screens/progress_tracking_screen.dart';
import 'package:ndu_project/screens/deliverable_status_updates_screen.dart';
import 'package:ndu_project/screens/recurring_deliverables_screen.dart';
import 'package:ndu_project/screens/status_reports_screen.dart';
import 'package:ndu_project/screens/gap_analysis_scope_reconcillation_screen.dart';
import 'package:ndu_project/screens/execution_plan_interface_management_overview_screen.dart';
import 'package:ndu_project/screens/project_decision_summary_screen.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/screens/security_management_screen.dart';
import '../screens/quality_management_screen.dart';
import 'package:ndu_project/screens/deliverables_roadmap_screen.dart';
import 'package:ndu_project/screens/finalize_project_screen.dart';
import 'package:ndu_project/screens/preferred_solution_analysis_screen.dart';
import 'package:ndu_project/screens/launch_checklist_screen.dart';
import 'package:ndu_project/screens/planning_requirements_screen.dart';

import 'package:ndu_project/screens/punchlist_actions_screen.dart';
import 'package:ndu_project/screens/tools_integration_screen.dart';
import 'package:ndu_project/screens/salvage_disposal_team_screen.dart';
import 'package:ndu_project/screens/deliver_project_closure_screen.dart';
import 'package:ndu_project/screens/transition_to_prod_team_screen.dart';
import 'package:ndu_project/screens/fat_mechanical_completion_screen.dart';
import 'package:ndu_project/screens/contract_close_out_screen.dart';
import 'package:ndu_project/screens/vendor_account_close_out_screen.dart';
import 'package:ndu_project/screens/ui_ux_design_screen.dart';
import 'package:ndu_project/screens/development_set_up_screen.dart';
import 'package:ndu_project/screens/project_close_out_screen.dart';
import 'package:ndu_project/screens/demobilize_team_screen.dart';
import 'package:ndu_project/screens/actual_vs_planned_gap_analysis_screen.dart';
import 'package:ndu_project/screens/commerce_viability_screen.dart';
import 'package:ndu_project/screens/technical_alignment_screen.dart';
import 'package:ndu_project/screens/long_lead_equipment_ordering_screen.dart';
import 'package:ndu_project/screens/specialized_design_screen.dart';
import 'package:ndu_project/screens/technical_development_screen.dart';
import 'package:ndu_project/screens/summarize_account_risks_screen.dart';
import 'package:ndu_project/screens/financial_closeout_screen.dart';
import 'package:ndu_project/screens/benefits_realization_screen.dart';
import 'package:ndu_project/screens/agile_development_iterations_screen.dart';
import 'package:ndu_project/screens/agile_project_hub_screen.dart';
import 'package:ndu_project/screens/agile_roadmap_screen.dart';
import 'package:ndu_project/screens/agile_dashboard_screen.dart';
import 'package:ndu_project/screens/agile_kanban_board_screen.dart';
import 'package:ndu_project/screens/agile_daily_standups_screen.dart';
import 'package:ndu_project/screens/agile_sprint_reviews_screen.dart';
import 'package:ndu_project/screens/agile_retrospectives_screen.dart';
import 'package:ndu_project/screens/agile_metrics_screen.dart';
import 'package:ndu_project/screens/agile_risks_screen.dart';
import 'package:ndu_project/screens/agile_ai_coach_screen.dart';
import 'package:ndu_project/screens/agile_iteration_management_screen.dart';
import 'package:ndu_project/screens/project_team_activities_screen.dart';
import 'package:ndu_project/screens/recognition_awards_screen.dart';
import 'package:ndu_project/screens/team_status_check_screen.dart';
import 'package:ndu_project/screens/team_handover_screen.dart';
import 'package:ndu_project/screens/scope_completion_screen.dart';
import 'package:ndu_project/screens/requirements_implementation_screen.dart';
import 'package:ndu_project/screens/backend_design_screen.dart';
import 'package:ndu_project/screens/technical_debt_management_screen.dart';
import 'package:ndu_project/screens/risk_tracking_screen.dart';
import 'package:ndu_project/screens/identify_staff_ops_team_screen.dart';
import 'package:ndu_project/screens/contracts_tracking_screen.dart';
import 'package:ndu_project/screens/vendor_tracking_screen.dart';
import 'package:ndu_project/screens/detailed_design_screen.dart';
import 'package:ndu_project/screens/scope_tracking_implementation_screen.dart';
import 'package:ndu_project/screens/stakeholder_alignment_screen.dart';
import 'package:ndu_project/screens/update_ops_maintenance_plans_screen.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
/// Sidebar styled to match InitiationPhaseScreen's sidebar.
class InitiationLikeSidebar extends StatefulWidget {
  const InitiationLikeSidebar(
      {super.key, this.showHeader = true, this.activeItemLabel});

  final bool showHeader;

  /// Optional: label of the item that should appear highlighted (active)
  final String? activeItemLabel;

  @override
  State<InitiationLikeSidebar> createState() => _InitiationLikeSidebarState();
}

class _InitiationLikeSidebarState extends State<InitiationLikeSidebar> {
  static const Set<String> _businessCaseLabels = {
    'Business Case Detail',
    'Potential Solutions',
    'Risk Identification',
    'IT Considerations',
    'Infrastructure Considerations',
    'Core Stakeholders',
    'Initial Cost Estimate',
    'Preferred Solution Analysis',
    'Preferred Solution',
  };

  static const Set<String> _executiveSummaryLabels = {
    'Preferred Solution Analysis',
    'Preferred Solution',
  };

  static const Set<String> _frontEndLabels = {
    'Details',
    'Summary',
    'Project Requirements',
    'Project Risks',
    'Project Opportunities',
    'Contracting',
    'Security',
    'Milestone',
    'Allowance',
    'Project Charter',
  };

  static const Set<String> _organizationPlanLabels = {
    'Organization Plan - Roles & Responsibilities',
    'Organization Plan - Staffing Plan',
    'Team Training and Team Building',
    'Stakeholder Management',
    'Team Management',
  };

  static const Set<String> _executionPlanLabels = {
    'Execution Plan Overview',
    'Execution Work Packages',
    'Executive Plan Strategy',
    'Execution Plan Details',
    'Execution Early Works',
    'Execution Enabling Work Plan',
    'Execution Issue Management',
    'Execution Stakeholder Identification',
    'Execution Plan - Construction Plan',
    'Execution Plan - Infrastructure Plan',
    'Execution Lessons Learned',
    'Execution Plan - Best Practices',
    'Execution Interface Management',
    'Execution Plan - Communication Plan',
    'Execution Interface Management Plan',
    'Execution Interface Management Overview',
  };

  static const Set<String> _technologyPlanningLabels = {
    'Technology Planning Overview',
  };

  static const Set<String> _costEstimateLabels = {
    'Cost Estimate',
  };

  static const Set<String> _projectServicesLabels = {
    'Scope Tracking Plan',
  };

  static const Set<String> _startUpPlanningLabels = {
    'Start-Up Planning',
    'Start-Up Planning - Operations Plan and Manual',
    'Start-Up Planning - Hypercare Plan',
    'Start-Up Planning - DevOps',
    'Start-Up Planning - Close Out Plan',
  };

  static const Set<String> _deliverableRoadmapLabels = {
    'Deliverable Roadmap',
    'Roadmap Overview',
  };

  static const Set<String> _agileWireframeLabels = {
    'Agile Delivery Model - Delivery Model',
    'Agile Delivery Model - Backlog Governance',
    'Agile Delivery Model - Team Structure',
    'Agile Delivery Model - Kanban Configuration',
    'Agile Delivery Model - Epics & Features',
    'Agile Delivery Model - Acceptance Criteria Planning',
    'Agile Delivery Model - Sprint Calendar',
    'Agile Delivery Model - Agile Map Out',
    'Agile Delivery Model - Release Plan',
    'Agile Delivery Model - Metrics Planning',
  };

  static const Set<String> _projectPlanLabels = {
    'Project Plan',
    'Project Plan - Level 1 - Project Schedule',
    'Project Plan - Detailed Project Schedule',
    'Project Plan - Condensed Project Summary',
  };

  static const Set<String> _designPhaseLabels = {
    'Design Phase',
    'Design Management',
    'Design Specifications',
    'Technical Alignment',
    'Development Set Up',
    'UI/UX Design',
    'Backend Design',
    'Engineering',
    'Technical Development',
    'Tools Integration',
    'Long Lead Equipment Ordering',
    'Specialized Design',
    'Design Deliverables',
  };

  static const Set<String> _progressTrackingLabels = {
    'Progress Tracking',
    'Deliverable Status Updates',
    'Recurring Deliverables',
    'Status Reports',
  };

  static const Set<String> _executionPhaseLabels = {
    'Execution Phase',
    'Staff Team',
    'Team Meetings',
    ..._progressTrackingLabels,
    'Contracts Tracking',
    'Vendor Tracking',
    'Detailed Design',
    'Agile Project Hub',
    'Scope Tracking Implementation',
    'Stakeholder Alignment',
    'Update Ops and Maintenance Plans',
    'Launch Checklist',
    'Risk Tracking',
    'Scope Completion',
    'Gap Analysis and Scope Reconciliation',
    'Punchlist Actions',
    'Technical Debt Management',
    'Identify and Staff Ops Team',
    'Salvage and/or Disposal Plan',
    'Finalize Project',
  };

  static const Set<String> _punchlistLabels = {
    'Punchlist Actions',
    'Technical Debt Management',
  };

  static const Set<String> _projectTeamLabels = {
    'Project Team Activities',
    'Project Team Activities - Mobilize Team',
    'Project Team Activities - Team Meetings',
    'Project Team Activities - Training & Team Building',
    'Project Team Activities - Recognition & Awards',
    'Project Team Activities - Team Status Check',
    'Project Team Activities - Team Handover',
    'Project Team Activities - Lessons Learned',
    'Staff Team',
    'Team Meetings',
    'Team Training and Team Building',
    'Lessons Learned',
  };

  static const Set<String> _agileHubLabels = {
    'Agile Project Hub',
    'Agile Project Hub - Agile Dashboard',
    'Agile Project Hub - Product Backlog',
    'Agile Project Hub - Sprint Planning',
    'Agile Project Hub - Iteration Management',
    'Agile Project Hub - Kanban Board',
    'Agile Project Hub - Daily Standups',
    'Agile Project Hub - Sprint Reviews',
    'Agile Project Hub - Sprint Retrospectives',
    'Agile Project Hub - Backlog Grooming',
    'Agile Project Hub - Agile Metrics',
    'Agile Project Hub - Release Planning',
    'Agile Project Hub - Agile Risks',
    'Agile Project Hub - Team Capacity',
    'Agile Project Hub - AI Agile Coach',
    'Agile Project Hub - Agile Roadmap',
  };

  static const Set<String> _projectFinancialReviewLabels = {
    'Project Financial Review',
    'Actual vs Planned Gap Analysis',
    'Project Financial Review - Scope Reconcillation',
  };

  static const Set<String> _projectCloseOutLabels = {
    'Project Close Out',
    'Project Close Out - Long Form',
    'Project Close Out - Summarized Form',
  };

  static const Set<String> _launchPhaseLabels = {
    'Launch Phase',
    'Launch Readiness Assessment',
    'Deployment Transfer, Certification & Release',
    'FAT, Mechanical Completion & Commission Solution',
    'Vendor & Contract Closeout',
    'Scope & Deliverable Reconciliation',
    'Hypercare & Warranty Support',
    'Financial Closeout',
    'Project Performance Review',
    'Benefits Realization',
    'Team Demobilization & Operations/Production Transition',
    'Project Closeout',
  };

  static const Set<String> _planningPhaseLabels = {
    'Planning Phase',
    'Project Details',
    'Work Breakdown Structure',
    'Project Goals & Milestones',
    'Requirements',
    ..._organizationPlanLabels,
    'SSHER',
    'Quality Management',
    'Design Planning',
    ..._technologyPlanningLabels,
    'Interface Management',
    ..._agileWireframeLabels,
    ..._executionPlanLabels,
    'Risk Assessment',
    'Contract',
    'Contract Planning',
    'Planning Procurement',
    'Schedule',
    ..._costEstimateLabels,
    ..._projectServicesLabels,
    'Change Management',
    'Issue Management',
    'Lessons Learned',
    'Security Management',
    ..._startUpPlanningLabels,
    ..._deliverableRoadmapLabels,
    ..._projectPlanLabels,
    'Project Baseline',
  };

  static const Set<String> _initiationPhaseLabels = {
    'Initiation Phase',
    ..._businessCaseLabels,
    ..._frontEndLabels,
  };

  // Shared expansion and scroll state across all instances so navigation
  // doesn't reset the sidebar UI state.
  static bool? _sharedInitiationExpanded;
  static bool? _sharedBusinessCaseExpanded;
  static bool? _sharedFrontEndExpanded;
  static bool? _sharedExecutionPlanExpanded;
  static bool? _sharedTechnologyPlanningExpanded;
  static bool? _sharedPlanningPhaseExpanded;
  static bool? _sharedDesignPhaseExpanded;
  static bool? _sharedExecutionPhaseExpanded;
  static bool? _sharedLaunchPhaseExpanded;
  static bool? _sharedActualVsPlannedExpanded;
  static bool? _sharedProjectCloseOutExpanded;
  static bool? _sharedExecutiveSummaryExpanded;
  static bool? _sharedProgressTrackingExpanded;
  static bool? _sharedStartUpPlanningExpanded;
  static bool? _sharedDeliverableRoadmapExpanded;
  static bool? _sharedOrganizationPlanExpanded;
  static bool? _sharedProjectPlanExpanded;
  static bool? _sharedPunchlistExpanded;
  static bool? _sharedProjectTeamExpanded;
  static bool? _sharedAgileHubExpanded;
  static bool? _sharedCostEstimateExpanded;
  static bool? _sharedProjectServicesExpanded;
  static bool? _sharedAgileWireframeExpanded;
  static double _sharedScrollOffset = 0;

  bool _initiationExpanded = _sharedInitiationExpanded ?? true;
  bool _businessCaseExpanded = _sharedBusinessCaseExpanded ?? true;
  bool _frontEndExpanded = _sharedFrontEndExpanded ?? true;
  bool _executionPlanExpanded = _sharedExecutionPlanExpanded ?? false;
  late bool _technologyPlanningExpanded =
      _sharedTechnologyPlanningExpanded ?? false;
  late bool _planningPhaseExpanded = _sharedPlanningPhaseExpanded ?? false;
  late bool _designPhaseExpanded = _sharedDesignPhaseExpanded ?? false;
  late bool _executionPhaseExpanded = _sharedExecutionPhaseExpanded ?? false;
  late bool _launchPhaseExpanded = _sharedLaunchPhaseExpanded ?? false;
  late bool _actualVsPlannedExpanded = _sharedActualVsPlannedExpanded ?? false;
  late bool _projectCloseOutExpanded = _sharedProjectCloseOutExpanded ?? false;
  late bool _executiveSummaryExpanded = _sharedExecutiveSummaryExpanded ?? true;
  late bool _progressTrackingExpanded =
      _sharedProgressTrackingExpanded ?? false;
  late bool _startUpPlanningExpanded = _sharedStartUpPlanningExpanded ?? false;
  late bool _deliverableRoadmapExpanded =
      _sharedDeliverableRoadmapExpanded ?? false;
  late bool _organizationPlanExpanded =
      _sharedOrganizationPlanExpanded ?? false;
  late bool _projectPlanExpanded = _sharedProjectPlanExpanded ?? false;
  late bool _punchlistExpanded = _sharedPunchlistExpanded ?? false;
  late bool _projectTeamExpanded = _sharedProjectTeamExpanded ?? false;
  late bool _agileHubExpanded = _sharedAgileHubExpanded ?? false;
  late bool _costEstimateExpanded = _sharedCostEstimateExpanded ?? false;
  late bool _projectServicesExpanded = _sharedProjectServicesExpanded ?? false;
  late bool _agileWireframeExpanded = _sharedAgileWireframeExpanded ?? false;
  late final ScrollController _scrollController =
      ScrollController(initialScrollOffset: _sharedScrollOffset);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _activeIn(Set<String> labels) {
    final activeLabel = widget.activeItemLabel;
    return activeLabel != null && labels.contains(activeLabel);
  }

  bool _expandForActiveLabel() {
    bool changed = false;

    void expandIf(
        Set<String> labels, bool currentValue, void Function() apply) {
      if (_activeIn(labels) && !currentValue) {
        apply();
        changed = true;
      }
    }

    expandIf(_initiationPhaseLabels, _initiationExpanded, () {
      _initiationExpanded = true;
      _sharedInitiationExpanded = true;
    });
    expandIf(_businessCaseLabels, _businessCaseExpanded, () {
      _businessCaseExpanded = true;
      _sharedBusinessCaseExpanded = true;
    });
    expandIf(_frontEndLabels, _frontEndExpanded, () {
      _frontEndExpanded = true;
      _sharedFrontEndExpanded = true;
    });
    expandIf(_executiveSummaryLabels, _executiveSummaryExpanded, () {
      _executiveSummaryExpanded = true;
      _sharedExecutiveSummaryExpanded = true;
    });
    expandIf(_planningPhaseLabels, _planningPhaseExpanded, () {
      _planningPhaseExpanded = true;
      _sharedPlanningPhaseExpanded = true;
    });
    expandIf(_organizationPlanLabels, _organizationPlanExpanded, () {
      _organizationPlanExpanded = true;
      _sharedOrganizationPlanExpanded = true;
    });
    expandIf(_technologyPlanningLabels, _technologyPlanningExpanded, () {
      _technologyPlanningExpanded = true;
      _sharedTechnologyPlanningExpanded = true;
    });
    expandIf(_executionPlanLabels, _executionPlanExpanded, () {
      _executionPlanExpanded = true;
      _sharedExecutionPlanExpanded = true;
    });
    expandIf(_costEstimateLabels, _costEstimateExpanded, () {
      _costEstimateExpanded = true;
      _sharedCostEstimateExpanded = true;
    });
    expandIf(_projectServicesLabels, _projectServicesExpanded, () {
      _projectServicesExpanded = true;
      _sharedProjectServicesExpanded = true;
    });
    expandIf(_startUpPlanningLabels, _startUpPlanningExpanded, () {
      _startUpPlanningExpanded = true;
      _sharedStartUpPlanningExpanded = true;
    });
    expandIf(_deliverableRoadmapLabels, _deliverableRoadmapExpanded, () {
      _deliverableRoadmapExpanded = true;
      _sharedDeliverableRoadmapExpanded = true;
    });
    expandIf(_agileWireframeLabels, _agileWireframeExpanded, () {
      _agileWireframeExpanded = true;
      _sharedAgileWireframeExpanded = true;
    });
    expandIf(_projectPlanLabels, _projectPlanExpanded, () {
      _projectPlanExpanded = true;
      _sharedProjectPlanExpanded = true;
    });
    expandIf(_designPhaseLabels, _designPhaseExpanded, () {
      _designPhaseExpanded = true;
      _sharedDesignPhaseExpanded = true;
    });
    expandIf(_executionPhaseLabels, _executionPhaseExpanded, () {
      _executionPhaseExpanded = true;
      _sharedExecutionPhaseExpanded = true;
    });
    expandIf(_progressTrackingLabels, _progressTrackingExpanded, () {
      _progressTrackingExpanded = true;
      _sharedProgressTrackingExpanded = true;
    });
    expandIf(_punchlistLabels, _punchlistExpanded, () {
      _punchlistExpanded = true;
      _sharedPunchlistExpanded = true;
    });
    expandIf(_projectTeamLabels, _projectTeamExpanded, () {
      _projectTeamExpanded = true;
      _sharedProjectTeamExpanded = true;
    });
    expandIf(_agileHubLabels, _agileHubExpanded, () {
      _agileHubExpanded = true;
      _sharedAgileHubExpanded = true;
    });
    expandIf(_launchPhaseLabels, _launchPhaseExpanded, () {
      _launchPhaseExpanded = true;
      _sharedLaunchPhaseExpanded = true;
    });
    expandIf(_projectFinancialReviewLabels, _actualVsPlannedExpanded, () {
      _actualVsPlannedExpanded = true;
      _sharedActualVsPlannedExpanded = true;
    });
    expandIf(_projectCloseOutLabels, _projectCloseOutExpanded, () {
      _projectCloseOutExpanded = true;
      _sharedProjectCloseOutExpanded = true;
    });

    return changed;
  }

  bool get _isBasicPlanProject {
    final provider = ProjectDataInherited.maybeOf(context);
    return provider?.projectData.isBasicPlanProject ?? false;
  }

  bool _isBasicPlanLocked(String label) {
    if (!_isBasicPlanProject) return false;
    final item = SidebarNavigationService.instance.findItemByLabel(label);
    if (item == null) return false;
    return SidebarNavigationService.instance.isItemLocked(item, true);
  }

  /// Check if a checkpoint has been reached based on Firestore project progress
  /// Returns false if the checkpoint is before the current checkpoint in sidebar order
  bool _isCheckpointReached(String checkpointName) {
    final provider = ProjectDataInherited.maybeOf(context);
    final currentCheckpoint = provider?.projectData.currentCheckpoint;

    if (currentCheckpoint == null || currentCheckpoint.isEmpty) {
      return false; // No progress yet
    }

    // Use SidebarNavigationService to check if checkpoint is reached
    return SidebarNavigationService.instance.isCheckpointReached(
      checkpointName,
      currentCheckpoint,
    );
  }

  /// Enhanced locking that checks both Basic Plan restrictions and checkpoint progress
  bool _isItemLocked(String label, String checkpointName) {
    // Check Basic Plan restrictions first
    if (_isBasicPlanLocked(label)) {
      return true;
    }

    // Check if checkpoint has been reached
    return !_isCheckpointReached(checkpointName);
  }

  @override
  void initState() {
    super.initState();
    _expandForActiveLabel();
    // Keep the shared state in sync as the user scrolls.
    _scrollController.addListener(() {
      _sharedScrollOffset = _scrollController.offset;
    });
  }

  @override
  void didUpdateWidget(covariant InitiationLikeSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_expandForActiveLabel()) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (_scrollController.hasClients) {
      _sharedScrollOffset = _scrollController.offset;
    }
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Surface missing setup context without blocking navigation.
  void _notifyPlanningPhaseRequirements() {
    final provider = ProjectDataInherited.maybeOf(context);
    if (provider == null) return;

    final projectData = provider.projectData;
    final missingFields = <String>[];

    // Check projectGoals (at least 1 required)
    if (projectData.projectGoals.isEmpty) {
      missingFields.add('Project Goals');
    }

    // Check overallFramework (not empty)
    if (projectData.overallFramework == null ||
        projectData.overallFramework!.isEmpty) {
      missingFields.add('Overall Framework');
    }

    if (missingFields.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Opening this page with partial setup. Missing context: ${missingFields.join(', ')}. AI or manual entry can fill this in later.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFD97706),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Project Details',
              textColor: Colors.white,
              onPressed: () {
                _openProjectFramework();
              },
            ),
          ),
        );
      }
    }
  }

  // Navigation helper.
  //
  // Goal: keep navigation responsive by not blocking route transitions on
  // network writes. We still persist data/checkpoint in the background.
  void _navigateWithCheckpoint(String checkpoint, Widget screen) {
    // Validate Planning Phase requirements for Planning Phase checkpoints
    final planningPhaseCheckpoints = [
      'work_breakdown_structure',
      'ssher',
      'change_management',
      'issue_management',
      'cost_estimate',
      'scope_tracking_plan',
      'contracts',
      'project_plan',
      'execution_plan',
      'schedule',
      'design',
      'technology',
      'interface_management',
      'startup_planning',
      'deliverable_roadmap',
      'deliverables_roadmap',
      'project_baseline',
      'organization_roles_responsibilities',
      'organization_staffing_plan',
      'team_training',
      'stakeholder_management',
      'lessons_learned',
      'team_management',
      'risk_assessment',
      'security_management',
      'quality_management',
    ];

    final agileWireframeCheckpoints = [
      'agile_delivery_model',
      'agile_backlog_governance',
      'agile_team_structure',
      'agile_kanban_config',
      'agile_epics_features',
      'agile_acceptance_criteria',
      'agile_sprint_calendar',
      'agile_map_out',
      'agile_release_plan',
      'agile_metrics_planning',
    ];
    if (planningPhaseCheckpoints.contains(checkpoint) ||
        agileWireframeCheckpoints.contains(checkpoint)) {
      _notifyPlanningPhaseRequirements();
    }

    final provider = ProjectDataInherited.maybeOf(context);
    final currentCheckpoint = provider?.projectData.currentCheckpoint;

    if (!mounted) return;
    PhaseTransitionHelper.pushPhaseAware(
      context: context,
      builder: (_) => screen,
      destinationCheckpoint: checkpoint,
      sourceCheckpoint: currentCheckpoint,
    );

    // Persist in background (no awaiting on UI thread).
    final projectId = provider?.projectData.projectId;
    if (provider != null && projectId != null && projectId.isNotEmpty) {
      // Update in-memory state immediately so other widgets (e.g. sidebars) can
      // reflect progress without waiting on Firestore.
      provider
          .updateField((data) => data.copyWith(currentCheckpoint: checkpoint));

      // Fast local persistence for "resume where you left off".
      Future<void>(() => ProjectNavigationService.instance
          .saveLastPageLocal(projectId, checkpoint));

      // Full remote save in the background so user data isn't lost if the app
      // is terminated later.
      Future<void>(() async {
        try {
          await provider.saveToFirebase(checkpoint: checkpoint);
        } catch (e) {
          debugPrint('Checkpoint save error (background): $e');
        }
      });
    }
  }

  // Navigation helpers (lightweight routes, pass empty data where required)
  void _openBusinessCase() {
    _navigateWithCheckpoint(
      'business_case',
      const InitiationPhaseScreen(scrollToBusinessCase: true),
    );
  }

  void _openPotentialSolutions() {
    _navigateWithCheckpoint(
        'potential_solutions', const PotentialSolutionsScreen());
  }

  void _openRiskIdentification() {
    final data = ProjectDataInherited.of(context).projectData;
    _navigateWithCheckpoint(
      'risk_identification',
      RiskIdentificationScreen(
        notes: data.notes,
        solutions: _buildSolutionItems(data),
        businessCase: data.businessCase,
      ),
    );
  }

  void _openITConsiderations() {
    final data = ProjectDataInherited.of(context).projectData;
    _navigateWithCheckpoint(
      'it_considerations',
      ITConsiderationsScreen(
        notes: data.itConsiderationsData?.notes ?? data.notes,
        solutions: _buildSolutionItems(data),
      ),
    );
  }

  void _openInfrastructureConsiderations() {
    final data = ProjectDataInherited.of(context).projectData;
    _navigateWithCheckpoint(
      'infrastructure_considerations',
      InfrastructureConsiderationsScreen(
        notes: data.infrastructureConsiderationsData?.notes ?? data.notes,
        solutions: _buildSolutionItems(data),
      ),
    );
  }

  void _openCoreStakeholders() {
    final data = ProjectDataInherited.of(context).projectData;
    _navigateWithCheckpoint(
      'core_stakeholders',
      CoreStakeholdersScreen(
        notes: data.coreStakeholdersData?.notes ?? data.notes,
        solutions: _buildSolutionItems(data),
      ),
    );
  }

  void _openCostAnalysis() {
    final data = ProjectDataInherited.of(context).projectData;
    _navigateWithCheckpoint(
      'cost_analysis',
      CostAnalysisScreen(
        notes: data.notes,
        solutions: _buildSolutionItems(data),
      ),
    );
  }

  List<AiSolutionItem> _buildSolutionItems(ProjectDataModel data) {
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

  void _openFrontEndRequirements() {
    _navigateWithCheckpoint(
        'fep_requirements', const FrontEndPlanningRequirementsScreen());
  }

  void _openPlanningRequirements() {
    _navigateWithCheckpoint('requirements', PlanningRequirementsScreen());
  }

  void _openFrontEndRisks() {
    _navigateWithCheckpoint('fep_risks', const FrontEndPlanningRisksScreen());
  }

  void _openFrontEndOpportunities() {
    _navigateWithCheckpoint(
        'fep_opportunities', const FrontEndPlanningOpportunitiesScreen());
  }

  void _openContractVendorQuotes() {
    // Security check: prevent navigation if item is locked
    if (_isBasicPlanLocked('Contracting')) {
      _showLockedItemMessage('Contracting');
      return;
    }
    _navigateWithCheckpoint('fep_contract_vendor_quotes',
        const FrontEndPlanningContractVendorQuotesScreen());
  }

  void _openSecurity() {
    // Security check: prevent navigation if item is locked
    if (_isBasicPlanLocked('Security')) {
      _showLockedItemMessage('Security');
      return;
    }
    _navigateWithCheckpoint(
        'fep_security', const FrontEndPlanningSecurityScreen());
  }

  void _openAllowance() {
    // Security check: prevent navigation if item is locked
    if (_isBasicPlanLocked('Allowance')) {
      _showLockedItemMessage('Allowance');
      return;
    }
    _navigateWithCheckpoint(
        'fep_allowance', const FrontEndPlanningAllowanceScreen());
  }

  void _openMilestone() {
    _navigateWithCheckpoint(
        'fep_milestone', const FrontEndPlanningMilestoneScreen());
  }

  void _showLockedItemMessage(String itemName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '$itemName is not available in your current plan. Please upgrade to access this feature.'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openSummary() async {
    if (mounted) {
      FrontEndPlanningSummaryScreen.open(context);
    }

    // Persist checkpoint in the background to keep navigation responsive.
    final provider = ProjectDataInherited.maybeOf(context);
    final projectId = provider?.projectData.projectId;
    if (provider != null && projectId != null && projectId.isNotEmpty) {
      provider.updateField(
          (data) => data.copyWith(currentCheckpoint: 'fep_summary'));
      Future<void>(() => ProjectNavigationService.instance
          .saveLastPageLocal(projectId, 'fep_summary'));
      Future<void>(() async {
        try {
          await provider.saveToFirebase(checkpoint: 'fep_summary');
        } catch (e) {
          debugPrint('Checkpoint save error (background): $e');
        }
      });
    }
  }

  Future<void> _openProjectCharter() async {
    if (mounted) {
      ProjectCharterScreen.open(context);
    }

    // Persist checkpoint in the background to keep navigation responsive.
    final provider = ProjectDataInherited.maybeOf(context);
    final projectId = provider?.projectData.projectId;
    if (provider != null && projectId != null && projectId.isNotEmpty) {
      provider.updateField(
          (data) => data.copyWith(currentCheckpoint: 'project_charter'));
      Future<void>(() => ProjectNavigationService.instance
          .saveLastPageLocal(projectId, 'project_charter'));
      Future<void>(() async {
        try {
          await provider.saveToFirebase(checkpoint: 'project_charter');
        } catch (e) {
          debugPrint('Checkpoint save error (background): $e');
        }
      });
    }
  }

  void _openProcurement() {
    _navigateWithCheckpoint(
        'fep_procurement', const FrontEndPlanningProcurementScreen());
  }

  void _openPlanningProcurement() {
    _navigateWithCheckpoint('procurement', const PlanningProcurementScreen());
  }

  void _openSSHER() {
    _navigateWithCheckpoint('ssher', const SsherStackedScreen());
  }

  void _openDesign() {
    _navigateWithCheckpoint('design', const DesignPlanningScreen());
  }

  void _openDesignManagement() {
    _navigateWithCheckpoint('design_management',
        const DesignPhaseScreen(activeItemLabel: 'Design Management'));
  }

  // ignore: unused_element
  void _openExecutionPlan() {
    _navigateWithCheckpoint('execution_plan', const ExecutionPlanScreen());
  }

  void _openExecutionWorkPackages() {
    _navigateWithCheckpoint('execution_work_packages',
        const ExecutionWorkPackagesScreen());
  }

  // ignore: unused_element
  void _openExecutionPlanStrategy() {
    _navigateWithCheckpoint(
        'execution_plan_strategy', const ExecutionPlanSolutionsScreen());
  }

  // ignore: unused_element
  void _openExecutionPlanDetails() {
    _navigateWithCheckpoint(
      'execution_plan_details',
      const ExecutionPlanDetailsScreen(
        activeItemLabel: 'Execution Plan Details',
        showPlanDetails: true,
        showEarlyWorks: false,
      ),
    );
  }

  // ignore: unused_element
  void _openExecutionEarlyWorks() {
    _navigateWithCheckpoint(
      'execution_early_works',
      const ExecutionPlanDetailsScreen(
        activeItemLabel: 'Execution Early Works',
        showPlanDetails: false,
        showEarlyWorks: true,
      ),
    );
  }

  // ignore: unused_element
  void _openExecutionEnablingWorkPlan() {
    _navigateWithCheckpoint('execution_enabling_work_plan',
        const ExecutionEnablingWorkPlanScreen());
  }

  // ignore: unused_element
  void _openExecutionIssueManagement() {
    _navigateWithCheckpoint(
        'execution_issue_management', const ExecutionIssueManagementScreen());
  }

  // ignore: unused_element
  void _openExecutionPlanLessonsLearned() {
    _navigateWithCheckpoint('execution_plan_lessons_learned',
        const ExecutionPlanLessonsLearnedScreen());
  }

  // ignore: unused_element
  void _openExecutionPlanBestPractices() {
    _navigateWithCheckpoint('execution_plan_best_practices',
        const ExecutionPlanBestPracticesScreen());
  }

  void _openExecutionPlanConstructionPlan() {
    _navigateWithCheckpoint('execution_plan_construction_plan',
        const ExecutionPlanConstructionPlanScreen());
  }

  void _openExecutionPlanInfrastructurePlan() {
    _navigateWithCheckpoint('execution_plan_infrastructure_plan',
        const ExecutionPlanInfrastructurePlanScreen());
  }

  void _openExecutionPlanAgileDeliveryPlan() {
    _navigateWithCheckpoint('execution_plan_agile_delivery_plan',
        const ExecutionPlanAgileDeliveryPlanScreen());
  }

  // ignore: unused_element
  void _openExecutionPlanInterfaceManagement() {
    _navigateWithCheckpoint('execution_plan_interface_management',
        const ExecutionPlanInterfaceManagementScreen());
  }

  // ignore: unused_element
  void _openExecutionPlanCommunicationPlan() {
    _navigateWithCheckpoint('execution_plan_communication_plan',
        const ExecutionPlanCommunicationPlanScreen());
  }

  // ignore: unused_element
  void _openExecutionPlanInterfaceManagementPlan() {
    _navigateWithCheckpoint('execution_plan_interface_management_plan',
        const ExecutionPlanInterfaceManagementPlanScreen());
  }

  // ignore: unused_element
  void _openExecutionPlanInterfaceManagementOverview() {
    _navigateWithCheckpoint('execution_plan_interface_management_overview',
        const ExecutionPlanInterfaceManagementOverviewScreen());
  }

  // ignore: unused_element
  void _openExecutionPlanStakeholderIdentification() {
    _navigateWithCheckpoint('execution_plan_stakeholder_identification',
        const ExecutionPlanStakeholderIdentificationScreen());
  }

  void _openTechnology() {
    _navigateWithCheckpoint('technology', const PlanningTechnologyScreen());
  }

  void _openInterfaceManagement() {
    _navigateWithCheckpoint(
        'interface_management', const InterfaceManagementScreen());
  }

  void _openAgileDeliveryModel() {
    _navigateWithCheckpoint(
        'agile_delivery_model', const AgileDeliveryModelScreen());
  }

  void _openAgileTeamStructure() {
    _navigateWithCheckpoint(
        'agile_team_structure', const AgileTeamStructureScreen());
  }

  void _openAgileEpicsFeatures() {
    _navigateWithCheckpoint(
        'agile_epics_features', const AgileEpicsFeaturesScreen());
  }

  void _openAgileSprintCalendar() {
    _navigateWithCheckpoint(
        'agile_sprint_calendar', const AgileSprintCalendarScreen());
  }

  void _openAgileMapOut() {
    _navigateWithCheckpoint(
        'agile_map_out', const DeliverableRoadmapAgileMapOutScreen());
  }

  void _openAgileReleasePlan() {
    _navigateWithCheckpoint(
        'agile_release_plan', const AgileReleasePlanScreen());
  }

  void _openAgileBacklogGovernance() {
    _navigateWithCheckpoint(
        'agile_backlog_governance', const AgileBacklogGovernanceScreen());
  }

  void _openAgileProjectBaseline() {
    _navigateWithCheckpoint(
        'agile_project_baseline', const AgileProjectBaselineScreen());
  }

  void _openAgileKanbanConfig() {
    _navigateWithCheckpoint(
        'agile_kanban_config', const AgileKanbanConfigScreen());
  }

  void _openAgileAcceptanceCriteria() {
    _navigateWithCheckpoint(
        'agile_acceptance_criteria', const AgileAcceptanceCriteriaScreen());
  }

  void _openAgileMetricsPlanning() {
    _navigateWithCheckpoint(
        'agile_metrics_planning', const AgileMetricsPlanningScreen());
  }

  void _openStartUpPlanning() {
    _navigateWithCheckpoint('startup_planning', const StartUpPlanningScreen());
  }

  void _openStartUpPlanningOperations() {
    _navigateWithCheckpoint(
      'startup_planning_operations',
      const StartUpPlanningOperationsScreen(),
    );
  }

  void _openStartUpPlanningHypercare() {
    _navigateWithCheckpoint(
      'startup_planning_hypercare',
      const StartUpPlanningHypercareScreen(),
    );
  }

  void _openStartUpPlanningDevOps() {
    _navigateWithCheckpoint(
      'startup_planning_devops',
      const StartUpPlanningDevOpsScreen(),
    );
  }

  void _openStartUpPlanningCloseOut() {
    _navigateWithCheckpoint(
      'startup_planning_closeout',
      const StartUpPlanningCloseOutPlanScreen(),
    );
  }

  void _openTeamManagement() {
    _navigateWithCheckpoint('team_management', const TeamManagementScreen());
  }

  void _openSecurityManagement() {
    _navigateWithCheckpoint(
        'security_management', const SecurityManagementScreen());
  }

  void _openQualityManagement() {
    _navigateWithCheckpoint(
        'quality_management', const QualityManagementScreen());
  }

  void _openContract() {
    _navigateWithCheckpoint('contracts', const PlanningContractingScreen());
  }

  void _openSchedule() {
    _navigateWithCheckpoint('schedule', const ScheduleModuleScreen());
  }

  void _openCostEstimate() {
    _navigateWithCheckpoint('cost_estimate', const CostEstimateModuleScreen());
  }

  void _openScopeTrackingPlan() {
    _navigateWithCheckpoint(
        'scope_tracking_plan', const ScopeTrackingPlanScreen());
  }

  void _openChangeManagement() {
    _navigateWithCheckpoint('change_management', const ChangeManagementModuleScreen());
  }

  void _openProjectPlan() {
    _navigateWithCheckpoint('project_plan', const ProjectPlanScreen());
  }

  void _openProjectPlanLevel1Schedule() {
    _navigateWithCheckpoint('project_plan_level1_schedule',
        const ProjectPlanLevel1ScheduleScreen());
  }

  void _openProjectPlanDetailedSchedule() {
    _navigateWithCheckpoint('project_plan_detailed_schedule',
        const ProjectPlanDetailedScheduleScreen());
  }

  void _openProjectPlanCondensedSummary() {
    _navigateWithCheckpoint('project_plan_condensed_summary',
        const ProjectPlanCondensedSummaryScreen());
  }

  void _openProjectBaseline() {
    _navigateWithCheckpoint('project_baseline', const ProjectBaselineScreen());
  }

  void _openStakeholderManagement() {
    _navigateWithCheckpoint(
        'stakeholder_management', const StakeholderManagementScreen());
  }

  void _openRiskAssessment() {
    _navigateWithCheckpoint('risk_assessment', const RiskAssessmentScreen());
  }

  void _openIssueManagement() {
    _navigateWithCheckpoint('issue_management', const IssueManagementScreen());
  }

  void _openLessonsLearned() {
    _navigateWithCheckpoint('lessons_learned', const LessonsLearnedScreen());
  }

  void _openTeamTraining() {
    _navigateWithCheckpoint(
        'team_training', const TeamTrainingAndBuildingScreen());
  }

  void _openOrganizationRolesResponsibilities() {
    _navigateWithCheckpoint('organization_roles_responsibilities',
        const OrganizationRolesResponsibilitiesScreen());
  }

  void _openOrganizationStaffingPlan() {
    _navigateWithCheckpoint(
        'organization_staffing_plan', const OrganizationStaffingPlanScreen());
  }

  void _openStaffTeam() {
    _navigateWithCheckpoint('staff_team', const StaffTeamScreen());
  }

  void _openProjectTeamActivities() {
    _navigateWithCheckpoint('staff_team', const ProjectTeamActivitiesScreen());
  }

  void _openRecognitionAwards() {
    _navigateWithCheckpoint('staff_team', const RecognitionAwardsScreen());
  }

  void _openTeamStatusCheck() {
    _navigateWithCheckpoint('staff_team', const TeamStatusCheckScreen());
  }

  void _openTeamHandover() {
    _navigateWithCheckpoint('staff_team', const TeamHandoverScreen());
  }

  void _openTeamMeetings() {
    _navigateWithCheckpoint('team_meetings', const TeamMeetingsScreen());
  }

  void _openProgressTracking() {
    _navigateWithCheckpoint(
        'progress_tracking', const ProgressTrackingScreen());
  }

  void _openDeliverableStatusUpdates() {
    _navigateWithCheckpoint(
        'deliverable_status_updates', const DeliverableStatusUpdatesScreen());
  }

  void _openRecurringDeliverables() {
    _navigateWithCheckpoint(
        'recurring_deliverables', const RecurringDeliverablesScreen());
  }

  void _openStatusReports() {
    _navigateWithCheckpoint('status_reports', const StatusReportsScreen());
  }

  void _openGapAnalysisAndScopeReconcillation() {
    _navigateWithCheckpoint('gap_analysis_scope_reconcillation',
        const GapAnalysisScopeReconcillationScreen());
  }

  void _openLaunchChecklist() {
    _navigateWithCheckpoint('launch_checklist', const LaunchChecklistScreen());
  }

  void _openPunchlistActions() {
    _navigateWithCheckpoint(
        'punchlist_actions', const PunchlistActionsScreen());
  }

  void _openToolsIntegration() {
    _navigateWithCheckpoint(
        'tools_integration', const ToolsIntegrationScreen());
  }

  void _openSalvageDisposalTeam() {
    _navigateWithCheckpoint(
        'salvage_disposal_team', const SalvageDisposalTeamScreen());
  }

  void _openDeliverProjectClosure() {
    _navigateWithCheckpoint(
        'deliver_project_closure', const DeliverProjectClosureScreen());
  }

  void _openTransitionToProdTeam() {
    _navigateWithCheckpoint(
        'transition_to_prod_team', const TransitionToProdTeamScreen());
  }

  void _openContractCloseOut() {
    _navigateWithCheckpoint(
        'contract_close_out', const ContractCloseOutScreen());
  }

  void _openVendorAccountCloseOut() {
    _navigateWithCheckpoint(
        'vendor_account_close_out', const VendorAccountCloseOutScreen());
  }

  void _openUiUxDesign() {
    _navigateWithCheckpoint('ui_ux_design', const UiUxDesignScreen());
  }

  void _openTechnicalAlignment() {
    _navigateWithCheckpoint(
        'technical_alignment', const TechnicalAlignmentScreen());
  }

  void _openDevelopmentSetUp() {
    _navigateWithCheckpoint(
        'development_set_up', const DevelopmentSetUpScreen());
  }

  void _openDesignDeliverables() {
    _navigateWithCheckpoint(
        'design_deliverables', const DesignDeliverablesScreen());
  }

  void _openLongLeadEquipmentOrdering() {
    _navigateWithCheckpoint('long_lead_equipment_ordering',
        const LongLeadEquipmentOrderingScreen());
  }

  void _openSpecializedDesign() {
    _navigateWithCheckpoint(
        'specialized_design', const SpecializedDesignScreen());
  }

  void _openTechnicalDevelopment() {
    _navigateWithCheckpoint(
        'technical_development', const TechnicalDevelopmentScreen());
  }

  void _openBackendDesign() {
    _navigateWithCheckpoint('backend_design', const BackendDesignScreen());
  }

  void _openEngineeringDesign() {
    _navigateWithCheckpoint(
        'engineering_design', const EngineeringDesignScreen());
  }

  // ignore: unused_element
  void _openProjectCloseOut() {
    _navigateWithCheckpoint('project_close_out', const ProjectCloseOutScreen());
  }

  void _openProjectCloseOutLongForm() {
    _navigateWithCheckpoint(
      'project_close_out',
      const ProjectCloseOutScreen(
        summarized: false,
        activeItemLabel: 'Project Close Out - Long Form',
      ),
    );
  }

  void _openProjectCloseOutSummarized() {
    _navigateWithCheckpoint(
      'project_close_out',
      const ProjectCloseOutScreen(
        summarized: true,
        activeItemLabel: 'Project Close Out - Summarized Form',
      ),
    );
  }

  void _openDemobilizeTeam() {
    _navigateWithCheckpoint('demobilize_team', const DemobilizeTeamScreen());
  }

  void _openActualVsPlannedGapAnalysis() {
    _navigateWithCheckpoint('actual_vs_planned_gap_analysis',
        const ActualVsPlannedGapAnalysisScreen());
  }

  void _openActualVsPlannedScopeReconcillation() {
    _navigateWithCheckpoint(
      'actual_vs_planned_gap_analysis',
      const GapAnalysisScopeReconcillationScreen(
        activeItemLabel: 'Project Financial Review - Scope Reconcillation',
      ),
    );
  }

  void _openCommerceViability() {
    _navigateWithCheckpoint(
        'commerce_viability', const CommerceViabilityScreen());
  }

  void _openSummarizeAccountRisks() {
    _navigateWithCheckpoint(
        'summarize_account_risks', const SummarizeAccountRisksScreen());
  }

  void _openFatMechanicalCompletion() {
    _navigateWithCheckpoint('fat_mechanical_completion',
        const FatMechanicalCompletionScreen());
  }

  void _openFinancialCloseout() {
    _navigateWithCheckpoint(
        'financial_closeout', const FinancialCloseoutScreen());
  }

  void _openBenefitsRealization() {
    _navigateWithCheckpoint(
        'benefits_realization', const BenefitsRealizationScreen());
  }

  void _openAgileDevelopmentIterations() {
    _navigateWithCheckpoint('agile_development_iterations',
        const AgileDevelopmentIterationsScreen());
  }

  void _openAgileProjectHub() {
    _navigateWithCheckpoint('agile_development_iterations',
        const AgileProjectHubScreen());
  }

  void _showAgileComingSoon(String sectionName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(sectionName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          ],
        ),
        content: const Text(
          'This section is being activated as part of the Agile Project Hub rollout. '
          'Data from earlier phases flows into this module automatically.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF6366F1)),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _openScopeCompletion() {
    _navigateWithCheckpoint('scope_completion', const ScopeCompletionScreen());
  }

  void _openTechnicalDebtManagement() {
    _navigateWithCheckpoint(
        'technical_debt_management', const TechnicalDebtManagementScreen());
  }

  void _openRiskTracking() {
    _navigateWithCheckpoint('risk_tracking', const RiskTrackingScreen());
  }

  void _openIdentifyStaffOpsTeam() {
    _navigateWithCheckpoint(
        'identify_staff_ops_team', const IdentifyStaffOpsTeamScreen());
  }

  void _openFinalizeProject() {
    _navigateWithCheckpoint('finalize_project', const FinalizeProjectScreen());
  }

  void _openContractsTracking() {
    _navigateWithCheckpoint(
        'contracts_tracking', const ContractsTrackingScreen());
  }

  void _openVendorTracking() {
    _navigateWithCheckpoint('vendor_tracking', const VendorTrackingScreen());
  }

  void _openDetailedDesign() {
    _navigateWithCheckpoint('detailed_design', const DetailedDesignScreen());
  }

  void _openScopeTrackingImplementation() {
    _navigateWithCheckpoint('scope_tracking_implementation',
        const ScopeTrackingImplementationScreen());
  }

  void _openStakeholderAlignment() {
    _navigateWithCheckpoint(
        'stakeholder_alignment', const StakeholderAlignmentScreen());
  }

  void _openUpdateOpsMaintenancePlans() {
    _navigateWithCheckpoint('update_ops_maintenance_plans',
        const UpdateOpsMaintenancePlansScreen());
  }

  void _openRequirementsImplementation() {
    _navigateWithCheckpoint('requirements_implementation',
        const RequirementsImplementationScreen());
  }

  void _openDeliverableRoadmap() {
    _navigateWithCheckpoint(
        'deliverable_roadmap', const DeliverablesRoadmapScreen());
  }

  void _openDeliverableRoadmapAgileMapOut() {
    _navigateWithCheckpoint(
        'agile_map_out', const DeliverableRoadmapAgileMapOutScreen());
  }

  Future<void> _openExecutiveSummary() async {
    if (mounted) {
      final provider = ProjectDataInherited.maybeOf(context);
      final projectData = provider?.projectData;
      final preferredAnalysis = projectData?.preferredSolutionAnalysis;

      // Get the selected solution from potential solutions
      final potentialSolutions = projectData?.potentialSolutions ?? [];
      if (potentialSolutions.isEmpty) {
        // No solutions available, show a message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No solutions available. Please complete the Potential Solutions step first.')),
        );
        return;
      }

      // Persist checkpoint in the background (after we know we're actually opening).
      final projectId = projectData?.projectId;
      if (provider != null && projectId != null && projectId.isNotEmpty) {
        provider.updateField(
            (data) => data.copyWith(currentCheckpoint: 'executive_summary'));
        Future<void>(() => ProjectNavigationService.instance
            .saveLastPageLocal(projectId, 'executive_summary'));
        Future<void>(() async {
          try {
            await provider.saveToFirebase(checkpoint: 'executive_summary');
          } catch (e) {
            debugPrint('Checkpoint save error (background): $e');
          }
        });
      }

      // Convert PotentialSolution to AiSolutionItem
      final solutions = potentialSolutions
          .map((s) => AiSolutionItem(
                title: s.title,
                description: s.description,
              ))
          .toList();

      // Find the selected solution or use the first one
      AiSolutionItem selectedSolution;
      if (preferredAnalysis?.selectedSolutionTitle != null) {
        selectedSolution = solutions.firstWhere(
          (s) => s.title == preferredAnalysis!.selectedSolutionTitle,
          orElse: () => solutions.first,
        );
      } else {
        selectedSolution = solutions.first;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectDecisionSummaryScreen(
            projectName: projectData?.projectName ?? 'Untitled Project',
            selectedSolution: selectedSolution,
            allSolutions: solutions,
            businessCase: projectData?.businessCase ?? '',
            notes: preferredAnalysis?.workingNotes ?? '',
          ),
        ),
      );
    }
  }

  void _openPreferredSolutionAnalysis() {
    try {
      final provider = ProjectDataInherited.maybeOf(context);
      final projectData = provider?.projectData;
      final potentialSolutions = projectData?.potentialSolutions ?? [];
      final solutions = potentialSolutions
          .map(
              (s) => AiSolutionItem(title: s.title, description: s.description))
          .toList();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreferredSolutionAnalysisScreen(
            notes: projectData?.preferredSolutionAnalysis?.workingNotes ?? '',
            solutions: solutions,
            businessCase: projectData?.businessCase ?? '',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Navigation error (Preferred Solution Analysis): $e');
    }
  }

  void _openPreferredSolutionsComparison() {
    try {
      final provider = ProjectDataInherited.maybeOf(context);
      final projectData = provider?.projectData;
      final potentialSolutions = projectData?.potentialSolutions ?? [];
      final solutions = potentialSolutions
          .map(
              (s) => AiSolutionItem(title: s.title, description: s.description))
          .toList();
      final safeSolutions = solutions.isNotEmpty
          ? solutions
          : [
              AiSolutionItem(
                title: projectData?.projectName ?? 'Preferred Solution',
                description: projectData?.businessCase ?? '',
              ),
            ];
      final preferredAnalysis = projectData?.preferredSolutionAnalysis;
      final selectedSolution =
          (preferredAnalysis?.selectedSolutionTitle != null)
              ? safeSolutions.firstWhere(
                  (s) => s.title == preferredAnalysis!.selectedSolutionTitle,
                  orElse: () => safeSolutions.first,
                )
              : safeSolutions.first;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectDecisionSummaryScreen(
            projectName: projectData?.projectName ?? 'Untitled Project',
            selectedSolution: selectedSolution,
            allSolutions: safeSolutions,
            businessCase: projectData?.businessCase ?? '',
            notes: preferredAnalysis?.workingNotes ?? '',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Navigation error (Preferred Solution): $e');
    }
  }

  void _openWorkBreakdownStructure() {
    _navigateWithCheckpoint(
        'work_breakdown_structure', const WBSModuleScreen());
  }

  void _openProjectFramework() {
    _navigateWithCheckpoint(
        'project_framework', const ProjectFrameworkScreen());
  }

  void _openProjectGoalsMilestones() {
    _navigateWithCheckpoint(
        'project_goals_milestones', const ProjectFrameworkNextScreen());
  }

  Widget _buildMenuItem(IconData icon, String title,
      {VoidCallback? onTap, bool isActive = false, bool isDisabled = false}) {
    const activeColor = Color(0xFFD97706);
    final isInteractive = !isDisabled && onTap != null;
    final isHighlighted = isActive && !isDisabled;
    final textColor = isDisabled
        ? Colors.grey[400]
        : (isHighlighted ? activeColor : Colors.black87);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: AbsorbPointer(
        absorbing: !isInteractive,
        child: InkWell(
          onTap: isInteractive ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? activeColor.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isHighlighted
                  ? Border.all(color: activeColor.withOpacity(0.20))
                  : null,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: textColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      fontWeight:
                          isHighlighted ? FontWeight.w600 : FontWeight.normal,
                    ),
                    softWrap: true,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubMenuItem(String title,
      {VoidCallback? onTap, bool isActive = false, bool isDisabled = false}) {
    const activeColor = Color(0xFFD97706);
    final isInteractive = !isDisabled && onTap != null;
    final isHighlighted = isActive && !isDisabled;
    final textColor = isDisabled
        ? Colors.grey[400]
        : (isHighlighted ? activeColor : Colors.black87);

    return Padding(
      padding: const EdgeInsets.only(left: 48, right: 24, top: 2, bottom: 2),
      child: AbsorbPointer(
        absorbing: !isInteractive,
        child: InkWell(
          onTap: isInteractive ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? activeColor.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isHighlighted
                  ? Border.all(color: activeColor.withOpacity(0.18))
                  : null,
            ),
            child: Row(
              children: [
                Icon(Icons.circle,
                    size: 8,
                    color: isDisabled
                        ? Colors.grey[400]
                        : (isHighlighted ? activeColor : Colors.grey[500])),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor,
                      fontWeight:
                          isHighlighted ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubExpandableHeader(String title,
      {required bool expanded,
      required VoidCallback onTap,
      bool isActive = false,
      bool isDisabled = false}) {
    const activeColor = Color(0xFFD97706);
    final isInteractive = !isDisabled;
    final isHighlighted = isActive && !isDisabled;
    final textColor = isDisabled
        ? Colors.grey[400]
        : (isHighlighted ? activeColor : Colors.black87);
    return Padding(
      padding: const EdgeInsets.only(left: 48, right: 24, top: 2, bottom: 2),
      child: InkWell(
        onTap: isInteractive ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isHighlighted
                ? activeColor.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isHighlighted
                ? Border.all(color: activeColor.withOpacity(0.18))
                : null,
          ),
          child: Row(
            children: [
              Icon(Icons.circle,
                  size: 8,
                  color: isDisabled
                      ? Colors.grey[400]
                      : (isHighlighted ? activeColor : Colors.grey[500])),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor,
                    fontWeight:
                        isHighlighted ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: isDisabled ? Colors.grey[400] : Colors.grey[600],
                  size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubSubMenuItem(String title,
      {VoidCallback? onTap, bool isActive = false, bool isDisabled = false}) {
    const activeColor = Color(0xFFD97706);
    final isInteractive = !isDisabled && onTap != null;
    final isHighlighted = isActive && !isDisabled;
    final textColor = isDisabled
        ? Colors.grey[400]
        : (isHighlighted ? activeColor : Colors.black87);
    return Padding(
      padding: const EdgeInsets.only(left: 72, right: 24, top: 2, bottom: 2),
      child: AbsorbPointer(
        absorbing: !isInteractive,
        child: InkWell(
          onTap: isInteractive
              ? onTap
              : (isDisabled ? () => _showLockedItemMessage(title) : null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? activeColor.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isHighlighted
                  ? Border.all(color: activeColor.withOpacity(0.15))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDisabled
                        ? Colors.grey[300]
                        : (isHighlighted ? activeColor : Colors.grey[400]),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor,
                      fontWeight:
                          isHighlighted ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableHeader(IconData icon, String title,
      {required bool expanded,
      required VoidCallback onTap,
      bool isActive = false}) {
    const activeColor = Color(0xFFD97706);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: activeColor.withOpacity(0.20))
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isActive ? activeColor : Colors.black87),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isActive ? activeColor : Colors.black87,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: isActive ? activeColor : Colors.grey[700],
                  size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bannerHeight = AppBreakpoints.isMobile(context) ? 72 : 96;
    final sidebarWidth = AppBreakpoints.sidebarWidth(context);
    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
              color: Colors.grey.withOpacity(0.25), width: 0.8),
        ),
      ),
      child: Column(
        children: [
          if (widget.showHeader) ...[
            // Full-width banner image above "StackOne"
            SizedBox(
              width: double.infinity,
              height: bannerHeight,
              child: Center(child: AppLogo(height: 64)),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFFFD700), width: 1),
                ),
              ),
              child: Builder(
                builder: (context) {
                  final provider = ProjectDataInherited.maybeOf(context);
                  final projectData = provider?.projectData;
                  final projectName =
                      projectData?.projectName.trim().isNotEmpty == true
                          ? projectData!.projectName
                          : 'Untitled Project';
                  return Text(
                    projectName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: VoiceTextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(
                      color: Color(0xFF1A1D1F),
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Search menu...',
                    hintStyle: TextStyle(
                        color: const Color(0xFF6B7280).withOpacity(0.6),
                        fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: const Color(0xFF6B7280).withOpacity(0.7),
                        size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded,
                                color: const Color(0xFF6B7280)
                                    .withOpacity(0.7),
                                size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ),
          ],
          Expanded(
            child: _searchQuery.isEmpty
                ? ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    children: _buildAllMenuItems(),
                  )
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAllMenuItems() {
    final lockContractVendorQuotes = _isBasicPlanLocked('Contracting');
    final lockSecurity = _isBasicPlanLocked('Security');
    final lockAllowance = _isBasicPlanLocked('Allowance');
    final lockWorkBreakdown = _isBasicPlanLocked('Work Breakdown Structure');
    final lockChangeManagement = _isBasicPlanLocked('Change Management');
    final lockInterfaceManagement = _isBasicPlanLocked('Interface Management');
    final lockProjectBaseline = _isBasicPlanLocked('Project Baseline');
    final lockProjectPlanLevel1 =
        _isBasicPlanLocked('Level 1 - Project Schedule');
    final lockProjectPlanDetailed =
        _isBasicPlanLocked('Detailed Project Schedule');
    final lockProjectPlanCondensed =
        _isBasicPlanLocked('Condensed Project Summary');
    final lockTeamManagement = _isBasicPlanLocked('Team Management');
    final lockStaffTeam = _isBasicPlanLocked('Staff Team');
    final lockUpdateOps =
        _isBasicPlanLocked('Update Ops and Maintenance Plans');
    final lockGapAnalysis =
        _isBasicPlanLocked('Gap Analysis and Scope Reconciliation');
    final lockPunchlistActions = _isBasicPlanLocked('Punchlist Actions');
    final lockSalvageDisposal =
        _isBasicPlanLocked('Salvage and/or Disposal Plan');
    final lockEngineering = _isBasicPlanLocked('Engineering');
    final lockSpecializedDesign = _isBasicPlanLocked('Specialized Design');
    final lockTechnicalDevelopment =
        _isBasicPlanLocked('Technical Development');
    final lockProjectSummary =
        _isBasicPlanLocked('Project Performance Review');
    final lockWarrantiesSupport =
        _isBasicPlanLocked('Hypercare & Warranty Support');
    return [
      _buildMenuItem(
        Icons.home_outlined,
        'Home',
        onTap: () => HomeScreen.open(context),
        isActive: widget.activeItemLabel == 'Home',
      ),
      _buildExpandableHeader(
        Icons.flag_outlined,
        'Initiation Phase',
        expanded: _initiationExpanded,
        onTap: () => setState(() {
          _initiationExpanded = !_initiationExpanded;
          _sharedInitiationExpanded = _initiationExpanded;
        }),
        isActive: _activeIn(_initiationPhaseLabels),
      ),
      if (_initiationExpanded) ...[
        _buildSubExpandableHeader(
          'Business Case',
          expanded: _businessCaseExpanded,
          onTap: () => setState(() {
            _businessCaseExpanded = !_businessCaseExpanded;
            _sharedBusinessCaseExpanded = _businessCaseExpanded;
          }),
          isActive: _activeIn(_businessCaseLabels),
        ),
        if (_businessCaseExpanded) ...[
          _buildSubSubMenuItem('Scope Statement',
              onTap: _openBusinessCase,
              isActive: widget.activeItemLabel == 'Business Case Detail'),
          _buildSubSubMenuItem('Potential Solutions',
              onTap: _openPotentialSolutions,
              isActive: widget.activeItemLabel == 'Potential Solutions'),
          _buildSubSubMenuItem('Risk Identification',
              onTap: _openRiskIdentification,
              isActive: widget.activeItemLabel == 'Risk Identification'),
          _buildSubSubMenuItem('IT Considerations',
              onTap: _openITConsiderations,
              isActive: widget.activeItemLabel == 'IT Considerations'),
          _buildSubSubMenuItem('Infrastructure Considerations',
              onTap: _openInfrastructureConsiderations,
              isActive:
                  widget.activeItemLabel == 'Infrastructure Considerations'),
          _buildSubSubMenuItem('Core Stakeholders',
              onTap: _openCoreStakeholders,
              isActive: widget.activeItemLabel == 'Core Stakeholders'),
          _buildSubSubMenuItem('Initial Cost Estimate',
              onTap: _openCostAnalysis,
              isActive: widget.activeItemLabel ==
                  'Initial Cost Estimate'),
          _buildSubExpandableHeader(
            'Executive Summary',
            expanded: _executiveSummaryExpanded,
            onTap: () => setState(() {
              _executiveSummaryExpanded = !_executiveSummaryExpanded;
              _sharedExecutiveSummaryExpanded = _executiveSummaryExpanded;
            }),
            isActive: _activeIn(_executiveSummaryLabels),
          ),
          if (_executiveSummaryExpanded) ...[
            _buildSubSubMenuItem('Preferred Solution',
                onTap: _openPreferredSolutionsComparison,
                isActive: widget.activeItemLabel == 'Preferred Solution'),
            _buildSubSubMenuItem('Preferred Solution Analysis',
                onTap: _openPreferredSolutionAnalysis,
                isActive:
                    widget.activeItemLabel == 'Preferred Solution Analysis'),
          ],
        ],
        _buildSubExpandableHeader(
          'Front End Planning',
          expanded: _frontEndExpanded,
          onTap: () => setState(() {
            _frontEndExpanded = !_frontEndExpanded;
            _sharedFrontEndExpanded = _frontEndExpanded;
          }),
          isActive: _activeIn(_frontEndLabels),
        ),
        if (_frontEndExpanded) ...[
          _buildSubSubMenuItem('Details',
              onTap: _openSummary,
              isActive: widget.activeItemLabel == 'Details' ||
                  widget.activeItemLabel == 'Summary'),
          _buildSubSubMenuItem('Project Requirements',
              onTap: _openFrontEndRequirements,
              isActive: widget.activeItemLabel == 'Project Requirements'),
          _buildSubSubMenuItem('Project Risks',
              onTap: _openFrontEndRisks,
              isActive: widget.activeItemLabel == 'Project Risks'),
          _buildSubSubMenuItem('Project Opportunities',
              onTap: _openFrontEndOpportunities,
              isActive: widget.activeItemLabel == 'Project Opportunities'),
          _buildSubSubMenuItem(
            'Contracting',
            onTap: lockContractVendorQuotes ? null : _openContractVendorQuotes,
            isActive: widget.activeItemLabel == 'Contracting',
            isDisabled: lockContractVendorQuotes,
          ),
          _buildSubSubMenuItem('Procurement',
              onTap: _openProcurement,
              isActive: widget.activeItemLabel == 'FEP Procurement'),
          _buildSubSubMenuItem(
            'Security',
            onTap: lockSecurity ? null : _openSecurity,
            isActive: widget.activeItemLabel == 'Security',
            isDisabled: lockSecurity,
          ),
          _buildSubSubMenuItem(
            'Milestone',
            onTap: _openMilestone,
            isActive: widget.activeItemLabel == 'Milestone',
          ),
          _buildSubSubMenuItem(
            'Allowance',
            onTap: lockAllowance ? null : _openAllowance,
            isActive: widget.activeItemLabel == 'Allowance',
            isDisabled: lockAllowance,
          ),
          _buildSubSubMenuItem('Project Charter',
              onTap: _openProjectCharter,
              isActive: widget.activeItemLabel == 'Project Charter'),
        ],
      ],
      _buildExpandableHeader(
        Icons.lightbulb_outline,
        'Planning Phase',
        expanded: _planningPhaseExpanded,
        onTap: () => setState(() {
          _planningPhaseExpanded = !_planningPhaseExpanded;
          _sharedPlanningPhaseExpanded = _planningPhaseExpanded;
        }),
        isActive: _activeIn(_planningPhaseLabels),
      ),
      if (_planningPhaseExpanded) ...[
        _buildSubMenuItem('Project Details',
            onTap: _openProjectFramework,
            isActive: widget.activeItemLabel == 'Project Details'),
        _buildSubMenuItem(
          'Work Breakdown Structure',
          onTap: lockWorkBreakdown ? null : _openWorkBreakdownStructure,
          isActive: widget.activeItemLabel == 'Work Breakdown Structure',
          isDisabled: lockWorkBreakdown,
        ),
        _buildSubMenuItem('Project Goals & Milestones',
            onTap: _openProjectGoalsMilestones,
            isActive: widget.activeItemLabel == 'Project Goals & Milestones'),
        _buildSubMenuItem('Requirements',
            onTap: _openPlanningRequirements,
            isActive: widget.activeItemLabel == 'Requirements'),
        _buildSubExpandableHeader(
          'Organization Plan',
          expanded: _organizationPlanExpanded,
          onTap: () => setState(() {
            _organizationPlanExpanded = !_organizationPlanExpanded;
            _sharedOrganizationPlanExpanded = _organizationPlanExpanded;
          }),
          isActive: _activeIn(_organizationPlanLabels),
        ),
        if (_organizationPlanExpanded) ...[
          _buildSubSubMenuItem('Roles & Responsibilities',
              onTap: _openOrganizationRolesResponsibilities,
              isActive: widget.activeItemLabel ==
                  'Organization Plan - Roles & Responsibilities'),
          _buildSubSubMenuItem('Staffing Plan',
              onTap: _openOrganizationStaffingPlan,
              isActive: widget.activeItemLabel ==
                  'Organization Plan - Staffing Plan'),
          _buildSubSubMenuItem('Training & Team Building',
              onTap: _openTeamTraining,
              isActive:
                  widget.activeItemLabel == 'Team Training and Team Building'),
          _buildSubSubMenuItem('Stakeholder Management',
              onTap: _openStakeholderManagement,
              isActive: widget.activeItemLabel == 'Stakeholder Management'),
          _buildSubSubMenuItem('Team Management',
              onTap: lockTeamManagement ? null : _openTeamManagement,
              isActive: widget.activeItemLabel == 'Team Management',
              isDisabled: lockTeamManagement),
        ],
        _buildSubMenuItem('SSHER',
            onTap: _openSSHER, isActive: widget.activeItemLabel == 'SSHER'),
        _buildSubMenuItem('Quality Management',
            onTap: _openQualityManagement,
            isActive: widget.activeItemLabel == 'Quality Management'),
        _buildSubMenuItem('Design Planning',
            onTap: _openDesign,
            isActive: widget.activeItemLabel == 'Design Planning'),
        _buildSubExpandableHeader(
          'Technology Planning',
          expanded: _technologyPlanningExpanded,
          onTap: () => setState(() {
            _technologyPlanningExpanded = !_technologyPlanningExpanded;
            _sharedTechnologyPlanningExpanded = _technologyPlanningExpanded;
          }),
          isActive: _activeIn(_technologyPlanningLabels),
        ),
        if (_technologyPlanningExpanded) ...[
          _buildSubSubMenuItem(
            'Technology Planning Overview',
            onTap: _openTechnology,
            isActive: widget.activeItemLabel == 'Technology Planning',
          ),
        ],
        _buildSubMenuItem(
          'Interface Management',
          onTap: lockInterfaceManagement ? null : _openInterfaceManagement,
          isActive: widget.activeItemLabel == 'Interface Management',
          isDisabled: lockInterfaceManagement,
        ),
        _buildSubExpandableHeader(
          'Agile Delivery Model',
          expanded: _agileWireframeExpanded,
          onTap: () => setState(() {
            _agileWireframeExpanded = !_agileWireframeExpanded;
            _sharedAgileWireframeExpanded = _agileWireframeExpanded;
          }),
          isActive: _activeIn(_agileWireframeLabels),
        ),
        if (_agileWireframeExpanded) ...[
          _buildSubSubMenuItem('Agile Delivery Model',
              onTap: _openAgileDeliveryModel,
              isActive:
                  widget.activeItemLabel == 'Agile Delivery Model - Delivery Model'),
          _buildSubSubMenuItem('Backlog Governance',
              onTap: _openAgileBacklogGovernance,
              isActive: widget.activeItemLabel ==
                  'Agile Delivery Model - Backlog Governance'),
          _buildSubSubMenuItem('Agile Team Structure',
              onTap: _openAgileTeamStructure,
              isActive:
                  widget.activeItemLabel == 'Agile Delivery Model - Team Structure'),
          _buildSubSubMenuItem('Kanban Configuration',
              onTap: _openAgileKanbanConfig,
              isActive: widget.activeItemLabel ==
                  'Agile Delivery Model - Kanban Configuration'),
          _buildSubSubMenuItem('Epics & Features',
              onTap: _openAgileEpicsFeatures,
              isActive:
                  widget.activeItemLabel == 'Agile Delivery Model - Epics & Features'),
          _buildSubSubMenuItem('Acceptance Criteria Planning',
              onTap: _openAgileAcceptanceCriteria,
              isActive: widget.activeItemLabel ==
                  'Agile Delivery Model - Acceptance Criteria Planning'),
          _buildSubSubMenuItem('Sprint Cadence & Calendar',
              onTap: _openAgileSprintCalendar,
              isActive: widget.activeItemLabel ==
                  'Agile Delivery Model - Sprint Calendar'),
          _buildSubSubMenuItem('Agile Map Out',
              onTap: _openAgileMapOut,
              isActive:
                  widget.activeItemLabel == 'Agile Delivery Model - Agile Map Out'),
          _buildSubSubMenuItem('Release Plan',
              onTap: _openAgileReleasePlan,
              isActive:
                  widget.activeItemLabel == 'Agile Delivery Model - Release Plan'),
          _buildSubSubMenuItem('Agile Metrics Planning',
              onTap: _openAgileMetricsPlanning,
              isActive: widget.activeItemLabel ==
                  'Agile Delivery Model - Metrics Planning'),
        ],
        _buildSubExpandableHeader(
          'Execution Plan',
          expanded: _executionPlanExpanded,
          onTap: () => setState(() {
            _executionPlanExpanded = !_executionPlanExpanded;
            _sharedExecutionPlanExpanded = _executionPlanExpanded;
          }),
          isActive: _activeIn(_executionPlanLabels),
        ),
        if (_executionPlanExpanded) ...[
          _buildSubSubMenuItem(
            'Overview',
            onTap: _openExecutionPlan,
            isActive: widget.activeItemLabel == 'Execution Plan Overview',
          ),
          _buildSubSubMenuItem(
            'Execution Work Packages',
            onTap: _openExecutionWorkPackages,
            isActive:
                widget.activeItemLabel == 'Execution Work Packages',
          ),
          _buildSubSubMenuItem(
            'Executive Plan Strategy',
            onTap: _openExecutionPlanStrategy,
            isActive: widget.activeItemLabel == 'Executive Plan Strategy',
          ),
          _buildSubSubMenuItem(
            'Execution Plan Details',
            onTap: _openExecutionPlanDetails,
            isActive: widget.activeItemLabel == 'Execution Plan Details',
          ),
          _buildSubSubMenuItem(
            'Execution Early Works',
            onTap: _openExecutionEarlyWorks,
            isActive: widget.activeItemLabel == 'Execution Early Works',
          ),
          _buildSubSubMenuItem(
            'Execution Enabling Work Plan',
            onTap: _openExecutionEnablingWorkPlan,
            isActive: widget.activeItemLabel == 'Execution Enabling Work Plan',
          ),
          _buildSubSubMenuItem(
            'Execution Issue Management',
            onTap: _openExecutionIssueManagement,
            isActive: widget.activeItemLabel == 'Execution Issue Management',
          ),
          _buildSubSubMenuItem(
            'Execution Stakeholder Identification',
            onTap: _openExecutionPlanStakeholderIdentification,
            isActive:
                widget.activeItemLabel == 'Execution Stakeholder Identification',
          ),
          _buildSubSubMenuItem('Construction Plan',
              onTap: _openExecutionPlanConstructionPlan,
              isActive: widget.activeItemLabel ==
                  'Execution Plan - Construction Plan'),
          _buildSubSubMenuItem('Infrastructure Plan',
              onTap: _openExecutionPlanInfrastructurePlan,
              isActive: widget.activeItemLabel ==
                  'Execution Plan - Infrastructure Plan'),
          _buildSubSubMenuItem(
            'Execution Lessons Learned',
            onTap: _openExecutionPlanLessonsLearned,
            isActive:
                widget.activeItemLabel == 'Execution Lessons Learned',
          ),
          _buildSubSubMenuItem(
            'Best Practices',
            onTap: _openExecutionPlanBestPractices,
            isActive:
                widget.activeItemLabel == 'Execution Plan - Best Practices',
          ),
          _buildSubSubMenuItem(
            'Execution Interface Management',
            onTap: _openExecutionPlanInterfaceManagement,
            isActive: widget.activeItemLabel ==
                'Execution Interface Management',
          ),
          _buildSubSubMenuItem(
            'Communication Plan',
            onTap: _openExecutionPlanCommunicationPlan,
            isActive:
                widget.activeItemLabel == 'Execution Plan - Communication Plan',
          ),
          _buildSubSubMenuItem(
            'Execution Interface Management Plan',
            onTap: _openExecutionPlanInterfaceManagementPlan,
            isActive: widget.activeItemLabel ==
                'Execution Interface Management Plan',
          ),
          _buildSubSubMenuItem(
            'Execution Interface Management Overview',
            onTap: _openExecutionPlanInterfaceManagementOverview,
            isActive: widget.activeItemLabel ==
                'Execution Interface Management Overview',
          ),
        ],
        _buildSubMenuItem('Risk Assessment',
            onTap: _openRiskAssessment,
            isActive: widget.activeItemLabel == 'Risk Assessment'),
        _buildSubMenuItem('Contract Planning',
            onTap: _openContract,
            isActive: widget.activeItemLabel == 'Contract Planning' ||
                widget.activeItemLabel == 'Contract'),
        _buildSubMenuItem('Procurement',
            onTap: _openPlanningProcurement,
            isActive: widget.activeItemLabel == 'Planning Procurement'),
        _buildSubMenuItem('Schedule',
            onTap: _openSchedule,
            isActive: widget.activeItemLabel == 'Schedule'),
        _buildSubExpandableHeader(
          'Cost Estimate',
          expanded: _costEstimateExpanded,
          onTap: () => setState(() {
            _costEstimateExpanded = !_costEstimateExpanded;
            _sharedCostEstimateExpanded = _costEstimateExpanded;
          }),
          isActive: _activeIn(_costEstimateLabels),
        ),
        if (_costEstimateExpanded) ...[
          _buildSubSubMenuItem('Cost Estimate Overview',
              onTap: _openCostEstimate,
              isActive: widget.activeItemLabel == 'Cost Estimate'),
        ],
        _buildSubExpandableHeader(
          'Project Services',
          expanded: _projectServicesExpanded,
          onTap: () => setState(() {
            _projectServicesExpanded = !_projectServicesExpanded;
            _sharedProjectServicesExpanded = _projectServicesExpanded;
          }),
          isActive: _activeIn(_projectServicesLabels),
        ),
        if (_projectServicesExpanded) ...[
          _buildSubSubMenuItem('Scope Tracking Plan',
              onTap: _openScopeTrackingPlan,
              isActive: widget.activeItemLabel == 'Scope Tracking Plan'),
        ],
        _buildSubMenuItem(
          'Change Management',
          onTap: lockChangeManagement ? null : _openChangeManagement,
          isActive: widget.activeItemLabel == 'Change Management',
          isDisabled: lockChangeManagement,
        ),
        _buildSubMenuItem('Issue Management',
            onTap: _openIssueManagement,
            isActive: widget.activeItemLabel == 'Issue Management'),
        _buildSubMenuItem('Lessons Learned',
            onTap: _openLessonsLearned,
            isActive: widget.activeItemLabel == 'Lessons Learned'),
        _buildSubMenuItem('Security Management',
            onTap: _openSecurityManagement,
            isActive: widget.activeItemLabel == 'Security Management'),
        _buildSubExpandableHeader(
          'Start-Up Planning',
          expanded: _startUpPlanningExpanded,
          onTap: () => setState(() {
            _startUpPlanningExpanded = !_startUpPlanningExpanded;
            _sharedStartUpPlanningExpanded = _startUpPlanningExpanded;
          }),
          isActive: _activeIn(_startUpPlanningLabels),
        ),
        if (_startUpPlanningExpanded) ...[
          _buildSubSubMenuItem(
            'Operations Plan and Manual',
            onTap: _openStartUpPlanningOperations,
            isActive: widget.activeItemLabel ==
                'Start-Up Planning - Operations Plan and Manual',
          ),
          _buildSubSubMenuItem(
            'Hypercare Plan',
            onTap: _openStartUpPlanningHypercare,
            isActive:
                widget.activeItemLabel == 'Start-Up Planning - Hypercare Plan',
          ),
          _buildSubSubMenuItem(
            'DevOps',
            onTap: _openStartUpPlanningDevOps,
            isActive: widget.activeItemLabel == 'Start-Up Planning - DevOps',
          ),
          _buildSubSubMenuItem(
            'Close Out Plan',
            onTap: _openStartUpPlanningCloseOut,
            isActive:
                widget.activeItemLabel == 'Start-Up Planning - Close Out Plan',
          ),
        ],
        _buildSubExpandableHeader(
          'Deliverable Roadmap',
          expanded: _deliverableRoadmapExpanded,
          onTap: () => setState(() {
            _deliverableRoadmapExpanded = !_deliverableRoadmapExpanded;
            _sharedDeliverableRoadmapExpanded = _deliverableRoadmapExpanded;
          }),
          isActive: _activeIn(_deliverableRoadmapLabels),
        ),
        if (_deliverableRoadmapExpanded) ...[
          _buildSubSubMenuItem('Roadmap Overview',
              onTap: _openDeliverableRoadmap,
              isActive: widget.activeItemLabel == 'Deliverable Roadmap' ||
                  widget.activeItemLabel == 'Roadmap Overview'),
        ],
        _buildSubExpandableHeader(
          'Project Plan',
          expanded: _projectPlanExpanded,
          onTap: () => setState(() {
            _projectPlanExpanded = !_projectPlanExpanded;
            _sharedProjectPlanExpanded = _projectPlanExpanded;
          }),
          isActive: _activeIn(_projectPlanLabels),
        ),
        if (_projectPlanExpanded) ...[
          _buildSubSubMenuItem('Project Plan Overview',
              onTap: _openProjectPlan,
              isActive: widget.activeItemLabel == 'Project Plan'),
          _buildSubSubMenuItem(
            'Level 1 - Project Schedule',
            onTap:
                lockProjectPlanLevel1 ? null : _openProjectPlanLevel1Schedule,
            isActive: widget.activeItemLabel ==
                'Project Plan - Level 1 - Project Schedule',
            isDisabled: lockProjectPlanLevel1,
          ),
          _buildSubSubMenuItem(
            'Detailed Project Schedule',
            onTap: lockProjectPlanDetailed
                ? null
                : _openProjectPlanDetailedSchedule,
            isActive: widget.activeItemLabel ==
                'Project Plan - Detailed Project Schedule',
            isDisabled: lockProjectPlanDetailed,
          ),
          _buildSubSubMenuItem(
            'Condensed Project Summary',
            onTap: lockProjectPlanCondensed
                ? null
                : _openProjectPlanCondensedSummary,
            isActive: widget.activeItemLabel ==
                'Project Plan - Condensed Project Summary',
            isDisabled: lockProjectPlanCondensed,
          ),
        ],
        _buildSubMenuItem(
          'Project Baseline',
          onTap: lockProjectBaseline ? null : _openProjectBaseline,
          isActive: widget.activeItemLabel == 'Project Baseline',
          isDisabled: lockProjectBaseline,
        ),
      ],
      _buildExpandableHeader(
        Icons.design_services_outlined,
        'Design Phase',
        expanded: _designPhaseExpanded,
        onTap: () => setState(() {
          _designPhaseExpanded = !_designPhaseExpanded;
          _sharedDesignPhaseExpanded = _designPhaseExpanded;
        }),
        isActive: _activeIn(_designPhaseLabels),
      ),
      if (_designPhaseExpanded) ...[
        _buildSubMenuItem('Design Management',
            onTap: _openDesignManagement,
            isActive: widget.activeItemLabel == 'Design Management'),
        _buildSubMenuItem('Design Specifications',
            onTap: _openRequirementsImplementation,
            isActive: widget.activeItemLabel == 'Design Specifications'),
        _buildSubMenuItem('Technical Alignment',
            onTap: _openTechnicalAlignment,
            isActive: widget.activeItemLabel == 'Technical Alignment'),
        _buildSubMenuItem('Development Set Up',
            onTap: _openDevelopmentSetUp,
            isActive: widget.activeItemLabel == 'Development Set Up'),
        _buildSubMenuItem('UI/UX Design',
            onTap: _openUiUxDesign,
            isActive: widget.activeItemLabel == 'UI/UX Design'),
        _buildSubMenuItem('Backend Design',
            onTap: _openBackendDesign,
            isActive: widget.activeItemLabel == 'Backend Design'),
        _buildSubMenuItem(
          'Engineering',
          onTap: lockEngineering ? null : _openEngineeringDesign,
          isActive: widget.activeItemLabel == 'Engineering',
          isDisabled: lockEngineering,
        ),
        _buildSubMenuItem(
          'Technical Development',
          onTap: lockTechnicalDevelopment ? null : _openTechnicalDevelopment,
          isActive: widget.activeItemLabel == 'Technical Development',
          isDisabled: lockTechnicalDevelopment,
        ),
        _buildSubMenuItem('Tools Integration',
            onTap: _openToolsIntegration,
            isActive: widget.activeItemLabel == 'Tools Integration'),
        _buildSubMenuItem('Long Lead Equipment Ordering',
            onTap: _openLongLeadEquipmentOrdering,
            isActive: widget.activeItemLabel == 'Long Lead Equipment Ordering'),
        _buildSubMenuItem(
          'Specialized Design',
          onTap: lockSpecializedDesign ? null : _openSpecializedDesign,
          isActive: widget.activeItemLabel == 'Specialized Design',
          isDisabled: lockSpecializedDesign,
        ),
        _buildSubMenuItem('Design Deliverables',
            onTap: _openDesignDeliverables,
            isActive: widget.activeItemLabel == 'Design Deliverables'),
      ],
      _buildExpandableHeader(
        Icons.play_circle_outline,
        'Execution Phase',
        expanded: _executionPhaseExpanded,
        onTap: () => setState(() {
          _executionPhaseExpanded = !_executionPhaseExpanded;
          _sharedExecutionPhaseExpanded = _executionPhaseExpanded;
        }),
        isActive: _activeIn(_executionPhaseLabels),
      ),
      if (_executionPhaseExpanded) ...[
        _buildSubExpandableHeader(
          'Project Team Activities',
          expanded: _projectTeamExpanded,
          onTap: () => setState(() {
            _projectTeamExpanded = !_projectTeamExpanded;
            _sharedProjectTeamExpanded = _projectTeamExpanded;
          }),
          isActive: _activeIn(_projectTeamLabels),
          isDisabled: lockStaffTeam,
        ),
        if (_projectTeamExpanded) ...[
          _buildSubSubMenuItem(
            'Mobilize Team',
            onTap: lockStaffTeam ? null : _openStaffTeam,
            isActive: widget.activeItemLabel == 'Staff Team' ||
                widget.activeItemLabel ==
                    'Project Team Activities - Mobilize Team',
          ),
          _buildSubSubMenuItem(
            'Team Meetings',
            onTap: _openTeamMeetings,
            isActive: widget.activeItemLabel == 'Team Meetings' ||
                widget.activeItemLabel ==
                    'Project Team Activities - Team Meetings',
          ),
          _buildSubSubMenuItem(
            'Training & Team Building',
            onTap: () {
              _navigateWithCheckpoint(
                  'team_training', const TeamTrainingAndBuildingScreen());
            },
            isActive: widget.activeItemLabel ==
                'Team Training and Team Building',
          ),
          _buildSubSubMenuItem(
            'Recognition & Awards',
            onTap: _openRecognitionAwards,
            isActive: widget.activeItemLabel ==
                'Project Team Activities - Recognition & Awards',
          ),
          _buildSubSubMenuItem(
            'Team Status Check',
            onTap: _openTeamStatusCheck,
            isActive: widget.activeItemLabel ==
                'Project Team Activities - Team Status Check',
          ),
          _buildSubSubMenuItem(
            'Team Handover',
            onTap: _openTeamHandover,
            isActive: widget.activeItemLabel ==
                'Project Team Activities - Team Handover',
          ),
          _buildSubSubMenuItem(
            'Lessons Learned',
            onTap: _openLessonsLearned,
            isActive: widget.activeItemLabel == 'Lessons Learned' ||
                widget.activeItemLabel ==
                    'Project Team Activities - Lessons Learned',
          ),
        ],
        _buildSubExpandableHeader(
          'Progress Tracking',
          expanded: _progressTrackingExpanded,
          onTap: () => setState(() {
            _progressTrackingExpanded = !_progressTrackingExpanded;
            _sharedProgressTrackingExpanded = _progressTrackingExpanded;
          }),
          isActive: _activeIn(_progressTrackingLabels),
        ),
        if (_progressTrackingExpanded) ...[
          _buildSubSubMenuItem('Deliverable Status Updates',
              onTap: _openDeliverableStatusUpdates,
              isActive: widget.activeItemLabel == 'Deliverable Status Updates'),
          _buildSubSubMenuItem('Recurring Deliverables',
              onTap: _openRecurringDeliverables,
              isActive: widget.activeItemLabel == 'Recurring Deliverables'),
          _buildSubSubMenuItem('Status Reports',
              onTap: _openStatusReports,
              isActive: widget.activeItemLabel == 'Status Reports'),
        ],
        _buildSubMenuItem('Contracts Tracking',
            onTap: _openContractsTracking,
            isActive: widget.activeItemLabel == 'Contracts Tracking'),
        _buildSubMenuItem('Vendor Tracking',
            onTap: _openVendorTracking,
            isActive: widget.activeItemLabel == 'Vendor Tracking'),
        _buildSubMenuItem('Detailed Design',
            onTap: _openDetailedDesign,
            isActive: widget.activeItemLabel == 'Detailed Design'),
        _buildSubExpandableHeader(
          'Agile Project Hub',
          expanded: _agileHubExpanded,
          onTap: () => setState(() {
            _agileHubExpanded = !_agileHubExpanded;
            _sharedAgileHubExpanded = _agileHubExpanded;
          }),
          isActive: _activeIn(_agileHubLabels),
        ),
        if (_agileHubExpanded) ...[
          _buildSubSubMenuItem(
            'Agile Dashboard',
            onTap: () => AgileDashboardScreen.open(context),
            isActive: widget.activeItemLabel == 'Agile Project Hub - Agile Dashboard',
          ),
          _buildSubSubMenuItem(
            'Product Backlog',
            onTap: _openAgileBacklogGovernance,
            isActive: widget.activeItemLabel == 'Agile Project Hub - Product Backlog',
          ),
          _buildSubSubMenuItem(
            'Sprint / Iteration Planning',
            onTap: _openAgileSprintCalendar,
            isActive: widget.activeItemLabel == 'Agile Project Hub - Sprint Planning',
          ),
          _buildSubSubMenuItem(
            'Iteration Management',
            onTap: () => AgileIterationManagementScreen.open(context),
            isActive: widget.activeItemLabel == 'Agile Project Hub - Iteration Management',
          ),
          _buildSubSubMenuItem(
            'Kanban Board',
            onTap: () => AgileKanbanBoardScreen.open(context),
            isActive: widget.activeItemLabel == 'Agile Project Hub - Kanban Board',
          ),
          _buildSubSubMenuItem(
            'Daily Standups',
            onTap: () => AgileDailyStandupsScreen.open(context),
            isActive: widget.activeItemLabel == 'Agile Project Hub - Daily Standups',
          ),
          _buildSubSubMenuItem(
            'Sprint Reviews',
            onTap: () => AgileSprintReviewsScreen.open(context),
            isActive: widget.activeItemLabel == 'Agile Project Hub - Sprint Reviews',
          ),
          _buildSubSubMenuItem(
            'Sprint Retrospectives',
            onTap: () => AgileRetrospectivesScreen.open(context),
            isActive: widget.activeItemLabel == 'Agile Project Hub - Sprint Retrospectives',
          ),
          _buildSubSubMenuItem(
            'Backlog Grooming',
            onTap: _openAgileBacklogGovernance,
            isActive: widget.activeItemLabel == 'Agile Project Hub - Backlog Grooming',
          ),
          _buildSubSubMenuItem(
            'Agile Metrics & Reporting',
            onTap: () => AgileMetricsScreen.open(context),
            isActive: widget.activeItemLabel == 'Agile Project Hub - Agile Metrics',
          ),
          _buildSubSubMenuItem(
            'Release Planning',
            onTap: _openAgileReleasePlan,
            isActive: widget.activeItemLabel == 'Agile Project Hub - Release Planning',
          ),
          _buildSubSubMenuItem(
            'Agile Risks & Impediments',
            onTap: () => AgileRisksScreen.open(context),
            isActive: widget.activeItemLabel == 'Agile Project Hub - Agile Risks',
          ),
          _buildSubSubMenuItem(
            'Team Capacity & Workload',
            onTap: _openAgileTeamStructure,
            isActive: widget.activeItemLabel == 'Agile Project Hub - Team Capacity',
          ),
          _buildSubSubMenuItem(
            'AI Agile Coach',
            onTap: () => AgileAiCoachScreen.open(context),
            isActive: widget.activeItemLabel == 'Agile Project Hub - AI Agile Coach',
          ),
          _buildSubSubMenuItem(
            'Agile Roadmap',
            onTap: () => AgileRoadmapScreen.open(context),
            isActive: widget.activeItemLabel == 'Agile Project Hub - Agile Roadmap',
          ),
        ],
        _buildSubMenuItem('Scope Tracking Implementation',
            onTap: _openScopeTrackingImplementation,
            isActive:
                widget.activeItemLabel == 'Scope Tracking Implementation'),
        _buildSubMenuItem('Stakeholder Alignment',
            onTap: _openStakeholderAlignment,
            isActive: widget.activeItemLabel == 'Stakeholder Alignment'),
        _buildSubMenuItem(
          'Update Ops and Maintenance Plans',
          onTap: lockUpdateOps ? null : _openUpdateOpsMaintenancePlans,
          isActive:
              widget.activeItemLabel == 'Update Ops and Maintenance Plans',
          isDisabled: lockUpdateOps,
        ),
        _buildSubMenuItem('Launch Checklist',
            onTap: _openLaunchChecklist,
            isActive: widget.activeItemLabel == 'Launch Checklist'),
        _buildSubMenuItem('Risk Tracking',
            onTap: _openRiskTracking,
            isActive: widget.activeItemLabel == 'Risk Tracking'),
        _buildSubMenuItem('Scope Completion',
            onTap: _openScopeCompletion,
            isActive: widget.activeItemLabel == 'Scope Completion'),
        _buildSubMenuItem(
          'Gap Analysis and Scope Reconciliation',
          onTap:
              lockGapAnalysis ? null : _openGapAnalysisAndScopeReconcillation,
          isActive:
              widget.activeItemLabel == 'Gap Analysis and Scope Reconciliation',
          isDisabled: lockGapAnalysis,
        ),
        _buildSubExpandableHeader(
          'Punchlist Actions',
          expanded: _punchlistExpanded,
          onTap: () => setState(() {
            _punchlistExpanded = !_punchlistExpanded;
            _sharedPunchlistExpanded = _punchlistExpanded;
          }),
          isActive: _activeIn(_punchlistLabels),
          isDisabled: lockPunchlistActions,
        ),
        if (_punchlistExpanded) ...[
          _buildSubSubMenuItem(
            'Punchlist Overview',
            onTap: lockPunchlistActions ? null : _openPunchlistActions,
            isActive: widget.activeItemLabel == 'Punchlist Actions',
            isDisabled: lockPunchlistActions,
          ),
          _buildSubSubMenuItem(
            'Tech Debt Management',
            onTap: lockPunchlistActions ? null : _openTechnicalDebtManagement,
            isActive: widget.activeItemLabel == 'Technical Debt Management',
            isDisabled: lockPunchlistActions,
          ),
        ],
        _buildSubMenuItem('Identify and Staff Ops Team',
            onTap: _openIdentifyStaffOpsTeam,
            isActive: widget.activeItemLabel == 'Identify and Staff Ops Team'),
        _buildSubMenuItem(
          'Salvage and/or Disposal Plan',
          onTap: lockSalvageDisposal ? null : _openSalvageDisposalTeam,
          isActive: widget.activeItemLabel == 'Salvage and/or Disposal Plan',
          isDisabled: lockSalvageDisposal,
        ),
        _buildSubMenuItem('Finalize Project',
            onTap: _openFinalizeProject,
            isActive: widget.activeItemLabel == 'Finalize Project'),
      ],
      _buildExpandableHeader(
        Icons.rocket_launch_outlined,
        'Launch Phase',
        expanded: _launchPhaseExpanded,
        onTap: () => setState(() {
          _launchPhaseExpanded = !_launchPhaseExpanded;
          _sharedLaunchPhaseExpanded = _launchPhaseExpanded;
        }),
        isActive: _activeIn(_launchPhaseLabels),
      ),
      if (_launchPhaseExpanded) ...[
        _buildSubMenuItem('Launch Readiness Assessment',
            onTap: _openDeliverProjectClosure,
            isActive: widget.activeItemLabel ==
                'Launch Readiness Assessment'),
        _buildSubMenuItem('Deployment Transfer, Certification & Release',
            onTap: _openTransitionToProdTeam,
            isActive: widget.activeItemLabel ==
                'Deployment Transfer, Certification & Release'),
        _buildSubMenuItem('FAT, Mechanical Completion & Commission Solution',
            onTap: _openFatMechanicalCompletion,
            isActive: widget.activeItemLabel ==
                'FAT, Mechanical Completion & Commission Solution'),
        _buildSubMenuItem('Vendor & Contract Closeout',
            onTap: _openContractCloseOut,
            isActive:
                widget.activeItemLabel == 'Vendor & Contract Closeout'),
        _buildSubMenuItem('Scope & Deliverable Reconciliation',
            onTap: _openActualVsPlannedGapAnalysis,
            isActive: widget.activeItemLabel ==
                'Scope & Deliverable Reconciliation'),
        _buildSubMenuItem(
          'Hypercare & Warranty Support',
          onTap: lockWarrantiesSupport ? null : _openCommerceViability,
          isActive:
              widget.activeItemLabel == 'Hypercare & Warranty Support',
          isDisabled: lockWarrantiesSupport,
        ),
        _buildSubMenuItem('Financial Closeout',
            onTap: _openFinancialCloseout,
            isActive: widget.activeItemLabel == 'Financial Closeout'),
        _buildSubMenuItem('Project Performance Review',
            onTap: lockProjectSummary ? null : _openSummarizeAccountRisks,
            isActive:
                widget.activeItemLabel == 'Project Performance Review',
            isDisabled: lockProjectSummary,
        ),
        _buildSubMenuItem('Benefits Realization',
            onTap: _openBenefitsRealization,
            isActive: widget.activeItemLabel == 'Benefits Realization'),
        _buildSubMenuItem(
            'Team Demobilization & Operations/Production Transition',
            onTap: _openDemobilizeTeam,
            isActive: widget.activeItemLabel ==
                'Team Demobilization & Operations/Production Transition'),
        _buildSubMenuItem('Project Closeout',
            onTap: _openProjectCloseOutLongForm,
            isActive: widget.activeItemLabel == 'Project Closeout'),
      ],
      const SizedBox(height: 20),
      _buildMenuItem(Icons.settings_outlined, 'Settings',
          onTap: () => SettingsScreen.open(context),
          isActive: widget.activeItemLabel == 'Settings'),
      _buildMenuItem(Icons.logout_outlined, 'LogOut',
          onTap: () => AuthNav.signOutAndExit(context),
          isActive: widget.activeItemLabel == 'LogOut'),
    ];
  }

  Widget _buildSearchResults() {
    final query = _searchQuery.toLowerCase();
    final results = <Widget>[];
    final lockContractVendorQuotes = _isBasicPlanLocked('Contracting');
    final lockSecurity = _isBasicPlanLocked('Security');
    final lockAllowance = _isBasicPlanLocked('Allowance');
    final lockWorkBreakdown = _isBasicPlanLocked('Work Breakdown Structure');
    final lockChangeManagement = _isBasicPlanLocked('Change Management');
    final lockInterfaceManagement = _isBasicPlanLocked('Interface Management');
    final lockProjectBaseline = _isBasicPlanLocked('Project Baseline');
    final lockProjectPlanLevel1 =
        _isBasicPlanLocked('Level 1 - Project Schedule');
    final lockProjectPlanDetailed =
        _isBasicPlanLocked('Detailed Project Schedule');
    final lockProjectPlanCondensed =
        _isBasicPlanLocked('Condensed Project Summary');
    final lockTeamManagement = _isBasicPlanLocked('Team Management');
    final lockStaffTeam = _isBasicPlanLocked('Staff Team');
    final lockUpdateOps =
        _isBasicPlanLocked('Update Ops and Maintenance Plans');
    final lockGapAnalysis =
        _isBasicPlanLocked('Gap Analysis and Scope Reconciliation');
    final lockPunchlistActions = _isBasicPlanLocked('Punchlist Actions');
    final lockSalvageDisposal =
        _isBasicPlanLocked('Salvage and/or Disposal Plan');
    final lockEngineering = _isBasicPlanLocked('Engineering');
    final lockSpecializedDesign = _isBasicPlanLocked('Specialized Design');
    final lockTechnicalDevelopment =
        _isBasicPlanLocked('Technical Development');
    final lockProjectSummary =
        _isBasicPlanLocked('Project Performance Review');
    final lockWarrantiesSupport =
        _isBasicPlanLocked('Hypercare & Warranty Support');

    // Search through all menu items
    if ('home'.contains(query)) {
      results.add(_buildMenuItem(Icons.home_outlined, 'Home',
          onTap: () => HomeScreen.open(context),
          isActive: widget.activeItemLabel == 'Home'));
    }
    if ('business case'.contains(query)) {
      results.add(_buildMenuItem(Icons.description_outlined, 'Business Case',
          onTap: _openBusinessCase,
          isActive: widget.activeItemLabel == 'Business Case'));
    }
    if ('potential solutions'.contains(query)) {
      results.add(_buildMenuItem(Icons.lightbulb_outline, 'Potential Solutions',
          onTap: _openPotentialSolutions,
          isActive: widget.activeItemLabel == 'Potential Solutions'));
    }
    if ('risk identification'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.warning_amber_outlined, 'Risk Identification',
          onTap: _openRiskIdentification,
          isActive: widget.activeItemLabel == 'Risk Identification'));
    }
    if ('it considerations'.contains(query)) {
      results.add(_buildMenuItem(Icons.computer_outlined, 'IT Considerations',
          onTap: _openITConsiderations,
          isActive: widget.activeItemLabel == 'IT Considerations'));
    }
    if ('infrastructure considerations'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.foundation_outlined, 'Infrastructure Considerations',
          onTap: _openInfrastructureConsiderations,
          isActive: widget.activeItemLabel == 'Infrastructure Considerations'));
    }
    if ('core stakeholders'.contains(query)) {
      results.add(_buildMenuItem(Icons.groups_outlined, 'Core Stakeholders',
          onTap: _openCoreStakeholders,
          isActive: widget.activeItemLabel == 'Core Stakeholders'));
    }
    if ('cost benefit analysis'.contains(query) ||
        'financial metrics'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.analytics_outlined, 'Initial Cost Estimate',
          onTap: _openCostAnalysis,
          isActive: widget.activeItemLabel ==
              'Initial Cost Estimate'));
    }
    if ('executive summary'.contains(query)) {
      results.add(_buildMenuItem(Icons.summarize_outlined, 'Executive Summary',
          onTap: _openExecutiveSummary,
          isActive: widget.activeItemLabel == 'Executive Summary'));
    }
    if ('preferred solution'.contains(query) ||
        'preferred solutions'.contains(query) ||
        'preferred comparison'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.fact_check_outlined, 'Preferred Solution',
          onTap: _openPreferredSolutionsComparison,
          isActive: widget.activeItemLabel == 'Preferred Solution'));
    }
    if ('preferred solution analysis'.contains(query) ||
        'preferred'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.fact_check_outlined, 'Preferred Solution Analysis',
          onTap: _openPreferredSolutionAnalysis,
          isActive: widget.activeItemLabel == 'Preferred Solution Analysis'));
    }
    if ('work breakdown structure'.contains(query) ||
        'wbs'.contains(query) ||
        'breakdown'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.account_tree_outlined,
          'Work Breakdown Structure',
          onTap: lockWorkBreakdown ? null : _openWorkBreakdownStructure,
          isActive: widget.activeItemLabel == 'Work Breakdown Structure',
          isDisabled: lockWorkBreakdown,
        ),
      );
    }
    if ('project details'.contains(query) ||
        'project management framework'.contains(query) ||
        'framework'.contains(query) ||
        'details'.contains(query)) {
      results.add(_buildMenuItem(Icons.widgets_outlined, 'Project Details',
          onTap: _openProjectFramework,
          isActive: widget.activeItemLabel == 'Project Details'));
    }
    if ('summary'.contains(query) || 'front end'.contains(query)) {
      results.add(_buildMenuItem(Icons.summarize_outlined, 'Summary',
          onTap: _openSummary, isActive: widget.activeItemLabel == 'Summary'));
    }
    if ('project requirements'.contains(query) ||
        'requirements'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.checklist_outlined, 'Project Requirements',
          onTap: _openFrontEndRequirements,
          isActive: widget.activeItemLabel == 'Project Requirements'));
    }
    if ('project risks'.contains(query) || 'risks'.contains(query)) {
      results.add(_buildMenuItem(Icons.error_outline, 'Project Risks',
          onTap: _openFrontEndRisks,
          isActive: widget.activeItemLabel == 'Project Risks'));
    }
    if ('project opportunities'.contains(query) ||
        'opportunities'.contains(query)) {
      results.add(_buildMenuItem(Icons.stars_outlined, 'Project Opportunities',
          onTap: _openFrontEndOpportunities,
          isActive: widget.activeItemLabel == 'Project Opportunities'));
    }
    if ('contract'.contains(query) || 'vendor quotes'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.description_outlined,
          'Contracting',
          onTap: lockContractVendorQuotes ? null : _openContractVendorQuotes,
          isActive: widget.activeItemLabel == 'Contracting',
          isDisabled: lockContractVendorQuotes,
        ),
      );
    }
    if ('procurement'.contains(query)) {
      results.add(_buildMenuItem(Icons.shopping_cart_outlined, 'Procurement',
          onTap: _openProcurement,
          isActive: widget.activeItemLabel == 'Procurement'));
    }
    if ('security'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.security_outlined,
          'Security',
          onTap: lockSecurity ? null : _openSecurity,
          isActive: widget.activeItemLabel == 'Security',
          isDisabled: lockSecurity,
        ),
      );
    }
    if ('allowance'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.account_balance_wallet_outlined,
          'Allowance',
          onTap: lockAllowance ? null : _openAllowance,
          isActive: widget.activeItemLabel == 'Allowance',
          isDisabled: lockAllowance,
        ),
      );
    }
    if ('project charter'.contains(query) || 'charter'.contains(query)) {
      results.add(_buildMenuItem(Icons.description_outlined, 'Project Charter',
          onTap: _openProjectCharter,
          isActive: widget.activeItemLabel == 'Project Charter'));
    }
    if ('ssher'.contains(query)) {
      results.add(_buildMenuItem(Icons.shield_outlined, 'SSHER',
          onTap: _openSSHER, isActive: widget.activeItemLabel == 'SSHER'));
    }
    if ('change management'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.change_circle_outlined,
          'Change Management',
          onTap: lockChangeManagement ? null : _openChangeManagement,
          isActive: widget.activeItemLabel == 'Change Management',
          isDisabled: lockChangeManagement,
        ),
      );
    }
    if ('issue management'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.report_problem_outlined, 'Issue Management',
          onTap: _openIssueManagement,
          isActive: widget.activeItemLabel == 'Issue Management'));
    }
    if ('cost estimate'.contains(query)) {
      results.add(_buildMenuItem(Icons.attach_money_outlined, 'Cost Estimate',
          onTap: _openCostEstimate,
          isActive: widget.activeItemLabel == 'Cost Estimate'));
    }
    if ('project services'.contains(query) ||
        'scope tracking plan'.contains(query) ||
        'scope tracking'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.track_changes_outlined, 'Scope Tracking Plan',
          onTap: _openScopeTrackingPlan,
          isActive: widget.activeItemLabel == 'Scope Tracking Plan'));
    }
    if ('project plan'.contains(query)) {
      results.add(_buildMenuItem(Icons.assignment_outlined, 'Project Plan',
          onTap: _openProjectPlan,
          isActive: widget.activeItemLabel == 'Project Plan'));
    }
    if ('level 1 project schedule'.contains(query) ||
        'level 1 - project schedule'.contains(query) ||
        'level 1 schedule'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.timeline_outlined,
          'Level 1 - Project Schedule',
          onTap: lockProjectPlanLevel1 ? null : _openProjectPlanLevel1Schedule,
          isActive: widget.activeItemLabel ==
              'Project Plan - Level 1 - Project Schedule',
          isDisabled: lockProjectPlanLevel1,
        ),
      );
    }
    if ('detailed project schedule'.contains(query) ||
        'detailed schedule'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.event_note_outlined,
          'Detailed Project Schedule',
          onTap:
              lockProjectPlanDetailed ? null : _openProjectPlanDetailedSchedule,
          isActive: widget.activeItemLabel ==
              'Project Plan - Detailed Project Schedule',
          isDisabled: lockProjectPlanDetailed,
        ),
      );
    }
    if ('condensed project summary'.contains(query) ||
        'condensed summary'.contains(query) ||
        'project summary'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.summarize_outlined,
          'Condensed Project Summary',
          onTap: lockProjectPlanCondensed
              ? null
              : _openProjectPlanCondensedSummary,
          isActive: widget.activeItemLabel ==
              'Project Plan - Condensed Project Summary',
          isDisabled: lockProjectPlanCondensed,
        ),
      );
    }
    // ── Agile Project Hub ──
    // Broad search entry so the hub is discoverable when users search for
    // any agile-related term (agile, hub, sprint, kanban, scrum, backlog,
    // retrospective, standup, roadmap, etc.)
    if ('agile project hub'.contains(query) ||
        'agile hub'.contains(query) ||
        'agile'.contains(query) ||
        'hub'.contains(query) ||
        'scrum'.contains(query) ||
        'kanban'.contains(query) ||
        'sprint planning'.contains(query) ||
        'daily standup'.contains(query) ||
        'standup'.contains(query) ||
        'retrospective'.contains(query) ||
        'sprint review'.contains(query) ||
        'agile coach'.contains(query) ||
        'agile roadmap'.contains(query) ||
        'iteration management'.contains(query) ||
        'team capacity'.contains(query) ||
        'agile metrics'.contains(query) ||
        'agile risks'.contains(query) ||
        'impediments'.contains(query) ||
        'backlog grooming'.contains(query) ||
        'release planning'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.dashboard_outlined, 'Agile Project Hub',
          onTap: _openAgileProjectHub,
          isActive: widget.activeItemLabel == 'Agile Project Hub'));
    }
    if ('agile roadmap'.contains(query) ||
        'roadmap'.contains(query) ||
        'delivery roadmap'.contains(query) ||
        'strategic roadmap'.contains(query) ||
        'release roadmap'.contains(query) ||
        'milestone roadmap'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.map_outlined, 'Agile Project Hub - Agile Roadmap',
          onTap: () => AgileRoadmapScreen.open(context),
          isActive:
              widget.activeItemLabel == 'Agile Project Hub - Agile Roadmap'));
    }
    if ('agile project baseline'.contains(query) ||
        'agile baseline'.contains(query)) {
      results.add(_buildMenuItem(Icons.grid_view_outlined,
          'Agile Project Baseline',
          onTap: _openAgileProjectBaseline,
          isActive: widget.activeItemLabel ==
              'Agile Delivery Model - Metrics Planning'));
    }
    if ('agile metrics'.contains(query) || 'metrics'.contains(query) ||
        'velocity'.contains(query) || 'throughput'.contains(query) ||
        'cycle time'.contains(query) || 'lead time'.contains(query) ||
        'burndown'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.analytics_outlined, 'Agile Metrics Planning',
          onTap: _openAgileMetricsPlanning,
          isActive: widget.activeItemLabel ==
              'Agile Delivery Model - Metrics Planning'));
    }
    if ('project baseline'.contains(query) || 'baseline'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.flag_circle_outlined,
          'Project Baseline',
          onTap: lockProjectBaseline ? null : _openProjectBaseline,
          isActive: widget.activeItemLabel == 'Project Baseline',
          isDisabled: lockProjectBaseline,
        ),
      );
    }
    if ('execution plan'.contains(query) ||
        'construction plan'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.home_repair_service_outlined, 'Construction Plan',
          onTap: _openExecutionPlanConstructionPlan,
          isActive:
              widget.activeItemLabel == 'Execution Plan - Construction Plan'));
    }
    if ('execution plan'.contains(query) ||
        'infrastructure plan'.contains(query)) {
      results.add(_buildMenuItem(Icons.domain_outlined, 'Infrastructure Plan',
          onTap: _openExecutionPlanInfrastructurePlan,
          isActive: widget.activeItemLabel ==
              'Execution Plan - Infrastructure Plan'));
    }
    if ('agile delivery model'.contains(query) ||
        'agile delivery plan'.contains(query) ||
        'agile delivery'.contains(query)) {
      results.add(_buildMenuItem(Icons.route_outlined, 'Agile Delivery Model',
          onTap: _openAgileDeliveryModel,
          isActive:
              widget.activeItemLabel == 'Agile Delivery Model - Delivery Model'));
    }
    if ('schedule'.contains(query)) {
      results.add(_buildMenuItem(Icons.calendar_today_outlined, 'Schedule',
          onTap: _openSchedule,
          isActive: widget.activeItemLabel == 'Schedule'));
    }
    if ('design planning'.contains(query) || 'design'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.design_services_outlined, 'Design Planning',
          onTap: _openDesign,
          isActive: widget.activeItemLabel == 'Design Planning'));
    }
    if ('technology'.contains(query)) {
      results.add(_buildMenuItem(Icons.computer_outlined, 'Technology Planning',
          onTap: _openTechnology,
          isActive: widget.activeItemLabel == 'Technology Planning'));
    }
    if ('interface management'.contains(query) ||
        'interfaces'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.device_hub_outlined,
          'Interface Management',
          onTap: lockInterfaceManagement ? null : _openInterfaceManagement,
          isActive: widget.activeItemLabel == 'Interface Management',
          isDisabled: lockInterfaceManagement,
        ),
      );
    }
    if ('agile team structure'.contains(query) || 'squad'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.groups_outlined, 'Agile Team Structure',
          onTap: _openAgileTeamStructure,
          isActive: widget.activeItemLabel == 'Agile Delivery Model - Team Structure'));
    }
    if ('kanban'.contains(query) || 'workflow'.contains(query) ||
        'wip'.contains(query) || 'column'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.dashboard_outlined, 'Kanban Configuration',
          onTap: _openAgileKanbanConfig,
          isActive: widget.activeItemLabel ==
              'Agile Delivery Model - Kanban Configuration'));
    }
    if ('epics'.contains(query) || 'features'.contains(query) ||
        'user story'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.account_tree_outlined, 'Epics & Features',
          onTap: _openAgileEpicsFeatures,
          isActive: widget.activeItemLabel ==
              'Agile Delivery Model - Epics & Features'));
    }
    if ('acceptance criteria'.contains(query) || 'ac'.contains(query) ||
        'criteria'.contains(query) || 'bdd'.contains(query) ||
        'definition of done'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.checklist_outlined, 'Acceptance Criteria Planning',
          onTap: _openAgileAcceptanceCriteria,
          isActive: widget.activeItemLabel ==
              'Agile Delivery Model - Acceptance Criteria Planning'));
    }
    if ('sprint calendar'.contains(query) || 'sprint cadence'.contains(query) ||
        'sprint'.contains(query) || 'iteration'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.calendar_month_outlined, 'Sprint Cadence & Calendar',
          onTap: _openAgileSprintCalendar,
          isActive: widget.activeItemLabel ==
              'Agile Delivery Model - Sprint Calendar'));
    }
    if ('release plan'.contains(query) || 'release'.contains(query) ||
        'pi planning'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.rocket_launch_outlined, 'Release Plan',
          onTap: _openAgileReleasePlan,
          isActive: widget.activeItemLabel == 'Agile Delivery Model - Release Plan'));
    }
    if ('backlog'.contains(query) || 'backlog governance'.contains(query) ||
        'grooming'.contains(query) || 'refinement'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.list_alt_outlined, 'Backlog Governance',
          onTap: _openAgileBacklogGovernance,
          isActive: widget.activeItemLabel ==
              'Agile Delivery Model - Backlog Governance'));
    }
    if ('start-up planning'.contains(query) ||
        'startup planning'.contains(query) ||
        'start up planning'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.rocket_launch_outlined, 'Start-Up Planning',
          onTap: _openStartUpPlanning,
          isActive: widget.activeItemLabel == 'Start-Up Planning'));
    }
    if ('operations plan'.contains(query) || 'manual'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.menu_book_outlined, 'Operations Plan and Manual',
          onTap: _openStartUpPlanningOperations,
          isActive: widget.activeItemLabel ==
              'Start-Up Planning - Operations Plan and Manual'));
    }
    if ('hypercare'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.health_and_safety_outlined, 'Hypercare Plan',
          onTap: _openStartUpPlanningHypercare,
          isActive:
              widget.activeItemLabel == 'Start-Up Planning - Hypercare Plan'));
    }
    if ('devops'.contains(query) ||
        'ci/cd'.contains(query) ||
        'pipeline'.contains(query)) {
      results.add(_buildMenuItem(Icons.settings_suggest_outlined, 'DevOps',
          onTap: _openStartUpPlanningDevOps,
          isActive: widget.activeItemLabel == 'Start-Up Planning - DevOps'));
    }
    if ('close out plan'.contains(query) || 'closeout plan'.contains(query)) {
      results.add(_buildMenuItem(Icons.fact_check_outlined, 'Close Out Plan',
          onTap: _openStartUpPlanningCloseOut,
          isActive:
              widget.activeItemLabel == 'Start-Up Planning - Close Out Plan'));
    }
    if ('team training'.contains(query) || 'team building'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.school_outlined, 'Team Training and Team Building',
          onTap: _openTeamTraining,
          isActive:
              widget.activeItemLabel == 'Team Training and Team Building'));
    }
    if ('roles and responsibilities'.contains(query) ||
        'roles & responsibilities'.contains(query) ||
        'roles responsibilities'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.assignment_ind_outlined, 'Roles & Responsibilities',
          onTap: _openOrganizationRolesResponsibilities,
          isActive: widget.activeItemLabel ==
              'Organization Plan - Roles & Responsibilities'));
    }
    if ('staffing plan'.contains(query) ||
        'staffing'.contains(query) ||
        'resource plan'.contains(query)) {
      results.add(_buildMenuItem(Icons.badge_outlined, 'Staffing Plan',
          onTap: _openOrganizationStaffingPlan,
          isActive:
              widget.activeItemLabel == 'Organization Plan - Staffing Plan'));
    }
    if ('lessons learned'.contains(query)) {
      results.add(_buildMenuItem(Icons.history_edu_outlined, 'Lessons Learned',
          onTap: _openLessonsLearned,
          isActive: widget.activeItemLabel == 'Lessons Learned'));
    }
    if ('team management'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.groups_outlined,
          'Team Management',
          onTap: lockTeamManagement ? null : _openTeamManagement,
          isActive: widget.activeItemLabel == 'Team Management',
          isDisabled: lockTeamManagement,
        ),
      );
    }
    if ('security management'.contains(query)) {
      results.add(_buildMenuItem(Icons.security_outlined, 'Security Management',
          onTap: _openSecurityManagement,
          isActive: widget.activeItemLabel == 'Security Management'));
    }
    if ('quality management'.contains(query) || 'quality'.contains(query)) {
      results.add(_buildMenuItem(Icons.verified_outlined, 'Quality Management',
          onTap: _openQualityManagement,
          isActive: widget.activeItemLabel == 'Quality Management'));
    }
    if ('stakeholder management'.contains(query) ||
        'stakeholder'.contains(query)) {
      results.add(_buildMenuItem(Icons.people_outline, 'Stakeholder Management',
          onTap: _openStakeholderManagement,
          isActive: widget.activeItemLabel == 'Stakeholder Management'));
    }
    if ('risk assessment'.contains(query)) {
      results.add(_buildMenuItem(Icons.assessment_outlined, 'Risk Assessment',
          onTap: _openRiskAssessment,
          isActive: widget.activeItemLabel == 'Risk Assessment'));
    }
    if ('design management'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.design_services_outlined, 'Design Management',
          onTap: _openDesignManagement,
          isActive: widget.activeItemLabel == 'Design Management'));
    }
    if ('design deliverables'.contains(query) ||
        'deliverables'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.inventory_2_outlined, 'Design Deliverables',
          onTap: _openDesignDeliverables,
          isActive: widget.activeItemLabel == 'Design Deliverables'));
    }
    if ('requirements implementation'.contains(query) ||
        'requirements'.contains(query) ||
        'implementation'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.checklist_rtl_outlined, 'Requirements Implementation',
          onTap: _openRequirementsImplementation,
          isActive: widget.activeItemLabel == 'Requirements Implementation'));
    }
    if ('development set up'.contains(query) ||
        'development setup'.contains(query) ||
        'setup'.contains(query)) {
      results.add(_buildMenuItem(Icons.build_outlined, 'Development Set Up',
          onTap: _openDevelopmentSetUp,
          isActive: widget.activeItemLabel == 'Development Set Up'));
    }
    if ('ui/ux design'.contains(query) ||
        'ui ux'.contains(query) ||
        'ux design'.contains(query) ||
        'user interface'.contains(query) ||
        'user experience'.contains(query)) {
      results.add(_buildMenuItem(Icons.palette_outlined, 'UI/UX Design',
          onTap: _openUiUxDesign,
          isActive: widget.activeItemLabel == 'UI/UX Design'));
    }
    if ('backend design'.contains(query) ||
        'backend'.contains(query) ||
        'database'.contains(query)) {
      results.add(_buildMenuItem(Icons.storage_outlined, 'Backend Design',
          onTap: _openBackendDesign,
          isActive: widget.activeItemLabel == 'Backend Design'));
    }
    // ── Project Team Activities hub ──
    if ('project team activities'.contains(query) ||
        'project team'.contains(query) ||
        'team activities'.contains(query) ||
        'mobilize team'.contains(query) ||
        'team hub'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.groups_outlined, 'Project Team Activities',
          onTap: _openProjectTeamActivities,
          isActive: widget.activeItemLabel == 'Project Team Activities'));
    }
    if ('staff team'.contains(query) || 'mobilize'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.badge_outlined,
          'Mobilize Team',
          onTap: lockStaffTeam ? null : _openStaffTeam,
          isActive: widget.activeItemLabel == 'Staff Team',
          isDisabled: lockStaffTeam,
        ),
      );
    }
    if ('recognition'.contains(query) ||
        'awards'.contains(query) ||
        'recognition awards'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.emoji_events_outlined, 'Recognition & Awards',
          onTap: _openRecognitionAwards,
          isActive: widget.activeItemLabel ==
              'Project Team Activities - Recognition & Awards'));
    }
    if ('team status'.contains(query) ||
        'status check'.contains(query) ||
        'team capacity'.contains(query) ||
        'team operations'.contains(query) ||
        'shift coverage'.contains(query) ||
        'capacity health'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.health_and_safety_outlined, 'Team Status Check',
          onTap: _openTeamStatusCheck,
          isActive: widget.activeItemLabel ==
              'Project Team Activities - Team Status Check'));
    }
    if ('team handover'.contains(query) ||
        'handover'.contains(query) ||
        'demobilize'.contains(query) ||
        'offboarding'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.swap_horiz_outlined, 'Team Handover',
          onTap: _openTeamHandover,
          isActive: widget.activeItemLabel ==
              'Project Team Activities - Team Handover'));
    }
    if ('engineering'.contains(query) ||
        'engineering design'.contains(query) ||
        'system architecture'.contains(query) ||
        'technical blueprint'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.architecture_outlined,
          'Engineering Design',
          onTap: lockEngineering ? null : _openEngineeringDesign,
          isActive: widget.activeItemLabel == 'Engineering',
          isDisabled: lockEngineering,
        ),
      );
    }
    if ('team meetings'.contains(query) || 'meetings'.contains(query)) {
      results.add(_buildMenuItem(Icons.meeting_room_outlined, 'Team Meetings',
          onTap: _openTeamMeetings,
          isActive: widget.activeItemLabel == 'Team Meetings'));
    }
    if ('progress tracking'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.track_changes_outlined, 'Progress Tracking',
          onTap: _openProgressTracking,
          isActive: widget.activeItemLabel == 'Progress Tracking'));
    }
    if ('deliverable status updates'.contains(query) ||
        'deliverable updates'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.inventory_2_outlined, 'Deliverable Status Updates',
          onTap: _openDeliverableStatusUpdates,
          isActive: widget.activeItemLabel == 'Deliverable Status Updates'));
    }
    if ('recurring deliverables'.contains(query) ||
        'recurring'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.repeat_outlined, 'Recurring Deliverables',
          onTap: _openRecurringDeliverables,
          isActive: widget.activeItemLabel == 'Recurring Deliverables'));
    }
    if ('status reports'.contains(query) || 'reports'.contains(query)) {
      results.add(_buildMenuItem(Icons.description_outlined, 'Status Reports',
          onTap: _openStatusReports,
          isActive: widget.activeItemLabel == 'Status Reports'));
    }
    if ('gap analysis'.contains(query) ||
        'scope reconciliation'.contains(query) ||
        'scope reconcillation'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.compare_arrows_outlined,
          'Gap Analysis And Scope Reconcillation',
          onTap:
              lockGapAnalysis ? null : _openGapAnalysisAndScopeReconcillation,
          isActive:
              widget.activeItemLabel == 'Gap Analysis And Scope Reconcillation',
          isDisabled: lockGapAnalysis,
        ),
      );
    }
    if ('punchlist actions'.contains(query) ||
        'punch list'.contains(query) ||
        'technical debt'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.fact_check_outlined,
          'Punchlist Actions',
          onTap: lockPunchlistActions ? null : _openPunchlistActions,
          isActive: widget.activeItemLabel == 'Punchlist Actions',
          isDisabled: lockPunchlistActions,
        ),
      );
    }
    if ('contracts tracking'.contains(query) ||
        'contracts tracking'.contains(query) ||
        'contracts'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.description_outlined, 'Contracts Tracking',
          onTap: _openContractsTracking,
          isActive: widget.activeItemLabel == 'Contracts Tracking'));
    }
    if ('vendor tracking'.contains(query) ||
        'vendors'.contains(query) ||
        'vendor'.contains(query)) {
      results.add(_buildMenuItem(Icons.storefront_outlined, 'Vendor Tracking',
          onTap: _openVendorTracking,
          isActive: widget.activeItemLabel == 'Vendor Tracking'));
    }
    if ('detailed design'.contains(query) || 'detail design'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.design_services_outlined, 'Detailed Design',
          onTap: _openDetailedDesign,
          isActive: widget.activeItemLabel == 'Detailed Design'));
    }
    if ('scope tracking implementation'.contains(query) ||
        'scope tracking'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.track_changes_outlined, 'Scope Tracking Implementation',
          onTap: _openScopeTrackingImplementation,
          isActive: widget.activeItemLabel == 'Scope Tracking Implementation'));
    }
    if ('stakeholder alignment'.contains(query) ||
        'alignment'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.group_work_outlined, 'Stakeholder Alignment',
          onTap: _openStakeholderAlignment,
          isActive: widget.activeItemLabel == 'Stakeholder Alignment'));
    }
    if ('update ops and maintenance plans'.contains(query) ||
        'ops maintenance'.contains(query) ||
        'maintenance plans'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.handyman_outlined,
          'Update Ops and Maintenance Plans',
          onTap: lockUpdateOps ? null : _openUpdateOpsMaintenancePlans,
          isActive:
              widget.activeItemLabel == 'Update Ops and Maintenance Plans',
          isDisabled: lockUpdateOps,
        ),
      );
    }
    if ('technical debt management'.contains(query) ||
        'tech debt'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.rule_folder_outlined, 'Technical Debt Management',
          onTap: _openTechnicalDebtManagement,
          isActive: widget.activeItemLabel == 'Technical Debt Management'));
    }
    if ('risk tracking'.contains(query) || 'risk'.contains(query)) {
      results.add(_buildMenuItem(Icons.assessment_outlined, 'Risk Tracking',
          onTap: _openRiskTracking,
          isActive: widget.activeItemLabel == 'Risk Tracking'));
    }
    if ('identify and staff ops team'.contains(query) ||
        'ops team'.contains(query) ||
        'staff ops'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.groups_outlined, 'Identify and Staff Ops Team',
          onTap: _openIdentifyStaffOpsTeam,
          isActive: widget.activeItemLabel == 'Identify and Staff Ops Team'));
    }
    if ('launch checklist'.contains(query) || 'launch'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.rocket_launch_outlined, 'Launch Checklist',
          onTap: _openLaunchChecklist,
          isActive: widget.activeItemLabel == 'Launch Checklist'));
    }
    if ('deliverable roadmap'.contains(query) ||
        'deliverables'.contains(query) ||
        'roadmap'.contains(query)) {
      results.add(_buildMenuItem(Icons.map_outlined, 'Deliverable Roadmap',
          onTap: _openDeliverableRoadmap,
          isActive: widget.activeItemLabel == 'Deliverable Roadmap'));
    }
    if ('agile map out'.contains(query) ||
        'agile map'.contains(query) ||
        'map out'.contains(query)) {
      results.add(_buildMenuItem(Icons.timeline_outlined, 'Agile Map Out',
          onTap: _openAgileMapOut,
          isActive:
              widget.activeItemLabel == 'Agile Delivery Model - Agile Map Out'));
    }
    if ('tools integration'.contains(query) ||
        'integration'.contains(query) ||
        'figma'.contains(query) ||
        'miro'.contains(query)) {
      results.add(_buildMenuItem(Icons.extension_outlined, 'Tools Integration',
          onTap: _openToolsIntegration,
          isActive: widget.activeItemLabel == 'Tools Integration'));
    }
    if ('technical development'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.build_outlined,
          'Technical Development',
          onTap: lockTechnicalDevelopment ? null : _openTechnicalDevelopment,
          isActive: widget.activeItemLabel == 'Technical Development',
          isDisabled: lockTechnicalDevelopment,
        ),
      );
    }
    if ('specialized design'.contains(query) ||
        'specialised design'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.design_services_outlined,
          'Specialized Design',
          onTap: lockSpecializedDesign ? null : _openSpecializedDesign,
          isActive: widget.activeItemLabel == 'Specialized Design',
          isDisabled: lockSpecializedDesign,
        ),
      );
    }
    if ('salvage disposal team'.contains(query) ||
        'salvage'.contains(query) ||
        'disposal'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.recycling_outlined,
          'Salvage Disposal Team',
          onTap: lockSalvageDisposal ? null : _openSalvageDisposalTeam,
          isActive: widget.activeItemLabel == 'Salvage Disposal Team',
          isDisabled: lockSalvageDisposal,
        ),
      );
    }
    if ('deliver project'.contains(query) ||
        'closure'.contains(query) ||
        'close out'.contains(query) ||
        'launch readiness'.contains(query) ||
        'readiness assessment'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.delivery_dining_outlined, 'Launch Readiness Assessment',
          onTap: _openDeliverProjectClosure,
          isActive: widget.activeItemLabel ==
              'Launch Readiness Assessment'));
    }
    if ('contract close out'.contains(query) ||
        'contract closure'.contains(query) ||
        'contracts'.contains(query) ||
        'vendor closeout'.contains(query) ||
        'vendor contract'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.description_outlined, 'Vendor & Contract Closeout',
          onTap: _openContractCloseOut,
          isActive: widget.activeItemLabel == 'Vendor & Contract Closeout'));
    }
    if ('vendor account close out'.contains(query) ||
        'vendor close'.contains(query) ||
        'vendor account'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.business_outlined, 'Vendor & Contract Closeout',
          onTap: _openContractCloseOut,
          isActive: widget.activeItemLabel == 'Vendor & Contract Closeout'));
    }
    if ('transition'.contains(query) ||
        'production team'.contains(query) ||
        'prod team'.contains(query) ||
        'handover'.contains(query) ||
        'deployment transfer'.contains(query) ||
        'certification'.contains(query) ||
        'release'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.swap_horiz_outlined,
          'Deployment Transfer, Certification & Release',
          onTap: _openTransitionToProdTeam,
          isActive: widget.activeItemLabel ==
              'Deployment Transfer, Certification & Release'));
    }
    if ('fat'.contains(query) ||
        'mechanical completion'.contains(query) ||
        'commissioning'.contains(query) ||
        'site acceptance'.contains(query) ||
        'turnover'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.engineering_outlined,
          'FAT, Mechanical Completion & Commission Solution',
          onTap: _openFatMechanicalCompletion,
          isActive: widget.activeItemLabel ==
              'FAT, Mechanical Completion & Commission Solution'));
    }
    if ('project close out'.contains(query) ||
        'project closure'.contains(query) ||
        'closeout'.contains(query) ||
        'project closeout'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.task_alt_outlined, 'Project Closeout',
          onTap: _openProjectCloseOutLongForm,
          isActive: widget.activeItemLabel == 'Project Closeout'));
    }
    if ('close out long form'.contains(query) || 'long form'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.task_alt_outlined, 'Project Closeout',
          onTap: _openProjectCloseOutLongForm,
          isActive: widget.activeItemLabel == 'Project Closeout'));
    }
    if ('close out summarized form'.contains(query) ||
        'summarized form'.contains(query) ||
        'summary form'.contains(query) ||
        'close out summary'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.task_alt_outlined, 'Project Closeout',
          onTap: _openProjectCloseOutLongForm,
          isActive: widget.activeItemLabel == 'Project Closeout'));
    }
    if ('demobilize team'.contains(query) ||
        'demobilize'.contains(query) ||
        'team ramp down'.contains(query) ||
        'wind down'.contains(query) ||
        'operations transition'.contains(query) ||
        'production transition'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.groups_outlined,
          'Team Demobilization & Operations/Production Transition',
          onTap: _openDemobilizeTeam,
          isActive: widget.activeItemLabel ==
              'Team Demobilization & Operations/Production Transition'));
    }
    if ('project financial review'.contains(query) ||
        'actual vs planned'.contains(query) ||
        'gap analysis'.contains(query) ||
        'financial review'.contains(query) ||
        'scope reconciliation'.contains(query) ||
        'deliverable reconciliation'.contains(query) ||
        'scope reconcile'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.compare_arrows_outlined,
          'Scope & Deliverable Reconciliation',
          onTap: _openActualVsPlannedGapAnalysis,
          isActive: widget.activeItemLabel ==
              'Scope & Deliverable Reconciliation',
        ),
      );
    }
    if ('scope reconcillation'.contains(query) ||
        'scope reconciliation'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.compare_arrows_outlined,
          'Scope & Deliverable Reconciliation',
          onTap: _openActualVsPlannedGapAnalysis,
          isActive: widget.activeItemLabel ==
              'Scope & Deliverable Reconciliation'));
    }
    if ('warranties'.contains(query) ||
        'warranty'.contains(query) ||
        'operations support'.contains(query) ||
        'commerce warranty'.contains(query) ||
        'commerce viability'.contains(query) ||
        'commercial'.contains(query) ||
        'viability'.contains(query) ||
        'hypercare'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.monetization_on_outlined,
          'Hypercare & Warranty Support',
          onTap: lockWarrantiesSupport ? null : _openCommerceViability,
          isActive:
              widget.activeItemLabel == 'Hypercare & Warranty Support',
          isDisabled: lockWarrantiesSupport,
        ),
      );
    }
    if ('project summary'.contains(query) ||
        'summary'.contains(query) ||
        'summarize account'.contains(query) ||
        'account risks'.contains(query) ||
        'summarize'.contains(query) ||
        'account summary'.contains(query) ||
        'performance review'.contains(query) ||
        'project performance'.contains(query)) {
      results.add(
        _buildMenuItem(
          Icons.summarize_outlined,
          'Project Performance Review',
          onTap: lockProjectSummary ? null : _openSummarizeAccountRisks,
          isActive: widget.activeItemLabel == 'Project Performance Review',
          isDisabled: lockProjectSummary,
        ),
      );
    }
    if ('financial closeout'.contains(query) ||
        'financial closure'.contains(query) ||
        'accounting reconciliation'.contains(query) ||
        'financial summary'.contains(query) ||
        'financial analysis'.contains(query) ||
        'cpi'.contains(query) ||
        'roi'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.account_balance_wallet_outlined, 'Financial Closeout',
          onTap: _openFinancialCloseout,
          isActive: widget.activeItemLabel == 'Financial Closeout'));
    }
    if ('benefits realization'.contains(query) ||
        'benefits'.contains(query) ||
        'benefit tracking'.contains(query) ||
        'benefit dashboard'.contains(query) ||
        'benefit quantification'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.insights_outlined, 'Benefits Realization',
          onTap: _openBenefitsRealization,
          isActive: widget.activeItemLabel == 'Benefits Realization'));
    }
    if ('project controls'.contains(query) ||
        'controls'.contains(query) ||
        'evm'.contains(query) ||
        'earned value'.contains(query) ||
        'scope tracking'.contains(query) ||
        'cost control'.contains(query) ||
        'forecasting'.contains(query)) {
      results.add(_buildMenuItem(
          Icons.shield_moon_outlined, 'Project Controls',
          onTap: () => context.push('/project-controls'),
          isActive: widget.activeItemLabel == 'Project Controls'));
    }
    // NOTE: 'Change Management' search entry removed from this block — it
    // was duplicating the Change Management entry in the Planning Phase
    // search block (line ~2987). The Planning Phase entry is the canonical
    // one; this second entry pointed to the Project Controls module route
    // which is a different screen, causing confusion with two identical
    // "Change Management" items in search results.
    if ('settings'.contains(query)) {
      results.add(_buildMenuItem(Icons.settings_outlined, 'Settings',
          onTap: () => SettingsScreen.open(context),
          isActive: widget.activeItemLabel == 'Settings'));
    }

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  color: const Color(0xFF6B7280).withOpacity(0.4),
                  size: 40),
              const SizedBox(height: 12),
              Text(
                'No results found',
                style: TextStyle(
                    color: const Color(0xFF6B7280).withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      children: results,
    );
  }
}
