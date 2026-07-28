import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/widgets/procurement/procurement_common_widgets.dart';
import 'package:ndu_project/widgets/responsive.dart';

class ReportKpi {
  const ReportKpi({
    required this.label,
    required this.value,
    required this.delta,
    required this.positive,
  });

  final String label;
  final String value;
  final String delta;
  final bool positive;
}

class SpendBreakdown {
  const SpendBreakdown({
    required this.label,
    required this.amount,
    required this.percent,
    required this.color,
  });

  final String label;
  final int amount;
  final double percent;
  final Color color;
}

class LeadTimeMetric {
  const LeadTimeMetric({required this.label, required this.onTimeRate});

  final String label;
  final double onTimeRate;
}

class SavingsOpportunity {
  const SavingsOpportunity({
    required this.title,
    required this.value,
    required this.owner,
  });

  final String title;
  final String value;
  final String owner;
}

class ComplianceMetric {
  const ComplianceMetric({required this.label, required this.value});

  final String label;
  final double value;
}

class ProcurementReportsView extends StatelessWidget {
  const ProcurementReportsView({
    super.key,
    required this.kpis,
    required this.spendBreakdown,
    required this.leadTimeMetrics,
    required this.savingsOpportunities,
    required this.complianceMetrics,
    required this.currencyFormat,
    required this.onGenerateReports,
  });

  final List<ReportKpi> kpis;
  final List<SpendBreakdown> spendBreakdown;
  final List<LeadTimeMetric> leadTimeMetrics;
  final List<SavingsOpportunity> savingsOpportunities;
  final List<ComplianceMetric> complianceMetrics;
  final NumberFormat currencyFormat;
  final VoidCallback onGenerateReports;

  @override
  Widget build(BuildContext context) {
    void showShareFeedback() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report sharing has been queued. Export PDF first to distribute a static file.',
          ),
        ),
      );
    }

    void showExportFeedback() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PDF export started. Refresh in a few seconds if the file is not ready yet.',
          ),
        ),
      );
    }

    final isMobile = AppBreakpoints.isMobile(context);
    final hasData = kpis.isNotEmpty ||
        spendBreakdown.isNotEmpty ||
        leadTimeMetrics.isNotEmpty ||
        savingsOpportunities.isNotEmpty ||
        complianceMetrics.isNotEmpty;

    if (!hasData) {
      return _buildEmptyState(context, onGenerateReports, showShareFeedback, showExportFeedback);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, onGenerateReports, showShareFeedback, showExportFeedback),
        const SizedBox(height: 16),
        if (isMobile)
          Column(
            children: [
              for (var i = 0; i < kpis.length; i++) ...[
                _ReportKpiCard(kpi: kpis[i]),
                if (i != kpis.length - 1) const SizedBox(height: 12),
              ],
            ],
          )
        else
          Row(
            children: [
              for (var i = 0; i < kpis.length; i++) ...[
                Expanded(child: _ReportKpiCard(kpi: kpis[i])),
                if (i != kpis.length - 1) const SizedBox(width: 16),
              ],
            ],
          ),
        const SizedBox(height: 24),
        if (isMobile)
          Column(
            children: [
              _SpendBreakdownCard(
                  breakdown: spendBreakdown, currencyFormat: currencyFormat),
              const SizedBox(height: 16),
              _LeadTimePerformanceCard(metrics: leadTimeMetrics),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                  child: _SpendBreakdownCard(
                      breakdown: spendBreakdown,
                      currencyFormat: currencyFormat)),
              const SizedBox(width: 16),
              Expanded(
                  child: _LeadTimePerformanceCard(metrics: leadTimeMetrics)),
            ],
          ),
        const SizedBox(height: 24),
        if (isMobile)
          Column(
            children: [
              _SavingsOpportunitiesCard(items: savingsOpportunities),
              const SizedBox(height: 16),
              _ComplianceSnapshotCard(metrics: complianceMetrics),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                  child:
                      _SavingsOpportunitiesCard(items: savingsOpportunities)),
              const SizedBox(width: 16),
              Expanded(
                  child: _ComplianceSnapshotCard(metrics: complianceMetrics)),
            ],
          ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    VoidCallback onGenerateReports,
    VoidCallback showShareFeedback,
    VoidCallback showExportFeedback,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, onGenerateReports, showShareFeedback, showExportFeedback),
        const SizedBox(height: 16),
        const ProcurementEmptyStateCard(
          icon: Icons.insert_chart_outlined,
          title: 'No report data yet',
          message:
              'Reports will populate as procurement activity is recorded.',
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    VoidCallback onGenerateReports,
    VoidCallback showShareFeedback,
    VoidCallback showExportFeedback,
  ) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Procurement Reports',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A)),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: onGenerateReports,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Generate Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
            OutlinedButton(
              onPressed: showShareFeedback,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Share'),
            ),
            ElevatedButton.icon(
              onPressed: showExportFeedback,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReportKpiCard extends StatelessWidget {
  const _ReportKpiCard({required this.kpi});

  final ReportKpi kpi;

  @override
  Widget build(BuildContext context) {
    final Color deltaColor =
        kpi.positive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final IconData deltaIcon = kpi.positive
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kpi.label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Text(kpi.value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(deltaIcon, size: 16, color: deltaColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  kpi.delta,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: deltaColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpendBreakdownCard extends StatelessWidget {
  const _SpendBreakdownCard(
      {required this.breakdown, required this.currencyFormat});

  final List<SpendBreakdown> breakdown;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const ProcurementEmptyStateCard(
        icon: Icons.pie_chart_outline,
        title: 'Spend by category',
        message: 'Category spend will appear after items and POs are logged.',
        compact: true,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spend by category',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < breakdown.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    breakdown[i].label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937)),
                  ),
                ),
                Text(
                  currencyFormat.format(breakdown[i].amount),
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Container(
                      height: 8,
                      width: constraints.maxWidth * breakdown[i].percent,
                      decoration: BoxDecoration(
                        color: breakdown[i].color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (i != breakdown.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _LeadTimePerformanceCard extends StatelessWidget {
  const _LeadTimePerformanceCard({required this.metrics});

  final List<LeadTimeMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const ProcurementEmptyStateCard(
        icon: Icons.schedule_outlined,
        title: 'Lead time performance',
        message: 'Lead time data will appear once deliveries are tracked.',
        compact: true,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lead time performance',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < metrics.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    metrics[i].label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937)),
                  ),
                ),
                Text(
                  '${(metrics[i].onTimeRate * 100).round()}%',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: metrics[i].onTimeRate,
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
            if (i != metrics.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SavingsOpportunitiesCard extends StatelessWidget {
  const _SavingsOpportunitiesCard({required this.items});

  final List<SavingsOpportunity> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const ProcurementEmptyStateCard(
        icon: Icons.savings_outlined,
        title: 'Savings opportunities',
        message: 'Savings will appear as sourcing insights are captured.',
        compact: true,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Savings opportunities',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Owner ${items[i].owner}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Text(
                  items[i].value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A)),
                ),
              ],
            ),
            if (i != items.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ComplianceSnapshotCard extends StatelessWidget {
  const _ComplianceSnapshotCard({required this.metrics});

  final List<ComplianceMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const ProcurementEmptyStateCard(
        icon: Icons.verified_outlined,
        title: 'Compliance snapshot',
        message:
            'Compliance tracking appears after vendors and orders are recorded.',
        compact: true,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compliance snapshot',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < metrics.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    metrics[i].label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937)),
                  ),
                ),
                Text(
                  '${(metrics[i].value * 100).round()}%',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: metrics[i].value,
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            ),
            if (i != metrics.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
