/// Project Controls — ChangeNotifier state management
///
/// Serves as the single source of truth for project controls.
/// Persists all data to Firestore via ProjectControlsFirestoreService.
library;

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/project_controls/models/project_controls_models.dart';
import 'package:ndu_project/project_controls/services/project_controls_firestore_service.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart' as ce_models;

String get _currentUser => FirebaseAuth.instance.currentUser?.email ?? 'you@ndu.project';

class ProjectControlsProvider extends ChangeNotifier {
  ProjectControlsState _state = const ProjectControlsState(
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
  /// from cost lines (one control account per unique WBS reference).
  void syncFromCostEstimate(ce_models.CostEstimate? estimate) {
    if (estimate == null) return;

    final bac = estimate.totals.totalAuthorizedBudget;
    if (bac <= 0) return;

    // Existing control accounts are allocated from their WBS-linked cost
    // lines first. This preserves the chain WBS → Schedule → Cost → Control
    // instead of spreading the budget across unrelated work packages.
    if (_state.workPackages.isNotEmpty) {
      final currentTotal = _state.totalOriginalBudget;
      final costByWbsRef = <String, double>{};
      for (final line in estimate.lines) {
        final ref = line.wbsRef?.trim() ?? '';
        if (ref.isEmpty) continue;
        costByWbsRef[ref] = (costByWbsRef[ref] ?? 0) + line.total;
      }
      final tracedCostTotal =
          costByWbsRef.values.fold<double>(0, (a, b) => a + b);
      final allLineTotal =
          estimate.lines.fold<double>(0, (sum, line) => sum + line.total);

      if (tracedCostTotal > 0) {
        // Allocate contingency/reserve proportionally so the control-account
        // roll-up reconciles to BAC once every cost line has a WBS reference.
        // Unlinked lines deliberately remain unallocated and visible as a
        // lifecycle traceability gap.
        final authorizationScale = allLineTotal > 0 ? bac / allLineTotal : 1.0;
        final updatedWPs = _state.workPackages.map((wp) {
          final tracedCost = costByWbsRef[wp.wbsCode];
          if (tracedCost == null) return wp;
          final allocated = tracedCost * authorizationScale;
          return wp.copyWith(
            originalBudget: allocated,
            currentBudget: allocated,
            plannedValue: allocated,
          );
        }).toList();
        _state = _state.copyWith(workPackages: updatedWPs);
        _addAudit(
          'BAC',
          '\$${currentTotal.toStringAsFixed(0)}',
          '\$${bac.toStringAsFixed(0)}',
          'Budget allocated to control accounts from WBS-linked cost lines',
        );
        notifyListeners();
        _saveToFirestore();
        for (final wp in updatedWPs) {
          ProjectControlsFirestoreService.instance.saveWorkPackage(wp);
        }
      } else if (currentTotal > 0 && (currentTotal - bac).abs() > 1) {
        // Legacy estimates may not have WBS references yet. Preserve their
        // established proportions until the user completes traceability.
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
      // Do not create an untraceable project-total control account. The
      // lifecycle UI keeps Controls blocked until costs reference the WBS.
      return;
    } else {
      // Seed one control account per WBS work package, rolling up all labor,
      // material, equipment, and subcontract cost lines sharing that WBS ref.
      final linesByWbs = <String, List<ce_models.CostLine>>{};
      for (final line in costLines) {
        linesByWbs.putIfAbsent(line.wbsRef!, () => []).add(line);
      }
      final wps = <WorkPackageControl>[];
      var index = 0;
      for (final entry in linesByWbs.entries) {
        final lines = entry.value;
        final line = lines.first;
        final workPackageCost =
            lines.fold<double>(0, (sum, item) => sum + item.total);
        wps.add(WorkPackageControl(
          id: 'wp_ce_${entry.key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}',
          wbsCode: entry.key,
          name: line.description.isNotEmpty
              ? line.description
              : line.subCategory.isNotEmpty
                  ? line.subCategory
                  : 'WBS ${entry.key}',
          scopeDescription: '${line.category.name} — ${line.subCategory}',
          deliverables: [],
          acceptanceCriteria: [],
          priority: 'Medium',
          status: 'Not Started',
          plannedStart: DateTime.now(),
          plannedFinish: DateTime.now().add(const Duration(days: 180)),
          percentComplete: 0,
          isCriticalPath: index == 0,
          remainingDuration: 180,
          floatDays: 10,
          originalBudget: workPackageCost,
          currentBudget: workPackageCost,
          committedCost: 0,
          actualCost: 0,
          earnedValue: 0,
          plannedValue: workPackageCost,
          progressMethod: ProgressMethod.physicalPercent,
        ));
        index++;
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

  /// Per Task 19: Pull schedule activities from the ScheduleProvider and
  /// merge them into Project Controls work packages so the Scope Tracking
  /// tab stays in sync with the Schedule. Activities that already have a
  /// matching work package (by scheduleActivityId) are updated in place;
  /// new activities become new work packages.
  void syncFromScheduleActivities(List<ScheduleActivityShim> activities) {
    if (activities.isEmpty) return;
    final existingByActivityId = {
      for (final wp in _state.workPackages)
        if (wp.scheduleActivityId != null) wp.scheduleActivityId!: wp,
    };
    final updated = <WorkPackageControl>[];
    var addedCount = 0;
    var updatedCount = 0;
    for (final act in activities) {
      final existing = existingByActivityId[act.id];
      if (existing != null) {
        // Update schedule-related fields only — preserve cost / scope data
        // entered directly in Project Controls.
        updated.add(existing.copyWith(
          plannedStart: act.plannedStart,
          plannedFinish: act.plannedFinish,
          actualStart: act.actualStart,
          actualFinish: act.actualFinish,
          percentComplete: act.percentComplete ?? existing.percentComplete,
          isCriticalPath: act.isCriticalPath,
        ));
        updatedCount++;
      } else {
        // New activity from Schedule → seed a new work package.
        updated.add(WorkPackageControl(
          id: 'wp_${act.id}',
          wbsCode: act.wbsCode ?? 'WP-${(updated.length + 1).toString().padLeft(3, '0')}',
          scheduleActivityId: act.id,
          name: act.name,
          scopeDescription: act.description ?? '',
          deliverables: const [],
          acceptanceCriteria: const [],
          priority: 'Medium',
          status: 'Not Started',
          plannedStart: act.plannedStart,
          plannedFinish: act.plannedFinish,
          actualStart: act.actualStart,
          actualFinish: act.actualFinish,
          percentComplete: act.percentComplete,
          isCriticalPath: act.isCriticalPath,
          originalBudget: 0,
          currentBudget: 0,
          committedCost: 0,
          actualCost: 0,
          earnedValue: 0,
          plannedValue: 0,
          progressMethod: ProgressMethod.physicalPercent,
        ));
        addedCount++;
      }
    }
    // Preserve any existing work packages that don't have a scheduleActivityId
    // (manually-created ones in PC).
    for (final wp in _state.workPackages) {
      if (wp.scheduleActivityId == null ||
          !existingByActivityId.containsKey(wp.scheduleActivityId)) {
        // Already added above if matched; otherwise keep.
        if (!updated.any((u) => u.id == wp.id)) {
          updated.add(wp);
        }
      }
    }
    _state = _state.copyWith(workPackages: updated);
    _addAudit('workPackages', '—', '+$addedCount new, ~$updatedCount updated',
        'Synced from Schedule');
    notifyListeners();
    _saveToFirestore();
  }

  void updateWorkPackage(String id, WorkPackageControl updated) {
    final oldWp = _state.workPackages.where((w) => w.id == id).firstOrNull;
if (oldWp == null) return;
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
    final updated = _state.changeRequests.where((cr) => cr.id == id).firstOrNull;
if (updated == null) return;
ProjectControlsFirestoreService.instance.saveChangeRequest(updated);
  }

  void approveChangeStep(String changeId) {
    final cr = _state.changeRequests.where((c) => c.id == changeId).firstOrNull;
if (cr == null) return;
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
    final updated = _state.changeRequests.where((c) => c.id == changeId).firstOrNull;
if (updated == null) return;
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
    final updated = _state.changeRequests.where((cr) => cr.id == id).firstOrNull;
if (updated == null) return;
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
        _state.risksAndIssues.where((r) => r.id == id).firstOrNull;
    if (existing == null) return;
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

/// Lightweight value object used by [ProjectControlsProvider.syncFromScheduleActivities]
/// to receive schedule activity data without creating a hard dependency on the
/// Schedule module's models. Callers convert their ScheduleActivity objects
/// into this shim before calling the sync method.
class ScheduleActivityShim {
  final String id;
  final String name;
  final String? description;
  final String? wbsCode;
  final DateTime? plannedStart;
  final DateTime? plannedFinish;
  final DateTime? actualStart;
  final DateTime? actualFinish;
  final double? percentComplete;
  final bool isCriticalPath;

  const ScheduleActivityShim({
    required this.id,
    required this.name,
    this.description,
    this.wbsCode,
    this.plannedStart,
    this.plannedFinish,
    this.actualStart,
    this.actualFinish,
    this.percentComplete,
    this.isCriticalPath = false,
  });
}
