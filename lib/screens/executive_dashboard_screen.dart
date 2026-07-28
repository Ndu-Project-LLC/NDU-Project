import 'package:flutter/material.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:provider/provider.dart';

class ExecutiveDashboardScreen extends StatefulWidget {
 const ExecutiveDashboardScreen({super.key});

 @override
 State<ExecutiveDashboardScreen> createState() =>
 _ExecutiveDashboardScreenState();
}

class _ExecutiveDashboardScreenState extends State<ExecutiveDashboardScreen> {
 @override
 Widget build(BuildContext context) {
 final sidebarWidth = AppBreakpoints.sidebarWidth(context);
 final projectData = context.watch<ProjectDataProvider>().projectData;
 final wps = projectData.workPackages;
 final accounts = projectData.controlAccounts;

 final bac = wps.fold<double>(0, (s, wp) => s + wp.budgetedCost);
 final ac = wps.fold<double>(0, (s, wp) => s + wp.actualCost);

 double ev = 0;
 for (final wp in wps) {
 if (wp.status == 'complete') {
 ev += wp.budgetedCost;
 } else if (wp.status == 'in_progress') {
 ev += wp.budgetedCost > 0
 ? (wp.actualCost / wp.budgetedCost).clamp(0, 1) * wp.budgetedCost
 : 0;
 }
 }

 final cpi = ac > 0 ? ev / ac : 1.0;
 final eac = cpi > 0 ? bac / cpi : bac;
 final vac = bac - eac;

 // Baseline vs forecast comparison
 final baselineBudget = bac;
 final forecastBudget = eac;
 final overrun = forecastBudget - baselineBudget;
 final overrunPct =
 baselineBudget > 0 ? (overrun / baselineBudget * 100) : 0;

 // Cash flow: total committed vs forecast
 final committed =
 projectData.costEstimateItems
 .where((c) => c.costState == 'committed')
 .fold<double>(0, (s, c) => s + c.amount);
 final forecastTotal =
 projectData.costEstimateItems
 .where((c) => c.costState == 'forecast')
 .fold<double>(0, (s, c) => s + c.amount);

 // Risk exposure from risk items
 final riskExposure = projectData.executionRiskItems.fold<double>(
 0,
 (s, r) =>
 s + r.likelihoodScore * r.impactScore * 1000); // scaled dollar proxy

 // Control account breakdown by status
 final activeCount =
 accounts.where((a) => a.status == 'active').length;
 final authorizedCount =
 accounts.where((a) => a.status == 'authorized').length;
 final closedCount =
 accounts.where((a) => a.status == 'closed').length;

 return Scaffold(
 backgroundColor: Colors.grey[50],
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: sidebarWidth,
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Executive Dashboard',
 ),
 ),
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 header('Executive Dashboard'),
 const SizedBox(height: 20),
 Row(
 children: [
 kpiCard('BAC', '\$${_fmt(bac)}',
 const Color(0xFF1E293B), Icons.dashboard),
 kpiCard('EAC', '\$${_fmt(eac)}',
 const Color(0xFF7C3AED), Icons.trending_up),
 kpiCard('VAC', '\$${_fmt(vac)}',
 vac >= 0
 ? const Color(0xFF059669)
 : const Color(0xFFDC2626),
 Icons.assessment),
 kpiCard('CPI', cpi.toStringAsFixed(2),
 _evmColor(cpi), Icons.speed),
 ],
 ),
 const SizedBox(height: 16),
 Row(
 children: [
 kpiCard('Baseline Budget',
 '\$${_fmt(baselineBudget)}',
 const Color(0xFF2563EB), Icons.account_balance),
 kpiCard('Forecast',
 '\$${_fmt(forecastBudget)}',
 const Color(0xFF7C3AED), Icons.trending_up),
 kpiCard('Overrun',
 '\$${_fmt(overrun)} (${overrunPct.toStringAsFixed(1)}%)',
 overrun >= 0
 ? const Color(0xFFDC2626)
 : const Color(0xFF059669),
 Icons.warning_amber),
 ],
 ),
 const SizedBox(height: 20),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: sectionCard(
 'Cash Flow Summary',
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 cashRow('Committed', committed,
 const Color(0xFFB45309)),
 const SizedBox(height: 8),
 cashRow('Forecast', forecastTotal,
 const Color(0xFF7C3AED)),
 const SizedBox(height: 8),
 cashRow(
 'Actual', ac, const Color(0xFF059669)),
 const SizedBox(height: 12),
 const Divider(),
 cashRow(
 'Total Exposure',
 committed + forecastTotal + ac,
 const Color(0xFF111827),
 bold: true,
 ),
 ],
 ),
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: sectionCard(
 'Risk Exposure',
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Risk-Adjusted Exposure',
 style: TextStyle(
 fontSize: 12,
 color: Colors.grey[600]),
 ),
 const SizedBox(height: 4),
 Text(
 '\$${_fmt(riskExposure)}',
 style: const TextStyle(
 fontSize: 28,
 fontWeight: FontWeight.w700,
 color: Color(0xFFDC2626),
 ),
 ),
 const SizedBox(height: 16),
 Text('Open risks: ${projectData.executionRiskItems.length}',
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF6B7280))),
 ],
 ),
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: sectionCard(
 'Control Account Status',
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 statusRow('Active', activeCount,
 const Color(0xFF059669)),
 const SizedBox(height: 8),
 statusRow('Authorized', authorizedCount,
 const Color(0xFF2563EB)),
 const SizedBox(height: 8),
 statusRow('Closed', closedCount,
 const Color(0xFF6B7280)),
 const SizedBox(height: 12),
 Text(
 '${accounts.length} total',
 style: const TextStyle(
 fontSize: 13,
 color: Color(0xFF9CA3AF)),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 sectionCard(
 'Control Account Breakdown',
 accounts.isEmpty
 ? const Text('No control accounts defined.',
 style: TextStyle(color: Color(0xFF9CA3AF)))
 : Column(
 children: accounts.map((ca) {
 final barWidth = bac > 0
 ? (ca.budgetAtCompletion / bac)
 .clamp(0, 1)
 .toDouble()
 : 0.0;
 return Container(
 margin:
 const EdgeInsets.only(bottom: 8),
 child: Row(
 children: [
 SizedBox(
 width: 180,
 child: Text(ca.title,
 style: const TextStyle(
 fontWeight:
 FontWeight.w500)),
 ),
 Expanded(
 child: ClipRRect(
 borderRadius:
 BorderRadius.circular(4),
 child:
 LinearProgressIndicator(
 value: barWidth,
 backgroundColor: const Color(
 0xFFE5E7EB),
 valueColor:
 AlwaysStoppedAnimation<
 Color>(
 ca.cpi >= 1.0
 ? const Color(
 0xFF059669)
 : ca.cpi >= 0.8
 ? const Color(
 0xFFD97706)
 : const Color(
 0xFFDC2626),
 ),
 minHeight: 12,
 ),
 ),
 ),
 const SizedBox(width: 12),
 SizedBox(
 width: 120,
 child: Text(
 '\$${_fmt(ca.budgetAtCompletion)}',
 textAlign: TextAlign.right,
 style: const TextStyle(
 fontWeight: FontWeight.w600),
 ),
 ),
 ],
 ),
 );
 }).toList(),
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

 String _fmt(double v) {
 if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
 if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
 return v.toStringAsFixed(0);
 }

 Widget header(String title) {
 return Text(
 title,
 style: const TextStyle(
 fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
 );
 }

 Widget kpiCard(String label, String value, Color color, IconData icon) {
 return Expanded(
 child: Container(
 margin: const EdgeInsets.symmetric(horizontal: 6),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Icon(icon, size: 16, color: color),
 const SizedBox(width: 6),
 Text(label,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: color)),
 ],
 ),
 const SizedBox(height: 8),
 Text(value,
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: color)),
 ],
 ),
 ),
 );
 }

 Widget sectionCard(String title, Widget content) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title,
 style:
 const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
 const SizedBox(height: 16),
 content,
 ],
 ),
 );
 }

 Widget cashRow(String label, double amount, Color color, {bool bold = false}) {
 return Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(label,
 style: TextStyle(
 fontSize: 14,
 fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
 color: const Color(0xFF6B7280))),
 Text('\$${_fmt(amount)}',
 style: TextStyle(
 fontSize: 14,
 fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
 color: color)),
 ],
 );
 }

 Widget statusRow(String label, int count, Color color) {
 return Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Row(
 children: [
 Container(
 width: 8,
 height: 8,
 decoration: BoxDecoration(
 color: color,
 shape: BoxShape.circle,
 ),
 ),
 const SizedBox(width: 8),
 Text(label,
 style: const TextStyle(
 fontSize: 14, color: Color(0xFF6B7280))),
 ],
 ),
 Text('$count',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: color)),
 ],
 );
 }

 Color _evmColor(double value) {
 if (value >= 1.0) return const Color(0xFF059669);
 if (value >= 0.8) return const Color(0xFFD97706);
 return const Color(0xFFDC2626);
 }
}
