/// Project Controls — Firestore persistence service
///
/// Stores all project controls data under:
///   projects/{projectId}/projectControls/{section}
///
/// Sections: workPackages, changeRequests, risks, resources,
///           baselines, scheduleVariances, auditTrail, reports
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/project_controls/models/project_controls_models.dart';

class ProjectControlsFirestoreService {
  ProjectControlsFirestoreService._();
  static final instance = ProjectControlsFirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get the current user's UID, or empty string if not signed in.
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Reference to the user's project controls root document.
  /// Structure: users/{uid}/projectControls/current
  DocumentReference<Map<String, dynamic>> get _root =>
      _db.collection('users').doc(_uid).collection('projectControls').doc('current');

  // ─── Load all data ──────────────────────────────────────────────────

  /// Load the full project controls state from Firestore.
  Future<ProjectControlsState> loadState() async {
    if (_uid.isEmpty) {
      return const ProjectControlsState(
        deliveryModel: DeliveryModel.waterfall,
        isBaselined: false,
        isExecutionActive: false,
        workPackages: [],
        changeRequests: [],
        baselineHistory: [],
        auditTrail: [],
      );
    }

    try {
      final rootDoc = await _root.get();
      final data = rootDoc.data();

      if (data == null || !rootDoc.exists) {
        return const ProjectControlsState(
          deliveryModel: DeliveryModel.waterfall,
          isBaselined: false,
          isExecutionActive: false,
          workPackages: [],
          changeRequests: [],
          baselineHistory: [],
          auditTrail: [],
        );
      }

      // Load subcollections in parallel
      final results = await Future.wait([
        _loadWorkPackages(),
        _loadChangeRequests(),
        _loadBaselineHistory(),
        _loadAuditTrail(),
        _loadScheduleVariances(),
        _loadRisksAndIssues(),
        _loadResourceAllocations(),
        _loadReports(),
      ]);

      return ProjectControlsState(
        deliveryModel: DeliveryModel.values.byName(
            data['deliveryModel'] as String? ?? 'waterfall'),
        isBaselined: data['isBaselined'] as bool? ?? false,
        isExecutionActive: data['isExecutionActive'] as bool? ?? false,
        workPackages: results[0] as List<WorkPackageControl>,
        changeRequests: results[1] as List<ChangeRequest>,
        baselineHistory: results[2] as List<BaselineSnapshot>,
        auditTrail: results[3] as List<AuditEntry>,
        scheduleVariances: results[4] as List<ScheduleVariance>,
        risksAndIssues: results[5] as List<RiskItem>,
        resourceAllocations: results[6] as List<ResourceAllocation>,
        reports: results[7] as List<ReportRecord>,
      );
    } catch (e) {
      debugPrint('[PC Firestore] loadState error: $e');
      return const ProjectControlsState(
        deliveryModel: DeliveryModel.waterfall,
        isBaselined: false,
        isExecutionActive: false,
        workPackages: [],
        changeRequests: [],
        baselineHistory: [],
        auditTrail: [],
      );
    }
  }

  // ─── Save root metadata ─────────────────────────────────────────────

  Future<void> saveRootMetadata({
    required DeliveryModel deliveryModel,
    required bool isBaselined,
    required bool isExecutionActive,
  }) async {
    if (_uid.isEmpty) return;
    try {
      await _root.set({
        'deliveryModel': deliveryModel.name,
        'isBaselined': isBaselined,
        'isExecutionActive': isExecutionActive,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PC Firestore] saveRootMetadata error: $e');
    }
  }

  // ─── Work Packages ──────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _wpCol =>
      _root.collection('workPackages');

  Future<List<WorkPackageControl>> _loadWorkPackages() async {
    try {
      final snap = await _wpCol.orderBy('wbsCode').get();
      return snap.docs.map(_wpFromDoc).toList();
    } catch (e) {
      debugPrint('[PC Firestore] load workPackages error: $e');
      return [];
    }
  }

  Future<void> saveWorkPackage(WorkPackageControl wp) async {
    if (_uid.isEmpty) return;
    try {
      await _wpCol.doc(wp.id).set(_wpToMap(wp), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PC Firestore] save workPackage error: $e');
    }
  }

  Future<void> deleteWorkPackage(String id) async {
    if (_uid.isEmpty) return;
    try {
      await _wpCol.doc(id).delete();
    } catch (e) {
      debugPrint('[PC Firestore] delete workPackage error: $e');
    }
  }

  Map<String, dynamic> _wpToMap(WorkPackageControl wp) => {
        'wbsCode': wp.wbsCode,
        'name': wp.name,
        'scopeDescription': wp.scopeDescription,
        'deliverables': wp.deliverables,
        'acceptanceCriteria': wp.acceptanceCriteria,
        'responsibleOrg': wp.responsibleOrg,
        'responsibleIndividual': wp.responsibleIndividual,
        'discipline': wp.discipline,
        'location': wp.location,
        'phase': wp.phase,
        'priority': wp.priority,
        'status': wp.status,
        'plannedStart': wp.plannedStart,
        'plannedFinish': wp.plannedFinish,
        'actualStart': wp.actualStart,
        'actualFinish': wp.actualFinish,
        'percentComplete': wp.percentComplete,
        'isCriticalPath': wp.isCriticalPath,
        'remainingDuration': wp.remainingDuration,
        'floatDays': wp.floatDays,
        'originalBudget': wp.originalBudget,
        'currentBudget': wp.currentBudget,
        'committedCost': wp.committedCost,
        'actualCost': wp.actualCost,
        'earnedValue': wp.earnedValue,
        'plannedValue': wp.plannedValue,
        'storyPoints': wp.storyPoints,
        'storyPointsCompleted': wp.storyPointsCompleted,
        'velocity': wp.velocity,
        'sprint': wp.sprint,
        'release': wp.release,
        'progressMethod': wp.progressMethod.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  WorkPackageControl _wpFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return WorkPackageControl(
      id: doc.id,
      wbsCode: d['wbsCode'] as String? ?? '',
      name: d['name'] as String? ?? '',
      scopeDescription: d['scopeDescription'] as String? ?? '',
      deliverables: List<String>.from(d['deliverables'] ?? []),
      acceptanceCriteria: List<String>.from(d['acceptanceCriteria'] ?? []),
      responsibleOrg: d['responsibleOrg'] as String?,
      responsibleIndividual: d['responsibleIndividual'] as String?,
      discipline: d['discipline'] as String?,
      location: d['location'] as String?,
      phase: d['phase'] as String?,
      priority: d['priority'] as String? ?? 'Medium',
      status: d['status'] as String? ?? 'Not Started',
      plannedStart: (d['plannedStart'] as Timestamp?)?.toDate(),
      plannedFinish: (d['plannedFinish'] as Timestamp?)?.toDate(),
      actualStart: (d['actualStart'] as Timestamp?)?.toDate(),
      actualFinish: (d['actualFinish'] as Timestamp?)?.toDate(),
      percentComplete: (d['percentComplete'] as num?)?.toDouble(),
      isCriticalPath: d['isCriticalPath'] as bool? ?? false,
      remainingDuration: (d['remainingDuration'] as num?)?.toDouble(),
      floatDays: (d['floatDays'] as num?)?.toDouble(),
      originalBudget: (d['originalBudget'] as num?)?.toDouble() ?? 0,
      currentBudget: (d['currentBudget'] as num?)?.toDouble() ?? 0,
      committedCost: (d['committedCost'] as num?)?.toDouble() ?? 0,
      actualCost: (d['actualCost'] as num?)?.toDouble() ?? 0,
      earnedValue: (d['earnedValue'] as num?)?.toDouble() ?? 0,
      plannedValue: (d['plannedValue'] as num?)?.toDouble() ?? 0,
      storyPoints: (d['storyPoints'] as num?)?.toDouble(),
      storyPointsCompleted: (d['storyPointsCompleted'] as num?)?.toDouble(),
      velocity: (d['velocity'] as num?)?.toDouble(),
      sprint: d['sprint'] as String?,
      release: d['release'] as String?,
      progressMethod: ProgressMethod.values.byName(
          d['progressMethod'] as String? ?? 'physicalPercent'),
    );
  }

  // ─── Change Requests ────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _crCol =>
      _root.collection('changeRequests');

  Future<List<ChangeRequest>> _loadChangeRequests() async {
    try {
      final snap = await _crCol.orderBy('dateSubmitted', descending: true).get();
      return snap.docs.map(_crFromDoc).toList();
    } catch (e) {
      debugPrint('[PC Firestore] load changeRequests error: $e');
      return [];
    }
  }

  Future<void> saveChangeRequest(ChangeRequest cr) async {
    if (_uid.isEmpty) return;
    try {
      await _crCol.doc(cr.id).set(_crToMap(cr), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PC Firestore] save changeRequest error: $e');
    }
  }

  Map<String, dynamic> _crToMap(ChangeRequest cr) => {
        'description': cr.description,
        'requestor': cr.requestor,
        'justification': cr.justification,
        'rootCause': cr.rootCause,
        'category': cr.category.name,
        'priority': cr.priority,
        'status': cr.status.name,
        'impact': {
          'scheduleImpactDays': cr.impact.scheduleImpactDays,
          'costImpactAmount': cr.impact.costImpactAmount,
          'scopeImpact': cr.impact.scopeImpact,
          'resourceImpact': cr.impact.resourceImpact,
          'procurementImpact': cr.impact.procurementImpact,
          'contractImpact': cr.impact.contractImpact,
          'riskImpact': cr.impact.riskImpact,
          'qualityImpact': cr.impact.qualityImpact,
          'safetyImpact': cr.impact.safetyImpact,
          'stakeholderImpact': cr.impact.stakeholderImpact,
          'fundingImpact': cr.impact.fundingImpact,
          'benefitsImpact': cr.impact.benefitsImpact,
          'dependenciesImpact': cr.impact.dependenciesImpact,
          'interfacesImpact': cr.impact.interfacesImpact,
        },
        'approval': cr.approval != null
            ? {
                'currentStepIndex': cr.approval!.currentStepIndex,
                'steps': cr.approval!.steps
                    .map((s) => {
                          'id': s.id,
                          'role': s.role.name,
                          'assigneeName': s.assigneeName,
                          'approved': s.approved,
                          'approvedAt': s.approvedAt,
                          'comments': s.comments,
                        })
                    .toList(),
              }
            : null,
        'dateSubmitted': cr.dateSubmitted,
        'approvedAt': cr.approvedAt,
        'implementedAt': cr.implementedAt,
        'isAgileRoutineRefinement': cr.isAgileRoutineRefinement,
        'affectedBaselines': cr.affectedBaselines,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  ChangeRequest _crFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final impactData = d['impact'] as Map<String, dynamic>?;
    final approvalData = d['approval'] as Map<String, dynamic>?;

    ApprovalWorkflow? approval;
    if (approvalData != null) {
      final stepsData = approvalData['steps'] as List?;
      final steps = stepsData?.map((s) {
        final step = s as Map<String, dynamic>;
        return ApprovalStep(
          id: step['id'] as String? ?? '',
          role: ApprovalRole.values.byName(step['role'] as String? ?? 'projectManager'),
          assigneeName: step['assigneeName'] as String?,
          approved: step['approved'] as bool? ?? false,
          approvedAt: (step['approvedAt'] as Timestamp?)?.toDate(),
          comments: step['comments'] as String?,
        );
      }).toList();
      if (steps != null) {
        approval = ApprovalWorkflow(
          steps: steps,
          currentStepIndex: approvalData['currentStepIndex'] as int? ?? 0,
        );
      }
    }

    return ChangeRequest(
      id: doc.id,
      description: d['description'] as String? ?? '',
      requestor: d['requestor'] as String? ?? '',
      justification: d['justification'] as String? ?? '',
      rootCause: d['rootCause'] as String?,
      category: ChangeCategory.values.byName(d['category'] as String? ?? 'scope'),
      priority: d['priority'] as String? ?? 'Medium',
      status: ChangeStatus.values.byName(d['status'] as String? ?? 'draft'),
      impact: ImpactAnalysis(
        scheduleImpactDays: (impactData?['scheduleImpactDays'] as num?)?.toDouble(),
        costImpactAmount: (impactData?['costImpactAmount'] as num?)?.toDouble(),
        scopeImpact: impactData?['scopeImpact'] as String?,
        resourceImpact: impactData?['resourceImpact'] as String?,
        procurementImpact: impactData?['procurementImpact'] as String?,
        contractImpact: impactData?['contractImpact'] as String?,
        riskImpact: impactData?['riskImpact'] as String?,
        qualityImpact: impactData?['qualityImpact'] as String?,
        safetyImpact: impactData?['safetyImpact'] as String?,
        stakeholderImpact: impactData?['stakeholderImpact'] as String?,
        fundingImpact: impactData?['fundingImpact'] as String?,
        benefitsImpact: impactData?['benefitsImpact'] as String?,
        dependenciesImpact: impactData?['dependenciesImpact'] as String?,
        interfacesImpact: impactData?['interfacesImpact'] as String?,
      ),
      approval: approval,
      dateSubmitted: (d['dateSubmitted'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: (d['approvedAt'] as Timestamp?)?.toDate(),
      implementedAt: (d['implementedAt'] as Timestamp?)?.toDate(),
      isAgileRoutineRefinement: d['isAgileRoutineRefinement'] as bool? ?? false,
      affectedBaselines: List<String>.from(d['affectedBaselines'] ?? []),
    );
  }

  // ─── Baseline History ───────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _blCol =>
      _root.collection('baselineHistory');

  Future<List<BaselineSnapshot>> _loadBaselineHistory() async {
    try {
      final snap = await _blCol.orderBy('version').get();
      return snap.docs.map(_blFromDoc).toList();
    } catch (e) {
      debugPrint('[PC Firestore] load baselineHistory error: $e');
      return [];
    }
  }

  Future<void> saveBaseline(BaselineSnapshot bl) async {
    if (_uid.isEmpty) return;
    try {
      final wpsData = bl.workPackages.map(_wpToMap).toList();
      await _blCol.doc('v${bl.version}').set({
        'version': bl.version,
        'lockedAt': bl.lockedAt,
        'lockedBy': bl.lockedBy,
        'type': bl.type.name,
        'workPackages': wpsData,
        'totalBudget': bl.totalBudget,
        'baselineStartDate': bl.baselineStartDate,
        'baselineFinishDate': bl.baselineFinishDate,
        'reason': bl.reason,
        'scopeHash': bl.scopeHash,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PC Firestore] save baseline error: $e');
    }
  }

  BaselineSnapshot _blFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final wpsRaw = d['workPackages'] as List? ?? [];
    final wps = wpsRaw.map((wpData) {
      final wp = wpData as Map<String, dynamic>;
      return WorkPackageControl(
        id: wp['id'] as String? ?? doc.id,
        wbsCode: wp['wbsCode'] as String? ?? '',
        name: wp['name'] as String? ?? '',
        scopeDescription: wp['scopeDescription'] as String? ?? '',
        deliverables: List<String>.from(wp['deliverables'] ?? []),
        acceptanceCriteria: List<String>.from(wp['acceptanceCriteria'] ?? []),
        priority: wp['priority'] as String? ?? 'Medium',
        status: wp['status'] as String? ?? 'Not Started',
        plannedStart: (wp['plannedStart'] as Timestamp?)?.toDate(),
        plannedFinish: (wp['plannedFinish'] as Timestamp?)?.toDate(),
        actualStart: (wp['actualStart'] as Timestamp?)?.toDate(),
        actualFinish: (wp['actualFinish'] as Timestamp?)?.toDate(),
        percentComplete: (wp['percentComplete'] as num?)?.toDouble(),
        isCriticalPath: wp['isCriticalPath'] as bool? ?? false,
        remainingDuration: (wp['remainingDuration'] as num?)?.toDouble(),
        floatDays: (wp['floatDays'] as num?)?.toDouble(),
        originalBudget: (wp['originalBudget'] as num?)?.toDouble() ?? 0,
        currentBudget: (wp['currentBudget'] as num?)?.toDouble() ?? 0,
        committedCost: (wp['committedCost'] as num?)?.toDouble() ?? 0,
        actualCost: (wp['actualCost'] as num?)?.toDouble() ?? 0,
        earnedValue: (wp['earnedValue'] as num?)?.toDouble() ?? 0,
        plannedValue: (wp['plannedValue'] as num?)?.toDouble() ?? 0,
        progressMethod: ProgressMethod.values.byName(
            wp['progressMethod'] as String? ?? 'physicalPercent'),
      );
    }).toList();

    return BaselineSnapshot(
      version: d['version'] as int? ?? 0,
      lockedAt: (d['lockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lockedBy: d['lockedBy'] as String? ?? '',
      type: BaselineType.values.byName(d['type'] as String? ?? 'scope'),
      workPackages: wps,
      totalBudget: (d['totalBudget'] as num?)?.toDouble() ?? 0,
      baselineStartDate: (d['baselineStartDate'] as Timestamp?)?.toDate(),
      baselineFinishDate: (d['baselineFinishDate'] as Timestamp?)?.toDate(),
      reason: d['reason'] as String?,
      scopeHash: d['scopeHash'] as String?,
    );
  }

  // ─── Audit Trail ────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _auditCol =>
      _root.collection('auditTrail');

  Future<List<AuditEntry>> _loadAuditTrail() async {
    try {
      final snap = await _auditCol.orderBy('timestamp', descending: true).limit(500).get();
      return snap.docs.map(_auditFromDoc).toList();
    } catch (e) {
      debugPrint('[PC Firestore] load auditTrail error: $e');
      return [];
    }
  }

  Future<void> saveAuditEntry(AuditEntry entry) async {
    if (_uid.isEmpty) return;
    try {
      await _auditCol.doc(entry.id).set({
        'user': entry.user,
        'timestamp': entry.timestamp,
        'field': entry.field,
        'previousValue': entry.previousValue,
        'newValue': entry.newValue,
        'reason': entry.reason,
        'changeRequestId': entry.changeRequestId,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PC Firestore] save auditEntry error: $e');
    }
  }

  AuditEntry _auditFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return AuditEntry(
      id: doc.id,
      user: d['user'] as String? ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      field: d['field'] as String? ?? '',
      previousValue: d['previousValue'] as String? ?? '',
      newValue: d['newValue'] as String? ?? '',
      reason: d['reason'] as String?,
      changeRequestId: d['changeRequestId'] as String?,
    );
  }

  // ─── Schedule Variances ─────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _svCol =>
      _root.collection('scheduleVariances');

  Future<List<ScheduleVariance>> _loadScheduleVariances() async {
    try {
      final snap = await _svCol.get();
      return snap.docs.map((doc) {
        final d = doc.data();
        return ScheduleVariance(
          workPackageId: d['workPackageId'] as String? ?? '',
          plannedStart: (d['plannedStart'] as Timestamp?)?.toDate(),
          actualStart: (d['actualStart'] as Timestamp?)?.toDate(),
          plannedFinish: (d['plannedFinish'] as Timestamp?)?.toDate(),
          actualFinish: (d['actualFinish'] as Timestamp?)?.toDate(),
          floatDays: (d['floatDays'] as num?)?.toDouble() ?? 0,
          delayReason: d['delayReason'] as String? ?? '',
          compressionStrategy: CompressionStrategy.values.byName(
              d['compressionStrategy'] as String? ?? 'none'),
        );
      }).toList();
    } catch (e) {
      debugPrint('[PC Firestore] load scheduleVariances error: $e');
      return [];
    }
  }

  Future<void> saveScheduleVariance(ScheduleVariance sv) async {
    if (_uid.isEmpty) return;
    try {
      await _svCol.doc(sv.workPackageId).set({
        'workPackageId': sv.workPackageId,
        'plannedStart': sv.plannedStart,
        'actualStart': sv.actualStart,
        'plannedFinish': sv.plannedFinish,
        'actualFinish': sv.actualFinish,
        'floatDays': sv.floatDays,
        'delayReason': sv.delayReason,
        'compressionStrategy': sv.compressionStrategy.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PC Firestore] save scheduleVariance error: $e');
    }
  }

  // ─── Risks & Issues ─────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _riskCol =>
      _root.collection('risksAndIssues');

  Future<List<RiskItem>> _loadRisksAndIssues() async {
    try {
      final snap = await _riskCol.get();
      return snap.docs.map((doc) {
        final d = doc.data();
        return RiskItem(
          id: doc.id,
          description: d['description'] as String? ?? '',
          probability: d['probability'] as int? ?? 1,
          impact: d['impact'] as int? ?? 1,
          owner: d['owner'] as String? ?? '',
          mitigation: d['mitigation'] as String? ?? '',
          status: RiskStatus.values.byName(d['status'] as String? ?? 'open'),
          isIssue: d['isIssue'] as bool? ?? false,
        );
      }).toList();
    } catch (e) {
      debugPrint('[PC Firestore] load risksAndIssues error: $e');
      return [];
    }
  }

  Future<void> saveRiskItem(RiskItem item) async {
    if (_uid.isEmpty) return;
    try {
      await _riskCol.doc(item.id).set({
        'description': item.description,
        'probability': item.probability,
        'impact': item.impact,
        'owner': item.owner,
        'mitigation': item.mitigation,
        'status': item.status.name,
        'isIssue': item.isIssue,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PC Firestore] save riskItem error: $e');
    }
  }

  Future<void> deleteRiskItem(String id) async {
    if (_uid.isEmpty) return;
    try {
      await _riskCol.doc(id).delete();
    } catch (e) {
      debugPrint('[PC Firestore] delete riskItem error: $e');
    }
  }

  // ─── Resource Allocations ───────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _resCol =>
      _root.collection('resourceAllocations');

  Future<List<ResourceAllocation>> _loadResourceAllocations() async {
    try {
      final snap = await _resCol.get();
      return snap.docs.map((doc) {
        final d = doc.data();
        return ResourceAllocation(
          resourceName: d['resourceName'] as String? ?? '',
          discipline: ResourceDiscipline.values.byName(
              d['discipline'] as String? ?? 'pm'),
          weeklyHours: List<double>.from(
              (d['weeklyHours'] as List?)?.map((e) => (e as num).toDouble()) ?? []),
          capacityHoursPerWeek:
              (d['capacityHoursPerWeek'] as num?)?.toDouble() ?? 40,
        );
      }).toList();
    } catch (e) {
      debugPrint('[PC Firestore] load resourceAllocations error: $e');
      return [];
    }
  }

  Future<void> saveResourceAllocation(ResourceAllocation ra) async {
    if (_uid.isEmpty) return;
    try {
      await _resCol.doc(ra.resourceName).set({
        'resourceName': ra.resourceName,
        'discipline': ra.discipline.name,
        'weeklyHours': ra.weeklyHours,
        'capacityHoursPerWeek': ra.capacityHoursPerWeek,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PC Firestore] save resourceAllocation error: $e');
    }
  }

  // ─── Reports ────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _rptCol =>
      _root.collection('reports');

  Future<List<ReportRecord>> _loadReports() async {
    try {
      final snap = await _rptCol.orderBy('generatedAt', descending: true).get();
      return snap.docs.map((doc) {
        final d = doc.data();
        return ReportRecord(
          id: doc.id,
          type: ReportType.values.byName(d['type'] as String? ?? 'costVariance'),
          generatedAt: (d['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          dateRangeStart: (d['dateRangeStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
          dateRangeEnd: (d['dateRangeEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
          generatedBy: d['generatedBy'] as String? ?? '',
          summaryText: d['summaryText'] as String? ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('[PC Firestore] load reports error: $e');
      return [];
    }
  }

  Future<void> saveReport(ReportRecord report) async {
    if (_uid.isEmpty) return;
    try {
      await _rptCol.doc(report.id).set({
        'type': report.type.name,
        'generatedAt': report.generatedAt,
        'dateRangeStart': report.dateRangeStart,
        'dateRangeEnd': report.dateRangeEnd,
        'generatedBy': report.generatedBy,
        'summaryText': report.summaryText,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PC Firestore] save report error: $e');
    }
  }
}
