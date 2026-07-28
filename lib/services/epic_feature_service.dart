import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/services/agile_cache_service.dart';

class EpicFeatureService {
  static final _firestore = FirebaseFirestore.instance;

  static String _epicsCacheKey(String projectId) => 'epics:$projectId';
  static String _featuresCacheKey(String projectId, String epicId) =>
      'features:$projectId:$epicId';

  static CollectionReference<Map<String, dynamic>> _epicsCol(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('planning_phase_entries')
        .doc('agile_epics')
        .collection('epics');
  }

  static CollectionReference<Map<String, dynamic>> _featuresCol(
      String projectId, String epicId) {
    return _epicsCol(projectId).doc(epicId).collection('features');
  }

  // ── Epics ──

  static Future<List<Epic>> loadEpics(String projectId) async {
    try {
      return await AgileCacheService.instance.fetch(_epicsCacheKey(projectId),
          () async {
        final snapshot = await _epicsCol(projectId).orderBy('title').get();
        return snapshot.docs
            .map((doc) => Epic.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
      });
    } catch (error) {
      debugPrint('EpicFeatureService.loadEpics error: $error');
      return [];
    }
  }

  static Stream<List<Epic>> streamEpics(String projectId) {
    return _epicsCol(projectId).orderBy('title').snapshots().map((snap) => snap
        .docs
        .map((doc) => Epic.fromJson({...doc.data(), 'id': doc.id}))
        .toList());
  }

  static Future<List<Feature>> loadAllFeatures(String projectId) async {
    try {
      final epics = await loadEpics(projectId);
      final results = await Future.wait(
        epics.map((e) => loadFeatures(projectId, e.id)),
      );
      return results.expand((f) => f).toList();
    } catch (error) {
      debugPrint('EpicFeatureService.loadAllFeatures error: $error');
      return [];
    }
  }

  static Future<void> assignFeatureToSprint({
    required String projectId,
    required Feature feature,
    required String? sprintId,
  }) async {
    try {
      feature.sprintId = sprintId;
      await _featuresCol(projectId, feature.epicId)
          .doc(feature.id)
          .update({'sprintId': sprintId});
      AgileCacheService.instance
          .invalidate(_featuresCacheKey(projectId, feature.epicId));
    } catch (error) {
      debugPrint('EpicFeatureService.assignFeatureToSprint error: $error');
      rethrow;
    }
  }

  static Future<void> saveEpic({
    required String projectId,
    required Epic epic,
  }) async {
    try {
      await _epicsCol(projectId).doc(epic.id).set(epic.toJson());
      AgileCacheService.instance.invalidate(_epicsCacheKey(projectId));
    } catch (error) {
      debugPrint('EpicFeatureService.saveEpic error: $error');
      rethrow;
    }
  }

  static Future<void> deleteEpic({
    required String projectId,
    required String epicId,
  }) async {
    try {
      await _epicsCol(projectId).doc(epicId).delete();
      AgileCacheService.instance.invalidate(_epicsCacheKey(projectId));
    } catch (error) {
      debugPrint('EpicFeatureService.deleteEpic error: $error');
      rethrow;
    }
  }

  // ── Features ──

  /// Load features for a specific epic.
  static Future<List<Feature>> loadFeatures(
      String projectId, String epicId) async {
    try {
      return await AgileCacheService.instance
          .fetch(_featuresCacheKey(projectId, epicId), () async {
        final snapshot =
            await _featuresCol(projectId, epicId).orderBy('title').get();
        return snapshot.docs
            .map((doc) => Feature.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
      });
    } catch (error) {
      debugPrint('EpicFeatureService.loadFeatures error: $error');
      return [];
    }
  }

  static Future<void> saveFeature({
    required String projectId,
    required String epicId,
    required Feature feature,
  }) async {
    try {
      await _featuresCol(projectId, epicId)
          .doc(feature.id)
          .set(feature.toJson());
      AgileCacheService.instance
          .invalidate(_featuresCacheKey(projectId, epicId));
    } catch (error) {
      debugPrint('EpicFeatureService.saveFeature error: $error');
      rethrow;
    }
  }

  static Future<void> deleteFeature({
    required String projectId,
    required String epicId,
    required String featureId,
  }) async {
    try {
      await _featuresCol(projectId, epicId).doc(featureId).delete();
      AgileCacheService.instance
          .invalidate(_featuresCacheKey(projectId, epicId));
    } catch (error) {
      debugPrint('EpicFeatureService.deleteFeature error: $error');
      rethrow;
    }
  }
}
