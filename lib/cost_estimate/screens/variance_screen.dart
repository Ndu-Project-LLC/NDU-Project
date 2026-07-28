library;

/// Variance Screen — shows variance vs baseline + re-baseline via MoC.
///
/// Rendered inside the Cost Estimate module's [ResponsiveScaffold] body —
/// no Scaffold of its own. Light-mode (white) theme.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';

class VarianceScreen extends StatelessWidget {
  const VarianceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CostEstimateProvider>(
      builder: (context, provider, _) {
        final estimate = provider.estimate!;
        final baseline = estimate.baseline;

        if (baseline == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.trending_down,
                    color: Color(0xFF9CA3AF), size: 48),
                const SizedBox(height: 16),
                const Text('No baseline to compare',
                    style: TextStyle(
                        color: Color(0xFF1A1D1F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                    'Lock a baseline on the Review tab to start tracking variance.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }

        final variance = ComputeUtils.computeVariance(
            baseline.snapshot.lines, estimate.lines);
        final varianceLines =
            estimate.lines.where((l) => l.varianceType != null).toList();
        final isWaterfall = estimate.deliveryModel == DeliveryModel.waterfall ||
            estimate.deliveryModel == DeliveryModel.hybrid;
        final canRebaseline =
            (provider.currentRole == RBACRole.approver ||
                provider.currentRole == RBACRole.admin) &&
            baseline.rebaselineRemaining > 0 &&
            variance.delta != 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_down,
                      color: LightModeColors.accent, size: 20),
                  const SizedBox(width: 8),
                  const Text('Variance & Re-baseline',
                      style: TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE4E7EC)),
                    ),
                    child: Text(
                      'Re-baselines: ${baseline.rebaselineRemaining}/2',
                      style: const TextStyle(
                          color: Color(0xFF495057),
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Summary cards
              Row(
                children: [
                  Expanded(
                      child: _summaryCard('Baseline',
                          formatCurrency(variance.baselineTotal, 'USD'),
                          'v${baseline.version}', const Color(0xFF6B7280))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _summaryCard('Current',
                          formatCurrency(variance.currentTotal, 'USD'),
                          '${estimate.lines.length} lines', const Color(0xFF1A1D1F))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _summaryCard(
                          'Variance',
                          formatVariance(variance.delta, 'USD'),
                          formatPercent(variance.deltaPct),
                          variance.delta > 0
                              ? const Color(0xFFD97706)
                              : variance.delta < 0
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF6B7280),
                          highlight: true)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Variance by category
                  Expanded(
                    child: _buildVarianceByCategory(variance, 'USD'),
                  ),
                  const SizedBox(width: 24),
                  // Variance entries + re-baseline
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Variance entries',
                            style: TextStyle(
                                color: Color(0xFF1A1D1F),
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        if (varianceLines.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFE4E7EC)),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Column(
                                children: [
                                  Icon(Icons.check,
                                      color: Color(0xFF16A34A), size: 32),
                                  SizedBox(height: 8),
                                  Text('No variance entries',
                                      style: TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          )
                        else
                          ...varianceLines.map((l) => _buildVarianceLine(l, 'USD')),
                        const SizedBox(height: 24),
                        // Re-baseline section
                        const Row(
                          children: [
                            Icon(Icons.refresh,
                                color: LightModeColors.accent, size: 16),
                            SizedBox(width: 6),
                            Text('Re-baseline',
                                style: TextStyle(
                                    color: Color(0xFF1A1D1F),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Progress bar
                        LinearProgressIndicator(
                          value:
                              (2 - baseline.rebaselineRemaining) / 2,
                          backgroundColor: const Color(0xFFE5E7EB),
                          color: LightModeColors.accent,
                          minHeight: 6,
                        ),
                        const SizedBox(height: 8),
                        Text(
                            'Re-baselines used: ${2 - baseline.rebaselineRemaining} of 2',
                            style: const TextStyle(
                                color: Color(0xFF495057), fontSize: 12)),
                        const SizedBox(height: 12),
                        if (baseline.rebaselineRemaining > 0)
                          if (canRebaseline)
                            FilledButton.icon(
                              onPressed: () => _showRebaselineDialog(
                                  context, provider, estimate, isWaterfall),
                              icon: const Icon(Icons.refresh, size: 14),
                              label: Text(
                                  'Re-baseline (v${baseline.version + 1})'),
                              style: FilledButton.styleFrom(
                                backgroundColor: LightModeColors.accent,
                                foregroundColor: LightModeColors.lightOnPrimary,
                              ),
                            )
                          else
                            const Text('No variance to re-baseline',
                                style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 12))
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFD97706)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber,
                                    color: Color(0xFFD97706), size: 14),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Max 2 re-baselines consumed. Further changes require a new estimate version.',
                                    style: TextStyle(
                                        color: Color(0xFFD97706),
                                        fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard(
      String label, String value, String subtext, Color color,
      {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? LightModeColors.accent.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? LightModeColors.accent.withValues(alpha: 0.3)
              : const Color(0xFFE4E7EC),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(subtext,
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildVarianceByCategory(variance, String currency) {
    final cats = variance.byCategory
        .where((c) => c.baseline > 0 || c.current > 0 || c.delta != 0)
        .toList();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VARIANCE BY CATEGORY',
              style: TextStyle(
                  color: LightModeColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          ...cats.map((c) {
            final deltaColor = c.delta > 0
                ? const Color(0xFFD97706)
                : c.delta < 0
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF6B7280);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(c.label,
                        style: const TextStyle(
                            color: Color(0xFF495057), fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(formatCurrency(c.baseline, currency),
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12)),
                  const Text(' → ',
                      style: TextStyle(color: Color(0xFF9CA3AF))),
                  Text(formatCurrency(c.current, currency),
                      style: const TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: Text(
                      c.delta != 0
                          ? formatVariance(c.delta, currency)
                          : '—',
                      style: TextStyle(
                          color: deltaColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVarianceLine(CostLine line, String currency) {
    final delta = line.varianceDelta ?? 0;
    final deltaColor = delta > 0
        ? const Color(0xFFD97706)
        : delta < 0
            ? const Color(0xFF16A34A)
            : const Color(0xFF6B7280);
    final typeLabel = line.varianceType == VarianceType.add
        ? 'Added'
        : line.varianceType == VarianceType.change
            ? 'Changed'
            : 'Removed';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: deltaColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(typeLabel.toUpperCase(),
                style: TextStyle(
                    color: deltaColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(line.description,
                style: const TextStyle(
                    color: Color(0xFF1A1D1F),
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          Text(formatVariance(delta, currency),
              style: TextStyle(
                  color: deltaColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
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
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.refresh, color: LightModeColors.accent, size: 18),
            const SizedBox(width: 8),
            Text('Re-baseline to v${estimate.baseline!.version + 1}',
                style: const TextStyle(
                    color: Color(0xFF1A1D1F), fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for re-baseline',
                  labelStyle: TextStyle(color: Color(0xFF6B7280)),
                  hintText:
                      'Describe the major change that warrants a re-baseline...',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                ),
                style: const TextStyle(color: Color(0xFF1A1D1F), fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (isWaterfall)
                TextField(
                  controller: mocCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Management of Change (MoC) ID',
                    labelStyle: TextStyle(color: Color(0xFF6B7280)),
                    hintText: 'e.g. MOC-2026-001',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                  style: const TextStyle(color: Color(0xFF1A1D1F), fontSize: 13),
                )
              else
                TextField(
                  controller: agileCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Information note',
                    labelStyle: TextStyle(color: Color(0xFF6B7280)),
                    hintText:
                        'Brief note explaining the change (Agile — no formal MoC)...',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                  style: const TextStyle(color: Color(0xFF1A1D1F), fontSize: 13),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            onPressed: () {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              final mocId = isWaterfall ? mocCtrl.text.trim() : null;
              final agileNote =
                  !isWaterfall ? agileCtrl.text.trim() : null;
              if (isWaterfall && (mocId == null || mocId.isEmpty)) return;
              if (!isWaterfall && (agileNote == null || agileNote.isEmpty)) {
                return;
              }
              provider.rebaseline(
                  reason: reason, mocId: mocId, agileInfoNote: agileNote);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: LightModeColors.accent,
                foregroundColor: LightModeColors.lightOnPrimary),
            child: Text(
                'Lock v${estimate.baseline!.version + 1}'),
          ),
        ],
      ),
    );
  }
}
