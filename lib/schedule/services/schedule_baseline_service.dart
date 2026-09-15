// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';

/// ─── Phase 2: WBS → Schedule integration ────────────────────────────
///
/// Snapshots the new module-scoped [Schedule] tree (with CPM already
/// computed) to Firestore as a versioned schedule baseline — the
/// schedule-side analog of the Performance Measurement Baseline.
///
/// This complements `BaselineManagementService.captureSnapshot`, which
/// snapshots the *legacy* `ProjectDataModel` (control accounts, WBS,
/// CBS, OBS). This service handles the new `lib/schedule/` module's
/// `Schedule` tree so that the schedule side of the integrated PMB is
/// versioned independently and can be diffed / restored.
///
/// Firestore path:
///   `projects/{projectId}/schedule_baselines/{versionId}`
/// Each document carries:
///   • versionNumber — monotonic per-project
///   • label / description / author / triggerSource
///   • status — 'stage1Complete' | 'stage2Complete' | 'locked'
///   • scheduleJson — full serialized Schedule tree (activities + basis)
///   • activityCount / milestoneCount / criticalPathCount — quick metrics
///   • isCurrent — true for the most recent locked baseline
///   • createdAt — server timestamp
class ScheduleBaselineService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _versionsCol(
          String projectId) =>
      _firestore
          .collection('projects')
          .doc(projectId)
          .collection('schedule_baselines');

  /// Capture a snapshot of the given [schedule] as a new baseline version.
  ///
  /// [triggerSource] should describe what prompted the snapshot:
  ///   • `'manual'` — user clicked "Lock Baseline"
  ///   • `'CCB-<crId>'` — approved Change Request forced a re-baseline
  ///   • `'IBR-passed'` — IBR gate cleared, baseline automatically locked
  ///   • `'stage2-approved'` — 2-stage SME review completed
  ///
  /// Returns the new version document ID.
  static Future<String> captureSnapshot({
    required String projectId,
    required Schedule schedule,
    required String author,
    String label = '',
    String description = '',
    String triggerSource = 'manual',
    String approvedBy = '',
  }) async {
    if (projectId.isEmpty) {
      throw ArgumentError('projectId must not be empty');
    }

    try {
      final existing = await _versionsCol(projectId).get();
      final versionNumber = existing.size + 1;

      // Mark all prior baselines as non-current (only the latest is
      // "current" by default — older versions remain queryable).
      final batch = _firestore.batch();
      for (final doc in existing.docs) {
        if (doc.data()['isCurrent'] == true) {
          batch.update(doc.reference, {'isCurrent': false});
        }
      }
      await batch.commit();

      final scheduleJson = _scheduleToJson(schedule);
      final milestones = schedule.activities
          .where((a) => a.type == ActivityType.milestone)
          .toList();
      final critical = schedule.activities
          .where((a) => a.isCriticalPath)
          .toList();

      final docRef = await _versionsCol(projectId).add({
        'projectId': projectId,
        'versionNumber': versionNumber,
        'label': label.isEmpty ? 'Schedule Baseline v$versionNumber' : label,
        'description': description,
        'author': author,
        'approvedBy': approvedBy,
        'triggerSource': triggerSource,
        'scheduleStatus': schedule.status.name,
        'isLocked': schedule.isLocked,
        'scheduleJson': scheduleJson,
        'activityCount': schedule.activities.length,
        'milestoneCount': milestones.length,
        'criticalPathCount': critical.length,
        'isCurrent': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e, st) {
      debugPrint('ScheduleBaselineService.captureSnapshot failed: $e\n$st');
      rethrow;
    }
  }

  /// Stream all baseline versions for a project, newest first.
  static Stream<List<Map<String, dynamic>>> streamVersions(
      String projectId) {
    try {
      return _versionsCol(projectId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map((d) {
                final data = d.data();
                data['id'] = d.id;
                return data;
              }).toList());
    } catch (e) {
      debugPrint('ScheduleBaselineService.streamVersions failed: $e');
      return Stream.value([]);
    }
  }

  /// Fetch the current (most recently captured) baseline version.
  static Future<Map<String, dynamic>?> fetchCurrent(String projectId) async {
    try {
      final snap = await _versionsCol(projectId)
          .where('isCurrent', isEqualTo: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final data = snap.docs.first.data();
      data['id'] = snap.docs.first.id;
      return data;
    } catch (e) {
      debugPrint('ScheduleBaselineService.fetchCurrent failed: $e');
      return null;
    }
  }

  /// Restore a prior baseline version's schedule JSON. Caller is
  /// responsible for feeding the returned [Schedule] back into the
  /// [ScheduleProvider] (e.g. `provider.replaceSchedule(restored)`).
  static Future<Schedule?> restoreVersion(
    String projectId,
    String versionId,
  ) async {
    try {
      final doc = await _versionsCol(projectId).doc(versionId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      final json = data['scheduleJson'] as Map<String, dynamic>?;
      if (json == null) return null;
      return _scheduleFromJson(json);
    } catch (e) {
      debugPrint('ScheduleBaselineService.restoreVersion failed: $e');
      return null;
    }
  }

  // ─── Schedule JSON serialization ────────────────────────────────────
  // We intentionally serialize only the fields needed to reconstruct the
  // activity tree + basis for EVM/CPM re-computation. Provenance fields
  // (aiGenerated, importSource) are preserved so the source of each
  // activity remains traceable after a restore.

  static Map<String, dynamic> _scheduleToJson(Schedule s) => {
        'id': s.id,
        'projectId': s.projectId,
        'projectName': s.projectName,
        'basis': _basisToJson(s.basis),
        'activities': s.activities.map(_activityToJson).toList(),
        'status': s.status.name,
        'isLocked': s.isLocked,
        'createdAt': s.createdAt.toIso8601String(),
        'updatedAt': s.updatedAt.toIso8601String(),
      };

  static Schedule _scheduleFromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      projectName: json['projectName'] as String? ?? '',
      basis: json['basis'] != null
          ? _basisFromJson(json['basis'] as Map<String, dynamic>)
          : const ScheduleBasis(
              deliveryModel: 'WATERFALL',
              assumptions: [],
              constraints: [],
              milestones: [],
              interfaces: [],
            ),
      activities: (json['activities'] as List<dynamic>? ?? [])
          .map((a) => _activityFromJson(a as Map<String, dynamic>))
          .toList(),
      status: ScheduleStatus.values
          .byName(json['status'] as String? ?? 'draft'),
      isLocked: json['isLocked'] as bool? ?? false,
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static Map<String, dynamic> _activityToJson(ScheduleActivity a) => {
        'id': a.id,
        'level': a.level,
        'code': a.code,
        'name': a.name,
        if (a.description != null) 'description': a.description,
        'type': a.type.name,
        'domain': a.domain.name,
        if (a.wbsNodeId != null) 'wbsNodeId': a.wbsNodeId,
        if (a.wbsCode != null) 'wbsCode': a.wbsCode,
        if (a.controlAccountId != null) 'controlAccountId': a.controlAccountId,
        'duration': a.duration,
        if (a.durationUnit != null) 'durationUnit': a.durationUnit,
        if (a.startDate != null)
          'startDate': a.startDate!.toIso8601String(),
        if (a.endDate != null) 'endDate': a.endDate!.toIso8601String(),
        if (a.progress != null) 'progress': a.progress,
        if (a.status != null) 'status': a.status,
        if (a.isCriticalPath) 'isCriticalPath': true,
        if (a.isLongLead) 'isLongLead': true,
        'aiGenerated': a.aiGenerated,
        if (a.importSource != null) 'importSource': a.importSource,
      };

  static ScheduleActivity _activityFromJson(Map<String, dynamic> json) {
    return ScheduleActivity(
      id: json['id'] as String? ?? '',
      level: json['level'] as int? ?? 1,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      type: ActivityType.values
          .byName(json['type'] as String? ?? 'activity'),
      domain: ScheduleDomain.values
          .byName(json['domain'] as String? ?? 'execution'),
      wbsNodeId: json['wbsNodeId'] as String?,
      wbsCode: json['wbsCode'] as String?,
      controlAccountId: json['controlAccountId'] as String?,
      duration: (json['duration'] as num?)?.toDouble(),
      durationUnit: json['durationUnit'] as String?,
      startDate: json['startDate'] is String
          ? DateTime.tryParse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] is String
          ? DateTime.tryParse(json['endDate'] as String)
          : null,
      progress: (json['progress'] as num?)?.toDouble(),
      status: json['status'] as String?,
      isCriticalPath: json['isCriticalPath'] as bool? ?? false,
      isLongLead: json['isLongLead'] as bool? ?? false,
      aiGenerated: json['aiGenerated'] as bool? ?? false,
      importSource: json['importSource'] as String?,
      dependencies: const [],
      children: const [],
    );
  }

  static Map<String, dynamic> _basisToJson(ScheduleBasis b) => {
        'deliveryModel': b.deliveryModel,
        if (b.sprintDurationWeeks != null)
          'sprintDurationWeeks': b.sprintDurationWeeks,
        if (b.releaseCadence != null) 'releaseCadence': b.releaseCadence,
        if (b.definitionOfReady != null)
          'definitionOfReady': b.definitionOfReady,
        if (b.definitionOfDone != null)
          'definitionOfDone': b.definitionOfDone,
        'assumptions': b.assumptions,
        'constraints': b.constraints,
      };

  static ScheduleBasis _basisFromJson(Map<String, dynamic> json) {
    return ScheduleBasis(
      deliveryModel: json['deliveryModel'] as String? ?? 'WATERFALL',
      sprintDurationWeeks:
          (json['sprintDurationWeeks'] as num?)?.toInt(),
      releaseCadence: json['releaseCadence'] as String?,
      definitionOfReady: json['definitionOfReady'] as String?,
      definitionOfDone: json['definitionOfDone'] as String?,
      assumptions: (json['assumptions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      constraints: (json['constraints'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      milestones: const [],
      interfaces: const [],
    );
  }
}
