/// Project Controls Dashboard Screen
///
/// Embeds into the existing phase screen sidebar pattern.
/// Uses ResponsiveScaffold matching the existing UI.
///
/// Shows: executive KPIs, health indicators, EVM metrics (CPI/SPI),
/// work package summary, open change requests, variance alerts.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/project_controls/models/project_controls_models.dart';
import 'package:ndu_project/project_controls/providers/project_controls_provider.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/services/user_preferences_service.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/section_navigator.dart';
import 'package:ndu_project/widgets/project_controls_tab_scaffold.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/project_intelligence_service.dart';
import 'package:ndu_project/widgets/shimmer_loading.dart';
import 'package:ndu_project/widgets/cross_section_sync_card.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart' as sched;
import 'package:go_router/go_router.dart';

class ProjectControlsScreen extends StatefulWidget {
  const ProjectControlsScreen({super.key});

  static void open(BuildContext context) {
    context.push('/project-controls');
  }

  @override
  State<ProjectControlsScreen> createState() => _ProjectControlsScreenState();
}

class _ProjectControlsScreenState extends State<ProjectControlsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 10, vsync: this);
    // Sync from Cost Estimate module if available (no demo data fallback)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProjectControlsProvider>();
      final ceProvider = context.read<CostEstimateProvider>();
      if (ceProvider.estimate != null && ceProvider.setupComplete) {
        if (provider.state.workPackages.isEmpty) {
          provider.syncFromCostEstimate(ceProvider.estimate);
        } else {
          // Work packages exist — sync BAC from Cost Estimate if it changed
          provider.syncFromCostEstimate(ceProvider.estimate);
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ProjectControlsProvider, CostEstimateProvider, ProjectDataProvider>(
      builder: (context, provider, ceProvider, pdProvider, _) {
        final state = provider.state;

        // ── AI Context: derive insights from project data ──────────────
        final projectData = pdProvider.projectData;
        final aiContext = projectData.projectId != null
            ? ProjectIntelligenceService.buildContextScan(projectData,
                sectionLabel: 'Project Controls')
            : '';

        // ── Auto-populate: extract milestones from project activities ──
        final aiMilestones = <String>[];
        if (projectData.keyMilestones.isNotEmpty) {
          for (final m in projectData.keyMilestones.take(5)) {
            aiMilestones.add(m.name);
          }
        } else if (projectData.projectActivities.isNotEmpty) {
          for (final a in projectData.projectActivities.take(5)) {
            aiMilestones.add(a.title);
          }
        }

        // ── Auto-populate: extract cost forecasts from project context ──
        String aiCostForecast = '';
        if (projectData.costAnalysisData != null) {
          final ca = projectData.costAnalysisData!;
          double total = 0;
          for (final solution in ca.solutionCosts) {
            for (final row in solution.costRows) {
              final num = double.tryParse(row.cost.replaceAll(',', '')) ?? 0;
              total += num;
            }
          }
          if (total > 0) {
            aiCostForecast = 'Estimated solution cost: \$${total.toStringAsFixed(0)}';
          }
        }

        // ── Auto-populate: change recommendations from risks/constraints ──
        final changeRecommendations = <String>[];
        if (projectData.charterConstraints.isNotEmpty) {
          final lines = projectData.charterConstraints.split('\n');
          for (final line in lines.take(3)) {
            if (line.trim().isNotEmpty) {
              changeRecommendations.add(line.trim());
            }
          }
        }
        if (projectData.charterAssumptions.isNotEmpty) {
          final lines = projectData.charterAssumptions.split('\n');
          for (final line in lines.take(3)) {
            if (line.trim().isNotEmpty) {
              changeRecommendations.add(line.trim());
            }
          }
        }

        // ── Loading state while Firestore data loads ───────────────
        if (!provider.isLoaded) {
          return const ResponsiveScaffold(
            activeItemLabel: 'Project Controls',
            appBarTitle: 'Project Controls',
            breadcrumbPhase: 'Execution Phase',
            breadcrumbTitle: 'Project Controls',
            body: PageShimmerSkeleton(),
          );
        }

        return ResponsiveScaffold(
          activeItemLabel: 'Project Controls',
          appBarTitle: 'Project Controls',
          breadcrumbPhase: 'Execution Phase',
          breadcrumbTitle: 'Project Controls',
          body: Column(
            children: [
              // ── World-class Section Navigator ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SectionNavigator(
                  title: 'Project Controls Navigation',
                  subtitle: 'Navigate between project control sections',
                  icon: Icons.dashboard_outlined,
                  tabs: const [
                    SectionTab(icon: Icons.dashboard_outlined, label: 'Dashboard'),
                    SectionTab(icon: Icons.account_tree_outlined, label: 'Scope Tracking'),
                    SectionTab(icon: Icons.attach_money, label: 'Cost Control'),
                    SectionTab(icon: Icons.sync_alt, label: 'Change Management'),
                    SectionTab(icon: Icons.trending_up, label: 'Forecasting'),
                    SectionTab(icon: Icons.history, label: 'Baseline Management'),
                    SectionTab(icon: Icons.schedule, label: 'Schedule'),
                    SectionTab(icon: Icons.warning_amber_outlined, label: 'Risk & Issues'),
                    SectionTab(icon: Icons.people_outline, label: 'Resource'),
                    SectionTab(icon: Icons.assessment_outlined, label: 'Reporting'),
                  ],
                  controller: _tabController,
                  onChanged: (index) => setState(() {}),
                ),
              ),
              // ── Cross-section sync card (WBS ↔ Schedule ↔ PC) ──────────
              const CrossSectionSyncCard(
                currentSection: CrossSection.projectControls,
              ),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _DashboardTab(state: state, aiContext: aiContext, aiMilestones: aiMilestones, aiCostForecast: aiCostForecast, changeRecommendations: changeRecommendations),
                    _ScopeTrackingTab(state: state, aiMilestones: aiMilestones, aiContext: aiContext, provider: provider),
                    _CostControlTab(state: state, aiCostForecast: aiCostForecast, aiContext: aiContext, projectData: projectData),
                    _ChangeMgmtTab(state: state, provider: provider, changeRecommendations: changeRecommendations, aiContext: aiContext),
                    _ForecastingTab(state: state),
                    _BaselineMgmtTab(state: state, provider: provider),
                    _ScheduleControlTab(state: state, provider: provider),
                    _RiskIssuesTab(state: state, provider: provider),
                    _ResourceControlTab(state: state),
                    _ReportingAuditTab(state: state, provider: provider),
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

// ═════════════════════════════════════════════════════════════════════════
// TAB: Dashboard
// ═════════════════════════════════════════════════════════════════════════

class _DashboardTab extends StatelessWidget {
  final ProjectControlsState state;
  final String aiContext;
  final List<String> aiMilestones;
  final String aiCostForecast;
  final List<String> changeRecommendations;
  const _DashboardTab({
    required this.state,
    required this.aiContext,
    required this.aiMilestones,
    required this.aiCostForecast,
    required this.changeRecommendations,
  });

  @override
  Widget build(BuildContext context) {
    final currencySymbol = UserPreferencesService.currencySymbolSync;
    final cpiColor = _cpiColor(state.portfolioCPI);
    final spiColor = _spiColor(state.portfolioSPI);

    return PcTabShell(
      eyebrow: 'Project Controls Dashboard',
      title: 'Dashboard',
      subtitle:
          'Executive overview — health score, EVM metrics, open change requests, and scope growth detection.',
      icon: Icons.dashboard_rounded,
      accent: PcPalette.indigo,
      accentDeep: const Color(0xFF4F46E5),
      accentSoft: const Color(0xFFE0E7FF),
      tint: const Color(0xFFEEF2FF),
      borderColor: const Color(0xFFC7D2FE),
      kpis: [
        PcKpiSpec(
          label: 'Total Budget',
          value:
              '$currencySymbol${(state.totalOriginalBudget / 1000000).toStringAsFixed(1)}M',
          sub: 'Budget at Completion',
          icon: Icons.account_balance_wallet_rounded,
          accent: PcPalette.indigo,
        ),
        PcKpiSpec(
          label: 'Actual Cost',
          value:
              '$currencySymbol${(state.totalActualCost / 1000000).toStringAsFixed(1)}M',
          sub:
              '${((state.totalActualCost / state.totalOriginalBudget) * 100).toStringAsFixed(1)}% of budget',
          icon: Icons.payments_rounded,
          accent: PcPalette.amber,
        ),
        PcKpiSpec(
          label: 'CPI',
          value: state.portfolioCPI.toStringAsFixed(2),
          sub: state.portfolioCPI >= 1.0
              ? 'Under budget — healthy'
              : state.portfolioCPI >= 0.9
                  ? 'Marginal — watch'
                  : 'Over budget — at risk',
          icon: Icons.trending_up_rounded,
          accent: cpiColor,
        ),
        PcKpiSpec(
          label: 'SPI',
          value: state.portfolioSPI.toStringAsFixed(2),
          sub: state.portfolioSPI >= 1.0
              ? 'Ahead of schedule'
              : state.portfolioSPI >= 0.9
                  ? 'On track'
                  : 'Behind schedule',
          icon: Icons.schedule_rounded,
          accent: spiColor,
        ),
      ],
      sections: [
        if (aiContext.isNotEmpty) _aiInsightsCard(),
        LayoutBuilder(
          builder: (context, c) {
            final stacked = c.maxWidth < 900;
            if (stacked) {
              return Column(
                children: [
                  _healthCard(),
                  const SizedBox(height: 14),
                  _evmSummaryCard(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _healthCard()),
                const SizedBox(width: 14),
                Expanded(flex: 3, child: _evmSummaryCard()),
              ],
            );
          },
        ),
        LayoutBuilder(
          builder: (context, c) {
            final stacked = c.maxWidth < 900;
            if (stacked) {
              return Column(
                children: [
                  _openChangesCard(),
                  const SizedBox(height: 14),
                  _scopeGrowthCard(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _openChangesCard()),
                const SizedBox(width: 14),
                Expanded(child: _scopeGrowthCard()),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── AI-Powered Context Insights Card ─────────────────────────────────-
  Widget _aiInsightsCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFEEF2FF),
            const Color(0xFFF5F3FF),
          ],
        ),
        border: Border.all(
          color: PcPalette.indigo.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: PcPalette.indigo.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 24,
            right: 24,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    PcPalette.indigo.withValues(alpha: 0),
                    PcPalette.indigo,
                    PcPalette.violet,
                    PcPalette.indigo.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [PcPalette.indigo, PcPalette.violet],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PcPalette.indigo.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'AI-Powered Context Insights',
                            style: TextStyle(
                              color: PcPalette.inkPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.1,
                              fontFamily: appFontFamily,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Auto-populated from project data across all phases',
                            style: TextStyle(
                              color: PcPalette.inkSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: appFontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: PcPalette.indigo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: PcPalette.indigo
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'AI CONTEXT',
                        style: TextStyle(
                          color: PcPalette.indigo,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          fontFamily: appFontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (aiMilestones.isNotEmpty) ...[
                  _aiSectionLabel('SCOPE MILESTONES (from project data)'),
                  const SizedBox(height: 8),
                  ...aiMilestones.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: PcPalette.indigo
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Icon(Icons.flag_outlined,
                                  size: 11, color: PcPalette.indigo),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                m,
                                style: TextStyle(
                                  color: PcPalette.inkPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                  fontFamily: appFontFamily,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 14),
                ],
                if (aiCostForecast.isNotEmpty) ...[
                  _aiSectionLabel('COST INSIGHT (from cost analysis)'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: PcPalette.amber
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.attach_money_rounded,
                            size: 18, color: PcPalette.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            aiCostForecast,
                            style: TextStyle(
                              color: PcPalette.inkPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFamily: appFontFamily,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (changeRecommendations.isNotEmpty) ...[
                  _aiSectionLabel(
                      'CHANGE RECOMMENDATIONS (from constraints/assumptions)'),
                  const SizedBox(height: 6),
                  ...changeRecommendations.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: PcPalette.amber
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Icon(Icons.lightbulb_outline_rounded,
                                  size: 11, color: PcPalette.amber),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                r,
                                style: TextStyle(
                                  color: PcPalette.inkPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                  fontFamily: appFontFamily,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
                // Raw context scan fallback
                if (aiContext.isNotEmpty &&
                    aiMilestones.isEmpty &&
                    aiCostForecast.isEmpty &&
                    changeRecommendations.isEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: PcPalette.borderSubtle),
                    ),
                    child: Text(
                      aiContext.length > 400
                          ? '${aiContext.substring(0, 400)}...'
                          : aiContext,
                      style: TextStyle(
                        color: PcPalette.inkSecondary,
                        fontSize: 11.5,
                        height: 1.5,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: PcPalette.inkMuted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        fontFamily: appFontFamily,
      ),
    );
  }

  Color _cpiColor(double cpi) {
    if (cpi >= 1.0) return PcPalette.emerald;
    if (cpi >= 0.9) return PcPalette.amber;
    return PcPalette.danger;
  }

  Color _spiColor(double spi) {
    if (spi >= 1.0) return PcPalette.emerald;
    if (spi >= 0.9) return PcPalette.amber;
    return PcPalette.danger;
  }

  Widget _healthCard() {
    final score = state.healthScore;
    final color = score >= 80
        ? PcPalette.emerald
        : score >= 60
            ? PcPalette.amber
            : PcPalette.danger;
    return PcSectionCard(
      title: 'Overall Health',
      subtitle: 'Composite score based on cost, schedule, scope, and risk metrics.',
      icon: Icons.favorite_rounded,
      accent: color,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: CustomPaint(
              painter: _HealthGaugePainter(score: score, color: color),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        color: color,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        fontFamily: appFontFamily,
                      ),
                    ),
                    Text(
                      '/100',
                      style: TextStyle(
                        color: PcPalette.inkMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: color.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    score >= 80
                        ? 'HEALTHY'
                        : score >= 60
                            ? 'AT RISK'
                            : 'CRITICAL',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      fontFamily: appFontFamily,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${state.workPackages.length} work packages tracked',
                  style: TextStyle(
                    color: PcPalette.inkSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: appFontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.openChangeRequests} open change requests',
                  style: TextStyle(
                    color: PcPalette.inkSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: appFontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _evmSummaryCard() {
    return PcSectionCard(
      title: 'Earned Value Summary',
      subtitle: 'Full EVM metric breakdown — BAC, EV, AC, PV, EAC, VAC, CV, SV.',
      icon: Icons.analytics_rounded,
      accent: PcPalette.indigo,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        children: [
          _evmRow(
              'BAC (Budget at Completion)',
              '\$${(state.totalOriginalBudget / 1000000).toStringAsFixed(2)}M',
              PcPalette.inkPrimary,
              bold: true),
          _evmRow('EV (Earned Value)',
              '\$${(state.totalEarnedValue / 1000000).toStringAsFixed(2)}M',
              PcPalette.indigo),
          _evmRow('AC (Actual Cost)',
              '\$${(state.totalActualCost / 1000000).toStringAsFixed(2)}M',
              PcPalette.amber),
          _evmRow('PV (Planned Value)',
              '\$${(state.totalPlannedValue / 1000000).toStringAsFixed(2)}M',
              PcPalette.violet),
          _divider(),
          _evmRow('EAC (Estimate at Completion)',
              '\$${(state.portfolioEAC / 1000000).toStringAsFixed(2)}M',
              _cpiColor(state.portfolioCPI),
              bold: true),
          _evmRow('VAC (Variance at Completion)',
              '\$${(state.portfolioVAC / 1000000).toStringAsFixed(2)}M',
              state.portfolioVAC >= 0 ? PcPalette.emerald : PcPalette.danger,
              bold: true),
          _evmRow('CV (Cost Variance)',
              '\$${((state.totalEarnedValue - state.totalActualCost) / 1000000).toStringAsFixed(2)}M',
              state.totalEarnedValue >= state.totalActualCost
                  ? PcPalette.emerald
                  : PcPalette.danger),
          _evmRow('SV (Schedule Variance)',
              '\$${((state.totalEarnedValue - state.totalPlannedValue) / 1000000).toStringAsFixed(2)}M',
              state.totalEarnedValue >= state.totalPlannedValue
                  ? PcPalette.emerald
                  : PcPalette.danger),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: PcPalette.borderSubtle,
      ),
    );
  }

  Widget _evmRow(String label, String value, Color color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: PcPalette.inkSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              fontFamily: appFontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _openChangesCard() {
    return PcSectionCard(
      title: 'Change Requests',
      subtitle: 'Most recent open change requests across all categories.',
      icon: Icons.sync_alt_rounded,
      accent: PcPalette.amber,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: PcPalette.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: PcPalette.amber.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          '${state.openChangeRequests} OPEN',
          style: TextStyle(
            color: PcPalette.amber,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            fontFamily: appFontFamily,
          ),
        ),
      ),
      child: state.changeRequests.isEmpty
          ? const PcEmptyState(
              icon: Icons.check_circle_rounded,
              title: 'No open change requests',
              subtitle: 'All changes have been resolved.',
              accent: PcPalette.emerald,
            )
          : Column(
              children: state.changeRequests.take(3).map((cr) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: cr.status.color.withValues(alpha: 0.12),
                          border: Border.all(
                            color: cr.status.color
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(cr.category.icon,
                            size: 16, color: cr.status.color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cr.description,
                              style: TextStyle(
                                color: PcPalette.inkPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                fontFamily: appFontFamily,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${cr.category.label} • ${cr.status.label}',
                              style: TextStyle(
                                color: cr.status.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: appFontFamily,
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

  Widget _scopeGrowthCard() {
    // Check for unauthorized scope growth
    final growthIssues = <String>[];
    for (final wp in state.workPackages) {
      if (wp.status == 'Added') {
        final hasApproval = state.changeRequests.any((cr) =>
            cr.status == ChangeStatus.approved &&
            cr.description.toLowerCase().contains(wp.name.toLowerCase()));
        if (!hasApproval) {
          growthIssues.add(
              '${wp.wbsCode} ${wp.name} — added without approved change request');
        }
      }
    }

    final isHealthy = growthIssues.isEmpty;
    final accent = isHealthy ? PcPalette.emerald : PcPalette.danger;

    return PcSectionCard(
      title: 'Scope Growth Detection',
      subtitle:
          'Auto-detects work packages marked as "Added" without an approved change request.',
      icon: isHealthy
          ? Icons.verified_rounded
          : Icons.warning_amber_rounded,
      accent: accent,
      child: isHealthy
          ? Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: PcPalette.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: PcPalette.emerald
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(Icons.check_circle_rounded,
                      size: 18, color: PcPalette.emerald),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No unauthorized scope growth detected',
                    style: TextStyle(
                      color: PcPalette.emerald,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: appFontFamily,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: growthIssues
                  .map((issue) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: PcPalette.danger
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: PcPalette.danger
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Icon(Icons.warning_amber_rounded,
                                  size: 16, color: PcPalette.danger),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                issue,
                                style: TextStyle(
                                  color: PcPalette.inkPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                  fontFamily: appFontFamily,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════
// TAB: Scope Tracking
// ═════════════════════════════════════════════════════════════════════════

class _ScopeTrackingTab extends StatelessWidget {
  final ProjectControlsState state;
  final List<String> aiMilestones;
  final String aiContext;
  final ProjectControlsProvider provider;
  const _ScopeTrackingTab({
    required this.state,
    required this.aiMilestones,
    required this.aiContext,
    required this.provider,
  });

  /// Per Task 19: Pull schedule activities from ScheduleProvider and feed
  /// them into Scope Tracking via [ProjectControlsProvider.syncFromScheduleActivities].
  void _syncFromSchedule(BuildContext context) {
    final scheduleProvider = context.read<ScheduleProvider>();
    final schedule = scheduleProvider.schedule;
    if (schedule == null || schedule.activities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No schedule activities found. Build a schedule first, then sync.'),
        ),
      );
      return;
    }
    // Flatten the activity tree (activities can have nested children).
    final flattened = <sched.ScheduleActivity>[];
    void walk(sched.ScheduleActivity a) {
      flattened.add(a);
      for (final c in a.children) {
        walk(c);
      }
    }
    for (final a in schedule.activities) {
      walk(a);
    }
    final shims = flattened
        .map((a) => ScheduleActivityShim(
              id: a.id,
              name: a.name,
              description: a.description,
              wbsCode: a.wbsCode,
              plannedStart: a.startDate,
              plannedFinish: a.endDate,
              actualStart: null,
              actualFinish: null,
              percentComplete: a.progress,
              isCriticalPath: a.isCriticalPath,
            ))
        .toList();
    provider.syncFromScheduleActivities(shims);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Synced ${shims.length} schedule activities into Scope Tracking.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wps = state.workPackages;
    final isAgile = state.deliveryModel == DeliveryModel.agile;
    final completeCount = wps.where((w) => (w.percentComplete ?? 0) >= 100).length;
    final inProgressCount = wps.where((w) {
      final p = w.percentComplete ?? 0;
      return p > 0 && p < 100;
    }).length;
    final notStartedCount = wps.where((w) => (w.percentComplete ?? 0) == 0).length;

    return PcTabShell(
      eyebrow: 'Scope Tracking',
      title: 'Scope Tracking',
      subtitle:
          'Work package scope tracking with progress, CPI/SPI, EVM, and AI-derived milestones. '
          'Delivery model: ${state.deliveryModel.label}.',
      icon: Icons.account_tree_rounded,
      accent: PcPalette.indigo,
      accentDeep: const Color(0xFF4F46E5),
      accentSoft: const Color(0xFFE0E7FF),
      tint: const Color(0xFFEEF2FF),
      borderColor: const Color(0xFFC7D2FE),
      // Per Task 19: 'Sync from Schedule' CTA on the hero band feeds
      // Schedule activities into Scope Tracking.
      action: PcHeroAction(
        label: 'Sync from Schedule',
        icon: Icons.sync,
        onTap: () => _syncFromSchedule(context),
      ),
      kpis: [
        PcKpiSpec(
          label: isAgile ? 'Epics' : 'Work Packages',
          value: '${wps.length}',
          sub: isAgile ? 'Agile epics tracked' : 'Work packages tracked',
          icon: Icons.account_tree_rounded,
          accent: PcPalette.indigo,
        ),
        PcKpiSpec(
          label: 'Completed',
          value: '$completeCount',
          sub: completeCount == 0
              ? 'None completed'
              : 'At 100% complete',
          icon: Icons.task_alt_rounded,
          accent: PcPalette.emerald,
        ),
        PcKpiSpec(
          label: 'In Progress',
          value: '$inProgressCount',
          sub: 'Active work',
          icon: Icons.play_circle_outline_rounded,
          accent: PcPalette.amber,
        ),
        PcKpiSpec(
          label: 'Not Started',
          value: '$notStartedCount',
          sub: notStartedCount == 0 ? 'All started' : 'Awaiting kickoff',
          icon: Icons.schedule_rounded,
          accent: PcPalette.inkMuted,
        ),
      ],
      sections: [
        if (aiMilestones.isNotEmpty) _buildAiMilestonesCard(context, aiMilestones),
        PcSectionCard(
          title: isAgile ? 'Epic Scope Tracking' : 'Work Package Scope Tracking',
          subtitle:
              'Per-package progress, original/actual budgets, CPI/SPI, EVM metrics, and float days.',
          icon: Icons.view_list_rounded,
          accent: PcPalette.indigo,
          trailing: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: PcPalette.indigo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${wps.length} package${wps.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: PcPalette.indigo,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          child: wps.isEmpty
              ? const PcEmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'No work packages yet',
                  subtitle:
                      'Work packages from your cost estimate will appear here once the project is set up.',
                  accent: PcPalette.indigo,
                )
              : Column(
                  children: wps
                      .map((wp) => _workPackageCard(wp))
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }

  Widget _buildAiMilestonesCard(
      BuildContext context, List<String> milestones) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFECFDF5),
            const Color(0xFFD1FAE5),
          ],
        ),
        border: Border.all(
          color: PcPalette.emerald.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: PcPalette.emerald.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 24,
            right: 24,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    PcPalette.emerald.withValues(alpha: 0),
                    PcPalette.emerald,
                    const Color(0xFF059669),
                    PcPalette.emerald.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            PcPalette.emerald.withValues(alpha: 0.95),
                            const Color(0xFF059669),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PcPalette.emerald.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.flag_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'AI-Derived Scope Milestones',
                            style: TextStyle(
                              color: PcPalette.inkPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.1,
                              fontFamily: appFontFamily,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Auto-populated from your project context — review and add to the work package table.',
                            style: TextStyle(
                              color: PcPalette.inkSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: appFontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color:
                              PcPalette.emerald.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${milestones.length} proposed',
                        style: TextStyle(
                          color: PcPalette.emerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: appFontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  children: milestones.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: PcPalette.emerald
                                .withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color:
                                    PcPalette.emerald.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: PcPalette.emerald
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${entry.key + 1}',
                                  style: TextStyle(
                                    color: PcPalette.emerald,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: appFontFamily,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: PcPalette.inkPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                  fontFamily: appFontFamily,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: PcHoverBuilder(
                    builder: (hovered) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Milestones sent to Work Package table'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: PcPalette.emerald,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_circle_outline,
                              size: 16),
                          label: const Text('Add All to Work Package Table'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PcPalette.emerald,
                            backgroundColor: hovered
                                ? PcPalette.emerald.withValues(alpha: 0.05)
                                : Colors.transparent,
                            side: BorderSide(
                              color: PcPalette.emerald
                                  .withValues(alpha: hovered ? 0.6 : 0.4),
                              width: 1.4,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _workPackageCard(WorkPackageControl wp) {
    final isCritical = wp.isCriticalPath;
    final accent = isCritical ? PcPalette.danger : PcPalette.indigo;
    return PcHoverBuilder(
      builder: (hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: PcPalette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hovered
                  ? accent.withValues(alpha: 0.5)
                  : accent.withValues(alpha: 0.25),
            ),
            boxShadow: [
              if (hovered)
                BoxShadow(
                  color: accent.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: PcPalette.surfaceSubtle,
                    border: Border(
                      bottom: BorderSide(
                        color: PcPalette.borderSubtle,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 28,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wp.name,
                              style: TextStyle(
                                color: PcPalette.inkPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                fontFamily: appFontFamily,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${wp.wbsCode} • ${wp.discipline ?? "N/A"} • ${wp.status}',
                              style: TextStyle(
                                color: PcPalette.inkSecondary,
                                fontSize: 11.5,
                                fontFamily: appFontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCritical)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: PcPalette.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: PcPalette.danger
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            'CRITICAL PATH',
                            style: TextStyle(
                              color: PcPalette.danger,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              fontFamily: appFontFamily,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress
                      Row(
                        children: [
                          Text(
                            'PROGRESS',
                            style: TextStyle(
                              color: PcPalette.inkMuted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              fontFamily: appFontFamily,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(wp.percentComplete ?? 0).round()}%',
                            style: TextStyle(
                              color: PcPalette.inkPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              fontFamily: appFontFamily,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ((wp.percentComplete ?? 0) / 100)
                              .clamp(0.0, 1.0),
                          backgroundColor: PcPalette.surfaceSubtle,
                          valueColor: AlwaysStoppedAnimation(accent),
                          minHeight: 7,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Cost + Schedule row
                      LayoutBuilder(
                        builder: (context, c) {
                          final cols = c.maxWidth > 720 ? 4 : 2;
                          const spacing = 8.0;
                          final w =
                              (c.maxWidth - spacing * (cols - 1)) / cols;
                          final cells = <Widget>[
                            _infoChip('Original Budget',
                                '\$${(wp.originalBudget / 1000000).toStringAsFixed(2)}M',
                                width: w),
                            _infoChip('Actual Cost',
                                '\$${(wp.actualCost / 1000000).toStringAsFixed(2)}M',
                                width: w),
                            _infoChip('CPI', wp.cpi.toStringAsFixed(2),
                                width: w),
                            _infoChip('SPI', wp.spi.toStringAsFixed(2),
                                width: w),
                            _infoChip('EV',
                                '\$${(wp.earnedValue / 1000000).toStringAsFixed(2)}M',
                                width: w),
                            _infoChip('EAC',
                                '\$${(wp.eac / 1000000).toStringAsFixed(2)}M',
                                width: w),
                            _infoChip('VAC',
                                '\$${(wp.vac / 1000).toStringAsFixed(0)}K',
                                width: w),
                            _infoChip(
                                'Float', '${wp.floatDays?.round() ?? 0}d',
                                width: w),
                          ];
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: cells,
                          );
                        },
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

  Widget _infoChip(String label, String value, {required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: PcPalette.surfaceSubtle,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: PcPalette.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: PcPalette.inkMuted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              fontFamily: appFontFamily,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: PcPalette.inkPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: appFontFamily,
            ),
          ),
        ],
      ),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════
// TAB: Cost Control
// ═════════════════════════════════════════════════════════════════════════

/// NEW _CostControlTab implementation for project_controls_screen.dart
/// Replaces lines 718-1111 (old _CostControlTab class)

class _CostControlTab extends StatelessWidget {
  final ProjectControlsState state;
  final String aiCostForecast;
  final String aiContext;
  final ProjectDataModel projectData;
  const _CostControlTab({
    required this.state,
    required this.aiCostForecast,
    required this.aiContext,
    required this.projectData,
  });

  @override
  Widget build(BuildContext context) {
    final spent = state.totalActualCost;
    final total = state.totalOriginalBudget;
    final remaining = state.totalCurrentBudget - spent;
    final remainingPct = total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0;
    final spentPct = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;
    final overallCpi = state.workPackages.isEmpty
        ? 1.0
        : (state.workPackages.fold<double>(0.0, (s, w) => s + w.cpi) /
            state.workPackages.length);

    // Aggregate allowance stats for KPI strip
    final allowanceItems = projectData.frontEndPlanning.allowanceItems;
    final totalAllowance =
        allowanceItems.fold<double>(0.0, (s, i) => s + i.amount);

    return PcTabShell(
      eyebrow: 'Cost Control & EVM',
      title: 'Cost Control',
      subtitle:
          'Real-time budget burn, CPI/SPI health, and variance analytics across work packages.',
      icon: Icons.attach_money_rounded,
      accent: const Color(0xFF10B981),
      accentDeep: const Color(0xFF059669),
      accentSoft: const Color(0xFFD1FAE5),
      tint: const Color(0xFFECFDF5),
      borderColor: const Color(0xFFA7F3D0),
      kpis: [
        PcKpiSpec(
          label: 'Total Budget',
          value:
              '\$${(total / 1000000).toStringAsFixed(2)}M',
          sub: 'Budget at Completion (BAC)',
          icon: Icons.account_balance_wallet_rounded,
          accent: PcPalette.indigo,
        ),
        PcKpiSpec(
          label: 'Spent',
          value: '\$${(spent / 1000000).toStringAsFixed(2)}M',
          sub: '${(spentPct * 100).toStringAsFixed(1)}% of total budget',
          icon: Icons.local_fire_department_rounded,
          accent: PcPalette.amber,
          trend: PcKpiTrend(
            delta: '${(spentPct * 100).toStringAsFixed(0)}%',
            positive: spentPct < 0.95,
          ),
        ),
        PcKpiSpec(
          label: 'Remaining',
          value: '\$${(remaining / 1000000).toStringAsFixed(2)}M',
          sub: '${(remainingPct * 100).toStringAsFixed(1)}% of total budget',
          icon: Icons.savings_rounded,
          accent: PcPalette.emerald,
        ),
        PcKpiSpec(
          label: 'Overall CPI',
          value: overallCpi.toStringAsFixed(2),
          sub: overallCpi >= 1.0
              ? 'Under budget — healthy'
              : 'Over budget — at risk',
          icon: Icons.speed_rounded,
          accent: overallCpi >= 1.0 ? PcPalette.emerald : PcPalette.danger,
        ),
      ],
      sections: [
        // ── AI Cost Insight Card ─────────────────────────────────────
        if (aiCostForecast.isNotEmpty) _buildAiInsightCard(aiCostForecast),

        // ── Work Package Cost Cards ───────────────────────────────────
        PcSectionCard(
          title: 'Work Package Cost Breakdown',
          subtitle:
              'Per-package EVM metrics — budget burn, CPI, EAC, and VAC for each tracked work package.',
          icon: Icons.account_tree_rounded,
          accent: PcPalette.indigo,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: PcPalette.indigo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${state.workPackages.length} package${state.workPackages.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: PcPalette.indigo,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          child: state.workPackages.isEmpty
              ? const PcEmptyState(
                  icon: Icons.folder_open_rounded,
                  title: 'No work packages yet',
                  subtitle:
                      'Work packages from your cost estimate will appear here once the project is set up.',
                  accent: PcPalette.indigo,
                )
              : Column(
                  children: state.workPackages
                      .map((wp) => _costCard(wp))
                      .toList(growable: false),
                ),
        ),

        // ── Allowance & Contingency Tracking ─────────────────────────
        _buildAllowanceTrackingSection(projectData, totalAllowance),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // AI INSIGHT CARD — premium treatment for the auto-populated forecast.
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildAiInsightCard(String forecast) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
        ),
        border: Border.all(
          color: const Color(0xFFFDE68A).withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: PcPalette.amber.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 24,
            right: 24,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    PcPalette.amber.withValues(alpha: 0),
                    PcPalette.amber,
                    const Color(0xFFD97706),
                    PcPalette.amber.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            PcPalette.amber.withValues(alpha: 0.95),
                            const Color(0xFFD97706),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PcPalette.amber.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'AI Cost Insight',
                            style: TextStyle(
                              color: PcPalette.inkPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.1,
                              fontFamily: appFontFamily,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Auto-populated from your project cost analysis',
                            style: TextStyle(
                              color: PcPalette.inkSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: appFontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Text(
                        'FROM COST ANALYSIS',
                        style: TextStyle(
                          color: const Color(0xFFD97706),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          fontFamily: appFontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: const Color(0xFFFDE68A).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_money_rounded,
                          size: 22, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          forecast,
                          style: TextStyle(
                            color: PcPalette.inkPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            fontFamily: appFontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Compare this estimated solution cost against the EVM metrics above to validate your forecast vs. actuals.',
                  style: TextStyle(
                    color: PcPalette.inkSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    fontFamily: appFontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // ALLOWANCE & CONTINGENCY TRACKING — section card with summary tiles.
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildAllowanceTrackingSection(
      ProjectDataModel projectData, double totalAllowance) {
    final items = projectData.frontEndPlanning.allowanceItems;
    final formatter = NumberFormat.simpleCurrency(decimalDigits: 0);
    final totalReserved = items.fold<double>(0.0, (s, i) => s + i.amount);
    final totalReleased =
        items.fold<double>(0.0, (s, i) => s + i.releasedAmount);
    final totalActual = items.fold<double>(0.0, (s, i) => s + i.actualAmount);
    final totalScheduleWeeks = items.fold<double>(
        0.0, (s, i) => s + i.scheduleImpactWeeks);
    final reservedCount =
        items.where((i) => i.releaseStatus == 'Reserved').length;
    final releasedCount = items
        .where((i) =>
            i.releaseStatus == 'Released' ||
            i.releaseStatus == 'Partially Released')
        .length;
    final consumedCount =
        items.where((i) => i.releaseStatus == 'Consumed').length;
    final closedCount =
        items.where((i) => i.releaseStatus == 'Closed').length;

    return PcSectionCard(
      title: 'Allowance & Contingency Tracking',
      subtitle:
          'Live tracking of allowance and contingency items as the project progresses. Updated when items are delayed, moved, added, cancelled, or consumed.',
      icon: Icons.savings_outlined,
      accent: PcPalette.amber,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: PcPalette.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${items.length} item${items.length == 1 ? '' : 's'}',
          style: TextStyle(
            color: PcPalette.amber,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: appFontFamily,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary tiles grid
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 1100
                  ? 4
                  : c.maxWidth > 720
                      ? 2
                      : 1;
              const spacing = 12.0;
              final tileW =
                  (c.maxWidth - spacing * (cols - 1)) / cols;
              final tiles = <Widget>[
                _allowanceSummaryTile(
                  label: 'Total Reserved',
                  value: formatter.format(totalReserved),
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFF2563EB),
                  tileWidth: tileW,
                ),
                _allowanceSummaryTile(
                  label: 'Released',
                  value: formatter.format(totalReleased),
                  icon: Icons.unarchive_outlined,
                  color: PcPalette.amber,
                  tileWidth: tileW,
                ),
                _allowanceSummaryTile(
                  label: 'Actual Consumed',
                  value: formatter.format(totalActual),
                  icon: Icons.trending_down_rounded,
                  color: PcPalette.danger,
                  tileWidth: tileW,
                ),
                _allowanceSummaryTile(
                  label: 'Schedule Allowance',
                  value:
                      '${totalScheduleWeeks.toStringAsFixed(totalScheduleWeeks.truncateToDouble() == totalScheduleWeeks ? 0 : 1)} wks',
                  icon: Icons.schedule_outlined,
                  color: PcPalette.violet,
                  tileWidth: tileW,
                ),
              ];
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: tiles,
              );
            },
          ),
          const SizedBox(height: 16),
          // Status mix summary chip row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: PcPalette.surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PcPalette.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(Icons.pie_chart_outline,
                    size: 16, color: PcPalette.inkSecondary),
                const SizedBox(width: 8),
                Text(
                  'Status Mix',
                  style: TextStyle(
                    color: PcPalette.inkSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    fontFamily: appFontFamily,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _statusCountChip(
                          'Reserved', reservedCount, const Color(0xFF2563EB)),
                      _statusCountChip(
                          'Released', releasedCount, PcPalette.amber),
                      _statusCountChip(
                          'Consumed', consumedCount, PcPalette.danger),
                      _statusCountChip(
                          'Closed', closedCount, PcPalette.inkMuted),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const PcEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No allowance items to track yet',
              subtitle:
                  'Define allowances in Front End Planning → Allowance to begin tracking them here as the project progresses.',
              accent: PcPalette.amber,
            )
          else
            Column(
              children: items
                  .map((item) => _allowanceTrackingCard(item, formatter))
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _statusCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFamily: appFontFamily,
            ),
          ),
          const SizedBox(width: 4),
          Text(
          label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: appFontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _allowanceSummaryTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required double tileWidth,
  }) {
    return PcHoverBuilder(
      builder: (hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: tileWidth,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: PcPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hovered
                  ? color.withValues(alpha: 0.4)
                  : color.withValues(alpha: 0.18),
            ),
            boxShadow: [
              if (hovered)
                BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.95),
                      color.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: PcPalette.inkMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        fontFamily: appFontFamily,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        color: PcPalette.inkPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        fontFamily: appFontFamily,
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

  Widget _allowanceTrackingCard(AllowanceItem item, NumberFormat formatter) {
    final burnRate = item.amount > 0
        ? (item.actualAmount / item.amount).clamp(0.0, 2.0)
        : 0.0;
    final Color statusColor;
    switch (item.releaseStatus) {
      case 'Released':
        statusColor = PcPalette.amber;
        break;
      case 'Partially Released':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'Consumed':
        statusColor = PcPalette.danger;
        break;
      case 'Closed':
        statusColor = PcPalette.inkMuted;
        break;
      default:
        statusColor = const Color(0xFF2563EB);
    }
    final burnColor = burnRate > 1.0
        ? PcPalette.danger
        : burnRate > 0.75
            ? PcPalette.amber
            : PcPalette.emerald;

    return PcHoverBuilder(
      builder: (hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: PcPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hovered
                  ? statusColor.withValues(alpha: 0.4)
                  : PcPalette.border,
            ),
            boxShadow: [
              if (hovered)
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.1),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            color: PcPalette.inkPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFamily: appFontFamily,
                          ),
                        ),
                        if (item.description.isNotEmpty &&
                            item.description != item.name) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.description,
                            style: TextStyle(
                              color: PcPalette.inkSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              fontFamily: appFontFamily,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PcStatusPill(label: item.releaseStatus, color: statusColor),
                ],
              ),
              const SizedBox(height: 12),
              // Burn rate progress bar
              Row(
                children: [
                  Text(
                    'Burn Rate',
                    style: TextStyle(
                      color: PcPalette.inkMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      fontFamily: appFontFamily,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: burnRate,
                        backgroundColor: PcPalette.surfaceSubtle,
                        valueColor: AlwaysStoppedAnimation(burnColor),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: burnColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(burnRate * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: burnColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Meta row
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _metaText('Reserved', formatter.format(item.amount)),
                  _metaText('Released', formatter.format(item.releasedAmount)),
                  _metaText('Actual', formatter.format(item.actualAmount)),
                  if (item.scheduleImpactWeeks > 0)
                    _metaText('Schedule wks',
                        item.scheduleImpactWeeks.toStringAsFixed(1)),
                  if (item.responsibleDiscipline.isNotEmpty)
                    _metaText('Discipline', item.responsibleDiscipline),
                  if (item.triggerContext.isNotEmpty)
                    _metaText('Trigger', item.triggerContext),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metaText(String label, String value) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: PcPalette.inkSecondary,
          fontSize: 11,
          fontFamily: appFontFamily,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
                color: PcPalette.inkPrimary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _costCard(WorkPackageControl wp) {
    final pct = wp.currentBudget > 0 ? wp.actualCost / wp.currentBudget : 0.0;
    final pctClamped = pct.clamp(0.0, 1.0);
    final cpiColor = wp.cpi >= 1.0 ? PcPalette.emerald : PcPalette.danger;
    final pctColor = pct > 1.0 ? PcPalette.danger : PcPalette.amber;
    final vacColor = wp.vac >= 0 ? PcPalette.emerald : PcPalette.danger;

    return PcHoverBuilder(
      builder: (hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: PcPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hovered
                  ? PcPalette.indigo.withValues(alpha: 0.4)
                  : PcPalette.border,
            ),
            boxShadow: [
              if (hovered)
                BoxShadow(
                  color: PcPalette.indigo.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // WBS code chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: PcPalette.indigo.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      wp.wbsCode,
                      style: TextStyle(
                        color: PcPalette.indigo,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      wp.name,
                      style: TextStyle(
                        color: PcPalette.inkPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // CPI badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cpiColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: cpiColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          wp.cpi >= 1.0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 12,
                          color: cpiColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'CPI ${wp.cpi.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: cpiColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            fontFamily: appFontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Spend progress
              Row(
                children: [
                  Text(
                    'Spend',
                    style: TextStyle(
                      color: PcPalette.inkMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      fontFamily: appFontFamily,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pctClamped,
                        backgroundColor: PcPalette.surfaceSubtle,
                        valueColor: AlwaysStoppedAnimation(pctColor),
                        minHeight: 7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: pctColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: pctColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Footer row: Budget / Actual / EAC / VAC
              LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth > 720 ? 4 : 2;
                  final spacing = 10.0;
                  final cellW = (c.maxWidth - spacing * (cols - 1)) / cols;
                  final cells = <Widget>[
                    _costMetricCell(
                        label: 'Budget',
                        value:
                            '\$${(wp.currentBudget / 1000000).toStringAsFixed(2)}M',
                        color: PcPalette.inkSecondary,
                        width: cellW),
                    _costMetricCell(
                        label: 'Actual',
                        value:
                            '\$${(wp.actualCost / 1000000).toStringAsFixed(2)}M',
                        color: PcPalette.inkPrimary,
                        width: cellW),
                    _costMetricCell(
                        label: 'EAC',
                        value: '\$${(wp.eac / 1000000).toStringAsFixed(2)}M',
                        color: PcPalette.inkPrimary,
                        bold: true,
                        width: cellW),
                    _costMetricCell(
                        label: 'VAC',
                        value:
                            '\$${(wp.vac / 1000).toStringAsFixed(0)}K',
                        color: vacColor,
                        bold: true,
                        width: cellW),
                  ];
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: cells,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _costMetricCell({
    required String label,
    required String value,
    required Color color,
    required double width,
    bool bold = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: PcPalette.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PcPalette.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: PcPalette.inkMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontFamily: appFontFamily,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontFamily: appFontFamily,
            ),
          ),
        ],
      ),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════
// TAB: Change Management
// ═════════════════════════════════════════════════════════════════════════

class _ChangeMgmtTab extends StatelessWidget {
  final ProjectControlsState state;
  final ProjectControlsProvider provider;
  final List<String> changeRecommendations;
  final String aiContext;
  const _ChangeMgmtTab({
    required this.state,
    required this.provider,
    required this.changeRecommendations,
    required this.aiContext,
  });

  @override
  Widget build(BuildContext context) {
    final crs = state.changeRequests;
    final pending = crs.where((c) => c.status == ChangeStatus.underReview).length;
    final approved = crs.where((c) => c.status == ChangeStatus.approved).length;

    return PcTabShell(
      eyebrow: 'Change Management',
      title: 'Change Management',
      subtitle:
          'Track and approve change requests through your project\'s governance workflow — '
          '${state.deliveryModel.label} • ${state.deliveryModel.changeProcess}',
      icon: Icons.sync_alt_rounded,
      accent: PcPalette.teal,
      accentDeep: const Color(0xFF0D9488),
      accentSoft: const Color(0xFFCCFBF1),
      tint: const Color(0xFFF0FDFA),
      borderColor: const Color(0xFF99F6E4),
      kpis: [
        PcKpiSpec(
          label: 'Total Requests',
          value: '${crs.length}',
          sub: crs.isEmpty ? 'No changes registered' : 'Across all categories',
          icon: Icons.sync_alt_rounded,
          accent: PcPalette.teal,
        ),
        PcKpiSpec(
          label: 'Under Review',
          value: '$pending',
          sub: pending == 0 ? 'None pending' : 'Awaiting approval',
          icon: Icons.hourglass_top_rounded,
          accent: PcPalette.amber,
        ),
        PcKpiSpec(
          label: 'Approved',
          value: '$approved',
          sub: approved == 0 ? 'None approved' : 'Approved changes',
          icon: Icons.check_circle_rounded,
          accent: PcPalette.emerald,
        ),
        PcKpiSpec(
          label: 'AI Recommendations',
          value: '${changeRecommendations.length}',
          sub: changeRecommendations.isEmpty
              ? 'No auto-populated'
              : 'From project constraints',
          icon: Icons.auto_awesome_rounded,
          accent: PcPalette.rose,
        ),
      ],
      sections: [
        if (changeRecommendations.isNotEmpty)
          _buildAiRecommendationsCard(context, changeRecommendations),
        PcSectionCard(
          title: 'Change Requests',
          subtitle:
              'Formal change requests with impact analysis, affected baselines, and approval workflow.',
          icon: Icons.list_alt_rounded,
          accent: PcPalette.teal,
          trailing: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: PcPalette.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${crs.length} request${crs.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: PcPalette.teal,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          child: crs.isEmpty
              ? const PcEmptyState(
                  icon: Icons.sync_alt_rounded,
                  title: 'No change requests yet',
                  subtitle:
                      'Change requests from your project will appear here. AI recommendations above can be converted to formal change requests.',
                  accent: PcPalette.teal,
                )
              : Column(
                  children: crs
                      .map((cr) => _changeRequestCard(cr, context))
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }

  Widget _buildAiRecommendationsCard(
      BuildContext context, List<String> recommendations) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFF1F2),
            const Color(0xFFFFE4E6),
          ],
        ),
        border: Border.all(
          color: PcPalette.rose.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: PcPalette.rose.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 24,
            right: 24,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    PcPalette.rose.withValues(alpha: 0),
                    PcPalette.rose,
                    const Color(0xFFE11D48),
                    PcPalette.rose.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            PcPalette.rose.withValues(alpha: 0.95),
                            const Color(0xFFE11D48),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PcPalette.rose.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'AI Change Recommendations',
                            style: TextStyle(
                              color: PcPalette.inkPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.1,
                              fontFamily: appFontFamily,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Auto-populated from project constraints, assumptions, and risk data',
                            style: TextStyle(
                              color: PcPalette.inkSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: appFontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: PcPalette.rose.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${recommendations.length} item${recommendations.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: PcPalette.rose,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: appFontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  children: recommendations.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: PcPalette.rose.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: PcPalette.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color:
                                      PcPalette.amber.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${entry.key + 1}',
                                  style: TextStyle(
                                    color: PcPalette.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: appFontFamily,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: PcPalette.inkPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                  fontFamily: appFontFamily,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _createCrButton(context, entry.value),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _createCrButton(BuildContext context, String text) {
    return PcHoverBuilder(
      builder: (hovered) {
        return GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Change request created for: ${text.length > 40 ? '${text.substring(0, 40)}...' : text}'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: PcPalette.teal,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hovered
                  ? PcPalette.teal
                  : PcPalette.teal.withValues(alpha: 0.1)
              ,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: PcPalette.teal.withValues(alpha: hovered ? 1.0 : 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 12,
                  color: hovered ? Colors.white : PcPalette.teal,
                ),
                const SizedBox(width: 4),
                Text(
                  'Create CR',
                  style: TextStyle(
                    color: hovered ? Colors.white : PcPalette.teal,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFamily: appFontFamily,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _changeRequestCard(ChangeRequest cr, BuildContext context) {
    return PcHoverBuilder(
      builder: (hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: PcPalette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hovered
                  ? cr.status.color.withValues(alpha: 0.5)
                  : cr.status.color.withValues(alpha: 0.28),
            ),
            boxShadow: [
              if (hovered)
                BoxShadow(
                  color: cr.status.color.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: cr.status.color.withValues(alpha: 0.05),
                    border: Border(
                      bottom: BorderSide(
                        color: cr.status.color.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              cr.status.color.withValues(alpha: 0.95),
                              cr.status.color.withValues(alpha: 0.65),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cr.status.color.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(cr.category.icon,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cr.description,
                              style: TextStyle(
                                color: PcPalette.inkPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFamily: appFontFamily,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${cr.id} • ${cr.category.label} • Priority: ${cr.priority}',
                              style: TextStyle(
                                color: PcPalette.inkSecondary,
                                fontSize: 11,
                                fontFamily: appFontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PcStatusPill(
                          label: cr.status.label, color: cr.status.color),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildChangeBody(cr),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildChangeBody(ChangeRequest cr) {
    final children = <Widget>[];

    // Justification + root cause
    children.add(_kvRow('Justification', cr.justification));
    if (cr.rootCause != null) {
      children.add(const SizedBox(height: 6));
      children.add(_kvRow('Root Cause', cr.rootCause!));
    }

    children.add(const SizedBox(height: 14));

    // Impact analysis
    children.add(_sectionLabel('IMPACT ANALYSIS'));
    children.add(const SizedBox(height: 8));
    children.add(
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _buildImpactChips(cr),
      ),
    );

    // Affected baselines
    if (cr.affectedBaselines.isNotEmpty) {
      children.add(const SizedBox(height: 14));
      children.add(_sectionLabel('AFFECTED BASELINES'));
      children.add(const SizedBox(height: 6));
      children.add(
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: cr.affectedBaselines
              .map((b) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: PcPalette.surfaceSubtle,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: PcPalette.borderSubtle),
                    ),
                    child: Text(
                      b,
                      style: TextStyle(
                        color: PcPalette.inkSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ))
              .toList(),
        ),
      );
    }

    // Approval workflow
    if (cr.approval != null) {
      children.add(const SizedBox(height: 14));
      children.add(_sectionLabel('APPROVAL WORKFLOW'));
      children.add(const SizedBox(height: 10));
      for (final entry in cr.approval!.steps.asMap().entries) {
        final step = entry.value;
        final isCurrent = entry.key == cr.approval!.currentStepIndex;
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: step.approved
                      ? PcPalette.emerald
                      : (isCurrent
                          ? PcPalette.amber
                          : PcPalette.border),
                  shape: BoxShape.circle,
                  boxShadow: step.approved || isCurrent
                      ? [
                          BoxShadow(
                            color: (step.approved
                                    ? PcPalette.emerald
                                    : PcPalette.amber)
                                .withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: step.approved
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14)
                    : (isCurrent
                        ? const Icon(Icons.hourglass_top_rounded,
                            color: Colors.white, size: 13)
                        : null),
              ),
              const SizedBox(width: 10),
              Text(
                step.role.label,
                style: TextStyle(
                  color: step.approved
                      ? PcPalette.emerald
                      : (isCurrent
                          ? PcPalette.amber
                          : PcPalette.inkSecondary),
                  fontSize: 12.5,
                  fontWeight:
                      step.approved || isCurrent ? FontWeight.w700 : FontWeight.w500,
                  fontFamily: appFontFamily,
                ),
              ),
              if (step.approved && step.approvedAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  '✓ ${step.approvedAt!.day}/${step.approvedAt!.month}',
                  style: TextStyle(
                    color: PcPalette.emerald,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: appFontFamily,
                  ),
                ),
              ],
            ],
          ),
        ));
      }
    }

    // Action button
    if (cr.status == ChangeStatus.underReview &&
        cr.approval != null &&
        cr.approval!.currentStep != null) {
      children.add(const SizedBox(height: 14));
      children.add(
        PcHoverBuilder(
          builder: (hovered) {
            return AnimatedScale(
              scale: hovered ? 1.01 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => provider.approveChangeStep(cr.id),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(
                      'Approve as ${cr.approval!.currentStep!.role.label}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PcPalette.emerald,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    return children;
  }

  Widget _kvRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: PcPalette.inkSecondary,
          fontSize: 12,
          height: 1.4,
          fontFamily: appFontFamily,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
                color: PcPalette.inkPrimary,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: PcPalette.inkMuted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        fontFamily: appFontFamily,
      ),
    );
  }

  List<Widget> _buildImpactChips(ChangeRequest cr) {
    final chips = <Widget>[];
    if (cr.impact.scheduleImpactDays != null &&
        cr.impact.scheduleImpactDays! > 0) {
      chips.add(_impactChip(
          'Schedule', '+${cr.impact.scheduleImpactDays!.round()} days', PcPalette.danger));
    }
    if (cr.impact.costImpactAmount != null &&
        cr.impact.costImpactAmount! > 0) {
      chips.add(_impactChip('Cost',
          '+\$${(cr.impact.costImpactAmount! / 1000).round()}K', PcPalette.amber));
    }
    if (cr.impact.scopeImpact != null) {
      chips.add(_impactChip('Scope', cr.impact.scopeImpact!, PcPalette.indigo));
    }
    if (cr.impact.resourceImpact != null) {
      chips.add(_impactChip(
          'Resource', cr.impact.resourceImpact!, PcPalette.violet));
    }
    if (cr.impact.procurementImpact != null) {
      chips.add(_impactChip(
          'Procurement', cr.impact.procurementImpact!, PcPalette.emerald));
    }
    if (cr.impact.riskImpact != null) {
      chips.add(
          _impactChip('Risk', cr.impact.riskImpact!, PcPalette.rose));
    }
    return chips;
  }

  Widget _impactChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              fontFamily: appFontFamily,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFamily: appFontFamily,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════
// TAB: Forecasting
// ═════════════════════════════════════════════════════════════════════════

class _ForecastingTab extends StatelessWidget {
  final ProjectControlsState state;
  const _ForecastingTab({required this.state});

  @override
  Widget build(BuildContext context) {
    return PcTabShell(
      eyebrow: 'Forecasting & Analytics',
      title: 'Forecasting',
      subtitle:
          'Automated forecasts based on current performance trends — EAC, ETC, VAC, and per-work-package CPI/SPI.',
      icon: Icons.trending_up_rounded,
      accent: PcPalette.fuchsia,
      accentDeep: const Color(0xFFA21CAF),
      accentSoft: const Color(0xFFFAE8FF),
      tint: const Color(0xFFFDF4FF),
      borderColor: const Color(0xFFF5D0FE),
      kpis: [
        PcKpiSpec(
          label: 'EAC',
          value:
              '\$${(state.portfolioEAC / 1000000).toStringAsFixed(2)}M',
          sub: state.portfolioEAC <= state.totalOriginalBudget
              ? 'Under original budget'
              : 'Over original budget',
          icon: Icons.flag_rounded,
          accent: state.portfolioEAC <= state.totalOriginalBudget
              ? PcPalette.emerald
              : PcPalette.danger,
        ),
        PcKpiSpec(
          label: 'ETC',
          value:
              '\$${((state.portfolioEAC - state.totalActualCost) / 1000000).toStringAsFixed(2)}M',
          sub: 'Estimate to Complete',
          icon: Icons.hourglass_empty_rounded,
          accent: PcPalette.indigo,
        ),
        PcKpiSpec(
          label: 'VAC',
          value:
              '\$${(state.portfolioVAC / 1000000).toStringAsFixed(2)}M',
          sub: state.portfolioVAC >= 0
              ? 'Variance at Completion (under)'
              : 'Variance at Completion (over)',
          icon: Icons.show_chart_rounded,
          accent:
              state.portfolioVAC >= 0 ? PcPalette.emerald : PcPalette.danger,
        ),
        PcKpiSpec(
          label: 'Avg Progress',
          value: '${state.avgPercentComplete.round()}%',
          sub: '${state.workPackages.length} work packages',
          icon: Icons.timeline_rounded,
          accent: PcPalette.violet,
        ),
      ],
      sections: [
        PcSectionCard(
          title: 'Performance Trends',
          subtitle:
              'CPI / SPI per work package — color-coded health with progress bars showing percent complete.',
          icon: Icons.bar_chart_rounded,
          accent: PcPalette.fuchsia,
          trailing: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: PcPalette.fuchsia.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${state.workPackages.length} package${state.workPackages.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: PcPalette.fuchsia,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          child: state.workPackages.isEmpty
              ? const PcEmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'No work packages',
                  subtitle:
                      'Work packages will appear here once your project is set up.',
                  accent: PcPalette.fuchsia,
                )
              : Column(
                  children: state.workPackages
                      .map((wp) => _wpTrendCard(wp))
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }

  Widget _wpTrendCard(WorkPackageControl wp) {
    final cpiColor =
        wp.cpi >= 1.0 ? PcPalette.emerald : PcPalette.danger;
    final spiColor =
        wp.spi >= 1.0 ? PcPalette.emerald : PcPalette.danger;
    final pctComplete = wp.percentComplete?.round() ?? 0;

    return PcHoverBuilder(
      builder: (hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: PcPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hovered
                  ? PcPalette.fuchsia.withValues(alpha: 0.4)
                  : PcPalette.border,
            ),
            boxShadow: [
              if (hovered)
                BoxShadow(
                  color: PcPalette.fuchsia.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: PcPalette.indigo.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      wp.wbsCode,
                      style: TextStyle(
                        color: PcPalette.indigo,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      wp.name,
                      style: TextStyle(
                        color: PcPalette.inkPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cpiColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: cpiColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      'CPI ${wp.cpi.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: cpiColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: spiColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: spiColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      'SPI ${wp.spi.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: spiColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'PROGRESS',
                    style: TextStyle(
                      color: PcPalette.inkMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      fontFamily: appFontFamily,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (pctComplete / 100).clamp(0.0, 1.0),
                        backgroundColor: PcPalette.surfaceSubtle,
                        valueColor: AlwaysStoppedAnimation(
                          pctComplete >= 80
                              ? PcPalette.emerald
                              : pctComplete >= 50
                                  ? PcPalette.amber
                                  : PcPalette.indigo,
                        ),
                        minHeight: 7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: PcPalette.inkPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$pctComplete%',
                      style: TextStyle(
                        color: PcPalette.inkPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        fontFamily: appFontFamily,
                      ),
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
}


// ═════════════════════════════════════════════════════════════════════════
// TAB: Baseline Management
// ═════════════════════════════════════════════════════════════════════════
// ═════════════════════════════════════════════════════════════════════════
// TAB: Baseline Management  —  World-class redesign
// ═════════════════════════════════════════════════════════════════════════

class _BaselineMgmtTab extends StatefulWidget {
  final ProjectControlsState state;
  final ProjectControlsProvider provider;
  const _BaselineMgmtTab({required this.state, required this.provider});

  @override
  State<_BaselineMgmtTab> createState() => _BaselineMgmtTabState();
}

class _BaselineMgmtTabState extends State<_BaselineMgmtTab>
    with SingleTickerProviderStateMixin {
  int? _compareAVersion;
  int? _compareBVersion;
  late final AnimationController _intro;

  // Local palette — tightly coordinated, top 1% polish.
  static const Color _inkPrimary = Color(0xFF0B1220);
  static const Color _inkSecondary = Color(0xFF475467);
  static const Color _inkMuted = Color(0xFF98A2B3);
  static const Color _surface = Colors.white;
  static const Color _surfaceSubtle = Color(0xFFF9FAFB);
  static const Color _surfaceElevated = Color(0xFFFFFFFF);
  static const Color _border = Color(0xFFE4E7EC);
  static const Color _borderSubtle = Color(0xFFEFF1F4);
  static const Color _gold = Color(0xFFFFC107);
  static const Color _goldDeep = Color(0xFFF59E0B);
  static const Color _goldSoft = Color(0xFFFFF4CC);
  static const Color _indigo = Color(0xFF6366F1);
  static const Color _emerald = Color(0xFF10B981);
  static const Color _amber = Color(0xFFD97706);
  static const Color _violet = Color(0xFF8B5CF6);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _dangerSurface = Color(0xFFFFF1F1);

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 720;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBFCFD), Color(0xFFF3F5F8)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: FadeTransition(
              opacity: _intro,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(_intro),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHero(),
                    const SizedBox(height: 22),
                    _buildKpiStrip(isNarrow),
                    const SizedBox(height: 28),
                    _buildSnapshotHistory(),
                    const SizedBox(height: 28),
                    _buildCompareBaselines(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // HERO — page identity, primary action, ambient gradient.
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildHero() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFFCF8E8)],
        ),
        border: Border.all(color: const Color(0xFFF1E8C5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1220).withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _gold.withValues(alpha: 0.06),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top accent ribbon
          Positioned(
            top: 0,
            left: 24,
            right: 24,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    _gold.withValues(alpha: 0),
                    _gold,
                    _goldDeep,
                    _gold.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
            child: LayoutBuilder(
              builder: (context, c) {
                final stacked = c.maxWidth < 720;
                return stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroBadge(),
                          const SizedBox(height: 18),
                          _buildHeroCopy(),
                          const SizedBox(height: 20),
                          _buildHeroAction(),
                        ],
                      )
                    : Row(
                        children: [
                          _buildHeroBadge(),
                          const SizedBox(width: 22),
                          Expanded(child: _buildHeroCopy()),
                          const SizedBox(width: 22),
                          _buildHeroAction(),
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBadge() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gold, _goldDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Inner glow ring
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
            ),
          ),
          const Center(
            child: Icon(
              Icons.layers_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCopy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _goldSoft,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _gold.withValues(alpha: 0.35)),
          ),
          child: Text(
            'BASELINE MANAGEMENT',
            style: TextStyle(
              color: _goldDeep,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontFamily: appFontFamily,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Baseline Management',
          style: TextStyle(
            color: _inkPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.15,
            fontFamily: appFontFamily,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Snapshots, version comparison and rollback control',
          style: TextStyle(
            color: _inkSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            height: 1.4,
            fontFamily: appFontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroAction() {
    return _HoverBuilder(
      builder: (hovered) {
        return AnimatedScale(
          scale: hovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showCreateBaselineDialog(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_gold, _goldDeep],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: hovered ? 0.5 : 0.3),
                      blurRadius: hovered ? 16 : 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'New Baseline',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // KPI STRIP — four tactile metric cards with accent rails.
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildKpiStrip(bool isNarrow) {
    final history = widget.state.baselineHistory;
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 1100
            ? 4
            : c.maxWidth > 720
                ? 2
                : 1;
        const spacing = 14.0;
        final cardW = (c.maxWidth - spacing * (cols - 1)) / cols;
        final children = <Widget>[
          _buildKpiCard(
            label: 'Snapshots',
            value: '${history.length}',
            sub: history.isEmpty ? 'No locks yet' : 'Locked baselines',
            icon: Icons.history_rounded,
            accent: _indigo,
            cardWidth: cardW,
          ),
          _buildKpiCard(
            label: 'Latest Version',
            value: history.isEmpty ? '—' : 'v${history.last.version}',
            sub: history.isEmpty ? 'Awaiting first lock' : history.last.type.label,
            icon: Icons.layers_rounded,
            accent: _emerald,
            cardWidth: cardW,
          ),
          _buildKpiCard(
            label: 'Current BAC',
            value:
                '\$${(widget.state.totalOriginalBudget / 1000000).toStringAsFixed(2)}M',
            sub: 'Budget at Completion',
            icon: Icons.account_balance_wallet_rounded,
            accent: _amber,
            cardWidth: cardW,
          ),
          _buildKpiCard(
            label: 'Work Packages',
            value: '${widget.state.workPackages.length}',
            sub: widget.state.deliveryModel == DeliveryModel.agile
                ? 'Agile epics'
                : 'Tracked packages',
            icon: Icons.account_tree_rounded,
            accent: _violet,
            cardWidth: cardW,
          ),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children,
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color accent,
    required double cardWidth,
  }) {
    return _HoverBuilder(
      builder: (hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: cardWidth,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hovered
                  ? accent.withValues(alpha: 0.4)
                  : const Color(0xFFE4E7EC),
            ),
            boxShadow: [
              BoxShadow(
                color: _inkPrimary.withValues(alpha: hovered ? 0.08 : 0.04),
                blurRadius: hovered ? 18 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Accent left rail
              Positioned(
                left: 0,
                top: 12,
                bottom: 12,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent.withValues(alpha: 0.95),
                                accent.withValues(alpha: 0.65),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 20),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'LIVE',
                            style: TextStyle(
                              color: accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              fontFamily: appFontFamily,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: _inkMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        fontFamily: appFontFamily,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: _inkPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontFamily: appFontFamily,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(
                        color: _inkSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFamily: appFontFamily,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  // ──────────────────────────────────────────────────────────────────────
  // SNAPSHOT HISTORY — editorial timeline.
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildSnapshotHistory() {
    final history = widget.state.baselineHistory;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _inkPrimary.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _goldSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _gold.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.history_rounded,
                    color: _goldDeep, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Snapshot History',
                      style: TextStyle(
                        color: _inkPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: appFontFamily,
                      ),
                    ),
                    Text(
                      'Chronological record of every baseline lock',
                      style: TextStyle(
                        color: _inkSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _surfaceSubtle,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.layers_rounded,
                        size: 12, color: _inkSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '${history.length} ${history.length == 1 ? 'snapshot' : 'snapshots'}',
                      style: TextStyle(
                        color: _inkSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (history.isEmpty)
            _buildEmptyHistory()
          else
            _buildTimeline(history),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: _surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _border,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: _inkPrimary.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.history_toggle_off_rounded,
                color: _inkMuted, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            'No baselines locked yet',
            style: TextStyle(
              color: _inkPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: appFontFamily,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lock your first baseline to capture a snapshot of scope, cost and schedule.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _inkSecondary,
              fontSize: 12,
              fontFamily: appFontFamily,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _HoverBuilder(
            builder: (hovered) => AnimatedScale(
              scale: hovered ? 1.02 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showCreateBaselineDialog(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: [_gold, _goldDeep],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _gold.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Lock first baseline',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: appFontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<BaselineSnapshot> history) {
    final reversed = history.reversed.toList();
    return Stack(
      children: [
        // Vertical rail
        Positioned(
          left: 27,
          top: 14,
          bottom: 14,
          child: Container(
            width: 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _gold.withValues(alpha: 0.6),
                  _gold.withValues(alpha: 0.2),
                  _border,
                ],
              ),
            ),
          ),
        ),
        Column(
          children: [
            for (int i = 0; i < reversed.length; i++)
              _buildTimelineNode(reversed[i], history, i == 0),
          ],
        ),
      ],
    );
  }

  Widget _buildTimelineNode(
      BaselineSnapshot b, List<BaselineSnapshot> all, bool isLatest) {
    final isCurrent =
        all.isNotEmpty && b.version == all.last.version;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node marker
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent ? _gold : Colors.white,
                    border: Border.all(
                      color: isCurrent
                          ? _goldDeep
                          : _border,
                      width: isCurrent ? 2 : 1.5,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: _gold.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isCurrent
                        ? Icon(Icons.lock_rounded,
                            color: Colors.white, size: 16)
                        : Text(
                            'v${b.version}',
                            style: TextStyle(
                              color: _inkSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              fontFamily: appFontFamily,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Card
          Expanded(child: _buildSnapshotCard(b, all, isLatest: isLatest)),
        ],
      ),
    );
  }

  Widget _buildSnapshotCard(
    BaselineSnapshot b,
    List<BaselineSnapshot> all, {
    required bool isLatest,
  }) {
    final isCurrent =
        all.isNotEmpty && b.version == all.last.version;
    final dateStr =
        '${b.lockedAt.day}/${b.lockedAt.month}/${b.lockedAt.year}';
    final typeColor = _typeColor(b.type);

    return _HoverBuilder(
      builder: (hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrent
                  ? _gold.withValues(alpha: 0.45)
                  : hovered
                      ? const Color(0xFFCBD5E1)
                      : _border,
            ),
            boxShadow: [
              BoxShadow(
                color: _inkPrimary
                    .withValues(alpha: hovered ? 0.06 : 0.03),
                blurRadius: hovered ? 16 : 8,
                offset: const Offset(0, 3),
              ),
              if (isCurrent)
                BoxShadow(
                  color: _gold.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header band
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(18, 16, 14, 14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: typeColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(Icons.layers_rounded,
                          color: typeColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'v${b.version}',
                                style: TextStyle(
                                  color: _inkPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  fontFamily: appFontFamily,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 6),
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFCBD5E1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  b.type.label,
                                  style: TextStyle(
                                    color: _inkSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: appFontFamily,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 11, color: _inkMuted),
                              const SizedBox(width: 4),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  color: _inkMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: appFontFamily,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(Icons.person_rounded,
                                  size: 11, color: _inkMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  b.lockedBy,
                                  style: TextStyle(
                                    color: _inkMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: appFontFamily,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isCurrent) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _gold,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: _gold.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 10),
                            const SizedBox(width: 4),
                            Text(
                              'CURRENT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                fontFamily: appFontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _HoverBuilder(
                      builder: (h) => AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: isCurrent ? 0.4 : (h ? 1.0 : 0.7),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isCurrent
                                ? null
                                : () => _confirmRollback(b),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _dangerSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _danger.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.restore_rounded,
                                      color: _danger, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Roll back',
                                    style: TextStyle(
                                      color: _danger,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: appFontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Reason strip
              if (b.reason != null && b.reason!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _borderSubtle),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.flag_rounded,
                          size: 13, color: _inkMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REASON',
                              style: TextStyle(
                                color: _inkMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                fontFamily: appFontFamily,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              b.reason!,
                              style: TextStyle(
                                color: _inkPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                                fontFamily: appFontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 12),
              // Metric strip
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderSubtle),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _metricCell(
                            label: 'BAC',
                            value:
                                '\$${(b.totalBudget / 1000000).toStringAsFixed(2)}M',
                            icon: Icons.account_balance_wallet_rounded,
                          ),
                        ),
                        VerticalDivider(
                            width: 1,
                            color: _borderSubtle,
                            indent: 10,
                            endIndent: 10),
                        Expanded(
                          child: _metricCell(
                            label: 'WORK PACKAGES',
                            value: '${b.workPackages.length}',
                            icon: Icons.account_tree_rounded,
                          ),
                        ),
                        VerticalDivider(
                            width: 1,
                            color: _borderSubtle,
                            indent: 10,
                            endIndent: 10),
                        Expanded(
                          child: _metricCell(
                            label: 'SCOPE HASH',
                            value: b.scopeHashOrDerived,
                            icon: Icons.fingerprint_rounded,
                            mono: true,
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
      },
    );
  }

  Widget _metricCell({
    required String label,
    required String value,
    required IconData icon,
    bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: _inkMuted),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: _inkMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontFamily: appFontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: _inkPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              fontFamily: mono ? 'RobotoMono' : appFontFamily,
              letterSpacing: mono ? -0.2 : 0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _typeColor(BaselineType t) {
    switch (t) {
      case BaselineType.scope:
        return _indigo;
      case BaselineType.schedule:
        return const Color(0xFF0EA5E9);
      case BaselineType.cost:
        return _amber;
      case BaselineType.resource:
        return _violet;
      case BaselineType.procurement:
        return const Color(0xFF14B8A6);
      case BaselineType.contract:
        return const Color(0xFFEC4899);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // COMPARE BASELINES — high-end diff tool aesthetic.
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildCompareBaselines() {
    final history = widget.state.baselineHistory;
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _inkPrimary.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top accent ribbon
          Positioned(
            top: 0,
            left: 24,
            right: 24,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    _indigo.withValues(alpha: 0),
                    _indigo,
                    _violet,
                    _violet.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_indigo, _violet],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _indigo.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.compare_arrows_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compare Baselines',
                            style: TextStyle(
                              color: _inkPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: appFontFamily,
                            ),
                          ),
                          Text(
                            'Select two snapshots to view a field-by-field delta',
                            style: TextStyle(
                              color: _inkSecondary,
                              fontSize: 12,
                              fontFamily: appFontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Pickers
                LayoutBuilder(
                  builder: (context, c) {
                    final stacked = c.maxWidth < 640;
                    if (stacked) {
                      return Column(
                        children: [
                          _comparePicker(
                            'Baseline A',
                            _compareAVersion,
                            (v) => setState(() => _compareAVersion = v),
                            history,
                            color: _indigo,
                          ),
                          const SizedBox(height: 10),
                          _swapButton(),
                          const SizedBox(height: 10),
                          _comparePicker(
                            'Baseline B',
                            _compareBVersion,
                            (v) => setState(() => _compareBVersion = v),
                            history,
                            color: _violet,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: _comparePicker(
                            'Baseline A',
                            _compareAVersion,
                            (v) => setState(() => _compareAVersion = v),
                            history,
                            color: _indigo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _swapButton(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _comparePicker(
                            'Baseline B',
                            _compareBVersion,
                            (v) => setState(() => _compareBVersion = v),
                            history,
                            color: _violet,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                // Diff result
                if (_compareAVersion != null &&
                    _compareBVersion != null &&
                    _compareAVersion != _compareBVersion)
                  _buildDiffTable(
                    history.firstWhere(
                        (b) => b.version == _compareAVersion),
                    history.firstWhere(
                        (b) => b.version == _compareBVersion),
                  )
                else if (_compareAVersion != null &&
                    _compareBVersion != null &&
                    _compareAVersion == _compareBVersion)
                  _compareEmptyState(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Pick two different baselines',
                    message:
                        'You selected the same baseline on both sides — choose a different snapshot to see the delta.',
                  )
                else
                  _compareEmptyState(
                    icon: Icons.compare_rounded,
                    title: 'No comparison yet',
                    message:
                        'Select two baselines above to view a field-by-field delta.',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _swapButton() {
    return _HoverBuilder(
      builder: (hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (_compareAVersion == null || _compareBVersion == null)
                ? null
                : () {
                    setState(() {
                      final t = _compareAVersion;
                      _compareAVersion = _compareBVersion;
                      _compareBVersion = t;
                    });
                  },
            borderRadius: BorderRadius.circular(10),
            child: Tooltip(
              message: 'Swap A ↔ B',
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hovered ? _surfaceSubtle : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: _inkSecondary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _comparePicker(
    String label,
    int? value,
    ValueChanged<int?> onChanged,
    List<BaselineSnapshot> history,
    {required Color color}
  ) {
    final selected = value != null
        ? history.where((b) => b.version == value).toList()
        : <BaselineSnapshot>[];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: _surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.layers_rounded, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: _inkMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    fontFamily: appFontFamily,
                  ),
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: value,
                      isExpanded: true,
                      hint: Text(
                        'Select version',
                        style: TextStyle(
                          color: _inkSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: appFontFamily,
                        ),
                      ),
                      style: TextStyle(
                        color: _inkPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: appFontFamily,
                      ),
                      dropdownColor: Colors.white,
                      items: [
                        for (final b in history)
                          DropdownMenuItem<int?>(
                            value: b.version,
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('v${b.version}'),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    b.type.label,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: appFontFamily,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      onChanged: onChanged,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'v${selected.first.version}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFamily: appFontFamily,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _compareEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: _surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _border,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _border),
            ),
            child: Icon(icon, color: _inkMuted, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: _inkPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: appFontFamily,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _inkSecondary,
              fontSize: 11.5,
              height: 1.5,
              fontFamily: appFontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffTable(BaselineSnapshot a, BaselineSnapshot b) {
    final rows = <_DiffRow>[
      _DiffRow('Version', 'v${a.version}', 'v${b.version}'),
      _DiffRow('Type', a.type.label, b.type.label),
      _DiffRow(
        'Locked at',
        '${a.lockedAt.day}/${a.lockedAt.month}/${a.lockedAt.year}',
        '${b.lockedAt.day}/${b.lockedAt.month}/${b.lockedAt.year}',
      ),
      _DiffRow('Locked by', a.lockedBy, b.lockedBy),
      _DiffRow(
        'BAC',
        '\$${(a.totalBudget / 1000000).toStringAsFixed(2)}M',
        '\$${(b.totalBudget / 1000000).toStringAsFixed(2)}M',
      ),
      _DiffRow(
        'Work packages',
        '${a.workPackages.length}',
        '${b.workPackages.length}',
      ),
      _DiffRow('Reason', a.reason ?? '—', b.reason ?? '—'),
      _DiffRow('Scope hash', a.scopeHashOrDerived, b.scopeHashOrDerived),
    ];
    final changedCount = rows.where((r) => r.changed).length;
    return Container(
      decoration: BoxDecoration(
        color: _surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // Summary header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: changedCount > 0
                        ? _amber.withValues(alpha: 0.12)
                        : _emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    changedCount > 0
                        ? Icons.change_circle_rounded
                        : Icons.check_circle_rounded,
                    color: changedCount > 0 ? _amber : _emerald,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: _inkSecondary,
                        fontSize: 12,
                        fontFamily: appFontFamily,
                      ),
                      children: [
                        TextSpan(
                          text: '$changedCount',
                          style: TextStyle(
                            color: changedCount > 0 ? _amber : _emerald,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                            text:
                                ' field${changedCount == 1 ? '' : 's'} changed across '),
                        TextSpan(
                          text: '${rows.length}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800),
                        ),
                        const TextSpan(text: ' compared'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _border, thickness: 1),
          // Table header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: _diffHeaderCell('FIELD',
                        icon: Icons.label_rounded)),
                Expanded(
                    flex: 4,
                    child: _diffHeaderCell('BASELINE A',
                        icon: Icons.looks_one_rounded, color: _indigo)),
                Expanded(
                    flex: 4,
                    child: _diffHeaderCell('BASELINE B',
                        icon: Icons.looks_two_rounded, color: _violet)),
                Expanded(
                    flex: 1,
                    child: _diffHeaderCell('Δ', icon: Icons.change_history_rounded, centered: true)),
              ],
            ),
          ),
          Divider(height: 1, color: _borderSubtle, thickness: 1),
          // Rows
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              children: [
                for (final r in rows) _buildDiffRow(r),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diffHeaderCell(String label,
      {required IconData icon, Color? color, bool centered = false}) {
    return Row(
      mainAxisAlignment:
          centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Icon(icon, size: 10, color: color ?? _inkMuted),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color ?? _inkMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            fontFamily: appFontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildDiffRow(_DiffRow r) {
    final changed = r.changed;
    return _HoverBuilder(
      builder: (hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: changed
              ? (hovered
                  ? const Color(0xFFFFF7DA)
                  : const Color(0xFFFFFBE8))
              : (hovered ? _surface : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: changed ? _amber : _emerald,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      r.field,
                      style: TextStyle(
                        color: _inkPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: appFontFamily,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                r.a,
                style: TextStyle(
                  color: changed ? _inkSecondary : _inkSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  fontFamily: appFontFamily,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                r.b,
                style: TextStyle(
                  color: changed ? _amber : _inkSecondary,
                  fontSize: 11.5,
                  fontWeight: changed ? FontWeight.w800 : FontWeight.w500,
                  fontFamily: appFontFamily,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: changed
                    ? Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.arrow_forward_rounded,
                            color: _amber, size: 12),
                      )
                    : Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _emerald.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.check_rounded,
                            color: _emerald, size: 12),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // CREATE BASELINE DIALOG — world-class type picker + live preview.
  // ──────────────────────────────────────────────────────────────────────
  void _showCreateBaselineDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    BaselineType selectedType = BaselineType.scope;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          titlePadding: EdgeInsets.zero,
          title: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_gold, _goldDeep],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Baseline',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          fontFamily: appFontFamily,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lock a snapshot of the current project state',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontFamily: appFontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BASELINE TYPE',
                      style: TextStyle(
                        color: _inkMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        fontFamily: appFontFamily,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in BaselineType.values)
                          _buildTypeChip(
                            t,
                            isSelected: t == selectedType,
                            onTap: () => setState(() => selectedType = t),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'REASON / DESCRIPTION',
                      style: TextStyle(
                        color: _inkMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        fontFamily: appFontFamily,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Quarterly baseline refresh after CR-001',
                        hintStyle: TextStyle(
                          color: _inkMuted,
                          fontSize: 12.5,
                          fontFamily: appFontFamily,
                        ),
                        filled: true,
                        fillColor: _surfaceSubtle,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: _gold.withValues(alpha: 0.6),
                              width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Live preview
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.visibility_rounded,
                                  size: 12, color: _inkMuted),
                              const SizedBox(width: 6),
                              Text(
                                'PREVIEW — what gets locked',
                                style: TextStyle(
                                  color: _inkMuted,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                  fontFamily: appFontFamily,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _previewCell(
                                  label: 'Version',
                                  value:
                                      'v${widget.state.baselineHistory.length + 1}',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _previewCell(
                                  label: 'Type',
                                  value: selectedType.label,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _previewCell(
                                  label: 'BAC',
                                  value:
                                      '\$${(widget.state.totalOriginalBudget / 1000000).toStringAsFixed(2)}M',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _previewCell(
                                  label: 'WPs',
                                  value:
                                      '${widget.state.workPackages.length}',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                foregroundColor: _inkSecondary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  fontFamily: appFontFamily,
                ),
              ),
            ),
            _HoverBuilder(
              builder: (hovered) => AnimatedScale(
                scale: hovered ? 1.02 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: ElevatedButton(
                  onPressed: () {
                    widget.provider.createBaselineSnapshot(
                      selectedType,
                      reasonCtrl.text.trim().isEmpty
                          ? 'Manual baseline lock'
                          : reasonCtrl.text.trim(),
                    );
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    elevation: 0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: [_gold, _goldDeep],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _gold.withValues(alpha: 0.35),
                          blurRadius: hovered ? 14 : 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          'Lock Baseline',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: appFontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(
    BaselineType t, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = _typeColor(t);
    return _HoverBuilder(
      builder: (hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.1)
                    : (hovered ? _surfaceSubtle : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color : _border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? color : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? color
                            : _inkMuted.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 10)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t.label,
                    style: TextStyle(
                      color: isSelected ? color : _inkSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: appFontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewCell({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: _inkMuted,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              fontFamily: appFontFamily,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: _inkPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFamily: appFontFamily,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // ROLLBACK CONFIRMATION DIALOG
  // ──────────────────────────────────────────────────────────────────────
  void _confirmRollback(BaselineSnapshot b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        titlePadding: EdgeInsets.zero,
        title: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_danger, const Color(0xFFDC2626)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirm Rollback',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFamily: appFontFamily,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Restore project state to baseline v${b.version}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: 440,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _dangerSurface,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: _danger.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_rounded,
                          color: _danger, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This action restores the project state to baseline v${b.version}. Baseline history will be retained as audit records.',
                          style: TextStyle(
                            color: _inkPrimary,
                            fontSize: 12.5,
                            height: 1.5,
                            fontFamily: appFontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'IMPACT SUMMARY',
                  style: TextStyle(
                    color: _inkMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    fontFamily: appFontFamily,
                  ),
                ),
                const SizedBox(height: 10),
                _impactRow(
                  icon: Icons.account_tree_rounded,
                  label: 'Work packages',
                  value: '${b.workPackages.length} restored',
                  color: _violet,
                ),
                const SizedBox(height: 8),
                _impactRow(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Budget',
                  value:
                      '\$${(b.totalBudget / 1000000).toStringAsFixed(2)}M',
                  color: _amber,
                ),
                const SizedBox(height: 8),
                _impactRow(
                  icon: Icons.fingerprint_rounded,
                  label: 'Scope hash',
                  value: b.scopeHashOrDerived,
                  color: _indigo,
                ),
                const SizedBox(height: 8),
                _impactRow(
                  icon: Icons.history_rounded,
                  label: 'History',
                  value: 'Retained as audit record',
                  color: _emerald,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: _inkSecondary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          _HoverBuilder(
            builder: (hovered) => AnimatedScale(
              scale: hovered ? 1.02 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: ElevatedButton(
                onPressed: () {
                  widget.provider.rollbackToBaseline(b.version);
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  elevation: 0,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [_danger, const Color(0xFFDC2626)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _danger.withValues(alpha: 0.35),
                        blurRadius: hovered ? 14 : 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restore_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        'Roll back now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: appFontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _impactRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: _inkSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: _inkPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              fontFamily: appFontFamily,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DiffRow {
  final String field;
  final String a;
  final String b;
  _DiffRow(this.field, this.a, this.b);
  bool get changed => a != b;
}

// ──────────────────────────────────────────────────────────────────────
// _HoverBuilder — local hover state helper for animated micro-interactions.
// ──────────────────────────────────────────────────────────────────────
class _HoverBuilder extends StatefulWidget {
  const _HoverBuilder({required this.builder});
  final Widget Function(bool hovered) builder;
  @override
  State<_HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<_HoverBuilder> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(_hovered),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// TAB: Schedule Control
// ═════════════════════════════════════════════════════════════════════════

/// NEW _ScheduleControlTab implementation
/// Replaces the old class definition of _ScheduleControlTab

class _ScheduleControlTab extends StatefulWidget {
  final ProjectControlsState state;
  final ProjectControlsProvider provider;
  const _ScheduleControlTab({required this.state, required this.provider});

  @override
  State<_ScheduleControlTab> createState() => _ScheduleControlTabState();
}

class _ScheduleControlTabState extends State<_ScheduleControlTab> {
  String _filter = 'all'; // all | critical | delayed
  final Map<String, TextEditingController> _reasonControllers = {};

  @override
  void dispose() {
    for (final c in _reasonControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _reasonControllerFor(String wpId, String initial) {
    return _reasonControllers.putIfAbsent(
        wpId, () => TextEditingController(text: initial));
  }

  @override
  Widget build(BuildContext context) {
    final wps = widget.state.workPackages;
    final filtered = wps.where((wp) {
      final sv = _varianceFor(wp.id);
      if (_filter == 'critical') return sv.isCritical;
      if (_filter == 'delayed') return sv.varianceDays > 0;
      return true;
    }).toList();

    final avgSpi = wps.isEmpty
        ? 1.0
        : wps.fold<double>(0.0, (s, w) => s + w.spi) / wps.length;
    final onTrackCount = wps.where((w) => _varianceFor(w.id).varianceDays <= 0).length;

    return PcTabShell(
      eyebrow: 'Schedule Control',
      title: 'Schedule Control',
      subtitle:
          'Real-time variance, float, and SPI tracking across all work packages — including delay reasons and compression strategies.',
      icon: Icons.schedule_rounded,
      accent: PcPalette.sky,
      accentDeep: const Color(0xFF0284C7),
      accentSoft: const Color(0xFFE0F2FE),
      tint: const Color(0xFFF0F9FF),
      borderColor: const Color(0xFFBAE6FD),
      kpis: [
        PcKpiSpec(
          label: 'Work Packages',
          value: '${wps.length}',
          sub: '${onTrackCount} on track',
          icon: Icons.account_tree_rounded,
          accent: PcPalette.indigo,
        ),
        PcKpiSpec(
          label: 'Critical Path',
          value: '${widget.state.criticalPathCount}',
          sub: widget.state.criticalPathCount == 0
              ? 'No critical items'
              : 'On critical path',
          icon: Icons.flag_rounded,
          accent: PcPalette.danger,
        ),
        PcKpiSpec(
          label: 'Delayed',
          value: '${widget.state.delayedWorkPackagesCount}',
          sub: widget.state.delayedWorkPackagesCount == 0
              ? 'No delays'
              : 'Need attention',
          icon: Icons.error_outline_rounded,
          accent: PcPalette.amber,
        ),
        PcKpiSpec(
          label: 'Avg SPI',
          value: avgSpi.toStringAsFixed(2),
          sub: avgSpi >= 1.0
              ? 'Ahead of schedule'
              : 'Behind schedule',
          icon: Icons.speed_rounded,
          accent: avgSpi >= 1.0 ? PcPalette.emerald : PcPalette.danger,
        ),
      ],
      sections: [
        PcSectionCard(
          title: 'Work Package Schedule',
          subtitle:
              'Track planned vs. actual dates, variance, float, and SPI for each work package. Add delay reasons and compression strategies inline.',
          icon: Icons.table_chart_rounded,
          accent: PcPalette.sky,
          trailing: Wrap(
            spacing: 6,
            children: [
              _filterChip('All', 'all', wps.length),
              _filterChip('Critical Path', 'critical',
                  widget.state.criticalPathCount),
              _filterChip('Delayed', 'delayed',
                  widget.state.delayedWorkPackagesCount),
            ],
          ),
          child: filtered.isEmpty
              ? const PcEmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'No matching work packages',
                  subtitle:
                      'No work packages match the current filter. Try changing the filter above.',
                  accent: PcPalette.sky,
                )
              : MediaQuery.sizeOf(context).width > 900
                  ? _wideTable(filtered)
                  : Column(
                      children: filtered
                          .map((wp) => _narrowCard(wp))
                          .toList(growable: false),
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String key, int count) {
    final selected = _filter == key;
    return PcHoverBuilder(
      builder: (hovered) {
        return GestureDetector(
          onTap: () => setState(() => _filter = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? PcPalette.sky.withValues(alpha: 0.15)
                  : hovered
                      ? PcPalette.surfaceSubtle
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? PcPalette.sky.withValues(alpha: 0.5)
                    : PcPalette.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? PcPalette.sky
                        : PcPalette.inkSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: appFontFamily,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? PcPalette.sky.withValues(alpha: 0.2)
                        : PcPalette.surfaceSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected
                          ? PcPalette.sky
                          : PcPalette.inkMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: appFontFamily,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ScheduleVariance _varianceFor(String wpId) {
    return widget.state.scheduleVariances.firstWhere(
      (v) => v.workPackageId == wpId,
      orElse: () => ScheduleVariance(
          workPackageId: wpId,
          floatDays: 0,
          delayReason: '',
          compressionStrategy: CompressionStrategy.none),
    );
  }

  Widget _wideTable(List<WorkPackageControl> wps) {
    return Container(
      decoration: BoxDecoration(
        color: PcPalette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PcPalette.borderSubtle),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: PcPalette.surfaceSubtle,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Work Package',
                    style: TextStyle(
                      color: PcPalette.inkMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      fontFamily: appFontFamily,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Planned',
                      style: _tableHeaderStyle()),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Actual',
                      style: _tableHeaderStyle()),
                ),
                Expanded(
                  flex: 1,
                  child: Text('Var',
                      style: _tableHeaderStyle()),
                ),
                Expanded(
                  flex: 1,
                  child: Text('Float',
                      style: _tableHeaderStyle()),
                ),
                Expanded(
                  flex: 1,
                  child: Text('SPI',
                      style: _tableHeaderStyle()),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Delay reason / strategy',
                      style: _tableHeaderStyle()),
                ),
              ],
            ),
          ),
          ...wps.map((wp) => _wideRow(wp)),
        ],
      ),
    );
  }

  TextStyle _tableHeaderStyle() => TextStyle(
        color: PcPalette.inkMuted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        fontFamily: appFontFamily,
      );

  Widget _wideRow(WorkPackageControl wp) {
    final sv = _varianceFor(wp.id);
    final plannedStr = wp.plannedStart == null
        ? '—'
        : '${wp.plannedStart!.day}/${wp.plannedStart!.month}/${wp.plannedStart!.year} → ${wp.plannedFinish!.day}/${wp.plannedFinish!.month}/${wp.plannedFinish!.year}';
    final actualStr = wp.actualStart == null
        ? '(not started)'
        : (wp.actualFinish == null
            ? '${wp.actualStart!.day}/${wp.actualStart!.month}/${wp.actualStart!.year} → (in progress)'
            : '${wp.actualStart!.day}/${wp.actualStart!.month}/${wp.actualStart!.year} → ${wp.actualFinish!.day}/${wp.actualFinish!.month}/${wp.actualFinish!.year}');
    final variance = sv.varianceDays;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: PcPalette.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (sv.isCritical)
                  Container(
                    width: 4,
                    height: 32,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: PcPalette.danger,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wp.name,
                        style: TextStyle(
                          color: PcPalette.inkPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          fontFamily: appFontFamily,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        wp.wbsCode,
                        style: TextStyle(
                          color: PcPalette.inkMuted,
                          fontSize: 10.5,
                          fontFamily: appFontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              plannedStr,
              style: TextStyle(
                color: PcPalette.inkPrimary,
                fontSize: 11,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              actualStr,
              style: TextStyle(
                color: PcPalette.inkSecondary,
                fontSize: 11,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          Expanded(flex: 1, child: _varianceBadge(variance)),
          Expanded(
            flex: 1,
            child: Text(
              '${sv.floatDays.round()}d',
              style: TextStyle(
                color: sv.isCritical
                    ? PcPalette.danger
                    : PcPalette.inkSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              wp.spi.toStringAsFixed(2),
              style: TextStyle(
                color: wp.spi >= 1.0
                    ? PcPalette.emerald
                    : PcPalette.danger,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          Expanded(flex: 3, child: _delayStrategyCell(wp.id, sv)),
        ],
      ),
    );
  }

  Widget _varianceBadge(int days) {
    if (days == 0) {
      return Text(
        '0d',
        style: TextStyle(
          color: PcPalette.inkSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: appFontFamily,
        ),
      );
    }
    final late = days > 0;
    final color = late ? PcPalette.danger : PcPalette.emerald;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '${late ? '+' : ''}$days d',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: appFontFamily,
        ),
      ),
    );
  }

  Widget _delayStrategyCell(String wpId, ScheduleVariance sv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 30,
          child: TextField(
            controller: _reasonControllerFor(wpId, sv.delayReason),
            style: TextStyle(
              color: PcPalette.inkPrimary,
              fontSize: 11.5,
              fontFamily: appFontFamily,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              hintText: 'Add delay reason…',
              hintStyle: TextStyle(
                color: PcPalette.inkMuted,
                fontSize: 10.5,
                fontFamily: appFontFamily,
              ),
              filled: true,
              fillColor: PcPalette.surfaceSubtle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: PcPalette.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: PcPalette.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                    color: PcPalette.sky.withValues(alpha: 0.6)),
              ),
            ),
            onSubmitted: (val) =>
                widget.provider.setDelayReason(wpId, val.trim()),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: CompressionStrategy.values.map((s) {
            final selected = sv.compressionStrategy == s;
            return PcHoverBuilder(
              builder: (hovered) {
                return GestureDetector(
                  onTap: () =>
                      widget.provider.setCompressionStrategy(wpId, s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: selected
                          ? s.color.withValues(alpha: 0.18)
                          : hovered
                              ? PcPalette.surfaceSubtle
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: selected
                            ? s.color.withValues(alpha: 0.5)
                            : PcPalette.borderSubtle,
                      ),
                    ),
                    child: Text(
                      s.label,
                      style: TextStyle(
                        color: selected
                            ? s.color
                            : PcPalette.inkSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _narrowCard(WorkPackageControl wp) {
    final sv = _varianceFor(wp.id);
    final plannedStr = wp.plannedStart == null
        ? '—'
        : '${wp.plannedStart!.day}/${wp.plannedStart!.month} → ${wp.plannedFinish!.day}/${wp.plannedFinish!.month}';
    final actualStr = wp.actualStart == null
        ? '(not started)'
        : (wp.actualFinish == null
            ? '${wp.actualStart!.day}/${wp.actualStart!.month} → (in progress)'
            : '${wp.actualStart!.day}/${wp.actualStart!.month} → ${wp.actualFinish!.day}/${wp.actualFinish!.month}');
    return PcHoverBuilder(
      builder: (hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PcPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sv.isCritical
                  ? PcPalette.danger.withValues(alpha: hovered ? 0.6 : 0.4)
                  : hovered
                      ? PcPalette.sky.withValues(alpha: 0.4)
                      : PcPalette.border,
            ),
            boxShadow: [
              if (hovered)
                BoxShadow(
                  color: (sv.isCritical
                          ? PcPalette.danger
                          : PcPalette.sky)
                      .withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (sv.isCritical)
                    Container(
                      width: 4,
                      height: 22,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: PcPalette.danger,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      wp.name,
                      style: TextStyle(
                        color: PcPalette.inkPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: appFontFamily,
                      ),
                    ),
                  ),
                  if (sv.isCritical)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: PcPalette.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: PcPalette.danger
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'CRITICAL',
                        style: TextStyle(
                          color: PcPalette.danger,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          fontFamily: appFontFamily,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                wp.wbsCode,
                style: TextStyle(
                  color: PcPalette.inkMuted,
                  fontSize: 10.5,
                  fontFamily: appFontFamily,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _metaCell('Planned', plannedStr)),
                  const SizedBox(width: 6),
                  Expanded(child: _metaCell('Actual', actualStr)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _metaCell(
                      'Var',
                      '${sv.varianceDays >= 0 ? "+" : ""}${sv.varianceDays}d',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                      child:
                          _metaCell('Float', '${sv.floatDays.round()}d')),
                  const SizedBox(width: 6),
                  Expanded(
                      child:
                          _metaCell('SPI', wp.spi.toStringAsFixed(2))),
                ],
              ),
              const SizedBox(height: 12),
              _delayStrategyCell(wp.id, sv),
            ],
          ),
        );
      },
    );
  }

  Widget _metaCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: PcPalette.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: PcPalette.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: PcPalette.inkMuted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              fontFamily: appFontFamily,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: PcPalette.inkPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              fontFamily: appFontFamily,
            ),
          ),
        ],
      ),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════
// TAB: Risk & Issues
// ═════════════════════════════════════════════════════════════════════════

/// NEW _RiskIssuesTab implementation
/// Replaces the old class definition of _RiskIssuesTab

class _RiskIssuesTab extends StatefulWidget {
  final ProjectControlsState state;
  final ProjectControlsProvider provider;
  const _RiskIssuesTab({required this.state, required this.provider});

  @override
  State<_RiskIssuesTab> createState() => _RiskIssuesTabState();
}

class _RiskIssuesTabState extends State<_RiskIssuesTab> {
  String _severityFilter = 'all'; // all | low | medium | high | critical
  String _typeFilter = 'all'; // all | risks | issues
  String? _ownerFilter;
  final Map<String, TextEditingController> _mitigationControllers = {};

  @override
  void dispose() {
    for (final c in _mitigationControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _mitigationControllerFor(String id, String initial) {
    return _mitigationControllers.putIfAbsent(
        id, () => TextEditingController(text: initial));
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.state.risksAndIssues;
    final owners = <String>{for (final r in items) r.owner}.toList()..sort();
    final filtered = items.where((r) {
      if (_typeFilter == 'risks' && r.isIssue) return false;
      if (_typeFilter == 'issues' && !r.isIssue) return false;
      if (_ownerFilter != null && r.owner != _ownerFilter) return false;
      if (_severityFilter != 'all' &&
          r.severityLabel.toLowerCase() != _severityFilter) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.severity.compareTo(a.severity));

    final criticalCount = widget.state.criticalRisksCount;
    final mitigatedCount = items.where((r) => r.status != RiskStatus.open).length;
    final avgSeverity = items.isEmpty
        ? 0.0
        : items.fold<double>(0.0, (s, r) => s + r.severity) / items.length;

    return PcTabShell(
      eyebrow: 'Risk & Issues Register',
      title: 'Risk & Issues',
      subtitle:
          'Track and mitigate risks and issues — heatmap, weekly trend, severity-filtered register, and per-item response plans.',
      icon: Icons.warning_amber_rounded,
      accent: PcPalette.rose,
      accentDeep: const Color(0xFFE11D48),
      accentSoft: const Color(0xFFFFE4E6),
      tint: const Color(0xFFFFF1F2),
      borderColor: const Color(0xFFFECDD3),
      kpis: [
        PcKpiSpec(
          label: 'Open Risks',
          value: '${widget.state.openRisks.length}',
          sub: items.isEmpty ? 'No risks registered' : 'Across all owners',
          icon: Icons.warning_amber_rounded,
          accent: PcPalette.amber,
        ),
        PcKpiSpec(
          label: 'Open Issues',
          value: '${widget.state.openIssues.length}',
          sub: 'Active issues',
          icon: Icons.bug_report_outlined,
          accent: PcPalette.violet,
        ),
        PcKpiSpec(
          label: 'Critical',
          value: '$criticalCount',
          sub: criticalCount == 0 ? 'No critical items' : 'Need immediate attention',
          icon: Icons.priority_high_rounded,
          accent: PcPalette.danger,
        ),
        PcKpiSpec(
          label: 'Avg Severity',
          value: avgSeverity.toStringAsFixed(1),
          sub: mitigatedCount == 0
              ? 'None mitigated yet'
              : '$mitigatedCount mitigated',
          icon: Icons.analytics_outlined,
          accent: PcPalette.indigo,
        ),
      ],
      sections: [
        // Heatmap + trend
        LayoutBuilder(
          builder: (context, c) {
            final stacked = c.maxWidth < 760;
            if (stacked) {
              return Column(
                children: [
                  _heatmapCard(items),
                  const SizedBox(height: 14),
                  _trendCard(items),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _heatmapCard(items)),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: _trendCard(items)),
              ],
            );
          },
        ),

        // Register
        PcSectionCard(
          title: 'Risk & Issues Register',
          subtitle:
              'Filterable list of all risks and issues with mitigation plans, owner, and status workflow.',
          icon: Icons.list_alt_rounded,
          accent: PcPalette.rose,
          trailing: owners.isEmpty
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: PcPalette.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: PcPalette.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _ownerFilter,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      hint: Text(
                        'Owner: All',
                        style: TextStyle(
                          color: PcPalette.inkSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          fontFamily: appFontFamily,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All owners'),
                        ),
                        ...owners.map((o) => DropdownMenuItem(
                              value: o,
                              child: Text(o),
                            )),
                      ],
                      onChanged: (v) => setState(() => _ownerFilter = v),
                    ),
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _typeChip('All', 'all'),
                  _typeChip('Risks only', 'risks'),
                  _typeChip('Issues only', 'issues'),
                  const SizedBox(width: 8, height: 4),
                  ...['low', 'medium', 'high', 'critical']
                      .map((s) => _severityChip(_capitalize(s), s)),
                ],
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                const PcEmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'No items match the current filters',
                  subtitle:
                      'Try adjusting the type, severity, or owner filter to see more items.',
                  accent: PcPalette.rose,
                )
              else
                Column(
                  children: filtered
                      .map((r) => _riskCard(r))
                      .toList(growable: false),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Widget _typeChip(String label, String key) {
    final selected = _typeFilter == key;
    return PcHoverBuilder(
      builder: (hovered) {
        return GestureDetector(
          onTap: () => setState(() => _typeFilter = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(
                horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? PcPalette.rose.withValues(alpha: 0.15)
                  : hovered
                      ? PcPalette.surfaceSubtle
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? PcPalette.rose.withValues(alpha: 0.5)
                    : PcPalette.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? PcPalette.rose
                    : PcPalette.inkSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                fontFamily: appFontFamily,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _severityChip(String label, String key) {
    final selected = _severityFilter == key;
    final color = _severityColorFor(key);
    return PcHoverBuilder(
      builder: (hovered) {
        return GestureDetector(
          onTap: () => setState(() => _severityFilter = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.15)
                  : hovered
                      ? PcPalette.surfaceSubtle
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.5)
                    : PcPalette.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? color : PcPalette.inkSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: appFontFamily,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _severityColorFor(String key) {
    switch (key) {
      case 'low':
        return PcPalette.emerald;
      case 'medium':
        return PcPalette.amber;
      case 'high':
        return const Color(0xFFF97316);
      case 'critical':
        return PcPalette.danger;
      default:
        return PcPalette.inkSecondary;
    }
  }

  Widget _heatmapCard(List<RiskItem> items) {
    return PcSectionCard(
      title: 'Risk Heatmap (P × I)',
      subtitle:
          'Each cell is colored green→yellow→red by severity. Dots show open risks/issues plotted at their P×I coordinates.',
      icon: Icons.grid_view_rounded,
      accent: PcPalette.rose,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: AspectRatio(
        aspectRatio: 1.1,
        child: CustomPaint(
          painter: _RiskHeatmapPainter(risks: items),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _trendCard(List<RiskItem> items) {
    return PcSectionCard(
      title: 'Weekly Trend',
      subtitle: 'Open risks/issues per week (last 6 weeks)',
      icon: Icons.show_chart_rounded,
      accent: PcPalette.indigo,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        children: [
          SizedBox(
            height: 110,
            child: CustomPaint(
              painter: _RiskTrendPainter(items: items),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _legendDot(PcPalette.danger, 'Open'),
              const SizedBox(width: 14),
              _legendDot(PcPalette.emerald, 'Closed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: PcPalette.inkSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: appFontFamily,
          ),
        ),
      ],
    );
  }

  Widget _riskCard(RiskItem r) {
    final color = r.severityColor;
    return PcHoverBuilder(
      builder: (hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: PcPalette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hovered
                  ? color.withValues(alpha: 0.5)
                  : color.withValues(alpha: 0.28),
            ),
            boxShadow: [
              if (hovered)
                BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                // Header with tinted background
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    border: Border(
                      bottom: BorderSide(
                        color: color.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withValues(alpha: 0.95),
                              color.withValues(alpha: 0.7),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          r.isIssue
                              ? Icons.bug_report_rounded
                              : Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.description,
                              style: TextStyle(
                                color: PcPalette.inkPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                fontFamily: appFontFamily,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${r.id} • ${r.isIssue ? "Issue" : "Risk"} • Owner: ${r.owner}',
                              style: TextStyle(
                                color: PcPalette.inkSecondary,
                                fontSize: 11,
                                fontFamily: appFontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: color.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              '${r.severityLabel} (${r.severity})',
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                fontFamily: appFontFamily,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: r.status.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: r.status.color
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              r.status.label,
                              style: TextStyle(
                                color: r.status.color,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                fontFamily: appFontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _metaCell('Probability', '${r.probability}/5'),
                          const SizedBox(width: 6),
                          _metaCell('Impact', '${r.impact}/5'),
                          const SizedBox(width: 6),
                          _metaCell(
                              'Type', r.isIssue ? 'Issue' : 'Risk'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'MITIGATION / RESPONSE PLAN',
                        style: TextStyle(
                          color: PcPalette.inkMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          fontFamily: appFontFamily,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller:
                            _mitigationControllerFor(r.id, r.mitigation),
                        maxLines: 2,
                        style: TextStyle(
                          color: PcPalette.inkPrimary,
                          fontSize: 12,
                          fontFamily: appFontFamily,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.all(10),
                          hintText: 'Describe the mitigation/response plan…',
                          hintStyle: TextStyle(
                            color: PcPalette.inkMuted,
                            fontSize: 11,
                            fontFamily: appFontFamily,
                          ),
                          filled: true,
                          fillColor: PcPalette.surfaceSubtle,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: PcPalette.borderSubtle),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: PcPalette.borderSubtle),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: color.withValues(alpha: 0.5)),
                          ),
                        ),
                        onSubmitted: (val) => widget.provider.updateRiskItem(
                            r.id, r.copyWith(mitigation: val.trim())),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final s in RiskStatus.values)
                                  PcHoverBuilder(
                                    builder: (hovered) {
                                      final sel = r.status == s;
                                      return GestureDetector(
                                        onTap: () => widget.provider
                                            .updateRiskItem(
                                                r.id, r.copyWith(status: s)),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: sel
                                                ? s.color
                                                    .withValues(alpha: 0.18)
                                                : hovered
                                                    ? PcPalette.surfaceSubtle
                                                    : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: sel
                                                  ? s.color.withValues(
                                                      alpha: 0.5)
                                                  : PcPalette.borderSubtle,
                                            ),
                                          ),
                                          child: Text(
                                            s.label,
                                            style: TextStyle(
                                              color: sel
                                                  ? s.color
                                                  : PcPalette.inkSecondary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: appFontFamily,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                          if (r.status != RiskStatus.closed)
                            TextButton.icon(
                              onPressed: () =>
                                  widget.provider.closeRiskItem(r.id),
                              icon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 14),
                              label: const Text('Close'),
                              style: TextButton.styleFrom(
                                foregroundColor: PcPalette.emerald,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                minimumSize: const Size(0, 0),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
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

  Widget _metaCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: PcPalette.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: PcPalette.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: PcPalette.inkMuted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              fontFamily: appFontFamily,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: PcPalette.inkPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              fontFamily: appFontFamily,
            ),
          ),
        ],
      ),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════
// TAB: Resource Control
// ═════════════════════════════════════════════════════════════════════════

/// NEW _ResourceControlTab implementation
/// Replaces the old class definition of _ResourceControlTab

class _ResourceControlTab extends StatefulWidget {
  final ProjectControlsState state;
  const _ResourceControlTab({required this.state});

  @override
  State<_ResourceControlTab> createState() => _ResourceControlTabState();
}

class _ResourceControlTabState extends State<_ResourceControlTab> {
  double _adjustment = 0; // -50% to +50%
  double _capacityBoost = 0; // -10 to +10 h/wk capacity delta

  @override
  Widget build(BuildContext context) {
    final allocations = widget.state.resourceAllocations;
    final multiplier = 1.0 + (_adjustment / 100.0);
    final projectedAllocations = allocations
        .map((ra) => ResourceAllocation(
              resourceName: ra.resourceName,
              discipline: ra.discipline,
              weeklyHours: ra.weeklyHours
                  .map((h) => (h * multiplier).roundToDouble())
                  .toList(),
              capacityHoursPerWeek: ra.capacityHoursPerWeek + _capacityBoost,
            ))
        .toList();

    // Aggregate KPIs
    final avgUtil = projectedAllocations.isEmpty
        ? 0.0
        : projectedAllocations.fold<double>(0.0, (s, r) => s + r.utilizationPct) /
            projectedAllocations.length;
    final peakUtil = projectedAllocations.isEmpty
        ? 0.0
        : projectedAllocations
            .map((r) => r.peakWeekUtilizationPct)
            .reduce((a, b) => a > b ? a : b);
    final overloaded = projectedAllocations
        .where((r) => r.peakWeekUtilizationPct > 100)
        .length;

    return PcTabShell(
      eyebrow: 'Resource Control',
      title: 'Resource Control',
      subtitle:
          'Weekly allocation histogram, what-if scenarios, and per-resource utilization across the 12-week rolling window.',
      icon: Icons.people_alt_rounded,
      accent: PcPalette.violet,
      accentDeep: const Color(0xFF7C3AED),
      accentSoft: const Color(0xFFEDE9FE),
      tint: const Color(0xFFF5F3FF),
      borderColor: const Color(0xFFDDD6FE),
      kpis: [
        PcKpiSpec(
          label: 'Resources',
          value: '${allocations.length}',
          sub: 'Across ${ResourceDiscipline.values.length} disciplines',
          icon: Icons.people_outline_rounded,
          accent: PcPalette.violet,
        ),
        PcKpiSpec(
          label: 'Avg Utilization',
          value: '${avgUtil.toStringAsFixed(0)}%',
          sub: avgUtil < 80
              ? 'Healthy capacity'
              : avgUtil > 100
                  ? 'Over-allocated'
                  : 'Near capacity',
          icon: Icons.speed_rounded,
          accent:
              avgUtil < 80 ? PcPalette.emerald : avgUtil > 100 ? PcPalette.danger : PcPalette.amber,
        ),
        PcKpiSpec(
          label: 'Peak Utilization',
          value: '${peakUtil.toStringAsFixed(0)}%',
          sub: 'Highest single-week load',
          icon: Icons.trending_up_rounded,
          accent: peakUtil > 100 ? PcPalette.danger : PcPalette.amber,
        ),
        PcKpiSpec(
          label: 'Overloaded',
          value: '$overloaded',
          sub: overloaded == 0
              ? 'No over-allocations'
              : 'Resource(s) above 100%',
          icon: Icons.warning_amber_rounded,
          accent: overloaded == 0 ? PcPalette.emerald : PcPalette.danger,
        ),
      ],
      sections: [
        // Histogram card
        PcSectionCard(
          title: 'Weekly Allocation Histogram',
          subtitle:
              'Stacked bar chart of weekly hours per discipline across the 12-week window, with the current what-if projection applied.',
          icon: Icons.bar_chart_rounded,
          accent: PcPalette.violet,
          trailing: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: PcPalette.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: PcPalette.amber.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Projection: ${_adjustment >= 0 ? "+" : ""}${_adjustment.round()}% • Capacity ${_capacityBoost >= 0 ? "+" : ""}${_capacityBoost.toStringAsFixed(1)}h/wk',
              style: TextStyle(
                color: PcPalette.amber,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 240,
                child: CustomPaint(
                  painter: _ResourceHistogramPainter(
                      allocations: projectedAllocations),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: ResourceDiscipline.values
                    .map((d) => _legendDot(d.color, d.label))
                    .toList(),
              ),
            ],
          ),
        ),

        // What-If Analysis
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFF8E6),
                const Color(0xFFFFF4CC),
              ],
            ),
            border: Border.all(
              color: PcPalette.gold.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: PcPalette.amber.withValues(alpha: 0.1),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            PcPalette.amber.withValues(alpha: 0.95),
                            const Color(0xFFD97706),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PcPalette.amber.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.science_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'What-If Analysis',
                            style: TextStyle(
                              color: PcPalette.inkPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.1,
                              fontFamily: appFontFamily,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Test allocation or capacity changes. The histogram and utilization cards below update live.',
                            style: TextStyle(
                              color: PcPalette.inkSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              fontFamily: appFontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _adjustment = 0;
                        _capacityBoost = 0;
                      }),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset'),
                      style: TextButton.styleFrom(
                        foregroundColor: PcPalette.inkSecondary,
                        backgroundColor: Colors.white.withValues(alpha: 0.6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: PcPalette.border.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, c) {
                    final stacked = c.maxWidth < 640;
                    final children = <Widget>[
                      _sliderCard(
                        label: 'Allocation adjustment',
                        value: _adjustment,
                        min: -50,
                        max: 50,
                        divisions: 20,
                        suffix: '%',
                        displayValue:
                            '${_adjustment >= 0 ? "+" : ""}${_adjustment.round()}%',
                        onChanged: (v) => setState(() => _adjustment = v),
                      ),
                      _sliderCard(
                        label: 'Capacity delta',
                        value: _capacityBoost,
                        min: -10,
                        max: 10,
                        divisions: 20,
                        suffix: ' h/wk',
                        displayValue:
                            '${_capacityBoost >= 0 ? "+" : ""}${_capacityBoost.toStringAsFixed(1)} h/wk',
                        onChanged: (v) =>
                            setState(() => _capacityBoost = v),
                      ),
                    ];
                    if (stacked) {
                      return Column(
                        children: children
                            .expand((w) => [w, const SizedBox(height: 14)])
                            .toList()
                          ..removeLast(),
                      );
                    }
                    return Row(
                      children: children
                          .expand((w) => [
                                Expanded(child: w),
                                const SizedBox(width: 14)
                              ])
                          .toList()
                        ..removeLast(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Utilization per resource
        PcSectionCard(
          title: 'Utilization Per Resource',
          subtitle:
              'Projected utilization, average weekly hours, peak load, and total allocation per resource.',
          icon: Icons.person_outline_rounded,
          accent: PcPalette.violet,
          trailing: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: PcPalette.violet.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${projectedAllocations.length} resource${projectedAllocations.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: PcPalette.violet,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          child: projectedAllocations.isEmpty
              ? const PcEmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'No resources allocated',
                  subtitle:
                      'Resource allocations from your staffing plan will appear here once defined.',
                  accent: PcPalette.violet,
                )
              : Column(
                  children: projectedAllocations
                      .map((ra) => _utilizationCard(ra))
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }

  Widget _sliderCard({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    final isPositive = value > 0;
    final isNegative = value < 0;
    final color = isPositive
        ? PcPalette.emerald
        : isNegative
            ? PcPalette.danger
            : PcPalette.inkSecondary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PcPalette.gold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: PcPalette.inkPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  fontFamily: appFontFamily,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  displayValue,
                  style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: appFontFamily,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: PcPalette.amber,
              inactiveTrackColor: PcPalette.borderSubtle,
              thumbColor: PcPalette.amber,
              overlayColor: PcPalette.amber.withValues(alpha: 0.2),
              trackHeight: 4,
              valueIndicatorColor: PcPalette.amber,
              valueIndicatorTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: appFontFamily,
              ),
              showValueIndicator: ShowValueIndicator.always,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: displayValue,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: PcPalette.inkSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            fontFamily: appFontFamily,
          ),
        ),
      ],
    );
  }

  Widget _utilizationCard(ResourceAllocation ra) {
    final util = ra.utilizationPct;
    final peak = ra.peakWeekUtilizationPct;
    final color = util < 80
        ? PcPalette.emerald
        : util > 110
            ? PcPalette.danger
            : PcPalette.amber;
    final peakColor = peak > 110
        ? PcPalette.danger
        : peak > 90
            ? PcPalette.amber
            : PcPalette.emerald;
    final peakWeek = ra.weeklyHours.isEmpty
        ? 0.0
        : ra.weeklyHours.reduce((a, b) => a > b ? a : b);

    return PcHoverBuilder(
      builder: (hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PcPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hovered
                  ? color.withValues(alpha: 0.45)
                  : color.withValues(alpha: 0.25),
            ),
            boxShadow: [
              if (hovered)
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ra.discipline.color.withValues(alpha: 0.95),
                          ra.discipline.color.withValues(alpha: 0.65),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ra.discipline.color.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ra.resourceName,
                          style: TextStyle(
                            color: PcPalette.inkPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            fontFamily: appFontFamily,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ra.discipline.label} • ${ra.capacityHoursPerWeek.round()}h capacity/wk',
                          style: TextStyle(
                            color: PcPalette.inkSecondary,
                            fontSize: 11.5,
                            fontFamily: appFontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: color.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          util > 110
                              ? Icons.priority_high_rounded
                              : util > 80
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_rounded,
                          size: 12,
                          color: color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${util.toStringAsFixed(0)}% util',
                          style: TextStyle(
                            color: color,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            fontFamily: appFontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Utilization bar
              Row(
                children: [
                  Text(
                    'UTIL',
                    style: TextStyle(
                      color: PcPalette.inkMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      fontFamily: appFontFamily,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (util / 100).clamp(0.0, 1.5),
                        backgroundColor: PcPalette.surfaceSubtle,
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 7,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _miniStat(
                      'Avg', '${ra.avgWeekly.toStringAsFixed(1)}h/wk'),
                  const SizedBox(width: 8),
                  _miniStat(
                      'Peak', '$peakWeek h (${peak.toStringAsFixed(0)}%)',
                      color: peakColor),
                  const SizedBox(width: 8),
                  _miniStat('Total', '${ra.totalAllocated.round()}h'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniStat(String label, String value, {Color? color}) {
    final c = color ?? PcPalette.inkSecondary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: PcPalette.surfaceSubtle,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: PcPalette.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: PcPalette.inkMuted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                fontFamily: appFontFamily,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: c,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                fontFamily: appFontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════
// TAB: Reporting & Audit
// ═════════════════════════════════════════════════════════════════════════

/// NEW _ReportingAuditTab implementation
/// Replaces the old class definition of _ReportingAuditTab

class _ReportingAuditTab extends StatefulWidget {
  final ProjectControlsState state;
  final ProjectControlsProvider provider;
  const _ReportingAuditTab({required this.state, required this.provider});

  @override
  State<_ReportingAuditTab> createState() => _ReportingAuditTabState();
}

class _ReportingAuditTabState extends State<_ReportingAuditTab> {
  String? _actorFilter;
  String _actionSearch = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  Widget build(BuildContext context) {
    final reports = widget.state.reports;
    final actors = <String>{
      for (final a in widget.state.auditTrail) a.user
    }.toList()
      ..sort();

    final filteredAudit = widget.state.auditTrail.where((a) {
      if (_actorFilter != null && a.user != _actorFilter) return false;
      if (_actionSearch.trim().isNotEmpty &&
          !a.field.toLowerCase().contains(_actionSearch.toLowerCase()) &&
          !(a.reason?.toLowerCase().contains(_actionSearch.toLowerCase()) ?? false)) {
        return false;
      }
      if (_fromDate != null && a.timestamp.isBefore(_fromDate!)) return false;
      if (_toDate != null && a.timestamp.isAfter(_toDate!)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final activeFilterCount = [
      _actorFilter != null,
      _actionSearch.trim().isNotEmpty,
      _fromDate != null,
      _toDate != null,
    ].where((b) => b).length;

    return PcTabShell(
      eyebrow: 'Reporting & Audit',
      title: 'Reporting & Audit',
      subtitle:
          'Generate stakeholder reports and trace every change through the auditable trail of edits.',
      icon: Icons.assessment_rounded,
      accent: PcPalette.indigo,
      accentDeep: const Color(0xFF4F46E5),
      accentSoft: const Color(0xFFE0E7FF),
      tint: const Color(0xFFEEF2FF),
      borderColor: const Color(0xFFC7D2FE),
      action: PcHeroAction(
        label: 'Generate Report',
        icon: Icons.picture_as_pdf_outlined,
        onTap: () => _showGenerateDialog(context),
      ),
      kpis: [
        PcKpiSpec(
          label: 'Reports Generated',
          value: '${reports.length}',
          sub: reports.isEmpty ? 'No reports yet' : 'Available to download',
          icon: Icons.description_outlined,
          accent: PcPalette.indigo,
        ),
        PcKpiSpec(
          label: 'Audit Entries',
          value: '${widget.state.auditTrail.length}',
          sub: 'Total recorded actions',
          icon: Icons.history_rounded,
          accent: PcPalette.violet,
        ),
        PcKpiSpec(
          label: 'Showing',
          value: '${filteredAudit.length}',
          sub: filteredAudit.length == widget.state.auditTrail.length
              ? 'All entries'
              : 'Filtered view',
          icon: Icons.filter_list_rounded,
          accent: PcPalette.sky,
        ),
        PcKpiSpec(
          label: 'Active Filters',
          value: '$activeFilterCount',
          sub: activeFilterCount == 0
              ? 'No filters applied'
              : 'Filtering audit trail',
          icon: Icons.tune_rounded,
          accent: activeFilterCount == 0
              ? PcPalette.inkMuted
              : PcPalette.amber,
        ),
      ],
      sections: [
        // Generated Reports
        PcSectionCard(
          title: 'Generated Reports',
          subtitle:
              'Stakeholder-ready reports covering cost variance, schedule, risk, and EVM metrics. Click download to export.',
          icon: Icons.picture_as_pdf_outlined,
          accent: PcPalette.indigo,
          trailing: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: PcPalette.indigo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${reports.length} report${reports.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: PcPalette.indigo,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: appFontFamily,
              ),
            ),
          ),
          child: reports.isEmpty
              ? const PcEmptyState(
                  icon: Icons.description_outlined,
                  title: 'No reports generated yet',
                  subtitle:
                      'Click "Generate Report" above to create your first stakeholder report. Reports will appear here for download.',
                  accent: PcPalette.indigo,
                )
              : Column(
                  children: reports.reversed
                      .map((r) => _reportCard(r))
                      .toList(growable: false),
                ),
        ),

        // Audit Trail
        PcSectionCard(
          title: 'Audit Trail',
          subtitle:
              'Chronological record of every change made to project controls data — who, when, what field, and the old → new value.',
          icon: Icons.history_rounded,
          accent: PcPalette.violet,
          trailing: Text(
            '${filteredAudit.length} of ${widget.state.auditTrail.length} entries',
            style: TextStyle(
              color: PcPalette.inkSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              fontFamily: appFontFamily,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filters
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: PcPalette.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PcPalette.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        final stacked = c.maxWidth < 760;
                        final row1 = <Widget>[
                          Expanded(
                            child: _actorDropdown(actors),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _searchField(),
                          ),
                        ];
                        final row2 = <Widget>[
                          Expanded(
                            child: _datePickField(
                                'From date', _fromDate,
                                (d) => setState(() => _fromDate = d)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _datePickField(
                                'To date', _toDate,
                                (d) => setState(() => _toDate = d)),
                          ),
                          if (_fromDate != null || _toDate != null) ...[
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _fromDate = null;
                                _toDate = null;
                              }),
                              icon: const Icon(Icons.clear, size: 14),
                              label: const Text('Clear'),
                              style: TextButton.styleFrom(
                                foregroundColor: PcPalette.danger,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                minimumSize: const Size(0, 0),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ];
                        if (stacked) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: row1),
                              const SizedBox(height: 8),
                              Row(children: row2),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: row1),
                            const SizedBox(height: 8),
                            Row(children: row2),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (filteredAudit.isEmpty)
                const PcEmptyState(
                  icon: Icons.history_toggle_off,
                  title: 'No audit entries match the current filters',
                  subtitle:
                      'Try clearing some filters to see more entries, or adjust the date range and search terms.',
                  accent: PcPalette.violet,
                )
              else
                Column(
                  children: filteredAudit
                      .map((a) => _auditEntryCard(a))
                      .toList(growable: false),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actorDropdown(List<String> actors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: PcPalette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PcPalette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _actorFilter,
          isExpanded: true,
          hint: Row(
            children: [
              Icon(Icons.person_outline,
                  size: 14, color: PcPalette.inkMuted),
              const SizedBox(width: 6),
              Text(
                'All actors',
                style: TextStyle(
                  color: PcPalette.inkSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: appFontFamily,
                ),
              ),
            ],
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All actors'),
            ),
            ...actors.map((a) => DropdownMenuItem(value: a, child: Text(a))),
          ],
          onChanged: (v) => setState(() => _actorFilter = v),
        ),
      ),
    );
  }

  Widget _searchField() {
    return Container(
      decoration: BoxDecoration(
        color: PcPalette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PcPalette.border),
      ),
      child: TextField(
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search action / reason…',
          hintStyle: TextStyle(
            color: PcPalette.inkMuted,
            fontSize: 11.5,
            fontFamily: appFontFamily,
          ),
          prefixIcon: Icon(Icons.search,
              size: 16, color: PcPalette.inkMuted),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 10),
          filled: true,
          fillColor: PcPalette.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: PcPalette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: PcPalette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: PcPalette.indigo.withValues(alpha: 0.5)),
          ),
        ),
        style: TextStyle(
          fontSize: 12,
          color: PcPalette.inkPrimary,
          fontFamily: appFontFamily,
        ),
        onChanged: (v) => setState(() => _actionSearch = v),
      ),
    );
  }

  Widget _datePickField(
      String label, DateTime? value, ValueChanged<DateTime?> onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: PcPalette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PcPalette.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 14, color: PcPalette.inkMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value == null
                    ? label
                    : '${value.day}/${value.month}/${value.year}',
                style: TextStyle(
                  color: value == null
                      ? PcPalette.inkMuted
                      : PcPalette.inkPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: appFontFamily,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(ReportRecord r) {
    return PcHoverBuilder(
      builder: (hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PcPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hovered
                  ? PcPalette.indigo.withValues(alpha: 0.4)
                  : PcPalette.border,
            ),
            boxShadow: [
              if (hovered)
                BoxShadow(
                  color: PcPalette.indigo.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      PcPalette.amber.withValues(alpha: 0.95),
                      const Color(0xFFD97706),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PcPalette.amber.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(r.type.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.type.label,
                            style: TextStyle(
                              color: PcPalette.inkPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: appFontFamily,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${r.generatedAt.day}/${r.generatedAt.month}/${r.generatedAt.year}',
                          style: TextStyle(
                            color: PcPalette.inkSecondary,
                            fontSize: 11,
                            fontFamily: appFontFamily,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${r.id} • by ${r.generatedBy} • range: ${r.dateRangeStart.day}/${r.dateRangeStart.month}–${r.dateRangeEnd.day}/${r.dateRangeEnd.month}/${r.dateRangeEnd.year}',
                      style: TextStyle(
                        color: PcPalette.inkSecondary,
                        fontSize: 10.5,
                        fontFamily: appFontFamily,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: PcPalette.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: PcPalette.borderSubtle),
                      ),
                      child: Text(
                        r.summaryText,
                        style: TextStyle(
                          color: PcPalette.inkPrimary,
                          fontSize: 11.5,
                          height: 1.45,
                          fontFamily: appFontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PcHoverBuilder(
                builder: (btnHovered) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: btnHovered
                          ? PcPalette.indigo.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () => _downloadReport(r),
                      icon: Icon(Icons.download_rounded,
                          color: PcPalette.indigo),
                      tooltip: 'Download',
                      splashRadius: 18,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _auditEntryCard(AuditEntry a) {
    return PcHoverBuilder(
      builder: (hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PcPalette.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hovered
                  ? PcPalette.violet.withValues(alpha: 0.35)
                  : PcPalette.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline dot + connector
              Container(
                margin: const EdgeInsets.only(top: 4),
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: PcPalette.violet,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: PcPalette.violet.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            PcPalette.violet.withValues(alpha: 0.4),
                            PcPalette.borderSubtle,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: PcPalette.indigo.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: PcPalette.indigo
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            a.field,
                            style: TextStyle(
                              color: PcPalette.indigo,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              fontFamily: appFontFamily,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${a.timestamp.day}/${a.timestamp.month}/${a.timestamp.year} ${a.timestamp.hour.toString().padLeft(2, '0')}:${a.timestamp.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: PcPalette.inkSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            fontFamily: appFontFamily,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a.reason ?? '(no reason recorded)',
                      style: TextStyle(
                        color: PcPalette.inkPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        fontFamily: appFontFamily,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'by ${a.user}',
                          style: TextStyle(
                            color: PcPalette.inkSecondary,
                            fontSize: 10.5,
                            fontFamily: appFontFamily,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (a.previousValue.isNotEmpty ||
                            a.newValue.isNotEmpty)
                          Expanded(
                            child: Text(
                              '${a.previousValue.isEmpty ? "—" : a.previousValue} → ${a.newValue.isEmpty ? "—" : a.newValue}',
                              style: TextStyle(
                                color: PcPalette.inkMuted,
                                fontSize: 10.5,
                                fontStyle: FontStyle.italic,
                                fontFamily: appFontFamily,
                              ),
                              overflow: TextOverflow.ellipsis,
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
      },
    );
  }

  void _showGenerateDialog(BuildContext context) {
    ReportType selectedType = ReportType.costVariance;
    DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime endDate = DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [PcPalette.gold, PcPalette.goldDeep],
                  ),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Generate Report'),
            ],
          ),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Type',
                  style: TextStyle(
                    color: PcPalette.inkSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    fontFamily: appFontFamily,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: PcPalette.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: PcPalette.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ReportType>(
                      value: selectedType,
                      isExpanded: true,
                      items: ReportType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Row(
                                  children: [
                                    Icon(t.icon,
                                        size: 16, color: PcPalette.amber),
                                    const SizedBox(width: 10),
                                    Text(t.label),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => selectedType = v);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Date Range',
                  style: TextStyle(
                    color: PcPalette.inkSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    fontFamily: appFontFamily,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => startDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: PcPalette.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: PcPalette.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 14,
                                  color: PcPalette.inkMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'From: ${startDate.day}/${startDate.month}/${startDate.year}',
                                  style: TextStyle(
                                    color: PcPalette.inkPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: appFontFamily,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: endDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => endDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: PcPalette.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: PcPalette.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 14,
                                  color: PcPalette.inkMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'To: ${endDate.day}/${endDate.month}/${endDate.year}',
                                  style: TextStyle(
                                    color: PcPalette.inkPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: appFontFamily,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                foregroundColor: PcPalette.inkSecondary,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                widget.provider
                    .generateReport(selectedType, startDate, endDate);
                Navigator.of(ctx).pop();
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Generate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PcPalette.gold,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _downloadReport(ReportRecord r) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.download_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Downloading ${r.type.label} (${r.dateRangeStart.day}/${r.dateRangeStart.month}–${r.dateRangeEnd.day}/${r.dateRangeEnd.month})…',
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: PcPalette.indigo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════
// Custom Painters
// ═════════════════════════════════════════════════════════════════════════

/// 5×5 risk heatmap with color interpolation green → yellow → red,
/// plotting open risks/issues as dots on the grid.
class _RiskHeatmapPainter extends CustomPainter {
  final List<RiskItem> risks;
  _RiskHeatmapPainter({required this.risks});

  @override
  void paint(Canvas canvas, Size size) {
    const labelSpace = 22.0;
    final gridSize = size.width - labelSpace;
    final cellSize = gridSize / 5;

    // Draw cells
    for (int p = 1; p <= 5; p++) {
      for (int i = 1; i <= 5; i++) {
        final severity = p * i; // 1-25
        final color = _severityColor(severity);
        final rect = Rect.fromLTWH(
          labelSpace + (p - 1) * cellSize,
          (5 - i) * cellSize,
          cellSize,
          cellSize,
        );
        canvas.drawRect(rect.deflate(1.5), Paint()..color = color);
      }
    }

    // Axis labels (probability on bottom, impact on left)
    final labelPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    const labelStyle = TextStyle(
        color: const Color(0xFF6B7280),
        fontSize: 10,
        fontWeight: FontWeight.w700);

    for (int p = 1; p <= 5; p++) {
      labelPainter.text = TextSpan(text: '$p', style: labelStyle);
      labelPainter.layout();
      labelPainter.paint(
          canvas,
          Offset(labelSpace + (p - 1) * cellSize + cellSize / 2 - labelPainter.width / 2,
              gridSize + 4));
    }
    for (int i = 1; i <= 5; i++) {
      labelPainter.text = TextSpan(text: '$i', style: labelStyle);
      labelPainter.layout();
      labelPainter.paint(
          canvas,
          Offset(labelSpace - 14,
              (5 - i) * cellSize + cellSize / 2 - labelPainter.height / 2));
    }
    // Axis titles
    labelPainter.text = const TextSpan(
        text: 'Probability →',
        style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 9,
            fontWeight: FontWeight.w600));
    labelPainter.layout();
    labelPainter.paint(
        canvas,
        Offset(labelSpace + gridSize / 2 - labelPainter.width / 2,
            gridSize + 16));

    // Plot risk dots — count items per cell
    final cellCounts = <String, int>{};
    for (final r in risks) {
      final key = '${r.probability}_${r.impact}';
      cellCounts[key] = (cellCounts[key] ?? 0) + 1;
    }
    final drawnCells = <String, int>{};
    for (final r in risks) {
      final p = r.probability.clamp(1, 5);
      final i = r.impact.clamp(1, 5);
      final key = '${p}_$i';
      final idx = drawnCells[key] ?? 0;
      drawnCells[key] = idx + 1;
      final cx = labelSpace + (p - 1) * cellSize + cellSize / 2;
      final cy = (5 - i) * cellSize + cellSize / 2;
      // Offset dots within a cell if multiple
      final ox = (idx % 2) * 12 - 6;
      final oy = (idx ~/ 2) * 12 - 6;
      final dotColor =
          r.isIssue ? const Color(0xFF1A1D1F) : Colors.white;
      final ringColor =
          r.isIssue ? const Color(0xFFEF4444) : const Color(0xFF1A1D1F);
      canvas.drawCircle(
          Offset(cx + ox, cy + oy), 8, Paint()..color = dotColor);
      canvas.drawCircle(
          Offset(cx + ox, cy + oy),
          8,
          Paint()
            ..color = ringColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  Color _severityColor(int severity) {
    // Interpolate green → yellow → red via t = (severity - 1) / 24
    final t = ((severity - 1) / 24).clamp(0.0, 1.0);
    final Color c;
    if (t < 0.5) {
      // green → yellow
      final tt = t / 0.5;
      c = Color.lerp(const Color(0xFF10B981), const Color(0xFFFACC15), tt)!;
    } else {
      // yellow → red
      final tt = (t - 0.5) / 0.5;
      c = Color.lerp(const Color(0xFFFACC15), const Color(0xFFEF4444), tt)!;
    }
    return c.withValues(alpha: 0.85);
  }

  @override
  bool shouldRepaint(covariant _RiskHeatmapPainter old) =>
      old.risks.length != risks.length;
}

/// Mini risk burndown sparkline — synthetic weekly trend derived from
/// current open / closed counts.
class _RiskTrendPainter extends CustomPainter {
  final List<RiskItem> items;
  _RiskTrendPainter({required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    const weeks = 6;
    final open = items.where((r) => r.status != RiskStatus.closed).length;
    final closed =
        items.where((r) => r.status == RiskStatus.closed).length;
    final total = items.length;

    // Synthetic series: open starts at total and trends down to current open;
    // closed starts at 0 and trends up to current closed.
    final openSeries = <double>[];
    final closedSeries = <double>[];
    for (var i = 0; i < weeks; i++) {
      final t = i / (weeks - 1);
      openSeries.add(total + (open - total) * t);
      closedSeries.add(0 + (closed - 0) * t);
    }
    final maxVal = total.toDouble().clamp(1.0, double.infinity);

    final w = size.width;
    final h = size.height;
    final dx = w / (weeks - 1);

    Path openPath(Path Function(List<Offset>) build) {
      final pts = <Offset>[];
      for (var i = 0; i < weeks; i++) {
        pts.add(Offset(i * dx,
            h - (openSeries[i] / maxVal) * (h - 4)));
      }
      return build(pts);
    }

    Path closedPath(Path Function(List<Offset>) build) {
      final pts = <Offset>[];
      for (var i = 0; i < weeks; i++) {
        pts.add(Offset(i * dx,
            h - (closedSeries[i] / maxVal) * (h - 4)));
      }
      return build(pts);
    }

    Path linePath(List<Offset> pts) {
      final p = Path();
      for (var i = 0; i < pts.length; i++) {
        if (i == 0) {
          p.moveTo(pts[i].dx, pts[i].dy);
        } else {
          p.lineTo(pts[i].dx, pts[i].dy);
        }
      }
      return p;
    }

    // Grid baseline
    canvas.drawLine(
        Offset(0, h - 1), Offset(w, h - 1),
        Paint()..color = const Color(0xFFE4E7EC)..strokeWidth = 1);

    // Closed area (green fill)
    final closedPts = <Offset>[];
    for (var i = 0; i < weeks; i++) {
      closedPts.add(Offset(
          i * dx, h - (closedSeries[i] / maxVal) * (h - 4)));
    }
    final closedArea = Path()
      ..moveTo(0, h)
      ..addPolygon(closedPts, false)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
        closedArea,
        Paint()
          ..color = const Color(0xFF10B981).withValues(alpha: 0.15));

    // Open line
    canvas.drawPath(
        openPath(linePath),
        Paint()
          ..color = const Color(0xFFEF4444)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    // Closed line
    canvas.drawPath(
        closedPath(linePath),
        Paint()
          ..color = const Color(0xFF10B981)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Dots at endpoints
    canvas.drawCircle(
        Offset(w, h - (openSeries.last / maxVal) * (h - 4)),
        4,
        Paint()..color = const Color(0xFFEF4444));
    canvas.drawCircle(
        Offset(w, h - (closedSeries.last / maxVal) * (h - 4)),
        4,
        Paint()..color = const Color(0xFF10B981));
  }

  @override
  bool shouldRepaint(covariant _RiskTrendPainter old) =>
      old.items.length != items.length;
}

/// Stacked-bar histogram — one bar per week (12 weeks), segments per
/// discipline.
class _ResourceHistogramPainter extends CustomPainter {
  final List<ResourceAllocation> allocations;
  _ResourceHistogramPainter({required this.allocations});

  @override
  void paint(Canvas canvas, Size size) {
    const weeks = 12;
    const leftPad = 36.0;
    const bottomPad = 22.0;
    const topPad = 8.0;
    final w = size.width;
    final h = size.height;
    final plotW = w - leftPad;
    final plotH = h - bottomPad - topPad;

    // Compute weekly totals
    final totals = List<double>.filled(weeks, 0);
    for (final ra in allocations) {
      for (var i = 0; i < weeks && i < ra.weeklyHours.length; i++) {
        totals[i] += ra.weeklyHours[i];
      }
    }
    final maxTotal = totals.fold(0.0, (a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    // Y-axis grid (4 lines)
    final gridPaint = Paint()..color = const Color(0xFFE4E7EC)..strokeWidth = 1;
    final labelPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    const labelStyle = TextStyle(
        color: const Color(0xFF6B7280),
        fontSize: 9,
        fontWeight: FontWeight.w600);
    for (var g = 0; g <= 4; g++) {
      final y = topPad + (plotH * g / 4);
      canvas.drawLine(
          Offset(leftPad, y), Offset(w, y), gridPaint);
      final val = (maxTotal * (1 - g / 4)).round();
      labelPainter.text = TextSpan(text: '${val}h', style: labelStyle);
      labelPainter.layout();
      labelPainter.paint(canvas,
          Offset(2, y - labelPainter.height / 2));
    }

    // Bars
    final barWidth = plotW / weeks;
    for (var i = 0; i < weeks; i++) {
      final x = leftPad + i * barWidth;
      double yCursor = topPad + plotH;
      for (final disc in ResourceDiscipline.values) {
        double hrs = 0;
        for (final ra in allocations) {
          if (ra.discipline == disc &&
              i < ra.weeklyHours.length) {
            hrs += ra.weeklyHours[i];
          }
        }
        if (hrs <= 0) continue;
        final segH = (hrs / maxTotal) * plotH;
        final rect = Rect.fromLTWH(
            x + barWidth * 0.15, yCursor - segH,
            barWidth * 0.7, segH);
        canvas.drawRect(
            rect,
            Paint()
              ..color = disc.color.withValues(alpha: 0.9));
        yCursor -= segH;
      }
      // X-axis label (week number)
      labelPainter.text = TextSpan(
          text: 'W${i + 1}', style: labelStyle);
      labelPainter.layout();
      labelPainter.paint(canvas,
          Offset(x + barWidth / 2 - labelPainter.width / 2,
              topPad + plotH + 6));
    }

    // X-axis baseline
    canvas.drawLine(
        Offset(leftPad, topPad + plotH),
        Offset(w, topPad + plotH),
        Paint()
          ..color = const Color(0xFF6B7280)
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _ResourceHistogramPainter old) {
    if (old.allocations.length != allocations.length) return true;
    for (var i = 0; i < allocations.length; i++) {
      final a = allocations[i].weeklyHours;
      final b = old.allocations[i].weeklyHours;
      if (a.length != b.length) return true;
      for (var j = 0; j < a.length; j++) {
        if (a[j] != b[j]) return true;
      }
    }
    return false;
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Health Gauge Painter
// ═════════════════════════════════════════════════════════════════════════

class _HealthGaugePainter extends CustomPainter {
  final int score;
  final Color color;
  _HealthGaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const sw = 8.0;
    // Track
    canvas.drawCircle(center, radius - sw / 2, Paint()..color = const Color(0xFFE4E7EC)..style = PaintingStyle.stroke..strokeWidth = sw);
    // Fill
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - sw / 2), -3.14159 / 2, (score / 100) * 2 * 3.14159, false, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = sw..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _HealthGaugePainter old) => old.score != score;
}
