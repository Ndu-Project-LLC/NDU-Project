import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:ndu_project/project_controls/providers/project_controls_provider.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/ibr_service.dart';
import 'package:ndu_project/widgets/integration_dashboard/_integration_tokens.dart';
import 'package:ndu_project/widgets/integration_dashboard/integration_dashboard_parts.dart';

/// The baseline half of the Integration Dashboard.
///
/// Answers "is my Performance Measurement Baseline actually integrated?"
/// by running the Integrated Baseline Review (IBR) gate and presenting the
/// verdict, the per-domain coverage counts, the individual readiness checks,
/// the EVM snapshot, and the scope ↔ WBS 100%-Rule gaps.
///
/// Read-only by design: it never mutates module state. Every gap it reports
/// is paired with a jump straight to the module where the gap gets closed.
class IntegrationBaselineView extends StatelessWidget {
  const IntegrationBaselineView({
    super.key,
    required this.tokens,
    required this.report,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    this.projectLabel,
  });

  final IntegrationTokens tokens;
  final IbrReport? report;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  /// Name of the project the baseline belongs to, shown in the banner so the
  /// verdict is never ambiguous when several workspaces are in play.
  final String? projectLabel;

  @override
  Widget build(BuildContext context) {
    if (report == null && isLoading) {
      return IntegrationStatePanel(
        tokens: tokens,
        icon: Icons.hourglass_top_rounded,
        title: 'Running Integrated Baseline Review…',
        message: 'Checking the scope → WBS → schedule → cost → controls '
            'chain across the active project.',
        isBusy: true,
      );
    }

    final ibr = report;
    if (ibr == null) {
      return IntegrationStatePanel(
        tokens: tokens,
        icon: error == null ? Icons.insights_rounded : Icons.cloud_off_rounded,
        title: error == null ? 'No assessment yet' : 'Baseline unavailable',
        message: error ??
            'Run the Integrated Baseline Review to see whether Scope, WBS, '
                'Schedule, and Project Controls are integrated enough to '
                'lock the baseline.',
        accent: error == null ? tokens.brandDeep : tokens.bad,
        action: FilledButton.icon(
          onPressed: isLoading ? null : onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: tokens.brand,
            foregroundColor: tokens.onBrand,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text(
            'Run IBR assessment',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IbrBanner(
          tokens: tokens,
          report: ibr,
          projectLabel: projectLabel,
          onOpenBaseline: () => context.push('/${AppRoutes.projectBaseline}'),
        ),
        const SizedBox(height: 14),
        _CoverageKpis(tokens: tokens, report: ibr),
        const SizedBox(height: 14),
        _IbrChecksCard(tokens: tokens, report: ibr),
        const SizedBox(height: 14),
        _EvmAndLinksRow(tokens: tokens, report: ibr),
        const SizedBox(height: 14),
        _ScopeCoverageCard(tokens: tokens, report: ibr),
        const SizedBox(height: 14),
        _IntegrationMapCard(tokens: tokens),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Verdict banner
// ──────────────────────────────────────────────────────────────────────

class _IbrBanner extends StatelessWidget {
  const _IbrBanner({
    required this.tokens,
    required this.report,
    required this.onOpenBaseline,
    this.projectLabel,
  });

  final IntegrationTokens tokens;
  final IbrReport report;
  final VoidCallback onOpenBaseline;
  final String? projectLabel;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = statusVisual(tokens, report.overallStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 560;
          final text = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IBR · ${statusTitle(report.overallStatus)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: color,
                      ),
                    ),
                    if (projectLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        projectLabel!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: tokens.inkSoft,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      report.summary,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        IntegrationPill(
                          tokens: tokens,
                          label: '${report.passedCount}/${report.totalChecks} checks passed',
                          accent: tokens.good,
                        ),
                        if (report.blockedCount > 0)
                          IntegrationPill(
                            tokens: tokens,
                            label: '${report.blockedCount} blocking',
                            accent: tokens.bad,
                          ),
                        if (report.attentionCount > 0)
                          IntegrationPill(
                            tokens: tokens,
                            label: '${report.attentionCount} to review',
                            accent: tokens.warn,
                          ),
                        if (report.canLockBaseline)
                          IntegrationPill(
                            tokens: tokens,
                            label: 'Baseline may be locked',
                            accent: tokens.good,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final action = OutlinedButton.icon(
            onPressed: onOpenBaseline,
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.ink,
              side: BorderSide(color: tokens.outline),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.lock_outline_rounded, size: 16),
            label: const Text(
              'Project Baseline',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                const SizedBox(height: 16),
                action,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: text),
              const SizedBox(width: 16),
              Column(
                children: [
                  _ReadinessRing(tokens: tokens, score: report.readinessScore),
                  const SizedBox(height: 12),
                  action,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReadinessRing extends StatelessWidget {
  const _ReadinessRing({required this.tokens, required this.score});

  final IntegrationTokens tokens;
  final double score;

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0.0, 100.0);
    final color = clamped >= 90
        ? tokens.good
        : clamped >= 60
            ? tokens.warn
            : tokens.bad;
    return Semantics(
      label: 'Baseline readiness ${clamped.toStringAsFixed(0)} out of 100',
      child: Column(
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 78,
                  height: 78,
                  child: CircularProgressIndicator(
                    value: clamped / 100,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    backgroundColor: color.withValues(alpha: 0.16),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      clamped.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: color,
                      ),
                    ),
                    Text(
                      'READY',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: tokens.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Baseline readiness',
            style: TextStyle(fontSize: 11, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Coverage KPIs
// ──────────────────────────────────────────────────────────────────────

class _CoverageKpis extends StatelessWidget {
  const _CoverageKpis({required this.tokens, required this.report});

  final IntegrationTokens tokens;
  final IbrReport report;

  @override
  Widget build(BuildContext context) {
    final l = report.lifecycle;
    return IntegrationCard(
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntegrationSectionTitle(
            tokens: tokens,
            icon: Icons.hub_outlined,
            title: 'PMB Coverage',
            subtitle: 'How much of each domain is wired into the baseline.',
          ),
          const SizedBox(height: 14),
          IntegrationTileGrid(
            minTileWidth: 160,
            children: [
              IntegrationMiniKpi(
                tokens: tokens,
                label: 'Scope Items',
                value: '${l.workPackageCount}',
                icon: Icons.description_outlined,
                accent: tokens.brandDeep,
                hint: 'work packages decomposed from scope',
              ),
              IntegrationMiniKpi(
                tokens: tokens,
                label: 'WBS Leaves',
                value: '${l.workPackageCount}',
                icon: Icons.account_tree_outlined,
                accent: tokens.brandDeep,
                hint:
                    '${l.fullyTracedWorkPackageCount} of them fully traced',
              ),
              IntegrationMiniKpi(
                tokens: tokens,
                label: 'Schedule Activities',
                value: '${l.scheduleActivityCount}',
                icon: Icons.calendar_month_outlined,
                accent: tokens.brandDeep,
                hint: 'CPM activities in the network',
              ),
              IntegrationMiniKpi(
                tokens: tokens,
                label: 'Control Accounts',
                value: '${l.controlAccountCount}',
                icon: Icons.dashboard_customize_outlined,
                accent: tokens.brandDeep,
                hint: 'EVM measurement points',
              ),
              IntegrationMiniKpi(
                tokens: tokens,
                label: 'Cost Lines',
                value: '${l.costLineCount}',
                icon: Icons.attach_money_outlined,
                accent: tokens.brandDeep,
                hint: 'cost lines linked to the WBS',
              ),
            ],
          ),
        ],
      ),
    );
  }
}



// ──────────────────────────────────────────────────────────────────────
// Readiness checks
// ──────────────────────────────────────────────────────────────────────

class _IbrChecksCard extends StatelessWidget {
  const _IbrChecksCard({required this.tokens, required this.report});

  final IntegrationTokens tokens;
  final IbrReport report;

  @override
  Widget build(BuildContext context) {
    return IntegrationCard(
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntegrationSectionTitle(
            tokens: tokens,
            icon: Icons.fact_check_outlined,
            title: 'IBR Readiness Checks',
            subtitle: 'Each check must pass before the baseline can be locked.',
            trailing: IntegrationPill(
              tokens: tokens,
              label: '${report.passedCount}/${report.totalChecks}',
              accent: report.passedCount == report.totalChecks
                  ? tokens.good
                  : tokens.warn,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < report.checks.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: tokens.outlineSoft),
            _CheckRow(tokens: tokens, check: report.checks[i]),
          ],
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.tokens, required this.check});

  final IntegrationTokens tokens;
  final IbrCheckResult check;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = statusVisual(tokens, check.status);
    final pct = (check.completion * 100).clamp(0.0, 100.0);

    return Semantics(
      label: '${check.label}: ${statusTitle(check.status)}. ${check.detail}',
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          check.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: tokens.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    check.detail,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: tokens.muted,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 5,
                      backgroundColor: tokens.surfaceSunken,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// EVM + quick links
// ──────────────────────────────────────────────────────────────────────

class _EvmAndLinksRow extends StatelessWidget {
  const _EvmAndLinksRow({required this.tokens, required this.report});

  final IntegrationTokens tokens;
  final IbrReport report;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth > 900;
        final evm = _EvmSummaryCard(tokens: tokens, report: report);
        final links = _QuickLinksCard(tokens: tokens);
        if (twoCol) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: evm),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: links),
            ],
          );
        }
        return Column(
          children: [evm, const SizedBox(height: 14), links],
        );
      },
    );
  }
}

class _EvmSummaryCard extends StatelessWidget {
  const _EvmSummaryCard({required this.tokens, required this.report});

  final IntegrationTokens tokens;
  final IbrReport report;

  @override
  Widget build(BuildContext context) {
    // Watched (not read) so the snapshot tracks edits made on the Controls
    // screen without needing a manual re-run of the IBR.
    final controls = context.watch<ProjectControlsProvider>().state;

    final metrics = <_EvmMetric>[
      _EvmMetric('BAC', controls.totalOriginalBudget, currency: true),
      _EvmMetric('PV', controls.totalPlannedValue, currency: true),
      _EvmMetric('EV', controls.totalEarnedValue, currency: true),
      _EvmMetric('AC', controls.totalActualCost, currency: true),
      _EvmMetric('CPI', controls.portfolioCPI, ratio: true),
      _EvmMetric('SPI', controls.portfolioSPI, ratio: true),
      _EvmMetric('EAC', controls.portfolioEAC, currency: true),
      _EvmMetric('VAC', controls.portfolioVAC, currency: true),
    ];

    return IntegrationCard(
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntegrationSectionTitle(
            tokens: tokens,
            icon: Icons.trending_up_rounded,
            title: 'Earned Value Snapshot',
            subtitle: 'Portfolio-level EVM against the PMB.',
            trailing: report.lifecycle.evmReady
                ? IntegrationPill(
                    tokens: tokens,
                    label: 'EVM ready',
                    accent: tokens.good,
                    dot: false,
                  )
                : IntegrationPill(
                    tokens: tokens,
                    label: 'EVM pending',
                    accent: tokens.warn,
                    dot: false,
                  ),
          ),
          const SizedBox(height: 16),
          IntegrationTileGrid(
            minTileWidth: 130,
            children: [
              for (final m in metrics)
                _EvmCell(tokens: tokens, metric: m),
            ],
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
  final bool ratio;
  const _EvmMetric(this.label, this.value, {this.currency = false, this.ratio = false});

  String format() {
    if (ratio) return value.toStringAsFixed(2);
    if (currency) {
      if (value.abs() >= 1000000) {
        return '\$${(value / 1000000).toStringAsFixed(2)}M';
      }
      if (value.abs() >= 1000) return '\$${(value / 1000).toStringAsFixed(1)}K';
      return '\$${value.toStringAsFixed(0)}';
    }
    return value.toStringAsFixed(0);
  }
}

class _EvmCell extends StatelessWidget {
  const _EvmCell({required this.tokens, required this.metric});

  final IntegrationTokens tokens;
  final _EvmMetric metric;

  @override
  Widget build(BuildContext context) {
    final isRatio = metric.ratio;
    // A CPI/SPI of 1.00 is exactly on plan; anything under is a problem.
    final color = isRatio
        ? (metric.value >= 1.0 ? tokens.good : tokens.bad)
        : tokens.ink;
    return Semantics(
      label: '${metric.label} ${metric.format()}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.outlineSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              metric.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: tokens.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              metric.format(),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinksCard extends StatelessWidget {
  const _QuickLinksCard({required this.tokens});

  final IntegrationTokens tokens;

  static const _links = <_QuickLink>[
    _QuickLink(
      label: 'WBS Builder',
      subtitle: 'Decompose scope',
      icon: Icons.account_tree_outlined,
      route: AppRoutes.wbs,
    ),
    _QuickLink(
      label: 'Schedule',
      subtitle: 'Sequence activities',
      icon: Icons.calendar_month_outlined,
      route: AppRoutes.schedule,
    ),
    _QuickLink(
      label: 'Project Controls',
      subtitle: 'EVM & variances',
      icon: Icons.dashboard_customize_outlined,
      route: AppRoutes.projectControls,
    ),
    _QuickLink(
      label: 'Cost Estimate',
      subtitle: 'BAC & baseline',
      icon: Icons.attach_money_outlined,
      route: AppRoutes.costEstimate,
    ),
    _QuickLink(
      label: 'Change Management',
      subtitle: 'CCB & rebaseline',
      icon: Icons.sync_alt_rounded,
      route: AppRoutes.changeManagement,
    ),
    _QuickLink(
      label: 'Project Baseline',
      subtitle: 'PMB snapshot',
      icon: Icons.lock_outline_rounded,
      route: AppRoutes.projectBaseline,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return IntegrationCard(
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntegrationSectionTitle(
            tokens: tokens,
            icon: Icons.link_rounded,
            title: 'Jump to a Module',
            subtitle: 'Close any gap at its source.',
          ),
          const SizedBox(height: 14),
          for (final link in _links) ...[
            _QuickLinkTile(tokens: tokens, link: link),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _QuickLink {
  final String label;
  final String subtitle;
  final IconData icon;
  final String route;
  const _QuickLink({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({required this.tokens, required this.link});

  final IntegrationTokens tokens;
  final _QuickLink link;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/${link.route}'),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.outlineSoft),
          ),
          child: Row(
            children: [
              Icon(link.icon, size: 17, color: tokens.brandDeep),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      link.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.ink,
                      ),
                    ),
                    Text(
                      link.subtitle,
                      style: TextStyle(fontSize: 10.5, color: tokens.muted),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: tokens.mutedSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Scope ↔ WBS coverage
// ──────────────────────────────────────────────────────────────────────

class _ScopeCoverageCard extends StatelessWidget {
  const _ScopeCoverageCard({required this.tokens, required this.report});

  final IntegrationTokens tokens;
  final IbrReport report;

  @override
  Widget build(BuildContext context) {
    final cov = report.scopeCoverage;
    if (cov == null) return const SizedBox.shrink();

    final meters = [
      (
        'Scope coverage',
        cov.scopeCoverageRatio,
        '${cov.coveredScopeItemCount}/${cov.totalScopeItems} scope items traced into the WBS',
      ),
      (
        'WBS leaf trace',
        cov.wbsLeafTraceRatio,
        '${cov.tracedLeafCount}/${cov.totalWbsLeaves} leaves traced back to scope',
      ),
      (
        'WBS dictionary',
        cov.dictionaryCompletenessRatio,
        '${cov.completeDictionaryCount}/${cov.totalWbsLeaves} leaves with a full dictionary entry',
      ),
    ];

    return IntegrationCard(
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntegrationSectionTitle(
            tokens: tokens,
            icon: Icons.rule_folder_outlined,
            title: '100% Rule · Scope ↔ WBS',
            subtitle: 'Every scope item must live in the WBS, and every leaf '
                'must carry a dictionary entry.',
            trailing: IntegrationPill(
              tokens: tokens,
              label: cov.hundredPercentRuleSatisfied
                  ? 'Satisfied'
                  : 'Not satisfied',
              accent: cov.hundredPercentRuleSatisfied
                  ? tokens.good
                  : tokens.warn,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 620;
              final widgets = [
                for (final m in meters)
                  IntegrationMeter(
                    tokens: tokens,
                    label: m.$1,
                    value: m.$2,
                    detail: m.$3,
                    accent: tokens.brandDeep,
                  ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < widgets.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      widgets[i],
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < widgets.length; i++) ...[
                    if (i > 0) const SizedBox(width: 20),
                    Expanded(child: widgets[i]),
                  ],
                ],
              );
            },
          ),
          if (cov.uncoveredScopeItems.isNotEmpty) ...[
            const SizedBox(height: 18),
            Divider(height: 1, color: tokens.outlineSoft),
            const SizedBox(height: 16),
            IntegrationGapList(
              tokens: tokens,
              title: 'Scope items not yet in the WBS',
              icon: Icons.flag_outlined,
              accent: tokens.bad,
              items: cov.uncoveredScopeItems
                  .map((s) => s.description)
                  .toList(growable: false),
            ),
          ],
          if (cov.orphanWbsLeaves.isNotEmpty) ...[
            const SizedBox(height: 14),
            IntegrationGapList(
              tokens: tokens,
              title: 'WBS leaves not traced to scope',
              icon: Icons.help_outline_rounded,
              accent: tokens.warn,
              items: cov.orphanWbsLeaves
                  .map((n) => '${n.code} — ${n.name}')
                  .toList(growable: false),
            ),
          ],
          if (cov.incompleteDictionaryLeaves.isNotEmpty) ...[
            const SizedBox(height: 14),
            IntegrationGapList(
              tokens: tokens,
              title: 'WBS leaves missing a dictionary entry',
              icon: Icons.edit_note_rounded,
              accent: tokens.brandDeep,
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

// ──────────────────────────────────────────────────────────────────────
// Integration map
// ──────────────────────────────────────────────────────────────────────

class _IntegrationMapCard extends StatelessWidget {
  const _IntegrationMapCard({required this.tokens});

  final IntegrationTokens tokens;

  @override
  Widget build(BuildContext context) {
    return IntegrationCard(
      tokens: tokens,
      color: tokens.surfaceAlt,
      borderColor: tokens.outlineSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntegrationSectionTitle(
            tokens: tokens,
            icon: Icons.schema_outlined,
            title: 'How the domains interconnect',
            subtitle: 'Scope defines the "what", WBS decomposes it, Schedule '
                'sequences it, and Project Controls measure performance '
                'against the integrated baseline. Change requests feed back '
                'through the CCB into rebaselining.',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              const nodes = <_MapNode>[
                _MapNode('Scope', 'Statement', Icons.description_outlined),
                _MapNode('WBS', 'Work packages', Icons.account_tree_outlined),
                _MapNode('Schedule', 'Activities', Icons.calendar_month_outlined),
                _MapNode('Controls', 'EVM', Icons.dashboard_customize_outlined),
              ];
              const arrows = [
                'decomposes',
                'sequences',
                'measures',
              ];
              final horizontal = constraints.maxWidth >= 820;

              if (horizontal) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var i = 0; i < nodes.length; i++) ...[
                      if (i > 0)
                        Expanded(
                          child: _MapArrow(tokens: tokens, label: arrows[i - 1]),
                        ),
                      _MapNodeTile(tokens: tokens, node: nodes[i]),
                    ],
                  ],
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < nodes.length; i++) ...[
                    if (i > 0)
                      _MapArrow(
                        tokens: tokens,
                        label: arrows[i - 1],
                        vertical: true,
                      ),
                    _MapNodeTile(tokens: tokens, node: nodes[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MapNode {
  final String title;
  final String subtitle;
  final IconData icon;
  const _MapNode(this.title, this.subtitle, this.icon);
}

class _MapNodeTile extends StatelessWidget {
  const _MapNodeTile({required this.tokens, required this.node});

  final IntegrationTokens tokens;
  final _MapNode node;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(node.icon, color: tokens.brandDeep, size: 20),
            const SizedBox(height: 6),
            Text(
              node.title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: tokens.ink,
              ),
            ),
            Text(
              node.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: tokens.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapArrow extends StatelessWidget {
  const _MapArrow({
    required this.tokens,
    required this.label,
    this.vertical = false,
  });

  final IntegrationTokens tokens;
  final String label;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9.5,
            fontStyle: FontStyle.italic,
            color: tokens.muted,
          ),
        ),
        Icon(
          vertical
              ? Icons.arrow_downward_rounded
              : Icons.arrow_forward_rounded,
          size: 14,
          color: tokens.mutedSoft,
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Status presentation
// ──────────────────────────────────────────────────────────────────────

(Color, IconData) statusVisual(IntegrationTokens tokens, IbrStatus status) {
  switch (status) {
    case IbrStatus.passed:
      return (tokens.good, Icons.check_circle_rounded);
    case IbrStatus.attention:
      return (tokens.warn, Icons.warning_amber_rounded);
    case IbrStatus.blocked:
      return (tokens.bad, Icons.cancel_rounded);
    case IbrStatus.notAssessed:
      return (tokens.neutral, Icons.help_outline_rounded);
  }
}

String statusTitle(IbrStatus status) {
  switch (status) {
    case IbrStatus.passed:
      return 'PASSED';
    case IbrStatus.attention:
      return 'NEEDS ATTENTION';
    case IbrStatus.blocked:
      return 'BLOCKED';
    case IbrStatus.notAssessed:
      return 'NOT ASSESSED';
  }
}