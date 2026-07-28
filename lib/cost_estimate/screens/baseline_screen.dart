library;

/// Baseline Screen — shows the locked baseline snapshot.
///
/// Rendered inside the Cost Estimate module's [ResponsiveScaffold] body —
/// no Scaffold of its own. Light-mode (white) theme.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';

class BaselineScreen extends StatelessWidget {
  const BaselineScreen({super.key});

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
                const Icon(Icons.lock, color: Color(0xFF9CA3AF), size: 48),
                const SizedBox(height: 16),
                const Text('No baseline yet',
                    style: TextStyle(
                        color: Color(0xFF1A1D1F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                    'Complete the Review & Acceptance flow to lock the baseline.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
              ],
            ),
          );
        }

        final snap = baseline.snapshot;
        final t = snap.totals;
        final currency = estimate.currency;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock, color: Color(0xFF16A34A), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Baseline — v${baseline.version}',
                    style: const TextStyle(
                        color: Color(0xFF1A1D1F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('LOCKED',
                        style: TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Immutability warning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LightModeColors.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: LightModeColors.accent
                          .withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber,
                        color: LightModeColors.accent, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Baseline is immutable. Edits create variance entries. Major changes via MoC can consume a re-baseline (max 2).',
                        style: TextStyle(
                            color: Color(0xFF495057), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata
                  Expanded(
                    child: _buildMetadataCard(baseline, snap),
                  ),
                  const SizedBox(width: 24),
                  // Totals
                  Expanded(
                    child: _buildTotalsCard(t, currency),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetadataCard(baseline, snap) {
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
          const Text('SNAPSHOT METADATA',
              style: TextStyle(
                  color: LightModeColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          _metaRow('Version', 'v${baseline.version}'),
          _metaRow('Locked at', baseline.lockedAt.toString().substring(0, 19)),
          _metaRow('Locked by', baseline.lockedBy),
          _metaRow('Estimate class', '${snap.className.label} — ${snap.className.name}'),
          _metaRow('Delivery model', snap.deliveryModel.label),
          const Divider(color: Color(0xFFE4E7EC), height: 16),
          _metaRow('Re-baselines remaining',
              '${baseline.rebaselineRemaining} of 2',
              highlight: baseline.rebaselineRemaining == 0),
          _metaRow('Lines in baseline', '${snap.lines.length}'),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: Color(0xFF495057), fontSize: 13)),
          Text(value,
              style: TextStyle(
                color: highlight
                    ? const Color(0xFFD97706)
                    : const Color(0xFF1A1D1F),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(t, String currency) {
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
          const Text('BASELINE TOTALS',
              style: TextStyle(
                  color: LightModeColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          _totalRow('Direct costs', t.direct, currency),
          _totalRow('Indirect costs', t.indirect, currency),
          _totalRow('SSHER & Quality', t.sherQuality, currency),
          _totalRow('Risk allowances', t.riskAllowances, currency),
          _totalRow('Contingency', t.contingency, currency),
          _totalRow('Escalation', t.escalation, currency),
          _totalRow('Taxes & duties', t.taxes, currency),
          const Divider(color: Color(0xFFE4E7EC), height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: LightModeColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield,
                    color: LightModeColors.accent, size: 16),
                const SizedBox(width: 8),
                const Text('Cost Baseline',
                    style: TextStyle(
                        color: Color(0xFF1A1D1F),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(formatCurrency(t.costBaseline, currency),
                    style: const TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Authorized',
                  style: TextStyle(
                      color: Color(0xFF1A1D1F),
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              Text(formatCurrency(t.totalAuthorizedBudget, currency),
                  style: const TextStyle(
                      color: Color(0xFF1A1D1F),
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, String currency) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: Color(0xFF495057), fontSize: 13)),
          Text(formatCurrency(value, currency),
              style: const TextStyle(
                  color: Color(0xFF1A1D1F),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
