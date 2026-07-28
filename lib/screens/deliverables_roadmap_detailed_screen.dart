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

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
const Color _kBackground = Color(0xFFF7F8FC);
const Color _kAccent = Color(0xFFFFC812);
const Color _kHeadline = Color(0xFF1A1D1F);
const Color _kMuted = Color(0xFF6B7280);
const Color _kCardBorder = Color(0xFFE4E7EC);

class DeliverablesRoadmapDetailedScreen extends StatefulWidget {
 const DeliverablesRoadmapDetailedScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const DeliverablesRoadmapDetailedScreen()),
 );
 }

 @override
 State<DeliverablesRoadmapDetailedScreen> createState() =>
 _DeliverablesRoadmapDetailedScreenState();
}

class _DeliverablesRoadmapDetailedScreenState
 extends State<DeliverablesRoadmapDetailedScreen> {
 bool _isLoading = true;
 List<AggregatedDeliverable> _allDeliverables = [];
 List<AggregatedDeliverable> _filteredDeliverables = [];

 DeliverableFilter _filter = const DeliverableFilter();
 String _searchQuery = '';
 String _selectedCategory = 'All';
 String _selectedStatus = 'All';
 String _selectedPhase = 'All';

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
 final deliverables =
 await DeliverableAggregationService.instance.aggregateAllDeliverables(
 projectId: projectId,
 );

 deliverables.sort((a, b) => a.order.compareTo(b.order));

 if (mounted) {
 setState(() {
 _allDeliverables = deliverables;
 _filteredDeliverables = deliverables;
 _isLoading = false;
 });
 }
 } catch (e) {
 debugPrint('Error loading detailed deliverables: $e');
 if (mounted) setState(() => _isLoading = false);
 }
 }

 void _applyFilters() {
 setState(() {
 Set<DeliverableCategory>? categories;
 Set<RoadmapDeliverableStatus>? statuses;
 Set<DeliverablePhase>? phases;

 if (_selectedCategory != 'All') {
 final category = DeliverableCategory.values.firstWhere(
 (c) => c.name == _selectedCategory.toLowerCase(),
 orElse: () => DeliverableCategory.governance,
 );
 categories = {category};
 }

 if (_selectedStatus != 'All') {
 final status = RoadmapDeliverableStatus.values.firstWhere(
 (s) => s.name == _selectedStatus.toLowerCase(),
 orElse: () => RoadmapDeliverableStatus.notStarted,
 );
 statuses = {status};
 }

 if (_selectedPhase != 'All') {
 final phase = DeliverablePhase.values.firstWhere(
 (p) => p.name == _selectedPhase.toLowerCase(),
 orElse: () => DeliverablePhase.initiation,
 );
 phases = {phase};
 }

 _filter = DeliverableFilter(
 categories: categories,
 statuses: statuses,
 phases: phases,
 searchTerm: _searchQuery.isNotEmpty ? _searchQuery : null,
 );

 _filteredDeliverables = _allDeliverables.where(_filter.matches).toList();
 });
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
 activeItemLabel: 'Detailed Deliverables'),
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
 activeItemLabel: 'Detailed Deliverables',
 ),
 ),
 const KazAiChatBubble(),
 ],
 ),
 );
 }

 Widget _buildContent() {
 return Column(
 children: [
 PlanningPhaseHeader(
 title: 'Detailed Deliverables',
onBack: () => PlanningPhaseNavigation.goToPrevious(
 context,
 'deliverables_roadmap_detailed',
 ),
 onForward: () => PlanningPhaseNavigation.goToNext(
 context,
 'deliverables_roadmap_detailed',
 ), onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _buildHeader(),
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: _buildDeliverablesTable(),
 ),
 ),
 ],
 );
 }

 Widget _buildHeader() {
 return Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 border: Border(bottom: BorderSide(color: _kCardBorder)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 _NavCircleBtn(
 icon: Icons.arrow_back_ios_new_rounded,
 onTap: () => PlanningPhaseNavigation.goToPrevious(
 context,
 'deliverables_roadmap_detailed',
 ),
 ),
 const SizedBox(width: 10),
 _NavCircleBtn(
 icon: Icons.arrow_forward_ios_rounded,
 onTap: () => PlanningPhaseNavigation.goToNext(
 context,
 'deliverables_roadmap_detailed',
 ),
 ),
 const SizedBox(width: 16),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Detailed Deliverables',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.bold,
 color: _kHeadline,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 _buildFilterBar(),
 ],
 ),
 );
 }

 Widget _buildFilterBar() {
 return Row(
 children: [
 Expanded(
 child: VoiceTextField(
 decoration: InputDecoration(
 hintText: 'Search deliverables...',
 prefixIcon: const Icon(Icons.search),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(8),
 borderSide: BorderSide(color: _kCardBorder),
 ),
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 16,
 vertical: 12,
 ),
 ),
 onChanged: (value) {
 _searchQuery = value;
 _applyFilters();
 },
 ),
 ),
 const SizedBox(width: 16),
 _buildDropdown('Category', _selectedCategory, [
 'All',
 'Governance',
 'Requirements',
 'Risk & Compliance',
 'Execution',
 'Technical',
 'Quality',
 'Contracts & Procurement',
 'Schedule & Cost',
 'Team & Stakeholders',
 ], (value) {
 setState(() {
 _selectedCategory = value;
 _applyFilters();
 });
 }),
 const SizedBox(width: 12),
 _buildDropdown('Status', _selectedStatus, [
 'All',
 'Not Started',
 'In Progress',
 'Completed',
 'At Risk',
 'Blocked',
 ], (value) {
 setState(() {
 _selectedStatus = value;
 _applyFilters();
 });
 }),
 const SizedBox(width: 12),
 _buildDropdown('Phase', _selectedPhase, [
 'All',
 'Initiation',
 'Front-End Planning',
 'Planning',
 'Design',
 'Execution',
 'Launch',
 ], (value) {
 setState(() {
 _selectedPhase = value;
 _applyFilters();
 });
 }),
 const SizedBox(width: 16),
 ElevatedButton.icon(
 onPressed: _showAddDeliverableDialog,
 icon: const Icon(Icons.add),
 label: const Text('Add Deliverable'),
 style: ElevatedButton.styleFrom(
 backgroundColor: _kAccent,
 foregroundColor: Colors.black,
 padding: const EdgeInsets.symmetric(
 horizontal: 20,
 vertical: 16,
 ),
 ),
 ),
 ],
 );
 }

 Widget _buildDropdown(
 String label,
 String value,
 List<String> items,
 Function(String) onChanged,
 ) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: _kMuted,
 ),
 ),
 const SizedBox(height: 4),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12),
 decoration: BoxDecoration(
 border: Border.all(color: _kCardBorder),
 borderRadius: BorderRadius.circular(8),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: value,
 items: items
 .map((item) => DropdownMenuItem(
 value: item,
 child: Text(item, style: const TextStyle(fontSize: 14)),
 ))
 .toList(),
 onChanged: (v) => onChanged(v!),
 icon: const Icon(Icons.expand_more, size: 20),
 isDense: true,
 ),
 ),
 ),
 ],
 );
 }

 Widget _buildDeliverablesTable() {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 children: [
 _buildTableHeader(),
 if (_filteredDeliverables.isEmpty)
 _buildEmptyState()
 else
 _buildTableRows(),
 ],
 ),
 );
 }

 Widget _buildTableHeader() {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: const BorderRadius.only(
 topLeft: Radius.circular(18),
 topRight: Radius.circular(18),
 ),
 ),
 child: const Row(
 children: [
 SizedBox(width: 50, child: Center(child: Text('#', style: _headerStyle))),
 Expanded(flex: 2, child: Center(child: Text('DELIVERABLE', style: _headerStyle))),
 Expanded(child: Center(child: Text('CATEGORY', style: _headerStyle))),
 Expanded(child: Center(child: Text('PHASE', style: _headerStyle))),
 Expanded(child: Center(child: Text('STATUS', style: _headerStyle))),
 Expanded(child: Center(child: Text('PRIORITY', style: _headerStyle))),
 Expanded(child: Center(child: Text('ASSIGNEE', style: _headerStyle))),
 Expanded(child: Center(child: Text('DUE DATE', style: _headerStyle))),
 Expanded(child: Center(child: Text('SOURCE', style: _headerStyle))),
 SizedBox(width: 80, child: Center(child: Text('ACTIONS', style: _headerStyle))),
 ],
 ),
 );
 }

 Widget _buildEmptyState() {
 return Padding(
 padding: const EdgeInsets.all(48),
 child: Column(
 children: [
 Icon(Icons.search_off, size: 64, color: _kMuted.withOpacity(0.5)),
 const SizedBox(height: 16),
 Text(
 'No deliverables found',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w500,
 color: _kMuted,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Try adjusting your filters or search terms',
 style: TextStyle(
 fontSize: 14,
 color: _kMuted,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildTableRows() {
 return Column(
 children: [
 for (var i = 0; i < _filteredDeliverables.length; i++)
 _buildTableRow(_filteredDeliverables[i], i),
 ],
 );
 }

 Widget _buildTableRow(AggregatedDeliverable deliverable, int index) {
 final isEven = index.isEven;
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: isEven ? Colors.white : const Color(0xFFF9FAFB),
 border: Border(
 top: BorderSide(
 color: const Color(0xFFE5E7EB),
 width: index == 0 ? 1 : 0.5,
 ),
 ),
 ),
 child: Row(
 children: [
 SizedBox(
 width: 50,
 child: Center(
 child: Text(
 '${index + 1}',
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF9CA3AF),
 ),
 ),
 ),
 ),
 Expanded(
 flex: 2,
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
 if (deliverable.description.isNotEmpty)
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
 ),
 ),
 Expanded(child: _buildPhaseChip(deliverable.phase)),
 Expanded(child: _buildStatusChip(deliverable.status)),
 Expanded(child: _buildPriorityChip(deliverable.priority)),
 Expanded(
 child: Text(
 deliverable.assigneeName ?? 'Unassigned',
 style: _cellStyle,
 ),
 ),
 Expanded(
 child: Text(
 deliverable.dueDate != null
 ? '${deliverable.dueDate!.month}/${deliverable.dueDate!.day}/${deliverable.dueDate!.year}'
 : '-',
 style: _cellStyle.copyWith(
 color: deliverable.isOverdue ? Colors.red : null,
 ),
 ),
 ),
 Expanded(
 child: Text(
 deliverable.sourceTypeLabel,
 style: _cellStyle,
 ),
 ),
 SizedBox(
 width: 80,
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 18),
 onPressed: () => _editDeliverable(deliverable),
 tooltip: 'Edit',
 ),
 IconButton(
 icon: const Icon(Icons.delete_outlined, size: 18),
 onPressed: () => _deleteDeliverable(deliverable),
 tooltip: 'Delete',
 ),
 ],
 ),
 ),
 ],
 ),
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

 return Icon(icon, color: color, size: 18);
 }

 Widget _buildPhaseChip(DeliverablePhase phase) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: _getPhaseColor(phase).withOpacity(0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 _getPhaseLabel(phase),
 style: TextStyle(
 fontSize: 12,
 color: _getPhaseColor(phase),
 ),
 ),
 );
 }

 Widget _buildStatusChip(RoadmapDeliverableStatus status) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: _getStatusColor(status).withOpacity(0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 _getStatusLabel(status),
 style: TextStyle(
 fontSize: 12,
 color: _getStatusColor(status),
 fontWeight: FontWeight.w500,
 ),
 ),
 );
 }

 Widget _buildPriorityChip(RoadmapDeliverablePriority priority) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: _getPriorityColor(priority).withOpacity(0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 _getPriorityLabel(priority),
 style: TextStyle(
 fontSize: 12,
 color: _getPriorityColor(priority),
 ),
 ),
 );
 }

 Color _getPhaseColor(DeliverablePhase phase) {
 switch (phase) {
 case DeliverablePhase.initiation:
 return const Color(0xFF3B82F6);
 case DeliverablePhase.frontEndPlanning:
 return const Color(0xFF8B5CF6);
 case DeliverablePhase.planning:
 return const Color(0xFF10B981);
 case DeliverablePhase.design:
 return const Color(0xFFEC4899);
 case DeliverablePhase.execution:
 return const Color(0xFFF59E0B);
 case DeliverablePhase.launch:
 return const Color(0xFF14B8A6);
 }
 }

 Color _getStatusColor(RoadmapDeliverableStatus status) {
 switch (status) {
 case RoadmapDeliverableStatus.completed:
 return Colors.green;
 case RoadmapDeliverableStatus.inProgress:
 return Colors.orange;
 case RoadmapDeliverableStatus.notStarted:
 return Colors.grey;
 case RoadmapDeliverableStatus.atRisk:
 return Colors.orange;
 case RoadmapDeliverableStatus.blocked:
 return Colors.red;
 }
 }

 Color _getPriorityColor(RoadmapDeliverablePriority priority) {
 switch (priority) {
 case RoadmapDeliverablePriority.critical:
 return Colors.red;
 case RoadmapDeliverablePriority.high:
 return Colors.orange;
 case RoadmapDeliverablePriority.medium:
 return Colors.yellow.shade700;
 case RoadmapDeliverablePriority.low:
 return Colors.green;
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

 String _getStatusLabel(RoadmapDeliverableStatus status) {
 switch (status) {
 case RoadmapDeliverableStatus.notStarted:
 return 'Not Started';
 case RoadmapDeliverableStatus.inProgress:
 return 'In Progress';
 case RoadmapDeliverableStatus.completed:
 return 'Completed';
 case RoadmapDeliverableStatus.atRisk:
 return 'At Risk';
 case RoadmapDeliverableStatus.blocked:
 return 'Blocked';
 }
 }

 String _getPriorityLabel(RoadmapDeliverablePriority priority) {
 switch (priority) {
 case RoadmapDeliverablePriority.critical:
 return 'Critical';
 case RoadmapDeliverablePriority.high:
 return 'High';
 case RoadmapDeliverablePriority.medium:
 return 'Medium';
 case RoadmapDeliverablePriority.low:
 return 'Low';
 }
 }

 String _getCategoryLabel(DeliverableCategory category) {
 switch (category) {
 case DeliverableCategory.governance:
 return 'Governance';
 case DeliverableCategory.requirements:
 return 'Requirements';
 case DeliverableCategory.riskCompliance:
 return 'Risk & Compliance';
 case DeliverableCategory.execution:
 return 'Execution';
 case DeliverableCategory.technical:
 return 'Technical';
 case DeliverableCategory.quality:
 return 'Quality';
 case DeliverableCategory.contractsProcurement:
 return 'Contracts & Procurement';
 case DeliverableCategory.scheduleCost:
 return 'Schedule & Cost';
 case DeliverableCategory.teamStakeholders:
 return 'Team & Stakeholders';
 }
 }

 void _showAddDeliverableDialog() {
 showDialog(
 context: context,
 builder: (context) => _AddDeliverableDialog(
 onSubmit: (deliverable) async {
 final projectId = _projectId;
 if (projectId == null) return;

 try {
 await DeliverableAggregationService.instance.createNewDeliverable(
 projectId: projectId,
 title: deliverable['title'],
 description: deliverable['description'] ?? '',
 category: deliverable['category'],
 assignee: deliverable['assignee'],
 dueDate: deliverable['dueDate'],
 priority: deliverable['priority'],
 );
 _loadData();
 if (mounted) Navigator.of(context).pop();
 } catch (e) {
 debugPrint('Error adding deliverable: $e');
 }
 },
 ),
 );
 }

 void _editDeliverable(AggregatedDeliverable deliverable) {
 showDialog(
 context: context,
 builder: (context) => _EditDeliverableDialog(
 deliverable: deliverable,
 onSubmit: (updated) async {
 final projectId = _projectId;
 if (projectId == null) return;

 try {
 await DeliverableAggregationService.instance.syncDeliverableToSource(
 projectId: projectId,
 deliverable: updated,
 context: context,
 );
 _loadData();
 if (mounted) Navigator.of(context).pop();
 } catch (e) {
 debugPrint('Error updating deliverable: $e');
 }
 },
 ),
 );
 }

 void _deleteDeliverable(AggregatedDeliverable deliverable) {
 showDialog(
 context: context,
 builder: (context) => AlertDialog(
 title: const Text('Delete Deliverable'),
 content: Text(
 'Are you sure you want to delete "${deliverable.title}"?',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel'),
 ),
 TextButton(
 onPressed: () async {
 // TODO: Implement delete
 Navigator.of(context).pop();
 },
 style: TextButton.styleFrom(foregroundColor: Colors.red),
 child: const Text('Delete'),
 ),
 ],
 ),
 );
 }

 static const TextStyle _headerStyle = TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.8,
 color: Color(0xFF6B7280),
 );

 static const TextStyle _cellStyle = TextStyle(
 fontSize: 14,
 color: Color(0xFF374151),
 );

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Deliverables Roadmap Detailed',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_deliverables_roadmap_detailed_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _AddDeliverableDialog extends StatefulWidget {
 final Function(Map<String, dynamic>) onSubmit;

 const _AddDeliverableDialog({required this.onSubmit});

 @override
 State<_AddDeliverableDialog> createState() => _AddDeliverableDialogState();
}

class _AddDeliverableDialogState extends State<_AddDeliverableDialog> {
 final _formKey = GlobalKey<FormState>();
 final _titleController = TextEditingController();
 final _descriptionController = TextEditingController();
 final _assigneeController = TextEditingController();

 DeliverableCategory _selectedCategory = DeliverableCategory.governance;
 RoadmapDeliverablePriority _selectedPriority = RoadmapDeliverablePriority.medium;
 DateTime? _selectedDueDate;

 @override
 void dispose() {
 _titleController.dispose();
 _descriptionController.dispose();
 _assigneeController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return AlertDialog(
 title: const Text('Add Deliverable'),
 content: SingleChildScrollView(
 child: Form(
 key: _formKey,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 VoiceTextFormField(
 controller: _titleController,
 decoration: const InputDecoration(
 labelText: 'Title *',
 border: OutlineInputBorder(),
 ),
 validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
 ),
 const SizedBox(height: 16),
 VoiceTextFormField(
 controller: _descriptionController,
 maxLines: 3,
 decoration: const InputDecoration(
 labelText: 'Description',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 16),
 DropdownButtonFormField<DeliverableCategory>(
 value: _selectedCategory,
 decoration: const InputDecoration(
 labelText: 'Category *',
 border: OutlineInputBorder(),
 ),
 items: DeliverableCategory.values
 .map((c) => DropdownMenuItem(
 value: c,
 child: Text(_getCategoryLabel(c)),
 ))
 .toList(),
 onChanged: (v) => setState(() => _selectedCategory = v!),
 ),
 const SizedBox(height: 16),
 DropdownButtonFormField<RoadmapDeliverablePriority>(
 value: _selectedPriority,
 decoration: const InputDecoration(
 labelText: 'Priority',
 border: OutlineInputBorder(),
 ),
 items: RoadmapDeliverablePriority.values
 .map((p) => DropdownMenuItem(
 value: p,
 child: Text(_getPriorityLabel(p)),
 ))
 .toList(),
 onChanged: (v) => setState(() => _selectedPriority = v!),
 ),
 const SizedBox(height: 16),
 VoiceTextFormField(
 controller: _assigneeController,
 decoration: const InputDecoration(
 labelText: 'Assignee',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 16),
 InkWell(
 onTap: () async {
 final date = await showDatePicker(
 context: context,
 initialDate: DateTime.now(),
 firstDate: DateTime.now(),
 lastDate: DateTime.now().add(const Duration(days: 365)),
 );
 if (date != null) {
 setState(() => _selectedDueDate = date);
 }
 },
 child: InputDecorator(
 decoration: const InputDecoration(
 labelText: 'Due Date',
 border: OutlineInputBorder(),
 ),
 child: Text(
 _selectedDueDate != null
 ? '${_selectedDueDate!.month}/${_selectedDueDate!.day}/${_selectedDueDate!.year}'
 : 'Select date',
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 if (_formKey.currentState!.validate()) {
 widget.onSubmit({
 'title': _titleController.text,
 'description': _descriptionController.text,
 'category': _selectedCategory,
 'priority': _selectedPriority,
 'assignee': _assigneeController.text.isNotEmpty ? _assigneeController.text : null,
 'dueDate': _selectedDueDate,
 });
 }
 },
 child: const Text('Add'),
 ),
 ],
 );
 }

 String _getCategoryLabel(DeliverableCategory category) {
 switch (category) {
 case DeliverableCategory.governance:
 return 'Governance';
 case DeliverableCategory.requirements:
 return 'Requirements';
 case DeliverableCategory.riskCompliance:
 return 'Risk & Compliance';
 case DeliverableCategory.execution:
 return 'Execution';
 case DeliverableCategory.technical:
 return 'Technical';
 case DeliverableCategory.quality:
 return 'Quality';
 case DeliverableCategory.contractsProcurement:
 return 'Contracts & Procurement';
 case DeliverableCategory.scheduleCost:
 return 'Schedule & Cost';
 case DeliverableCategory.teamStakeholders:
 return 'Team & Stakeholders';
 }
 }

 String _getPriorityLabel(RoadmapDeliverablePriority priority) {
 switch (priority) {
 case RoadmapDeliverablePriority.critical:
 return 'Critical';
 case RoadmapDeliverablePriority.high:
 return 'High';
 case RoadmapDeliverablePriority.medium:
 return 'Medium';
 case RoadmapDeliverablePriority.low:
 return 'Low';
 }
 }
}

class _EditDeliverableDialog extends StatefulWidget {
 final AggregatedDeliverable deliverable;
 final Function(AggregatedDeliverable) onSubmit;

 const _EditDeliverableDialog({
 required this.deliverable,
 required this.onSubmit,
 });

 @override
 State<_EditDeliverableDialog> createState() => _EditDeliverableDialogState();
}

class _EditDeliverableDialogState extends State<_EditDeliverableDialog> {
 late final TextEditingController _titleController;
 late final TextEditingController _descriptionController;
 late RoadmapDeliverableStatus _selectedStatus;
 late RoadmapDeliverablePriority _selectedPriority;
 DateTime? _selectedDueDate;

 @override
 void initState() {
 super.initState();
 _titleController = TextEditingController(text: widget.deliverable.title);
 _descriptionController = TextEditingController(text: widget.deliverable.description);
 _selectedStatus = widget.deliverable.status;
 _selectedPriority = widget.deliverable.priority;
 _selectedDueDate = widget.deliverable.dueDate;
 }

 @override
 void dispose() {
 _titleController.dispose();
 _descriptionController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return AlertDialog(
 title: const Text('Edit Deliverable'),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 VoiceTextField(
 controller: _titleController,
 decoration: const InputDecoration(
 labelText: 'Title',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 16),
 VoiceTextField(
 controller: _descriptionController,
 maxLines: 3,
 decoration: const InputDecoration(
 labelText: 'Description',
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 16),
 DropdownButtonFormField<RoadmapDeliverableStatus>(
 value: _selectedStatus,
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 ),
 items: RoadmapDeliverableStatus.values
 .map((s) => DropdownMenuItem(
 value: s,
 child: Text(_getStatusLabel(s)),
 ))
 .toList(),
 onChanged: (v) => setState(() => _selectedStatus = v!),
 ),
 const SizedBox(height: 16),
 DropdownButtonFormField<RoadmapDeliverablePriority>(
 value: _selectedPriority,
 decoration: const InputDecoration(
 labelText: 'Priority',
 border: OutlineInputBorder(),
 ),
 items: RoadmapDeliverablePriority.values
 .map((p) => DropdownMenuItem(
 value: p,
 child: Text(_getPriorityLabel(p)),
 ))
 .toList(),
 onChanged: (v) => setState(() => _selectedPriority = v!),
 ),
 const SizedBox(height: 16),
 InkWell(
 onTap: () async {
 final date = await showDatePicker(
 context: context,
 initialDate: _selectedDueDate ?? DateTime.now(),
 firstDate: DateTime.now(),
 lastDate: DateTime.now().add(const Duration(days: 365)),
 );
 if (date != null) {
 setState(() => _selectedDueDate = date);
 }
 },
 child: InputDecorator(
 decoration: const InputDecoration(
 labelText: 'Due Date',
 border: OutlineInputBorder(),
 ),
 child: Text(
 _selectedDueDate != null
 ? '${_selectedDueDate!.month}/${_selectedDueDate!.day}/${_selectedDueDate!.year}'
 : 'Select date',
 ),
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 widget.onSubmit(widget.deliverable.copyWith(
 title: _titleController.text,
 description: _descriptionController.text,
 status: _selectedStatus,
 priority: _selectedPriority,
 dueDate: _selectedDueDate,
 ));
 },
 child: const Text('Save'),
 ),
 ],
 );
 }

 String _getStatusLabel(RoadmapDeliverableStatus status) {
 switch (status) {
 case RoadmapDeliverableStatus.notStarted:
 return 'Not Started';
 case RoadmapDeliverableStatus.inProgress:
 return 'In Progress';
 case RoadmapDeliverableStatus.completed:
 return 'Completed';
 case RoadmapDeliverableStatus.atRisk:
 return 'At Risk';
 case RoadmapDeliverableStatus.blocked:
 return 'Blocked';
 }
 }

 String _getPriorityLabel(RoadmapDeliverablePriority priority) {
 switch (priority) {
 case RoadmapDeliverablePriority.critical:
 return 'Critical';
 case RoadmapDeliverablePriority.high:
 return 'High';
 case RoadmapDeliverablePriority.medium:
 return 'Medium';
 case RoadmapDeliverablePriority.low:
 return 'Low';
 }
 }
}

class _NavCircleBtn extends StatelessWidget {
 const _NavCircleBtn({required this.icon, this.onTap});

 final IconData icon;
 final VoidCallback? onTap;

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(18),
 child: Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: Colors.white,
 shape: BoxShape.circle,
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
 ),
 );
 }
}
