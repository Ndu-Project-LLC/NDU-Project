import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/models/planning_contracting_models.dart';

class PlanningContractingService {
  static CollectionReference<Map<String, dynamic>> _rfqCol(String projectId) {
    return FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('planning_rfqs');
  }

  static Future<String> createRfq(PlanningRfq rfq) async {
    final payload = rfq.toMap();
    final ref = await _rfqCol(rfq.projectId).add(payload);
    return ref.id;
  }

  static Stream<List<PlanningRfq>> streamRfqs(String projectId,
      {int limit = 50}) {
    return _rfqCol(projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(PlanningRfq.fromDoc).toList());
  }

  static Future<void> updateRfq(
      String projectId, String rfqId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _rfqCol(projectId).doc(rfqId).update(data);
  }

  static Future<void> deleteRfq(String projectId, String rfqId) async {
    await _rfqCol(projectId).doc(rfqId).delete();
  }

  static Future<bool> hasAnyRfqs(String projectId) async {
    final snap = await _rfqCol(projectId).limit(1).get();
    return snap.docs.isNotEmpty;
  }
}
