library;

/// Baseline Screen — Treasury-treated locked baseline snapshot.
///
/// Design language:
///   "The Treasury" — premium, calm, light-mode executive cockpit built on
///   the NDU brand yellow (#FFC812) + amber (#D97706) gradient.
///
/// Rendered inside the Cost Estimate module's [ResponsiveScaffold] body —
/// no Scaffold of its own.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/widgets/treasury_components.dart';
import 'package:ndu_project/services/user_preferences_service.dart';

class BaselineScreen extends StatelessWidget {
  const BaselineScreen({super.key});

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
                    eyebrow: 'COST ESTIMATE · BASELINE',
                    title: 'Locked Baseline',
                    subtitle:
                        'The frozen snapshot of your estimate — versioned, immutable, ready for variance tracking.',
                    statusLabel: 'No baseline yet',
                    statusLive: false,
                    contextChips: [
                      TreasuryHeroChip(
                        icon: Icons.flag_outlined,
                        label: 'Project',
                        value: estimate.projectName,
                      ),
                      TreasuryHeroChip(
                        icon: Icons.class_outlined,
                        label: 'Class',
                        value: estimate.className.label,
                      ),
                      TreasuryHeroChip(
                        icon: Icons.payments_outlined,
                        label: 'Estimate',
                        value:
                            '$currencySymbol${treasuryFmt(estimate.totals.costBaseline)}',
                      ),
                    ],
                    actions: const [],
                  ),
                  const SizedBox(height: 22),
                  const TreasuryEmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'No baseline yet',
                    body:
                        'Complete the Review & Acceptance flow on the Review tab to lock the baseline. Once locked, you\'ll see the versioned snapshot here.',
                  ),
                ],
              ),
            ),
          );
        }

        final snap = baseline.snapshot;
        final t = snap.totals;
        final currency = estimate.currency;
        final linesInBaseline = snap.lines.length;
        final rebaselinesUsed = 2 - baseline.rebaselineRemaining;

        // Category rows (for totals breakdown)
        final categories = <_BaselineCategory>[
          _BaselineCategory(
              'Direct costs', t.direct, const Color(0xFFB8860B), Icons.engineering_outlined),
          _BaselineCategory(
              'Indirect costs', t.indirect, const Color(0xFFB8860B), Icons.account_tree_outlined),
          _BaselineCategory('SSHER & Quality', t.sherQuality,
              const Color(0xFFD97706), Icons.health_and_safety_outlined),
          _BaselineCategory('Risk allowances', t.riskAllowances,
              const Color(0xFFF59E0B), Icons.shield_outlined),
          _BaselineCategory(
              'Contingency', t.contingency, const Color(0xFF10B981), Icons.savings_outlined),
          _BaselineCategory(
              'Escalation', t.escalation, const Color(0xFFD97706), Icons.trending_up_rounded),
          _BaselineCategory(
              'Taxes & duties', t.taxes, const Color(0xFF64748B), Icons.receipt_long_outlined),
        ];
        final maxCat = categories
            .fold<double>(0, (m, c) => c.value > m ? c.value : m);

        return Container(
          color: TreasuryTokens.canvas,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Hero command band ─────────────────────────────────
                TreasuryHeroBand(
                  eyebrow: 'COST ESTIMATE · BASELINE',
                  title: 'Locked Baseline',
                  subtitle:
                      'The frozen snapshot of your estimate — versioned, immutable, ready for variance tracking.',
                  statusLabel: 'Baselined v${baseline.version}',
                  statusLive: true,
                  contextChips: [
                    TreasuryHeroChip(
                      icon: Icons.tag_rounded,
                      label: 'Version',
                      value: 'v${baseline.version}',
                    ),
                    const TreasuryHeroChip(
                      icon: Icons.lock_rounded,
                      label: 'Status',
                      value: 'LOCKED',
                    ),
                    TreasuryHeroChip(
                      icon: Icons.person_outline_rounded,
                      label: 'Locked by',
                      value: baseline.lockedBy,
                    ),
                  ],
                  actions: const [],
                ),
                const SizedBox(height: 22),

                // ── 2. Premium KPI strip ─────────────────────────────────
                TreasuryKpiStrip(
                  kpis: [
                    TreasuryKpiSpec(
                      label: 'Cost Baseline',
                      value:
                          '$currencySymbol${treasuryFmt(t.costBaseline)}',
                      sub: 'Frozen total',
                      icon: Icons.shield_outlined,
                      tint: const Color(0xFFD97706),
                      tintSoft: const Color(0xFFFFF3E0),
                    ),
                    TreasuryKpiSpec(
                      label: 'Total Authorized',
                      value:
                          '$currencySymbol${treasuryFmt(t.totalAuthorizedBudget)}',
                      sub: 'Baseline + mgmt reserve',
                      icon: Icons.account_balance_wallet_rounded,
                      tint: const Color(0xFFB8860B),
                      tintSoft: const Color(0xFFEEF0FF),
                    ),
                    TreasuryKpiSpec(
                      label: 'Lines in Snapshot',
                      value: '$linesInBaseline',
                      sub: 'Itemised cost lines',
                      icon: Icons.list_alt_rounded,
                      tint: const Color(0xFF10B981),
                      tintSoft: const Color(0xFFE7F8F0),
                    ),
                    TreasuryKpiSpec(
                      label: 'Re-baselines Used',
                      value: '$rebaselinesUsed / 2',
                      sub:
                          '${baseline.rebaselineRemaining} remaining via MoC',
                      icon: Icons.refresh_rounded,
                      tint: const Color(0xFFB8860B),
                      tintSoft: const Color(0xFFF4EEFF),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // ── 3. Immutability notice ──────────────────────────────
                _ImmutabilityNotice(
                  rebaselinesRemaining: baseline.rebaselineRemaining,
                ),
                const SizedBox(height: 22),

                // ── 4. Snapshot metadata + totals ──────────────────────
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 1000;
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _buildMetadataCard(baseline, snap)),
                          const SizedBox(width: 14),
                          Expanded(flex: 7, child: _buildTotalsCard(categories, maxCat, t, currency)),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildMetadataCard(baseline, snap),
                        const SizedBox(height: 14),
                        _buildTotalsCard(categories, maxCat, t, currency),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),

                // ── 5. Totals spotlight bar ────────────────────────────
                TreasurySpotlightBar(
                  columns: [
                    TreasurySpotlightColumn(
                      icon: Icons.shield_outlined,
                      label: 'Cost Baseline',
                      value:
                          '$currencySymbol${treasuryFmt(t.costBaseline)}',
                      tint: const Color(0xFFD97706),
                      tintSoft: const Color(0xFFFFF3E0),
                    ),
                    TreasurySpotlightColumn(
                      icon: Icons.savings_outlined,
                      label: 'Mgmt Reserve',
                      value:
                          '$currencySymbol${treasuryFmt(t.managementReserve)}',
                      tint: const Color(0xFF64748B),
                      tintSoft: const Color(0xFFF1F5F9),
                    ),
                    TreasurySpotlightColumn(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Total Authorized',
                      value:
                          '$currencySymbol${treasuryFmt(t.totalAuthorizedBudget)}',
                      tint: TreasuryTokens.brand,
                      tintSoft: TreasuryTokens.brandSoft,
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

  Widget _buildMetadataCard(baseline, snap) {
    return TreasurySectionCard(
      title: 'Snapshot Metadata',
      subtitle: 'Audit trail for this baseline version',
      child: Column(
        children: [
          _MetaRow(
            icon: Icons.tag_rounded,
            label: 'Version',
            value: 'v${baseline.version}',
            tint: TreasuryTokens.brandDeep,
          ),
          _MetaRow(
            icon: Icons.schedule_outlined,
            label: 'Locked at',
            value: baseline.lockedAt.toString().substring(0, 19),
          ),
          _MetaRow(
            icon: Icons.person_outline_rounded,
            label: 'Locked by',
            value: baseline.lockedBy,
          ),
          _MetaRow(
            icon: Icons.class_outlined,
            label: 'Estimate class',
            value:
                '${snap.className.label} — ${snap.className.name}',
          ),
          _MetaRow(
            icon: Icons.delivery_dining_outlined,
            label: 'Delivery model',
            value: snap.deliveryModel.label,
          ),
          const Divider(
              height: 20,
              thickness: 1,
              color: TreasuryTokens.hairline),
          _MetaRow(
            icon: Icons.refresh_rounded,
            label: 'Re-baselines remaining',
            value:
                '${baseline.rebaselineRemaining} of 2',
            tint: baseline.rebaselineRemaining == 0
                ? TreasuryTokens.warning
                : null,
          ),
          _MetaRow(
            icon: Icons.list_alt_rounded,
            label: 'Lines in baseline',
            value: '${snap.lines.length}',
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(
      List<_BaselineCategory> categories, double maxCat, t, String currency) {
    return TreasurySectionCard(
      title: 'Baseline Totals',
      subtitle: 'Category breakdown of the frozen snapshot',
      child: Column(
        children: [
          // Header row
          const Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Expanded(
                    flex: 5,
                    child: TreasuryTableHeader('CATEGORY')),
                Expanded(
                    flex: 3,
                    child: TreasuryTableHeader('SHARE',
                        alignRight: true)),
                Expanded(
                    flex: 4,
                    child: TreasuryTableHeader('VALUE',
                        alignRight: true)),
              ],
            ),
          ),
          const Divider(
              height: 1,
              thickness: 1,
              color: TreasuryTokens.hairline),
          // Rows
          for (final c in categories)
            _BaselineCategoryRow(
              cat: c,
              pct: maxCat > 0
                  ? (c.value / maxCat).clamp(0.0, 1.0)
                  : 0.0,
              sharePct: t.costBaseline > 0
                  ? (c.value / t.costBaseline * 100)
                  : 0.0,
              currencySymbol: _symbolFor(currency),
            ),
          const Divider(
              height: 1,
              thickness: 1,
              color: TreasuryTokens.hairline),
          const SizedBox(height: 6),
          // Cost Baseline highlighted row
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: TreasuryTokens.brandSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color:
                      TreasuryTokens.brand.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: TreasuryTokens.brand
                          .withValues(alpha: 0.30),
                    ),
                  ),
                  child: const Icon(Icons.shield_outlined,
                      size: 15, color: TreasuryTokens.brandDeep),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Cost Baseline',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: TreasuryTokens.ink)),
                ),
                Text(
                  '${_symbolFor(currency)}${treasuryFmt(t.costBaseline)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: TreasuryTokens.brandDeep,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Total Authorized — full width spotlight
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: TreasuryTokens.brand
                        .withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      size: 15, color: TreasuryTokens.brand),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Total Authorized',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white70)),
                ),
                Text(
                  '${_symbolFor(currency)}${treasuryFmt(t.totalAuthorizedBudget)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: TreasuryTokens.brand,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _symbolFor(String currency) =>
      switch (currency) {'USD' => '\$', 'EUR' => '€', 'GBP' => '£', _ => ''};
}

class _BaselineCategory {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  const _BaselineCategory(this.label, this.value, this.color, this.icon);
}

class _BaselineCategoryRow extends StatelessWidget {
  const _BaselineCategoryRow({
    required this.cat,
    required this.pct,
    required this.sharePct,
    required this.currencySymbol,
  });
  final _BaselineCategory cat;
  final double pct;
  final double sharePct;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: cat.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(cat.icon,
                    size: 14,
                    color: cat.color.withValues(alpha: 0.85)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    cat.label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: TreasuryTokens.inkSoft,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: TreasuryTokens.hairlineSoft,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(cat.color),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${sharePct.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: TreasuryTokens.muted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              '$currencySymbol${treasuryFmt(cat.value)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: TreasuryTokens.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.tint,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final effectiveTint = tint ?? TreasuryTokens.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 14, color: effectiveTint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: TreasuryTokens.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500)),
          ),
          Flexible(
            child: Text(value,
                style: TextStyle(
                  color: tint ?? TreasuryTokens.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _ImmutabilityNotice extends StatelessWidget {
  const _ImmutabilityNotice({required this.rebaselinesRemaining});
  final int rebaselinesRemaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: TreasuryTokens.warningSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: TreasuryTokens.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: TreasuryTokens.warning.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                size: 20, color: TreasuryTokens.warning),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Baseline is immutable',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: TreasuryTokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Edits create variance entries. Major changes via MoC can consume a re-baseline (max 2; $rebaselinesRemaining remaining).',
                  style: const TextStyle(
                    fontSize: 12,
                    color: TreasuryTokens.muted,
                    height: 1.45,
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
