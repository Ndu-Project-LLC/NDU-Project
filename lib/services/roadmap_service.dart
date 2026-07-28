import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/roadmap_deliverable.dart';
import 'package:ndu_project/models/roadmap_sprint.dart';

class RoadmapService {
  static final _firestore = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _roadmapDoc(
          String projectId) =>
      _firestore
          .collection('projects')
          .doc(projectId)
          .collection('planning_phase_entries')
          .doc('deliverables_roadmap');

  // ── Sprints ────────────────────────────────────────────────

  static Future<void> saveSprints({
    required String projectId,
    required List<RoadmapSprint> sprints,
    String? userId,
  }) async {
    try {
      await _roadmapDoc(projectId).set({
        'sprints': sprints.map((s) => s.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('RoadmapService.saveSprints error: $e');
      rethrow;
    }
  }

  static Future<List<RoadmapSprint>> loadSprints({
    required String projectId,
  }) async {
    try {
      final doc = await _roadmapDoc(projectId).get();
      if (!doc.exists) return [];
      final data = doc.data() ?? {};
      final raw = data['sprints'];
      if (raw is List) {
        final sprints = raw
            .map((s) {
              try {
                return RoadmapSprint.fromJson(Map<String, dynamic>.from(s));
              } catch (e) {
                debugPrint('Error parsing RoadmapSprint: $e');
                return null;
              }
            })
            .whereType<RoadmapSprint>()
            .toList();
        sprints.sort((a, b) => a.order.compareTo(b.order));
        return sprints;
      }
      return [];
    } catch (e) {
      debugPrint('RoadmapService.loadSprints error: $e');
      return [];
    }
  }

  // ── Deliverables ───────────────────────────────────────────

  static Future<void> saveDeliverables({
    required String projectId,
    required List<RoadmapDeliverable> deliverables,
    String? userId,
  }) async {
    try {
      await _roadmapDoc(projectId).set({
        'deliverables': deliverables.map((d) => d.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('RoadmapService.saveDeliverables error: $e');
      rethrow;
    }
  }

  static Future<List<RoadmapDeliverable>> loadDeliverables({
    required String projectId,
  }) async {
    try {
      final doc = await _roadmapDoc(projectId).get();
      if (!doc.exists) return [];
      final data = doc.data() ?? {};
      final raw = data['deliverables'];
      if (raw is List) {
        final items = raw
            .map((d) {
              try {
                return RoadmapDeliverable.fromJson(
                    Map<String, dynamic>.from(d));
              } catch (e) {
                debugPrint('Error parsing RoadmapDeliverable: $e');
                return null;
              }
            })
            .whereType<RoadmapDeliverable>()
            .toList();
        items.sort((a, b) => a.order.compareTo(b.order));
        return items;
      }
      return [];
    } catch (e) {
      debugPrint('RoadmapService.loadDeliverables error: $e');
      return [];
    }
  }

  // ── Save both in one write ─────────────────────────────────

  static Future<void> saveAll({
    required String projectId,
    required List<RoadmapSprint> sprints,
    required List<RoadmapDeliverable> deliverables,
    String? userId,
  }) async {
    try {
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      await _roadmapDoc(projectId).set({
        'sprints': sprints.map((s) => s.toJson()).toList(),
        'deliverables': deliverables.map((d) => d.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('RoadmapService.saveAll error: $e');
      rethrow;
    }
  }

  static Future<
      ({
        List<RoadmapSprint> sprints,
        List<RoadmapDeliverable> deliverables
      })> loadAll({
    required String projectId,
  }) async {
    try {
      final doc = await _roadmapDoc(projectId).get();
      if (!doc.exists) {
        return (
          sprints: <RoadmapSprint>[],
          deliverables: <RoadmapDeliverable>[]
        );
      }

      final data = doc.data() ?? {};

      List<RoadmapSprint> parseSprints(dynamic raw) {
        if (raw is! List) return <RoadmapSprint>[];
        final items = raw
            .map((s) {
              try {
                return RoadmapSprint.fromJson(Map<String, dynamic>.from(s));
              } catch (_) {
                return null;
              }
            })
            .whereType<RoadmapSprint>()
            .toList();
        items.sort((a, b) => a.order.compareTo(b.order));
        return items;
      }

      List<RoadmapDeliverable> parseDeliverables(dynamic raw) {
        if (raw is! List) return <RoadmapDeliverable>[];
        final items = raw
            .map((d) {
              try {
                return RoadmapDeliverable.fromJson(
                    Map<String, dynamic>.from(d));
              } catch (_) {
                return null;
              }
            })
            .whereType<RoadmapDeliverable>()
            .toList();
        items.sort((a, b) => a.order.compareTo(b.order));
        return items;
      }

      return (
        sprints: parseSprints(data['sprints']),
        deliverables: parseDeliverables(data['deliverables']),
      );
    } catch (e) {
      debugPrint('RoadmapService.loadAll error: $e');
      return (sprints: <RoadmapSprint>[], deliverables: <RoadmapDeliverable>[]);
    }
  }
}
