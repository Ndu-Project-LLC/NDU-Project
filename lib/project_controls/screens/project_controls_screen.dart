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
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/project_intelligence_service.dart';
import 'package:ndu_project/widgets/shimmer_loading.dart';
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
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _DashboardTab(state: state, aiContext: aiContext, aiMilestones: aiMilestones, aiCostForecast: aiCostForecast, changeRecommendations: changeRecommendations),
                    _ScopeTrackingTab(state: state, aiMilestones: aiMilestones, aiContext: aiContext),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── AI-Powered Context Insights ──────────────────────────────
          if (aiContext.isNotEmpty)
            _aiInsightsCard(),
          if (aiContext.isNotEmpty)
            const SizedBox(height: 24),
          // KPI Row
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.sizeOf(context).width > 800 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: [
              _kpiCard('Total Budget', '$currencySymbol${(state.totalOriginalBudget / 1000000).toStringAsFixed(1)}M',
                  Icons.account_balance_wallet, const Color(0xFF6366F1)),
              _kpiCard('Actual Cost', '$currencySymbol${(state.totalActualCost / 1000000).toStringAsFixed(1)}M',
                  Icons.payments, const Color(0xFFD97706)),
              _kpiCard('CPI', state.portfolioCPI.toStringAsFixed(2),
                  Icons.trending_up, _cpiColor(state.portfolioCPI)),
              _kpiCard('SPI', state.portfolioSPI.toStringAsFixed(2),
                  Icons.schedule, _spiColor(state.portfolioSPI)),
            ],
          ),
          const SizedBox(height: 24),
          // Health + EVM Summary
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _healthCard()),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: _evmSummaryCard()),
            ],
          ),
          const SizedBox(height: 24),
          // Open Changes + Scope Growth
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _openChangesCard()),
              const SizedBox(width: 16),
              Expanded(child: _scopeGrowthCard()),
            ],
          ),
        ],
      ),
    );
  }

  // ── AI-Powered Context Insights Card ─────────────────────────────────-
  Widget _aiInsightsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7D2FE).withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.06),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI-Powered Context Insights',
                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('Auto-populated from project data across all phases',
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('AI·CONTEXT',
                    style: TextStyle(color: Color(0xFF6366F1), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Milestones
          if (aiMilestones.isNotEmpty) ...[
            const Text('SCOPE MILESTONES (from project data)',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            ...aiMilestones.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.flag_outlined, size: 14, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Expanded(child: Text(m, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12))),
              ]),
            )),
            const SizedBox(height: 12),
          ],
          // Cost forecast
          if (aiCostForecast.isNotEmpty) ...[
            const Text('COST INSIGHT (from cost analysis)',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.attach_money, size: 16, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Text(aiCostForecast, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
          ],
          // Change recommendations
          if (changeRecommendations.isNotEmpty) ...[
            const Text('CHANGE RECOMMENDATIONS (from constraints/assumptions)',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            ...changeRecommendations.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lightbulb_outline, size: 14, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Expanded(child: Text(r, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12))),
              ]),
            )),
          ],
          // Raw context scan (collapsible)
          if (aiContext.isNotEmpty && aiMilestones.isEmpty && aiCostForecast.isEmpty && changeRecommendations.isEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                aiContext.length > 400 ? '${aiContext.substring(0, 400)}...' : aiContext,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontFamily: appFontFamily),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w600)),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16),
            ),
          ]),
          Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 28, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Color _cpiColor(double cpi) {
    if (cpi >= 1.0) return const Color(0xFF10B981);
    if (cpi >= 0.9) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _spiColor(double spi) {
    if (spi >= 1.0) return const Color(0xFF10B981);
    if (spi >= 0.9) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Widget _healthCard() {
    final score = state.healthScore;
    final color = score >= 80 ? const Color(0xFF10B981) : score >= 60 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('OVERALL HEALTH', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 16),
        Row(children: [
          SizedBox(width: 80, height: 80, child: CustomPaint(painter: _HealthGaugePainter(score: score, color: color), child: Center(child: Text('$score', style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900))))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(score >= 80 ? 'Healthy' : score >= 60 ? 'At Risk' : 'Critical', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${state.workPackages.length} work packages tracked', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
            Text('${state.openChangeRequests} open change requests', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          ])),
        ]),
      ]),
    );
  }

  Widget _evmSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('EARNED VALUE SUMMARY', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 16),
        _evmRow('BAC (Budget at Completion)', '\$${(state.totalOriginalBudget / 1000000).toStringAsFixed(2)}M', const Color(0xFF0F172A)),
        _evmRow('EV (Earned Value)', '\$${(state.totalEarnedValue / 1000000).toStringAsFixed(2)}M', const Color(0xFF6366F1)),
        _evmRow('AC (Actual Cost)', '\$${(state.totalActualCost / 1000000).toStringAsFixed(2)}M', const Color(0xFFD97706)),
        _evmRow('PV (Planned Value)', '\$${(state.totalPlannedValue / 1000000).toStringAsFixed(2)}M', const Color(0xFF8B5CF6)),
        _evmRow('EAC (Estimate at Completion)', '\$${(state.portfolioEAC / 1000000).toStringAsFixed(2)}M', _cpiColor(state.portfolioCPI)),
        _evmRow('VAC (Variance at Completion)', '\$${(state.portfolioVAC / 1000000).toStringAsFixed(2)}M', state.portfolioVAC >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
        _evmRow('CV (Cost Variance)', '\$${((state.totalEarnedValue - state.totalActualCost) / 1000000).toStringAsFixed(2)}M', state.totalEarnedValue >= state.totalActualCost ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
        _evmRow('SV (Schedule Variance)', '\$${((state.totalEarnedValue - state.totalPlannedValue) / 1000000).toStringAsFixed(2)}M', state.totalEarnedValue >= state.totalPlannedValue ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
      ]),
    );
  }

  Widget _evmRow(String label, String value, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
      Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
    ]));
  }

  Widget _openChangesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE4E7EC))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('CHANGE REQUESTS', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Text('${state.openChangeRequests} OPEN', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 16),
        ...state.changeRequests.take(3).map((cr) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
          Icon(cr.category.icon, size: 16, color: cr.status.color),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cr.description, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${cr.category.label} • ${cr.status.label}', style: TextStyle(color: cr.status.color, fontSize: 11)),
          ])),
        ]))),
      ]),
    );
  }

  Widget _scopeGrowthCard() {
    // Check for scope growth (work packages with status 'Added' but no approved CR)
    final growthIssues = <String>[];
    for (final wp in state.workPackages) {
      if (wp.status == 'Added') {
        final hasApproval = state.changeRequests.any((cr) =>
            cr.status == ChangeStatus.approved &&
            cr.description.toLowerCase().contains(wp.name.toLowerCase()));
        if (!hasApproval) {
          growthIssues.add('${wp.wbsCode} ${wp.name} — added without approved change request');
        }
      }
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE4E7EC))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SCOPE GROWTH DETECTION', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 16),
        if (growthIssues.isEmpty)
          const Row(children: [Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18), SizedBox(width: 8), Text('No unauthorized scope growth detected', style: TextStyle(color: Color(0xFF10B981), fontSize: 13))])
        else
          ...growthIssues.map((issue) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(issue, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12))),
          ]))),
      ]),
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
  const _ScopeTrackingTab({
    required this.state,
    required this.aiMilestones,
    required this.aiContext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Work Package Scope Tracking', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${state.workPackages.length} ${state.deliveryModel == DeliveryModel.agile ? 'Epics' : 'Work Packages'} • Delivery: ${state.deliveryModel.label}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        const SizedBox(height: 20),
        // ── AI-Derived Scope Milestones ──────────────────────────────
        if (aiMilestones.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0).withValues(alpha: 0.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.flag_rounded, color: Color(0xFF10B981), size: 14),
                  ),
                  const SizedBox(width: 10),
                  const Text('AI-Derived Scope Milestones', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${aiMilestones.length} proposed', style: const TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 12),
                const Text('The following milestones were auto-populated from your project context:', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                const SizedBox(height: 10),
                ...aiMilestones.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text('${entry.key + 1}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w700))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(entry.value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w500))),
                  ]),
                )),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Milestones sent to Work Package table'), behavior: SnackBarBehavior.floating),
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Add All to Work Package Table'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        // ── Work Packages ────────────────────────────────────────────
        ...state.workPackages.map((wp) => _workPackageCard(wp)),
      ]),
    );
  }

  Widget _workPackageCard(WorkPackageControl wp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE4E7EC))),
      child: Column(children: [
        // Header
        Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFFF9FAFB), borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))), child: Row(children: [
          Container(width: 4, height: 24, decoration: BoxDecoration(color: wp.isCriticalPath ? const Color(0xFFEF4444) : const Color(0xFF6366F1), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(wp.name, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w700)),
            Text('${wp.wbsCode} • ${wp.discipline ?? "N/A"} • ${wp.status}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          ])),
          if (wp.isCriticalPath) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: const Text('CRITICAL PATH', style: TextStyle(color: Color(0xFFEF4444), fontSize: 9, fontWeight: FontWeight.w700))),
        ])),
        // Body
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          // Progress
          Row(children: [
            const Text('Progress', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${(wp.percentComplete ?? 0).round()}%', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (wp.percentComplete ?? 0) / 100, backgroundColor: const Color(0xFFE4E7EC), valueColor: AlwaysStoppedAnimation(wp.isCriticalPath ? const Color(0xFFEF4444) : const Color(0xFF10B981)), minHeight: 6)),
          const SizedBox(height: 16),
          // Cost + Schedule row
          Row(children: [
            Expanded(child: _infoChip('Original Budget', '\$${(wp.originalBudget / 1000000).toStringAsFixed(2)}M')),
            const SizedBox(width: 8),
            Expanded(child: _infoChip('Actual Cost', '\$${(wp.actualCost / 1000000).toStringAsFixed(2)}M')),
            const SizedBox(width: 8),
            Expanded(child: _infoChip('CPI', wp.cpi.toStringAsFixed(2))),
            const SizedBox(width: 8),
            Expanded(child: _infoChip('SPI', wp.spi.toStringAsFixed(2))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _infoChip('EV', '\$${(wp.earnedValue / 1000000).toStringAsFixed(2)}M')),
            const SizedBox(width: 8),
            Expanded(child: _infoChip('EAC', '\$${(wp.eac / 1000000).toStringAsFixed(2)}M')),
            const SizedBox(width: 8),
            Expanded(child: _infoChip('VAC', '\$${(wp.vac / 1000).toStringAsFixed(0)}K')),
            const SizedBox(width: 8),
            Expanded(child: _infoChip('Float', '${wp.floatDays?.round() ?? 0}d')),
          ]),
        ])),
      ]),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(6)), child: Column(children: [
      Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9, fontWeight: FontWeight.w600)),
      Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w700)),
    ]));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// TAB: Cost Control
// ═════════════════════════════════════════════════════════════════════════

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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Cost Control & EVM', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Total Budget: \$${(state.totalOriginalBudget / 1000000).toStringAsFixed(2)}M • Spent: \$${(state.totalActualCost / 1000000).toStringAsFixed(2)}M • Remaining: \$${((state.totalCurrentBudget - state.totalActualCost) / 1000000).toStringAsFixed(2)}M', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        const SizedBox(height: 20),
        // ── AI Cost Forecast Card ────────────────────────────────────
        if (aiCostForecast.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.trending_up_rounded, color: Color(0xFFD97706), size: 14),
                  ),
                  const SizedBox(width: 10),
                  const Text('AI Cost Insight', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('FROM COST ANALYSIS', style: TextStyle(color: Color(0xFFD97706), fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.attach_money_rounded, size: 20, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(aiCostForecast, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 8),
                const Text('This amount was auto-populated from your project cost analysis data. You can compare it against the EVM metrics above.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        // Cost breakdown per WP
        ...state.workPackages.map((wp) => _costCard(wp)),
        const SizedBox(height: 28),
        // ── Allowance & Contingency Tracking ─────────────────────────
        _buildAllowanceTrackingSection(projectData),
      ]),
    );
  }

  Widget _buildAllowanceTrackingSection(ProjectDataModel projectData) {
    final items = projectData.frontEndPlanning.allowanceItems;
    final formatter = NumberFormat.simpleCurrency(decimalDigits: 0);
    final totalReserved = items.fold<double>(0.0, (s, i) => s + i.amount);
    final totalReleased = items.fold<double>(0.0, (s, i) => s + i.releasedAmount);
    final totalActual = items.fold<double>(0.0, (s, i) => s + i.actualAmount);
    final totalScheduleWeeks = items.fold<double>(
        0.0, (s, i) => s + i.scheduleImpactWeeks);
    final reservedCount = items.where((i) => i.releaseStatus == 'Reserved').length;
    final releasedCount = items
        .where((i) =>
            i.releaseStatus == 'Released' ||
            i.releaseStatus == 'Partially Released')
        .length;
    final consumedCount = items.where((i) => i.releaseStatus == 'Consumed').length;
    final closedCount = items.where((i) => i.releaseStatus == 'Closed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.savings_outlined,
                color: Color(0xFFD97706), size: 20),
            const SizedBox(width: 8),
            const Text('Allowance & Contingency Tracking',
                style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${items.length} item${items.length == 1 ? "" : "s"}',
                style: const TextStyle(
                    color: Color(0xFFD97706),
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Live tracking of allowance and contingency items as the project '
          'progresses. Updated when items are delayed, moved, added, '
          'cancelled, or consumed.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
        const SizedBox(height: 14),
        // Summary tiles
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _allowanceSummaryTile(
              label: 'Total Reserved',
              value: formatter.format(totalReserved),
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFF2563EB),
            ),
            _allowanceSummaryTile(
              label: 'Released',
              value: formatter.format(totalReleased),
              icon: Icons.unarchive_outlined,
              color: const Color(0xFFD97706),
            ),
            _allowanceSummaryTile(
              label: 'Actual Consumed',
              value: formatter.format(totalActual),
              icon: Icons.trending_down_rounded,
              color: const Color(0xFFDC2626),
            ),
            _allowanceSummaryTile(
              label: 'Schedule Allowance',
              value: '${totalScheduleWeeks.toStringAsFixed(totalScheduleWeeks.truncateToDouble() == totalScheduleWeeks ? 0 : 1)} wks',
              icon: Icons.schedule_outlined,
              color: const Color(0xFF7C3AED),
            ),
            _allowanceSummaryTile(
              label: 'Status Mix',
              value: '$reservedCount Rsv • $releasedCount Rel • $consumedCount Con • $closedCount Cls',
              icon: Icons.pie_chart_outline,
              color: const Color(0xFF059669),
              small: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Column(
              children: [
                Icon(Icons.inbox_outlined,
                    size: 36, color: Color(0xFF9CA3AF)),
                SizedBox(height: 10),
                Text('No allowance items to track yet.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                SizedBox(height: 4),
                Text(
                    'Define allowances in Front End Planning → Allowance to '
                    'begin tracking them here as the project progresses.',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                    textAlign: TextAlign.center),
              ],
            ),
          )
        else
          ...items.map((item) => _allowanceTrackingCard(item, formatter)),
      ],
    );
  }

  Widget _allowanceSummaryTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool small = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label.toUpperCase(),
                  style: TextStyle(
                      color: color.withValues(alpha: 0.85),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: small ? 11 : 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _allowanceTrackingCard(AllowanceItem item, NumberFormat formatter) {
    final burnRate = item.amount > 0
        ? (item.actualAmount / item.amount).clamp(0.0, 2.0)
        : 0.0;
    final Color statusColor;
    switch (item.releaseStatus) {
      case 'Released':
        statusColor = const Color(0xFFD97706);
        break;
      case 'Partially Released':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'Consumed':
        statusColor = const Color(0xFFDC2626);
        break;
      case 'Closed':
        statusColor = const Color(0xFF6B7280);
        break;
      default:
        statusColor = const Color(0xFF2563EB);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.name,
                    style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                ),
                child: Text(item.releaseStatus,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (item.description.isNotEmpty &&
              item.description != item.name) ...[
            const SizedBox(height: 4),
            Text(item.description,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 11)),
          ],
          const SizedBox(height: 8),
          // Burn rate progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: burnRate,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation(burnRate > 1.0
                  ? const Color(0xFFDC2626)
                  : burnRate > 0.75
                      ? const Color(0xFFD97706)
                      : const Color(0xFF10B981)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
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
  }

  Widget _metaText(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
        children: [
          TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(
              text: value,
              style: const TextStyle(color: Color(0xFF111827))),
        ],
      ),
    );
  }

  Widget _costCard(WorkPackageControl wp) {
    final pct = wp.currentBudget > 0 ? wp.actualCost / wp.currentBudget : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE4E7EC))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${wp.wbsCode} ${wp.name}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
          Text('CPI: ${wp.cpi.toStringAsFixed(2)}', style: TextStyle(color: wp.cpi >= 1.0 ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, backgroundColor: const Color(0xFFE4E7EC), valueColor: AlwaysStoppedAnimation(pct > 1.0 ? const Color(0xFFEF4444) : const Color(0xFFD97706)), minHeight: 8)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Budget: \$${(wp.currentBudget / 1000000).toStringAsFixed(2)}M', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
          Text('Actual: \$${(wp.actualCost / 1000000).toStringAsFixed(2)}M', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
          Text('EAC: \$${(wp.eac / 1000000).toStringAsFixed(2)}M', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.w700)),
          Text('VAC: \$${(wp.vac / 1000).toStringAsFixed(0)}K', style: TextStyle(color: wp.vac >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ]),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Change Management', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Delivery Model: ${state.deliveryModel.label} • ${state.deliveryModel.changeProcess}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        const SizedBox(height: 20),
        // ── AI Recommendations Card ─────────────────────────────────────
        if (changeRecommendations.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFEF2F2), Color(0xFFFFF5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA).withValues(alpha: 0.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFEF4444), size: 14),
                  ),
                  const SizedBox(width: 10),
                  const Text('AI Change Recommendations', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${changeRecommendations.length} items', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 12),
                const Text('These recommendations were auto-populated from project constraints, assumptions, and risk data:',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                const SizedBox(height: 10),
                ...changeRecommendations.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(entry.value,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      height: 28,
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Change request created for: ${entry.value.length > 40 ? '${entry.value.substring(0, 40)}...' : entry.value}'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: const Color(0xFFF59E0B),
                          side: const BorderSide(color: Color(0xFFF59E0B)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Create CR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        // Change requests
        ...state.changeRequests.map((cr) => _changeRequestCard(cr, context)),
      ]),
    );
  }

  Widget _changeRequestCard(ChangeRequest cr, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cr.status.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cr.status.color.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(children: [
              Icon(cr.category.icon, color: cr.status.color, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cr.description, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w700)),
                Text('${cr.id} • ${cr.category.label} • Priority: ${cr.priority}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: cr.status.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(cr.status.label, style: TextStyle(color: cr.status.color, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildChangeBody(cr)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChangeBody(ChangeRequest cr) {
    final children = <Widget>[];
    // Justification
    children.add(Text('Justification: ${cr.justification}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)));
    if (cr.rootCause != null) {
      children.add(const SizedBox(height: 4));
      children.add(Text('Root Cause: ${cr.rootCause}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)));
    }
    children.add(const SizedBox(height: 12));
    // Impact analysis
    children.add(const Text('IMPACT ANALYSIS', style: TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)));
    children.add(const SizedBox(height: 8));
    children.add(Wrap(spacing: 8, runSpacing: 8, children: _buildImpactChips(cr)));
    children.add(const SizedBox(height: 12));
    // Affected baselines
    if (cr.affectedBaselines.isNotEmpty) {
      children.add(const Text('AFFECTED BASELINES', style: TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)));
      children.add(const SizedBox(height: 4));
      children.add(Wrap(spacing: 6, children: cr.affectedBaselines.map((b) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE4E7EC))),
        child: Text(b, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
      )).toList()));
    }
    children.add(const SizedBox(height: 12));
    // Approval workflow
    if (cr.approval != null) {
      children.add(const Text('APPROVAL WORKFLOW', style: TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)));
      children.add(const SizedBox(height: 8));
      for (final entry in cr.approval!.steps.asMap().entries) {
        final step = entry.value;
        final isCurrent = entry.key == cr.approval!.currentStepIndex;
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: step.approved ? const Color(0xFF10B981) : (isCurrent ? const Color(0xFFF59E0B) : const Color(0xFFE4E7EC)),
                shape: BoxShape.circle,
              ),
              child: step.approved
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : (isCurrent ? const Icon(Icons.hourglass_top, color: Colors.white, size: 12) : null),
            ),
            const SizedBox(width: 8),
            Text(step.role.label, style: TextStyle(
              color: step.approved ? const Color(0xFF10B981) : (isCurrent ? const Color(0xFFF59E0B) : const Color(0xFF6B7280)),
              fontSize: 12,
              fontWeight: step.approved || isCurrent ? FontWeight.w600 : FontWeight.normal,
            )),
            if (step.approved && step.approvedAt != null)
              Text('  ✓ ${step.approvedAt!.day}/${step.approvedAt!.month}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 10)),
          ]),
        ));
      }
    }
    // Action button
    if (cr.status == ChangeStatus.underReview && cr.approval != null && cr.approval!.currentStep != null) {
      children.add(const SizedBox(height: 12));
      children.add(SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => provider.approveChangeStep(cr.id),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('Approve as ${cr.approval!.currentStep!.role.label}'),
        ),
      ));
    }
    return children;
  }

  List<Widget> _buildImpactChips(ChangeRequest cr) {
    final chips = <Widget>[];
    if (cr.impact.scheduleImpactDays != null && cr.impact.scheduleImpactDays! > 0) {
      chips.add(_impactChip('Schedule', '+${cr.impact.scheduleImpactDays!.round()} days', const Color(0xFFEF4444)));
    }
    if (cr.impact.costImpactAmount != null && cr.impact.costImpactAmount! > 0) {
      chips.add(_impactChip('Cost', '+\$${(cr.impact.costImpactAmount! / 1000).round()}K', const Color(0xFFD97706)));
    }
    if (cr.impact.scopeImpact != null) {
      chips.add(_impactChip('Scope', cr.impact.scopeImpact!, const Color(0xFF6366F1)));
    }
    if (cr.impact.resourceImpact != null) {
      chips.add(_impactChip('Resource', cr.impact.resourceImpact!, const Color(0xFF8B5CF6)));
    }
    if (cr.impact.procurementImpact != null) {
      chips.add(_impactChip('Procurement', cr.impact.procurementImpact!, const Color(0xFF10B981)));
    }
    if (cr.impact.riskImpact != null) {
      chips.add(_impactChip('Risk', cr.impact.riskImpact!, const Color(0xFFEF4444)));
    }
    return chips;
  }

  Widget _impactChip(String label, String value, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.2))), child: Column(children: [
      Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
      Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]));
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Forecasting & Analytics', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Automated forecasts based on current performance trends', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        const SizedBox(height: 20),
        // Forecast cards
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 2.2, children: [
          _forecastCard('EAC (Estimate at Completion)', '\$${(state.portfolioEAC / 1000000).toStringAsFixed(2)}M', 'Based on CPI ${state.portfolioCPI.toStringAsFixed(2)}', state.portfolioEAC <= state.totalOriginalBudget ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
          _forecastCard('ETC (Estimate to Complete)', '\$${((state.portfolioEAC - state.totalActualCost) / 1000000).toStringAsFixed(2)}M', 'Remaining work value', const Color(0xFF6366F1)),
          _forecastCard('VAC (Variance at Completion)', '\$${(state.portfolioVAC / 1000000).toStringAsFixed(2)}M', state.portfolioVAC >= 0 ? 'Under budget' : 'Over budget', state.portfolioVAC >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
          _forecastCard('Avg Progress', '${state.avgPercentComplete.round()}%', '${state.workPackages.length} work packages', const Color(0xFF8B5CF6)),
        ]),
        const SizedBox(height: 24),
        // Trend analysis
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE4E7EC))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PERFORMANCE TRENDS', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 16),
          ...state.workPackages.map((wp) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${wp.wbsCode} ${wp.name}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
              Row(children: [
                Text('CPI ${wp.cpi.toStringAsFixed(2)}', style: TextStyle(color: wp.cpi >= 1.0 ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('SPI ${wp.spi.toStringAsFixed(2)}', style: TextStyle(color: wp.spi >= 1.0 ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(flex: wp.percentComplete?.round() ?? 0, child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(2)))),
              Expanded(flex: 100 - (wp.percentComplete?.round() ?? 0), child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFE4E7EC), borderRadius: BorderRadius.circular(2)))),
            ]),
          ]))),
        ])),
      ]),
    );
  }

  Widget _forecastCard(String label, String value, String subtitle, Color color) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w600)),
      Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
      Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
    ]));
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
            'BASELINE MGMT',
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
    final variances = widget.state.scheduleVariances;
    final filtered = wps.where((wp) {
      final sv = variances.firstWhere(
        (v) => v.workPackageId == wp.id,
        orElse: () => ScheduleVariance(
            workPackageId: wp.id,
            floatDays: wp.floatDays ?? 0,
            delayReason: '',
            compressionStrategy: CompressionStrategy.none),
      );
      if (_filter == 'critical') return sv.isCritical;
      if (_filter == 'delayed') return sv.varianceDays > 0;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Schedule Control',
              style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              '${wps.length} work packages • ${widget.state.criticalPathCount} on critical path • ${widget.state.delayedWorkPackagesCount} delayed',
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 13)),
          const SizedBox(height: 16),
          // Filter chips
          Wrap(spacing: 8, children: [
            _filterChip('All', 'all', wps.length),
            _filterChip(
                'Critical Path', 'critical', widget.state.criticalPathCount),
            _filterChip('Delayed', 'delayed',
                widget.state.delayedWorkPackagesCount),
          ]),
          const SizedBox(height: 16),
          // Table header (only on wide screens, otherwise cards)
          if (MediaQuery.sizeOf(context).width > 900)
            _wideTable(filtered)
          else
            ...filtered.map((wp) => _narrowCard(wp)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String key, int count) {
    final selected = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: selected
                ? LightModeColors.accent.withValues(alpha: 0.15)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected
                    ? LightModeColors.accent.withValues(alpha: 0.5)
                    : const Color(0xFFE4E7EC))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  color: selected
                      ? const Color(0xFFD97706)
                      : const Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text('$count',
              style: TextStyle(
                  color: selected
                      ? const Color(0xFFD97706)
                      : const Color(0xFF6B7280),
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E7EC))),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12))),
            child: const Row(children: [
              Expanded(flex: 3, child: Text('Work Package',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
              Expanded(flex: 2, child: Text('Planned',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
              Expanded(flex: 2, child: Text('Actual',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
              Expanded(flex: 1, child: Text('Var',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
              Expanded(flex: 1, child: Text('Float',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
              Expanded(flex: 1, child: Text('SPI',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
              Expanded(flex: 3, child: Text('Delay reason / strategy',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
            ]),
          ),
          ...wps.map((wp) => _wideRow(wp)),
        ],
      ),
    );
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          border: Border(
              top: BorderSide(
                  color: const Color(0xFFE4E7EC).withValues(alpha: 0.6)))),
      child: Row(children: [
        Expanded(
            flex: 3,
            child: Row(children: [
              if (sv.isCritical)
                Container(
                  width: 4,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(2)),
                ),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(wp.name,
                          style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(wp.wbsCode,
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 10)),
                    ]),
              ),
            ])),
        Expanded(
            flex: 2,
            child: Text(plannedStr,
                style: const TextStyle(
                    color: Color(0xFF0F172A), fontSize: 11))),
        Expanded(
            flex: 2,
            child: Text(actualStr,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 11))),
        Expanded(
            flex: 1,
            child: _varianceBadge(variance)),
        Expanded(
            flex: 1,
            child: Text('${sv.floatDays.round()}d',
                style: TextStyle(
                    color: sv.isCritical
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w700))),
        Expanded(
            flex: 1,
            child: Text(wp.spi.toStringAsFixed(2),
                style: TextStyle(
                    color: wp.spi >= 1.0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    fontSize: 12,
                    fontWeight: FontWeight.w700))),
        Expanded(
            flex: 3,
            child: _delayStrategyCell(wp.id, sv)),
      ]),
    );
  }

  Widget _varianceBadge(int days) {
    if (days == 0) {
      return const Text('0d',
          style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w700));
    }
    final late = days > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: (late ? const Color(0xFFEF4444) : const Color(0xFF10B981))
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4)),
      child: Text(
          '${late ? '+' : ''}${days}d',
          style: TextStyle(
              color: late ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _delayStrategyCell(String wpId, ScheduleVariance sv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 28,
          child: TextField(
            controller: _reasonControllerFor(wpId, sv.delayReason),
            style: const TextStyle(
                color: Color(0xFF0F172A), fontSize: 11),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              hintText: 'Add delay reason…',
              hintStyle:
                  const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFE4E7EC))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFE4E7EC))),
            ),
            onSubmitted: (val) => widget.provider
                .setDelayReason(wpId, val.trim()),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
            spacing: 4,
            children: CompressionStrategy.values.map((s) {
              final selected = sv.compressionStrategy == s;
              return GestureDetector(
                onTap: () => widget.provider
                    .setCompressionStrategy(wpId, s),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: selected
                          ? s.color.withValues(alpha: 0.15)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: selected
                              ? s.color.withValues(alpha: 0.4)
                              : const Color(0xFFE4E7EC))),
                  child: Text(s.label,
                      style: TextStyle(
                          color: selected
                              ? s.color
                              : const Color(0xFF6B7280),
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              );
            }).toList()),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sv.isCritical
                  ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                  : const Color(0xFFE4E7EC))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (sv.isCritical)
              Container(
                  width: 4,
                  height: 18,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(2))),
            Expanded(
                child: Text(wp.name,
                    style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w700))),
            if (sv.isCritical)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('CRITICAL',
                    style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _metaCell('Planned', plannedStr)),
            const SizedBox(width: 6),
            Expanded(
                child: _metaCell('Actual', actualStr)),
            const SizedBox(width: 6),
            Expanded(
                child: _metaCell('Var', '${sv.varianceDays >= 0 ? "+" : ""}${sv.varianceDays}d')),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _metaCell('Float', '${sv.floatDays.round()}d')),
            const SizedBox(width: 6),
            Expanded(
                child: _metaCell('SPI', wp.spi.toStringAsFixed(2))),
          ]),
          const SizedBox(height: 10),
          _delayStrategyCell(wp.id, sv),
        ],
      ),
    );
  }

  Widget _metaCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(4)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 9,
                    fontWeight: FontWeight.w600)),
            Text(value,
                style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// TAB: Risk & Issues
// ═════════════════════════════════════════════════════════════════════════

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

  TextEditingController _mitigationControllerFor(
      String id, String initial) {
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Risk & Issues Register',
              style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              '${widget.state.openRisks.length} open risks • ${widget.state.openIssues.length} open issues • ${widget.state.criticalRisksCount} critical',
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 13)),
          const SizedBox(height: 16),
          // Heatmap + trend
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  flex: 3,
                  child: _heatmapCard(items)),
              const SizedBox(width: 16),
              Expanded(
                  flex: 2,
                  child: _trendCard(items)),
            ],
          ),
          const SizedBox(height: 16),
          // Filters
          Wrap(spacing: 8, runSpacing: 6, children: [
            _typeChip('All', 'all'),
            _typeChip('Risks only', 'risks'),
            _typeChip('Issues only', 'issues'),
            const SizedBox(width: 8),
            ...['low', 'medium', 'high', 'critical']
                .map((s) => _severityChip(_capitalize(s), s)),
          ]),
          const SizedBox(height: 8),
          if (owners.isNotEmpty)
            Row(children: [
              const Text('Owner: ',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFE4E7EC))),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _ownerFilter,
                      isExpanded: true,
                      hint: const Text('All owners'),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('All owners')),
                        ...owners.map((o) => DropdownMenuItem(
                            value: o, child: Text(o))),
                      ],
                      onChanged: (v) =>
                          setState(() => _ownerFilter = v),
                    ),
                  ),
                ),
              ),
            ]),
          const SizedBox(height: 16),
          // Register
          if (filtered.isEmpty)
            _emptyState('No items match the current filters.',
                Icons.filter_alt_off_outlined)
          else
            ...filtered.map((r) => _riskCard(r)),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Widget _typeChip(String label, String key) {
    final selected = _typeFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _typeFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: selected
                ? LightModeColors.accent.withValues(alpha: 0.15)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected
                    ? LightModeColors.accent.withValues(alpha: 0.5)
                    : const Color(0xFFE4E7EC))),
        child: Text(label,
            style: TextStyle(
                color: selected
                    ? const Color(0xFFD97706)
                    : const Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _severityChip(String label, String key) {
    final selected = _severityFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _severityFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: selected
                ? _severityColorFor(key).withValues(alpha: 0.15)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected
                    ? _severityColorFor(key).withValues(alpha: 0.5)
                    : const Color(0xFFE4E7EC))),
        child: Text(label,
            style: TextStyle(
                color: selected
                    ? _severityColorFor(key)
                    : const Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Color _severityColorFor(String key) {
    switch (key) {
      case 'low':
        return const Color(0xFF10B981);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'high':
        return const Color(0xFFF97316);
      case 'critical':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _heatmapCard(List<RiskItem> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E7EC))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RISK HEATMAP (P × I)',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          const Text(
              'Each cell is colored green→yellow→red by severity. Dots show open risks/issues plotted at their P×I coordinates.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.1,
            child: CustomPaint(
              painter: _RiskHeatmapPainter(risks: items),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendCard(List<RiskItem> items) {
    // Synthetic weekly trend: derived from current open/closed counts
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E7EC))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('WEEKLY TREND',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          const Text('Open risks/ issues per week (last 6 weeks)',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: CustomPaint(
              painter: _RiskTrendPainter(items: items),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _legendDot(const Color(0xFFEF4444), 'Open'),
            const SizedBox(width: 12),
            _legendDot(const Color(0xFF10B981), 'Closed'),
          ]),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _riskCard(RiskItem r) {
    final color = r.severityColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12))),
          child: Row(children: [
            Icon(r.isIssue ? Icons.bug_report_outlined : Icons.warning_amber,
                color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(r.description,
                      style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  Text(
                      '${r.id} • ${r.isIssue ? "Issue" : "Risk"} • Owner: ${r.owner}',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 11)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('${r.severityLabel} (${r.severity})',
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: r.status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(r.status.label,
                    style: TextStyle(
                        color: r.status.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _metaCell('Probability', '${r.probability}/5'),
                const SizedBox(width: 6),
                _metaCell('Impact', '${r.impact}/5'),
                const SizedBox(width: 6),
                _metaCell('Type', r.isIssue ? 'Issue' : 'Risk'),
              ]),
              const SizedBox(height: 10),
              const Text('MITIGATION / RESPONSE PLAN',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              const SizedBox(height: 6),
              TextField(
                controller: _mitigationControllerFor(r.id, r.mitigation),
                maxLines: 2,
                style: const TextStyle(
                    color: Color(0xFF0F172A), fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.all(8),
                  hintText: 'Describe the mitigation/response plan…',
                  hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 11),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: Color(0xFFE4E7EC))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: Color(0xFFE4E7EC))),
                ),
                onSubmitted: (val) => widget.provider.updateRiskItem(
                    r.id, r.copyWith(mitigation: val.trim())),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: Wrap(spacing: 6, children: [
                    for (final s in RiskStatus.values)
                      GestureDetector(
                        onTap: () => widget.provider
                            .updateRiskItem(r.id, r.copyWith(status: s)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: r.status == s
                                  ? s.color.withValues(alpha: 0.15)
                                  : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: r.status == s
                                      ? s.color.withValues(alpha: 0.4)
                                      : const Color(0xFFE4E7EC))),
                          child: Text(s.label,
                              style: TextStyle(
                                  color: r.status == s
                                      ? s.color
                                      : const Color(0xFF6B7280),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ]),
                ),
                if (r.status != RiskStatus.closed)
                  TextButton.icon(
                    onPressed: () =>
                        widget.provider.closeRiskItem(r.id),
                    icon: const Icon(Icons.check_circle_outline,
                        size: 14),
                    label: const Text('Close'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _metaCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(4)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 9,
                    fontWeight: FontWeight.w600)),
            Text(value,
                style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFFE4E7EC),
              style: BorderStyle.solid)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: const Color(0xFF6B7280), size: 18),
        const SizedBox(width: 8),
        Text(message,
            style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 13)),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// TAB: Resource Control
// ═════════════════════════════════════════════════════════════════════════

class _ResourceControlTab extends StatefulWidget {
  final ProjectControlsState state;
  const _ResourceControlTab({required this.state});

  @override
  State<_ResourceControlTab> createState() => _ResourceControlTabState();
}

class _ResourceControlTabState extends State<_ResourceControlTab> {
  double _adjustment = 0; // -50% to +50%
  double _capacityBoost = 0; // -2 to +2 (headcount equivalent)

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
              capacityHoursPerWeek:
                  ra.capacityHoursPerWeek + _capacityBoost,
            ))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resource Control',
              style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              '${allocations.length} resources across ${ResourceDiscipline.values.length} disciplines • 12-week window',
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 13)),
          const SizedBox(height: 20),
          // Histogram
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E7EC))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('WEEKLY ALLOCATION HISTOGRAM',
                      style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  const Spacer(),
                  Text(
                      'Projection: ${_adjustment >= 0 ? "+" : ""}${_adjustment.round()}% • Capacity ${_capacityBoost >= 0 ? "+" : ""}${_capacityBoost.toStringAsFixed(1)}h/wk',
                      style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: CustomPaint(
                    painter: _ResourceHistogramPainter(
                        allocations: projectedAllocations),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 12),
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
          const SizedBox(height: 20),
          // What-if controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF4CC).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: LightModeColors.accent.withValues(alpha: 0.4))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.science_outlined,
                      color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  const Text('WHAT-IF ANALYSIS',
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _adjustment = 0;
                      _capacityBoost = 0;
                    }),
                    child: const Text('Reset',
                        style: TextStyle(
                            color: Color(0xFF6B7280), fontSize: 12)),
                  ),
                ],
                ),
                const SizedBox(height: 8),
                const Text(
                    'Test adding / removing workload or capacity. The histogram and utilization cards below update live.',
                    style:
                        TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Allocation adjustment: ${_adjustment >= 0 ? "+" : ""}${_adjustment.round()}%',
                            style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        Slider(
                          value: _adjustment,
                          min: -50,
                          max: 50,
                          divisions: 20,
                          activeColor: LightModeColors.accent,
                          label: '${_adjustment.round()}%',
                          onChanged: (v) => setState(() => _adjustment = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Capacity delta: ${_capacityBoost >= 0 ? "+" : ""}${_capacityBoost.toStringAsFixed(1)} h/wk',
                            style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        Slider(
                          value: _capacityBoost,
                          min: -10,
                          max: 10,
                          divisions: 20,
                          activeColor: LightModeColors.accent,
                          label: '${_capacityBoost.toStringAsFixed(1)}h',
                          onChanged: (v) =>
                              setState(() => _capacityBoost = v),
                        ),
                      ],
                    ),
                  ),
                ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Utilization cards
          const Text('UTILIZATION PER RESOURCE',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          ...projectedAllocations.map((ra) => _utilizationCard(ra)),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _utilizationCard(ResourceAllocation ra) {
    final util = ra.utilizationPct;
    final peak = ra.peakWeekUtilizationPct;
    final color = util < 80
        ? const Color(0xFF10B981)
        : util > 110
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);
    final peakColor = peak > 110
        ? const Color(0xFFEF4444)
        : peak > 90
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: ra.discipline.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6)),
              child: Icon(Icons.person_outline,
                  color: ra.discipline.color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(ra.resourceName,
                      style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  Text(
                      '${ra.discipline.label} • ${ra.capacityHoursPerWeek.round()}h capacity/wk',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 11)),
                ])),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6)),
              child: Text('${util.toStringAsFixed(0)}% util',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 8),
          // Utilization bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (util / 100).clamp(0.0, 1.5),
              backgroundColor: const Color(0xFFE4E7EC),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Avg: ${ra.avgWeekly.toStringAsFixed(1)}h/wk • Peak: ${ra.weeklyHours.reduce((a, b) => a > b ? a : b).toStringAsFixed(0)}h (${peak.toStringAsFixed(0)}%)',
                    style: TextStyle(
                        color: peakColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                Text('Total: ${ra.totalAllocated.round()}h',
                    style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// TAB: Reporting & Audit
// ═════════════════════════════════════════════════════════════════════════

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reporting & Audit',
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text(
                      'Generate reports and trace every change through the audit trail',
                      style: TextStyle(
                          color: Color(0xFF6B7280), fontSize: 13)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showGenerateDialog(context),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: const Text('Generate Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.accent,
                foregroundColor: LightModeColors.lightOnPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          // Reports list
          const Text('GENERATED REPORTS',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          if (reports.isEmpty)
            _emptyState('No reports generated yet',
                Icons.description_outlined)
          else
            ...reports.reversed.map((r) => _reportCard(r)),
          const SizedBox(height: 24),
          // Audit trail
          Row(children: [
            const Text('AUDIT TRAIL',
                style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(width: 12),
            Text('${filteredAudit.length} of ${widget.state.auditTrail.length} entries',
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 11)),
          ]),
          const SizedBox(height: 12),
          // Filters
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E7EC))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFFE4E7EC))),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _actorFilter,
                          isExpanded: true,
                          hint: const Text('All actors'),
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null, child: Text('All actors')),
                            ...actors.map((a) => DropdownMenuItem(
                                value: a, child: Text(a))),
                          ],
                          onChanged: (v) =>
                              setState(() => _actorFilter = v),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Search action / reason…',
                        prefixIcon: Icon(Icons.search, size: 16),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(6)),
                            borderSide:
                                BorderSide(color: Color(0xFFE4E7EC))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(6)),
                            borderSide:
                                BorderSide(color: Color(0xFFE4E7EC))),
                      ),
                      style: const TextStyle(fontSize: 12),
                      onChanged: (v) =>
                          setState(() => _actionSearch = v),
                    ),
                  ),
                ],
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: _datePickField(
                        'From date', _fromDate, (d) => setState(() {
                              _fromDate = d;
                            })),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _datePickField(
                        'To date', _toDate, (d) => setState(() {
                              _toDate = d;
                            })),
                  ),
                  if (_fromDate != null || _toDate != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        _fromDate = null;
                        _toDate = null;
                      }),
                      child: const Text('Clear'),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Audit timeline
          if (filteredAudit.isEmpty)
            _emptyState('No audit entries match the current filters.',
                Icons.history_toggle_off)
          else
            ...filteredAudit.map((a) => _auditEntryCard(a)),
        ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE4E7EC))),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined,
              size: 14, color: Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                value == null
                    ? label
                    : '${value.day}/${value.month}/${value.year}',
                style: TextStyle(
                    color: value == null
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF0F172A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
        ),
      ),
    );
  }

  Widget _reportCard(ReportRecord r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE4E7EC))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: LightModeColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(r.type.icon, color: const Color(0xFFD97706), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(r.type.label,
                        style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                  Text(
                      '${r.generatedAt.day}/${r.generatedAt.month}/${r.generatedAt.year}',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 11)),
                ]),
                const SizedBox(height: 2),
                Text(
                    '${r.id} • by ${r.generatedBy} • range: ${r.dateRangeStart.day}/${r.dateRangeStart.month}–${r.dateRangeEnd.day}/${r.dateRangeEnd.month}/${r.dateRangeEnd.year}',
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(r.summaryText,
                      style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 11,
                          height: 1.4)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _downloadReport(r),
            icon: const Icon(Icons.download, color: Color(0xFF6366F1)),
            tooltip: 'Download',
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _auditEntryCard(AuditEntry a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E7EC))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot
          Container(
            margin: const EdgeInsets.only(top: 4),
            child: Column(children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: LightModeColors.accent,
                    shape: BoxShape.circle),
              ),
              Container(
                width: 2,
                height: 32,
                color: const Color(0xFFE4E7EC),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFF6366F1)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(a.field,
                        style: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                      '${a.timestamp.day}/${a.timestamp.month}/${a.timestamp.year} ${a.timestamp.hour.toString().padLeft(2, '0')}:${a.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                Text(a.reason ?? '(no reason recorded)',
                    style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Row(children: [
                  Text('by ${a.user}',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 10)),
                  const SizedBox(width: 12),
                  if (a.previousValue.isNotEmpty ||
                      a.newValue.isNotEmpty)
                    Text('${a.previousValue.isEmpty ? "—" : a.previousValue} → ${a.newValue.isEmpty ? "—" : a.newValue}',
                        style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 10,
                            fontStyle: FontStyle.italic)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFFE4E7EC),
              style: BorderStyle.solid)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: const Color(0xFF6B7280), size: 18),
        const SizedBox(width: 8),
        Text(message,
            style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 13)),
      ]),
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
          title: const Text('Generate Report'),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Report Type',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFE4E7EC))),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ReportType>(
                      value: selectedType,
                      isExpanded: true,
                      items: ReportType.values
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Row(children: [
                                Icon(t.icon, size: 16,
                                    color: const Color(0xFFD97706)),
                                const SizedBox(width: 8),
                                Text(t.label),
                              ])))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => selectedType = v);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Date Range',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(children: [
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFE4E7EC))),
                        child: Text(
                            'From: ${startDate.day}/${startDate.month}/${startDate.year}',
                            style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFE4E7EC))),
                        child: Text(
                            'To: ${endDate.day}/${endDate.month}/${endDate.year}',
                            style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                widget.provider.generateReport(
                    selectedType, startDate, endDate);
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.accent,
                foregroundColor: LightModeColors.lightOnPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }

  void _downloadReport(ReportRecord r) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Downloading ${r.type.label} (${r.dateRangeStart.day}/${r.dateRangeStart.month}–${r.dateRangeEnd.day}/${r.dateRangeEnd.month})…'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
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
