library;

/// Variance Screen — Treasury-treated variance vs baseline + re-baseline
/// via MoC.
///
/// Design language:
///   "The Treasury" — premium, calm, light-mode executive cockpit built on
///   the NDU brand yellow (#FFC812) + amber (#D97706) gradient.
///
/// Rendered inside the Cost Estimate module's [ResponsiveScaffold] body —
/// no Scaffold of its own.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/cost_estimate/widgets/treasury_components.dart';
import 'package:ndu_project/services/user_preferences_service.dart';

class VarianceScreen extends StatelessWidget {
  const VarianceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CostEstimateProvider>(
      builder: (context, provider, _) {
        final estimate = provider.estimate!;
        final baseline = estimate.baseline;
        final currencySymbol = UserPreferencesService.currencySymbolSync;

        if (baseline == null) {
          return Container(
            color: TreasuryTokens.canvas,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TreasuryHeroBand(
                    eyebrow: 'COST ESTIMATE · VARIANCE',
                    title: 'Variance & Re-baseline',
                    subtitle:
                        'Track deviations from the locked baseline and trigger re-baselines via Management of Change.',
                    statusLabel: 'No baseline yet',
                    statusLive: false,
                    contextChips: [
                      TreasuryHeroChip(
                        icon: Icons.flag_outlined,
                        label: 'Project',
                        value: estimate.projectName,
                      ),
                      TreasuryHeroChip(
                        icon: Icons.payments_outlined,
                        label: 'Estimate',
                        value:
                            '$currencySymbol${treasuryFmt(estimate.totals.costBaseline)}',
                      ),
                      TreasuryHeroChip(
                        icon: Icons.delivery_dining_outlined,
                        label: 'Model',
                        value: estimate.deliveryModel.label,
                      ),
                    ],
                    actions: const [],
                  ),
                  const SizedBox(height: 22),
                  TreasuryEmptyState(
                    icon: Icons.trending_flat_rounded,
                    title: 'No baseline to compare',
                    body:
                        'Lock a baseline on the Review tab to start tracking variance. Re-baselines are limited to 2 per estimate.',
                  ),
                ],
              ),
            ),
          );
        }

        final variance = ComputeUtils.computeVariance(
            baseline.snapshot.lines, estimate.lines);
        final varianceLines =
            estimate.lines.where((l) => l.varianceType != null).toList();
        final isWaterfall =
            estimate.deliveryModel == DeliveryModel.waterfall ||
                estimate.deliveryModel == DeliveryModel.hybrid;
        final canRebaseline =
            (provider.currentRole == RBACRole.approver ||
                provider.currentRole == RBACRole.admin) &&
                baseline.rebaselineRemaining > 0 &&
                variance.delta != 0;
        final rebaselinesUsed = 2 - baseline.rebaselineRemaining;

        return Container(
          color: TreasuryTokens.canvas,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Hero command band ─────────────────────────────────
                TreasuryHeroBand(
                  eyebrow: 'COST ESTIMATE · VARIANCE',
                  title: 'Variance & Re-baseline',
                  subtitle:
                      'Track deviations from the locked baseline and trigger re-baselines via Management of Change.',
                  statusLabel: variance.delta == 0
                      ? 'On baseline — no variance'
                      : (variance.delta > 0
                          ? 'Over baseline'
                          : 'Under baseline'),
                  statusLive: variance.delta != 0,
                  contextChips: [
                    TreasuryHeroChip(
                      icon: Icons.tag_rounded,
                      label: 'Baseline',
                      value: 'v${baseline.version}',
                    ),
                    TreasuryHeroChip(
                      icon: Icons.trending_up_rounded,
                      label: 'Variance',
                      value:
                          '${variance.delta > 0 ? "+" : variance.delta < 0 ? "−" : ""}$currencySymbol${treasuryFmt(variance.delta.abs())}',
                    ),
                    TreasuryHeroChip(
                      icon: Icons.refresh_rounded,
                      label: 'Re-baselines',
                      value:
                          '${baseline.rebaselineRemaining} / 2 left',
                    ),
                  ],
                  actions: [
                    if (canRebaseline)
                      TreasuryHeroAction(
                        icon: Icons.refresh_rounded,
                        label: 'Re-baseline (v${baseline.version + 1})',
                        primary: true,
                        onTap: () => _showRebaselineDialog(
                            context, provider, estimate, isWaterfall),
                      ),
                  ],
                ),
                const SizedBox(height: 22),

                // ── 2. Premium KPI strip ─────────────────────────────────
                TreasuryKpiStrip(
                  kpis: [
                    TreasuryKpiSpec(
                      label: 'Baseline',
                      value:
                          '$currencySymbol${treasuryFmt(variance.baselineTotal)}',
                      sub: 'v${baseline.version} locked total',
                      icon: Icons.shield_outlined,
                      tint: const Color(0xFF64748B),
                      tintSoft: const Color(0xFFF1F5F9),
                    ),
                    TreasuryKpiSpec(
                      label: 'Current',
                      value:
                          '$currencySymbol${treasuryFmt(variance.currentTotal)}',
                      sub: '${estimate.lines.length} live lines',
                      icon: Icons.trending_flat_rounded,
                      tint: const Color(0xFFB8860B),
                      tintSoft: const Color(0xFFEEF0FF),
                    ),
                    TreasuryKpiSpec(
                      label: 'Variance',
                      value:
                          '${variance.delta > 0 ? "+" : variance.delta < 0 ? "−" : ""}$currencySymbol${treasuryFmt(variance.delta.abs())}',
                      sub: formatPercent(variance.deltaPct),
                      icon: variance.delta > 0
                          ? Icons.trending_up_rounded
                          : variance.delta < 0
                              ? Icons.trending_down_rounded
                              : Icons.trending_flat_rounded,
                      tint: variance.delta > 0
                          ? const Color(0xFFD97706)
                          : variance.delta < 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFF64748B),
                      tintSoft: variance.delta > 0
                          ? const Color(0xFFFFF3E0)
                          : variance.delta < 0
                              ? const Color(0xFFE7F8F0)
                              : const Color(0xFFF1F5F9),
                    ),
                    TreasuryKpiSpec(
                      label: 'Variance Lines',
                      value: '${varianceLines.length}',
                      sub: 'Items with variance entries',
                      icon: Icons.list_alt_rounded,
                      tint: const Color(0xFFB8860B),
                      tintSoft: const Color(0xFFF4EEFF),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // ── 3. Re-baseline progress bar ─────────────────────────
                _RebaselineProgressCard(
                  rebaselinesUsed: rebaselinesUsed,
                  rebaselinesRemaining: baseline.rebaselineRemaining,
                  canRebaseline: canRebaseline,
                  isWaterfall: isWaterfall,
                  onRebaseline: () => _showRebaselineDialog(
                      context, provider, estimate, isWaterfall),
                  nextVersion: baseline.version + 1,
                ),
                const SizedBox(height: 22),

                // ── 4. Variance by category + Variance entries ─────────
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 1000;
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 7,
                              child: _buildVarianceByCategory(
                                  variance, currencySymbol)),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 5,
                            child: _buildVarianceEntries(
                                varianceLines, currencySymbol),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildVarianceByCategory(variance, currencySymbol),
                        const SizedBox(height: 14),
                        _buildVarianceEntries(
                            varianceLines, currencySymbol),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),

                // ── 5. Variance spotlight bar ──────────────────────────
                TreasurySpotlightBar(
                  columns: [
                    TreasurySpotlightColumn(
                      icon: Icons.shield_outlined,
                      label: 'Baseline Total',
                      value:
                          '$currencySymbol${treasuryFmt(variance.baselineTotal)}',
                      tint: const Color(0xFF64748B),
                      tintSoft: const Color(0xFFF1F5F9),
                    ),
                    TreasurySpotlightColumn(
                      icon: Icons.trending_flat_rounded,
                      label: 'Current Total',
                      value:
                          '$currencySymbol${treasuryFmt(variance.currentTotal)}',
                      tint: const Color(0xFFB8860B),
                      tintSoft: const Color(0xFFEEF0FF),
                    ),
                    TreasurySpotlightColumn(
                      icon: variance.delta > 0
                          ? Icons.trending_up_rounded
                          : variance.delta < 0
                              ? Icons.trending_down_rounded
                              : Icons.trending_flat_rounded,
                      label: 'Net Variance',
                      value:
                          '${variance.delta > 0 ? "+" : variance.delta < 0 ? "−" : ""}$currencySymbol${treasuryFmt(variance.delta.abs())}',
                      tint: variance.delta > 0
                          ? const Color(0xFFD97706)
                          : variance.delta < 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFF64748B),
                      tintSoft: variance.delta > 0
                          ? const Color(0xFFFFF3E0)
                          : variance.delta < 0
                              ? const Color(0xFFE7F8F0)
                              : const Color(0xFFF1F5F9),
                      dark: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVarianceByCategory(variance, String currencySymbol) {
    final cats = variance.byCategory
        .where((c) => c.baseline > 0 || c.current > 0 || c.delta != 0)
        .toList();
    final maxAbs = cats.fold<double>(0, (m, c) {
      final a = c.delta.abs();
      return a > m ? a : m;
    });

    return TreasurySectionCard(
      title: 'Variance by Category',
      subtitle: 'Baseline → Current delta, per category',
      child: cats.isEmpty
          ? TreasuryEmptyState(
              icon: Icons.bar_chart_rounded,
              title: 'No category variance yet',
              body: 'Categories with delta values will appear here.',
            )
          : Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 6),
                  child: Row(
                    children: const [
                      Expanded(
                          flex: 4,
                          child: TreasuryTableHeader('CATEGORY')),
                      Expanded(
                          flex: 3,
                          child: TreasuryTableHeader('BASELINE',
                              alignRight: true)),
                      Expanded(
                          flex: 3,
                          child: TreasuryTableHeader('CURRENT',
                              alignRight: true)),
                      Expanded(
                          flex: 3,
                          child: TreasuryTableHeader('DELTA',
                              alignRight: true)),
                    ],
                  ),
                ),
                const Divider(
                    height: 1,
                    thickness: 1,
                    color: TreasuryTokens.hairline),
                for (final c in cats)
                  _VarianceCategoryRow(
                    label: c.label,
                    baseline: c.baseline,
                    current: c.current,
                    delta: c.delta,
                    deltaPct: maxAbs > 0
                        ? (c.delta.abs() / maxAbs).clamp(0.0, 1.0)
                        : 0.0,
                    currencySymbol: currencySymbol,
                  ),
              ],
            ),
    );
  }

  Widget _buildVarianceEntries(
      List<CostLine> varianceLines, String currencySymbol) {
    return TreasurySectionCard(
      title: 'Variance Entries',
      subtitle:
          '${varianceLines.length} ${varianceLines.length == 1 ? "entry" : "entries"}',
      child: varianceLines.isEmpty
          ? TreasuryEmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'No variance entries',
              body:
                  'The current estimate matches the baseline exactly. Variance entries will appear here as you edit lines after the baseline was locked.',
            )
          : Column(
              children: [
                for (final l in varianceLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VarianceLineRow(
                      line: l,
                      currencySymbol: currencySymbol,
                    ),
                  ),
              ],
            ),
    );
  }

  void _showRebaselineDialog(BuildContext context,
      CostEstimateProvider provider, CostEstimate estimate, bool isWaterfall) {
    final reasonCtrl = TextEditingController();
    final mocCtrl = TextEditingController();
    final agileCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => _TreasuryRebaselineDialog(
        estimate: estimate,
        isWaterfall: isWaterfall,
        reasonCtrl: reasonCtrl,
        mocCtrl: mocCtrl,
        agileCtrl: agileCtrl,
        onConfirm: () {
          final reason = reasonCtrl.text.trim();
          if (reason.isEmpty) return;
          final mocId = isWaterfall ? mocCtrl.text.trim() : null;
          final agileNote =
              !isWaterfall ? agileCtrl.text.trim() : null;
          if (isWaterfall && (mocId == null || mocId.isEmpty)) return;
          if (!isWaterfall &&
              (agileNote == null || agileNote.isEmpty)) {
            return;
          }
          provider.rebaseline(
              reason: reason, mocId: mocId, agileInfoNote: agileNote);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RE-BASELINE PROGRESS CARD
// ═══════════════════════════════════════════════════════════════════════════

class _RebaselineProgressCard extends StatelessWidget {
  const _RebaselineProgressCard({
    required this.rebaselinesUsed,
    required this.rebaselinesRemaining,
    required this.canRebaseline,
    required this.isWaterfall,
    required this.onRebaseline,
    required this.nextVersion,
  });
  final int rebaselinesUsed;
  final int rebaselinesRemaining;
  final bool canRebaseline;
  final bool isWaterfall;
  final VoidCallback onRebaseline;
  final int nextVersion;

  @override
  Widget build(BuildContext context) {
    final exhausted = rebaselinesRemaining == 0;
    return TreasurySectionCard(
      title: 'Re-baseline',
      subtitle: isWaterfall
          ? 'Waterfall — requires a Management of Change (MoC) ID'
          : 'Agile — information note in lieu of formal MoC',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Re-baselines used: $rebaselinesUsed of 2',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: TreasuryTokens.inkSoft,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (exhausted)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: TreasuryTokens.dangerSoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: TreasuryTokens.danger
                            .withValues(alpha: 0.55)),
                  ),
                  child: Text('MAX REACHED',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: TreasuryTokens.danger)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: TreasuryTokens.warningSoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: TreasuryTokens.warning
                            .withValues(alpha: 0.55)),
                  ),
                  child: Text(
                      '$rebaselinesRemaining REMAINING',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: const Color(0xFFB45309))),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: rebaselinesUsed / 2,
                backgroundColor: TreasuryTokens.hairlineSoft,
                color: exhausted
                    ? TreasuryTokens.danger
                    : TreasuryTokens.warning,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (exhausted)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: TreasuryTokens.dangerSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: TreasuryTokens.danger
                        .withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: TreasuryTokens.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Max 2 re-baselines consumed. Further changes require a new estimate version.',
                      style: TextStyle(
                          color: TreasuryTokens.inkSoft,
                          fontSize: 12,
                          height: 1.45),
                    ),
                  ),
                ],
              ),
            )
          else if (canRebaseline)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lock v$nextVersion — this consumes one re-baseline.',
                    style: TextStyle(
                        color: TreasuryTokens.muted, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 14),
                TreasuryPrimaryButton(
                  icon: Icons.refresh_rounded,
                  label: 'Re-baseline (v$nextVersion)',
                  onPressed: onRebaseline,
                ),
              ],
            )
          else
            Text(
              'No variance to re-baseline — current estimate matches the baseline.',
              style: TextStyle(
                  color: TreasuryTokens.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VARIANCE CATEGORY ROW
// ═══════════════════════════════════════════════════════════════════════════

class _VarianceCategoryRow extends StatelessWidget {
  const _VarianceCategoryRow({
    required this.label,
    required this.baseline,
    required this.current,
    required this.delta,
    required this.deltaPct,
    required this.currencySymbol,
  });
  final String label;
  final double baseline;
  final double current;
  final double delta;
  final double deltaPct;
  final String currencySymbol;

  (Color, Color) _deltaColors() {
    if (delta > 0) {
      return (const Color(0xFFD97706), const Color(0xFFFFF3E0));
    }
    if (delta < 0) {
      return (const Color(0xFF10B981), const Color(0xFFE7F8F0));
    }
    return (TreasuryTokens.muted, TreasuryTokens.surfaceAlt);
  }

  @override
  Widget build(BuildContext context) {
    final (deltaFg, deltaBg) = _deltaColors();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: const TextStyle(
                    color: TreasuryTokens.inkSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '$currencySymbol${treasuryFmt(baseline)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: TreasuryTokens.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '$currencySymbol${treasuryFmt(current)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: TreasuryTokens.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: deltaBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: deltaFg.withValues(alpha: 0.40)),
                  ),
                  child: Text(
                    delta != 0
                        ? '${delta > 0 ? "+" : "−"}$currencySymbol${treasuryFmt(delta.abs())}'
                        : '—',
                    style: TextStyle(
                      color: deltaFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [
                        FontFeature.tabularFigures()
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VARIANCE LINE ROW
// ═══════════════════════════════════════════════════════════════════════════

class _VarianceLineRow extends StatelessWidget {
  const _VarianceLineRow({
    required this.line,
    required this.currencySymbol,
  });
  final CostLine line;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final delta = line.varianceDelta ?? 0;
    final (deltaFg, deltaBg) = delta > 0
        ? (const Color(0xFFD97706), const Color(0xFFFFF3E0))
        : delta < 0
            ? (const Color(0xFF10B981), const Color(0xFFE7F8F0))
            : (TreasuryTokens.muted, TreasuryTokens.surfaceAlt);
    final typeLabel = line.varianceType == VarianceType.add
        ? 'Added'
        : line.varianceType == VarianceType.change
            ? 'Changed'
            : 'Removed';
    final typeIcon = line.varianceType == VarianceType.add
        ? Icons.add_circle_outline_rounded
        : line.varianceType == VarianceType.change
            ? Icons.change_circle_outlined
            : Icons.remove_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TreasuryTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TreasuryTokens.hairline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: deltaBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: deltaFg.withValues(alpha: 0.40)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(typeIcon, size: 11, color: deltaFg),
                const SizedBox(width: 4),
                Text(typeLabel.toUpperCase(),
                    style: TextStyle(
                      color: deltaFg,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(line.description,
                style: const TextStyle(
                    color: TreasuryTokens.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          Text(
            delta != 0
                ? '${delta > 0 ? "+" : "−"}$currencySymbol${treasuryFmt(delta.abs())}'
                : '—',
            style: TextStyle(
              color: deltaFg,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TREASURY RE-BASELINE DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class _TreasuryRebaselineDialog extends StatelessWidget {
  const _TreasuryRebaselineDialog({
    required this.estimate,
    required this.isWaterfall,
    required this.reasonCtrl,
    required this.mocCtrl,
    required this.agileCtrl,
    required this.onConfirm,
  });
  final CostEstimate estimate;
  final bool isWaterfall;
  final TextEditingController reasonCtrl;
  final TextEditingController mocCtrl;
  final TextEditingController agileCtrl;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TreasuryTokens.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: TreasuryTokens.brandSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.refresh_rounded,
                size: 16, color: TreasuryTokens.brandDeep),
          ),
          const SizedBox(width: 10),
          Text(
              'Re-baseline to v${estimate.baseline!.version + 1}',
              style: const TextStyle(
                  color: TreasuryTokens.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: TreasuryTokens.warningSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: TreasuryTokens.warning
                        .withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: TreasuryTokens.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isWaterfall
                          ? 'This will consume one re-baseline. A Management of Change (MoC) ID is required.'
                          : 'This will consume one re-baseline. An information note is required in lieu of formal MoC.',
                      style: TextStyle(
                          color: TreasuryTokens.inkSoft,
                          fontSize: 12,
                          height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _TreasuryField(
              controller: reasonCtrl,
              label: 'Reason for re-baseline',
              hint:
                  'Describe the major change that warrants a re-baseline...',
              minLines: 3,
            ),
            const SizedBox(height: 12),
            if (isWaterfall)
              _TreasuryField(
                controller: mocCtrl,
                label: 'Management of Change (MoC) ID',
                hint: 'e.g. MOC-2026-001',
              )
            else
              _TreasuryField(
                controller: agileCtrl,
                label: 'Information note',
                hint:
                    'Brief note explaining the change (Agile — no formal MoC)...',
                minLines: 2,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(
                  color: TreasuryTokens.muted, fontSize: 13)),
        ),
        TreasuryPrimaryButton(
          icon: Icons.lock_rounded,
          label: 'Lock v${estimate.baseline!.version + 1}',
          dark: true,
          onPressed: onConfirm,
        ),
      ],
    );
  }
}

class _TreasuryField extends StatelessWidget {
  const _TreasuryField({
    required this.controller,
    required this.label,
    required this.hint,
    this.minLines = 1,
    this.maxLines,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final int minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines ?? (minLines > 1 ? null : 1),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: TreasuryTokens.muted, fontSize: 12),
        hintText: hint,
        hintStyle:
            TextStyle(color: TreasuryTokens.mutedSoft, fontSize: 12.5),
        filled: true,
        fillColor: TreasuryTokens.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: TreasuryTokens.hairline)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: TreasuryTokens.brandDeep, width: 1.6)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: TreasuryTokens.hairline)),
      ),
      style: const TextStyle(color: TreasuryTokens.ink, fontSize: 13),
    );
  }
}
