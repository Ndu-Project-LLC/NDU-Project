import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/project_data_model.dart';

/// Represents context data from a specific Planning Phase screen.
/// Each screen publishes its key data points so downstream screens
/// can reference them via the ContextBanner.
class PlanningScreenContext {
  final String screenId;
  final String screenTitle;
  final DateTime timestamp;
  final Map<String, String> summaryData;
  final List<String> keyInsights;

  const PlanningScreenContext({
    required this.screenId,
    required this.screenTitle,
    required this.timestamp,
    this.summaryData = const {},
    this.keyInsights = const [],
  });

  @override
  String toString() => 'PlanningScreenContext($screenId: $summaryData)';
}

/// Service that manages context flow between Planning Phase screens.
///
/// Follows the sidebar order:
/// 1. Project Details (project_framework)
/// 2. Work Breakdown Structure (work_breakdown_structure)
/// 3. Project Goals & Milestones (project_goals_milestones)
/// 4. Requirements (requirements)
/// 5. Organization Plan (organization_* screens)
/// 6. SSHER (ssher)
/// 7. Quality Management (quality_management)
/// 8. Design Planning (design)
/// 9. Technology Planning (technology)
/// ... and so on
class PlanningPhaseContextService {
  PlanningPhaseContextService._();
  static final PlanningPhaseContextService instance =
      PlanningPhaseContextService._();

  static final _firestore = FirebaseFirestore.instance;

  /// Current project ID for Firestore persistence.
  String? _currentProjectId;

  /// In-memory cache of screen contexts for the current session.
  final Map<String, PlanningScreenContext> _screenContexts = {};

  /// Launch Phase screen IDs in their flow order (matching sidebar).
  static const List<String> launchFlowOrder = [
    'deliver_project_closure',
    'transition_to_prod_team',
    'fat_mechanical_completion',
    'contract_close_out',
    'actual_vs_planned_gap_analysis',
    'commerce_viability',
    'financial_closeout',
    'summarize_account_risks',
    'benefits_realization',
    'demobilize_team',
    'project_close_out',
  ];

  /// Human-readable labels for each Launch Phase screen.
  static const Map<String, String> launchScreenLabels = {
    'deliver_project_closure': 'Launch Readiness Assessment',
    'transition_to_prod_team': 'Deployment Transfer, Certification & Release',
    'fat_mechanical_completion': 'FAT, Mechanical Completion & Commission Solution',
    'contract_close_out': 'Vendor & Contract Closeout',
    'actual_vs_planned_gap_analysis': 'Scope & Deliverable Reconciliation',
    'commerce_viability': 'Hypercare & Warranty Support',
    'financial_closeout': 'Financial Closeout',
    'summarize_account_risks': 'Project Performance Review',
    'benefits_realization': 'Benefits Realization',
    'demobilize_team': 'Team Demobilization & Operations/Production Transition',
    'project_close_out': 'Project Closeout',
  };

  /// Screen IDs in their flow order (matching sidebar).
  static const List<String> planningFlowOrder = [
    'project_framework',
    'work_breakdown_structure',
    'project_goals_milestones',
    'requirements',
    'organization_roles_responsibilities',
    'organization_raci_matrix',
    'organization_staffing_plan',
    'team_training',
    'stakeholder_management',
    'team_management',
    'ssher',
    'quality_management',
    'design',
    'technology',
    'interface_management',
    'agile_delivery_model',
    'agile_scrum_config',
    'agile_capacity_planning',
    'agile_backlog_governance',
    'agile_team_structure',
    'agile_kanban_config',
    'agile_epics_features',
    'agile_acceptance_criteria',
    'agile_sprint_calendar',
    'agile_map_out',
    'agile_release_plan',
    'agile_metrics_planning',
    'risk_assessment',
    'contracts',
    'procurement',
    'schedule',
    'cost_estimate',
    'scope_tracking_plan',
    'change_management',
    'issue_management',
    'lessons_learned',
    'execution_plan',
    'execution_work_packages',
    'execution_plan_strategy',
    'execution_plan_details',
    'execution_early_works',
    'execution_enabling_work_plan',
    'execution_issue_management',
    'execution_plan_stakeholder_identification',
    'execution_plan_construction_plan',
    'execution_plan_infrastructure_plan',
    'execution_plan_lessons_learned',
    'execution_plan_best_practices',
    'execution_plan_interface_management',
    'execution_plan_communication_plan',
    'execution_plan_interface_management_plan',
    'execution_plan_interface_management_overview',
    'startup_planning',
    'deliverables_roadmap',
    'project_plan',
    'project_baseline',
  ];

  /// Human-readable labels for each screen in the flow.
  static const Map<String, String> screenLabels = {
    'project_framework': 'Project Details',
    'work_breakdown_structure': 'Work Breakdown Structure',
    'project_goals_milestones': 'Project Goals & Milestones',
    'requirements': 'Requirements',
    'organization_roles_responsibilities': 'Roles & Responsibilities',
    'organization_raci_matrix': 'RACI Matrix',
    'organization_staffing_plan': 'Staffing Plan',
    'team_training': 'Training & Team Building',
    'stakeholder_management': 'Stakeholder Management',
    'team_management': 'Team Management',
    'ssher': 'SSHER',
    'quality_management': 'Quality Management',
    'design': 'Design Planning',
    'technology': 'Technology Planning',
    'interface_management': 'Interface Management',
    'agile_delivery_model': 'Agile Delivery Model',
    'agile_scrum_config': 'Scrum Configuration',
    'agile_capacity_planning': 'Capacity Planning',
    'agile_backlog_governance': 'Backlog Governance',
    'agile_team_structure': 'Agile Team Structure',
    'agile_kanban_config': 'Kanban Configuration',
    'agile_epics_features': 'Epics & Features',
    'agile_acceptance_criteria': 'Acceptance Criteria',
    'agile_sprint_calendar': 'Sprint Calendar',
    'agile_map_out': 'Agile Map Out',
    'agile_release_plan': 'Release Plan',
    'agile_metrics_planning': 'Agile Metrics Planning',
    'risk_assessment': 'Risk Assessment',
    'contracts': 'Contract Planning',
    'procurement': 'Procurement',
    'schedule': 'Schedule',
    'cost_estimate': 'Cost Estimate',
    'scope_tracking_plan': 'Scope Tracking Plan',
    'change_management': 'Change Management',
    'issue_management': 'Issue Management',
    'lessons_learned': 'Lessons Learned',
    'execution_plan': 'Execution Plan Overview',
    'execution_work_packages': 'Execution Work Packages',
    'execution_plan_strategy': 'Executive Plan Strategy',
    'execution_plan_details': 'Execution Plan Details',
    'execution_early_works': 'Execution Early Works',
    'execution_enabling_work_plan': 'Enabling Work Plan',
    'execution_issue_management': 'Execution Issue Management',
    'execution_plan_stakeholder_identification': 'Stakeholder Identification',
    'execution_plan_construction_plan': 'Construction Plan',
    'execution_plan_infrastructure_plan': 'Infrastructure Plan',
    'execution_plan_lessons_learned': 'Lessons Learned',
    'execution_plan_best_practices': 'Best Practices',
    'execution_plan_interface_management': 'Interface Management',
    'execution_plan_communication_plan': 'Communication Plan',
    'execution_plan_interface_management_plan': 'Interface Management Plan',
    'execution_plan_interface_management_overview': 'Interface Management Overview',
    'startup_planning': 'Start-Up Planning',
    'deliverables_roadmap': 'Deliverables Roadmap',
    'project_plan': 'Project Plan',
    'project_baseline': 'Project Baseline',
  };

  /// Set the current project ID for Firestore persistence.
  void setCurrentProject(String projectId) {
    _currentProjectId = projectId;
    if (kDebugMode) {
      debugPrint('PlanningPhaseContext: Project ID set to $projectId');
    }
  }

  /// Get the Firestore collection reference for context data.
  CollectionReference<Map<String, dynamic>>? _contextCol() {
    if (_currentProjectId == null) return null;
    return _firestore
        .collection('projects')
        .doc(_currentProjectId)
        .collection('planning_contexts');
  }

  /// Publish context data from a screen after it saves.
  /// Also persists to Firestore if a project ID is set.
  void publishContext(PlanningScreenContext context) {
    _screenContexts[context.screenId] = context;
    _persistToFirestore(context);
    if (kDebugMode) {
      debugPrint(
          'PlanningPhaseContext: Published context for ${context.screenId}');
    }
  }

  /// Persist a context to Firestore asynchronously.
  Future<void> _persistToFirestore(PlanningScreenContext context) async {
    final col = _contextCol();
    if (col == null) return;
    try {
      await col.doc(context.screenId).set({
        'screenId': context.screenId,
        'screenTitle': context.screenTitle,
        'timestamp': context.timestamp.toIso8601String(),
        'summaryData': context.summaryData,
        'keyInsights': context.keyInsights,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('PlanningPhaseContext: Firestore persist error: $e');
    }
  }

  /// Load all contexts from Firestore for the current project.
  Future<void> loadContexts() async {
    final col = _contextCol();
    if (col == null) return;
    try {
      final snapshot = await col.get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final screenId = data['screenId'] as String? ?? doc.id;
        final screenTitle = data['screenTitle'] as String? ?? screenId;
        final timestampStr = data['timestamp'] as String?;
        final timestamp = timestampStr != null
            ? DateTime.tryParse(timestampStr) ?? DateTime.now()
            : DateTime.now();
        final summaryData = (data['summaryData'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v.toString())) ?? {};
        final keyInsights = (data['keyInsights'] as List<dynamic>?)
                ?.map((e) => e.toString()).toList() ?? [];

        _screenContexts[screenId] = PlanningScreenContext(
          screenId: screenId,
          screenTitle: screenTitle,
          timestamp: timestamp,
          summaryData: summaryData,
          keyInsights: keyInsights,
        );
      }
      if (kDebugMode) {
        debugPrint(
            'PlanningPhaseContext: Loaded ${_screenContexts.length} contexts from Firestore');
      }
    } catch (e) {
      debugPrint('PlanningPhaseContext: Firestore load error: $e');
    }
  }

  /// Get context for a specific screen.
  PlanningScreenContext? getContext(String screenId) {
    return _screenContexts[screenId];
  }

  /// Get all upstream contexts (screens that come before the given screen
  /// in the planning flow order).
  List<PlanningScreenContext> getUpstreamContexts(String currentScreenId) {
    // Check planning phase flow
    final currentIndex = planningFlowOrder.indexOf(currentScreenId);
    if (currentIndex > 0) {
      final upstreamIds = planningFlowOrder.sublist(0, currentIndex);
      return upstreamIds
          .where((id) => _screenContexts.containsKey(id))
          .map((id) => _screenContexts[id]!)
          .toList();
    }

    // Check launch phase flow
    final launchIndex = launchFlowOrder.indexOf(currentScreenId);
    if (launchIndex > 0) {
      final upstreamIds = launchFlowOrder.sublist(0, launchIndex);
      return upstreamIds
          .where((id) => _screenContexts.containsKey(id))
          .map((id) => _screenContexts[id]!)
          .toList();
    }

    return [];
  }

  /// Get summary data from all upstream screens for the ContextBanner.
  Map<String, String> getUpstreamSummary(String currentScreenId) {
    final upstream = getUpstreamContexts(currentScreenId);
    final summary = <String, String>{};

    for (final context in upstream) {
      for (final entry in context.summaryData.entries) {
        // Use screen prefix to avoid key collisions
        final prefixedKey = '${context.screenTitle}: ${entry.key}';
        summary[prefixedKey] = entry.value;
      }
    }

    return summary;
  }

  /// Build ContextBanner items from upstream data.
  List<ContextBannerItemData> buildBannerItems(String currentScreenId) {
    final upstream = getUpstreamContexts(currentScreenId);
    final items = <ContextBannerItemData>[];

    for (final context in upstream) {
      for (final entry in context.summaryData.entries) {
        items.add(ContextBannerItemData(
          screenId: context.screenId,
          screenTitle: context.screenTitle,
          label: entry.key,
          value: entry.value,
        ));
      }
    }

    return items;
  }

  /// Clear all cached contexts (e.g., when starting a new project).
  /// Also removes from Firestore if a project ID is set.
  void clearAll() {
    _clearAllFromFirestore();
    _screenContexts.clear();
    if (kDebugMode) {
      debugPrint('PlanningPhaseContext: Cleared all contexts');
    }
  }

  /// Clear context for a specific screen.
  /// Also removes from Firestore if a project ID is set.
  void clearContext(String screenId) {
    _clearFromFirestore(screenId);
    _screenContexts.remove(screenId);
    if (kDebugMode) {
      debugPrint('PlanningPhaseContext: Cleared context for $screenId');
    }
  }

  /// Remove all contexts from Firestore for the current project.
  Future<void> _clearAllFromFirestore() async {
    final col = _contextCol();
    if (col == null) return;
    try {
      final snapshot = await col.get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('PlanningPhaseContext: Firestore clear all error: $e');
    }
  }

  /// Remove a specific context from Firestore.
  Future<void> _clearFromFirestore(String screenId) async {
    final col = _contextCol();
    if (col == null) return;
    try {
      await col.doc(screenId).delete();
    } catch (e) {
      debugPrint('PlanningPhaseContext: Firestore clear error: $e');
    }
  }

  /// Check if a screen has published context.
  bool hasContext(String screenId) {
    return _screenContexts.containsKey(screenId);
  }

  /// Get the screen label for a given screen ID (checks both planning and launch).
  String getScreenLabel(String screenId) {
    return screenLabels[screenId] ?? launchScreenLabels[screenId] ?? screenId;
  }

  /// Get the previous screen in the flow.
  String? getPreviousScreenId(String currentScreenId) {
    // Check planning flow
    final index = planningFlowOrder.indexOf(currentScreenId);
    if (index > 0) return planningFlowOrder[index - 1];

    // Check launch flow
    final launchIndex = launchFlowOrder.indexOf(currentScreenId);
    if (launchIndex > 0) return launchFlowOrder[launchIndex - 1];

    return null;
  }

  /// Get the next screen in the flow.
  String? getNextScreenId(String currentScreenId) {
    // Check planning flow
    final index = planningFlowOrder.indexOf(currentScreenId);
    if (index >= 0 && index < planningFlowOrder.length - 1) {
      return planningFlowOrder[index + 1];
    }

    // Check launch flow
    final launchIndex = launchFlowOrder.indexOf(currentScreenId);
    if (launchIndex >= 0 && launchIndex < launchFlowOrder.length - 1) {
      return launchFlowOrder[launchIndex + 1];
    }

    return null;
  }
}

/// Data class for ContextBanner items.
class ContextBannerItemData {
  final String screenId;
  final String screenTitle;
  final String label;
  final String value;

  const ContextBannerItemData({
    required this.screenId,
    required this.screenTitle,
    required this.label,
    required this.value,
  });
}

/// Helper to build context from ProjectDataModel for common screens.
class PlanningContextBuilder {
  /// Build context for Project Details screen.
  static PlanningScreenContext buildProjectDetailsContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'project_framework',
      screenTitle: 'Project Details',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : data.solutionTitle.isNotEmpty
                ? data.solutionTitle
                : 'Not set',
        'Framework': data.overallFramework ?? 'Not selected',
        'Goals Count': '${data.projectGoals.length} goals',
        'Objective': data.projectObjective.isNotEmpty
            ? (data.projectObjective.length > 60
                ? '${data.projectObjective.substring(0, 60)}...'
                : data.projectObjective)
            : 'Not set',
      },
      keyInsights: [
        if (data.overallFramework != null &&
            data.overallFramework!.isNotEmpty)
          'Using ${data.overallFramework} framework',
        if (data.projectGoals.isNotEmpty)
          '${data.projectGoals.length} project goals defined',
      ],
    );
  }

  /// Build context for Work Breakdown Structure screen.
  static PlanningScreenContext buildWBSContext(ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'work_breakdown_structure',
      screenTitle: 'Work Breakdown Structure',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Framework': data.overallFramework ?? 'Not selected',
        'WBS Nodes': '${data.wbsTree.length} nodes',
      },
      keyInsights: [
        if (data.wbsTree.isNotEmpty)
          'WBS structure defined with ${data.wbsTree.length} nodes',
      ],
    );
  }

  /// Build context for Requirements screen.
  static PlanningScreenContext buildRequirementsContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'requirements',
      screenTitle: 'Requirements',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Requirements Count': '${data.planningRequirementItems.length} items',
      },
      keyInsights: [
        if (data.planningRequirementItems.isNotEmpty)
          '${data.planningRequirementItems.length} requirements captured',
      ],
    );
  }

  /// Build context for Quality Management screen.
  static PlanningScreenContext buildQualityContext(ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'quality_management',
      screenTitle: 'Quality Management',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Quality Data': data.qualityManagementData != null
            ? 'Defined'
            : 'Not defined',
      },
      keyInsights: [],
    );
  }

  /// Build context for Design Planning screen.
  static PlanningScreenContext buildDesignContext(ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'design',
      screenTitle: 'Design Planning',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Methodology':
            data.designManagementData?.methodology.name ?? 'Not selected',
      },
      keyInsights: [],
    );
  }

  /// Build context for Technology Planning screen.
  static PlanningScreenContext buildTechnologyContext(ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'technology',
      screenTitle: 'Technology Planning',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Technology': data.technology.isNotEmpty
            ? data.technology
            : 'Not defined',
      },
      keyInsights: [],
    );
  }

  /// Build context for Agile Delivery Model screen.
  static PlanningScreenContext buildAgileDeliveryModelContext(
      ProjectDataModel data, Map<String, String> deliveryData) {
    return PlanningScreenContext(
      screenId: 'agile_delivery_model',
      screenTitle: 'Agile Delivery Model',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Framework': deliveryData['framework'] ?? 'Not selected',
        'Sprint Length': deliveryData['sprintLength'] ?? 'Not set',
        'Estimation': deliveryData['estimationMethod'] ?? 'Not set',
      },
      keyInsights: [
        if (deliveryData['framework'] != null)
          'Using ${deliveryData['framework']} framework',
      ],
    );
  }

  /// Build context for Backlog Governance screen.
  static PlanningScreenContext buildBacklogGovernanceContext(
      ProjectDataModel data, {String? prioritizationFramework}) {
    return PlanningScreenContext(
      screenId: 'agile_backlog_governance',
      screenTitle: 'Backlog Governance',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Prioritization': prioritizationFramework ?? 'Not configured',
      },
      keyInsights: [],
    );
  }

  /// Build context for Agile Team Structure screen.
  static PlanningScreenContext buildAgileTeamStructureContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'agile_team_structure',
      screenTitle: 'Agile Team Structure',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Team Members': '${data.teamMembers.length} members',
      },
      keyInsights: [],
    );
  }

  /// Build context for Kanban Configuration screen.
  static PlanningScreenContext buildKanbanConfigContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'agile_kanban_config',
      screenTitle: 'Kanban Configuration',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
      },
      keyInsights: [],
    );
  }

  /// Build context for Epics & Features screen.
  static PlanningScreenContext buildEpicsFeaturesContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'agile_epics_features',
      screenTitle: 'Epics & Features',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Goals': '${data.projectGoals.length} goals',
      },
      keyInsights: [],
    );
  }

  /// Build context for Sprint Calendar screen.
  static PlanningScreenContext buildSprintCalendarContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'agile_sprint_calendar',
      screenTitle: 'Sprint Calendar',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Sprint Length': 'Configured',
      },
      keyInsights: [],
    );
  }

  /// Build context for Acceptance Criteria screen.
  static PlanningScreenContext buildAcceptanceCriteriaContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'agile_acceptance_criteria',
      screenTitle: 'Acceptance Criteria',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
      },
      keyInsights: [],
    );
  }

  // ── Execution Plan Context Builders ──────────────────────────────────

  /// Build context for Execution Plan Overview screen.
  static PlanningScreenContext buildExecutionPlanContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'execution_plan',
      screenTitle: 'Execution Plan Overview',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Framework': data.overallFramework ?? 'Not selected',
        'Team Size': '${data.teamMembers.length} members',
      },
      keyInsights: [],
    );
  }

  /// Build context for Execution Work Packages screen.
  static PlanningScreenContext buildExecutionWorkPackagesContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'execution_work_packages',
      screenTitle: 'Execution Work Packages',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Work Packages': '${data.workPackages.length} packages',
      },
      keyInsights: [],
    );
  }

  /// Build context for Execution Plan Strategy screen.
  static PlanningScreenContext buildExecutionPlanStrategyContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'execution_plan_strategy',
      screenTitle: 'Executive Plan Strategy',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
      },
      keyInsights: [],
    );
  }

  /// Build context for Execution Plan Details screen.
  static PlanningScreenContext buildExecutionPlanDetailsContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'execution_plan_details',
      screenTitle: 'Execution Plan Details',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Control Accounts': '${data.controlAccounts.length} accounts',
      },
      keyInsights: [],
    );
  }

  /// Build context for Construction Plan screen.
  static PlanningScreenContext buildConstructionPlanContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'execution_plan_construction_plan',
      screenTitle: 'Construction Plan',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
      },
      keyInsights: [],
    );
  }

  /// Build context for Infrastructure Plan screen.
  static PlanningScreenContext buildInfrastructurePlanContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'execution_plan_infrastructure_plan',
      screenTitle: 'Infrastructure Plan',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
      },
      keyInsights: [],
    );
  }

  /// Build context for Communication Plan screen.
  static PlanningScreenContext buildCommunicationPlanContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'execution_plan_communication_plan',
      screenTitle: 'Communication Plan',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
      },
      keyInsights: [],
    );
  }

  // ── Launch Phase Context Builders ──────────────────────────────────

  /// Build context for Launch Readiness Assessment screen.
  static PlanningScreenContext buildLaunchReadinessContext(
      ProjectDataModel data) {
    final milestoneCount = data.keyMilestones.length;
    final completedMilestones = data.keyMilestones
        .where((m) => m.comments.toLowerCase().contains('complete') ||
            m.comments.toLowerCase().contains('done'))
        .length;
    final riskCount = data.frontEndPlanning.riskRegisterItems.length;
    return PlanningScreenContext(
      screenId: 'deliver_project_closure',
      screenTitle: 'Launch Readiness Assessment',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Milestones': '$completedMilestones of $milestoneCount completed',
        'Open Risks': '$riskCount tracked',
      },
      keyInsights: [
        if (data.charterApprovalDate != null)
          'Charter approved',
        '$milestoneCount milestones tracked',
      ],
    );
  }

  /// Build context for Deployment Transfer screen.
  static PlanningScreenContext buildDeploymentTransferContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'transition_to_prod_team',
      screenTitle: 'Deployment Transfer, Certification & Release',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Team Members': '${data.teamMembers.length} members',
        'Contractors': '${data.contractors.length} contractors',
      },
      keyInsights: [],
    );
  }

  /// Build context for FAT, Mechanical Completion screen.
  static PlanningScreenContext buildFATMechanicalContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'fat_mechanical_completion',
      screenTitle: 'FAT, Mechanical Completion & Commission Solution',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Framework': data.overallFramework ?? 'Not selected',
      },
      keyInsights: [],
    );
  }

  /// Build context for Vendor & Contract Closeout screen.
  static PlanningScreenContext buildVendorCloseoutContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'contract_close_out',
      screenTitle: 'Vendor & Contract Closeout',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Vendors': '${data.vendors.length} vendors',
        'Contractors': '${data.contractors.length} contractors',
      },
      keyInsights: [],
    );
  }

  /// Build context for Scope & Deliverable Reconciliation screen.
  static PlanningScreenContext buildScopeReconciliationContext(
      ProjectDataModel data) {
    final scopeCount = data.withinScope.length + data.outOfScope.length;
    return PlanningScreenContext(
      screenId: 'actual_vs_planned_gap_analysis',
      screenTitle: 'Scope & Deliverable Reconciliation',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'In-Scope Items': '${data.withinScope.length} items',
        'Out-of-Scope': '${data.outOfScope.length} items',
        'Total Scope Items': '$scopeCount items',
      },
      keyInsights: [],
    );
  }

  /// Build context for Hypercare & Warranty Support screen.
  static PlanningScreenContext buildHypercareContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'commerce_viability',
      screenTitle: 'Hypercare & Warranty Support',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Vendors': '${data.vendors.length} under warranty',
      },
      keyInsights: [],
    );
  }

  /// Build context for Financial Closeout screen.
  static PlanningScreenContext buildFinancialCloseoutContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'financial_closeout',
      screenTitle: 'Financial Closeout',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Framework': data.overallFramework ?? 'Not selected',
      },
      keyInsights: [],
    );
  }

  /// Build context for Project Performance Review screen.
  static PlanningScreenContext buildPerformanceReviewContext(
      ProjectDataModel data) {
    final risks = data.frontEndPlanning.riskRegisterItems;
    final openRisks = risks
        .where((r) => r.status.toLowerCase() != 'closed')
        .length;
    return PlanningScreenContext(
      screenId: 'summarize_account_risks',
      screenTitle: 'Project Performance Review',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Open Risks': '$openRisks of ${risks.length}',
        'Milestones': '${data.keyMilestones.length} tracked',
      },
      keyInsights: [],
    );
  }

  /// Build context for Benefits Realization screen.
  static PlanningScreenContext buildBenefitsRealizationContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'benefits_realization',
      screenTitle: 'Benefits Realization',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Project Goals': '${data.projectGoals.length} goals',
      },
      keyInsights: [],
    );
  }

  /// Build context for Team Demobilization screen.
  static PlanningScreenContext buildDemobilizeContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'demobilize_team',
      screenTitle: 'Team Demobilization & Operations/Production Transition',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Team Members': '${data.teamMembers.length} members',
      },
      keyInsights: [],
    );
  }

  /// Build context for Project Closeout screen.
  static PlanningScreenContext buildProjectCloseoutContext(
      ProjectDataModel data) {
    return PlanningScreenContext(
      screenId: 'project_close_out',
      screenTitle: 'Project Closeout',
      timestamp: DateTime.now(),
      summaryData: {
        'Project Name': data.projectName.isNotEmpty
            ? data.projectName
            : 'Not set',
        'Framework': data.overallFramework ?? 'Not selected',
        'Team Size': '${data.teamMembers.length} members',
      },
      keyInsights: [],
    );
  }

  /// Generic context builder for screens without specific logic.
  static PlanningScreenContext buildGenericContext({
    required String screenId,
    required String screenTitle,
    required ProjectDataModel data,
    Map<String, String>? extraData,
  }) {
    final summaryData = <String, String>{
      'Project Name': data.projectName.isNotEmpty
          ? data.projectName
          : 'Not set',
      'Framework': data.overallFramework ?? 'Not selected',
    };
    if (extraData != null) {
      summaryData.addAll(extraData);
    }
    return PlanningScreenContext(
      screenId: screenId,
      screenTitle: screenTitle,
      timestamp: DateTime.now(),
      summaryData: summaryData,
      keyInsights: [],
    );
  }
}
