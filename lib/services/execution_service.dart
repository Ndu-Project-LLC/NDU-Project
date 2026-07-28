import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Model for execution tools/items
class ExecutionToolModel {
  final String id;
  final String projectId;
  final String tool;
  final String description;
  final String source;
  final String? cost;
  final String comments;
  final String createdById;
  final String createdByEmail;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExecutionToolModel({
    required this.id,
    required this.projectId,
    required this.tool,
    required this.description,
    required this.source,
    this.cost,
    required this.comments,
    required this.createdById,
    required this.createdByEmail,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'tool': tool,
        'description': description,
        'source': source,
        'cost': cost ?? '',
        'comments': comments,
        'createdById': createdById,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static ExecutionToolModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return ExecutionToolModel(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      tool: (data['tool'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      source: (data['source'] ?? '').toString(),
      cost: data['cost']?.toString(),
      comments: (data['comments'] ?? '').toString(),
      createdById: (data['createdById'] ?? '').toString(),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }
}

/// Model for execution issues
class ExecutionIssueModel {
  final String id;
  final String projectId;
  final String issueTopic;
  final String description;
  final String discipline;
  final String raisedBy;
  final String scheduleImpact;
  final String costImpact;
  final bool approved;
  final String comments;
  final String? llOrBp; // Lessons Learned or Best Practice
  final String? impacted;
  final String createdById;
  final String createdByEmail;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExecutionIssueModel({
    required this.id,
    required this.projectId,
    required this.issueTopic,
    required this.description,
    required this.discipline,
    required this.raisedBy,
    required this.scheduleImpact,
    required this.costImpact,
    required this.approved,
    required this.comments,
    this.llOrBp,
    this.impacted,
    required this.createdById,
    required this.createdByEmail,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'issueTopic': issueTopic,
        'description': description,
        'discipline': discipline,
        'raisedBy': raisedBy,
        'scheduleImpact': scheduleImpact,
        'costImpact': costImpact,
        'approved': approved,
        'comments': comments,
        'llOrBp': llOrBp ?? '',
        'impacted': impacted ?? '',
        'createdById': createdById,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static ExecutionIssueModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return ExecutionIssueModel(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      issueTopic: (data['issueTopic'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      discipline: (data['discipline'] ?? '').toString(),
      raisedBy: (data['raisedBy'] ?? '').toString(),
      scheduleImpact: (data['scheduleImpact'] ?? '').toString(),
      costImpact: (data['costImpact'] ?? '').toString(),
      approved: data['approved'] == true,
      comments: (data['comments'] ?? '').toString(),
      llOrBp: data['llOrBp']?.toString(),
      impacted: data['impacted']?.toString(),
      createdById: (data['createdById'] ?? '').toString(),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }
}

/// Model for interface register entries
class InterfaceRegisterModel {
  final String id;
  final String projectId;
  final String interfaceId;
  final String interfaceName;
  final String interfaceType;
  final String partyA;
  final String partyB;
  final String status;
  final String frequency;
  final String comments;
  final String createdById;
  final String createdByEmail;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InterfaceRegisterModel({
    required this.id,
    required this.projectId,
    required this.interfaceId,
    required this.interfaceName,
    required this.interfaceType,
    required this.partyA,
    required this.partyB,
    required this.status,
    required this.frequency,
    required this.comments,
    required this.createdById,
    required this.createdByEmail,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'interfaceId': interfaceId,
        'interfaceName': interfaceName,
        'interfaceType': interfaceType,
        'partyA': partyA,
        'partyB': partyB,
        'status': status,
        'frequency': frequency,
        'comments': comments,
        'createdById': createdById,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static InterfaceRegisterModel fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return InterfaceRegisterModel(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      interfaceId: (data['interfaceId'] ?? '').toString(),
      interfaceName: (data['interfaceName'] ?? '').toString(),
      interfaceType: (data['interfaceType'] ?? '').toString(),
      partyA: (data['partyA'] ?? '').toString(),
      partyB: (data['partyB'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      frequency: (data['frequency'] ?? '').toString(),
      comments: (data['comments'] ?? '').toString(),
      createdById: (data['createdById'] ?? '').toString(),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }
}

/// Model for communication plan entries
class CommunicationPlanModel {
  final String id;
  final String projectId;
  final String stakeholder;
  final String infoType;
  final String frequency;
  final String channel;
  final String owner;
  final String status;
  final String comments;
  final String createdById;
  final String createdByEmail;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommunicationPlanModel({
    required this.id,
    required this.projectId,
    required this.stakeholder,
    required this.infoType,
    required this.frequency,
    required this.channel,
    required this.owner,
    required this.status,
    required this.comments,
    required this.createdById,
    required this.createdByEmail,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'stakeholder': stakeholder,
        'infoType': infoType,
        'frequency': frequency,
        'channel': channel,
        'owner': owner,
        'status': status,
        'comments': comments,
        'createdById': createdById,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static CommunicationPlanModel fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return CommunicationPlanModel(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      stakeholder: (data['stakeholder'] ?? '').toString(),
      infoType: (data['infoType'] ?? '').toString(),
      frequency: (data['frequency'] ?? '').toString(),
      channel: (data['channel'] ?? '').toString(),
      owner: (data['owner'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      comments: (data['comments'] ?? '').toString(),
      createdById: (data['createdById'] ?? '').toString(),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }
}

class ExecutionService {
  static CollectionReference<Map<String, dynamic>> _toolsCol(String projectId) =>
      FirebaseFirestore.instance.collection('projects').doc(projectId).collection('execution_tools');

  static CollectionReference<Map<String, dynamic>> _issuesCol(String projectId) =>
      FirebaseFirestore.instance.collection('projects').doc(projectId).collection('execution_issues');

  // Execution Tools CRUD
  static Future<String> createTool({
    required String projectId,
    required String tool,
    required String description,
    required String source,
    String? cost,
    required String comments,
    String? createdById,
    String? createdByEmail,
    String? createdByName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';
    final userEmail = createdByEmail ?? user?.email ?? '';
    final userName = createdByName ?? user?.displayName ?? userEmail.split('@').first;

    final payload = ExecutionToolModel(
      id: '',
      projectId: projectId,
      tool: tool,
      description: description,
      source: source,
      cost: cost,
      comments: comments,
      createdById: userId,
      createdByEmail: userEmail,
      createdByName: userName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _toolsCol(projectId).add(payload);
    return ref.id;
  }

  static Future<void> updateTool({
    required String projectId,
    required String toolId,
    String? tool,
    String? description,
    String? source,
    String? cost,
    String? comments,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (tool != null) updateData['tool'] = tool;
    if (description != null) updateData['description'] = description;
    if (source != null) updateData['source'] = source;
    if (cost != null) updateData['cost'] = cost;
    if (comments != null) updateData['comments'] = comments;

    await _toolsCol(projectId).doc(toolId).update(updateData);
  }

  static Future<void> deleteTool({
    required String projectId,
    required String toolId,
  }) async {
    await _toolsCol(projectId).doc(toolId).delete();
  }

  static Stream<List<ExecutionToolModel>> streamTools(String projectId, {int limit = 50}) {
    return _toolsCol(projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ExecutionToolModel.fromDoc).toList());
  }

  // Execution Issues CRUD
  static Future<String> createIssue({
    required String projectId,
    required String issueTopic,
    required String description,
    required String discipline,
    required String raisedBy,
    required String scheduleImpact,
    required String costImpact,
    required bool approved,
    required String comments,
    String? llOrBp,
    String? impacted,
    String? createdById,
    String? createdByEmail,
    String? createdByName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';
    final userEmail = createdByEmail ?? user?.email ?? '';
    final userName = createdByName ?? user?.displayName ?? userEmail.split('@').first;

    final payload = ExecutionIssueModel(
      id: '',
      projectId: projectId,
      issueTopic: issueTopic,
      description: description,
      discipline: discipline,
      raisedBy: raisedBy,
      scheduleImpact: scheduleImpact,
      costImpact: costImpact,
      approved: approved,
      comments: comments,
      llOrBp: llOrBp,
      impacted: impacted,
      createdById: userId,
      createdByEmail: userEmail,
      createdByName: userName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _issuesCol(projectId).add(payload);
    return ref.id;
  }

  static Future<void> updateIssue({
    required String projectId,
    required String issueId,
    String? issueTopic,
    String? description,
    String? discipline,
    String? raisedBy,
    String? scheduleImpact,
    String? costImpact,
    bool? approved,
    String? comments,
    String? llOrBp,
    String? impacted,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (issueTopic != null) updateData['issueTopic'] = issueTopic;
    if (description != null) updateData['description'] = description;
    if (discipline != null) updateData['discipline'] = discipline;
    if (raisedBy != null) updateData['raisedBy'] = raisedBy;
    if (scheduleImpact != null) updateData['scheduleImpact'] = scheduleImpact;
    if (costImpact != null) updateData['costImpact'] = costImpact;
    if (approved != null) updateData['approved'] = approved;
    if (comments != null) updateData['comments'] = comments;
    if (llOrBp != null) updateData['llOrBp'] = llOrBp;
    if (impacted != null) updateData['impacted'] = impacted;

    await _issuesCol(projectId).doc(issueId).update(updateData);
  }

  static Future<void> deleteIssue({
    required String projectId,
    required String issueId,
  }) async {
    await _issuesCol(projectId).doc(issueId).delete();
  }

  static Stream<List<ExecutionIssueModel>> streamIssues(String projectId, {int limit = 50}) {
    return _issuesCol(projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ExecutionIssueModel.fromDoc).toList());
  }

  // Enabling Works CRUD
  static CollectionReference<Map<String, dynamic>> _enablingWorksCol(String projectId) =>
      FirebaseFirestore.instance.collection('projects').doc(projectId).collection('execution_enabling_works');

  // Early Works CRUD (separate from tools to avoid shared data bug)
  static CollectionReference<Map<String, dynamic>> _earlyWorksCol(String projectId) =>
      FirebaseFirestore.instance.collection('projects').doc(projectId).collection('execution_early_works');

  static Stream<List<ExecutionToolModel>> streamEarlyWorks(String projectId, {int limit = 50}) {
    return _earlyWorksCol(projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ExecutionToolModel.fromDoc).toList());
  }

  static Future<String> createEarlyWork({
    required String projectId,
    required String tool,
    required String description,
    required String source,
    String? cost,
    required String comments,
    String? createdById,
    String? createdByEmail,
    String? createdByName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';
    final userEmail = createdByEmail ?? user?.email ?? '';
    final userName = createdByName ?? user?.displayName ?? userEmail.split('@').first;

    final payload = ExecutionToolModel(
      id: '',
      projectId: projectId,
      tool: tool,
      description: description,
      source: source,
      cost: cost,
      comments: comments,
      createdById: userId,
      createdByEmail: userEmail,
      createdByName: userName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _earlyWorksCol(projectId).add(payload);
    return ref.id;
  }

  static Future<void> updateEarlyWork({
    required String projectId,
    required String workId,
    String? tool,
    String? description,
    String? source,
    String? cost,
    String? comments,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (tool != null) updateData['tool'] = tool;
    if (description != null) updateData['description'] = description;
    if (source != null) updateData['source'] = source;
    if (cost != null) updateData['cost'] = cost;
    if (comments != null) updateData['comments'] = comments;

    await _earlyWorksCol(projectId).doc(workId).update(updateData);
  }

  static Future<void> deleteEarlyWork({
    required String projectId,
    required String workId,
  }) async {
    await _earlyWorksCol(projectId).doc(workId).delete();
  }

  static Future<String> createEnablingWork({
    required String projectId,
    required String aspect,
    required String description,
    required String duration,
    required String cost,
    required String comments,
    String? createdById,
    String? createdByEmail,
    String? createdByName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';
    final userEmail = createdByEmail ?? user?.email ?? '';
    final userName = createdByName ?? user?.displayName ?? userEmail.split('@').first;

    final payload = ExecutionEnablingWorkModel(
      id: '',
      projectId: projectId,
      aspect: aspect,
      description: description,
      duration: duration,
      cost: cost,
      comments: comments,
      createdById: userId,
      createdByEmail: userEmail,
      createdByName: userName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _enablingWorksCol(projectId).add(payload);
    return ref.id;
  }

  static Future<void> updateEnablingWork({
    required String projectId,
    required String workId,
    String? aspect,
    String? description,
    String? duration,
    String? cost,
    String? comments,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (aspect != null) updateData['aspect'] = aspect;
    if (description != null) updateData['description'] = description;
    if (duration != null) updateData['duration'] = duration;
    if (cost != null) updateData['cost'] = cost;
    if (comments != null) updateData['comments'] = comments;

    await _enablingWorksCol(projectId).doc(workId).update(updateData);
  }

  static Future<void> deleteEnablingWork({
    required String projectId,
    required String workId,
  }) async {
    await _enablingWorksCol(projectId).doc(workId).delete();
  }

  static Stream<List<ExecutionEnablingWorkModel>> streamEnablingWorks(String projectId, {int limit = 50}) {
    return _enablingWorksCol(projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ExecutionEnablingWorkModel.fromDoc).toList());
  }

  // Change Requests CRUD (using ExecutionIssueModel structure)
  static CollectionReference<Map<String, dynamic>> _changeRequestsCol(String projectId) =>
      FirebaseFirestore.instance.collection('projects').doc(projectId).collection('execution_change_requests');

  static Stream<List<ExecutionIssueModel>> streamChangeRequests(String projectId, {int limit = 50}) {
    return _changeRequestsCol(projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ExecutionIssueModel.fromDoc).toList());
  }

  static Future<String> createChangeRequest({
    required String projectId,
    required String issueTopic,
    required String description,
    required String discipline,
    required String raisedBy,
    required String scheduleImpact,
    required String costImpact,
    required bool approved,
    required String comments,
    String? llOrBp,
    String? impacted,
    String? createdById,
    String? createdByEmail,
    String? createdByName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';
    final userEmail = createdByEmail ?? user?.email ?? '';
    final userName = createdByName ?? user?.displayName ?? userEmail.split('@').first;

    final payload = ExecutionIssueModel(
      id: '',
      projectId: projectId,
      issueTopic: issueTopic,
      description: description,
      discipline: discipline,
      raisedBy: raisedBy,
      scheduleImpact: scheduleImpact,
      costImpact: costImpact,
      approved: approved,
      comments: comments,
      llOrBp: llOrBp,
      impacted: impacted,
      createdById: userId,
      createdByEmail: userEmail,
      createdByName: userName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _changeRequestsCol(projectId).add(payload);
    return ref.id;
  }

  static Future<void> updateChangeRequest({
    required String projectId,
    required String requestId,
    String? issueTopic,
    String? description,
    String? discipline,
    String? raisedBy,
    String? scheduleImpact,
    String? costImpact,
    bool? approved,
    String? comments,
    String? llOrBp,
    String? impacted,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (issueTopic != null) updateData['issueTopic'] = issueTopic;
    if (description != null) updateData['description'] = description;
    if (discipline != null) updateData['discipline'] = discipline;
    if (raisedBy != null) updateData['raisedBy'] = raisedBy;
    if (scheduleImpact != null) updateData['scheduleImpact'] = scheduleImpact;
    if (costImpact != null) updateData['costImpact'] = costImpact;
    if (approved != null) updateData['approved'] = approved;
    if (comments != null) updateData['comments'] = comments;
    if (llOrBp != null) updateData['llOrBp'] = llOrBp;
    if (impacted != null) updateData['impacted'] = impacted;

    await _changeRequestsCol(projectId).doc(requestId).update(updateData);
  }

  static Future<void> deleteChangeRequest({
    required String projectId,
    required String requestId,
  }) async {
    await _changeRequestsCol(projectId).doc(requestId).delete();
  }

  // Interface Register CRUD
  static CollectionReference<Map<String, dynamic>> _interfaceRegisterCol(
          String projectId) =>
      FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('execution_interface_register');

  static Stream<List<InterfaceRegisterModel>> streamInterfaceRegister(
          String projectId,
          {int limit = 50}) =>
      _interfaceRegisterCol(projectId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs.map(InterfaceRegisterModel.fromDoc).toList());

  static Future<String> createInterfaceRegister({
    required String projectId,
    required String interfaceId,
    required String interfaceName,
    required String interfaceType,
    required String partyA,
    required String partyB,
    required String status,
    required String frequency,
    required String comments,
    String? createdById,
    String? createdByEmail,
    String? createdByName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';
    final userEmail = createdByEmail ?? user?.email ?? '';
    final userName =
        createdByName ?? user?.displayName ?? userEmail.split('@').first;

    final payload = InterfaceRegisterModel(
      id: '',
      projectId: projectId,
      interfaceId: interfaceId,
      interfaceName: interfaceName,
      interfaceType: interfaceType,
      partyA: partyA,
      partyB: partyB,
      status: status,
      frequency: frequency,
      comments: comments,
      createdById: userId,
      createdByEmail: userEmail,
      createdByName: userName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _interfaceRegisterCol(projectId).add(payload);
    return ref.id;
  }

  static Future<void> updateInterfaceRegister({
    required String projectId,
    required String registerId,
    String? interfaceId,
    String? interfaceName,
    String? interfaceType,
    String? partyA,
    String? partyB,
    String? status,
    String? frequency,
    String? comments,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (interfaceId != null) updateData['interfaceId'] = interfaceId;
    if (interfaceName != null) updateData['interfaceName'] = interfaceName;
    if (interfaceType != null) updateData['interfaceType'] = interfaceType;
    if (partyA != null) updateData['partyA'] = partyA;
    if (partyB != null) updateData['partyB'] = partyB;
    if (status != null) updateData['status'] = status;
    if (frequency != null) updateData['frequency'] = frequency;
    if (comments != null) updateData['comments'] = comments;

    await _interfaceRegisterCol(projectId).doc(registerId).update(updateData);
  }

  static Future<void> deleteInterfaceRegister({
    required String projectId,
    required String registerId,
  }) async {
    await _interfaceRegisterCol(projectId).doc(registerId).delete();
  }

  // Communication Plan CRUD
  static CollectionReference<Map<String, dynamic>> _communicationPlanCol(
          String projectId) =>
      FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('execution_communication_plan');

  static Stream<List<CommunicationPlanModel>> streamCommunicationPlan(
          String projectId,
          {int limit = 50}) =>
      _communicationPlanCol(projectId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) =>
              snap.docs.map(CommunicationPlanModel.fromDoc).toList());

  static Future<String> createCommunicationPlan({
    required String projectId,
    required String stakeholder,
    required String infoType,
    required String frequency,
    required String channel,
    required String owner,
    required String status,
    required String comments,
    String? createdById,
    String? createdByEmail,
    String? createdByName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';
    final userEmail = createdByEmail ?? user?.email ?? '';
    final userName =
        createdByName ?? user?.displayName ?? userEmail.split('@').first;

    final payload = CommunicationPlanModel(
      id: '',
      projectId: projectId,
      stakeholder: stakeholder,
      infoType: infoType,
      frequency: frequency,
      channel: channel,
      owner: owner,
      status: status,
      comments: comments,
      createdById: userId,
      createdByEmail: userEmail,
      createdByName: userName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _communicationPlanCol(projectId).add(payload);
    return ref.id;
  }

  static Future<void> updateCommunicationPlan({
    required String projectId,
    required String planId,
    String? stakeholder,
    String? infoType,
    String? frequency,
    String? channel,
    String? owner,
    String? status,
    String? comments,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (stakeholder != null) updateData['stakeholder'] = stakeholder;
    if (infoType != null) updateData['infoType'] = infoType;
    if (frequency != null) updateData['frequency'] = frequency;
    if (channel != null) updateData['channel'] = channel;
    if (owner != null) updateData['owner'] = owner;
    if (status != null) updateData['status'] = status;
    if (comments != null) updateData['comments'] = comments;

    await _communicationPlanCol(projectId).doc(planId).update(updateData);
  }

  static Future<void> deleteCommunicationPlan({
    required String projectId,
    required String planId,
  }) async {
    await _communicationPlanCol(projectId).doc(planId).delete();
  }
}

/// Model for enabling works
class ExecutionEnablingWorkModel {
  final String id;
  final String projectId;
  final String aspect;
  final String description;
  final String duration;
  final String cost;
  final String comments;
  final String createdById;
  final String createdByEmail;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExecutionEnablingWorkModel({
    required this.id,
    required this.projectId,
    required this.aspect,
    required this.description,
    required this.duration,
    required this.cost,
    required this.comments,
    required this.createdById,
    required this.createdByEmail,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'aspect': aspect,
        'description': description,
        'duration': duration,
        'cost': cost,
        'comments': comments,
        'createdById': createdById,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static ExecutionEnablingWorkModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return ExecutionEnablingWorkModel(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      aspect: (data['aspect'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      duration: (data['duration'] ?? '').toString(),
      cost: (data['cost'] ?? '').toString(),
      comments: (data['comments'] ?? '').toString(),
      createdById: (data['createdById'] ?? '').toString(),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }
}

