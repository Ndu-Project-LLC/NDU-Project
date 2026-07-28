import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OpsMemberModel {
  final String id;
  final String projectId;
  final String name;
  final String role;
  final String responsibility;
  final String status; // Active, Pending, Inactive
  final int readinessScore; // 0-100
  final String? notes;
  final String createdById;
  final String createdByEmail;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OpsMemberModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.role,
    required this.responsibility,
    required this.status,
    required this.readinessScore,
    this.notes,
    required this.createdById,
    required this.createdByEmail,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'name': name,
        'role': role,
        'responsibility': responsibility,
        'status': status,
        'readinessScore': readinessScore,
        'notes': notes ?? '',
        'createdById': createdById,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static OpsMemberModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    int parseInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return OpsMemberModel(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      role: (data['role'] ?? '').toString(),
      responsibility: (data['responsibility'] ?? '').toString(),
      status: (data['status'] ?? 'Active').toString(),
      readinessScore: parseInt(data['readinessScore']),
      notes: data['notes']?.toString(),
      createdById: (data['createdById'] ?? '').toString(),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }
}

class OpsChecklistItemModel {
  final String id;
  final String projectId;
  final String item;
  final bool completed;
  final String? notes;
  final String createdById;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OpsChecklistItemModel({
    required this.id,
    required this.projectId,
    required this.item,
    required this.completed,
    this.notes,
    required this.createdById,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'item': item,
        'completed': completed,
        'notes': notes ?? '',
        'createdById': createdById,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static OpsChecklistItemModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return OpsChecklistItemModel(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      item: (data['item'] ?? '').toString(),
      completed: data['completed'] == true,
      notes: data['notes']?.toString(),
      createdById: (data['createdById'] ?? '').toString(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }
}

class OpsService {
  static CollectionReference<Map<String, dynamic>> _membersCol(String projectId) =>
      FirebaseFirestore.instance.collection('projects').doc(projectId).collection('ops_members');

  static CollectionReference<Map<String, dynamic>> _checklistCol(String projectId) =>
      FirebaseFirestore.instance.collection('projects').doc(projectId).collection('ops_checklist');

  // Ops Members CRUD
  static Future<String> createMember({
    required String projectId,
    required String name,
    required String role,
    required String responsibility,
    required String status,
    required int readinessScore,
    String? notes,
    String? createdById,
    String? createdByEmail,
    String? createdByName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';
    final userEmail = createdByEmail ?? user?.email ?? '';
    final userName = createdByName ?? user?.displayName ?? userEmail.split('@').first;

    final payload = OpsMemberModel(
      id: '',
      projectId: projectId,
      name: name,
      role: role,
      responsibility: responsibility,
      status: status,
      readinessScore: readinessScore,
      notes: notes,
      createdById: userId,
      createdByEmail: userEmail,
      createdByName: userName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _membersCol(projectId).add(payload);
    return ref.id;
  }

  static Future<void> updateMember({
    required String projectId,
    required String memberId,
    String? name,
    String? role,
    String? responsibility,
    String? status,
    int? readinessScore,
    String? notes,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updateData['name'] = name;
    if (role != null) updateData['role'] = role;
    if (responsibility != null) updateData['responsibility'] = responsibility;
    if (status != null) updateData['status'] = status;
    if (readinessScore != null) updateData['readinessScore'] = readinessScore;
    if (notes != null) updateData['notes'] = notes;

    await _membersCol(projectId).doc(memberId).update(updateData);
  }

  static Future<void> deleteMember({
    required String projectId,
    required String memberId,
  }) async {
    await _membersCol(projectId).doc(memberId).delete();
  }

  static Stream<List<OpsMemberModel>> streamMembers(String projectId, {int limit = 50}) {
    return _membersCol(projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(OpsMemberModel.fromDoc).toList());
  }

  // Ops Checklist CRUD
  static Future<String> createChecklistItem({
    required String projectId,
    required String item,
    required bool completed,
    String? notes,
    String? createdById,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';

    final payload = OpsChecklistItemModel(
      id: '',
      projectId: projectId,
      item: item,
      completed: completed,
      notes: notes,
      createdById: userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _checklistCol(projectId).add(payload);
    return ref.id;
  }

  static Future<void> updateChecklistItem({
    required String projectId,
    required String itemId,
    String? item,
    bool? completed,
    String? notes,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (item != null) updateData['item'] = item;
    if (completed != null) updateData['completed'] = completed;
    if (notes != null) updateData['notes'] = notes;

    await _checklistCol(projectId).doc(itemId).update(updateData);
  }

  static Future<void> deleteChecklistItem({
    required String projectId,
    required String itemId,
  }) async {
    await _checklistCol(projectId).doc(itemId).delete();
  }

  static Stream<List<OpsChecklistItemModel>> streamChecklist(String projectId, {int limit = 50}) {
    return _checklistCol(projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(OpsChecklistItemModel.fromDoc).toList());
  }
}
