import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/launch_phase_models.dart';

class LaunchPhaseService {
  static final _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _launchCol(
          String projectId) =>
      _firestore
          .collection('projects')
          .doc(projectId)
          .collection('launch_phase');

  static Future<void> savePageData({
    required String projectId,
    required String pageKey,
    required Map<String, dynamic> data,
  }) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _launchCol(projectId)
          .doc(pageKey)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('LaunchPhaseService savePageData error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> loadPageData({
    required String projectId,
    required String pageKey,
  }) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _launchCol(projectId).doc(pageKey).get();
      if (!doc.exists || doc.data() == null) return null;
      return doc.data()!;
    } catch (e) {
      debugPrint('LaunchPhaseService loadPageData error: $e');
      return null;
    }
  }

  static List<T> parseList<T>(
    Map<String, dynamic>? data,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (data == null) return [];
    final raw = data[key];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ── Deliver Project Closure ────────────────────────────────
  static Future<void> saveDeliverProject({
    required String projectId,
    required List<LaunchScopeItem> scopeItems,
    required List<LaunchMilestone> milestones,
    required List<LaunchFollowUpItem> outstandingItems,
    required List<LaunchFollowUpItem> riskFollowUps,
    required LaunchClosureNotes closureNotes,
  }) async {
    await savePageData(
        projectId: projectId,
        pageKey: 'deliver_project_closure',
        data: {
          'scopeItems': scopeItems.map((e) => e.toJson()).toList(),
          'milestones': milestones.map((e) => e.toJson()).toList(),
          'outstandingItems': outstandingItems.map((e) => e.toJson()).toList(),
          'riskFollowUps': riskFollowUps.map((e) => e.toJson()).toList(),
          'closureNotes': closureNotes.toJson(),
        });
  }

  static Future<
      ({
        List<LaunchScopeItem> scopeItems,
        List<LaunchMilestone> milestones,
        List<LaunchFollowUpItem> outstandingItems,
        List<LaunchFollowUpItem> riskFollowUps,
        LaunchClosureNotes closureNotes,
      })> loadDeliverProject({required String projectId}) async {
    final data = await loadPageData(
        projectId: projectId, pageKey: 'deliver_project_closure');
    return (
      scopeItems: parseList(data, 'scopeItems', LaunchScopeItem.fromJson),
      milestones: parseList(data, 'milestones', LaunchMilestone.fromJson),
      outstandingItems:
          parseList(data, 'outstandingItems', LaunchFollowUpItem.fromJson),
      riskFollowUps:
          parseList(data, 'riskFollowUps', LaunchFollowUpItem.fromJson),
      closureNotes: data != null
          ? LaunchClosureNotes.fromJson(
              Map<String, dynamic>.from(data['closureNotes'] ?? {}))
          : LaunchClosureNotes(),
    );
  }

  // ── Transition to Production Team ───────────────────────────
  static Future<void> saveTransitionToProd({
    required String projectId,
    required List<LaunchTeamMember> teamRoster,
    required List<LaunchHandoverItem> handoverChecklist,
    required List<LaunchKnowledgeTransfer> knowledgeTransfers,
    required List<LaunchApproval> signOffs,
  }) async {
    await savePageData(
        projectId: projectId,
        pageKey: 'transition_to_prod_team',
        data: {
          'teamRoster': teamRoster.map((e) => e.toJson()).toList(),
          'handoverChecklist':
              handoverChecklist.map((e) => e.toJson()).toList(),
          'knowledgeTransfers':
              knowledgeTransfers.map((e) => e.toJson()).toList(),
          'signOffs': signOffs.map((e) => e.toJson()).toList(),
        });
  }

  static Future<
      ({
        List<LaunchTeamMember> teamRoster,
        List<LaunchHandoverItem> handoverChecklist,
        List<LaunchKnowledgeTransfer> knowledgeTransfers,
        List<LaunchApproval> signOffs,
      })> loadTransitionToProd({required String projectId}) async {
    final data = await loadPageData(
        projectId: projectId, pageKey: 'transition_to_prod_team');
    return (
      teamRoster: parseList(data, 'teamRoster', LaunchTeamMember.fromJson),
      handoverChecklist:
          parseList(data, 'handoverChecklist', LaunchHandoverItem.fromJson),
      knowledgeTransfers: parseList(
          data, 'knowledgeTransfers', LaunchKnowledgeTransfer.fromJson),
      signOffs: parseList(data, 'signOffs', LaunchApproval.fromJson),
    );
  }

  // ── Contract Close Out ──────────────────────────────────────
  static Future<void> saveContractCloseOut({
    required String projectId,
    required List<LaunchContractItem> contracts,
    required List<LaunchCloseOutStep> closeOutSteps,
    required List<LaunchApproval> signOffs,
    required List<LaunchFinancialMetric> financialSummary,
  }) async {
    await savePageData(
        projectId: projectId,
        pageKey: 'contract_close_out',
        data: {
          'contracts': contracts.map((e) => e.toJson()).toList(),
          'closeOutSteps': closeOutSteps.map((e) => e.toJson()).toList(),
          'signOffs': signOffs.map((e) => e.toJson()).toList(),
          'financialSummary': financialSummary.map((e) => e.toJson()).toList(),
        });
  }

  static Future<
      ({
        List<LaunchContractItem> contracts,
        List<LaunchCloseOutStep> closeOutSteps,
        List<LaunchApproval> signOffs,
        List<LaunchFinancialMetric> financialSummary,
      })> loadContractCloseOut({required String projectId}) async {
    final data =
        await loadPageData(projectId: projectId, pageKey: 'contract_close_out');
    return (
      contracts: parseList(data, 'contracts', LaunchContractItem.fromJson),
      closeOutSteps:
          parseList(data, 'closeOutSteps', LaunchCloseOutStep.fromJson),
      signOffs: parseList(data, 'signOffs', LaunchApproval.fromJson),
      financialSummary:
          parseList(data, 'financialSummary', LaunchFinancialMetric.fromJson),
    );
  }

  // ── Vendor Account Close Out ────────────────────────────────
  static Future<void> saveVendorAccountCloseOut({
    required String projectId,
    required List<LaunchVendorItem> vendors,
    required List<LaunchAccessItem> accessItems,
    required List<LaunchFollowUpItem> obligations,
    required List<LaunchFollowUpItem> closureChecklist,
  }) async {
    await savePageData(
        projectId: projectId,
        pageKey: 'vendor_account_close_out',
        data: {
          'vendors': vendors.map((e) => e.toJson()).toList(),
          'accessItems': accessItems.map((e) => e.toJson()).toList(),
          'obligations': obligations.map((e) => e.toJson()).toList(),
          'closureChecklist': closureChecklist.map((e) => e.toJson()).toList(),
        });
  }

  static Future<
      ({
        List<LaunchVendorItem> vendors,
        List<LaunchAccessItem> accessItems,
        List<LaunchFollowUpItem> obligations,
        List<LaunchFollowUpItem> closureChecklist,
      })> loadVendorAccountCloseOut({required String projectId}) async {
    final data = await loadPageData(
        projectId: projectId, pageKey: 'vendor_account_close_out');
    return (
      vendors: parseList(data, 'vendors', LaunchVendorItem.fromJson),
      accessItems: parseList(data, 'accessItems', LaunchAccessItem.fromJson),
      obligations: parseList(data, 'obligations', LaunchFollowUpItem.fromJson),
      closureChecklist:
          parseList(data, 'closureChecklist', LaunchFollowUpItem.fromJson),
    );
  }

  // ── Project Summary ─────────────────────────────────────────
  static Future<void> saveProjectSummary({
    required String projectId,
    required List<LaunchFinancialMetric> metrics,
    required List<LaunchHighlightItem> highlights,
    required List<LaunchFollowUpItem> topRisks,
    required List<LaunchFollowUpItem> next90Days,
    required LaunchClosureNotes summary,
  }) async {
    await savePageData(
        projectId: projectId,
        pageKey: 'summarize_account_risks',
        data: {
          'metrics': metrics.map((e) => e.toJson()).toList(),
          'highlights': highlights.map((e) => e.toJson()).toList(),
          'topRisks': topRisks.map((e) => e.toJson()).toList(),
          'next90Days': next90Days.map((e) => e.toJson()).toList(),
          'summary': summary.toJson(),
        });
  }

  static Future<
      ({
        List<LaunchFinancialMetric> metrics,
        List<LaunchHighlightItem> highlights,
        List<LaunchFollowUpItem> topRisks,
        List<LaunchFollowUpItem> next90Days,
        LaunchClosureNotes summary,
      })> loadProjectSummary({required String projectId}) async {
    final data = await loadPageData(
        projectId: projectId, pageKey: 'summarize_account_risks');
    return (
      metrics: parseList(data, 'metrics', LaunchFinancialMetric.fromJson),
      highlights: parseList(data, 'highlights', LaunchHighlightItem.fromJson),
      topRisks: parseList(data, 'topRisks', LaunchFollowUpItem.fromJson),
      next90Days: parseList(data, 'next90Days', LaunchFollowUpItem.fromJson),
      summary: data != null
          ? LaunchClosureNotes.fromJson(
              Map<String, dynamic>.from(data['summary'] ?? {}))
          : LaunchClosureNotes(),
    );
  }

  // ── Commerce Viability ──────────────────────────────────────
  static Future<void> saveCommerceViability({
    required String projectId,
    required List<LaunchWarrantyItem> warranties,
    required List<LaunchOpsCostItem> opsCosts,
    required List<LaunchFinancialMetric> financialMetrics,
    required List<LaunchFollowUpItem> recommendations,
    required LaunchClosureNotes decision,
  }) async {
    await savePageData(
        projectId: projectId,
        pageKey: 'commerce_viability',
        data: {
          'warranties': warranties.map((e) => e.toJson()).toList(),
          'opsCosts': opsCosts.map((e) => e.toJson()).toList(),
          'financialMetrics': financialMetrics.map((e) => e.toJson()).toList(),
          'recommendations': recommendations.map((e) => e.toJson()).toList(),
          'decision': decision.toJson(),
        });
  }

  static Future<
      ({
        List<LaunchWarrantyItem> warranties,
        List<LaunchOpsCostItem> opsCosts,
        List<LaunchFinancialMetric> financialMetrics,
        List<LaunchFollowUpItem> recommendations,
        LaunchClosureNotes decision,
      })> loadCommerceViability({required String projectId}) async {
    final data =
        await loadPageData(projectId: projectId, pageKey: 'commerce_viability');
    return (
      warranties: parseList(data, 'warranties', LaunchWarrantyItem.fromJson),
      opsCosts: parseList(data, 'opsCosts', LaunchOpsCostItem.fromJson),
      financialMetrics:
          parseList(data, 'financialMetrics', LaunchFinancialMetric.fromJson),
      recommendations:
          parseList(data, 'recommendations', LaunchFollowUpItem.fromJson),
      decision: data != null
          ? LaunchClosureNotes.fromJson(
              Map<String, dynamic>.from(data['decision'] ?? {}))
          : LaunchClosureNotes(),
    );
  }

  // ── Actual vs Planned Gap Analysis ──────────────────────────
  static Future<void> saveGapAnalysis({
    required String projectId,
    required List<LaunchGapItem> scopeGaps,
    required List<LaunchMilestoneVariance> milestoneVariances,
    required List<LaunchBudgetVariance> budgetVariances,
    required List<LaunchRootCauseItem> rootCauses,
    required List<LaunchFollowUpItem> followUpActions,
  }) async {
    await savePageData(
        projectId: projectId,
        pageKey: 'actual_vs_planned_gap_analysis',
        data: {
          'scopeGaps': scopeGaps.map((e) => e.toJson()).toList(),
          'milestoneVariances':
              milestoneVariances.map((e) => e.toJson()).toList(),
          'budgetVariances': budgetVariances.map((e) => e.toJson()).toList(),
          'rootCauses': rootCauses.map((e) => e.toJson()).toList(),
          'followUpActions': followUpActions.map((e) => e.toJson()).toList(),
        });
  }

  static Future<
      ({
        List<LaunchGapItem> scopeGaps,
        List<LaunchMilestoneVariance> milestoneVariances,
        List<LaunchBudgetVariance> budgetVariances,
        List<LaunchRootCauseItem> rootCauses,
        List<LaunchFollowUpItem> followUpActions,
      })> loadGapAnalysis({required String projectId}) async {
    final data = await loadPageData(
        projectId: projectId, pageKey: 'actual_vs_planned_gap_analysis');
    return (
      scopeGaps: parseList(data, 'scopeGaps', LaunchGapItem.fromJson),
      milestoneVariances: parseList(
          data, 'milestoneVariances', LaunchMilestoneVariance.fromJson),
      budgetVariances:
          parseList(data, 'budgetVariances', LaunchBudgetVariance.fromJson),
      rootCauses: parseList(data, 'rootCauses', LaunchRootCauseItem.fromJson),
      followUpActions:
          parseList(data, 'followUpActions', LaunchFollowUpItem.fromJson),
    );
  }

  // ── Project Close Out ───────────────────────────────────────
  static Future<void> saveProjectCloseOut({
    required String projectId,
    required List<LaunchCloseOutCheckItem> closeOutChecklist,
    required List<LaunchApproval> approvals,
    required List<LaunchArchiveItem> archive,
    required LaunchClosureNotes lessonsLearned,
  }) async {
    await savePageData(
        projectId: projectId,
        pageKey: 'project_close_out',
        data: {
          'closeOutChecklist':
              closeOutChecklist.map((e) => e.toJson()).toList(),
          'approvals': approvals.map((e) => e.toJson()).toList(),
          'archive': archive.map((e) => e.toJson()).toList(),
          'lessonsLearned': lessonsLearned.toJson(),
        });
  }

  static Future<
      ({
        List<LaunchCloseOutCheckItem> closeOutChecklist,
        List<LaunchApproval> approvals,
        List<LaunchArchiveItem> archive,
        LaunchClosureNotes lessonsLearned,
      })> loadProjectCloseOut({required String projectId}) async {
    final data =
        await loadPageData(projectId: projectId, pageKey: 'project_close_out');
    return (
      closeOutChecklist: parseList(
          data, 'closeOutChecklist', LaunchCloseOutCheckItem.fromJson),
      approvals: parseList(data, 'approvals', LaunchApproval.fromJson),
      archive: parseList(data, 'archive', LaunchArchiveItem.fromJson),
      lessonsLearned: data != null
          ? LaunchClosureNotes.fromJson(
              Map<String, dynamic>.from(data['lessonsLearned'] ?? {}))
          : LaunchClosureNotes(),
    );
  }

  // ── Demobilize Team ─────────────────────────────────────────
  static Future<void> saveDemobilizeTeam({
    required String projectId,
    required List<LaunchTeamMember> teamRoster,
    required List<LaunchKnowledgeTransfer> knowledgeTransfers,
    required List<LaunchFollowUpItem> vendorOffboarding,
    required List<LaunchCommunicationItem> communications,
    required LaunchClosureNotes debriefNotes,
  }) async {
    await savePageData(projectId: projectId, pageKey: 'demobilize_team', data: {
      'teamRoster': teamRoster.map((e) => e.toJson()).toList(),
      'knowledgeTransfers': knowledgeTransfers.map((e) => e.toJson()).toList(),
      'vendorOffboarding': vendorOffboarding.map((e) => e.toJson()).toList(),
      'communications': communications.map((e) => e.toJson()).toList(),
      'debriefNotes': debriefNotes.toJson(),
    });
  }

  static Future<
      ({
        List<LaunchTeamMember> teamRoster,
        List<LaunchKnowledgeTransfer> knowledgeTransfers,
        List<LaunchFollowUpItem> vendorOffboarding,
        List<LaunchCommunicationItem> communications,
        LaunchClosureNotes debriefNotes,
      })> loadDemobilizeTeam({required String projectId}) async {
    final data =
        await loadPageData(projectId: projectId, pageKey: 'demobilize_team');
    return (
      teamRoster: parseList(data, 'teamRoster', LaunchTeamMember.fromJson),
      knowledgeTransfers: parseList(
          data, 'knowledgeTransfers', LaunchKnowledgeTransfer.fromJson),
      vendorOffboarding:
          parseList(data, 'vendorOffboarding', LaunchFollowUpItem.fromJson),
      communications:
          parseList(data, 'communications', LaunchCommunicationItem.fromJson),
      debriefNotes: data != null
          ? LaunchClosureNotes.fromJson(
              Map<String, dynamic>.from(data['debriefNotes'] ?? {}))
          : LaunchClosureNotes(),
    );
  }

  // ── Cross-Phase Data Loaders ────────────────────────────────

  static Future<List<LaunchTeamMember>> loadExecutionStaffing(
      String projectId) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('staff_team')
          .get();
      if (!doc.exists) return [];
      final data = doc.data() ?? {};
      final rows = data['staffingRows'];
      if (rows is! List) return [];
      return rows
          .whereType<Map>()
          .map((r) {
            final m = Map<String, dynamic>.from(r);
            return LaunchTeamMember(
              name: m['role']?.toString() ?? '',
              role: m['roleDescription']?.toString() ?? '',
              contact: '',
              releaseStatus: m['status']?.toString() ?? 'Active',
            );
          })
          .where((m) => m.name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('LaunchPhaseService.loadExecutionStaffing error: $e');
      return [];
    }
  }

  static Future<List<LaunchContractItem>> loadExecutionContracts(
      String projectId) async {
    try {
      final snap = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('contracts')
          .get();
      return snap.docs
          .map((doc) {
            final m = doc.data();
            return LaunchContractItem(
              contractName:
                  m['name']?.toString() ?? m['title']?.toString() ?? '',
              vendor: m['contractorName']?.toString() ?? '',
              contractRef: doc.id,
              value:
                  (m['estimatedValue'] ?? m['estimatedCost'] ?? 0).toString(),
              closeOutStatus: m['statusLabel']?.toString() ??
                  m['status']?.toString() ??
                  'Open',
            );
          })
          .where((c) => c.contractName.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('LaunchPhaseService.loadExecutionContracts error: $e');
      return [];
    }
  }

  static Future<List<LaunchVendorItem>> loadExecutionVendors(
      String projectId) async {
    try {
      final snap = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('vendors')
          .get();
      return snap.docs
          .map((doc) {
            final m = doc.data();
            return LaunchVendorItem(
              vendorName: m['name']?.toString() ?? '',
              contractRef: m['contractId']?.toString() ?? '',
              accountStatus: m['status']?.toString() ?? 'Active',
            );
          })
          .where((v) => v.vendorName.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('LaunchPhaseService.loadExecutionVendors error: $e');
      return [];
    }
  }

  static Future<List<LaunchScopeItem>> loadScopeTrackingItems(
      String projectId) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('scope_tracking')
          .get();
      if (!doc.exists) return [];
      final data = doc.data() ?? {};
      final items = data['items'];
      if (items is! List) return [];
      return items
          .whereType<Map>()
          .map((r) {
            final m = Map<String, dynamic>.from(r);
            return LaunchScopeItem(
              deliverable: m['scopeItem']?.toString() ?? '',
              status: m['implementationStatus']?.toString() ?? 'Pending',
              notes: m['trackingNotes']?.toString() ?? '',
            );
          })
          .where((s) => s.deliverable.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('LaunchPhaseService.loadScopeTrackingItems error: $e');
      return [];
    }
  }

  static Future<List<LaunchTeamMember>> loadOpsTeamMembers(
      String projectId) async {
    final staff = await loadExecutionStaffing(projectId);
    return staff;
  }

  static Future<List<Map<String, dynamic>>> loadBudgetRows(String projectId) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('progress_tracking')
          .get();
      if (!doc.exists) return [];
      final data = doc.data() ?? {};
      final rows = data['budgetRows'];
      if (rows is! List) return [];
      return rows
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } catch (e) {
      debugPrint('LaunchPhaseService.loadBudgetRows error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> loadDeliverableRows(String projectId) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('progress_tracking')
          .get();
      if (!doc.exists) return [];
      final data = doc.data() ?? {};
      final rows = data['deliverableRows'];
      if (rows is! List) return [];
      return rows
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } catch (e) {
      debugPrint('LaunchPhaseService.loadDeliverableRows error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> loadRiskTrackingSnapshot(String projectId) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('risk_tracking')
          .get();
      if (!doc.exists) return {};
      final data = doc.data() ?? {};
      return data;
    } catch (e) {
      debugPrint('LaunchPhaseService.loadRiskTrackingSnapshot error: $e');
      return {};
    }
  }

  static Future<List<Map<String, String>>> loadCoreStakeholders(String projectId) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .get();
      if (!doc.exists) return [];
      final data = doc.data() ?? {};
      final raw = data['coreStakeholdersData'];
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((r) => r.map((k, v) => MapEntry(k.toString(), v.toString())))
          .toList();
    } catch (e) {
      debugPrint('LaunchPhaseService.loadCoreStakeholders error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> loadPlanningDeliverables(String projectId) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('planning_phase_entries')
          .doc('deliverables_roadmap')
          .get();
      if (!doc.exists) return [];
      final data = doc.data() ?? {};
      final rows = data['deliverables'];
      if (rows is! List) return [];
      return rows
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } catch (e) {
      debugPrint('LaunchPhaseService.loadPlanningDeliverables error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> loadPlanningSprints(String projectId) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('planning_phase_entries')
          .doc('deliverables_roadmap')
          .get();
      if (!doc.exists) return [];
      final data = doc.data() ?? {};
      final rows = data['sprints'];
      if (rows is! List) return [];
      return rows
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } catch (e) {
      debugPrint('LaunchPhaseService.loadPlanningSprints error: $e');
      return [];
    }
  }
}
