import 'package:flutter/material.dart';
import 'package:ndu_project/models/control_account_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/change_request_service.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

class OperationsControlScreen extends StatefulWidget {
 const OperationsControlScreen({super.key});

 @override
 State<OperationsControlScreen> createState() =>
 _OperationsControlScreenState();
}

class _OperationsControlScreenState extends State<OperationsControlScreen> {
 @override
 Widget build(BuildContext context) {
 final sidebarWidth = AppBreakpoints.sidebarWidth(context);
 final projectData = context.watch<ProjectDataProvider>().projectData;
 final wps = projectData.workPackages;
 final activities = projectData.scheduleActivities;
 final risks = projectData.executionRiskItems;
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
 final cv = ev - ac;

 final totalRiskScore =
 risks.fold<int>(0, (s, r) => s + r.likelihoodScore * r.impactScore);
 final openRisks = risks.where((r) => r.status != 'closed').length;
 final completedActivities =
 activities.where((a) => a.status == 'complete').length;

 final isMobile = AppBreakpoints.isMobile(context);

 final content = SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(title: 'Operations Control', onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 header('Operations Control Board'),
 const SizedBox(height: 20),
 evmMetricsRow(bac, ev, ac, cpi, cv, eac),
 const SizedBox(height: 20),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: scheduleSummaryCard(
 activities.length, completedActivities),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: riskSummaryCard(openRisks, totalRiskScore),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: changeRequestSummaryCard(),
 ),
 ],
 ),
 const SizedBox(height: 20),
 controlAccountTable(accounts),
 ],
 ),
 );

 if (isMobile) {
 return Scaffold(
 backgroundColor: Colors.grey[50],
 drawer: Drawer(
 width: sidebarWidth,
 child: SafeArea(
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Operations Control',
 ),
 ),
 ),
 body: SafeArea(
 child: Column(
 children: [
 Expanded(
 child: Stack(
 children: [
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Operations Control',
 ),
 ),
 content,
 const Positioned(
 right: 24,
 bottom: 24,
 child: KazAiChatBubble(positioned: false),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 return Scaffold(
 backgroundColor: Colors.grey[50],
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: sidebarWidth,
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Operations Control',
 ),
 ),
 Expanded(child: content),
 ],
 ),
 ),
 );
 }

 Widget header(String title) {
 return Text(
 title,
 style: const TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 );
 }

 Widget evmMetricsRow(
 double bac, double ev, double ac, double cpi, double cv, double eac) {
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
 const Text(
 'EVM Summary',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
 ),
 const SizedBox(height: 16),
 Row(
 children: [
 metricCard('BAC', '\$${bac.toStringAsFixed(0)}',
 const Color(0xFF1E293B)),
 metricCard('EV', '\$${ev.toStringAsFixed(0)}',
 const Color(0xFF059669)),
 metricCard('AC', '\$${ac.toStringAsFixed(0)}',
 const Color(0xFFB45309)),
 metricCard('CPI', cpi.toStringAsFixed(2), _evmColor(cpi)),
 metricCard('CV', '\$${cv.toStringAsFixed(0)}',
 cv >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)),
 metricCard('EAC', '\$${eac.toStringAsFixed(0)}',
 const Color(0xFF7C3AED)),
 ],
 ),
 ],
 ),
 );
 }

 Widget metricCard(String label, String value, Color color) {
 return Expanded(
 child: Container(
 margin: const EdgeInsets.symmetric(horizontal: 4),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.08),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: color)),
 const SizedBox(height: 4),
 Text(value,
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: color)),
 ],
 ),
 ),
 );
 }

 Color _evmColor(double value) {
 if (value >= 1.0) return const Color(0xFF059669);
 if (value >= 0.8) return const Color(0xFFD97706);
 return const Color(0xFFDC2626);
 }

 Widget scheduleSummaryCard(int total, int completed) {
 final pct = total > 0 ? (completed / total * 100).toStringAsFixed(0) : '0';
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
 const Text('Schedule',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
 const SizedBox(height: 12),
 Text('$completed / $total activities complete',
 style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
 const SizedBox(height: 8),
 LinearProgressIndicator(
 value: total > 0 ? completed / total : 0,
 backgroundColor: const Color(0xFFE5E7EB),
 valueColor:
 const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
 ),
 const SizedBox(height: 4),
 Text('$pct%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
 ],
 ),
 );
 }

 Widget riskSummaryCard(int openCount, int totalScore) {
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
 const Text('Risk Exposure',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
 const SizedBox(height: 12),
 Text('$openCount open risks',
 style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
 const SizedBox(height: 4),
 Text('Score: $totalScore',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: totalScore > 50
 ? const Color(0xFFDC2626)
 : const Color(0xFF059669))),
 ],
 ),
 );
 }

 Widget changeRequestSummaryCard() {
 return StreamBuilder<List<ChangeRequest>>(
 stream: ChangeRequestService.streamChangeRequests(),
 builder: (context, snapshot) {
 final crs = snapshot.data ?? [];
 final pending =
 crs.where((cr) => cr.status == 'Pending' || cr.status == 'pending').length;
 final approved = crs.where((cr) => cr.status == 'Approved' || cr.status == 'approved').length;
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
 const Text('Change Requests',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
 const SizedBox(height: 12),
 Text('$pending pending',
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFFD97706))),
 Text('$approved approved',
 style: const TextStyle(
 fontSize: 14, color: Color(0xFF6B7280))),
 ],
 ),
 );
 },
 );
 }

 Widget controlAccountTable(List<ControlAccount> accounts) {
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
 const Text('Control Accounts',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
 const SizedBox(height: 16),
 if (accounts.isEmpty)
 const Text('No control accounts defined.',
 style: TextStyle(color: Color(0xFF9CA3AF)))
 else
 ...accounts.map((ca) {
 final color = ca.cpi >= 1.0
 ? const Color(0xFF059669)
 : ca.cpi >= 0.8
 ? const Color(0xFFD97706)
 : const Color(0xFFDC2626);
 return Container(
 margin: const EdgeInsets.only(bottom: 8),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Row(
 children: [
 Expanded(
 flex: 2,
 child: Text(ca.title,
 style: const TextStyle(
 fontWeight: FontWeight.w600))),
 Expanded(
 child: Text('\$${ca.budgetAtCompletion.toStringAsFixed(0)}',
 style: const TextStyle(color: Color(0xFF6B7280)))),
 Expanded(
 child: Text('CPI: ${ca.cpi.toStringAsFixed(2)}',
 style: TextStyle(
 fontWeight: FontWeight.w600, color: color))),
 Expanded(
 child: Text('EV: \$${ca.earnedValue.toStringAsFixed(0)}',
 style: const TextStyle(color: Color(0xFF6B7280)))),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(ca.status.toUpperCase(),
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: color)),
 ),
 ],
 ),
 );
 }),
 ],
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Operations Control',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_operations_control_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}
