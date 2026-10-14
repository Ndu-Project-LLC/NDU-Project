/// Screens that still overflow a phone viewport, worst site first.
///
/// This is a work list, not an allowance. `mobile_responsiveness_audit_test.dart`
/// fails for any screen that overflows without an entry here, and the teardown check
/// fails when an entry no longer overflows — so the map can only shrink, and a new
/// screen cannot quietly join it.
///
/// Keys are audited at 360x800 and 427x952. The value is where to start reading: the
/// site with the most overflow reports in that screen.
///
/// Generated from an audit run; regenerate the list as screens are fixed.
library;

const Map<String, String> knownPhoneOverflows = <String, String>{
  // 101 overflow(s) at phone width, worst site (16 reports):
  'LandingScreen': 'landing_screen.dart:2582',
  // 70 overflow(s) at phone width, worst site (60 reports):
  'FrontEndPlanningWorkspaceScreen':
      'front_end_planning_workspace_screen.dart:856',
  // 60 overflow(s) at phone width, worst site (55 reports):
  'ProjectTeamActivitiesScreen': 'project_team_activities_screen.dart:788',
  // 48 overflow(s) at phone width, worst site (28 reports):
  'TechnicalAlignmentScreen': 'technical_alignment_screen.dart:5607',
  // 32 overflow(s) at phone width, worst site (15 reports):
  'AgileAiCoachScreen': 'agile_ai_coach_screen.dart:909',
  // 27 overflow(s) at phone width, worst site (14 reports):
  'ChangeManagementModuleScreen': 'change_management_module_screen.dart:502',
  // 26 overflow(s) at phone width, worst site (12 reports):
  'PlanningProcurementV2Screen': 'planning_procurement_v2_screen.dart:2768',
  // 25 overflow(s) at phone width, worst site (12 reports):
  'AgileMetricsScreen': 'agile_metrics_screen.dart:773',
  // 23 overflow(s) at phone width, worst site (8 reports):
  'AgileDashboardScreen': 'agile_dashboard_screen.dart:850',
  // 23 overflow(s) at phone width, worst site (8 reports):
  'AgileRisksScreen': 'agile_risks_screen.dart:917',
  // 22 overflow(s) at phone width, worst site (14 reports):
  'CostEstimateScreen': 'cost_estimate_screen.dart:3535',
  // 20 overflow(s) at phone width, worst site (12 reports):
  'AgileDailyStandupsScreen': 'agile_daily_standups_screen.dart:579',
  // 19 overflow(s) at phone width, worst site (17 reports):
  'PartnerScreen': 'partner_screen.dart:175',
  // 18 overflow(s) at phone width, worst site (12 reports):
  'FrontEndPlanningContractVendorQuotesScreen':
      'front_end_planning_contract_vendor_quotes_screen.dart:891',
  // 18 overflow(s) at phone width, worst site (10 reports):
  'FrontEndPlanningMilestoneScreen': 'front_end_planning_milestone.dart:1951',
  // 18 overflow(s) at phone width, worst site (10 reports):
  'UseCasesScreen': 'use_cases_screen.dart:215',
  // 16 overflow(s) at phone width, worst site (6 reports):
  'AgileSprintReviewsScreen': 'agile_sprint_reviews_screen.dart:679',
  // 15 overflow(s) at phone width, worst site (8 reports):
  'FinalizeProjectScreen': 'finalize_project_screen.dart:420',
  // 14 overflow(s) at phone width, worst site (2 reports):
  'ProgramDashboardScreen': 'program_dashboard_screen.dart:577',
  // 14 overflow(s) at phone width, worst site (2 reports):
  'ProjectBaselineScreen': 'project_baseline_screen.dart:769',
  // 14 overflow(s) at phone width, worst site (2 reports):
  'StakeholderManagementScreen': 'stakeholder_management_screen.dart:1909',
  // 14 overflow(s) at phone width, worst site (12 reports):
  'StartUpPlanningCloseOutPlanScreen':
      'startup_planning_subsections_screen.dart:3325',
  // 14 overflow(s) at phone width, worst site (12 reports):
  'StartUpPlanningDevOpsScreen':
      'startup_planning_subsections_screen.dart:3325',
  // 14 overflow(s) at phone width, worst site (12 reports):
  'StartUpPlanningHypercareScreen':
      'startup_planning_subsections_screen.dart:3325',
  // 13 overflow(s) at phone width, worst site (13 reports):
  'ToolsIntegrationScreen': 'tools_integration_screen.dart:1026',
  // 12 overflow(s) at phone width, worst site (5 reports):
  'QualityManagementScreen': 'quality_management_screen.dart:2083',
  // 12 overflow(s) at phone width, worst site (10 reports):
  'RiskTrackingWorkspaceScreen': 'risk_tracking_workspace_screen.dart:718',
  // 11 overflow(s) at phone width, worst site (3 reports):
  'AgileIterationManagementScreen':
      'agile_iteration_management_screen.dart:474',
  // 11 overflow(s) at phone width, worst site (2 reports):
  'CostEstimateModuleScreen': 'cost_estimate_module_screen.dart:1004',
  // 10 overflow(s) at phone width, worst site (2 reports):
  'LandingPageScreen': 'landing_page_screen.dart:375',
  // 10 overflow(s) at phone width, worst site (8 reports):
  'TeamHandoverScreen': 'team_handover_screen.dart:418',
  // 10 overflow(s) at phone width, worst site (6 reports):
  'TeamTrainingAndBuildingScreen': 'team_training_building_screen.dart:415',
  // 9 overflow(s) at phone width, worst site (5 reports):
  'CareersPageScreen': 'careers_page_screen.dart:137',
  // 8 overflow(s) at phone width, worst site (6 reports):
  'AdminHintsScreen': 'admin_hints_screen.dart:1661',
  // 8 overflow(s) at phone width, worst site (6 reports):
  'DesignPhaseScreen': 'design_phase_screen.dart:708',
  // 8 overflow(s) at phone width, worst site (4 reports):
  'ProjectPlanLevel1ScheduleScreen':
      'project_plan_subsections_screen.dart:4992',
  // 8 overflow(s) at phone width, worst site (8 reports):
  'TechnicalDevelopmentScreen': 'technical_development_screen.dart:813',
  // 7 overflow(s) at phone width, worst site (4 reports):
  'AgileProjectHubScreen': 'agile_project_hub_screen.dart:270',
  // 7 overflow(s) at phone width, worst site (2 reports):
  'BasicPlanDashboardScreen': 'project_dashboard_mobile_shell.dart:662',
  // 7 overflow(s) at phone width, worst site (2 reports):
  'RequirementsImplementationScreen':
      'requirements_implementation_screen.dart:1483',
  // 7 overflow(s) at phone width, worst site (6 reports):
  'TeamRolesResponsibilitiesScreen':
      'team_roles_responsibilities_screen.dart:1435',
  // 6 overflow(s) at phone width, worst site (2 reports):
  'DesignPlanningScreen': 'design_planning_screen.dart:7222',
  // 6 overflow(s) at phone width, worst site (4 reports):
  'PlanningTechnologyScreen': 'planning_technology_screen.dart:1777',
  // 6 overflow(s) at phone width, worst site (3 reports):
  'ProgramDashboardMobileScreen': 'program_dashboard_mobile_screen.dart:977',
  // 6 overflow(s) at phone width, worst site (2 reports):
  'ProjectPlanCondensedSummaryScreen':
      'project_plan_subsections_screen.dart:4066',
  // 6 overflow(s) at phone width, worst site (2 reports):
  'RiskAssessmentScreen': 'risk_assessment_screen.dart:1835',
  // 6 overflow(s) at phone width, worst site (2 reports):
  'ScheduleScreen': 'schedule_screen.dart:6262',
  // 6 overflow(s) at phone width, worst site (4 reports):
  'StaffTeamScreen': 'staff_team_resource_grid.dart:905',
  // 5 overflow(s) at phone width, worst site (5 reports):
  'AgileKanbanConfigScreen': 'agile_kanban_config_screen.dart:400',
  // 5 overflow(s) at phone width, worst site (2 reports):
  'AgileRetrospectivesScreen': 'agile_retrospectives_screen.dart:527',
  // 5 overflow(s) at phone width, worst site (2 reports):
  'HomeScreen': 'project_dashboard_mobile_shell.dart:662',
  // 5 overflow(s) at phone width, worst site (2 reports):
  'PlanningContractingScreen': 'planning_contracting_screen.dart:279',
  // 5 overflow(s) at phone width, worst site (2 reports):
  'ProjectCommandCenterScreen': 'project_command_center_screen.dart:296',
  // 5 overflow(s) at phone width, worst site (2 reports):
  'ProjectDashboardScreen': 'project_dashboard_mobile_shell.dart:662',
  // 5 overflow(s) at phone width, worst site (2 reports):
  'ProjectPlanDetailedScheduleScreen':
      'project_plan_subsections_screen.dart:2126',
  // 5 overflow(s) at phone width, worst site (5 reports):
  'RecognitionAwardsScreen': 'recognition_awards_screen.dart:775',
  // 5 overflow(s) at phone width, worst site (5 reports):
  'ScopeCompletionScreen': 'scope_completion_screen.dart:2927',
  // 4 overflow(s) at phone width, worst site (2 reports):
  'AdminDashboardScreen': 'admin_dashboard_screen.dart:280',
  // 4 overflow(s) at phone width, worst site (2 reports):
  'AdminHomeScreen': 'admin_home_screen.dart:114',
  // 4 overflow(s) at phone width, worst site (2 reports):
  'AdminUsersScreen': 'admin_users_screen.dart:126',
  // 4 overflow(s) at phone width, worst site (2 reports):
  'AgileKanbanBoardScreen': 'agile_kanban_board_screen.dart:986',
  // 4 overflow(s) at phone width, worst site (2 reports):
  'DeliverablesRoadmapScreen': 'deliverables_roadmap_screen.dart:498',
  // 4 overflow(s) at phone width, worst site (2 reports):
  'FrontEndPlanningAllowanceScreen': 'front_end_planning_allowance.dart:1213',
  // 4 overflow(s) at phone width, worst site (2 reports):
  'IssueManagementScreen': 'issue_management_screen.dart:843',
  // 4 overflow(s) at phone width, worst site (2 reports):
  'ProjectCloseOutScreen': 'project_close_out_screen.dart:107',
  // 4 overflow(s) at phone width, worst site (2 reports):
  'ProjectFrameworkNextScreen': 'project_framework_next_screen.dart:992',
  // 4 overflow(s) at phone width, worst site (2 reports):
  'ScheduleManagementBoardScreen': 'schedule_management_board_screen.dart:1079',
  // 4 overflow(s) at phone width, worst site (2 reports):
  'WBSModuleScreen': 'wbs_builder_screen.dart:670',
  // 3 overflow(s) at phone width, worst site (2 reports):
  'AdminCouponsScreen': 'admin_coupons_screen.dart:149',
  // 3 overflow(s) at phone width, worst site (2 reports):
  'CreateContractScreen': 'front_end_planning_contracts_screen.dart:2343',
  // 3 overflow(s) at phone width, worst site (2 reports):
  'HowItWorksScreen': 'how_it_works_screen.dart:955',
  // 3 overflow(s) at phone width, worst site (2 reports):
  'LessonsLearnedScreen': 'lessons_learned_screen.dart:357',
  // 3 overflow(s) at phone width, worst site (2 reports):
  'ProgressTrackingScreen': 'progress_tracking_dashboard.dart:62',
  // 3 overflow(s) at phone width, worst site (3 reports):
  'SettingsScreen': 'settings_screen.dart:334',
  // 3 overflow(s) at phone width, worst site (2 reports):
  'SsherStackedScreen': 'ssher_stacked_screen.dart:2315',
  // 2 overflow(s) at phone width, worst site (2 reports):
  'AgileProjectBaselineScreen': 'agile_project_baseline_screen.dart:1163',
  // 2 overflow(s) at phone width, worst site (2 reports):
  'ExecutionPlanSolutionsScreen': 'execution_plan_solutions_screen.dart:145',
  // 2 overflow(s) at phone width, worst site (2 reports):
  'FinancialCloseoutScreen': 'financial_closeout_screen.dart:481',
  // 2 overflow(s) at phone width, worst site (2 reports):
  'LaunchChecklistScreen': 'launch_checklist_screen.dart:583',
  // 2 overflow(s) at phone width, worst site (2 reports):
  'OrganizationRaciMatrixScreen': 'raci_deliverable_matrix.dart:657',
  // 2 overflow(s) at phone width, worst site (2 reports):
  'ProgramTeammatesScreen': 'program_teammates_screen.dart:227',
  // 2 overflow(s) at phone width, worst site (2 reports):
  'SignInScreen': 'sign_in_screen.dart:553',
  // 2 overflow(s) at phone width, worst site (2 reports):
  'StartUpPlanningOperationsScreen':
      'startup_planning_subsections_screen.dart:2396',
  // 2 overflow(s) at phone width, worst site (2 reports):
  'TeamMeetingsScreen': 'team_meetings_resource_grid.dart:403',
  // 2 overflow(s) at phone width, worst site (2 reports):
  'TechnicalDebtManagementScreen': 'technical_debt_management_screen.dart:2555',
  // 2 overflow(s) at phone width, worst site (1 reports):
  'TrainingProjectTasksScreen': 'training_project_tasks_screen.dart:144',
  // 2 overflow(s) at phone width, worst site (2 reports):
  'UserManagementScreen': 'user_management_screen.dart:156',
  // 1 overflow(s) at phone width, worst site (1 reports):
  'ExecutionPlanInterfaceManagementOverviewScreen':
      'ai_diagram_panel.dart:1086',
  // 1 overflow(s) at phone width, worst site (1 reports):
  'FrontEndPlanningOpportunitiesScreen':
      'front_end_planning_opportunities_screen.dart:1249',
  // 1 overflow(s) at phone width, worst site (1 reports):
  'ProfileOnboardingScreen': 'profile_onboarding_screen.dart:861',
  // 1 overflow(s) at phone width, worst site (1 reports):
  'ProjectDetailsScreen': 'program_basics_screen.dart:864',
  // 1 overflow(s) at phone width, worst site (1 reports):
  'ProjectFrameworkScreen': 'project_framework_screen.dart:1171',
};
