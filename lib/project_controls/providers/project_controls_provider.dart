/// Project Controls — ChangeNotifier state management
///
/// Serves as the single source of truth for project controls.
/// Persists all data to Firestore via ProjectControlsFirestoreService.

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/project_controls/models/project_controls_models.dart';
import 'package:ndu_project/project_controls/services/project_controls_firestore_service.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart' as ce_models;

String get _currentUser => FirebaseAuth.instance.currentUser?.email ?? 'you@ndu.project';

class ProjectControlsProvider extends ChangeNotifier {
  ProjectControlsState _state = ProjectControlsState(
    deliveryModel: DeliveryModel.waterfall,
    isBaselined: false,
    isExecutionActive: false,
    workPackages: [],
    changeRequests: [],
    baselineHistory: [],
    auditTrail: [],
  );

  ProjectControlsState get state => _state;

  bool _loaded = false;

  ProjectControlsProvider() {
    _loadFromFirestore();
  }

  bool get isLoaded => _loaded;

  // ─── Firestore persistence ─────────────────────────────────────────
  Future<void> _loadFromFirestore() async {
    try {
      final firestoreState =
          await ProjectControlsFirestoreService.instance.loadState();
      _state = firestoreState;
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[PC Provider] Firestore load error: $e');
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveToFirestore() async {
    try {
      await ProjectControlsFirestoreService.instance.saveRootMetadata(
        deliveryModel: _state.deliveryModel,
        isBaselined: _state.isBaselined,
        isExecutionActive: _state.isExecutionActive,
      );
    } catch (e) {
      debugPrint('[PC Provider] Firestore save error: $e');
    }
  }

  /// Force-reload from Firestore (e.g. after sign-in or pull-to-refresh).
  Future<void> reloadFromFirestore() async {
    await _loadFromFirestore();
  }

  // ─── Setup ───────────────────────────────────────────────────────────
  void setDeliveryModel(DeliveryModel model) {
    _state = _state.copyWith(deliveryModel: model);
    notifyListeners();
    _saveToFirestore();
  }

  /// Sync the BAC (Budget at Completion) from the Cost Estimate module.
  ///
  /// This ties the Project Controls dashboard to the Cost Estimate module:
  /// the total authorized budget from the cost estimate becomes the BAC
  /// for EVM calculations. If work packages don't exist yet, seed them
  /// from cost lines (one work package per cost line with a WBS ref).
  void syncFromCostEstimate(ce_models.CostEstimate? estimate) {
    if (estimate == null) return;

    final bac = estimate.totals.totalAuthorizedBudget;
    if (bac <= 0) return;

    // If we already have work packages, just update the total budget
    // by scaling the original budgets proportionally to match the new BAC.
    if (_state.workPackages.isNotEmpty) {
      final currentTotal = _state.totalOriginalBudget;
      if (currentTotal > 0 && (currentTotal - bac).abs() > 1) {
        final scale = bac / currentTotal;
        final updatedWPs = _state.workPackages.map((wp) {
          return wp.copyWith(
            originalBudget: wp.originalBudget * scale,
            currentBudget: wp.originalBudget * scale,
          );
        }).toList();
        _state = _state.copyWith(workPackages: updatedWPs);
        _addAudit('BAC', '\$${currentTotal.toStringAsFixed(0)}',
            '\$${bac.toStringAsFixed(0)}',
            'BAC synced from Cost Estimate (total authorized budget)');
        notifyListeners();
        _saveToFirestore();
      }
      return;
    }

    // No work packages yet — seed from cost lines that have WBS references.
    final costLines = estimate.lines.where((l) =>
        l.wbsRef != null && l.wbsRef!.isNotEmpty).toList();

    if (costLines.isEmpty) {
      // No WBS-linked cost lines — just set a single work package with the total BAC
      _state = _state.copyWith(
        workPackages: [
          WorkPackageControl(
            id: 'wp_ce_total',
            wbsCode: '—',
            name: 'Total Project (from Cost Estimate)',
            scopeDescription: 'Auto-synced from Cost Estimate module',
            deliverables: [],
            acceptanceCriteria: [],
            priority: 'Medium',
            status: 'Not Started',
            plannedStart: DateTime.now(),
            plannedFinish: DateTime.now().add(const Duration(days: 365)),
            percentComplete: 0,
            isCriticalPath: false,
            remainingDuration: 365,
            floatDays: 0,
            originalBudget: bac,
            currentBudget: bac,
            committedCost: 0,
            actualCost: 0,
            earnedValue: 0,
            plannedValue: 0,
            progressMethod: ProgressMethod.physicalPercent,
          ),
        ],
      );
    } else {
      // Seed one work package per WBS-linked cost line
      final wps = <WorkPackageControl>[];
      for (int i = 0; i < costLines.length; i++) {
        final line = costLines[i];
        wps.add(WorkPackageControl(
          id: 'wp_ce_${line.id}',
          wbsCode: line.wbsRef ?? '—',
          name: line.description.isNotEmpty
              ? line.description
              : line.subCategory.isNotEmpty
                  ? line.subCategory
                  : 'Cost Line ${i + 1}',
          scopeDescription: '${line.category.name} — ${line.subCategory}',
          deliverables: [],
          acceptanceCriteria: [],
          priority: 'Medium',
          status: 'Not Started',
          plannedStart: DateTime.now(),
          plannedFinish: DateTime.now().add(const Duration(days: 180)),
          percentComplete: 0,
          isCriticalPath: i == 0,
          remainingDuration: 180,
          floatDays: 10,
          originalBudget: line.total,
          currentBudget: line.total,
          committedCost: 0,
          actualCost: 0,
          earnedValue: 0,
          plannedValue: line.total,
          progressMethod: ProgressMethod.physicalPercent,
        ));
      }
      _state = _state.copyWith(workPackages: wps);
    }

    _addAudit('BAC', '—', '\$${bac.toStringAsFixed(0)}',
        'BAC synced from Cost Estimate (${estimate.lines.length} cost lines, \$$bac total)');
    notifyListeners();
    _saveToFirestore();
    for (final wp in _state.workPackages) {
      ProjectControlsFirestoreService.instance.saveWorkPackage(wp);
    }
  }

  void activateExecution() {
    _state = _state.copyWith(isExecutionActive: true);
    notifyListeners();
    _saveToFirestore();
  }

  // ─── Work Packages ──────────────────────────────────────────────────
  void addWorkPackage(WorkPackageControl wp) {
    _state = _state.copyWith(workPackages: [..._state.workPackages, wp]);
    _addAudit('workPackages', '—', wp.name, 'Work package added');
    notifyListeners();
    _saveToFirestore();
    ProjectControlsFirestoreService.instance.saveWorkPackage(wp);
  }

  void updateWorkPackage(String id, WorkPackageControl updated) {
    final oldWp = _state.workPackages.firstWhere((w) => w.id == id);
    _state = _state.copyWith(
      workPackages: _state.workPackages
          .map((w) => w.id == id ? updated : w)
          .toList(),
    );
    if (oldWp.actualCost != updated.actualCost) {
      _addAudit('actualCost.$id', '${oldWp.actualCost}',
          '${updated.actualCost}', 'Actual cost updated');
    }
    if (oldWp.percentComplete != updated.percentComplete) {
      _addAudit('percentComplete.$id', '${oldWp.percentComplete}',
          '${updated.percentComplete}', 'Progress updated');
    }
    notifyListeners();
    _saveToFirestore();
    ProjectControlsFirestoreService.instance.saveWorkPackage(updated);
  }

  // ─── Change Management ──────────────────────────────────────────────

  /// Submit a new change request.
  /// For Waterfall: ALL scope changes require formal MoC.
  /// For Agile: routine backlog refinement is tracked in audit only;
  /// controlled baseline changes (new Epics, budget increases, etc.) require formal workflow.
  void submitChangeRequest(ChangeRequest cr) {
    _state = _state.copyWith(changeRequests: [..._state.changeRequests, cr]);
    _addAudit('changeRequest', '—', cr.id,
        'Change request submitted: ${cr.description}');
    notifyListeners();
    _saveToFirestore();
    ProjectControlsFirestoreService.instance.saveChangeRequest(cr);
  }

  void updateChangeStatus(String id, ChangeStatus status) {
    _state = _state.copyWith(
      changeRequests: _state.changeRequests
          .map((cr) => cr.id == id
              ? cr.copyWith(
                  status: status,
                  approvedAt: status == ChangeStatus.approved
                      ? DateTime.now()
                      : cr.approvedAt,
                  implementedAt: status == ChangeStatus.implemented
                      ? DateTime.now()
                      : cr.implementedAt,
                )
              : cr)
          .toList(),
    );
    _addAudit('changeStatus.$id', '', status.label,
        'Change request status updated to ${status.label}');
    notifyListeners();
    _saveToFirestore();
    final updated = _state.changeRequests.firstWhere((cr) => cr.id == id);
    ProjectControlsFirestoreService.instance.saveChangeRequest(updated);
  }

  void approveChangeStep(String changeId) {
    final cr = _state.changeRequests.firstWhere((c) => c.id == changeId);
    if (cr.approval == null) return;
    final steps = cr.approval!.steps;
    final currentIdx = cr.approval!.currentStepIndex;
    if (currentIdx >= steps.length) return;

    final updatedSteps = steps.asMap().map((i, s) => MapEntry(
        i,
        i == currentIdx
            ? ApprovalStep(
                id: s.id,
                role: s.role,
                assigneeName: s.assigneeName,
                approved: true,
                approvedAt: DateTime.now(),
                comments: s.comments,
              )
            : s)).values.toList();

    final newIdx = currentIdx + 1;
    final allApproved = updatedSteps.every((s) => s.approved);

    final updatedWorkflow = ApprovalWorkflow(
      steps: updatedSteps,
      currentStepIndex: newIdx,
    );

    _state = _state.copyWith(
      changeRequests: _state.changeRequests
          .map((c) => c.id == changeId
              ? c.copyWith(
                  approval: updatedWorkflow,
                  status: allApproved
                      ? ChangeStatus.approved
                      : ChangeStatus.underReview,
                  approvedAt: allApproved ? DateTime.now() : c.approvedAt,
                )
              : c)
          .toList(),
    );
    _addAudit('changeApproval.$changeId', 'step $currentIdx',
        allApproved ? 'ALL APPROVED' : 'step $newIdx',
        'Change approval step ${currentIdx + 1} approved');
    notifyListeners();
    _saveToFirestore();
    final updated = _state.changeRequests.firstWhere((c) => c.id == changeId);
    ProjectControlsFirestoreService.instance.saveChangeRequest(updated);
  }

  void rejectChangeRequest(String id, String reason) {
    _state = _state.copyWith(
      changeRequests: _state.changeRequests
          .map((cr) => cr.id == id
              ? cr.copyWith(status: ChangeStatus.rejected)
              : cr)
          .toList(),
    );
    _addAudit('changeRejection.$id', '', 'REJECTED',
        'Change request rejected: $reason');
    notifyListeners();
    _saveToFirestore();
    final updated = _state.changeRequests.firstWhere((cr) => cr.id == id);
    ProjectControlsFirestoreService.instance.saveChangeRequest(updated);
  }

  // ─── Baseline Management ────────────────────────────────────────────
  void lockBaseline(BaselineType type, {String? reason}) {
    final baseline = BaselineSnapshot(
      version: _state.baselineHistory.length + 1,
      lockedAt: DateTime.now(),
      lockedBy: _currentUser,
      type: type,
      workPackages: List.from(_state.workPackages),
      totalBudget: _state.totalOriginalBudget,
      reason: reason ?? 'Manual baseline lock',
    );
    _state = _state.copyWith(
      isBaselined: true,
      baselineHistory: [..._state.baselineHistory, baseline],
    );
    _addAudit('baseline.${type.name}', '', 'v${baseline.version}',
        '${type.label} locked at version ${baseline.version}${reason != null ? ' — $reason' : ''}');
    notifyListeners();
    _saveToFirestore();
    ProjectControlsFirestoreService.instance.saveBaseline(baseline);
  }

  /// Convenience wrapper that explicitly creates a snapshot with a reason.
  void createBaselineSnapshot(BaselineType type, String reason) {
    lockBaseline(type, reason: reason);
  }

  /// Restore the work-package set + total budget from a prior baseline
  /// version.  Logs a rollback audit entry.  Does not delete subsequent
  /// baseline history entries (they remain as an audit record).
  void rollbackToBaseline(int version) {
    final baseline = _state.baselineHistory
        .cast<BaselineSnapshot?>()
        .firstWhere((b) => b?.version == version, orElse: () => null);
    if (baseline == null) return;
    final previousWpCount = _state.workPackages.length;
    _state = _state.copyWith(
      workPackages: List.from(baseline.workPackages),
      isBaselined: true,
    );
    _addAudit('baseline.rollback', 'v$version', 'current',
        'Rolled back to baseline v$version — restored ${baseline.workPackages.length} work packages (was $previousWpCount), budget \$${baseline.totalBudget}');
    notifyListeners();
    _saveToFirestore();
    for (final wp in _state.workPackages) {
      ProjectControlsFirestoreService.instance.saveWorkPackage(wp);
    }
  }

  // ─── Schedule Control ───────────────────────────────────────────────
  void addScheduleVariance(ScheduleVariance sv) {
    _state = _state.copyWith(
      scheduleVariances: [..._state.scheduleVariances, sv],
    );
    _addAudit('scheduleVariance.${sv.workPackageId}', '—', 'created',
        'Schedule variance record added for ${sv.workPackageId}');
    notifyListeners();
    _saveToFirestore();
    ProjectControlsFirestoreService.instance.saveScheduleVariance(sv);
  }

  void updateScheduleVariance(String workPackageId, ScheduleVariance updated) {
    final existing = _state.scheduleVariances
        .any((sv) => sv.workPackageId == workPackageId);
    _state = _state.copyWith(
      scheduleVariances: existing
          ? _state.scheduleVariances
              .map((sv) =>
                  sv.workPackageId == workPackageId ? updated : sv)
              .toList()
          : [..._state.scheduleVariances, updated],
    );
    _addAudit('scheduleVariance.$workPackageId', 'updated',
        updated.compressionStrategy.label,
        'Schedule variance updated — strategy: ${updated.compressionStrategy.label}, reason: "${updated.delayReason}"');
    notifyListeners();
    _saveToFirestore();
    ProjectControlsFirestoreService.instance.saveScheduleVariance(updated);
  }

  void setCompressionStrategy(
      String workPackageId, CompressionStrategy strategy) {
    final idx =
        _state.scheduleVariances.indexWhere((sv) => sv.workPackageId == workPackageId);
    if (idx == -1) return;
    final old = _state.scheduleVariances[idx];
    final updated = old.copyWith(compressionStrategy: strategy);
    final newList = List<ScheduleVariance>.from(_state.scheduleVariances);
    newList[idx] = updated;
    _state = _state.copyWith(scheduleVariances: newList);
    _addAudit('scheduleVariance.$workPackageId.compression',
        old.compressionStrategy.label,
        strategy.label,
        'Compression strategy set to ${strategy.label} for $workPackageId');
    notifyListeners();
    _saveToFirestore();
    ProjectControlsFirestoreService.instance.saveScheduleVariance(updated);
  }

  void setDelayReason(String workPackageId, String reason) {
    final idx =
        _state.scheduleVariances.indexWhere((sv) => sv.workPackageId == workPackageId);
    if (idx == -1) return;
    final updated =
        _state.scheduleVariances[idx].copyWith(delayReason: reason);
    final newList = List<ScheduleVariance>.from(_state.scheduleVariances);
    newList[idx] = updated;
    _state = _state.copyWith(scheduleVariances: newList);
    _addAudit('scheduleVariance.$workPackageId.delayReason', '',
        reason.isEmpty ? '(cleared)' : reason,
        'Delay reason recorded for $workPackageId');
    notifyListeners();
    _saveToFirestore();
    ProjectControlsFirestoreService.instance.saveScheduleVariance(updated);
  }

  // ─── Risk & Issues ──────────────────────────────────────────────────
  void addRiskItem(RiskItem item) {
    _state = _state.copyWith(risksAndIssues: [..._state.risksAndIssues, item]);
    _addAudit(item.isIssue ? 'issue.${item.id}' : 'risk.${item.id}', '—',
        item.status.label,
        '${item.isIssue ? "Issue" : "Risk"} ${item.id} added: ${item.description}');
    notifyListeners();
    _saveToFirestore();
    ProjectControlsFirestoreService.instance.saveRiskItem(item);
  }

  void updateRiskItem(String id, RiskItem updated) {
    _state = _state.copyWith(
      risksAndIssues: _state.risksAndIssues
          .map((r) => r.id == id ? updated : r)
          .toList(),
    );
    _addAudit('risk.$id', '', updated.status.label,
        'Risk/issue $id updated — status: ${updated.status.label}, owner: ${updated.owner}');
    notifyListeners();
    _saveToFirestore();
    ProjectControlsFirestoreService.instance.saveRiskItem(updated);
  }

  void closeRiskItem(String id) {
    final existing =
        _state.risksAndIssues.firstWhere((r) => r.id == id);
    updateRiskItem(id, existing.copyWith(status: RiskStatus.closed));
  }

  // ─── Resource Control ───────────────────────────────────────────────
  void addResourceAllocation(ResourceAllocation ra) {
    _state = _state.copyWith(
      resourceAllocations: [..._state.resourceAllocations, ra],
    );
    _addAudit('resource.${ra.resourceName}', '—', 'added',
        'Resource ${ra.resourceName} (${ra.discipline.label}) added');
    notifyListeners();
    _saveToFirestore();
    ProjectControlsFirestoreService.instance.saveResourceAllocation(ra);
  }

  void updateResourceAllocation(
      String resourceName, ResourceAllocation updated) {
    final existing =
        _state.resourceAllocations.any((r) => r.resourceName == resourceName);
    _state = _state.copyWith(
      resourceAllocations: existing
          ? _state.resourceAllocations
              .map((r) => r.resourceName == resourceName ? updated : r)
              .toList()
          : [..._state.resourceAllocations, updated],
    );
    _addAudit('resource.$resourceName', 'updated',
        '${updated.weeklyHours.length}w',
        'Resource allocation updated for $resourceName');
    notifyListeners();
    _saveToFirestore();
    ProjectControlsFirestoreService.instance.saveResourceAllocation(updated);
  }

  // ─── Reporting ──────────────────────────────────────────────────────
  void generateReport(ReportType type, DateTime start, DateTime end,
      {String? summaryOverride}) {
    final summary = summaryOverride ?? _buildDefaultReportSummary(type, start, end);
    final report = ReportRecord(
      id: 'rpt_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      generatedAt: DateTime.now(),
      dateRangeStart: start,
      dateRangeEnd: end,
      generatedBy: _currentUser,
      summaryText: summary,
    );
    _state = _state.copyWith(reports: [..._state.reports, report]);
    _addAudit('report.${type.name}', '—', report.id,
        '${type.label} generated (${start.day}/${start.month}–${end.day}/${end.month})');
    notifyListeners();
    _saveToFirestore();
    ProjectControlsFirestoreService.instance.saveReport(report);
  }

  String _buildDefaultReportSummary(
      ReportType type, DateTime start, DateTime end) {
    final rangeLabel =
        '${start.day}/${start.month}/${start.year} – ${end.day}/${end.month}/${end.year}';
    switch (type) {
      case ReportType.costVariance:
        final cv = _state.totalEarnedValue - _state.totalActualCost;
        return 'Cost Variance Report ($rangeLabel)\n'
            'BAC: \$${(_state.totalOriginalBudget / 1000000).toStringAsFixed(2)}M • '
            'AC: \$${(_state.totalActualCost / 1000000).toStringAsFixed(2)}M • '
            'EV: \$${(_state.totalEarnedValue / 1000000).toStringAsFixed(2)}M\n'
            'CV: \$${(cv / 1000000).toStringAsFixed(2)}M • CPI: ${_state.portfolioCPI.toStringAsFixed(2)} • '
            'EAC: \$${(_state.portfolioEAC / 1000000).toStringAsFixed(2)}M';
      case ReportType.scheduleVariance:
        final sv = _state.totalEarnedValue - _state.totalPlannedValue;
        return 'Schedule Variance Report ($rangeLabel)\n'
            'PV: \$${(_state.totalPlannedValue / 1000000).toStringAsFixed(2)}M • '
            'EV: \$${(_state.totalEarnedValue / 1000000).toStringAsFixed(2)}M\n'
            'SV: \$${(sv / 1000000).toStringAsFixed(2)}M • SPI: ${_state.portfolioSPI.toStringAsFixed(2)}\n'
            'Critical-path WPs: ${_state.criticalPathCount} • Delayed WPs: ${_state.delayedWorkPackagesCount}';
      case ReportType.evmForecast:
        return 'EVM Forecast Report ($rangeLabel)\n'
            'EAC: \$${(_state.portfolioEAC / 1000000).toStringAsFixed(2)}M • '
            'ETC: \$${((_state.portfolioEAC - _state.totalActualCost) / 1000000).toStringAsFixed(2)}M\n'
            'VAC: \$${(_state.portfolioVAC / 1000000).toStringAsFixed(2)}M • '
            'Avg progress: ${_state.avgPercentComplete.round()}%';
      case ReportType.riskBurnDown:
        final open = _state.openRisks.length;
        final critical = _state.criticalRisksCount;
        return 'Risk Burn-down Report ($rangeLabel)\n'
            'Open risks: $open • Critical risks: $critical • Open issues: ${_state.openIssues.length}\n'
            'Realized risks: ${_state.risksAndIssues.where((r) => r.status == RiskStatus.realized).length} • '
            'Closed: ${_state.risksAndIssues.where((r) => r.status == RiskStatus.closed).length}';
      case ReportType.auditTrail:
        return 'Audit Trail Report ($rangeLabel)\n'
            'Total audit entries: ${_state.auditTrail.length} • '
            'Generated by $_currentUser\n'
            'Earliest: ${_state.auditTrail.isEmpty ? "—" : _state.auditTrail.first.timestamp} • '
            'Latest: ${_state.auditTrail.isEmpty ? "—" : _state.auditTrail.last.timestamp}';
      case ReportType.performanceSummary:
        return 'Performance Summary Report ($rangeLabel)\n'
            'Health score: ${_state.healthScore}/100 • CPI: ${_state.portfolioCPI.toStringAsFixed(2)} • '
            'SPI: ${_state.portfolioSPI.toStringAsFixed(2)}\n'
            'Work packages: ${_state.workPackages.length} • Open changes: ${_state.openChangeRequests}';
    }
  }

  // ─── Audit Trail ────────────────────────────────────────────────────
  void _addAudit(String field, String prev, String next, String reason) {
    final entry = AuditEntry(
      id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
      user: _currentUser,
      timestamp: DateTime.now(),
      field: field,
      previousValue: prev,
      newValue: next,
      reason: reason,
    );
    _state = _state.copyWith(auditTrail: [..._state.auditTrail, entry]);
    ProjectControlsFirestoreService.instance.saveAuditEntry(entry);
  }

  // ─── Scope Growth Detection ────────────────────────────────────────

  /// Detect unauthorized scope changes (activities added without approved change request)
  List<String> detectScopeGrowth() {
    final issues = <String>[];
    // Check for work packages with no corresponding approved change request
    for (final wp in _state.workPackages) {
      final hasApproval = _state.changeRequests.any((cr) =>
          cr.status == ChangeStatus.approved &&
          cr.description.toLowerCase().contains(wp.name.toLowerCase()));
      if (!hasApproval && wp.status == 'Added') {
        issues.add('${wp.wbsCode} ${wp.name} — added without approved change request');
      }
    }
    return issues;
  }

  // (seedDemoData removed — data now comes from Firestore)
}
