// ignore_for_file: avoid_print

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/models/project_data_model.dart'
    hide ScheduleActivity;
import 'package:ndu_project/project_controls/models/project_controls_models.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/services/project_lifecycle_service.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/services/scope_coverage_validator.dart';

/// ─── Phase 5: Integrated Baseline Review (IBR) gate ─────────────────
///
/// Per NDIA/ANSI/EIA-748 and PMI's Practice Standard for Earned Value
/// Management, an Integrated Baseline Review is a formal validation
/// that the Performance Measurement Baseline (PMB) is realistic,
/// complete, and internally consistent BEFORE execution begins.
///
/// In this application, the IBR gate combines three signals:
///   1. `ProjectLifecycleService.assess().evmReady` — confirms the
///      scope→wbs→schedule→resources→cost→controls chain is complete.
///   2. `ProjectLifecycleService.assess().fullyTracedWorkPackageCount`
///      equals `workPackageCount` — confirms every WBS leaf has
///      activities, dates, resources, cost, and a control account.
///   3. `ScopeCoverageValidator.validate(...).hundredPercentRuleSatisfied`
///      — confirms the 100% Rule: every scope item is in the WBS, and
///      every work-package WBS leaf has its dictionary entry.
///
/// When all three pass, the IBR is "passed" and the baseline may be
/// locked. Otherwise, the report lists the specific gaps that must be
/// closed before the PMB can be signed off.

enum IbrStatus { notAssessed, blocked, attention, passed }

class IbrCheckResult {
  final String checkId;
  final String label;
  final IbrStatus status;
  final String detail;
  final double completion; // 0–1

  const IbrCheckResult({
    required this.checkId,
    required this.label,
    required this.status,
    required this.detail,
    required this.completion,
  });
}

class IbrReport {
  final IbrStatus overallStatus;
  final List<IbrCheckResult> checks;
  final ProjectLifecycleAssessment lifecycle;
  final ScopeCoverageReport? scopeCoverage;

  /// Recommended gating decision: can the PMB be locked?
  final bool canLockBaseline;

  /// Human-readable summary, suitable for the dashboard banner.
  final String summary;

  const IbrReport({
    required this.overallStatus,
    required this.checks,
    required this.lifecycle,
    required this.scopeCoverage,
    required this.canLockBaseline,
    required this.summary,
  });

  int get passedCount =>
      checks.where((c) => c.status == IbrStatus.passed).length;
  int get blockedCount =>
      checks.where((c) => c.status == IbrStatus.blocked).length;
  int get attentionCount =>
      checks.where((c) => c.status == IbrStatus.attention).length;
  int get totalChecks => checks.length;

  /// 0–100 readiness score blending per-check completion ratios.
  double get readinessScore {
    if (checks.isEmpty) return 0;
    final sum = checks.fold<double>(0, (s, c) => s + c.completion);
    return (sum / checks.length) * 100;
  }
}

class IbrService {
  IbrService._();

  /// Run the IBR assessment.
  ///
  /// Inputs:
  /// - [project] — legacy `ProjectDataModel` (still the source of truth
  ///   for scope narrative + scope items).
  /// - [wbs] — the WBS tree (must be loaded).
  /// - [schedule] — the schedule tree (must be loaded, ideally CPM-computed).
  /// - [costEstimate] — the cost estimate (must include lines + totals).
  /// - [controls] — the project controls state (must include work packages).
  /// - [scopeItems] — optional explicit scope-item list; if null, the
  ///   validator is skipped and that check returns `attention`.
  static IbrReport assess({
    required ProjectDataModel project,
    required WBS? wbs,
    required Schedule? schedule,
    required CostEstimate? costEstimate,
    required ProjectControlsState controls,
    List<ScopeCoverageInput>? scopeItems,
  }) {
    final lifecycle = ProjectLifecycleService.assess(
      project: project,
      wbs: wbs,
      schedule: schedule,
      costEstimate: costEstimate,
      controls: controls,
    );

    ScopeCoverageReport? scopeReport;
    if (wbs != null && scopeItems != null) {
      scopeReport =
          ScopeCoverageValidator.validate(wbs: wbs, scopeItems: scopeItems);
    }

    final checks = <IbrCheckResult>[];

    // ── Check 1: Scope narrative defined ────────────────────────────
    final hasNarrative = project.projectObjective.trim().isNotEmpty ||
        project.solutionDescription.trim().isNotEmpty ||
        project.businessCase.trim().isNotEmpty;
    checks.add(IbrCheckResult(
      checkId: 'scope_narrative',
      label: 'Scope narrative defined',
      status: hasNarrative ? IbrStatus.passed : IbrStatus.blocked,
      detail: hasNarrative
          ? 'Project objective / solution description / business case captured.'
          : 'No scope narrative — capture objective, solution, or business case.',
      completion: hasNarrative ? 1.0 : 0.0,
    ));

    // ── Check 2: WBS exists with at least 3 L1 nodes ───────────────
    final wbsExists = wbs != null;
    final l1Count = wbsExists ? wbs.level0.children.length : 0;
    final wbsReady = wbsExists && l1Count >= 3;
    checks.add(IbrCheckResult(
      checkId: 'wbs_structure',
      label: 'WBS structure valid (≥3 Level-1 nodes)',
      status: wbsReady
          ? IbrStatus.passed
          : (wbsExists ? IbrStatus.attention : IbrStatus.blocked),
      detail: wbsExists
          ? 'WBS has $l1Count Level-1 node${l1Count == 1 ? '' : 's'} (need ≥3).'
          : 'No WBS — create one in the WBS Builder.',
      completion: wbsExists ? (l1Count / 3).clamp(0.0, 1.0) : 0.0,
    ));

    // ── Check 3: 100% Rule (scope ↔ WBS coverage) ──────────────────
    if (scopeReport != null) {
      final ratio = scopeReport.scopeCoverageRatio;
      final dictRatio = scopeReport.dictionaryCompletenessRatio;
      final satisfied = scopeReport.hundredPercentRuleSatisfied;
      checks.add(IbrCheckResult(
        checkId: 'hundred_percent_rule',
        label: '100% Rule satisfied (scope ↔ WBS)',
        status: satisfied
            ? IbrStatus.passed
            : (ratio >= 0.8 && dictRatio >= 0.5
                ? IbrStatus.attention
                : IbrStatus.blocked),
        detail: satisfied
            ? 'All scope items traced to WBS; all WP leaves have dictionary entries.'
            : '${scopeReport.uncoveredScopeItems.length} scope item(s) untraced; '
                '${scopeReport.incompleteDictionaryLeaves.length} WP leaf/leaves missing dictionary entry.',
        completion: scopeReport.readinessScore / 100,
      ));
    } else {
      checks.add(const IbrCheckResult(
        checkId: 'hundred_percent_rule',
        label: '100% Rule satisfied (scope ↔ WBS)',
        status: IbrStatus.attention,
        detail: 'Scope items not provided — cannot validate 100% Rule.',
        completion: 0.0,
      ));
    }

    // ── Check 4: Schedule has activities with dates ────────────────
    final actCount = lifecycle.scheduleActivityCount;
    final hasDates = lifecycle.traceability.every((t) => t.hasDates);
    final scheduleReady = actCount > 0 && hasDates;
    checks.add(IbrCheckResult(
      checkId: 'schedule_dates',
      label: 'Schedule activities have dates',
      status: scheduleReady
          ? IbrStatus.passed
          : (actCount > 0 ? IbrStatus.attention : IbrStatus.blocked),
      detail: scheduleReady
          ? '$actCount activities scheduled with start/finish dates.'
          : actCount == 0
              ? 'No schedule activities — import from WBS or build manually.'
              : '${lifecycle.traceability.where((t) => !t.hasDates).length} WP(s) missing dates.',
      completion: actCount == 0
          ? 0.0
          : (lifecycle.traceability.where((t) => t.hasDates).length /
              lifecycle.traceability.length),
    ));

    // ── Check 5: Control accounts exist with budgets ───────────────
    final caCount = lifecycle.controlAccountCount;
    final costCount = lifecycle.costLineCount;
    final caReady = caCount > 0 && costCount > 0;
    checks.add(IbrCheckResult(
      checkId: 'control_accounts',
      label: 'Control accounts seeded with cost',
      status: caReady
          ? IbrStatus.passed
          : (caCount > 0 ? IbrStatus.attention : IbrStatus.blocked),
      detail: caReady
          ? '$caCount control account(s) linked to $costCount cost line(s).'
          : caCount == 0
              ? 'No control accounts — sync Project Controls from Cost Estimate.'
              : 'Control accounts exist but no cost lines linked.',
      completion: caCount == 0
          ? 0.0
          : (costCount > 0 ? 1.0 : 0.5),
    ));

    // ── Check 6: Every WBS leaf fully traced ───────────────────────
    final totalWp = lifecycle.workPackageCount;
    final tracedWp = lifecycle.fullyTracedWorkPackageCount;
    final allTraced = totalWp > 0 && tracedWp == totalWp;
    checks.add(IbrCheckResult(
      checkId: 'wp_traceability',
      label: 'Every WBS leaf fully traced',
      status: allTraced
          ? IbrStatus.passed
          : (tracedWp > 0 ? IbrStatus.attention : IbrStatus.blocked),
      detail: allTraced
          ? 'All $tracedWp work-package leaves have activity + dates + resources + cost + control account.'
          : '$tracedWp of $totalWp work-package leaves fully traced.',
      completion: totalWp == 0 ? 0.0 : (tracedWp / totalWp),
    ));

    // ── Check 7: EVM-ready (lifecycle verdict) ─────────────────────
    checks.add(IbrCheckResult(
      checkId: 'evm_ready',
      label: 'EVM computation ready',
      status: lifecycle.evmReady
          ? IbrStatus.passed
          : IbrStatus.attention,
      detail: lifecycle.evmReady
          ? 'Earned Value can be computed against the PMB.'
          : 'EVM not yet ready — close the gaps above first.',
      completion: lifecycle.evmReady ? 1.0 : 0.5,
    ));

    // ── Aggregate ──────────────────────────────────────────────────
    final blocked = checks.where((c) => c.status == IbrStatus.blocked).length;
    final attention =
        checks.where((c) => c.status == IbrStatus.attention).length;
    final IbrStatus overall;
    if (blocked > 0) {
      overall = IbrStatus.blocked;
    } else if (attention > 0) {
      overall = IbrStatus.attention;
    } else {
      overall = IbrStatus.passed;
    }

    final canLock = overall == IbrStatus.passed;

    final summary = canLock
        ? 'IBR passed — Performance Measurement Baseline is ready to lock.'
        : blocked > 0
            ? 'IBR blocked — $blocked critical gap(s) must be closed before locking the PMB.'
            : 'IBR needs attention — $attention gap(s) remain, but no critical blockers.';

    return IbrReport(
      overallStatus: overall,
      checks: checks,
      lifecycle: lifecycle,
      scopeCoverage: scopeReport,
      canLockBaseline: canLock,
      summary: summary,
    );
  }
}
