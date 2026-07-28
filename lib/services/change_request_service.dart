import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ApprovalStep {
  final int stepNumber;
  final String approverRole;
  final String? approverName;
  final String status; // 'pending' | 'approved' | 'rejected'
  final DateTime? approvedAt;
  final String? comments;

  const ApprovalStep({
    required this.stepNumber,
    required this.approverRole,
    this.approverName,
    this.status = 'pending',
    this.approvedAt,
    this.comments,
  });

  ApprovalStep copyWith({
    String? approverName,
    String? status,
    DateTime? approvedAt,
    String? comments,
  }) {
    return ApprovalStep(
      stepNumber: stepNumber,
      approverRole: approverRole,
      approverName: approverName ?? this.approverName,
      status: status ?? this.status,
      approvedAt: approvedAt ?? this.approvedAt,
      comments: comments ?? this.comments,
    );
  }

  Map<String, dynamic> toJson() => {
        'stepNumber': stepNumber,
        'approverRole': approverRole,
        'approverName': approverName,
        'status': status,
        'approvedAt': approvedAt?.toIso8601String(),
        'comments': comments,
      };

  factory ApprovalStep.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      if (v is DateTime) return v;
      if (v is Timestamp) return v.toDate();
      return null;
    }

    return ApprovalStep(
      stepNumber: json['stepNumber'] as int? ?? 0,
      approverRole: json['approverRole']?.toString() ?? '',
      approverName: json['approverName']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      approvedAt: parseDate(json['approvedAt']),
      comments: json['comments']?.toString(),
    );
  }
}

class ChangeRequest {
  final String id;
  final String displayId;
  final String title;
  final String type;
  final String impact;
  final String status;
  final String requester;
  final String? projectId;
  final String? description;
  final String? justification;
  final String? attachmentUrl;
  final String? attachmentName;
  final DateTime requestDate;
  final DateTime createdAt;

  // Structured impact analysis
  final String? scopeChange;
  final int? scheduleDelay;
  final double? costChange;
  final String? riskExposure;
  final String? contractImpact;
  final String? agileImpact;

  // ── P2.3: Computed impact on project controls ──
  /// Control Account IDs affected by this change request.
  final List<String> affectedControlAccountIds;
  /// WBS element IDs affected by this change request.
  final List<String> affectedWbsIds;
  /// CBS element IDs affected by this change request.
  final List<String> affectedCbsIds;
  /// OBS element IDs affected by this change request.
  final List<String> affectedObsIds;
  /// Baseline version that this change request modifies.
  final String? baselineVersionId;
  /// Computed EVM impact: projected CPI change after this CR.
  final double? projectedCpiChange;
  /// Computed EVM impact: projected SPI change after this CR.
  final double? projectedSpiChange;
  /// Computed EVM impact: projected EAC change after this CR.
  final double? projectedEacChange;
  /// Whether EVM recalculation has been applied after approval.
  final bool evmRecalculated;

  // Multi-level approval
  final List<ApprovalStep> approvalSteps;

  ChangeRequest({
    required this.id,
    required this.displayId,
    required this.title,
    required this.type,
    required this.impact,
    required this.status,
    required this.requester,
    required this.requestDate,
    required this.createdAt,
    this.projectId,
    this.description,
    this.justification,
    this.attachmentUrl,
    this.attachmentName,
    this.scopeChange,
    this.scheduleDelay,
    this.costChange,
    this.riskExposure,
    this.contractImpact,
    this.agileImpact,
    List<String>? affectedControlAccountIds,
    List<String>? affectedWbsIds,
    List<String>? affectedCbsIds,
    List<String>? affectedObsIds,
    this.baselineVersionId,
    this.projectedCpiChange,
    this.projectedSpiChange,
    this.projectedEacChange,
    this.evmRecalculated = false,
    List<ApprovalStep>? approvalSteps,
  }) : approvalSteps = approvalSteps ?? [],
       affectedControlAccountIds = affectedControlAccountIds ?? [],
       affectedWbsIds = affectedWbsIds ?? [],
       affectedCbsIds = affectedCbsIds ?? [],
       affectedObsIds = affectedObsIds ?? [];

  ChangeRequest copyWith({
    String? title,
    String? type,
    String? impact,
    String? status,
    String? description,
    String? justification,
    String? attachmentUrl,
    String? attachmentName,
    String? scopeChange,
    int? scheduleDelay,
    double? costChange,
    String? riskExposure,
    String? contractImpact,
    String? agileImpact,
    List<String>? affectedControlAccountIds,
    List<String>? affectedWbsIds,
    List<String>? affectedCbsIds,
    List<String>? affectedObsIds,
    String? baselineVersionId,
    double? projectedCpiChange,
    double? projectedSpiChange,
    double? projectedEacChange,
    bool? evmRecalculated,
    List<ApprovalStep>? approvalSteps,
  }) {
    return ChangeRequest(
      id: id,
      displayId: displayId,
      title: title ?? this.title,
      type: type ?? this.type,
      impact: impact ?? this.impact,
      status: status ?? this.status,
      requester: requester,
      requestDate: requestDate,
      createdAt: createdAt,
      projectId: projectId,
      description: description ?? this.description,
      justification: justification ?? this.justification,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      scopeChange: scopeChange ?? this.scopeChange,
      scheduleDelay: scheduleDelay ?? this.scheduleDelay,
      costChange: costChange ?? this.costChange,
      riskExposure: riskExposure ?? this.riskExposure,
      contractImpact: contractImpact ?? this.contractImpact,
      agileImpact: agileImpact ?? this.agileImpact,
      affectedControlAccountIds: affectedControlAccountIds ?? List.from(this.affectedControlAccountIds),
      affectedWbsIds: affectedWbsIds ?? List.from(this.affectedWbsIds),
      affectedCbsIds: affectedCbsIds ?? List.from(this.affectedCbsIds),
      affectedObsIds: affectedObsIds ?? List.from(this.affectedObsIds),
      baselineVersionId: baselineVersionId ?? this.baselineVersionId,
      projectedCpiChange: projectedCpiChange ?? this.projectedCpiChange,
      projectedSpiChange: projectedSpiChange ?? this.projectedSpiChange,
      projectedEacChange: projectedEacChange ?? this.projectedEacChange,
      evmRecalculated: evmRecalculated ?? this.evmRecalculated,
      approvalSteps: approvalSteps ?? List.from(this.approvalSteps),
    );
  }

  static ChangeRequest fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseDate(dynamic value, {required String fieldName}) {
      try {
        if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
        if (value is Timestamp) return value.toDate();
        if (value is DateTime) return value;
        if (value is String) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) return parsed;
        }
        if (value is int) {
          if (value > 100000000000) {
            return DateTime.fromMillisecondsSinceEpoch(value);
          }
          return DateTime.fromMillisecondsSinceEpoch(value * 1000);
        }
        if (value is Map) {
          final seconds = value['seconds'] ?? value['_seconds'];
          final nanos = value['nanoseconds'] ?? value['_nanoseconds'] ?? 0;
          final intSec = seconds is int
              ? seconds
              : (seconds is double
                  ? seconds.toInt()
                  : (seconds is num ? seconds.toInt() : 0));
          final intNanos = nanos is int
              ? nanos
              : (nanos is double
                  ? nanos.toInt()
                  : (nanos is num ? nanos.toInt() : 0));
          if (intSec != 0 || intNanos != 0) {
            return DateTime.fromMillisecondsSinceEpoch(
                intSec * 1000 + (intNanos ~/ 1000000));
          }
        }
      } catch (e, st) {
        debugPrint('ChangeRequest parse error for field "$fieldName": $e\n$st');
      }
      debugPrint(
          'ChangeRequest warning: Unrecognized date value for "$fieldName" -> $value (type: ${value.runtimeType}), defaulting to now');
      return DateTime.now();
    }

    final requestDate =
        parseDate(data['requestDate'], fieldName: 'requestDate');
    final createdAt = parseDate(data['createdAt'], fieldName: 'createdAt');

    List<ApprovalStep> parseApprovalSteps(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((m) => ApprovalStep.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    return ChangeRequest(
      id: doc.id,
      displayId: data['displayId'] as String? ??
          'CR-${doc.id.substring(0, 6).toUpperCase()}',
      title: data['title'] as String? ?? '',
      type: data['type'] as String? ?? '',
      impact: data['impact'] as String? ?? '',
      status: data['status'] as String? ?? 'Pending',
      requester: data['requester'] as String? ?? '',
      projectId: data['projectId'] as String?,
      description: data['description'] as String?,
      justification: data['justification'] as String?,
      attachmentUrl: data['attachmentUrl'] as String?,
      attachmentName: data['attachmentName'] as String?,
      requestDate: requestDate,
      createdAt: createdAt,
      scopeChange: data['scopeChange']?.toString(),
      scheduleDelay: data['scheduleDelay'] is int
          ? data['scheduleDelay'] as int
          : (data['scheduleDelay'] is num
              ? (data['scheduleDelay'] as num).toInt()
              : null),
      costChange: data['costChange'] is num
          ? (data['costChange'] as num).toDouble()
          : null,
      riskExposure: data['riskExposure']?.toString(),
      contractImpact: data['contractImpact']?.toString(),
      agileImpact: data['agileImpact']?.toString(),
      affectedControlAccountIds: (data['affectedControlAccountIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      affectedWbsIds: (data['affectedWbsIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      affectedCbsIds: (data['affectedCbsIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      affectedObsIds: (data['affectedObsIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      baselineVersionId: data['baselineVersionId']?.toString(),
      projectedCpiChange: data['projectedCpiChange'] is num
          ? (data['projectedCpiChange'] as num).toDouble()
          : null,
      projectedSpiChange: data['projectedSpiChange'] is num
          ? (data['projectedSpiChange'] as num).toDouble()
          : null,
      projectedEacChange: data['projectedEacChange'] is num
          ? (data['projectedEacChange'] as num).toDouble()
          : null,
      evmRecalculated: data['evmRecalculated'] == true,
      approvalSteps: parseApprovalSteps(data['approvalSteps']),
    );
  }

  Map<String, dynamic> toMapForCreate() {
    return {
      'displayId': displayId,
      'title': title,
      'type': type,
      'impact': impact,
      'status': status,
      'requester': requester,
      'projectId': projectId,
      'description': description,
      'justification': justification,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'requestDate': Timestamp.fromDate(requestDate),
      'createdAt': FieldValue.serverTimestamp(),
      'scopeChange': scopeChange,
      'scheduleDelay': scheduleDelay,
      'costChange': costChange,
      'riskExposure': riskExposure,
      'contractImpact': contractImpact,
      'agileImpact': agileImpact,
      'affectedControlAccountIds': affectedControlAccountIds,
      'affectedWbsIds': affectedWbsIds,
      'affectedCbsIds': affectedCbsIds,
      'affectedObsIds': affectedObsIds,
      'baselineVersionId': baselineVersionId,
      'projectedCpiChange': projectedCpiChange,
      'projectedSpiChange': projectedSpiChange,
      'projectedEacChange': projectedEacChange,
      'evmRecalculated': evmRecalculated,
      'approvalSteps':
          approvalSteps.map((s) => s.toJson()).toList(),
    };
  }
}

class ChangeRequestService {
  static CollectionReference<Map<String, dynamic>>? _tryCollection() {
    try {
      return FirebaseFirestore.instance.collection('change_requests');
    } catch (e, st) {
      debugPrint('ChangeRequestService: Firestore not ready ($e)\n$st');
      return null;
    }
  }

  static CollectionReference<Map<String, dynamic>> _requireCollection() {
    final col = _tryCollection();
    if (col == null) {
      throw StateError('Firestore is not initialized');
    }
    return col;
  }

  static Future<String> _generateDisplayId(String? projectId) async {
    Query query = _requireCollection();
    if (projectId != null) {
      query = query.where('projectId', isEqualTo: projectId);
    }
    final snapshot = await query.count().get();
    final next = (snapshot.count ?? 0) + 1;
    String pad(int n) => n.toString().padLeft(3, '0');
    return 'CR-${pad(next)}';
  }

  static Future<String> createChangeRequest({
    required String title,
    required String type,
    required String impact,
    required String status,
    required String requester,
    required DateTime requestDate,
    String? projectId,
    String? description,
    String? justification,
    String? attachmentUrl,
    String? attachmentName,
    String? scopeChange,
    int? scheduleDelay,
    double? costChange,
    String? riskExposure,
    String? contractImpact,
    String? agileImpact,
    // ── P2.3: Affected project controls elements ──
    List<String>? affectedControlAccountIds,
    List<String>? affectedWbsIds,
    List<String>? affectedCbsIds,
    List<String>? affectedObsIds,
    String? baselineVersionId,
    List<ApprovalStep>? approvalSteps,
  }) async {
    final displayId = await _generateDisplayId(projectId);
    final data = {
      'displayId': displayId,
      'title': title,
      'type': type,
      'impact': impact,
      'status': status,
      'requester': requester,
      'projectId': projectId,
      'description': description,
      'justification': justification,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'requestDate': Timestamp.fromDate(requestDate),
      'createdAt': FieldValue.serverTimestamp(),
      'scopeChange': scopeChange,
      'scheduleDelay': scheduleDelay,
      'costChange': costChange,
      'riskExposure': riskExposure,
      'contractImpact': contractImpact,
      'agileImpact': agileImpact,
      // P2.3: Persist affected elements and baseline linkage
      'affectedControlAccountIds': affectedControlAccountIds ?? [],
      'affectedWbsIds': affectedWbsIds ?? [],
      'affectedCbsIds': affectedCbsIds ?? [],
      'affectedObsIds': affectedObsIds ?? [],
      'baselineVersionId': baselineVersionId,
      'evmRecalculated': false,
      'approvalSteps':
          (approvalSteps ?? []).map((s) => s.toJson()).toList(),
    };
    final ref = await _requireCollection().add(data);
    return ref.id;
  }

  static Stream<List<ChangeRequest>> streamChangeRequests(
      {String? projectId}) {
    final col = _tryCollection();
    if (col == null) {
      return Stream<List<ChangeRequest>>.value(const []);
    }
    try {
      Query<Map<String, dynamic>> query = col;
      if (projectId != null && projectId.isNotEmpty) {
        query = query.where('projectId', isEqualTo: projectId);
      }

      return query.snapshots().handleError((error) {
        debugPrint('ChangeRequestService: stream error ($error)');
      }).map((s) {
        final list =
            s.docs.map((d) => ChangeRequest.fromDoc(d)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    } catch (e, st) {
      debugPrint('ChangeRequestService: stream failure ($e)\n$st');
      return Stream<List<ChangeRequest>>.value(const []);
    }
  }

  static Future<void> updateChangeRequest(ChangeRequest request) async {
    try {
      await _requireCollection().doc(request.id).update({
        'title': request.title,
        'type': request.type,
        'impact': request.impact,
        'status': request.status,
        'requester': request.requester,
        'description': request.description,
        'justification': request.justification,
        'attachmentUrl': request.attachmentUrl,
        'attachmentName': request.attachmentName,
        'requestDate': Timestamp.fromDate(request.requestDate),
        'scopeChange': request.scopeChange,
        'scheduleDelay': request.scheduleDelay,
        'costChange': request.costChange,
        'riskExposure': request.riskExposure,
        'contractImpact': request.contractImpact,
        'agileImpact': request.agileImpact,
        'affectedControlAccountIds': request.affectedControlAccountIds,
        'affectedWbsIds': request.affectedWbsIds,
        'affectedCbsIds': request.affectedCbsIds,
        'affectedObsIds': request.affectedObsIds,
        'baselineVersionId': request.baselineVersionId,
        'projectedCpiChange': request.projectedCpiChange,
        'projectedSpiChange': request.projectedSpiChange,
        'projectedEacChange': request.projectedEacChange,
        'evmRecalculated': request.evmRecalculated,
        'approvalSteps':
            request.approvalSteps.map((s) => s.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('Failed to update change request (${request.id}): $e');
      rethrow;
    }
  }

  static Future<void> deleteChangeRequest(String id) async {
    try {
      await _requireCollection().doc(id).delete();
    } catch (e) {
      debugPrint('Failed to delete change request ($id): $e');
    }
  }

  /// Approve a specific approval step and auto-update the overall CR status.
  ///
  /// ── P2.3: When all steps are approved, automatically computes the projected
  /// EVM impact and stores it on the CR. The caller should then call
  /// [applyEvmImpact] to propagate the impact to control accounts.
  static Future<void> approveStep({
    required ChangeRequest request,
    required int stepNumber,
    required String approverName,
    String? comments,
    List<Map<String, dynamic>>? controlAccountSnapshots,
  }) async {
    final updatedSteps = request.approvalSteps.map((step) {
      if (step.stepNumber == stepNumber) {
        return step.copyWith(
          approverName: approverName,
          status: 'approved',
          approvedAt: DateTime.now(),
          comments: comments,
        );
      }
      return step;
    }).toList();

    final allApproved = updatedSteps.every((s) => s.status == 'approved');
    final anyRejected = updatedSteps.any((s) => s.status == 'rejected');
    final newStatus = allApproved
        ? 'Approved'
        : anyRejected
            ? 'Rejected'
            : 'Pending';

    // ── P2.3: Compute EVM impact upon full approval ──
    double? projectedCpiChange;
    double? projectedSpiChange;
    double? projectedEacChange;

    if (allApproved && controlAccountSnapshots != null) {
      final impact = computeEvmImpact(
        request: request,
        controlAccountSnapshots: controlAccountSnapshots,
      );
      projectedCpiChange = impact['projectedCpiChange'];
      projectedSpiChange = impact['projectedSpiChange'];
      projectedEacChange = impact['projectedEacChange'];
    }

    final updated = request.copyWith(
      status: newStatus,
      approvalSteps: updatedSteps,
      projectedCpiChange: projectedCpiChange,
      projectedSpiChange: projectedSpiChange,
      projectedEacChange: projectedEacChange,
    );
    await updateChangeRequest(updated);
  }

  /// ── P2.3: Apply an approved CR's impact to the affected control accounts ──
  /// Updates each affected control account's actual cost by the CR's cost change
  /// (distributed evenly across affected CAs), adds the CR ID to each CA's
  /// [affectedChangeRequestIds], and marks the CR as [evmRecalculated].
  ///
  /// Returns the list of updated [ControlAccount] objects. The caller is
  /// responsible for persisting these to Firestore.
  ///
  /// After calling this, run [ControlAccountService.recalculateAll] to
  /// recompute EVM metrics for the updated control accounts.
  static List<Map<String, dynamic>> applyEvmImpact({
    required ChangeRequest request,
    required List<Map<String, dynamic>> controlAccountSnapshots,
  }) {
    if (request.status != 'Approved') {
      throw StateError('Cannot apply EVM impact to a non-approved CR');
    }

    final costDelta = request.costChange ?? 0;
    final affectedIds = request.affectedControlAccountIds.toSet();

    // Distribute cost delta evenly across affected CAs
    final affectedSnapshots = controlAccountSnapshots
        .where((ca) => affectedIds.contains(ca['id']?.toString()))
        .toList();
    final perCaDelta =
        affectedSnapshots.isNotEmpty ? costDelta / affectedSnapshots.length : 0;

    final updatedSnapshots = <Map<String, dynamic>>[];
    for (final ca in controlAccountSnapshots) {
      final caId = ca['id']?.toString() ?? '';
      if (affectedIds.contains(caId)) {
        final currentAc = (ca['actualCost'] as num?)?.toDouble() ?? 0;
        final existingCrIds = (ca['affectedChangeRequestIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        updatedSnapshots.add({
          ...ca,
          'actualCost': currentAc + perCaDelta,
          'affectedChangeRequestIds': [
            ...existingCrIds,
            request.id,
          ],
        });
      } else {
        updatedSnapshots.add(ca);
      }
    }

    return updatedSnapshots;
  }

  /// Reject a specific approval step.
  static Future<void> rejectStep({
    required ChangeRequest request,
    required int stepNumber,
    required String approverName,
    String? comments,
  }) async {
    final updatedSteps = request.approvalSteps.map((step) {
      if (step.stepNumber == stepNumber) {
        return step.copyWith(
          approverName: approverName,
          status: 'rejected',
          approvedAt: DateTime.now(),
          comments: comments,
        );
      }
      return step;
    }).toList();

    final updated = request.copyWith(
      status: 'Rejected',
      approvalSteps: updatedSteps,
    );
    await updateChangeRequest(updated);
  }

  /// ── P2.3: Compute the projected EVM impact of a change request ──
  /// Returns a map with projected CPI, SPI, and EAC changes based on
  /// the CR's cost and schedule impact applied to the affected control accounts.
  ///
  /// If [request.affectedControlAccountIds] is non-empty, only those control
  /// accounts are considered; otherwise all snapshots are used (legacy compat).
  static Map<String, double> computeEvmImpact({
    required ChangeRequest request,
    required List<Map<String, dynamic>> controlAccountSnapshots,
  }) {
    // Filter to affected CAs if specified; otherwise use all (backward compat)
    List<Map<String, dynamic>> relevantSnapshots;
    if (request.affectedControlAccountIds.isNotEmpty) {
      final affectedSet = request.affectedControlAccountIds.toSet();
      relevantSnapshots = controlAccountSnapshots
          .where((ca) => affectedSet.contains(ca['id']?.toString()))
          .toList();
      // Fallback: if no matching CAs found, use all snapshots
      if (relevantSnapshots.isEmpty) {
        relevantSnapshots = controlAccountSnapshots;
      }
    } else {
      relevantSnapshots = controlAccountSnapshots;
    }

    double totalBac = 0, totalEv = 0, totalAc = 0, totalPv = 0;
    for (final ca in relevantSnapshots) {
      totalBac += (ca['bac'] as num?)?.toDouble() ?? 0;
      totalEv += (ca['earnedValue'] as num?)?.toDouble() ?? 0;
      totalAc += (ca['actualCost'] as num?)?.toDouble() ?? 0;
      // PV from snapshot if stored, otherwise estimate as 50% of BAC
      final pvFromSnapshot = (ca['plannedValue'] as num?)?.toDouble();
      totalPv += pvFromSnapshot ??
          ((ca['bac'] as num?)?.toDouble() ?? 0) * 0.5;
    }

    // Apply CR cost impact to actual cost
    final costDelta = request.costChange ?? 0;
    final newAc = totalAc + costDelta;

    // Apply CR schedule impact (delays reduce SPI)
    // Heuristic: each day of delay degrades SPI proportionally,
    // capped at 30% to prevent unrealistic projections
    final scheduleDelayDays = (request.scheduleDelay ?? 0).toDouble();
    final scheduleImpactFactor = scheduleDelayDays > 0
        ? 1.0 - (scheduleDelayDays / 365).clamp(0, 0.3)
        : 1.0;

    // Current EVM metrics
    final currentCpi = totalAc > 0 ? totalEv / totalAc : 1.0;
    final currentSpi = totalPv > 0 ? totalEv / totalPv : 1.0;
    final currentEac = currentCpi > 0 ? totalBac / currentCpi : totalBac;

    // Projected EVM metrics after CR impact
    final projectedCpi = newAc > 0 ? totalEv / newAc : 1.0;
    final projectedSpi = currentSpi * scheduleImpactFactor;
    final projectedEac = projectedCpi > 0 ? totalBac / projectedCpi : totalBac;

    return {
      'projectedCpiChange': projectedCpi - currentCpi,
      'projectedSpiChange': projectedSpi - currentSpi,
      'projectedEacChange': projectedEac - currentEac,
    };
  }
}
