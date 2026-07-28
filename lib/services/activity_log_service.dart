import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';

class ActivityLogEntry {
  const ActivityLogEntry({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.phase,
    required this.page,
    required this.action,
    required this.details,
  });

  final String id;
  final DateTime? timestamp;
  final String userId;
  final String userName;
  final String userEmail;
  final String phase;
  final String page;
  final String action;
  final Map<String, dynamic> details;

  factory ActivityLogEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final timestampRaw = data['timestamp'];
    DateTime? timestamp;
    if (timestampRaw is Timestamp) {
      timestamp = timestampRaw.toDate();
    } else if (timestampRaw is String) {
      timestamp = DateTime.tryParse(timestampRaw);
    }

    return ActivityLogEntry(
      id: doc.id,
      timestamp: timestamp,
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? '').toString(),
      userEmail: (data['userEmail'] ?? '').toString(),
      phase: (data['phase'] ?? '').toString(),
      page: (data['page'] ?? '').toString(),
      action: (data['action'] ?? '').toString(),
      details: _normalizeDetails(data['details']),
    );
  }

  static Map<String, dynamic> _normalizeDetails(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(key.toString(), entry),
      );
    }
    return const <String, dynamic>{};
  }
}

class ActivityLogService {
  ActivityLogService._();

  static final ActivityLogService instance = ActivityLogService._();

  CollectionReference<Map<String, dynamic>> _collection(String projectId) {
    return FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('activityLog');
  }

  Stream<List<ActivityLogEntry>> watchActivityLog(
    String projectId, {
    int limit = 100,
  }) {
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty) {
      return Stream<List<ActivityLogEntry>>.value(const <ActivityLogEntry>[]);
    }

    return _collection(normalizedProjectId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots(includeMetadataChanges: false)
        .map(
          (snapshot) => snapshot.docs
              .map(ActivityLogEntry.fromDoc)
              .toList(growable: false),
        );
  }

  Future<void> logActivity({
    required String projectId,
    required String phase,
    required String page,
    required String action,
    Map<String, dynamic>? details,
  }) async {
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final normalizedDetails = <String, dynamic>{};
    (details ?? const <String, dynamic>{}).forEach((key, value) {
      if (value == null) return;
      if (value is num || value is bool || value is String) {
        normalizedDetails[key] = value;
      } else if (value is DateTime) {
        normalizedDetails[key] = value.toIso8601String();
      } else {
        normalizedDetails[key] = value.toString();
      }
    });

    try {
      await _collection(normalizedProjectId).add({
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'userName': (user.displayName ?? user.email ?? 'Unknown User').trim(),
        'userEmail': (user.email ?? '').trim(),
        'phase': phase.trim().isEmpty ? 'Unknown Phase' : phase.trim(),
        'page': page.trim().isEmpty ? 'Unknown Page' : page.trim(),
        'action': action.trim().isEmpty ? 'Updated data' : action.trim(),
        'details': normalizedDetails,
      });
    } catch (error, stackTrace) {
      debugPrint('Activity log write failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> logCheckpointActivity({
    required String projectId,
    required String checkpoint,
    required String action,
    Map<String, dynamic>? details,
  }) async {
    final item =
        SidebarNavigationService.instance.findItemByCheckpoint(checkpoint);
    final page = item?.label ?? checkpoint;
    final phase =
        SidebarNavigationService.phaseForCheckpoint(checkpoint) ?? 'Project';

    await logActivity(
      projectId: projectId,
      phase: phase,
      page: page,
      action: action,
      details: <String, dynamic>{
        'checkpoint': checkpoint,
        ...?details,
      },
    );
  }
}
