library;

/// Cost by WBS Tab — world-class dashboard showing costs per WBS level.
/// Used by both the WBS Module and Cost Estimate Module screens.
///
/// This tab is the canonical consumer of [WBSProvider.computeCostRollup] —
/// it does NOT re-walk the cost estimate itself. Cost matching (by
/// `costLineIds` OR `wbsRef == node.code`) and rolled-up totals (including
/// descendant nodes) are computed once by the provider and consumed here.
///
/// Each L1 row also surfaces the schedule linkage (planned start / finish /
/// status) that [WbsLinkageService] backfills onto every [WBSNode], so the
/// Cost by WBS view doubles as a "scope ↔ cost ↔ schedule" traceability
/// matrix at a glance.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/providers/wbs_cost_rollup.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/services/user_preferences_service.dart';

class CostByWBSTab extends StatelessWidget {
  const CostByWBSTab({super.key});

  static const _textPrimary = Color(0xFF1A1D1F);
  static const _textSecondary = Color(0xFF6B7280);
  static const _border = Color(0xFFE4E7EC);
  static const _cardBg = Colors.white;

  @override
  Widget build(BuildContext context) {
    final wbsProvider = context.read<WBSProvider>();
    final wbs = wbsProvider.wbs;
    if (wbs == null) {
      return const Center(
        child: Text(
          'No WBS data available. Set up the WBS first.',
          style: TextStyle(color: _textSecondary, fontSize: 14),
        ),
      );
    }

    final ceProvider = context.read<CostEstimateProvider>();
    final estimate = ceProvider.estimate;
    final currencySymbol = UserPreferencesService.currencySymbolSync;
    final allLines = estimate?.lines ?? const <CostLine>[];

    // ── Canonical cost rollups (single source of truth) ──────────────
    // The provider walks the WBS tree once and returns a rollup per L1
    // node, with rolled-up totals including descendant costs.
    final l1Rollups = wbsProvider.getCostRollupsForL1(allLines);

    // For the L2 children rows, we ask the provider to compute a rollup
    // per child on demand. (Iterating the L1 rollup's node.children and
    // calling computeCostRollup keeps the matching logic in one place.)
    WBSNodeCostRollup rollupFor(WBSNode n) =>
        wbsProvider.computeCostRollup(n, allLines);

    // KPI aggregates
    final totalLinked =
        l1Rollups.fold<double>(0, (s, r) => s + r.rolledUpCost);
    final linkedLineIds = <String>{};
    for (final r in l1Rollups) {
      for (final l in r.directLines) {
        linkedLineIds.add(l.id);
      }
    }
    // Walk the tree to also catch lines linked to L2+ nodes (their direct
    // lines are inside the L1 rollup's directLines ONLY when they're
    // linked at L1; we need a separate pass for L2+ direct links).
    void collectLinkedIds(WBSNode n) {
      for (final id in (n.costLineIds ?? const <String>[])) {
        linkedLineIds.add(id);
      }
      for (final c in n.children) {
        collectLinkedIds(c);
      }
    }

    collectLinkedIds(wbs.level0);
    // Also count lines matched by wbsRef == node.code
    final wbsCodes = <String>{};
    for (final flat in flattenWBS(wbs)) {
      if (flat.path.isNotEmpty) wbsCodes.add(flat.path);
    }
    for (final line in allLines) {
      final ref = (line.wbsRef ?? '').trim();
      if (ref.isNotEmpty && wbsCodes.contains(ref)) {
        linkedLineIds.add(line.id);
      }
    }
    final unlinkedLines = allLines.where((l) => !linkedLineIds.contains(l.id)).toList();
    final unlinkedTotal =
        unlinkedLines.fold<double>(0, (s, l) => s + _effectiveLineTotal(l));
    final totalAll = totalLinked + unlinkedTotal;
    final linkedPct = totalAll > 0 ? (totalLinked / totalAll * 100) : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text('Cost by WBS Level',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          const SizedBox(height: 4),
          Text(
              '${allLines.length} cost lines · $currencySymbol${_fmt(totalAll)} total · ${linkedPct.toStringAsFixed(0)}% linked to WBS',
              style: const TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 24),

          // KPI Cards
          Row(
            children: [
              Expanded(
                  child: _costKpi(
                      'Total Cost',
                      '$currencySymbol${_fmt(totalAll)}',
                      Icons.account_balance_wallet_outlined,
                      const Color(0xFFB8860B))),
              const SizedBox(width: 12),
              Expanded(
                  child: _costKpi(
                      'Linked',
                      '$currencySymbol${_fmt(totalLinked)}',
                      Icons.link_outlined,
                      const Color(0xFF10B981))),
              const SizedBox(width: 12),
              Expanded(
                  child: _costKpi(
                      'Unlinked',
                      '$currencySymbol${_fmt(unlinkedTotal)}',
                      Icons.link_off_outlined,
                      const Color(0xFFEF4444))),
              const SizedBox(width: 12),
              Expanded(
                  child: _costKpi('L1 Deliverables', '${l1Rollups.length}',
                      Icons.layers_outlined, const Color(0xFFB8860B))),
            ],
          ),
          const SizedBox(height: 24),

          // Cost Distribution Bar Chart
          if (totalAll > 0) ...[
            _sectionCard(
              title: 'Cost Distribution by WBS Level',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 36,
                      child: Row(
                        children: [
                          if (totalLinked > 0)
                            Expanded(
                              flex: (totalLinked / totalAll * 1000).round(),
                              child: Container(
                                color: const Color(0xFF10B981),
                                child: Center(
                                    child: Text(
                                        '${linkedPct.toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold))),
                              ),
                            ),
                          if (unlinkedTotal > 0)
                            Expanded(
                              flex: (unlinkedTotal / totalAll * 1000).round(),
                              child: Container(
                                color: const Color(0xFFEF4444),
                                child: const Center(
                                    child: Text('Unlinked',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold))),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _legendDot('Linked to WBS', const Color(0xFF10B981),
                          '$currencySymbol${_fmt(totalLinked)}'),
                      const SizedBox(width: 24),
                      _legendDot('Unlinked', const Color(0xFFEF4444),
                          '$currencySymbol${_fmt(unlinkedTotal)}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Level 1 Deliverable Costs
          _sectionCard(
            title: 'Level 1 — ${wbs.framework.level1Label} Costs',
            child: l1Rollups.isEmpty
                ? const Text(
                    'No Level 1 deliverables yet. Add them in the Builder tab or use "Seed from Initiation" in Export & Link.',
                    style: TextStyle(color: _textSecondary, fontSize: 13))
                : Column(
                    children: l1Rollups.map((rollup) {
                      final cost = rollup.rolledUpCost;
                      final lineCount = rollup.rolledUpLineCount;
                      final pct = totalAll > 0 ? (cost / totalAll * 100) : 0.0;
                      final maxCost = l1Rollups.fold<double>(
                          0,
                          (a, r) =>
                              a > r.rolledUpCost ? a : r.rolledUpCost);
                      final barPct = maxCost > 0 ? (cost / maxCost) : 0.0;
                      return _wbsCostRow(
                        code: rollup.node.code,
                        name: rollup.node.name,
                        description: rollup.node.description ?? "",
                        cost: cost,
                        currencySymbol: currencySymbol,
                        lineCount: lineCount,
                        pct: pct,
                        barPct: barPct,
                        color: const Color(0xFFB8860B),
                        // Schedule linkage (backfilled by WbsLinkageService).
                        plannedStart: rollup.node.plannedStart,
                        plannedFinish: rollup.node.plannedFinish,
                        scheduleStatus: rollup.node.scheduleStatus,
                        // L2 children rows
                        children: rollup.node.children.map((l2) {
                          final l2Rollup = rollupFor(l2);
                          return _wbsCostRow(
                            code: l2.code,
                            name: l2.name,
                            description: l2.description ?? "",
                            cost: l2Rollup.rolledUpCost,
                            currencySymbol: currencySymbol,
                            lineCount: l2Rollup.rolledUpLineCount,
                            pct: totalAll > 0
                                ? (l2Rollup.rolledUpCost / totalAll * 100)
                                : 0.0,
                            barPct: cost > 0
                                ? (l2Rollup.rolledUpCost / cost)
                                : 0,
                            color: const Color(0xFFB8860B),
                            plannedStart: l2.plannedStart,
                            plannedFinish: l2.plannedFinish,
                            scheduleStatus: l2.scheduleStatus,
                            isChild: true,
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 20),

          // Unlinked Cost Lines
          if (unlinkedLines.isNotEmpty) ...[
            _sectionCard(
              title: 'Unlinked Cost Lines (${unlinkedLines.length})',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              'These cost lines have no WBS reference. Link them in the Cost Estimate Builder, or use "Auto-link FEP Cost Lines" in Export & Link to match by name.',
                              style: const TextStyle(
                                  color: Color(0xFF92400E), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...unlinkedLines.map((line) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(
                                    line.description.isNotEmpty
                                        ? line.description
                                        : line.subCategory,
                                    style: const TextStyle(
                                        color: _textPrimary, fontSize: 12),
                                    overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text('${line.category.label}',
                                style: const TextStyle(
                                    color: _textSecondary, fontSize: 10)),
                            const SizedBox(width: 8),
                            Text(
                                '$currencySymbol${line.total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ])),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Summary Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      LightModeColors.accent.withValues(alpha: 0.12),
                      LightModeColors.accent.withValues(alpha: 0.04)
                    ]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: LightModeColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                                color: LightModeColors.accent
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.layers,
                                color: LightModeColors.accent, size: 16)),
                        const SizedBox(width: 8),
                        const Text('WBS-Linked Total',
                            style: TextStyle(
                                color: _textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 10),
                      Text('$currencySymbol${_fmt(totalLinked)}',
                          style: const TextStyle(
                              color: Color(0xFFD97706),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()])),
                      const SizedBox(height: 4),
                      Text('${linkedPct.toStringAsFixed(1)}% of total',
                          style: const TextStyle(
                              color: _textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Color(0xFF1A1D1F),
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('GRAND TOTAL',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 10),
                      Text('$currencySymbol${_fmt(totalAll)}',
                          style: TextStyle(
                              color: LightModeColors.accent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ])),
                      const SizedBox(height: 4),
                      Text('${allLines.length} cost lines',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Effective contribution of a cost line — accounts for variance flags
  /// (added / removed / changed) so the unlinked-total computation stays
  /// consistent with [ComputeUtils.computeTotals] on the cost side and
  /// with [WBSProvider.computeCostRollup] on the WBS side.
  double _effectiveLineTotal(CostLine l) {
    if (l.varianceType == VarianceType.remove) {
      return -(l.varianceBaselineTotal ?? 0);
    }
    if (l.varianceType == VarianceType.change) {
      return l.varianceDelta ?? 0;
    }
    return l.total;
  }

  Widget _costKpi(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
                child: Text(label,
                    style: TextStyle(
                        color: color.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color, String value) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: _textSecondary, fontSize: 11)),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(
                color: _textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  /// Formats a [DateTime] as a compact "MMM d" string (e.g. "Jan 15").
  /// Returns "—" if the date is null.
  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  /// Maps a raw schedule-status string (free-form, written by
  /// [WbsLinkageService]) to a (color, label) pair for display. Unknown
  /// statuses fall back to a neutral grey.
  ({Color color, String label}) _scheduleStatusStyle(String? status) {
    if (status == null || status.isEmpty) {
      return (color: const Color(0xFF9CA3AF), label: 'No schedule');
    }
    final s = status.toLowerCase();
    if (s.contains('complete') || s.contains('done')) {
      return (color: const Color(0xFF10B981), label: status);
    }
    if (s.contains('on track') || s.contains('on-track') || s == 'in_progress') {
      return (color: const Color(0xFFFFC812), label: 'On track');
    }
    if (s.contains('delay') || s.contains('late') || s.contains('behind')) {
      return (color: const Color(0xFFEF4444), label: status);
    }
    if (s.contains('not started') || s.contains('pending')) {
      return (color: const Color(0xFF6B7280), label: status);
    }
    return (color: const Color(0xFF6B7280), label: status);
  }

  Widget _wbsCostRow({
    required String code,
    required String name,
    required String description,
    required double cost,
    required String currencySymbol,
    required int lineCount,
    required double pct,
    required double barPct,
    required Color color,
    required DateTime? plannedStart,
    required DateTime? plannedFinish,
    required String? scheduleStatus,
    bool isChild = false,
    List<Widget> children = const [],
  }) {
    final hasSchedule = plannedStart != null || plannedFinish != null;
    final statusStyle = _scheduleStatusStyle(scheduleStatus);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(code,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: appFontFamily)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            color: _textPrimary,
                            fontSize: isChild ? 12 : 13,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    if (description.isNotEmpty)
                      Text(description,
                          style: const TextStyle(
                              color: _textSecondary, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (lineCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('$lineCount',
                      style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              const SizedBox(width: 8),
              Text('$currencySymbol${_fmt(cost)}',
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: isChild ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text('${pct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
          // Schedule + status info row — compact chips showing the
          // scope↔cost↔schedule traceability at a glance. Hidden when
          // the node has no schedule linkage AND no cost (clean UI).
          if (hasSchedule || lineCount > 0 || scheduleStatus != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: isChild ? 18 : 18),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (hasSchedule)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 11, color: Color(0xFF6B7280)),
                        const SizedBox(width: 3),
                        Text(
                          '${_fmtDate(plannedStart)} – ${_fmtDate(plannedFinish)}',
                          style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  if (scheduleStatus != null && scheduleStatus.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusStyle.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: statusStyle.color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        statusStyle.label,
                        style: TextStyle(
                            color: statusStyle.color,
                            fontSize: 9,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (lineCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.attach_money_outlined,
                            size: 11, color: Color(0xFF6B7280)),
                        const SizedBox(width: 3),
                        Text(
                          '$lineCount cost line${lineCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: barPct.clamp(0.0, 1.0),
              minHeight: isChild ? 3 : 5,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4),
              child: Column(children: children),
            ),
        ],
      ),
    );
  }

  static String _fmt(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
  }
}
