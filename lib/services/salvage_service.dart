import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Model for salvage/disposal team members
class SalvageTeamMemberModel {
  final String id;
  final String projectId;
  final String name;
  final String role;
  final String email;
  final String status; // 'Active', 'On Leave', etc.
  final int itemsHandled;
  final String createdById;
  final String createdByEmail;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SalvageTeamMemberModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.role,
    required this.email,
    required this.status,
    required this.itemsHandled,
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
        'email': email,
        'status': status,
        'itemsHandled': itemsHandled,
        'createdById': createdById,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static SalvageTeamMemberModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return SalvageTeamMemberModel(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      role: (data['role'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      status: (data['status'] ?? 'Active').toString(),
      itemsHandled: (data['itemsHandled'] ?? 0) as int,
      createdById: (data['createdById'] ?? '').toString(),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }
}

/// Model for salvage inventory items
class SalvageInventoryItemModel {
  final String id;
  final String projectId;
  final String assetId;
  final String name;
  final String category;
  final String condition; // 'Excellent', 'Good', 'Fair', etc.
  final String location;
  final String status; // 'Ready', 'Pending', 'Review', 'Flagged'
  final String estimatedValue;
  final String createdById;
  final String createdByEmail;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SalvageInventoryItemModel({
    required this.id,
    required this.projectId,
    required this.assetId,
    required this.name,
    required this.category,
    required this.condition,
    required this.location,
    required this.status,
    required this.estimatedValue,
    required this.createdById,
    required this.createdByEmail,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'assetId': assetId,
        'name': name,
        'category': category,
        'condition': condition,
        'location': location,
        'status': status,
        'estimatedValue': estimatedValue,
        'createdById': createdById,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static SalvageInventoryItemModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return SalvageInventoryItemModel(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      assetId: (data['assetId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      condition: (data['condition'] ?? '').toString(),
      location: (data['location'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      estimatedValue: (data['estimatedValue'] ?? '').toString(),
      createdById: (data['createdById'] ?? '').toString(),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }
}

/// Model for disposal queue items — industry-standard fields per ITAD / ISO 14001 /
/// NIST SP 800-88 / government asset disposal best practices.
class SalvageDisposalItemModel {
  final String id;
  final String projectId;
  final String assetId;
  final String name;
  final String category;
  final String condition; // 'Excellent', 'Good', 'Fair', 'Poor', 'Non-Functional'
  final String location;
  final String disposalMethod; // 'Auction', 'Recycle', 'Donate', 'Scrap', 'Resell', 'Trade-In', 'Transfer'
  final String status; // 'Pending Review', 'Approved', 'In Progress', 'Pending Disposal', 'Completed', 'On Hold', 'Cancelled'
  final String estimatedValue;
  final String disposalCost;
  final String priority; // 'Critical', 'High', 'Medium', 'Low'
  final String assignedTo;
  final String targetDate;
  final String createdById;
  final String createdByEmail;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SalvageDisposalItemModel({
    required this.id,
    required this.projectId,
    required this.assetId,
    required this.name,
    required this.category,
    this.condition = '',
    this.location = '',
    this.disposalMethod = '',
    required this.status,
    required this.estimatedValue,
    this.disposalCost = '',
    required this.priority,
    this.assignedTo = '',
    this.targetDate = '',
    required this.createdById,
    required this.createdByEmail,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'assetId': assetId,
        'name': name,
        'category': category,
        'condition': condition,
        'location': location,
        'disposalMethod': disposalMethod,
        'status': status,
        'estimatedValue': estimatedValue,
        'disposalCost': disposalCost,
        'priority': priority,
        'assignedTo': assignedTo,
        'targetDate': targetDate,
        'createdById': createdById,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static SalvageDisposalItemModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return SalvageDisposalItemModel(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      assetId: (data['assetId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      condition: (data['condition'] ?? '').toString(),
      location: (data['location'] ?? '').toString(),
      disposalMethod: (data['disposalMethod'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      estimatedValue: (data['estimatedValue'] ?? '').toString(),
      disposalCost: (data['disposalCost'] ?? '').toString(),
      priority: (data['priority'] ?? 'Medium').toString(),
      assignedTo: (data['assignedTo'] ?? '').toString(),
      targetDate: (data['targetDate'] ?? '').toString(),
      createdById: (data['createdById'] ?? '').toString(),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }
}

/// Model for disposal timeline milestones — tracks key disposal project phases,
/// approvals, audits, and deliverables per project management best practices.
class SalvageTimelineItemModel {
  final String id;
  final String projectId;
  final String milestone;
  final String description;
  final String phase; // 'Planning', 'Execution', 'Review', 'Closure'
  final String status; // 'Not Started', 'In Progress', 'Completed', 'Overdue', 'On Hold'
  final String owner;
  final String startDate;
  final String dueDate;
  final String completedDate;
  final int progress; // 0-100
  final String priority; // 'Critical', 'High', 'Medium', 'Low'
  final String dependencies;
  final String notes;
  final String createdById;
  final String createdByEmail;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SalvageTimelineItemModel({
    required this.id,
    required this.projectId,
    required this.milestone,
    this.description = '',
    this.phase = 'Planning',
    this.status = 'Not Started',
    this.owner = '',
    this.startDate = '',
    this.dueDate = '',
    this.completedDate = '',
    this.progress = 0,
    this.priority = 'Medium',
    this.dependencies = '',
    this.notes = '',
    required this.createdById,
    required this.createdByEmail,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'milestone': milestone,
        'description': description,
        'phase': phase,
        'status': status,
        'owner': owner,
        'startDate': startDate,
        'dueDate': dueDate,
        'completedDate': completedDate,
        'progress': progress,
        'priority': priority,
        'dependencies': dependencies,
        'notes': notes,
        'createdById': createdById,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static SalvageTimelineItemModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return SalvageTimelineItemModel(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      milestone: (data['milestone'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      phase: (data['phase'] ?? 'Planning').toString(),
      status: (data['status'] ?? 'Not Started').toString(),
      owner: (data['owner'] ?? '').toString(),
      startDate: (data['startDate'] ?? '').toString(),
      dueDate: (data['dueDate'] ?? '').toString(),
      completedDate: (data['completedDate'] ?? '').toString(),
      progress: (data['progress'] is int) ? data['progress'] as int : int.tryParse(data['progress'].toString()) ?? 0,
      priority: (data['priority'] ?? 'Medium').toString(),
      dependencies: (data['dependencies'] ?? '').toString(),
      notes: (data['notes'] ?? '').toString(),
      createdById: (data['createdById'] ?? '').toString(),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }
}

class SalvageService {
  // Team Members CRUD
  static CollectionReference<Map<String, dynamic>> _teamMembersCol(String projectId) =>
      FirebaseFirestore.instance.collection('projects').doc(projectId).collection('salvage_team_members');

  static Future<String> createTeamMember({
    required String projectId,
    required String name,
    required String role,
    required String email,
    required String status,
    int itemsHandled = 0,
    String? createdById,
    String? createdByEmail,
    String? createdByName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';
    final userEmail = createdByEmail ?? user?.email ?? '';
    final userName = createdByName ?? user?.displayName ?? userEmail.split('@').first;

    final payload = SalvageTeamMemberModel(
      id: '',
      projectId: projectId,
      name: name,
      role: role,
      email: email,
      status: status,
      itemsHandled: itemsHandled,
      createdById: userId,
      createdByEmail: userEmail,
      createdByName: userName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _teamMembersCol(projectId).add(payload);
    return ref.id;
  }

  static Future<void> updateTeamMember({
    required String projectId,
    required String memberId,
    String? name,
    String? role,
    String? email,
    String? status,
    int? itemsHandled,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updateData['name'] = name;
    if (role != null) updateData['role'] = role;
    if (email != null) updateData['email'] = email;
    if (status != null) updateData['status'] = status;
    if (itemsHandled != null) updateData['itemsHandled'] = itemsHandled;

    await _teamMembersCol(projectId).doc(memberId).update(updateData);
  }

  static Future<void> deleteTeamMember({
    required String projectId,
    required String memberId,
  }) async {
    await _teamMembersCol(projectId).doc(memberId).delete();
  }

  static Stream<List<SalvageTeamMemberModel>> streamTeamMembers(String projectId, {int limit = 50}) {
    return _teamMembersCol(projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(SalvageTeamMemberModel.fromDoc).toList());
  }

  // Inventory Items CRUD
  static CollectionReference<Map<String, dynamic>> _inventoryCol(String projectId) =>
      FirebaseFirestore.instance.collection('projects').doc(projectId).collection('salvage_inventory');

  static Future<String> createInventoryItem({
    required String projectId,
    required String assetId,
    required String name,
    required String category,
    required String condition,
    required String location,
    required String status,
    required String estimatedValue,
    String? createdById,
    String? createdByEmail,
    String? createdByName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';
    final userEmail = createdByEmail ?? user?.email ?? '';
    final userName = createdByName ?? user?.displayName ?? userEmail.split('@').first;

    final payload = SalvageInventoryItemModel(
      id: '',
      projectId: projectId,
      assetId: assetId,
      name: name,
      category: category,
      condition: condition,
      location: location,
      status: status,
      estimatedValue: estimatedValue,
      createdById: userId,
      createdByEmail: userEmail,
      createdByName: userName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _inventoryCol(projectId).add(payload);
    return ref.id;
  }

  static Future<void> updateInventoryItem({
    required String projectId,
    required String itemId,
    String? assetId,
    String? name,
    String? category,
    String? condition,
    String? location,
    String? status,
    String? estimatedValue,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (assetId != null) updateData['assetId'] = assetId;
    if (name != null) updateData['name'] = name;
    if (category != null) updateData['category'] = category;
    if (condition != null) updateData['condition'] = condition;
    if (location != null) updateData['location'] = location;
    if (status != null) updateData['status'] = status;
    if (estimatedValue != null) updateData['estimatedValue'] = estimatedValue;

    await _inventoryCol(projectId).doc(itemId).update(updateData);
  }

  static Future<void> deleteInventoryItem({
    required String projectId,
    required String itemId,
  }) async {
    await _inventoryCol(projectId).doc(itemId).delete();
  }

  static Stream<List<SalvageInventoryItemModel>> streamInventoryItems(String projectId, {int limit = 50}) {
    return _inventoryCol(projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(SalvageInventoryItemModel.fromDoc).toList());
  }

  // Disposal Items CRUD
  static CollectionReference<Map<String, dynamic>> _disposalCol(String projectId) =>
      FirebaseFirestore.instance.collection('projects').doc(projectId).collection('salvage_disposal');

  static Future<String> createDisposalItem({
    required String projectId,
    required String assetId,
    required String name,
    required String category,
    String condition = '',
    String location = '',
    String disposalMethod = '',
    required String status,
    required String estimatedValue,
    String disposalCost = '',
    required String priority,
    String assignedTo = '',
    String targetDate = '',
    String? createdById,
    String? createdByEmail,
    String? createdByName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';
    final userEmail = createdByEmail ?? user?.email ?? '';
    final userName = createdByName ?? user?.displayName ?? userEmail.split('@').first;

    final payload = SalvageDisposalItemModel(
      id: '',
      projectId: projectId,
      assetId: assetId,
      name: name,
      category: category,
      condition: condition,
      location: location,
      disposalMethod: disposalMethod,
      status: status,
      estimatedValue: estimatedValue,
      disposalCost: disposalCost,
      priority: priority,
      assignedTo: assignedTo,
      targetDate: targetDate,
      createdById: userId,
      createdByEmail: userEmail,
      createdByName: userName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _disposalCol(projectId).add(payload);
    return ref.id;
  }

  static Future<void> updateDisposalItem({
    required String projectId,
    required String itemId,
    String? assetId,
    String? name,
    String? category,
    String? condition,
    String? location,
    String? disposalMethod,
    String? status,
    String? estimatedValue,
    String? disposalCost,
    String? priority,
    String? assignedTo,
    String? targetDate,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (assetId != null) updateData['assetId'] = assetId;
    if (name != null) updateData['name'] = name;
    if (category != null) updateData['category'] = category;
    if (condition != null) updateData['condition'] = condition;
    if (location != null) updateData['location'] = location;
    if (disposalMethod != null) updateData['disposalMethod'] = disposalMethod;
    if (status != null) updateData['status'] = status;
    if (estimatedValue != null) updateData['estimatedValue'] = estimatedValue;
    if (disposalCost != null) updateData['disposalCost'] = disposalCost;
    if (priority != null) updateData['priority'] = priority;
    if (assignedTo != null) updateData['assignedTo'] = assignedTo;
    if (targetDate != null) updateData['targetDate'] = targetDate;

    await _disposalCol(projectId).doc(itemId).update(updateData);
  }

  static Future<void> deleteDisposalItem({
    required String projectId,
    required String itemId,
  }) async {
    await _disposalCol(projectId).doc(itemId).delete();
  }

  static Stream<List<SalvageDisposalItemModel>> streamDisposalItems(String projectId, {String? status, int limit = 50}) {
    Query<Map<String, dynamic>> query = _disposalCol(projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }
    
    return query.snapshots().map((snap) => snap.docs.map(SalvageDisposalItemModel.fromDoc).toList());
  }

  // Timeline Items CRUD
  static CollectionReference<Map<String, dynamic>> _timelineCol(String projectId) =>
      FirebaseFirestore.instance.collection('projects').doc(projectId).collection('salvage_timeline');

  static Future<String> createTimelineItem({
    required String projectId,
    required String milestone,
    String description = '',
    String phase = 'Planning',
    String status = 'Not Started',
    String owner = '',
    String startDate = '',
    String dueDate = '',
    String completedDate = '',
    int progress = 0,
    String priority = 'Medium',
    String dependencies = '',
    String notes = '',
    String? createdById,
    String? createdByEmail,
    String? createdByName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';
    final userEmail = createdByEmail ?? user?.email ?? '';
    final userName = createdByName ?? user?.displayName ?? userEmail.split('@').first;

    final payload = SalvageTimelineItemModel(
      id: '',
      projectId: projectId,
      milestone: milestone,
      description: description,
      phase: phase,
      status: status,
      owner: owner,
      startDate: startDate,
      dueDate: dueDate,
      completedDate: completedDate,
      progress: progress,
      priority: priority,
      dependencies: dependencies,
      notes: notes,
      createdById: userId,
      createdByEmail: userEmail,
      createdByName: userName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _timelineCol(projectId).add(payload);
    return ref.id;
  }

  static Future<void> updateTimelineItem({
    required String projectId,
    required String itemId,
    String? milestone,
    String? description,
    String? phase,
    String? status,
    String? owner,
    String? startDate,
    String? dueDate,
    String? completedDate,
    int? progress,
    String? priority,
    String? dependencies,
    String? notes,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (milestone != null) updateData['milestone'] = milestone;
    if (description != null) updateData['description'] = description;
    if (phase != null) updateData['phase'] = phase;
    if (status != null) updateData['status'] = status;
    if (owner != null) updateData['owner'] = owner;
    if (startDate != null) updateData['startDate'] = startDate;
    if (dueDate != null) updateData['dueDate'] = dueDate;
    if (completedDate != null) updateData['completedDate'] = completedDate;
    if (progress != null) updateData['progress'] = progress;
    if (priority != null) updateData['priority'] = priority;
    if (dependencies != null) updateData['dependencies'] = dependencies;
    if (notes != null) updateData['notes'] = notes;

    await _timelineCol(projectId).doc(itemId).update(updateData);
  }

  static Future<void> deleteTimelineItem({
    required String projectId,
    required String itemId,
  }) async {
    await _timelineCol(projectId).doc(itemId).delete();
  }

  static Stream<List<SalvageTimelineItemModel>> streamTimelineItems(String projectId, {int limit = 50}) {
    return _timelineCol(projectId)
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(SalvageTimelineItemModel.fromDoc).toList());
  }
}
