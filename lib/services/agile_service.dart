import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Legacy parallel agile story model.
///
/// Prefer `AgileTask` persisted via `ExecutionPhaseService` for canonical
/// backlog/execution/schedule integration. This service is retained only for
/// backward compatibility with any older flows that still read `agile_stories`.
class AgileStoryModel {
  final String id;
  final String projectId;
  final String title;
  final String owner;
  final String points;
  final String notes;
  final String status; // 'planned', 'inProgress', 'readyToDemo'
  final String createdById;
  final String createdByEmail;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AgileStoryModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.owner,
    required this.points,
    required this.notes,
    required this.status,
    required this.createdById,
    required this.createdByEmail,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'title': title,
        'owner': owner,
        'points': points,
        'notes': notes,
        'status': status,
        'createdById': createdById,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static AgileStoryModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return AgileStoryModel(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      owner: (data['owner'] ?? '').toString(),
      points: (data['points'] ?? '').toString(),
      notes: (data['notes'] ?? '').toString(),
      status: (data['status'] ?? 'planned').toString(),
      createdById: (data['createdById'] ?? '').toString(),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }
}

/// Legacy agile story service.
///
/// New work should use `AgileTask` + `ExecutionPhaseService` instead of this
/// parallel `agile_stories` store to avoid divergence from Kanban, backlog,
/// release, sprint, and schedule flows.
class AgileService {
  static CollectionReference<Map<String, dynamic>> _storiesCol(
          String projectId) =>
      FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('agile_stories');

  static Future<String> createStory({
    required String projectId,
    required String title,
    required String owner,
    required String points,
    required String notes,
    required String status,
    String? createdById,
    String? createdByEmail,
    String? createdByName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';
    final userEmail = createdByEmail ?? user?.email ?? '';
    final userName =
        createdByName ?? user?.displayName ?? userEmail.split('@').first;

    final payload = AgileStoryModel(
      id: '',
      projectId: projectId,
      title: title,
      owner: owner,
      points: points,
      notes: notes,
      status: status,
      createdById: userId,
      createdByEmail: userEmail,
      createdByName: userName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _storiesCol(projectId).add(payload);
    return ref.id;
  }

  static Future<void> updateStory({
    required String projectId,
    required String storyId,
    String? title,
    String? owner,
    String? points,
    String? notes,
    String? status,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (title != null) updateData['title'] = title;
    if (owner != null) updateData['owner'] = owner;
    if (points != null) updateData['points'] = points;
    if (notes != null) updateData['notes'] = notes;
    if (status != null) updateData['status'] = status;

    await _storiesCol(projectId).doc(storyId).update(updateData);
  }

  static Future<void> deleteStory({
    required String projectId,
    required String storyId,
  }) async {
    await _storiesCol(projectId).doc(storyId).delete();
  }

  static Stream<List<AgileStoryModel>> streamStories(String projectId,
      {String? status, int limit = 50}) {
    Query<Map<String, dynamic>> query = _storiesCol(projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .snapshots()
        .map((snap) => snap.docs.map(AgileStoryModel.fromDoc).toList());
  }
}
