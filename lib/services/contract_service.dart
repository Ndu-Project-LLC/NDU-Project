import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/planning_contracting_models.dart';

String _normalizeStatusForStorage(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized.isEmpty) return 'draft';
  switch (normalized) {
    case 'draft':
    case 'under_review':
    case 'approved':
    case 'executed':
    case 'expired':
    case 'terminated':
      return normalized;
  }
  if (normalized.contains('not started')) return 'draft';
  if (normalized.contains('pending')) return 'under_review';
  if (normalized.contains('review')) return 'under_review';
  if (normalized.contains('in progress')) return 'approved';
  if (normalized.contains('progress')) return 'approved';
  if (normalized.contains('complete')) return 'executed';
  if (normalized.contains('completed')) return 'executed';
  return 'draft';
}

String _normalizeStatusForDisplay(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized.isEmpty) return 'Not Started';
  switch (normalized) {
    case 'draft':
      return 'Not Started';
    case 'under_review':
      return 'Pending Review';
    case 'approved':
      return 'In Progress';
    case 'executed':
      return 'Completed';
    case 'expired':
    case 'terminated':
      return 'Completed';
  }
  if (normalized.contains('not started')) return 'Not Started';
  if (normalized.contains('pending')) return 'Pending Review';
  if (normalized.contains('review')) return 'Pending Review';
  if (normalized.contains('in progress')) return 'In Progress';
  if (normalized.contains('progress')) return 'In Progress';
  if (normalized.contains('complete')) return 'Completed';
  if (normalized.contains('completed')) return 'Completed';
  return status.trim();
}

class ContractModel {
  final String id;
  final String projectId;
  final String name; // Contract Name
  final String description;
  final String contractType;
  final String paymentType;
  final String status;
  final double estimatedValue;
  final DateTime? startDate;
  final DateTime? endDate;
  final String scope;
  final String discipline;
  final String contractorName;
  final String owner;
  final String notes; // optional
  final String createdById;
  final String createdByEmail;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PaymentMilestone>? paymentMilestones;
  final String? changeOrderProcedure;
  final String? disputeResolution;
  final String? contractManagerId;
  final String? contractManagerName;
  final String? reportingFrequency;
  final double? contingencyAmount;
  final double? contingencyPercent;
  final String? negotiationStatus;
  final String? negotiationObjectives;
  final String? negotiationAuthority;
  final List<NegotiationItem>? negotiationItems;
  final String? linkedRfqId;
  final List<EvaluationScore>? evaluationScores;
  final List<VendorTechnicalScreening>? technicalScreenings;
  final ContractBudgetBreakdown? budgetBreakdown;
  final String? performanceKpis;
  final String? awardStrategy;
  final String? linkedFepScopeId;
  final String? packageSummary;
  final double? engineerEstimate;
  final DateTime? targetAwardDate;
  final DateTime? plannedExecutionStart;
  final List<String>? linkedScheduleMilestoneIds;
  final String? technicalGateStatus;
  final String? technicalGateNotes;
  final String? recommendedVendor;
  final double? recommendedAwardValue;
  final String? vendorComparisonSummary;
  final String? pmReviewStatus;
  final String? pmReviewNotes;
  final DateTime? pmReviewDate;
  final String? sponsorApprovalStatus;
  final String? sponsorApprovalNotes;
  final DateTime? sponsorApprovalDate;
  final List<String>? complianceChecklist;
  final String? retentionPlan;
  final double? taxFeePlan;
  final double? commitmentForecast;
  final String? handoffStatus;
  final String? handoffNotes;
  final DateTime? handoffReadyAt;
  final String? procurementHandoffStatus;
  final DateTime? procurementIssuedAt;
  final String? procurementRfqId;

  const ContractModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.description,
    required this.contractType,
    required this.paymentType,
    required this.status,
    required this.estimatedValue,
    this.startDate,
    this.endDate,
    required this.scope,
    required this.discipline,
    this.contractorName = '',
    this.owner = '',
    required this.notes,
    required this.createdById,
    required this.createdByEmail,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
    this.paymentMilestones,
    this.changeOrderProcedure,
    this.disputeResolution,
    this.contractManagerId,
    this.contractManagerName,
    this.reportingFrequency,
    this.contingencyAmount,
    this.contingencyPercent,
    this.negotiationStatus,
    this.negotiationObjectives,
    this.negotiationAuthority,
    this.negotiationItems,
    this.linkedRfqId,
    this.evaluationScores,
    this.technicalScreenings,
    this.budgetBreakdown,
    this.performanceKpis,
    this.awardStrategy,
    this.linkedFepScopeId,
    this.packageSummary,
    this.engineerEstimate,
    this.targetAwardDate,
    this.plannedExecutionStart,
    this.linkedScheduleMilestoneIds,
    this.technicalGateStatus,
    this.technicalGateNotes,
    this.recommendedVendor,
    this.recommendedAwardValue,
    this.vendorComparisonSummary,
    this.pmReviewStatus,
    this.pmReviewNotes,
    this.pmReviewDate,
    this.sponsorApprovalStatus,
    this.sponsorApprovalNotes,
    this.sponsorApprovalDate,
    this.complianceChecklist,
    this.retentionPlan,
    this.taxFeePlan,
    this.commitmentForecast,
    this.handoffStatus,
    this.handoffNotes,
    this.handoffReadyAt,
    this.procurementHandoffStatus,
    this.procurementIssuedAt,
    this.procurementRfqId,
  });

  Map<String, dynamic> toMap() {
    final normalizedStatus = _normalizeStatusForStorage(status);
    final statusLabel = _normalizeStatusForDisplay(status);
    return {
      'projectId': projectId,
      'name': name,
      'title': name,
      'description': description,
      'contractType': contractType,
      'paymentType': paymentType,
      'status': normalizedStatus,
      'statusLabel': statusLabel,
      'estimatedValue': estimatedValue,
      'estimatedCost': estimatedValue,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'scope': scope,
      'discipline': discipline,
      'contractorName': contractorName,
      'owner': owner,
      'notes': notes,
      'createdById': createdById,
      'createdByEmail': createdByEmail,
      'createdByName': createdByName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (paymentMilestones != null)
        'paymentMilestones': paymentMilestones!.map((m) => m.toMap()).toList(),
      if (changeOrderProcedure != null)
        'changeOrderProcedure': changeOrderProcedure,
      if (disputeResolution != null) 'disputeResolution': disputeResolution,
      if (contractManagerId != null) 'contractManagerId': contractManagerId,
      if (contractManagerName != null)
        'contractManagerName': contractManagerName,
      if (reportingFrequency != null) 'reportingFrequency': reportingFrequency,
      if (contingencyAmount != null) 'contingencyAmount': contingencyAmount,
      if (contingencyPercent != null) 'contingencyPercent': contingencyPercent,
      if (negotiationStatus != null) 'negotiationStatus': negotiationStatus,
      if (negotiationObjectives != null)
        'negotiationObjectives': negotiationObjectives,
      if (negotiationAuthority != null)
        'negotiationAuthority': negotiationAuthority,
      if (negotiationItems != null)
        'negotiationItems': negotiationItems!.map((n) => n.toMap()).toList(),
      if (linkedRfqId != null) 'linkedRfqId': linkedRfqId,
      if (evaluationScores != null)
        'evaluationScores': evaluationScores!.map((s) => s.toMap()).toList(),
      if (technicalScreenings != null)
        'technicalScreenings':
            technicalScreenings!.map((item) => item.toMap()).toList(),
      if (budgetBreakdown != null) 'budgetBreakdown': budgetBreakdown!.toMap(),
      if (performanceKpis != null) 'performanceKpis': performanceKpis,
      if (awardStrategy != null) 'awardStrategy': awardStrategy,
      if (linkedFepScopeId != null) 'linkedFepScopeId': linkedFepScopeId,
      if (packageSummary != null) 'packageSummary': packageSummary,
      if (engineerEstimate != null) 'engineerEstimate': engineerEstimate,
      if (targetAwardDate != null)
        'targetAwardDate': Timestamp.fromDate(targetAwardDate!),
      if (plannedExecutionStart != null)
        'plannedExecutionStart': Timestamp.fromDate(plannedExecutionStart!),
      if (linkedScheduleMilestoneIds != null)
        'linkedScheduleMilestoneIds': linkedScheduleMilestoneIds,
      if (technicalGateStatus != null) 'technicalGateStatus': technicalGateStatus,
      if (technicalGateNotes != null) 'technicalGateNotes': technicalGateNotes,
      if (recommendedVendor != null) 'recommendedVendor': recommendedVendor,
      if (recommendedAwardValue != null)
        'recommendedAwardValue': recommendedAwardValue,
      if (vendorComparisonSummary != null)
        'vendorComparisonSummary': vendorComparisonSummary,
      if (pmReviewStatus != null) 'pmReviewStatus': pmReviewStatus,
      if (pmReviewNotes != null) 'pmReviewNotes': pmReviewNotes,
      if (pmReviewDate != null) 'pmReviewDate': Timestamp.fromDate(pmReviewDate!),
      if (sponsorApprovalStatus != null)
        'sponsorApprovalStatus': sponsorApprovalStatus,
      if (sponsorApprovalNotes != null)
        'sponsorApprovalNotes': sponsorApprovalNotes,
      if (sponsorApprovalDate != null)
        'sponsorApprovalDate': Timestamp.fromDate(sponsorApprovalDate!),
      if (complianceChecklist != null) 'complianceChecklist': complianceChecklist,
      if (retentionPlan != null) 'retentionPlan': retentionPlan,
      if (taxFeePlan != null) 'taxFeePlan': taxFeePlan,
      if (commitmentForecast != null) 'commitmentForecast': commitmentForecast,
      if (handoffStatus != null) 'handoffStatus': handoffStatus,
      if (handoffNotes != null) 'handoffNotes': handoffNotes,
      if (handoffReadyAt != null)
        'handoffReadyAt': Timestamp.fromDate(handoffReadyAt!),
      if (procurementHandoffStatus != null)
        'procurementHandoffStatus': procurementHandoffStatus,
      if (procurementIssuedAt != null)
        'procurementIssuedAt': Timestamp.fromDate(procurementIssuedAt!),
      if (procurementRfqId != null) 'procurementRfqId': procurementRfqId,
    };
  }

  static ContractModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    String? ns(dynamic v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    double? nd(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final d = double.tryParse(v.toString());
      return d;
    }

    List<PaymentMilestone>? pm(dynamic v) {
      if (v is! List) return null;
      final items = v
          .whereType<Map>()
          .map((e) => PaymentMilestone.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      return items.isEmpty ? null : items;
    }

    List<NegotiationItem>? ni(dynamic v) {
      if (v is! List) return null;
      final items = v
          .whereType<Map>()
          .map((e) => NegotiationItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      return items.isEmpty ? null : items;
    }

    List<EvaluationScore>? es(dynamic v) {
      if (v is! List) return null;
      final items = v
          .whereType<Map>()
          .map((e) => EvaluationScore.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      return items.isEmpty ? null : items;
    }

    List<VendorTechnicalScreening>? parseTechnicalScreenings(dynamic v) {
      if (v is! List) return null;
      final items = v
          .whereType<Map>()
          .map((e) => VendorTechnicalScreening.fromMap(
              Map<String, dynamic>.from(e)))
          .toList();
      return items.isEmpty ? null : items;
    }

    List<String>? sl(dynamic v) {
      if (v is! List) return null;
      final items = v.map((e) => e.toString()).toList();
      return items.isEmpty ? null : items;
    }

    final rawStatus = (data['statusLabel'] ?? data['status'] ?? '').toString();
    final displayStatus = _normalizeStatusForDisplay(rawStatus);

    return ContractModel(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      name: (data['name'] ?? data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      contractType: (data['contractType'] ?? '').toString(),
      paymentType: (data['paymentType'] ?? '').toString(),
      status: displayStatus,
      estimatedValue:
          parseDouble(data['estimatedValue'] ?? data['estimatedCost']),
      startDate: parseTs(data['startDate']),
      endDate: parseTs(data['endDate']),
      scope: (data['scope'] ?? '').toString(),
      discipline: (data['discipline'] ?? '').toString(),
      contractorName: (data['contractorName'] ?? '').toString(),
      owner: (data['owner'] ?? '').toString(),
      notes: (data['notes'] ?? '').toString(),
      createdById: (data['createdById'] ?? '').toString(),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt:
          parseTs(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          parseTs(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      paymentMilestones: pm(data['paymentMilestones']),
      changeOrderProcedure: ns(data['changeOrderProcedure']),
      disputeResolution: ns(data['disputeResolution']),
      contractManagerId: ns(data['contractManagerId']),
      contractManagerName: ns(data['contractManagerName']),
      reportingFrequency: ns(data['reportingFrequency']),
      contingencyAmount: nd(data['contingencyAmount']),
      contingencyPercent: nd(data['contingencyPercent']),
      negotiationStatus: ns(data['negotiationStatus']),
      negotiationObjectives: ns(data['negotiationObjectives']),
      negotiationAuthority: ns(data['negotiationAuthority']),
      negotiationItems: ni(data['negotiationItems']),
      linkedRfqId: ns(data['linkedRfqId']),
      evaluationScores: es(data['evaluationScores']),
      technicalScreenings: parseTechnicalScreenings(data['technicalScreenings']),
      budgetBreakdown: data['budgetBreakdown'] is Map
          ? ContractBudgetBreakdown.fromMap(
              Map<String, dynamic>.from(data['budgetBreakdown'] as Map))
          : null,
      performanceKpis: ns(data['performanceKpis']),
      awardStrategy: ns(data['awardStrategy']),
      linkedFepScopeId: ns(data['linkedFepScopeId']),
      packageSummary: ns(data['packageSummary']),
      engineerEstimate: nd(data['engineerEstimate']),
      targetAwardDate: parseTs(data['targetAwardDate']),
      plannedExecutionStart: parseTs(data['plannedExecutionStart']),
      linkedScheduleMilestoneIds: sl(data['linkedScheduleMilestoneIds']),
      technicalGateStatus: ns(data['technicalGateStatus']),
      technicalGateNotes: ns(data['technicalGateNotes']),
      recommendedVendor: ns(data['recommendedVendor']),
      recommendedAwardValue: nd(data['recommendedAwardValue']),
      vendorComparisonSummary: ns(data['vendorComparisonSummary']),
      pmReviewStatus: ns(data['pmReviewStatus']),
      pmReviewNotes: ns(data['pmReviewNotes']),
      pmReviewDate: parseTs(data['pmReviewDate']),
      sponsorApprovalStatus: ns(data['sponsorApprovalStatus']),
      sponsorApprovalNotes: ns(data['sponsorApprovalNotes']),
      sponsorApprovalDate: parseTs(data['sponsorApprovalDate']),
      complianceChecklist: sl(data['complianceChecklist']),
      retentionPlan: ns(data['retentionPlan']),
      taxFeePlan: nd(data['taxFeePlan']),
      commitmentForecast: nd(data['commitmentForecast']),
      handoffStatus: ns(data['handoffStatus']),
      handoffNotes: ns(data['handoffNotes']),
      handoffReadyAt: parseTs(data['handoffReadyAt']),
      procurementHandoffStatus: ns(data['procurementHandoffStatus']),
      procurementIssuedAt: parseTs(data['procurementIssuedAt']),
      procurementRfqId: ns(data['procurementRfqId']),
    );
  }
}

class ContractService {
  static CollectionReference<Map<String, dynamic>> _contractsCol(
          String projectId) =>
      FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('contracts');

  static Future<String> createContract({
    required String projectId,
    required String name,
    required String description,
    required String contractType,
    required String paymentType,
    required String status,
    required double estimatedValue,
    DateTime? startDate,
    DateTime? endDate,
    required String scope,
    required String discipline,
    String notes = '',
    required String createdById,
    required String createdByEmail,
    required String createdByName,
  }) async {
    final payload = ContractModel(
      id: '',
      projectId: projectId,
      name: name,
      description: description,
      contractType: contractType,
      paymentType: paymentType,
      status: status,
      estimatedValue: estimatedValue,
      startDate: startDate,
      endDate: endDate,
      scope: scope,
      discipline: discipline,
      contractorName: '',
      owner: '',
      notes: notes,
      createdById: createdById,
      createdByEmail: createdByEmail,
      createdByName: createdByName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _contractsCol(projectId).add(payload);
    return ref.id;
  }

  static Stream<List<ContractModel>> streamContracts(String projectId,
      {int limit = 50}) {
    return _contractsCol(projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final contracts = <ContractModel>[];
      for (final doc in snap.docs) {
        try {
          contracts.add(ContractModel.fromDoc(doc));
        } catch (e) {
          debugPrint('Skipping malformed contract ${doc.id}: $e');
        }
      }
      return contracts;
    });
  }

  /// Update an existing contract
  static Future<void> updateContract({
    required String projectId,
    required String contractId,
    String? name,
    String? description,
    String? contractType,
    String? paymentType,
    String? status,
    double? estimatedValue,
    DateTime? startDate,
    DateTime? endDate,
    String? scope,
    String? discipline,
    String? notes,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) {
      updateData['name'] = name;
      updateData['title'] = name;
    }
    if (description != null) updateData['description'] = description;
    if (contractType != null) updateData['contractType'] = contractType;
    if (paymentType != null) updateData['paymentType'] = paymentType;
    if (status != null) {
      updateData['status'] = _normalizeStatusForStorage(status);
      updateData['statusLabel'] = _normalizeStatusForDisplay(status);
    }
    if (estimatedValue != null) {
      updateData['estimatedValue'] = estimatedValue;
      updateData['estimatedCost'] = estimatedValue;
    }
    if (startDate != null) {
      updateData['startDate'] = Timestamp.fromDate(startDate);
    }
    if (endDate != null) {
      updateData['endDate'] = Timestamp.fromDate(endDate);
    }
    if (scope != null) updateData['scope'] = scope;
    if (discipline != null) updateData['discipline'] = discipline;
    if (notes != null) updateData['notes'] = notes;

    await _contractsCol(projectId).doc(contractId).update(updateData);
  }

  /// Delete a contract
  static Future<void> deleteContract({
    required String projectId,
    required String contractId,
  }) async {
    await _contractsCol(projectId).doc(contractId).delete();
  }

  static Future<void> updatePlanningFields({
    required String projectId,
    required String contractId,
    List<PaymentMilestone>? paymentMilestones,
    String? changeOrderProcedure,
    String? disputeResolution,
    String? contractManagerId,
    String? contractManagerName,
    String? reportingFrequency,
    double? contingencyAmount,
    double? contingencyPercent,
    String? negotiationStatus,
    String? negotiationObjectives,
    String? negotiationAuthority,
    List<NegotiationItem>? negotiationItems,
    String? linkedRfqId,
    List<EvaluationScore>? evaluationScores,
    List<VendorTechnicalScreening>? technicalScreenings,
    ContractBudgetBreakdown? budgetBreakdown,
    String? performanceKpis,
    String? awardStrategy,
    String? linkedFepScopeId,
    String? packageSummary,
    double? engineerEstimate,
    DateTime? targetAwardDate,
    DateTime? plannedExecutionStart,
    List<String>? linkedScheduleMilestoneIds,
    String? technicalGateStatus,
    String? technicalGateNotes,
    String? recommendedVendor,
    double? recommendedAwardValue,
    String? vendorComparisonSummary,
    String? pmReviewStatus,
    String? pmReviewNotes,
    DateTime? pmReviewDate,
    String? sponsorApprovalStatus,
    String? sponsorApprovalNotes,
    DateTime? sponsorApprovalDate,
    List<String>? complianceChecklist,
    String? retentionPlan,
    double? taxFeePlan,
    double? commitmentForecast,
    String? handoffStatus,
    String? handoffNotes,
    DateTime? handoffReadyAt,
    String? procurementHandoffStatus,
    DateTime? procurementIssuedAt,
    String? procurementRfqId,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (paymentMilestones != null) {
      updateData['paymentMilestones'] =
          paymentMilestones.map((m) => m.toMap()).toList();
    }
    if (changeOrderProcedure != null) {
      updateData['changeOrderProcedure'] = changeOrderProcedure;
    }
    if (disputeResolution != null) {
      updateData['disputeResolution'] = disputeResolution;
    }
    if (contractManagerId != null) {
      updateData['contractManagerId'] = contractManagerId;
    }
    if (contractManagerName != null) {
      updateData['contractManagerName'] = contractManagerName;
    }
    if (reportingFrequency != null) {
      updateData['reportingFrequency'] = reportingFrequency;
    }
    if (contingencyAmount != null) {
      updateData['contingencyAmount'] = contingencyAmount;
    }
    if (contingencyPercent != null) {
      updateData['contingencyPercent'] = contingencyPercent;
    }
    if (negotiationStatus != null) {
      updateData['negotiationStatus'] = negotiationStatus;
    }
    if (negotiationObjectives != null) {
      updateData['negotiationObjectives'] = negotiationObjectives;
    }
    if (negotiationAuthority != null) {
      updateData['negotiationAuthority'] = negotiationAuthority;
    }
    if (negotiationItems != null) {
      updateData['negotiationItems'] =
          negotiationItems.map((n) => n.toMap()).toList();
    }
    if (linkedRfqId != null) {
      updateData['linkedRfqId'] = linkedRfqId;
    }
    if (evaluationScores != null) {
      updateData['evaluationScores'] =
          evaluationScores.map((s) => s.toMap()).toList();
    }
    if (technicalScreenings != null) {
      updateData['technicalScreenings'] =
          technicalScreenings.map((item) => item.toMap()).toList();
    }
    if (budgetBreakdown != null) {
      updateData['budgetBreakdown'] = budgetBreakdown.toMap();
    }
    if (performanceKpis != null) {
      updateData['performanceKpis'] = performanceKpis;
    }
    if (awardStrategy != null) {
      updateData['awardStrategy'] = awardStrategy;
    }
    if (linkedFepScopeId != null) {
      updateData['linkedFepScopeId'] = linkedFepScopeId;
    }
    if (packageSummary != null) {
      updateData['packageSummary'] = packageSummary;
    }
    if (engineerEstimate != null) {
      updateData['engineerEstimate'] = engineerEstimate;
    }
    if (targetAwardDate != null) {
      updateData['targetAwardDate'] = Timestamp.fromDate(targetAwardDate);
    }
    if (plannedExecutionStart != null) {
      updateData['plannedExecutionStart'] =
          Timestamp.fromDate(plannedExecutionStart);
    }
    if (linkedScheduleMilestoneIds != null) {
      updateData['linkedScheduleMilestoneIds'] = linkedScheduleMilestoneIds;
    }
    if (technicalGateStatus != null) {
      updateData['technicalGateStatus'] = technicalGateStatus;
    }
    if (technicalGateNotes != null) {
      updateData['technicalGateNotes'] = technicalGateNotes;
    }
    if (recommendedVendor != null) {
      updateData['recommendedVendor'] = recommendedVendor;
    }
    if (recommendedAwardValue != null) {
      updateData['recommendedAwardValue'] = recommendedAwardValue;
    }
    if (vendorComparisonSummary != null) {
      updateData['vendorComparisonSummary'] = vendorComparisonSummary;
    }
    if (pmReviewStatus != null) {
      updateData['pmReviewStatus'] = pmReviewStatus;
    }
    if (pmReviewNotes != null) {
      updateData['pmReviewNotes'] = pmReviewNotes;
    }
    if (pmReviewDate != null) {
      updateData['pmReviewDate'] = Timestamp.fromDate(pmReviewDate);
    }
    if (sponsorApprovalStatus != null) {
      updateData['sponsorApprovalStatus'] = sponsorApprovalStatus;
    }
    if (sponsorApprovalNotes != null) {
      updateData['sponsorApprovalNotes'] = sponsorApprovalNotes;
    }
    if (sponsorApprovalDate != null) {
      updateData['sponsorApprovalDate'] =
          Timestamp.fromDate(sponsorApprovalDate);
    }
    if (complianceChecklist != null) {
      updateData['complianceChecklist'] = complianceChecklist;
    }
    if (retentionPlan != null) {
      updateData['retentionPlan'] = retentionPlan;
    }
    if (taxFeePlan != null) {
      updateData['taxFeePlan'] = taxFeePlan;
    }
    if (commitmentForecast != null) {
      updateData['commitmentForecast'] = commitmentForecast;
    }
    if (handoffStatus != null) {
      updateData['handoffStatus'] = handoffStatus;
    }
    if (handoffNotes != null) {
      updateData['handoffNotes'] = handoffNotes;
    }
    if (handoffReadyAt != null) {
      updateData['handoffReadyAt'] = Timestamp.fromDate(handoffReadyAt);
    }
    if (procurementHandoffStatus != null) {
      updateData['procurementHandoffStatus'] = procurementHandoffStatus;
    }
    if (procurementIssuedAt != null) {
      updateData['procurementIssuedAt'] = Timestamp.fromDate(procurementIssuedAt);
    }
    if (procurementRfqId != null) {
      updateData['procurementRfqId'] = procurementRfqId;
    }
    await _contractsCol(projectId).doc(contractId).update(updateData);
  }

  /// Get a single contract
  static Future<ContractModel?> getContract({
    required String projectId,
    required String contractId,
  }) async {
    final doc = await _contractsCol(projectId).doc(contractId).get();
    if (!doc.exists) return null;
    try {
      return ContractModel.fromDoc(doc);
    } catch (e) {
      debugPrint('Unable to parse contract $contractId: $e');
      return null;
    }
  }

}
