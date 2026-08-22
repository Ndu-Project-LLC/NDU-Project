library;

/// Integration Dashboard — the unified view of Scope ↔ WBS ↔ Schedule ↔
/// Project Controls ↔ Cost Estimate, with the Integrated Baseline Review
/// (IBR) readiness gate front-and-center.
///
/// This screen is the operational answer to "how do Scope, WBS, Project
/// Controls, and Schedule interconnect?" — it surfaces:
///   • The current PMB (Performance Measurement Baseline) status as a
///     single IBR banner.
///   • Per-domain coverage KPIs (scope items / WBS leaves / schedule
///     activities / control accounts / cost lines).
///   • The 7-check IBR readiness breakdown.
///   • Quick-jump buttons to each module.
///   • EVM snapshot at-a-glance (BAC, EV, AC, CPI, SPI, EAC, VAC).
///   • Recent change requests (last 5) feeding back into the PMB.
///
/// The dashboard is read-only — it never mutates module state. Users
/// click through to the individual module screens to make changes.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/services/scope_coverage_validator.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/project_controls/providers/project_controls_provider.dart';
import 'package:ndu_project/project_controls/models/project_controls_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/services/ibr_service.dart';
import 'package:ndu_project/routing/app_router.dart';

// Local color tokens — keep the file self-contained. The codebase uses
// different theme patterns (LightModeColors / DarkModeColors / adaptive
// extensions on BuildContext) so we declare our own constants here.
class _Tk {
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
}

class IntegrationDashboardScreen extends StatefulWidget {
  const IntegrationDashboardScreen({super.key});

  @override
  State<IntegrationDashboardScreen> createState() =>
      _IntegrationDashboardScreenState();
}

class _IntegrationDashboardScreenState
    extends State<IntegrationDashboardScreen> {
  IbrReport? _report;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runIbr());
  }

  Future<void> _runIbr() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final project = context.read<ProjectDataProvider>().projectData;
      final wbs = context.read<WBSProvider>().wbs;
      final schedule = context.read<ScheduleProvider>().schedule;
      final controls = context.read<ProjectControlsProvider>().state;
      final estimate = context.read<CostEstimateProvider>().estimate;

      // Convert legacy scope items to the validator DTO. Note:
      // PlanningDashboardItem has no wbsId field in the legacy model,
      // so we pass scope items as text-only and let the validator
      // flag any that don't match by code (currently none will — they
      // are surfaced as "uncovered" until the user explicitly links
      // them to WBS nodes via the Scope Tracking Plan screen).
      final scopeItems = project.withinScopeItems
          .where((s) => s.description.trim().isNotEmpty)
          .map((s) => ScopeCoverageInput(
                id: s.id,
                description: s.description,
                wbsNodeId: null,
                wbsCode: null,
              ))
          .toList();

      final report = IbrService.assess(
        project: project,
        wbs: wbs,
        schedule: schedule,
        costEstimate: estimate,
        controls: controls,
        scopeItems: scopeItems,
      );
      if (mounted) setState(() => _report = report);
    } catch (e) {
      debugPrint('IntegrationDashboard: IBR assess failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return ResponsiveScaffold(
      appBarTitle: 'Integration Dashboard',
      activeItemLabel: 'Integration Dashboard',
      body: RefreshIndicator(
        onRefresh: _runIbr,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _Header(
              onRefresh: _runIbr,
              loading: _loading,
            ),
            const SizedBox(height: 16),
            if (report == null && _loading)
              const _LoadingCard()
            else if (report == null)
              const _EmptyStateCard()
            else ...[
              _IbrBanner(report: report),
              const SizedBox(height: 16),
              _CoverageKpisRow(report: report),
              const SizedBox(height: 16),
              _IbrChecksCard(report: report),
              const SizedBox(height: 16),
              _EvmAndLinksRow(report: report),
              const SizedBox(height: 16),
              _ScopeCoverageDetailsCard(report: report),
              const SizedBox(height: 16),
              _ModuleLaunchpadsRow(),
              const SizedBox(height: 96),
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Header
// ──────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool loading;
  const _Header({required this.onRefresh, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Integration Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _Tk.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'The Performance Measurement Baseline (PMB) is the integration '
                'of Scope, WBS, Schedule, and Cost. This dashboard shows the '
                'current integration state and the Integrated Baseline '
                'Review (IBR) readiness gate.',
                style: TextStyle(
                  fontSize: 14,
                  color: _Tk.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: loading ? null : onRefresh,
          icon: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          label: const Text('Re-run IBR'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// IBR banner
// ──────────────────────────────────────────────────────────────────────

class _IbrBanner extends StatelessWidget {
  final IbrReport report;
  const _IbrBanner({required this.report});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (report.overallStatus) {
      IbrStatus.passed => (const Color(0xFF10B981), Icons.check_circle),
      IbrStatus.attention => (const Color(0xFFF59E0B), Icons.warning_amber),
      IbrStatus.blocked => (const Color(0xFFEF4444), Icons.block),
      IbrStatus.notAssessed => (Colors.grey, Icons.help_outline),
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IBR — ${report.overallStatus.name.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report.summary,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _Tk.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _ScoreBadge(score: report.readinessScore),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;
  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0.0, 100.0);
    final color = clamped >= 90
        ? const Color(0xFF10B981)
        : clamped >= 60
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                value: clamped / 100,
                strokeWidth: 6,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Text(
              clamped.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Readiness',
          style: TextStyle(fontSize: 11, color: _Tk.textSecondary),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Coverage KPIs
// ──────────────────────────────────────────────────────────────────────

class _CoverageKpisRow extends StatelessWidget {
  final IbrReport report;
  const _CoverageKpisRow({required this.report});

  @override
  Widget build(BuildContext context) {
    final l = report.lifecycle;
    final kpis = <_KpiSpec>[
      _KpiSpec(
        label: 'Scope Items',
        value: '${l.workPackageCount > 0 ? l.workPackageCount : 0}',
        sub: 'work packages',
        color: const Color(0xFFB8860B),
      ),
      _KpiSpec(
        label: 'WBS Leaves',
        value: '${l.workPackageCount}',
        sub: '${l.fullyTracedWorkPackageCount} fully traced',
        color: const Color(0xFFFFC812),
      ),
      _KpiSpec(
        label: 'Schedule Activities',
        value: '${l.scheduleActivityCount}',
        sub: 'CPM activities',
        color: const Color(0xFFD97706),
      ),
      _KpiSpec(
        label: 'Control Accounts',
        value: '${l.controlAccountCount}',
        sub: 'EVM measurement points',
        color: const Color(0xFFF59E0B),
      ),
      _KpiSpec(
        label: 'Cost Lines',
        value: '${l.costLineCount}',
        sub: 'linked to WBS',
        color: const Color(0xFFD97706),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 1100
            ? 5
            : constraints.maxWidth > 700
                ? 3
                : 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: kpis
              .map((k) => SizedBox(
                    width: (constraints.maxWidth - 12 * (cols - 1)) / cols,
                    child: _KpiCard(spec: k),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _KpiSpec {
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _KpiSpec({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiSpec spec;
  const _KpiCard({required this.spec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: spec.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  spec.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _Tk.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            spec.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _Tk.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            spec.sub,
            style: const TextStyle(
              fontSize: 11,
              color: _Tk.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// IBR Checks Card
// ──────────────────────────────────────────────────────────────────────

class _IbrChecksCard extends StatelessWidget {
  final IbrReport report;
  const _IbrChecksCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check, size: 20),
              const SizedBox(width: 8),
              const Text(
                'IBR Readiness Checks',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _Tk.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${report.passedCount}/${report.totalChecks} passed',
                style: const TextStyle(
                  fontSize: 13,
                  color: _Tk.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...report.checks.map((c) => _CheckRow(check: c)),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final IbrCheckResult check;
  const _CheckRow({required this.check});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (check.status) {
      IbrStatus.passed => (Icons.check_circle, const Color(0xFF10B981)),
      IbrStatus.attention => (Icons.warning_amber, const Color(0xFFF59E0B)),
      IbrStatus.blocked => (Icons.cancel, const Color(0xFFEF4444)),
      IbrStatus.notAssessed => (Icons.help_outline, Colors.grey),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _Tk.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  check.detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _Tk.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: LinearProgressIndicator(
              value: check.completion,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// EVM + Quick links row
// ──────────────────────────────────────────────────────────────────────

class _EvmAndLinksRow extends StatelessWidget {
  final IbrReport report;
  const _EvmAndLinksRow({required this.report});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final twoCol = c.maxWidth > 900;
        final children = [
          _EvmSummaryCard(report: report),
          _QuickLinksCard(),
        ];
        if (twoCol) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: children[0]),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: children[1]),
            ],
          );
        }
        return Column(children: [
          children[0],
          const SizedBox(height: 12),
          children[1],
        ]);
      },
    );
  }
}

class _EvmSummaryCard extends StatelessWidget {
  final IbrReport report;
  const _EvmSummaryCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final cs = report.lifecycle;
    // Portfolio-level EVM is sourced from the ProjectControlsState. We
    // approximate by reading the controls provider via context.
    final controls = context.read<ProjectControlsProvider>().state;
    final bac = controls.totalOriginalBudget;
    final ev = controls.totalEarnedValue;
    final ac = controls.totalActualCost;
    final pv = controls.totalPlannedValue;
    final cpi = controls.portfolioCPI;
    final spi = controls.portfolioSPI;
    final eac = controls.portfolioEAC;
    final vac = controls.portfolioVAC;

    final evmMetrics = <_EvmMetric>[
      _EvmMetric('BAC', bac, currency: true),
      _EvmMetric('EV', ev, currency: true),
      _EvmMetric('PV', pv, currency: true),
      _EvmMetric('AC', ac, currency: true),
      _EvmMetric('CPI', cpi, percent: true, ratio: true),
      _EvmMetric('SPI', spi, percent: true, ratio: true),
      _EvmMetric('EAC', eac, currency: true),
      _EvmMetric('VAC', vac, currency: true),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Portfolio EVM',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _Tk.textPrimary,
                ),
              ),
              const Spacer(),
              if (cs.evmReady)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'EVM READY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: evmMetrics.map((m) => _EvmCell(metric: m)).toList(),
          ),
        ],
      ),
    );
  }
}

class _EvmMetric {
  final String label;
  final double value;
  final bool currency;
  final bool percent;
  final bool ratio;
  const _EvmMetric(this.label, this.value,
      {this.currency = false, this.percent = false, this.ratio = false});
}

class _EvmCell extends StatelessWidget {
  final _EvmMetric metric;
  const _EvmCell({required this.metric});

  @override
  Widget build(BuildContext context) {
    String formatted;
    if (metric.ratio) {
      formatted = metric.value.toStringAsFixed(2);
    } else if (metric.currency) {
      formatted = '\$${_compactCurrency(metric.value)}';
    } else {
      formatted = metric.value.toStringAsFixed(0);
    }
    final color = metric.ratio
        ? (metric.value >= 1.0
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444))
        : _Tk.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          metric.label,
          style: const TextStyle(
            fontSize: 11,
            color: _Tk.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatted,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  String _compactCurrency(double v) {
    if (v.abs() >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(2)}M';
    } else if (v.abs() >= 1000) {
      return '${(v / 1000).toStringAsFixed(1)}K';
    }
    return v.toStringAsFixed(0);
  }
}

// ──────────────────────────────────────────────────────────────────────
// Quick links
// ──────────────────────────────────────────────────────────────────────

class _QuickLinksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final links = <_QuickLink>[
      const _QuickLink(
        label: 'WBS Builder',
        subtitle: 'Decompose scope',
        icon: Icons.account_tree,
        color: Color(0xFFFFC812),
        route: AppRoutes.wbs,
      ),
      const _QuickLink(
        label: 'Schedule',
        subtitle: 'Sequence activities',
        icon: Icons.calendar_month,
        color: Color(0xFFD97706),
        route: AppRoutes.schedule,
      ),
      const _QuickLink(
        label: 'Project Controls',
        subtitle: 'EVM & variances',
        icon: Icons.dashboard_customize,
        color: Color(0xFFF59E0B),
        route: AppRoutes.projectControls,
      ),
      const _QuickLink(
        label: 'Cost Estimate',
        subtitle: 'BAC & baseline',
        icon: Icons.attach_money,
        color: Color(0xFFD97706),
        route: AppRoutes.costEstimate,
      ),
      const _QuickLink(
        label: 'Change Management',
        subtitle: 'CCB & rebaseline',
        icon: Icons.sync_alt,
        color: Color(0xFFB8860B),
        route: AppRoutes.changeManagement,
      ),
      const _QuickLink(
        label: 'Project Baseline',
        subtitle: 'PMB snapshot',
        icon: Icons.lock,
        color: Color(0xFFB8860B),
        route: AppRoutes.projectBaseline,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.link, size: 20),
              SizedBox(width: 8),
              Text(
                'Quick Links',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _Tk.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: links
                .map((l) => _QuickLinkChip(link: l))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _QuickLink {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  const _QuickLink({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _QuickLinkChip extends StatelessWidget {
  final _QuickLink link;
  const _QuickLinkChip({required this.link});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/${link.route}'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: link.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: link.color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(link.icon, color: link.color, size: 16),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  link.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: link.color,
                  ),
                ),
                Text(
                  link.subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: _Tk.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Scope coverage details
// ──────────────────────────────────────────────────────────────────────

class _ScopeCoverageDetailsCard extends StatelessWidget {
  final IbrReport report;
  const _ScopeCoverageDetailsCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final cov = report.scopeCoverage;
    if (cov == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.rule_folder, size: 20),
              SizedBox(width: 8),
              Text(
                '100% Rule — Scope ↔ WBS Coverage',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _Tk.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 700 ? 3 : 1;
              final bars = <_CoverageBar>[
                _CoverageBar(
                  label: 'Scope coverage',
                  value: cov.scopeCoverageRatio,
                  detail:
                      '${cov.coveredScopeItemCount}/${cov.totalScopeItems} scope items traced to WBS',
                  color: const Color(0xFFB8860B),
                ),
                _CoverageBar(
                  label: 'WBS leaf trace',
                  value: cov.wbsLeafTraceRatio,
                  detail:
                      '${cov.tracedLeafCount}/${cov.totalWbsLeaves} leaves traced to scope',
                  color: const Color(0xFFFFC812),
                ),
                _CoverageBar(
                  label: 'WBS Dictionary complete',
                  value: cov.dictionaryCompletenessRatio,
                  detail:
                      '${cov.completeDictionaryCount}/${cov.totalWbsLeaves} leaves with full dictionary',
                  color: const Color(0xFFD97706),
                ),
              ];
              if (cols == 3) {
                return Row(
                  children: bars
                      .map((b) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: b,
                            ),
                          ))
                      .toList(),
                );
              }
              return Column(
                children: bars
                    .map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: b,
                        ))
                    .toList(),
              );
            },
          ),
          if (cov.uncoveredScopeItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            _GapList(
              title: 'Scope items not yet in WBS',
              icon: Icons.flag_outlined,
              color: const Color(0xFFEF4444),
              items: cov.uncoveredScopeItems
                  .map((s) => s.description)
                  .toList(growable: false),
            ),
          ],
          if (cov.orphanWbsLeaves.isNotEmpty) ...[
            const SizedBox(height: 12),
            _GapList(
              title: 'WBS leaves not traced to scope',
              icon: Icons.help_outline,
              color: const Color(0xFFF59E0B),
              items: cov.orphanWbsLeaves
                  .map((n) => '${n.code} — ${n.name}')
                  .toList(growable: false),
            ),
          ],
          if (cov.incompleteDictionaryLeaves.isNotEmpty) ...[
            const SizedBox(height: 12),
            _GapList(
              title: 'WBS leaves missing dictionary entry',
              icon: Icons.edit_note,
              color: const Color(0xFFB8860B),
              items: cov.incompleteDictionaryLeaves
                  .map((n) => '${n.code} — ${n.name}')
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoverageBar extends StatelessWidget {
  final String label;
  final double value;
  final String detail;
  final Color color;
  const _CoverageBar({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _Tk.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            FractionallySizedBox(
              widthFactor: pct / 100,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${pct.toStringAsFixed(0)}% — $detail',
          style: const TextStyle(
            fontSize: 11,
            color: _Tk.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _GapList extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  const _GapList({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              '$title (${items.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...items.take(8).map(
              (item) => Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•',
                        style: TextStyle(color: color, fontSize: 14)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _Tk.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        if (items.length > 8)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 4),
            child: Text(
              '+ ${items.length - 8} more…',
              style: const TextStyle(
                fontSize: 11,
                color: _Tk.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Module launchpads (footer row)
// ──────────────────────────────────────────────────────────────────────

class _ModuleLaunchpadsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub, size: 20),
              SizedBox(width: 8),
              Text(
                'PMB Integration Map',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _Tk.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'The four domains form a closed-loop control system. '
            'Scope defines the "what", WBS decomposes it, Schedule '
            'sequences it, and Project Controls measure performance '
            'against the integrated baseline (PMB). Change requests '
            'feed back through the CCB into rebaselining.',
            style: TextStyle(
              fontSize: 13,
              color: _Tk.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _IntegrationFlow(),
        ],
      ),
    );
  }
}

class _IntegrationFlow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final horizontal = c.maxWidth > 900;
        if (horizontal) {
          return const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _FlowNode('Scope', 'Statement', Icons.description,
                  Color(0xFFB8860B)),
              _FlowArrow(label: 'decomposes'),
              _FlowNode('WBS', 'Tree', Icons.account_tree,
                  Color(0xFFFFC812)),
              _FlowArrow(label: 'sequences'),
              _FlowNode('Schedule', 'Activities', Icons.calendar_month,
                  Color(0xFFD97706)),
              _FlowArrow(label: 'measures'),
              _FlowNode('Controls', 'EVM', Icons.dashboard_customize,
                  Color(0xFFF59E0B)),
              _FlowArrow(label: 'feeds back', reversed: true),
            ],
          );
        }
        return const Column(
          children: [
            _FlowNode('Scope', 'Statement', Icons.description,
                Color(0xFFB8860B)),
            _FlowArrow(label: 'decomposes'),
            _FlowNode('WBS', 'Tree', Icons.account_tree,
                Color(0xFFFFC812)),
            _FlowArrow(label: 'sequences'),
            _FlowNode('Schedule', 'Activities', Icons.calendar_month,
                Color(0xFFD97706)),
            _FlowArrow(label: 'measures'),
            _FlowNode('Controls', 'EVM', Icons.dashboard_customize,
                Color(0xFFF59E0B)),
          ],
        );
      },
    );
  }
}

class _FlowNode extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _FlowNode(this.title, this.subtitle, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: _Tk.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowArrow extends StatelessWidget {
  final String label;
  final bool reversed;
  const _FlowArrow({required this.label, this.reversed = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: _Tk.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
        Icon(
          reversed ? Icons.arrow_back : Icons.arrow_forward,
          size: 14,
          color: _Tk.textSecondary,
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Loading + empty states
// ──────────────────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Running Integrated Baseline Review…',
            style: TextStyle(fontSize: 14, color: _Tk.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        children: [
          Icon(Icons.insights, size: 48, color: _Tk.textSecondary),
          SizedBox(height: 12),
          Text(
            'No assessment yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _Tk.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Click "Re-run IBR" to assess the integration state of '
            'Scope, WBS, Schedule, and Project Controls.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _Tk.textSecondary),
          ),
        ],
      ),
    );
  }
}
