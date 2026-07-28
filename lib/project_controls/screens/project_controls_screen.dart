/// Project Controls Dashboard Screen
///
/// Embeds into the existing phase screen sidebar pattern.
/// Uses ResponsiveScaffold matching the existing UI.
///
/// Shows: executive KPIs, health indicators, EVM metrics (CPI/SPI),
/// work package summary, open change requests, variance alerts.

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

class ProjectControlsScreen extends StatefulWidget {
  const ProjectControlsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProjectControlsScreen()),
    );
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
          return ResponsiveScaffold(
            activeItemLabel: 'Project Controls',
            appBarTitle: 'Project Controls',
            breadcrumbPhase: 'Execution Phase',
            breadcrumbTitle: 'Project Controls',
            body: const PageShimmerSkeleton(),
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
                    SectionTab(icon: Icons.sync_alt, label: 'Change Mgmt'),
                    SectionTab(icon: Icons.trending_up, label: 'Forecasting'),
                    SectionTab(icon: Icons.history, label: 'Baseline Mgmt'),
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
          Text(value, style: TextStyle(color: const Color(0xFF0F172A), fontSize: 28, fontWeight: FontWeight.w900)),
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
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))), child: Row(children: [
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
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
                      color: color.withOpacity(0.85),
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
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.35)),
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
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: const Color(0xFFF59E0B),
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

class _BaselineMgmtTab extends StatefulWidget {
  final ProjectControlsState state;
  final ProjectControlsProvider provider;
  const _BaselineMgmtTab({required this.state, required this.provider});

  @override
  State<_BaselineMgmtTab> createState() => _BaselineMgmtTabState();
}

class _BaselineMgmtTabState extends State<_BaselineMgmtTab> {
  int? _compareAVersion;
  int? _compareBVersion;

  @override
  Widget build(BuildContext context) {
    final history = widget.state.baselineHistory;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Baseline Management',
                        style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text(
                        'Snapshots, version comparison and rollback control',
                        style: TextStyle(
                            color: Color(0xFF6B7280), fontSize: 13)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateBaselineDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Baseline'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightModeColors.accent,
                  foregroundColor: LightModeColors.lightOnPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // KPI strip
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount:
                MediaQuery.sizeOf(context).width > 800 ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.4,
            children: [
              _baselineKpi('Snapshots', '${history.length}',
                  Icons.history_outlined, const Color(0xFF6366F1)),
              _baselineKpi(
                  'Latest Version',
                  history.isEmpty ? '—' : 'v${history.last.version}',
                  Icons.layers_outlined,
                  const Color(0xFF10B981)),
              _baselineKpi(
                  'Current BAC',
                  '\$${(widget.state.totalOriginalBudget / 1000000).toStringAsFixed(2)}M',
                  Icons.account_balance_wallet_outlined,
                  const Color(0xFFD97706)),
              _baselineKpi(
                  'Work Packages',
                  '${widget.state.workPackages.length}',
                  Icons.account_tree_outlined,
                  const Color(0xFF8B5CF6)),
            ],
          ),
          const SizedBox(height: 24),
          // Snapshot list
          const Text('SNAPSHOT HISTORY',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          if (history.isEmpty)
            _emptyState('No baselines locked yet', Icons.history_toggle_off)
          else
            ...history.reversed.map((b) => _snapshotCard(b, history)),
          const SizedBox(height: 24),
          // Compare baselines
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E7EC))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('COMPARE BASELINES',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _baselineVersionDropdown(
                          'Baseline A', _compareAVersion, (v) {
                    setState(() => _compareAVersion = v);
                  })),
                  const SizedBox(width: 12),
                  const Icon(Icons.compare_arrows,
                      color: Color(0xFF6B7280)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _baselineVersionDropdown(
                          'Baseline B', _compareBVersion, (v) {
                    setState(() => _compareBVersion = v);
                  })),
                ]),
                const SizedBox(height: 16),
                if (_compareAVersion != null &&
                    _compareBVersion != null &&
                    _compareAVersion != _compareBVersion)
                  _baselineDiffTable(
                      history.firstWhere((b) => b.version == _compareAVersion),
                      history
                          .firstWhere((b) => b.version == _compareBVersion))
                else if (_compareAVersion != null &&
                    _compareBVersion != null &&
                    _compareAVersion == _compareBVersion)
                  const Text(
                      'Pick two different baselines to see the diff.',
                      style:
                          TextStyle(color: Color(0xFF6B7280), fontSize: 12))
                else
                  const Text(
                      'Select two baselines above to view a field-by-field delta.',
                      style:
                          TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _baselineKpi(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E7EC))),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              Text(value,
                  style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _snapshotCard(BaselineSnapshot b, List<BaselineSnapshot> all) {
    final isLatest = all.isNotEmpty && b.version == all.last.version;
    final dateStr =
        '${b.lockedAt.day}/${b.lockedAt.month}/${b.lockedAt.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isLatest
                  ? LightModeColors.accent.withValues(alpha: 0.5)
                  : const Color(0xFFE4E7EC))),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12))),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: LightModeColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.layers_outlined,
                  color: Color(0xFFD97706), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text('v${b.version} • ${b.type.label}',
                        style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    if (isLatest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color:
                                LightModeColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('CURRENT',
                            style: TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                  Text('$dateStr • by ${b.lockedBy}',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 11)),
                ])),
            TextButton.icon(
              onPressed: isLatest
                  ? null
                  : () => _confirmRollback(b),
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('Roll back'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                disabledForegroundColor: const Color(0xFF9CA3AF),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (b.reason != null && b.reason!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.flag_outlined,
                            color: Color(0xFF6B7280), size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Reason: ${b.reason}',
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ]),
                ),
              Row(children: [
                Expanded(
                    child: _metaCell('BAC',
                        '\$${(b.totalBudget / 1000000).toStringAsFixed(2)}M')),
                Expanded(
                    child: _metaCell(
                        'WPs', '${b.workPackages.length}')),
                Expanded(
                    child: _metaCell(
                        'Scope Hash', b.scopeHashOrDerived)),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _metaCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(6)),
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
                    fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
    );
  }

  Widget _baselineVersionDropdown(
      String label, int? value, ValueChanged<int?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E7EC))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          hint: Text(label),
          style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 13,
              fontWeight: FontWeight.w600),
          dropdownColor: Colors.white,
          items: [
            for (final b in widget.state.baselineHistory)
              DropdownMenuItem<int?>(
                  value: b.version, child: Text('v${b.version} (${b.type.label})')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _baselineDiffTable(BaselineSnapshot a, BaselineSnapshot b) {
    final rows = <_DiffRow>[
      _DiffRow('Version', 'v${a.version}', 'v${b.version}'),
      _DiffRow('Type', a.type.label, b.type.label),
      _DiffRow('Locked at',
          '${a.lockedAt.day}/${a.lockedAt.month}/${a.lockedAt.year}',
          '${b.lockedAt.day}/${b.lockedAt.month}/${b.lockedAt.year}'),
      _DiffRow('Locked by', a.lockedBy, b.lockedBy),
      _DiffRow(
          'BAC',
          '\$${(a.totalBudget / 1000000).toStringAsFixed(2)}M',
          '\$${(b.totalBudget / 1000000).toStringAsFixed(2)}M'),
      _DiffRow('Work packages', '${a.workPackages.length}',
          '${b.workPackages.length}'),
      _DiffRow('Reason', a.reason ?? '—', b.reason ?? '—'),
      _DiffRow('Scope hash', a.scopeHashOrDerived, b.scopeHashOrDerived),
    ];
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E7EC))),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Row(children: const [
              Expanded(flex: 3, child: Text('Field',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
              Expanded(flex: 4, child: Text('Baseline A',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
              Expanded(flex: 4, child: Text('Baseline B',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
              Expanded(flex: 1, child: Text('Δ',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
            ]),
          ),
          ...rows.map((r) => Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                    color: r.changed
                        ? const Color(0xFFFFF4CC).withValues(alpha: 0.4)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4)),
                child: Row(children: [
                  Expanded(
                      flex: 3,
                      child: Text(r.field,
                          style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 11,
                              fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 4,
                      child: Text(r.a,
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  Expanded(
                      flex: 4,
                      child: Text(r.b,
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  Expanded(
                      flex: 1,
                      child: r.changed
                          ? const Icon(Icons.arrow_forward,
                              color: Color(0xFFD97706), size: 14)
                          : const Icon(Icons.check,
                              color: Color(0xFF10B981), size: 14)),
                ]),
              )),
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

  void _showCreateBaselineDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    BaselineType selectedType = BaselineType.scope;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Create New Baseline'),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Baseline Type',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: const Color(0xFFE4E7EC))),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BaselineType>(
                      value: selectedType,
                      isExpanded: true,
                      items: BaselineType.values
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(t.label)))
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
                const Text('Reason / description',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g. Quarterly baseline refresh after CR-001',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Color(0xFFE4E7EC))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Color(0xFFE4E7EC))),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                widget.provider.createBaselineSnapshot(
                    selectedType,
                    reasonCtrl.text.trim().isEmpty
                        ? 'Manual baseline lock'
                        : reasonCtrl.text.trim());
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.accent,
                foregroundColor: LightModeColors.lightOnPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Lock Baseline'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRollback(BaselineSnapshot b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm rollback'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
            'Rolling back to baseline v${b.version} will restore ${b.workPackages.length} work packages and \$${(b.totalBudget / 1000000).toStringAsFixed(2)}M budget. Subsequent baseline history will be retained as audit records. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              widget.provider.rollbackToBaseline(b.version);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Roll back'),
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
            child: Row(children: const [
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
                decoration: BoxDecoration(
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
    final labelStyle = TextStyle(
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
    labelPainter.text = TextSpan(
        text: 'Probability →',
        style: TextStyle(
            color: const Color(0xFF6B7280),
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
    final weeks = 6;
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
    final labelStyle = TextStyle(
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
