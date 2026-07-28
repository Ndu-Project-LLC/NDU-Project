import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/agile_project_baseline.dart';

class AgileProjectBaselineService {
  static final _firestore = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _doc(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('planning_phase_entries')
        .doc('agile_project_baseline');
  }

  static Future<AgileProjectBaseline> load(String projectId) async {
    try {
      final snapshot = await _doc(projectId).get();
      if (!snapshot.exists) return AgileProjectBaseline();
      final data = snapshot.data() ?? <String, dynamic>{};
      return AgileProjectBaseline.fromJson(data);
    } catch (error) {
      debugPrint('AgileProjectBaselineService.load error: $error');
      return AgileProjectBaseline();
    }
  }

  static Future<void> save({
    required String projectId,
    required AgileProjectBaseline baseline,
    required String updatedBy,
  }) async {
    try {
      await _doc(projectId).set({
        ...baseline.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('AgileProjectBaselineService.save error: $error');
      rethrow;
    }
  }
}
