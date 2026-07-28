import 'package:ndu_project/widgets/launch_notes_section.dart';
import 'package:ndu_project/widgets/launch_insights_widgets.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ndu_project/utils/download_helper_stub.dart'
 if (dart.library.html) 'package:ndu_project/utils/download_helper_web.dart' as loader;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:ndu_project/models/launch_phase_models.dart';
import 'package:ndu_project/screens/transition_to_prod_team_screen.dart';
import 'package:ndu_project/services/launch_phase_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/launch_phase_ai_seed.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';

import 'package:ndu_project/utils/csv_import_helper.dart';
class DeliverProjectClosureScreen extends StatefulWidget {
 const DeliverProjectClosureScreen({super.key});

 static void open(BuildContext context) {
 PhaseTransitionHelper.pushPhaseAware(
 context: context,
 builder: (_) => const DeliverProjectClosureScreen(),
 destinationCheckpoint: 'deliver_project_closure',
 );
 }

 @override
 State<DeliverProjectClosureScreen> createState() =>
 _DeliverProjectClosureScreenState();
}

class _DeliverProjectClosureScreenState
 extends State<DeliverProjectClosureScreen> {
  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
  final TextEditingController _notesController = TextEditingController();
 List<LaunchScopeItem> _scopeItems = [];
 List<LaunchMilestone> _milestones = [];
 List<LaunchFollowUpItem> _outstandingItems = [];
 List<LaunchFollowUpItem> _riskFollowUps = [];
 LaunchClosureNotes _closureNotes = LaunchClosureNotes();

 bool _isLoading = true;
 bool _isGenerating = false;
 bool _isExporting = false;
 bool _hasLoaded = false;
 bool _suspendSave = false;
 final Map<String, bool> _kazAiRegenerating = {};

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
 }

 String? get _projectId => ProjectDataHelper.getData(context).projectId;

 @override
 Widget build(BuildContext context) {
 final bool isMobile = MediaQuery.sizeOf(context).width < 980;

 return ResponsiveScaffold(
 activeItemLabel: '1. Launch Readiness Assessment',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: isMobile ? 16 : 32,
 vertical: isMobile ? 16 : 28,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_isLoading) const LinearProgressIndicator(minHeight: 2),
 PlanningPhaseHeader(
 title: 'Launch Readiness Assessment',
showNavigationButtons: false,
 showActivityLogAction: false,
 onExportPdf: _exportPdf),
 const SizedBox(height: 12),
            _buildLaunchInsights(),
            const SizedBox(height: 16),
            LaunchNotesSection(
              controller: _notesController,
              onChanged: (v) {},
            ),
            const SizedBox(height: 16),
 _buildScopeAcceptancePanel(),
 const SizedBox(height: 16),
 _buildMilestonesPanel(),
 const SizedBox(height: 16),
 _buildOutstandingPanel(),
 const SizedBox(height: 16),
 _buildRiskFollowUpsPanel(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Salvage and/or Disposal Plan',
 nextLabel: 'Next: Deployment Transfer, Certification & Release',
 onBack: () => Navigator.of(context).maybePop(),
 onNext: () => TransitionToProdTeamScreen.open(context),
 ),
 const SizedBox(height: 48),
 ],
 ),
 ),
 );
 }



 List<String> _teamMemberNames() {
 final data = ProjectDataHelper.getData(context);
 final names = data.teamMembers
 .map((m) => m.name.trim())
 .where((n) => n.isNotEmpty)
 .toList();
 if (names.isEmpty) return const ['Unassigned'];
 return names;
 }


 // Launch Insights: KPIs + completion donut (auto-derived from project data)
 Widget _buildLaunchInsights() {
   final projectData = ProjectDataHelper.getData(context);
   final totalChecks = 4; // charter + milestones + risks + allowances
       var ready = 0;
       if (projectData.charterApprovalDate != null) ready++;
       if (projectData.keyMilestones.isNotEmpty) ready++;
       if (projectData.frontEndPlanning.riskRegisterItems.isNotEmpty) ready++;
       if (projectData.frontEndPlanning.allowanceItems.isNotEmpty) ready++;
       final completionPct = ready / totalChecks;
   return LaunchInsightsHeader(
     sectionTitle: 'Launch Readiness Assessment',
     sectionSubtitle: 'Go-live readiness across people, process, technology & operations',
     sectionIcon: Icons.fact_check_outlined,
     sectionColor: const Color(0xFF10B981),
     completionPercent: completionPct,
     completionLabel: 'READY',
     completionCaption:
         '${(completionPct * 100).round()}% complete - auto-derived from project data',
     kpiTiles: [
       LaunchKpiTile(
             label: 'Charter Approved',
             value: projectData.charterApprovalDate != null ? 'Yes' : 'No',
             icon: Icons.verified_outlined,
             color: projectData.charterApprovalDate != null
                 ? const Color(0xFF10B981)
                 : const Color(0xFFEF4444),
             delta: projectData.charterApprovalDate != null
                 ? 'planning unlocked'
                 : 'planning locked',
           ),
           LaunchKpiTile(
             label: 'Milestones',
             value: '${projectData.keyMilestones.length}',
             icon: Icons.flag_outlined,
             color: const Color(0xFF2563EB),
             delta: '${projectData.keyMilestones.where((m) => m.dueDate.isNotEmpty).length} dated',
           ),
           LaunchKpiTile(
             label: 'Risks Tracked',
             value: '${projectData.frontEndPlanning.riskRegisterItems.length}',
             icon: Icons.warning_amber_outlined,
             color: const Color(0xFFF59E0B),
             delta: '${projectData.frontEndPlanning.riskRegisterItems.where((r) => r.status.toLowerCase() != 'closed').length} open',
           ),
           LaunchKpiTile(
             label: 'Allowances',
             value: '${projectData.frontEndPlanning.allowanceItems.length}',
             icon: Icons.savings_outlined,
             color: const Color(0xFFD97706),
             delta: 'contingency tracked',
           ),
     ],
   );
 }


 Widget _buildScopeAcceptancePanel() {
 return LaunchDataTable(
 title: 'Scope Acceptance',
 subtitle:
 'Track acceptance status for each deliverable. Items are editable inline.',
 columns: [
 const LaunchColumn(label: 'Deliverable', flexible: true),
 const LaunchColumn(label: 'Criteria', flexible: true),
 LaunchColumn(
 label: 'Status',
 width: 120,
 fieldType: LaunchFieldType.dropdown,
 dropdownItems: const ['Pending', 'Accepted', 'Partial', 'Rejected'],
 ),
 const LaunchColumn(label: 'Date', width: 130, fieldType: LaunchFieldType.date),
 ],
 rowCount: _scopeItems.length,
 onAddValues: _addScopeItem,
 csvColumns: const [
 CsvColumnSpec(key: 'deliverable', label: 'Deliverable', sampleValue: 'User Portal'),
 CsvColumnSpec(key: 'criteria', label: 'Criteria', sampleValue: 'All acceptance tests pass'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Pending', allowedValues: ['Pending', 'Accepted', 'Partial', 'Rejected']),
 CsvColumnSpec(key: 'date', label: 'Date', sampleValue: '2025-01-15'),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _scopeItems.add(LaunchScopeItem(
 deliverable: row['deliverable'] ?? '',
 acceptanceCriteria: row['criteria'] ?? '',
 status: row['status'] ?? 'Pending',
 acceptanceDate: row['date'] ?? '',
 ));
 });
 }
 _scheduleSave();
 },
 emptyMessage:
 'No scope items yet. Add deliverables to track their acceptance status.',
 cellBuilder: (ctx, i) => LaunchDataRow(
 onEdit: () => _editScopeItem(i),
 onDelete: () => _confirmDeleteScope(i),
 onKazAi: () => _regenerateScopeRow(i),
 showDivider: i < _scopeItems.length - 1,
 cells: [
 LaunchEditableCell(
 value: _scopeItems[i].deliverable,
 hint: 'Deliverable',
 expand: true,
 bold: true,
 onChanged: (v) {
 _scopeItems[i] = _scopeItems[i].copyWith(deliverable: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: _scopeItems[i].acceptanceCriteria,
 hint: 'Criteria',
 expand: true,
 onChanged: (v) {
 _scopeItems[i] = _scopeItems[i].copyWith(acceptanceCriteria: v);
 _scheduleSave();
 },
 ),
 LaunchStatusDropdown(
 value: _scopeItems[i].status,
 items: ['Pending', 'Accepted', 'Partial', 'Rejected'],
 onChanged: (v) {
 if (v == null) return;
 _scopeItems[i] = _scopeItems[i].copyWith(status: v);
 _scheduleSave();
 setState(() {});
 },
 ),
 LaunchDateCell(
 value: _scopeItems[i].acceptanceDate,
 hint: 'Date',
 width: 130,
 onChanged: (v) {
 _scopeItems[i] = _scopeItems[i].copyWith(acceptanceDate: v);
 _scheduleSave();
 },
 ),
 ],
 ),
 );
 }

 Widget _buildMilestonesPanel() {
 return LaunchDataTable(
 title: 'Delivery Milestones',
 subtitle: 'Track planned vs actual completion for key milestones.',
 columns: [
 const LaunchColumn(label: 'Milestone', flexible: true),
 const LaunchColumn(label: 'Planned', width: 120, fieldType: LaunchFieldType.date),
 const LaunchColumn(label: 'Actual', width: 120, fieldType: LaunchFieldType.date),
 LaunchColumn(
 label: 'Status',
 width: 120,
 fieldType: LaunchFieldType.dropdown,
 dropdownItems: const ['Pending', 'In Progress', 'Complete', 'Delayed'],
 ),
 ],
 rowCount: _milestones.length,
 onAddValues: _addMilestone,
 csvColumns: const [
 CsvColumnSpec(key: 'milestone', label: 'Milestone', sampleValue: 'Go-live'),
 CsvColumnSpec(key: 'planned', label: 'Planned', sampleValue: '2025-01-15'),
 CsvColumnSpec(key: 'actual', label: 'Actual', sampleValue: '2025-01-18'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Pending', allowedValues: ['Pending', 'In Progress', 'Complete', 'Delayed']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _milestones.add(LaunchMilestone(
 title: row['milestone'] ?? '',
 plannedDate: row['planned'] ?? '',
 actualDate: row['actual'] ?? '',
 status: row['status'] ?? 'Pending',
 ));
 });
 }
 _scheduleSave();
 },
 emptyMessage:
 'No milestones yet. Add delivery milestones to track progress.',
 cellBuilder: (ctx, i) => LaunchDataRow(
 onEdit: () => _scheduleSave(),
 onDelete: () => _confirmDeleteMilestone(i),
 onKazAi: () => _regenerateMilestoneRow(i),
 showDivider: i < _milestones.length - 1,
 cells: [
 LaunchEditableCell(
 value: _milestones[i].title,
 hint: 'Milestone',
 expand: true,
 bold: true,
 onChanged: (v) {
 _milestones[i] = _milestones[i].copyWith(title: v);
 _scheduleSave();
 },
 ),
 LaunchDateCell(
 value: _milestones[i].plannedDate,
 hint: 'Planned date',
 onChanged: (v) {
 _milestones[i] = _milestones[i].copyWith(plannedDate: v);
 _scheduleSave();
 },
 ),
 LaunchDateCell(
 value: _milestones[i].actualDate,
 hint: 'Actual date',
 onChanged: (v) {
 _milestones[i] = _milestones[i].copyWith(actualDate: v);
 _scheduleSave();
 },
 ),
 LaunchStatusDropdown(
 value: _milestones[i].status,
 items: ['Pending', 'In Progress', 'Complete', 'Delayed'],
 onChanged: (v) {
 if (v == null) return;
 _milestones[i] = _milestones[i].copyWith(status: v);
 _scheduleSave();
 setState(() {});
 },
 ),
 ],
 ),
 );
 }

 Widget _buildOutstandingPanel() {
 final ownerNames = _teamMemberNames();
 return LaunchDataTable(
 title: 'Outstanding Items',
 subtitle: 'Items still pending closure before or shortly after handover.',
 columns: [
 const LaunchColumn(label: 'Title', flexible: true),
 const LaunchColumn(label: 'Details', flexible: true),
 LaunchColumn(
 label: 'Owner',
 width: 120,
 fieldType: LaunchFieldType.dropdown,
 dropdownItems: ownerNames,
 ),
 LaunchColumn(
 label: 'Status',
 width: 120,
 fieldType: LaunchFieldType.dropdown,
 dropdownItems: const ['Open', 'In Progress', 'Complete', 'Deferred'],
 ),
 ],
 rowCount: _outstandingItems.length,
 onAddValues: (v) => _addFollowUp(_outstandingItems, v),
 csvColumns: const [
 CsvColumnSpec(key: 'title', label: 'Title', sampleValue: 'Pending bug fix'),
 CsvColumnSpec(key: 'details', label: 'Details', sampleValue: 'Critical UI bug in production'),
 CsvColumnSpec(key: 'owner', label: 'Owner', sampleValue: 'Tech Lead'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Open', allowedValues: ['Open', 'In Progress', 'Complete', 'Deferred']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _outstandingItems.add(LaunchFollowUpItem(
 title: row['title'] ?? '',
 details: row['details'] ?? '',
 owner: row['owner'] ?? '',
 status: row['status'] ?? 'Open',
 ));
 });
 }
 _scheduleSave();
 },
 emptyMessage:
 'No outstanding items. All clear, or add items that need resolution.',
 cellBuilder: (ctx, i) => LaunchDataRow(
 onEdit: () => _scheduleSave(),
 onDelete: () => _confirmDeleteFollowUp(i, _outstandingItems),
 onKazAi: () => _regenerateOutstandingRow(i),
 showDivider: i < _outstandingItems.length - 1,
 cells: [
 LaunchEditableCell(
 value: _outstandingItems[i].title,
 hint: 'Title',
 expand: true,
 bold: true,
 onChanged: (v) {
 _outstandingItems[i] = _outstandingItems[i].copyWith(title: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: _outstandingItems[i].details,
 hint: 'Details',
 expand: true,
 onChanged: (v) {
 _outstandingItems[i] = _outstandingItems[i].copyWith(details: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: _outstandingItems[i].owner,
 hint: 'Owner',
 expand: true,
 onChanged: (v) {
 _outstandingItems[i] = _outstandingItems[i].copyWith(owner: v);
 _scheduleSave();
 },
 ),
 LaunchStatusDropdown(
 value: _outstandingItems[i].status,
 items: ['Open', 'In Progress', 'Complete', 'Deferred'],
 onChanged: (v) {
 if (v == null) return;
 _outstandingItems[i] = _outstandingItems[i].copyWith(status: v);
 _scheduleSave();
 setState(() {});
 },
 ),
 ],
 ),
 );
 }

 Widget _buildRiskFollowUpsPanel() {
 final ownerNames = _teamMemberNames();
 return LaunchDataTable(
 title: 'Post-Delivery Risks',
 subtitle: 'Risks and gaps to monitor after project delivery.',
 columns: [
 const LaunchColumn(label: 'Title', flexible: true),
 const LaunchColumn(label: 'Details', flexible: true),
 LaunchColumn(
 label: 'Owner',
 width: 120,
 fieldType: LaunchFieldType.dropdown,
 dropdownItems: ownerNames,
 ),
 LaunchColumn(
 label: 'Status',
 width: 120,
 fieldType: LaunchFieldType.dropdown,
 dropdownItems: const ['Open', 'In Progress', 'Complete', 'Deferred'],
 ),
 ],
 rowCount: _riskFollowUps.length,
 onAddValues: (v) => _addFollowUp(_riskFollowUps, v),
 csvColumns: const [
 CsvColumnSpec(key: 'title', label: 'Title', sampleValue: 'Performance degradation'),
 CsvColumnSpec(key: 'details', label: 'Details', sampleValue: 'API latency above threshold'),
 CsvColumnSpec(key: 'owner', label: 'Owner', sampleValue: 'Ops Lead'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Open', allowedValues: ['Open', 'In Progress', 'Complete', 'Deferred']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _riskFollowUps.add(LaunchFollowUpItem(
 title: row['title'] ?? '',
 details: row['details'] ?? '',
 owner: row['owner'] ?? '',
 status: row['status'] ?? 'Open',
 ));
 });
 }
 _scheduleSave();
 },
 emptyMessage:
 'No post-delivery risks. Document risks that need monitoring post-delivery.',
 cellBuilder: (ctx, i) => LaunchDataRow(
 onEdit: () => _scheduleSave(),
 onDelete: () => _confirmDeleteFollowUp(i, _riskFollowUps),
 onKazAi: () => _regenerateRiskFollowUpRow(i),
 showDivider: i < _riskFollowUps.length - 1,
 cells: [
 LaunchEditableCell(
 value: _riskFollowUps[i].title,
 hint: 'Title',
 expand: true,
 bold: true,
 onChanged: (v) {
 _riskFollowUps[i] = _riskFollowUps[i].copyWith(title: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: _riskFollowUps[i].details,
 hint: 'Details',
 expand: true,
 onChanged: (v) {
 _riskFollowUps[i] = _riskFollowUps[i].copyWith(details: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: _riskFollowUps[i].owner,
 hint: 'Owner',
 expand: true,
 onChanged: (v) {
 _riskFollowUps[i] = _riskFollowUps[i].copyWith(owner: v);
 _scheduleSave();
 },
 ),
 LaunchStatusDropdown(
 value: _riskFollowUps[i].status,
 items: ['Open', 'In Progress', 'Complete', 'Deferred'],
 onChanged: (v) {
 if (v == null) return;
 _riskFollowUps[i] = _riskFollowUps[i].copyWith(status: v);
 _scheduleSave();
 setState(() {});
 },
 ),
 ],
 ),
 );
 }

 void _addScopeItem(Map<String, String> values) {
 setState(() {
 _scopeItems.add(LaunchScopeItem(
 deliverable: values['Deliverable'] ?? '',
 acceptanceCriteria: values['Criteria'] ?? '',
 status: values['Status'] ?? 'Pending',
 acceptanceDate: values['Date'] ?? '',
 ));
 });
 _scheduleSave();
 }

 /// Opens an edit modal for a Scope Acceptance row.
 /// Pre-fills the dialog with existing values and updates the row on save.
 Future<void> _editScopeItem(int index) async {
 if (index < 0 || index >= _scopeItems.length) return;
 final item = _scopeItems[index];

 final result = await showDialog<Map<String, String>>(
 context: context,
 builder: (context) => _ScopeEditDialog(
 deliverable: item.deliverable,
 criteria: item.acceptanceCriteria,
 status: item.status,
 date: item.acceptanceDate,
 ),
 );

 if (result != null && mounted) {
 setState(() {
 _scopeItems[index] = item.copyWith(
 deliverable: result['Deliverable'] ?? item.deliverable,
 acceptanceCriteria: result['Criteria'] ?? item.acceptanceCriteria,
 status: result['Status'] ?? item.status,
 acceptanceDate: result['Date'] ?? item.acceptanceDate,
 );
 });
 _scheduleSave();
 }
 }

 void _addMilestone(Map<String, String> values) {
 setState(() {
 _milestones.add(LaunchMilestone(
 title: values['Milestone'] ?? '',
 plannedDate: values['Planned'] ?? '',
 actualDate: values['Actual'] ?? '',
 status: values['Status'] ?? 'Pending',
 ));
 });
 _scheduleSave();
 }

 void _addFollowUp(List<LaunchFollowUpItem> list, Map<String, String> values) {
 setState(() {
 list.add(LaunchFollowUpItem(
 title: values['Title'] ?? '',
 details: values['Details'] ?? '',
 owner: values['Owner'] ?? '',
 status: values['Status'] ?? 'Open',
 ));
 });
 _scheduleSave();
 }

 Future<void> _importScope() async {
 if (_projectId == null) return;
 final imported =
 await LaunchPhaseService.loadScopeTrackingItems(_projectId!);
 if (imported.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('No scope items found to import.')),
 );
 }
 return;
 }
 setState(() {
 final existing = _scopeItems.map((s) => s.deliverable).toSet();
 for (final s in imported) {
 if (!existing.contains(s.deliverable)) _scopeItems.add(s);
 }
 });
 _scheduleSave();
 }

 Future<void> _confirmDeleteScope(int idx) async {
 final confirmed =
 await launchConfirmDelete(context, itemName: 'scope item');
 if (!confirmed || !mounted) return;
 setState(() => _scopeItems.removeAt(idx));
 _scheduleSave();
 }

 Future<void> _confirmDeleteMilestone(int idx) async {
 final confirmed = await launchConfirmDelete(context, itemName: 'milestone');
 if (!confirmed || !mounted) return;
 setState(() => _milestones.removeAt(idx));
 _scheduleSave();
 }

 Future<void> _confirmDeleteFollowUp(
 int idx, List<LaunchFollowUpItem> list) async {
 final confirmed =
 await launchConfirmDelete(context, itemName: 'follow-up item');
 if (!confirmed || !mounted) return;
 setState(() => list.removeAt(idx));
 _scheduleSave();
 }

 void _scheduleSave() {
 if (_suspendSave || !_hasLoaded) return;
 Future.microtask(() {
 if (mounted) _persistData();
 });
 }

 Future<void> _loadData() async {
 if (_hasLoaded || _projectId == null) return;
 _suspendSave = true;

 try {
 final result =
 await LaunchPhaseService.loadDeliverProject(projectId: _projectId!);

 if (!mounted) return;
 setState(() {
 _scopeItems = result.scopeItems;
 _milestones = result.milestones;
 _outstandingItems = result.outstandingItems;
 _riskFollowUps = result.riskFollowUps;
 _closureNotes = result.closureNotes;
 _isLoading = false;
 _hasLoaded = true;
 });

 final allEmpty = _scopeItems.isEmpty &&
 _milestones.isEmpty &&
 _outstandingItems.isEmpty &&
 _riskFollowUps.isEmpty;
 if (allEmpty) {
 await _autoPopulateFromPriorPhases();
 }

 final stillEmpty = _scopeItems.isEmpty &&
 _milestones.isEmpty &&
 _outstandingItems.isEmpty &&
 _riskFollowUps.isEmpty;
 if (stillEmpty) await _populateFromAi();

 final allStillEmpty = _scopeItems.isEmpty &&
 _milestones.isEmpty &&
 _outstandingItems.isEmpty &&
 _riskFollowUps.isEmpty;
 if (allStillEmpty) _populateWithSeedData();
 } catch (e) {
 debugPrint('Deliver project load error: $e');
 if (mounted) setState(() => _isLoading = false);
 }

 _suspendSave = false;

 // Persist seed data after suspend is lifted
 if (_scopeItems.isNotEmpty || _milestones.isNotEmpty ||
 _outstandingItems.isNotEmpty || _riskFollowUps.isNotEmpty) {
 _persistData();
 }
 }

 Future<void> _persistData() async {
 if (_projectId == null) return;
 try {
 await LaunchPhaseService.saveDeliverProject(
 projectId: _projectId!,
 scopeItems: _scopeItems,
 milestones: _milestones,
 outstandingItems: _outstandingItems,
 riskFollowUps: _riskFollowUps,
 closureNotes: _closureNotes,
 );
 } catch (e) {
 debugPrint('Deliver project save error: $e');
 }
 }

 Future<void> _autoPopulateFromPriorPhases() async {
 if (_projectId == null) return;
 try {
 final cp = await LaunchPhaseAiSeed.loadCrossPhaseData(_projectId!);
 if (!mounted) return;

 // Pre-fill scope items from cross-phase scope tracking
 if (_scopeItems.isEmpty && cp.scopeTracking.isNotEmpty) {
 final existing = _scopeItems.map((s) => s.deliverable).toSet();
 final newItems = cp.scopeTracking
 .where((s) => !existing.contains(s.deliverable))
 .toList();
 if (newItems.isNotEmpty) {
 setState(() => _scopeItems.addAll(newItems));
 }
 }

 // Pre-fill milestones from planning sprints
 if (_milestones.isEmpty && cp.planningSprints.isNotEmpty) {
 final newMilestones = cp.planningSprints
 .map((s) => LaunchMilestone(
 title: 'Sprint ${s['sprintNumber'] ?? s['name'] ?? '?'}: ${s['goal'] ?? s['title'] ?? ''}',
 status: _normalizeSprintStatus(s['status']),
 ))
 .where((m) => m.title.isNotEmpty)
 .toList();
 if (newMilestones.isNotEmpty) {
 setState(() => _milestones.addAll(newMilestones));
 }
 }

 // Pre-fill risk follow-ups from open risk items
 if (_riskFollowUps.isEmpty && cp.openRiskItems.isNotEmpty) {
 final existing = _riskFollowUps.map((r) => r.title).toSet();
 final newRisks = cp.openRiskItems
 .where((r) => !existing.contains(r['title']?.toString() ?? r['risk']?.toString() ?? ''))
 .map((r) => LaunchFollowUpItem(
 title: r['title']?.toString() ?? r['risk']?.toString() ?? '',
 details: r['description']?.toString() ?? r['details']?.toString() ?? '',
 owner: r['owner']?.toString() ?? '',
 status: r['status']?.toString() ?? 'Open',
 ))
 .where((r) => r.title.isNotEmpty)
 .toList();
 if (newRisks.isNotEmpty) {
 setState(() => _riskFollowUps.addAll(newRisks));
 }
 }

 final hasNewData = _scopeItems.isNotEmpty ||
 _milestones.isNotEmpty ||
 _riskFollowUps.isNotEmpty;
 if (hasNewData) await _persistData();
 } catch (e) {
 debugPrint('Deliver project auto-populate error: $e');
 }
 }

 void _populateWithSeedData() {
 final now = DateTime.now();
 final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
 final nextWeek = now.add(const Duration(days: 7));
 final nextWeekStr = '${nextWeek.year}-${nextWeek.month.toString().padLeft(2, '0')}-${nextWeek.day.toString().padLeft(2, '0')}';
 final twoWeeks = now.add(const Duration(days: 14));
 final twoWeeksStr = '${twoWeeks.year}-${twoWeeks.month.toString().padLeft(2, '0')}-${twoWeeks.day.toString().padLeft(2, '0')}';

 setState(() {
 _scopeItems = [
 LaunchScopeItem(
 deliverable: 'User Portal — Final Build',
 acceptanceCriteria: 'All user acceptance tests pass; no critical bugs',
 status: 'Pending',
 acceptanceDate: nextWeekStr,
 ),
 LaunchScopeItem(
 deliverable: 'Admin Dashboard',
 acceptanceCriteria: 'Admin role CRUD operations verified end-to-end',
 status: 'Pending',
 acceptanceDate: nextWeekStr,
 ),
 LaunchScopeItem(
 deliverable: 'API Documentation',
 acceptanceCriteria: 'All endpoints documented with examples and error codes',
 status: 'Accepted',
 acceptanceDate: today,
 ),
 LaunchScopeItem(
 deliverable: 'Deployment Scripts & CI/CD',
 acceptanceCriteria: 'Automated deploy to staging succeeds; rollback tested',
 status: 'Pending',
 acceptanceDate: twoWeeksStr,
 ),
 LaunchScopeItem(
 deliverable: 'Data Migration Package',
 acceptanceCriteria: 'Production data migrated with zero data loss verified',
 status: 'Partial',
 acceptanceDate: twoWeeksStr,
 ),
 ];

 _milestones = [
 LaunchMilestone(
 title: 'Final UAT Sign-Off',
 plannedDate: nextWeekStr,
 status: 'In Progress',
 ),
 LaunchMilestone(
 title: 'Production Deployment',
 plannedDate: twoWeeksStr,
 status: 'Pending',
 ),
 LaunchMilestone(
 title: 'Handover to Operations',
 plannedDate: twoWeeksStr,
 status: 'Pending',
 ),
 LaunchMilestone(
 title: 'Post-Launch Review',
 plannedDate: () {
 final d = twoWeeks.add(const Duration(days: 7));
 return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
 }(),
 status: 'Pending',
 ),
 ];

 _outstandingItems = [
 LaunchFollowUpItem(
 title: 'Performance load testing results',
 details: 'Complete load test for 500 concurrent users and document results',
 owner: 'Tech Lead',
 status: 'In Progress',
 ),
 LaunchFollowUpItem(
 title: 'Security audit remediation',
 details: 'Address 3 medium-severity findings from the penetration test',
 owner: 'Security Analyst',
 status: 'Open',
 ),
 LaunchFollowUpItem(
 title: 'End-user training materials',
 details: 'Finalize user guide and record walkthrough video',
 owner: 'Business Analyst',
 status: 'Open',
 ),
 LaunchFollowUpItem(
 title: 'License key provisioning',
 details: 'Procure production licenses for all third-party integrations',
 owner: 'Procurement Lead',
 status: 'Open',
 ),
 ];

 _riskFollowUps = [
 LaunchFollowUpItem(
 title: 'Third-party API rate limits',
 details: 'Monitor usage against vendor API quotas during initial launch period',
 owner: 'Integration Lead',
 status: 'Open',
 ),
 LaunchFollowUpItem(
 title: 'Data rollback readiness',
 details: 'Ensure database snapshots are taken before go-live for rollback capability',
 owner: 'DBA',
 status: 'Open',
 ),
 LaunchFollowUpItem(
 title: 'Stakeholder availability',
 details: 'Confirm key stakeholders are available for go-live support window',
 owner: 'Project Manager',
 status: 'In Progress',
 ),
 ];
 });
 }

 String _normalizeSprintStatus(dynamic status) {
 final s = (status ?? '').toString().toLowerCase();
 if (s == 'completed' || s == 'done') return 'Complete';
 if (s == 'in progress' || s == 'active') return 'In Progress';
 return 'Pending';
 }

 Future<void> _populateFromAi() async {
 if (_isGenerating) return;

 setState(() => _isGenerating = true);

 LaunchAiResult? result;
 try {
 result = await LaunchPhaseAiSeed.generateEntries(
 context: context,
 sectionLabel: 'Deliver Project Closure',
 sections: const {
 'scope_acceptance':
 'Scope acceptance items with "deliverable", "acceptance_criteria", "status"',
 'milestones':
 'Delivery milestones with "title", "planned_date", "actual_date", "status"',
 'outstanding': 'Outstanding items with "title", "details", "owner", "status"',
 'risk_followups': 'Post-delivery risks with "title", "details", "owner", "status"',
 },
 itemsPerSection: 3,
 );
 } catch (e) {
 debugPrint('Deliver project AI error: $e');
 }

 if (!mounted) return;

 // Show insufficient context dialog if context is insufficient
 if (result != null && !result.isContextSufficient) {
 setState(() => _isGenerating = false);
 await LaunchPhaseAiSeed.showInsufficientContextDialog(
 context,
 missingAreas: result.missingAreas,
 );
 return;
 }

 final generated = result?.entries ?? {};

 final hasExistingData = _scopeItems.isNotEmpty ||
 _milestones.isNotEmpty ||
 _outstandingItems.isNotEmpty ||
 _riskFollowUps.isNotEmpty;
 if (hasExistingData) {
 setState(() => _isGenerating = false);
 return;
 }

 setState(() {
 _scopeItems = _mapToScopeItems(generated['scope_acceptance']);
 _milestones = _mapToMilestones(generated['milestones']);
 _outstandingItems = _mapToFollowUps(generated['outstanding']);
 _riskFollowUps = _mapToFollowUps(generated['risk_followups']);
 _isGenerating = false;
 });
 await _persistData();
 }

 /// Regenerate a single scope acceptance row using KAZ AI.
 /// Re-populates the deliverable name and acceptance criteria from AI.
 /// Regenerate a single scope acceptance row using KAZ AI.
 Future<void> _regenerateScopeRow(int index) async {
 if (index < 0 || index >= _scopeItems.length) return;
 final key = 'scope_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final contextText = ProjectDataHelper.buildProjectContextScan(
 projectData,
 sectionLabel: 'Scope Acceptance',
 );
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a deliverable name and its '
 'acceptance criteria for a scope acceptance item.\n\n'
 'Context:\n$contextText\n\n'
 'Current deliverable: ${_scopeItems[index].deliverable}\n'
 'Current criteria: ${_scopeItems[index].acceptanceCriteria}\n\n'
 'Return ONLY a valid JSON object with keys: "deliverable", "criteria".',
 maxTokens: 200,
 temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final jsonStr = result.substring(start, end + 1);
 final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _scopeItems[index] = _scopeItems[index].copyWith(
 deliverable: (parsed['deliverable'] ?? '').toString(),
 acceptanceCriteria: (parsed['criteria'] ?? '').toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('KAZ AI regeneration failed: $e')),
 );
 }
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 /// Regenerate a single delivery milestone row using KAZ AI.
 Future<void> _regenerateMilestoneRow(int index) async {
 if (index < 0 || index >= _milestones.length) return;
 final key = 'milestone_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final contextText = ProjectDataHelper.buildProjectContextScan(
 projectData,
 sectionLabel: 'Delivery Milestones',
 );
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a delivery milestone title '
 'and its status for a project closure checklist.\n\n'
 'Context:\n$contextText\n\n'
 'Current milestone: ${_milestones[index].title}\n'
 'Current status: ${_milestones[index].status}\n\n'
 'Return ONLY a valid JSON object with keys: "title", "status". '
 'Status must be one of: Pending, In Progress, Complete, Delayed.',
 maxTokens: 200,
 temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final jsonStr = result.substring(start, end + 1);
 final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _milestones[index] = _milestones[index].copyWith(
 title: (parsed['title'] ?? '').toString(),
 status: (parsed['status'] ?? _milestones[index].status).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('KAZ AI regeneration failed: $e')),
 );
 }
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 /// Regenerate a single outstanding item row using KAZ AI.
 Future<void> _regenerateOutstandingRow(int index) async {
 if (index < 0 || index >= _outstandingItems.length) return;
 final key = 'outstanding_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final contextText = ProjectDataHelper.buildProjectContextScan(
 projectData,
 sectionLabel: 'Outstanding Items',
 );
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest an outstanding item title, '
 'details, owner, and status for a project closure checklist.\n\n'
 'Context:\n$contextText\n\n'
 'Current title: ${_outstandingItems[index].title}\n'
 'Current details: ${_outstandingItems[index].details}\n'
 'Current owner: ${_outstandingItems[index].owner}\n'
 'Current status: ${_outstandingItems[index].status}\n\n'
 'Return ONLY a valid JSON object with keys: "title", "details", '
 '"owner", "status". Status must be one of: Open, In Progress, '
 'Complete, Deferred.',
 maxTokens: 250,
 temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final jsonStr = result.substring(start, end + 1);
 final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _outstandingItems[index] = _outstandingItems[index].copyWith(
 title: (parsed['title'] ?? '').toString(),
 details: (parsed['details'] ?? '').toString(),
 owner: (parsed['owner'] ?? _outstandingItems[index].owner).toString(),
 status: (parsed['status'] ?? _outstandingItems[index].status).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('KAZ AI regeneration failed: $e')),
 );
 }
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 /// Regenerate a single post-delivery risk row using KAZ AI.
 Future<void> _regenerateRiskFollowUpRow(int index) async {
 if (index < 0 || index >= _riskFollowUps.length) return;
 final key = 'risk_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final contextText = ProjectDataHelper.buildProjectContextScan(
 projectData,
 sectionLabel: 'Post-Delivery Risks',
 );
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a post-delivery risk title, '
 'details, owner, and status for a project closure risk register.\n\n'
 'Context:\n$contextText\n\n'
 'Current title: ${_riskFollowUps[index].title}\n'
 'Current details: ${_riskFollowUps[index].details}\n'
 'Current owner: ${_riskFollowUps[index].owner}\n'
 'Current status: ${_riskFollowUps[index].status}\n\n'
 'Return ONLY a valid JSON object with keys: "title", "details", '
 '"owner", "status". Status must be one of: Open, In Progress, '
 'Complete, Deferred.',
 maxTokens: 250,
 temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final jsonStr = result.substring(start, end + 1);
 final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _riskFollowUps[index] = _riskFollowUps[index].copyWith(
 title: (parsed['title'] ?? '').toString(),
 details: (parsed['details'] ?? '').toString(),
 owner: (parsed['owner'] ?? _riskFollowUps[index].owner).toString(),
 status: (parsed['status'] ?? _riskFollowUps[index].status).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('KAZ AI regeneration failed: $e')),
 );
 }
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 Future<void> _exportPdf() async {
 setState(() => _isExporting = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final projectName = projectData.projectName.isEmpty ? 'Project' : projectData.projectName;
 final now = DateTime.now();
 final stamp =
 '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
 final filename =
 'deliver_project_${projectName.replaceAll(' ', '_')}_$stamp.pdf';

 final doc = pw.Document();

 doc.addPage(
 pw.MultiPage(
 pageFormat: PdfPageFormat.a4,
 margin: const pw.EdgeInsets.all(32),
 build: (_) => [
 pw.Text(
 'Deliver Project — Closure Summary',
 style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
 ),
 pw.SizedBox(height: 4),
 pw.Text(
 '$projectName — Generated ${now.toLocal().toIso8601String()}',
 style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
 ),
 pw.SizedBox(height: 16),
 _pdfSectionTitle('Scope Acceptance'),
 pw.SizedBox(height: 6),
 if (_scopeItems.isEmpty)
 pw.Text('No scope items recorded.',
 style: const pw.TextStyle(
 fontSize: 10, color: PdfColors.grey500))
 else
 pw.Table(
 border: pw.TableBorder.all(color: PdfColors.grey300),
 children: [
 pw.TableRow(
 decoration:
 const pw.BoxDecoration(color: PdfColors.grey100),
 children: [
 _pdfHeaderCell('Deliverable'),
 _pdfHeaderCell('Acceptance Criteria'),
 _pdfHeaderCell('Status'),
 ],
 ),
 ..._scopeItems.map((s) => pw.TableRow(children: [
 _pdfCell(s.deliverable),
 _pdfCell(s.acceptanceCriteria),
 _pdfCell(s.status),
 ])),
 ],
 ),
 pw.SizedBox(height: 16),
 _pdfSectionTitle('Delivery Milestones'),
 pw.SizedBox(height: 6),
 if (_milestones.isEmpty)
 pw.Text('No milestones recorded.',
 style: const pw.TextStyle(
 fontSize: 10, color: PdfColors.grey500))
 else
 pw.Table(
 border: pw.TableBorder.all(color: PdfColors.grey300),
 children: [
 pw.TableRow(
 decoration:
 const pw.BoxDecoration(color: PdfColors.grey100),
 children: [
 _pdfHeaderCell('Milestone'),
 _pdfHeaderCell('Status'),
 ],
 ),
 ..._milestones.map((m) => pw.TableRow(children: [
 _pdfCell(m.title),
 _pdfCell(m.status),
 ])),
 ],
 ),
 pw.SizedBox(height: 16),
 _pdfSectionTitle('Outstanding Items'),
 pw.SizedBox(height: 6),
 if (_outstandingItems.isEmpty)
 pw.Text('No outstanding items.',
 style: const pw.TextStyle(
 fontSize: 10, color: PdfColors.grey500))
 else
 pw.Table(
 border: pw.TableBorder.all(color: PdfColors.grey300),
 children: [
 pw.TableRow(
 decoration:
 const pw.BoxDecoration(color: PdfColors.grey100),
 children: [
 _pdfHeaderCell('Title'),
 _pdfHeaderCell('Details'),
 _pdfHeaderCell('Status'),
 ],
 ),
 ..._outstandingItems.map((o) => pw.TableRow(children: [
 _pdfCell(o.title),
 _pdfCell(o.details),
 _pdfCell(o.status),
 ])),
 ],
 ),
 pw.SizedBox(height: 16),
 _pdfSectionTitle('Post-Delivery Risks'),
 pw.SizedBox(height: 6),
 if (_riskFollowUps.isEmpty)
 pw.Text('No post-delivery risks recorded.',
 style: const pw.TextStyle(
 fontSize: 10, color: PdfColors.grey500))
 else
 pw.Table(
 border: pw.TableBorder.all(color: PdfColors.grey300),
 children: [
 pw.TableRow(
 decoration:
 const pw.BoxDecoration(color: PdfColors.grey100),
 children: [
 _pdfHeaderCell('Title'),
 _pdfHeaderCell('Details'),
 _pdfHeaderCell('Status'),
 ],
 ),
 ..._riskFollowUps.map((r) => pw.TableRow(children: [
 _pdfCell(r.title),
 _pdfCell(r.details),
 _pdfCell(r.status),
 ])),
 ],
 ),
 ],
 ),
 );

 final bytes = await doc.save();
 if (!mounted) return;
 loader.downloadFile(bytes, filename, mimeType: 'application/pdf');
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('PDF export failed: ${e.toString()}')),
 );
 }
 } finally {
 if (mounted) setState(() => _isExporting = false);
 }
 }

 pw.Widget _pdfSectionTitle(String title) {
 return pw.Text(title,
 style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold));
 }

 pw.Widget _pdfHeaderCell(String text) {
 return pw.Padding(
 padding: const pw.EdgeInsets.all(6),
 child: pw.Text(text,
 style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
 );
 }

 pw.Widget _pdfCell(String text) {
 return pw.Padding(
 padding: const pw.EdgeInsets.all(6),
 child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
 );
 }

 List<LaunchScopeItem> _mapToScopeItems(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((m) => LaunchScopeItem(
 deliverable: (m['title'] ?? '').toString().trim(),
 acceptanceCriteria: (m['details'] ?? '').toString().trim(),
 status: _normalizeStatus(m['status'], 'Pending'),
 ))
 .where((i) => i.deliverable.isNotEmpty)
 .toList();
 }

 List<LaunchMilestone> _mapToMilestones(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((m) => LaunchMilestone(
 title: (m['title'] ?? '').toString().trim(),
 status: _normalizeStatus(m['status'], 'Pending'),
 ))
 .where((i) => i.title.isNotEmpty)
 .toList();
 }

 List<LaunchFollowUpItem> _mapToFollowUps(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((m) => LaunchFollowUpItem(
 title: (m['title'] ?? '').toString().trim(),
 details: (m['details'] ?? '').toString().trim(),
 status: _normalizeStatus(m['status'], 'Open'),
 ))
 .where((i) => i.title.isNotEmpty)
 .toList();
 }

 String _normalizeStatus(dynamic value, String fallback) {
 final s = (value ?? '').toString().trim();
 return s.isEmpty ? fallback : s;
 }
}


// ═══════════════════════════════════════════════════════════════════════════
// _ScopeEditDialog — modal for editing a Scope Acceptance row
// ═══════════════════════════════════════════════════════════════════════════
// Pre-fills the dialog with existing values and returns a Map with the
// updated values when the user clicks "Save Changes". Includes KAZ AI
// buttons on text fields for AI-powered content generation.

class _ScopeEditDialog extends StatefulWidget {
 final String deliverable;
 final String criteria;
 final String status;
 final String date;

 const _ScopeEditDialog({
 required this.deliverable,
 required this.criteria,
 required this.status,
 required this.date,
 });

 @override
 State<_ScopeEditDialog> createState() => _ScopeEditDialogState();
}

class _ScopeEditDialogState extends State<_ScopeEditDialog> {
 late final TextEditingController _deliverableCtrl;
 late final TextEditingController _criteriaCtrl;
 late final TextEditingController _dateCtrl;
 late String _status;
 final _formKey = GlobalKey<FormState>();
 final _kazAiLoading = <String, bool>{};

 @override
 void initState() {
 super.initState();
 _deliverableCtrl = TextEditingController(text: widget.deliverable);
 _criteriaCtrl = TextEditingController(text: widget.criteria);
 _dateCtrl = TextEditingController(text: widget.date);
 _status = widget.status;
 }

 @override
 void dispose() {
 _deliverableCtrl.dispose();
 _criteriaCtrl.dispose();
 _dateCtrl.dispose();
 super.dispose();
 }

 Future<void> _generateFieldWithAi(String field, TextEditingController controller) async {
 setState(() => _kazAiLoading[field] = true);
 try {
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Suggest a concise value for the "$field" field in a '
 'Scope Acceptance table entry for a project management application. '
 'Return ONLY the text value (no JSON, no markdown).',
 maxTokens: 100,
 temperature: 0.6,
 );
 final cleaned = result.trim();
 if (cleaned.isNotEmpty) {
 controller.text = cleaned;
 if (mounted) setState(() {});
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('KAZ AI failed: $e')),
 );
 }
 }
 if (mounted) setState(() => _kazAiLoading[field] = false);
 }

 InputDecoration _inputDecoration(String hint, TextEditingController controller, String field) {
 return InputDecoration(
 hintText: hint,
 hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
 filled: true,
 fillColor: const Color(0xFFF9FAFB),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
 ),
 contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 suffixIcon: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 // KAZ AI button
 IconButton(
 tooltip: 'KAZ AI',
 icon: _kazAiLoading[field] == true
 ? const SizedBox(
 width: 14, height: 14,
 child: CircularProgressIndicator(strokeWidth: 2))
 : const Icon(Icons.auto_awesome,
 color: Color(0xFFF59E0B), size: 16),
 onPressed: _kazAiLoading[field] == true
 ? null
 : () => _generateFieldWithAi(field, controller),
 padding: const EdgeInsets.all(4),
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 // Clear-all button
 if (controller.text.isNotEmpty)
 IconButton(
 tooltip: 'Clear all content',
 icon: const Icon(Icons.delete_sweep,
 color: Color(0xFFEF4444), size: 16),
 onPressed: () {
 controller.clear();
 setState(() {});
 },
 padding: const EdgeInsets.all(4),
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 ],
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return Dialog(
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 520),
 child: Padding(
 padding: const EdgeInsets.all(28),
 child: Form(
 key: _formKey,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // ── Header ────────────────────────────────────────────
 Row(
 children: [
 Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: const Color(0xFFFEF3C7),
 borderRadius: BorderRadius.circular(12),
 ),
 child: const Icon(Icons.edit_note_rounded,
 color: Color(0xFFD97706), size: 22),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Edit Scope Acceptance',
 style: TextStyle(
 fontSize: 18, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 2),
 Text(
 'Update the deliverable details below.',
 style: TextStyle(
 fontSize: 12.5, color: Colors.grey[600]),
 ),
 ],
 ),
 ),
 IconButton(
 icon: const Icon(Icons.close, size: 20),
 onPressed: () => Navigator.of(context).pop(),
 ),
 ],
 ),
 const SizedBox(height: 24),

 // ── Deliverable field ─────────────────────────────────
 const Text('Deliverable *',
 style:
 TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
 const SizedBox(height: 4),
 VoiceTextField(
 controller: _deliverableCtrl,
 style: const TextStyle(fontSize: 13, color: Color(0xFF1A1D1F)),
 decoration: _inputDecoration(
 'Deliverable name', _deliverableCtrl, 'Deliverable'),
 onChanged: (_) => setState(() {}),
 ),
 const SizedBox(height: 14),

 // ── Criteria field ────────────────────────────────────
 const Text('Criteria *',
 style:
 TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
 const SizedBox(height: 4),
 VoiceTextField(
 controller: _criteriaCtrl,
 minLines: 2,
 maxLines: 4,
 style: const TextStyle(fontSize: 13, color: Color(0xFF1A1D1F)),
 decoration:
 _inputDecoration('Acceptance criteria', _criteriaCtrl, 'Criteria'),
 onChanged: (_) => setState(() {}),
 ),
 const SizedBox(height: 14),

 // ── Status + Date row ─────────────────────────────────
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Status',
 style: TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600)),
 const SizedBox(height: 4),
 DropdownButtonFormField<String>(
 value: _status,
 decoration: InputDecoration(
 filled: true,
 fillColor: const Color(0xFFF9FAFB),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide:
 const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 14, vertical: 12),
 ),
 items: const ['Pending', 'Accepted', 'Partial', 'Rejected']
 .map((s) => DropdownMenuItem(
 value: s, child: Text(s)))
 .toList(),
 onChanged: (v) {
 if (v != null) setState(() => _status = v);
 },
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Date',
 style: TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600)),
 const SizedBox(height: 4),
 VoiceTextField(
 controller: _dateCtrl,
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF1A1D1F)),
 decoration: _inputDecoration(
 'YYYY-MM-DD', _dateCtrl, 'Date'),
 onChanged: (_) => setState(() {}),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 28),

 // ── Action buttons ────────────────────────────────────
 Row(
 mainAxisAlignment: MainAxisAlignment.end,
 children: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel',
 style: TextStyle(color: Color(0xFF6B7280))),
 ),
 const SizedBox(width: 12),
 ElevatedButton.icon(
 onPressed: () {
 Navigator.of(context).pop({
 'Deliverable': _deliverableCtrl.text.trim(),
 'Criteria': _criteriaCtrl.text.trim(),
 'Status': _status,
 'Date': _dateCtrl.text.trim(),
 });
 },
 icon: const Icon(Icons.check_circle_outline, size: 18),
 label: const Text('Save Changes'),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFD97706),
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10)),
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }

}
