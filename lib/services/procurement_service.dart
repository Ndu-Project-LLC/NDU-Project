import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';

class ProcurementService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const int _defaultQueryLimit = 80;
  static const int _maxQueryLimit = 500;

  static int _sanitizeLimit(int limit) {
    if (limit < 1) return 1;
    if (limit > _maxQueryLimit) return _maxQueryLimit;
    return limit;
  }

  // --- Collection References ---

  static CollectionReference<Map<String, dynamic>> _itemsCol(
          String projectId) =>
      _db.collection('projects').doc(projectId).collection('procurement_items');

  static CollectionReference<Map<String, dynamic>> _strategiesCol(
          String projectId) =>
      _db
          .collection('projects')
          .doc(projectId)
          .collection('procurement_strategies');

  static CollectionReference<Map<String, dynamic>> _rfqsCol(String projectId) =>
      _db.collection('projects').doc(projectId).collection('rfqs');

  static CollectionReference<Map<String, dynamic>> _posCol(String projectId) =>
      _db.collection('projects').doc(projectId).collection('purchase_orders');

  static CollectionReference<Map<String, dynamic>> _contractsCol(
          String projectId) =>
      _db.collection('projects').doc(projectId).collection('contracts');

  static Query<ProcurementItemModel> _itemsQuery(
    String projectId, {
    int limit = _defaultQueryLimit,
  }) {
    return _itemsCol(projectId)
        .limit(_sanitizeLimit(limit))
        .withConverter<ProcurementItemModel>(
          fromFirestore: (snapshot, _) =>
              ProcurementItemModel.fromDoc(snapshot),
          toFirestore: (model, _) => model.toMap(),
        );
  }

  static Query<ProcurementStrategyModel> _strategiesQuery(
    String projectId, {
    int limit = _defaultQueryLimit,
  }) {
    return _strategiesCol(projectId)
        .limit(_sanitizeLimit(limit))
        .withConverter<ProcurementStrategyModel>(
          fromFirestore: (snapshot, _) =>
              ProcurementStrategyModel.fromDoc(snapshot),
          toFirestore: (model, _) => model.toMap(),
        );
  }

  static Query<RfqModel> _rfqsQuery(
    String projectId, {
    int limit = _defaultQueryLimit,
  }) {
    return _rfqsCol(projectId)
        .limit(_sanitizeLimit(limit))
        .withConverter<RfqModel>(
          fromFirestore: (snapshot, _) => RfqModel.fromDoc(snapshot),
          toFirestore: (model, _) => model.toMap(),
        );
  }

  static Query<PurchaseOrderModel> _posQuery(
    String projectId, {
    int limit = _defaultQueryLimit,
  }) {
    return _posCol(projectId)
        .limit(_sanitizeLimit(limit))
        .withConverter<PurchaseOrderModel>(
          fromFirestore: (snapshot, _) => PurchaseOrderModel.fromDoc(snapshot),
          toFirestore: (model, _) => model.toMap(),
        );
  }

  static Query<ContractModel> _contractsQuery(
    String projectId, {
    int limit = _defaultQueryLimit,
  }) {
    return _contractsCol(projectId)
        .limit(_sanitizeLimit(limit))
        .withConverter<ContractModel>(
          fromFirestore: (snapshot, _) => ContractModel.fromDoc(snapshot),
          toFirestore: (model, _) => model.toMap(),
        );
  }

  // --- Procurement Items ---

  static Stream<List<ProcurementItemModel>> streamItems(
    String projectId, {
    int limit = _defaultQueryLimit,
  }) {
    return _itemsQuery(projectId, limit: limit).snapshots().map(
      (snap) {
        final items = <ProcurementItemModel>[];
        for (final doc in snap.docs) {
          try {
            items.add(doc.data());
          } catch (e) {
            debugPrint('Skipping malformed procurement item ${doc.id}: $e');
          }
        }
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return items;
      },
    );
  }

  static Future<bool> hasAnyItems(String projectId) async {
    final snap = await _itemsCol(projectId).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  static Future<bool> hasAnyStrategies(String projectId) async {
    final snap = await _strategiesCol(projectId).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  static Future<String> createItem(ProcurementItemModel item) async {
    // Note: Creating with auto-ID if item.id is empty, but usually model creation generates ID or we wait for Firestore.
    // Ideally we let Firestore generate ID.
    final ref = _itemsCol(item.projectId).doc();
    // Re-create map to inject server timestamp if needed, but model has it.
    // We update the ID in the payload to match the doc ID.
    final payload = item.toMap();
    // Ensure we don't save empty ID if we want doc ID in the field (optional but good practice)

    await ref.set(payload);
    return ref.id;
  }

  static Future<void> updateItem(
      String projectId, String itemId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _itemsCol(projectId).doc(itemId).update(data);
  }

  static Future<void> deleteItem(String projectId, String itemId) async {
    await _itemsCol(projectId).doc(itemId).delete();
  }

  // --- Strategies ---

  static Stream<List<ProcurementStrategyModel>> streamStrategies(
    String projectId, {
    int limit = _defaultQueryLimit,
  }) {
    return _strategiesQuery(projectId, limit: limit).snapshots().map(
      (snap) {
        final strategies = <ProcurementStrategyModel>[];
        for (final doc in snap.docs) {
          try {
            strategies.add(doc.data());
          } catch (e) {
            debugPrint('Skipping malformed procurement strategy ${doc.id}: $e');
          }
        }
        strategies.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return strategies;
      },
    );
  }

  static Future<void> createStrategy(ProcurementStrategyModel strategy) async {
    final projectId = strategy.projectId.trim();
    if (projectId.isEmpty) {
      throw Exception('Missing project id for procurement strategy.');
    }
    if (strategy.title.trim().isEmpty || strategy.category.trim().isEmpty) {
      throw Exception('Strategy title and category are required.');
    }
    final ref = _strategiesCol(projectId).doc();
    await ref.set(strategy.toMap());
  }

  static Future<void> updateStrategy(
      String projectId, String strategyId, Map<String, dynamic> data) async {
    await _strategiesCol(projectId).doc(strategyId).update(data);
  }

  static Future<void> deleteStrategy(
      String projectId, String strategyId) async {
    await _strategiesCol(projectId).doc(strategyId).delete();
  }

  // --- RFQs ---

  static Stream<List<RfqModel>> streamRfqs(
    String projectId, {
    int limit = _defaultQueryLimit,
  }) {
    return _rfqsQuery(projectId, limit: limit).snapshots().map(
      (snap) {
        final rfqs = <RfqModel>[];
        for (final doc in snap.docs) {
          try {
            rfqs.add(doc.data());
          } catch (e) {
            debugPrint('Skipping malformed RFQ ${doc.id}: $e');
          }
        }
        rfqs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return rfqs;
      },
    );
  }

  static Future<String> createRfq(RfqModel rfq) async {
    final ref = await _rfqsCol(rfq.projectId).add(rfq.toMap());
    return ref.id;
  }

  static Future<bool> hasAnyRfqs(String projectId) async {
    final snap = await _rfqsCol(projectId).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  static Future<void> updateRfq(
      String projectId, String rfqId, Map<String, dynamic> data) async {
    await _rfqsCol(projectId).doc(rfqId).update(data);
  }

  static Future<void> deleteRfq(String projectId, String rfqId) async {
    await _rfqsCol(projectId).doc(rfqId).delete();
  }

  // --- Purchase Orders ---

  static Stream<List<PurchaseOrderModel>> streamPos(
    String projectId, {
    int limit = _defaultQueryLimit,
  }) {
    return _posQuery(projectId, limit: limit).snapshots().map(
      (snap) {
        final orders = <PurchaseOrderModel>[];
        for (final doc in snap.docs) {
          try {
            orders.add(doc.data());
          } catch (e) {
            debugPrint('Skipping malformed purchase order doc ${doc.id}: $e');
          }
        }
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return orders;
      },
    );
  }

  static Future<void> createPo(PurchaseOrderModel po) async {
    await _posCol(po.projectId).add(po.toMap());
  }

  static Future<bool> hasAnyPos(String projectId) async {
    final snap = await _posCol(projectId).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  static Future<void> updatePo(
      String projectId, String poId, Map<String, dynamic> data) async {
    await _posCol(projectId).doc(poId).update(data);
  }

  static Future<void> deletePo(String projectId, String poId) async {
    await _posCol(projectId).doc(poId).delete();
  }

  // --- Contracts ---

  static Stream<List<ContractModel>> streamContracts(
    String projectId, {
    int limit = _defaultQueryLimit,
  }) {
    return _contractsQuery(projectId, limit: limit).snapshots().map(
      (snap) {
        final contracts = <ContractModel>[];
        for (final doc in snap.docs) {
          try {
            contracts.add(doc.data());
          } catch (e) {
            debugPrint('Skipping malformed contract ${doc.id}: $e');
          }
        }
        contracts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return contracts;
      },
    );
  }

  static Future<bool> hasAnyContracts(String projectId) async {
    final snap = await _contractsCol(projectId).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  static Future<void> createContract(ContractModel contract) async {
    await _contractsCol(contract.projectId).add(contract.toMap());
  }

  static Future<void> updateContract(
      String projectId, String contractId, Map<String, dynamic> data) async {
    await _contractsCol(projectId).doc(contractId).update(data);
  }

  static Future<void> deleteContract(
      String projectId, String contractId) async {
    await _contractsCol(projectId).doc(contractId).delete();
  }

  // --- Approval Workflow Methods ---

  /// Submit PO for approval
  static Future<void> submitPoForApproval(
    String projectId,
    String poId,
    String approverId,
    String approverName,
    int escalationDays,
  ) async {
    await _posCol(projectId).doc(poId).update({
      'approvalStatus': 'pending',
      'approverId': approverId,
      'approverName': approverName,
      'approvalDate': FieldValue.serverTimestamp(),
      'escalationDays': escalationDays,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Approve a PO
  static Future<void> approvePo(
    String projectId,
    String poId, {
    String? comments,
  }) async {
    final updateData = <String, dynamic>{
      'approvalStatus': 'approved',
      'status': 'issued', // Also update PO status
      'approverComments': comments ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Update approval date only if not already set
    await _posCol(projectId).doc(poId).update(updateData);
  }

  /// Reject a PO
  static Future<void> rejectPo(
    String projectId,
    String poId,
    String reason,
  ) async {
    await _posCol(projectId).doc(poId).update({
      'approvalStatus': 'rejected',
      'status': 'draft', // Reset to draft for revision
      'rejectionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Escalate a PO that hasn't been approved
  static Future<void> escalatePo(
    String projectId,
    String poId,
    String escalationTargetId,
  ) async {
    await _posCol(projectId).doc(poId).update({
      'approvalStatus': 'escalated',
      'escalationTargetId': escalationTargetId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get POs pending approval
  static Stream<List<PurchaseOrderModel>> streamPendingApprovals(
    String projectId,
  ) {
    return _posCol(projectId)
        .where('approvalStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PurchaseOrderModel.fromDoc(doc))
            .toList());
  }

  /// Get overdue POs (pending past escalation days)
  static Future<List<PurchaseOrderModel>> getOverdueApprovals(
    String projectId,
  ) async {
    final snap = await _posCol(projectId)
        .where('approvalStatus', isEqualTo: 'pending')
        .get();

    final overdue = <PurchaseOrderModel>[];
    for (final doc in snap.docs) {
      try {
        final po = PurchaseOrderModel.fromDoc(doc);
        if (po.isPendingApproval) {
          overdue.add(po);
        }
      } catch (e) {
        debugPrint('Skipping malformed PO ${doc.id}: $e');
      }
    }
    return overdue;
  }

  // --- Schedule Linkage Methods ---

  /// Update item's schedule linkage
  static Future<void> updateItemScheduleLink(
    String projectId,
    String itemId, {
    String? wbsId,
    String? milestoneId,
    DateTime? requiredByDate,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (wbsId != null) {
      data['linkedWbsId'] = wbsId;
    }
    if (milestoneId != null) {
      data['linkedMilestoneId'] = milestoneId;
    }
    if (requiredByDate != null) {
      data['requiredByDate'] = Timestamp.fromDate(requiredByDate);
    } else {
      data['requiredByDate'] = FieldValue.delete();
    }

    await _itemsCol(projectId).doc(itemId).update(data);
  }

  /// Clear schedule linkage from an item
  static Future<void> clearItemScheduleLink(
    String projectId,
    String itemId,
  ) async {
    await _itemsCol(projectId).doc(itemId).update({
      'linkedWbsId': FieldValue.delete(),
      'linkedMilestoneId': FieldValue.delete(),
      'requiredByDate': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get items linked to a specific milestone
  static Stream<List<ProcurementItemModel>> streamItemsByMilestone(
    String projectId,
    String milestoneId,
  ) {
    return _itemsCol(projectId)
        .where('linkedMilestoneId', isEqualTo: milestoneId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ProcurementItemModel.fromDoc(doc))
            .toList());
  }

  /// Get items linked to a specific WBS element
  static Stream<List<ProcurementItemModel>> streamItemsByWbs(
    String projectId,
    String wbsId,
  ) {
    return _itemsCol(projectId)
        .where('linkedWbsId', isEqualTo: wbsId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ProcurementItemModel.fromDoc(doc))
            .toList());
  }
}
