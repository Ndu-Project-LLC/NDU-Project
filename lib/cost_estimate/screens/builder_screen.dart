library;

/// Builder Screen — Treasury-treated cost estimate builder with 4 sub-tabs.
///
/// Design language:
///   "The Treasury" — premium, calm, light-mode executive cockpit built on
///   the NDU brand yellow (#FFC812) + amber (#D97706) gradient. Generous
///   whitespace, tabular figures everywhere, hairline borders, layered soft
///   shadows, and a bento-style composition.
///
/// Tabs: Direct Costs, Indirect Costs, SSHER & Quality, Additional Elements.
/// Shows cost lines grouped by category with add/edit/delete + live totals
/// sidebar (TotalsPanel).
///
/// Rendered inside the Cost Estimate module's [ResponsiveScaffold] body —
/// no Scaffold of its own.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/cost_estimate/widgets/totals_panel.dart';
import 'package:ndu_project/cost_estimate/widgets/add_line_dialog.dart';
import 'package:ndu_project/cost_estimate/widgets/treasury_components.dart';
import 'package:ndu_project/services/user_preferences_service.dart';

class BuilderScreen extends StatefulWidget {
  const BuilderScreen({super.key});

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _subTabs = [
    ('Direct Costs', [
      CostCategory.labor,
      CostCategory.materials,
      CostCategory.software,
      CostCategory.procurement,
      CostCategory.travelTraining,
      CostCategory.construction,
    ]),
    ('Indirect Costs', [
      CostCategory.projectTeam,
      CostCategory.overheads,
      CostCategory.ga,
      CostCategory.facilities,
      CostCategory.insuranceCompliance,
    ]),
    ('SSHER & Quality', [
      CostCategory.ssher,
      CostCategory.quality,
    ]),
    ('Additional Elements', [
      CostCategory.riskAllowance,
      CostCategory.contingency,
      CostCategory.mgmtReserve,
      CostCategory.escalation,
      CostCategory.taxes,
      CostCategory.financing,
      CostCategory.startup,
      CostCategory.warranty,
      CostCategory.decommissioning,
    ]),
  ];

  // Tab accent tints — warm Treasury palette progression
  static const _tabTints = <Color>[
    Color(0xFFD97706), // Direct — amber (brand deep)
    Color(0xFF8B5CF6), // Indirect — violet
    Color(0xFFEC4899), // SSHER & Quality — pink
    Color(0xFF06B6D4), // Additional — cyan
  ];
  static const _tabTintsSoft = <Color>[
    Color(0xFFFFF3E0),
    Color(0xFFF4EEFF),
    Color(0xFFFCE7F3),
    Color(0xFFCFFAFE),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CostEstimateProvider>(
      builder: (context, provider, _) {
        final estimate = provider.estimate!;
        final isBaselined = estimate.status == EstimateStatus.baselined ||
            estimate.status == EstimateStatus.rebaselined;
        final canEdit = provider.currentRole == RBACRole.editor ||
            provider.currentRole == RBACRole.approver ||
            provider.currentRole == RBACRole.admin;
        final canEditNow = canEdit && !isBaselined;

        final currencySymbol = UserPreferencesService.currencySymbolSync;
        final tabIndex = _tabController.index;
        final tabCategories = _subTabs[tabIndex].$2;
        final tabLines = estimate.lines
            .where((l) => tabCategories.contains(l.category))
            .toList();
        final tabTotal = tabLines.fold(0.0, (a, l) => a + l.total);
        final totalLines = estimate.lines.length;
        final grandTotal = estimate.totals.costBaseline;

        return Container(
          color: TreasuryTokens.canvas,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Hero command band ─────────────────────────────────
                TreasuryHeroBand(
                  eyebrow: 'COST ESTIMATE · BUILDER',
                  title: 'Cost Line Builder',
                  subtitle:
                      '$totalLines lines · ${estimate.className.label} · $currencySymbol${treasuryFmt(grandTotal)} baseline',
                  statusLabel: isBaselined
                      ? 'Baselined v${estimate.baseline?.version ?? 1}'
                      : 'Draft — open for edits',
                  statusLive: isBaselined,
                  contextChips: [
                    TreasuryHeroChip(
                      icon: Icons.flag_outlined,
                      label: 'Project',
                      value: estimate.projectName,
                    ),
                    TreasuryHeroChip(
                      icon: Icons.layers_outlined,
                      label: 'Active Tab',
                      value: _subTabs[tabIndex].$1,
                    ),
                    TreasuryHeroChip(
                      icon: Icons.shield_outlined,
                      label: 'Class',
                      value: estimate.className.label,
                    ),
                  ],
                  actions: [
                    if (canEditNow)
                      TreasuryHeroAction(
                        icon: Icons.add_rounded,
                        label: 'Add line',
                        primary: true,
                        onTap: () => _showAddLineDialog(context, provider,
                            tabCategories.isNotEmpty
                                ? tabCategories.first
                                : CostCategory.labor),
                      ),
                  ],
                ),
                const SizedBox(height: 22),

                // ── 2. Premium KPI strip ─────────────────────────────────
                TreasuryKpiStrip(
                  kpis: [
                    TreasuryKpiSpec(
                      label: 'Tab Total',
                      value:
                          '$currencySymbol${treasuryFmt(tabTotal)}',
                      sub: '${tabLines.length} lines in this tab',
                      icon: Icons.account_balance_wallet_outlined,
                      tint: _tabTints[tabIndex],
                      tintSoft: _tabTintsSoft[tabIndex],
                    ),
                    TreasuryKpiSpec(
                      label: 'Estimate Total',
                      value:
                          '$currencySymbol${treasuryFmt(grandTotal)}',
                      sub: 'All categories combined',
                      icon: Icons.shield_outlined,
                      tint: const Color(0xFFD97706),
                      tintSoft: const Color(0xFFFFF3E0),
                    ),
                    TreasuryKpiSpec(
                      label: 'Total Lines',
                      value: '$totalLines',
                      sub: 'Itemised cost lines',
                      icon: Icons.list_alt_rounded,
                      tint: const Color(0xFF10B981),
                      tintSoft: const Color(0xFFE7F8F0),
                    ),
                    TreasuryKpiSpec(
                      label: 'Avg / Line',
                      value: totalLines > 0
                          ? '$currencySymbol${treasuryFmt(grandTotal / totalLines)}'
                          : '${currencySymbol}0',
                      sub: 'Mean cost across estimate',
                      icon: Icons.analytics_outlined,
                      tint: const Color(0xFF6366F1),
                      tintSoft: const Color(0xFFEEF0FF),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // ── 3. Treasury sub-tab bar ──────────────────────────────
                _TreasurySubTabBar(
                  controller: _tabController,
                  tabs: _subTabs.map((t) => t.$1).toList(),
                  tints: _tabTints,
                  tintsSoft: _tabTintsSoft,
                  counts: _subTabs
                      .map((t) => estimate.lines
                          .where((l) => t.$2.contains(l.category))
                          .length)
                      .toList(),
                ),
                if (isBaselined) ...[
                  const SizedBox(height: 14),
                  _BaselinedNotice(version: estimate.baseline?.version ?? 1,
                      remaining: estimate.baseline?.rebaselineRemaining ?? 0),
                ],
                const SizedBox(height: 18),

                // ── 4. Two-column: lines list + totals sidebar ──────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lines column
                    Expanded(
                      child: _buildLinesColumn(
                        context,
                        provider,
                        estimate,
                        tabCategories,
                        tabLines,
                        tabTotal,
                        canEditNow,
                        currencySymbol,
                        tabIndex,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Totals sidebar
                    SizedBox(
                      width: 320,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 0),
                        child: TotalsPanel(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinesColumn(
    BuildContext context,
    CostEstimateProvider provider,
    CostEstimate estimate,
    List<CostCategory> categories,
    List<CostLine> lines,
    double tabTotal,
    bool canEditNow,
    String currencySymbol,
    int tabIndex,
  ) {
    return TreasurySectionCard(
      title: _subTabs[tabIndex].$1,
      subtitle:
          '${lines.length} ${lines.length == 1 ? "line" : "lines"} · $currencySymbol${treasuryFmt(tabTotal)}',
      trailing: canEditNow
          ? TreasuryPrimaryButton(
              icon: Icons.add_rounded,
              label: 'Add line',
              onPressed: () => _showAddLineDialog(context, provider,
                  categories.isNotEmpty ? categories.first : CostCategory.labor),
            )
          : null,
      child: lines.isEmpty
          ? TreasuryEmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No ${_subTabs[tabIndex].$1.toLowerCase()} yet',
              body:
                  'Add your first cost line in this category. The totals sidebar updates live as you build out the estimate.',
              ctaLabel: canEditNow ? 'Add first line' : null,
              onCta: canEditNow
                  ? () => _showAddLineDialog(context, provider,
                      categories.isNotEmpty ? categories.first : CostCategory.labor)
                  : null,
            )
          : Column(
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TreasuryLineRow(
                      line: line,
                      currencySymbol: currencySymbol,
                      canEdit: canEditNow,
                      onEdit: () => _showAddLineDialog(
                          context, provider, line.category, line),
                      onDelete: () => provider.removeLine(line.id),
                    ),
                  ),
              ],
            ),
    );
  }

  void _showAddLineDialog(
    BuildContext context,
    CostEstimateProvider provider,
    CostCategory defaultCategory, [
    CostLine? editing,
  ]) {
    showDialog(
      context: context,
      builder: (ctx) => AddLineDialog(
        defaultCategory: defaultCategory,
        editingLine: editing,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TREASURY SUB-TAB BAR — pill-style with active accent tint
// ═══════════════════════════════════════════════════════════════════════════

class _TreasurySubTabBar extends StatelessWidget {
  const _TreasurySubTabBar({
    required this.controller,
    required this.tabs,
    required this.tints,
    required this.tintsSoft,
    required this.counts,
  });
  final TabController controller;
  final List<String> tabs;
  final List<Color> tints;
  final List<Color> tintsSoft;
  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: TreasuryTokens.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TreasuryTokens.hairline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _TreasurySubTabPill(
                label: tabs[i],
                count: counts[i],
                tint: tints[i],
                tintSoft: tintsSoft[i],
                active: controller.index == i,
                onTap: () {
                  controller.animateTo(i);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TreasurySubTabPill extends StatelessWidget {
  const _TreasurySubTabPill({
    required this.label,
    required this.count,
    required this.tint,
    required this.tintSoft,
    required this.active,
    required this.onTap,
  });
  final String label;
  final int count;
  final Color tint;
  final Color tintSoft;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? tint : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active
                        ? Colors.white
                        : TreasuryTokens.inkSoft,
                    letterSpacing: 0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.25)
                      : tintSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? Colors.white
                        : tint,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BASELINED NOTICE — Treasury-styled inline banner
// ═══════════════════════════════════════════════════════════════════════════

class _BaselinedNotice extends StatelessWidget {
  const _BaselinedNotice({required this.version, required this.remaining});
  final int version;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: TreasuryTokens.warningSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: TreasuryTokens.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: TreasuryTokens.warning.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.lock_rounded,
                size: 15, color: TreasuryTokens.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimate is baselined (v$version)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: TreasuryTokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Edits create variance entries. Re-baselines remaining: $remaining',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: TreasuryTokens.muted,
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
// TREASURY LINE ROW — premium card for each cost line
// ═══════════════════════════════════════════════════════════════════════════

class _TreasuryLineRow extends StatelessWidget {
  const _TreasuryLineRow({
    required this.line,
    required this.currencySymbol,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });
  final CostLine line;
  final String currencySymbol;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TreasuryTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TreasuryTokens.hairline),
      ),
      child: Row(
        children: [
          // Icon tile
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: TreasuryTokens.brandSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: TreasuryTokens.brand.withValues(alpha: 0.20),
              ),
            ),
            child: Icon(Icons.receipt_long_rounded,
                size: 18, color: TreasuryTokens.brandDeep),
          ),
          const SizedBox(width: 12),
          // Description + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        line.description,
                        style: const TextStyle(
                          color: TreasuryTokens.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (line.aiGenerated) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF3B82F6)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'AI',
                          style: TextStyle(
                            color: Color(0xFF3B82F6),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                    if (!line.inSchedule) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: TreasuryTokens.warningSoft,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: TreasuryTokens.warning
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'NOT IN SCHEDULE',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.label_outline,
                        size: 11,
                        color: TreasuryTokens.mutedSoft),
                    const SizedBox(width: 4),
                    Text(
                      line.category.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: TreasuryTokens.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.source_outlined,
                        size: 11,
                        color: TreasuryTokens.mutedSoft),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        line.basisSource.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: TreasuryTokens.muted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Total
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '$currencySymbol${formatCurrency(line.total, 'USD')}',
              style: const TextStyle(
                color: TreasuryTokens.ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(width: 8),
            _IconAction(
              icon: Icons.edit_outlined,
              onTap: onEdit,
              tint: TreasuryTokens.muted,
            ),
            const SizedBox(width: 4),
            _IconAction(
              icon: Icons.delete_outline,
              onTap: onDelete,
              tint: const Color(0xFFDC2626),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.onTap,
    required this.tint,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: tint),
        ),
      ),
    );
  }
}
