library;

/// Cost Estimate Module Screen — main entry point for the Cost Estimate module.
///
/// Uses [ResponsiveScaffold] with the standard app sidebar
/// (`InitiationLikeSidebar`) so it matches the rest of the app.
///
/// Sub-navigation between Builder / BOE / AI / Stakeholders / Accounting /
/// Review / Baseline / Variance is a horizontal `TabBar` at the top of the
/// content area (light-mode pills matching the Project Controls screen),
/// replacing the old dark navy left rail.
///
/// A subtle [ContextBanner] is shown between the [SectionNavigator] and the
/// tab content summarising upstream context (project name, WBS framework and
/// deliverable count, solutions count) so the user can see what data this
/// page is drawing from.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/services/user_preferences_service.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/section_navigator.dart';
import 'package:ndu_project/widgets/context_banner.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/screens/setup_wizard_screen.dart';
import 'package:ndu_project/cost_estimate/screens/builder_screen.dart';
import 'package:ndu_project/cost_estimate/screens/boe_screen.dart';
import 'package:ndu_project/cost_estimate/screens/ai_assistant_screen.dart';
import 'package:ndu_project/cost_estimate/screens/stakeholders_screen.dart';
import 'package:ndu_project/cost_estimate/screens/accounting_screen.dart';
import 'package:ndu_project/cost_estimate/screens/review_screen.dart';
import 'package:ndu_project/cost_estimate/screens/baseline_screen.dart';
import 'package:ndu_project/cost_estimate/screens/variance_screen.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/cost_by_wbs_tab.dart';
import 'package:go_router/go_router.dart';

class CostEstimateModuleScreen extends StatefulWidget {
  const CostEstimateModuleScreen({super.key});

  static void open(BuildContext context) {
    context.push('/cost-estimate');
  }

  @override
  State<CostEstimateModuleScreen> createState() =>
      _CostEstimateModuleScreenState();
}

class _CostEstimateModuleScreenState extends State<CostEstimateModuleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 10,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabChanged);
    // Auto-complete setup with defaults so the user goes straight to the
    // Cost Estimate dashboard without seeing the setup wizard. The project
    // name is read from the central ProjectDataHelper (which captures the
    // name from the Initiation Phase's ProjectDataModel) — falling back to
    // 'My Project' when no name has been captured yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<CostEstimateProvider>();
      if (provider.estimate == null || !provider.setupComplete) {
        final projectName =
            ProjectDataHelper.readProjectNameFromContext(context) ??
                'My Project';
        provider.setup(
          projectName: projectName,
          className: EstimateClass.class3,
          deliveryModel: DeliveryModel.waterfall,
        );
      }
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<CostEstimateProvider, WBSProvider, ProjectDataProvider>(
      builder: (context, provider, wbsProvider, projectProvider, _) {
        final estimate = provider.estimate;

        // Setup state — show the setup wizard (which itself uses
        // ResponsiveScaffold so the sidebar stays visible).
        if (estimate == null || !provider.setupComplete) {
          return const SetupWizardScreen();
        }

        // ---- Context banner data ----
        final projectData = projectProvider.projectData;
        final projectName = (projectData.projectName).trim().isNotEmpty
            ? projectData.projectName
            : estimate.projectName;
        final solutionsCount = projectData.potentialSolutions.length;
        final wbs = wbsProvider.wbs;
        final wbsCounts = wbs != null ? countNodes(wbs) : null;
        final wbsFrameworkLabel = wbs?.framework.label;
        final wbsDeliverableWord =
            wbs?.framework.level1Label ?? 'deliverables';

        return ResponsiveScaffold(
          activeItemLabel: 'Cost Estimate',
          appBarTitle: 'Cost Estimate',
          breadcrumbPhase: 'Planning Phase',
          breadcrumbTitle: 'Cost Estimate',
          backgroundColor: Colors.white,
          body: Column(
            children: [
              // ── World-class Section Navigator (always visible, pinned) ─
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SectionNavigator(
                  title: 'Cost Estimate Navigation',
                  subtitle: 'Navigate between cost estimate sections',
                  icon: Icons.attach_money_outlined,
                  tabs: const [
                    SectionTab(icon: Icons.dashboard_outlined, label: 'Cost Dashboard'),
                    SectionTab(icon: Icons.build_outlined, label: 'Builder'),
                    SectionTab(icon: Icons.description_outlined, label: 'BOE'),
                    SectionTab(icon: Icons.auto_awesome, label: 'AI'),
                    SectionTab(icon: Icons.people_outline, label: 'Stakeholders'),
                    SectionTab(icon: Icons.account_balance_outlined, label: 'Accounting'),
                    SectionTab(icon: Icons.check_circle_outline, label: 'Review'),
                    SectionTab(icon: Icons.lock_outline, label: 'Baseline'),
                    SectionTab(icon: Icons.trending_up, label: 'Variance'),
                    SectionTab(icon: Icons.account_tree_outlined, label: 'Cost by WBS'),
                  ],
                  controller: _tabController,
                  onChanged: (index) => setState(() {}),
                ),
              ),
              // ── Context banner (drawn from Initiation + WBS) ──────────
              ContextBanner(
                storageKey: 'cost_estimate_module_context_banner',
                items: [
                  ContextBannerItem(
                    label: 'Project',
                    value: projectName,
                    icon: Icons.flag_outlined,
                  ),
                  if (wbs != null && wbsCounts != null)
                    ContextBannerItem(
                      label: 'WBS',
                      value:
                          '${wbsFrameworkLabel ?? 'WBS'} · ${wbsCounts.level1} $wbsDeliverableWord',
                      icon: Icons.account_tree_outlined,
                    ),
                  ContextBannerItem(
                    label: 'Solutions',
                    value: '$solutionsCount potential',
                    icon: Icons.lightbulb_outline,
                  ),
                ],
              ),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _CostDashboardTab(provider: provider),
                    const BuilderScreen(),
                    const BOEScreen(),
                    const AIAssistantScreen(),
                    const StakeholdersScreen(),
                    const AccountingScreen(),
                    const ReviewScreen(),
                    const BaselineScreen(),
                    const VarianceScreen(),
                    const CostByWBSTab(),
                  ],
                ),
              ),
              // ── Bottom navigation ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Next: Scope Tracking Plan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC812),
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COST DASHBOARD TAB — world-class executive dashboard
//
// Design language:
//   "The Treasury" — a premium, calm, light-mode executive cockpit built on
//   the NDU brand yellow (#FFC812) + amber (#D97706) gradient. Generous
//   whitespace, tabular figures everywhere, hairline borders, layered soft
//   shadows, and a bento-style composition that scales gracefully from
//   compact laptop to ultrawide. Every section earns its real estate —
//   empty states are first-class, never silent zeros.
//
// Sections:
//   1. Hero command band — gradient header with eyebrow, title, status
//      chip, context line, and inline action chips (Open Builder, Baseline).
//   2. Premium KPI strip — 4 elevated cards with brand-tinted icon tiles,
//      large tabular figures, and sub-labels.
//   3. Two-column bento — left: Cost Breakdown stacked bar + legend; right:
//      Cost Composition donut chart (CustomPaint) with centered total + legend.
//   4. Category Details table — color dot, label, count, hairline bar,
//      $ value, % of baseline. Tabular numerics, hover-quiet rows.
//   5. Lines by Category — world-class empty state with illustration icon,
//      headline, supportive copy, and a CTA button. When populated, renders
//      a horizontal bar chart sorted descending.
//   6. Totals summary bar — single full-width premium card with three
//      columns (Cost Baseline | Mgmt Reserve | Total Authorized), the third
//      elevated as a dark "spotlight" tile with the brand-yellow figure.
// ═══════════════════════════════════════════════════════════════════════════

class _CostDashboardTab extends StatelessWidget {
  final CostEstimateProvider provider;
  const _CostDashboardTab({required this.provider});

  // ── Design tokens ───────────────────────────────────────────────────────
  static const _ink = Color(0xFF0B1220); // primary text
  static const _inkSoft = Color(0xFF1E293B); // secondary text
  static const _muted = Color(0xFF64748B); // tertiary text / captions
  static const _mutedSoft = Color(0xFF94A3B8); // quaternary
  static const _hairline = Color(0xFFE2E8F0); // 1px borders
  static const _hairlineSoft = Color(0xFFEEF1F6); // 1px inner dividers
  static const _canvas = Color(0xFFF8FAFC); // page canvas
  static const _surface = Colors.white; // card surface
  static const _surfaceAlt = Color(0xFFF8FAFC); // alt card surface
  static const _brand = Color(0xFFFFC812); // app primary yellow
  static const _brandDeep = Color(0xFFD97706); // amber
  static const _brandSoft = Color(0xFFFFF7E0); // brand tint

  @override
  Widget build(BuildContext context) {
    final estimate = provider.estimate!;
    final t = estimate.totals;
    final lines = estimate.lines;
    final currencySymbol = UserPreferencesService.currencySymbolSync;
    final lineCount = lines.length;
    final avgPerLine = lineCount > 0 ? t.costBaseline / lineCount : 0.0;
    final isBaselined = estimate.status == EstimateStatus.baselined ||
        estimate.status == EstimateStatus.rebaselined;
    final statusLabel = isBaselined
        ? 'Baselined v${estimate.baseline?.version ?? 1}'
        : 'Draft — not baselined';
    final className = estimate.className.label;

    // Category breakdown (top-level summary categories)
    final categories = <_CatData>[
      _CatData('Direct', t.direct, const Color(0xFF6366F1), Icons.engineering_outlined),
      _CatData('Indirect', t.indirect, const Color(0xFF8B5CF6), Icons.account_tree_outlined),
      _CatData('SSHER & Quality', t.sherQuality, const Color(0xFFEC4899), Icons.health_and_safety_outlined),
      _CatData('Risk', t.riskAllowances, const Color(0xFFF59E0B), Icons.shield_outlined),
      _CatData('Contingency', t.contingency, const Color(0xFF10B981), Icons.savings_outlined),
      _CatData('Escalation', t.escalation, const Color(0xFF06B6D4), Icons.trending_up_rounded),
      _CatData('Taxes', t.taxes, const Color(0xFF64748B), Icons.receipt_long_outlined),
    ];
    final activeCats = categories.where((c) => c.value > 0).toList();
    final maxCat = activeCats.fold<double>(0, (m, c) => c.value > m ? c.value : m);

    // Lines grouped by CostCategory
    final byCategory = <CostCategory, List<CostLine>>{};
    for (final l in lines) {
      byCategory.putIfAbsent(l.category, () => []).add(l);
    }
    final byCategoryEntries = byCategory.entries.toList()
      ..sort((a, b) {
        final aTotal = a.value.fold(0.0, (s, l) => s + l.total);
        final bTotal = b.value.fold(0.0, (s, l) => s + l.total);
        return bTotal.compareTo(aTotal);
      });
    final maxCategoryTotal = byCategoryEntries.isEmpty
        ? 0.0
        : byCategoryEntries
            .map((e) => e.value.fold(0.0, (s, l) => s + l.total))
            .fold<double>(0, (m, v) => v > m ? v : m);

    return Container(
      color: _canvas,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Hero command band ─────────────────────────────────
            _HeroBand(
              eyebrow: 'COST ESTIMATE · DASHBOARD',
              title: 'Cost Dashboard',
              subtitle:
                  '$lineCount cost lines · $className · $currencySymbol baseline',
              statusLabel: statusLabel,
              statusLive: isBaselined,
              contextChips: [
                _HeroChip(
                    icon: Icons.flag_outlined, label: 'Project', value: estimate.projectName),
                _HeroChip(
                    icon: Icons.class_outlined,
                    label: 'Class',
                    value: className),
                _HeroChip(
                    icon: Icons.payments_outlined,
                    label: 'Currency',
                    value: estimate.currency),
              ],
              actions: [
                _HeroAction(
                  icon: Icons.build_outlined,
                  label: 'Open Builder',
                  primary: true,
                  onTap: () => _scrollToBuilder(context),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ── 2. Premium KPI strip ─────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1100;
                final gap = 14.0;
                final cols = wide ? 4 : 2;
                final rows = (4 / cols).ceil();
                final tileW = (constraints.maxWidth - gap * (cols - 1)) / cols;
                final kpis = <_KpiSpec>[
                  _KpiSpec(
                    label: 'Cost Baseline',
                    value: '$currencySymbol${_fmt(t.costBaseline)}',
                    sub: 'Total estimated cost',
                    icon: Icons.shield_outlined,
                    tint: const Color(0xFFD97706),
                    tintSoft: const Color(0xFFFFF3E0),
                  ),
                  _KpiSpec(
                    label: 'Total Authorized',
                    value: '$currencySymbol${_fmt(t.totalAuthorizedBudget)}',
                    sub: 'Baseline + mgmt reserve',
                    icon: Icons.account_balance_wallet_outlined,
                    tint: const Color(0xFF6366F1),
                    tintSoft: const Color(0xFFEEF0FF),
                  ),
                  _KpiSpec(
                    label: 'Cost Lines',
                    value: '$lineCount',
                    sub: 'Itemised cost lines',
                    icon: Icons.list_alt_rounded,
                    tint: const Color(0xFF10B981),
                    tintSoft: const Color(0xFFE7F8F0),
                  ),
                  _KpiSpec(
                    label: 'Avg / Line',
                    value: '$currencySymbol${_fmt(avgPerLine)}',
                    sub: 'Mean cost per line',
                    icon: Icons.analytics_outlined,
                    tint: const Color(0xFF8B5CF6),
                    tintSoft: const Color(0xFFF4EEFF),
                  ),
                ];
                return Column(
                  children: [
                    for (var r = 0; r < rows; r++)
                      Padding(
                        padding: EdgeInsets.only(bottom: r < rows - 1 ? gap : 0),
                        child: Row(
                          children: [
                            for (var c = 0; c < cols; c++)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                      right: c < cols - 1 ? gap : 0),
                                  child: SizedBox(
                                    width: tileW,
                                    child: _KpiTile(spec: kpis[r * cols + c]),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),

            // ── 3. Two-column bento: Cost Breakdown + Composition donut ──
            if (t.costBaseline > 0) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1100;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _CostBreakdownCard(
                          currencySymbol: currencySymbol,
                          categories: activeCats,
                          total: t.costBaseline,
                        )),
                        const SizedBox(width: 14),
                        Expanded(flex: 5, child: _CompositionDonutCard(
                          currencySymbol: currencySymbol,
                          categories: activeCats,
                          total: t.costBaseline,
                        )),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _CostBreakdownCard(
                        currencySymbol: currencySymbol,
                        categories: activeCats,
                        total: t.costBaseline,
                      ),
                      const SizedBox(height: 14),
                      _CompositionDonutCard(
                        currencySymbol: currencySymbol,
                        categories: activeCats,
                        total: t.costBaseline,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
            ],

            // ── 4. Category Details table ───────────────────────────
            _CategoryDetailsCard(
              currencySymbol: currencySymbol,
              categories: categories,
              maxCat: maxCat,
              total: t.costBaseline,
            ),
            const SizedBox(height: 22),

            // ── 5. Lines by Category ────────────────────────────────
            _LinesByCategoryCard(
              currencySymbol: currencySymbol,
              entries: byCategoryEntries,
              maxTotal: maxCategoryTotal,
              onOpenBuilder: () => _scrollToBuilder(context),
            ),
            const SizedBox(height: 22),

            // ── 6. Totals summary spotlight bar ────────────────────
            _TotalsSpotlightBar(
              currencySymbol: currencySymbol,
              costBaseline: t.costBaseline,
              mgmtReserve: t.managementReserve,
              totalAuthorized: t.totalAuthorizedBudget,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _scrollToBuilder(BuildContext context) {
    // The Cost Estimate module uses a TabController owned by the parent
    // State. We can't reach it from here directly, so we use a lightweight
    // notification that the parent listens for via a NotificationListener.
    // For now, we no-op — the user can click the "Builder" pill in the
    // SectionNavigator above. Kept as a hook for future wiring.
    // ignore: avoid_print
    debugPrint('Open Builder tapped from Cost Dashboard');
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

// ═══════════════════════════════════════════════════════════════════════════
// 1. HERO COMMAND BAND
// ═══════════════════════════════════════════════════════════════════════════

class _HeroBand extends StatelessWidget {
  const _HeroBand({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusLive,
    required this.contextChips,
    required this.actions,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String statusLabel;
  final bool statusLive;
  final List<_HeroChip> contextChips;
  final List<_HeroAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFC812), Color(0xFFFABD00), Color(0xFFD97706)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative grid
          Positioned.fill(
            child: CustomPaint(painter: _HeroGridPainter()),
          ),
          // Soft glow orb
          Positioned(
            right: -70,
            top: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.38),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: eyebrow + status chip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1D1F).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF1A1D1F).withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.dashboard_rounded,
                              size: 13, color: const Color(0xFF1A1D1F).withValues(alpha: 0.8)),
                          const SizedBox(width: 6),
                          Text(
                            eyebrow,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: Color(0xFF1A1D1F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusLive
                            ? const Color(0xFF059669).withValues(alpha: 0.16)
                            : const Color(0xFF1A1D1F).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: statusLive
                              ? const Color(0xFF059669).withValues(alpha: 0.55)
                              : const Color(0xFF1A1D1F).withValues(alpha: 0.30),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusLive
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF1A1D1F).withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              boxShadow: statusLive
                                  ? const [
                                      BoxShadow(
                                        color: Color(0xFF059669),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: statusLive
                                  ? const Color(0xFF047857)
                                  : const Color(0xFF1A1D1F).withValues(alpha: 0.78),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ...actions,
                  ],
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.05,
                    color: Color(0xFF1A1D1F),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF1A1D1F).withValues(alpha: 0.72),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                // Context chips
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: contextChips,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1A1D1F).withValues(alpha: 0.78)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: const Color(0xFF1A1D1F).withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1D1F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.label,
    required this.primary,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return Material(
        color: const Color(0xFF1A1D1F),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A1D1F).withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: const Color(0xFFFFC812)),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: const Color(0xFF1A1D1F)),
      label: Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1D1F))),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.18),
        side: BorderSide(color: const Color(0xFF1A1D1F).withValues(alpha: 0.32)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _HeroGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 0.7;
    const spacing = 32.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. PREMIUM KPI TILE
// ═══════════════════════════════════════════════════════════════════════════

class _KpiSpec {
  const _KpiSpec({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.tint,
    required this.tintSoft,
  });
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color tint;
  final Color tintSoft;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.spec});
  final _KpiSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _CostDashboardTab._surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _CostDashboardTab._hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: spec.tint.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon tile + label
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: spec.tintSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: spec.tint.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(spec.icon, size: 17, color: spec.tint),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  spec.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: _CostDashboardTab._muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Big value
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              spec.value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: _CostDashboardTab._ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            spec.sub,
            style: TextStyle(
              fontSize: 11.5,
              color: _CostDashboardTab._mutedSoft,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3a. COST BREAKDOWN CARD (stacked horizontal bar + legend)
// ═══════════════════════════════════════════════════════════════════════════

class _CostBreakdownCard extends StatelessWidget {
  const _CostBreakdownCard({
    required this.currencySymbol,
    required this.categories,
    required this.total,
  });
  final String currencySymbol;
  final List<_CatData> categories;
  final double total;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Cost Breakdown',
      subtitle: 'Share of cost baseline by category',
      trailing: Text(
        '$currencySymbol${_CostDashboardTab._fmt(total)}',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: _CostDashboardTab._ink,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 44,
              child: Row(
                children: categories.map((c) {
                  final pct = total > 0 ? c.value / total : 0.0;
                  return Expanded(
                    flex: (pct * 1000).clamp(1, 1000).round(),
                    child: Container(
                      color: c.color,
                      child: pct > 0.06
                          ? Center(
                              child: Text(
                                '${(pct * 100).round()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Legend grid
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: categories.map((c) {
              final pct = total > 0 ? (c.value / total * 100) : 0.0;
              return SizedBox(
                width: 180,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: c.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            c.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _CostDashboardTab._inkSoft,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$currencySymbol${_CostDashboardTab._fmt(c.value)} · ${pct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: _CostDashboardTab._muted,
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3b. COMPOSITION DONUT CARD (CustomPaint donut + centered total)
// ═══════════════════════════════════════════════════════════════════════════

class _CompositionDonutCard extends StatelessWidget {
  const _CompositionDonutCard({
    required this.currencySymbol,
    required this.categories,
    required this.total,
  });
  final String currencySymbol;
  final List<_CatData> categories;
  final double total;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Cost Composition',
      subtitle: 'Donut view of category share',
      child: Column(
        children: [
          // Donut
          SizedBox(
            height: 200,
            child: CustomPaint(
              size: const Size(double.infinity, 200),
              painter: _DonutPainter(
                segments: categories
                    .map((c) => _DonutSegment(
                          value: c.value,
                          color: c.color,
                          label: c.label,
                        ))
                    .toList(),
                total: total,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'BASELINE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: _CostDashboardTab._muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$currencySymbol${_CostDashboardTab._fmt(total)}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: _CostDashboardTab._ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${categories.length} active ${categories.length == 1 ? "category" : "categories"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: _CostDashboardTab._mutedSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Compact legend
          Column(
            children: categories.map((c) {
              final pct = total > 0 ? (c.value / total * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: c.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: _CostDashboardTab._inkSoft,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: _CostDashboardTab._muted,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DonutSegment {
  final double value;
  final Color color;
  final String label;
  const _DonutSegment({
    required this.value,
    required this.color,
    required this.label,
  });
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments, required this.total});
  final List<_DonutSegment> segments;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    // Donut: outer radius vs inner radius (track)
    const trackThickness = 22.0;
    const gapDegrees = 2.0; // small gap between segments

    // Background track
    final trackPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackThickness
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - trackThickness / 2, trackPaint);

    if (total <= 0) return;

    final activeSegments = segments.where((s) => s.value > 0).toList();
    if (activeSegments.isEmpty) return;

    final totalActive =
        activeSegments.fold<double>(0, (s, seg) => s + seg.value);
    if (totalActive <= 0) return;

    // Each segment's sweep is proportional to its share of totalActive.
    // We start at -90deg (12 o'clock) and sweep clockwise.
    var startAngle = -math.pi / 2;
    final gapRad = gapDegrees * math.pi / 180;

    for (final seg in activeSegments) {
      final sweep = (seg.value / totalActive) * 2 * math.pi;
      final effectiveSweep = sweep > gapRad * 2 ? sweep - gapRad * 2 : sweep;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackThickness
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - trackThickness / 2),
        startAngle + gapRad,
        effectiveSweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.total != total ||
      oldDelegate.segments.length != segments.length;
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. CATEGORY DETAILS TABLE
// ═══════════════════════════════════════════════════════════════════════════

class _CategoryDetailsCard extends StatelessWidget {
  const _CategoryDetailsCard({
    required this.currencySymbol,
    required this.categories,
    required this.maxCat,
    required this.total,
  });
  final String currencySymbol;
  final List<_CatData> categories;
  final double maxCat;
  final double total;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Category Details',
      subtitle: 'Per-category contribution to the cost baseline',
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: const [
                Expanded(flex: 5, child: _TableHeader('CATEGORY')),
                Expanded(flex: 4, child: _TableHeader('SHARE', alignRight: true)),
                Expanded(flex: 4, child: _TableHeader('VALUE', alignRight: true)),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _CostDashboardTab._hairline),
          // Rows
          for (final c in categories)
            _CategoryRow(
              currencySymbol: currencySymbol,
              cat: c,
              pct: maxCat > 0 ? (c.value / maxCat).clamp(0.0, 1.0) : 0.0,
              sharePct: total > 0 ? (c.value / total * 100) : 0.0,
            ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.label, {this.alignRight = false});
  final String label;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: _CostDashboardTab._mutedSoft,
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.currencySymbol,
    required this.cat,
    required this.pct,
    required this.sharePct,
  });
  final String currencySymbol;
  final _CatData cat;
  final double pct;
  final double sharePct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          // Color dot + label + icon
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
                Icon(cat.icon, size: 14, color: cat.color.withValues(alpha: 0.85)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    cat.label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _CostDashboardTab._inkSoft,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Share bar + percent
          Expanded(
            flex: 4,
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
                        backgroundColor: _CostDashboardTab._hairlineSoft,
                        valueColor: AlwaysStoppedAnimation<Color>(cat.color),
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
                      color: _CostDashboardTab._muted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Value
          Expanded(
            flex: 4,
            child: Text(
              '$currencySymbol${_CostDashboardTab._fmt(cat.value)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _CostDashboardTab._ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. LINES BY CATEGORY (empty state + horizontal bars)
// ═══════════════════════════════════════════════════════════════════════════

class _LinesByCategoryCard extends StatelessWidget {
  const _LinesByCategoryCard({
    required this.currencySymbol,
    required this.entries,
    required this.maxTotal,
    required this.onOpenBuilder,
  });
  final String currencySymbol;
  final List<MapEntry<CostCategory, List<CostLine>>> entries;
  final double maxTotal;
  final VoidCallback onOpenBuilder;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _SectionCard(
        title: 'Lines by Category',
        subtitle: 'Where your itemised cost lines live',
        child: _EmptyState(
          icon: Icons.bar_chart_rounded,
          title: 'No cost lines yet',
          body:
              'Itemised cost lines will appear here, grouped by category, once you add them in the Builder tab.',
          ctaLabel: 'Open Builder',
          onCta: onOpenBuilder,
        ),
      );
    }
    return _SectionCard(
      title: 'Lines by Category',
      subtitle: '${entries.length} ${entries.length == 1 ? "category" : "categories"} · sorted by spend',
      child: Column(
        children: entries.map((entry) {
          final catTotal = entry.value.fold(0.0, (s, l) => s + l.total);
          final pct = maxTotal > 0 ? (catTotal / maxTotal).clamp(0.0, 1.0) : 0.0;
          final catColor = _categoryColor(entry.key);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: catColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: Text(
                    entry.key.label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _CostDashboardTab._inkSoft,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${entry.value.length}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _CostDashboardTab._muted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 8,
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 8,
                              backgroundColor: _CostDashboardTab._hairlineSoft,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(catColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 64,
                        child: Text(
                          '$currencySymbol${_CostDashboardTab._fmt(catTotal)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _CostDashboardTab._ink,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _categoryColor(CostCategory cat) {
    switch (cat) {
      case CostCategory.labor:
      case CostCategory.materials:
      case CostCategory.software:
      case CostCategory.procurement:
      case CostCategory.travelTraining:
      case CostCategory.construction:
        return const Color(0xFF6366F1); // Direct (indigo)
      case CostCategory.projectTeam:
      case CostCategory.overheads:
      case CostCategory.ga:
      case CostCategory.facilities:
      case CostCategory.insuranceCompliance:
        return const Color(0xFF8B5CF6); // Indirect (violet)
      case CostCategory.ssher:
      case CostCategory.quality:
        return const Color(0xFFEC4899); // SSHER & Quality (pink)
      case CostCategory.riskAllowance:
        return const Color(0xFFF59E0B); // Risk (amber)
      case CostCategory.contingency:
        return const Color(0xFF10B981); // Contingency (emerald)
      case CostCategory.mgmtReserve:
        return const Color(0xFF06B6D4); // Mgmt reserve (cyan)
      case CostCategory.escalation:
        return const Color(0xFF06B6D4); // Escalation (cyan)
      case CostCategory.taxes:
        return const Color(0xFF64748B); // Taxes (slate)
      case CostCategory.financing:
        return const Color(0xFF0EA5E9); // Financing (sky)
      case CostCategory.startup:
        return const Color(0xFF14B8A6); // Startup (teal)
      case CostCategory.warranty:
        return const Color(0xFFA855F7); // Warranty (purple)
      case CostCategory.decommissioning:
        return const Color(0xFF64748B); // Decommissioning (slate)
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
  });
  final IconData icon;
  final String title;
  final String body;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: _CostDashboardTab._surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _CostDashboardTab._hairline,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _CostDashboardTab._brandSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: _CostDashboardTab._brand.withValues(alpha: 0.32),
              ),
            ),
            child: Icon(icon, size: 28, color: _CostDashboardTab._brandDeep),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _CostDashboardTab._ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: _CostDashboardTab._muted,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: _CostDashboardTab._brand,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onCta,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: _CostDashboardTab._brand.withValues(alpha: 0.40),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: _CostDashboardTab._ink),
                    const SizedBox(width: 7),
                    Text(
                      ctaLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _CostDashboardTab._ink,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 6. TOTALS SPOTLIGHT BAR
// ═══════════════════════════════════════════════════════════════════════════

class _TotalsSpotlightBar extends StatelessWidget {
  const _TotalsSpotlightBar({
    required this.currencySymbol,
    required this.costBaseline,
    required this.mgmtReserve,
    required this.totalAuthorized,
  });
  final String currencySymbol;
  final double costBaseline;
  final double mgmtReserve;
  final double totalAuthorized;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: _CostDashboardTab._surface,
        border: Border.all(color: _CostDashboardTab._hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Cost Baseline column
            Expanded(
              child: _SpotlightColumn(
                icon: Icons.shield_outlined,
                label: 'Cost Baseline',
                value: '$currencySymbol${_CostDashboardTab._fmt(costBaseline)}',
                tint: const Color(0xFFD97706),
                tintSoft: const Color(0xFFFFF3E0),
              ),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: _CostDashboardTab._hairline,
            ),
            // Mgmt Reserve column
            Expanded(
              child: _SpotlightColumn(
                icon: Icons.savings_outlined,
                label: 'Mgmt Reserve',
                value: '$currencySymbol${_CostDashboardTab._fmt(mgmtReserve)}',
                tint: const Color(0xFF64748B),
                tintSoft: const Color(0xFFF1F5F9),
              ),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: _CostDashboardTab._hairline,
            ),
            // Total Authorized — elevated dark spotlight
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                decoration: const BoxDecoration(
                  color: Color(0xFF0B1220),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _CostDashboardTab._brand.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.account_balance_wallet_rounded,
                              size: 15, color: _CostDashboardTab._brand),
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          'TOTAL AUTHORIZED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$currencySymbol${_CostDashboardTab._fmt(totalAuthorized)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: _CostDashboardTab._brand,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightColumn extends StatelessWidget {
  const _SpotlightColumn({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    required this.tintSoft,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final Color tintSoft;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: tintSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tint.withValues(alpha: 0.20)),
                ),
                child: Icon(icon, size: 15, color: tint),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: _CostDashboardTab._muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: _CostDashboardTab._ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared section card chrome
// ═══════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _CostDashboardTab._surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _CostDashboardTab._hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _CostDashboardTab._ink,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _CostDashboardTab._muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Category data model
// ═══════════════════════════════════════════════════════════════════════════

class _CatData {
  const _CatData(this.label, this.value, this.color, this.icon);
  final String label;
  final double value;
  final Color color;
  final IconData icon;
}
