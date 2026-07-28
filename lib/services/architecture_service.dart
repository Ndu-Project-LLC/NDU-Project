import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for persisting the Design > Architecture workspace for a project.
/// Stores Output Documents, nodes and edges under:
///   projects/{projectId}/design/architecture
class ArchitectureService {
  static DocumentReference<Map<String, dynamic>> _doc(String projectId) =>
      FirebaseFirestore.instance.collection('projects').doc(projectId).collection('design').doc('architecture');

  /// Load architecture state. Returns null if not found.
  static Future<Map<String, dynamic>?> load(String projectId) async {
    try {
      final doc = await _doc(projectId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e, st) {
      debugPrint('❌ ArchitectureService.load error: $e\n$st');
      return null;
    }
  }

  /// Save architecture state. Uses set(merge: true) so partial updates are ok.
  static Future<void> save(String projectId, Map<String, dynamic> data) async {
    try {
      await _doc(projectId).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('❌ ArchitectureService.save error: $e\n$st');
      rethrow;
    }
  }
}
