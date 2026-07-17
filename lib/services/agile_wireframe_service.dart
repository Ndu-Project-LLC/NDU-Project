import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/acceptance_criteria.dart';
import 'package:ndu_project/models/agile_release_plan.dart';
import 'package:ndu_project/services/agile_cache_service.dart';

class AgileWireframeService {
  static final _firestore = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _agileDoc(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('planning_phase_entries')
        .doc('agile_wireframe');
  }

  static String _cacheKey(String projectId) => 'agile_wireframe:$projectId';
  static String _releasesCacheKey(String projectId) =>
      'agile_wireframe:releases:$projectId';

  static Future<Map<String, dynamic>?> _loadDoc(String projectId) async {
    return AgileCacheService.instance.fetch(_cacheKey(projectId), () async {
      final snapshot = await _agileDoc(projectId).get();
      return snapshot.exists ? snapshot.data() : null;
    });
  }

  static void _invalidate(String projectId) {
    AgileCacheService.instance.invalidate(_cacheKey(projectId));
  }

  // ── Agile Team Structure ──

  static Future<Map<String, dynamic>> loadTeamStructure(
      String projectId) async {
    try {
      final doc = await _loadDoc(projectId);
      if (doc == null) return {};
      return (doc['teamStructure'] as Map<String, dynamic>?) ?? {};
    } catch (error) {
      debugPrint('AgileWireframeService.loadTeamStructure error: $error');
      return {};
    }
  }

  static Future<void> saveTeamStructure({
    required String projectId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _agileDoc(projectId).set({
        'teamStructure': data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _invalidate(projectId);
    } catch (error) {
      debugPrint('AgileWireframeService.saveTeamStructure error: $error');
      rethrow;
    }
  }

  // ── Delivery Model ──

  static Future<Map<String, dynamic>> loadDeliveryModel(
      String projectId) async {
    try {
      final doc = await _loadDoc(projectId);
      if (doc == null) return {};
      return (doc['deliveryModel'] as Map<String, dynamic>?) ?? {};
    } catch (error) {
      debugPrint('AgileWireframeService.loadDeliveryModel error: $error');
      return {};
    }
  }

  static Future<void> saveDeliveryModel({
    required String projectId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _agileDoc(projectId).set({
        'deliveryModel': data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _invalidate(projectId);
    } catch (error) {
      debugPrint('AgileWireframeService.saveDeliveryModel error: $error');
      rethrow;
    }
  }

  // ── Sprint Calendar ──

  static Future<Map<String, dynamic>> loadSprintCalendar(
      String projectId) async {
    try {
      final doc = await _loadDoc(projectId);
      if (doc == null) return {};
      return (doc['sprintCalendar'] as Map<String, dynamic>?) ?? {};
    } catch (error) {
      debugPrint('AgileWireframeService.loadSprintCalendar error: $error');
      return {};
    }
  }

  static Future<void> saveSprintCalendar({
    required String projectId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _agileDoc(projectId).set({
        'sprintCalendar': data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _invalidate(projectId);
    } catch (error) {
      debugPrint('AgileWireframeService.saveSprintCalendar error: $error');
      rethrow;
    }
  }

  // ── Backlog Governance ──

  static Future<Map<String, dynamic>> loadBacklogGovernance(
      String projectId) async {
    try {
      final doc = await _loadDoc(projectId);
      if (doc == null) return {};
      return (doc['backlogGovernance'] as Map<String, dynamic>?) ?? {};
    } catch (error) {
      debugPrint('AgileWireframeService.loadBacklogGovernance error: $error');
      return {};
    }
  }

  static Future<void> saveBacklogGovernance({
    required String projectId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _agileDoc(projectId).set({
        'backlogGovernance': data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _invalidate(projectId);
    } catch (error) {
      debugPrint('AgileWireframeService.saveBacklogGovernance error: $error');
      rethrow;
    }
  }

  // ── Release Plans ──

  static CollectionReference<Map<String, dynamic>> _releasesCol(
      String projectId) {
    return _agileDoc(projectId).collection('releases');
  }

  static Future<List<AgileReleasePlan>> loadReleasePlans(
      String projectId) async {
    try {
      return await AgileCacheService.instance
          .fetch(_releasesCacheKey(projectId), () async {
        final snapshot =
            await _releasesCol(projectId).orderBy('releaseLabel').get();
        return snapshot.docs
            .map((doc) =>
                AgileReleasePlan.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
      });
    } catch (error) {
      debugPrint('AgileWireframeService.loadReleasePlans error: $error');
      return [];
    }
  }

  static Future<void> saveReleasePlan({
    required String projectId,
    required AgileReleasePlan plan,
  }) async {
    try {
      await _releasesCol(projectId).doc(plan.id).set(plan.toJson());
      AgileCacheService.instance.invalidate(_releasesCacheKey(projectId));
    } catch (error) {
      debugPrint('AgileWireframeService.saveReleasePlan error: $error');
      rethrow;
    }
  }

  static Future<void> deleteReleasePlan({
    required String projectId,
    required String planId,
  }) async {
    try {
      await _releasesCol(projectId).doc(planId).delete();
      AgileCacheService.instance.invalidate(_releasesCacheKey(projectId));
    } catch (error) {
      debugPrint('AgileWireframeService.deleteReleasePlan error: $error');
      rethrow;
    }
  }

  // ── Acceptance Criteria ──

  static Future<AcceptanceCriteriaConfig> loadAcceptanceCriteria(
      String projectId) async {
    try {
      final doc = await _loadDoc(projectId);
      if (doc == null) return AcceptanceCriteriaConfig();
      final data = doc['acceptanceCriteria'] as Map<String, dynamic>?;
      if (data == null) return AcceptanceCriteriaConfig();
      return AcceptanceCriteriaConfig.fromJson(data);
    } catch (error) {
      debugPrint('AgileWireframeService.loadAcceptanceCriteria error: $error');
      return AcceptanceCriteriaConfig();
    }
  }

  static Future<void> saveAcceptanceCriteria({
    required String projectId,
    required AcceptanceCriteriaConfig config,
  }) async {
    try {
      await _agileDoc(projectId).set({
        'acceptanceCriteria': config.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _invalidate(projectId);
    } catch (error) {
      debugPrint('AgileWireframeService.saveAcceptanceCriteria error: $error');
      rethrow;
    }
  }

  // ── Scrum Config ──

  static Future<Map<String, dynamic>> loadScrumConfig(String projectId) async {
    try {
      final doc = await _loadDoc(projectId);
      if (doc == null) return {};
      return (doc['scrumConfig'] as Map<String, dynamic>?) ?? {};
    } catch (error) {
      debugPrint('AgileWireframeService.loadScrumConfig error: $error');
      return {};
    }
  }

  static Future<void> saveScrumConfig({
    required String projectId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _agileDoc(projectId).set({
        'scrumConfig': data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _invalidate(projectId);
    } catch (error) {
      debugPrint('AgileWireframeService.saveScrumConfig error: $error');
      rethrow;
    }
  }

  // ── Capacity Planning ──

  static Future<Map<String, dynamic>> loadCapacityPlanning(
      String projectId) async {
    try {
      final doc = await _loadDoc(projectId);
      if (doc == null) return {};
      return (doc['capacityPlanning'] as Map<String, dynamic>?) ?? {};
    } catch (error) {
      debugPrint('AgileWireframeService.loadCapacityPlanning error: $error');
      return {};
    }
  }

  static Future<void> saveCapacityPlanning({
    required String projectId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _agileDoc(projectId).set({
        'capacityPlanning': data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _invalidate(projectId);
    } catch (error) {
      debugPrint('AgileWireframeService.saveCapacityPlanning error: $error');
      rethrow;
    }
  }

  // ── Metrics Config ──

  static Future<Map<String, dynamic>> loadMetricsConfig(
      String projectId) async {
    try {
      final doc = await _loadDoc(projectId);
      if (doc == null) return {};
      return (doc['metricsConfig'] as Map<String, dynamic>?) ?? {};
    } catch (error) {
      debugPrint('AgileWireframeService.loadMetricsConfig error: $error');
      return {};
    }
  }

  static Future<void> saveMetricsConfig({
    required String projectId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _agileDoc(projectId).set({
        'metricsConfig': data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _invalidate(projectId);
    } catch (error) {
      debugPrint('AgileWireframeService.saveMetricsConfig error: $error');
      rethrow;
    }
  }

  // ── Kanban Config ──

  static Future<Map<String, dynamic>> loadKanbanConfig(String projectId) async {
    try {
      final doc = await _loadDoc(projectId);
      if (doc == null) return {};
      return (doc['kanbanConfig'] as Map<String, dynamic>?) ?? {};
    } catch (error) {
      debugPrint('AgileWireframeService.loadKanbanConfig error: $error');
      return {};
    }
  }

  static Future<void> saveKanbanConfig({
    required String projectId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _agileDoc(projectId).set({
        'kanbanConfig': data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _invalidate(projectId);
    } catch (error) {
      debugPrint('AgileWireframeService.saveKanbanConfig error: $error');
      rethrow;
    }
  }
}
