import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/design_phase_models.dart';
import 'package:ndu_project/models/project_activity.dart';
import 'package:ndu_project/models/staffing_row.dart';
import 'package:ndu_project/models/control_account_model.dart';
import 'package:ndu_project/models/obs_element_model.dart';
import 'package:ndu_project/models/cbs_element_model.dart';

/// Comprehensive project data model that captures all information across the application flow
class ProjectDataModel {
  // Initiation Phase Data
  String projectName;
  String solutionTitle;
  String solutionDescription;
  String businessCase;
  String notes;

  // --- Legacy / Alias Getters ---
  String get projectDescription => solutionDescription;
  set projectDescription(String val) => solutionDescription = val;

  FrontEndPlanningData get frontEndPlanningData => frontEndPlanning;
  set frontEndPlanningData(FrontEndPlanningData val) => frontEndPlanning = val;

  String get technology {
    if (technologyDefinitions.isEmpty) return 'Not specified';
    return technologyDefinitions.map((e) => e['name'] ?? '').join(', ');
  }

  // --- Structured Planning Fields ---
  List<PlanningDashboardItem> withinScopeItems;
  List<PlanningDashboardItem> outOfScopeItems;
  List<PlanningDashboardItem> assumptionItems;
  List<PlanningDashboardItem> constraintItems;

  // --- Legacy Getters (Backward Compatibility) ---
  List<String> get withinScope =>
      withinScopeItems.map((e) => e.description).toList();
  set withinScope(List<String> val) {
    withinScopeItems =
        val.map((e) => PlanningDashboardItem(description: e)).toList();
  }

  List<String> get outOfScope =>
      outOfScopeItems.map((e) => e.description).toList();
  set outOfScope(List<String> val) {
    outOfScopeItems =
        val.map((e) => PlanningDashboardItem(description: e)).toList();
  }

  List<String> get assumptions =>
      assumptionItems.map((e) => e.description).toList();
  set assumptions(List<String> val) {
    assumptionItems =
        val.map((e) => PlanningDashboardItem(description: e)).toList();
  }

  List<String> get constraints =>
      constraintItems.map((e) => e.description).toList();
  set constraints(List<String> val) {
    constraintItems =
        val.map((e) => PlanningDashboardItem(description: e)).toList();
  }

  List<String> opportunities;
  List<ProjectActivity> projectActivities;
  List<ProjectActivity> customProjectActivities;
  List<String> hiddenProjectActivityIds;

  // Project Charter (editable in Project Charter screen)
  String charterAssumptions;
  String charterConstraints;
  String charterProjectManagerName;
  String charterProjectSponsorName;
  String charterReviewedBy; // Added
  DateTime? charterApprovalDate; // Added
  String charterEmail;
  String charterPhone;
  String charterOrganizationalUnit;
  String charterGreenBelt;
  String charterBlackBelt;
  List<String> tags;
  List<Contractor> contractors; // Added
  List<Vendor> vendors; // Added
  List<PotentialSolution> potentialSolutions;
  List<SolutionRisk> solutionRisks;
  PreferredSolutionAnalysis? preferredSolutionAnalysis;

  // Project Framework Data
  String? overallFramework;
  List<ProjectGoal> projectGoals;

  // Planning Phase Data
  String potentialSolution;
  String projectObjective;
  List<PlanningGoal> planningGoals;
  List<Milestone> keyMilestones;
  Map<String, String> planningNotes;
  Map<String, String> riskMitigationPlans;
  List<ExecutionRiskItem> executionRiskItems;
  List<ExecutionRiskSignal> executionRiskSignals;
  List<ExecutionRiskMitigation> executionRiskMitigations;
  List<InterfaceEntry> interfaceEntries;
  List<InterfaceChangeLogEntry> interfaceChangeLog;
  List<ScheduleActivity> scheduleActivities;
  List<ScheduleActivity> scheduleBaselineActivities;
  String scheduleBaselineDate;
  // Work Packages
  List<WorkPackage> workPackages;
  // Planning Requirements Data
  List<PlanningRequirementItem> planningRequirementItems;
  String planningRequirementsNotes;

  // Work Breakdown Structure Data
  String? wbsCriteriaA;
  String? wbsCriteriaB;
  List<List<WorkItem>> goalWorkItems;
  List<WorkItem> wbsTree;

  // Issue Management Data
  List<IssueLogItem> issueLogItems;
  // Lessons learned
  List<LessonRecord> lessonsLearned;

  // Front End Planning Data
  FrontEndPlanningData frontEndPlanning;
  // Technology/IT Data
  List<Map<String, dynamic>> technologyDefinitions;
  List<Map<String, dynamic>> technologyInventory;

  // SSHER Data
  SSHERData ssherData;

  // Team Management Data
  List<TeamMember> teamMembers;

  // Launch Checklist Data
  List<LaunchChecklistItem> launchChecklistItems;

  // Cost Analysis Data
  CostAnalysisData? costAnalysisData;

  // Cost Estimate Data
  List<CostEstimateItem> costEstimateItems;
  double managementReserve;

  // IT Considerations Data
  ITConsiderationsData? itConsiderationsData;

  // Infrastructure Considerations Data
  InfrastructureConsiderationsData? infrastructureConsiderationsData;

  // Core Stakeholders Data
  CoreStakeholdersData? coreStakeholdersData;

  // Organisation Plan Data
  List<RoleDefinition> projectRoles;
  List<RaciMatrixRow> raciMatrixRows;
  List<StaffingRequirement> staffingRequirements;
  List<InfrastructurePlanningItem> planningInfrastructureItems;
  List<TrainingActivity> trainingActivities;

  // Design Deliverables Data
  DesignDeliverablesData designDeliverablesData;

  // Design Management Data
  DesignManagementData? designManagementData;

  // Execution Phase Data
  ExecutionPhaseData? executionPhaseData;

  // Monitoring & Controls Data
  MonitoringControlsData? monitoringControls;

  // Launch Phase Data
  LaunchPhaseData? launchPhaseData;

  // Stakeholder Management Data
  List<StakeholderEntry> stakeholderEntries;
  List<EngagementPlanEntry> engagementPlanEntries;

  // Quality Management Data
  QualityManagementData? qualityManagementData;

  // Control Accounts
  List<ControlAccount> controlAccounts;

  // OBS and CBS
  List<ObsElement> obsElements;
  List<CbsElement> cbsElements;

  // ── P2.5: Project-level EVM aggregate fields ──
  /// Aggregate Budget at Completion (sum of all control account BACs).
  double aggregateBac;

  /// Aggregate Planned Value to date.
  double aggregatePlannedValue;

  /// Aggregate Earned Value.
  double aggregateEarnedValue;

  /// Aggregate Actual Cost.
  double aggregateActualCost;

  /// Aggregate CPI (Cost Performance Index).
  double aggregateCpi;

  /// Aggregate SPI (Schedule Performance Index).
  double aggregateSpi;

  /// Aggregate EAC (Estimate at Completion).
  double aggregateEac;

  /// Aggregate ETC (Estimate to Complete).
  double aggregateEtc;

  /// Aggregate VAC (Variance at Completion).
  double aggregateVac;

  /// Aggregate CV (Cost Variance).
  double aggregateCv;

  /// Aggregate SV (Schedule Variance).
  double aggregateSv;

  /// Aggregate TCPI (To-Complete Performance Index).
  double aggregateTcpi;

  /// Last time project-level EVM was recalculated.
  DateTime? evmLastRecalculated;

  // Metadata
  bool isBasicPlanProject;
  Map<String, int> aiUsageCounts;

  List<Map<String, dynamic>> aiIntegrations;
  List<Map<String, dynamic>> externalIntegrations;
  List<Map<String, dynamic>> aiRecommendations;
  String? projectId;
  DateTime? createdAt;
  DateTime? updatedAt;
  String currentCheckpoint;

  // Field History Tracking for Undo functionality
  Map<String, FieldHistory> fieldHistories;

  // Currency setting for Cost-Benefit Analysis
  String costBenefitCurrency;

  // Preferred Solution Reference
  String? preferredSolutionId;

  ProjectDataModel({
    this.projectName = '',
    this.solutionTitle = '',
    this.solutionDescription = '',
    this.businessCase = '',
    this.notes = '',
    this.charterAssumptions = '',
    this.charterConstraints = '',
    this.charterProjectManagerName = '',
    this.charterProjectSponsorName = '',
    this.charterReviewedBy = '',
    this.charterApprovalDate,
    this.designManagementData,
    this.charterEmail = '',
    this.charterPhone = '',
    this.charterOrganizationalUnit = '',
    this.charterGreenBelt = '',
    this.charterBlackBelt = '',
    this.tags = const [],
    List<Contractor>? contractors,
    List<Vendor>? vendors,
    List<PotentialSolution>? potentialSolutions,
    List<SolutionRisk>? solutionRisks,
    this.preferredSolutionAnalysis,
    this.overallFramework,
    List<ProjectGoal>? projectGoals,
    this.potentialSolution = '',
    this.projectObjective = '',
    List<PlanningGoal>? planningGoals,
    List<Milestone>? keyMilestones,
    Map<String, String>? planningNotes,
    Map<String, String>? riskMitigationPlans,
    List<ExecutionRiskItem>? executionRiskItems,
    List<ExecutionRiskSignal>? executionRiskSignals,
    List<ExecutionRiskMitigation>? executionRiskMitigations,
    List<InterfaceEntry>? interfaceEntries,
    List<InterfaceChangeLogEntry>? interfaceChangeLog,
    List<ScheduleActivity>? scheduleActivities,
    List<ScheduleActivity>? scheduleBaselineActivities,
    String? scheduleBaselineDate,
    List<PlanningRequirementItem>? planningRequirementItems,
    this.planningRequirementsNotes = '',
    this.wbsCriteriaA,
    this.wbsCriteriaB,
    List<String>? assumptions,
    List<String>? constraints,
    List<String>? withinScope,
    List<String>? outOfScope,
    List<String>? opportunities,
    List<List<WorkItem>>? goalWorkItems,
    List<WorkItem>? wbsTree,
    List<ProjectActivity>? projectActivities,
    List<ProjectActivity>? customProjectActivities,
    List<String>? hiddenProjectActivityIds,
    List<IssueLogItem>? issueLogItems,
    List<LessonRecord>? lessonsLearned,
    List<Map<String, dynamic>>? technologyDefinitions,
    List<Map<String, dynamic>>? technologyInventory,
    FrontEndPlanningData? frontEndPlanning,
    SSHERData? ssherData,
    List<TeamMember>? teamMembers,
    List<LaunchChecklistItem>? launchChecklistItems,
    this.costAnalysisData,
    List<CostEstimateItem>? costEstimateItems,
    this.managementReserve = 0.0,
    List<WorkPackage>? workPackages,
    this.itConsiderationsData,
    this.infrastructureConsiderationsData,
    this.coreStakeholdersData,
    List<RoleDefinition>? projectRoles,
    List<RaciMatrixRow>? raciMatrixRows,
    List<StaffingRequirement>? staffingRequirements,
    List<InfrastructurePlanningItem>? planningInfrastructureItems,
    List<TrainingActivity>? trainingActivities,
    DesignDeliverablesData? designDeliverablesData,
    this.isBasicPlanProject = false,
    Map<String, int>? aiUsageCounts,
    List<Map<String, dynamic>>? aiIntegrations,
    List<Map<String, dynamic>>? externalIntegrations,
    List<Map<String, dynamic>>? aiRecommendations,
    List<StakeholderEntry>? stakeholderEntries,
    List<EngagementPlanEntry>? engagementPlanEntries,
    this.qualityManagementData,
    this.executionPhaseData,
    this.projectId,
    this.createdAt,
    this.updatedAt,
    this.currentCheckpoint = 'initiation',
    Map<String, FieldHistory>? fieldHistories,
    this.monitoringControls,
    this.launchPhaseData,
    String? costBenefitCurrency,
    this.preferredSolutionId,
    List<PlanningDashboardItem>? withinScopeItems,
    List<PlanningDashboardItem>? outOfScopeItems,
    List<PlanningDashboardItem>? assumptionItems,
    List<PlanningDashboardItem>? constraintItems,
    List<ControlAccount>? controlAccounts,
    List<ObsElement>? obsElements,
    List<CbsElement>? cbsElements,
    this.aggregateBac = 0,
    this.aggregatePlannedValue = 0,
    this.aggregateEarnedValue = 0,
    this.aggregateActualCost = 0,
    this.aggregateCpi = 1.0,
    this.aggregateSpi = 1.0,
    this.aggregateEac = 0,
    this.aggregateEtc = 0,
    this.aggregateVac = 0,
    this.aggregateCv = 0,
    this.aggregateSv = 0,
    this.aggregateTcpi = 0,
    this.evmLastRecalculated,
  })  : potentialSolutions = potentialSolutions ?? [],
        solutionRisks = solutionRisks ?? [],
        contractors = contractors ?? [],
        vendors = vendors ?? [],
        projectGoals = projectGoals ?? [],
        opportunities = opportunities ?? [],
        planningGoals = planningGoals ??
            List.generate(3, (i) => PlanningGoal(goalNumber: i + 1)),
        keyMilestones = keyMilestones ?? [],
        planningNotes = planningNotes ?? {},
        riskMitigationPlans = riskMitigationPlans ?? {},
        executionRiskItems = executionRiskItems ?? [],
        executionRiskSignals = executionRiskSignals ?? [],
        executionRiskMitigations = executionRiskMitigations ?? [],
        interfaceEntries = interfaceEntries ?? [],
        interfaceChangeLog = interfaceChangeLog ?? [],
        scheduleActivities = scheduleActivities ?? [],
        scheduleBaselineActivities = scheduleBaselineActivities ?? [],
        scheduleBaselineDate = scheduleBaselineDate ?? '',
        planningRequirementItems = planningRequirementItems ?? [],
        goalWorkItems = goalWorkItems ?? List.generate(3, (_) => []),
        wbsTree = wbsTree ?? [],
        projectActivities = projectActivities ?? [],
        customProjectActivities = customProjectActivities ?? [],
        hiddenProjectActivityIds = hiddenProjectActivityIds ?? [],
        issueLogItems = issueLogItems ?? [],
        lessonsLearned = lessonsLearned ?? [],
        technologyDefinitions = technologyDefinitions ?? [],
        technologyInventory = technologyInventory ?? [],
        frontEndPlanning = frontEndPlanning ?? FrontEndPlanningData(),
        ssherData = ssherData ?? SSHERData(),
        teamMembers = teamMembers ?? [],
        launchChecklistItems = launchChecklistItems ?? [],
        costEstimateItems = costEstimateItems ?? [],
        workPackages = workPackages ?? [],
        controlAccounts = controlAccounts ?? [],
        obsElements = obsElements ?? [],
        cbsElements = cbsElements ?? [],
        designDeliverablesData =
            designDeliverablesData ?? DesignDeliverablesData(),
        projectRoles = projectRoles ?? [],
        raciMatrixRows = raciMatrixRows ?? [],
        staffingRequirements = staffingRequirements ?? [],
        planningInfrastructureItems = planningInfrastructureItems ?? [],
        trainingActivities = trainingActivities ?? [],
        aiUsageCounts = aiUsageCounts ?? {},
        aiIntegrations = aiIntegrations ?? [],
        externalIntegrations = externalIntegrations ?? [],
        aiRecommendations = aiRecommendations ?? [],
        stakeholderEntries = stakeholderEntries ?? [],
        engagementPlanEntries = engagementPlanEntries ?? [],
        fieldHistories = fieldHistories ?? {},
        costBenefitCurrency = costBenefitCurrency ?? 'USD',
        withinScopeItems = withinScopeItems ??
            (withinScope
                    ?.map((e) => PlanningDashboardItem(description: e))
                    .toList() ??
                []),
        outOfScopeItems = outOfScopeItems ??
            (outOfScope
                    ?.map((e) => PlanningDashboardItem(description: e))
                    .toList() ??
                []),
        assumptionItems = assumptionItems ??
            (assumptions
                    ?.map((e) => PlanningDashboardItem(description: e))
                    .toList() ??
                []),
        constraintItems = constraintItems ??
            (constraints
                    ?.map((e) => PlanningDashboardItem(description: e))
                    .toList() ??
                []);

  ProjectDataModel copyWith({
    String? projectName,
    String? solutionTitle,
    String? solutionDescription,
    String? businessCase,
    String? notes,
    // Legacy args (kept for compatibility in signature, but we prioritize new fields)
    List<String>? assumptions,
    List<String>? constraints,
    List<String>? withinScope,
    List<String>? outOfScope,
    List<String>? opportunities,
    String? charterAssumptions,
    String? charterConstraints,
    String? charterProjectManagerName,
    String? charterProjectSponsorName,
    String? charterReviewedBy,
    DateTime? charterApprovalDate,
    String? charterEmail,
    String? charterPhone,
    String? charterOrganizationalUnit,
    String? charterGreenBelt,
    String? charterBlackBelt,
    List<String>? tags,
    List<Contractor>? contractors,
    List<Vendor>? vendors,
    List<PotentialSolution>? potentialSolutions,
    List<SolutionRisk>? solutionRisks,
    PreferredSolutionAnalysis? preferredSolutionAnalysis,
    String? overallFramework,
    List<ProjectGoal>? projectGoals,
    String? potentialSolution,
    String? projectObjective,
    List<PlanningGoal>? planningGoals,
    List<Milestone>? keyMilestones,
    Map<String, String>? planningNotes,
    Map<String, String>? riskMitigationPlans,
    List<ExecutionRiskItem>? executionRiskItems,
    List<ExecutionRiskSignal>? executionRiskSignals,
    List<ExecutionRiskMitigation>? executionRiskMitigations,
    List<PlanningRequirementItem>? planningRequirementItems,
    String? planningRequirementsNotes,
    String? wbsCriteriaA,
    String? wbsCriteriaB,
    List<List<WorkItem>>? goalWorkItems,
    List<WorkItem>? wbsTree,
    List<ProjectActivity>? projectActivities,
    List<ProjectActivity>? customProjectActivities,
    List<String>? hiddenProjectActivityIds,
    List<IssueLogItem>? issueLogItems,
    List<LessonRecord>? lessonsLearned,
    FrontEndPlanningData? frontEndPlanning,
    List<Map<String, dynamic>>? technologyDefinitions,
    List<Map<String, dynamic>>? technologyInventory,
    SSHERData? ssherData,
    List<TeamMember>? teamMembers,
    List<LaunchChecklistItem>? launchChecklistItems,
    CostAnalysisData? costAnalysisData,
    List<CostEstimateItem>? costEstimateItems,
    double? managementReserve,
    ITConsiderationsData? itConsiderationsData,
    InfrastructureConsiderationsData? infrastructureConsiderationsData,
    CoreStakeholdersData? coreStakeholdersData,
    List<RoleDefinition>? projectRoles,
    List<RaciMatrixRow>? raciMatrixRows,
    List<StaffingRequirement>? staffingRequirements,
    List<InfrastructurePlanningItem>? planningInfrastructureItems,
    List<TrainingActivity>? trainingActivities,
    DesignDeliverablesData? designDeliverablesData,
    DesignManagementData? designManagementData,
    ExecutionPhaseData? executionPhaseData,
    MonitoringControlsData? monitoringControls,
    LaunchPhaseData? launchPhaseData,
    bool? isBasicPlanProject,
    Map<String, int>? aiUsageCounts,
    List<Map<String, dynamic>>? aiIntegrations,
    List<Map<String, dynamic>>? externalIntegrations,
    List<Map<String, dynamic>>? aiRecommendations,
    String? projectId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? currentCheckpoint,
    Map<String, FieldHistory>? fieldHistories,
    String? costBenefitCurrency,
    String? preferredSolutionId,
    List<StakeholderEntry>? stakeholderEntries,
    List<EngagementPlanEntry>? engagementPlanEntries,
    QualityManagementData? qualityManagementData,
    List<ControlAccount>? controlAccounts,
    List<ObsElement>? obsElements,
    List<CbsElement>? cbsElements,
    double? aggregateBac,
    double? aggregatePlannedValue,
    double? aggregateEarnedValue,
    double? aggregateActualCost,
    double? aggregateCpi,
    double? aggregateSpi,
    double? aggregateEac,
    double? aggregateEtc,
    double? aggregateVac,
    double? aggregateCv,
    double? aggregateSv,
    double? aggregateTcpi,
    DateTime? evmLastRecalculated,

    // New Fields
    List<PlanningDashboardItem>? withinScopeItems,
    List<PlanningDashboardItem>? outOfScopeItems,
    List<PlanningDashboardItem>? assumptionItems,
    List<PlanningDashboardItem>? constraintItems,
    List<InterfaceEntry>? interfaceEntries,
    List<InterfaceChangeLogEntry>? interfaceChangeLog,
    List<ScheduleActivity>? scheduleActivities,
    List<ScheduleActivity>? scheduleBaselineActivities,
    String? scheduleBaselineDate,
    List<WorkPackage>? workPackages,
  }) {
    List<PlanningDashboardItem> resolveDashboardItems({
      required List<PlanningDashboardItem>? explicitItems,
      required List<String>? legacyItems,
      required List<PlanningDashboardItem> currentItems,
    }) {
      if (explicitItems != null) return explicitItems;
      if (legacyItems != null) {
        return legacyItems
            .map((entry) => PlanningDashboardItem(description: entry))
            .toList();
      }
      return currentItems;
    }

    return ProjectDataModel(
      projectName: projectName ?? this.projectName,
      solutionTitle: solutionTitle ?? this.solutionTitle,
      solutionDescription: solutionDescription ?? this.solutionDescription,
      businessCase: businessCase ?? this.businessCase,
      notes: notes ?? this.notes,
      // Pass legacy args if provided. The constructor handles mapping them to items if items aren't provided.
      assumptions: assumptions,
      constraints: constraints,
      withinScope: withinScope,
      outOfScope: outOfScope,

      opportunities: opportunities ?? this.opportunities,
      charterAssumptions: charterAssumptions ?? this.charterAssumptions,
      charterConstraints: charterConstraints ?? this.charterConstraints,
      charterProjectManagerName:
          charterProjectManagerName ?? this.charterProjectManagerName,
      charterProjectSponsorName:
          charterProjectSponsorName ?? this.charterProjectSponsorName,
      charterReviewedBy: charterReviewedBy ?? this.charterReviewedBy,
      charterApprovalDate: charterApprovalDate ?? this.charterApprovalDate,
      designManagementData: designManagementData ?? this.designManagementData,
      charterEmail: charterEmail ?? this.charterEmail,
      charterPhone: charterPhone ?? this.charterPhone,
      charterOrganizationalUnit:
          charterOrganizationalUnit ?? this.charterOrganizationalUnit,
      charterGreenBelt: charterGreenBelt ?? this.charterGreenBelt,
      charterBlackBelt: charterBlackBelt ?? this.charterBlackBelt,
      tags: tags ?? this.tags,
      contractors: contractors ?? this.contractors,
      vendors: vendors ?? this.vendors,
      potentialSolutions: potentialSolutions ?? this.potentialSolutions,
      solutionRisks: solutionRisks ?? this.solutionRisks,
      preferredSolutionAnalysis:
          preferredSolutionAnalysis ?? this.preferredSolutionAnalysis,
      overallFramework: overallFramework ?? this.overallFramework,
      projectGoals: projectGoals ?? this.projectGoals,
      potentialSolution: potentialSolution ?? this.potentialSolution,
      projectObjective: projectObjective ?? this.projectObjective,
      planningGoals: planningGoals ?? this.planningGoals,
      keyMilestones: keyMilestones ?? this.keyMilestones,
      planningNotes: planningNotes ?? this.planningNotes,
      riskMitigationPlans: riskMitigationPlans ?? this.riskMitigationPlans,
      executionRiskItems: executionRiskItems ?? this.executionRiskItems,
      executionRiskSignals: executionRiskSignals ?? this.executionRiskSignals,
      executionRiskMitigations:
          executionRiskMitigations ?? this.executionRiskMitigations,
      interfaceEntries: interfaceEntries ?? this.interfaceEntries,
      interfaceChangeLog: interfaceChangeLog ?? this.interfaceChangeLog,
      scheduleActivities: scheduleActivities ?? this.scheduleActivities,
      scheduleBaselineActivities:
          scheduleBaselineActivities ?? this.scheduleBaselineActivities,
      scheduleBaselineDate: scheduleBaselineDate ?? this.scheduleBaselineDate,
      workPackages: workPackages ?? this.workPackages,
      planningRequirementItems:
          planningRequirementItems ?? this.planningRequirementItems,
      planningRequirementsNotes:
          planningRequirementsNotes ?? this.planningRequirementsNotes,
      wbsCriteriaA: wbsCriteriaA ?? this.wbsCriteriaA,
      wbsCriteriaB: wbsCriteriaB ?? this.wbsCriteriaB,
      goalWorkItems: goalWorkItems ?? this.goalWorkItems,
      wbsTree: wbsTree ?? this.wbsTree,
      projectActivities: projectActivities ?? this.projectActivities,
      customProjectActivities:
          customProjectActivities ?? this.customProjectActivities,
      hiddenProjectActivityIds:
          hiddenProjectActivityIds ?? this.hiddenProjectActivityIds,
      issueLogItems: issueLogItems ?? this.issueLogItems,
      lessonsLearned: lessonsLearned ?? this.lessonsLearned,
      technologyDefinitions:
          technologyDefinitions ?? this.technologyDefinitions,
      technologyInventory: technologyInventory ?? this.technologyInventory,
      frontEndPlanning: frontEndPlanning ?? this.frontEndPlanning,
      ssherData: ssherData ?? this.ssherData,
      teamMembers: teamMembers ?? this.teamMembers,
      launchChecklistItems: launchChecklistItems ?? this.launchChecklistItems,
      costAnalysisData: costAnalysisData ?? this.costAnalysisData,
      costEstimateItems: costEstimateItems ?? this.costEstimateItems,
      managementReserve: managementReserve ?? this.managementReserve,
      itConsiderationsData: itConsiderationsData ?? this.itConsiderationsData,
      infrastructureConsiderationsData: infrastructureConsiderationsData ??
          this.infrastructureConsiderationsData,
      coreStakeholdersData: coreStakeholdersData ?? this.coreStakeholdersData,
      projectRoles: projectRoles ?? this.projectRoles,
      raciMatrixRows: raciMatrixRows ?? this.raciMatrixRows,
      staffingRequirements: staffingRequirements ?? this.staffingRequirements,
      planningInfrastructureItems:
          planningInfrastructureItems ?? this.planningInfrastructureItems,
      trainingActivities: trainingActivities ?? this.trainingActivities,
      designDeliverablesData:
          designDeliverablesData ?? this.designDeliverablesData,
      executionPhaseData: executionPhaseData ?? this.executionPhaseData,
      monitoringControls: monitoringControls ?? this.monitoringControls,
      launchPhaseData: launchPhaseData ?? this.launchPhaseData,
      isBasicPlanProject: isBasicPlanProject ?? this.isBasicPlanProject,
      aiUsageCounts: aiUsageCounts ?? this.aiUsageCounts,
      aiIntegrations: aiIntegrations ?? this.aiIntegrations,
      externalIntegrations: externalIntegrations ?? this.externalIntegrations,
      aiRecommendations: aiRecommendations ?? this.aiRecommendations,
      projectId: projectId ?? this.projectId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentCheckpoint: currentCheckpoint ?? this.currentCheckpoint,
      fieldHistories: fieldHistories ?? this.fieldHistories,
      costBenefitCurrency: costBenefitCurrency ?? this.costBenefitCurrency,
      preferredSolutionId: preferredSolutionId ?? this.preferredSolutionId,
      stakeholderEntries: stakeholderEntries ?? this.stakeholderEntries,
      engagementPlanEntries:
          engagementPlanEntries ?? this.engagementPlanEntries,
      qualityManagementData:
          qualityManagementData ?? this.qualityManagementData,
      controlAccounts: controlAccounts ?? this.controlAccounts,
      obsElements: obsElements ?? this.obsElements,
      cbsElements: cbsElements ?? this.cbsElements,
      aggregateBac: aggregateBac ?? this.aggregateBac,
      aggregatePlannedValue:
          aggregatePlannedValue ?? this.aggregatePlannedValue,
      aggregateEarnedValue: aggregateEarnedValue ?? this.aggregateEarnedValue,
      aggregateActualCost: aggregateActualCost ?? this.aggregateActualCost,
      aggregateCpi: aggregateCpi ?? this.aggregateCpi,
      aggregateSpi: aggregateSpi ?? this.aggregateSpi,
      aggregateEac: aggregateEac ?? this.aggregateEac,
      aggregateEtc: aggregateEtc ?? this.aggregateEtc,
      aggregateVac: aggregateVac ?? this.aggregateVac,
      aggregateCv: aggregateCv ?? this.aggregateCv,
      aggregateSv: aggregateSv ?? this.aggregateSv,
      aggregateTcpi: aggregateTcpi ?? this.aggregateTcpi,
      evmLastRecalculated: evmLastRecalculated ?? this.evmLastRecalculated,

      // New Fields copy
      withinScopeItems: resolveDashboardItems(
        explicitItems: withinScopeItems,
        legacyItems: withinScope,
        currentItems: this.withinScopeItems,
      ),
      outOfScopeItems: resolveDashboardItems(
        explicitItems: outOfScopeItems,
        legacyItems: outOfScope,
        currentItems: this.outOfScopeItems,
      ),
      assumptionItems: resolveDashboardItems(
        explicitItems: assumptionItems,
        legacyItems: assumptions,
        currentItems: this.assumptionItems,
      ),
      constraintItems: resolveDashboardItems(
        explicitItems: constraintItems,
        legacyItems: constraints,
        currentItems: this.constraintItems,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    // Flatten goalWorkItems to avoid nested arrays (Firestore doesn't support nested arrays)
    final flattenedWorkItems = <Map<String, dynamic>>[];
    for (int goalIndex = 0; goalIndex < goalWorkItems.length; goalIndex++) {
      for (final item in goalWorkItems[goalIndex]) {
        flattenedWorkItems.add({
          ...item.toJson(),
          'goalIndex': goalIndex,
        });
      }
    }

    return {
      'name': projectName, // Map to 'name' for ProjectService compatibility
      'projectName': projectName,
      'solutionTitle': solutionTitle,
      'solutionDescription': solutionDescription,
      'businessCase': businessCase,
      'notes': notes,
      'assumptions': assumptions,
      'constraints': constraints,
      'withinScope': withinScope,
      'outOfScope': outOfScope,
      'opportunities': opportunities,
      'charterAssumptions': charterAssumptions,
      'charterConstraints': charterConstraints,
      'charterProjectManagerName': charterProjectManagerName,
      'charterProjectSponsorName': charterProjectSponsorName,
      'charterReviewedBy': charterReviewedBy,
      'charterApprovalDate': charterApprovalDate?.toIso8601String(),
      'charterEmail': charterEmail,
      'charterPhone': charterPhone,
      'charterOrganizationalUnit': charterOrganizationalUnit,
      'charterGreenBelt': charterGreenBelt,
      'charterBlackBelt': charterBlackBelt,
      'tags': tags,
      'contractors': contractors.map((c) => c.toJson()).toList(),
      'vendors': vendors.map((v) => v.toJson()).toList(),
      'potentialSolutions': potentialSolutions.map((s) => s.toJson()).toList(),
      'solutionRisks': solutionRisks.map((r) => r.toJson()).toList(),
      'preferredSolutionAnalysis': preferredSolutionAnalysis?.toJson(),
      'overallFramework': overallFramework,
      'projectGoals': projectGoals.map((g) => g.toJson()).toList(),
      'potentialSolution': potentialSolution,
      'projectObjective': projectObjective,
      'planningGoals': planningGoals.map((g) => g.toJson()).toList(),
      'keyMilestones': keyMilestones.map((m) => m.toJson()).toList(),
      'planningNotes': planningNotes,
      'riskMitigationPlans': riskMitigationPlans,
      'executionRiskItems':
          executionRiskItems.map((item) => item.toJson()).toList(),
      'executionRiskSignals':
          executionRiskSignals.map((item) => item.toJson()).toList(),
      'executionRiskMitigations':
          executionRiskMitigations.map((item) => item.toJson()).toList(),
      'interfaceEntries':
          interfaceEntries.map((entry) => entry.toJson()).toList(),
      'interfaceChangeLog':
          interfaceChangeLog.map((entry) => entry.toJson()).toList(),
      'scheduleActivities':
          scheduleActivities.map((activity) => activity.toJson()).toList(),
      'scheduleBaselineActivities': scheduleBaselineActivities
          .map((activity) => activity.toJson())
          .toList(),
      'scheduleBaselineDate': scheduleBaselineDate,
      'planningRequirementItems':
          planningRequirementItems.map((e) => e.toJson()).toList(),
      'planningRequirementsNotes': planningRequirementsNotes,
      'wbsCriteriaA': wbsCriteriaA,
      'wbsCriteriaB': wbsCriteriaB,
      'goalWorkItems': flattenedWorkItems,
      'wbsTree': wbsTree.map((item) => item.toJson()).toList(),
      'projectActivities': projectActivities.map((x) => x.toJson()).toList(),
      'customProjectActivities':
          customProjectActivities.map((x) => x.toJson()).toList(),
      'hiddenProjectActivityIds': hiddenProjectActivityIds,
      'issueLogItems': issueLogItems.map((item) => item.toJson()).toList(),
      'lessonsLearned': lessonsLearned.map((l) => l.toJson()).toList(),
      'technologyDefinitions': technologyDefinitions,
      'technologyInventory': technologyInventory,
      'frontEndPlanning': frontEndPlanning.toJson(),
      'ssherData': ssherData.toJson(),
      'teamMembers': teamMembers.map((m) => m.toJson()).toList(),
      'teamMemberEmails':
          teamMembers.map((m) => m.email).where((e) => e.isNotEmpty).toList(),
      'launchChecklistItems':
          launchChecklistItems.map((item) => item.toJson()).toList(),
      if (costAnalysisData != null)
        'costAnalysisData': costAnalysisData!.toJson(),
      'costEstimateItems':
          costEstimateItems.map((item) => item.toJson()).toList(),
      'managementReserve': managementReserve,
      if (itConsiderationsData != null)
        'itConsiderationsData': itConsiderationsData!.toJson(),
      if (infrastructureConsiderationsData != null)
        'infrastructureConsiderationsData':
            infrastructureConsiderationsData!.toJson(),
      if (coreStakeholdersData != null)
        'coreStakeholdersData': coreStakeholdersData!.toJson(),
      'projectRoles': projectRoles.map((r) => r.toJson()).toList(),
      'raciMatrixRows': raciMatrixRows.map((r) => r.toJson()).toList(),
      'staffingRequirements':
          staffingRequirements.map((s) => s.toJson()).toList(),
      'planningInfrastructureItems':
          planningInfrastructureItems.map((item) => item.toJson()).toList(),
      'trainingActivities': trainingActivities.map((t) => t.toJson()).toList(),
      'designDeliverables': designDeliverablesData.toJson(),
      'currentCheckpoint': currentCheckpoint,
      'isBasicPlanProject': isBasicPlanProject,
      'aiUsageCounts': aiUsageCounts,

      'aiIntegrations': aiIntegrations,
      'externalIntegrations': externalIntegrations,
      'aiRecommendations': aiRecommendations,
      'projectId': projectId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'fieldHistories':
          fieldHistories.map((key, value) => MapEntry(key, value.toJson())),
      'costBenefitCurrency': costBenefitCurrency,
      'preferredSolutionId': preferredSolutionId,
      'stakeholderEntries': stakeholderEntries.map((e) => e.toJson()).toList(),
      'engagementPlanEntries':
          engagementPlanEntries.map((e) => e.toJson()).toList(),
      'qualityManagementData': qualityManagementData?.toJson(),
      'designManagementData': designManagementData?.toJson(),
      'executionPhaseData': executionPhaseData?.toJson(),
      'workPackages': workPackages.map((wp) => wp.toJson()).toList(),
      'controlAccounts': controlAccounts.map((ca) => ca.toJson()).toList(),
      'obsElements': obsElements.map((o) => o.toJson()).toList(),
      'cbsElements': cbsElements.map((c) => c.toJson()).toList(),
      'aggregateBac': aggregateBac,
      'aggregatePlannedValue': aggregatePlannedValue,
      'aggregateEarnedValue': aggregateEarnedValue,
      'aggregateActualCost': aggregateActualCost,
      'aggregateCpi': aggregateCpi,
      'aggregateSpi': aggregateSpi,
      'aggregateEac': aggregateEac,
      'aggregateEtc': aggregateEtc,
      'aggregateVac': aggregateVac,
      'aggregateCv': aggregateCv,
      'aggregateSv': aggregateSv,
      'aggregateTcpi': aggregateTcpi,
      'evmLastRecalculated': evmLastRecalculated?.toIso8601String(),

      // New Structured Data persistence
      'withinScopeItems': withinScopeItems.map((x) => x.toJson()).toList(),
      'outOfScopeItems': outOfScopeItems.map((x) => x.toJson()).toList(),
      'assumptionItems': assumptionItems.map((x) => x.toJson()).toList(),
      'constraintItems': constraintItems.map((x) => x.toJson()).toList(),
    };
  }

  factory ProjectDataModel.fromJson(Map<String, dynamic> json) {
    // Reconstruct goalWorkItems from flattened structure
    List<List<WorkItem>> reconstructedGoalWorkItems =
        List.generate(3, (_) => []);
    final rawWorkItems = json['goalWorkItems'] as List?;

    if (rawWorkItems != null) {
      try {
        // Check if it's the old nested format or new flattened format
        if (rawWorkItems.isNotEmpty && rawWorkItems.first is List) {
          // Old nested format (backward compatibility)
          reconstructedGoalWorkItems = rawWorkItems
              .map((items) =>
                  (items as List).map((i) => WorkItem.fromJson(i)).toList())
              .toList();
        } else {
          // New flattened format
          for (final item in rawWorkItems) {
            final itemMap = item as Map<String, dynamic>;
            final goalIndex = itemMap['goalIndex'] as int? ?? 0;

            // Ensure the list is large enough
            while (reconstructedGoalWorkItems.length <= goalIndex) {
              reconstructedGoalWorkItems.add([]);
            }

            reconstructedGoalWorkItems[goalIndex]
                .add(WorkItem.fromJson(itemMap));
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing goalWorkItems: $e');
        reconstructedGoalWorkItems = List.generate(3, (_) => []);
      }
    }

    // Helper to safely parse PlanningDashboardItem lists
    List<PlanningDashboardItem>? parseDashboardItems(String key) {
      if (json[key] is List) {
        return (json[key] as List)
            .map((e) => PlanningDashboardItem.fromJson(e))
            .toList();
      }
      return null; // Return null so constructor uses legacy fallback
    }

    // Safe parsing helper for lists
    List<T> safeParseList<T>(
        String key, T Function(Map<String, dynamic>) parser) {
      try {
        final list = json[key] as List?;
        if (list == null) return [];
        return list
            .map((item) {
              try {
                return parser(item as Map<String, dynamic>);
              } catch (e) {
                debugPrint('⚠️ Error parsing item in $key: $e');
                return null;
              }
            })
            .whereType<T>()
            .toList();
      } catch (e) {
        debugPrint('⚠️ Error parsing list $key: $e');
        return [];
      }
    }

    // Safe parsing helper for single objects
    T? safeParseSingle<T>(String key, T Function(Map<String, dynamic>) parser) {
      try {
        final obj = json[key];
        if (obj == null) return null;
        return parser(obj as Map<String, dynamic>);
      } catch (e) {
        debugPrint('⚠️ Error parsing $key: $e');
        return null;
      }
    }

    // Safe DateTime parsing
    DateTime? safeParseDateTime(String key) {
      try {
        final value = json[key];
        if (value == null) return null;
        if (value is String) return DateTime.parse(value);
        if (value is DateTime) return value;
        return null;
      } catch (e) {
        debugPrint('⚠️ Error parsing DateTime $key: $e');
        return null;
      }
    }

    return ProjectDataModel(
      projectName:
          json['projectName']?.toString() ?? json['name']?.toString() ?? '',
      solutionTitle: json['solutionTitle']?.toString() ?? '',
      solutionDescription: json['solutionDescription']?.toString() ?? '',
      businessCase: json['businessCase']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      assumptions:
          (json['assumptions'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      constraints:
          (json['constraints'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      withinScope:
          (json['withinScope'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      outOfScope:
          (json['outOfScope'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      opportunities:
          (json['opportunities'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      charterAssumptions: json['charterAssumptions']?.toString() ?? '',
      charterConstraints: json['charterConstraints']?.toString() ?? '',
      charterProjectManagerName:
          json['charterProjectManagerName']?.toString() ?? '',
      charterProjectSponsorName:
          json['charterProjectSponsorName']?.toString() ?? '',
      charterReviewedBy: json['charterReviewedBy']?.toString() ?? '',
      charterApprovalDate: safeParseDateTime('charterApprovalDate'),
      charterEmail: json['charterEmail']?.toString() ?? '',
      charterPhone: json['charterPhone']?.toString() ?? '',
      charterOrganizationalUnit:
          json['charterOrganizationalUnit']?.toString() ?? '',
      charterGreenBelt: json['charterGreenBelt']?.toString() ?? '',
      charterBlackBelt: json['charterBlackBelt']?.toString() ?? '',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      contractors: safeParseList('contractors', Contractor.fromJson),
      vendors: safeParseList('vendors', Vendor.fromJson),
      potentialSolutions:
          safeParseList('potentialSolutions', PotentialSolution.fromJson),
      solutionRisks: safeParseList('solutionRisks', SolutionRisk.fromJson),
      preferredSolutionAnalysis: safeParseSingle(
          'preferredSolutionAnalysis', PreferredSolutionAnalysis.fromJson),
      overallFramework: json['overallFramework']?.toString(),
      projectGoals: safeParseList('projectGoals', ProjectGoal.fromJson),
      potentialSolution: json['potentialSolution']?.toString() ?? '',
      projectObjective: json['projectObjective']?.toString() ?? '',
      planningGoals: () {
        final parsed = safeParseList('planningGoals', PlanningGoal.fromJson);
        return parsed.isEmpty
            ? List.generate(3, (i) => PlanningGoal(goalNumber: i + 1))
            : parsed;
      }(),
      keyMilestones: safeParseList('keyMilestones', Milestone.fromJson),
      planningNotes: (json['planningNotes'] is Map)
          ? Map<String, String>.from(
              (json['planningNotes'] as Map).map(
                  (key, value) => MapEntry(key.toString(), value.toString())),
            )
          : {},
      riskMitigationPlans: (json['riskMitigationPlans'] is Map)
          ? Map<String, String>.from(
              (json['riskMitigationPlans'] as Map).map((key, value) {
                return MapEntry(key.toString(), value.toString());
              }),
            )
          : {},
      executionRiskItems:
          safeParseList('executionRiskItems', ExecutionRiskItem.fromJson),
      executionRiskSignals:
          safeParseList('executionRiskSignals', ExecutionRiskSignal.fromJson),
      executionRiskMitigations: safeParseList(
          'executionRiskMitigations', ExecutionRiskMitigation.fromJson),
      interfaceEntries:
          safeParseList('interfaceEntries', InterfaceEntry.fromJson),
      interfaceChangeLog:
          safeParseList('interfaceChangeLog', InterfaceChangeLogEntry.fromJson),
      scheduleActivities:
          safeParseList('scheduleActivities', ScheduleActivity.fromJson),
      scheduleBaselineActivities: safeParseList(
          'scheduleBaselineActivities', ScheduleActivity.fromJson),
      scheduleBaselineDate: json['scheduleBaselineDate']?.toString() ?? '',
      planningRequirementItems: safeParseList(
          'planningRequirementItems', PlanningRequirementItem.fromJson),
      planningRequirementsNotes:
          json['planningRequirementsNotes']?.toString() ?? '',
      wbsCriteriaA: json['wbsCriteriaA']?.toString(),
      wbsCriteriaB: json['wbsCriteriaB']?.toString(),
      goalWorkItems: reconstructedGoalWorkItems,
      wbsTree: safeParseList('wbsTree', WorkItem.fromJson),
      projectActivities:
          safeParseList('projectActivities', ProjectActivity.fromJson),
      customProjectActivities:
          safeParseList('customProjectActivities', ProjectActivity.fromJson),
      hiddenProjectActivityIds: (json['hiddenProjectActivityIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      issueLogItems: safeParseList('issueLogItems', IssueLogItem.fromJson),
      lessonsLearned: safeParseList('lessonsLearned', LessonRecord.fromJson),
      technologyDefinitions: (json['technologyDefinitions'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      technologyInventory: (json['technologyInventory'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      frontEndPlanning:
          safeParseSingle('frontEndPlanning', FrontEndPlanningData.fromJson) ??
              FrontEndPlanningData(),
      ssherData:
          safeParseSingle('ssherData', SSHERData.fromJson) ?? SSHERData(),
      teamMembers: safeParseList('teamMembers', TeamMember.fromJson),
      launchChecklistItems:
          safeParseList('launchChecklistItems', LaunchChecklistItem.fromJson),
      costAnalysisData:
          safeParseSingle('costAnalysisData', CostAnalysisData.fromJson),
      costEstimateItems:
          safeParseList('costEstimateItems', CostEstimateItem.fromJson),
      managementReserve: (json['managementReserve'] is num)
          ? (json['managementReserve'] as num).toDouble()
          : 0.0,
      itConsiderationsData: safeParseSingle(
          'itConsiderationsData', ITConsiderationsData.fromJson),
      infrastructureConsiderationsData: safeParseSingle(
          'infrastructureConsiderationsData',
          InfrastructureConsiderationsData.fromJson),
      coreStakeholdersData: safeParseSingle(
          'coreStakeholdersData', CoreStakeholdersData.fromJson),
      projectRoles: safeParseList('projectRoles', RoleDefinition.fromJson),
      raciMatrixRows: safeParseList('raciMatrixRows', RaciMatrixRow.fromJson),
      staffingRequirements:
          safeParseList('staffingRequirements', StaffingRequirement.fromJson),
      planningInfrastructureItems: safeParseList(
          'planningInfrastructureItems', InfrastructurePlanningItem.fromJson),
      trainingActivities:
          safeParseList('trainingActivities', TrainingActivity.fromJson),
      designDeliverablesData: safeParseSingle(
              'designDeliverables', DesignDeliverablesData.fromJson) ??
          DesignDeliverablesData(),
      executionPhaseData:
          safeParseSingle('executionPhaseData', ExecutionPhaseData.fromJson),
      designManagementData: safeParseSingle(
          'designManagementData', DesignManagementData.fromJson),
      isBasicPlanProject: json['isBasicPlanProject'] == true,
      aiUsageCounts: (json['aiUsageCounts'] is Map)
          ? Map<String, int>.from(
              (json['aiUsageCounts'] as Map).map((key, value) {
                final parsed =
                    value is int ? value : int.tryParse(value.toString()) ?? 0;
                return MapEntry(key.toString(), parsed);
              }),
            )
          : {},
      aiIntegrations: (json['aiIntegrations'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      externalIntegrations: () {
        final external = (json['externalIntegrations'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        if (external.isNotEmpty) return external;
        // Backward-compatibility fallback for older records where external
        // integrations were incorrectly persisted in aiIntegrations.
        return (json['aiIntegrations'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
      }(),
      aiRecommendations: (json['aiRecommendations'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      currentCheckpoint: json['currentCheckpoint']?.toString() ??
          json['checkpointRoute']?.toString() ??
          'initiation',
      projectId: json['projectId']?.toString(),
      createdAt: safeParseDateTime('createdAt'),
      updatedAt: safeParseDateTime('updatedAt'),
      fieldHistories: (json['fieldHistories'] is Map)
          ? Map<String, FieldHistory>.from(
              (json['fieldHistories'] as Map).map((key, value) {
                try {
                  return MapEntry(
                    key.toString(),
                    FieldHistory.fromJson(value as Map<String, dynamic>),
                  );
                } catch (e) {
                  debugPrint('⚠️ Error parsing FieldHistory for $key: $e');
                  return MapEntry(
                      key.toString(), FieldHistory(fieldName: key.toString()));
                }
              }),
            )
          : {},
      costBenefitCurrency: json['costBenefitCurrency']?.toString() ?? 'USD',
      preferredSolutionId: json['preferredSolutionId']?.toString(),
      stakeholderEntries: (json['stakeholderEntries'] as List?)
              ?.map((e) => StakeholderEntry.fromJson(e))
              .toList() ??
          [],
      engagementPlanEntries: (json['engagementPlanEntries'] as List?)
              ?.map((e) => EngagementPlanEntry.fromJson(e))
              .toList() ??
          [],
      qualityManagementData: json['qualityManagementData'] != null
          ? QualityManagementData.fromJson(json['qualityManagementData'])
          : null,
      workPackages: safeParseList('workPackages', WorkPackage.fromJson),
      controlAccounts:
          safeParseList('controlAccounts', ControlAccount.fromJson),
      obsElements: safeParseList('obsElements', ObsElement.fromJson),
      cbsElements: safeParseList('cbsElements', CbsElement.fromJson),
      aggregateBac: (json['aggregateBac'] is num)
          ? (json['aggregateBac'] as num).toDouble()
          : 0.0,
      aggregatePlannedValue: (json['aggregatePlannedValue'] is num)
          ? (json['aggregatePlannedValue'] as num).toDouble()
          : 0.0,
      aggregateEarnedValue: (json['aggregateEarnedValue'] is num)
          ? (json['aggregateEarnedValue'] as num).toDouble()
          : 0.0,
      aggregateActualCost: (json['aggregateActualCost'] is num)
          ? (json['aggregateActualCost'] as num).toDouble()
          : 0.0,
      aggregateCpi: (json['aggregateCpi'] is num)
          ? (json['aggregateCpi'] as num).toDouble()
          : 1.0,
      aggregateSpi: (json['aggregateSpi'] is num)
          ? (json['aggregateSpi'] as num).toDouble()
          : 1.0,
      aggregateEac: (json['aggregateEac'] is num)
          ? (json['aggregateEac'] as num).toDouble()
          : 0.0,
      aggregateEtc: (json['aggregateEtc'] is num)
          ? (json['aggregateEtc'] as num).toDouble()
          : 0.0,
      aggregateVac: (json['aggregateVac'] is num)
          ? (json['aggregateVac'] as num).toDouble()
          : 0.0,
      aggregateCv: (json['aggregateCv'] is num)
          ? (json['aggregateCv'] as num).toDouble()
          : 0.0,
      aggregateSv: (json['aggregateSv'] is num)
          ? (json['aggregateSv'] as num).toDouble()
          : 0.0,
      aggregateTcpi: (json['aggregateTcpi'] is num)
          ? (json['aggregateTcpi'] as num).toDouble()
          : 0.0,
      evmLastRecalculated: safeParseDateTime('evmLastRecalculated'),

      // Load New Structured Data
      withinScopeItems: parseDashboardItems('withinScopeItems'),
      outOfScopeItems: parseDashboardItems('outOfScopeItems'),
      assumptionItems: parseDashboardItems('assumptionItems'),
      constraintItems: parseDashboardItems('constraintItems'),
    );
  }

  /// ── P2.5: Compute project-level aggregate EVM from control accounts ──
  /// Rolls up BAC, EV, AC, and PV from all [controlAccounts], then derives
  /// CPI, SPI, EAC, ETC, VAC, CV, SV, and TCPI using standard EVM formulas.
  ///
  /// Call this after [ControlAccountService.recalculateAll] has updated
  /// individual control account EVM metrics. This method mutates the aggregate
  /// fields on this model in-place and updates [evmLastRecalculated].
  ///
  /// Returns `this` for chaining convenience.
  ProjectDataModel computeAggregateEvm() {
    double aggBac = 0, aggEv = 0, aggAc = 0, aggPv = 0;
    for (final ca in controlAccounts) {
      aggBac += ca.budgetAtCompletion;
      aggEv += ca.earnedValue;
      aggAc += ca.actualCost;
      // Sum planned value from period data
      final now = DateTime.now();
      final currentKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      for (final entry in ca.plannedValueByPeriod.entries) {
        if (entry.key.compareTo(currentKey) <= 0) {
          aggPv += entry.value;
        }
      }
    }

    aggregateBac = aggBac;
    aggregatePlannedValue = aggPv;
    aggregateEarnedValue = aggEv;
    aggregateActualCost = aggAc;
    aggregateCpi = aggAc > 0 ? aggEv / aggAc : 1.0;
    aggregateSpi = aggPv > 0 ? aggEv / aggPv : 1.0;
    aggregateEac = aggregateCpi > 0 ? aggBac / aggregateCpi : aggBac;
    aggregateEtc = aggregateEac - aggAc;
    aggregateVac = aggBac - aggregateEac;
    aggregateCv = aggEv - aggAc;
    aggregateSv = aggEv - aggPv;
    aggregateTcpi =
        (aggBac - aggAc) > 0 ? (aggBac - aggEv) / (aggBac - aggAc) : 1.0;
    evmLastRecalculated = DateTime.now();

    return this;
  }

  /// Add a field value to history for undo functionality
  void addFieldToHistory(String fieldName, String value,
      {bool isAiGenerated = false}) {
    if (!fieldHistories.containsKey(fieldName)) {
      fieldHistories[fieldName] = FieldHistory(
        fieldName: fieldName,
        isAiGenerated: isAiGenerated,
      );
    }
    fieldHistories[fieldName]!.addToHistory(value);
  }

  /// Undo the last change to a field
  String? undoField(String fieldName) {
    return fieldHistories[fieldName]?.undo();
  }

  /// Redo a reverted change to a field
  String? redoField(String fieldName) {
    return fieldHistories[fieldName]?.redo();
  }

  /// Check if a field can be undone
  bool canUndoField(String fieldName) {
    return fieldHistories[fieldName]?.canUndo ?? false;
  }

  /// Check if a field can be redone
  bool canRedoField(String fieldName) {
    return fieldHistories[fieldName]?.canRedo ?? false;
  }

  /// Add a new potential solution
  void addPotentialSolution() {
    if (potentialSolutions.length < 3) {
      potentialSolutions.add(PotentialSolution.empty(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        number: potentialSolutions.length + 1,
      ));
    }
  }

  /// Delete a potential solution by ID
  void deletePotentialSolution(String id) {
    potentialSolutions.removeWhere((s) => s.id == id);
    _renumberSolutions();
  }

  /// Renumber solutions after deletion
  void _renumberSolutions() {
    for (int i = 0; i < potentialSolutions.length; i++) {
      potentialSolutions[i].number = i + 1;
    }
  }

  /// Set the preferred solution
  void setPreferredSolution(String solutionId) {
    preferredSolutionId = solutionId;
  }

  /// Get the preferred solution
  PotentialSolution? get preferredSolution {
    if (preferredSolutionId == null) return null;
    try {
      return potentialSolutions.firstWhere(
        (s) => s.id == preferredSolutionId,
      );
    } catch (e) {
      return null;
    }
  }
}

class ProjectGoal {
  String name;
  String description;
  String? framework;

  ProjectGoal({
    this.name = '',
    this.description = '',
    this.framework,
  });

  ProjectGoal copyWith({
    String? name,
    String? description,
    String? framework,
  }) {
    return ProjectGoal(
      name: name ?? this.name,
      description: description ?? this.description,
      framework: framework ?? this.framework,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'framework': framework,
      };

  factory ProjectGoal.fromJson(Map<String, dynamic> json) {
    return ProjectGoal(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      framework: json['framework'],
    );
  }
}

class PlanningGoal {
  String id;
  int goalNumber;
  String title;
  String description;
  String targetYear;
  String priority;
  List<String> milestoneIds;
  List<PlanningMilestone> milestones;

  PlanningGoal({
    String? id,
    required this.goalNumber,
    this.title = '',
    this.description = '',
    this.targetYear = '',
    this.priority = 'Medium Priority',
    List<String>? milestoneIds,
    List<PlanningMilestone>? milestones,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        milestoneIds = milestoneIds ?? [],
        milestones = milestones ?? [PlanningMilestone()];

  Map<String, dynamic> toJson() => {
        'id': id,
        'goalNumber': goalNumber,
        'title': title,
        'description': description,
        'targetYear': targetYear,
        'priority': priority,
        'isHighPriority': priority == 'High Priority',
        'milestoneIds': milestoneIds,
        'milestones': milestones.map((m) => m.toJson()).toList(),
      };

  factory PlanningGoal.fromJson(Map<String, dynamic> json) {
    final rawPriority = json['priority']?.toString() ?? '';
    final legacyHigh = json['isHighPriority'] == true;
    return PlanningGoal(
      id: json['id']?.toString(),
      goalNumber: json['goalNumber'] ?? 1,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      targetYear: json['targetYear'] ?? '',
      priority: rawPriority.isNotEmpty
          ? rawPriority
          : (legacyHigh ? 'High Priority' : 'Medium Priority'),
      milestoneIds: (json['milestoneIds'] as List?)
              ?.map((m) => m.toString())
              .where((m) => m.trim().isNotEmpty)
              .toList() ??
          const [],
      milestones: (json['milestones'] as List?)
              ?.map((m) => PlanningMilestone.fromJson(m))
              .toList() ??
          [PlanningMilestone()],
    );
  }
}

class PlanningMilestone {
  String title;
  String deadline;
  String status;

  PlanningMilestone({
    this.title = '',
    this.deadline = '',
    this.status = 'In Progress',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'deadline': deadline,
        'status': status,
      };

  factory PlanningMilestone.fromJson(Map<String, dynamic> json) {
    return PlanningMilestone(
      title: json['title'] ?? '',
      deadline: json['deadline'] ?? '',
      status: json['status'] ?? 'In Progress',
    );
  }
}

class LaunchChecklistItem {
  LaunchChecklistItem({
    String? id,
    this.itemName = '',
    this.details = '',
    this.owner = '',
    this.dueBefore = '',
    this.statusTag = 'Pending sign-off',
    this.completionRule = '',
  }) : id = id ?? _generateId();

  final String id;
  String itemName;
  String details;
  String owner;
  String dueBefore;
  String statusTag;
  String completionRule;

  LaunchChecklistItem copyWith({
    String? itemName,
    String? details,
    String? owner,
    String? dueBefore,
    String? statusTag,
    String? completionRule,
  }) {
    return LaunchChecklistItem(
      id: id,
      itemName: itemName ?? this.itemName,
      details: details ?? this.details,
      owner: owner ?? this.owner,
      dueBefore: dueBefore ?? this.dueBefore,
      statusTag: statusTag ?? this.statusTag,
      completionRule: completionRule ?? this.completionRule,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemName': itemName,
        'details': details,
        'owner': owner,
        'dueBefore': dueBefore,
        'statusTag': statusTag,
        'completionRule': completionRule,
      };

  factory LaunchChecklistItem.fromJson(Map<String, dynamic> json) {
    return LaunchChecklistItem(
      id: json['id']?.toString(),
      itemName: json['itemName']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      dueBefore: json['dueBefore']?.toString() ?? '',
      statusTag: json['statusTag']?.toString() ?? 'Pending sign-off',
      completionRule: json['completionRule']?.toString() ?? '',
    );
  }

  static String _generateId() =>
      DateTime.now().microsecondsSinceEpoch.toString();
}

class Milestone {
  String id;
  String name;
  String discipline;
  String dueDate;
  String references;
  String comments;

  Milestone({
    String? id,
    this.name = '',
    this.discipline = '',
    this.dueDate = '',
    this.references = '',
    this.comments = '',
  }) : id = (id == null || id.trim().isEmpty)
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : id;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'discipline': discipline,
        'dueDate': dueDate,
        'references': references,
        'comments': comments,
      };

  factory Milestone.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString();
    return Milestone(
      id: (rawId == null || rawId.trim().isEmpty) ? null : rawId,
      name: json['name'] ?? '',
      discipline: json['discipline'] ?? '',
      dueDate: json['dueDate'] ?? '',
      references: json['references'] ?? '',
      comments: json['comments'] ?? '',
    );
  }
}

/// Returns default milestones for fallback when AI generation fails
List<Milestone> getDefaultMilestones() {
  return [
    Milestone(
      name: 'Project Kickoff',
      discipline: 'All',
      dueDate: '',
      comments: 'Official project initiation and team mobilization',
    ),
    Milestone(
      name: 'Planning Completion',
      discipline: 'Planning, Management',
      dueDate: '',
      comments: 'All planning documents finalized and approved',
    ),
    Milestone(
      name: 'Execution Start',
      discipline: 'All',
      dueDate: '',
      comments: 'Begin implementation of project deliverables',
    ),
    Milestone(
      name: 'Execution Completion',
      discipline: 'All',
      dueDate: '',
      comments: 'All deliverables completed and ready for launch',
    ),
    Milestone(
      name: 'Project Launch',
      discipline: 'All',
      dueDate: '',
      comments: 'Go-live and transition to operations',
    ),
  ];
}

class WorkItem {
  String id;
  String parentId;
  String title;
  String description;
  String status;
  String framework;
  List<WorkItem> children;
  List<String> dependencies;
  String controlAccountId;

  /// Formal WBS element code (e.g. "1.2.3.4") — canonical identifier for
  /// cross-referencing with CBS, OBS, and Control Accounts.
  String wbsCode;

  /// WBS Dictionary fields: deliverable description, acceptance criteria,
  /// and work package definition per the Integrated Project Controls guide.
  String deliverableDescription;
  String acceptanceCriteria;
  String workPackageDefinition;

  /// Relative weight (0-1) for progress rollup from children to parent.
  double weight;

  /// CBS element ID cross-reference — links this WBS node to its cost account.
  String cbsId;

  /// OBS element ID cross-reference — links this WBS node to its org unit.
  String obsId;

  WorkItem({
    String? id,
    this.parentId = '',
    this.title = '',
    this.description = '',
    this.status = 'not_started',
    this.framework = '',
    List<WorkItem>? children,
    List<String>? dependencies,
    this.controlAccountId = '',
    this.wbsCode = '',
    this.deliverableDescription = '',
    this.acceptanceCriteria = '',
    this.workPackageDefinition = '',
    this.weight = 0,
    this.cbsId = '',
    this.obsId = '',
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        children = children ?? [],
        dependencies = dependencies ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'parentId': parentId,
        'title': title,
        'description': description,
        'status': status,
        'framework': framework,
        'children': children.map((c) => c.toJson()).toList(),
        'dependencies': dependencies,
        'controlAccountId': controlAccountId,
        'wbsCode': wbsCode,
        'deliverableDescription': deliverableDescription,
        'acceptanceCriteria': acceptanceCriteria,
        'workPackageDefinition': workPackageDefinition,
        'weight': weight,
        'cbsId': cbsId,
        'obsId': obsId,
      };

  factory WorkItem.fromJson(Map<String, dynamic> json) {
    return WorkItem(
      id: json['id']?.toString(),
      parentId: json['parentId']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'not_started',
      framework: json['framework']?.toString() ?? '',
      children: (json['children'] as List?)
              ?.map((c) => WorkItem.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      dependencies:
          (json['dependencies'] as List?)?.map((d) => d.toString()).toList() ??
              [],
      controlAccountId: json['controlAccountId']?.toString() ?? '',
      wbsCode: json['wbsCode']?.toString() ?? '',
      deliverableDescription: json['deliverableDescription']?.toString() ?? '',
      acceptanceCriteria: json['acceptanceCriteria']?.toString() ?? '',
      workPackageDefinition: json['workPackageDefinition']?.toString() ?? '',
      weight: (json['weight'] is num) ? (json['weight'] as num).toDouble() : 0,
      cbsId: json['cbsId']?.toString() ?? '',
      obsId: json['obsId']?.toString() ?? '',
    );
  }
}

enum ProgressMeasurementMethod {
  zeroHundred,
  fiftyFifty,
  percentComplete,
  unitsComplete,
  milestoneGate,
  earnedValue,
  physical,
  other;

  String get label {
    switch (this) {
      case zeroHundred:
        return '0/100';
      case fiftyFifty:
        return '50/50';
      case percentComplete:
        return '% Complete';
      case unitsComplete:
        return 'Units Complete';
      case milestoneGate:
        return 'Milestone Gate';
      case earnedValue:
        return 'Earned Value';
      case physical:
        return 'Physical';
      case other:
        return 'Other';
    }
  }
}

class ScheduleActivity {
  String id;
  String wbsId;
  String title;
  int durationDays;
  List<String> predecessorIds;
  bool isMilestone;
  String status;
  String priority;
  String assignee;
  String discipline;
  double progress;
  String startDate;
  String dueDate;
  double estimatedHours;
  String milestone;
  // Work package linkage
  String workPackageId;
  String workPackageTitle;
  String
      workPackageType; // 'design' | 'construction' | 'execution' | 'agile' | 'procurement' | 'delivery'
  String phase; // 'design' | 'execution' | 'launch'
  // WBS Level 2 parent for rollup
  String wbsLevel2Id;
  String wbsLevel2Title;
  // Procurement linkage
  String contractId;
  String vendorId;
  String
      procurementStatus; // 'not_started' | 'rfq' | 'evaluating' | 'awarded' | 'contracted'
  String? procurementRfqDate;
  String? procurementAwardDate;
  String? contractStartDate;
  String? contractEndDate;
  // Cost integration
  double budgetedCost;
  double actualCost;
  String estimatingBasis;
  // Dependency & scheduling
  List<String> dependencyIds; // Multiple dependencies
  bool isCriticalPath;
  int totalFloat;
  String controlAccountId;
  String
      progressMeasurementMethod; // 'zeroHundred' | 'fiftyFifty' | 'percentComplete' | ...

  // ── P3.5: Percent complete, resource assignments, cost ──
  double percentComplete; // 0-1 for EVM calculation
  List<String> resourceIds; // assigned team member/resource IDs
  double estimatedCost; // cost-loaded schedule

  ScheduleActivity({
    String? id,
    this.wbsId = '',
    this.title = '',
    this.durationDays = 5,
    List<String>? predecessorIds,
    this.isMilestone = false,
    this.status = 'pending',
    this.priority = 'medium',
    this.assignee = '',
    this.discipline = '',
    this.progress = 0,
    this.startDate = '',
    this.dueDate = '',
    this.estimatedHours = 0,
    this.milestone = '',
    this.workPackageId = '',
    this.workPackageTitle = '',
    this.workPackageType = '',
    this.phase = '',
    this.wbsLevel2Id = '',
    this.wbsLevel2Title = '',
    this.contractId = '',
    this.vendorId = '',
    this.procurementStatus = 'not_started',
    this.procurementRfqDate,
    this.procurementAwardDate,
    this.contractStartDate,
    this.contractEndDate,
    this.budgetedCost = 0,
    this.actualCost = 0,
    this.estimatingBasis = '',
    List<String>? dependencyIds,
    this.isCriticalPath = false,
    this.totalFloat = 0,
    this.controlAccountId = '',
    this.progressMeasurementMethod = '',
    this.percentComplete = 0,
    List<String>? resourceIds,
    this.estimatedCost = 0,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        predecessorIds = predecessorIds ?? [],
        dependencyIds = dependencyIds ?? [],
        resourceIds = resourceIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'wbsId': wbsId,
        'title': title,
        'durationDays': durationDays,
        'predecessorIds': predecessorIds,
        'isMilestone': isMilestone,
        'status': status,
        'priority': priority,
        'assignee': assignee,
        'discipline': discipline,
        'progress': progress,
        'startDate': startDate,
        'dueDate': dueDate,
        'estimatedHours': estimatedHours,
        'milestone': milestone,
        'workPackageId': workPackageId,
        'workPackageTitle': workPackageTitle,
        'workPackageType': workPackageType,
        'phase': phase,
        'wbsLevel2Id': wbsLevel2Id,
        'wbsLevel2Title': wbsLevel2Title,
        'contractId': contractId,
        'vendorId': vendorId,
        'procurementStatus': procurementStatus,
        'procurementRfqDate': procurementRfqDate,
        'procurementAwardDate': procurementAwardDate,
        'contractStartDate': contractStartDate,
        'contractEndDate': contractEndDate,
        'budgetedCost': budgetedCost,
        'actualCost': actualCost,
        'estimatingBasis': estimatingBasis,
        'dependencyIds': dependencyIds,
        'isCriticalPath': isCriticalPath,
        'totalFloat': totalFloat,
        'controlAccountId': controlAccountId,
        'progressMeasurementMethod': progressMeasurementMethod,
        'percentComplete': percentComplete,
        'resourceIds': resourceIds,
        'estimatedCost': estimatedCost,
      };

  factory ScheduleActivity.fromJson(Map<String, dynamic> json) {
    return ScheduleActivity(
      id: json['id']?.toString(),
      wbsId: json['wbsId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      durationDays: json['durationDays'] is num
          ? (json['durationDays'] as num).round()
          : int.tryParse(json['durationDays']?.toString() ?? '') ?? 5,
      predecessorIds: (json['predecessorIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isMilestone: json['isMilestone'] == true,
      status: json['status']?.toString().trim().isNotEmpty == true
          ? json['status'].toString()
          : 'pending',
      priority: json['priority']?.toString().trim().isNotEmpty == true
          ? json['priority'].toString()
          : 'medium',
      assignee: json['assignee']?.toString() ?? '',
      discipline: json['discipline']?.toString() ?? '',
      progress: json['progress'] is num
          ? (json['progress'] as num).toDouble()
          : double.tryParse(json['progress']?.toString() ?? '') ?? 0,
      startDate: json['startDate']?.toString() ?? '',
      dueDate: json['dueDate']?.toString() ?? '',
      estimatedHours: json['estimatedHours'] is num
          ? (json['estimatedHours'] as num).toDouble()
          : double.tryParse(json['estimatedHours']?.toString() ?? '') ?? 0,
      milestone: json['milestone']?.toString() ?? '',
      workPackageId: json['workPackageId']?.toString() ?? '',
      workPackageTitle: json['workPackageTitle']?.toString() ?? '',
      workPackageType: json['workPackageType']?.toString() ?? '',
      phase: json['phase']?.toString() ?? '',
      wbsLevel2Id: json['wbsLevel2Id']?.toString() ?? '',
      wbsLevel2Title: json['wbsLevel2Title']?.toString() ?? '',
      contractId: json['contractId']?.toString() ?? '',
      vendorId: json['vendorId']?.toString() ?? '',
      procurementStatus: json['procurementStatus']?.toString() ?? 'not_started',
      procurementRfqDate: json['procurementRfqDate']?.toString(),
      procurementAwardDate: json['procurementAwardDate']?.toString(),
      contractStartDate: json['contractStartDate']?.toString(),
      contractEndDate: json['contractEndDate']?.toString(),
      budgetedCost: json['budgetedCost'] is num
          ? (json['budgetedCost'] as num).toDouble()
          : double.tryParse(json['budgetedCost']?.toString() ?? '') ?? 0,
      actualCost: json['actualCost'] is num
          ? (json['actualCost'] as num).toDouble()
          : double.tryParse(json['actualCost']?.toString() ?? '') ?? 0,
      estimatingBasis: json['estimatingBasis']?.toString() ?? '',
      dependencyIds:
          (json['dependencyIds'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      isCriticalPath: json['isCriticalPath'] == true,
      totalFloat: json['totalFloat'] is num
          ? (json['totalFloat'] as num).round()
          : int.tryParse(json['totalFloat']?.toString() ?? '') ?? 0,
      controlAccountId: json['controlAccountId']?.toString() ?? '',
      progressMeasurementMethod:
          json['progressMeasurementMethod']?.toString() ?? '',
      // P3.5: percentComplete and resource fields
      percentComplete: json['percentComplete'] is num
          ? (json['percentComplete'] as num).toDouble().clamp(0, 1)
          : 0,
      resourceIds:
          (json['resourceIds'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      estimatedCost: json['estimatedCost'] is num
          ? (json['estimatedCost'] as num).toDouble()
          : 0,
    );
  }
}

class IssueLogItem {
  String id;
  String title;
  String description;
  String type;
  String severity;
  String status;
  String assignee;
  String dueDate;
  String milestone;

  IssueLogItem({
    this.id = '',
    this.title = '',
    this.description = '',
    this.type = '',
    this.severity = '',
    this.status = '',
    this.assignee = '',
    this.dueDate = '',
    this.milestone = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type,
        'severity': severity,
        'status': status,
        'assignee': assignee,
        'dueDate': dueDate,
        'milestone': milestone,
      };

  factory IssueLogItem.fromJson(Map<String, dynamic> json) {
    return IssueLogItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? '',
      severity: json['severity'] ?? '',
      status: json['status'] ?? '',
      assignee: json['assignee'] ?? '',
      dueDate: json['dueDate'] ?? '',
      milestone: json['milestone'] ?? '',
    );
  }
}

class RequirementItem {
  String id;
  String description;
  String requirementType;
  String discipline;
  String role;
  String person;
  String phase;
  String requirementSource;
  String comments;

  RequirementItem({
    this.id = '',
    this.description = '',
    this.requirementType = '',
    this.discipline = '',
    this.role = '',
    this.person = '',
    this.phase = '',
    this.requirementSource = '',
    this.comments = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'requirementType': requirementType,
        'discipline': discipline,
        'role': role,
        'person': person,
        'phase': phase,
        'requirementSource': requirementSource,
        'comments': comments,
      };

  factory RequirementItem.fromJson(Map<String, dynamic> json) {
    return RequirementItem(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      requirementType: json['requirementType']?.toString() ??
          json['requirement_type']?.toString() ??
          '',
      discipline: json['discipline']?.toString() ?? '',
      role: json['role']?.toString() ?? json['ownerRole']?.toString() ?? '',
      person: json['person']?.toString() ??
          json['ownerPerson']?.toString() ??
          json['assignee']?.toString() ??
          '',
      phase: json['phase']?.toString() ??
          json['implementationPhase']?.toString() ??
          json['implementation_phase']?.toString() ??
          '',
      requirementSource: json['requirementSource']?.toString() ??
          json['requirement_source']?.toString() ??
          json['source']?.toString() ??
          '',
      comments: json['comments']?.toString() ?? '',
    );
  }
}

class PlanningRequirementItem {
  String id;
  List<String> sourceRequirementIds;
  String plannedText;
  String priority;
  String owner;
  String acceptanceCriteria;
  String verificationMethod;
  String status;
  String wbsRef;
  String notes;
  String lastSourceHash;

  PlanningRequirementItem({
    this.id = '',
    List<String>? sourceRequirementIds,
    this.plannedText = '',
    this.priority = '',
    this.owner = '',
    this.acceptanceCriteria = '',
    this.verificationMethod = '',
    this.status = 'Draft',
    this.wbsRef = '',
    this.notes = '',
    this.lastSourceHash = '',
  }) : sourceRequirementIds = sourceRequirementIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceRequirementIds': sourceRequirementIds,
        'plannedText': plannedText,
        'priority': priority,
        'owner': owner,
        'acceptanceCriteria': acceptanceCriteria,
        'verificationMethod': verificationMethod,
        'status': status,
        'wbsRef': wbsRef,
        'notes': notes,
        'lastSourceHash': lastSourceHash,
      };

  factory PlanningRequirementItem.fromJson(Map<String, dynamic> json) {
    return PlanningRequirementItem(
      id: json['id']?.toString() ?? '',
      sourceRequirementIds: (json['sourceRequirementIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      plannedText: json['plannedText']?.toString() ?? '',
      priority: json['priority']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      acceptanceCriteria: json['acceptanceCriteria']?.toString() ?? '',
      verificationMethod: json['verificationMethod']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Draft',
      wbsRef: json['wbsRef']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      lastSourceHash: json['lastSourceHash']?.toString() ?? '',
    );
  }
}

class FrontEndPlanningData {
  String requirements;
  String requirementsPlan;
  String requirementsNotes;
  String risks;
  String
      opportunities; // Legacy string field, kept for backward compatibility if needed, or deprecated
  List<OpportunityItem> opportunityItems; // New structured list
  String contractVendorQuotes;
  String procurement;
  String security;
  String allowance;
  String summary;
  String technology;
  String personnel;
  String infrastructure;
  String contracts;
  // Milestone date fields
  String milestoneStartDate;
  String milestoneEndDate;
  List<RequirementItem> requirementItems;
  // Persisted scenario matrix items
  List<ScenarioRecord> scenarioMatrixItems;
  // Security management items
  List<RoleItem> securityRoles;
  List<PermissionItem> securityPermissions;
  List<SecuritySetting> securitySettings;
  List<AccessLogItem> securityAccessLogs;
  // Technical debt related fields
  List<DebtItem> technicalDebtItems;
  List<DebtInsight> technicalDebtRootCauses;
  List<RemediationTrack> technicalDebtTracks;
  List<OwnerItem> technicalDebtOwners;
  // Structured risk register items (used for charter/summary tables)
  List<RiskRegisterItem> riskRegisterItems;
  // Structured allowance items
  List<AllowanceItem> allowanceItems;
  // Structured personnel planning rows
  List<StaffingRow> staffingRows;
  // Structured technology ownership rows
  List<TechnologyPersonnelItem> technologyPersonnelItems;
  // Structured infrastructure planning rows
  List<InfrastructurePlanningItem> infrastructureItems;
  // Success Criteria items
  List<PlanningDashboardItem> successCriteriaItems;
  bool detailsConfirmed;

  FrontEndPlanningData({
    this.requirements = '',
    this.requirementsPlan = '',
    this.requirementsNotes = '',
    this.risks = '',
    this.opportunities = '',
    this.contractVendorQuotes = '',
    this.procurement = '',
    this.security = '',
    this.allowance = '',
    this.summary = '',
    this.technology = '',
    this.personnel = '',
    this.infrastructure = '',
    this.contracts = '',
    this.milestoneStartDate = '',
    this.milestoneEndDate = '',
    this.detailsConfirmed = false,
    List<RequirementItem>? requirementItems,
    List<ScenarioRecord>? scenarioMatrixItems,
    List<RoleItem>? securityRoles,
    List<PermissionItem>? securityPermissions,
    List<SecuritySetting>? securitySettings,
    List<AccessLogItem>? securityAccessLogs,
    List<DebtItem>? technicalDebtItems,
    List<DebtInsight>? technicalDebtRootCauses,
    List<RemediationTrack>? technicalDebtTracks,
    List<OwnerItem>? technicalDebtOwners,
    List<RiskRegisterItem>? riskRegisterItems,
    List<AllowanceItem>? allowanceItems,
    List<StaffingRow>? staffingRows,
    List<TechnologyPersonnelItem>? technologyPersonnelItems,
    List<InfrastructurePlanningItem>? infrastructureItems,
    List<OpportunityItem>? opportunityItems,
    List<PlanningDashboardItem>? successCriteriaItems,
  })  : requirementItems = requirementItems ?? [],
        technicalDebtItems = technicalDebtItems ?? [],
        technicalDebtRootCauses = technicalDebtRootCauses ?? [],
        technicalDebtTracks = technicalDebtTracks ?? [],
        technicalDebtOwners = technicalDebtOwners ?? [],
        riskRegisterItems = riskRegisterItems ?? [],
        scenarioMatrixItems = scenarioMatrixItems ?? [],
        securityRoles = securityRoles ?? [],
        securityPermissions = securityPermissions ?? [],
        securitySettings = securitySettings ?? [],
        securityAccessLogs = securityAccessLogs ?? [],
        allowanceItems = allowanceItems ?? [],
        staffingRows = staffingRows ?? [],
        technologyPersonnelItems = technologyPersonnelItems ?? [],
        infrastructureItems = infrastructureItems ?? [],
        opportunityItems = opportunityItems ?? [],
        successCriteriaItems = successCriteriaItems ?? [];

  FrontEndPlanningData copyWith({
    String? requirements,
    String? requirementsPlan,
    String? requirementsNotes,
    String? risks,
    String? opportunities,
    String? contractVendorQuotes,
    String? procurement,
    String? security,
    String? allowance,
    String? summary,
    String? technology,
    String? personnel,
    String? infrastructure,
    String? contracts,
    String? milestoneStartDate,
    String? milestoneEndDate,
    List<RequirementItem>? requirementItems,
    List<ScenarioRecord>? scenarioMatrixItems,
    List<RoleItem>? securityRoles,
    List<PermissionItem>? securityPermissions,
    List<SecuritySetting>? securitySettings,
    List<AccessLogItem>? securityAccessLogs,
    List<DebtItem>? technicalDebtItems,
    List<DebtInsight>? technicalDebtRootCauses,
    List<RemediationTrack>? technicalDebtTracks,
    List<OwnerItem>? technicalDebtOwners,
    List<RiskRegisterItem>? riskRegisterItems,
    List<AllowanceItem>? allowanceItems,
    List<StaffingRow>? staffingRows,
    List<TechnologyPersonnelItem>? technologyPersonnelItems,
    List<InfrastructurePlanningItem>? infrastructureItems,
    List<OpportunityItem>? opportunityItems,
    List<PlanningDashboardItem>? successCriteriaItems,
    bool? detailsConfirmed,
  }) {
    return FrontEndPlanningData(
      requirements: requirements ?? this.requirements,
      requirementsPlan: requirementsPlan ?? this.requirementsPlan,
      requirementsNotes: requirementsNotes ?? this.requirementsNotes,
      risks: risks ?? this.risks,
      opportunities: opportunities ?? this.opportunities,
      contractVendorQuotes: contractVendorQuotes ?? this.contractVendorQuotes,
      procurement: procurement ?? this.procurement,
      security: security ?? this.security,
      allowance: allowance ?? this.allowance,
      summary: summary ?? this.summary,
      technology: technology ?? this.technology,
      personnel: personnel ?? this.personnel,
      infrastructure: infrastructure ?? this.infrastructure,
      contracts: contracts ?? this.contracts,
      milestoneStartDate: milestoneStartDate ?? this.milestoneStartDate,
      milestoneEndDate: milestoneEndDate ?? this.milestoneEndDate,
      requirementItems: requirementItems ?? this.requirementItems,
      scenarioMatrixItems: scenarioMatrixItems ?? this.scenarioMatrixItems,
      securityRoles: securityRoles ?? this.securityRoles,
      securityPermissions: securityPermissions ?? this.securityPermissions,
      securitySettings: securitySettings ?? this.securitySettings,
      securityAccessLogs: securityAccessLogs ?? this.securityAccessLogs,
      technicalDebtItems: technicalDebtItems ?? this.technicalDebtItems,
      technicalDebtRootCauses:
          technicalDebtRootCauses ?? this.technicalDebtRootCauses,
      technicalDebtTracks: technicalDebtTracks ?? this.technicalDebtTracks,
      technicalDebtOwners: technicalDebtOwners ?? this.technicalDebtOwners,
      riskRegisterItems: riskRegisterItems ?? this.riskRegisterItems,
      allowanceItems: allowanceItems ?? this.allowanceItems,
      staffingRows: staffingRows ?? this.staffingRows,
      technologyPersonnelItems:
          technologyPersonnelItems ?? this.technologyPersonnelItems,
      infrastructureItems: infrastructureItems ?? this.infrastructureItems,
      opportunityItems: opportunityItems ?? this.opportunityItems,
      successCriteriaItems: successCriteriaItems ?? this.successCriteriaItems,
      detailsConfirmed: detailsConfirmed ?? this.detailsConfirmed,
    );
  }

  Map<String, dynamic> toJson() => {
        'requirements': requirements,
        'requirementsPlan': requirementsPlan,
        'requirementsNotes': requirementsNotes,
        'risks': risks,
        'opportunities': opportunities,
        'contractVendorQuotes': contractVendorQuotes,
        'procurement': procurement,
        'security': security,
        'allowance': allowance,
        'summary': summary,
        'technology': technology,
        'personnel': personnel,
        'infrastructure': infrastructure,
        'contracts': contracts,
        'milestoneStartDate': milestoneStartDate,
        'milestoneEndDate': milestoneEndDate,
        'allowanceItems': allowanceItems.map((e) => e.toJson()).toList(),
        'staffingRows': staffingRows.map((item) => item.toJson()).toList(),
        'technologyPersonnelItems':
            technologyPersonnelItems.map((item) => item.toJson()).toList(),
        'infrastructureItems':
            infrastructureItems.map((item) => item.toJson()).toList(),
        'opportunityItems':
            opportunityItems.map((item) => item.toJson()).toList(),
        'successCriteriaItems':
            successCriteriaItems.map((item) => item.toJson()).toList(),
        'requirementsItems':
            requirementItems.map((item) => item.toJson()).toList(),
        'riskRegisterItems':
            riskRegisterItems.map((item) => item.toJson()).toList(),
        'technicalDebtItems':
            technicalDebtItems.map((d) => d.toJson()).toList(),
        'technicalDebtRootCauses':
            technicalDebtRootCauses.map((r) => r.toJson()).toList(),
        'technicalDebtTracks':
            technicalDebtTracks.map((t) => t.toJson()).toList(),
        'technicalDebtOwners':
            technicalDebtOwners.map((o) => o.toJson()).toList(),
        'scenarioMatrixItems':
            scenarioMatrixItems.map((s) => s.toJson()).toList(),
        'securityRoles': securityRoles.map((r) => r.toJson()).toList(),
        'securityPermissions':
            securityPermissions.map((p) => p.toJson()).toList(),
        'securitySettings': securitySettings.map((s) => s.toJson()).toList(),
        'securityAccessLogs':
            securityAccessLogs.map((a) => a.toJson()).toList(),
        'detailsConfirmed': detailsConfirmed,
      };

  factory FrontEndPlanningData.fromJson(Map<String, dynamic> json) {
    return FrontEndPlanningData(
      requirements: json['requirements'] ?? '',
      requirementsPlan: json['requirementsPlan'] ?? '',
      requirementsNotes: json['requirementsNotes'] ?? '',
      risks: json['risks'] ?? '',
      opportunities: json['opportunities'] ?? '',
      contractVendorQuotes: json['contractVendorQuotes'] ?? '',
      procurement: json['procurement'] ?? '',
      security: json['security'] ?? '',
      allowance: json['allowance'] ?? '',
      summary: json['summary'] ?? '',
      technology: json['technology'] ?? '',
      personnel: json['personnel'] ?? '',
      infrastructure: json['infrastructure'] ?? '',
      contracts: json['contracts'] ?? '',
      milestoneStartDate: json['milestoneStartDate'] ?? '',
      milestoneEndDate: json['milestoneEndDate'] ?? '',
      allowanceItems: (json['allowanceItems'] as List?)
              ?.map((e) => AllowanceItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      staffingRows: (json['staffingRows'] as List?)
              ?.map(
                  (item) => StaffingRow.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      technologyPersonnelItems: (json['technologyPersonnelItems'] as List?)
              ?.map((item) => TechnologyPersonnelItem.fromJson(
                  item as Map<String, dynamic>))
              .toList() ??
          [],
      infrastructureItems: (json['infrastructureItems'] as List?)
              ?.map((item) => InfrastructurePlanningItem.fromJson(
                  item as Map<String, dynamic>))
              .toList() ??
          [],
      opportunityItems: (json['opportunityItems'] as List?)
              ?.map((e) => OpportunityItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      successCriteriaItems: (json['successCriteriaItems'] as List?)
              ?.map((e) =>
                  PlanningDashboardItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      requirementItems:
          ((json['requirementItems'] ?? json['requirementsItems']) as List?)
                  ?.map((item) =>
                      RequirementItem.fromJson(item as Map<String, dynamic>))
                  .toList() ??
              [],
      riskRegisterItems: (json['riskRegisterItems'] as List?)
              ?.map((item) =>
                  RiskRegisterItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      technicalDebtItems: (json['technicalDebtItems'] as List?)
              ?.map((item) => DebtItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      technicalDebtRootCauses: (json['technicalDebtRootCauses'] as List?)
              ?.map(
                  (item) => DebtInsight.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      technicalDebtTracks: (json['technicalDebtTracks'] as List?)
              ?.map((item) =>
                  RemediationTrack.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      technicalDebtOwners: (json['technicalDebtOwners'] as List?)
              ?.map((item) => OwnerItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      scenarioMatrixItems: (json['scenarioMatrixItems'] as List?)
              ?.map((item) =>
                  ScenarioRecord.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      securityRoles: (json['securityRoles'] as List?)
              ?.map((item) => RoleItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      securityPermissions: (json['securityPermissions'] as List?)
              ?.map((item) =>
                  PermissionItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      securitySettings: (json['securitySettings'] as List?)
              ?.map((item) =>
                  SecuritySetting.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      securityAccessLogs: (json['securityAccessLogs'] as List?)
              ?.map((item) =>
                  AccessLogItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      detailsConfirmed: json['detailsConfirmed'] ?? false,
    );
  }
}

class InfrastructurePlanningItem {
  String id;
  int number;
  String name;
  String summary;
  String details;
  double potentialCost;
  String owner;
  String status;

  InfrastructurePlanningItem({
    String? id,
    this.number = 0,
    this.name = '',
    this.summary = '',
    this.details = '',
    this.potentialCost = 0.0,
    this.owner = '',
    this.status = 'Planned',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  InfrastructurePlanningItem copyWith({
    int? number,
    String? name,
    String? summary,
    String? details,
    double? potentialCost,
    String? owner,
    String? status,
  }) {
    return InfrastructurePlanningItem(
      id: id,
      number: number ?? this.number,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      details: details ?? this.details,
      potentialCost: potentialCost ?? this.potentialCost,
      owner: owner ?? this.owner,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'name': name,
        'summary': summary,
        'details': details,
        'potentialCost': potentialCost,
        'owner': owner,
        'status': status,
      };

  factory InfrastructurePlanningItem.fromJson(Map<String, dynamic> json) {
    return InfrastructurePlanningItem(
      id: json['id']?.toString(),
      number: json['number'] is int
          ? json['number'] as int
          : (json['number'] is num ? (json['number'] as num).toInt() : 0),
      name: json['name']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      potentialCost: json['potentialCost'] is num
          ? (json['potentialCost'] as num).toDouble()
          : double.tryParse(json['potentialCost']?.toString() ?? '') ?? 0.0,
      owner: json['owner']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Planned',
    );
  }
}

class TechnologyPersonnelItem {
  String id;
  int number;
  String technologyArea;
  String primaryOwner;
  String backupSupport;
  String notes;

  TechnologyPersonnelItem({
    required this.id,
    this.number = 0,
    this.technologyArea = '',
    this.primaryOwner = '',
    this.backupSupport = '',
    this.notes = '',
  });

  TechnologyPersonnelItem copyWith({
    String? id,
    int? number,
    String? technologyArea,
    String? primaryOwner,
    String? backupSupport,
    String? notes,
  }) {
    return TechnologyPersonnelItem(
      id: id ?? this.id,
      number: number ?? this.number,
      technologyArea: technologyArea ?? this.technologyArea,
      primaryOwner: primaryOwner ?? this.primaryOwner,
      backupSupport: backupSupport ?? this.backupSupport,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'technologyArea': technologyArea,
        'primaryOwner': primaryOwner,
        'backupSupport': backupSupport,
        'notes': notes,
      };

  factory TechnologyPersonnelItem.fromJson(Map<String, dynamic> json) {
    return TechnologyPersonnelItem(
      id: json['id']?.toString() ?? '',
      number: json['number'] is int
          ? json['number'] as int
          : (json['number'] is num ? (json['number'] as num).toInt() : 0),
      technologyArea: json['technologyArea']?.toString() ??
          json['technology']?.toString() ??
          '',
      primaryOwner:
          json['primaryOwner']?.toString() ?? json['owner']?.toString() ?? '',
      backupSupport: json['backupSupport']?.toString() ??
          json['support']?.toString() ??
          '',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class AllowanceItem {
  String id;
  int number;
  String name;
  String type; // Contingency, Training, Staffing, Tech, Other
  double amount;
  List<String> appliesTo;
  String notes;
  String assignedTo; // Role or person responsible for this allowance
  String releaseStatus;
  double releasedAmount;
  double actualAmount;

  AllowanceItem({
    required this.id,
    this.number = 0,
    this.name = '',
    this.type = 'Other',
    this.amount = 0.0,
    this.appliesTo = const [],
    this.notes = '',
    this.assignedTo = '',
    this.releaseStatus = 'Reserved',
    this.releasedAmount = 0.0,
    this.actualAmount = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'name': name,
        'type': type,
        'amount': amount,
        'appliesTo': appliesTo,
        'notes': notes,
        'assignedTo': assignedTo,
        'releaseStatus': releaseStatus,
        'releasedAmount': releasedAmount,
        'actualAmount': actualAmount,
      };

  factory AllowanceItem.fromJson(Map<String, dynamic> json) {
    return AllowanceItem(
      id: json['id']?.toString() ?? '',
      number: json['number'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Other',
      amount:
          (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      appliesTo:
          (json['appliesTo'] as List?)?.map((e) => e.toString()).toList() ?? [],
      notes: json['notes']?.toString() ?? '',
      assignedTo: json['assignedTo']?.toString() ?? '',
      releaseStatus: json['releaseStatus']?.toString() ?? 'Reserved',
      releasedAmount: (json['releasedAmount'] is num)
          ? (json['releasedAmount'] as num).toDouble()
          : double.tryParse(json['releasedAmount']?.toString() ?? '') ?? 0.0,
      actualAmount: (json['actualAmount'] is num)
          ? (json['actualAmount'] as num).toDouble()
          : double.tryParse(json['actualAmount']?.toString() ?? '') ?? 0.0,
    );
  }
}

class OpportunityItem {
  String id;
  String opportunity;
  String discipline;
  String stakeholder;
  String responsibleRole;
  String potentialCostSavings;
  String potentialScheduleSavings;
  String implementationStrategy;
  String applicablePhase;
  String owner;
  String status;
  List<String> appliesTo;
  String assignedTo;
  String impact;

  /// Whether this opportunity has been accepted (applied to cost estimate)
  bool isAccepted;

  OpportunityItem({
    required this.id,
    this.opportunity = '',
    this.discipline = '',
    this.stakeholder = '',
    this.responsibleRole = '',
    this.potentialCostSavings = '',
    this.potentialScheduleSavings = '',
    this.implementationStrategy = '',
    this.applicablePhase = '',
    this.owner = '',
    this.status = 'Identified',
    this.appliesTo = const [],
    this.assignedTo = '',
    this.impact = 'Medium',
    this.isAccepted = false,
  });

  OpportunityItem copyWithAcceptance({required bool accepted}) {
    // Build the appliesTo list immutably — add 'Estimate' when accepting
    final newAppliesTo = accepted && !appliesTo.contains('Estimate')
        ? [...appliesTo, 'Estimate']
        : List<String>.from(appliesTo);
    return OpportunityItem(
      id: id,
      opportunity: opportunity,
      discipline: discipline,
      stakeholder: stakeholder,
      responsibleRole: responsibleRole,
      potentialCostSavings: potentialCostSavings,
      potentialScheduleSavings: potentialScheduleSavings,
      implementationStrategy: implementationStrategy,
      applicablePhase: applicablePhase,
      owner: owner,
      status: status,
      appliesTo: newAppliesTo,
      assignedTo: assignedTo,
      impact: impact,
      isAccepted: accepted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'opportunity': opportunity,
        'discipline': discipline,
        'stakeholder': stakeholder,
        'responsibleRole': responsibleRole,
        'potentialCostSavings': potentialCostSavings,
        'potentialScheduleSavings': potentialScheduleSavings,
        'implementationStrategy': implementationStrategy,
        'applicablePhase': applicablePhase,
        'owner': owner,
        'status': status,
        'appliesTo': appliesTo,
        'assignedTo': assignedTo,
        'impact': impact,
        'isAccepted': isAccepted,
      };

  factory OpportunityItem.fromJson(Map<String, dynamic> json) {
    // Migration: If 'isApplied' exists and is true, add 'Estimate' to appliesTo
    List<String> appliesTo = [];
    if (json['appliesTo'] != null) {
      appliesTo = List<String>.from(json['appliesTo']);
    } else if (json['isApplied'] == true) {
      appliesTo = ['Estimate'];
    }

    return OpportunityItem(
      id: json['id']?.toString() ?? '',
      opportunity: json['opportunity']?.toString() ?? '',
      discipline: json['discipline']?.toString() ?? '',
      stakeholder: json['stakeholder']?.toString() ?? '',
      responsibleRole: json['responsibleRole']?.toString() ??
          json['stakeholder']?.toString() ??
          '',
      potentialCostSavings: json['potentialCostSavings']?.toString() ?? '',
      potentialScheduleSavings:
          json['potentialScheduleSavings']?.toString() ?? '',
      implementationStrategy: json['implementationStrategy']?.toString() ?? '',
      applicablePhase: json['applicablePhase']?.toString() ??
          ((appliesTo.isNotEmpty) ? appliesTo.join(', ') : ''),
      owner: json['owner']?.toString() ?? json['assignedTo']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Identified',
      appliesTo: appliesTo,
      assignedTo: json['assignedTo']?.toString() ?? '',
      impact: json['impact']?.toString() ?? 'Medium',
      isAccepted: json['isAccepted'] == true,
    );
  }
}

class RiskRegisterItem {
  String riskName;
  String description;
  String category;
  String requirement;
  String requirementType;
  String impactLevel;
  String likelihood;
  String mitigationStrategy;
  String discipline;
  String projectRole;
  String owner;
  String status;

  // ── P3.6: Quantitative risk analysis fields ──
  /// Numeric probability (0-1) for EMV and Monte Carlo calculations.
  double probabilityNumeric;

  /// Minimum cost impact if risk materializes.
  double costImpactMin;

  /// Most likely cost impact if risk materializes.
  double costImpactMostLikely;

  /// Maximum cost impact if risk materializes.
  double costImpactMax;

  /// Minimum schedule impact (days) if risk materializes.
  int scheduleImpactMin;

  /// Most likely schedule impact (days) if risk materializes.
  int scheduleImpactMostLikely;

  /// Maximum schedule impact (days) if risk materializes.
  int scheduleImpactMax;

  /// Control Account ID affected by this risk.
  String controlAccountId;

  /// CBS element ID for cost risk allocation.
  String cbsId;

  /// Whether this is a threat (negative) or opportunity (positive).
  String riskType; // 'threat' | 'opportunity'
  /// Risk response strategy category.
  String
      responseStrategy; // 'avoid' | 'mitigate' | 'transfer' | 'accept' | 'exploit' | 'enhance' | 'share'
  /// Residual probability after mitigation.
  double? residualProbability;

  /// Residual cost impact after mitigation.
  double? residualCostImpact;

  RiskRegisterItem({
    this.riskName = '',
    this.description = '',
    this.category = '',
    this.requirement = '',
    this.requirementType = '',
    this.impactLevel = '',
    this.likelihood = '',
    this.mitigationStrategy = '',
    this.discipline = '',
    this.projectRole = '',
    this.owner = '',
    this.status = '',
    this.probabilityNumeric = 0,
    this.costImpactMin = 0,
    this.costImpactMostLikely = 0,
    this.costImpactMax = 0,
    this.scheduleImpactMin = 0,
    this.scheduleImpactMostLikely = 0,
    this.scheduleImpactMax = 0,
    this.controlAccountId = '',
    this.cbsId = '',
    this.riskType = 'threat',
    this.responseStrategy = 'accept',
    this.residualProbability,
    this.residualCostImpact,
  });

  /// ── P3.6: Computed quantitative metrics ──
  /// Expected Monetary Value = probability × most likely cost impact.
  double get emv => probabilityNumeric * costImpactMostLikely;

  /// PERT mean of cost impact = (min + 4×mostLikely + max) / 6.
  double get pertCostImpact =>
      (costImpactMin + 4 * costImpactMostLikely + costImpactMax) / 6;

  /// PERT mean of schedule impact = (min + 4×mostLikely + max) / 6.
  double get pertScheduleImpact =>
      (scheduleImpactMin + 4 * scheduleImpactMostLikely + scheduleImpactMax) /
      6;

  /// Residual EMV after mitigation.
  double get residualEmv =>
      (residualProbability ?? probabilityNumeric) *
      (residualCostImpact ?? costImpactMostLikely);

  Map<String, dynamic> toJson() => {
        'riskName': riskName,
        'description': description,
        'category': category,
        'requirement': requirement,
        'requirementType': requirementType,
        'impactLevel': impactLevel,
        'likelihood': likelihood,
        'mitigationStrategy': mitigationStrategy,
        'discipline': discipline,
        'projectRole': projectRole,
        'owner': owner,
        'status': status,
        'probabilityNumeric': probabilityNumeric,
        'costImpactMin': costImpactMin,
        'costImpactMostLikely': costImpactMostLikely,
        'costImpactMax': costImpactMax,
        'scheduleImpactMin': scheduleImpactMin,
        'scheduleImpactMostLikely': scheduleImpactMostLikely,
        'scheduleImpactMax': scheduleImpactMax,
        'controlAccountId': controlAccountId,
        'cbsId': cbsId,
        'riskType': riskType,
        'responseStrategy': responseStrategy,
        'residualProbability': residualProbability,
        'residualCostImpact': residualCostImpact,
      };

  factory RiskRegisterItem.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    int toInt(dynamic v) =>
        (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    return RiskRegisterItem(
      riskName: json['riskName']?.toString() ?? json['risk']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      requirement: json['requirement']?.toString() ?? '',
      requirementType: json['requirementType']?.toString() ??
          json['requirement_type']?.toString() ??
          '',
      impactLevel:
          json['impactLevel']?.toString() ?? json['impact']?.toString() ?? '',
      likelihood: json['likelihood']?.toString() ??
          json['probability']?.toString() ??
          '',
      mitigationStrategy: json['mitigationStrategy']?.toString() ??
          json['mitigation']?.toString() ??
          '',
      discipline: json['discipline']?.toString() ?? '',
      projectRole:
          json['projectRole']?.toString() ?? json['role']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      probabilityNumeric: toDouble(json['probabilityNumeric']),
      costImpactMin: toDouble(json['costImpactMin']),
      costImpactMostLikely: toDouble(json['costImpactMostLikely']),
      costImpactMax: toDouble(json['costImpactMax']),
      scheduleImpactMin: toInt(json['scheduleImpactMin']),
      scheduleImpactMostLikely: toInt(json['scheduleImpactMostLikely']),
      scheduleImpactMax: toInt(json['scheduleImpactMax']),
      controlAccountId: json['controlAccountId']?.toString() ?? '',
      cbsId: json['cbsId']?.toString() ?? '',
      riskType: json['riskType']?.toString() ?? 'threat',
      responseStrategy: json['responseStrategy']?.toString() ?? 'accept',
      residualProbability: json['residualProbability'] is num
          ? (json['residualProbability'] as num).toDouble()
          : null,
      residualCostImpact: json['residualCostImpact'] is num
          ? (json['residualCostImpact'] as num).toDouble()
          : null,
    );
  }
}

class ExecutionRiskItem {
  final String id;
  final String title;
  final String description;
  final String category;
  final String owner;
  final int likelihoodScore;
  final int impactScore;
  final String probability;
  final String impact;
  final int riskScore;
  final String status;
  final String triggerEvents;
  final String mitigationStrategy;
  final String nextReview;
  final String associatedMitigation;
  final String createdAt;
  final String lastModified;
  final String controlAccountId;

  const ExecutionRiskItem({
    required this.id,
    this.title = '',
    this.description = '',
    this.category = 'General',
    this.owner = '',
    this.likelihoodScore = 0,
    this.impactScore = 0,
    this.probability = '',
    this.impact = '',
    this.riskScore = 0,
    this.status = '',
    this.triggerEvents = '',
    this.mitigationStrategy = '',
    this.nextReview = '',
    this.associatedMitigation = '',
    this.createdAt = '',
    this.lastModified = '',
    this.controlAccountId = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'owner': owner,
        'likelihoodScore': likelihoodScore,
        'impactScore': impactScore,
        'probability': probability,
        'impact': impact,
        'riskScore': riskScore,
        'status': status,
        'triggerEvents': triggerEvents,
        'mitigationStrategy': mitigationStrategy,
        'nextReview': nextReview,
        'associatedMitigation': associatedMitigation,
        'createdAt': createdAt,
        'lastModified': lastModified,
        'controlAccountId': controlAccountId,
      };

  factory ExecutionRiskItem.fromJson(Map<String, dynamic> json) {
    return ExecutionRiskItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      owner: json['owner']?.toString() ?? '',
      likelihoodScore: json['likelihoodScore'] as int? ?? 0,
      impactScore: json['impactScore'] as int? ?? 0,
      probability: json['probability']?.toString() ?? '',
      impact: json['impact']?.toString() ?? '',
      riskScore: json['riskScore'] as int? ?? 0,
      status: json['status']?.toString() ?? '',
      triggerEvents: json['triggerEvents']?.toString() ?? '',
      mitigationStrategy: json['mitigationStrategy']?.toString() ?? '',
      nextReview: json['nextReview']?.toString() ?? '',
      associatedMitigation: json['associatedMitigation']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      lastModified: json['lastModified']?.toString() ?? '',
      controlAccountId: json['controlAccountId']?.toString() ?? '',
    );
  }
}

class ExecutionRiskSignal {
  final String id;
  final String title;
  final String detail;
  final String severity;
  final String source;
  final String dateDetected;
  final String confidenceLevel;
  final String associatedRiskId;

  const ExecutionRiskSignal({
    required this.id,
    this.title = '',
    this.detail = '',
    this.severity = '',
    this.source = '',
    this.dateDetected = '',
    this.confidenceLevel = '',
    this.associatedRiskId = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'detail': detail,
        'severity': severity,
        'source': source,
        'dateDetected': dateDetected,
        'confidenceLevel': confidenceLevel,
        'associatedRiskId': associatedRiskId,
      };

  factory ExecutionRiskSignal.fromJson(Map<String, dynamic> json) {
    return ExecutionRiskSignal(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      dateDetected: json['dateDetected']?.toString() ?? '',
      confidenceLevel: json['confidenceLevel']?.toString() ?? '',
      associatedRiskId: json['associatedRiskId']?.toString() ?? '',
    );
  }
}

class ExecutionRiskMitigation {
  final String id;
  final String title;
  final String description;
  final String owner;
  final String status;
  final String dueDate;
  final int progress;
  final String estimatedCost;
  final String statusNotes;
  final String associatedRiskId;
  final String associatedRiskTitle;
  final String createdAt;

  const ExecutionRiskMitigation({
    required this.id,
    this.title = '',
    this.description = '',
    this.owner = '',
    this.status = '',
    this.dueDate = '',
    this.progress = 0,
    this.estimatedCost = '',
    this.statusNotes = '',
    this.associatedRiskId = '',
    this.associatedRiskTitle = '',
    this.createdAt = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'owner': owner,
        'status': status,
        'dueDate': dueDate,
        'progress': progress,
        'estimatedCost': estimatedCost,
        'statusNotes': statusNotes,
        'associatedRiskId': associatedRiskId,
        'associatedRiskTitle': associatedRiskTitle,
        'createdAt': createdAt,
      };

  factory ExecutionRiskMitigation.fromJson(Map<String, dynamic> json) {
    return ExecutionRiskMitigation(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      dueDate: json['dueDate']?.toString() ?? '',
      progress: json['progress'] as int? ?? 0,
      estimatedCost: json['estimatedCost']?.toString() ?? '',
      statusNotes: json['statusNotes']?.toString() ?? '',
      associatedRiskId: json['associatedRiskId']?.toString() ?? '',
      associatedRiskTitle: json['associatedRiskTitle']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class RoleItem {
  String id;
  String name;
  String description;

  RoleItem({String? id, this.name = '', this.description = ''})
      : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'description': description};

  factory RoleItem.fromJson(Map<String, dynamic> json) {
    return RoleItem(
        id: json['id']?.toString(),
        name: json['name'] ?? '',
        description: json['description'] ?? '');
  }
}

class PermissionItem {
  String id;
  String resource;
  String scope;

  PermissionItem({String? id, this.resource = '', this.scope = ''})
      : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() =>
      {'id': id, 'resource': resource, 'scope': scope};

  factory PermissionItem.fromJson(Map<String, dynamic> json) {
    return PermissionItem(
        id: json['id']?.toString(),
        resource: json['resource'] ?? '',
        scope: json['scope'] ?? '');
  }
}

class SecuritySetting {
  String key;
  String value;

  SecuritySetting({this.key = '', this.value = ''});

  Map<String, dynamic> toJson() => {'key': key, 'value': value};

  factory SecuritySetting.fromJson(Map<String, dynamic> json) {
    return SecuritySetting(key: json['key'] ?? '', value: json['value'] ?? '');
  }
}

class AccessLogItem {
  String id;
  String user;
  String action;
  String timestamp;

  AccessLogItem(
      {String? id, this.user = '', this.action = '', this.timestamp = ''})
      : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() =>
      {'id': id, 'user': user, 'action': action, 'timestamp': timestamp};

  factory AccessLogItem.fromJson(Map<String, dynamic> json) {
    return AccessLogItem(
      id: json['id']?.toString(),
      user: json['user'] ?? '',
      action: json['action'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class SSHERData {
  List<SafetyItem> safetyItems;
  List<SsherEntry> entries;
  String screen1Data;
  String screen2Data;
  String screen3Data;
  String screen4Data;

  SSHERData({
    List<SafetyItem>? safetyItems,
    List<SsherEntry>? entries,
    this.screen1Data = '',
    this.screen2Data = '',
    this.screen3Data = '',
    this.screen4Data = '',
  })  : safetyItems = safetyItems ?? [],
        entries = entries ?? [];

  Map<String, dynamic> toJson() => {
        'safetyItems': safetyItems.map((s) => s.toJson()).toList(),
        'entries': entries.map((e) => e.toJson()).toList(),
        'screen1Data': screen1Data,
        'screen2Data': screen2Data,
        'screen3Data': screen3Data,
        'screen4Data': screen4Data,
      };

  factory SSHERData.fromJson(Map<String, dynamic> json) {
    return SSHERData(
      safetyItems: (json['safetyItems'] as List?)
              ?.map((s) => SafetyItem.fromJson(s))
              .toList() ??
          [],
      entries: (json['entries'] as List?)
              ?.map((e) => SsherEntry.fromJson(e))
              .toList() ??
          [],
      screen1Data: json['screen1Data'] ?? '',
      screen2Data: json['screen2Data'] ?? '',
      screen3Data: json['screen3Data'] ?? '',
      screen4Data: json['screen4Data'] ?? '',
    );
  }

  SSHERData copyWith({
    List<SafetyItem>? safetyItems,
    List<SsherEntry>? entries,
    String? screen1Data,
    String? screen2Data,
    String? screen3Data,
    String? screen4Data,
  }) {
    return SSHERData(
      safetyItems: safetyItems ?? this.safetyItems,
      entries: entries ?? this.entries,
      screen1Data: screen1Data ?? this.screen1Data,
      screen2Data: screen2Data ?? this.screen2Data,
      screen3Data: screen3Data ?? this.screen3Data,
      screen4Data: screen4Data ?? this.screen4Data,
    );
  }
}

class SsherEntry {
  String id;
  String category;
  String department;
  String teamMember;
  String concern;
  String riskLevel;
  String mitigation;

  SsherEntry({
    String? id,
    this.category = '',
    this.department = '',
    this.teamMember = '',
    this.concern = '',
    this.riskLevel = '',
    this.mitigation = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'department': department,
        'teamMember': teamMember,
        'concern': concern,
        'riskLevel': riskLevel,
        'mitigation': mitigation,
      };

  factory SsherEntry.fromJson(Map<String, dynamic> json) {
    return SsherEntry(
      id: json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
      category: json['category'] ?? '',
      department: json['department'] ?? '',
      teamMember: json['teamMember'] ?? '',
      concern: json['concern'] ?? '',
      riskLevel: json['riskLevel'] ?? '',
      mitigation: json['mitigation'] ?? '',
    );
  }
}

class SafetyItem {
  String title;
  String description;
  String category;

  SafetyItem({
    this.title = '',
    this.description = '',
    this.category = '',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'category': category,
      };

  factory SafetyItem.fromJson(Map<String, dynamic> json) {
    return SafetyItem(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
    );
  }
}

class PotentialSolution {
  final String id;
  int number;
  String title;
  String description;
  Map<String, FieldHistory> fieldHistories;

  PotentialSolution({
    required this.id,
    required this.number,
    this.title = '',
    this.description = '',
    Map<String, FieldHistory>? fieldHistories,
  }) : fieldHistories = fieldHistories ?? {};

  /// Factory constructor for creating empty solutions
  factory PotentialSolution.empty({
    required String id,
    required int number,
  }) {
    return PotentialSolution(
      id: id,
      number: number,
      title: '',
      description: '',
      fieldHistories: {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'title': title,
        'description': description,
        'fieldHistories':
            fieldHistories.map((key, value) => MapEntry(key, value.toJson())),
      };

  factory PotentialSolution.fromJson(Map<String, dynamic> json) {
    return PotentialSolution(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      number: (json['number'] is num) ? (json['number'] as num).toInt() : 1,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      fieldHistories: (json['fieldHistories'] is Map)
          ? Map<String, FieldHistory>.from(
              (json['fieldHistories'] as Map).map((key, value) {
                try {
                  return MapEntry(
                    key.toString(),
                    FieldHistory.fromJson(value as Map<String, dynamic>),
                  );
                } catch (e) {
                  return MapEntry(
                    key.toString(),
                    FieldHistory(fieldName: key.toString()),
                  );
                }
              }),
            )
          : {},
    );
  }

  PotentialSolution copyWith({
    String? id,
    int? number,
    String? title,
    String? description,
    Map<String, FieldHistory>? fieldHistories,
  }) {
    return PotentialSolution(
      id: id ?? this.id,
      number: number ?? this.number,
      title: title ?? this.title,
      description: description ?? this.description,
      fieldHistories: fieldHistories ?? this.fieldHistories,
    );
  }
}

class LessonRecord {
  String id;
  String lesson;
  String category;
  String type;
  String phase;
  String status;
  String submittedBy;
  String notes;
  String impact;
  bool highlight;
  DateTime? dateSubmitted;

  LessonRecord({
    String? id,
    this.lesson = '',
    this.category = '',
    this.type = '',
    this.phase = '',
    this.status = '',
    this.submittedBy = '',
    this.notes = '',
    this.impact = 'Medium',
    this.highlight = false,
    this.dateSubmitted,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson': lesson,
        'category': category,
        'type': type,
        'phase': phase,
        'status': status,
        'submittedBy': submittedBy,
        'notes': notes,
        'impact': impact,
        'highlight': highlight,
        'dateSubmitted': dateSubmitted?.toIso8601String(),
      };

  factory LessonRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parsed;
    try {
      if (json['dateSubmitted'] is String) {
        parsed = DateTime.parse(json['dateSubmitted']);
      }
    } catch (_) {}
    return LessonRecord(
      id: json['id']?.toString(),
      lesson: json['lesson'] ?? '',
      category: json['category'] ?? '',
      type: json['type'] ?? '',
      phase: json['phase'] ?? '',
      status: json['status'] ?? '',
      submittedBy: json['submittedBy'] ?? '',
      notes: json['notes'] ?? '',
      impact: json['impact'] ?? 'Medium',
      highlight: json['highlight'] == true,
      dateSubmitted: parsed,
    );
  }
}

class SolutionRisk {
  String solutionTitle;
  List<String> risks;

  SolutionRisk({
    this.solutionTitle = '',
    List<String>? risks,
  }) : risks = risks ?? ['', '', ''];

  Map<String, dynamic> toJson() => {
        'solutionTitle': solutionTitle,
        'risks': risks,
      };

  factory SolutionRisk.fromJson(Map<String, dynamic> json) {
    final riskList =
        (json['risks'] as List?)?.map((r) => r.toString()).toList() ??
            ['', '', ''];
    // Ensure we always have 3 risks
    while (riskList.length < 3) {
      riskList.add('');
    }
    return SolutionRisk(
      solutionTitle: json['solutionTitle'] ?? '',
      risks: riskList.take(3).toList(),
    );
  }
}

class TeamMember {
  String id;
  String name;
  String role;
  String email;
  String responsibilities;

  TeamMember({
    String? id,
    this.name = '',
    this.role = '',
    this.email = '',
    this.responsibilities = '',
  }) : id = id ?? _generateId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'email': email,
        'responsibilities': responsibilities,
      };

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      email: json['email'] ?? '',
      responsibilities: json['responsibilities'] ?? '',
    );
  }

  static String _generateId() =>
      DateTime.now().microsecondsSinceEpoch.toString();
}

class PreferredSolutionAnalysis {
  String workingNotes;
  List<SolutionAnalysisItem> solutionAnalyses;
  String? selectedSolutionTitle;
  String? selectedSolutionId; // UUID/ID for reliable matching
  int? selectedSolutionIndex; // Index fallback for matching
  bool isSelectionFinalized;

  PreferredSolutionAnalysis({
    this.workingNotes = '',
    List<SolutionAnalysisItem>? solutionAnalyses,
    this.selectedSolutionTitle,
    this.selectedSolutionId,
    this.selectedSolutionIndex,
    this.isSelectionFinalized = false,
  }) : solutionAnalyses = solutionAnalyses ?? [];

  Map<String, dynamic> toJson() => {
        'workingNotes': workingNotes,
        'solutionAnalyses': solutionAnalyses.map((s) => s.toJson()).toList(),
        'selectedSolutionTitle': selectedSolutionTitle,
        'selectedSolutionId': selectedSolutionId,
        'selectedSolutionIndex': selectedSolutionIndex,
        'isSelectionFinalized': isSelectionFinalized,
      };

  factory PreferredSolutionAnalysis.fromJson(Map<String, dynamic> json) {
    return PreferredSolutionAnalysis(
      workingNotes: json['workingNotes'] ?? '',
      solutionAnalyses: (json['solutionAnalyses'] as List?)
              ?.map((s) => SolutionAnalysisItem.fromJson(s))
              .toList() ??
          [],
      selectedSolutionTitle: json['selectedSolutionTitle'],
      selectedSolutionId: json['selectedSolutionId']?.toString(),
      selectedSolutionIndex: json['selectedSolutionIndex'] is int
          ? json['selectedSolutionIndex'] as int
          : (json['selectedSolutionIndex'] != null
              ? int.tryParse(json['selectedSolutionIndex'].toString())
              : null),
      isSelectionFinalized: json['isSelectionFinalized'] == true,
    );
  }
}

class SolutionAnalysisItem {
  String solutionTitle;
  String solutionDescription;
  List<String> stakeholders;
  List<String> risks;
  List<String> technologies;
  List<String> infrastructure;
  List<CostItem> costs;
  String? itConsiderationText;
  String? infraConsiderationText;

  SolutionAnalysisItem({
    this.solutionTitle = '',
    this.solutionDescription = '',
    List<String>? stakeholders,
    List<String>? risks,
    List<String>? technologies,
    List<String>? infrastructure,
    List<CostItem>? costs,
    this.itConsiderationText,
    this.infraConsiderationText,
  })  : stakeholders = stakeholders ?? [],
        risks = risks ?? [],
        technologies = technologies ?? [],
        infrastructure = infrastructure ?? [],
        costs = costs ?? [];

  Map<String, dynamic> toJson() => {
        'solutionTitle': solutionTitle,
        'solutionDescription': solutionDescription,
        'stakeholders': stakeholders,
        'risks': risks,
        'technologies': technologies,
        'infrastructure': infrastructure,
        'costs': costs.map((c) => c.toJson()).toList(),
        'itConsiderationText': itConsiderationText,
        'infraConsiderationText': infraConsiderationText,
      };

  factory SolutionAnalysisItem.fromJson(Map<String, dynamic> json) {
    return SolutionAnalysisItem(
      solutionTitle: json['solutionTitle'] ?? '',
      solutionDescription: json['solutionDescription'] ?? '',
      stakeholders: List<String>.from(json['stakeholders'] ?? []),
      risks: List<String>.from(json['risks'] ?? []),
      technologies: List<String>.from(json['technologies'] ?? []),
      infrastructure: List<String>.from(json['infrastructure'] ?? []),
      costs:
          (json['costs'] as List?)?.map((c) => CostItem.fromJson(c)).toList() ??
              [],
      itConsiderationText: json['itConsiderationText'],
      infraConsiderationText: json['infraConsiderationText'],
    );
  }
}

class CostItem {
  String item;
  String description;
  double estimatedCost;
  double roiPercent;
  Map<int, double> npvByYear;
  String controlAccountId;
  String cbsId;

  CostItem({
    this.item = '',
    this.description = '',
    this.estimatedCost = 0.0,
    this.roiPercent = 0.0,
    Map<int, double>? npvByYear,
    this.controlAccountId = '',
    this.cbsId = '',
  }) : npvByYear = npvByYear ?? {};

  Map<String, dynamic> toJson() => {
        'item': item,
        'description': description,
        'estimatedCost': estimatedCost,
        'roiPercent': roiPercent,
        'npvByYear':
            npvByYear.map((key, value) => MapEntry(key.toString(), value)),
        'controlAccountId': controlAccountId,
        'cbsId': cbsId,
      };

  factory CostItem.fromJson(Map<String, dynamic> json) {
    final npvMap = json['npvByYear'] as Map?;
    final convertedNpv = <int, double>{};
    if (npvMap != null) {
      npvMap.forEach((key, value) {
        final intKey = int.tryParse(key.toString()) ?? 0;
        final doubleValue = (value is num) ? value.toDouble() : 0.0;
        convertedNpv[intKey] = doubleValue;
      });
    }

    return CostItem(
      item: json['item'] ?? '',
      description: json['description'] ?? '',
      estimatedCost: (json['estimatedCost'] is num)
          ? (json['estimatedCost'] as num).toDouble()
          : 0.0,
      roiPercent: (json['roiPercent'] is num)
          ? (json['roiPercent'] as num).toDouble()
          : 0.0,
      npvByYear: convertedNpv,
      controlAccountId: json['controlAccountId']?.toString() ?? '',
      cbsId: json['cbsId']?.toString() ?? '',
    );
  }
}

class CostEstimateItem {
  String id;
  String title;
  String notes;
  double amount;
  String costType;
  String source;
  String costState; // 'forecast' | 'committed' | 'actual'
  bool isBaseline;
  // Schedule & work package linkage
  String scheduleActivityId;
  String wbsItemId;
  String workPackageId;
  String workPackageTitle;
  String phase; // 'design' | 'execution' | 'launch'
  // Estimating method fields
  String
      estimatingMethod; // 'bottoms_up' | 'top_down' | 'unit_rate' | 'analogous'
  String estimatingBasis;
  double unitRate;
  int quantity;
  String unitOfMeasure;
  // Contingency
  double contingencyPercent;
  double contingencyAmount;
  // Structured BOE fields (P1)
  String scopeIncluded;
  String scopeExcluded;
  String
      designMaturity; // '10%' | '30%' | '60%' | '90%' | 'IFC' | 'AsBuilt' | ''
  String designMaturityNote;
  String
      rateSource; // 'vendor_quote' | 'historical' | 'published_index' | 'benchmark' | 'expert_judgment' | ''
  // PERT risk ranges (P1)
  double rangeLow;
  double rangeHigh;
  // Contract linkage
  String contractId;
  String quoteReference;
  String reconciliationReference;
  String controlAccountId;
  String cbsId;

  CostEstimateItem({
    String? id,
    this.title = '',
    this.notes = '',
    this.amount = 0.0,
    this.costType = 'direct',
    this.source = 'manual',
    this.costState = 'forecast',
    this.isBaseline = false,
    this.scheduleActivityId = '',
    this.wbsItemId = '',
    this.workPackageId = '',
    this.workPackageTitle = '',
    this.phase = '',
    this.estimatingMethod = 'manual',
    this.estimatingBasis = '',
    this.unitRate = 0,
    this.quantity = 0,
    this.unitOfMeasure = '',
    this.contingencyPercent = 0,
    this.contingencyAmount = 0,
    this.scopeIncluded = '',
    this.scopeExcluded = '',
    this.designMaturity = '',
    this.designMaturityNote = '',
    this.rateSource = '',
    this.rangeLow = 0,
    this.rangeHigh = 0,
    this.contractId = '',
    this.quoteReference = '',
    this.reconciliationReference = '',
    this.controlAccountId = '',
    this.cbsId = '',
  }) : id = id ?? _generateId();

  double get pertMean => (rangeLow > 0 && rangeHigh > 0 && amount > 0)
      ? (rangeLow + 4 * amount + rangeHigh) / 6
      : amount;

  double get pertExposure => pertMean - amount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'amount': amount,
        'costType': costType,
        'source': source,
        'costState': costState,
        'isBaseline': isBaseline,
        'scheduleActivityId': scheduleActivityId,
        'wbsItemId': wbsItemId,
        'workPackageId': workPackageId,
        'workPackageTitle': workPackageTitle,
        'phase': phase,
        'estimatingMethod': estimatingMethod,
        'estimatingBasis': estimatingBasis,
        'unitRate': unitRate,
        'quantity': quantity,
        'unitOfMeasure': unitOfMeasure,
        'contingencyPercent': contingencyPercent,
        'contingencyAmount': contingencyAmount,
        'scopeIncluded': scopeIncluded,
        'scopeExcluded': scopeExcluded,
        'designMaturity': designMaturity,
        'designMaturityNote': designMaturityNote,
        'rateSource': rateSource,
        'rangeLow': rangeLow,
        'rangeHigh': rangeHigh,
        'contractId': contractId,
        'quoteReference': quoteReference,
        'reconciliationReference': reconciliationReference,
        'controlAccountId': controlAccountId,
        'cbsId': cbsId,
      };

  factory CostEstimateItem.fromJson(Map<String, dynamic> json) {
    return CostEstimateItem(
      id: json['id']?.toString(),
      title: json['title'] ?? '',
      notes: json['notes'] ?? '',
      amount:
          (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      costType: json['costType']?.toString() ?? 'direct',
      source: json['source']?.toString() ?? 'manual',
      costState: json['costState']?.toString() ?? 'forecast',
      isBaseline: json['isBaseline'] == true,
      scheduleActivityId: json['scheduleActivityId']?.toString() ?? '',
      wbsItemId: json['wbsItemId']?.toString() ?? '',
      workPackageId: json['workPackageId']?.toString() ?? '',
      workPackageTitle: json['workPackageTitle']?.toString() ?? '',
      phase: json['phase']?.toString() ?? '',
      estimatingMethod: json['estimatingMethod']?.toString() ?? 'manual',
      estimatingBasis: json['estimatingBasis']?.toString() ?? '',
      unitRate: json['unitRate'] is num
          ? (json['unitRate'] as num).toDouble()
          : double.tryParse(json['unitRate']?.toString() ?? '') ?? 0,
      quantity: json['quantity'] is num
          ? (json['quantity'] as num).round()
          : int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      unitOfMeasure: json['unitOfMeasure']?.toString() ?? '',
      contingencyPercent: json['contingencyPercent'] is num
          ? (json['contingencyPercent'] as num).toDouble()
          : double.tryParse(json['contingencyPercent']?.toString() ?? '') ?? 0,
      contingencyAmount: json['contingencyAmount'] is num
          ? (json['contingencyAmount'] as num).toDouble()
          : double.tryParse(json['contingencyAmount']?.toString() ?? '') ?? 0,
      scopeIncluded: json['scopeIncluded']?.toString() ?? '',
      scopeExcluded: json['scopeExcluded']?.toString() ?? '',
      designMaturity: json['designMaturity']?.toString() ?? '',
      designMaturityNote: json['designMaturityNote']?.toString() ?? '',
      rateSource: json['rateSource']?.toString() ?? '',
      rangeLow: json['rangeLow'] is num
          ? (json['rangeLow'] as num).toDouble()
          : double.tryParse(json['rangeLow']?.toString() ?? '') ?? 0,
      rangeHigh: json['rangeHigh'] is num
          ? (json['rangeHigh'] as num).toDouble()
          : double.tryParse(json['rangeHigh']?.toString() ?? '') ?? 0,
      contractId: json['contractId']?.toString() ?? '',
      quoteReference: json['quoteReference']?.toString() ?? '',
      reconciliationReference:
          json['reconciliationReference']?.toString() ?? '',
      controlAccountId: json['controlAccountId']?.toString() ?? '',
      cbsId: json['cbsId']?.toString() ?? '',
    );
  }

  static String _generateId() =>
      DateTime.now().microsecondsSinceEpoch.toString();
}

class WorkPackage {
  String id;
  String wbsItemId;
  String wbsLevel2Id;
  String wbsLevel2Title;
  String sourceWbsLevel3Id;
  String sourceWbsLevel3Title;
  int packageLevel;
  String packageCode;
  String
      packageClassification; // engineeringEwp | procurementPackage | constructionCwp | implementationWorkPackage | agileIterationPackage
  String parentPackageId;
  List<String> childPackageIds;
  List<String> linkedEngineeringPackageIds;
  List<String> linkedProcurementPackageIds;
  List<String> linkedExecutionPackageIds;
  String title;
  String description;
  String
      type; // 'design' | 'construction' | 'execution' | 'agile' | 'procurement' | 'delivery'
  String phase; // 'design' | 'execution' | 'launch'
  String
      status; // 'planned' | 'in_progress' | 'complete' | 'blocked' | 'on_hold'
  String owner;
  String discipline;
  String? plannedStart;
  String? plannedEnd;
  String? actualStart;
  String? actualEnd;
  double budgetedCost;
  double actualCost;
  double plannedHours;
  double actualHours;
  List<String> scheduleActivityIds;
  List<String> contractIds;
  List<String> vendorIds;
  List<String> requirementIds;
  List<PackageDeliverable> deliverables;
  String acceptingCriteria;
  String designPackageId;
  List<String> procurementItemIds;
  List<String> milestoneIds;
  String areaOrSystem;
  String contractorOrCrew;
  String releaseStatus;

  /// Date when the EWP was released for execution (Guide Step 2 / Fix 1.4).
  /// Null means not yet released. Only set when releaseStatus is 'released'.
  String? releaseForExecutionDate;

  /// IDs of design specification rows from DesignPlanningDocument
  /// that are linked to this package (Guide Step 2 / Fix 1.2).
  /// For EWPs, these are the specs this package must produce deliverables for.
  /// For procurement packages, these are specs whose deliverables feed this package.
  List<String> linkedDesignSpecificationIds;
  PackageReadinessChecklist readiness;
  PackageEstimateBasis estimateBasis;
  PackageProcurementBreakdown procurementBreakdown;
  List<String> readinessWarnings;
  String notes;
  String controlAccountId;

  /// Physical percent complete (0.0 - 1.0). Used for Earned Value calculation.
  /// EV = percentComplete × budgetedCost.  This is the standard EVM approach
  /// per the Integrated Project Controls guide.
  double percentComplete;

  bool get isReleasedForExecution =>
      releaseStatus == 'released' || releaseStatus == 'complete';

  WorkPackage({
    String? id,
    this.wbsItemId = '',
    this.wbsLevel2Id = '',
    this.wbsLevel2Title = '',
    this.sourceWbsLevel3Id = '',
    this.sourceWbsLevel3Title = '',
    this.packageLevel = 3,
    this.packageCode = '',
    this.packageClassification = '',
    this.parentPackageId = '',
    List<String>? childPackageIds,
    List<String>? linkedEngineeringPackageIds,
    List<String>? linkedProcurementPackageIds,
    List<String>? linkedExecutionPackageIds,
    this.title = '',
    this.description = '',
    this.type = '',
    this.phase = '',
    this.status = 'planned',
    this.owner = '',
    this.discipline = '',
    this.plannedStart,
    this.plannedEnd,
    this.actualStart,
    this.actualEnd,
    this.budgetedCost = 0,
    this.actualCost = 0,
    this.plannedHours = 0,
    this.actualHours = 0,
    List<String>? scheduleActivityIds,
    List<String>? contractIds,
    List<String>? vendorIds,
    List<String>? requirementIds,
    List<PackageDeliverable>? deliverables,
    this.acceptingCriteria = '',
    this.designPackageId = '',
    List<String>? procurementItemIds,
    List<String>? milestoneIds,
    this.areaOrSystem = '',
    this.contractorOrCrew = '',
    this.releaseStatus = 'draft',
    this.releaseForExecutionDate,
    List<String>? linkedDesignSpecificationIds,
    PackageReadinessChecklist? readiness,
    PackageEstimateBasis? estimateBasis,
    PackageProcurementBreakdown? procurementBreakdown,
    List<String>? readinessWarnings,
    this.notes = '',
    this.controlAccountId = '',
    this.percentComplete = 0,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        childPackageIds = childPackageIds ?? [],
        linkedEngineeringPackageIds = linkedEngineeringPackageIds ?? [],
        linkedProcurementPackageIds = linkedProcurementPackageIds ?? [],
        linkedExecutionPackageIds = linkedExecutionPackageIds ?? [],
        scheduleActivityIds = scheduleActivityIds ?? [],
        contractIds = contractIds ?? [],
        vendorIds = vendorIds ?? [],
        requirementIds = requirementIds ?? [],
        deliverables = deliverables ?? [],
        procurementItemIds = procurementItemIds ?? [],
        milestoneIds = milestoneIds ?? [],
        linkedDesignSpecificationIds = linkedDesignSpecificationIds ?? [],
        readiness = readiness ?? PackageReadinessChecklist(),
        estimateBasis = estimateBasis ?? PackageEstimateBasis(),
        procurementBreakdown =
            procurementBreakdown ?? PackageProcurementBreakdown(),
        readinessWarnings = readinessWarnings ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'wbsItemId': wbsItemId,
        'wbsLevel2Id': wbsLevel2Id,
        'wbsLevel2Title': wbsLevel2Title,
        'sourceWbsLevel3Id': sourceWbsLevel3Id,
        'sourceWbsLevel3Title': sourceWbsLevel3Title,
        'packageLevel': packageLevel,
        'packageCode': packageCode,
        'packageClassification': packageClassification,
        'parentPackageId': parentPackageId,
        'childPackageIds': childPackageIds,
        'linkedEngineeringPackageIds': linkedEngineeringPackageIds,
        'linkedProcurementPackageIds': linkedProcurementPackageIds,
        'linkedExecutionPackageIds': linkedExecutionPackageIds,
        'title': title,
        'description': description,
        'type': type,
        'phase': phase,
        'status': status,
        'owner': owner,
        'discipline': discipline,
        'plannedStart': plannedStart,
        'plannedEnd': plannedEnd,
        'actualStart': actualStart,
        'actualEnd': actualEnd,
        'budgetedCost': budgetedCost,
        'actualCost': actualCost,
        'plannedHours': plannedHours,
        'actualHours': actualHours,
        'scheduleActivityIds': scheduleActivityIds,
        'contractIds': contractIds,
        'vendorIds': vendorIds,
        'requirementIds': requirementIds,
        'deliverables': deliverables.map((item) => item.toJson()).toList(),
        'acceptingCriteria': acceptingCriteria,
        'designPackageId': designPackageId,
        'procurementItemIds': procurementItemIds,
        'milestoneIds': milestoneIds,
        'areaOrSystem': areaOrSystem,
        'contractorOrCrew': contractorOrCrew,
        'releaseStatus': releaseStatus,
        'releaseForExecutionDate': releaseForExecutionDate,
        'linkedDesignSpecificationIds': linkedDesignSpecificationIds,
        'readiness': readiness.toJson(),
        'estimateBasis': estimateBasis.toJson(),
        'procurementBreakdown': procurementBreakdown.toJson(),
        'readinessWarnings': readinessWarnings,
        'notes': notes,
        'controlAccountId': controlAccountId,
        'percentComplete': percentComplete,
      };

  factory WorkPackage.fromJson(Map<String, dynamic> json) {
    return WorkPackage(
      id: json['id']?.toString(),
      wbsItemId: json['wbsItemId']?.toString() ?? '',
      wbsLevel2Id: json['wbsLevel2Id']?.toString() ?? '',
      wbsLevel2Title: json['wbsLevel2Title']?.toString() ?? '',
      sourceWbsLevel3Id: json['sourceWbsLevel3Id']?.toString() ?? '',
      sourceWbsLevel3Title: json['sourceWbsLevel3Title']?.toString() ?? '',
      packageLevel: json['packageLevel'] is num
          ? (json['packageLevel'] as num).round()
          : int.tryParse(json['packageLevel']?.toString() ?? '') ?? 3,
      packageCode: json['packageCode']?.toString() ?? '',
      packageClassification: json['packageClassification']?.toString() ?? '',
      parentPackageId: json['parentPackageId']?.toString() ?? '',
      childPackageIds: (json['childPackageIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      linkedEngineeringPackageIds:
          (json['linkedEngineeringPackageIds'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
      linkedProcurementPackageIds:
          (json['linkedProcurementPackageIds'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
      linkedExecutionPackageIds: (json['linkedExecutionPackageIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      phase: json['phase']?.toString() ?? '',
      status: json['status']?.toString() ?? 'planned',
      owner: json['owner']?.toString() ?? '',
      discipline: json['discipline']?.toString() ?? '',
      plannedStart: json['plannedStart']?.toString(),
      plannedEnd: json['plannedEnd']?.toString(),
      actualStart: json['actualStart']?.toString(),
      actualEnd: json['actualEnd']?.toString(),
      budgetedCost: json['budgetedCost'] is num
          ? (json['budgetedCost'] as num).toDouble()
          : double.tryParse(json['budgetedCost']?.toString() ?? '') ?? 0,
      actualCost: json['actualCost'] is num
          ? (json['actualCost'] as num).toDouble()
          : double.tryParse(json['actualCost']?.toString() ?? '') ?? 0,
      plannedHours: json['plannedHours'] is num
          ? (json['plannedHours'] as num).toDouble()
          : double.tryParse(json['plannedHours']?.toString() ?? '') ?? 0,
      actualHours: json['actualHours'] is num
          ? (json['actualHours'] as num).toDouble()
          : double.tryParse(json['actualHours']?.toString() ?? '') ?? 0,
      scheduleActivityIds: (json['scheduleActivityIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      contractIds:
          (json['contractIds'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      vendorIds:
          (json['vendorIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      requirementIds: (json['requirementIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      deliverables: (json['deliverables'] as List?)
              ?.whereType<Map>()
              .map((item) =>
                  PackageDeliverable.fromJson(Map<String, dynamic>.from(item)))
              .toList() ??
          [],
      acceptingCriteria: json['acceptingCriteria']?.toString() ?? '',
      designPackageId: json['designPackageId']?.toString() ?? '',
      procurementItemIds: (json['procurementItemIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      milestoneIds: (json['milestoneIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      areaOrSystem: json['areaOrSystem']?.toString() ?? '',
      contractorOrCrew: json['contractorOrCrew']?.toString() ?? '',
      releaseStatus: json['releaseStatus']?.toString() ?? 'draft',
      releaseForExecutionDate: json['releaseForExecutionDate']?.toString(),
      linkedDesignSpecificationIds:
          (json['linkedDesignSpecificationIds'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
      readiness: json['readiness'] is Map
          ? PackageReadinessChecklist.fromJson(
              Map<String, dynamic>.from(json['readiness'] as Map),
            )
          : PackageReadinessChecklist(),
      estimateBasis: json['estimateBasis'] is Map
          ? PackageEstimateBasis.fromJson(
              Map<String, dynamic>.from(json['estimateBasis'] as Map),
            )
          : PackageEstimateBasis(),
      procurementBreakdown: json['procurementBreakdown'] is Map
          ? PackageProcurementBreakdown.fromJson(
              Map<String, dynamic>.from(json['procurementBreakdown'] as Map),
            )
          : PackageProcurementBreakdown(),
      readinessWarnings: (json['readinessWarnings'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      notes: json['notes']?.toString() ?? '',
      controlAccountId: json['controlAccountId']?.toString() ?? '',
      percentComplete: (json['percentComplete'] is num)
          ? (json['percentComplete'] as num).toDouble().clamp(0, 1)
          : 0,
    );
  }

  WorkPackage copyWith({
    String? wbsItemId,
    String? wbsLevel2Id,
    String? wbsLevel2Title,
    String? sourceWbsLevel3Id,
    String? sourceWbsLevel3Title,
    int? packageLevel,
    String? packageCode,
    String? packageClassification,
    String? parentPackageId,
    List<String>? childPackageIds,
    List<String>? linkedEngineeringPackageIds,
    List<String>? linkedProcurementPackageIds,
    List<String>? linkedExecutionPackageIds,
    String? title,
    String? description,
    String? type,
    String? phase,
    String? status,
    String? owner,
    String? discipline,
    String? plannedStart,
    String? plannedEnd,
    String? actualStart,
    String? actualEnd,
    double? budgetedCost,
    double? actualCost,
    List<String>? scheduleActivityIds,
    List<String>? contractIds,
    List<String>? vendorIds,
    List<String>? requirementIds,
    List<PackageDeliverable>? deliverables,
    String? acceptingCriteria,
    String? designPackageId,
    List<String>? procurementItemIds,
    List<String>? milestoneIds,
    String? areaOrSystem,
    String? contractorOrCrew,
    String? releaseStatus,
    String? releaseForExecutionDate,
    List<String>? linkedDesignSpecificationIds,
    PackageReadinessChecklist? readiness,
    PackageEstimateBasis? estimateBasis,
    PackageProcurementBreakdown? procurementBreakdown,
    List<String>? readinessWarnings,
    String? notes,
    String? controlAccountId,
    double? percentComplete,
  }) {
    return WorkPackage(
      id: id,
      wbsItemId: wbsItemId ?? this.wbsItemId,
      wbsLevel2Id: wbsLevel2Id ?? this.wbsLevel2Id,
      wbsLevel2Title: wbsLevel2Title ?? this.wbsLevel2Title,
      sourceWbsLevel3Id: sourceWbsLevel3Id ?? this.sourceWbsLevel3Id,
      sourceWbsLevel3Title: sourceWbsLevel3Title ?? this.sourceWbsLevel3Title,
      packageLevel: packageLevel ?? this.packageLevel,
      packageCode: packageCode ?? this.packageCode,
      packageClassification:
          packageClassification ?? this.packageClassification,
      parentPackageId: parentPackageId ?? this.parentPackageId,
      childPackageIds: childPackageIds ?? this.childPackageIds,
      linkedEngineeringPackageIds:
          linkedEngineeringPackageIds ?? this.linkedEngineeringPackageIds,
      linkedProcurementPackageIds:
          linkedProcurementPackageIds ?? this.linkedProcurementPackageIds,
      linkedExecutionPackageIds:
          linkedExecutionPackageIds ?? this.linkedExecutionPackageIds,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      phase: phase ?? this.phase,
      status: status ?? this.status,
      owner: owner ?? this.owner,
      discipline: discipline ?? this.discipline,
      plannedStart: plannedStart ?? this.plannedStart,
      plannedEnd: plannedEnd ?? this.plannedEnd,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      budgetedCost: budgetedCost ?? this.budgetedCost,
      actualCost: actualCost ?? this.actualCost,
      scheduleActivityIds: scheduleActivityIds ?? this.scheduleActivityIds,
      contractIds: contractIds ?? this.contractIds,
      vendorIds: vendorIds ?? this.vendorIds,
      requirementIds: requirementIds ?? this.requirementIds,
      deliverables: deliverables ?? this.deliverables,
      acceptingCriteria: acceptingCriteria ?? this.acceptingCriteria,
      designPackageId: designPackageId ?? this.designPackageId,
      procurementItemIds: procurementItemIds ?? this.procurementItemIds,
      milestoneIds: milestoneIds ?? this.milestoneIds,
      areaOrSystem: areaOrSystem ?? this.areaOrSystem,
      contractorOrCrew: contractorOrCrew ?? this.contractorOrCrew,
      releaseStatus: releaseStatus ?? this.releaseStatus,
      releaseForExecutionDate:
          releaseForExecutionDate ?? this.releaseForExecutionDate,
      linkedDesignSpecificationIds:
          linkedDesignSpecificationIds ?? this.linkedDesignSpecificationIds,
      readiness: readiness ?? this.readiness,
      estimateBasis: estimateBasis ?? this.estimateBasis,
      procurementBreakdown: procurementBreakdown ?? this.procurementBreakdown,
      readinessWarnings: readinessWarnings ?? this.readinessWarnings,
      notes: notes ?? this.notes,
      controlAccountId: controlAccountId ?? this.controlAccountId,
      percentComplete: percentComplete ?? this.percentComplete,
    );
  }
}

class PackageDeliverable {
  String id;
  String title;
  String type;
  String status;
  String reference;
  String notes;

  /// IDs of procurement packages that this deliverable feeds into.
  /// Enables design-to-procurement traceability (Guide Step 3):
  /// each EWP output that must be purchased or contracted links
  /// directly to the procurement package it triggers.
  List<String> feedsProcurementPackageIds;

  /// IDs of design specification rows from DesignPlanningDocument
  /// that this deliverable fulfills. Provides traceability from
  /// design specifications → EWP deliverables.
  List<String> linkedSpecificationIds;

  /// Whether this deliverable is required for procurement.
  /// When true, the linked procurement package cannot start
  /// until this deliverable reaches 'released' status.
  bool requiredForProcurement;

  PackageDeliverable({
    String? id,
    this.title = '',
    this.type = '',
    this.status = 'planned',
    this.reference = '',
    this.notes = '',
    List<String>? feedsProcurementPackageIds,
    List<String>? linkedSpecificationIds,
    this.requiredForProcurement = false,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        feedsProcurementPackageIds = feedsProcurementPackageIds ?? [],
        linkedSpecificationIds = linkedSpecificationIds ?? [];

  /// Whether this deliverable has been released for execution.
  bool get isReleased => status == 'released' || status == 'complete';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'status': status,
        'reference': reference,
        'notes': notes,
        'feedsProcurementPackageIds': feedsProcurementPackageIds,
        'linkedSpecificationIds': linkedSpecificationIds,
        'requiredForProcurement': requiredForProcurement,
      };

  factory PackageDeliverable.fromJson(Map<String, dynamic> json) {
    return PackageDeliverable(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? 'planned',
      reference: json['reference']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      feedsProcurementPackageIds: (json['feedsProcurementPackageIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      linkedSpecificationIds: (json['linkedSpecificationIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      requiredForProcurement: json['requiredForProcurement'] == true,
    );
  }
}

class PackageReadinessChecklist {
  bool requirementsTraced;
  bool drawingsComplete;
  bool specificationsComplete;
  bool calculationsComplete;
  bool billOfMaterialsComplete;
  bool codesAndStandardsConfirmed;
  bool designReviewComplete;
  bool ifcApproved;
  bool procurementScopeDefined;
  bool rfqIssued;
  bool bidsEvaluated;
  bool contractAwarded;
  bool fabricationComplete;
  bool deliveredOrOnSite;
  bool materialsAvailable;
  bool permitsApproved;
  bool accessReady;
  bool predecessorsComplete;
  bool resourcesAssigned;
  bool siteReady;

  PackageReadinessChecklist({
    this.requirementsTraced = false,
    this.drawingsComplete = false,
    this.specificationsComplete = false,
    this.calculationsComplete = false,
    this.billOfMaterialsComplete = false,
    this.codesAndStandardsConfirmed = false,
    this.designReviewComplete = false,
    this.ifcApproved = false,
    this.procurementScopeDefined = false,
    this.rfqIssued = false,
    this.bidsEvaluated = false,
    this.contractAwarded = false,
    this.fabricationComplete = false,
    this.deliveredOrOnSite = false,
    this.materialsAvailable = false,
    this.permitsApproved = false,
    this.accessReady = false,
    this.predecessorsComplete = false,
    this.resourcesAssigned = false,
    this.siteReady = false,
  });

  Map<String, dynamic> toJson() => {
        'requirementsTraced': requirementsTraced,
        'drawingsComplete': drawingsComplete,
        'specificationsComplete': specificationsComplete,
        'calculationsComplete': calculationsComplete,
        'billOfMaterialsComplete': billOfMaterialsComplete,
        'codesAndStandardsConfirmed': codesAndStandardsConfirmed,
        'designReviewComplete': designReviewComplete,
        'ifcApproved': ifcApproved,
        'procurementScopeDefined': procurementScopeDefined,
        'rfqIssued': rfqIssued,
        'bidsEvaluated': bidsEvaluated,
        'contractAwarded': contractAwarded,
        'fabricationComplete': fabricationComplete,
        'deliveredOrOnSite': deliveredOrOnSite,
        'materialsAvailable': materialsAvailable,
        'permitsApproved': permitsApproved,
        'accessReady': accessReady,
        'predecessorsComplete': predecessorsComplete,
        'resourcesAssigned': resourcesAssigned,
        'siteReady': siteReady,
      };

  factory PackageReadinessChecklist.fromJson(Map<String, dynamic> json) {
    bool parseBool(String key) => json[key] == true;
    return PackageReadinessChecklist(
      requirementsTraced: parseBool('requirementsTraced'),
      drawingsComplete: parseBool('drawingsComplete'),
      specificationsComplete: parseBool('specificationsComplete'),
      calculationsComplete: parseBool('calculationsComplete'),
      billOfMaterialsComplete: parseBool('billOfMaterialsComplete'),
      codesAndStandardsConfirmed: parseBool('codesAndStandardsConfirmed'),
      designReviewComplete: parseBool('designReviewComplete'),
      ifcApproved: parseBool('ifcApproved'),
      procurementScopeDefined: parseBool('procurementScopeDefined'),
      rfqIssued: parseBool('rfqIssued'),
      bidsEvaluated: parseBool('bidsEvaluated'),
      contractAwarded: parseBool('contractAwarded'),
      fabricationComplete: parseBool('fabricationComplete'),
      deliveredOrOnSite: parseBool('deliveredOrOnSite'),
      materialsAvailable: parseBool('materialsAvailable'),
      permitsApproved: parseBool('permitsApproved'),
      accessReady: parseBool('accessReady'),
      predecessorsComplete: parseBool('predecessorsComplete'),
      resourcesAssigned: parseBool('resourcesAssigned'),
      siteReady: parseBool('siteReady'),
    );
  }
}

class PackageEstimateBasis {
  String method;
  String sourceData;
  List<String> assumptions;
  String productivityBasis;
  String resourceBasis;
  String workingCalendar;
  String procurementLeadTimeBasis;
  String reviewAllowance;
  String confidenceLevel;
  List<String> exclusions;
  String risksAndContingency;

  PackageEstimateBasis({
    this.method = '',
    this.sourceData = '',
    List<String>? assumptions,
    this.productivityBasis = '',
    this.resourceBasis = '',
    this.workingCalendar = '',
    this.procurementLeadTimeBasis = '',
    this.reviewAllowance = '',
    this.confidenceLevel = '',
    List<String>? exclusions,
    this.risksAndContingency = '',
  })  : assumptions = assumptions ?? [],
        exclusions = exclusions ?? [];

  bool get hasMinimumBasis =>
      method.trim().isNotEmpty &&
      sourceData.trim().isNotEmpty &&
      assumptions.any((item) => item.trim().isNotEmpty);

  Map<String, dynamic> toJson() => {
        'method': method,
        'sourceData': sourceData,
        'assumptions': assumptions,
        'productivityBasis': productivityBasis,
        'resourceBasis': resourceBasis,
        'workingCalendar': workingCalendar,
        'procurementLeadTimeBasis': procurementLeadTimeBasis,
        'reviewAllowance': reviewAllowance,
        'confidenceLevel': confidenceLevel,
        'exclusions': exclusions,
        'risksAndContingency': risksAndContingency,
      };

  factory PackageEstimateBasis.fromJson(Map<String, dynamic> json) {
    return PackageEstimateBasis(
      method: json['method']?.toString() ?? '',
      sourceData: json['sourceData']?.toString() ?? '',
      assumptions:
          (json['assumptions'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      productivityBasis: json['productivityBasis']?.toString() ?? '',
      resourceBasis: json['resourceBasis']?.toString() ?? '',
      workingCalendar: json['workingCalendar']?.toString() ?? '',
      procurementLeadTimeBasis:
          json['procurementLeadTimeBasis']?.toString() ?? '',
      reviewAllowance: json['reviewAllowance']?.toString() ?? '',
      confidenceLevel: json['confidenceLevel']?.toString() ?? '',
      exclusions:
          (json['exclusions'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      risksAndContingency: json['risksAndContingency']?.toString() ?? '',
    );
  }

  PackageEstimateBasis copyWith({
    String? method,
    String? sourceData,
    List<String>? assumptions,
    String? productivityBasis,
    String? resourceBasis,
    String? workingCalendar,
    String? procurementLeadTimeBasis,
    String? reviewAllowance,
    String? confidenceLevel,
    List<String>? exclusions,
    String? risksAndContingency,
  }) {
    return PackageEstimateBasis(
      method: method ?? this.method,
      sourceData: sourceData ?? this.sourceData,
      assumptions: assumptions ?? this.assumptions,
      productivityBasis: productivityBasis ?? this.productivityBasis,
      resourceBasis: resourceBasis ?? this.resourceBasis,
      workingCalendar: workingCalendar ?? this.workingCalendar,
      procurementLeadTimeBasis:
          procurementLeadTimeBasis ?? this.procurementLeadTimeBasis,
      reviewAllowance: reviewAllowance ?? this.reviewAllowance,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      exclusions: exclusions ?? this.exclusions,
      risksAndContingency: risksAndContingency ?? this.risksAndContingency,
    );
  }
}

class PackageProcurementBreakdown {
  String
      category; // longLeadEquipment | bulkMaterials | subcontract | services | technology
  String scopeDefinition;
  int leadTimeDays;
  String rfqDate;
  String awardDate;
  String deliveryDate;
  String requiredByMilestoneId;
  String vendorScope;
  List<String> activities;

  PackageProcurementBreakdown({
    this.category = '',
    this.scopeDefinition = '',
    this.leadTimeDays = 0,
    this.rfqDate = '',
    this.awardDate = '',
    this.deliveryDate = '',
    this.requiredByMilestoneId = '',
    this.vendorScope = '',
    List<String>? activities,
  }) : activities = activities ?? [];

  Map<String, dynamic> toJson() => {
        'category': category,
        'scopeDefinition': scopeDefinition,
        'leadTimeDays': leadTimeDays,
        'rfqDate': rfqDate,
        'awardDate': awardDate,
        'deliveryDate': deliveryDate,
        'requiredByMilestoneId': requiredByMilestoneId,
        'vendorScope': vendorScope,
        'activities': activities,
      };

  factory PackageProcurementBreakdown.fromJson(Map<String, dynamic> json) {
    return PackageProcurementBreakdown(
      category: json['category']?.toString() ?? '',
      scopeDefinition: json['scopeDefinition']?.toString() ?? '',
      leadTimeDays: json['leadTimeDays'] is num
          ? (json['leadTimeDays'] as num).round()
          : int.tryParse(json['leadTimeDays']?.toString() ?? '') ?? 0,
      rfqDate: json['rfqDate']?.toString() ?? '',
      awardDate: json['awardDate']?.toString() ?? '',
      deliveryDate: json['deliveryDate']?.toString() ?? '',
      requiredByMilestoneId: json['requiredByMilestoneId']?.toString() ?? '',
      vendorScope: json['vendorScope']?.toString() ?? '',
      activities:
          (json['activities'] as List?)?.map((e) => e.toString()).toList() ??
              [],
    );
  }

  PackageProcurementBreakdown copyWith({
    String? category,
    String? scopeDefinition,
    int? leadTimeDays,
    String? rfqDate,
    String? awardDate,
    String? deliveryDate,
    String? requiredByMilestoneId,
    String? vendorScope,
    List<String>? activities,
  }) {
    return PackageProcurementBreakdown(
      category: category ?? this.category,
      scopeDefinition: scopeDefinition ?? this.scopeDefinition,
      leadTimeDays: leadTimeDays ?? this.leadTimeDays,
      rfqDate: rfqDate ?? this.rfqDate,
      awardDate: awardDate ?? this.awardDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      requiredByMilestoneId:
          requiredByMilestoneId ?? this.requiredByMilestoneId,
      vendorScope: vendorScope ?? this.vendorScope,
      activities: activities ?? this.activities,
    );
  }
}

class CostAnalysisData {
  String notes;
  List<SolutionCostData> solutionCosts;
  // Step 1: Project Value data
  String projectValueAmount;
  Map<String, String> projectValueBenefits;
  List<BenefitLineItem> benefitLineItems;
  // Per-solution financial inputs
  List<SolutionProjectBenefitData> solutionProjectBenefits;
  // Per-solution category estimates from Initial Cost Estimate
  List<SolutionCategoryCostData> solutionCategoryCosts;
  // Per-solution assumptions and narrative context
  List<SolutionCostAssumptionData> solutionCostAssumptions;
  String savingsNotes;
  String savingsTarget;
  String? basisFrequency;
  String trackerBasisFrequency;
  double npvDiscountRate;
  List<SolutionSavingsData> solutionSavingsSuggestions;

  CostAnalysisData({
    this.notes = '',
    List<SolutionCostData>? solutionCosts,
    this.projectValueAmount = '',
    Map<String, String>? projectValueBenefits,
    List<BenefitLineItem>? benefitLineItems,
    List<SolutionProjectBenefitData>? solutionProjectBenefits,
    List<SolutionCategoryCostData>? solutionCategoryCosts,
    List<SolutionCostAssumptionData>? solutionCostAssumptions,
    this.savingsNotes = '',
    this.savingsTarget = '',
    this.basisFrequency,
    this.trackerBasisFrequency = 'Annual',
    this.npvDiscountRate = 0.10,
    List<SolutionSavingsData>? solutionSavingsSuggestions,
  })  : solutionCosts = solutionCosts ?? [],
        projectValueBenefits = projectValueBenefits ?? {},
        benefitLineItems = benefitLineItems ?? [],
        solutionProjectBenefits = solutionProjectBenefits ?? [],
        solutionCategoryCosts = solutionCategoryCosts ?? [],
        solutionCostAssumptions = solutionCostAssumptions ?? [],
        solutionSavingsSuggestions = solutionSavingsSuggestions ?? [];

  Map<String, dynamic> toJson() => {
        'notes': notes,
        'solutionCosts': solutionCosts.map((s) => s.toJson()).toList(),
        'projectValueAmount': projectValueAmount,
        'projectValueBenefits': projectValueBenefits,
        'benefitLineItems': benefitLineItems.map((b) => b.toJson()).toList(),
        'solutionProjectBenefits':
            solutionProjectBenefits.map((s) => s.toJson()).toList(),
        'solutionCategoryCosts':
            solutionCategoryCosts.map((s) => s.toJson()).toList(),
        'solutionCostAssumptions':
            solutionCostAssumptions.map((s) => s.toJson()).toList(),
        'savingsNotes': savingsNotes,
        'savingsTarget': savingsTarget,
        'basisFrequency': basisFrequency,
        'trackerBasisFrequency': trackerBasisFrequency,
        'npvDiscountRate': npvDiscountRate,
        'solutionSavingsSuggestions':
            solutionSavingsSuggestions.map((s) => s.toJson()).toList(),
      };

  factory CostAnalysisData.fromJson(Map<String, dynamic> json) {
    final parsedProjectBenefits = (json['solutionProjectBenefits'] as List?)
            ?.map((s) => SolutionProjectBenefitData.fromJson(s))
            .toList() ??
        [];
    final legacyBenefitLineItems = (json['benefitLineItems'] as List?)
            ?.map((b) => BenefitLineItem.fromJson(b))
            .toList() ??
        [];
    final projectValueAmount = json['projectValueAmount'] ?? '';
    final projectValueBenefits =
        Map<String, String>.from(json['projectValueBenefits'] ?? {});

    final solutionProjectBenefits = parsedProjectBenefits.isNotEmpty
        ? parsedProjectBenefits
        : (projectValueAmount.toString().trim().isNotEmpty ||
                projectValueBenefits.isNotEmpty ||
                legacyBenefitLineItems.isNotEmpty)
            ? [
                SolutionProjectBenefitData(
                  solutionTitle: '',
                  projectValueAmount: projectValueAmount,
                  projectValueBenefits: projectValueBenefits,
                  projectBenefits: legacyBenefitLineItems,
                )
              ]
            : <SolutionProjectBenefitData>[];

    return CostAnalysisData(
      notes: json['notes'] ?? '',
      solutionCosts: (json['solutionCosts'] as List?)
              ?.map((s) => SolutionCostData.fromJson(s))
              .toList() ??
          [],
      projectValueAmount: projectValueAmount,
      projectValueBenefits: projectValueBenefits,
      benefitLineItems: legacyBenefitLineItems,
      solutionProjectBenefits: solutionProjectBenefits,
      solutionCategoryCosts: (json['solutionCategoryCosts'] as List?)
              ?.map((s) => SolutionCategoryCostData.fromJson(s))
              .toList() ??
          [],
      solutionCostAssumptions: (json['solutionCostAssumptions'] as List?)
              ?.map((s) => SolutionCostAssumptionData.fromJson(s))
              .toList() ??
          [],
      savingsNotes: json['savingsNotes'] ?? '',
      savingsTarget: json['savingsTarget'] ?? '',
      basisFrequency: json['basisFrequency']?.toString(),
      trackerBasisFrequency:
          json['trackerBasisFrequency']?.toString() ?? 'Annual',
      npvDiscountRate: json['npvDiscountRate'] is num
          ? (json['npvDiscountRate'] as num).toDouble()
          : (double.tryParse(json['npvDiscountRate']?.toString() ?? '') ??
              0.10),
      solutionSavingsSuggestions: (json['solutionSavingsSuggestions'] as List?)
              ?.map((s) => SolutionSavingsData.fromJson(s))
              .toList() ??
          [],
    );
  }
}

class SolutionCostData {
  String solutionTitle;
  List<CostRowData> costRows;
  String contextHash;

  SolutionCostData({
    this.solutionTitle = '',
    List<CostRowData>? costRows,
    this.contextHash = '',
  }) : costRows = costRows ?? [];

  Map<String, dynamic> toJson() => {
        'solutionTitle': solutionTitle,
        'costRows': costRows.map((r) => r.toJson()).toList(),
        'contextHash': contextHash,
      };

  factory SolutionCostData.fromJson(Map<String, dynamic> json) {
    return SolutionCostData(
      solutionTitle: json['solutionTitle'] ?? '',
      costRows: (json['costRows'] as List?)
              ?.map((r) => CostRowData.fromJson(r))
              .toList() ??
          [],
      contextHash: json['contextHash']?.toString() ?? '',
    );
  }
}

class SolutionProjectBenefitData {
  String solutionTitle;
  String projectValueAmount;
  Map<String, String> projectValueBenefits;
  List<BenefitLineItem> projectBenefits;
  String contextHash;

  SolutionProjectBenefitData({
    this.solutionTitle = '',
    this.projectValueAmount = '',
    Map<String, String>? projectValueBenefits,
    List<BenefitLineItem>? projectBenefits,
    this.contextHash = '',
  })  : projectValueBenefits = projectValueBenefits ?? {},
        projectBenefits = projectBenefits ?? [];

  Map<String, dynamic> toJson() => {
        'solutionTitle': solutionTitle,
        'projectValueAmount': projectValueAmount,
        'projectValueBenefits': projectValueBenefits,
        'projectBenefits': projectBenefits.map((b) => b.toJson()).toList(),
        'contextHash': contextHash,
      };

  factory SolutionProjectBenefitData.fromJson(Map<String, dynamic> json) {
    return SolutionProjectBenefitData(
      solutionTitle: json['solutionTitle']?.toString() ?? '',
      projectValueAmount: json['projectValueAmount']?.toString() ?? '',
      projectValueBenefits:
          Map<String, String>.from(json['projectValueBenefits'] ?? {}),
      projectBenefits: (json['projectBenefits'] as List?)
              ?.map((b) => BenefitLineItem.fromJson(b))
              .toList() ??
          [],
      contextHash: json['contextHash']?.toString() ?? '',
    );
  }
}

class SolutionSavingsData {
  String solutionTitle;
  String contextHash;
  List<SavingsSuggestionData> suggestions;

  SolutionSavingsData({
    this.solutionTitle = '',
    this.contextHash = '',
    List<SavingsSuggestionData>? suggestions,
  }) : suggestions = suggestions ?? [];

  Map<String, dynamic> toJson() => {
        'solutionTitle': solutionTitle,
        'contextHash': contextHash,
        'suggestions': suggestions.map((s) => s.toJson()).toList(),
      };

  factory SolutionSavingsData.fromJson(Map<String, dynamic> json) {
    return SolutionSavingsData(
      solutionTitle: json['solutionTitle']?.toString() ?? '',
      contextHash: json['contextHash']?.toString() ?? '',
      suggestions: (json['suggestions'] as List?)
              ?.map((s) => SavingsSuggestionData.fromJson(s))
              .toList() ??
          [],
    );
  }
}

class SavingsSuggestionData {
  String lever;
  String recommendation;
  double projectedSavings;
  String timeframe;
  String confidence;
  String rationale;

  SavingsSuggestionData({
    this.lever = '',
    this.recommendation = '',
    this.projectedSavings = 0,
    this.timeframe = '',
    this.confidence = '',
    this.rationale = '',
  });

  Map<String, dynamic> toJson() => {
        'lever': lever,
        'recommendation': recommendation,
        'projectedSavings': projectedSavings,
        'timeframe': timeframe,
        'confidence': confidence,
        'rationale': rationale,
      };

  factory SavingsSuggestionData.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    return SavingsSuggestionData(
      lever: json['lever']?.toString() ?? '',
      recommendation: json['recommendation']?.toString() ?? '',
      projectedSavings: parseDouble(json['projectedSavings']),
      timeframe: json['timeframe']?.toString() ?? '',
      confidence: json['confidence']?.toString() ?? '',
      rationale: json['rationale']?.toString() ?? '',
    );
  }
}

class SolutionCategoryCostData {
  String solutionTitle;
  Map<String, String> categoryCosts;
  Map<String, String> categoryNotes;

  SolutionCategoryCostData({
    this.solutionTitle = '',
    Map<String, String>? categoryCosts,
    Map<String, String>? categoryNotes,
  })  : categoryCosts = categoryCosts ?? {},
        categoryNotes = categoryNotes ?? {};

  Map<String, dynamic> toJson() => {
        'solutionTitle': solutionTitle,
        'categoryCosts': categoryCosts,
        'categoryNotes': categoryNotes,
      };

  factory SolutionCategoryCostData.fromJson(Map<String, dynamic> json) {
    return SolutionCategoryCostData(
      solutionTitle: json['solutionTitle']?.toString() ?? '',
      categoryCosts: Map<String, String>.from(json['categoryCosts'] ?? {}),
      categoryNotes: Map<String, String>.from(json['categoryNotes'] ?? {}),
    );
  }
}

class SolutionCostAssumptionData {
  String solutionTitle;
  int resourceIndex;
  int timelineIndex;
  int complexityIndex;
  String justification;

  SolutionCostAssumptionData({
    this.solutionTitle = '',
    this.resourceIndex = 0,
    this.timelineIndex = 1,
    this.complexityIndex = 0,
    this.justification = '',
  });

  Map<String, dynamic> toJson() => {
        'solutionTitle': solutionTitle,
        'resourceIndex': resourceIndex,
        'timelineIndex': timelineIndex,
        'complexityIndex': complexityIndex,
        'justification': justification,
      };

  factory SolutionCostAssumptionData.fromJson(Map<String, dynamic> json) {
    int parseIndex(dynamic value, int fallback) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    return SolutionCostAssumptionData(
      solutionTitle: json['solutionTitle']?.toString() ?? '',
      resourceIndex: parseIndex(json['resourceIndex'], 0),
      timelineIndex: parseIndex(json['timelineIndex'], 1),
      complexityIndex: parseIndex(json['complexityIndex'], 0),
      justification: json['justification']?.toString() ?? '',
    );
  }
}

class CostRowData {
  String itemName;
  String description;
  String cost;
  String assumptions;

  CostRowData({
    this.itemName = '',
    this.description = '',
    this.cost = '',
    this.assumptions = '',
  });

  Map<String, dynamic> toJson() => {
        'itemName': itemName,
        'description': description,
        'cost': cost,
        'assumptions': assumptions,
      };

  factory CostRowData.fromJson(Map<String, dynamic> json) {
    return CostRowData(
      itemName: json['itemName'] ?? '',
      description: json['description'] ?? '',
      cost: json['cost'] ?? '',
      assumptions: json['assumptions'] ?? '',
    );
  }
}

class BenefitLineItem {
  String id;
  String categoryKey;
  String title;
  String unitValue;
  String units;
  String notes;

  BenefitLineItem({
    required this.id,
    this.categoryKey = '',
    this.title = '',
    this.unitValue = '',
    this.units = '',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryKey': categoryKey,
        'title': title,
        'unitValue': unitValue,
        'units': units,
        'notes': notes,
      };

  factory BenefitLineItem.fromJson(Map<String, dynamic> json) {
    return BenefitLineItem(
      id: json['id'] ?? '',
      categoryKey: json['categoryKey'] ?? '',
      title: json['title'] ?? '',
      unitValue: json['unitValue'] ?? '',
      units: json['units'] ?? '',
      notes: json['notes'] ?? '',
    );
  }
}

class ITConsiderationsData {
  String notes;
  String hardwareRequirements;
  String softwareRequirements;
  String networkRequirements;
  List<SolutionITData> solutionITData;

  ITConsiderationsData({
    this.notes = '',
    this.hardwareRequirements = '',
    this.softwareRequirements = '',
    this.networkRequirements = '',
    List<SolutionITData>? solutionITData,
  }) : solutionITData = solutionITData ?? [];

  Map<String, dynamic> toJson() => {
        'notes': notes,
        'hardwareRequirements': hardwareRequirements,
        'softwareRequirements': softwareRequirements,
        'networkRequirements': networkRequirements,
        'solutionITData': solutionITData.map((s) => s.toJson()).toList(),
      };

  factory ITConsiderationsData.fromJson(Map<String, dynamic> json) {
    return ITConsiderationsData(
      notes: json['notes'] ?? '',
      hardwareRequirements: json['hardwareRequirements'] ?? '',
      softwareRequirements: json['softwareRequirements'] ?? '',
      networkRequirements: json['networkRequirements'] ?? '',
      solutionITData: (json['solutionITData'] as List?)
              ?.map((s) => SolutionITData.fromJson(s))
              .toList() ??
          [],
    );
  }
}

class SolutionITData {
  String solutionTitle;
  String coreTechnology;

  SolutionITData({
    this.solutionTitle = '',
    this.coreTechnology = '',
  });

  Map<String, dynamic> toJson() => {
        'solutionTitle': solutionTitle,
        'coreTechnology': coreTechnology,
      };

  factory SolutionITData.fromJson(Map<String, dynamic> json) {
    return SolutionITData(
      solutionTitle: json['solutionTitle'] ?? '',
      coreTechnology: json['coreTechnology'] ?? '',
    );
  }
}

class InfrastructureConsiderationsData {
  String notes;
  String physicalSpaceRequirements;
  String powerCoolingRequirements;
  String connectivityRequirements;
  List<SolutionInfrastructureData> solutionInfrastructureData;

  InfrastructureConsiderationsData({
    this.notes = '',
    this.physicalSpaceRequirements = '',
    this.powerCoolingRequirements = '',
    this.connectivityRequirements = '',
    List<SolutionInfrastructureData>? solutionInfrastructureData,
  }) : solutionInfrastructureData = solutionInfrastructureData ?? [];

  Map<String, dynamic> toJson() => {
        'notes': notes,
        'physicalSpaceRequirements': physicalSpaceRequirements,
        'powerCoolingRequirements': powerCoolingRequirements,
        'connectivityRequirements': connectivityRequirements,
        'solutionInfrastructureData':
            solutionInfrastructureData.map((s) => s.toJson()).toList(),
      };

  factory InfrastructureConsiderationsData.fromJson(Map<String, dynamic> json) {
    return InfrastructureConsiderationsData(
      notes: json['notes'] ?? '',
      physicalSpaceRequirements: json['physicalSpaceRequirements'] ?? '',
      powerCoolingRequirements: json['powerCoolingRequirements'] ?? '',
      connectivityRequirements: json['connectivityRequirements'] ?? '',
      solutionInfrastructureData: (json['solutionInfrastructureData'] as List?)
              ?.map((s) => SolutionInfrastructureData.fromJson(s))
              .toList() ??
          [],
    );
  }
}

class SolutionInfrastructureData {
  String solutionTitle;
  String majorInfrastructure;

  SolutionInfrastructureData({
    this.solutionTitle = '',
    this.majorInfrastructure = '',
  });

  Map<String, dynamic> toJson() => {
        'solutionTitle': solutionTitle,
        'majorInfrastructure': majorInfrastructure,
      };

  factory SolutionInfrastructureData.fromJson(Map<String, dynamic> json) {
    return SolutionInfrastructureData(
      solutionTitle: json['solutionTitle'] ?? '',
      majorInfrastructure: json['majorInfrastructure'] ?? '',
    );
  }
}

class CoreStakeholdersData {
  String notes;
  String organisationContext;
  List<SolutionStakeholderData> solutionStakeholderData;

  CoreStakeholdersData({
    this.notes = '',
    this.organisationContext = '',
    List<SolutionStakeholderData>? solutionStakeholderData,
  }) : solutionStakeholderData = solutionStakeholderData ?? [];

  Map<String, dynamic> toJson() => {
        'notes': notes,
        'organisationContext': organisationContext,
        'solutionStakeholderData':
            solutionStakeholderData.map((s) => s.toJson()).toList(),
      };

  factory CoreStakeholdersData.fromJson(Map<String, dynamic> json) {
    return CoreStakeholdersData(
      notes: json['notes'] ?? '',
      organisationContext: json['organisationContext'] ?? '',
      solutionStakeholderData: (json['solutionStakeholderData'] as List?)
              ?.map((s) => SolutionStakeholderData.fromJson(s))
              .toList() ??
          [],
    );
  }
}

class SolutionStakeholderData {
  String solutionTitle;
  String notableStakeholders;
  String internalStakeholders;
  String externalStakeholders;

  SolutionStakeholderData({
    this.solutionTitle = '',
    this.notableStakeholders = '',
    this.internalStakeholders = '',
    this.externalStakeholders = '',
  });

  Map<String, dynamic> toJson() => {
        'solutionTitle': solutionTitle,
        'notableStakeholders': notableStakeholders,
        'internalStakeholders': internalStakeholders,
        'externalStakeholders': externalStakeholders,
      };

  factory SolutionStakeholderData.fromJson(Map<String, dynamic> json) {
    return SolutionStakeholderData(
      solutionTitle: json['solutionTitle'] ?? '',
      notableStakeholders: json['notableStakeholders'] ?? '',
      internalStakeholders: json['internalStakeholders'] ?? '',
      externalStakeholders: json['externalStakeholders'] ?? '',
    );
  }
}

// Technical debt models (top-level)
class DebtItem {
  String id;
  String title;
  String area;
  String owner;
  String severity;
  String status;
  String target;

  DebtItem({
    this.id = '',
    this.title = '',
    this.area = '',
    this.owner = '',
    this.severity = '',
    this.status = '',
    this.target = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'area': area,
        'owner': owner,
        'severity': severity,
        'status': status,
        'target': target,
      };

  factory DebtItem.fromJson(Map<String, dynamic> json) => DebtItem(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        area: json['area'] ?? '',
        owner: json['owner'] ?? '',
        severity: json['severity'] ?? '',
        status: json['status'] ?? '',
        target: json['target'] ?? '',
      );
}

class DebtInsight {
  String title;
  String subtitle;
  String evidence;
  String control;
  String tier;
  int colorValue;

  DebtInsight({
    this.title = '',
    this.subtitle = '',
    this.evidence = '',
    this.control = '',
    this.tier = 'Medium',
    this.colorValue = 0xFF6366F1,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'evidence': evidence,
        'control': control,
        'tier': tier,
        'colorValue': colorValue,
      };

  factory DebtInsight.fromJson(Map<String, dynamic> json) => DebtInsight(
        title: json['title'] ?? '',
        subtitle: json['subtitle'] ?? '',
        evidence: json['evidence'] ?? '',
        control: json['control'] ?? '',
        tier: json['tier'] ?? 'Medium',
        colorValue: json['colorValue'] ?? 0xFF6366F1,
      );

  DebtInsight copyWith({
    String? title,
    String? subtitle,
    String? evidence,
    String? control,
    String? tier,
    int? colorValue,
  }) =>
      DebtInsight(
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        evidence: evidence ?? this.evidence,
        control: control ?? this.control,
        tier: tier ?? this.tier,
        colorValue: colorValue ?? this.colorValue,
      );
}

class RemediationTrack {
  String label;
  String secondary;
  String exitCriteria;
  String evidence;
  String ownerCadence;
  double progress;
  int colorValue;

  RemediationTrack({
    this.label = '',
    this.secondary = '',
    this.exitCriteria = '',
    this.evidence = '',
    this.ownerCadence = '',
    this.progress = 0.0,
    this.colorValue = 0xFF6366F1,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'secondary': secondary,
        'exitCriteria': exitCriteria,
        'evidence': evidence,
        'ownerCadence': ownerCadence,
        'progress': progress,
        'colorValue': colorValue,
      };

  factory RemediationTrack.fromJson(Map<String, dynamic> json) =>
      RemediationTrack(
        label: json['label'] ?? '',
        secondary: json['secondary'] ?? '',
        exitCriteria: json['exitCriteria'] ?? '',
        evidence: json['evidence'] ?? '',
        ownerCadence: json['ownerCadence'] ?? '',
        progress: (json['progress'] is num)
            ? (json['progress'] as num).toDouble()
            : 0.0,
        colorValue: json['colorValue'] ?? 0xFF6366F1,
      );

  RemediationTrack copyWith({
    String? label,
    String? secondary,
    String? exitCriteria,
    String? evidence,
    String? ownerCadence,
    double? progress,
    int? colorValue,
  }) =>
      RemediationTrack(
        label: label ?? this.label,
        secondary: secondary ?? this.secondary,
        exitCriteria: exitCriteria ?? this.exitCriteria,
        evidence: evidence ?? this.evidence,
        ownerCadence: ownerCadence ?? this.ownerCadence,
        progress: progress ?? this.progress,
        colorValue: colorValue ?? this.colorValue,
      );
}

class OwnerItem {
  String name;
  String count;
  String note;
  String workstream;
  String scope;
  String coverage;
  String escalation;

  OwnerItem({
    this.name = '',
    this.count = '1',
    this.note = '',
    this.workstream = '',
    this.scope = '',
    this.coverage = '',
    this.escalation = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'count': count,
        'note': note,
        'workstream': workstream,
        'scope': scope,
        'coverage': coverage,
        'escalation': escalation,
      };

  factory OwnerItem.fromJson(Map<String, dynamic> json) => OwnerItem(
        name: json['name'] ?? '',
        count: json['count'] ?? '1',
        note: json['note'] ?? '',
        workstream: json['workstream'] ?? '',
        scope: json['scope'] ?? '',
        coverage: json['coverage'] ?? '',
        escalation: json['escalation'] ?? '',
      );

  OwnerItem copyWith({
    String? name,
    String? count,
    String? note,
    String? workstream,
    String? scope,
    String? coverage,
    String? escalation,
  }) =>
      OwnerItem(
        name: name ?? this.name,
        count: count ?? this.count,
        note: note ?? this.note,
        workstream: workstream ?? this.workstream,
        scope: scope ?? this.scope,
        coverage: coverage ?? this.coverage,
        escalation: escalation ?? this.escalation,
      );
}

// Execution Phase Data
class ExecutionPhaseData {
  final String? executionPlanOutline;
  final String? executionPlanStrategy;
  final Map<String, List<ExecutionPhaseEntry>> sectionData;

  ExecutionPhaseData({
    this.executionPlanOutline,
    this.executionPlanStrategy,
    Map<String, List<ExecutionPhaseEntry>>? sectionData,
  }) : sectionData = sectionData ?? {};

  bool get isEmpty =>
      (executionPlanOutline == null || executionPlanOutline!.isEmpty) &&
      (executionPlanStrategy == null || executionPlanStrategy!.isEmpty) &&
      sectionData.isEmpty;

  ExecutionPhaseData copyWith({
    String? executionPlanOutline,
    String? executionPlanStrategy,
    Map<String, List<ExecutionPhaseEntry>>? sectionData,
  }) {
    return ExecutionPhaseData(
      executionPlanOutline: executionPlanOutline ?? this.executionPlanOutline,
      executionPlanStrategy:
          executionPlanStrategy ?? this.executionPlanStrategy,
      sectionData: sectionData ?? this.sectionData,
    );
  }

  Map<String, dynamic> toJson() => {
        'executionPlanOutline': executionPlanOutline,
        'executionPlanStrategy': executionPlanStrategy,
        'sectionData': sectionData.map(
          (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
        ),
      };

  factory ExecutionPhaseData.fromJson(Map<String, dynamic> json) {
    final sectionDataMap = <String, List<ExecutionPhaseEntry>>{};
    final sectionDataJson = json['sectionData'];
    if (sectionDataJson is Map) {
      sectionDataJson.forEach((key, value) {
        if (value is List) {
          sectionDataMap[key.toString()] = value.map((e) {
            if (e is Map) {
              return ExecutionPhaseEntry.fromJson(Map<String, dynamic>.from(e));
            }
            return ExecutionPhaseEntry(title: '', details: '', status: '');
          }).toList();
        }
      });
    }
    return ExecutionPhaseData(
      executionPlanOutline: json['executionPlanOutline']?.toString(),
      executionPlanStrategy: json['executionPlanStrategy']?.toString(),
      sectionData: sectionDataMap,
    );
  }
}

class ExecutionPhaseEntry {
  final String title;
  final String details;
  final String status;

  ExecutionPhaseEntry({
    required this.title,
    required this.details,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'details': details,
        'status': status,
      };

  factory ExecutionPhaseEntry.fromJson(Map<String, dynamic> json) =>
      ExecutionPhaseEntry(
        title: json['title']?.toString() ?? '',
        details: json['details']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
      );
}

// Scenario matrix record persisted in project data
class ScenarioRecord {
  String id;
  String title;
  String detail;
  String category; // Impact / Gap / Plan / Custom
  String owner;
  int severity; // 1..3
  int likelihood; // 1..3

  ScenarioRecord({
    this.id = '',
    this.title = '',
    this.detail = '',
    this.category = 'Custom',
    this.owner = '',
    this.severity = 2,
    this.likelihood = 2,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'detail': detail,
        'category': category,
        'owner': owner,
        'severity': severity,
        'likelihood': likelihood,
      };

  factory ScenarioRecord.fromJson(Map<String, dynamic> json) => ScenarioRecord(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        detail: json['detail'] ?? '',
        category: json['category'] ?? 'Custom',
        owner: json['owner'] ?? '',
        severity:
            (json['severity'] is num) ? (json['severity'] as num).toInt() : 2,
        likelihood: (json['likelihood'] is num)
            ? (json['likelihood'] as num).toInt()
            : 2,
      );
}

class DesignDeliverablesData {
  final DesignDeliverablesMetrics metrics;
  final List<DesignDeliverablePipelineItem> pipeline;
  final List<String> approvals;
  final List<DesignDeliverableRegisterItem> register;
  final List<String> dependencies;
  final List<String> handoffChecklist;

  const DesignDeliverablesData({
    this.metrics = const DesignDeliverablesMetrics(),
    this.pipeline = const [],
    this.approvals = const [],
    this.register = const [],
    this.dependencies = const [],
    this.handoffChecklist = const [],
  });

  bool get isEmpty =>
      pipeline.isEmpty &&
      approvals.isEmpty &&
      register.isEmpty &&
      dependencies.isEmpty &&
      handoffChecklist.isEmpty;

  DesignDeliverablesData copyWith({
    DesignDeliverablesMetrics? metrics,
    List<DesignDeliverablePipelineItem>? pipeline,
    List<String>? approvals,
    List<DesignDeliverableRegisterItem>? register,
    List<String>? dependencies,
    List<String>? handoffChecklist,
  }) {
    return DesignDeliverablesData(
      metrics: metrics ?? this.metrics,
      pipeline: pipeline ?? this.pipeline,
      approvals: approvals ?? this.approvals,
      register: register ?? this.register,
      dependencies: dependencies ?? this.dependencies,
      handoffChecklist: handoffChecklist ?? this.handoffChecklist,
    );
  }

  Map<String, dynamic> toJson() => {
        'metrics': metrics.toJson(),
        'pipeline': pipeline.map((item) => item.toJson()).toList(),
        'approvals': approvals,
        'register': register.map((item) => item.toJson()).toList(),
        'dependencies': dependencies,
        'handoffChecklist': handoffChecklist,
      };

  factory DesignDeliverablesData.fromJson(Map<String, dynamic> json) {
    return DesignDeliverablesData(
      metrics: DesignDeliverablesMetrics.fromJson(
          json['metrics'] as Map<String, dynamic>? ?? {}),
      pipeline: (json['pipeline'] as List?)
              ?.map((e) => DesignDeliverablePipelineItem.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
      approvals:
          (json['approvals'] as List?)?.map((e) => e.toString()).toList() ?? [],
      register: (json['register'] as List?)
              ?.map((e) => DesignDeliverableRegisterItem.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
      dependencies:
          (json['dependencies'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      handoffChecklist: (json['handoffChecklist'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  factory DesignDeliverablesData.fromMap(Map<String, dynamic> map) =>
      DesignDeliverablesData.fromJson(map);
}

class DesignDeliverablesMetrics {
  final int active;
  final int inReview;
  final int approved;
  final int atRisk;

  const DesignDeliverablesMetrics({
    this.active = 0,
    this.inReview = 0,
    this.approved = 0,
    this.atRisk = 0,
  });

  DesignDeliverablesMetrics copyWith({
    int? active,
    int? inReview,
    int? approved,
    int? atRisk,
  }) {
    return DesignDeliverablesMetrics(
      active: active ?? this.active,
      inReview: inReview ?? this.inReview,
      approved: approved ?? this.approved,
      atRisk: atRisk ?? this.atRisk,
    );
  }

  Map<String, dynamic> toJson() => {
        'active': active,
        'inReview': inReview,
        'approved': approved,
        'atRisk': atRisk,
      };

  factory DesignDeliverablesMetrics.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return DesignDeliverablesMetrics(
      active: toInt(json['active']),
      inReview: toInt(json['inReview'] ?? json['in_review']),
      approved: toInt(json['approved']),
      atRisk: toInt(json['atRisk'] ?? json['at_risk']),
    );
  }
}

class DesignDeliverablePipelineItem {
  final String label;
  final String status;

  const DesignDeliverablePipelineItem({
    this.label = '',
    this.status = '',
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'status': status,
      };

  factory DesignDeliverablePipelineItem.fromJson(Map<String, dynamic> json) {
    return DesignDeliverablePipelineItem(
      label: json['label']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class DesignDeliverableRegisterItem {
  final String name;
  final String owner;
  final String status;
  final String due;
  final String risk;

  const DesignDeliverableRegisterItem({
    this.name = '',
    this.owner = '',
    this.status = '',
    this.due = '',
    this.risk = '',
  });

  DesignDeliverableRegisterItem copyWith({
    String? name,
    String? owner,
    String? status,
    String? due,
    String? risk,
  }) {
    return DesignDeliverableRegisterItem(
      name: name ?? this.name,
      owner: owner ?? this.owner,
      status: status ?? this.status,
      due: due ?? this.due,
      risk: risk ?? this.risk,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'owner': owner,
        'status': status,
        'due': due,
        'risk': risk,
      };

  factory DesignDeliverableRegisterItem.fromJson(Map<String, dynamic> json) {
    return DesignDeliverableRegisterItem(
      name: json['name']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      due: json['due']?.toString() ?? '',
      risk: json['risk']?.toString() ?? '',
    );
  }
}

/// Field history tracking for undo functionality
class FieldHistory {
  final String fieldName;
  final List<String> history;
  final bool isAiGenerated;
  int currentIndex;

  FieldHistory({
    required this.fieldName,
    List<String>? history,
    this.isAiGenerated = false,
    int? currentIndex,
  })  : history = history ?? [],
        currentIndex = currentIndex ?? ((history?.length ?? 0) - 1);

  /// Add a value to history
  void addToHistory(String value) {
    if (history.isNotEmpty &&
        currentIndex >= 0 &&
        currentIndex < history.length &&
        history[currentIndex] == value) {
      return;
    }

    if (currentIndex < history.length - 1) {
      history.removeRange(currentIndex + 1, history.length);
    }

    history.add(value);
    currentIndex = history.length - 1;

    // Limit history to last 50 entries to prevent memory issues
    if (history.length > 50) {
      history.removeAt(0);
      currentIndex = history.length - 1;
    }
  }

  /// Undo the last change (remove last entry and return previous)
  String? undo() {
    if (canUndo) {
      currentIndex -= 1;
      return history[currentIndex];
    }
    return null;
  }

  /// Redo the next change and return it
  String? redo() {
    if (canRedo) {
      currentIndex += 1;
      return history[currentIndex];
    }
    return null;
  }

  /// Check if undo is possible
  bool get canUndo => currentIndex > 0 && history.isNotEmpty;

  /// Check if redo is possible
  bool get canRedo =>
      history.isNotEmpty &&
      currentIndex >= 0 &&
      currentIndex < history.length - 1;

  /// Get current value (last in history)
  String? get currentValue {
    if (history.isEmpty || currentIndex < 0 || currentIndex >= history.length) {
      return null;
    }
    return history[currentIndex];
  }

  Map<String, dynamic> toJson() => {
        'fieldName': fieldName,
        'history': history,
        'isAiGenerated': isAiGenerated,
        'currentIndex': currentIndex,
      };

  factory FieldHistory.fromJson(Map<String, dynamic> json) {
    final parsedHistory =
        (json['history'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final parsedIndex = json['currentIndex'] is int
        ? json['currentIndex'] as int
        : parsedHistory.length - 1;
    final clampedIndex = parsedHistory.isEmpty
        ? -1
        : parsedIndex.clamp(0, parsedHistory.length - 1);

    return FieldHistory(
      fieldName: json['fieldName']?.toString() ?? '',
      history: parsedHistory,
      isAiGenerated: json['isAiGenerated'] == true,
      currentIndex: clampedIndex,
    );
  }
}

class RoleDefinition {
  String id;
  String title;
  String description;
  String workstream;
  bool isPredefined;

  RoleDefinition({
    String? id,
    this.title = '',
    this.description = '',
    this.workstream = '',
    this.isPredefined = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'workstream': workstream,
        'isPredefined': isPredefined,
      };

  factory RoleDefinition.fromJson(Map<String, dynamic> json) {
    return RoleDefinition(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      workstream: json['workstream']?.toString() ?? '',
      isPredefined: json['isPredefined'] == true,
    );
  }
}

class RaciMatrixRow {
  String id;
  String role;
  String framework;
  String discipline;
  Map<String, String> assignments;

  RaciMatrixRow({
    String? id,
    this.role = '',
    this.framework = '',
    this.discipline = '',
    Map<String, String>? assignments,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        assignments = assignments ?? <String, String>{};

  RaciMatrixRow copyWith({
    String? id,
    String? role,
    String? framework,
    String? discipline,
    Map<String, String>? assignments,
  }) {
    return RaciMatrixRow(
      id: id ?? this.id,
      role: role ?? this.role,
      framework: framework ?? this.framework,
      discipline: discipline ?? this.discipline,
      assignments: assignments ?? Map<String, String>.from(this.assignments),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'framework': framework,
        'discipline': discipline,
        'assignments': assignments,
      };

  factory RaciMatrixRow.fromJson(Map<String, dynamic> json) {
    return RaciMatrixRow(
      id: json['id']?.toString(),
      role: json['role']?.toString() ?? '',
      framework: json['framework']?.toString() ?? '',
      discipline: json['discipline']?.toString() ?? '',
      assignments: (json['assignments'] as Map?)?.map((key, value) =>
              MapEntry(key.toString(), value?.toString() ?? '')) ??
          <String, String>{},
    );
  }
}

class StaffingRequirement {
  String id;
  String title;
  int headcount;
  double monthlyCost;
  double plannedMonths;
  String startDate;
  String endDate;
  String status;
  String personName;
  String employmentType; // FT or PT
  String location;
  String employeeType; // e.g., Employee, Contractor
  String notes;

  StaffingRequirement({
    String? id,
    this.title = '',
    this.headcount = 1,
    this.monthlyCost = 0,
    this.plannedMonths = 0,
    this.startDate = '',
    this.endDate = '',
    this.status = 'Not Started',
    this.personName = '',
    this.employmentType = 'FT',
    this.location = '',
    this.employeeType = 'Employee',
    this.notes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  double get estimatedTotal => headcount * monthlyCost * plannedMonths;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'headcount': headcount,
        'monthlyCost': monthlyCost,
        'plannedMonths': plannedMonths,
        'startDate': startDate,
        'endDate': endDate,
        'status': status,
        'personName': personName,
        'employmentType': employmentType,
        'location': location,
        'employeeType': employeeType,
        'notes': notes,
      };

  factory StaffingRequirement.fromJson(Map<String, dynamic> json) {
    return StaffingRequirement(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      headcount: json['headcount'] as int? ?? 1,
      monthlyCost: json['monthlyCost'] is num
          ? (json['monthlyCost'] as num).toDouble()
          : double.tryParse(json['monthlyCost']?.toString() ?? '') ?? 0,
      plannedMonths: json['plannedMonths'] is num
          ? (json['plannedMonths'] as num).toDouble()
          : double.tryParse(json['plannedMonths']?.toString() ?? '') ?? 0,
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Not Started',
      personName: json['personName']?.toString() ?? '',
      employmentType: json['employmentType']?.toString() ?? 'FT',
      location: json['location']?.toString() ?? '',
      employeeType: json['employeeType']?.toString() ?? 'Employee',
      notes: json['notes']?.toString() ?? '',
    );
  }

  StaffingRequirement copyWith({
    String? title,
    int? headcount,
    double? monthlyCost,
    double? plannedMonths,
    String? startDate,
    String? endDate,
    String? status,
    String? personName,
    String? employmentType,
    String? location,
    String? employeeType,
    String? notes,
  }) {
    return StaffingRequirement(
      id: id,
      title: title ?? this.title,
      headcount: headcount ?? this.headcount,
      monthlyCost: monthlyCost ?? this.monthlyCost,
      plannedMonths: plannedMonths ?? this.plannedMonths,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      personName: personName ?? this.personName,
      employmentType: employmentType ?? this.employmentType,
      location: location ?? this.location,
      employeeType: employeeType ?? this.employeeType,
      notes: notes ?? this.notes,
    );
  }
}

class TrainingActivity {
  String id;
  String title;
  String description;
  String date;
  String duration;
  String category; // Training or Team Building
  String status;
  bool isMandatory;
  String? attachedFile;
  String? attachedFileUrl;
  String? attachedFileStoragePath;
  bool isCompleted;

  TrainingActivity({
    String? id,
    this.title = '',
    this.description = '',
    this.date = '',
    this.duration = '',
    this.category = 'Training',
    this.status = 'Upcoming',
    this.isMandatory = false,
    this.attachedFile,
    this.attachedFileUrl,
    this.attachedFileStoragePath,
    this.isCompleted = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date,
        'duration': duration,
        'category': category,
        'status': status,
        'isMandatory': isMandatory,
        'attachedFile': attachedFile,
        'attachedFileUrl': attachedFileUrl,
        'attachedFileStoragePath': attachedFileStoragePath,
        'isCompleted': isCompleted,
      };

  factory TrainingActivity.fromJson(Map<String, dynamic> json) {
    return TrainingActivity(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Training',
      status: json['status']?.toString() ?? 'Upcoming',
      isMandatory: json['isMandatory'] == true,
      attachedFile: json['attachedFile']?.toString(),
      attachedFileUrl: json['attachedFileUrl']?.toString(),
      attachedFileStoragePath: json['attachedFileStoragePath']?.toString(),
      isCompleted: json['isCompleted'] == true,
    );
  }

  TrainingActivity copyWith({
    String? title,
    String? description,
    String? date,
    String? duration,
    String? category,
    String? status,
    bool? isMandatory,
    String? attachedFile,
    String? attachedFileUrl,
    String? attachedFileStoragePath,
    bool? isCompleted,
    bool clearAttachment = false,
  }) {
    return TrainingActivity(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      duration: duration ?? this.duration,
      category: category ?? this.category,
      status: status ?? this.status,
      isMandatory: isMandatory ?? this.isMandatory,
      attachedFile:
          clearAttachment ? null : (attachedFile ?? this.attachedFile),
      attachedFileUrl:
          clearAttachment ? null : (attachedFileUrl ?? this.attachedFileUrl),
      attachedFileStoragePath: clearAttachment
          ? null
          : (attachedFileStoragePath ?? this.attachedFileStoragePath),
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class StakeholderEntry {
  final String id;
  final String name;
  final String organization;
  final String role;
  final String influence;
  final String interest;
  final String channel;
  final String contactInfo;
  final String owner;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  StakeholderEntry({
    required this.id,
    required this.name,
    required this.organization,
    required this.role,
    required this.influence,
    required this.interest,
    required this.channel,
    required this.contactInfo,
    required this.owner,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StakeholderEntry.empty() {
    final now = DateTime.now();
    return StakeholderEntry(
      id: now.microsecondsSinceEpoch.toString(),
      name: '',
      organization: '',
      role: '',
      influence: 'Medium',
      interest: 'Medium',
      channel: '',
      contactInfo: '',
      owner: '',
      notes: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  StakeholderEntry copyWith({
    String? name,
    String? organization,
    String? role,
    String? influence,
    String? interest,
    String? channel,
    String? contactInfo,
    String? owner,
    String? notes,
    DateTime? updatedAt,
  }) {
    return StakeholderEntry(
      id: id,
      name: name ?? this.name,
      organization: organization ?? this.organization,
      role: role ?? this.role,
      influence: influence ?? this.influence,
      interest: interest ?? this.interest,
      channel: channel ?? this.channel,
      contactInfo: contactInfo ?? this.contactInfo,
      owner: owner ?? this.owner,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'organization': organization,
        'role': role,
        'influence': influence,
        'interest': interest,
        'channel': channel,
        'contactInfo': contactInfo,
        'owner': owner,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StakeholderEntry.fromJson(Map<String, dynamic> json) {
    return StakeholderEntry(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      organization: json['organization']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      influence: json['influence']?.toString() ?? 'Medium',
      interest: json['interest']?.toString() ?? 'Medium',
      channel: json['channel']?.toString() ?? '',
      contactInfo: json['contactInfo']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class EngagementPlanEntry {
  final String id;
  final String stakeholder;
  final String objective;
  final String method;
  final String frequency;
  final String owner;
  final String status;
  final String nextTouchpoint;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  EngagementPlanEntry({
    required this.id,
    required this.stakeholder,
    required this.objective,
    required this.method,
    required this.frequency,
    required this.owner,
    required this.status,
    required this.nextTouchpoint,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EngagementPlanEntry.empty() {
    final now = DateTime.now();
    return EngagementPlanEntry(
      id: now.microsecondsSinceEpoch.toString(),
      stakeholder: '',
      objective: '',
      method: '',
      frequency: '',
      owner: '',
      status: 'Planned',
      nextTouchpoint: '',
      notes: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  EngagementPlanEntry copyWith({
    String? stakeholder,
    String? objective,
    String? method,
    String? frequency,
    String? owner,
    String? status,
    String? nextTouchpoint,
    String? notes,
    DateTime? updatedAt,
  }) {
    return EngagementPlanEntry(
      id: id,
      stakeholder: stakeholder ?? this.stakeholder,
      objective: objective ?? this.objective,
      method: method ?? this.method,
      frequency: frequency ?? this.frequency,
      owner: owner ?? this.owner,
      status: status ?? this.status,
      nextTouchpoint: nextTouchpoint ?? this.nextTouchpoint,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'stakeholder': stakeholder,
        'objective': objective,
        'method': method,
        'frequency': frequency,
        'owner': owner,
        'status': status,
        'nextTouchpoint': nextTouchpoint,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory EngagementPlanEntry.fromJson(Map<String, dynamic> json) {
    return EngagementPlanEntry(
      id: json['id']?.toString() ?? '',
      stakeholder: json['stakeholder']?.toString() ?? '',
      objective: json['objective']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Planned',
      nextTouchpoint: json['nextTouchpoint']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

enum QualityTargetStatus { onTrack, monitoring, offTrack }

class QualityTarget {
  final String id;
  final String name;
  final String metric;
  final String target;
  final String current;
  final QualityTargetStatus status;

  QualityTarget({
    required this.id,
    required this.name,
    required this.metric,
    required this.target,
    required this.current,
    required this.status,
  });

  factory QualityTarget.empty() {
    return QualityTarget(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: '',
      metric: '',
      target: '',
      current: '',
      status: QualityTargetStatus.onTrack,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'metric': metric,
        'target': target,
        'current': current,
        'status': status.index,
      };

  factory QualityTarget.fromJson(Map<String, dynamic> json) {
    var statusValue = json['status'];
    QualityTargetStatus status;
    if (statusValue is int) {
      status = QualityTargetStatus.values[statusValue];
    } else {
      status = QualityTargetStatus.onTrack;
    }

    return QualityTarget(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      metric: json['metric']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
      current: json['current']?.toString() ?? '',
      status: status,
    );
  }

  QualityTarget copyWith({
    String? name,
    String? metric,
    String? target,
    String? current,
    QualityTargetStatus? status,
  }) {
    return QualityTarget(
      id: id,
      name: name ?? this.name,
      metric: metric ?? this.metric,
      target: target ?? this.target,
      current: current ?? this.current,
      status: status ?? this.status,
    );
  }
}

class QaTechnique {
  final String id;
  final String name;
  final String description;
  final String frequency;
  final String standards;

  QaTechnique({
    required this.id,
    required this.name,
    required this.description,
    required this.frequency,
    required this.standards,
  });

  factory QaTechnique.empty() {
    return QaTechnique(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: '',
      description: '',
      frequency: '',
      standards: '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'frequency': frequency,
        'standards': standards,
      };

  factory QaTechnique.fromJson(Map<String, dynamic> json) {
    return QaTechnique(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      standards: json['standards']?.toString() ?? '',
    );
  }

  QaTechnique copyWith({
    String? name,
    String? description,
    String? frequency,
    String? standards,
  }) {
    return QaTechnique(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      standards: standards ?? this.standards,
    );
  }
}

class QcTechnique {
  final String id;
  final String name;
  final String description;
  final String frequency;

  QcTechnique({
    required this.id,
    required this.name,
    required this.description,
    required this.frequency,
  });

  factory QcTechnique.empty() {
    return QcTechnique(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: '',
      description: '',
      frequency: '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'frequency': frequency,
      };

  factory QcTechnique.fromJson(Map<String, dynamic> json) {
    return QcTechnique(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
    );
  }

  QcTechnique copyWith({
    String? name,
    String? description,
    String? frequency,
  }) {
    return QcTechnique(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
    );
  }
}

enum QualityWorkflowType { qa, qc }

enum QualityTaskStatus { notStarted, inProgress, complete, blocked }

enum QualityTaskPriority { minimal, moderate, critical }

enum AuditResultStatus { pass, conditional, fail, pending }

enum CorrectiveActionStatus { open, inProgress, verified, closed, overdue }

String _normalizeQualityEnumToken(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

QualityWorkflowType _parseWorkflowType(dynamic raw) {
  if (raw is int && raw >= 0 && raw < QualityWorkflowType.values.length) {
    return QualityWorkflowType.values[raw];
  }
  final token = _normalizeQualityEnumToken(raw?.toString() ?? '');
  return token == 'qc' ? QualityWorkflowType.qc : QualityWorkflowType.qa;
}

QualityTaskStatus _parseQualityTaskStatus(dynamic raw) {
  if (raw is int && raw >= 0 && raw < QualityTaskStatus.values.length) {
    return QualityTaskStatus.values[raw];
  }
  final token = _normalizeQualityEnumToken(raw?.toString() ?? '');
  switch (token) {
    case 'inprogress':
      return QualityTaskStatus.inProgress;
    case 'complete':
    case 'completed':
      return QualityTaskStatus.complete;
    case 'blocked':
      return QualityTaskStatus.blocked;
    default:
      return QualityTaskStatus.notStarted;
  }
}

QualityTaskPriority _parseQualityTaskPriority(dynamic raw) {
  if (raw is int && raw >= 0 && raw < QualityTaskPriority.values.length) {
    return QualityTaskPriority.values[raw];
  }
  final token = _normalizeQualityEnumToken(raw?.toString() ?? '');
  switch (token) {
    case 'moderate':
    case 'medium':
      return QualityTaskPriority.moderate;
    case 'critical':
    case 'high':
      return QualityTaskPriority.critical;
    default:
      return QualityTaskPriority.minimal;
  }
}

AuditResultStatus _parseAuditResultStatus(dynamic raw) {
  if (raw is int && raw >= 0 && raw < AuditResultStatus.values.length) {
    return AuditResultStatus.values[raw];
  }
  final token = _normalizeQualityEnumToken(raw?.toString() ?? '');
  switch (token) {
    case 'pass':
    case 'passed':
      return AuditResultStatus.pass;
    case 'conditional':
      return AuditResultStatus.conditional;
    case 'fail':
    case 'failed':
      return AuditResultStatus.fail;
    default:
      return AuditResultStatus.pending;
  }
}

CorrectiveActionStatus _parseCorrectiveActionStatus(dynamic raw) {
  if (raw is int && raw >= 0 && raw < CorrectiveActionStatus.values.length) {
    return CorrectiveActionStatus.values[raw];
  }
  final token = _normalizeQualityEnumToken(raw?.toString() ?? '');
  switch (token) {
    case 'inprogress':
      return CorrectiveActionStatus.inProgress;
    case 'verified':
      return CorrectiveActionStatus.verified;
    case 'closed':
      return CorrectiveActionStatus.closed;
    case 'overdue':
      return CorrectiveActionStatus.overdue;
    default:
      return CorrectiveActionStatus.open;
  }
}

String _objectiveStatusFromTargetStatus(QualityTargetStatus status) {
  switch (status) {
    case QualityTargetStatus.onTrack:
      return 'On Track';
    case QualityTargetStatus.monitoring:
      return 'Monitoring';
    case QualityTargetStatus.offTrack:
      return 'Off Track';
  }
}

class QualityStandard {
  final String id;
  final String name;
  final String source;
  final String category;
  final String description;
  final String applicability;

  QualityStandard({
    required this.id,
    required this.name,
    required this.source,
    required this.category,
    required this.description,
    required this.applicability,
  });

  factory QualityStandard.empty() => QualityStandard(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: '',
        source: '',
        category: '',
        description: '',
        applicability: '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source,
        'category': category,
        'description': description,
        'applicability': applicability,
      };

  factory QualityStandard.fromJson(Map<String, dynamic> json) {
    return QualityStandard(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      applicability: json['applicability']?.toString() ?? '',
    );
  }

  QualityStandard copyWith({
    String? name,
    String? source,
    String? category,
    String? description,
    String? applicability,
  }) {
    return QualityStandard(
      id: id,
      name: name ?? this.name,
      source: source ?? this.source,
      category: category ?? this.category,
      description: description ?? this.description,
      applicability: applicability ?? this.applicability,
    );
  }
}

class QualityObjective {
  final String id;
  final String title;
  final String acceptanceCriteria;
  final String successMetric;
  final String targetValue;
  final String currentValue;
  final String owner;
  final String linkedRequirement;
  final String linkedWbs;
  final String status;

  QualityObjective({
    required this.id,
    required this.title,
    required this.acceptanceCriteria,
    required this.successMetric,
    required this.targetValue,
    required this.currentValue,
    required this.owner,
    required this.linkedRequirement,
    required this.linkedWbs,
    required this.status,
  });

  factory QualityObjective.empty() => QualityObjective(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: '',
        acceptanceCriteria: '',
        successMetric: '',
        targetValue: '',
        currentValue: '',
        owner: '',
        linkedRequirement: '',
        linkedWbs: '',
        status: 'Draft',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'acceptanceCriteria': acceptanceCriteria,
        'successMetric': successMetric,
        'targetValue': targetValue,
        'currentValue': currentValue,
        'owner': owner,
        'linkedRequirement': linkedRequirement,
        'linkedWbs': linkedWbs,
        'status': status,
      };

  factory QualityObjective.fromJson(Map<String, dynamic> json) {
    return QualityObjective(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      acceptanceCriteria: json['acceptanceCriteria']?.toString() ?? '',
      successMetric: json['successMetric']?.toString() ?? '',
      targetValue: json['targetValue']?.toString() ?? '',
      currentValue: json['currentValue']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      linkedRequirement: json['linkedRequirement']?.toString() ?? '',
      linkedWbs: json['linkedWbs']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Draft',
    );
  }

  QualityObjective copyWith({
    String? title,
    String? acceptanceCriteria,
    String? successMetric,
    String? targetValue,
    String? currentValue,
    String? owner,
    String? linkedRequirement,
    String? linkedWbs,
    String? status,
  }) {
    return QualityObjective(
      id: id,
      title: title ?? this.title,
      acceptanceCriteria: acceptanceCriteria ?? this.acceptanceCriteria,
      successMetric: successMetric ?? this.successMetric,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      owner: owner ?? this.owner,
      linkedRequirement: linkedRequirement ?? this.linkedRequirement,
      linkedWbs: linkedWbs ?? this.linkedWbs,
      status: status ?? this.status,
    );
  }
}

class QualityWorkflowControl {
  final String id;
  final QualityWorkflowType type;
  final String name;
  final String method;
  final String tools;
  final String checklist;
  final String frequency;
  final String owner;
  final String standardsReference;

  QualityWorkflowControl({
    required this.id,
    required this.type,
    required this.name,
    required this.method,
    required this.tools,
    required this.checklist,
    required this.frequency,
    required this.owner,
    required this.standardsReference,
  });

  factory QualityWorkflowControl.empty(QualityWorkflowType type) =>
      QualityWorkflowControl(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: type,
        name: '',
        method: '',
        tools: '',
        checklist: '',
        frequency: '',
        owner: '',
        standardsReference: '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'name': name,
        'method': method,
        'tools': tools,
        'checklist': checklist,
        'frequency': frequency,
        'owner': owner,
        'standardsReference': standardsReference,
      };

  factory QualityWorkflowControl.fromJson(Map<String, dynamic> json) {
    return QualityWorkflowControl(
      id: json['id']?.toString() ?? '',
      type: _parseWorkflowType(json['type']),
      name: json['name']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      tools: json['tools']?.toString() ?? '',
      checklist: json['checklist']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      standardsReference: json['standardsReference']?.toString() ?? '',
    );
  }

  QualityWorkflowControl copyWith({
    QualityWorkflowType? type,
    String? name,
    String? method,
    String? tools,
    String? checklist,
    String? frequency,
    String? owner,
    String? standardsReference,
  }) {
    return QualityWorkflowControl(
      id: id,
      type: type ?? this.type,
      name: name ?? this.name,
      method: method ?? this.method,
      tools: tools ?? this.tools,
      checklist: checklist ?? this.checklist,
      frequency: frequency ?? this.frequency,
      owner: owner ?? this.owner,
      standardsReference: standardsReference ?? this.standardsReference,
    );
  }
}

class QualityAuditEntry {
  final String id;
  final String title;
  final String scope;
  final String plannedDate;
  final String completedDate;
  final String owner;
  final AuditResultStatus result;
  final String findings;
  final String notes;

  QualityAuditEntry({
    required this.id,
    required this.title,
    required this.scope,
    required this.plannedDate,
    required this.completedDate,
    required this.owner,
    required this.result,
    required this.findings,
    required this.notes,
  });

  factory QualityAuditEntry.empty() => QualityAuditEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: '',
        scope: '',
        plannedDate: '',
        completedDate: '',
        owner: '',
        result: AuditResultStatus.pending,
        findings: '',
        notes: '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'scope': scope,
        'plannedDate': plannedDate,
        'completedDate': completedDate,
        'owner': owner,
        'result': result.index,
        'findings': findings,
        'notes': notes,
      };

  factory QualityAuditEntry.fromJson(Map<String, dynamic> json) {
    return QualityAuditEntry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      scope: json['scope']?.toString() ?? '',
      plannedDate: json['plannedDate']?.toString() ?? '',
      completedDate: json['completedDate']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      result: _parseAuditResultStatus(json['result']),
      findings: json['findings']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }

  QualityAuditEntry copyWith({
    String? title,
    String? scope,
    String? plannedDate,
    String? completedDate,
    String? owner,
    AuditResultStatus? result,
    String? findings,
    String? notes,
  }) {
    return QualityAuditEntry(
      id: id,
      title: title ?? this.title,
      scope: scope ?? this.scope,
      plannedDate: plannedDate ?? this.plannedDate,
      completedDate: completedDate ?? this.completedDate,
      owner: owner ?? this.owner,
      result: result ?? this.result,
      findings: findings ?? this.findings,
      notes: notes ?? this.notes,
    );
  }
}

class QualityTaskEntry {
  final String id;
  final String task;
  final double percentComplete;
  final String responsible;
  final String startDate;
  final String endDate;
  final int? durationDays;
  final QualityTaskStatus status;
  final QualityTaskPriority priority;
  final String comments;
  final String? resolvedDate;

  QualityTaskEntry({
    required this.id,
    required this.task,
    required this.percentComplete,
    required this.responsible,
    required this.startDate,
    required this.endDate,
    required this.durationDays,
    required this.status,
    required this.priority,
    required this.comments,
    required this.resolvedDate,
  });

  factory QualityTaskEntry.empty() => QualityTaskEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        task: '',
        percentComplete: 0.0,
        responsible: '',
        startDate: '',
        endDate: '',
        durationDays: null,
        status: QualityTaskStatus.notStarted,
        priority: QualityTaskPriority.minimal,
        comments: '',
        resolvedDate: null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'task': task,
        'percentComplete': percentComplete,
        'responsible': responsible,
        'startDate': startDate,
        'endDate': endDate,
        'durationDays': durationDays,
        'status': status.index,
        'priority': priority.index,
        'comments': comments,
        'resolvedDate': resolvedDate,
      };

  factory QualityTaskEntry.fromJson(Map<String, dynamic> json) {
    double parsePercent(dynamic raw) {
      if (raw is num) return raw.toDouble();
      final token = raw?.toString() ?? '';
      final cleaned = token.replaceAll('%', '').trim();
      return double.tryParse(cleaned) ?? 0.0;
    }

    int? parseDuration(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.round();
      return int.tryParse(raw?.toString() ?? '');
    }

    return QualityTaskEntry(
      id: json['id']?.toString() ?? '',
      task: json['task']?.toString() ?? '',
      percentComplete: parsePercent(json['percentComplete']),
      responsible: json['responsible']?.toString() ?? '',
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      durationDays: parseDuration(json['durationDays']),
      status: _parseQualityTaskStatus(json['status']),
      priority: _parseQualityTaskPriority(json['priority']),
      comments: json['comments']?.toString() ?? '',
      resolvedDate: json['resolvedDate']?.toString(),
    );
  }

  QualityTaskEntry copyWith({
    String? task,
    double? percentComplete,
    String? responsible,
    String? startDate,
    String? endDate,
    int? durationDays,
    QualityTaskStatus? status,
    QualityTaskPriority? priority,
    String? comments,
    String? resolvedDate,
  }) {
    return QualityTaskEntry(
      id: id,
      task: task ?? this.task,
      percentComplete: percentComplete ?? this.percentComplete,
      responsible: responsible ?? this.responsible,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      durationDays: durationDays ?? this.durationDays,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      comments: comments ?? this.comments,
      resolvedDate: resolvedDate ?? this.resolvedDate,
    );
  }
}

class CorrectiveActionEntry {
  final String id;
  final String auditEntryId;
  final String title;
  final String rootCause;
  final String action;
  final String owner;
  final String dueDate;
  final CorrectiveActionStatus status;
  final String createdAt;
  final String closedAt;
  final String verificationNotes;

  CorrectiveActionEntry({
    required this.id,
    required this.auditEntryId,
    required this.title,
    required this.rootCause,
    required this.action,
    required this.owner,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    required this.closedAt,
    required this.verificationNotes,
  });

  factory CorrectiveActionEntry.empty() {
    final now = DateTime.now().toIso8601String();
    return CorrectiveActionEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      auditEntryId: '',
      title: '',
      rootCause: '',
      action: '',
      owner: '',
      dueDate: '',
      status: CorrectiveActionStatus.open,
      createdAt: now,
      closedAt: '',
      verificationNotes: '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'auditEntryId': auditEntryId,
        'title': title,
        'rootCause': rootCause,
        'action': action,
        'owner': owner,
        'dueDate': dueDate,
        'status': status.index,
        'createdAt': createdAt,
        'closedAt': closedAt,
        'verificationNotes': verificationNotes,
      };

  factory CorrectiveActionEntry.fromJson(Map<String, dynamic> json) {
    return CorrectiveActionEntry(
      id: json['id']?.toString() ?? '',
      auditEntryId: json['auditEntryId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      rootCause: json['rootCause']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      dueDate: json['dueDate']?.toString() ?? '',
      status: _parseCorrectiveActionStatus(json['status']),
      createdAt: json['createdAt']?.toString() ?? '',
      closedAt: json['closedAt']?.toString() ?? '',
      verificationNotes: json['verificationNotes']?.toString() ?? '',
    );
  }

  CorrectiveActionEntry copyWith({
    String? auditEntryId,
    String? title,
    String? rootCause,
    String? action,
    String? owner,
    String? dueDate,
    CorrectiveActionStatus? status,
    String? createdAt,
    String? closedAt,
    String? verificationNotes,
  }) {
    return CorrectiveActionEntry(
      id: id,
      auditEntryId: auditEntryId ?? this.auditEntryId,
      title: title ?? this.title,
      rootCause: rootCause ?? this.rootCause,
      action: action ?? this.action,
      owner: owner ?? this.owner,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      closedAt: closedAt ?? this.closedAt,
      verificationNotes: verificationNotes ?? this.verificationNotes,
    );
  }
}

class QualityChangeEntry {
  final String id;
  final String description;
  final String reason;
  final String requestedBy;
  final String approvedBy;
  final String date;
  final String status;

  QualityChangeEntry({
    required this.id,
    required this.description,
    required this.reason,
    required this.requestedBy,
    required this.approvedBy,
    required this.date,
    required this.status,
  });

  factory QualityChangeEntry.empty() => QualityChangeEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        description: '',
        reason: '',
        requestedBy: '',
        approvedBy: '',
        date: '',
        status: 'Draft',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'reason': reason,
        'requestedBy': requestedBy,
        'approvedBy': approvedBy,
        'date': date,
        'status': status,
      };

  factory QualityChangeEntry.fromJson(Map<String, dynamic> json) {
    return QualityChangeEntry(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      requestedBy: json['requestedBy']?.toString() ?? '',
      approvedBy: json['approvedBy']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Draft',
    );
  }

  QualityChangeEntry copyWith({
    String? description,
    String? reason,
    String? requestedBy,
    String? approvedBy,
    String? date,
    String? status,
  }) {
    return QualityChangeEntry(
      id: id,
      description: description ?? this.description,
      reason: reason ?? this.reason,
      requestedBy: requestedBy ?? this.requestedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      date: date ?? this.date,
      status: status ?? this.status,
    );
  }
}

class QualityDashboardConfig {
  final double targetTimeToResolutionDays;
  final bool allowManualMetricsOverride;
  final int maxTrendPoints;

  const QualityDashboardConfig({
    this.targetTimeToResolutionDays = 15,
    this.allowManualMetricsOverride = true,
    this.maxTrendPoints = 12,
  });

  factory QualityDashboardConfig.empty() => const QualityDashboardConfig();

  Map<String, dynamic> toJson() => {
        'targetTimeToResolutionDays': targetTimeToResolutionDays,
        'allowManualMetricsOverride': allowManualMetricsOverride,
        'maxTrendPoints': maxTrendPoints,
      };

  factory QualityDashboardConfig.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic raw, double fallback) {
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '') ?? fallback;
    }

    return QualityDashboardConfig(
      targetTimeToResolutionDays:
          parseDouble(json['targetTimeToResolutionDays'], 15),
      allowManualMetricsOverride: json['allowManualMetricsOverride'] != false,
      maxTrendPoints: (json['maxTrendPoints'] is int)
          ? json['maxTrendPoints'] as int
          : int.tryParse(json['maxTrendPoints']?.toString() ?? '') ?? 12,
    );
  }

  QualityDashboardConfig copyWith({
    double? targetTimeToResolutionDays,
    bool? allowManualMetricsOverride,
    int? maxTrendPoints,
  }) {
    return QualityDashboardConfig(
      targetTimeToResolutionDays:
          targetTimeToResolutionDays ?? this.targetTimeToResolutionDays,
      allowManualMetricsOverride:
          allowManualMetricsOverride ?? this.allowManualMetricsOverride,
      maxTrendPoints: maxTrendPoints ?? this.maxTrendPoints,
    );
  }
}

class QualityComputedSnapshot {
  final double averageTimeToResolutionDays;
  final double targetTimeToResolutionDays;
  final double averageTaskCompletionPercent;
  final double plannedAuditsCompletionPercent;
  final Map<String, int> statusTallies;
  final Map<String, int> priorityTallies;
  final List<double> defectTrendData;
  final List<double> satisfactionTrendData;
  final String generatedAt;

  const QualityComputedSnapshot({
    required this.averageTimeToResolutionDays,
    required this.targetTimeToResolutionDays,
    required this.averageTaskCompletionPercent,
    required this.plannedAuditsCompletionPercent,
    required this.statusTallies,
    required this.priorityTallies,
    required this.defectTrendData,
    required this.satisfactionTrendData,
    required this.generatedAt,
  });

  factory QualityComputedSnapshot.empty() => QualityComputedSnapshot(
        averageTimeToResolutionDays: 0,
        targetTimeToResolutionDays: 15,
        averageTaskCompletionPercent: 0,
        plannedAuditsCompletionPercent: 0,
        statusTallies: const {
          'notStarted': 0,
          'inProgress': 0,
          'complete': 0,
          'blocked': 0,
        },
        priorityTallies: const {
          'minimal': 0,
          'moderate': 0,
          'critical': 0,
        },
        defectTrendData: const [],
        satisfactionTrendData: const [],
        generatedAt: '',
      );

  Map<String, dynamic> toJson() => {
        'averageTimeToResolutionDays': averageTimeToResolutionDays,
        'targetTimeToResolutionDays': targetTimeToResolutionDays,
        'averageTaskCompletionPercent': averageTaskCompletionPercent,
        'plannedAuditsCompletionPercent': plannedAuditsCompletionPercent,
        'statusTallies': statusTallies,
        'priorityTallies': priorityTallies,
        'defectTrendData': defectTrendData,
        'satisfactionTrendData': satisfactionTrendData,
        'generatedAt': generatedAt,
      };

  factory QualityComputedSnapshot.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '') ?? 0;
    }

    Map<String, int> parseIntMap(dynamic raw) {
      if (raw is! Map) return const {};
      final map = <String, int>{};
      raw.forEach((key, value) {
        if (value is int) {
          map[key.toString()] = value;
        } else if (value is num) {
          map[key.toString()] = value.round();
        } else {
          map[key.toString()] = int.tryParse(value.toString()) ?? 0;
        }
      });
      return map;
    }

    List<double> parseDoubleList(dynamic raw) {
      if (raw is! List) return const [];
      return raw.map((e) => parseDouble(e)).toList();
    }

    return QualityComputedSnapshot(
      averageTimeToResolutionDays:
          parseDouble(json['averageTimeToResolutionDays']),
      targetTimeToResolutionDays:
          parseDouble(json['targetTimeToResolutionDays']),
      averageTaskCompletionPercent:
          parseDouble(json['averageTaskCompletionPercent']),
      plannedAuditsCompletionPercent:
          parseDouble(json['plannedAuditsCompletionPercent']),
      statusTallies: parseIntMap(json['statusTallies']),
      priorityTallies: parseIntMap(json['priorityTallies']),
      defectTrendData: parseDoubleList(json['defectTrendData']),
      satisfactionTrendData: parseDoubleList(json['satisfactionTrendData']),
      generatedAt: json['generatedAt']?.toString() ?? '',
    );
  }

  QualityComputedSnapshot copyWith({
    double? averageTimeToResolutionDays,
    double? targetTimeToResolutionDays,
    double? averageTaskCompletionPercent,
    double? plannedAuditsCompletionPercent,
    Map<String, int>? statusTallies,
    Map<String, int>? priorityTallies,
    List<double>? defectTrendData,
    List<double>? satisfactionTrendData,
    String? generatedAt,
  }) {
    return QualityComputedSnapshot(
      averageTimeToResolutionDays:
          averageTimeToResolutionDays ?? this.averageTimeToResolutionDays,
      targetTimeToResolutionDays:
          targetTimeToResolutionDays ?? this.targetTimeToResolutionDays,
      averageTaskCompletionPercent:
          averageTaskCompletionPercent ?? this.averageTaskCompletionPercent,
      plannedAuditsCompletionPercent:
          plannedAuditsCompletionPercent ?? this.plannedAuditsCompletionPercent,
      statusTallies: statusTallies ?? this.statusTallies,
      priorityTallies: priorityTallies ?? this.priorityTallies,
      defectTrendData: defectTrendData ?? this.defectTrendData,
      satisfactionTrendData:
          satisfactionTrendData ?? this.satisfactionTrendData,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}

class QualitySeedBundle {
  final List<QualityStandard> standards;
  final List<QualityObjective> objectives;
  final List<QualityWorkflowControl> workflowControls;
  final List<QualityAuditEntry> auditPlan;
  final QualityDashboardConfig dashboardConfig;

  QualitySeedBundle({
    required this.standards,
    required this.objectives,
    required this.workflowControls,
    required this.auditPlan,
    required this.dashboardConfig,
  });

  factory QualitySeedBundle.empty() => QualitySeedBundle(
        standards: const [],
        objectives: const [],
        workflowControls: const [],
        auditPlan: const [],
        dashboardConfig: QualityDashboardConfig.empty(),
      );

  Map<String, dynamic> toJson() => {
        'standards': standards.map((e) => e.toJson()).toList(),
        'objectives': objectives.map((e) => e.toJson()).toList(),
        'workflowControls': workflowControls.map((e) => e.toJson()).toList(),
        'auditPlan': auditPlan.map((e) => e.toJson()).toList(),
        'dashboardConfig': dashboardConfig.toJson(),
      };

  factory QualitySeedBundle.fromJson(Map<String, dynamic> json) {
    return QualitySeedBundle(
      standards: (json['standards'] as List?)
              ?.map((e) => QualityStandard.fromJson(e))
              .toList() ??
          [],
      objectives: (json['objectives'] as List?)
              ?.map((e) => QualityObjective.fromJson(e))
              .toList() ??
          [],
      workflowControls: (json['workflowControls'] as List?)
              ?.map((e) => QualityWorkflowControl.fromJson(e))
              .toList() ??
          [],
      auditPlan: (json['auditPlan'] as List?)
              ?.map((e) => QualityAuditEntry.fromJson(e))
              .toList() ??
          [],
      dashboardConfig: json['dashboardConfig'] != null
          ? QualityDashboardConfig.fromJson(
              Map<String, dynamic>.from(json['dashboardConfig'] as Map))
          : QualityDashboardConfig.empty(),
    );
  }
}

class MetricValue {
  final String value;
  final String unit;
  final String change;
  final String trendDirection; // "up", "down", "neutral"

  MetricValue({
    this.value = '',
    this.unit = '',
    this.change = '',
    this.trendDirection = 'neutral',
  });

  factory MetricValue.empty() => MetricValue();

  Map<String, dynamic> toJson() => {
        'value': value,
        'unit': unit,
        'change': change,
        'trendDirection': trendDirection,
      };

  factory MetricValue.fromJson(Map<String, dynamic> json) {
    return MetricValue(
      value: json['value']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      change: json['change']?.toString() ?? '',
      trendDirection: json['trendDirection']?.toString() ?? 'neutral',
    );
  }

  MetricValue copyWith({
    String? value,
    String? unit,
    String? change,
    String? trendDirection,
  }) {
    return MetricValue(
      value: value ?? this.value,
      unit: unit ?? this.unit,
      change: change ?? this.change,
      trendDirection: trendDirection ?? this.trendDirection,
    );
  }
}

class QualityMetrics {
  final MetricValue defectDensity;
  final MetricValue customerSatisfaction;
  final MetricValue onTimeDelivery;
  final List<double> defectTrendData;
  final List<double> satisfactionTrendData;

  QualityMetrics({
    required this.defectDensity,
    required this.customerSatisfaction,
    required this.onTimeDelivery,
    required this.defectTrendData,
    required this.satisfactionTrendData,
  });

  factory QualityMetrics.empty() {
    return QualityMetrics(
      defectDensity: MetricValue.empty(),
      customerSatisfaction: MetricValue.empty(),
      onTimeDelivery: MetricValue.empty(),
      defectTrendData: [],
      satisfactionTrendData: [],
    );
  }

  Map<String, dynamic> toJson() => {
        'defectDensity': defectDensity.toJson(),
        'customerSatisfaction': customerSatisfaction.toJson(),
        'onTimeDelivery': onTimeDelivery.toJson(),
        'defectTrendData': defectTrendData,
        'satisfactionTrendData': satisfactionTrendData,
      };

  factory QualityMetrics.fromJson(Map<String, dynamic> json) {
    return QualityMetrics(
      defectDensity: json['defectDensity'] != null
          ? MetricValue.fromJson(json['defectDensity'])
          : MetricValue.empty(),
      customerSatisfaction: json['customerSatisfaction'] != null
          ? MetricValue.fromJson(json['customerSatisfaction'])
          : MetricValue.empty(),
      onTimeDelivery: json['onTimeDelivery'] != null
          ? MetricValue.fromJson(json['onTimeDelivery'])
          : MetricValue.empty(),
      defectTrendData: (json['defectTrendData'] as List?)
              ?.map((e) => double.tryParse(e.toString()) ?? 0.0)
              .toList() ??
          [],
      satisfactionTrendData: (json['satisfactionTrendData'] as List?)
              ?.map((e) => double.tryParse(e.toString()) ?? 0.0)
              .toList() ??
          [],
    );
  }

  QualityMetrics copyWith({
    MetricValue? defectDensity,
    MetricValue? customerSatisfaction,
    MetricValue? onTimeDelivery,
    List<double>? defectTrendData,
    List<double>? satisfactionTrendData,
  }) {
    return QualityMetrics(
      defectDensity: defectDensity ?? this.defectDensity,
      customerSatisfaction: customerSatisfaction ?? this.customerSatisfaction,
      onTimeDelivery: onTimeDelivery ?? this.onTimeDelivery,
      defectTrendData: defectTrendData ?? this.defectTrendData,
      satisfactionTrendData:
          satisfactionTrendData ?? this.satisfactionTrendData,
    );
  }
}

class QualityManagementData {
  final String qualityPlan;
  final String reviewCadence;
  final String escalationPath;
  final String changeControlProcess;
  final List<QualityTarget> targets;
  final List<QaTechnique> qaTechniques;
  final List<QcTechnique> qcTechniques;
  final QualityMetrics metrics;
  final List<QualityStandard> standards;
  final List<QualityObjective> objectives;
  final List<QualityWorkflowControl> workflowControls;
  final List<QualityAuditEntry> auditPlan;
  final List<QualityTaskEntry> qaTaskLog;
  final List<QualityTaskEntry> qcTaskLog;
  final List<CorrectiveActionEntry> correctiveActions;
  final List<QualityChangeEntry> qualityChangeLog;
  final QualityDashboardConfig dashboardConfig;
  final QualityComputedSnapshot? computedSnapshot;

  QualityManagementData({
    required this.qualityPlan,
    required this.reviewCadence,
    required this.escalationPath,
    required this.changeControlProcess,
    required this.targets,
    required this.qaTechniques,
    required this.qcTechniques,
    required this.metrics,
    required this.standards,
    required this.objectives,
    required this.workflowControls,
    required this.auditPlan,
    required this.qaTaskLog,
    required this.qcTaskLog,
    required this.correctiveActions,
    required this.qualityChangeLog,
    required this.dashboardConfig,
    required this.computedSnapshot,
  });

  factory QualityManagementData.empty() {
    return QualityManagementData(
      qualityPlan: '',
      reviewCadence: '',
      escalationPath: '',
      changeControlProcess: '',
      targets: [],
      qaTechniques: [],
      qcTechniques: [],
      metrics: QualityMetrics.empty(),
      standards: [],
      objectives: [],
      workflowControls: [],
      auditPlan: [],
      qaTaskLog: [],
      qcTaskLog: [],
      correctiveActions: [],
      qualityChangeLog: [],
      dashboardConfig: QualityDashboardConfig.empty(),
      computedSnapshot: null,
    );
  }

  Map<String, dynamic> toJson() => {
        'qualityPlan': qualityPlan,
        'reviewCadence': reviewCadence,
        'escalationPath': escalationPath,
        'changeControlProcess': changeControlProcess,
        'targets': targets.map((t) => t.toJson()).toList(),
        'qaTechniques': qaTechniques.map((t) => t.toJson()).toList(),
        'qcTechniques': qcTechniques.map((t) => t.toJson()).toList(),
        'metrics': metrics.toJson(),
        'standards': standards.map((s) => s.toJson()).toList(),
        'objectives': objectives.map((o) => o.toJson()).toList(),
        'workflowControls': workflowControls.map((w) => w.toJson()).toList(),
        'auditPlan': auditPlan.map((a) => a.toJson()).toList(),
        'qaTaskLog': qaTaskLog.map((t) => t.toJson()).toList(),
        'qcTaskLog': qcTaskLog.map((t) => t.toJson()).toList(),
        'correctiveActions': correctiveActions.map((c) => c.toJson()).toList(),
        'qualityChangeLog': qualityChangeLog.map((c) => c.toJson()).toList(),
        'dashboardConfig': dashboardConfig.toJson(),
        'computedSnapshot': computedSnapshot?.toJson(),
      };

  factory QualityManagementData.fromJson(Map<String, dynamic> json) {
    final legacyTargets = (json['targets'] as List?)
            ?.map((e) => QualityTarget.fromJson(e))
            .toList() ??
        [];
    final legacyQaTechniques = (json['qaTechniques'] as List?)
            ?.map((e) => QaTechnique.fromJson(e))
            .toList() ??
        [];
    final legacyQcTechniques = (json['qcTechniques'] as List?)
            ?.map((e) => QcTechnique.fromJson(e))
            .toList() ??
        [];

    final parsedObjectives = (json['objectives'] as List?)
            ?.map((e) => QualityObjective.fromJson(e))
            .toList() ??
        [];
    final parsedWorkflowControls = (json['workflowControls'] as List?)
            ?.map((e) => QualityWorkflowControl.fromJson(e))
            .toList() ??
        [];

    final derivedObjectives = parsedObjectives.isNotEmpty
        ? parsedObjectives
        : legacyTargets
            .map((t) => QualityObjective(
                  id: t.id,
                  title: t.name,
                  acceptanceCriteria: t.target,
                  successMetric: t.metric,
                  targetValue: t.target,
                  currentValue: t.current,
                  owner: '',
                  linkedRequirement: '',
                  linkedWbs: '',
                  status: _objectiveStatusFromTargetStatus(t.status),
                ))
            .toList();

    final derivedWorkflowControls = parsedWorkflowControls.isNotEmpty
        ? parsedWorkflowControls
        : [
            ...legacyQaTechniques.map(
              (t) => QualityWorkflowControl(
                id: t.id,
                type: QualityWorkflowType.qa,
                name: t.name,
                method: t.description,
                tools: '',
                checklist: '',
                frequency: t.frequency,
                owner: '',
                standardsReference: t.standards,
              ),
            ),
            ...legacyQcTechniques.map(
              (t) => QualityWorkflowControl(
                id: t.id,
                type: QualityWorkflowType.qc,
                name: t.name,
                method: t.description,
                tools: '',
                checklist: '',
                frequency: t.frequency,
                owner: '',
                standardsReference: '',
              ),
            ),
          ];

    return QualityManagementData(
      qualityPlan: json['qualityPlan']?.toString() ?? '',
      reviewCadence: json['reviewCadence']?.toString() ?? '',
      escalationPath: json['escalationPath']?.toString() ?? '',
      changeControlProcess: json['changeControlProcess']?.toString() ?? '',
      targets: legacyTargets,
      qaTechniques: legacyQaTechniques,
      qcTechniques: legacyQcTechniques,
      metrics: json['metrics'] != null
          ? QualityMetrics.fromJson(json['metrics'])
          : QualityMetrics.empty(),
      standards: (json['standards'] as List?)
              ?.map((e) => QualityStandard.fromJson(e))
              .toList() ??
          [],
      objectives: derivedObjectives,
      workflowControls: derivedWorkflowControls,
      auditPlan: (json['auditPlan'] as List?)
              ?.map((e) => QualityAuditEntry.fromJson(e))
              .toList() ??
          [],
      qaTaskLog: (json['qaTaskLog'] as List?)
              ?.map((e) => QualityTaskEntry.fromJson(e))
              .toList() ??
          [],
      qcTaskLog: (json['qcTaskLog'] as List?)
              ?.map((e) => QualityTaskEntry.fromJson(e))
              .toList() ??
          [],
      correctiveActions: (json['correctiveActions'] as List?)
              ?.map((e) => CorrectiveActionEntry.fromJson(e))
              .toList() ??
          [],
      qualityChangeLog: (json['qualityChangeLog'] as List?)
              ?.map((e) => QualityChangeEntry.fromJson(e))
              .toList() ??
          [],
      dashboardConfig: json['dashboardConfig'] != null
          ? QualityDashboardConfig.fromJson(
              Map<String, dynamic>.from(json['dashboardConfig'] as Map))
          : QualityDashboardConfig.empty(),
      computedSnapshot: json['computedSnapshot'] != null
          ? QualityComputedSnapshot.fromJson(
              Map<String, dynamic>.from(json['computedSnapshot'] as Map))
          : null,
    );
  }

  QualityManagementData copyWith({
    String? qualityPlan,
    String? reviewCadence,
    String? escalationPath,
    String? changeControlProcess,
    List<QualityTarget>? targets,
    List<QaTechnique>? qaTechniques,
    List<QcTechnique>? qcTechniques,
    QualityMetrics? metrics,
    List<QualityStandard>? standards,
    List<QualityObjective>? objectives,
    List<QualityWorkflowControl>? workflowControls,
    List<QualityAuditEntry>? auditPlan,
    List<QualityTaskEntry>? qaTaskLog,
    List<QualityTaskEntry>? qcTaskLog,
    List<CorrectiveActionEntry>? correctiveActions,
    List<QualityChangeEntry>? qualityChangeLog,
    QualityDashboardConfig? dashboardConfig,
    QualityComputedSnapshot? computedSnapshot,
  }) {
    return QualityManagementData(
      qualityPlan: qualityPlan ?? this.qualityPlan,
      reviewCadence: reviewCadence ?? this.reviewCadence,
      escalationPath: escalationPath ?? this.escalationPath,
      changeControlProcess: changeControlProcess ?? this.changeControlProcess,
      targets: targets ?? this.targets,
      qaTechniques: qaTechniques ?? this.qaTechniques,
      qcTechniques: qcTechniques ?? this.qcTechniques,
      metrics: metrics ?? this.metrics,
      standards: standards ?? this.standards,
      objectives: objectives ?? this.objectives,
      workflowControls: workflowControls ?? this.workflowControls,
      auditPlan: auditPlan ?? this.auditPlan,
      qaTaskLog: qaTaskLog ?? this.qaTaskLog,
      qcTaskLog: qcTaskLog ?? this.qcTaskLog,
      correctiveActions: correctiveActions ?? this.correctiveActions,
      qualityChangeLog: qualityChangeLog ?? this.qualityChangeLog,
      dashboardConfig: dashboardConfig ?? this.dashboardConfig,
      computedSnapshot: computedSnapshot ?? this.computedSnapshot,
    );
  }
}

class Contractor {
  final String id;
  String name;
  String service;
  double estimatedCost;
  String status;
  String notes;

  Contractor({
    required this.id,
    this.name = '',
    this.service = '',
    this.estimatedCost = 0.0,
    this.status = 'Pending',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'service': service,
        'estimatedCost': estimatedCost,
        'status': status,
        'notes': notes,
      };

  factory Contractor.fromJson(Map<String, dynamic> json) {
    return Contractor(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? '',
      service: json['service']?.toString() ?? '',
      estimatedCost: (json['estimatedCost'] is num)
          ? (json['estimatedCost'] as num).toDouble()
          : double.tryParse(json['estimatedCost']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? 'Pending',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class Vendor {
  final String id;
  String name;
  String equipmentOrService;
  double estimatedPrice;
  String procurementStage;
  String status;
  String notes;

  Vendor({
    required this.id,
    this.name = '',
    this.equipmentOrService = '',
    this.estimatedPrice = 0.0,
    this.procurementStage = 'Identified',
    this.status = 'Pending',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'equipmentOrService': equipmentOrService,
        'estimatedPrice': estimatedPrice,
        'procurementStage': procurementStage,
        'status': status,
        'notes': notes,
      };

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? '',
      equipmentOrService: json['equipmentOrService']?.toString() ?? '',
      estimatedPrice: (json['estimatedPrice'] is num)
          ? (json['estimatedPrice'] as num).toDouble()
          : double.tryParse(json['estimatedPrice']?.toString() ?? '0') ?? 0.0,
      procurementStage: json['procurementStage']?.toString() ?? 'Identified',
      status: json['status']?.toString() ?? 'Pending',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class PlanningDashboardItem {
  static int _idCounter = 0;

  static String _nextId() {
    _idCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  String id;
  String title;
  String description;
  DateTime createdAt;
  bool isAiGenerated;

  PlanningDashboardItem({
    String? id,
    this.title = '',
    required this.description,
    DateTime? createdAt,
    this.isAiGenerated = false,
  })  : id = (id == null || id.trim().isEmpty) ? _nextId() : id,
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'isAiGenerated': isAiGenerated,
    };
  }

  factory PlanningDashboardItem.fromJson(Map<String, dynamic> json) {
    return PlanningDashboardItem(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      isAiGenerated: json['isAiGenerated'] ?? false,
    );
  }
}

class MonitoringControlsData {
  String kpiTracking;
  String qaPlan;
  String riskMonitoring;

  MonitoringControlsData({
    this.kpiTracking = '',
    this.qaPlan = '',
    this.riskMonitoring = '',
  });

  Map<String, dynamic> toJson() => {
        'kpiTracking': kpiTracking,
        'qaPlan': qaPlan,
        'riskMonitoring': riskMonitoring,
      };

  factory MonitoringControlsData.fromJson(Map<String, dynamic> json) {
    return MonitoringControlsData(
      kpiTracking: json['kpiTracking'] ?? '',
      qaPlan: json['qaPlan'] ?? '',
      riskMonitoring: json['riskMonitoring'] ?? '',
    );
  }
}

class LaunchPhaseData {
  String launchPlan;
  String goNoGoCriteria;
  String postLaunchReview;

  LaunchPhaseData({
    this.launchPlan = '',
    this.goNoGoCriteria = '',
    this.postLaunchReview = '',
  });

  Map<String, dynamic> toJson() => {
        'launchPlan': launchPlan,
        'goNoGoCriteria': goNoGoCriteria,
        'postLaunchReview': postLaunchReview,
      };

  factory LaunchPhaseData.fromJson(Map<String, dynamic> json) {
    return LaunchPhaseData(
      launchPlan: json['launchPlan'] ?? '',
      goNoGoCriteria: json['goNoGoCriteria'] ?? '',
      postLaunchReview: json['postLaunchReview'] ?? '',
    );
  }
}

class InterfaceEntry {
  final String id;
  final String boundary;
  final String owner;
  final String cadence;
  final String risk;
  final String status;
  final String lastSync;
  final String notes;

  // PM-standard fields (Tier 1)
  final String
      interfaceType; // Technical, Contractual, Organizational, Physical, Procedural
  final String partyA; // Providing party
  final String partyB; // Receiving party
  final String priority; // High, Medium, Low
  final String criticality; // Critical, Major, Minor
  final String dataFlow; // Bidirectional, A→B, B→A
  final String protocol; // API, File Transfer, Manual, Email, Shared DB

  InterfaceEntry({
    String? id,
    this.boundary = '',
    this.owner = '',
    this.cadence = '',
    this.risk = '',
    this.status = '',
    this.lastSync = '',
    this.notes = '',
    this.interfaceType = '',
    this.partyA = '',
    this.partyB = '',
    this.priority = '',
    this.criticality = '',
    this.dataFlow = '',
    this.protocol = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  InterfaceEntry copyWith({
    String? boundary,
    String? owner,
    String? cadence,
    String? risk,
    String? status,
    String? lastSync,
    String? notes,
    String? interfaceType,
    String? partyA,
    String? partyB,
    String? priority,
    String? criticality,
    String? dataFlow,
    String? protocol,
  }) {
    return InterfaceEntry(
      id: id,
      boundary: boundary ?? this.boundary,
      owner: owner ?? this.owner,
      cadence: cadence ?? this.cadence,
      risk: risk ?? this.risk,
      status: status ?? this.status,
      lastSync: lastSync ?? this.lastSync,
      notes: notes ?? this.notes,
      interfaceType: interfaceType ?? this.interfaceType,
      partyA: partyA ?? this.partyA,
      partyB: partyB ?? this.partyB,
      priority: priority ?? this.priority,
      criticality: criticality ?? this.criticality,
      dataFlow: dataFlow ?? this.dataFlow,
      protocol: protocol ?? this.protocol,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'boundary': boundary,
        'owner': owner,
        'cadence': cadence,
        'risk': risk,
        'status': status,
        'lastSync': lastSync,
        'notes': notes,
        'interfaceType': interfaceType,
        'partyA': partyA,
        'partyB': partyB,
        'priority': priority,
        'criticality': criticality,
        'dataFlow': dataFlow,
        'protocol': protocol,
      };

  factory InterfaceEntry.fromJson(Map<String, dynamic> json) {
    return InterfaceEntry(
      id: json['id']?.toString(),
      boundary: json['boundary']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      cadence: json['cadence']?.toString() ?? '',
      risk: json['risk']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      lastSync: json['lastSync']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      interfaceType: json['interfaceType']?.toString() ?? '',
      partyA: json['partyA']?.toString() ?? '',
      partyB: json['partyB']?.toString() ?? '',
      priority: json['priority']?.toString() ?? '',
      criticality: json['criticality']?.toString() ?? '',
      dataFlow: json['dataFlow']?.toString() ?? '',
      protocol: json['protocol']?.toString() ?? '',
    );
  }
}

class InterfaceChangeLogEntry {
  final String id;
  final String interfaceId;
  final String interfaceName;
  final String
      action; // 'Created', 'Updated', 'Deleted', 'Status Changed', 'Imported'
  final String fieldName; // Which field changed (empty for Created/Deleted)
  final String oldValue; // Previous value (empty for Created)
  final String newValue; // New value (empty for Deleted)
  final String changedBy; // User who made the change
  final String changedAt; // ISO timestamp

  InterfaceChangeLogEntry({
    String? id,
    this.interfaceId = '',
    this.interfaceName = '',
    this.action = '',
    this.fieldName = '',
    this.oldValue = '',
    this.newValue = '',
    this.changedBy = '',
    this.changedAt = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  InterfaceChangeLogEntry copyWith({
    String? interfaceId,
    String? interfaceName,
    String? action,
    String? fieldName,
    String? oldValue,
    String? newValue,
    String? changedBy,
    String? changedAt,
  }) {
    return InterfaceChangeLogEntry(
      id: id,
      interfaceId: interfaceId ?? this.interfaceId,
      interfaceName: interfaceName ?? this.interfaceName,
      action: action ?? this.action,
      fieldName: fieldName ?? this.fieldName,
      oldValue: oldValue ?? this.oldValue,
      newValue: newValue ?? this.newValue,
      changedBy: changedBy ?? this.changedBy,
      changedAt: changedAt ?? this.changedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'interfaceId': interfaceId,
        'interfaceName': interfaceName,
        'action': action,
        'fieldName': fieldName,
        'oldValue': oldValue,
        'newValue': newValue,
        'changedBy': changedBy,
        'changedAt': changedAt,
      };

  factory InterfaceChangeLogEntry.fromJson(Map<String, dynamic> json) {
    return InterfaceChangeLogEntry(
      id: json['id']?.toString(),
      interfaceId: json['interfaceId']?.toString() ?? '',
      interfaceName: json['interfaceName']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      fieldName: json['fieldName']?.toString() ?? '',
      oldValue: json['oldValue']?.toString() ?? '',
      newValue: json['newValue']?.toString() ?? '',
      changedBy: json['changedBy']?.toString() ?? '',
      changedAt: json['changedAt']?.toString() ?? '',
    );
  }
}
