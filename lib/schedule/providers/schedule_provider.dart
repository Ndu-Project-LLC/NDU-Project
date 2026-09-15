library;

/// Schedule — ChangeNotifier-based state management (Dart equivalent)
///
/// Mirrors the Zustand store in the Next.js module.
/// Persists to SharedPreferences as JSON.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/services/schedule_cpm_service.dart';
import 'package:ndu_project/schedule/utils/schedule_purchase_cost.dart';
import 'package:ndu_project/schedule/utils/schedule_wbs_packages.dart';
import 'package:ndu_project/utils/project_scoped_storage.dart';

/// Project-scoped storage key prefix — see [projectScopedPrefsKey].
///
/// Storage used to be one global entry (`ndu_schedule_v1`), so every project in
/// the workspace read back whichever project's schedule was saved last.
/// Records under that legacy key are now adopted once, by the project they
/// belong to, and then removed.
const String _storageKeyPrefix = 'ndu_schedule_v2';
const String _legacyStorageKey = 'ndu_schedule_v1';

class ScheduleProvider extends ChangeNotifier {
  Schedule? _schedule;
  bool _setupComplete = false;

  /// Project whose schedule is currently held in [_schedule] (see
  /// [ensureProjectLoaded]) — [unattributedProjectId] until one is loaded.
  String _activeProjectId = unattributedProjectId;

  /// True until the constructor's bootstrap read of the current scope settles.
  bool _isLoadingFromStorage = true;

  Schedule? get schedule => _schedule;
  bool get setupComplete => _setupComplete;

  /// The project whose schedule this provider currently holds.
  String get activeProjectId => _activeProjectId;

  ScheduleProvider() {
    _loadFromStorage();
  }

  String _storageKeyForProject(String projectId) =>
      projectScopedPrefsKey(_storageKeyPrefix, projectId);

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKeyForProject(_activeProjectId));
      if (raw != null) {
        _applyStoredState(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error loading schedule: $e');
    } finally {
      _isLoadingFromStorage = false;
      notifyListeners();
    }
  }

  /// Applies a decoded `{'state': {...}}` payload to this provider.
  void _applyStoredState(Map<String, dynamic> decoded) {
    final state = decoded['state'] as Map<String, dynamic>? ?? {};
    _setupComplete = state['setupComplete'] as bool? ?? false;
    final scheduleJson = state['schedule'] as Map<String, dynamic>?;
    _schedule =
        scheduleJson != null ? _scheduleFromJson(scheduleJson) : null;
  }

  /// Makes [projectId]'s own schedule the one in memory before any caller reads
  /// [schedule].
  ///
  /// Screens must call this on entry (and whenever the active project changes):
  /// storage is project-scoped, so without it the provider would keep showing
  /// the previously opened project's activities, basis and reviewers. A legacy
  /// global record is adopted here — once — by the project it belongs to and
  /// then removed, so it can never appear inside another project.
  ///
  /// An empty [projectId] selects the [unattributedProjectId] scope rather than
  /// silently keeping another project's schedule on screen.
  Future<void> ensureProjectLoaded(
    String projectId, {
    String? projectName,
  }) async {
    final pid = projectId.trim().isEmpty
        ? unattributedProjectId
        : projectId.trim();

    // Wait for the constructor's bootstrap read so we don't race it.
    while (_isLoadingFromStorage) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    if (_activeProjectId == pid) return;

    // Reset before loading, so a missing/failed load can never leave the
    // previous project's schedule on screen.
    _activeProjectId = pid;
    _schedule = null;
    _setupComplete = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKeyForProject(pid));
      if (raw != null) {
        _applyStoredState(jsonDecode(raw) as Map<String, dynamic>);
        notifyListeners();
        return;
      }
      await _adoptLegacyRecord(prefs, pid, projectName);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading project-scoped schedule: $e');
    }
  }

  /// Adopts the pre-scoping global record ([_legacyStorageKey]) for [pid] when
  /// it belongs to that project, then moves it onto the project's own key and
  /// clears the legacy entry so it is claimed exactly once.
  Future<void> _adoptLegacyRecord(
    SharedPreferences prefs,
    String pid,
    String? projectName,
  ) async {
    final raw = prefs.getString(_legacyStorageKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final state = decoded['state'] as Map<String, dynamic>? ?? {};
    final scheduleJson = state['schedule'] as Map<String, dynamic>?;
    if (scheduleJson == null) return;
    if (!legacyRecordBelongsToProject(
      projectId: pid,
      projectName: projectName,
      legacyProjectId: scheduleJson['projectId']?.toString(),
      legacyProjectName: scheduleJson['projectName']?.toString(),
    )) {
      return;
    }

    _applyStoredState(decoded);
    final adopted = _schedule;
    if (adopted != null && adopted.projectId != pid) {
      final resolvedName = (projectName ?? '').trim();
      _schedule = adopted.copyWith(
        projectId: pid,
        projectName: resolvedName.isEmpty ? adopted.projectName : resolvedName,
      );
    }
    await _saveToStorage();
    await prefs.remove(_legacyStorageKey);
  }

  Future<void> _saveToStorage() async {
    // Snapshot the target key and payload BEFORE awaiting: a project switch that
    // lands while this write is in flight must not retarget it at another
    // project's key or serialise the wrong state.
    final key = _storageKeyForProject(_activeProjectId);
    final payload = jsonEncode(_statePayload());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, payload);
    } catch (e) {
      debugPrint('Error saving schedule: $e');
    }
  }

  /// Serialises the current state — written under the ACTIVE PROJECT's key
  /// only, so a save can never write one project's schedule into another's.
  Map<String, dynamic> _statePayload() {
    final s = _schedule;
    return {
        'state': {
          'schedule': s != null
              ? {
                  'id': s.id,
                  'projectId': s.projectId,
                  'projectName': s.projectName,
                  'deliveryModel': s.basis.deliveryModel,
                  'status': s.status.name,
                  'isLocked': s.isLocked,
                  'basis': _basisToJson(s.basis),
                  'estimateBasis': _estimateBasisToJson(s.estimateBasis),
                  'activities': s.activities.map((a) => a.toJson()).toList(),
                }
              : null,
          'setupComplete': _setupComplete,
        },
    };
  }

  Schedule _scheduleFromJson(Map<String, dynamic> json) {
    final deliveryModel = json['deliveryModel'] as String? ?? 'WATERFALL';
    final s = createEmptySchedule(
      projectId: json['projectId'] as String? ?? unattributedProjectId,
      projectName: json['projectName'] as String? ?? 'Project',
      deliveryModel: deliveryModel,
    );
    final rawActivities = json['activities'] as List<dynamic>?;
    if (rawActivities != null && rawActivities.isNotEmpty) {
      final activities = rawActivities
          .map((a) => ScheduleActivity.fromJson(a as Map<String, dynamic>))
          .toList();
      var restored = s.copyWith(activities: activities);
      final basisJson = json['basis'] as Map<String, dynamic>?;
      if (basisJson != null) {
        restored = restored.copyWith(basis: _basisFromJson(basisJson));
      }
      final estimateJson = json['estimateBasis'] as Map<String, dynamic>?;
      if (estimateJson != null) {
        restored = restored.copyWith(estimateBasis: _estimateBasisFromJson(estimateJson));
      }
      return restored;
    }
    return s;
  }

  static Map<String, dynamic> _basisToJson(ScheduleBasis b) => {
        'deliveryModel': b.deliveryModel,
        if (b.sprintDurationWeeks != null)
          'sprintDurationWeeks': b.sprintDurationWeeks,
        if (b.releaseCadence != null) 'releaseCadence': b.releaseCadence,
        if (b.incrementStrategy != null)
          'incrementStrategy': b.incrementStrategy,
        if (b.definitionOfReady != null)
          'definitionOfReady': b.definitionOfReady,
        if (b.definitionOfDone != null)
          'definitionOfDone': b.definitionOfDone,
        'assumptions': b.assumptions,
        'constraints': b.constraints,
        'milestones': b.milestones,
        'interfaces': b.interfaces,
      };

  static ScheduleBasis _basisFromJson(Map<String, dynamic> json) {
    return ScheduleBasis(
      deliveryModel: json['deliveryModel'] as String? ?? 'WATERFALL',
      sprintDurationWeeks: (json['sprintDurationWeeks'] as num?)?.toInt(),
      releaseCadence: json['releaseCadence'] as String?,
      incrementStrategy: json['incrementStrategy'] as String?,
      definitionOfReady: json['definitionOfReady'] as String?,
      definitionOfDone: json['definitionOfDone'] as String?,
      assumptions: (json['assumptions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      constraints: (json['constraints'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      milestones: (json['milestones'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      interfaces: (json['interfaces'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  static Map<String, dynamic>? _estimateBasisToJson(EstimateBasis? e) {
    if (e == null) return null;
    return {
      'scopeAlignment': e.scopeAlignment,
      'estimationMethods': e.estimationMethods.map((m) => m.name).toList(),
      'keyAssumptions': e.keyAssumptions,
      'procurementConsiderations': e.procurementConsiderations,
      'engineeringConsiderations': e.engineeringConsiderations,
      'constraintsAndRisks': e.constraintsAndRisks,
      'validationBenchmarking': e.validationBenchmarking,
      'documentation': e.documentation,
    };
  }

  static EstimateBasis _estimateBasisFromJson(Map<String, dynamic> json) {
    return EstimateBasis(
      scopeAlignment: json['scopeAlignment'] as String? ?? '',
      estimationMethods:
          (json['estimationMethods'] as List<dynamic>? ?? [])
              .map((e) => EstimationMethod.values
                  .byName(e.toString())
                  // Defensive: any unknown method falls back to expert judgment.
                  )
              .toList()
              .cast<EstimationMethod>(),
      keyAssumptions:
          Map<String, String>.from(json['keyAssumptions'] as Map? ?? {}),
      procurementConsiderations: Map<String, String>.from(
          json['procurementConsiderations'] as Map? ?? {}),
      engineeringConsiderations: Map<String, String>.from(
          json['engineeringConsiderations'] as Map? ?? {}),
      constraintsAndRisks: (json['constraintsAndRisks'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      validationBenchmarking: json['validationBenchmarking'] as String? ?? '',
      documentation: json['documentation'] as String? ?? '',
    );
  }

  // ─── Setup ──────────────────────────────────────────────────────────────

  void setup({
    required String projectName,
    required String deliveryModel,
    String projectId = '',
  }) {
    // Bind the new schedule to the active project so it is persisted (and read
    // back) under that project's own key — never the shared `default` scope.
    _activeProjectId = projectId.trim().isNotEmpty
        ? projectId.trim()
        : _activeProjectId;
    _schedule = createEmptySchedule(
      projectId: _activeProjectId,
      projectName: projectName,
      deliveryModel: deliveryModel,
    );
    _setupComplete = true;
    notifyListeners();
    _saveToStorage();
  }

  void resetSchedule() {
    _schedule = null;
    _setupComplete = false;
    notifyListeners();
    _saveToStorage();
  }

  /// Re-syncs the schedule's delivery model with the project's current
  /// Project Details methodology selection (AGILE / WATERFALL / HYBRID).
  /// Existing activities and the rest of the basis are kept intact — only
  /// the methodology-dependent view state (badge, agile hints, level
  /// import behaviour) is updated.
  void syncDeliveryModel(String deliveryModel) {
    if (_schedule == null) return;
    final normalized = deliveryModel.toUpperCase();
    if (_schedule!.basis.deliveryModel.toUpperCase() == normalized) return;
    _schedule = _schedule!.copyWith(
      basis: _schedule!.basis.copyWith(deliveryModel: normalized),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  // ─── Basis ──────────────────────────────────────────────────────────────

  void updateBasis(ScheduleBasis patch) {
    if (_schedule == null) return;
    _schedule = _schedule!.copyWith(
      basis: _schedule!.basis.copyWith(
        deliveryModel: patch.deliveryModel,
        sprintDurationWeeks: patch.sprintDurationWeeks,
        releaseCadence: patch.releaseCadence,
        incrementStrategy: patch.incrementStrategy,
        definitionOfReady: patch.definitionOfReady,
        definitionOfDone: patch.definitionOfDone,
        assumptions: patch.assumptions,
        constraints: patch.constraints,
        milestones: patch.milestones,
        interfaces: patch.interfaces,
      ),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  /// Update the schedule's estimate basis (assumptions, methods, data
  /// sources used to determine activity durations).
  void updateEstimateBasis(EstimateBasis patch) {
    if (_schedule == null) return;
    final current = _schedule!.estimateBasis ?? createEmptyEstimateBasis();
    _schedule = _schedule!.copyWith(
      estimateBasis: current.copyWith(
        scopeAlignment: patch.scopeAlignment,
        estimationMethods: patch.estimationMethods,
        keyAssumptions: patch.keyAssumptions,
        procurementConsiderations: patch.procurementConsiderations,
        engineeringConsiderations: patch.engineeringConsiderations,
        constraintsAndRisks: patch.constraintsAndRisks,
        validationBenchmarking: patch.validationBenchmarking,
        documentation: patch.documentation,
      ),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  // ─── Activities ─────────────────────────────────────────────────────────

  void setActivities(List<ScheduleActivity> activities) {
    if (_schedule == null) return;
    _schedule = _schedule!.copyWith(
      activities: activities,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  CpmResult? computeCpm({bool overwriteDates = false, DateTime? projectStart}) {
    if (_schedule == null || _schedule!.activities.isEmpty) return null;
    final start = projectStart ?? DateTime.now();
    final flat = ScheduleCpmService.flatten(_schedule!.activities);
    final result = ScheduleCpmService.calculate(activities: flat);
    final updated = ScheduleCpmService.applyToActivities(
      roots: _schedule!.activities,
      projectStart: start,
      result: result,
      overwriteDates: overwriteDates,
    );
    _schedule = _schedule!.copyWith(
      activities: updated,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
    return result;
  }

  String addActivity(String parentId, ScheduleActivity activity) {
    if (_schedule == null || _schedule!.activities.isEmpty) return '';
    final id = newSchedId('act');
    final newActivity = activity.copyWith(id: id, code: '', level: 0);
    final root = _schedule!.activities[0];
    final updatedRoot = recalcActivityCodes(
      _findAndUpdate(
          root,
          parentId,
          (n) => n.copyWith(
                children: [...n.children, newActivity],
              )),
    );
    _schedule = _schedule!.copyWith(
      activities: [updatedRoot],
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
    return id;
  }

  void updateActivity(String id, ScheduleActivity patch) {
    if (_schedule == null || _schedule!.activities.isEmpty) return;
    final root = _schedule!.activities[0];
    final updatedRoot = recalcActivityCodes(
      _findAndUpdate(
          root,
          id,
          (a) => a.copyWith(
                name: patch.name,
                description: patch.description,
                domain: patch.domain,
                type: patch.type,
                duration: patch.duration,
                durationUnit: patch.durationUnit,
                owner: patch.owner,
                status: patch.status,
                progress: patch.progress,
                estimationMethod: patch.estimationMethod,
                storyPoints: patch.storyPoints,
                tShirtSize: patch.tShirtSize,
                definitionOfReady: patch.definitionOfReady,
                definitionOfDone: patch.definitionOfDone,
                costLineId: patch.costLineId,
                sprintId: patch.sprintId,
                releaseId: patch.releaseId,
                agileEpicTitle: patch.agileEpicTitle,
                agileFeatureTitle: patch.agileFeatureTitle,
                sprintLabel: patch.sprintLabel,
                releaseLabel: patch.releaseLabel,
                importSource: patch.importSource,
                startDate: patch.startDate,
                endDate: patch.endDate,
                isCriticalPath: patch.isCriticalPath,
                isLongLead: patch.isLongLead,
                dependencies: patch.dependencies,
                // Cross-section linkage (WBS ↔ Schedule ↔ Project Controls)
                wbsNodeId: patch.wbsNodeId,
                wbsCode: patch.wbsCode,
                controlAccountId: patch.controlAccountId,
                estimatedHours: patch.estimatedHours,
              )),
    );
    _schedule = _schedule!.copyWith(
      activities: [updatedRoot],
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  void removeActivity(String id) {
    if (_schedule == null || _schedule!.activities.isEmpty) return;
    final root = _schedule!.activities[0];
    if (root.id == id) return;
    final updatedRoot = recalcActivityCodes(_findAndRemove(root, id));
    _schedule = _schedule!.copyWith(
      activities: [updatedRoot],
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  void moveActivity(String id, bool directionUp) {
    if (_schedule == null || _schedule!.activities.isEmpty) return;
    final root = _schedule!.activities[0];
    final updatedRoot = recalcActivityCodes(
      _swapInTree(root, id, directionUp),
    );
    _schedule = _schedule!.copyWith(
      activities: [updatedRoot],
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  /// Legacy direct WBS import path retained for backward compatibility.
  ///
  /// Prefer integrated work-package generation for Waterfall/Hybrid and
  /// `importStoriesFromAgile` for Agile delivery flows.
  void importFromWBS(List<WbsImportNode> wbsNodes) {
    if (_schedule == null || _schedule!.activities.isEmpty) return;
    final root = _schedule!.activities[0];
    final dm = _schedule!.basis.deliveryModel;
    final isAgile = dm == 'AGILE' || dm == 'HYBRID';

    ScheduleActivity buildActivity(WbsImportNode node, int level) {
      // Use Agile-specific types and domain for Agile/Hybrid projects
      final type = isAgile
          ? (level <= 2 ? ActivityType.summary : ActivityType.activity)
          : ActivityType.summary;
      final domain = isAgile
          ? (level <= 3 ? ScheduleDomain.execution : _domainForLevel(level))
          : ScheduleDomain.engineering;

      return ScheduleActivity(
        id: newSchedId('act'),
        level: level,
        code: '',
        name: node.name,
        description: node.description,
        type: type,
        domain: domain,
        dependencies: [],
        aiGenerated: false,
        wbsNodeId: node.id,
        importSource: 'wbs',
        definitionOfReady: isAgile ? _schedule!.basis.definitionOfReady : null,
        definitionOfDone: isAgile ? _schedule!.basis.definitionOfDone : null,
        children:
            node.children.map((c) => buildActivity(c, level + 1)).toList(),
      );
    }

    final newChildren = [
      ...root.children,
      ...wbsNodes.map((n) => buildActivity(n, 1)),
    ];
    final updatedRoot =
        recalcActivityCodes(root.copyWith(children: newChildren));
    _schedule = _schedule!.copyWith(
      activities: [updatedRoot],
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  ScheduleDomain _domainForLevel(int level) {
    return switch (level) {
      1 => ScheduleDomain.engineering,
      2 => ScheduleDomain.execution,
      3 => ScheduleDomain.procurement,
      _ => ScheduleDomain.execution,
    };
  }

  /// Schedule ← WBS: puts the WBS work packages the schedule does not carry yet
  /// onto the schedule.
  ///
  /// Product rule (voice note, 2026-09-10): "the schedule should be able to put
  /// out everything that's like on the WBS [and it] should be able to find
  /// itself on the schedule". The owner had work packages that existed in the
  /// WBS but nowhere on the schedule, with no way to bring them across.
  ///
  /// Each [WbsPackagePull] becomes one leaf activity that keeps the link home —
  /// `wbsNodeId` (the FK the Gantt, the Cost Estimate and Project Controls all
  /// read) and the denormalised `wbsCode` — and starts from the package's own
  /// planned window when the WBS has one. The activity name is the package's
  /// `code — name` label, so the schedule row reads exactly like the WBS row.
  ///
  /// Idempotent by construction: a package whose node id is already linked from
  /// any activity in the tree is skipped, so re-running the pull after a partial
  /// import offers only what is still missing. Returns the number created.
  int attachWbsPackages(List<WbsPackagePull> packages) {
    if (packages.isEmpty) return 0;
    final schedule = _schedule;
    if (schedule == null || schedule.activities.isEmpty) return 0;

    final alreadyLinked = <String>{
      for (final activity in schedule.activities
          .expand((root) => ScheduleCpmService.flatten([root])))
        if ((activity.wbsNodeId ?? '').trim().isNotEmpty)
          activity.wbsNodeId!.trim(),
    };

    final additions = <ScheduleActivity>[];
    for (final package in packages) {
      final nodeId = package.nodeId.trim();
      if (nodeId.isEmpty || alreadyLinked.contains(nodeId)) continue;
      alreadyLinked.add(nodeId);

      final start = package.plannedStart;
      final finish = package.plannedFinish;
      additions.add(ScheduleActivity(
        id: newSchedId('act'),
        level: package.level.clamp(1, 4),
        code: '',
        name: package.label.trim().isEmpty ? package.name : package.label,
        description: package.description,
        type: ActivityType.task,
        domain: _domainForLevel(package.level),
        duration: start != null && finish != null
            ? finish.difference(start).inDays + 1
            : null,
        durationUnit: 'day',
        dependencies: const [],
        aiGenerated: false,
        wbsNodeId: nodeId,
        wbsCode: package.code.trim().isEmpty ? null : package.code.trim(),
        startDate: start,
        endDate: finish,
        status: 'planned',
        importSource: 'wbs',
        children: const [],
      ));
    }

    if (additions.isEmpty) return 0;

    final root = schedule.activities.first;
    final updatedRoot = recalcActivityCodes(
      root.copyWith(children: [...root.children, ...additions]),
    );
    _schedule = schedule.copyWith(
      activities: [updatedRoot, ...schedule.activities.skip(1)],
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
    return additions.length;
  }

  /// Fills the planned window the WBS carries onto the schedule activities
  /// linked to each node — the WBS → Schedule half of the timeline link.
  ///
  /// The other direction already exists (`WBSProvider.applyScheduleTimelines`
  /// stamps the schedule's dates onto the WBS). This one covers the case where
  /// the package's start and finish were agreed on the WBS first, and the
  /// schedule row is what is blank.
  ///
  /// Only activities with **no** dates of their own are written, so a CPM pass
  /// or a hand-entered window is never silently overwritten. Returns the number
  /// of activities that gained a date.
  int applyWbsPlannedDates(
      Map<String, ({DateTime? start, DateTime? finish})> byNodeId) {
    if (byNodeId.isEmpty) return 0;
    final schedule = _schedule;
    if (schedule == null || schedule.activities.isEmpty) return 0;

    var updated = 0;

    ScheduleActivity apply(ScheduleActivity activity) {
      final children = activity.children.map(apply).toList(growable: false);
      final nodeId = (activity.wbsNodeId ?? '').trim();
      final window = nodeId.isEmpty ? null : byNodeId[nodeId];
      if (window == null ||
          (window.start == null && window.finish == null) ||
          activity.startDate != null ||
          activity.endDate != null) {
        return children.isEmpty
            ? activity
            : activity.copyWith(children: children);
      }

      updated++;
      return activity.copyWith(
        startDate: window.start,
        endDate: window.finish,
        duration: window.start != null && window.finish != null
            ? window.finish!.difference(window.start!).inDays + 1
            : activity.duration,
        children: children,
      );
    }

    final updatedRoots =
        schedule.activities.map(apply).toList(growable: false);
    if (updated == 0) return 0;

    _schedule = schedule.copyWith(
      activities: updatedRoots,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
    return updated;
  }

  /// Stamps a Cost Estimate line onto the schedule activity it prices, so the
  /// schedule row can show that it is costed (and the estimate keeps pointing
  /// back at the row that created it).
  ///
  /// Returns the activity's WBS node id when it has one, so the caller can link
  /// the same line onto the WBS node and close the Schedule → Cost → WBS loop.
  String? attachCostLineToActivity(String activityId, String costLineId) {
    final schedule = _schedule;
    if (schedule == null) return null;
    final activity = findActivityById(schedule.activities, activityId);
    if (activity == null) return null;

    updateActivity(activity.id, activity.copyWith(costLineId: costLineId));

    final nodeId = (activity.wbsNodeId ?? '').trim();
    return nodeId.isEmpty ? null : nodeId;
  }

  /// Import AgileTask (story) records into the schedule as ScheduleActivity entries.
  ///
  /// Groups stories under Feature/Epic summary activities. Only operates when
  /// the schedule delivery model is AGILE or HYBRID.
  void importStoriesFromAgile({
    required List<
            ({
              AgileTask story,
              String epicTitle,
              String featureTitle,
              String? sprintLabel,
              String? releaseLabel
            })>
        stories,
  }) {
    if (_schedule == null || _schedule!.activities.isEmpty) return;
    final dm = _schedule!.basis.deliveryModel;
    if (dm != 'AGILE' && dm != 'HYBRID') return;

    final root = _schedule!.activities[0];

    // Build a map: epic title → feature title → list of stories
    final Map<String, Map<String, List<AgileTask>>> grouped = {};
    final Map<String, String?> sprintLabelByStoryId = {};
    final Map<String, String?> releaseLabelByStoryId = {};
    for (final entry in stories) {
      grouped.putIfAbsent(entry.epicTitle, () => {});
      grouped[entry.epicTitle]!.putIfAbsent(entry.featureTitle, () => []);
      grouped[entry.epicTitle]![entry.featureTitle]!.add(entry.story);
      sprintLabelByStoryId[entry.story.id] = entry.sprintLabel;
      releaseLabelByStoryId[entry.story.id] = entry.releaseLabel;
    }

    // Build feature activities as children of epic activities
    final List<ScheduleActivity> epicActivities = [];
    for (final epicEntry in grouped.entries) {
      final featureActivities = <ScheduleActivity>[];
      for (final featureEntry in epicEntry.value.entries) {
        final storyActivities = featureEntry.value.map((s) {
          return ScheduleActivity(
            id: newSchedId('act'),
            level: 4,
            code: '',
            name: s.userStory,
            description:
                s.taskDescription.isNotEmpty ? s.taskDescription : null,
            type: ActivityType.activity,
            domain: ScheduleDomain.execution,
            duration: null,
            dependencies: [],
            storyPoints: s.storyPoints.toDouble(),
            sprintId: s.plannedSprintId.isNotEmpty ? s.plannedSprintId : null,
            releaseId:
                s.plannedReleaseId.isNotEmpty ? s.plannedReleaseId : null,
            agileEpicTitle: epicEntry.key,
            agileFeatureTitle: featureEntry.key,
            sprintLabel: sprintLabelByStoryId[s.id],
            releaseLabel: releaseLabelByStoryId[s.id],
            estimationMethod: EstimationMethod.storyPoints,
            aiGenerated: false,
            children: [],
            agileTaskId: s.id,
            wbsNodeId: s.wbsId.isNotEmpty ? s.wbsId : null,
            importSource: 'agile_story',
            definitionOfReady: _schedule!.basis.definitionOfReady,
            definitionOfDone: _schedule!.basis.definitionOfDone,
            prerequisites: s.dependencyTaskIds.isEmpty
                ? null
                : List<String>.from(s.dependencyTaskIds),
          );
        }).toList();

        featureActivities.add(
          ScheduleActivity(
            id: newSchedId('act'),
            level: 3,
            code: '',
            name: featureEntry.key,
            type: ActivityType.summary,
            domain: ScheduleDomain.execution,
            dependencies: [],
            aiGenerated: false,
            children: storyActivities,
          ),
        );
      }

      epicActivities.add(
        ScheduleActivity(
          id: newSchedId('act'),
          level: 2,
          code: '',
          name: epicEntry.key,
          type: ActivityType.summary,
          domain: ScheduleDomain.execution,
          dependencies: [],
          aiGenerated: false,
          children: featureActivities,
        ),
      );
    }

    final updatedRoot = recalcActivityCodes(root.copyWith(
      children: [...root.children, ...epicActivities],
    ));
    _schedule = _schedule!.copyWith(
      activities: [updatedRoot],
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  // ─── Review ─────────────────────────────────────────────────────────────

  void addSMEReviewer(SMEReviewer reviewer) {
    if (_schedule == null) return;
    final review = _schedule!.review ??
        const ScheduleReview(
          stage1Reviewers: [],
          stage2Reviewers: [],
          stage1Complete: false,
          stage2Complete: false,
        );
    if (reviewer.stage == 1) {
      _schedule = _schedule!.copyWith(
        review: review.copyWith(
          stage1Reviewers: [...review.stage1Reviewers, reviewer],
        ),
      );
    } else {
      _schedule = _schedule!.copyWith(
        review: review.copyWith(
          stage2Reviewers: [...review.stage2Reviewers, reviewer],
        ),
      );
    }
    notifyListeners();
    _saveToStorage();
  }

  void approveReviewer(String id) {
    if (_schedule?.review == null) return;
    final review = _schedule!.review!;
    final now = DateTime.now();
    _schedule = _schedule!.copyWith(
      review: review.copyWith(
        stage1Reviewers: review.stage1Reviewers
            .map((r) => r.id == id
                ? SMEReviewer(
                    id: r.id,
                    name: r.name,
                    email: r.email,
                    role: r.role,
                    stage: r.stage,
                    approved: true,
                    approvedAt: now)
                : r)
            .toList(),
        stage2Reviewers: review.stage2Reviewers
            .map((r) => r.id == id
                ? SMEReviewer(
                    id: r.id,
                    name: r.name,
                    email: r.email,
                    role: r.role,
                    stage: r.stage,
                    approved: true,
                    approvedAt: now)
                : r)
            .toList(),
      ),
    );
    notifyListeners();
    _saveToStorage();
  }

  void completeStage1() {
    if (_schedule == null) return;
    _schedule = _schedule!.copyWith(
      status: ScheduleStatus.stage1Complete,
      review: (_schedule!.review ??
              const ScheduleReview(
                stage1Reviewers: [],
                stage2Reviewers: [],
                stage1Complete: false,
                stage2Complete: false,
              ))
          .copyWith(stage1Complete: true, stage1CompletedAt: DateTime.now()),
    );
    notifyListeners();
    _saveToStorage();
  }

  void completeStage2() {
    if (_schedule == null) return;
    _schedule = _schedule!.copyWith(
      status: ScheduleStatus.stage2Complete,
      review: (_schedule!.review ??
              const ScheduleReview(
                stage1Reviewers: [],
                stage2Reviewers: [],
                stage1Complete: false,
                stage2Complete: false,
              ))
          .copyWith(stage2Complete: true, stage2CompletedAt: DateTime.now()),
    );
    notifyListeners();
    _saveToStorage();
  }

  void proceedToCostEstimate() {
    if (_schedule == null) return;
    _schedule =
        _schedule!.copyWith(status: ScheduleStatus.readyForCostEstimate);
    notifyListeners();
    _saveToStorage();
  }

  // ─── Lock ───────────────────────────────────────────────────────────────

  void lock() {
    if (_schedule == null) return;
    _schedule =
        _schedule!.copyWith(isLocked: true, status: ScheduleStatus.locked);
    notifyListeners();
    _saveToStorage();
  }

  void unlock() {
    if (_schedule == null) return;
    _schedule = _schedule!
        .copyWith(isLocked: false, status: ScheduleStatus.readyForCostEstimate);
    notifyListeners();
    _saveToStorage();
  }

  // ─── Tree helpers ───────────────────────────────────────────────────────

  ScheduleActivity _findAndUpdate(ScheduleActivity root, String id,
      ScheduleActivity Function(ScheduleActivity) updater) {
    if (root.id == id) return updater(root);
    return root.copyWith(
      children:
          root.children.map((c) => _findAndUpdate(c, id, updater)).toList(),
    );
  }

  ScheduleActivity _findAndRemove(ScheduleActivity root, String id) {
    return root.copyWith(
      children: root.children
          .where((c) => c.id != id)
          .map((c) => _findAndRemove(c, id))
          .toList(),
    );
  }

  ScheduleActivity _swapInTree(
      ScheduleActivity root, String id, bool directionUp) {
    List<ScheduleActivity> swap(List<ScheduleActivity> arr) {
      final idx = arr.indexWhere((a) => a.id == id);
      if (idx >= 0) {
        if (directionUp && idx > 0) {
          final newArr = List<ScheduleActivity>.from(arr);
          final temp = newArr[idx - 1];
          newArr[idx - 1] = newArr[idx];
          newArr[idx] = temp;
          return newArr;
        }
        if (!directionUp && idx < arr.length - 1) {
          final newArr = List<ScheduleActivity>.from(arr);
          final temp = newArr[idx];
          newArr[idx] = newArr[idx + 1];
          newArr[idx + 1] = temp;
          return newArr;
        }
        return arr;
      }
      return arr.map((n) => n.copyWith(children: swap(n.children))).toList();
    }

    final idx = root.children.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      return root.copyWith(children: swap(root.children));
    }
    return root.copyWith(
        children:
            root.children.map((c) => _swapInTree(c, id, directionUp)).toList());
  }
}
