import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/roadmap_deliverable.dart';
import '../models/roadmap_sprint.dart';
import '../services/roadmap_service.dart';
import '../providers/project_data_provider.dart';
import '../widgets/initiation_like_sidebar.dart';
import '../widgets/draggable_sidebar.dart';
import '../widgets/kaz_ai_chat_bubble.dart';
import '../widgets/responsive.dart';
import '../widgets/planning_ai_notes_card.dart';
import '../widgets/launch_phase_navigation.dart';
import '../utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
const Color _kBackground = Colors.white;
const Color _kAccent = Color(0xFFFFC812);
const Color _kHeadline = Color(0xFF1A1D1F);
const Color _kMuted = Color(0xFF6B7280);
const Color _kCardBorder = Color(0xFFE4E7EC);
const double _kColumnMinWidth = 270.0;

class DeliverablesRoadmapScreen extends StatelessWidget {
 const DeliverablesRoadmapScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const DeliverablesRoadmapScreen()),
 );
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
 activeItemLabel: 'Deliverables Roadmap'),
 ),
 const Expanded(child: _DeliverablesRoadmapBody()),
 ],
 ),
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Deliverables Roadmap',
 ),
 ),
 const KazAiChatBubble(),
 ],
 ),
 );
 }
}

class _DeliverablesRoadmapBody extends StatefulWidget {
 const _DeliverablesRoadmapBody();

 @override
 State<_DeliverablesRoadmapBody> createState() =>
 _DeliverablesRoadmapBodyState();
}

class _DeliverablesRoadmapBodyState extends State<_DeliverablesRoadmapBody> {
 List<RoadmapSprint> _sprints = [];
 List<RoadmapDeliverable> _deliverables = [];
 bool _isLoading = false;
 bool _hasLoaded = false;
 String? _filterStatus;
 bool _isSaving = false;
 Timer? _saveDebounce;

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
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
 }

 @override
 void didChangeDependencies() {
 super.didChangeDependencies();
 if (!_hasLoaded) {
 _loadData();
 }
 }

 @override
 void dispose() {
 _saveDebounce?.cancel();
 super.dispose();
 }

 Future<void> _loadData() async {
 final projectId = _projectId;
 if (projectId == null) {
 await Future.delayed(const Duration(milliseconds: 300));
 if (!mounted) return;
 final retryId = _projectId;
 if (retryId == null) return;
 return _loadDataWithId(retryId);
 }
 return _loadDataWithId(projectId);
 }

 Future<void> _loadDataWithId(String projectId) async {
 if (_hasLoaded) return;
 setState(() => _isLoading = true);
 try {
 final result = await RoadmapService.loadAll(projectId: projectId);
 if (mounted) {
 setState(() {
 _sprints = result.sprints;
 _deliverables = result.deliverables;
 _isLoading = false;
 _hasLoaded = true;
 });
 }
 } catch (e) {
 debugPrint('Error loading roadmap: $e');
 if (mounted) setState(() => _isLoading = false);
 }
 }

 List<RoadmapDeliverable> _filteredForSprint(String sprintId) {
 var items = _deliverables.where((d) => d.sprintId == sprintId).toList();
 if (_filterStatus != null) {
 items = items.where((d) => d.statusLabel == _filterStatus).toList();
 }
 items.sort((a, b) => a.order.compareTo(b.order));
 return items;
 }

 int get _totalCount => _deliverables.length;
 int get _completedCount => _deliverables
 .where((d) => d.status == RoadmapDeliverableStatus.completed)
 .length;
 int get _inProgressCount => _deliverables
 .where((d) => d.status == RoadmapDeliverableStatus.inProgress)
 .length;
 int get _atRiskCount => _deliverables
 .where((d) =>
 d.status == RoadmapDeliverableStatus.atRisk ||
 d.status == RoadmapDeliverableStatus.blocked)
 .length;

 void _scheduleSave() {
 _saveDebounce?.cancel();
 _saveDebounce = Timer(const Duration(milliseconds: 500), () {
 _saveAll();
 });
 }

 Future<void> _saveAll() async {
 if (_isSaving) return;
 final projectId = _projectId;
 if (projectId == null) return;
 final uid = FirebaseAuth.instance.currentUser?.uid;
 try {
 setState(() => _isSaving = true);
 await RoadmapService.saveAll(
 projectId: projectId,
 sprints: _sprints,
 deliverables: _deliverables,
 userId: uid,
 );
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Roadmap saved'),
 duration: Duration(seconds: 2),
 ),
 );
 } catch (e) {
 debugPrint('Error saving roadmap: $e');
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Unable to save: $e'),
 backgroundColor: Colors.red,
 ),
 );
 } finally {
 if (mounted) setState(() => _isSaving = false);
 }
 }

 void _handleAddSprint() async {
 final result = await _showSprintDialog(context);
 if (result == null) return;
 setState(() {
 _sprints.add(RoadmapSprint(
 name: result['name'] ?? '',
 startDate: result['startDate'] as DateTime?,
 endDate: result['endDate'] as DateTime?,
 goal: result['goal'] ?? '',
 order: _sprints.length,
 createdById: FirebaseAuth.instance.currentUser?.uid ?? '',
 createdByEmail: FirebaseAuth.instance.currentUser?.email ?? '',
 createdByName: FirebaseAuth.instance.currentUser?.displayName ?? '',
));
 });
 _scheduleSave();
 }

 void _handleDeleteDeliverable(int index) async {
 final item = _deliverables[index];
 final confirmed = await _showConfirmDialog(
 'Delete Deliverable',
 'Delete "${item.title}"?',
 );
 if (confirmed != true) return;
 setState(() => _deliverables.removeAt(index));
 _scheduleSave();
 }

 void _handleMoveDeliverable(int deliverableIndex, String newSprintId) async {
 setState(() {
 _deliverables[deliverableIndex] =
 _deliverables[deliverableIndex].copyWith(sprintId: newSprintId);
 });
 _scheduleSave();
 }

 void _handleEditSprint(int index) async {
 if (index < 0 || index >= _sprints.length) return;
 final sprint = _sprints[index];
 final result = await _showSprintDialog(context, existing: sprint);
 if (result == null) return;
 setState(() {
 _sprints[index] = sprint.copyWith(
 name: result['name'],
 startDate: result['startDate'] as DateTime?,
 endDate: result['endDate'] as DateTime?,
 goal: result['goal'],
 );
 });
 _scheduleSave();
 }

 void _handleDeleteSprint(int index) async {
 final sprint = _sprints[index];
 final hasItems = _deliverables.any((d) => d.sprintId == sprint.id);
 final confirmed = await _showConfirmDialog(
 'Delete Sprint',
 hasItems
 ? '${sprint.name} has deliverables. Deleting will unassign them. Continue?'
 : 'Delete ${sprint.name}?',
 );
 if (confirmed != true) return;
 setState(() {
 for (var i = 0; i < _deliverables.length; i++) {
 if (_deliverables[i].sprintId == sprint.id) {
 _deliverables[i] = _deliverables[i].copyWith(sprintId: '');
 }
 }
 _sprints.removeAt(index);
 for (var i = 0; i < _sprints.length; i++) {
 _sprints[i] = _sprints[i].copyWith(order: i);
 }
 });
 _scheduleSave();
 }

 void _handleAddDeliverable(String sprintId) async {
 final result = await _showDeliverableDialog(
 context,
 sprints: _sprints,
 selectedSprintId: sprintId,
 allDeliverables: _deliverables,
 );
 if (result == null) return;
 setState(() {
 _deliverables.add(RoadmapDeliverable(
 title: result['title'] ?? '',
 description: result['description'] ?? '',
 sprintId: result['sprintId'] ?? sprintId,
 assignee: result['assignee'] ?? '',
 dueDate: result['dueDate'] as DateTime?,
 status: result['status'] as RoadmapDeliverableStatus? ??
 RoadmapDeliverableStatus.notStarted,
 priority: result['priority'] as RoadmapDeliverablePriority? ??
 RoadmapDeliverablePriority.medium,
 storyPoints: result['storyPoints'] as int? ?? 1,
 dependencies: result['dependencies'] as List<String>? ?? [],
 blockers: result['blockers'] ?? '',
 acceptanceCriteria: result['acceptanceCriteria'] ?? '',
 notes: result['notes'] ?? '',
 order: _deliverables.length,
 createdById: FirebaseAuth.instance.currentUser?.uid ?? '',
 createdByEmail: FirebaseAuth.instance.currentUser?.email ?? '',
 createdByName: FirebaseAuth.instance.currentUser?.displayName ?? '',
 ));
 });
 _scheduleSave();
 }

 void _handleEditDeliverable(int index) async {
 if (index < 0 || index >= _deliverables.length) return;
 final item = _deliverables[index];
 final result = await _showDeliverableDialog(
 context,
 sprints: _sprints,
 selectedSprintId: item.sprintId,
 existing: item,
 allDeliverables: _deliverables,
 );
 if (result == null) return;
 setState(() {
 _deliverables[index] = item.copyWith(
 title: result['title'],
 description: result['description'],
 sprintId: result['sprintId'],
 assignee: result['assignee'],
 dueDate: result['dueDate'] as DateTime?,
 status: result['status'] as RoadmapDeliverableStatus?,
 priority: result['priority'] as RoadmapDeliverablePriority?,
 storyPoints: result['storyPoints'] as int?,
 dependencies: result['dependencies'] as List<String>?,
 blockers: result['blockers'],
 acceptanceCriteria: result['acceptanceCriteria'],
 notes: result['notes'],
 );
 });
 _scheduleSave();
 }

 @override
 Widget build(BuildContext context) {
 final user = FirebaseAuth.instance.currentUser;
 final displayName = _displayName(user);
 final subtitle = _displaySubtitle(user);
 final initials = _initialsFor(displayName);

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
 color: _kBackground,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(
 title: 'Deliverables Roadmap',
onBack: () => PlanningPhaseNavigation.goToPrevious(
 context, 'deliverables_roadmap'),
 onForward: () =>
 PlanningPhaseNavigation.goToNext(context, 'deliverables_roadmap'), onExportPdf: _exportPdf),
 const SizedBox(height: 24),
 _buildStatsRow(),
 const SizedBox(height: 16),
 _buildFilterBar(),
 const SizedBox(height: 20),
 const PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Deliverable Roadmap',
 noteKey: 'planning_deliverable_roadmap_notes',
 checkpoint: 'deliverables_roadmap',
 description:
 'Summarize roadmap milestones, delivery pacing, and risk flags.',
 ),
 const SizedBox(height: 24),
 Expanded(
 child: _isLoading
 ? const Center(child: CircularProgressIndicator())
 : _buildKanbanBoard(),
 ),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel('deliverables_roadmap'),
 nextLabel: PlanningPhaseNavigation.nextLabel('deliverables_roadmap'),
 onBack: () => PlanningPhaseNavigation.goToPrevious(
 context, 'deliverables_roadmap'),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context, 'deliverables_roadmap'),
 ),
 ],
 ),
 );
 }

 Widget _buildStatsRow() {
 return Wrap(
 spacing: 14,
 runSpacing: 14,
 children: [
 _StatCard(
 label: 'Total Deliverables',
 value: '$_totalCount',
 accent: const Color(0xFF2563EB),
 ),
 _StatCard(
 label: 'Completed',
 value: '$_completedCount',
 accent: const Color(0xFF10B981),
 ),
 _StatCard(
 label: 'In Progress',
 value: '$_inProgressCount',
 accent: const Color(0xFFF97316),
 ),
 _StatCard(
 label: 'At Risk / Blocked',
 value: '$_atRiskCount',
 accent: const Color(0xFFEF4444),
 ),
 _StatCard(
 label: 'Sprints',
 value: '${_sprints.length}',
 accent: const Color(0xFF8B5CF6),
 ),
 ],
 );
 }

 Widget _buildFilterBar() {
 return Row(
 children: [
 const Text(
 'Filter by status:',
 style: TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600, color: _kMuted),
 ),
 const SizedBox(width: 10),
 _FilterChip(
 label: 'All',
 selected: _filterStatus == null,
 onTap: () => setState(() => _filterStatus = null),
 ),
 ...RoadmapDeliverableStatus.values.map((status) {
 final label = _statusLabel(status);
 return Padding(
 padding: const EdgeInsets.only(left: 8),
 child: _FilterChip(
 label: label,
 selected: _filterStatus == label,
 onTap: () => setState(() => _filterStatus = label),
 ),
 );
 }),
 ],
 );
 }

 Widget _buildKanbanBoard() {
 if (_sprints.isEmpty) {
 return _EmptyState(
 title: 'No sprint roadmap yet',
 message: 'Create sprints to organize your deliverables.',
 icon: Icons.view_week_outlined,
 actionLabel: 'Add Sprint',
 onAction: _handleAddSprint,
 );
 }

 return LayoutBuilder(
 builder: (context, constraints) {
 final totalGap = 18.0 * (_sprints.length);
 final available = constraints.maxWidth - totalGap;
 final colWidth = available / (_sprints.length + 1);
 final needsHScroll = colWidth < _kColumnMinWidth ||
 (_sprints.length + 1) * _kColumnMinWidth + totalGap >
 constraints.maxWidth;
 final resolvedWidth = needsHScroll ? _kColumnMinWidth : colWidth;

 List<Widget> columns() {
 return [
 for (var i = 0; i < _sprints.length; i++) ...[
 SizedBox(
 width: resolvedWidth,
 child: _buildSprintColumn(i),
 ),
 const SizedBox(width: 18),
 ],
 SizedBox(
 width: resolvedWidth,
 child: _buildAddSprintCard(),
 ),
 ];
 }

 Widget board = Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: columns(),
 );

 if (needsHScroll) {
 board = SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: board,
 );
 }

 return SingleChildScrollView(child: board);
 },
 );
 }

 Widget _buildSprintColumn(int sprintIndex) {
 final sprint = _sprints[sprintIndex];
 final items = _filteredForSprint(sprint.id);
 final totalPoints = items.fold<int>(0, (sum, d) => sum + d.storyPoints);

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
 decoration: BoxDecoration(
 color: const Color(0xFFF2F4FA),
 borderRadius: BorderRadius.circular(26),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 sprint.name,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w800,
 color: _kHeadline,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 if (sprint.dateRangeLabel.isNotEmpty) ...[
 const SizedBox(height: 2),
 Text(
 sprint.dateRangeLabel,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: _kMuted),
 ),
 ],
 ],
 ),
 ),
 _SprintMenu(
 onEdit: () => _handleEditSprint(sprintIndex),
 onDelete: () => _handleDeleteSprint(sprintIndex),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Text(
 '$totalPoints pts · ${items.length} items',
 style: const TextStyle(
 fontSize: 11, fontWeight: FontWeight.w600, color: _kMuted),
 ),
 if (sprint.goal.isNotEmpty) ...[
 const SizedBox(height: 6),
 Text(
 sprint.goal,
 style: const TextStyle(fontSize: 11, color: _kMuted, height: 1.3),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 const SizedBox(height: 14),
 for (final item in items)
 _DeliverableCard(
 item: item,
 sprints: _sprints,
 allDeliverables: _deliverables,
 onEdit: () {
 final idx = _deliverables.indexWhere((d) => d.id == item.id);
 if (idx >= 0) _handleEditDeliverable(idx);
 },
 onDelete: () {
 final idx = _deliverables.indexWhere((d) => d.id == item.id);
 if (idx >= 0) _handleDeleteDeliverable(idx);
 },
 onMove: (newSprintId) {
 final idx = _deliverables.indexWhere((d) => d.id == item.id);
 if (idx >= 0) _handleMoveDeliverable(idx, newSprintId);
 },
 ),
 const SizedBox(height: 8),
 GestureDetector(
 onTap: () => _handleAddDeliverable(sprint.id),
 child: Container(
 padding: const EdgeInsets.symmetric(vertical: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(
 color: _kAccent.withOpacity(0.4),
 style: BorderStyle.solid),
 ),
 child: const Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(Icons.add, size: 16, color: Color(0xFFD97706)),
 SizedBox(width: 6),
 Text(
 'Add Deliverable',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFFD97706),
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildAddSprintCard() {
 return GestureDetector(
 onTap: _handleAddSprint,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(26),
 border: Border.all(
 color: _kAccent.withOpacity(0.3), style: BorderStyle.solid),
 ),
 child: const Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 SizedBox(height: 24),
 Icon(Icons.add_circle_outline, size: 36, color: Color(0xFFD97706)),
 SizedBox(height: 10),
 Text(
 'Add Sprint',
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFFD97706),
 ),
 ),
 SizedBox(height: 24),
 ],
 ),
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Deliverables Roadmap',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_deliverables_roadmap_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _StatCard extends StatelessWidget {
 const _StatCard(
 {required this.label, required this.value, required this.accent});
 final String label;
 final String value;
 final Color accent;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: 170,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: _kCardBorder),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 6)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label, style: const TextStyle(fontSize: 11, color: _kMuted)),
 const SizedBox(height: 4),
 Text(
 value,
 style: TextStyle(
 fontSize: 20, fontWeight: FontWeight.w700, color: accent),
 ),
 ],
 ),
 );
 }
}

class _FilterChip extends StatelessWidget {
 const _FilterChip(
 {required this.label, required this.selected, required this.onTap});
 final String label;
 final bool selected;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 return GestureDetector(
 onTap: onTap,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: selected ? _kAccent.withOpacity(0.15) : Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: selected ? _kAccent : _kCardBorder),
 ),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: selected ? const Color(0xFFD97706) : _kMuted,
 ),
 ),
 ),
 );
 }
}

class _SprintMenu extends StatelessWidget {
 const _SprintMenu({required this.onEdit, required this.onDelete});
 final VoidCallback onEdit;
 final VoidCallback onDelete;

 @override
 Widget build(BuildContext context) {
 return PopupMenuButton<String>(
 padding: EdgeInsets.zero,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 onSelected: (v) {
 if (v == 'edit') onEdit();
 if (v == 'delete') onDelete();
 },
 itemBuilder: (_) => [
 const PopupMenuItem(value: 'edit', child: Text('Edit Sprint')),
 const PopupMenuItem(
 value: 'delete',
 child: Text('Delete Sprint',
 style: TextStyle(color: Color(0xFFEF4444)))),
 ],
 child: Container(
 width: 28,
 height: 28,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: _kCardBorder),
 ),
 child: const Icon(Icons.more_horiz, size: 16, color: _kMuted),
 ),
 );
 }
}

class _DeliverableCard extends StatelessWidget {
 const _DeliverableCard({
 required this.item,
 required this.sprints,
 required this.allDeliverables,
 required this.onEdit,
 required this.onDelete,
 required this.onMove,
 });

 final RoadmapDeliverable item;
 final List<RoadmapSprint> sprints;
 final List<RoadmapDeliverable> allDeliverables;
 final VoidCallback onEdit;
 final VoidCallback onDelete;
 final void Function(String newSprintId) onMove;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 margin: const EdgeInsets.only(bottom: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: Colors.white),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 10,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Stack(
 children: [
 Positioned.fill(
 child: ClipRRect(
 borderRadius: BorderRadius.circular(18),
 child: Align(
 alignment: Alignment.centerLeft,
 child: Container(
 width: 6,
 decoration: BoxDecoration(
 color: _statusColor(item.status),
 borderRadius: const BorderRadius.horizontal(
 left: Radius.circular(18)),
 ),
 ),
 ),
 ),
 ),
 Padding(
 padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Text(
 item.title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w800,
 color: _kHeadline),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 const SizedBox(width: 8),
 _PopupMenu(
 sprints: sprints,
 currentSprintId: item.sprintId,
 onEdit: onEdit,
 onDelete: onDelete,
 onMove: onMove,
 ),
 ],
 ),
 const SizedBox(height: 8),
 Row(
 children: [
 _StatusChip(status: item.status),
 const SizedBox(width: 6),
 _PriorityDot(priority: item.priority),
 const Spacer(),
 Text(
 '${item.storyPoints} pts',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: _kMuted),
 ),
 ],
 ),
 if (item.assignee.isNotEmpty) ...[
 const SizedBox(height: 8),
 Row(
 children: [
 const Icon(Icons.person_outline,
 size: 12, color: _kMuted),
 const SizedBox(width: 4),
 Expanded(
 child: Text(
 item.assignee,
 style: const TextStyle(fontSize: 11, color: _kMuted),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 ],
 if (item.dueDate != null) ...[
 const SizedBox(height: 4),
 Row(
 children: [
 Icon(Icons.calendar_today_outlined,
 size: 11,
 color: item.isOverdue
 ? const Color(0xFFEF4444)
 : _kMuted),
 const SizedBox(width: 4),
 Text(
 '${item.dueDate!.month}/${item.dueDate!.day}/${item.dueDate!.year}',
 style: TextStyle(
 fontSize: 11,
 color: item.isOverdue
 ? const Color(0xFFEF4444)
 : _kMuted,
 ),
 ),
 if (item.isOverdue) ...[
 const SizedBox(width: 4),
 const Text('OVERDUE',
 style: TextStyle(
 fontSize: 9,
 fontWeight: FontWeight.w800,
 color: Color(0xFFEF4444),
 )),
 ],
 ],
 ),
 ],
 if (item.dependencies.isNotEmpty) ...[
 const SizedBox(height: 4),
 Row(
 children: [
 const Icon(Icons.link, size: 11, color: _kMuted),
 const SizedBox(width: 4),
 Text(
 '${item.dependencies.length} dependenc${item.dependencies.length == 1 ? 'y' : 'ies'}',
 style: const TextStyle(fontSize: 11, color: _kMuted),
 ),
 ],
 ),
 ],
 ],
 ),
 ),
 ],
 ),
 );
 }
}

class _PopupMenu extends StatelessWidget {
 const _PopupMenu({
 required this.sprints,
 required this.currentSprintId,
 required this.onEdit,
 required this.onDelete,
 required this.onMove,
 });

 final List<RoadmapSprint> sprints;
 final String currentSprintId;
 final VoidCallback onEdit;
 final VoidCallback onDelete;
 final void Function(String) onMove;

 @override
 Widget build(BuildContext context) {
 return PopupMenuButton<String>(
 padding: EdgeInsets.zero,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 onSelected: (v) {
 if (v == 'edit') return onEdit();
 if (v == 'delete') return onDelete();
 if (v.startsWith('move:')) onMove(v.substring(5));
 },
 itemBuilder: (_) => [
 const PopupMenuItem(value: 'edit', child: Text('Edit')),
 ...sprints
 .where((s) => s.id != currentSprintId)
 .map((s) => PopupMenuItem(
 value: 'move:${s.id}',
 child: Text('Move to ${s.name}'),
 )),
 const PopupMenuItem(
 value: 'delete',
 child: Text('Delete', style: TextStyle(color: Color(0xFFEF4444)))),
 ],
 child: const Icon(Icons.more_vert, size: 16, color: _kMuted),
 );
 }
}

class _StatusChip extends StatelessWidget {
 const _StatusChip({required this.status});
 final RoadmapDeliverableStatus status;

 @override
 Widget build(BuildContext context) {
 final color = _statusColor(status);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 _statusLabel(status),
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 );
 }
}

class _PriorityDot extends StatelessWidget {
 const _PriorityDot({required this.priority});
 final RoadmapDeliverablePriority priority;

 @override
 Widget build(BuildContext context) {
 final color = _priorityColor(priority);
 return Container(
 width: 8,
 height: 8,
 decoration: BoxDecoration(
 color: color,
 shape: BoxShape.circle,
 ),
 );
 }
}

class _EmptyState extends StatelessWidget {
 const _EmptyState({
 required this.title,
 required this.message,
 required this.icon,
 this.actionLabel,
 this.onAction,
 });

 final String title;
 final String message;
 final IconData icon;
 final String? actionLabel;
 final VoidCallback? onAction;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(28),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: _kCardBorder),
 ),
 child: Column(
 children: [
 Container(
 width: 56,
 height: 56,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7ED),
 borderRadius: BorderRadius.circular(16),
 ),
 child: Icon(icon, color: const Color(0xFFF59E0B), size: 28),
 ),
 const SizedBox(height: 16),
 Text(title,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: _kHeadline)),
 const SizedBox(height: 6),
 Text(message, style: const TextStyle(fontSize: 13, color: _kMuted)),
 if (actionLabel != null && onAction != null) ...[
 const SizedBox(height: 20),
 ElevatedButton.icon(
 onPressed: onAction,
 icon: const Icon(Icons.add, size: 18),
 label: Text(actionLabel!),
 style: ElevatedButton.styleFrom(
 backgroundColor: _kAccent,
 foregroundColor: _kHeadline,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14)),
 padding:
 const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 ),
 ),
 ],
 ],
 ),
 );
 }
}

// ── Dialogs ──────────────────────────────────────────────────

Future<Map<String, dynamic>?> _showSprintDialog(
 BuildContext context, {
 RoadmapSprint? existing,
}) async {
 final nameCtl = TextEditingController(text: existing?.name ?? '');
 final goalCtl = TextEditingController(text: existing?.goal ?? '');
 DateTime? startDate = existing?.startDate;
 DateTime? endDate = existing?.endDate;
 final formKey = GlobalKey<FormState>();

 return showDialog<Map<String, dynamic>>(
 context: context,
 barrierDismissible: false,
 builder: (ctx) {
 return StatefulBuilder(builder: (ctx, setDialogState) {
 return AlertDialog(
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
 title: Text(
 existing == null ? 'Create Sprint' : 'Edit Sprint',
 style:
 const TextStyle(fontWeight: FontWeight.w800, color: _kHeadline),
 ),
 content: Form(
 key: formKey,
 child: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 VoiceTextFormField(
 controller: nameCtl,
 decoration: const InputDecoration(labelText: 'Sprint Name'),
 textCapitalization: TextCapitalization.sentences,
 validator: (v) =>
 (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
 ),
 const SizedBox(height: 14),
 Row(
 children: [
 Expanded(
 child: _DatePickerField(
 label: 'Start Date',
 value: startDate,
 onChanged: (d) => setDialogState(() => startDate = d),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _DatePickerField(
 label: 'End Date',
 value: endDate,
 onChanged: (d) => setDialogState(() => endDate = d),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 VoiceTextFormField(
 controller: goalCtl,
 decoration: const InputDecoration(labelText: 'Sprint Goal'),
 minLines: 2,
 maxLines: 4,
 ),
 ],
 ),
 ),
 ),
 actionsPadding:
 const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 if (!(formKey.currentState?.validate() ?? false)) return;
 Navigator.of(ctx).pop({
 'name': nameCtl.text.trim(),
 'startDate': startDate,
 'endDate': endDate,
 'goal': goalCtl.text.trim(),
 });
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: _kAccent,
 foregroundColor: _kHeadline,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14)),
 ),
 child: const Text('Save'),
 ),
 ],
 );
 });
 },
 );
}

Future<Map<String, dynamic>?> _showDeliverableDialog(
 BuildContext context, {
 required List<RoadmapSprint> sprints,
 required String selectedSprintId,
 required List<RoadmapDeliverable> allDeliverables,
 RoadmapDeliverable? existing,
}) async {
 final titleCtl = TextEditingController(text: existing?.title ?? '');
 final descCtl = TextEditingController(text: existing?.description ?? '');
 final assigneeCtl = TextEditingController(text: existing?.assignee ?? '');
 final criteriaCtl =
 TextEditingController(text: existing?.acceptanceCriteria ?? '');
 final notesCtl = TextEditingController(text: existing?.notes ?? '');
 final blockersCtl = TextEditingController(text: existing?.blockers ?? '');
 String sprintId = existing?.sprintId ?? selectedSprintId;
 var status = existing?.status ?? RoadmapDeliverableStatus.notStarted;
 var priority = existing?.priority ?? RoadmapDeliverablePriority.medium;
 var storyPoints = existing?.storyPoints ?? 1;
 DateTime? dueDate = existing?.dueDate;
 var selectedDeps = existing?.dependencies.toList() ?? <String>[];
 final formKey = GlobalKey<FormState>();

 return showDialog<Map<String, dynamic>>(
 context: context,
 barrierDismissible: false,
 builder: (ctx) {
 return StatefulBuilder(builder: (ctx, setDialogState) {
 return AlertDialog(
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
 title: Text(
 existing == null ? 'Create Deliverable' : 'Edit Deliverable',
 style:
 const TextStyle(fontWeight: FontWeight.w800, color: _kHeadline),
 ),
 content: SingleChildScrollView(
 child: Form(
 key: formKey,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 VoiceTextFormField(
 controller: titleCtl,
 decoration:
 const InputDecoration(labelText: 'Deliverable Title'),
 textCapitalization: TextCapitalization.sentences,
 validator: (v) => (v == null || v.trim().isEmpty)
 ? 'Enter a title'
 : null,
 ),
 const SizedBox(height: 12),
 VoiceTextFormField(
 controller: descCtl,
 decoration: const InputDecoration(labelText: 'Description'),
 minLines: 2,
 maxLines: 4,
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value:
 sprints.any((s) => s.id == sprintId) ? sprintId : null,
 decoration: const InputDecoration(labelText: 'Sprint'),
 items: sprints
 .map((s) => DropdownMenuItem(
 value: s.id,
 child: Text(s.name),
 ))
 .toList(),
 onChanged: (v) {
 if (v != null) setDialogState(() => sprintId = v);
 },
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child:
 DropdownButtonFormField<RoadmapDeliverableStatus>(
 value: status,
 decoration:
 const InputDecoration(labelText: 'Status'),
 items: RoadmapDeliverableStatus.values
 .map((s) => DropdownMenuItem(
 value: s,
 child: Text(_statusLabel(s)),
 ))
 .toList(),
 onChanged: (v) {
 if (v != null) setDialogState(() => status = v);
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child:
 DropdownButtonFormField<RoadmapDeliverablePriority>(
 value: priority,
 decoration:
 const InputDecoration(labelText: 'Priority'),
 items: RoadmapDeliverablePriority.values
 .map((p) => DropdownMenuItem(
 value: p,
 child: Text(_priorityLabel(p)),
 ))
 .toList(),
 onChanged: (v) {
 if (v != null) setDialogState(() => priority = v);
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<int>(
 value: storyPoints,
 decoration:
 const InputDecoration(labelText: 'Story Points'),
 items: [1, 2, 3, 5, 8, 13, 21]
 .map((v) => DropdownMenuItem(
 value: v,
 child: Text('$v'),
 ))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => storyPoints = v);
 }
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _DatePickerField(
 label: 'Due Date',
 value: dueDate,
 onChanged: (d) => setDialogState(() => dueDate = d),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 VoiceTextFormField(
 controller: assigneeCtl,
 decoration: const InputDecoration(labelText: 'Assigned To'),
 ),
 const SizedBox(height: 12),
 VoiceTextFormField(
 controller: criteriaCtl,
 decoration:
 const InputDecoration(labelText: 'Acceptance Criteria'),
 minLines: 2,
 maxLines: 4,
 ),
 const SizedBox(height: 12),
 VoiceTextFormField(
 controller: blockersCtl,
 decoration: const InputDecoration(labelText: 'Blockers'),
 minLines: 1,
 maxLines: 3,
 ),
 const SizedBox(height: 12),
 VoiceTextFormField(
 controller: notesCtl,
 decoration: const InputDecoration(labelText: 'Notes'),
 minLines: 1,
 maxLines: 3,
 ),
 if (allDeliverables.isNotEmpty) ...[
 const SizedBox(height: 12),
 const Text('Dependencies',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: _kMuted)),
 const SizedBox(height: 6),
 ...allDeliverables
 .where((d) => d.id != existing?.id)
 .map((d) {
 final isSelected = selectedDeps.contains(d.id);
 return GestureDetector(
 onTap: () {
 setDialogState(() {
 if (isSelected) {
 selectedDeps.remove(d.id);
 } else {
 selectedDeps.add(d.id);
 }
 });
 },
 child: Container(
 margin: const EdgeInsets.only(bottom: 4),
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: isSelected
 ? _kAccent.withOpacity(0.1)
 : const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color:
 isSelected ? _kAccent : Colors.transparent),
 ),
 child: Row(
 children: [
 Icon(
 isSelected
 ? Icons.check_box
 : Icons.check_box_outline_blank,
 size: 16,
 color: isSelected
 ? const Color(0xFFD97706)
 : _kMuted,
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 d.title,
 style: TextStyle(
 fontSize: 12,
 color: isSelected
 ? const Color(0xFFD97706)
 : _kHeadline,
 fontWeight: isSelected
 ? FontWeight.w600
 : FontWeight.w400,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 ),
 );
 }),
 ],
 ],
 ),
 ),
 ),
 actionsPadding:
 const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 if (!(formKey.currentState?.validate() ?? false)) return;
 Navigator.of(ctx).pop({
 'title': titleCtl.text.trim(),
 'description': descCtl.text.trim(),
 'sprintId': sprintId,
 'assignee': assigneeCtl.text.trim(),
 'dueDate': dueDate,
 'status': status,
 'priority': priority,
 'storyPoints': storyPoints,
 'acceptanceCriteria': criteriaCtl.text.trim(),
 'blockers': blockersCtl.text.trim(),
 'notes': notesCtl.text.trim(),
 'dependencies': selectedDeps,
 });
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: _kAccent,
 foregroundColor: _kHeadline,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14)),
 ),
 child: const Text('Save'),
 ),
 ],
 );
 });
 },
 );
}

Future<bool?> _showConfirmDialog(String title, String message) {
 return showDialog<bool>(
 context: GlobalKey<NavigatorState>().currentContext!,
 builder: (ctx) => AlertDialog(
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
 title: Text(title,
 style:
 const TextStyle(fontWeight: FontWeight.w800, color: _kHeadline)),
 content:
 Text(message, style: const TextStyle(fontSize: 13, color: _kMuted)),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(false),
 child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () => Navigator.of(ctx).pop(true),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFEF4444),
 foregroundColor: Colors.white,
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 child: const Text('Delete'),
 ),
 ],
 ),
 );
}

class _DatePickerField extends StatelessWidget {
 const _DatePickerField({
 required this.label,
 required this.value,
 required this.onChanged,
 });

 final String label;
 final DateTime? value;
 final ValueChanged<DateTime?> onChanged;

 @override
 Widget build(BuildContext context) {
 final text =
 value != null ? '${value!.month}/${value!.day}/${value!.year}' : '';
 return GestureDetector(
 onTap: () async {
 final picked = await showDatePicker(
 context: context,
 initialDate: value ?? DateTime.now(),
 firstDate: DateTime(2020),
 lastDate: DateTime(2040),
 );
 if (picked != null) onChanged(picked);
 },
 child: InputDecorator(
 decoration: InputDecoration(
 labelText: label,
 suffixIcon: const Icon(Icons.calendar_today, size: 16),
 ),
 child: Text(
 text.isEmpty ? 'Select' : text,
 style: TextStyle(
 fontSize: 14,
 color: text.isEmpty ? _kMuted : _kHeadline,
 ),
 ),
 ),
 );
 }
}

// ── Helpers ──────────────────────────────────────────────────

Color _statusColor(RoadmapDeliverableStatus status) {
 switch (status) {
 case RoadmapDeliverableStatus.completed:
 return const Color(0xFF10B981);
 case RoadmapDeliverableStatus.inProgress:
 return const Color(0xFFF97316);
 case RoadmapDeliverableStatus.notStarted:
 return const Color(0xFF6B7280);
 case RoadmapDeliverableStatus.atRisk:
 return const Color(0xFFF59E0B);
 case RoadmapDeliverableStatus.blocked:
 return const Color(0xFFEF4444);
 }
}

String _statusLabel(RoadmapDeliverableStatus status) {
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

Color _priorityColor(RoadmapDeliverablePriority priority) {
 switch (priority) {
 case RoadmapDeliverablePriority.critical:
 return const Color(0xFFEF4444);
 case RoadmapDeliverablePriority.high:
 return const Color(0xFFF97316);
 case RoadmapDeliverablePriority.medium:
 return const Color(0xFFF59E0B);
 case RoadmapDeliverablePriority.low:
 return const Color(0xFF6B7280);
 }
}

String _priorityLabel(RoadmapDeliverablePriority priority) {
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

String _displayName(User? user) {
 final name = user?.displayName?.trim();
 if (name != null && name.isNotEmpty) return name;
 final email = user?.email?.trim();
 if (email != null && email.isNotEmpty) return email;
 return 'Guest';
}

String _displaySubtitle(User? user) {
 final email = user?.email?.trim();
 if (email != null && email.isNotEmpty) return email;
 return 'Signed in';
}

String _initialsFor(String value) {
 final trimmed = value.trim();
 if (trimmed.isEmpty) return 'U';
 final parts = trimmed.split(RegExp(r'\s+'));
 if (parts.length == 1) return parts.first.characters.first.toUpperCase();
 final first = parts.first.characters.first.toUpperCase();
 final last = parts.last.characters.first.toUpperCase();
 return '$first$last';
}
