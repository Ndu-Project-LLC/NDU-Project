import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/routing/platform_router.dart';

// Screens
import 'package:ndu_project/screens/landing_screen.dart';
import 'package:ndu_project/screens/sign_in_screen.dart';
import 'package:ndu_project/screens/create_account_screen.dart';
import 'package:ndu_project/screens/profile_onboarding_screen.dart';
import 'package:ndu_project/screens/pricing_screen.dart';
import 'package:ndu_project/screens/settings_screen.dart';
import 'package:ndu_project/screens/mobile_dashboard_screen.dart';
import 'package:ndu_project/screens/auth/mobile_forgot_password_screen.dart';
import 'package:ndu_project/screens/project_dashboard_screen.dart';
import 'package:ndu_project/screens/program_dashboard_screen.dart';
import 'package:ndu_project/screens/portfolio_dashboard_screen.dart';
import 'package:ndu_project/screens/launch_checklist_screen.dart';
import 'package:ndu_project/screens/home_screen.dart';
import 'package:ndu_project/screens/lessons_learned_screen.dart';
import 'package:ndu_project/screens/management_level_screen.dart';
import 'package:ndu_project/screens/stakeholder_management_screen.dart';
import 'package:ndu_project/screens/core_stakeholders_screen.dart';
import 'package:ndu_project/screens/splash_screen.dart';
import 'package:ndu_project/screens/onboarding/onboarding_screen.dart';

// Front-end planning cluster
import 'package:ndu_project/screens/front_end_planning_screen.dart';
import 'package:ndu_project/screens/front_end_planning_workspace_screen.dart';
import 'package:ndu_project/screens/front_end_planning_requirements_screen.dart';
import 'package:ndu_project/screens/front_end_planning_personnel_screen.dart';
import 'package:ndu_project/screens/front_end_planning_procurement_screen.dart';
import 'package:ndu_project/screens/front_end_planning_contract_vendor_quotes_screen.dart';
import 'package:ndu_project/screens/front_end_planning_contracts_screen.dart';
import 'package:ndu_project/screens/front_end_planning_infrastructure_screen.dart';
import 'package:ndu_project/screens/planning_contracting_screen.dart';
import 'package:ndu_project/screens/planning_technology_screen.dart';
import 'package:ndu_project/screens/front_end_planning_technology_personnel_screen.dart';
import 'package:ndu_project/screens/front_end_planning_risks_screen.dart';
import 'package:ndu_project/screens/front_end_planning_allowance.dart';
import 'package:ndu_project/screens/front_end_planning_milestone.dart';
import 'package:ndu_project/screens/front_end_planning_opportunities_screen.dart';
import 'package:ndu_project/screens/front_end_planning_summary.dart';
import 'package:ndu_project/screens/front_end_planning_summary_end.dart';
import 'package:ndu_project/screens/front_end_planning_security.dart';

// Project/Process cluster
import 'package:ndu_project/screens/project_plan_screen.dart';
import 'package:ndu_project/screens/project_framework_screen.dart';
import 'package:ndu_project/screens/project_framework_next_screen.dart';
import 'package:ndu_project/screens/project_charter_screen.dart';
import 'package:ndu_project/screens/project_decision_summary_screen.dart';
import 'package:ndu_project/screens/progress_tracking_screen.dart';
import 'package:ndu_project/wbs/screens/wbs_module_screen.dart';
import 'package:ndu_project/pbs/screens/pbs_module_screen.dart';
import 'package:ndu_project/cost_estimate/screens/cost_estimate_module_screen.dart';
import 'package:ndu_project/schedule/screens/schedule_module_screen.dart';
import 'package:ndu_project/project_controls/screens/project_controls_screen.dart';
import 'package:ndu_project/project_controls/screens/change_management_module_screen.dart';
import 'package:ndu_project/screens/integration_dashboard_screen.dart';
import 'package:ndu_project/screens/landing/careers_page_screen.dart';
import 'package:ndu_project/screens/execution_plan_screen.dart';
import 'package:ndu_project/screens/execution_work_packages_screen.dart';
import 'package:ndu_project/screens/execution_plan_interface_management_overview_screen.dart';
import 'package:ndu_project/screens/cost_estimate_screen.dart';
import 'package:ndu_project/screens/cost_analysis_screen.dart';
import 'package:ndu_project/screens/potential_solutions_screen.dart';
import 'package:ndu_project/screens/preferred_solution_analysis_screen.dart';
import 'package:ndu_project/screens/risk_assessment_screen.dart';
import 'package:ndu_project/screens/risk_identification_screen.dart';
import 'package:ndu_project/screens/issue_management_screen.dart';
import 'package:ndu_project/screens/contract_details_dashboard_screen.dart';
import 'package:ndu_project/screens/schedule_management_board_screen.dart';

// Team cluster
import 'package:ndu_project/screens/team_management_screen.dart';
import 'package:ndu_project/screens/team_meetings_screen.dart';
import 'package:ndu_project/screens/team_roles_responsibilities_screen.dart';
import 'package:ndu_project/screens/team_training_building_screen.dart';
import 'package:ndu_project/screens/training_project_tasks_screen.dart';
import 'package:ndu_project/screens/staff_team_screen.dart';
import 'package:ndu_project/screens/infrastructure_considerations_screen.dart';
import 'package:ndu_project/screens/it_considerations_screen.dart';
import 'package:ndu_project/screens/security_management_screen.dart';

// Program basics / templates
import 'package:ndu_project/screens/program_basics_screen.dart';
import 'package:ndu_project/screens/initiation_phase_screen.dart';
import 'package:ndu_project/screens/design_phase_screen.dart';
import 'package:ndu_project/screens/deliverables_roadmap_screen.dart';
import 'package:ndu_project/screens/deliver_project_closure_screen.dart';
import 'package:ndu_project/screens/transition_to_prod_team_screen.dart';
import 'package:ndu_project/screens/fat_mechanical_completion_screen.dart';
import 'package:ndu_project/screens/contract_close_out_screen.dart';
import 'package:ndu_project/screens/vendor_account_close_out_screen.dart';
import 'package:ndu_project/screens/ui_ux_design_screen.dart';
import 'package:ndu_project/screens/development_set_up_screen.dart';
import 'package:ndu_project/screens/technical_alignment_screen.dart';
import 'package:ndu_project/screens/long_lead_equipment_ordering_screen.dart';
import 'package:ndu_project/screens/technical_development_screen.dart';
import 'package:ndu_project/screens/tools_integration_screen.dart';
import 'package:ndu_project/screens/project_close_out_screen.dart';
import 'package:ndu_project/screens/demobilize_team_screen.dart';
import 'package:ndu_project/screens/summarize_account_risks_screen.dart';
import 'package:ndu_project/screens/financial_closeout_screen.dart';
import 'package:ndu_project/screens/benefits_realization_screen.dart';
import 'package:ndu_project/screens/agile_development_iterations_screen.dart';
import 'package:ndu_project/screens/engineering_design_screen.dart';
import 'package:ndu_project/screens/scope_completion_screen.dart';
import 'package:ndu_project/screens/requirements_implementation_screen.dart';
import 'package:ndu_project/screens/privacy_policy_screen.dart';
import 'package:ndu_project/screens/terms_conditions_screen.dart';
import 'package:ndu_project/screens/backend_design_screen.dart';
import 'package:ndu_project/screens/technical_debt_management_screen.dart';
import 'package:ndu_project/screens/risk_tracking_workspace_screen.dart';
import 'package:ndu_project/screens/identify_staff_ops_team_screen.dart';
import 'package:ndu_project/screens/contracts_tracking_screen.dart';
import 'package:ndu_project/screens/vendor_tracking_screen.dart';
import 'package:ndu_project/screens/deliverable_status_updates_screen.dart';
import 'package:ndu_project/screens/recurring_deliverables_screen.dart';
import 'package:ndu_project/screens/status_reports_screen.dart';
import 'package:ndu_project/screens/detailed_design_screen.dart';
import 'package:ndu_project/screens/scope_tracking_implementation_screen.dart';
import 'package:ndu_project/screens/stakeholder_alignment_screen.dart';
import 'package:ndu_project/screens/update_ops_maintenance_plans_screen.dart';

// SSHER suite
import 'package:ndu_project/screens/ssher_stacked_screen.dart';
import 'package:ndu_project/screens/ssher_screen_1.dart';
import 'package:ndu_project/screens/ssher_screen_2.dart';
import 'package:ndu_project/screens/ssher_screen_3.dart';
import 'package:ndu_project/screens/ssher_screen_4.dart';

// Workspace dashboards & remaining pages
import 'package:ndu_project/screens/regular_project_dashboard_screen.dart';
import 'package:ndu_project/screens/project_command_center_screen.dart';
import 'package:ndu_project/screens/program_dashboard_mobile_screen.dart';
import 'package:ndu_project/screens/project_baseline_screen.dart';
import 'package:ndu_project/screens/schedule_screen.dart';
import 'package:ndu_project/screens/agile_project_hub_screen.dart';
import 'package:ndu_project/screens/agile_release_plan_screen.dart';
import 'package:ndu_project/screens/team_status_check_screen.dart';
import 'package:ndu_project/screens/admin_content_screen.dart';
import 'package:ndu_project/screens/admin/admin_hints_screen.dart';
import 'package:ndu_project/screens/admin/admin_dashboard_screen.dart';
import 'package:ndu_project/screens/admin/user_management_screen.dart';
import 'package:ndu_project/screens/punchlist_actions_screen.dart';
import 'package:ndu_project/screens/ai_recommendations_screen.dart';
import 'package:ndu_project/screens/technology_definitions_screen.dart';
import 'package:ndu_project/screens/external_integrations_screen.dart';
import 'package:ndu_project/screens/ai_integrations_screen.dart';
import 'package:ndu_project/screens/quality_management_screen.dart';
import 'package:ndu_project/screens/interface_management_screen.dart';
import 'package:ndu_project/screens/planning_requirements_screen.dart';
import 'package:ndu_project/screens/ssher_safety_full_view.dart';
import 'package:ndu_project/screens/gap_analysis_scope_reconcillation_screen.dart';
import 'package:ndu_project/screens/project_workspace_dashboard_screen.dart';
import 'package:ndu_project/screens/group_into_portfolio_screen.dart';
import 'package:ndu_project/screens/actual_vs_planned_gap_analysis_screen.dart';
import 'package:ndu_project/screens/deliverables_roadmap_detailed_screen.dart';
import 'package:ndu_project/screens/execution_enabling_work_plan_screen.dart';
import 'package:ndu_project/screens/execution_plan_best_practices_screen.dart';
import 'package:ndu_project/screens/execution_plan_lessons_learned_screen.dart';
import 'package:ndu_project/screens/execution_plan_stakeholder_identification_screen.dart';
import 'package:ndu_project/screens/execution_plan_communication_plan_screen.dart';
import 'package:ndu_project/screens/execution_plan_infrastructure_plan_screen.dart';
import 'package:ndu_project/screens/execution_plan_interface_management_plan_screen.dart';
import 'package:ndu_project/screens/execution_plan_construction_plan_screen.dart';
import 'package:ndu_project/screens/execution_plan_agile_delivery_plan_screen.dart';
import 'package:ndu_project/screens/execution_plan_details_screen.dart';
import 'package:ndu_project/screens/two_factor_verification_screen.dart';
import 'package:ndu_project/screens/business_system_integrations_screen.dart';
import 'package:ndu_project/screens/project_plan_subsections_screen.dart';
import 'package:ndu_project/screens/agile_delivery_model_screen.dart';
import 'package:ndu_project/screens/agile_kanban_config_screen.dart';
import 'package:ndu_project/screens/agile_acceptance_criteria_screen.dart';
import 'package:ndu_project/screens/agile_epics_features_screen.dart';
import 'package:ndu_project/screens/agile_scrum_config_screen.dart';
import 'package:ndu_project/screens/agile_capacity_planning_screen.dart';
import 'package:ndu_project/screens/agile_metrics_planning_screen.dart';
import 'package:ndu_project/screens/deliverable_roadmap_subsections_screen.dart';
import 'package:ndu_project/screens/organization_plan_subsections_screen.dart';
import 'package:ndu_project/screens/startup_planning_subsections_screen.dart';
import 'package:ndu_project/screens/startup_planning_screen.dart';
import 'package:ndu_project/screens/agile_backlog_governance_screen.dart';
import 'package:ndu_project/screens/agile_sprint_calendar_screen.dart';
import 'package:ndu_project/screens/agile_team_structure_screen.dart';
import 'package:ndu_project/screens/mfa_enrollment_screen.dart';
import 'package:ndu_project/screens/recovery_codes_screen.dart';
import 'package:ndu_project/screens/project_activities_log_screen.dart';
import 'package:ndu_project/screens/basic_plan_dashboard_screen.dart';
import 'package:ndu_project/screens/admin/admin_pricing_config_screen.dart';
import 'package:ndu_project/screens/execution_plan_interface_management_screen.dart';
import 'package:ndu_project/screens/design_deliverables_screen.dart';
import 'package:ndu_project/screens/design_planning_screen.dart';
import 'package:ndu_project/screens/partner_screen.dart';
import 'package:ndu_project/screens/how_it_works_screen.dart';
import 'package:ndu_project/screens/use_cases_screen.dart';
import 'package:ndu_project/screens/landing/landing_page_screen.dart';
import 'package:ndu_project/screens/execution_plan_solutions_screen.dart';
import 'package:ndu_project/screens/execution_issue_management_screen.dart';
import 'package:ndu_project/screens/finalize_project_screen.dart';
import 'package:ndu_project/screens/commerce_viability_screen.dart';
import 'package:ndu_project/screens/team_handover_screen.dart';
import 'package:ndu_project/screens/scope_tracking_plan_screen.dart';
import 'package:ndu_project/screens/salvage_disposal_team_screen.dart';
import 'package:ndu_project/screens/risk_tracking_screen.dart';
import 'package:ndu_project/screens/recognition_awards_screen.dart';
import 'package:ndu_project/screens/agile_sprint_reviews_screen.dart';
import 'package:ndu_project/screens/agile_retrospectives_screen.dart';
import 'package:ndu_project/screens/agile_roadmap_screen.dart';
import 'package:ndu_project/screens/agile_daily_standups_screen.dart';
import 'package:ndu_project/screens/agile_iteration_management_screen.dart';
import 'package:ndu_project/screens/agile_risks_screen.dart';
import 'package:ndu_project/screens/agile_metrics_screen.dart';
import 'package:ndu_project/screens/agile_kanban_board_screen.dart';
import 'package:ndu_project/screens/agile_ai_coach_screen.dart';
import 'package:ndu_project/screens/agile_dashboard_screen.dart';
import 'package:ndu_project/screens/agile_project_baseline_screen.dart';
import 'package:ndu_project/screens/document_review_matrix_screen.dart';
import 'package:ndu_project/screens/specialized_design_screen.dart';
import 'package:ndu_project/screens/planning_procurement_v2_screen.dart';
import 'package:ndu_project/screens/project_team_activities_screen.dart';
import 'package:ndu_project/screens/technology_inventory_screen.dart';

// Admin (used in admin main entry)
import 'package:ndu_project/screens/admin/admin_home_screen.dart';
import 'package:ndu_project/screens/admin/admin_auth_wrapper.dart';

import 'package:ndu_project/screens/admin/admin_projects_screen.dart';
import 'package:ndu_project/screens/admin/admin_users_screen.dart';
import 'package:ndu_project/screens/admin/admin_coupons_screen.dart';
import 'package:ndu_project/screens/admin/admin_survey_responses_screen.dart';
import 'package:ndu_project/screens/admin/admin_subscription_lookup_screen.dart';
import 'package:ndu_project/services/access_policy.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/services/subscription_service.dart';
import 'package:ndu_project/services/activity_auto_logger.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/pricing/mobile_pricing_screen.dart';
import 'package:ndu_project/routing/shimmer_page_transition.dart';

/// Named route constants for consistency.
class AppRoutes {
  static const splash = 'splash';
  static const onboarding = 'onboarding';
  static const landing = 'landing';
  static const signIn = 'sign-in';
  static const createAccount = 'create-account';
  static const profileOnboarding = 'profile-onboarding';
  static const forgotPassword = 'forgot-password';
  static const pricing = 'pricing';
  static const mobilePricing = 'mobile-pricing';
  static const settings = 'settings';

  static const dashboard = 'dashboard';
  static const programDashboard = 'program-dashboard';
  static const portfolioDashboard = 'portfolio-dashboard';
  static const launchChecklist = 'launch-checklist';

  // FEP cluster
  static const fep = 'front-end-planning';
  static const fepWorkspace = 'fep-workspace';
  static const fepRequirements = 'fep-requirements';
  static const fepPersonnel = 'fep-personnel';
  static const fepProcurement = 'fep-procurement';
  static const fepContracts = 'fep-contracts';
  static const fepVendorQuotes = 'fep-contract-vendor-quotes';
  static const fepInfrastructure = 'fep-infrastructure';
  static const fepTechnology = 'fep-technology';
  static const fepTechnologyPersonnel = 'fep-technology-personnel';
  static const fepRisks = 'fep-risks';
  static const fepAllowance = 'fep-allowance';
  static const fepMilestone = 'fep-milestone';
  static const fepOpportunities = 'fep-opportunities';
  static const fepSummary = 'fep-summary';
  static const fepSummaryEnd = 'fep-summary-end';

  // Process cluster
  static const projectPlan = 'project-plan';
  static const projectFramework = 'project-framework';
  static const projectFrameworkNext = 'project-framework-next';
  static const projectCharter = 'project-charter';
  static const projectDecisionSummary = 'project-decision-summary';
  static const progressTracking = 'progress-tracking';
  static const wbs = 'work-breakdown-structure';
  static const pbs = 'product-breakdown-structure';
  static const executionPlan = 'execution-plan';
  static const executionWorkPackages = 'execution-work-packages';
  static const executionPlanInterface = 'execution-plan-interface-management';
  static const costEstimate = 'cost-estimate';
  static const costAnalysis = 'cost-analysis';
  static const potentialSolutions = 'potential-solutions';
  static const preferredSolutionAnalysis = 'preferred-solution-analysis';
  static const riskAssessment = 'risk-assessment';
  static const riskIdentification = 'risk-identification';
  static const issueManagement = 'issue-management';
  static const changeManagement = 'change-management';
  static const schedule = 'schedule';
  static const contractDetails = 'contract-details';
  static const scheduleManagementBoard = 'schedule-management';
  static const projectControls = 'project-controls';
  static const changeManagementModule = 'change-management-module';
  static const integrationDashboard = 'integration-dashboard';
  static const landingPage = 'landing-page';
  static const careersPage = 'careers';

  // Team cluster
  static const teamManagement = 'team-management';
  static const teamMeetings = 'team-meetings';
  static const teamRoles = 'team-roles-responsibilities';
  static const teamTraining = 'team-training-building';
  static const trainingTasks = 'training-project-tasks';
  static const staffTeam = 'staff-team';
  static const infrastructureConsiderations = 'infrastructure-considerations';
  static const itConsiderations = 'it-considerations';
  static const securityManagement = 'security-management';

  // Program basics
  static const programBasics = 'program-basics';
  static const initiationPhase = 'initiation-phase';
  static const designPhase = 'design-phase';
  static const deliverablesRoadmap = 'deliverables-roadmap';
  static const managementLevel = 'management-level';
  static const mobileDashboard = 'mobile-dashboard';
  static const home = 'home';
  static const lessonsLearned = 'lessons-learned';
  static const stakeholderManagement = 'stakeholder-management';
  static const coreStakeholders = 'core-stakeholders';
  static const fepSecurity = 'fep-security';
  static const deliverProjectClosure = 'deliver-project-closure';
  static const transitionToProdTeam = 'transition-to-prod-team';
  static const contractCloseOut = 'contract-close-out';
  static const vendorAccountCloseOut = 'vendor-account-close-out';
  static const uiUxDesign = 'ui-ux-design';
  static const developmentSetUp = 'development-set-up';
  static const technicalAlignment = 'technical-alignment';
  static const backendDesign = 'backend-design';
  static const longLeadEquipmentOrdering = 'long-lead-equipment-ordering';
  static const technicalDebtManagement = 'technical-debt-management';
  static const riskTracking = 'risk-tracking';
  static const identifyStaffOpsTeam = 'identify-staff-ops-team';
  static const contractsTracking = 'contracts-tracking';
  static const vendorTracking = 'vendor-tracking';
  static const deliverableStatusUpdates = 'deliverable-status-updates';
  static const recurringDeliverables = 'recurring-deliverables';
  static const statusReports = 'status-reports';
  static const detailedDesign = 'detailed-design';
  static const scopeTrackingImplementation = 'scope-tracking-implementation';
  static const stakeholderAlignment = 'stakeholder-alignment';
  static const updateOpsMaintenancePlans = 'update-ops-maintenance-plans';
  static const projectCloseOut = 'project-close-out';
  static const demobilizeTeam = 'demobilize-team';
  static const fatMechanicalCompletion = 'fat-mechanical-completion';
  static const financialCloseout = 'financial-closeout';
  static const benefitsRealization = 'benefits-realization';
  static const technicalDevelopment = 'technical-development';
  static const toolsIntegration = 'tools-integration';
  static const summarizeAccountRisks = 'summarize-account-risks';
  static const agileDevelopmentIterations = 'agile-development-iterations';
  static const engineeringDesign = 'engineering-design';
  static const scopeCompletion = 'scope-completion';
  static const requirementsImplementation = 'requirements-implementation';
  static const privacyPolicy = 'privacy-policy';
  static const termsConditions = 'terms-conditions';

  // Workspace dashboards & remaining pages (unique URLs for every page)
  static const regularProjectDashboard = 'regular-project-dashboard';
  static const projectCommandCenter = 'project-command-center';
  static const programDashboardMobile = 'program-dashboard-mobile';
  static const projectBaseline = 'project-baseline';
  static const scheduleScreen = 'schedule-screen';
  static const agileProjectHub = 'agile-project-hub';
  static const agileReleasePlan = 'agile-release-plan';
  static const teamStatusCheck = 'team-status-check';
  static const adminContent = 'admin-content';
  static const adminHints = 'admin-hints';
  static const adminDashboard = 'admin-dashboard';
  static const userManagement = 'user-management';
  static const punchlistActions = 'punchlist-actions';
  static const aiRecommendations = 'ai-recommendations';
  static const technologyDefinitions = 'technology-definitions';
  static const externalIntegrations = 'external-integrations';
  static const aiIntegrations = 'ai-integrations';
  static const qualityManagement = 'quality-management';
  static const safetyFullView = 'safety-full-view';
  static const gapAnalysisScopeReconcillation = 'gap-analysis-scope-reconciliation';
  static const projectWorkspaceDashboard = 'project-workspace-dashboard';
  static const groupIntoPortfolio = 'group-into-portfolio';
  static const actualVsPlannedGapAnalysis = 'actual-vs-planned-gap-analysis';
  static const deliverablesRoadmapDetailed = 'deliverables-roadmap-detailed';
  static const executionEnablingWorkPlan = 'execution-enabling-work-plan';
  static const executionPlanBestPractices = 'execution-plan-best-practices';
  static const executionPlanLessonsLearned = 'execution-plan-lessons-learned';
  static const executionPlanStakeholderIdentification = 'execution-plan-stakeholder-identification';
  static const executionPlanCommunicationPlan = 'execution-plan-communication-plan';
  static const executionPlanInfrastructurePlan = 'execution-plan-infrastructure-plan';
  static const executionPlanInterfaceManagementPlan = 'execution-plan-interface-management-plan';
  static const executionPlanConstructionPlan = 'execution-plan-construction-plan';
  static const executionPlanAgileDeliveryPlan = 'execution-plan-agile-delivery-plan';
  static const executionPlanDetails = 'execution-plan-details';
  static const twoFactorVerification = 'two-factor-verification';
  static const businessSystemIntegrations = 'business-system-integrations';
  static const projectPlanLevel1Schedule = 'project-plan-level-1-schedule';
  static const agileBacklogGovernance = 'agile-backlog-governance';
  static const agileSprintCalendar = 'agile-sprint-calendar';
  static const agileTeamStructure = 'agile-team-structure';
  static const mfaEnrollment = 'mfa-enrollment';
  static const recoveryCodes = 'recovery-codes';
  static const projectActivitiesLog = 'project-activities-log';
  static const basicPlanDashboard = 'basic-plan-dashboard';
  static const adminPricingConfig = 'admin-pricing-config';
  static const executionPlanInterfaceManagement = 'execution-interface-management';
  static const projectPlanDetailedSchedule = 'project-plan-detailed-schedule';
  static const projectPlanCondensedSummary = 'project-plan-condensed-summary';
  static const agileDeliveryModel = 'agile-delivery-model';
  static const agileKanbanConfig = 'agile-kanban-config';
  static const agileAcceptanceCriteria = 'agile-acceptance-criteria';
  static const agileEpicsFeatures = 'agile-epics-features';
  static const agileScrumConfig = 'agile-scrum-config';
  static const agileCapacityPlanning = 'agile-capacity-planning';
  static const agileMetricsPlanning = 'agile-metrics-planning';
  static const deliverableRoadmapAgileMapOut = 'deliverable-roadmap-agile-map-out';
  static const organizationRolesResponsibilities = 'organization-roles-responsibilities';
  static const organizationRaciMatrix = 'organization-raci-matrix';
  static const organizationStaffingPlan = 'organization-staffing-plan';
  static const startupPlanningOperations = 'startup-planning-operations';
  static const startupPlanningHypercare = 'startup-planning-hypercare';
  static const startupPlanningDevOps = 'startup-planning-devops';
  static const startupPlanningCloseOutPlan = 'startup-planning-closeout-plan';
  static const startupPlanning = 'startup-planning';
  static const interfaceManagement = 'interface-management';
  static const planningRequirements = 'planning-requirements';
  static const designDeliverables = 'design-deliverables';
  static const designPlanning = 'design-planning';
  static const partner = 'partner';
  static const howItWorks = 'how-it-works';
  static const useCases = 'use-cases';
  static const landingPageScreen = 'landing-page-screen';
  static const projectDetails = 'project-details';
  static const executionPlanSolutions = 'execution-plan-solutions';
  static const executionIssueManagement = 'execution-issue-management';
  static const finalizeProject = 'finalize-project';
  static const commerceViability = 'commerce-viability';
  static const teamHandover = 'team-handover';
  static const scopeTrackingPlan = 'scope-tracking-plan';
  static const salvageDisposalTeam = 'salvage-disposal-team';
  static const riskTrackingScreen = 'risk-tracking-screen';
  static const recognitionAwards = 'recognition-awards';
  static const agileSprintReviews = 'agile-sprint-reviews';
  static const agileRetrospectives = 'agile-retrospectives';
  static const agileRoadmap = 'agile-roadmap';
  static const agileDailyStandups = 'agile-daily-standups';
  static const agileIterationManagement = 'agile-iteration-management';
  static const agileRisks = 'agile-risks';
  static const agileMetrics = 'agile-metrics';
  static const agileKanbanBoard = 'agile-kanban-board';
  static const agileAiCoach = 'agile-ai-coach';
  static const agileDashboard = 'agile-dashboard';
  static const agileProjectBaseline = 'agile-project-baseline';
  static const documentReviewMatrix = 'document-review-matrix';
  static const specializedDesign = 'specialized-design';
  static const createContract = 'create-contract';
  static const planningProcurement = 'planning-procurement';
  static const projectTeamActivities = 'project-team-activities';
  static const technologyInventory = 'technology-inventory';
  static const costEstimateScreen = 'cost-estimate-screen';

  // SSHER suite
  static const ssherStacked = 'ssher-stacked';
  static const ssher1 = 'ssher-1';
  static const ssher2 = 'ssher-2';
  static const ssher3 = 'ssher-3';
  static const ssher4 = 'ssher-4';
  static const ssherFull = 'ssher-full';

  // Admin
  static const adminHome = 'admin-home';
  static const adminProjects = 'admin-projects';
  static const adminUsers = 'admin-users';
  static const adminCoupons = 'admin-coupons';
  static const adminSubscriptionLookup = 'admin-subscription-lookup';
  static const adminSurveyResponses = 'admin-survey-responses';
  static const adminPortal = 'admin';
}

/// A common redirect that checks web host policy when necessary.
String? _adminHostGuard(User? user) {
  if (AccessPolicy.isRestrictedAdminHost()) {
    final allowed = AccessPolicy.isEmailAllowedForAdmin(user?.email);
    if (!allowed) {
      // Redirect unauthenticated users on admin host to sign-in page
      return '/${AppRoutes.signIn}';
    }
  }
  return null;
}

/// Detects route-table collisions that would break deep linking.
///
/// go_router only rejects duplicate *sibling* paths at construction time; two
/// routes in different parents can still resolve to the same full path and
/// silently shadow each other. This walks the whole tree (including nested
/// [GoRoute]s under shells) and returns a human-readable description of the
/// first violation, or `null` when the table is valid.
///
/// Used as a runtime guard by [AppRouter] and exercised directly by the
/// router tests.
String? routeTableViolation(List<RouteBase> routes) {
  final fullPaths = <String, List<String>>{};
  final names = <String, String>{};
  final nameConflicts = <String>[];

  void walk(RouteBase route, String parent) {
    final segment = route is GoRoute ? route.path : null;
    final full = segment == null
        ? parent
        : '$parent/$segment'.replaceAll(RegExp(r'/+'), '/');
    if (route is GoRoute) {
      final label = route.name ??
          (parent.isEmpty ? '<unnamed>' : '$parent/<unnamed>');
      // Guard against empty/absent segments: an empty child path would
      // resolve to the parent's own full path and be miscounted as a
      // collision. (This go_router version rejects empty paths, but keep the
      // walk defensive against future variants.)
      if (segment != null && segment.isNotEmpty) {
        fullPaths.putIfAbsent(full, () => <String>[]).add(label);
      }
      final name = route.name;
      if (name != null && name.isNotEmpty) {
        final existing = names[name];
        if (existing != null && existing != full) {
          nameConflicts.add('"$name" registered for both "$existing" and "$full"');
        } else {
          names[name] = full;
        }
      }
    }
    for (final sub in route.routes) {
      walk(sub, segment == null ? parent : full);
    }
  }

  for (final route in routes) {
    walk(route, '');
  }

  final collisions = fullPaths.entries
      .where((entry) => entry.value.length > 1)
      .map((entry) => '  ${entry.key} -> ${entry.value.join(', ')}')
      .toList()
    ..sort();
  if (collisions.isNotEmpty) {
    return 'duplicate full paths across the route tree:\n'
        '${collisions.join('\n')}\n'
        'Fix the collisions so every deep link resolves to a single screen.';
  }
  if (nameConflicts.isNotEmpty) {
    return 'duplicate route names: ${nameConflicts.join('; ')}';
  }
  return null;
}

/// Builds a [GoRouter] and runs [routeTableViolation] over its configuration.
///
/// Throws a [StateError] in debug and release builds when the route table is
/// invalid, so a misconfigured deep link fails loudly at startup instead of
/// 404ing or shadowing another page at runtime.
GoRouter _guardedRouter(String routerId, GoRouter Function() build) {
  final router = build();
  final violation = routeTableViolation(router.configuration.routes);
  if (violation != null) {
    throw StateError('GoRouter "$routerId" rejected: $violation');
  }
  return router;
}

class AppRouter {
  // The primary router for the end-user app
  static final GoRouter main = _guardedRouter('main', () => GoRouter(
    debugLogDiagnostics: kDebugMode,
    initialLocation: PlatformRouter.getInitialRoute(),
    redirect: (context, state) async {
      // Enforce admin-host policy if a user is present
      User? user;
      try {
        user = FirebaseAuth.instance.currentUser;
      } catch (_) {}
      final blocked = _adminHostGuard(user);
      if (blocked != null) return blocked;

      // ── Auth guard: redirect unauthenticated users to sign-in for protected routes ──
      final publicRoutes = [
        '/', '/${AppRoutes.signIn}', '/${AppRoutes.createAccount}',
        '/${AppRoutes.splash}', '/${AppRoutes.onboarding}',
        '/${AppRoutes.profileOnboarding}',
        '/${AppRoutes.mobilePricing}', '/${AppRoutes.pricing}',
        '/${AppRoutes.privacyPolicy}', '/${AppRoutes.termsConditions}',
      ];
      final isPublicRoute = publicRoutes.contains(state.matchedLocation);
      if (user == null && !isPublicRoute) {
        return '/${AppRoutes.signIn}';
      }

      // On admin host: authenticated users on root or sign-in go to dashboard
      if (AccessPolicy.isRestrictedAdminHost() && user != null) {
        final loc = state.matchedLocation;
        if (loc == '/' || loc == '/${AppRoutes.signIn}') {
          return '/${AppRoutes.dashboard}';
        }
      }

      // Friendly default: if authenticated and on the root, go to dashboard
      if (user != null && state.matchedLocation == '/') {
        return '/${AppRoutes.dashboard}';
      }

      // ── Subscription guard: redirect users without an active subscription
      // to the pricing page. Only applies to authenticated users on
      // non-public routes (except pricing itself). The check is async-safe
      // and cached to avoid repeated Firestore reads. ──
      if (user != null && !isPublicRoute &&
          state.matchedLocation != '/${AppRoutes.pricing}' &&
          state.matchedLocation != '/${AppRoutes.mobilePricing}') {
        // Skip for admin host (admin portal has its own access control)
        // Also skip for admin users (by email) — admins don't need subscriptions
        final isAdminUser = UserService.isAdminEmail(user.email ?? '');
        if (!AccessPolicy.isRestrictedAdminHost() && !isAdminUser) {
          final hasSub = await SubscriptionService.hasActiveSubscription();
          if (!hasSub) {
            return '/${AppRoutes.pricing}?reason=no_subscription';
          }
        }
      }


      // ── Auto-log page visits to the project activity log ──
      // Every navigation to a project screen (anything other than the public
      // routes) is recorded so the activity log is a live document of who
      // visited what, when. Skipped for unauthenticated users and public
      // routes to avoid noise. The ActivityAutoLogger throttles repeat
      // visits to the same page within 30 seconds.
      if (user != null) {
        final loc = state.matchedLocation;
        final isPublic = const [
          '/', '/sign-in', '/create-account', '/splash', '/onboarding',
          '/profile-onboarding', '/mobile-pricing', '/privacy-policy',
          '/terms-conditions', '/pricing',
        ].contains(loc);
        if (!isPublic) {
          final pageMeta = _describeRoute(loc);
          if (pageMeta != null) {
            // Fire-and-forget — never block navigation on a log write.
            ActivityAutoLogger.instance.logPageVisit(
              projectId: _activeProjectIdForUser(user.uid),
              route: loc,
              pageTitle: pageMeta.$1,
              phase: pageMeta.$2,
            );
          }
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        name: AppRoutes.landing,
        path: '/',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const LandingScreen()),
      ),
      GoRoute(
        name: AppRoutes.splash,
        path: '/splash',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const SplashScreen()),
      ),
      GoRoute(
        name: AppRoutes.onboarding,
        path: '/onboarding',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const OnboardingScreen()),
      ),
      GoRoute(
        name: AppRoutes.mobilePricing,
        path: '/mobile-pricing',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const MobilePricingScreen()),
      ),
      GoRoute(
        name: AppRoutes.adminPortal,
        path: '/${AppRoutes.adminPortal}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const AdminAuthWrapper()),
      ),
      GoRoute(
        name: AppRoutes.adminHome,
        path: '/${AppRoutes.adminHome}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const AdminAuthWrapper(child: AdminHomeScreen())),
      ),
      GoRoute(
        name: AppRoutes.adminProjects,
        path: '/${AppRoutes.adminProjects}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const AdminAuthWrapper(child: AdminProjectsScreen())),
      ),
      GoRoute(
        name: AppRoutes.adminUsers,
        path: '/${AppRoutes.adminUsers}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const AdminAuthWrapper(child: AdminUsersScreen())),
      ),
      GoRoute(
        name: AppRoutes.adminCoupons,
        path: '/${AppRoutes.adminCoupons}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const AdminAuthWrapper(child: AdminCouponsScreen())),
      ),
      GoRoute(
        name: AppRoutes.adminSubscriptionLookup,
        path: '/${AppRoutes.adminSubscriptionLookup}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const AdminAuthWrapper(child: AdminSubscriptionLookupScreen())),
      ),
      GoRoute(
        name: AppRoutes.adminSurveyResponses,
        path: '/${AppRoutes.adminSurveyResponses}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const AdminAuthWrapper(child: AdminSurveyResponsesScreen())),
      ),
      GoRoute(
        name: AppRoutes.signIn,
        path: '/${AppRoutes.signIn}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const SignInScreen()),
      ),
      GoRoute(
        name: AppRoutes.createAccount,
        path: '/${AppRoutes.createAccount}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const CreateAccountScreen()),
      ),
      GoRoute(
        name: AppRoutes.profileOnboarding,
        path: '/${AppRoutes.profileOnboarding}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const ProfileOnboardingScreen()),
      ),
      GoRoute(
        name: AppRoutes.forgotPassword,
        path: '/${AppRoutes.forgotPassword}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const MobileForgotPasswordScreen()),
      ),
      GoRoute(
        name: AppRoutes.pricing,
        path: '/${AppRoutes.pricing}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const PricingScreen()),
      ),
      GoRoute(
        name: AppRoutes.settings,
        path: '/${AppRoutes.settings}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const SettingsScreen()),
      ),
      // Dashboards
      GoRoute(
        name: AppRoutes.dashboard,
        path: '/${AppRoutes.dashboard}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const ProjectDashboardScreen()),
      ),
      GoRoute(
        name: AppRoutes.programDashboard,
        path: '/${AppRoutes.programDashboard}',
        pageBuilder: (context, state) {
          final programId = state.uri.queryParameters['programId'];
          return shimmerTransitionPage(state: state, child: ProgramDashboardScreen(programId: programId));
        },
      ),
      GoRoute(
        name: AppRoutes.mobileDashboard,
        path: '/${AppRoutes.mobileDashboard}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const MobileDashboardScreen()),
      ),
      GoRoute(
        name: AppRoutes.portfolioDashboard,
        path: '/${AppRoutes.portfolioDashboard}',
        pageBuilder: (context, state) {
          final portfolioId = state.uri.queryParameters['portfolioId'];
          return shimmerTransitionPage(state: state, child: PortfolioDashboardScreen(portfolioId: portfolioId));
        },
      ),
      GoRoute(
        name: AppRoutes.launchChecklist,
        path: '/${AppRoutes.launchChecklist}',
        pageBuilder: (context, state) => shimmerTransitionPage(state: state, child: const LaunchChecklistScreen()),
      ),

      // Supplemental entry points
      GoRoute(
          name: AppRoutes.home,
          path: '/${AppRoutes.home}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const HomeScreen())),
      GoRoute(
          name: AppRoutes.managementLevel,
          path: '/${AppRoutes.managementLevel}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ManagementLevelScreen())),
      GoRoute(
          name: AppRoutes.lessonsLearned,
          path: '/${AppRoutes.lessonsLearned}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const LessonsLearnedScreen())),
      GoRoute(
          name: AppRoutes.stakeholderManagement,
          path: '/${AppRoutes.stakeholderManagement}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const StakeholderManagementScreen())),
      GoRoute(
        name: AppRoutes.coreStakeholders,
        path: '/${AppRoutes.coreStakeholders}',
        pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: _extraOr(s, const CoreStakeholdersScreen(notes: '', solutions: []))),
      ),

      // FEP cluster
      GoRoute(
          name: AppRoutes.fep,
          path: '/${AppRoutes.fep}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FrontEndPlanningScreen())),
      GoRoute(
          name: AppRoutes.fepWorkspace,
          path: '/${AppRoutes.fepWorkspace}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: _extraOr(s, const FrontEndPlanningWorkspaceScreen()))),
      GoRoute(
          name: AppRoutes.fepRequirements,
          path: '/${AppRoutes.fepRequirements}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FrontEndPlanningRequirementsScreen())),
      GoRoute(
          name: AppRoutes.fepPersonnel,
          path: '/${AppRoutes.fepPersonnel}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FrontEndPlanningPersonnelScreen())),
      GoRoute(
          name: AppRoutes.fepProcurement,
          path: '/${AppRoutes.fepProcurement}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FrontEndPlanningProcurementScreen())),
      GoRoute(
          name: AppRoutes.fepContracts,
          path: '/${AppRoutes.fepContracts}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const PlanningContractingScreen())),
      GoRoute(
          name: AppRoutes.fepVendorQuotes,
          path: '/${AppRoutes.fepVendorQuotes}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FrontEndPlanningContractVendorQuotesScreen())),
      GoRoute(
          name: AppRoutes.fepInfrastructure,
          path: '/${AppRoutes.fepInfrastructure}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FrontEndPlanningInfrastructureScreen())),
      GoRoute(
          name: AppRoutes.fepTechnology,
          path: '/${AppRoutes.fepTechnology}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const PlanningTechnologyScreen())),
      GoRoute(
          name: AppRoutes.fepTechnologyPersonnel,
          path: '/${AppRoutes.fepTechnologyPersonnel}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FrontEndPlanningTechnologyPersonnelScreen())),
      GoRoute(
          name: AppRoutes.fepRisks,
          path: '/${AppRoutes.fepRisks}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FrontEndPlanningRisksScreen())),
      GoRoute(
          name: AppRoutes.fepAllowance,
          path: '/${AppRoutes.fepAllowance}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FrontEndPlanningAllowanceScreen())),
      GoRoute(
          name: AppRoutes.fepMilestone,
          path: '/${AppRoutes.fepMilestone}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FrontEndPlanningMilestoneScreen())),
      GoRoute(
          name: AppRoutes.fepOpportunities,
          path: '/${AppRoutes.fepOpportunities}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FrontEndPlanningOpportunitiesScreen())),
      GoRoute(
          name: AppRoutes.fepSummary,
          path: '/${AppRoutes.fepSummary}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FrontEndPlanningSummaryScreen())),
      GoRoute(
          name: AppRoutes.fepSummaryEnd,
          path: '/${AppRoutes.fepSummaryEnd}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FrontEndPlanningSummaryEndScreen())),
      GoRoute(
          name: AppRoutes.fepSecurity,
          path: '/${AppRoutes.fepSecurity}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FrontEndPlanningSecurityScreen())),
      // Process cluster
      GoRoute(
          name: AppRoutes.projectPlan,
          path: '/${AppRoutes.projectPlan}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProjectPlanScreen())),
      GoRoute(
          name: AppRoutes.projectFramework,
          path: '/${AppRoutes.projectFramework}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProjectFrameworkScreen())),
      GoRoute(
          name: AppRoutes.projectFrameworkNext,
          path: '/${AppRoutes.projectFrameworkNext}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProjectFrameworkNextScreen())),
      GoRoute(
          name: AppRoutes.projectCharter,
          path: '/${AppRoutes.projectCharter}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProjectCharterScreen())),
      GoRoute(
        name: AppRoutes.projectDecisionSummary,
        path: '/${AppRoutes.projectDecisionSummary}',
        pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: _extraOr(s, ProjectDecisionSummaryScreen(
          projectName: 'Untitled Project',
          selectedSolution: AiSolutionItem(
              title: 'TBD Solution', description: 'Draft placeholder'),
          allSolutions: const [],
          businessCase: '',
          notes: '',
        ))),
      ),
      GoRoute(
          name: AppRoutes.progressTracking,
          path: '/${AppRoutes.progressTracking}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProgressTrackingScreen())),
      GoRoute(
          name: AppRoutes.wbs,
          path: '/${AppRoutes.wbs}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const WBSModuleScreen())),
      GoRoute(
          name: AppRoutes.pbs,
          path: '/${AppRoutes.pbs}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const PBSModuleScreen())),
      GoRoute(
          name: AppRoutes.executionPlan,
          path: '/${AppRoutes.executionPlan}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionPlanScreen())),
      GoRoute(
          name: AppRoutes.executionWorkPackages,
          path: '/${AppRoutes.executionWorkPackages}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionWorkPackagesScreen())),
      GoRoute(
          name: AppRoutes.executionPlanInterface,
          path: '/${AppRoutes.executionPlanInterface}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionPlanInterfaceManagementOverviewScreen())),
      GoRoute(
          name: AppRoutes.costEstimate,
          path: '/${AppRoutes.costEstimate}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const CostEstimateModuleScreen())),
      GoRoute(
        name: AppRoutes.costAnalysis,
        path: '/${AppRoutes.costAnalysis}',
        pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: _extraOr(s, const CostAnalysisScreen(notes: '', solutions: []))),
      ),
      GoRoute(
          name: AppRoutes.potentialSolutions,
          path: '/${AppRoutes.potentialSolutions}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const PotentialSolutionsScreen())),
      GoRoute(
        name: AppRoutes.preferredSolutionAnalysis,
        path: '/${AppRoutes.preferredSolutionAnalysis}',
        pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: _extraOr(s, const PreferredSolutionAnalysisScreen(
            notes: '', solutions: [], businessCase: ''))),
      ),
      GoRoute(
          name: AppRoutes.riskAssessment,
          path: '/${AppRoutes.riskAssessment}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const RiskAssessmentScreen())),
      GoRoute(
        name: AppRoutes.riskIdentification,
        path: '/${AppRoutes.riskIdentification}',
        pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: _extraOr(s, const RiskIdentificationScreen(notes: '', solutions: []))),
      ),
      GoRoute(
          name: AppRoutes.issueManagement,
          path: '/${AppRoutes.issueManagement}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const IssueManagementScreen())),
      GoRoute(
          name: AppRoutes.changeManagement,
          path: '/${AppRoutes.changeManagement}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ChangeManagementModuleScreen())),
      GoRoute(
          name: AppRoutes.schedule,
          path: '/${AppRoutes.schedule}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ScheduleModuleScreen())),
      GoRoute(
          name: AppRoutes.contractDetails,
          path: '/${AppRoutes.contractDetails}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ContractDetailsDashboardScreen())),
      GoRoute(
          name: AppRoutes.scheduleManagementBoard,
          path: '/${AppRoutes.scheduleManagementBoard}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ScheduleManagementBoardScreen())),
      GoRoute(
          name: AppRoutes.projectControls,
          path: '/${AppRoutes.projectControls}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProjectControlsScreen())),
      GoRoute(
          name: AppRoutes.integrationDashboard,
          path: '/${AppRoutes.integrationDashboard}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const IntegrationDashboardScreen())),
      GoRoute(
          name: AppRoutes.changeManagementModule,
          path: '/${AppRoutes.changeManagementModule}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ChangeManagementModuleScreen())),
      GoRoute(
          name: AppRoutes.landingPage,
          path: "/landing",
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const LandingScreen())),
      GoRoute(
          name: AppRoutes.careersPage,
          path: "/careers",
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const CareersPageScreen())),
      // Team cluster
      GoRoute(
          name: AppRoutes.teamManagement,
          path: '/${AppRoutes.teamManagement}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const TeamManagementScreen())),
      GoRoute(
          name: AppRoutes.teamMeetings,
          path: '/${AppRoutes.teamMeetings}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const TeamMeetingsScreen())),
      GoRoute(
          name: AppRoutes.teamRoles,
          path: '/${AppRoutes.teamRoles}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const TeamRolesResponsibilitiesScreen())),
      GoRoute(
          name: AppRoutes.teamTraining,
          path: '/${AppRoutes.teamTraining}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const TeamTrainingAndBuildingScreen())),
      GoRoute(
          name: AppRoutes.trainingTasks,
          path: '/${AppRoutes.trainingTasks}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const TrainingProjectTasksScreen())),
      GoRoute(
          name: AppRoutes.staffTeam,
          path: '/${AppRoutes.staffTeam}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const StaffTeamScreen())),
      GoRoute(
        name: AppRoutes.infrastructureConsiderations,
        path: '/${AppRoutes.infrastructureConsiderations}',
        pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: _extraOr(s, const InfrastructureConsiderationsScreen(notes: '', solutions: []))),
      ),
      GoRoute(
        name: AppRoutes.itConsiderations,
        path: '/${AppRoutes.itConsiderations}',
        pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: _extraOr(s, const ITConsiderationsScreen(notes: '', solutions: []))),
      ),
      GoRoute(
          name: AppRoutes.securityManagement,
          path: '/${AppRoutes.securityManagement}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const SecurityManagementScreen())),
      // Program basics
      GoRoute(
          name: AppRoutes.programBasics,
          path: '/${AppRoutes.programBasics}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProgramBasicsScreen())),
      GoRoute(
          name: AppRoutes.initiationPhase,
          path: '/${AppRoutes.initiationPhase}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const InitiationPhaseScreen())),
      GoRoute(
          name: AppRoutes.designPhase,
          path: '/${AppRoutes.designPhase}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const DesignPhaseScreen())),
      GoRoute(
          name: AppRoutes.requirementsImplementation,
          path: '/${AppRoutes.requirementsImplementation}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const RequirementsImplementationScreen())),
      GoRoute(
          name: AppRoutes.deliverablesRoadmap,
          path: '/${AppRoutes.deliverablesRoadmap}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const DeliverablesRoadmapScreen())),
      GoRoute(
          name: AppRoutes.deliverProjectClosure,
          path: '/${AppRoutes.deliverProjectClosure}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const DeliverProjectClosureScreen())),
      GoRoute(
          name: AppRoutes.transitionToProdTeam,
          path: '/${AppRoutes.transitionToProdTeam}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const TransitionToProdTeamScreen())),
      GoRoute(
          name: AppRoutes.contractCloseOut,
          path: '/${AppRoutes.contractCloseOut}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ContractCloseOutScreen())),
      GoRoute(
          name: AppRoutes.vendorAccountCloseOut,
          path: '/${AppRoutes.vendorAccountCloseOut}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const VendorAccountCloseOutScreen())),
      GoRoute(
          name: AppRoutes.uiUxDesign,
          path: '/${AppRoutes.uiUxDesign}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const UiUxDesignScreen())),
      GoRoute(
          name: AppRoutes.developmentSetUp,
          path: '/${AppRoutes.developmentSetUp}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const DevelopmentSetUpScreen())),
      GoRoute(
          name: AppRoutes.technicalAlignment,
          path: '/${AppRoutes.technicalAlignment}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const TechnicalAlignmentScreen())),
      GoRoute(
          name: AppRoutes.backendDesign,
          path: '/${AppRoutes.backendDesign}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const BackendDesignScreen())),
      GoRoute(
          name: AppRoutes.longLeadEquipmentOrdering,
          path: '/${AppRoutes.longLeadEquipmentOrdering}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const LongLeadEquipmentOrderingScreen())),
      GoRoute(
          name: AppRoutes.projectCloseOut,
          path: '/${AppRoutes.projectCloseOut}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: _extraOr(s, const ProjectCloseOutScreen()))),
      GoRoute(
          name: AppRoutes.demobilizeTeam,
          path: '/${AppRoutes.demobilizeTeam}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const DemobilizeTeamScreen())),
      GoRoute(
          name: AppRoutes.fatMechanicalCompletion,
          path: '/${AppRoutes.fatMechanicalCompletion}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FatMechanicalCompletionScreen())),
      GoRoute(
          name: AppRoutes.financialCloseout,
          path: '/${AppRoutes.financialCloseout}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FinancialCloseoutScreen())),
      GoRoute(
          name: AppRoutes.benefitsRealization,
          path: '/${AppRoutes.benefitsRealization}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const BenefitsRealizationScreen())),
      GoRoute(
          name: AppRoutes.technicalDevelopment,
          path: '/${AppRoutes.technicalDevelopment}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const TechnicalDevelopmentScreen())),
      GoRoute(
          name: AppRoutes.toolsIntegration,
          path: '/${AppRoutes.toolsIntegration}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ToolsIntegrationScreen())),
      GoRoute(
          name: AppRoutes.summarizeAccountRisks,
          path: '/${AppRoutes.summarizeAccountRisks}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const SummarizeAccountRisksScreen())),
      GoRoute(
          name: AppRoutes.agileDevelopmentIterations,
          path: '/${AppRoutes.agileDevelopmentIterations}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileDevelopmentIterationsScreen())),
      GoRoute(
          name: AppRoutes.engineeringDesign,
          path: '/${AppRoutes.engineeringDesign}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const EngineeringDesignScreen())),
      GoRoute(
          name: AppRoutes.scopeCompletion,
          path: '/${AppRoutes.scopeCompletion}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ScopeCompletionScreen())),
      GoRoute(
          name: AppRoutes.technicalDebtManagement,
          path: '/${AppRoutes.technicalDebtManagement}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const TechnicalDebtManagementScreen())),
      GoRoute(
          name: AppRoutes.riskTracking,
          path: '/${AppRoutes.riskTracking}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const RiskTrackingWorkspaceScreen())),
      GoRoute(
          name: AppRoutes.identifyStaffOpsTeam,
          path: '/${AppRoutes.identifyStaffOpsTeam}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const IdentifyStaffOpsTeamScreen())),
      GoRoute(
          name: AppRoutes.contractsTracking,
          path: '/${AppRoutes.contractsTracking}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ContractsTrackingScreen())),
      GoRoute(
          name: AppRoutes.vendorTracking,
          path: '/${AppRoutes.vendorTracking}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const VendorTrackingScreen())),
      GoRoute(
          name: AppRoutes.deliverableStatusUpdates,
          path: '/${AppRoutes.deliverableStatusUpdates}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const DeliverableStatusUpdatesScreen())),
      GoRoute(
          name: AppRoutes.recurringDeliverables,
          path: '/${AppRoutes.recurringDeliverables}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const RecurringDeliverablesScreen())),
      GoRoute(
          name: AppRoutes.statusReports,
          path: '/${AppRoutes.statusReports}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const StatusReportsScreen())),
      GoRoute(
          name: AppRoutes.detailedDesign,
          path: '/${AppRoutes.detailedDesign}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const DetailedDesignScreen())),
      GoRoute(
          name: AppRoutes.scopeTrackingImplementation,
          path: '/${AppRoutes.scopeTrackingImplementation}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ScopeTrackingImplementationScreen())),
      GoRoute(
          name: AppRoutes.stakeholderAlignment,
          path: '/${AppRoutes.stakeholderAlignment}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const StakeholderAlignmentScreen())),
      GoRoute(
          name: AppRoutes.updateOpsMaintenancePlans,
          path: '/${AppRoutes.updateOpsMaintenancePlans}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const UpdateOpsMaintenancePlansScreen())),
      GoRoute(
          name: AppRoutes.privacyPolicy,
          path: '/${AppRoutes.privacyPolicy}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const PrivacyPolicyScreen())),
      GoRoute(
          name: AppRoutes.termsConditions,
          path: '/${AppRoutes.termsConditions}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const TermsConditionsScreen())),
      // Workspace dashboards & remaining pages
      GoRoute(
          name: AppRoutes.regularProjectDashboard,
          path: '/${AppRoutes.regularProjectDashboard}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const RegularProjectDashboardScreen())),
      GoRoute(
          name: AppRoutes.projectCommandCenter,
          path: '/${AppRoutes.projectCommandCenter}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProjectCommandCenterScreen())),
      GoRoute(
          name: AppRoutes.programDashboardMobile,
          path: '/${AppRoutes.programDashboardMobile}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProgramDashboardMobileScreen())),
      GoRoute(
          name: AppRoutes.projectBaseline,
          path: '/${AppRoutes.projectBaseline}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProjectBaselineScreen())),
      GoRoute(
          name: AppRoutes.scheduleScreen,
          path: '/${AppRoutes.scheduleScreen}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ScheduleScreen())),
      GoRoute(
          name: AppRoutes.agileProjectHub,
          path: '/${AppRoutes.agileProjectHub}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileProjectHubScreen())),
      GoRoute(
          name: AppRoutes.agileReleasePlan,
          path: '/${AppRoutes.agileReleasePlan}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileReleasePlanScreen())),
      GoRoute(
          name: AppRoutes.teamStatusCheck,
          path: '/${AppRoutes.teamStatusCheck}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const TeamStatusCheckScreen())),
      GoRoute(
          name: AppRoutes.adminContent,
          path: '/${AppRoutes.adminContent}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AdminContentScreen())),
      GoRoute(
          name: AppRoutes.adminHints,
          path: '/${AppRoutes.adminHints}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AdminHintsScreen())),
      GoRoute(
          name: AppRoutes.adminDashboard,
          path: '/${AppRoutes.adminDashboard}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AdminDashboardScreen())),
      GoRoute(
          name: AppRoutes.userManagement,
          path: '/${AppRoutes.userManagement}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const UserManagementScreen())),
      GoRoute(
          name: AppRoutes.punchlistActions,
          path: '/${AppRoutes.punchlistActions}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const PunchlistActionsScreen())),
      GoRoute(
          name: AppRoutes.aiRecommendations,
          path: '/${AppRoutes.aiRecommendations}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AiRecommendationsScreen())),
      GoRoute(
          name: AppRoutes.technologyDefinitions,
          path: '/${AppRoutes.technologyDefinitions}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const TechnologyDefinitionsScreen())),
      GoRoute(
          name: AppRoutes.externalIntegrations,
          path: '/${AppRoutes.externalIntegrations}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExternalIntegrationsScreen())),
      GoRoute(
          name: AppRoutes.aiIntegrations,
          path: '/${AppRoutes.aiIntegrations}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AiIntegrationsScreen())),
      GoRoute(
          name: AppRoutes.qualityManagement,
          path: '/${AppRoutes.qualityManagement}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const QualityManagementScreen())),
      GoRoute(
          name: AppRoutes.safetyFullView,
          path: '/${AppRoutes.safetyFullView}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: _extraOr(s, const SafetyFullViewScreen(
              columns: [], initialRows: [], accentColor: Color(0xFF34A853), detailsText: '')))),
      GoRoute(
          name: AppRoutes.gapAnalysisScopeReconcillation,
          path: '/${AppRoutes.gapAnalysisScopeReconcillation}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const GapAnalysisScopeReconcillationScreen())),
      GoRoute(
          name: AppRoutes.projectWorkspaceDashboard,
          path: '/${AppRoutes.projectWorkspaceDashboard}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: _extraOr(s, const ProjectWorkspaceDashboardScreen(isBasicPlan: false)))),
      GoRoute(
          name: AppRoutes.groupIntoPortfolio,
          path: '/${AppRoutes.groupIntoPortfolio}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: _extraOr(s, const GroupIntoPortfolioScreen(projects: [])))),
      GoRoute(
          name: AppRoutes.actualVsPlannedGapAnalysis,
          path: '/${AppRoutes.actualVsPlannedGapAnalysis}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ActualVsPlannedGapAnalysisScreen())),
      GoRoute(
          name: AppRoutes.deliverablesRoadmapDetailed,
          path: '/${AppRoutes.deliverablesRoadmapDetailed}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const DeliverablesRoadmapDetailedScreen())),
      GoRoute(
          name: AppRoutes.executionEnablingWorkPlan,
          path: '/${AppRoutes.executionEnablingWorkPlan}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionEnablingWorkPlanScreen())),
      GoRoute(
          name: AppRoutes.executionPlanBestPractices,
          path: '/${AppRoutes.executionPlanBestPractices}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionPlanBestPracticesScreen())),
      GoRoute(
          name: AppRoutes.executionPlanLessonsLearned,
          path: '/${AppRoutes.executionPlanLessonsLearned}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionPlanLessonsLearnedScreen())),
      GoRoute(
          name: AppRoutes.executionPlanStakeholderIdentification,
          path: '/${AppRoutes.executionPlanStakeholderIdentification}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionPlanStakeholderIdentificationScreen())),
      GoRoute(
          name: AppRoutes.executionPlanCommunicationPlan,
          path: '/${AppRoutes.executionPlanCommunicationPlan}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionPlanCommunicationPlanScreen())),
      GoRoute(
          name: AppRoutes.executionPlanInfrastructurePlan,
          path: '/${AppRoutes.executionPlanInfrastructurePlan}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionPlanInfrastructurePlanScreen())),
      GoRoute(
          name: AppRoutes.executionPlanInterfaceManagementPlan,
          path: '/${AppRoutes.executionPlanInterfaceManagementPlan}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionPlanInterfaceManagementPlanScreen())),
      GoRoute(
          name: AppRoutes.executionPlanConstructionPlan,
          path: '/${AppRoutes.executionPlanConstructionPlan}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionPlanConstructionPlanScreen())),
      GoRoute(
          name: AppRoutes.executionPlanAgileDeliveryPlan,
          path: '/${AppRoutes.executionPlanAgileDeliveryPlan}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionPlanAgileDeliveryPlanScreen())),
      GoRoute(
          name: AppRoutes.executionPlanDetails,
          path: '/${AppRoutes.executionPlanDetails}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionPlanDetailsScreen())),
      GoRoute(
          name: AppRoutes.twoFactorVerification,
          path: '/${AppRoutes.twoFactorVerification}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: _extraOr(s, const TwoFactorVerificationScreen(email: '')))),
      GoRoute(
          name: AppRoutes.businessSystemIntegrations,
          path: '/${AppRoutes.businessSystemIntegrations}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: _extraOr(s, const BusinessSystemIntegrationsScreen(programId: '')))),
      GoRoute(
          name: AppRoutes.projectPlanLevel1Schedule,
          path: '/${AppRoutes.projectPlanLevel1Schedule}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProjectPlanLevel1ScheduleScreen())),
      GoRoute(
          name: AppRoutes.agileBacklogGovernance,
          path: '/${AppRoutes.agileBacklogGovernance}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileBacklogGovernanceScreen())),
      GoRoute(
          name: AppRoutes.agileSprintCalendar,
          path: '/${AppRoutes.agileSprintCalendar}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileSprintCalendarScreen())),
      GoRoute(
          name: AppRoutes.agileTeamStructure,
          path: '/${AppRoutes.agileTeamStructure}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileTeamStructureScreen())),
      GoRoute(
          name: AppRoutes.mfaEnrollment,
          path: '/${AppRoutes.mfaEnrollment}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const MfaEnrollmentScreen())),
      GoRoute(
          name: AppRoutes.recoveryCodes,
          path: '/${AppRoutes.recoveryCodes}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const RecoveryCodesScreen())),
      GoRoute(
          name: AppRoutes.projectActivitiesLog,
          path: '/${AppRoutes.projectActivitiesLog}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProjectActivitiesLogScreen())),
      GoRoute(
          name: AppRoutes.basicPlanDashboard,
          path: '/${AppRoutes.basicPlanDashboard}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const BasicPlanDashboardScreen())),
      GoRoute(
          name: AppRoutes.adminPricingConfig,
          path: '/${AppRoutes.adminPricingConfig}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AdminPricingConfigScreen())),
      GoRoute(
          name: AppRoutes.executionPlanInterfaceManagement,
          path: '/${AppRoutes.executionPlanInterfaceManagement}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionPlanInterfaceManagementScreen())),
      GoRoute(
          name: AppRoutes.projectPlanDetailedSchedule,
          path: '/${AppRoutes.projectPlanDetailedSchedule}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProjectPlanDetailedScheduleScreen())),
      GoRoute(
          name: AppRoutes.projectPlanCondensedSummary,
          path: '/${AppRoutes.projectPlanCondensedSummary}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProjectPlanCondensedSummaryScreen())),
      GoRoute(
          name: AppRoutes.agileDeliveryModel,
          path: '/${AppRoutes.agileDeliveryModel}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileDeliveryModelScreen())),
      GoRoute(
          name: AppRoutes.agileKanbanConfig,
          path: '/${AppRoutes.agileKanbanConfig}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileKanbanConfigScreen())),
      GoRoute(
          name: AppRoutes.agileAcceptanceCriteria,
          path: '/${AppRoutes.agileAcceptanceCriteria}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileAcceptanceCriteriaScreen())),
      GoRoute(
          name: AppRoutes.agileEpicsFeatures,
          path: '/${AppRoutes.agileEpicsFeatures}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileEpicsFeaturesScreen())),
      GoRoute(
          name: AppRoutes.agileScrumConfig,
          path: '/${AppRoutes.agileScrumConfig}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileScrumConfigScreen())),
      GoRoute(
          name: AppRoutes.agileCapacityPlanning,
          path: '/${AppRoutes.agileCapacityPlanning}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileCapacityPlanningScreen())),
      GoRoute(
          name: AppRoutes.agileMetricsPlanning,
          path: '/${AppRoutes.agileMetricsPlanning}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileMetricsPlanningScreen())),
      GoRoute(
          name: AppRoutes.deliverableRoadmapAgileMapOut,
          path: '/${AppRoutes.deliverableRoadmapAgileMapOut}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const DeliverableRoadmapAgileMapOutScreen())),
      GoRoute(
          name: AppRoutes.organizationRolesResponsibilities,
          path: '/${AppRoutes.organizationRolesResponsibilities}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const OrganizationRolesResponsibilitiesScreen())),
      GoRoute(
          name: AppRoutes.organizationRaciMatrix,
          path: '/${AppRoutes.organizationRaciMatrix}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const OrganizationRaciMatrixScreen())),
      GoRoute(
          name: AppRoutes.organizationStaffingPlan,
          path: '/${AppRoutes.organizationStaffingPlan}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const OrganizationStaffingPlanScreen())),
      GoRoute(
          name: AppRoutes.startupPlanningOperations,
          path: '/${AppRoutes.startupPlanningOperations}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const StartUpPlanningOperationsScreen())),
      GoRoute(
          name: AppRoutes.startupPlanningHypercare,
          path: '/${AppRoutes.startupPlanningHypercare}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const StartUpPlanningHypercareScreen())),
      GoRoute(
          name: AppRoutes.startupPlanningDevOps,
          path: '/${AppRoutes.startupPlanningDevOps}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const StartUpPlanningDevOpsScreen())),
      GoRoute(
          name: AppRoutes.startupPlanningCloseOutPlan,
          path: '/${AppRoutes.startupPlanningCloseOutPlan}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const StartUpPlanningCloseOutPlanScreen())),
      GoRoute(
          name: AppRoutes.startupPlanning,
          path: '/${AppRoutes.startupPlanning}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const StartUpPlanningScreen())),
      GoRoute(
          name: AppRoutes.interfaceManagement,
          path: '/${AppRoutes.interfaceManagement}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const InterfaceManagementScreen())),
      GoRoute(
          name: AppRoutes.planningRequirements,
          path: '/${AppRoutes.planningRequirements}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const PlanningRequirementsScreen())),
      GoRoute(
          name: AppRoutes.designDeliverables,
          path: '/${AppRoutes.designDeliverables}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const DesignDeliverablesScreen())),
      GoRoute(
          name: AppRoutes.designPlanning,
          path: '/${AppRoutes.designPlanning}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const DesignPlanningScreen())),
      GoRoute(
          name: AppRoutes.partner,
          path: '/${AppRoutes.partner}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const PartnerScreen())),
      GoRoute(
          name: AppRoutes.howItWorks,
          path: '/${AppRoutes.howItWorks}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const HowItWorksScreen())),
      GoRoute(
          name: AppRoutes.useCases,
          path: '/${AppRoutes.useCases}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const UseCasesScreen())),
      GoRoute(
          name: AppRoutes.landingPageScreen,
          path: '/${AppRoutes.landingPageScreen}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const LandingPageScreen())),
      GoRoute(
          name: AppRoutes.projectDetails,
          path: '/${AppRoutes.projectDetails}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProjectDetailsScreen())),
      GoRoute(
          name: AppRoutes.executionPlanSolutions,
          path: '/${AppRoutes.executionPlanSolutions}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionPlanSolutionsScreen())),
      GoRoute(
          name: AppRoutes.executionIssueManagement,
          path: '/${AppRoutes.executionIssueManagement}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ExecutionIssueManagementScreen())),
      GoRoute(
          name: AppRoutes.finalizeProject,
          path: '/${AppRoutes.finalizeProject}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const FinalizeProjectScreen())),
      GoRoute(
          name: AppRoutes.commerceViability,
          path: '/${AppRoutes.commerceViability}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const CommerceViabilityScreen())),
      GoRoute(
          name: AppRoutes.teamHandover,
          path: '/${AppRoutes.teamHandover}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const TeamHandoverScreen())),
      GoRoute(
          name: AppRoutes.scopeTrackingPlan,
          path: '/${AppRoutes.scopeTrackingPlan}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ScopeTrackingPlanScreen())),
      GoRoute(
          name: AppRoutes.salvageDisposalTeam,
          path: '/${AppRoutes.salvageDisposalTeam}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const SalvageDisposalTeamScreen())),
      GoRoute(
          name: AppRoutes.riskTrackingScreen,
          path: '/${AppRoutes.riskTrackingScreen}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const RiskTrackingScreen())),
      GoRoute(
          name: AppRoutes.recognitionAwards,
          path: '/${AppRoutes.recognitionAwards}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const RecognitionAwardsScreen())),
      GoRoute(
          name: AppRoutes.agileSprintReviews,
          path: '/${AppRoutes.agileSprintReviews}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileSprintReviewsScreen())),
      GoRoute(
          name: AppRoutes.agileRetrospectives,
          path: '/${AppRoutes.agileRetrospectives}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileRetrospectivesScreen())),
      GoRoute(
          name: AppRoutes.agileRoadmap,
          path: '/${AppRoutes.agileRoadmap}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileRoadmapScreen())),
      GoRoute(
          name: AppRoutes.agileDailyStandups,
          path: '/${AppRoutes.agileDailyStandups}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileDailyStandupsScreen())),
      GoRoute(
          name: AppRoutes.agileIterationManagement,
          path: '/${AppRoutes.agileIterationManagement}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileIterationManagementScreen())),
      GoRoute(
          name: AppRoutes.agileRisks,
          path: '/${AppRoutes.agileRisks}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileRisksScreen())),
      GoRoute(
          name: AppRoutes.agileMetrics,
          path: '/${AppRoutes.agileMetrics}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileMetricsScreen())),
      GoRoute(
          name: AppRoutes.agileKanbanBoard,
          path: '/${AppRoutes.agileKanbanBoard}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileKanbanBoardScreen())),
      GoRoute(
          name: AppRoutes.agileAiCoach,
          path: '/${AppRoutes.agileAiCoach}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileAiCoachScreen())),
      GoRoute(
          name: AppRoutes.agileDashboard,
          path: '/${AppRoutes.agileDashboard}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileDashboardScreen())),
      GoRoute(
          name: AppRoutes.agileProjectBaseline,
          path: '/${AppRoutes.agileProjectBaseline}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AgileProjectBaselineScreen())),
      GoRoute(
          name: AppRoutes.documentReviewMatrix,
          path: '/${AppRoutes.documentReviewMatrix}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const DocumentReviewMatrixScreen())),
      GoRoute(
          name: AppRoutes.specializedDesign,
          path: '/${AppRoutes.specializedDesign}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const SpecializedDesignScreen())),
      GoRoute(
          name: AppRoutes.createContract,
          path: '/${AppRoutes.createContract}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: _extraOr(s, const CreateContractScreen()))),
      GoRoute(
          name: AppRoutes.planningProcurement,
          path: '/${AppRoutes.planningProcurement}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const PlanningProcurementV2Screen())),
      GoRoute(
          name: AppRoutes.projectTeamActivities,
          path: '/${AppRoutes.projectTeamActivities}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const ProjectTeamActivitiesScreen())),
      GoRoute(
          name: AppRoutes.technologyInventory,
          path: '/${AppRoutes.technologyInventory}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const TechnologyInventoryScreen())),
      GoRoute(
          name: AppRoutes.costEstimateScreen,
          path: '/${AppRoutes.costEstimateScreen}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const CostEstimateScreen())),
      // SSHER suite
      GoRoute(
          name: AppRoutes.ssherStacked,
          path: '/${AppRoutes.ssherStacked}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const SsherStackedScreen())),
      GoRoute(
          name: AppRoutes.ssher1,
          path: '/${AppRoutes.ssher1}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const SsherScreen1())),
      GoRoute(
          name: AppRoutes.ssher2,
          path: '/${AppRoutes.ssher2}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const SsherScreen2())),
      GoRoute(
          name: AppRoutes.ssher3,
          path: '/${AppRoutes.ssher3}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const SsherScreen3())),
      GoRoute(
          name: AppRoutes.ssher4,
          path: '/${AppRoutes.ssher4}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const SsherScreen4())),
      // SafetyFullViewScreen requires constructor data; reachable via the SSHER flow, not direct URL
    ],
    errorBuilder: (context, state) {
      return _RouteNotFound(path: state.uri.toString());
    },
  ));

  // Admin router: used by lib/main_admin.dart
  static final GoRouter admin = _guardedRouter('admin', () => GoRouter(
    debugLogDiagnostics: kDebugMode,
    initialLocation: '/',
    redirect: (context, state) {
      User? user;
      try {
        user = FirebaseAuth.instance.currentUser;
      } catch (_) {}
      final currentPath = state.uri.path;

      // On admin domain, handle routing specially
      if (AccessPolicy.isRestrictedAdminHost()) {
        // Redirect /landing to appropriate page (it doesn't exist in admin router)
        if (currentPath == '/${AppRoutes.landing}' ||
            currentPath == '/landing') {
          final email = user?.email;
          if (email != null && email.isNotEmpty) {
            return '/${AppRoutes.adminHome}';
          }
          return '/${AppRoutes.signIn}';
        }

        // If user is authenticated (has email), allow access
        final email = user?.email;
        if (email != null && email.isNotEmpty) {
          // If on root path and authenticated, redirect to admin home
          if (currentPath == '/' || currentPath.isEmpty) {
            return '/${AppRoutes.adminHome}';
          }
          // Allow access to other routes
          return null;
        }

        // If not authenticated, redirect to sign-in (unless already on sign-in)
        if (currentPath != '/${AppRoutes.signIn}' &&
            currentPath != '/sign-in') {
          return '/${AppRoutes.signIn}';
        }
        return null;
      }

      // For non-admin domains, use the standard guard
      final block = _adminHostGuard(user);
      if (block != null) return block;

      // Default: if authenticated and on root, go to admin home
      if (user != null && (currentPath == '/' || currentPath.isEmpty)) {
        return '/${AppRoutes.adminHome}';
      }

      return null;
    },
    routes: [
      // Root path - will be handled by redirect function above
      GoRoute(
        path: '/',
        pageBuilder: (c, s) {
          // This should never be reached due to redirect, but provide fallback
          User? user;
          try {
            user = FirebaseAuth.instance.currentUser;
          } catch (_) {}
          if (user?.email != null && user!.email!.isNotEmpty) {
            return shimmerTransitionPage(state: s, child: const AdminAuthWrapper(child: AdminHomeScreen()));
          }
          return shimmerTransitionPage(state: s, child: const SignInScreen());
        },
      ),
      GoRoute(
          name: AppRoutes.signIn,
          path: '/${AppRoutes.signIn}',
          pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const SignInScreen())),
      GoRoute(
        name: AppRoutes.adminHome,
        path: '/${AppRoutes.adminHome}',
        pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AdminAuthWrapper(child: AdminHomeScreen())),
      ),
      GoRoute(
        name: AppRoutes.adminProjects,
        path: '/${AppRoutes.adminProjects}',
        pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AdminAuthWrapper(child: AdminProjectsScreen())),
      ),
      GoRoute(
        name: AppRoutes.adminUsers,
        path: '/${AppRoutes.adminUsers}',
        pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AdminAuthWrapper(child: AdminUsersScreen())),
      ),
      GoRoute(
        name: AppRoutes.adminCoupons,
        path: '/${AppRoutes.adminCoupons}',
        pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AdminAuthWrapper(child: AdminCouponsScreen())),
      ),
      GoRoute(
        name: AppRoutes.adminSubscriptionLookup,
        path: '/${AppRoutes.adminSubscriptionLookup}',
        pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AdminAuthWrapper(child: AdminSubscriptionLookupScreen())),
      ),
      GoRoute(
        name: AppRoutes.adminSurveyResponses,
        path: '/${AppRoutes.adminSurveyResponses}',
        pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AdminAuthWrapper(child: AdminSurveyResponsesScreen())),
      ),
      GoRoute(
        name: AppRoutes.settings,
        path: '/${AppRoutes.settings}',
        pageBuilder: (c, s) => shimmerTransitionPage(state: s, child: const AdminAuthWrapper(child: SettingsScreen())),
      ),
    ],
    errorBuilder: (context, state) =>
        _RouteNotFound(path: state.uri.toString()),
  ));

  // ── Helpers for the activity auto-logger ──────────────────────────────────

  /// Returns the most-recently-known project ID for the current user, or
  /// an empty string if none is known. Used by the redirect callback to
  /// attribute page visits to a project.
  static String _activeProjectIdForUser(String userId) {
    // ProjectDataProvider.lastKnownProjectId is updated whenever a project
    // is loaded or saved. It's a process-wide static — good enough for
    // single-user-at-a-time apps.
    return ProjectDataProvider.lastKnownProjectId ?? '';
  }

  /// Maps a route path to a human-readable (pageTitle, phase) tuple, or
  /// null if the route isn't a project page worth logging.
  static (String, String)? _describeRoute(String location) {
    // Strip query string
    final path = location.split('?').first;

    // Dashboard / portfolio / program dashboards
    if (path == '/dashboard') return ('Project Dashboard', 'Initiation');
    if (path == '/program-dashboard') return ('Program Dashboard', 'Program');
    if (path == '/portfolio-dashboard') return ('Portfolio Dashboard', 'Portfolio');
    if (path == '/regular-project-dashboard') return ('Regular Projects', 'Project');
    if (path == '/project-command-center') return ('Project Command Center', 'Project');
    if (path == '/program-dashboard-mobile') return ('Program Dashboard', 'Program');

    // Design phase routes
    if (path.contains('design')) return ('Design Phase', 'Design');
    if (path.contains('engineering')) return ('Engineering Design', 'Design');
    if (path.contains('ui-ux')) return ('UI/UX Design', 'Design');
    if (path.contains('backend')) return ('Backend Design', 'Design');

    // Execution phase routes
    if (path.contains('execution')) return ('Execution Plan', 'Execution');
    if (path.contains('execution-work-packages')) return ('Execution Work Packages', 'Execution');
    if (path.contains('agile')) return ('Agile Delivery', 'Execution');
    if (path.contains('sprint')) return ('Sprint Planning', 'Execution');
    if (path.contains('work-breakdown')) return ('Work Breakdown Structure', 'Execution');

    // FEP / planning routes
    if (path.contains('front-end-planning') || path.contains('fep')) {
      return ('Front-End Planning', 'Planning');
    }
    if (path.contains('project-plan')) return ('Project Plan', 'Planning');
    if (path.contains('project-framework')) return ('Project Framework', 'Planning');
    if (path.contains('project-charter')) return ('Project Charter', 'Planning');

    // Cost / procurement / contracts
    if (path.contains('cost')) return ('Cost Analysis', 'Planning');
    if (path.contains('procurement')) return ('Procurement', 'Planning');
    if (path.contains('contract')) return ('Contracts', 'Planning');

    // Risk / SSHER
    if (path.contains('risk')) return ('Risk Assessment', 'Planning');
    if (path.contains('ssher')) return ('SSHER', 'Planning');

    // Activities log itself — don't log a visit to the log page
    if (path.contains('activities-log') || path.contains('activity-log')) {
      return null;
    }

    // Settings / admin — group as 'Admin'
    if (path.contains('settings')) return ('Settings', 'Admin');
    if (path.startsWith('/admin')) return ('Admin', 'Admin');

    // Generic fallback — still log so nothing is missed
    final seg = path.split('/').where((s) => s.isNotEmpty).lastOrNull ?? 'Page';
    return (_titleCase(seg), 'Project');
  }

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s.split('-').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }
}

/// Resolves a screen instance passed through GoRouter `extra`, falling back
/// to [fallback] when the route was opened as a bare deep link (e.g. after a
/// browser refresh, where `extra` is not preserved).
T _extraOr<T>(GoRouterState state, T fallback) {
  final extra = state.extra;
  return extra is T ? extra : fallback;
}

class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound({required this.path});
  final String path;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isAdminDomain = AccessPolicy.isRestrictedAdminHost();
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      // Firebase not yet initialized or unavailable
    }
    final hasEmail = user?.email != null && user!.email!.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        top: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.travel_explore,
                          color: t.colorScheme.primary, size: 32),
                      const SizedBox(width: 12),
                      Text('Page not found', style: t.textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'We couldn\'t find "$path". Check the URL or use navigation.',
                      style: t.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      if (isAdminDomain) {
                        if (hasEmail) {
                          context.go('/${AppRoutes.adminHome}');
                        } else {
                          context.go('/${AppRoutes.signIn}');
                        }
                      } else {
                        context.go('/${AppRoutes.dashboard}');
                      }
                    },
                    icon: const Icon(Icons.dashboard),
                    label: const Text('Go to dashboard'),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
