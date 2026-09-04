import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';

class WbsFirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static DocumentReference _docRef(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('wbs')
        .doc('main');
  }

  static Map<String, dynamic> _wbsToFirestore(WBS wbs) => {
        'projectId': wbs.projectId,
        'projectName': wbs.projectName,
        'framework': wbs.framework.name,
        if (wbs.methodology != ProjectMethodology.waterfall)
          'methodology': wbs.methodology.name,
        'level0': _nodeToFirestore(wbs.level0),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static Map<String, dynamic> _nodeToFirestore(WBSNode node) => {
        'id': node.id,
        'level': node.level.name,
        'code': node.code,
        'name': node.name,
        if (node.description != null) 'description': node.description,
        if (node.estimationMethod != null)
          'estimationMethod': node.estimationMethod!.name,
        if (node.isWorkPackage != null) 'isWorkPackage': node.isWorkPackage,
        if (node.aiGenerated) 'aiGenerated': true,
        if (node.aiSource != null) 'aiSource': node.aiSource!.name,
        if (node.aiConfidence != null) 'aiConfidence': node.aiConfidence!.name,
        if (node.methodology != null) 'methodology': node.methodology,
        if (node.costLineIds != null && node.costLineIds!.isNotEmpty)
          'costLineIds': node.costLineIds,
        // Cross-section linkage (WBS ↔ PC ↔ Schedule) — previously dropped
        // on Firestore round-trip; restored here so the integrated PMB
        // survives load/save cycles. See Phase 0 of the integration plan.
        if (node.controlAccountId != null &&
            node.controlAccountId!.isNotEmpty)
          'controlAccountId': node.controlAccountId,
        if (node.scheduleActivityId != null &&
            node.scheduleActivityId!.isNotEmpty)
          'scheduleActivityId': node.scheduleActivityId,
        if (node.percentComplete != null)
          'percentComplete': node.percentComplete,
        if (node.actualCost != null) 'actualCost': node.actualCost,
        if (node.plannedStart != null)
          'plannedStart': node.plannedStart!.toIso8601String(),
        if (node.plannedFinish != null)
          'plannedFinish': node.plannedFinish!.toIso8601String(),
        if (node.scheduleStatus != null && node.scheduleStatus!.isNotEmpty)
          'scheduleStatus': node.scheduleStatus,
        // WBS Dictionary fields (Phase 1) — the per-work-package scope
        // statement / acceptance criteria / work-package definition.
        if (node.deliverableDescription != null &&
            node.deliverableDescription!.isNotEmpty)
          'deliverableDescription': node.deliverableDescription,
        if (node.acceptanceCriteria != null &&
            node.acceptanceCriteria!.isNotEmpty)
          'acceptanceCriteria': node.acceptanceCriteria,
        if (node.workPackageDefinition != null &&
            node.workPackageDefinition!.isNotEmpty)
          'workPackageDefinition': node.workPackageDefinition,
        'children': node.children.map(_nodeToFirestore).toList(),
      };

  static WBS _wbsFromFirestore(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return WBS(
      id: json['id']?.toString() ?? 'wbs_main',
      projectId: json['projectId']?.toString() ?? '',
      projectName: json['projectName']?.toString() ?? '',
      framework: WBSFramework.values
          .byName(json['framework']?.toString() ?? 'waterfallDeliverable'),
      methodology: json['methodology'] != null
          ? ProjectMethodology.values.byName(json['methodology'] as String)
          : ProjectMethodology.waterfall,
      level0: _nodeFromFirestore(json['level0'] as Map<String, dynamic>),
      aiSuggestions: [],
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(json['updatedAt']) ?? DateTime.now(),
    );
  }

  static WBSNode _nodeFromFirestore(Map<String, dynamic> json) {
    return WBSNode(
      id: json['id'] as String? ?? '',
      level: WBSLevel.values.byName(json['level'] as String? ?? 'level0'),
      code: json['code'] as String? ?? '0',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      estimationMethod: json['estimationMethod'] != null
          ? EstimationMethod.values.byName(json['estimationMethod'] as String)
          : null,
      isWorkPackage: json['isWorkPackage'] as bool?,
      aiGenerated: json['aiGenerated'] as bool? ?? false,
      aiSource: json['aiSource'] != null
          ? AISource.values.byName(json['aiSource'] as String)
          : null,
      aiConfidence: json['aiConfidence'] != null
          ? AIConfidence.values.byName(json['aiConfidence'] as String)
          : null,
      methodology: json['methodology'] as String?,
      costLineIds: json['costLineIds'] != null
          ? (json['costLineIds'] as List<dynamic>).cast<String>()
          : null,
      // Cross-section linkage (WBS ↔ PC ↔ Schedule) — restored on load.
      controlAccountId: json['controlAccountId'] as String?,
      scheduleActivityId: json['scheduleActivityId'] as String?,
      percentComplete: (json['percentComplete'] as num?)?.toDouble(),
      actualCost: (json['actualCost'] as num?)?.toDouble(),
      plannedStart: json['plannedStart'] is Timestamp
          ? (json['plannedStart'] as Timestamp).toDate()
          : (json['plannedStart'] is String
              ? DateTime.tryParse(json['plannedStart'] as String)
              : null),
      plannedFinish: json['plannedFinish'] is Timestamp
          ? (json['plannedFinish'] as Timestamp).toDate()
          : (json['plannedFinish'] is String
              ? DateTime.tryParse(json['plannedFinish'] as String)
              : null),
      scheduleStatus: json['scheduleStatus'] as String?,
      // WBS Dictionary fields (Phase 1)
      deliverableDescription: json['deliverableDescription'] as String?,
      acceptanceCriteria: json['acceptanceCriteria'] != null
          ? (json['acceptanceCriteria'] as List<dynamic>).cast<String>()
          : null,
      workPackageDefinition: json['workPackageDefinition'] as String?,
      children: (json['children'] as List<dynamic>? ?? [])
          .map((c) => _nodeFromFirestore(c as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<void> saveWBS(String projectId, WBS wbs) async {
    if (projectId.isEmpty) return;
    try {
      final data = _wbsToFirestore(wbs);
      await _docRef(projectId).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving WBS to Firestore: $e');
    }
  }

  static Future<WBS?> loadWBS(String projectId) async {
    if (projectId.isEmpty) return null;
    try {
      final doc = await _docRef(projectId).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      return _wbsFromFirestore(data);
    } catch (e) {
      debugPrint('Error loading WBS from Firestore: $e');
      return null;
    }
  }

  static Future<void> deleteWBS(String projectId) async {
    if (projectId.isEmpty) return;
    try {
      await _docRef(projectId).delete();
    } catch (e) {
      debugPrint('Error deleting WBS from Firestore: $e');
    }
  }
}
