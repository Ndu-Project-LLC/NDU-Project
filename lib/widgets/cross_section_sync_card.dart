/// Cross-Section Sync Card — a compact status banner embedded at the top
/// of each of the three execution-planning module screens (WBS, Schedule,
/// Project Controls) showing live linkage stats and providing one-click
/// sync + cross-navigation.
///
/// Goals:
/// - Make the data-flow between WBS, Schedule, and Project Controls
///   discoverable from any of the three screens.
/// - Surface orphan count ("5 WBS work packages have no control account")
///   so the user knows when to re-sync.
/// - Provide a "Sync Now" button that runs `WbsLinkageService.syncAll`
///   and a row of "Open section" buttons for quick navigation.
///
/// Visual design:
/// - Compact card with 3 KPI columns (WBS / Schedule / Project Controls).
/// - Each KPI shows the section's leaf / activity / control-account count
///   plus a coverage percentage.
/// - Status pill in the top-right: green "Fully linked" / amber "X orphans"
///   / grey "Not synced yet".
/// - Bottom row: "Sync Now" primary button + 2 secondary "Open other-section"
///   buttons.
///
/// The card reads all three providers via `context.watch` so it updates
/// live whenever any provider notifies its listeners.

library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/project_controls/providers/project_controls_provider.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/project_lifecycle_service.dart';
import 'package:ndu_project/services/wbs_linkage_service.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/widgets/trace_chip.dart';

class CrossSectionSyncCard extends StatefulWidget {
  const CrossSectionSyncCard({
    super.key,
    required this.currentSection,
    this.compact = false,
    this.backgroundColor = const Color(0xFFF8FAFC),
  });

  /// Which module screen the card is embedded on. Drives which "Open X"
  /// buttons are shown (we hide the "current" one).
  final CrossSection currentSection;

  /// When true, the card renders in a slimmer single-row layout suitable
  /// for very tall tab content. Default is false (full card).
  final bool compact;

  /// Surface color for expanded, collapsed, and compact presentations.
  final Color backgroundColor;

  @override
  State<CrossSectionSyncCard> createState() => _CrossSectionSyncCardState();
}

/// Enumerates the three sections this card bridges. Used to decide which
/// "Open X" navigation button to render.
enum CrossSection { wbs, schedule, costEstimate, projectControls }

class _CrossSectionSyncCardState extends State<CrossSectionSyncCard> {
  bool _syncing = false;
  LinkageReport? _lastReport;
  DateTime? _lastSyncedAt;
  // Per Tasks 9 + 13: card is collapsible to free up vertical space on the
  // WBS and Schedule module screens. Defaults to expanded so first-time
  // users still see the sync status; once they collapse it, the choice
  // persists for the lifetime of the widget instance.
  bool _collapsed = false;

  Future<void> _runSync() async {
    setState(() => _syncing = true);
    try {
      final wbsProvider = context.read<WBSProvider>();
      final scheduleProvider = context.read<ScheduleProvider>();
      final pcProvider = context.read<ProjectControlsProvider>();
      final costProvider = context.read<CostEstimateProvider>();
      final report = await WbsLinkageService.syncAll(
        wbsProvider: wbsProvider,
        scheduleProvider: scheduleProvider,
        pcProvider: pcProvider,
      );
      // Newly-created control accounts can now receive their exact WBS cost
      // allocation. The operation is idempotent and reconciles to BAC.
      if (report.wbsWorkPackageCount > 0) {
        pcProvider.syncFromCostEstimate(costProvider.estimate);
      }
      setState(() {
        _lastReport = report;
        _lastSyncedAt = DateTime.now();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              report.fullyLinked
                  ? 'Cross-section sync complete — ${report.wbsWorkPackageCount} work packages fully linked.'
                  : 'Sync complete — ${report.orphanNoControlAccount + report.orphanNoScheduleActivity} orphan links remain. Re-run after editing the relevant section.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectDataProvider>();
    final costProvider = context.watch<CostEstimateProvider>();
    return Consumer3<WBSProvider, ScheduleProvider, ProjectControlsProvider>(
      builder: (context, wbsP, schedP, pcP, _) {
        final lifecycle = ProjectLifecycleService.assess(
          project: projectProvider.projectData,
          wbs: wbsP.wbs,
          schedule: schedP.schedule,
          costEstimate: costProvider.estimate,
          controls: pcP.state,
        );
        final snapshot = WbsLinkageService.snapshot(
          wbsProvider: wbsP,
          scheduleProvider: schedP,
          pcProvider: pcP,
        );
        // Prefer the last sync report (more detail) but fall back to
        // the live snapshot when no sync has run yet.
        final report = _lastReport ?? snapshot;
        final coveragePct = (report.coverageRatio * 100).round();
        final fullyLinked = report.fullyLinked;
        final hasOrphans = report.orphanNoControlAccount > 0 ||
            report.orphanNoScheduleActivity > 0;

        final statusColor = fullyLinked
            ? const Color(0xFF16A34A) // green
            : hasOrphans
                ? const Color(0xFFD97706) // amber
                : const Color(0xFF6B7280); // grey
        final statusLabel = fullyLinked
            ? 'Fully linked'
            : hasOrphans
                ? '${report.orphanNoControlAccount + report.orphanNoScheduleActivity} orphan links'
                : 'Not synced yet';

        if (widget.compact) {
          return _buildCompact(report, statusColor, lifecycle);
        }
        final fullCard = _buildFull(
          report,
          coveragePct,
          statusColor,
          statusLabel,
          wbsP,
          schedP,
          pcP,
          lifecycle,
        );

        // Per Tasks 9 + 13: wrap the full card in a collapsible container.
        // When collapsed, only a slim header bar with the status pill and
        // an expand toggle is shown — frees up vertical space for the main
        // WBS / Schedule content.
        if (!_collapsed) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _collapsed = true),
                    icon: const Icon(Icons.unfold_less, size: 14),
                    label: const Text('Collapse',
                        style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              fullCard,
            ],
          );
        }
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.hub, size: 14, color: Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              const Text(
                'Cross-Section Sync',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _collapsed = false),
                icon: const Icon(Icons.unfold_more, size: 14),
                label: const Text('Expand',
                    style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFull(
    LinkageReport report,
    int coveragePct,
    Color statusColor,
    String statusLabel,
    WBSProvider wbsP,
    ScheduleProvider schedP,
    ProjectControlsProvider pcP,
    ProjectLifecycleAssessment lifecycle,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.hub, size: 16, color: Color(0xFF4F46E5)),
              const SizedBox(width: 6),
              const Text(
                'Project Delivery Chain',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scope → WBS → Activities → Schedule → Resources → Cost → Controls',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      fullyLinked(report)
                          ? Icons.check_circle
                          : Icons.warning_amber_rounded,
                      size: 11,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildLifecycleFlow(lifecycle),
          const SizedBox(height: 9),
          _buildCommonStructureSummary(lifecycle),
          if (lifecycle.hasIterativeFeedback) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.loop, size: 14, color: Color(0xFFFFC812)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${lifecycle.openFeedbackCount} control signal${lifecycle.openFeedbackCount == 1 ? '' : 's'} require review. Feed approved changes back into Scope/WBS, then resync downstream.',
                      style: const TextStyle(
                          fontSize: 10.5, color: Color(0xFFFFC812)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          // KPI row — the traceable execution chain
          Row(
            children: [
              Expanded(
                child: _kpiCell(
                  label: 'WBS',
                  icon: Icons.account_tree_outlined,
                  color: TraceChipPalette.wbs,
                  value: '${report.wbsWorkPackageCount}',
                  sub: 'what',
                ),
              ),
              Container(width: 1, height: 38, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _kpiCell(
                  label: 'Schedule',
                  icon: Icons.calendar_month_outlined,
                  color: TraceChipPalette.schedule,
                  value: '${lifecycle.scheduleActivityCount}',
                  sub: 'when',
                ),
              ),
              Container(width: 1, height: 38, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _kpiCell(
                  label: 'Cost',
                  icon: Icons.attach_money,
                  color: const Color(0xFFD97706),
                  value: '${lifecycle.costLineCount}',
                  sub: 'how much',
                ),
              ),
              Container(width: 1, height: 38, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _kpiCell(
                  label: 'Project Controls',
                  icon: Icons.dashboard_outlined,
                  color: TraceChipPalette.projectControls,
                  value: '${report.controlAccountCount}',
                  sub: 'performance',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Coverage bar
          Row(
            children: [
              Text(
                'Linkage coverage:',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: coveragePct / 100.0,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$coveragePct%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
          if (_lastSyncedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Last synced: ${_formatTimestamp(_lastSyncedAt!)}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (hasOrphans(report)) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 13, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _orphanMessage(report),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Action row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                onPressed: _syncing ? null : _runSync,
                icon: _syncing
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 14),
                label: Text(_syncing ? 'Syncing…' : 'Sync Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
              if (widget.currentSection != CrossSection.wbs)
                _secondaryButton(
                  label: 'Open WBS',
                  icon: Icons.account_tree_outlined,
                  color: TraceChipPalette.wbs,
                  onTap: () => _navigate(context, AppRoutes.wbs),
                ),
              if (widget.currentSection != CrossSection.schedule)
                _secondaryButton(
                  label: 'Open Schedule',
                  icon: Icons.calendar_month_outlined,
                  color: TraceChipPalette.schedule,
                  onTap: () => _navigate(context, AppRoutes.schedule),
                ),
              if (widget.currentSection != CrossSection.costEstimate)
                _secondaryButton(
                  label: 'Open Cost',
                  icon: Icons.attach_money,
                  color: const Color(0xFFD97706),
                  onTap: () => _navigate(context, AppRoutes.costEstimate),
                ),
              if (widget.currentSection != CrossSection.projectControls)
                _secondaryButton(
                  label: 'Open Project Controls',
                  icon: Icons.dashboard_outlined,
                  color: TraceChipPalette.projectControls,
                  onTap: () => _navigate(context, AppRoutes.projectControls),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(
    LinkageReport report,
    Color statusColor,
    ProjectLifecycleAssessment lifecycle,
  ) {
    final coveragePct = (report.coverageRatio * 100).round();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub, size: 13, color: Color(0xFF4F46E5)),
          const SizedBox(width: 6),
          Flexible(
            flex: 2,
            child: Text(
              '${report.wbsWorkPackageCount} WBS · ${lifecycle.scheduleActivityCount} Schedule · ${lifecycle.costLineCount} Cost · ${report.controlAccountCount} Controls',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: coveragePct / 100.0,
                minHeight: 4,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$coveragePct%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _syncing ? null : _runSync,
            icon: _syncing
                ? const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync, size: 12),
            label: const Text('Sync', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4F46E5),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: const Size(0, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleFlow(ProjectLifecycleAssessment lifecycle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'DELIVERY READINESS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
                color: Color(0xFF64748B),
              ),
            ),
            const Spacer(),
            Text(
              'Click a stage to review its source data',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
            ),
          ],
        ),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < lifecycle.stages.length; index++) ...[
                _lifecycleStage(lifecycle.stages[index]),
                if (index < lifecycle.stages.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommonStructureSummary(ProjectLifecycleAssessment lifecycle) {
    final total = lifecycle.workPackageCount;
    final traced = lifecycle.fullyTracedWorkPackageCount;
    final traceRatio = total == 0 ? 0.0 : traced / total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 820;
          final description = Row(
            children: [
              const Icon(Icons.account_tree_rounded,
                  size: 15, color: Color(0xFF4F46E5)),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WBS COMMON STRUCTURE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .7,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$traced/$total work packages trace What → Activities → When → Resources → How much → Control account',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          );
          final readiness = Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: narrow ? 110 : 70,
                child: LinearProgressIndicator(
                  value: traceRatio,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: traced == total && total > 0
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD97706),
                ),
              ),
              _readinessPill(
                label: lifecycle.timePhasedBaselineReady
                    ? 'Time-phased baseline ready'
                    : '${lifecycle.timePhasedCostLineCount}/${lifecycle.costLineCount} costs time-phased',
                ready: lifecycle.timePhasedBaselineReady,
              ),
              _readinessPill(
                label:
                    lifecycle.evmReady ? 'EVM ready' : 'EVM prerequisites open',
                ready: lifecycle.evmReady,
              ),
            ],
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [description, const SizedBox(height: 8), readiness],
            );
          }
          return Row(
            children: [
              Expanded(child: description),
              const SizedBox(width: 10),
              readiness,
            ],
          );
        },
      ),
    );
  }

  Widget _readinessPill({required String label, required bool ready}) {
    final color = ready ? const Color(0xFF15803D) : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ready ? Icons.check_circle : Icons.pending_outlined,
              size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _lifecycleStage(LifecycleStageAssessment stage) {
    final isCurrent = switch (stage.stage) {
      ProjectLifecycleStage.wbs => widget.currentSection == CrossSection.wbs,
      ProjectLifecycleStage.schedule =>
        widget.currentSection == CrossSection.schedule,
      ProjectLifecycleStage.resources => false,
      ProjectLifecycleStage.cost =>
        widget.currentSection == CrossSection.costEstimate,
      ProjectLifecycleStage.controls =>
        widget.currentSection == CrossSection.projectControls,
      ProjectLifecycleStage.scope => false,
    };
    final color = switch (stage.state) {
      LifecycleStageState.ready => const Color(0xFF15803D),
      LifecycleStageState.attention => const Color(0xFFD97706),
      LifecycleStageState.blocked => const Color(0xFF64748B),
    };
    final icon = switch (stage.state) {
      LifecycleStageState.ready => Icons.check_circle,
      LifecycleStageState.attention => Icons.pending_rounded,
      LifecycleStageState.blocked => Icons.lock_outline_rounded,
    };

    return Tooltip(
      message: stage.summary,
      child: InkWell(
        onTap: () => _openLifecycleStage(stage.stage),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 142,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: isCurrent
                ? const Color(0xFFFFF8E1)
                : color.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCurrent
                  ? const Color(0xFFB8860B)
                  : color.withValues(alpha: .28),
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      stage.label,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Text(
                    '${(stage.completion * 100).round()}%',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                stage.summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLifecycleStage(ProjectLifecycleStage stage) {
    final route = switch (stage) {
      ProjectLifecycleStage.scope => AppRoutes.projectCharter,
      ProjectLifecycleStage.wbs => AppRoutes.wbs,
      ProjectLifecycleStage.schedule => AppRoutes.schedule,
      ProjectLifecycleStage.resources => AppRoutes.projectControls,
      ProjectLifecycleStage.cost => AppRoutes.costEstimate,
      ProjectLifecycleStage.controls => AppRoutes.projectControls,
    };
    _navigate(context, route);
  }

  Widget _kpiCell({
    required String label,
    required IconData icon,
    required Color color,
    required String value,
    required String sub,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, String routeName) {
    context.push('/$routeName');
  }

  bool fullyLinked(LinkageReport r) => r.fullyLinked;
  bool hasOrphans(LinkageReport r) =>
      r.orphanNoControlAccount > 0 || r.orphanNoScheduleActivity > 0;

  String _orphanMessage(LinkageReport r) {
    final parts = <String>[];
    if (r.orphanNoControlAccount > 0) {
      parts.add(
          '${r.orphanNoControlAccount} WBS ${r.orphanNoControlAccount == 1 ? "package has" : "packages have"} no Project Controls account');
    }
    if (r.orphanNoScheduleActivity > 0) {
      parts.add(
          '${r.orphanNoScheduleActivity} WBS ${r.orphanNoScheduleActivity == 1 ? "package has" : "packages have"} no Schedule activity');
    }
    return '${parts.join(' · ')}. Press "Sync Now" to create them.';
  }

  String _formatTimestamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
