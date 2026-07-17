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

const String _storageKey = 'ndu_schedule_v1';

class ScheduleProvider extends ChangeNotifier {
  Schedule? _schedule;
  bool _setupComplete = false;

  Schedule? get schedule => _schedule;
  bool get setupComplete => _setupComplete;

  ScheduleProvider() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final state = data['state'] as Map<String, dynamic>? ?? {};
        _setupComplete = state['setupComplete'] as bool? ?? false;
        // Simplified deserialization — in production, use full JSON mapping
        if (state['schedule'] != null) {
          _schedule =
              _scheduleFromJson(state['schedule'] as Map<String, dynamic>);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading schedule: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = _schedule;
      final data = {
        'state': {
          'schedule': s != null
              ? {
                  'id': s.id,
                  'projectId': s.projectId,
                  'projectName': s.projectName,
                  'deliveryModel': s.basis.deliveryModel,
                  'status': s.status.name,
                  'isLocked': s.isLocked,
                  'activities': s.activities.map((a) => a.toJson()).toList(),
                }
              : null,
          'setupComplete': _setupComplete,
        },
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving schedule: $e');
    }
  }

  Schedule _scheduleFromJson(Map<String, dynamic> json) {
    final deliveryModel = json['deliveryModel'] as String? ?? 'WATERFALL';
    final s = createEmptySchedule(
      projectName: json['projectName'] as String? ?? 'Project',
      deliveryModel: deliveryModel,
    );
    final rawActivities = json['activities'] as List<dynamic>?;
    if (rawActivities != null && rawActivities.isNotEmpty) {
      final activities = rawActivities
          .map((a) => ScheduleActivity.fromJson(a as Map<String, dynamic>))
          .toList();
      return s.copyWith(activities: activities);
    }
    return s;
  }

  // ─── Setup ──────────────────────────────────────────────────────────────

  void setup({required String projectName, required String deliveryModel}) {
    _schedule = createEmptySchedule(
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

  // ─── Basis ──────────────────────────────────────────────────────────────

  void updateBasis(ScheduleBasis patch) {
    if (_schedule == null) return;
    _schedule = _schedule!.copyWith(
      basis: _schedule!.basis.copyWith(
        deliveryModel: patch.deliveryModel,
        sprintDurationWeeks: patch.sprintDurationWeeks,
        releaseCadence: patch.releaseCadence,
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

    ScheduleActivity _buildActivity(WbsImportNode node, int level) {
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
            node.children.map((c) => _buildActivity(c, level + 1)).toList(),
      );
    }

    final newChildren = [
      ...root.children,
      ...wbsNodes.map((n) => _buildActivity(n, 1)),
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
