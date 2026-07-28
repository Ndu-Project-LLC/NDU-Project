import 'package:ndu_project/widgets/launch_notes_section.dart';
import 'package:ndu_project/widgets/launch_insights_widgets.dart';
import 'package:ndu_project/widgets/launch_notes_section.dart';
import 'dart:convert';
import 'package:ndu_project/utils/download_helper_stub.dart'
 if (dart.library.html) 'package:ndu_project/utils/download_helper_web.dart' as loader;
import 'package:flutter/material.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:ndu_project/models/launch_phase_models.dart';
import 'package:ndu_project/screens/contract_close_out_screen.dart';
import 'package:ndu_project/screens/deliver_project_closure_screen.dart';
import 'package:ndu_project/screens/fat_mechanical_completion_screen.dart';
import 'package:ndu_project/services/launch_phase_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/launch_phase_ai_seed.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';

class TransitionToProdTeamScreen extends StatefulWidget {
 const TransitionToProdTeamScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const TransitionToProdTeamScreen()),
 );
 }

 @override
 State<TransitionToProdTeamScreen> createState() =>
 _TransitionToProdTeamScreenState();
}

class _TransitionToProdTeamScreenState extends State<TransitionToProdTeamScreen> {
  final TextEditingController _notesController = TextEditingController();
 List<LaunchTeamMember> _teamRoster = [];
 List<LaunchHandoverItem> _handoverChecklist = [];
 List<LaunchKnowledgeTransfer> _knowledgeTransfers = [];
 List<LaunchApproval> _signOffs = [];

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
 activeItemLabel: '2. Deployment Transfer, Certification & Release',
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
 title: 'Deployment Transfer, Certification & Release',
showNavigationButtons: false,
 showActivityLogAction: false,
 onExportPdf: _exportPdf,
 showAiAssist: true,
 onAiAssist: _isGenerating ? null : _populateFromAi,
 ),
 const SizedBox(height: 12),
            _buildLaunchInsights(),
            const SizedBox(height: 16),
 _buildMetricsRow(),
 const SizedBox(height: 16),
            LaunchNotesSection(
              controller: _notesController,
              onChanged: (v) {},
            ),
            const SizedBox(height: 20),
 _buildTeamRosterPanel(),
 const SizedBox(height: 16),
 _buildHandoverChecklistPanel(),
 const SizedBox(height: 16),
 _buildKnowledgeTransferPanel(),
 const SizedBox(height: 16),
 _buildSignOffsPanel(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Launch Readiness Assessment',
 nextLabel: 'Next: FAT, Mechanical Completion & Commission Solution',
 onBack: () => DeliverProjectClosureScreen.open(context),
 onNext: () => FatMechanicalCompletionScreen.open(context),
 ),
 const SizedBox(height: 48),
 ],
 ),
 ),
 );
 }



 Widget _buildMetricsRow() {
 final active = _teamRoster.where((m) => m.releaseStatus == 'Active').length;
 final pendingHandover =
 _handoverChecklist.where((h) => h.status == 'Pending').length;
 final pendingKt =
 _knowledgeTransfers.where((k) => k.status == 'Pending').length;
 final pendingSignOff = _signOffs.where((s) => s.status == 'Pending').length;

 return ExecutionMetricsGrid(
 metrics: [
 ExecutionMetricData(
 label: 'Team Members',
 value: '${_teamRoster.length}',
 icon: Icons.people_outline,
 emphasisColor: const Color(0xFFD97706),
 helper: '$active active',
 ),
 ExecutionMetricData(
 label: 'Handover Items',
 value: '${_handoverChecklist.length}',
 icon: Icons.swap_horiz,
 emphasisColor: const Color(0xFF8B5CF6),
 helper: '$pendingHandover pending',
 ),
 ExecutionMetricData(
 label: 'Knowledge Transfers',
 value: '${_knowledgeTransfers.length}',
 icon: Icons.school_outlined,
 emphasisColor: const Color(0xFFF59E0B),
 helper: '$pendingKt pending',
 ),
 ExecutionMetricData(
 label: 'Sign-Offs',
 value: '$pendingSignOff',
 icon: Icons.assignment_turned_in_outlined,
 emphasisColor: pendingSignOff > 0
 ? const Color(0xFFEF4444)
 : const Color(0xFF10B981),
 ),
 ],
 );
 }

 Widget _buildTeamRosterPanel() {
 return LaunchDataTable(
 title: 'Production Team Roster',
 subtitle: 'Members receiving the handover from the project team.',
 columns: const [LaunchColumn(label: 'Name', flexible: true, fieldType: LaunchFieldType.text, hint: 'Name'), LaunchColumn(label: 'Role', width: 120, fieldType: LaunchFieldType.text, hint: 'Role'), LaunchColumn(label: 'Contact', width: 120, fieldType: LaunchFieldType.text, hint: 'Contact'), LaunchColumn(label: 'Start Date', width: 130, fieldType: LaunchFieldType.date, hint: 'Start'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Active', 'Transitioning', 'Released'])],
 rowCount: _teamRoster.length,
 onAddValues: (values) {
 setState(() {
 _teamRoster.add(LaunchTeamMember(
 name: values['Name'] ?? '',
 role: values['Role'] ?? '',
 contact: values['Contact'] ?? '',
 startDate: values['Start Date'] ?? '',
 releaseStatus: values['Status'] ?? 'Active',
 ));
 });
 _scheduleSave();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'name', label: 'Name', sampleValue: 'John Doe'),
 CsvColumnSpec(key: 'role', label: 'Role', sampleValue: 'System Admin'),
 CsvColumnSpec(key: 'contact', label: 'Contact', sampleValue: 'john@example.com'),
 CsvColumnSpec(key: 'startDate', label: 'Start Date', sampleValue: '2025-01-15'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Active', allowedValues: ['Active', 'Transitioning', 'Released']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _teamRoster.add(LaunchTeamMember(
 name: row['name'] ?? '',
 role: row['role'] ?? '',
 contact: row['contact'] ?? '',
 startDate: row['startDate'] ?? '',
 releaseStatus: row['status'] ?? 'Active',
 ));
 });
 }
 _scheduleSave();
 },

 emptyMessage:
 'No team members yet. Add production team members or import from staffing.',
 cellBuilder: (context, idx) {
 final item = _teamRoster[idx];
 return LaunchDataRow(
 onEdit: () => _scheduleSave(),
 onDelete: () => _deleteTeamMember(idx),
 onKazAi: () => _regenerateTeamRosterRow(idx),
 cells: [
 LaunchEditableCell(
 value: item.name,
 hint: 'Name',
 bold: true,
 expand: true,
 onChanged: (v) {
 _teamRoster[idx] = item.copyWith(name: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.role,
 hint: 'Role',
 expand: true,
 onChanged: (v) {
 _teamRoster[idx] = item.copyWith(role: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.contact,
 hint: 'Contact',
 expand: true,
 onChanged: (v) {
 _teamRoster[idx] = item.copyWith(contact: v);
 _scheduleSave();
 },
 ),
 LaunchDateCell(
 value: item.startDate,
 hint: 'Start',
 onChanged: (v) {
 _teamRoster[idx] = item.copyWith(startDate: v);
 _scheduleSave();
 },
 ),
 LaunchStatusDropdown(
 value: item.releaseStatus,
 items: const ['Active', 'Transitioning', 'Released'],
 onChanged: (v) {
 if (v == null) return;
 _teamRoster[idx] = item.copyWith(releaseStatus: v);
 _scheduleSave();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildHandoverChecklistPanel() {
 return LaunchDataTable(
 title: 'Handover Checklist',
 subtitle:
 'Structured items to transfer to production: docs, access, monitoring, training, runbooks.',
 columns: const [LaunchColumn(label: 'Category', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: LaunchHandoverItem.categories), LaunchColumn(label: 'Item', flexible: true, fieldType: LaunchFieldType.text, hint: 'Item'), LaunchColumn(label: 'Owner', width: 120, fieldType: LaunchFieldType.text, hint: 'Owner'), LaunchColumn(label: 'Due', width: 130, fieldType: LaunchFieldType.date, hint: 'Due'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Pending', 'In Progress', 'Complete'])],
 rowCount: _handoverChecklist.length,
 onAddValues: (values) {
 setState(() {
 _handoverChecklist.add(LaunchHandoverItem(
 category: values['Category'] ?? 'Documentation',
 item: values['Item'] ?? '',
 owner: values['Owner'] ?? '',
 dueDate: values['Due'] ?? '',
 status: values['Status'] ?? 'Pending',
 ));
 });
 _scheduleSave();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'category', label: 'Category', sampleValue: 'Documentation', allowedValues: LaunchHandoverItem.categories),
 CsvColumnSpec(key: 'item', label: 'Item', sampleValue: 'Handover runbook'),
 CsvColumnSpec(key: 'owner', label: 'Owner', sampleValue: 'Jane Smith'),
 CsvColumnSpec(key: 'due', label: 'Due', sampleValue: '2025-02-01'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Pending', allowedValues: ['Pending', 'In Progress', 'Complete']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _handoverChecklist.add(LaunchHandoverItem(
 category: row['category'] ?? 'Documentation',
 item: row['item'] ?? '',
 owner: row['owner'] ?? '',
 dueDate: row['due'] ?? '',
 status: row['status'] ?? 'Pending',
 ));
 });
 }
 _scheduleSave();
 },
 emptyMessage:
 'No handover items. Add items to track the production handover.',
 cellBuilder: (context, idx) {
 final item = _handoverChecklist[idx];
 return LaunchDataRow(
 onEdit: () => _scheduleSave(),
 onDelete: () => _deleteHandoverItem(idx),
 onKazAi: () => _regenerateHandoverRow(idx),
 cells: [
 LaunchStatusDropdown(
 value: item.category,
 items: LaunchHandoverItem.categories,
 onChanged: (v) {
 if (v == null) return;
 _handoverChecklist[idx] = item.copyWith(category: v);
 _scheduleSave();
 setState(() {});
 },
 ),
 LaunchEditableCell(
 value: item.item,
 hint: 'Item',
 bold: true,
 expand: true,
 onChanged: (v) {
 _handoverChecklist[idx] = item.copyWith(item: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.owner,
 hint: 'Owner',
 expand: true,
 onChanged: (v) {
 _handoverChecklist[idx] = item.copyWith(owner: v);
 _scheduleSave();
 },
 ),
 LaunchDateCell(
 value: item.dueDate,
 hint: 'Due',
 onChanged: (v) {
 _handoverChecklist[idx] = item.copyWith(dueDate: v);
 _scheduleSave();
 },
 ),
 LaunchStatusDropdown(
 value: item.status,
 items: const ['Pending', 'In Progress', 'Complete'],
 onChanged: (v) {
 if (v == null) return;
 _handoverChecklist[idx] = item.copyWith(status: v);
 _scheduleSave();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildKnowledgeTransferPanel() {
 return LaunchDataTable(
 title: 'Knowledge Transfer',
 subtitle: 'Track sessions, artifacts, and owners for knowledge capture.',
 columns: const [LaunchColumn(label: 'Topic', flexible: true, fieldType: LaunchFieldType.text, hint: 'Topic'), LaunchColumn(label: 'From', width: 130, fieldType: LaunchFieldType.text, hint: 'From'), LaunchColumn(label: 'To', width: 130, fieldType: LaunchFieldType.text, hint: 'To'), LaunchColumn(label: 'Method', width: 130, fieldType: LaunchFieldType.text, hint: 'Method'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Pending', 'Scheduled', 'Complete'])],
 rowCount: _knowledgeTransfers.length,
 onAddValues: (values) {
 setState(() {
 _knowledgeTransfers.add(LaunchKnowledgeTransfer(
 topic: values['Topic'] ?? '',
 fromPerson: values['From'] ?? '',
 toPerson: values['To'] ?? '',
 method: values['Method'] ?? '',
 status: values['Status'] ?? 'Pending',
 ));
 });
 _scheduleSave();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'topic', label: 'Topic', sampleValue: 'Deployment Process'),
 CsvColumnSpec(key: 'from', label: 'From', sampleValue: 'Alice Brown'),
 CsvColumnSpec(key: 'to', label: 'To', sampleValue: 'Bob Chen'),
 CsvColumnSpec(key: 'method', label: 'Method', sampleValue: 'Walkthrough'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Pending', allowedValues: ['Pending', 'Scheduled', 'Complete']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _knowledgeTransfers.add(LaunchKnowledgeTransfer(
 topic: row['topic'] ?? '',
 fromPerson: row['from'] ?? '',
 toPerson: row['to'] ?? '',
 method: row['method'] ?? '',
 status: row['status'] ?? 'Pending',
 ));
 });
 }
 _scheduleSave();
 },
 emptyMessage:
 'No knowledge transfers. Track knowledge handoff from project team to operations.',
 cellBuilder: (context, idx) {
 final item = _knowledgeTransfers[idx];
 return LaunchDataRow(
 onEdit: () => _scheduleSave(),
 onDelete: () => _deleteKnowledgeTransfer(idx),
 onKazAi: () => _regenerateKnowledgeTransferRow(idx),
 cells: [
 LaunchEditableCell(
 value: item.topic,
 hint: 'Topic',
 bold: true,
 expand: true,
 onChanged: (v) {
 _knowledgeTransfers[idx] = item.copyWith(topic: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.fromPerson,
 hint: 'From',
 expand: true,
 onChanged: (v) {
 _knowledgeTransfers[idx] = item.copyWith(fromPerson: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.toPerson,
 hint: 'To',
 expand: true,
 onChanged: (v) {
 _knowledgeTransfers[idx] = item.copyWith(toPerson: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.method,
 hint: 'Method',
 expand: true,
 onChanged: (v) {
 _knowledgeTransfers[idx] = item.copyWith(method: v);
 _scheduleSave();
 },
 ),
 LaunchStatusDropdown(
 value: item.status,
 items: const ['Pending', 'Scheduled', 'Complete'],
 onChanged: (v) {
 if (v == null) return;
 _knowledgeTransfers[idx] = item.copyWith(status: v);
 _scheduleSave();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildSignOffsPanel() {
 return LaunchDataTable(
 title: 'Ops & Client Sign-Offs',
 subtitle: 'Track who needs to approve the handover and their status.',
 columns: const [LaunchColumn(label: 'Stakeholder', flexible: true, fieldType: LaunchFieldType.text, hint: 'Name'), LaunchColumn(label: 'Role', width: 120, fieldType: LaunchFieldType.text, hint: 'Role'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Pending', 'Approved', 'Rejected']), LaunchColumn(label: 'Date', width: 130, fieldType: LaunchFieldType.date, hint: 'Date'), LaunchColumn(label: 'Notes', flexible: true, fieldType: LaunchFieldType.text, hint: 'Notes')],
 rowCount: _signOffs.length,
 onAddValues: (values) {
 setState(() {
 _signOffs.add(LaunchApproval(
 stakeholder: values['Stakeholder'] ?? '',
 role: values['Role'] ?? '',
 status: values['Status'] ?? 'Pending',
 date: values['Date'] ?? '',
 notes: values['Notes'] ?? '',
 ));
 });
 _scheduleSave();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'stakeholder', label: 'Stakeholder', sampleValue: 'Jane Smith'),
 CsvColumnSpec(key: 'role', label: 'Role', sampleValue: 'Operations Director'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Pending', allowedValues: ['Pending', 'Approved', 'Rejected']),
 CsvColumnSpec(key: 'date', label: 'Date', sampleValue: '2025-01-20'),
 CsvColumnSpec(key: 'notes', label: 'Notes', sampleValue: 'Waiting for review'),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _signOffs.add(LaunchApproval(
 stakeholder: row['stakeholder'] ?? '',
 role: row['role'] ?? '',
 status: row['status'] ?? 'Pending',
 date: row['date'] ?? '',
 notes: row['notes'] ?? '',
 ));
 });
 }
 _scheduleSave();
 },
 emptyMessage:
 'No sign-offs yet. Capture who needs to approve the handover.',
 cellBuilder: (context, idx) {
 final item = _signOffs[idx];
 return LaunchDataRow(
 onEdit: () => _scheduleSave(),
 onDelete: () => _deleteApproval(idx),
 onKazAi: () => _regenerateSignOffRow(idx),
 cells: [
 LaunchEditableCell(
 value: item.stakeholder,
 hint: 'Name',
 bold: true,
 expand: true,
 onChanged: (v) {
 _signOffs[idx] = item.copyWith(stakeholder: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.role,
 hint: 'Role',
 expand: true,
 onChanged: (v) {
 _signOffs[idx] = item.copyWith(role: v);
 _scheduleSave();
 },
 ),
 LaunchStatusDropdown(
 value: item.status,
 items: const ['Pending', 'Approved', 'Rejected'],
 onChanged: (v) {
 if (v == null) return;
 _signOffs[idx] = item.copyWith(status: v);
 _scheduleSave();
 setState(() {});
 },
 ),
 LaunchDateCell(
 value: item.date,
 hint: 'Date',
 onChanged: (v) {
 _signOffs[idx] = item.copyWith(date: v);
 _scheduleSave();
 },
 ),
 LaunchEditableCell(
 value: item.notes,
 hint: 'Notes',
 expand: true,
 onChanged: (v) {
 _signOffs[idx] = item.copyWith(notes: v);
 _scheduleSave();
 },
 ),
 ],
 );
 },
 );
 }

 Future<void> _deleteTeamMember(int idx) async {
 final name = _teamRoster[idx].name.isNotEmpty
 ? _teamRoster[idx].name
 : 'team member';
 final confirmed = await launchConfirmDelete(context, itemName: name);
 if (!confirmed) return;
 setState(() => _teamRoster.removeAt(idx));
 _scheduleSave();
 }

 Future<void> _deleteHandoverItem(int idx) async {
 final label = _handoverChecklist[idx].item.isNotEmpty
 ? _handoverChecklist[idx].item
 : 'handover item';
 final confirmed = await launchConfirmDelete(context, itemName: label);
 if (!confirmed) return;
 setState(() => _handoverChecklist.removeAt(idx));
 _scheduleSave();
 }

 Future<void> _deleteKnowledgeTransfer(int idx) async {
 final topic = _knowledgeTransfers[idx].topic.isNotEmpty
 ? _knowledgeTransfers[idx].topic
 : 'knowledge transfer';
 final confirmed = await launchConfirmDelete(context, itemName: topic);
 if (!confirmed) return;
 setState(() => _knowledgeTransfers.removeAt(idx));
 _scheduleSave();
 }

 Future<void> _deleteApproval(int idx) async {
 final who = _signOffs[idx].stakeholder.isNotEmpty
 ? _signOffs[idx].stakeholder
 : 'sign-off';
 final confirmed = await launchConfirmDelete(context, itemName: who);
 if (!confirmed) return;
 setState(() => _signOffs.removeAt(idx));
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
 await LaunchPhaseService.loadTransitionToProd(projectId: _projectId!);
 if (!mounted) return;
 setState(() {
 _teamRoster = result.teamRoster;
 _handoverChecklist = result.handoverChecklist;
 _knowledgeTransfers = result.knowledgeTransfers;
 _signOffs = result.signOffs;
 _isLoading = false;
 _hasLoaded = true;
 });

 final allEmpty = _teamRoster.isEmpty &&
 _handoverChecklist.isEmpty &&
 _knowledgeTransfers.isEmpty &&
 _signOffs.isEmpty;
 if (allEmpty) {
 await _autoPopulateFromPriorPhases();
 }

 final stillEmpty = _teamRoster.isEmpty &&
 _handoverChecklist.isEmpty &&
 _knowledgeTransfers.isEmpty &&
 _signOffs.isEmpty;
 if (stillEmpty) await _populateFromAi();
 } catch (e) {
 debugPrint('Transition load error: $e');
 if (mounted) setState(() => _isLoading = false);
 }
 _suspendSave = false;
 }

 Future<void> _autoPopulateFromPriorPhases() async {
 if (_projectId == null) return;
 try {
 final cp = await LaunchPhaseAiSeed.loadCrossPhaseData(_projectId!);
 if (!mounted) return;

 // Pre-fill team roster from staffing
 if (_teamRoster.isEmpty && cp.staffing.isNotEmpty) {
 final existing = _teamRoster.map((m) => m.name).toSet();
 final newMembers = cp.staffing
 .where((m) => !existing.contains(m.name))
 .toList();
 if (newMembers.isNotEmpty) {
 setState(() => _teamRoster.addAll(newMembers));
 }
 }

 // Pre-fill sign-offs from stakeholders
 if (_signOffs.isEmpty && cp.stakeholders.isNotEmpty) {
 final newSignOffs = cp.stakeholders
 .map((s) => LaunchApproval(
 stakeholder: s['name'] ?? s['title'] ?? '',
 role: s['role'] ?? '',
 status: 'Pending',
 ))
 .where((s) => s.stakeholder.isNotEmpty)
 .toList();
 if (newSignOffs.isNotEmpty) {
 setState(() => _signOffs.addAll(newSignOffs));
 }
 }

 // Pre-fill handover items from deliverable rows
 if (_handoverChecklist.isEmpty && cp.deliverableRows.isNotEmpty) {
 final newHandover = cp.deliverableRows
 .map((d) => LaunchHandoverItem(
 category: 'Documentation',
 item: 'Handover: ${d['title'] ?? 'Untitled'}',
 status: d['status']?.toString().toLowerCase() == 'completed' ? 'Complete' : 'Pending',
 ))
 .where((h) => h.item.isNotEmpty)
 .toList();
 if (newHandover.isNotEmpty) {
 setState(() => _handoverChecklist.addAll(newHandover));
 }
 }

 // Pre-fill knowledge transfer from staffing roles
 if (_knowledgeTransfers.isEmpty && cp.staffing.isNotEmpty) {
 final newKt = cp.staffing
 .where((m) => m.name.isNotEmpty && m.role.isNotEmpty)
 .take(5)
 .map((m) => LaunchKnowledgeTransfer(
 topic: '${m.role} knowledge handover',
 fromPerson: m.name,
 status: 'Pending',
 ))
 .toList();
 if (newKt.isNotEmpty) {
 setState(() => _knowledgeTransfers.addAll(newKt));
 }
 }

 final hasNewData = _teamRoster.isNotEmpty ||
 _handoverChecklist.isNotEmpty ||
 _knowledgeTransfers.isNotEmpty ||
 _signOffs.isNotEmpty;
 if (hasNewData) await _persistData();
 } catch (e) {
 debugPrint('Transition auto-populate error: $e');
 }
 }

 Future<void> _persistData() async {
 if (_projectId == null) return;
 try {
 await LaunchPhaseService.saveTransitionToProd(
 projectId: _projectId!,
 teamRoster: _teamRoster,
 handoverChecklist: _handoverChecklist,
 knowledgeTransfers: _knowledgeTransfers,
 signOffs: _signOffs,
 );
 } catch (e) {
 debugPrint('Transition save error: $e');
 }
 }

 Future<void> _populateFromAi() async {
 if (_isGenerating) return;

 setState(() => _isGenerating = true);
 LaunchAiResult? result;
 try {
 result = await LaunchPhaseAiSeed.generateEntries(
 context: context,
 sectionLabel: 'Transition to Production Team',
 sections: const {
 'team_roster': 'Production team members with "name", "role", "contact", "release_status"',
 'handover_checklist':
 'Handover items with "category", "item", "owner", "due_date", "status"',
 'knowledge_transfer':
 'Knowledge transfer topics with "topic", "from_person", "to_person", "method", "status"',
 'signoffs': 'Sign-off approvers with "stakeholder", "role", "status"',
 },
 itemsPerSection: 3,
 );
 } catch (e) {
 debugPrint('Transition AI error: $e');
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

 final hasExisting = _teamRoster.isNotEmpty ||
 _handoverChecklist.isNotEmpty ||
 _knowledgeTransfers.isNotEmpty ||
 _signOffs.isNotEmpty;
 if (hasExisting) {
 setState(() => _isGenerating = false);
 return;
 }

 setState(() {
 _teamRoster = _mapMembers(generated['team_roster']);
 _handoverChecklist = _mapHandoverItems(generated['handover_checklist']);
 _knowledgeTransfers = _mapKT(generated['knowledge_transfer']);
 _signOffs = _mapApprovals(generated['signoffs']);
 _isGenerating = false;
 });
 await _persistData();
 }

 Future<void> _exportPdf() async {
 setState(() => _isExporting = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final projectName = projectData.projectName ?? 'Project';
 final now = DateTime.now();
 final stamp =
 '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
 final filename = 'transition_to_prod_${projectName.replaceAll(' ', '_')}_$stamp.pdf';

 final doc = pw.Document();

 doc.addPage(
 pw.MultiPage(
 pageFormat: PdfPageFormat.a4,
 margin: const pw.EdgeInsets.all(32),
 build: (_) => [
 pw.Text('Transition to Production Team', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
 pw.SizedBox(height: 4),
 pw.Text('$projectName — Generated ${now.toLocal().toIso8601String()}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
 pw.SizedBox(height: 16),

 // Team Roster
 _pdfSectionTitle('Production Team Roster'),
 pw.SizedBox(height: 6),
 if (_teamRoster.isEmpty)
 _pdfCell('No team members recorded.')
 else
 pw.Table.fromTextArray(
 headers: ['Name', 'Role', 'Contact', 'Status'],
 data: _teamRoster.map((m) => [m.name, m.role, m.contact, m.releaseStatus]).toList(),
 headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 cellStyle: const pw.TextStyle(fontSize: 9),
 headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
 cellPadding: const pw.EdgeInsets.all(6),
 ),
 pw.SizedBox(height: 14),

 // Handover Checklist
 _pdfSectionTitle('Handover Checklist'),
 pw.SizedBox(height: 6),
 if (_handoverChecklist.isEmpty)
 _pdfCell('No handover items recorded.')
 else
 pw.Table.fromTextArray(
 headers: ['Category', 'Item', 'Owner', 'Status'],
 data: _handoverChecklist.map((h) => [h.category, h.item, h.owner, h.status]).toList(),
 headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 cellStyle: const pw.TextStyle(fontSize: 9),
 headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
 cellPadding: const pw.EdgeInsets.all(6),
 ),
 pw.SizedBox(height: 14),

 // Knowledge Transfers
 _pdfSectionTitle('Knowledge Transfer'),
 pw.SizedBox(height: 6),
 if (_knowledgeTransfers.isEmpty)
 _pdfCell('No knowledge transfers recorded.')
 else
 pw.Table.fromTextArray(
 headers: ['Topic', 'From', 'To', 'Method', 'Status'],
 data: _knowledgeTransfers.map((k) => [k.topic, k.fromPerson, k.toPerson, k.method, k.status]).toList(),
 headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 cellStyle: const pw.TextStyle(fontSize: 9),
 headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
 cellPadding: const pw.EdgeInsets.all(6),
 ),
 pw.SizedBox(height: 14),

 // Sign-Offs
 _pdfSectionTitle('Ops & Client Sign-Offs'),
 pw.SizedBox(height: 6),
 if (_signOffs.isEmpty)
 _pdfCell('No sign-offs recorded.')
 else
 pw.Table.fromTextArray(
 headers: ['Stakeholder', 'Role', 'Status'],
 data: _signOffs.map((s) => [s.stakeholder, s.role, s.status]).toList(),
 headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 cellStyle: const pw.TextStyle(fontSize: 9),
 headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
 cellPadding: const pw.EdgeInsets.all(6),
 ),
 ],
 ),
 );

 final bytes = await doc.save();
 if (!mounted) return;
 loader.downloadFile(bytes, filename, mimeType: 'application/pdf');
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF export failed: ${e.toString()}')));
 }
 } finally {
 if (mounted) setState(() => _isExporting = false);
 }
 }

 pw.Widget _pdfSectionTitle(String title) {
 return pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold));
 }

 pw.Widget _pdfHeaderCell(String text) {
 return pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)));
 }

 pw.Widget _pdfCell(String text) {
 return pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)));
 }

 // ── KAZ AI Row Regeneration ─────────────────────────────────────────────

 Future<void> _regenerateTeamRosterRow(int index) async {
 if (index < 0 || index >= _teamRoster.length) return;
 final key = 'team_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Production Team Roster');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a production team member name, role, and contact for a handover roster.\n\nContext:\n$ctx\n\nCurrent: ${_teamRoster[index].name} / ${_teamRoster[index].role}\n\nReturn ONLY a valid JSON object with keys: "name", "role", "contact", "status". Status must be Active, Transitioning, or Released.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _teamRoster[index] = _teamRoster[index].copyWith(
 name: (parsed['name'] ?? '').toString(),
 role: (parsed['role'] ?? '').toString(),
 contact: (parsed['contact'] ?? '').toString(),
 releaseStatus: (parsed['status'] ?? _teamRoster[index].releaseStatus).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 Future<void> _regenerateHandoverRow(int index) async {
 if (index < 0 || index >= _handoverChecklist.length) return;
 final key = 'handover_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Handover Checklist');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a handover checklist item with category, item description, and owner.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "category", "item", "owner", "status". Status must be Pending, In Progress, or Complete.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _handoverChecklist[index] = _handoverChecklist[index].copyWith(
 category: (parsed['category'] ?? _handoverChecklist[index].category).toString(),
 item: (parsed['item'] ?? '').toString(),
 owner: (parsed['owner'] ?? _handoverChecklist[index].owner).toString(),
 status: (parsed['status'] ?? _handoverChecklist[index].status).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 Future<void> _regenerateKnowledgeTransferRow(int index) async {
 if (index < 0 || index >= _knowledgeTransfers.length) return;
 final key = 'kt_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Knowledge Transfer');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a knowledge transfer topic, from/to persons, and method.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "topic", "from", "to", "method", "status". Status must be Pending, Scheduled, or Complete.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _knowledgeTransfers[index] = _knowledgeTransfers[index].copyWith(
 topic: (parsed['topic'] ?? '').toString(),
 fromPerson: (parsed['from'] ?? _knowledgeTransfers[index].fromPerson).toString(),
 toPerson: (parsed['to'] ?? _knowledgeTransfers[index].toPerson).toString(),
 method: (parsed['method'] ?? _knowledgeTransfers[index].method).toString(),
 status: (parsed['status'] ?? _knowledgeTransfers[index].status).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 Future<void> _regenerateSignOffRow(int index) async {
 if (index < 0 || index >= _signOffs.length) return;
 final key = 'signoff_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Ops & Client Sign-Offs');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a sign-off approver name, role, and status.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "stakeholder", "role", "status", "notes". Status must be Pending, Approved, or Rejected.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _signOffs[index] = _signOffs[index].copyWith(
 stakeholder: (parsed['stakeholder'] ?? '').toString(),
 role: (parsed['role'] ?? _signOffs[index].role).toString(),
 status: (parsed['status'] ?? _signOffs[index].status).toString(),
 notes: (parsed['notes'] ?? _signOffs[index].notes).toString(),
 );
 });
 _scheduleSave();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 List<LaunchTeamMember> _mapMembers(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((m) {
 final title = (m['title'] ?? '').toString().trim();
 final details = (m['details'] ?? '').toString().trim();
 return LaunchTeamMember(
 name: title, role: details.isNotEmpty ? details : 'Team Member');
 })
 .where((i) => i.name.isNotEmpty)
 .toList();
 }

 List<LaunchHandoverItem> _mapHandoverItems(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((m) {
 return LaunchHandoverItem(
 item: (m['title'] ?? '').toString().trim(),
 owner: (m['details'] ?? '').toString().trim(),
 status: _norm(m['status'], 'Pending'),
 );
 })
 .where((i) => i.item.isNotEmpty)
 .toList();
 }

 List<LaunchKnowledgeTransfer> _mapKT(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((m) {
 return LaunchKnowledgeTransfer(
 topic: (m['title'] ?? '').toString().trim(),
 status: _norm(m['status'], 'Pending'),
 );
 })
 .where((i) => i.topic.isNotEmpty)
 .toList();
 }

 List<LaunchApproval> _mapApprovals(List<Map<String, dynamic>>? raw) {
 if (raw == null) return [];
 return raw
 .map((m) {
 return LaunchApproval(
 stakeholder: (m['title'] ?? '').toString().trim(),
 role: (m['details'] ?? '').toString().trim(),
 status: _norm(m['status'], 'Pending'),
 );
 })
 .where((i) => i.stakeholder.isNotEmpty)
 .toList();
 }

 String _norm(dynamic v, String fb) {
 final s = (v ?? '').toString().trim();
 return s.isEmpty ? fb : s;
 }
  // Launch Insights: KPIs + completion donut (auto-derived from project data)
  Widget _buildLaunchInsights() {
    final projectData = ProjectDataHelper.getData(context);
    final totalMilestones = projectData.keyMilestones.length;
        final doneMilestones = projectData.keyMilestones
            .where((m) =>
                m.comments.toLowerCase().contains('complete') ||
                m.comments.toLowerCase().contains('done'))
            .length;
        final completionPct =
            totalMilestones == 0 ? 0.0 : doneMilestones / totalMilestones;
    return LaunchInsightsHeader(
      sectionTitle: 'Deployment Transfer Progress',
      sectionSubtitle: 'Certification, release readiness, and production handoff',
      sectionIcon: Icons.send_outlined,
      sectionColor: const Color(0xFFD97706),
      completionPercent: completionPct,
      completionLabel: 'TRANSFERRED',
      completionCaption:
          '${(completionPct * 100).round()}% complete - auto-derived from project data',
      kpiTiles: [
        LaunchKpiTile(
              label: 'Team Members',
              value: '${projectData.teamMembers.length}',
              icon: Icons.people_outline,
              color: const Color(0xFFD97706),
              delta: 'assigned to project',
            ),
            LaunchKpiTile(
              label: 'Contractors',
              value: '${projectData.contractors.length}',
              icon: Icons.construction_outlined,
              color: const Color(0xFFF59E0B),
              delta: 'under contract',
            ),
            LaunchKpiTile(
              label: 'Vendors',
              value: '${projectData.vendors.length}',
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFF7C3AED),
              delta: 'in supply chain',
            ),
            LaunchKpiTile(
              label: 'Milestones Done',
              value: '${projectData.keyMilestones.where((m) => m.comments.toLowerCase().contains('complete') || m.comments.toLowerCase().contains('done')).length}',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF10B981),
              delta: 'of ${projectData.keyMilestones.length} total',
            ),
      ],
    );
  }


}
