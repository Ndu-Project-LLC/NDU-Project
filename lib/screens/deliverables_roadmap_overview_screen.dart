import 'package:flutter/material.dart';
import 'package:ndu_project/models/aggregated_deliverable.dart';
import 'package:ndu_project/models/roadmap_deliverable.dart';
import 'package:ndu_project/services/deliverable_aggregation_service.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

const Color _kBackground = Color(0xFFF7F8FC);
const Color _kAccent = Color(0xFFFFC812);
const Color _kHeadline = Color(0xFF1A1D1F);
const Color _kMuted = Color(0xFF6B7280);
const Color _kCardBorder = Color(0xFFE4E7EC);

class DeliverablesRoadmapOverviewScreen extends StatefulWidget {
 const DeliverablesRoadmapOverviewScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const DeliverablesRoadmapOverviewScreen()),
 );
 }

 @override
 State<DeliverablesRoadmapOverviewScreen> createState() =>
 _DeliverablesRoadmapOverviewScreenState();
}

class _DeliverablesRoadmapOverviewScreenState
 extends State<DeliverablesRoadmapOverviewScreen> {
 bool _isLoading = true;
 DeliverableStatistics? _statistics;
 Map<DeliverableCategory, List<AggregatedDeliverable>>? _deliverablesByCategory;

 String? get _projectId {
 try {
 return ProjectDataInherited.maybeOf(context)?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 @override
 void initState() {
 super.initState();
 _loadData();
 }

 @override
 void didChangeDependencies() {
 super.didChangeDependencies();
 _loadData();
 }

 Future<void> _loadData() async {
 final projectId = _projectId;
 if (projectId == null) return;

 setState(() => _isLoading = true);

 try {
 final stats = await DeliverableAggregationService.instance
 .calculateStatistics(projectId: projectId);
 final byCategory = await DeliverableAggregationService.instance
 .getDeliverablesByCategory(projectId: projectId);

 if (mounted) {
 setState(() {
 _statistics = stats;
 _deliverablesByCategory = byCategory;
 _isLoading = false;
 });
 }
 } catch (e) {
 debugPrint('Error loading roadmap overview: $e');
 if (mounted) setState(() => _isLoading = false);
 }
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: _kBackground,
 body: Stack(
 children: [
 SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Roadmap Overview'),
 ),
 Expanded(
 child: _isLoading
 ? const Center(child: CircularProgressIndicator())
 : _buildContent()),
 ],
 ),
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Roadmap Overview',
 ),
 ),
 const KazAiChatBubble(),
 ],
 ),
 );
 }

 Widget _buildContent() {
 return SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(
 title: 'Roadmap Overview',
onBack: () => PlanningPhaseNavigation.goToPrevious(
 context, 'deliverables_roadmap_overview'),
 onForward: () => PlanningPhaseNavigation.goToNext(
 context, 'deliverables_roadmap_overview'), onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _buildHeader(),
 const SizedBox(height: 24),
 if (_statistics != null) _buildStatisticsCards(),
 const SizedBox(height: 24),
 if (_deliverablesByCategory != null)
 _buildCategorySections(),
 ],
 ),
 );
 }

 Widget _buildHeader() {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Deliverables Roadmap',
 style: TextStyle(
 fontSize: 28,
 fontWeight: FontWeight.bold,
 color: _kHeadline,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Overview of all deliverables across Initiation and Planning phases',
 style: TextStyle(
 fontSize: 14,
 color: _kMuted,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ],
 );
 }

 Widget _buildStatisticsCards() {
 final stats = _statistics!;
 return Row(
 children: [
 Expanded(child: _buildStatCard('Total', stats.total.toString(), Icons.list)),
 Expanded(child: _buildStatCard('Completed', stats.completed.toString(), Icons.check_circle, Colors.green)),
 Expanded(child: _buildStatCard('In Progress', stats.inProgress.toString(), Icons.pending, Colors.orange)),
 Expanded(child: _buildStatCard('At Risk', stats.atRisk.toString(), Icons.warning, Colors.red)),
 Expanded(child: _buildStatCard('Overdue', stats.overdue.toString(), Icons.error_outline, Colors.red)),
 Expanded(child: _buildStatCard('Completion', '${stats.completionPercent.toStringAsFixed(0)}%', Icons.pie_chart)),
 ],
 );
 }

 Widget _buildStatCard(String title, String value, IconData icon, [Color? color]) {
 return Container(
 margin: const EdgeInsets.symmetric(horizontal: 4),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: _kCardBorder),
 ),
 child: Column(
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 title,
 style: TextStyle(
 fontSize: 12,
 color: _kMuted,
 ),
 ),
 Icon(icon, size: 16, color: color ?? _kMuted),
 ],
 ),
 const SizedBox(height: 8),
 Text(
 value,
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.bold,
 color: color ?? _kHeadline,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildCategorySections() {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 for (final category in DeliverableCategory.values)
 if (_deliverablesByCategory![category]!.isNotEmpty)
 _buildCategorySection(category, _deliverablesByCategory![category]!),
 ],
 );
 }

 Widget _buildCategorySection(
 DeliverableCategory category, List<AggregatedDeliverable> deliverables) {
 final categoryInfo = _getCategoryInfo(category);

 return Container(
 margin: const EdgeInsets.only(bottom: 16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: _kCardBorder),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildCategoryHeader(categoryInfo, deliverables.length),
 _buildCategoryDeliverables(deliverables),
 ],
 ),
 );
 }

 Widget _buildCategoryHeader(_CategoryInfo info, int count) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: info.color.withOpacity(0.1),
 borderRadius: const BorderRadius.only(
 topLeft: Radius.circular(12),
 topRight: Radius.circular(12),
 ),
 ),
 child: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: info.color,
 borderRadius: BorderRadius.circular(8),
 ),
 child: Icon(info.icon, color: Colors.white, size: 20),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 info.title,
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.bold,
 color: _kHeadline,
 ),
 ),
 Text(
 '$count deliverable${count != 1 ? 's' : ''}',
 style: TextStyle(
 fontSize: 12,
 color: _kMuted,
 ),
 ),
 ],
 ),
 ),
 _buildCategoryProgressBar(info, count),
 ],
 ),
 );
 }

 Widget _buildCategoryProgressBar(_CategoryInfo info, int totalCount) {
 if (_deliverablesByCategory == null) return const SizedBox();

 final deliverables = _deliverablesByCategory![info.category]!;
 final completed = deliverables.where((d) => d.isCompleted).length;
 final percent = totalCount > 0 ? (completed / totalCount) : 0.0;

 return Column(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 Text(
 '${(percent * 100).toStringAsFixed(0)}%',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.bold,
 color: info.color,
 ),
 ),
 const SizedBox(height: 4),
 SizedBox(
 width: 80,
 child: ClipRRect(
 borderRadius: BorderRadius.circular(4),
 child: LinearProgressIndicator(
 value: percent,
 backgroundColor: info.color.withOpacity(0.2),
 valueColor: AlwaysStoppedAnimation<Color>(info.color),
 minHeight: 6,
 ),
 ),
 ),
 ],
 );
 }

 Widget _buildCategoryDeliverables(List<AggregatedDeliverable> deliverables) {
 return Column(
 children: [
 for (var i = 0; i < deliverables.length; i++)
 _buildDeliverableTile(deliverables[i], i < deliverables.length - 1),
 ],
 );
 }

 Widget _buildDeliverableTile(AggregatedDeliverable deliverable, bool showDivider) {
 return Column(
 children: [
 InkWell(
 onTap: () => _navigateToDetailed(deliverable),
 child: Padding(
 padding: const EdgeInsets.all(16),
 child: Row(
 children: [
 _buildStatusIcon(deliverable.status),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 deliverable.title,
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w500,
 color: _kHeadline,
 decoration: deliverable.isCompleted
 ? TextDecoration.lineThrough
 : null,
 ),
 ),
 if (deliverable.description.isNotEmpty) ...[
 const SizedBox(height: 4),
 Text(
 deliverable.description,
 style: TextStyle(
 fontSize: 12,
 color: _kMuted,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 Row(
 children: [
 _buildPhaseChip(deliverable.phase),
 const SizedBox(width: 8),
 if (deliverable.assigneeName != null)
 _buildAssigneeChip(deliverable.assigneeName!),
 const SizedBox(width: 8),
 if (deliverable.dueDate != null)
 _buildDueDateChip(deliverable.dueDate!),
 ],
 ),
 ],
 ),
 ),
 Icon(Icons.chevron_right, color: _kMuted, size: 20),
 ],
 ),
 ),
 ),
 if (showDivider)
 Divider(height: 1, color: _kCardBorder, indent: 56),
 ],
 );
 }

 Widget _buildStatusIcon(RoadmapDeliverableStatus status) {
 IconData icon;
 Color color;

 switch (status) {
 case RoadmapDeliverableStatus.completed:
 icon = Icons.check_circle;
 color = Colors.green;
 break;
 case RoadmapDeliverableStatus.inProgress:
 icon = Icons.sync;
 color = Colors.orange;
 break;
 case RoadmapDeliverableStatus.notStarted:
 icon = Icons.circle_outlined;
 color = Colors.grey;
 break;
 case RoadmapDeliverableStatus.atRisk:
 icon = Icons.warning;
 color = Colors.orange;
 break;
 case RoadmapDeliverableStatus.blocked:
 icon = Icons.block;
 color = Colors.red;
 break;
 }

 return Icon(icon, color: color, size: 20);
 }

 Widget _buildPhaseChip(DeliverablePhase phase) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: Colors.grey.withOpacity(0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 _getPhaseLabel(phase),
 style: TextStyle(
 fontSize: 10,
 color: _kMuted,
 ),
 ),
 );
 }

 Widget _buildAssigneeChip(String assignee) {
 return Row(
 children: [
 Icon(Icons.person_outline, size: 12, color: _kMuted),
 const SizedBox(width: 4),
 Text(
 assignee,
 style: TextStyle(
 fontSize: 11,
 color: _kMuted,
 ),
 ),
 ],
 );
 }

 Widget _buildDueDateChip(DateTime dueDate) {
 final isOverdue = DateTime.now().isAfter(dueDate);
 return Row(
 children: [
 Icon(Icons.calendar_today, size: 12, color: isOverdue ? Colors.red : _kMuted),
 const SizedBox(width: 4),
 Text(
 '${dueDate.month}/${dueDate.day}',
 style: TextStyle(
 fontSize: 11,
 color: isOverdue ? Colors.red : _kMuted,
 ),
 ),
 ],
 );
 }

 void _navigateToDetailed(AggregatedDeliverable deliverable) {
 PlanningPhaseNavigation.navigateToNext(
 context,
 'deliverables_roadmap_overview',
 );
 }

 _CategoryInfo _getCategoryInfo(DeliverableCategory category) {
 switch (category) {
 case DeliverableCategory.governance:
 return _CategoryInfo(
 title: 'Governance',
 icon: Icons.account_balance,
 color: const Color(0xFF3B82F6),
 category: category,
 );
 case DeliverableCategory.requirements:
 return _CategoryInfo(
 title: 'Requirements',
 icon: Icons.checklist,
 color: const Color(0xFF8B5CF6),
 category: category,
 );
 case DeliverableCategory.riskCompliance:
 return _CategoryInfo(
 title: 'Risk & Compliance',
 icon: Icons.shield,
 color: const Color(0xFFEF4444),
 category: category,
 );
 case DeliverableCategory.execution:
 return _CategoryInfo(
 title: 'Execution',
 icon: Icons.play_arrow,
 color: const Color(0xFF10B981),
 category: category,
 );
 case DeliverableCategory.technical:
 return _CategoryInfo(
 title: 'Technical',
 icon: Icons.code,
 color: const Color(0xFF6366F1),
 category: category,
 );
 case DeliverableCategory.quality:
 return _CategoryInfo(
 title: 'Quality',
 icon: Icons.verified,
 color: const Color(0xFFEC4899),
 category: category,
 );
 case DeliverableCategory.contractsProcurement:
 return _CategoryInfo(
 title: 'Contracts & Procurement',
 icon: Icons.description,
 color: const Color(0xFFF59E0B),
 category: category,
 );
 case DeliverableCategory.scheduleCost:
 return _CategoryInfo(
 title: 'Schedule & Cost',
 icon: Icons.attach_money,
 color: const Color(0xFF14B8A6),
 category: category,
 );
 case DeliverableCategory.teamStakeholders:
 return _CategoryInfo(
 title: 'Team & Stakeholders',
 icon: Icons.groups,
 color: const Color(0xFF84CC16),
 category: category,
 );
 }
 }

 String _getPhaseLabel(DeliverablePhase phase) {
 switch (phase) {
 case DeliverablePhase.initiation:
 return 'Initiation';
 case DeliverablePhase.frontEndPlanning:
 return 'Front-End Planning';
 case DeliverablePhase.planning:
 return 'Planning';
 case DeliverablePhase.design:
 return 'Design';
 case DeliverablePhase.execution:
 return 'Execution';
 case DeliverablePhase.launch:
 return 'Launch';
 }
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Deliverables Roadmap Overview',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_deliverables_roadmap_overview_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _CategoryInfo {
 final String title;
 final IconData icon;
 final Color color;
 final DeliverableCategory category;

 const _CategoryInfo({
 required this.title,
 required this.icon,
 required this.color,
 required this.category,
 });
}
