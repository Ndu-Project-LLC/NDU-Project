import 'package:flutter/material.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/numeric_stepper_field.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:go_router/go_router.dart';

import 'package:ndu_project/widgets/delete_success_snackbar.dart';
class PunchlistActionsScreen extends StatefulWidget {
  const PunchlistActionsScreen({super.key});

  static void open(BuildContext context) {
    context.push('/punchlist-actions');
  }

  @override
  State<PunchlistActionsScreen> createState() => _PunchlistActionsScreenState();
}

class _PunchlistActionsScreenState extends State<PunchlistActionsScreen> {
  static const double _panelMinHeight = 200;

 List<_DistributionRow> _distributionRows = [];
 List<_ActionVelocityRow> _velocityRows = [];

 bool _isLoading = false;

 @override
 void initState() {
 super.initState();
 _distributionRows = _defaultDistributionRows();
 _velocityRows = _defaultVelocityRows();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromFirestore());
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 18 : 32;

 return Scaffold(
 backgroundColor: Theme.of(context).scaffoldBackgroundColor,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Punchlist Actions'),
 ),
 Expanded(
 child: Stack(
 children: [
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 28),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(
 title: 'Punchlist Actions',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 20),
 if (_isLoading)
 const LinearProgressIndicator(minHeight: 2),
 if (_isLoading) const SizedBox(height: 16),
 _buildSummaryGrid(context),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel('punchlist_actions'),
 nextLabel: PlanningPhaseNavigation.nextLabel('punchlist_actions'),
 onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'punchlist_actions'),
 onNext: () => PlanningPhaseNavigation.goToNext(context, 'punchlist_actions'),
 ),
 const SizedBox(height: 48),
 ],
 ),
 ),
 const MobileSidebarHamburger(
 sidebar: InitiationLikeSidebar(
 activeItemLabel: 'Punchlist Actions',
 ),
 ),
 const KazAiChatBubble(),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 void _showActionSnack(String message) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text(message)),
 );
 }

 String? _projectId() => ProjectDataHelper.getData(context).projectId;

 Future<void> _loadFromFirestore() async {
 final projectId = _projectId();
 if (projectId == null || projectId.isEmpty) return;
 setState(() => _isLoading = true);
 try {
 final doc = await _docRef(projectId).get();
 final data = doc.data() ?? {};
 // Load distribution and velocity table data
 final distData = data['distributionRows'];
 final velData = data['velocityRows'];
 if (distData != null && distData is List && distData.isNotEmpty) {
 _distributionRows = distData.map((e) => _DistributionRow.fromMap(e as Map<String, dynamic>)).toList();
 }
 if (velData != null && velData is List && velData.isNotEmpty) {
 _velocityRows = velData.map((e) => _ActionVelocityRow.fromMap(e as Map<String, dynamic>)).toList();
 }
 } catch (error) {
 debugPrint('Punchlist actions load error: $error');
 } finally {
 if (mounted) setState(() => _isLoading = false);
 }
 }

 Future<void> _saveToFirestore() async {
 final projectId = _projectId();
 if (projectId == null || projectId.isEmpty) return;
 try {
 await _docRef(projectId).set({
 'distributionRows': _distributionRows.map((e) => e.toMap()).toList(),
 'velocityRows': _velocityRows.map((e) => e.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));
 } catch (error) {
 debugPrint('Punchlist actions save error: $error');
 }
 }

 DocumentReference<Map<String, dynamic>> _docRef(String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('execution_phase_sections')
 .doc('punchlist_actions');
 }

 Widget _buildSummaryGrid(BuildContext context) {
 final cards = [
 _buildCompletionCard(),
 _buildDistributionCard(),
 _buildActionVelocityCard(),
 ];

 return _buildPanelGrid(cards, horizontalSpacing: 20, verticalSpacing: 20);
 }

 List<_DistributionRow> _defaultDistributionRows() => [
 const _DistributionRow(category: 'Systems', openItems: 44, critical: 8, high: 10, medium: 16, low: 10, closed: 38, owner: 'Systems Team', status: 'Active', lastUpdated: '2 hrs ago'),
 const _DistributionRow(category: 'Facilities', openItems: 28, critical: 4, high: 6, medium: 10, low: 8, closed: 22, owner: 'Facilities Management', status: 'Active', lastUpdated: '4 hrs ago'),
 const _DistributionRow(category: 'QA', openItems: 18, critical: 2, high: 2, medium: 8, low: 6, closed: 14, owner: 'QA Lead', status: 'Under Review', lastUpdated: '1 day ago'),
 const _DistributionRow(category: 'Integration', openItems: 30, critical: 3, high: 4, medium: 12, low: 11, closed: 25, owner: 'Integration Lead', status: 'Active', lastUpdated: '6 hrs ago'),
 const _DistributionRow(category: 'Field Ops', openItems: 22, critical: 5, high: 7, medium: 6, low: 4, closed: 18, owner: 'Field Ops Manager', status: 'Monitoring', lastUpdated: '3 hrs ago'),
 const _DistributionRow(category: 'Safety', openItems: 12, critical: 6, high: 4, medium: 2, low: 0, closed: 9, owner: 'Safety Officer', status: 'Active', lastUpdated: '1 hr ago'),
 const _DistributionRow(category: 'Compliance', openItems: 8, critical: 1, high: 2, medium: 3, low: 2, closed: 7, owner: 'Compliance Lead', status: 'Under Review', lastUpdated: '5 hrs ago'),
 ];

 List<_ActionVelocityRow> _defaultVelocityRows() => [
 const _ActionVelocityRow(workstream: 'Field execution', openItems: 44, closedThisSprint: 32, velocity: 72, throughput: 16.0, delta: '+8.2%', avgCycleTime: 2.4, period: 'Sprint 41-42', owner: 'Field Ops', status: 'On Track'),
 const _ActionVelocityRow(workstream: 'QA verification', openItems: 18, closedThisSprint: 14, velocity: 58, throughput: 7.0, delta: '+5.6%', avgCycleTime: 3.1, period: 'Sprint 41-42', owner: 'QA Lead', status: 'Improving'),
 const _ActionVelocityRow(workstream: 'Technical debt', openItems: 30, closedThisSprint: 12, velocity: 41, throughput: 6.0, delta: '-3.4%', avgCycleTime: 5.8, period: 'Sprint 41-42', owner: 'Platform Team', status: 'At Risk'),
 const _ActionVelocityRow(workstream: 'Remediation', openItems: 22, closedThisSprint: 18, velocity: 65, throughput: 9.0, delta: '+2.1%', avgCycleTime: 3.6, period: 'Sprint 41-42', owner: 'Operations', status: 'On Track'),
 const _ActionVelocityRow(workstream: 'Closure items', openItems: 15, closedThisSprint: 12, velocity: 53, throughput: 6.0, delta: '+4.8%', avgCycleTime: 4.2, period: 'Sprint 41-42', owner: 'PMO', status: 'Stable'),
 const _ActionVelocityRow(workstream: 'Safety', openItems: 12, closedThisSprint: 9, velocity: 78, throughput: 4.5, delta: '+11.0%', avgCycleTime: 1.8, period: 'Sprint 41-42', owner: 'Safety Officer', status: 'On Track'),
 ];

 Widget _buildPanelGrid(
 List<Widget> cards, {
 double horizontalSpacing = 20,
 double verticalSpacing = 20,
 }) {
 return Column(
 children: [
 for (int i = 0; i < cards.length; i++) ...[
 cards[i],
 if (i != cards.length - 1) SizedBox(height: verticalSpacing),
 ],
 ],
 );
 }

 Widget _buildCompletionCard() {
 return _panel(
 title: 'Punchlist completion health',
 subtitle:
 '62% of punch actions closed this sprint window. 12 blockers remain triaged.',
 child: const Row(
 children: [
 SizedBox(
 width: 140,
 height: 140,
 child: Stack(
 alignment: Alignment.center,
 children: [
 SizedBox(
 width: 140,
 height: 140,
 child: CircularProgressIndicator(
 value: 0.62,
 strokeWidth: 12,
 backgroundColor: Color(0xFFE2E8F0),
 valueColor: AlwaysStoppedAnimation(Color(0xFFFFC812)),
 ),
 ),
 Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 '62%',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w800,
 color: Color(0xFFFFC812),
 ),
 ),
 SizedBox(height: 4),
 Text(
 'complete',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF475569),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 SizedBox(width: 24),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _LegendRow(
 label: 'Closed', color: Color(0xFFFFC812), value: '112'),
 SizedBox(height: 10),
 _LegendRow(
 label: 'In review', color: Color(0xFFFFC812), value: '34'),
 SizedBox(height: 10),
 _LegendRow(
 label: 'Field fix pending',
 color: Color(0xFFFACC15),
 value: '21'),
 SizedBox(height: 10),
 _LegendRow(
 label: 'Escalated', color: Color(0xFFEF4444), value: '12'),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildDistributionCard() {
 final grandOpen = _distributionRows.fold<int>(0, (sum, r) => sum + r.openItems);
 final grandClosed = _distributionRows.fold<int>(0, (sum, r) => sum + r.closed);
 final grandTotal = grandOpen + grandClosed;
 final grandPct = grandTotal > 0 ? (grandClosed / grandTotal * 100) : 0.0;
 return _panel(
 title: 'Item distribution',
 subtitle: 'Punchlist item severity breakdown by workstream category with ownership tracking and closure metrics.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Summary bar
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 _summaryMetric(label: 'Total Items', value: '$grandTotal', color: const Color(0xFF1E293B)),
 const SizedBox(width: 20),
 _summaryMetric(label: 'Open', value: '$grandOpen', color: const Color(0xFFF59E0B)),
 const SizedBox(width: 20),
 _summaryMetric(label: 'Closed', value: '$grandClosed', color: const Color(0xFF22C55E)),
 const SizedBox(width: 20),
 _summaryMetric(label: 'Completion', value: '${grandPct.toStringAsFixed(1)}%', color: const Color(0xFFFFC812)),
 const Spacer(),
 FilledButton.icon(
 onPressed: () => _showDistributionDialog(context),
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add Category'),
 style: FilledButton.styleFrom(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 backgroundColor: const Color(0xFFFFC812),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 10),
 // Full-width table
 Builder(builder: (bc) {
  Widget buildTable(BuildContext ctx) {
  return LayoutBuilder(
 builder: (context, constraints) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: BoxConstraints(minWidth: constraints.maxWidth),
 child: buildNduDataTable(context: context, 
 headingRowColor: const Color(0xFFF8FAFC),
 headingRowHeight: 30,
 dataRowMinHeight: 22,
 dataRowMaxHeight: 28,
 headingTextStyle: const TextStyle(
 fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151), letterSpacing: 0.4,
 ),
 dataTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
 columnSpacing: 8,
 horizontalMargin: 8,
 columns: const [
 DataColumn(label: Text('Category')),
 DataColumn(label: Text('Open'), numeric: true),
 DataColumn(label: Text('Critical'), numeric: true),
 DataColumn(label: Text('High'), numeric: true),
 DataColumn(label: Text('Medium'), numeric: true),
 DataColumn(label: Text('Low'), numeric: true),
 DataColumn(label: Text('Closed'), numeric: true),
 DataColumn(label: Text('Total'), numeric: true),
 DataColumn(label: Text('% Complete'), numeric: true),
 DataColumn(label: Text('Owner')),
 DataColumn(label: Text('Status')),
 DataColumn(label: Text('Updated')),
 DataColumn(label: Text('Actions')),
 ],
 rows: _distributionRows.asMap().entries.map((entry) {
 final idx = entry.key;
 final row = entry.value;
 final pct = row.percentComplete;
 return DataRow(cells: [
 DataCell(Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFFFC812), shape: BoxShape.circle)),
 const SizedBox(width: 8),
 Text(row.category, style: const TextStyle(fontWeight: FontWeight.w700)),
 ],
 )),
 DataCell(_numberCell('${row.openItems}', const Color(0xFFF59E0B))),
 DataCell(_numberCell('${row.critical}', row.critical > 0 ? const Color(0xFFDC2626) : const Color(0xFF94A3B8))),
 DataCell(_numberCell('${row.high}', row.high > 0 ? const Color(0xFFEA580C) : const Color(0xFF94A3B8))),
 DataCell(_numberCell('${row.medium}', const Color(0xFFF59E0B))),
 DataCell(_numberCell('${row.low}', const Color(0xFF22C55E))),
 DataCell(_numberCell('${row.closed}', const Color(0xFF22C55E))),
 DataCell(Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8)),
 child: Text('${row.total}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFFFC812))),
 )),
 DataCell(Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 SizedBox(
 width: 48,
 child: ClipRRect(
 borderRadius: BorderRadius.circular(4),
 child: LinearProgressIndicator(
 value: pct / 100,
 backgroundColor: const Color(0xFFE5E7EB),
 valueColor: AlwaysStoppedAnimation(
 pct >= 70 ? const Color(0xFF22C55E) : pct >= 40 ? const Color(0xFFFFC812) : const Color(0xFFEF4444),
 ),
 minHeight: 4,
 ),
 ),
 ),
 const SizedBox(width: 4),
 Text('${pct.toStringAsFixed(0)}%', style: TextStyle(
 fontWeight: FontWeight.w700, fontSize: 12,
 color: pct >= 70 ? const Color(0xFF16A34A) : pct >= 40 ? const Color(0xFFFFC812) : const Color(0xFFDC2626),
 )),
 ],
 )),
 DataCell(Text(row.owner, style: const TextStyle(fontSize: 12))),
 DataCell(_buildStatusChip(row.status)),
 DataCell(Text(row.lastUpdated.isNotEmpty ? row.lastUpdated : '-', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
 DataCell(Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFFFC812)), onPressed: () => _showDistributionDialog(context, editIndex: idx), splashRadius: 18, tooltip: 'Edit'),
 IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)), onPressed: () => _deleteDistributionRow(idx), splashRadius: 18, tooltip: 'Delete'),
 IconButton(
   onPressed: () {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('KAZ AI: Generating suggestions...'), duration: Duration(seconds: 2)),
     );
   },
   icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFF59E0B)),
   tooltip: 'KAZ AI',
   padding: EdgeInsets.zero,
   constraints: const BoxConstraints(minWidth: 28),
 ),
 ],
 )),
 ]);
 }).toList(),
 ),
 ),
 );
 },
 );
  }
  return FullScreenTableWrapper(
   title: 'Punchlist Distribution',
   tableBuilder: buildTable,
   child: buildTable(bc),
  );
 })
 ],
 ),
 );
 }

 Widget _summaryMetric({required String label, required String value, required Color color}) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8), letterSpacing: 0.4)),
 const SizedBox(height: 4),
 Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
 ],
 );
 }

 Widget _numberCell(String value, Color color) {
 return Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontFeatures: const [FontFeature.tabularFigures()]));
 }

 Widget _buildActionVelocityCard() {
 final totalOpen = _velocityRows.fold<int>(0, (sum, r) => sum + r.openItems);
 final totalClosed = _velocityRows.fold<int>(0, (sum, r) => sum + r.closedThisSprint);
 final avgVelocity = _velocityRows.isNotEmpty
 ? _velocityRows.fold<int>(0, (sum, r) => sum + r.velocity) / _velocityRows.length
 : 0.0;
 final avgCycle = _velocityRows.isNotEmpty
 ? _velocityRows.fold<double>(0.0, (sum, r) => sum + r.avgCycleTime) / _velocityRows.length
 : 0.0;
 return _panel(
 title: 'Action velocity',
 subtitle: 'Workstream throughput momentum measured across sprint boundaries with trend indicators and cycle time analysis.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Summary bar
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 _summaryMetric(label: 'Total Open', value: '$totalOpen', color: const Color(0xFFF59E0B)),
 const SizedBox(width: 20),
 _summaryMetric(label: 'Closed Sprint', value: '$totalClosed', color: const Color(0xFF22C55E)),
 const SizedBox(width: 20),
 _summaryMetric(label: 'Avg Velocity', value: '${avgVelocity.toStringAsFixed(0)}%', color: const Color(0xFFFFC812)),
 const SizedBox(width: 20),
 _summaryMetric(label: 'Avg Cycle Time', value: '${avgCycle.toStringAsFixed(1)}d', color: const Color(0xFFB8860B)),
 const Spacer(),
 FilledButton.icon(
 onPressed: () => _showVelocityDialog(context),
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add Workstream'),
 style: FilledButton.styleFrom(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 backgroundColor: const Color(0xFFFFC812),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 10),
 // Full-width table
 Builder(builder: (bc) {
  Widget buildTable(BuildContext ctx) {
  return LayoutBuilder(
 builder: (context, constraints) {
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: ConstrainedBox(
 constraints: BoxConstraints(minWidth: constraints.maxWidth),
 child: buildNduDataTable(context: context, 
 headingRowColor: const Color(0xFFF8FAFC),
 headingRowHeight: 30,
 dataRowMinHeight: 22,
 dataRowMaxHeight: 28,
 headingTextStyle: const TextStyle(
 fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151), letterSpacing: 0.4,
 ),
 dataTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
 columnSpacing: 8,
 horizontalMargin: 8,
 columns: const [
 DataColumn(label: Text('Workstream')),
 DataColumn(label: Text('Open'), numeric: true),
 DataColumn(label: Text('Closed'), numeric: true),
 DataColumn(label: Text('Velocity %'), numeric: true),
 DataColumn(label: Text('Throughput'), numeric: true),
 DataColumn(label: Text('Trend')),
 DataColumn(label: Text('Cycle Time'), numeric: true),
 DataColumn(label: Text('Period')),
 DataColumn(label: Text('Owner')),
 DataColumn(label: Text('Status')),
 DataColumn(label: Text('Actions')),
 ],
 rows: _velocityRows.asMap().entries.map((entry) {
 final idx = entry.key;
 final row = entry.value;
 final isPositive = row.delta.startsWith('+');
 return DataRow(cells: [
 DataCell(Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(width: 10, height: 10, decoration: BoxDecoration(color: isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444), shape: BoxShape.circle)),
 const SizedBox(width: 8),
 Text(row.workstream, style: const TextStyle(fontWeight: FontWeight.w700)),
 ],
 )),
 DataCell(_numberCell('${row.openItems}', const Color(0xFFF59E0B))),
 DataCell(_numberCell('${row.closedThisSprint}', const Color(0xFF22C55E))),
 DataCell(Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 SizedBox(
 width: 56,
 child: ClipRRect(
 borderRadius: BorderRadius.circular(6),
 child: LinearProgressIndicator(
 value: row.velocity / 100,
 backgroundColor: const Color(0xFFE5E7EB),
 valueColor: AlwaysStoppedAnimation(
 row.velocity >= 60 ? const Color(0xFFFFC812) : row.velocity >= 40 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
 ),
 minHeight: 8,
 ),
 ),
 ),
 const SizedBox(width: 8),
 Text('${row.velocity}%', style: TextStyle(
 fontWeight: FontWeight.w700,
 fontFeatures: const [FontFeature.tabularFigures()],
 color: row.velocity >= 60 ? const Color(0xFFFFC812) : row.velocity >= 40 ? const Color(0xFFD97706) : const Color(0xFFDC2626),
 )),
 ],
 )),
 DataCell(Text('${row.throughput.toStringAsFixed(1)}/sp', style: const TextStyle(
 fontWeight: FontWeight.w700, color: Color(0xFF475569),
 fontFeatures: [FontFeature.tabularFigures()],
 ))),
 DataCell(Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: isPositive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Row(mainAxisSize: MainAxisSize.min, children: [
 Icon(isPositive ? Icons.trending_up : Icons.trending_down, size: 16, color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
 const SizedBox(width: 4),
 Text(row.delta, style: TextStyle(fontWeight: FontWeight.w700, color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
 ]),
 )),
 DataCell(Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: row.avgCycleTime <= 3.0 ? const Color(0xFFF0FDF4) : row.avgCycleTime <= 5.0 ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text('${row.avgCycleTime.toStringAsFixed(1)}d', style: TextStyle(
 fontWeight: FontWeight.w700,
 fontFeatures: const [FontFeature.tabularFigures()],
 color: row.avgCycleTime <= 3.0 ? const Color(0xFF16A34A) : row.avgCycleTime <= 5.0 ? const Color(0xFFD97706) : const Color(0xFFDC2626),
 )),
 )),
 DataCell(Text(row.period, style: const TextStyle(fontSize: 12))),
 DataCell(Text(row.owner, style: const TextStyle(fontSize: 12))),
 DataCell(_buildStatusChip(row.status)),
 DataCell(Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFFFC812)), onPressed: () => _showVelocityDialog(context, editIndex: idx), splashRadius: 18, tooltip: 'Edit'),
 IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)), onPressed: () => _deleteVelocityRow(idx), splashRadius: 18, tooltip: 'Delete'),
 IconButton(
   onPressed: () {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('KAZ AI: Generating suggestions...'), duration: Duration(seconds: 2)),
     );
   },
   icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFF59E0B)),
   tooltip: 'KAZ AI',
   padding: EdgeInsets.zero,
   constraints: const BoxConstraints(minWidth: 28),
 ),
 ],
 )),
 ]);
 }).toList(),
 ),
 ),
 );
 },
 );
  }
  return FullScreenTableWrapper(
   title: 'Action Velocity',
   tableBuilder: buildTable,
   child: buildTable(bc),
  );
 })
 ],
 ),
 );
 }

 Widget _panel(
 {required String title, String? subtitle, required Widget child}) {
 return Container(
 constraints: const BoxConstraints(minHeight: _panelMinHeight),
 alignment: Alignment.topLeft,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(28),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.04),
 blurRadius: 24,
 offset: const Offset(0, 18),
 ),
 ],
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Color(0xFF0F172A),
 ),
 ),
 if (subtitle != null) ...[
 const SizedBox(height: 8),
 Text(
 subtitle,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ],
 ),
 ),
 const SizedBox(width: 12),
 IconButton(
 onPressed: () => _showActionSnack(
 'Additional panel actions will be available in the next refinement pass.'),
 icon: const Icon(Icons.more_horiz, color: Color(0xFF94A3B8)),
 splashRadius: 20,
 ),
 ],
 ),
 const SizedBox(height: 20),
 child,
 ],
 ),
 );
 }

 Widget _buildStatusChip(String status) {
 Color bg;
 Color fg;
 switch (status.toLowerCase()) {
 case 'active':
 case 'on track':
 bg = const Color(0xFFF0FDF4); fg = const Color(0xFF16A34A); break;
 case 'improving':
 case 'stable':
 bg = const Color(0xFFFFF8E1); fg = const Color(0xFFFFC812); break;
 case 'at risk':
 bg = const Color(0xFFFEF2F2); fg = const Color(0xFFDC2626); break;
 case 'under review':
 case 'monitoring':
 bg = const Color(0xFFFFFBEB); fg = const Color(0xFFD97706); break;
 default:
 bg = const Color(0xFFF1F5F9); fg = const Color(0xFF475569);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
 child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
 );
 }

 void _showDistributionDialog(BuildContext context, {int? editIndex}) {
 final isEdit = editIndex != null;
 final existing = isEdit ? _distributionRows[editIndex] : null;
 final categoryCtrl = TextEditingController(text: existing?.category ?? '');
 final openItemsCtrl = TextEditingController(text: existing != null ? '${existing.openItems}' : '0');
 final criticalCtrl = TextEditingController(text: existing != null ? '${existing.critical}' : '0');
 final highCtrl = TextEditingController(text: existing != null ? '${existing.high}' : '0');
 final mediumCtrl = TextEditingController(text: existing != null ? '${existing.medium}' : '0');
 final lowCtrl = TextEditingController(text: existing != null ? '${existing.low}' : '0');
 final closedCtrl = TextEditingController(text: existing != null ? '${existing.closed}' : '0');
 final ownerCtrl = TextEditingController(text: existing?.owner ?? '');
 final lastUpdatedCtrl = TextEditingController(text: existing?.lastUpdated ?? 'Just now');
 const String otherCategoryOption = 'Other (specify)';
 final Set<String> categorySet = {
 'Systems', 'Field Ops', 'Compliance', 'Logistics',
 'Reporting', 'Safety', 'Quality', 'Facilities',
 ..._distributionRows.map((row) => row.category.trim()),
 }..removeWhere((name) => name.isEmpty);
 final List<String> categoryOptions = categorySet.toList();
 final String existingCategory = existing?.category.trim() ?? '';
 final bool usesCustomCategory =
 existingCategory.isNotEmpty && !categoryOptions.contains(existingCategory);
 String selectedCategory = usesCustomCategory
 ? otherCategoryOption
 : (existingCategory.isNotEmpty ? existingCategory : categoryOptions.first);
 String status = existing?.status ?? 'Active';

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDialogState) => AlertDialog(
 title: Text(isEdit ? 'Edit Category' : 'Add Category'),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 content: SizedBox(
 width: 480,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 DropdownButtonFormField<String>(
 initialValue: selectedCategory,
 decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
 items: <String>[...categoryOptions, otherCategoryOption]
 .map((c) => DropdownMenuItem(value: c, child: Text(c)))
 .toList(),
 onChanged: (v) =>
 setDialogState(() => selectedCategory = v ?? categoryOptions.first),
 ),
 if (selectedCategory == otherCategoryOption) ...[
 const SizedBox(height: 14),
 VoiceTextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Specify category', border: OutlineInputBorder()),),
 ],
 const SizedBox(height: 14),
 Row(children: [
 Expanded(child: NumericStepperField(controller: openItemsCtrl, label: 'Open Items')),
 const SizedBox(width: 10),
 Expanded(child: NumericStepperField(controller: closedCtrl, label: 'Closed')),
 ]),
 const SizedBox(height: 14),
 Row(children: [
 Expanded(child: NumericStepperField(controller: criticalCtrl, label: 'Critical')),
 const SizedBox(width: 10),
 Expanded(child: NumericStepperField(controller: highCtrl, label: 'High')),
 ]),
 const SizedBox(height: 14),
 Row(children: [
 Expanded(child: NumericStepperField(controller: mediumCtrl, label: 'Medium')),
 const SizedBox(width: 10),
 Expanded(child: NumericStepperField(controller: lowCtrl, label: 'Low')),
 ]),
 const SizedBox(height: 14),
 Row(children: [
 Expanded(child: VoiceTextField(controller: ownerCtrl, decoration: const InputDecoration(labelText: 'Owner', border: OutlineInputBorder()),)),
 const SizedBox(width: 10),
 Expanded(child: VoiceTextField(controller: lastUpdatedCtrl, decoration: const InputDecoration(labelText: 'Last Updated', border: OutlineInputBorder()),)),
 ]),
 const SizedBox(height: 14),
 DropdownButtonFormField<String>(
 initialValue: status,
 decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
 items: ['Active', 'Under Review', 'Monitoring', 'At Risk'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
 onChanged: (v) => setDialogState(() => status = v ?? 'Active'),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final row = _DistributionRow(
 category: selectedCategory == otherCategoryOption
 ? categoryCtrl.text.trim()
 : selectedCategory,
 openItems: int.tryParse(openItemsCtrl.text) ?? 0,
 critical: int.tryParse(criticalCtrl.text) ?? 0,
 high: int.tryParse(highCtrl.text) ?? 0,
 medium: int.tryParse(mediumCtrl.text) ?? 0,
 low: int.tryParse(lowCtrl.text) ?? 0,
 closed: int.tryParse(closedCtrl.text) ?? 0,
 owner: ownerCtrl.text.trim(),
 status: status,
 lastUpdated: lastUpdatedCtrl.text.trim().isNotEmpty ? lastUpdatedCtrl.text.trim() : 'Just now',
 );
 setState(() {
 if (isEdit) {
 _distributionRows[editIndex] = row;
 } else {
 _distributionRows.add(row);
 }
 });
 _saveToFirestore();
 Navigator.pop(ctx);
 _showActionSnack(isEdit ? 'Category updated successfully.' : 'Category added successfully.');
 },
 child: Text(isEdit ? 'Update' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 String _formatDeltaValue(double value) {
 final rounded = (value * 10).roundToDouble() / 10;
 return '${rounded >= 0 ? '+' : ''}${rounded.toStringAsFixed(1)}%';
 }

 void _showVelocityDialog(BuildContext context, {int? editIndex}) {
 final isEdit = editIndex != null;
 final existing = isEdit ? _velocityRows[editIndex] : null;
 final workstreamCtrl = TextEditingController(text: existing?.workstream ?? '');
 final openItemsCtrl = TextEditingController(text: existing != null ? '${existing.openItems}' : '0');
 final closedThisSprintCtrl = TextEditingController(text: existing != null ? '${existing.closedThisSprint}' : '0');
 final velocityCtrl = TextEditingController(text: existing != null ? '${existing.velocity}' : '50');
 final throughputCtrl = TextEditingController(
 text: existing != null
 ? NumericStepperField.formatValue(existing.throughput, isDouble: true)
 : '0');
 final double existingDelta = existing == null
 ? 0.0
 : (double.tryParse(
 existing.delta.replaceAll('%', '').replaceAll('+', '').trim()) ??
 0.0);
 final deltaCtrl = TextEditingController(
 text: NumericStepperField.formatValue(existingDelta, isDouble: true));
 final avgCycleTimeCtrl = TextEditingController(
 text: existing != null
 ? NumericStepperField.formatValue(existing.avgCycleTime, isDouble: true)
 : '0');
 final periodCtrl = TextEditingController(text: existing?.period ?? '');
 const String otherPeriodOption = 'Other (specify)';
 final Set<String> periodSet = {
 'Current Sprint', 'Next Sprint', 'Sprint 41-42',
 'Sprint 43-44', 'Sprint 45-46',
 ..._velocityRows.map((row) => row.period.trim()),
 }..removeWhere((period) => period.isEmpty);
 final List<String> periodOptions = periodSet.toList();
 final String existingPeriod = existing?.period.trim() ?? '';
 final bool usesCustomPeriod =
 existingPeriod.isNotEmpty && !periodOptions.contains(existingPeriod);
 String selectedPeriod = usesCustomPeriod
 ? otherPeriodOption
 : (existingPeriod.isNotEmpty ? existingPeriod : 'Sprint 41-42');
 final ownerCtrl = TextEditingController(text: existing?.owner ?? '');
 String status = existing?.status ?? 'On Track';

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDialogState) => AlertDialog(
 title: Text(isEdit ? 'Edit Workstream' : 'Add Workstream'),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 content: SizedBox(
 width: 480,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(controller: workstreamCtrl, decoration: const InputDecoration(labelText: 'Workstream', border: OutlineInputBorder()),),
 const SizedBox(height: 14),
 Row(children: [
 Expanded(child: NumericStepperField(controller: openItemsCtrl, label: 'Open Items')),
 const SizedBox(width: 10),
 Expanded(child: NumericStepperField(controller: closedThisSprintCtrl, label: 'Closed Sprint')),
 ]),
 const SizedBox(height: 14),
 Row(children: [
 Expanded(child: NumericStepperField(controller: velocityCtrl, label: 'Velocity %', step: 5, max: 100)),
 const SizedBox(width: 10),
 Expanded(child: NumericStepperField(controller: throughputCtrl, label: 'Throughput (items/sp)', step: 0.5, isDouble: true)),
 ]),
 const SizedBox(height: 14),
 Row(children: [
 Expanded(child: NumericStepperField(controller: deltaCtrl, label: 'Delta %', step: 0.5, min: -100, isDouble: true)),
 const SizedBox(width: 10),
 Expanded(child: NumericStepperField(controller: avgCycleTimeCtrl, label: 'Avg Cycle Time (days)', step: 0.5, isDouble: true)),
 ]),
 const SizedBox(height: 14),
 DropdownButtonFormField<String>(
 initialValue: selectedPeriod,
 decoration: const InputDecoration(labelText: 'Period', border: OutlineInputBorder()),
 items: <String>[...periodOptions, otherPeriodOption]
 .map((p) => DropdownMenuItem(value: p, child: Text(p)))
 .toList(),
 onChanged: (v) =>
 setDialogState(() => selectedPeriod = v ?? periodOptions.first),
 ),
 if (selectedPeriod == otherPeriodOption) ...[
 const SizedBox(height: 14),
 VoiceTextField(controller: periodCtrl, decoration: const InputDecoration(labelText: 'Specify period', border: OutlineInputBorder()),),
 ],
 const SizedBox(height: 14),
 VoiceTextField(controller: ownerCtrl, decoration: const InputDecoration(labelText: 'Owner', border: OutlineInputBorder()),),
 const SizedBox(height: 14),
 DropdownButtonFormField<String>(
 initialValue: status,
 decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
 items: ['On Track', 'Improving', 'Stable', 'At Risk'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
 onChanged: (v) => setDialogState(() => status = v ?? 'On Track'),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final row = _ActionVelocityRow(
 workstream: workstreamCtrl.text.trim(),
 openItems: int.tryParse(openItemsCtrl.text) ?? 0,
 closedThisSprint: int.tryParse(closedThisSprintCtrl.text) ?? 0,
 velocity: int.tryParse(velocityCtrl.text) ?? 0,
 throughput: double.tryParse(throughputCtrl.text) ?? 0.0,
 delta: _formatDeltaValue(double.tryParse(deltaCtrl.text) ?? 0.0),
 avgCycleTime: double.tryParse(avgCycleTimeCtrl.text) ?? 0.0,
 period: selectedPeriod == otherPeriodOption
 ? periodCtrl.text.trim()
 : selectedPeriod,
 owner: ownerCtrl.text.trim(),
 status: status,
 );
 setState(() {
 if (isEdit) {
 _velocityRows[editIndex] = row;
 } else {
 _velocityRows.add(row);
 }
 });
 _saveToFirestore();
 Navigator.pop(ctx);
 _showActionSnack(isEdit ? 'Workstream updated successfully.' : 'Workstream added successfully.');
 },
 child: Text(isEdit ? 'Update' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 void _deleteDistributionRow(int index) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete Category'),
 content: Text('Are you sure you want to delete "${_distributionRows[index].category}"? This action cannot be undone.'),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 actions: [
 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
 FilledButton(
 style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
 onPressed: () {
 setState(() => _distributionRows.removeAt(index));
 _saveToFirestore();
 showDeleteSuccessSnackBar(context, itemLabel: 'Distribution');
 Navigator.pop(ctx);
 _showActionSnack('Category deleted.');
 },
 child: const Text('Delete'),
 ),
 ],
 ),
 );
 }

 void _deleteVelocityRow(int index) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete Workstream'),
 content: Text('Are you sure you want to delete "${_velocityRows[index].workstream}"? This action cannot be undone.'),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 actions: [
 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
 FilledButton(
 style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
 onPressed: () {
 setState(() => _velocityRows.removeAt(index));
 _saveToFirestore();
 showDeleteSuccessSnackBar(context, itemLabel: 'Velocity');
 Navigator.pop(ctx);
 _showActionSnack('Workstream deleted.');
 },
 child: const Text('Delete'),
 ),
 ],
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Punchlist Actions',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_punchlist_actions_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.color,
    required this.value,
  });

  final String label;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _DistributionRow {
  const _DistributionRow({
    required this.category,
    required this.openItems,
    required this.critical,
    required this.high,
    required this.medium,
    required this.low,
    required this.closed,
    required this.owner,
    required this.status,
    this.lastUpdated = '',
  });

  final String category;
  final int openItems;
  final int critical;
  final int high;
  final int medium;
  final int low;
  final int closed;
  final String owner;
  final String status;
  final String lastUpdated;

  int get total => openItems + closed;
  double get percentComplete => total > 0 ? (closed / total * 100) : 0.0;

  Map<String, dynamic> toMap() => {
        'category': category,
        'openItems': openItems,
        'critical': critical,
        'high': high,
        'medium': medium,
        'low': low,
        'closed': closed,
        'owner': owner,
        'status': status,
        'lastUpdated': lastUpdated,
      };

  static _DistributionRow fromMap(Map<String, dynamic> map) => _DistributionRow(
        category: map['category']?.toString() ?? '',
        openItems: (map['openItems'] is int)
            ? map['openItems'] as int
            : int.tryParse(map['openItems'].toString()) ?? 0,
        critical: (map['critical'] is int)
            ? map['critical'] as int
            : int.tryParse(map['critical'].toString()) ?? 0,
        high: (map['high'] is int)
            ? map['high'] as int
            : int.tryParse(map['high'].toString()) ?? 0,
        medium: (map['medium'] is int)
            ? map['medium'] as int
            : int.tryParse(map['medium'].toString()) ?? 0,
        low: (map['low'] is int)
            ? map['low'] as int
            : int.tryParse(map['low'].toString()) ?? 0,
        closed: (map['closed'] is int)
            ? map['closed'] as int
            : int.tryParse(map['closed'].toString()) ?? 0,
        owner: map['owner']?.toString() ?? '',
        status: map['status']?.toString() ?? 'Active',
        lastUpdated: map['lastUpdated']?.toString() ?? '',
      );
}

class _ActionVelocityRow {
  const _ActionVelocityRow({
    required this.workstream,
    required this.openItems,
    required this.closedThisSprint,
    required this.velocity,
    required this.throughput,
    required this.delta,
    required this.avgCycleTime,
    required this.period,
    required this.owner,
    required this.status,
  });

  final String workstream;
  final int openItems;
  final int closedThisSprint;
  final int velocity;
  final double throughput;
  final String delta;
  final double avgCycleTime;
  final String period;
  final String owner;
  final String status;

  Map<String, dynamic> toMap() => {
        'workstream': workstream,
        'openItems': openItems,
        'closedThisSprint': closedThisSprint,
        'velocity': velocity,
        'throughput': throughput,
        'delta': delta,
        'avgCycleTime': avgCycleTime,
        'period': period,
        'owner': owner,
        'status': status,
      };

  static _ActionVelocityRow fromMap(Map<String, dynamic> map) =>
      _ActionVelocityRow(
        workstream: map['workstream']?.toString() ?? '',
        openItems: (map['openItems'] is int)
            ? map['openItems'] as int
            : int.tryParse(map['openItems'].toString()) ?? 0,
        closedThisSprint: (map['closedThisSprint'] is int)
            ? map['closedThisSprint'] as int
            : int.tryParse(map['closedThisSprint'].toString()) ?? 0,
        velocity: (map['velocity'] is int)
            ? map['velocity'] as int
            : int.tryParse(map['velocity'].toString()) ?? 0,
        throughput: (map['throughput'] is num)
            ? (map['throughput'] as num).toDouble()
            : double.tryParse(map['throughput'].toString()) ?? 0.0,
        delta: map['delta']?.toString() ?? '+0.0%',
        avgCycleTime: (map['avgCycleTime'] is num)
            ? (map['avgCycleTime'] as num).toDouble()
            : double.tryParse(map['avgCycleTime'].toString()) ?? 0.0,
        period: map['period']?.toString() ?? '',
        owner: map['owner']?.toString() ?? '',
        status: map['status']?.toString() ?? 'On Track',
      );
}
