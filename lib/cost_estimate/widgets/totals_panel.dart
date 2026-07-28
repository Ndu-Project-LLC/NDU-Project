library;

/// Totals Panel — world-class sticky sidebar showing live-computed totals.
///
/// Implements the baseline formula from the guidance doc:
///   Direct + Indirect + SSHER/Quality + Risk + Contingency + Escalation + Taxes = Cost Baseline
///   Cost Baseline + Management Reserve = Total Authorized Budget
///
/// Features:
/// - KPI cards (Cost Baseline, Total Authorized, # Lines, Avg / Line)
/// - Visual cost-breakdown bar chart (each category as a colored segment)
/// - Category rows with progress bars showing % of total
/// - All values update live as cost lines are added/edited
///
/// Light-mode (white) theme — matches the rest of the app.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/services/user_preferences_service.dart';
import "package:ndu_project/cost_estimate/models/cost_estimate_models.dart";
import "package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart";

class TotalsPanel extends StatelessWidget {
  const TotalsPanel({super.key});

  // Category colors for the breakdown chart
  static const _categoryColors = <String, Color>{
    'Direct costs': Color(0xFF6366F1),
    'Indirect costs': Color(0xFF8B5CF6),
    'SSHER & Quality': Color(0xFFEC4899),
    'Risk allowances': Color(0xFFF59E0B),
    'Contingency': Color(0xFF10B981),
    'Escalation': Color(0xFF06B6D4),
    'Taxes & duties': Color(0xFF64748B),
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<CostEstimateProvider>(
      builder: (context, provider, _) {
        final estimate = provider.estimate;
        if (estimate == null) return const SizedBox.shrink();
        final t = estimate.totals;
        final currencySymbol = UserPreferencesService.currencySymbolSync;
        final lineCount = estimate.lines.length;
        final avgPerLine = lineCount > 0 ? t.costBaseline / lineCount : 0.0;
        final isBaselined = estimate.status == EstimateStatus.baselined ||
            estimate.status == EstimateStatus.rebaselined;

        // Build category list for chart
        final categories = <_CategoryTotal>[
          _CategoryTotal('Direct costs', t.direct, _categoryColors['Direct costs']!),
          _CategoryTotal('Indirect costs', t.indirect, _categoryColors['Indirect costs']!),
          _CategoryTotal('SSHER & Quality', t.sherQuality, _categoryColors['SSHER & Quality']!),
          _CategoryTotal('Risk allowances', t.riskAllowances, _categoryColors['Risk allowances']!),
          _CategoryTotal('Contingency', t.contingency, _categoryColors['Contingency']!),
          _CategoryTotal('Escalation', t.escalation, _categoryColors['Escalation']!),
          _CategoryTotal('Taxes & duties', t.taxes, _categoryColors['Taxes & duties']!),
        ];
        final maxCategory = categories.fold<double>(0, (m, c) => c.value > m ? c.value : m);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4E7EC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ESTIMATE TOTALS',
                      style: TextStyle(
                        color: LightModeColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (isBaselined)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock, size: 10, color: Color(0xFF16A34A)),
                            const SizedBox(width: 3),
                            Text(
                              'v${estimate.baseline?.version}',
                              style: const TextStyle(
                                color: Color(0xFF16A34A),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── KPI Cards (2x2 grid) ────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        label: 'Cost Baseline',
                        value: '$currencySymbol${_formatCompact(t.costBaseline)}',
                        icon: Icons.shield_outlined,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _KpiCard(
                        label: 'Total Authorized',
                        value: '$currencySymbol${_formatCompact(t.totalAuthorizedBudget)}',
                        icon: Icons.account_balance_wallet_outlined,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        label: 'Cost Lines',
                        value: '$lineCount',
                        icon: Icons.list_alt_rounded,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _KpiCard(
                        label: 'Avg / Line',
                        value: '$currencySymbol${_formatCompact(avgPerLine)}',
                        icon: Icons.analytics_outlined,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Cost Breakdown Bar Chart ────────────────────────────
                if (t.costBaseline > 0) ...[
                  const Text(
                    'COST BREAKDOWN',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Stacked horizontal bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 28,
                      child: Row(
                        children: categories
                            .where((c) => c.value > 0)
                            .map((c) {
                              final pct = t.costBaseline > 0 ? c.value / t.costBaseline : 0.0;
                              return Expanded(
                                flex: (pct * 1000).clamp(1, 1000).round(),
                                child: Container(
                                  color: c.color,
                                  child: pct > 0.08
                                      ? Center(
                                          child: Text(
                                            '${(pct * 100).round()}%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Legend
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: categories
                        .where((c) => c.value > 0)
                        .map((c) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: c.color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  c.label,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Category Rows with Progress Bars ────────────────────
                const Text(
                  'BREAKDOWN DETAILS',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                for (final c in categories)
                  _CategoryRow(
                    label: c.label,
                    value: c.value,
                    currencySymbol: currencySymbol,
                    color: c.color,
                    maxTotal: maxCategory > 0 ? maxCategory : 1,
                  ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFE4E7EC), height: 1),
                const SizedBox(height: 12),

                // ── Cost Baseline (highlighted) ────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        LightModeColors.accent.withValues(alpha: 0.12),
                        LightModeColors.accent.withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: LightModeColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: LightModeColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.shield, color: LightModeColors.accent, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Cost Baseline',
                        style: TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$currencySymbol${_formatCompact(t.costBaseline)}',
                        style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── Management Reserve ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up, color: Color(0xFF6B7280), size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Mgmt Reserve',
                        style: TextStyle(
                          color: Color(0xFF495057),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$currencySymbol${_formatCompact(t.managementReserve)}',
                        style: const TextStyle(
                          color: Color(0xFF495057),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── Total Authorized Budget ─────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D1F),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'TOTAL AUTHORIZED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$currencySymbol${_formatCompact(t.totalAuthorizedBudget)}',
                        style: const TextStyle(
                          color: LightModeColors.accent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Format a number compactly (e.g. 1.2M, 45K, 950)
  String _formatCompact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
  }
}

/// A KPI card showing a label, value, and icon.
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A category row with label, value, and a progress bar showing % of max.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.value,
    required this.currencySymbol,
    required this.color,
    required this.maxTotal,
  });

  final String label;
  final double value;
  final String currencySymbol;
  final Color color;
  final double maxTotal;

  @override
  Widget build(BuildContext context) {
    final pct = maxTotal > 0 ? (value / maxTotal).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF495057), fontSize: 12),
              ),
              Text(
                '$currencySymbol${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}',
                style: const TextStyle(
                  color: Color(0xFF1A1D1F),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple data class for category totals.
class _CategoryTotal {
  final String label;
  final double value;
  final Color color;
  const _CategoryTotal(this.label, this.value, this.color);
}
