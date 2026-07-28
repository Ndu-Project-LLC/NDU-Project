import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/services/activity_log_service.dart';
import 'package:ndu_project/services/activity_auto_logger.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/services/project_intelligence_service.dart';

/// Provider that manages project data state across the entire application
class ProjectDataProvider extends ChangeNotifier {
  ProjectDataProvider();

  /// Most-recently-loaded project ID across all [ProjectDataProvider]
  /// instances in the app. Used by the router-level [ActivityAutoLogger]
  /// to attribute page visits to a project when the user navigates between
  /// screens without an explicit project context (e.g. via the sidebar).
  /// Updated by [_loadFromFirebaseInternal] and [saveToFirebase].
  static String? lastKnownProjectId;

  ProjectDataModel _projectData = ProjectDataModel();
  bool _isSaving = false;
  String? _lastError;
  String? _cachedProjectId; // Cache to prevent redundant loads
  Future<bool>? _activeSaveFuture;
  Future<bool>? _activeLoadFuture;
  String? _activeLoadProjectId;
  bool _queuedAnotherSave = false;
  String? _queuedCheckpoint;
  Timer? _autoSaveDebounce;

  ProjectDataModel get projectData => _projectData;
  bool get isSaving => _isSaving;
  String? get lastError => _lastError;

  /// Mark data as dirty and schedule a debounced auto-save to Firebase.
  /// Cancels any pending auto-save so rapid changes are coalesced.
  void _markDirty() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(seconds: 2), () {
      saveToFirebase();
    });
  }

  /// Computes a rough progress percentage from the current checkpoint.
  static double _computeProgressFromCheckpoint(String checkpoint) {
    const phaseProgress = {
      'initiation': 0.05,
      'preferred_solution_analysis': 0.10,
      'project_charter': 0.15,
      'front_end_planning': 0.20,
      'fep_summary': 0.20,
      'fep_requirements': 0.22,
      'fep_risks': 0.24,
      'fep_opportunities': 0.26,
      'fep_contract_vendor_quotes': 0.28,
      'fep_procurement': 0.30,
      'fep_security': 0.32,
      'fep_milestone': 0.34,
      'fep_allowance': 0.36,
      'project_framework': 0.38,
      'project_goals_milestones': 0.40,
      'work_breakdown_structure': 0.42,
      'cost_estimate': 0.44,
      'schedule': 0.46,
      'technical_alignment': 0.48,
      'detailed_design': 0.50,
      'design_specifications': 0.52,
      'agile_development_iterations': 0.55,
      'scope_tracking_implementation': 0.58,
      'stakeholder_alignment': 0.60,
      'execution_plan': 0.62,
      'execution_plan_strategy': 0.63,
      'execution_plan_details': 0.64,
      'execution_early_works': 0.65,
      'execution_enabling_work_plan': 0.66,
      'execution_issue_management': 0.67,
      'execution_plan_construction_plan': 0.68,
      'execution_plan_infrastructure_plan': 0.69,
      'execution_plan_agile_delivery_plan': 0.70,
      'execution_plan_lessons_learned': 0.72,
      'execution_plan_best_practices': 0.74,
      'execution_plan_interface_management': 0.76,
      'execution_plan_communication_plan': 0.78,
      'staff_team': 0.80,
      'progress_tracking': 0.82,
      'status_reports': 0.84,
      'recurring_deliverables': 0.85,
      'quality_management': 0.86,
      'issue_management': 0.87,
      'risk_tracking': 0.88,
      'scope_completion': 0.89,
      'gap_analysis_scope_reconcillation': 0.90,
      'punchlist_actions': 0.91,
      'technical_debt_management': 0.92,
      'identify_staff_ops_team': 0.93,
      'salvage_disposal_team': 0.94,
      'launch_checklist': 0.95,
      'deliver_project_closure': 0.96,
      'transition_to_prod_team': 0.97,
      'contract_close_out': 0.97,
      'vendor_account_close_out': 0.98,
      'summarize_account_risks': 0.98,
      'commerce_viability': 0.99,
      'actual_vs_planned_gap_analysis': 0.99,
      'project_close_out': 0.99,
      'demobilize_team': 1.0,
      'finalize_project': 1.0,
    };
    return phaseProgress[checkpoint] ?? 0.1;
  }

  /// Resolves the project status from the current checkpoint.
  static String _resolveStatusFromCheckpoint(String checkpoint) {
    if (checkpoint.contains('finalize') || checkpoint.contains('demobilize')) {
      return 'Completed';
    }
    if (checkpoint.contains('deliver_project') || checkpoint.contains('close_out') ||
        checkpoint.contains('transition_to_prod') || checkpoint.contains('commerce_viability') ||
        checkpoint.contains('summarize_account') || checkpoint.contains('actual_vs_planned')) {
      return 'Launch';
    }
    if (checkpoint.contains('execution') || checkpoint.contains('staff_team') ||
        checkpoint.contains('progress_tracking') || checkpoint.contains('status_reports') ||
        checkpoint.contains('quality_management') || checkpoint.contains('issue_management') ||
        checkpoint.contains('risk_tracking') || checkpoint.contains('scope_completion') ||
        checkpoint.contains('gap_analysis') || checkpoint.contains('punchlist') ||
        checkpoint.contains('technical_debt') || checkpoint.contains('salvage_disposal') ||
        checkpoint.contains('launch_checklist') || checkpoint.contains('identify_staff_ops')) {
      return 'Execution';
    }
    if (checkpoint.contains('fep_') || checkpoint.contains('project_framework') ||
        checkpoint.contains('project_goals') || checkpoint.contains('work_breakdown') ||
        checkpoint.contains('cost_estimate') || checkpoint.contains('schedule') ||
        checkpoint.contains('technical_alignment') || checkpoint.contains('detailed_design') ||
        checkpoint.contains('design_specifications') || checkpoint.contains('agile_development') ||
        checkpoint.contains('scope_tracking_implementation') || checkpoint.contains('stakeholder_alignment')) {
      return 'Planning';
    }
    return 'Initiation';
  }

  /// Flush any pending auto-save immediately. Call before navigation so
  /// in-memory changes are persisted before the next screen loads.
  Future<void> flushAutoSave() async {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = null;
    if (_projectData.projectId != null) {
      await saveToFirebase();
    }
  }

  /// Update project data and notify listeners, then schedule auto-save
  void updateProjectData(ProjectDataModel data) {
    _projectData = ProjectIntelligenceService.rebuildActivityLog(data);
    notifyListeners();
    _markDirty();
  }

  /// Update specific fields in project data, then schedule auto-save
  void updateField(ProjectDataModel Function(ProjectDataModel) updater) {
    final updated = updater(_projectData);
    _projectData = ProjectIntelligenceService.rebuildActivityLog(updated);
    notifyListeners();
    _markDirty();
  }

  /// Save current project data to Firebase
  Future<bool> saveToFirebase({String? checkpoint}) async {
    // Coalesce rapid consecutive saves. If one save is already in-flight, mark
    // that another pass is needed and reuse the same future.
    if (_activeSaveFuture != null) {
      _queuedAnotherSave = true;
      if (checkpoint != null) {
        _queuedCheckpoint = checkpoint;
      }
      return _activeSaveFuture!;
    }

    _queuedCheckpoint = checkpoint;
    final saveFuture = _drainSaveQueue();
    _activeSaveFuture = saveFuture;
    final result = await saveFuture;
    return result;
  }

  Future<bool> _drainSaveQueue() async {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = null;
    var overallSuccess = true;
    var checkpointToSave = _queuedCheckpoint;
    _queuedCheckpoint = null;

    try {
      do {
        _queuedAnotherSave = false;
        final success = await _performSave(checkpoint: checkpointToSave);
        overallSuccess = overallSuccess && success;
        checkpointToSave = _queuedCheckpoint;
        _queuedCheckpoint = null;
      } while (_queuedAnotherSave || checkpointToSave != null);

      return overallSuccess;
    } finally {
      _activeSaveFuture = null;
    }
  }

  Future<bool> _performSave({String? checkpoint}) async {
    final previousProjectId = _projectData.projectId;
    final previousCheckpoint = _projectData.currentCheckpoint;

    _isSaving = true;
    _lastError = null;

    try {
      _projectData =
          ProjectIntelligenceService.rebuildActivityLog(_projectData);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _lastError = 'User not authenticated';
        _isSaving = false;
        // Failure state should still notify so error surfaces can react.
        notifyListeners();
        return false;
      }

      final projectsCol = FirebaseFirestore.instance.collection('projects');
      final now = FieldValue.serverTimestamp();

      // Prepare data payload
      final effectiveCheckpoint = checkpoint ?? _projectData.currentCheckpoint ?? 'initiation';
      final dataPayload = {
        ..._projectData.toJson(),
        'ownerId': user.uid,
        'ownerName': user.displayName ?? user.email ?? 'User',
        'ownerEmail': user.email,
        'updatedAt': now,
        // Always update progress/status/milestone so the dashboard tracks correctly
        'progress': _computeProgressFromCheckpoint(effectiveCheckpoint),
        'status': _resolveStatusFromCheckpoint(effectiveCheckpoint),
        'milestone': effectiveCheckpoint,
        if (checkpoint != null) 'checkpointRoute': checkpoint,
        if (checkpoint != null) 'checkpointAt': now,
      };

      if (_projectData.projectId != null) {
        // Update existing project
        await projectsCol.doc(_projectData.projectId).update(dataPayload);
      } else {
        // Create new project
        dataPayload['createdAt'] = now;
        dataPayload['status'] = dataPayload['status'] ??
            'Initiation'; // Use Initiation instead of 'In Progress' to match query expectations
        dataPayload['progress'] = dataPayload['progress'] ?? 0.1;
        dataPayload['investmentMillions'] =
            dataPayload['investmentMillions'] ?? 0.0;
        dataPayload['milestone'] = checkpoint ?? 'initiation';

        // Ensure both 'name' and 'projectName' are set for query compatibility
        final projectName =
            dataPayload['projectName'] ?? dataPayload['name'] ?? '';
        if (projectName.isNotEmpty) {
          dataPayload['name'] = projectName;
          dataPayload['projectName'] = projectName;
        }

        // Ensure isBasicPlanProject is set
        dataPayload['isBasicPlanProject'] =
            dataPayload['isBasicPlanProject'] ?? false;

        final ref = await projectsCol.add(dataPayload);
        _projectData = _projectData.copyWith(
          projectId: ref.id,
          createdAt: DateTime.now(),
        );

        debugPrint(
            '✅ Project created with ID: ${ref.id}, name: $projectName, ownerId: ${user.uid}');
      }

      _projectData = _projectData.copyWith(
        updatedAt: DateTime.now(),
        currentCheckpoint: checkpoint ?? _projectData.currentCheckpoint,
      );

      _isSaving = false;

      // Avoid global rebuild churn on every save by notifying only when the
      // observable project state materially changed.
      final hasNewProjectId = previousProjectId != _projectData.projectId;
      final hasCheckpointChange =
          previousCheckpoint != _projectData.currentCheckpoint;
      if (hasNewProjectId || hasCheckpointChange) {
        notifyListeners();
      }

      final projectId = _projectData.projectId;
      // Track the most-recently-saved project for router-level auto-logging.
      if (projectId != null && projectId.isNotEmpty) {
        lastKnownProjectId = projectId;
      }
      if (checkpoint != null && projectId != null && projectId.isNotEmpty) {
        unawaited(
          ActivityLogService.instance.logCheckpointActivity(
            projectId: projectId,
            checkpoint: checkpoint,
            action: 'Saved page changes',
          ),
        );
        // Also record via the auto-logger so the entry includes the
        // 'auto: true' flag and a normalized phase label.
        final phase = SidebarNavigationService.phaseForCheckpoint(checkpoint) ??
            'Project';
        final item = SidebarNavigationService.instance
            .findItemByCheckpoint(checkpoint);
        unawaited(
          ActivityAutoLogger.instance.logDataSave(
            projectId: projectId,
            checkpoint: checkpoint,
            page: item?.label ?? checkpoint,
            phase: phase,
          ),
        );
      }

      return true;
    } catch (e) {
      _lastError = e.toString();
      _isSaving = false;
      // Failure state should still notify so error surfaces can react.
      notifyListeners();
      return false;
    }
  }

  /// Load project data from Firebase by ID
  Future<bool> loadFromFirebase(String projectId) async {
    if (_activeLoadFuture != null) {
      if (_activeLoadProjectId == projectId) {
        return _activeLoadFuture!;
      }
      // Serialize distinct project loads to avoid parallel heavy deserialization.
      await _activeLoadFuture;
    }

    final loadFuture = _loadFromFirebaseInternal(projectId);
    _activeLoadFuture = loadFuture;
    _activeLoadProjectId = projectId;

    try {
      return await loadFuture;
    } finally {
      if (identical(_activeLoadFuture, loadFuture)) {
        _activeLoadFuture = null;
        _activeLoadProjectId = null;
      }
    }
  }

  Future<bool> _loadFromFirebaseInternal(String projectId) async {
    const cacheValidationTimeout = Duration(seconds: 8);
    const projectLoadTimeout = Duration(seconds: 25);

    // Track the most-recently-loaded project for router-level auto-logging.
    lastKnownProjectId = projectId;

    // Skip if already loaded and cached, but only if data is valid
    if (_cachedProjectId == projectId &&
        _projectData.projectId == projectId &&
        _projectData.projectId != null &&
        _projectData.projectId!.isNotEmpty) {
      // Verify the cached data is still valid by checking if project exists
      try {
        final doc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .get()
            .timeout(cacheValidationTimeout);
        if (doc.exists) {
          return true; // Cached data is valid
        }
      } catch (e) {
        debugPrint('Error validating cached project: $e');
        // Continue to reload if validation fails
      }
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get()
          .timeout(projectLoadTimeout);

      if (!doc.exists) {
        _lastError = 'Project not found';
        debugPrint('Project not found: $projectId');
        notifyListeners();
        return false;
      }

      final data = doc.data();
      if (data == null) {
        _lastError = 'Project data is empty';
        debugPrint('Project data is null: $projectId');
        notifyListeners();
        return false;
      }

      debugPrint('Loading project data for: $projectId');
      debugPrint('Raw data keys: ${data.keys.toList()}');

      // Convert Firestore Timestamps to ISO8601 strings for compatibility (recursive)
      final sanitizedData =
          _sanitizeTimestampsRecursive(data) as Map<String, dynamic>;

      try {
        _projectData = _decodeProjectData(sanitizedData, projectId);
        _cachedProjectId = projectId;
        debugPrint('Project loaded successfully: ${_projectData.projectName}');
        notifyListeners();
        return true;
      } catch (parseError) {
        // Avoid logging full payloads (large docs can cause memory pressure).
        debugPrint('Primary parse failed for $projectId: $parseError');
        debugPrint('Payload summary: ${_summarizePayload(sanitizedData)}');

        final compactPayload = _compactPayloadForRecovery(sanitizedData);
        try {
          _projectData = _decodeProjectData(compactPayload, projectId);
          _cachedProjectId = projectId;
          debugPrint(
              'Project loaded in safe recovery mode: ${_projectData.projectName}');
          notifyListeners();
          return true;
        } catch (recoveryError) {
          _lastError =
              'Failed to parse project data: ${recoveryError.toString()}';
          debugPrint('Recovery parse failed: $recoveryError');
          notifyListeners();
          return false;
        }
      }
    } catch (e, stackTrace) {
      if (e is TimeoutException) {
        _lastError =
            'Request timed out while loading project data. Please try again.';
      } else {
        _lastError = e.toString();
      }
      debugPrint('Error loading project: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      return false;
    }
  }

  ProjectDataModel _decodeProjectData(
      Map<String, dynamic> source, String projectId) {
    final parsed = ProjectDataModel.fromJson(source);
    final withProjectId = parsed.copyWith(projectId: projectId);
    // One-time migration: backfill requirementType (sourceSection tag) on
    // existing risks that have no source-section tag.
    final migrated = _migrateRiskSourceSections(withProjectId);
    return ProjectIntelligenceService.rebuildActivityLog(migrated);
  }

  /// One-time migration: backfills `requirementType` on existing risks that
  /// have no source-section tag. Uses category heuristics to infer the
  /// originating section.
  ProjectDataModel _migrateRiskSourceSections(ProjectDataModel data) {
    final items = data.frontEndPlanning.riskRegisterItems;
    if (items.isEmpty) return data;
    bool changed = false;
    final migrated = items.map((r) {
      final rt = r.requirementType.trim();
      if (rt.isNotEmpty) return r;
      final cat = r.category.trim().toLowerCase();
      String inferred;
      if (cat == 'safety' ||
          cat == 'security' ||
          cat == 'health' ||
          cat == 'environment' ||
          cat == 'regulatory') {
        inferred = 'SSHER';
      } else if (cat.contains('interface')) {
        inferred = 'Interface Management';
      } else if (cat.contains('design')) {
        inferred = 'Design Planning';
      } else if (cat.contains('quality')) {
        inferred = 'Quality';
      } else if (cat.contains('execution') || cat.contains('tracking')) {
        inferred = 'Risk Tracking Workspace';
      } else {
        inferred = 'Front End Planning';
      }
      changed = true;
      return RiskRegisterItem(
        riskName: r.riskName,
        description: r.description,
        category: r.category,
        requirement: r.requirement,
        requirementType: inferred,
        impactLevel: r.impactLevel,
        likelihood: r.likelihood,
        mitigationStrategy: r.mitigationStrategy,
        discipline: r.discipline,
        projectRole: r.projectRole,
        owner: r.owner,
        status: r.status,
        probabilityNumeric: r.probabilityNumeric,
        costImpactMin: r.costImpactMin,
        costImpactMostLikely: r.costImpactMostLikely,
        costImpactMax: r.costImpactMax,
        scheduleImpactMin: r.scheduleImpactMin,
        scheduleImpactMostLikely: r.scheduleImpactMostLikely,
        scheduleImpactMax: r.scheduleImpactMax,
        controlAccountId: r.controlAccountId,
        cbsId: r.cbsId,
        riskType: r.riskType,
        responseStrategy: r.responseStrategy,
        residualProbability: r.residualProbability,
        residualCostImpact: r.residualCostImpact,
      );
    }).toList();
    if (!changed) return data;
    return data.copyWith(
      frontEndPlanning:
          data.frontEndPlanning.copyWith(riskRegisterItems: migrated),
    );
  }

  static String _summarizePayload(Map<String, dynamic> payload) {
    int listCount(String key) {
      final value = payload[key];
      return value is List ? value.length : -1;
    }

    final execution = payload['executionPhaseData'];
    var executionSections = 0;
    if (execution is Map && execution['sectionData'] is Map) {
      executionSections = (execution['sectionData'] as Map).length;
    }

    return 'keys=${payload.length}, '
        'projectActivities=${listCount('projectActivities')}, '
        'goalWorkItems=${listCount('goalWorkItems')}, '
        'aiRecommendations=${listCount('aiRecommendations')}, '
        'aiIntegrations=${listCount('aiIntegrations')}, '
        'externalIntegrations=${listCount('externalIntegrations')}, '
        'executionSections=$executionSections';
  }

  static Map<String, dynamic> _compactPayloadForRecovery(
      Map<String, dynamic> payload) {
    final compact = Map<String, dynamic>.from(payload);

    List<dynamic>? compactList(String key, int maxItems) {
      final raw = payload[key];
      if (raw is! List) return null;
      if (raw.length <= maxItems) return raw;
      return raw.sublist(0, maxItems);
    }

    final activities = compactList('projectActivities', 350);
    if (activities != null) {
      compact['projectActivities'] = activities;
    }

    final workItems = compactList('goalWorkItems', 900);
    if (workItems != null) {
      compact['goalWorkItems'] = workItems;
    }

    final aiRecommendations = compactList('aiRecommendations', 300);
    if (aiRecommendations != null) {
      compact['aiRecommendations'] = aiRecommendations;
    }

    final aiIntegrations = compactList('aiIntegrations', 200);
    if (aiIntegrations != null) {
      compact['aiIntegrations'] = aiIntegrations;
    }

    final externalIntegrations = compactList('externalIntegrations', 200);
    if (externalIntegrations != null) {
      compact['externalIntegrations'] = externalIntegrations;
    }

    final execution = payload['executionPhaseData'];
    if (execution is Map) {
      final executionMap = Map<String, dynamic>.from(execution);
      final sectionData = executionMap['sectionData'];
      if (sectionData is Map) {
        final trimmedSectionData = <String, dynamic>{};
        sectionData.forEach((key, value) {
          if (value is List && value.length > 120) {
            trimmedSectionData[key.toString()] = value.sublist(0, 120);
          } else {
            trimmedSectionData[key.toString()] = value;
          }
        });
        executionMap['sectionData'] = trimmedSectionData;
      }
      compact['executionPhaseData'] = executionMap;
    }

    return compact;
  }

  /// Recursively sanitize Timestamp objects in nested data structures
  static dynamic _sanitizeTimestampsRecursive(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is List) {
      return value.map((item) => _sanitizeTimestampsRecursive(item)).toList();
    } else if (value is Map) {
      final sanitizedMap = <String, dynamic>{};
      value.forEach((key, val) {
        sanitizedMap[key.toString()] = _sanitizeTimestampsRecursive(val);
      });
      return sanitizedMap;
    }
    return value;
  }

  /// Reset project data to initial state
  void reset() {
    final hadData = _projectData.projectId != null;
    _projectData = ProjectDataModel();
    _lastError = null;
    _cachedProjectId = null; // Clear cache
    if (hadData) notifyListeners(); // Only notify if there was data to clear
  }

  /// Update initiation phase data
  void updateInitiationData({
    String? projectName,
    String? solutionTitle,
    String? solutionDescription,
    String? businessCase,
    String? notes,
    List<String>? tags,
    List<PotentialSolution>? potentialSolutions,
    List<SolutionRisk>? solutionRisks,
    Map<String, String>? riskMitigationPlans,
  }) {
    _projectData = _projectData.copyWith(
      projectName: projectName ?? _projectData.projectName,
      solutionTitle: solutionTitle ?? _projectData.solutionTitle,
      solutionDescription:
          solutionDescription ?? _projectData.solutionDescription,
      businessCase: businessCase ?? _projectData.businessCase,
      notes: notes ?? _projectData.notes,
      tags: tags ?? _projectData.tags,
      potentialSolutions: potentialSolutions ?? _projectData.potentialSolutions,
      solutionRisks: solutionRisks ?? _projectData.solutionRisks,
      riskMitigationPlans:
          riskMitigationPlans ?? _projectData.riskMitigationPlans,
    );
    notifyListeners();
    _markDirty();
  }

  /// Update project framework data
  void updateFrameworkData({
    String? overallFramework,
    List<ProjectGoal>? projectGoals,
  }) {
    _projectData = _projectData.copyWith(
      overallFramework: overallFramework ?? _projectData.overallFramework,
      projectGoals: projectGoals ?? _projectData.projectGoals,
    );
    notifyListeners();
    _markDirty();
  }

  /// Update planning phase data
  void updatePlanningData({
    String? potentialSolution,
    String? projectObjective,
    List<PlanningGoal>? planningGoals,
    List<Milestone>? keyMilestones,
    Map<String, String>? planningNotes,
  }) {
    _projectData = _projectData.copyWith(
      potentialSolution: potentialSolution ?? _projectData.potentialSolution,
      projectObjective: projectObjective ?? _projectData.projectObjective,
      planningGoals: planningGoals ?? _projectData.planningGoals,
      keyMilestones: keyMilestones ?? _projectData.keyMilestones,
      planningNotes: planningNotes ?? _projectData.planningNotes,
    );
    notifyListeners();
    _markDirty();
  }

  /// Update work breakdown structure data
  void updateWBSData({
    String? wbsCriteriaA,
    String? wbsCriteriaB,
    List<List<WorkItem>>? goalWorkItems,
    List<WorkItem>? wbsTree,
  }) {
    _projectData = _projectData.copyWith(
      wbsCriteriaA: wbsCriteriaA ?? _projectData.wbsCriteriaA,
      wbsCriteriaB: wbsCriteriaB ?? _projectData.wbsCriteriaB,
      goalWorkItems: goalWorkItems ?? _projectData.goalWorkItems,
      wbsTree: wbsTree ?? _projectData.wbsTree,
    );
    notifyListeners();
    _markDirty();
  }

  /// Update front end planning data
  void updateFrontEndPlanningData(FrontEndPlanningData data) {
    _projectData = _projectData.copyWith(frontEndPlanning: data);
    notifyListeners();
    _markDirty();
  }

  /// Update SSHER data
  void updateSSHERData(SSHERData data) {
    _projectData = _projectData.copyWith(ssherData: data);
    notifyListeners();
    _markDirty();
  }

  /// Update team members
  void updateTeamMembers(List<TeamMember> members) {
    _projectData = _projectData.copyWith(teamMembers: members);
    notifyListeners();
    _markDirty();
  }

  /// Add a field value to history for undo functionality
  void addFieldToHistory(String fieldName, String value,
      {bool isAiGenerated = false}) {
    _projectData.addFieldToHistory(fieldName, value,
        isAiGenerated: isAiGenerated);
    notifyListeners();
  }

  /// Undo the last change to a field
  Future<bool> undoField(String fieldName, {String? checkpoint}) async {
    final previousValue = _projectData.undoField(fieldName);
    if (previousValue != null) {
      // Update the field value - this needs to be handled by the calling screen
      // as we don't know which field in the model this corresponds to
      notifyListeners();
      if (checkpoint != null) {
        await saveToFirebase(checkpoint: checkpoint);
      }
      return true;
    }
    return false;
  }

  /// Redo a reverted change to a field
  Future<bool> redoField(String fieldName, {String? checkpoint}) async {
    final redoneValue = _projectData.redoField(fieldName);
    if (redoneValue != null) {
      notifyListeners();
      if (checkpoint != null) {
        await saveToFirebase(checkpoint: checkpoint);
      }
      return true;
    }
    return false;
  }

  /// Check if a field can be undone
  bool canUndoField(String fieldName) {
    return _projectData.canUndoField(fieldName);
  }

  /// Check if a field can be redone
  bool canRedoField(String fieldName) {
    return _projectData.canRedoField(fieldName);
  }

  /// Add a new potential solution
  Future<bool> addPotentialSolution({String? checkpoint}) async {
    if (_projectData.potentialSolutions.length >= 3) {
      return false;
    }
    _projectData.addPotentialSolution();
    notifyListeners();
    if (checkpoint != null) {
      await saveToFirebase(checkpoint: checkpoint);
    }
    return true;
  }

  /// Delete a potential solution by ID
  Future<bool> deletePotentialSolution(String id, {String? checkpoint}) async {
    final hadSolution = _projectData.potentialSolutions.any((s) => s.id == id);
    if (!hadSolution) return false;

    _projectData.deletePotentialSolution(id);
    notifyListeners();
    if (checkpoint != null) {
      await saveToFirebase(checkpoint: checkpoint);
    }
    return true;
  }

  /// Set the preferred solution
  Future<bool> setPreferredSolution(String solutionId,
      {String? checkpoint}) async {
    final solutionExists =
        _projectData.potentialSolutions.any((s) => s.id == solutionId);
    if (!solutionExists) return false;

    _projectData.setPreferredSolution(solutionId);
    notifyListeners();
    if (checkpoint != null) {
      await saveToFirebase(checkpoint: checkpoint);
    }
    return true;
  }

  /// Get the preferred solution
  PotentialSolution? get preferredSolution => _projectData.preferredSolution;

  /// Update cost benefit currency
  void updateCostBenefitCurrency(String currency) {
    _projectData = _projectData.copyWith(costBenefitCurrency: currency);
    notifyListeners();
    _markDirty();
  }
}

/// InheritedWidget to provide project data throughout the widget tree
class ProjectDataInherited extends InheritedNotifier<ProjectDataProvider> {
  const ProjectDataInherited({
    super.key,
    required ProjectDataProvider provider,
    required super.child,
  }) : super(notifier: provider);

  static ProjectDataProvider? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ProjectDataInherited>()
        ?.notifier;
  }

  static ProjectDataProvider? maybeRead(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<ProjectDataInherited>();
    final widget = element?.widget;
    if (widget is ProjectDataInherited) {
      return widget.notifier;
    }
    return null;
  }

  static ProjectDataProvider of(BuildContext context) {
    final provider = maybeOf(context);
    assert(provider != null, 'No ProjectDataInherited found in context');
    return provider!;
  }

  static ProjectDataProvider read(BuildContext context) {
    final provider = maybeRead(context);
    assert(provider != null, 'No ProjectDataInherited found in context');
    return provider!;
  }
}
