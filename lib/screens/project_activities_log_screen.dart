import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_activity.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/activity_log_panel.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
class ProjectActivitiesLogScreen extends StatefulWidget {
 const ProjectActivitiesLogScreen({super.key});

 static void open(BuildContext context) {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;

 if (provider != null) {
 provider.updateField(
 (data) => data.copyWith(currentCheckpoint: 'project_activities_log'),
 );

 if (projectId != null && projectId.isNotEmpty) {
 Future<void>(() => ProjectNavigationService.instance
 .saveLastPageLocal(projectId, 'project_activities_log'));
 Future<void>(() async {
 try {
 await provider.saveToFirebase(checkpoint: 'project_activities_log');
 } catch (error) {
 debugPrint('Activity log checkpoint save failed: $error');
 }
 });
 }
 }

 // Navigate to the FULL Activity Log screen (not the small popup panel).
 Navigator.of(context).push(
 MaterialPageRoute<void>(
 builder: (_) => const ProjectActivitiesLogScreen(),
 ),
 );
 }

 @override
 State<ProjectActivitiesLogScreen> createState() =>
 _ProjectActivitiesLogScreenState();
}

class _ProjectActivitiesLogScreenState
 extends State<ProjectActivitiesLogScreen> {
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 final fep = projectData.frontEndPlanning;
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Project Activities Log',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', fep.requirementsNotes ?? 'No data recorded.'),
 ],
 );
 }

 final TextEditingController _searchController = TextEditingController();

 String _searchQuery = '';
 Set<String> _selectedStatuses = <String>{};
 Set<String> _selectedRoles = <String>{};
 Set<String> _selectedAssignedTo = <String>{};
 Set<String> _selectedPhases = <String>{};
 Set<String> _selectedDisciplines = <String>{};
 Set<String> _selectedApprovals = <String>{};
 Set<String> _selectedAppliedSections = <String>{};
 DateTimeRange? _selectedDateRange;

 int _rowsPerPage = 25;
 int _currentPage = 0;

 bool get _hasActiveFilters {
 return _selectedStatuses.isNotEmpty ||
 _selectedRoles.isNotEmpty ||
 _selectedAssignedTo.isNotEmpty ||
 _selectedPhases.isNotEmpty ||
 _selectedDisciplines.isNotEmpty ||
 _selectedApprovals.isNotEmpty ||
 _selectedAppliedSections.isNotEmpty ||
 _selectedDateRange != null;
 }

 @override
 void dispose() {
 _searchController.dispose();
 super.dispose();
 }

 void _resetPagination() {
 _currentPage = 0;
 }

 void _clearAllFilters() {
 setState(() {
 _selectedStatuses = <String>{};
 _selectedRoles = <String>{};
 _selectedAssignedTo = <String>{};
 _selectedPhases = <String>{};
 _selectedDisciplines = <String>{};
 _selectedApprovals = <String>{};
 _selectedAppliedSections = <String>{};
 _selectedDateRange = null;
 _resetPagination();
 });
 }

 Future<void> _openMultiSelectDialog({
 required String title,
 required List<String> options,
 required Set<String> selectedValues,
 required ValueChanged<Set<String>> onApplied,
 }) async {
 var localQuery = '';
 final working = Set<String>.from(selectedValues);

 final result = await showDialog<Set<String>>(
 context: context,
 builder: (dialogContext) {
 return StatefulBuilder(
 builder: (context, setModalState) {
 final visibleOptions = options.where((option) {
 if (localQuery.trim().isEmpty) return true;
 return option.toLowerCase().contains(localQuery.toLowerCase());
 }).toList();

 return AlertDialog(
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(16),
 ),
 title: Text(title),
 content: SizedBox(
 width: 420,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 onChanged: (value) {
 setModalState(() {
 localQuery = value;
 });
 },
 decoration: InputDecoration(
 hintText: 'Search options...',
 prefixIcon: const Icon(Icons.search, size: 18),
 isDense: true,
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 10,
 vertical: 10,
 ),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide:
 const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide:
 const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 ),
 ),
 const SizedBox(height: 12),
 Align(
 alignment: Alignment.centerLeft,
 child: Wrap(
 spacing: 8,
 children: [
 TextButton(
 onPressed: () {
 setModalState(() {
 working
 ..clear()
 ..addAll(options);
 });
 },
 child: const Text('Select all'),
 ),
 TextButton(
 onPressed: () {
 setModalState(() {
 working.clear();
 });
 },
 child: const Text('Clear'),
 ),
 ],
 ),
 ),
 const SizedBox(height: 8),
 Flexible(
 child: Container(
 width: double.infinity,
 decoration: BoxDecoration(
 border: Border.all(color: const Color(0xFFE5E7EB)),
 borderRadius: BorderRadius.circular(12),
 ),
 child: visibleOptions.isEmpty
 ? const Center(
 child: Padding(
 padding: EdgeInsets.all(24),
 child: Text(
 'No options found.',
 style: TextStyle(color: Color(0xFF6B7280)),
 ),
 ),
 )
 : ListView.builder(
 shrinkWrap: true,
 itemCount: visibleOptions.length,
 itemBuilder: (context, index) {
 final option = visibleOptions[index];
 final selected = working.contains(option);
 return CheckboxListTile(
 dense: true,
 value: selected,
 title: Text(
 option,
 style: const TextStyle(fontSize: 13),
 overflow: TextOverflow.ellipsis,
 ),
 onChanged: (_) {
 setModalState(() {
 if (selected) {
 working.remove(option);
 } else {
 working.add(option);
 }
 });
 },
 controlAffinity:
 ListTileControlAffinity.leading,
 );
 },
 ),
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(working),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFF4B400),
 foregroundColor: Colors.black,
 elevation: 0,
 ),
 child: const Text('Apply'),
 ),
 ],
 );
 },
 );
 },
 );

 if (result != null) {
 setState(() {
 onApplied(result);
 _resetPagination();
 });
 }
 }

 Future<void> _pickDateRange() async {
 final now = DateTime.now();
 final initialRange = _selectedDateRange ??
 DateTimeRange(
 start: DateTime(now.year, now.month, now.day).subtract(
 const Duration(days: 30),
 ),
 end: DateTime(now.year, now.month, now.day),
 );

 final picked = await showDateRangePicker(
 context: context,
 firstDate: DateTime(now.year - 5),
 lastDate: DateTime(now.year + 5),
 initialDateRange: initialRange,
 helpText: 'Filter By Updated Date',
 );

 if (picked != null) {
 setState(() {
 _selectedDateRange = picked;
 _resetPagination();
 });
 }
 }

 bool _isCustomActivity(ProjectActivity activity, Set<String> customIds) {
 return customIds.contains(activity.id) ||
 activity.id.startsWith('activity_custom_');
 }

 Future<void> _persistActivityLog() async {
 final provider = ProjectDataHelper.getProvider(context);
 await provider.saveToFirebase(checkpoint: 'project_activities_log');
 }

 Future<void> _upsertActivity(
 ProjectActivity activity, {
 required bool isCustom,
 }) async {
 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField((data) {
 final visibleActivities =
 List<ProjectActivity>.from(data.projectActivities);
 final visibleIndex =
 visibleActivities.indexWhere((item) => item.id == activity.id);
 if (visibleIndex >= 0) {
 visibleActivities[visibleIndex] = activity;
 } else {
 visibleActivities.add(activity);
 }

 final customActivities =
 List<ProjectActivity>.from(data.customProjectActivities);
 if (isCustom || activity.id.startsWith('activity_custom_')) {
 final customIndex =
 customActivities.indexWhere((item) => item.id == activity.id);
 if (customIndex >= 0) {
 customActivities[customIndex] = activity;
 } else {
 customActivities.add(activity);
 }
 }

 final hiddenIds = List<String>.from(data.hiddenProjectActivityIds)
 ..remove(activity.id);

 return data.copyWith(
 projectActivities: visibleActivities,
 customProjectActivities: customActivities,
 hiddenProjectActivityIds: hiddenIds,
 );
 });
 await _persistActivityLog();
 }

 Future<void> _deleteActivity(
 ProjectActivity activity, {
 required bool isCustom,
 }) async {
 final actionLabel =
 isCustom ? 'delete this custom activity' : 'hide this activity';
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: Text(isCustom ? 'Delete Activity' : 'Hide Activity'),
 content: Text(
 isCustom
 ? 'This will permanently delete the custom activity.'
 : 'This will hide the generated activity from the log.',
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFF4B400),
 foregroundColor: Colors.black,
 elevation: 0,
 ),
 child: Text(isCustom ? 'Delete' : 'Hide'),
 ),
 ],
 ),
 );

 if (confirmed != true || !mounted) return;

 final provider = ProjectDataHelper.getProvider(context);
 provider.updateField((data) {
 final visibleActivities = data.projectActivities
 .where((item) => item.id != activity.id)
 .toList(growable: false);
 final customActivities = data.customProjectActivities
 .where((item) => item.id != activity.id)
 .toList(growable: false);
 final hiddenIds = Set<String>.from(data.hiddenProjectActivityIds);
 if (isCustom) {
 hiddenIds.remove(activity.id);
 } else {
 hiddenIds.add(activity.id);
 }

 return data.copyWith(
 projectActivities: visibleActivities,
 customProjectActivities: customActivities,
 hiddenProjectActivityIds: hiddenIds.toList(),
 );
 });

 await _persistActivityLog();
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Successfully updated activity log: $actionLabel.')),
 );
 }

 Future<void> _openActivityEditor({
 ProjectActivity? existing,
 required bool isCustom,
 }) async {
 final isCreate = existing == null;
 final allowStructuralEdit = isCreate || isCustom;
 final now = DateTime.now();

 final titleController = TextEditingController(text: existing?.title ?? '');
 final descriptionController =
 TextEditingController(text: existing?.description ?? '');
 final sourceController = TextEditingController(
 text: existing?.sourceSection ?? 'manual_activity',
 );
 final phaseController = TextEditingController(
 text: existing?.phase.isNotEmpty == true
 ? existing!.phase
 : 'Planning Phase',
 );
 final disciplineController = TextEditingController(
 text: existing?.discipline.isNotEmpty == true
 ? existing!.discipline
 : 'Project Management',
 );
 final roleController = TextEditingController(
 text: existing?.role.isNotEmpty == true ? existing!.role : 'Project Lead',
 );
 final assignedToController =
 TextEditingController(text: existing?.assignedTo ?? '');
 final dueDateController =
 TextEditingController(text: existing?.dueDate ?? '');
 final appliesToController = TextEditingController(
 text: (existing?.applicableSections ?? const <String>[]).join(', '),
 );

 var selectedStatus = existing?.status ?? ProjectActivityStatus.pending;
 var selectedApproval =
 existing?.approvalStatus ?? ProjectApprovalStatus.draft;

 final result = await showDialog<ProjectActivity>(
 context: context,
 builder: (dialogContext) {
 return StatefulBuilder(
 builder: (dialogContext, setModalState) {
 return Dialog(
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(16),
 ),
 child: ConstrainedBox(
 constraints:
 const BoxConstraints(maxWidth: 760, maxHeight: 680),
 child: Padding(
 padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 isCreate ? 'Add Activity' : 'Edit Activity',
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 if (!allowStructuralEdit) ...[
 const SizedBox(height: 8),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: const Color(0xFFFFFBEB),
 border: Border.all(color: const Color(0xFFFDE68A)),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Text(
 'Generated activity: you can update assignment, status, approval, and due date here. Edit source sections to change structure.',
 style: TextStyle(
 fontSize: 12,
 color: Color(0xFF92400E),
 ),
 ),
 ),
 ],
 const SizedBox(height: 12),
 Expanded(
 child: SingleChildScrollView(
 child: Column(
 children: [
 _ActivityField(
 label: 'Activity',
 controller: titleController,
 enabled: allowStructuralEdit,
 ),
 _ActivityField(
 label: 'Description',
 controller: descriptionController,
 enabled: allowStructuralEdit,
 maxLines: 4,
 ),
 if (allowStructuralEdit) ...[
 _ActivityField(
 label: 'Source Section',
 controller: sourceController,
 ),
 _ActivityField(
 label: 'Phase',
 controller: phaseController,
 ),
 _ActivityField(
 label: 'Discipline',
 controller: disciplineController,
 ),
 _ActivityField(
 label: 'Role',
 controller: roleController,
 ),
 _ActivityField(
 label:
 'Applied To Sections (comma-separated)',
 controller: appliesToController,
 ),
 ],
 _ActivityField(
 label: 'Assigned To',
 controller: assignedToController,
 ),
 _ActivityField(
 label: 'Due Date',
 controller: dueDateController,
 hintText: 'YYYY-MM-DD (optional)',
 ),
 const SizedBox(height: 8),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<
 ProjectActivityStatus>(
 value: selectedStatus,
 decoration: const InputDecoration(
 labelText: 'Status',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 items: ProjectActivityStatus.values
 .map((status) => DropdownMenuItem(
 value: status,
 child:
 Text(_statusLabel(status)),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setModalState(
 () => selectedStatus = value);
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<
 ProjectApprovalStatus>(
 value: selectedApproval,
 decoration: const InputDecoration(
 labelText: 'Approval',
 border: OutlineInputBorder(),
 isDense: true,
 ),
 items: ProjectApprovalStatus.values
 .map((approval) => DropdownMenuItem(
 value: approval,
 child: Text(
 _approvalLabel(approval),
 ),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setModalState(
 () => selectedApproval = value);
 },
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 const SizedBox(height: 14),
 Row(
 children: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 child: const Text('Cancel'),
 ),
 const Spacer(),
 ElevatedButton(
 onPressed: () {
 final title = allowStructuralEdit
 ? titleController.text.trim()
 : existing.title.trim();
 if (title.isEmpty) {
 ScaffoldMessenger.of(dialogContext)
 .showSnackBar(
 const SnackBar(
 content:
 Text('Activity title is required.'),
 ),
 );
 return;
 }

 final sections = allowStructuralEdit
 ? appliesToController.text
 .split(',')
 .map((part) => part.trim())
 .where((part) => part.isNotEmpty)
 .toSet()
 .toList()
 : existing.applicableSections;

 final nextActivity = ProjectActivity(
 id: existing?.id ??
 'activity_custom_${now.microsecondsSinceEpoch}',
 title: title,
 description: allowStructuralEdit
 ? descriptionController.text.trim()
 : existing.description,
 sourceSection: allowStructuralEdit
 ? sourceController.text.trim()
 : existing.sourceSection,
 phase: allowStructuralEdit
 ? phaseController.text.trim()
 : existing.phase,
 discipline: allowStructuralEdit
 ? disciplineController.text.trim()
 : existing.discipline,
 role: allowStructuralEdit
 ? roleController.text.trim()
 : existing.role,
 assignedTo:
 assignedToController.text.trim().isEmpty
 ? null
 : assignedToController.text.trim(),
 applicableSections: sections,
 dueDate: dueDateController.text.trim(),
 status: selectedStatus,
 approvalStatus: selectedApproval,
 createdAt: existing?.createdAt ?? now,
 updatedAt: now,
 );
 Navigator.of(dialogContext).pop(nextActivity);
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFF4B400),
 foregroundColor: Colors.black,
 elevation: 0,
 ),
 child: const Text('Save'),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 );
 },
 );
 },
 );

 titleController.dispose();
 descriptionController.dispose();
 sourceController.dispose();
 phaseController.dispose();
 disciplineController.dispose();
 roleController.dispose();
 assignedToController.dispose();
 dueDateController.dispose();
 appliesToController.dispose();

 if (result == null || !mounted) return;
 await _upsertActivity(
 result,
 isCustom:
 isCreate || isCustom || result.id.startsWith('activity_custom_'),
 );
 }

 @override
 Widget build(BuildContext context) {
 final data = ProjectDataHelper.getData(context, listen: true);
 final customActivityIds = <String>{
 for (final item in data.customProjectActivities) item.id,
 };
 final activities = List<ProjectActivity>.from(data.projectActivities)
 ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
 final options = _buildFilterOptions(activities);
 final filteredActivities = _applyFilters(activities);

 final totalCount = activities.length;
 final pendingCount = activities
 .where((activity) => activity.status == ProjectActivityStatus.pending)
 .length;
 final implementedCount = activities
 .where(
 (activity) => activity.status == ProjectActivityStatus.implemented)
 .length;
 final approvedCount = activities
 .where((activity) =>
 activity.approvalStatus == ProjectApprovalStatus.approved)
 .length;

 final totalPages = filteredActivities.isEmpty
 ? 1
 : ((filteredActivities.length - 1) ~/ _rowsPerPage) + 1;
 final pageIndex = _currentPage.clamp(0, totalPages - 1);
 final startIndex =
 filteredActivities.isEmpty ? 0 : pageIndex * _rowsPerPage;
 final endIndex = filteredActivities.isEmpty
 ? 0
 : math.min(startIndex + _rowsPerPage, filteredActivities.length);
 final pageItems = filteredActivities.isEmpty
 ? const <ProjectActivity>[]
 : filteredActivities.sublist(startIndex, endIndex);

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Stack(
 children: [
 const AdminEditToggle(),
 Column(
 children: [
 FrontEndPlanningHeader(
 title: 'Project Activities Log',
 showActivityLogAction: false, onExportPdf: _exportPdf),
 Expanded(
 child: LayoutBuilder(
 builder: (context, constraints) {
 final horizontalPadding =
 constraints.maxWidth > 1400
 ? 24.0
 : constraints.maxWidth > 1000
 ? 18.0
 : 12.0;

 return SingleChildScrollView(
 padding: EdgeInsets.fromLTRB(
 horizontalPadding,
 20,
 horizontalPadding,
 24,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: [
 const Expanded(
 child: Text(
 'Track generated project activities, ownership, approvals, and implementation status across phases.',
 style: TextStyle(
 fontSize: 14,
 color: Color(0xFF4B5563),
 height: 1.4,
 ),
 ),
 ),
 const SizedBox(width: 12),
 OutlinedButton.icon(
 onPressed: () => _openActivityEditor(
 existing: null,
 isCustom: true,
 ),
 icon: const Icon(Icons.add, size: 16),
 label: const Text(
 'Add Activity',
 style: TextStyle(
 fontWeight: FontWeight.w700,
 ),
 ),
 style: OutlinedButton.styleFrom(
 foregroundColor:
 const Color(0xFF111827),
 side: const BorderSide(
 color: Color(0xFFD1D5DB),
 ),
 shape: RoundedRectangleBorder(
 borderRadius:
 BorderRadius.circular(10),
 ),
 padding: const EdgeInsets.symmetric(
 horizontal: 14,
 vertical: 12,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 LayoutBuilder(
 builder: (context, statConstraints) {
 final cardWidth = statConstraints
 .maxWidth >=
 1120
 ? (statConstraints.maxWidth - 36) / 4
 : statConstraints.maxWidth >= 760
 ? (statConstraints.maxWidth -
 24) /
 3
 : statConstraints.maxWidth >= 460
 ? (statConstraints.maxWidth -
 12) /
 2
 : statConstraints.maxWidth;

 return Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [
 SizedBox(
 width: cardWidth,
 child: _StatCard(
 title: 'Total Activities',
 value: '$totalCount',
 color: const Color(0xFF0EA5E9),
 ),
 ),
 SizedBox(
 width: cardWidth,
 child: _StatCard(
 title: 'Pending',
 value: '$pendingCount',
 color: const Color(0xFFF59E0B),
 ),
 ),
 SizedBox(
 width: cardWidth,
 child: _StatCard(
 title: 'Implemented',
 value: '$implementedCount',
 color: const Color(0xFF10B981),
 ),
 ),
 SizedBox(
 width: cardWidth,
 child: _StatCard(
 title: 'Approved',
 value: '$approvedCount',
 color: const Color(0xFF6366F1),
 ),
 ),
 ],
 );
 },
 ),
 const SizedBox(height: 16),
 _FilterToolbar(
 searchController: _searchController,
 hasActiveFilters: _hasActiveFilters,
 selectedStatuses: _selectedStatuses,
 selectedRoles: _selectedRoles,
 selectedAssignedTo: _selectedAssignedTo,
 selectedPhases: _selectedPhases,
 selectedDisciplines: _selectedDisciplines,
 selectedApprovals: _selectedApprovals,
 selectedAppliedSections:
 _selectedAppliedSections,
 selectedDateRange: _selectedDateRange,
 options: options,
 onSearchChanged: (value) => setState(() {
 _searchQuery = value.trim().toLowerCase();
 _resetPagination();
 }),
 onStatusTap: () => _openMultiSelectDialog(
 title: 'Filter by Status',
 options: options.statuses,
 selectedValues: _selectedStatuses,
 onApplied: (value) {
 _selectedStatuses = value;
 },
 ),
 onRoleTap: () => _openMultiSelectDialog(
 title: 'Filter by Role',
 options: options.roles,
 selectedValues: _selectedRoles,
 onApplied: (value) {
 _selectedRoles = value;
 },
 ),
 onAssignedTap: () => _openMultiSelectDialog(
 title: 'Filter by Assigned To',
 options: options.assignedTo,
 selectedValues: _selectedAssignedTo,
 onApplied: (value) {
 _selectedAssignedTo = value;
 },
 ),
 onPhaseTap: () => _openMultiSelectDialog(
 title: 'Filter by Phase',
 options: options.phases,
 selectedValues: _selectedPhases,
 onApplied: (value) {
 _selectedPhases = value;
 },
 ),
 onDisciplineTap: () =>
 _openMultiSelectDialog(
 title: 'Filter by Discipline',
 options: options.disciplines,
 selectedValues: _selectedDisciplines,
 onApplied: (value) {
 _selectedDisciplines = value;
 },
 ),
 onApprovalTap: () => _openMultiSelectDialog(
 title: 'Filter by Approval Status',
 options: options.approvals,
 selectedValues: _selectedApprovals,
 onApplied: (value) {
 _selectedApprovals = value;
 },
 ),
 onAppliedSectionTap: () =>
 _openMultiSelectDialog(
 title: 'Filter by Applied To Section',
 options: options.appliedSections,
 selectedValues: _selectedAppliedSections,
 onApplied: (value) {
 _selectedAppliedSections = value;
 },
 ),
 onDateTap: _pickDateRange,
 onDateClear: _selectedDateRange == null
 ? null
 : () {
 setState(() {
 _selectedDateRange = null;
 _resetPagination();
 });
 },
 onClearAll: _clearAllFilters,
 onClearStatuses: () => setState(() {
 _selectedStatuses = <String>{};
 _resetPagination();
 }),
 onClearRoles: () => setState(() {
 _selectedRoles = <String>{};
 _resetPagination();
 }),
 onClearAssignedTo: () => setState(() {
 _selectedAssignedTo = <String>{};
 _resetPagination();
 }),
 onClearPhases: () => setState(() {
 _selectedPhases = <String>{};
 _resetPagination();
 }),
 onClearDisciplines: () => setState(() {
 _selectedDisciplines = <String>{};
 _resetPagination();
 }),
 onClearApprovals: () => setState(() {
 _selectedApprovals = <String>{};
 _resetPagination();
 }),
 onClearAppliedSections: () => setState(() {
 _selectedAppliedSections = <String>{};
 _resetPagination();
 }),
 onClearDateRange: _selectedDateRange == null
 ? null
 : () => setState(() {
 _selectedDateRange = null;
 _resetPagination();
 }),
 dateLabel: _selectedDateRange == null
 ? null
 : _dateRangeLabel(_selectedDateRange!),
 ),
 const SizedBox(height: 14),
 _ActivitiesTable(
 activities: pageItems,
 rowOffset: startIndex,
 statusLabel: _statusLabel,
 approvalLabel: _approvalLabel,
 dateFormatter: _formatDate,
 isCustomActivity: (activity) =>
 _isCustomActivity(
 activity, customActivityIds),
 onEdit: (activity) => _openActivityEditor(
 existing: activity,
 isCustom: _isCustomActivity(
 activity,
 customActivityIds,
 ),
 ),
 onDelete: (activity) => _deleteActivity(
 activity,
 isCustom: _isCustomActivity(
 activity,
 customActivityIds,
 ),
 ),
 ),
 const SizedBox(height: 12),
 _PaginationFooter(
 totalCount: filteredActivities.length,
 startIndex: startIndex,
 endIndex: endIndex,
 pageIndex: pageIndex,
 totalPages: totalPages,
 rowsPerPage: _rowsPerPage,
 onRowsPerPageChanged: (value) {
 setState(() {
 _rowsPerPage = value;
 _resetPagination();
 });
 },
 onPrev: pageIndex == 0
 ? null
 : () => setState(() {
 _currentPage = pageIndex - 1;
 }),
 onNext: pageIndex >= totalPages - 1
 ? null
 : () => setState(() {
 _currentPage = pageIndex + 1;
 }),
 ),
 ],
 ),
 );
 },
 ),
 ),
 ],
 ),
 const KazAiChatBubble(),
 ],
 ),
 ),
 );
 }

 List<ProjectActivity> _applyFilters(List<ProjectActivity> activities) {
 return activities.where((activity) {
 final status = _statusLabel(activity.status);
 final approval = _approvalLabel(activity.approvalStatus);
 final role = activity.role.trim().isEmpty ? 'Unspecified' : activity.role;
 final assignedTo = (activity.assignedTo ?? '').trim().isEmpty
 ? 'Unassigned'
 : (activity.assignedTo ?? '').trim();
 final phase =
 activity.phase.trim().isEmpty ? 'Unspecified' : activity.phase;
 final discipline = activity.discipline.trim().isEmpty
 ? 'Unspecified'
 : activity.discipline;
 final appliedSections = activity.applicableSections
 .map(_normalizeSectionLabel)
 .where((section) => section.isNotEmpty)
 .toSet();
 if (appliedSections.isEmpty) {
 final sourceSection = _normalizeSectionLabel(activity.sourceSection);
 if (sourceSection.isNotEmpty) {
 appliedSections.add(sourceSection);
 }
 }

 if (_selectedStatuses.isNotEmpty && !_selectedStatuses.contains(status)) {
 return false;
 }
 if (_selectedRoles.isNotEmpty && !_selectedRoles.contains(role)) {
 return false;
 }
 if (_selectedAssignedTo.isNotEmpty &&
 !_selectedAssignedTo.contains(assignedTo)) {
 return false;
 }
 if (_selectedPhases.isNotEmpty && !_selectedPhases.contains(phase)) {
 return false;
 }
 if (_selectedDisciplines.isNotEmpty &&
 !_selectedDisciplines.contains(discipline)) {
 return false;
 }
 if (_selectedApprovals.isNotEmpty &&
 !_selectedApprovals.contains(approval)) {
 return false;
 }
 if (_selectedAppliedSections.isNotEmpty &&
 !appliedSections.any(_selectedAppliedSections.contains)) {
 return false;
 }

 if (_selectedDateRange != null) {
 final rangeStart = DateTime(
 _selectedDateRange!.start.year,
 _selectedDateRange!.start.month,
 _selectedDateRange!.start.day,
 );
 final rangeEnd = DateTime(
 _selectedDateRange!.end.year,
 _selectedDateRange!.end.month,
 _selectedDateRange!.end.day,
 23,
 59,
 59,
 999,
 );
 if (activity.updatedAt.isBefore(rangeStart) ||
 activity.updatedAt.isAfter(rangeEnd)) {
 return false;
 }
 }

 if (_searchQuery.isEmpty) {
 return true;
 }

 final sourceSection = _normalizeSectionLabel(activity.sourceSection);
 final text = [
 activity.title,
 activity.description,
 activity.phase,
 activity.discipline,
 activity.role,
 activity.assignedTo ?? '',
 sourceSection,
 appliedSections.join(' '),
 status,
 approval,
 ].join(' ').toLowerCase();

 return text.contains(_searchQuery);
 }).toList();
 }

 _FilterOptions _buildFilterOptions(List<ProjectActivity> activities) {
 final statuses = <String>{};
 final roles = <String>{};
 final assignedTo = <String>{};
 final phases = <String>{};
 final disciplines = <String>{};
 final approvals = <String>{};
 final appliedSections = <String>{};

 for (final activity in activities) {
 statuses.add(_statusLabel(activity.status));
 roles.add(
 activity.role.trim().isEmpty ? 'Unspecified' : activity.role.trim());
 assignedTo.add((activity.assignedTo ?? '').trim().isEmpty
 ? 'Unassigned'
 : (activity.assignedTo ?? '').trim());
 phases
 .add(activity.phase.trim().isEmpty ? 'Unspecified' : activity.phase);
 disciplines.add(activity.discipline.trim().isEmpty
 ? 'Unspecified'
 : activity.discipline.trim());
 approvals.add(_approvalLabel(activity.approvalStatus));

 for (final section in activity.applicableSections) {
 final normalized = _normalizeSectionLabel(section);
 if (normalized.isNotEmpty) appliedSections.add(normalized);
 }
 if (activity.applicableSections.isEmpty) {
 final sourceSection = _normalizeSectionLabel(activity.sourceSection);
 if (sourceSection.isNotEmpty) {
 appliedSections.add(sourceSection);
 }
 }
 }

 List<String> sorted(Set<String> source) {
 final values = source.toList()..sort((a, b) => a.compareTo(b));
 return values;
 }

 return _FilterOptions(
 statuses: sorted(statuses),
 roles: sorted(roles),
 assignedTo: sorted(assignedTo),
 phases: sorted(phases),
 disciplines: sorted(disciplines),
 approvals: sorted(approvals),
 appliedSections: sorted(appliedSections),
 );
 }

 String _dateRangeLabel(DateTimeRange range) {
 return '${_formatDate(range.start)} to ${_formatDate(range.end)}';
 }

 String _formatDate(DateTime value) {
 final yyyy = value.year.toString().padLeft(4, '0');
 final mm = value.month.toString().padLeft(2, '0');
 final dd = value.day.toString().padLeft(2, '0');
 return '$yyyy-$mm-$dd';
 }

 String _normalizeSectionLabel(String value) {
 return value.replaceAll('_', ' ').trim();
 }

 String _statusLabel(ProjectActivityStatus status) {
 switch (status) {
 case ProjectActivityStatus.pending:
 return 'Pending';
 case ProjectActivityStatus.acknowledged:
 return 'Acknowledged';
 case ProjectActivityStatus.implemented:
 return 'Implemented';
 case ProjectActivityStatus.rejected:
 return 'Rejected';
 case ProjectActivityStatus.deferred:
 return 'Deferred';
 }
 }

 String _approvalLabel(ProjectApprovalStatus status) {
 switch (status) {
 case ProjectApprovalStatus.draft:
 return 'Draft';
 case ProjectApprovalStatus.approved:
 return 'Approved';
 case ProjectApprovalStatus.locked:
 return 'Locked';
 }
 }
}

class _FilterOptions {
 const _FilterOptions({
 required this.statuses,
 required this.roles,
 required this.assignedTo,
 required this.phases,
 required this.disciplines,
 required this.approvals,
 required this.appliedSections,
 });

 final List<String> statuses;
 final List<String> roles;
 final List<String> assignedTo;
 final List<String> phases;
 final List<String> disciplines;
 final List<String> approvals;
 final List<String> appliedSections;
}

class _StatCard extends StatelessWidget {
 const _StatCard({
 required this.title,
 required this.value,
 required this.color,
 });

 final String title;
 final String value;
 final Color color;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280),
 ),
 ),
 const SizedBox(height: 8),
 Text(
 value,
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 ],
 ),
 );
 }
}

class _FilterToolbar extends StatelessWidget {
 const _FilterToolbar({
 required this.searchController,
 required this.hasActiveFilters,
 required this.selectedStatuses,
 required this.selectedRoles,
 required this.selectedAssignedTo,
 required this.selectedPhases,
 required this.selectedDisciplines,
 required this.selectedApprovals,
 required this.selectedAppliedSections,
 required this.selectedDateRange,
 required this.options,
 required this.onSearchChanged,
 required this.onStatusTap,
 required this.onRoleTap,
 required this.onAssignedTap,
 required this.onPhaseTap,
 required this.onDisciplineTap,
 required this.onApprovalTap,
 required this.onAppliedSectionTap,
 required this.onDateTap,
 required this.onDateClear,
 required this.onClearAll,
 required this.onClearStatuses,
 required this.onClearRoles,
 required this.onClearAssignedTo,
 required this.onClearPhases,
 required this.onClearDisciplines,
 required this.onClearApprovals,
 required this.onClearAppliedSections,
 required this.onClearDateRange,
 required this.dateLabel,
 });

 final TextEditingController searchController;
 final bool hasActiveFilters;
 final Set<String> selectedStatuses;
 final Set<String> selectedRoles;
 final Set<String> selectedAssignedTo;
 final Set<String> selectedPhases;
 final Set<String> selectedDisciplines;
 final Set<String> selectedApprovals;
 final Set<String> selectedAppliedSections;
 final DateTimeRange? selectedDateRange;
 final _FilterOptions options;
 final ValueChanged<String> onSearchChanged;
 final VoidCallback onStatusTap;
 final VoidCallback onRoleTap;
 final VoidCallback onAssignedTap;
 final VoidCallback onPhaseTap;
 final VoidCallback onDisciplineTap;
 final VoidCallback onApprovalTap;
 final VoidCallback onAppliedSectionTap;
 final VoidCallback onDateTap;
 final VoidCallback? onDateClear;
 final VoidCallback onClearAll;
 final VoidCallback onClearStatuses;
 final VoidCallback onClearRoles;
 final VoidCallback onClearAssignedTo;
 final VoidCallback onClearPhases;
 final VoidCallback onClearDisciplines;
 final VoidCallback onClearApprovals;
 final VoidCallback onClearAppliedSections;
 final VoidCallback? onClearDateRange;
 final String? dateLabel;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final searchWidth =
 constraints.maxWidth < 420 ? constraints.maxWidth : 330.0;

 return Wrap(
 spacing: 10,
 runSpacing: 10,
 crossAxisAlignment: WrapCrossAlignment.center,
 children: [
 SizedBox(
 width: searchWidth,
 child: VoiceTextField(
 controller: searchController,
 onChanged: onSearchChanged,
 decoration: InputDecoration(
 hintText: 'Search activity, owner, role, phase...',
 isDense: true,
 prefixIcon: const Icon(
 Icons.search,
 size: 20,
 color: Color(0xFF6B7280),
 ),
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 12,
 vertical: 10,
 ),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide:
 const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide:
 const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 ),
 ),
 ),
 _FilterActionButton(
 label: 'Status',
 selectedCount: selectedStatuses.length,
 onTap: onStatusTap,
 ),
 _FilterActionButton(
 label: 'Role',
 selectedCount: selectedRoles.length,
 onTap: onRoleTap,
 ),
 _FilterActionButton(
 label: 'Assigned To',
 selectedCount: selectedAssignedTo.length,
 onTap: onAssignedTap,
 ),
 _FilterActionButton(
 label: 'Phase',
 selectedCount: selectedPhases.length,
 onTap: onPhaseTap,
 ),
 _FilterActionButton(
 label: 'Discipline',
 selectedCount: selectedDisciplines.length,
 onTap: onDisciplineTap,
 ),
 _FilterActionButton(
 label: 'Approval',
 selectedCount: selectedApprovals.length,
 onTap: onApprovalTap,
 ),
 _FilterActionButton(
 label: 'Applied Section',
 selectedCount: selectedAppliedSections.length,
 onTap: onAppliedSectionTap,
 ),
 _DateRangeActionButton(
 hasValue: selectedDateRange != null,
 label: selectedDateRange == null
 ? 'Date Range'
 : (dateLabel ?? 'Date Range'),
 onTap: onDateTap,
 onClear: onDateClear,
 ),
 if (hasActiveFilters)
 TextButton.icon(
 onPressed: onClearAll,
 icon: const Icon(Icons.clear_all, size: 18),
 label: const Text('Clear All'),
 ),
 ],
 );
 },
 ),
 ),
 if (hasActiveFilters) ...[
 const SizedBox(height: 10),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: [
 if (selectedStatuses.isNotEmpty)
 _ActiveFilterTag(
 label: 'Status (${selectedStatuses.length})',
 onClear: onClearStatuses,
 ),
 if (selectedRoles.isNotEmpty)
 _ActiveFilterTag(
 label: 'Role (${selectedRoles.length})',
 onClear: onClearRoles,
 ),
 if (selectedAssignedTo.isNotEmpty)
 _ActiveFilterTag(
 label: 'Assigned (${selectedAssignedTo.length})',
 onClear: onClearAssignedTo,
 ),
 if (selectedPhases.isNotEmpty)
 _ActiveFilterTag(
 label: 'Phase (${selectedPhases.length})',
 onClear: onClearPhases,
 ),
 if (selectedDisciplines.isNotEmpty)
 _ActiveFilterTag(
 label: 'Discipline (${selectedDisciplines.length})',
 onClear: onClearDisciplines,
 ),
 if (selectedApprovals.isNotEmpty)
 _ActiveFilterTag(
 label: 'Approval (${selectedApprovals.length})',
 onClear: onClearApprovals,
 ),
 if (selectedAppliedSections.isNotEmpty)
 _ActiveFilterTag(
 label: 'Applied (${selectedAppliedSections.length})',
 onClear: onClearAppliedSections,
 ),
 if (selectedDateRange != null && onClearDateRange != null)
 _ActiveFilterTag(
 label: 'Date Range',
 onClear: onClearDateRange!,
 ),
 ],
 ),
 ],
 ],
 );
 }
}

class _FilterActionButton extends StatelessWidget {
 const _FilterActionButton({
 required this.label,
 required this.selectedCount,
 required this.onTap,
 });

 final String label;
 final int selectedCount;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 final isActive = selectedCount > 0;

 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(10),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 decoration: BoxDecoration(
 color: isActive ? const Color(0xFFFFF8E1) : Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(
 color: isActive ? const Color(0xFFF4B400) : const Color(0xFFE5E7EB),
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: isActive
 ? const Color(0xFF92400E)
 : const Color(0xFF374151),
 ),
 ),
 if (isActive) ...[
 const SizedBox(width: 6),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: const Color(0xFFF4B400),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 '$selectedCount',
 style: const TextStyle(
 fontSize: 10,
 color: Colors.black,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 ],
 const SizedBox(width: 6),
 Icon(
 Icons.arrow_drop_down,
 size: 18,
 color:
 isActive ? const Color(0xFF92400E) : const Color(0xFF6B7280),
 ),
 ],
 ),
 ),
 );
 }
}

class _DateRangeActionButton extends StatelessWidget {
 const _DateRangeActionButton({
 required this.label,
 required this.hasValue,
 required this.onTap,
 this.onClear,
 });

 final String label;
 final bool hasValue;
 final VoidCallback onTap;
 final VoidCallback? onClear;

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(10),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 decoration: BoxDecoration(
 color: hasValue ? const Color(0xFFFFF8E1) : Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(
 color: hasValue ? const Color(0xFFF4B400) : const Color(0xFFE5E7EB),
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 Icons.date_range_outlined,
 size: 16,
 color:
 hasValue ? const Color(0xFF92400E) : const Color(0xFF6B7280),
 ),
 const SizedBox(width: 6),
 Text(
 label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: hasValue
 ? const Color(0xFF92400E)
 : const Color(0xFF374151),
 ),
 ),
 if (onClear != null) ...[
 const SizedBox(width: 6),
 GestureDetector(
 onTap: onClear,
 child: const Icon(
 Icons.close,
 size: 14,
 color: Color(0xFF92400E),
 ),
 ),
 ],
 ],
 ),
 ),
 );
 }
}

class _ActiveFilterTag extends StatelessWidget {
 const _ActiveFilterTag({
 required this.label,
 required this.onClear,
 });

 final String label;
 final VoidCallback onClear;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7E0),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFF7D36A)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 label,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF92400E),
 ),
 ),
 const SizedBox(width: 6),
 InkWell(
 onTap: onClear,
 child: const Icon(
 Icons.close,
 size: 14,
 color: Color(0xFF92400E),
 ),
 ),
 ],
 ),
 );
 }
}

class _PaginationFooter extends StatelessWidget {
 const _PaginationFooter({
 required this.totalCount,
 required this.startIndex,
 required this.endIndex,
 required this.pageIndex,
 required this.totalPages,
 required this.rowsPerPage,
 required this.onRowsPerPageChanged,
 required this.onPrev,
 required this.onNext,
 });

 final int totalCount;
 final int startIndex;
 final int endIndex;
 final int pageIndex;
 final int totalPages;
 final int rowsPerPage;
 final ValueChanged<int> onRowsPerPageChanged;
 final VoidCallback? onPrev;
 final VoidCallback? onNext;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Wrap(
 spacing: 12,
 runSpacing: 8,
 crossAxisAlignment: WrapCrossAlignment.center,
 children: [
 Text(
 'Showing ${totalCount == 0 ? 0 : startIndex + 1}-$endIndex of $totalCount',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF4B5563),
 fontWeight: FontWeight.w600,
 ),
 ),
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Text(
 'Rows:',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 6),
 DropdownButton<int>(
 value: rowsPerPage,
 underline: const SizedBox.shrink(),
 items: const [10, 25, 50, 100]
 .map((value) => DropdownMenuItem<int>(
 value: value,
 child: Text('$value'),
 ))
 .toList(),
 onChanged: (value) {
 if (value != null) onRowsPerPageChanged(value);
 },
 ),
 ],
 ),
 Text(
 'Page ${pageIndex + 1} of $totalPages',
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF4B5563),
 fontWeight: FontWeight.w600,
 ),
 ),
 IconButton(
 tooltip: 'Previous page',
 visualDensity: VisualDensity.compact,
 onPressed: onPrev,
 icon: const Icon(Icons.chevron_left, size: 20),
 ),
 IconButton(
 tooltip: 'Next page',
 visualDensity: VisualDensity.compact,
 onPressed: onNext,
 icon: const Icon(Icons.chevron_right, size: 20),
 ),
 ],
 ),
 );
 }
}

class _ActivitiesTable extends StatefulWidget {
 const _ActivitiesTable({
 required this.activities,
 required this.rowOffset,
 required this.statusLabel,
 required this.approvalLabel,
 required this.dateFormatter,
 required this.onEdit,
 required this.onDelete,
 required this.isCustomActivity,
 });

 final List<ProjectActivity> activities;
 final int rowOffset;
 final String Function(ProjectActivityStatus) statusLabel;
 final String Function(ProjectApprovalStatus) approvalLabel;
 final String Function(DateTime) dateFormatter;
 final ValueChanged<ProjectActivity> onEdit;
 final ValueChanged<ProjectActivity> onDelete;
 final bool Function(ProjectActivity) isCustomActivity;

 @override
 State<_ActivitiesTable> createState() => _ActivitiesTableState();
}

class _ActivitiesTableState extends State<_ActivitiesTable> {
 final ScrollController _horizontalController = ScrollController();

 @override
 void dispose() {
 _horizontalController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 const indexWidth = 52.0;
 const activityWidth = 230.0;
 const descriptionWidth = 360.0;
 const phaseWidth = 160.0;
 const disciplineWidth = 170.0;
 const roleWidth = 180.0;
 const assignedToWidth = 180.0;
 const statusWidth = 130.0;
 const approvalWidth = 120.0;
 const sourceWidth = 190.0;
 const appliesToWidth = 260.0;
 const updatedWidth = 120.0;
 const actionsWidth = 92.0;

 if (widget.activities.isEmpty) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: const Text(
 'No activities found for the selected filters.',
 style: TextStyle(color: Color(0xFF6B7280)),
 ),
 );
 }

 return Container(
 width: double.infinity,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Scrollbar(
 controller: _horizontalController,
 thumbVisibility: true,
 interactive: true,
 child: SingleChildScrollView(
 controller: _horizontalController,
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: 2160,
 child: DataTable(
 horizontalMargin: 12,
 columnSpacing: 16,
 showBottomBorder: true,
 dataRowMinHeight: 56,
 dataRowMaxHeight: 74,
 headingTextStyle: const TextStyle(
 fontWeight: FontWeight.w700,
 fontSize: 12,
 color: Color(0xFF374151),
 ),
 dataTextStyle: const TextStyle(
 fontSize: 12,
 color: Color(0xFF111827),
 ),
 columns: const [
 DataColumn(label: _TableHeaderCell('#', indexWidth)),
 DataColumn(label: _TableHeaderCell('Activity', activityWidth)),
 DataColumn(
 label: _TableHeaderCell('Description', descriptionWidth)),
 DataColumn(label: _TableHeaderCell('Phase', phaseWidth)),
 DataColumn(
 label: _TableHeaderCell('Discipline', disciplineWidth)),
 DataColumn(label: _TableHeaderCell('Role', roleWidth)),
 DataColumn(
 label: _TableHeaderCell('Assigned To', assignedToWidth)),
 DataColumn(label: _TableHeaderCell('Status', statusWidth)),
 DataColumn(label: _TableHeaderCell('Approval', approvalWidth)),
 DataColumn(label: _TableHeaderCell('Source', sourceWidth)),
 DataColumn(
 label: _TableHeaderCell('Applies To', appliesToWidth)),
 DataColumn(label: _TableHeaderCell('Updated', updatedWidth)),
 DataColumn(label: _TableHeaderCell('Actions', actionsWidth)),
 ],
 rows: widget.activities.asMap().entries.map((entry) {
 final localIndex = entry.key;
 final activity = entry.value;
 final globalIndex = widget.rowOffset + localIndex + 1;
 final assignedTo = (activity.assignedTo ?? '').trim();
 final phase = activity.phase.trim().isEmpty
 ? 'Unspecified'
 : activity.phase;
 final source = activity.sourceSection.replaceAll('_', ' ');
 final appliesTo = activity.applicableSections.isEmpty
 ? '-'
 : activity.applicableSections.join(', ');

 return DataRow.byIndex(
 index: globalIndex,
 color: WidgetStateProperty.resolveWith<Color?>(
 (states) => localIndex.isEven
 ? const Color(0xFFFAFBFF)
 : Colors.transparent,
 ),
 cells: [
 DataCell(_dataCell(context, '#', '$globalIndex',
 width: indexWidth)),
 DataCell(_dataCell(context, 'Activity', activity.title,
 width: activityWidth)),
 DataCell(_dataCell(
 context, 'Description', activity.description,
 width: descriptionWidth)),
 DataCell(
 _dataCell(context, 'Phase', phase, width: phaseWidth)),
 DataCell(_dataCell(
 context, 'Discipline', activity.discipline,
 width: disciplineWidth)),
 DataCell(_dataCell(context, 'Role', activity.role,
 width: roleWidth)),
 DataCell(_dataCell(context, 'Assigned To',
 assignedTo.isEmpty ? '-' : assignedTo,
 width: assignedToWidth)),
 DataCell(_statusPill(widget.statusLabel(activity.status))),
 DataCell(_approvalPill(
 widget.approvalLabel(activity.approvalStatus))),
 DataCell(_dataCell(context, 'Source', source,
 width: sourceWidth)),
 DataCell(_dataCell(context, 'Applies To', appliesTo,
 width: appliesToWidth)),
 DataCell(_dataCell(context, 'Updated',
 widget.dateFormatter(activity.updatedAt),
 width: updatedWidth)),
 DataCell(
 SizedBox(
 width: actionsWidth,
 child: Align(
 alignment: Alignment.centerLeft,
 child: PopupMenuButton<String>(
 icon: const Icon(
 Icons.more_horiz,
 size: 18,
 color: Color(0xFF6B7280),
 ),
 tooltip: 'Activity actions',
 onSelected: (value) {
 if (value == 'edit') {
 widget.onEdit(activity);
 } else if (value == 'delete') {
 widget.onDelete(activity);
 }
 },
 itemBuilder: (context) => [
 PopupMenuItem(
 value: 'edit',
 child: Row(
 children: [
 const Icon(Icons.edit_outlined, size: 16),
 const SizedBox(width: 8),
 Text(widget.isCustomActivity(activity)
 ? 'Edit'
 : 'Update'),
 ],
 ),
 ),
 PopupMenuItem(
 value: 'delete',
 child: Row(
 children: [
 Icon(
 widget.isCustomActivity(activity)
 ? Icons.delete_outline
 : Icons.visibility_off_outlined,
 size: 16,
 color: const Color(0xFFB91C1C),
 ),
 const SizedBox(width: 8),
 Text(
 widget.isCustomActivity(activity)
 ? 'Delete'
 : 'Hide',
 style: const TextStyle(
 color: Color(0xFFB91C1C),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 ],
 );
 }).toList(),
 ),
 ),
 ),
 ),
 );
 }

 Widget _dataCell(
 BuildContext context,
 String label,
 String value, {
 required double width,
 }) {
 final text = value.trim().isEmpty ? '-' : value.trim();
 final canExpand = text != '-';

 return SizedBox(
 width: width,
 child: InkWell(
 onTap: canExpand
 ? () => _showFullTextDialog(context, title: label, value: text)
 : null,
 borderRadius: BorderRadius.circular(8),
 mouseCursor: canExpand ? SystemMouseCursors.click : MouseCursor.defer,
 child: Padding(
 padding: const EdgeInsets.symmetric(vertical: 4),
 child: Text(
 text,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ),
 );
 }

 void _showFullTextDialog(
 BuildContext context, {
 required String title,
 required String value,
 }) {
 showDialog<void>(
 context: context,
 builder: (dialogContext) {
 final size = MediaQuery.of(dialogContext).size;
 return Dialog(
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 insetPadding: EdgeInsets.symmetric(
 horizontal: size.width < 640 ? 16 : 40,
 vertical: 24,
 ),
 child: ConstrainedBox(
 constraints: BoxConstraints(
 maxWidth: 760,
 maxHeight: size.height * 0.75,
 ),
 child: Padding(
 padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 title,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 ),
 IconButton(
 onPressed: () => Navigator.of(dialogContext).pop(),
 icon: const Icon(Icons.close),
 ),
 ],
 ),
 const Divider(height: 1, color: Color(0xFFE5E7EB)),
 const SizedBox(height: 12),
 Expanded(
 child: Scrollbar(
 thumbVisibility: true,
 child: SingleChildScrollView(
 child: SelectableText(
 value,
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF1F2937),
 height: 1.45,
 ),
 ),
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 },
 );
 }

 Widget _statusPill(String label) {
 Color bg;
 Color fg;
 switch (label) {
 case 'Implemented':
 bg = const Color(0xFFD1FAE5);
 fg = const Color(0xFF065F46);
 break;
 case 'Acknowledged':
 bg = const Color(0xFFE0E7FF);
 fg = const Color(0xFF3730A3);
 break;
 case 'Rejected':
 bg = const Color(0xFFFEE2E2);
 fg = const Color(0xFF991B1B);
 break;
 case 'Deferred':
 bg = const Color(0xFFFFF7ED);
 fg = const Color(0xFF9A3412);
 break;
 default:
 bg = const Color(0xFFFEF3C7);
 fg = const Color(0xFF92400E);
 }

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
 decoration: BoxDecoration(
 color: bg,
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 label,
 style: TextStyle(
 color: fg,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 ),
 ),
 );
 }

 Widget _approvalPill(String label) {
 Color bg;
 Color fg;
 switch (label) {
 case 'Approved':
 bg = const Color(0xFFDCFCE7);
 fg = const Color(0xFF166534);
 break;
 case 'Locked':
 bg = const Color(0xFFE5E7EB);
 fg = const Color(0xFF1F2937);
 break;
 default:
 bg = const Color(0xFFF3F4F6);
 fg = const Color(0xFF4B5563);
 }

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
 decoration: BoxDecoration(
 color: bg,
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 label,
 style: TextStyle(
 color: fg,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 ),
 ),
 );
 }
}

class _ActivityField extends StatelessWidget {
 const _ActivityField({
 required this.label,
 required this.controller,
 this.enabled = true,
 this.maxLines = 1,
 this.hintText,
 });

 final String label;
 final TextEditingController controller;
 final bool enabled;
 final int maxLines;
 final String? hintText;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: VoiceTextField(
 controller: controller,
 enabled: enabled,
 maxLines: maxLines,
 decoration: InputDecoration(
 labelText: label,
 hintText: hintText,
 border: const OutlineInputBorder(),
 isDense: true,
 ),
 ),
 );
 }
}

class _TableHeaderCell extends StatelessWidget {
 const _TableHeaderCell(this.label, this.width);

 final String label;
 final double width;

 @override
 Widget build(BuildContext context) {
 return SizedBox(
 width: width,
 child: Text(
 label,
 overflow: TextOverflow.ellipsis,
 ),
 );
 }
}
