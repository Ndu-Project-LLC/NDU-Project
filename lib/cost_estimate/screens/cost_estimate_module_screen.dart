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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
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

class CostEstimateModuleScreen extends StatefulWidget {
  const CostEstimateModuleScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CostEstimateModuleScreen()),
    );
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
                  tabs: [
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
                    BOEScreen(),
                    AIAssistantScreen(),
                    StakeholdersScreen(),
                    AccountingScreen(),
                    ReviewScreen(),
                    BaselineScreen(),
                    VarianceScreen(),
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
// ═══════════════════════════════════════════════════════════════════════════

class _CostDashboardTab extends StatelessWidget {
  final CostEstimateProvider provider;
  const _CostDashboardTab({required this.provider});

  static const _textPrimary = Color(0xFF1A1D1F);
  static const _textSecondary = Color(0xFF6B7280);
  static const _border = Color(0xFFE4E7EC);
  static const _cardBg = Colors.white;

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

    // Category breakdown for chart
    final categories = <_CatData>[
      _CatData('Direct', t.direct, const Color(0xFF6366F1)),
      _CatData('Indirect', t.indirect, const Color(0xFF8B5CF6)),
      _CatData('SSHER & Quality', t.sherQuality, const Color(0xFFEC4899)),
      _CatData('Risk', t.riskAllowances, const Color(0xFFF59E0B)),
      _CatData('Contingency', t.contingency, const Color(0xFF10B981)),
      _CatData('Escalation', t.escalation, const Color(0xFF06B6D4)),
      _CatData('Taxes', t.taxes, const Color(0xFF64748B)),
    ];
    final maxCat = categories.fold<double>(0, (m, c) => c.value > m ? c.value : m);

    // Lines by category
    final byCategory = <CostCategory, List<CostLine>>{};
    for (final l in lines) {
      byCategory.putIfAbsent(l.category, () => []).add(l);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──────────────────────────────────────────────────
          const Text('Cost Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary)),
          const SizedBox(height: 4),
          Text('$lineCount cost lines · ${isBaselined ? "Baselined v${estimate.baseline?.version}" : "Draft — not baselined"}',
              style: const TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 24),

          // ── KPI Cards (4 in a row) ────────────────────────────────
          Row(
            children: [
              Expanded(child: _dashboardKpi('Cost Baseline', '$currencySymbol${_fmt(t.costBaseline)}', Icons.shield_outlined, const Color(0xFFD97706))),
              const SizedBox(width: 12),
              Expanded(child: _dashboardKpi('Total Authorized', '$currencySymbol${_fmt(t.totalAuthorizedBudget)}', Icons.account_balance_wallet_outlined, const Color(0xFF6366F1))),
              const SizedBox(width: 12),
              Expanded(child: _dashboardKpi('Cost Lines', '$lineCount', Icons.list_alt_rounded, const Color(0xFF10B981))),
              const SizedBox(width: 12),
              Expanded(child: _dashboardKpi('Avg / Line', '$currencySymbol${_fmt(avgPerLine)}', Icons.analytics_outlined, const Color(0xFF8B5CF6))),
            ],
          ),
          const SizedBox(height: 24),

          // ── Stacked Bar Chart + Legend ─────────────────────────────
          if (t.costBaseline > 0) ...[
            _sectionCard(
              title: 'Cost Breakdown',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stacked horizontal bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 36,
                      child: Row(
                        children: categories.where((c) => c.value > 0).map((c) {
                          final pct = t.costBaseline > 0 ? c.value / t.costBaseline : 0.0;
                          return Expanded(
                            flex: (pct * 1000).clamp(1, 1000).round(),
                            child: Container(
                              color: c.color,
                              child: pct > 0.06
                                  ? Center(child: Text('${(pct * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Legend + values
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: categories.where((c) => c.value > 0).map((c) {
                      final pct = t.costBaseline > 0 ? (c.value / t.costBaseline * 100) : 0.0;
                      return SizedBox(
                        width: 160,
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: c.color, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 6),
                            Expanded(child: Text(c.label, style: const TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                            Text('$currencySymbol${_fmt(c.value)}', style: const TextStyle(color: _textPrimary, fontSize: 11, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Category Breakdown with Progress Bars ──────────────────
          _sectionCard(
            title: 'Category Details',
            child: Column(
              children: categories.map((c) {
                final pct = maxCat > 0 ? (c.value / maxCat).clamp(0.0, 1.0) : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(c.label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                          Text('$currencySymbol${c.value.toStringAsFixed(c.value == c.value.roundToDouble() ? 0 : 2)}',
                              style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFF3F4F6),
                          valueColor: AlwaysStoppedAnimation<Color>(c.color),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // ── Lines by Category ──────────────────────────────────────
          _sectionCard(
            title: 'Lines by Category',
            child: byCategory.isEmpty
                ? const Text('No cost lines yet. Add lines in the Builder tab.', style: TextStyle(color: _textSecondary, fontSize: 13))
                : Column(
                    children: byCategory.entries.map((entry) {
                      final catTotal = entry.value.fold(0.0, (a, l) => a + l.total);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF6366F1))),
                                const SizedBox(width: 8),
                                Text('${entry.key.label}', style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 6),
                                Text('(${entry.value.length})', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                              ],
                            ),
                            Text('$currencySymbol${_fmt(catTotal)}', style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 20),

          // ── Bottom Summary Cards ───────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cost Baseline
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [LightModeColors.accent.withValues(alpha: 0.12), LightModeColors.accent.withValues(alpha: 0.04)]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LightModeColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(width: 28, height: 28, decoration: BoxDecoration(color: LightModeColors.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.shield, color: LightModeColors.accent, size: 16)),
                        const SizedBox(width: 8),
                        const Text('Cost Baseline', style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 10),
                      Text('$currencySymbol${_fmt(t.costBaseline)}', style: const TextStyle(color: Color(0xFFD97706), fontSize: 20, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Management Reserve
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.trending_up, color: _textSecondary, size: 18),
                        const SizedBox(width: 8),
                        const Text('Mgmt Reserve', style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 10),
                      Text('$currencySymbol${_fmt(t.managementReserve)}', style: const TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Total Authorized
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1A1D1F), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL AUTHORIZED', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      const SizedBox(height: 10),
                      Text('$currencySymbol${_fmt(t.totalAuthorizedBudget)}', style: const TextStyle(color: LightModeColors.accent, fontSize: 20, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
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

  Widget _dashboardKpi(String label, String value, IconData icon, Color color) {
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
            Flexible(child: Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()])),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  String _fmt(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
  }
}

class _CatData {
  final String label;
  final double value;
  final Color color;
  const _CatData(this.label, this.value, this.color);
}
