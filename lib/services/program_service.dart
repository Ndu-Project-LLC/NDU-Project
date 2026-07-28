import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/program_model.dart';

class ProgramService {
  static final CollectionReference<Map<String, dynamic>> _programsCol =
      FirebaseFirestore.instance.collection('programs');

  static Future<String> createProgram({
    required String name,
    required List<String> projectIds,
    required String ownerId,
  }) async {
    try {
      final docRef = await _programsCol.add({
        'name': name,
        'projectIds': projectIds,
        'ownerId': ownerId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'Active',
      });
      debugPrint('✅ Program created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating program: $e');
      rethrow;
    }
  }

  static Stream<List<ProgramModel>> streamPrograms({required String ownerId}) {
    return _programsCol
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final programs = <ProgramModel>[];
          for (final doc in snapshot.docs) {
            try {
              if (doc.exists) {
                programs.add(ProgramModel.fromFirestore(doc));
              }
            } catch (e) {
              debugPrint('⚠️ Error parsing program ${doc.id}: $e');
            }
          }
          return programs;
        });
  }

  static Future<ProgramModel?> getProgram(String programId) async {
    try {
      final doc = await _programsCol.doc(programId).get();
      if (!doc.exists) return null;
      return ProgramModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error fetching program: $e');
      return null;
    }
  }

  static Future<void> updateProgram(String programId, Map<String, dynamic> data) async {
    try {
      await _programsCol.doc(programId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Program updated: $programId');
    } catch (e) {
      debugPrint('❌ Error updating program: $e');
      rethrow;
    }
  }

  static Future<void> deleteProgram(String programId) async {
    try {
      await _programsCol.doc(programId).delete();
      debugPrint('✅ Program deleted: $programId');
    } catch (e) {
      debugPrint('❌ Error deleting program: $e');
      rethrow;
    }
  }

  static Future<int> getProgramCount({required String ownerId}) async {
    try {
      final snapshot = await _programsCol
          .where('ownerId', isEqualTo: ownerId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting program count: $e');
      return 0;
    }
  }
}
