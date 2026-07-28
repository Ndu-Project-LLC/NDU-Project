import 'package:ndu_project/widgets/launch_notes_section.dart';
import 'package:ndu_project/widgets/launch_insights_widgets.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:ndu_project/models/launch_phase_models.dart';
import 'package:ndu_project/screens/benefits_realization_screen.dart';
import 'package:ndu_project/screens/finalize_project_screen.dart';
import 'package:ndu_project/screens/project_close_out_screen.dart';
import 'package:ndu_project/services/launch_phase_service.dart';
import 'package:ndu_project/utils/launch_phase_ai_seed.dart';
import 'package:ndu_project/utils/download_helper.dart' as download_helper;
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
class DemobilizeTeamScreen extends StatefulWidget {
 const DemobilizeTeamScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const DemobilizeTeamScreen()),
 );
 }

 @override
 State<DemobilizeTeamScreen> createState() => _DemobilizeTeamScreenState();
}

class _DemobilizeTeamScreenState extends State<DemobilizeTeamScreen> {
 List<LaunchTeamMember> _teamRoster = [];
  final TextEditingController _notesController = TextEditingController();
 List<LaunchKnowledgeTransfer> _knowledgeTransfers = [];
 List<LaunchFollowUpItem> _vendorOffboarding = [];
 List<LaunchCommunicationItem> _communications = [];
 LaunchClosureNotes _debriefNotes = LaunchClosureNotes();

 bool _isLoading = true;
 bool _isGenerating = false;
 bool _isExporting = false;
 bool _hasLoaded = false;
 bool _suspendSave = false;
 final Map<String, bool> _kazAiRegenerating = {};
 String _selectedView = 'full'; // 'full' or 'summary'

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
 activeItemLabel: '10. Team Demobilization & Operations/Production Transition',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: Column(
 children: [
 Expanded(
 child: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: isMobile ? 16 : 32,
 vertical: isMobile ? 16 : 28,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_isLoading) const LinearProgressIndicator(minHeight: 2),
 PlanningPhaseHeader(
 title: 'Team Demobilization & Operations/Production Transition',
showNavigationButtons: false, showExportPdf: false, showAiAssist: false),
 const SizedBox(height: 16),
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
 _buildKnowledgeTransferPanel(),
 const SizedBox(height: 16),
 _buildVendorOffboardingPanel(),
 const SizedBox(height: 16),
 _buildCommunicationsPanel(),
 const SizedBox(height: 24),
 ],
 ),
 ),
 ),
 // ── Bottom navigation bar (pinned to bottom of screen) ──
 Container(
 padding: EdgeInsets.symmetric(
 horizontal: isMobile ? 16 : 32,
 vertical: 16,
 ),
 decoration: BoxDecoration(
 color: Colors.white,
 border: Border(
 top: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
 ),
 ),
 child: LaunchPhaseNavigation(
 backLabel: 'Back: Benefits Realization',
 nextLabel: 'Next: Project Closeout',
 onBack: () => BenefitsRealizationScreen.open(context),
 onNext: () => ProjectCloseOutScreen.open(context),
 ),
 ),
 ],
 ),
 );
 }



 Widget _buildMetricsRow() {
 final active = _teamRoster.where((m) => m.releaseStatus == 'Active').length;
 final released =
 _teamRoster.where((m) => m.releaseStatus == 'Released').length;
 final pendingKt =
 _knowledgeTransfers.where((k) => k.status != 'Complete').length;
 final pendingComms =
 _communications.where((c) => c.status != 'Sent').length;

 return ExecutionMetricsGrid(
 metrics: [
 ExecutionMetricData(
 label: 'Team Members',
 value: '${_teamRoster.length}',
 icon: Icons.people_outline,
 emphasisColor: const Color(0xFF2563EB),
 helper: '$active active, $released released',
 ),
 ExecutionMetricData(
 label: 'Knowledge Transfers',
 value: '$pendingKt pending',
 icon: Icons.school_outlined,
 emphasisColor:
 pendingKt > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
 ),
 ExecutionMetricData(
 label: 'Vendor Offboarding',
 value: '${_vendorOffboarding.length}',
 icon: Icons.business_center_outlined,
 emphasisColor: const Color(0xFF8B5CF6),
 ),
 ExecutionMetricData(
 label: 'Communications',
 value: '$pendingComms pending',
 icon: Icons.campaign_outlined,
 emphasisColor: const Color(0xFF10B981),
 ),
 ],
 );
 }

 Widget _buildTeamRosterPanel() {
 return LaunchDataTable(
 title: 'Team Ramp-Down Roster',
 subtitle: 'Track each team member\'s release status and dates.',
 columns: const [
 LaunchColumn(label: 'Name', flexible: true, fieldType: LaunchFieldType.text, hint: 'Name'),
 LaunchColumn(label: 'Role', width: 120, fieldType: LaunchFieldType.text, hint: 'Role'),
 LaunchColumn(label: 'Contact', width: 120, fieldType: LaunchFieldType.text, hint: 'Contact'),
 LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Active', 'Transitioning', 'Released']),
 ],
 rowCount: _teamRoster.length,
 onAddValues: (values) {
 setState(() => _teamRoster.add(LaunchTeamMember(
 name: values['Name'] ?? '',
 role: values['Role'] ?? '',
 contact: values['Contact'] ?? '',
 releaseStatus: values['Status'] ?? 'Active',
 )));
 _save();
 },
 onImport: _importTeam,
 importLabel: 'Import',
 csvColumns: const [
 CsvColumnSpec(key: 'name', label: 'Name', sampleValue: 'John Doe'),
 CsvColumnSpec(key: 'role', label: 'Role', sampleValue: 'Developer'),
 CsvColumnSpec(key: 'contact', label: 'Contact', sampleValue: 'john@example.com'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Active', allowedValues: ['Active', 'Transitioning', 'Released']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _teamRoster.add(LaunchTeamMember(
 name: row['name'] ?? '',
 role: row['role'] ?? '',
 contact: row['contact'] ?? '',
 releaseStatus: row['status'] ?? 'Active',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'No team members. Add or import from staffing.',
 cellBuilder: (context, i) {
 final m = _teamRoster[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirmed =
 await launchConfirmDelete(context, itemName: 'team member');
 if (!confirmed) return;
 setState(() => _teamRoster.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateTeamRosterRow(i),
 cells: [
 LaunchEditableCell(
 value: m.name,
 hint: 'Name',
 bold: true,
 expand: true,
 onChanged: (s) {
 _teamRoster[i] = m.copyWith(name: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: m.role,
 hint: 'Role',
 expand: true,
 onChanged: (s) {
 _teamRoster[i] = m.copyWith(role: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: m.contact,
 hint: 'Contact',
 expand: true,
 onChanged: (s) {
 _teamRoster[i] = m.copyWith(contact: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: m.releaseStatus,
 items: const ['Active', 'Transitioning', 'Released'],
 onChanged: (s) {
 if (s == null) return;
 _teamRoster[i] = m.copyWith(releaseStatus: s);
 _save();
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
 subtitle: 'Sessions and artifacts being handed off before team release.',
 columns: const [
 LaunchColumn(label: 'Topic', flexible: true, fieldType: LaunchFieldType.text, hint: 'Topic'),
 LaunchColumn(label: 'From', width: 130, fieldType: LaunchFieldType.text, hint: 'From'),
 LaunchColumn(label: 'To', width: 130, fieldType: LaunchFieldType.text, hint: 'To'),
 LaunchColumn(label: 'Method', width: 130, fieldType: LaunchFieldType.text, hint: 'Method'),
 LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Pending', 'Scheduled', 'Complete']),
 ],
 rowCount: _knowledgeTransfers.length,
 onAddValues: (values) {
 setState(() => _knowledgeTransfers.add(LaunchKnowledgeTransfer(
 topic: values['Topic'] ?? '',
 fromPerson: values['From'] ?? '',
 toPerson: values['To'] ?? '',
 method: values['Method'] ?? '',
 status: values['Status'] ?? 'Pending',
 )));
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'topic', label: 'Topic', sampleValue: 'API Documentation'),
 CsvColumnSpec(key: 'from', label: 'From', sampleValue: 'Alice'),
 CsvColumnSpec(key: 'to', label: 'To', sampleValue: 'Bob'),
 CsvColumnSpec(key: 'method', label: 'Method', sampleValue: 'Workshop'),
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
 _save();
 },
 emptyMessage: 'No transfers. Track knowledge handoff sessions.',
 cellBuilder: (context, i) {
 final k = _knowledgeTransfers[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirmed = await launchConfirmDelete(context,
 itemName: 'knowledge transfer');
 if (!confirmed) return;
 setState(() => _knowledgeTransfers.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateKnowledgeTransferRow(i),
 cells: [
 LaunchEditableCell(
 value: k.topic,
 hint: 'Topic',
 bold: true,
 expand: true,
 onChanged: (s) {
 _knowledgeTransfers[i] = k.copyWith(topic: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: k.fromPerson,
 hint: 'From',
 expand: true,
 onChanged: (s) {
 _knowledgeTransfers[i] = k.copyWith(fromPerson: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: k.toPerson,
 hint: 'To',
 expand: true,
 onChanged: (s) {
 _knowledgeTransfers[i] = k.copyWith(toPerson: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: k.method,
 hint: 'Method',
 expand: true,
 onChanged: (s) {
 _knowledgeTransfers[i] = k.copyWith(method: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: k.status,
 items: const ['Pending', 'Scheduled', 'Complete'],
 onChanged: (s) {
 if (s == null) return;
 _knowledgeTransfers[i] = k.copyWith(status: s);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildVendorOffboardingPanel() {
 return LaunchDataTable(
 title: 'Vendor Offboarding',
 subtitle:
 'Track vendor exits, access cleanup, and remaining obligations.',
 columns: const [
 LaunchColumn(label: 'Task', flexible: true, fieldType: LaunchFieldType.text, hint: 'Task'),
 LaunchColumn(label: 'Details', flexible: true, fieldType: LaunchFieldType.text, hint: 'Details'),
 LaunchColumn(label: 'Owner', width: 120, fieldType: LaunchFieldType.text, hint: 'Owner'),
 LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Pending', 'In Progress', 'Complete']),
 ],
 rowCount: _vendorOffboarding.length,
 onAddValues: (values) {
 setState(() => _vendorOffboarding.add(LaunchFollowUpItem(
 title: values['Task'] ?? '',
 details: values['Details'] ?? '',
 owner: values['Owner'] ?? '',
 status: values['Status'] ?? 'Pending',
 )));
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'task', label: 'Task', sampleValue: 'Revoke system access'),
 CsvColumnSpec(key: 'details', label: 'Details', sampleValue: 'Remove VPN and email'),
 CsvColumnSpec(key: 'owner', label: 'Owner', sampleValue: 'IT Lead'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Pending', allowedValues: ['Pending', 'In Progress', 'Complete']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _vendorOffboarding.add(LaunchFollowUpItem(
 title: row['task'] ?? '',
 details: row['details'] ?? '',
 owner: row['owner'] ?? '',
 status: row['status'] ?? 'Pending',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'No vendor items. Track vendor offboarding tasks.',
 cellBuilder: (context, i) {
 final v = _vendorOffboarding[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirmed = await launchConfirmDelete(context,
 itemName: 'vendor offboarding task');
 if (!confirmed) return;
 setState(() => _vendorOffboarding.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateVendorOffboardingRow(i),
 cells: [
 LaunchEditableCell(
 value: v.title,
 hint: 'Task',
 bold: true,
 expand: true,
 onChanged: (s) {
 _vendorOffboarding[i] = v.copyWith(title: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: v.details,
 hint: 'Details',
 expand: true,
 onChanged: (s) {
 _vendorOffboarding[i] = v.copyWith(details: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: v.owner,
 hint: 'Owner',
 expand: true,
 onChanged: (s) {
 _vendorOffboarding[i] = v.copyWith(owner: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: v.status,
 items: const ['Pending', 'In Progress', 'Complete'],
 onChanged: (s) {
 if (s == null) return;
 _vendorOffboarding[i] = v.copyWith(status: s);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildCommunicationsPanel() {
 return LaunchDataTable(
 title: 'Communications & People Care',
 subtitle:
 'Planned communications to stakeholders, team, and affected people.',
 columns: const [
 LaunchColumn(label: 'Audience', flexible: true, fieldType: LaunchFieldType.text, hint: 'Audience'),
 LaunchColumn(label: 'Message', flexible: true, fieldType: LaunchFieldType.text, hint: 'Message'),
 LaunchColumn(label: 'Channel', width: 130, fieldType: LaunchFieldType.text, hint: 'Channel'),
 LaunchColumn(label: 'Send Date', width: 130, fieldType: LaunchFieldType.date, hint: 'Send Date'),
 LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Planned', 'Sent', 'Cancelled']),
 ],
 rowCount: _communications.length,
 onAddValues: (values) {
 setState(() => _communications.add(LaunchCommunicationItem(
 audience: values['Audience'] ?? '',
 message: values['Message'] ?? '',
 channel: values['Channel'] ?? '',
 sendDate: values['Send Date'] ?? '',
 status: values['Status'] ?? 'Planned',
 )));
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'audience', label: 'Audience', sampleValue: 'All Team Members'),
 CsvColumnSpec(key: 'message', label: 'Message', sampleValue: 'Project wrap-up notification'),
 CsvColumnSpec(key: 'channel', label: 'Channel', sampleValue: 'Email'),
 CsvColumnSpec(key: 'sendDate', label: 'Send Date', sampleValue: '2025-01-20'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Planned', allowedValues: ['Planned', 'Sent', 'Cancelled']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _communications.add(LaunchCommunicationItem(
 audience: row['audience'] ?? '',
 message: row['message'] ?? '',
 channel: row['channel'] ?? '',
 sendDate: row['sendDate'] ?? '',
 status: row['status'] ?? 'Planned',
 ));
 });
 }
 _save();
 },
 emptyMessage:
 'No communications. Plan team and stakeholder communications.',
 cellBuilder: (context, i) {
 final c = _communications[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirmed =
 await launchConfirmDelete(context, itemName: 'communication');
 if (!confirmed) return;
 setState(() => _communications.removeAt(i));
 _save();
 },
 onKazAi: () => _regenerateCommunicationRow(i),
 cells: [
 LaunchEditableCell(
 value: c.audience,
 hint: 'Audience',
 bold: true,
 expand: true,
 onChanged: (s) {
 _communications[i] = c.copyWith(audience: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: c.message,
 hint: 'Message',
 expand: true,
 onChanged: (s) {
 _communications[i] = c.copyWith(message: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: c.channel,
 hint: 'Channel',
 expand: true,
 onChanged: (s) {
 _communications[i] = c.copyWith(channel: s);
 _save();
 },
 ),
 LaunchDateCell(
 value: c.sendDate,
 hint: 'Date',
 onChanged: (s) {
 _communications[i] = c.copyWith(sendDate: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: c.status,
 items: const ['Planned', 'Sent', 'Cancelled'],
 onChanged: (s) {
 if (s == null) return;
 _communications[i] = c.copyWith(status: s);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Future<void> _importTeam() async {
 if (_projectId == null) return;
 final staff = await LaunchPhaseService.loadExecutionStaffing(_projectId!);
 if (staff.isEmpty) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('No team members found to import.')));
 }
 return;
 }
 setState(() {
 final existing = _teamRoster.map((m) => m.name).toSet();
 for (final m in staff) {
 if (!existing.contains(m.name)) _teamRoster.add(m);
 }
 });
 _save();
 }

 // ── KAZ AI Row Regeneration ─────────────────────────────────────────────

 Future<void> _regenerateTeamRosterRow(int index) async {
 if (index < 0 || index >= _teamRoster.length) return;
 final key = 'team_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Team Ramp-Down Roster');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a team member name, role, and contact for ramp-down.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "name", "role", "contact", "status". Status must be Active, Transitioning, or Released.',
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
 role: (parsed['role'] ?? _teamRoster[index].role).toString(),
 contact: (parsed['contact'] ?? _teamRoster[index].contact).toString(),
 releaseStatus: (parsed['status'] ?? _teamRoster[index].releaseStatus).toString(),
 );
 });
 _save();
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
 _save();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 Future<void> _regenerateVendorOffboardingRow(int index) async {
 if (index < 0 || index >= _vendorOffboarding.length) return;
 final key = 'voff_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Vendor Offboarding');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a vendor offboarding task, details, and owner.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "task", "details", "owner", "status". Status must be Pending, In Progress, or Complete.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _vendorOffboarding[index] = _vendorOffboarding[index].copyWith(
 title: (parsed['task'] ?? '').toString(),
 details: (parsed['details'] ?? _vendorOffboarding[index].details).toString(),
 owner: (parsed['owner'] ?? _vendorOffboarding[index].owner).toString(),
 status: (parsed['status'] ?? _vendorOffboarding[index].status).toString(),
 );
 });
 _save();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 Future<void> _regenerateCommunicationRow(int index) async {
 if (index < 0 || index >= _communications.length) return;
 final key = 'comm_$index';
 if (_kazAiRegenerating[key] == true) return;
 setState(() => _kazAiRegenerating[key] = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final ctx = ProjectDataHelper.buildProjectContextScan(projectData, sectionLabel: 'Communications & People Care');
 final openai = OpenAiServiceSecure();
 final result = await openai.generateCompletion(
 'Based on this project context, suggest a communication audience, message, and channel.\n\nContext:\n$ctx\n\nReturn ONLY a valid JSON object with keys: "audience", "message", "channel", "status". Status must be Planned, Sent, or Cancelled.',
 maxTokens: 250, temperature: 0.6,
 );
 final start = result.indexOf('{');
 final end = result.lastIndexOf('}');
 if (start != -1 && end != -1) {
 final parsed = jsonDecode(result.substring(start, end + 1)) as Map<String, dynamic>;
 if (mounted) {
 setState(() {
 _communications[index] = _communications[index].copyWith(
 audience: (parsed['audience'] ?? '').toString(),
 message: (parsed['message'] ?? _communications[index].message).toString(),
 channel: (parsed['channel'] ?? _communications[index].channel).toString(),
 status: (parsed['status'] ?? _communications[index].status).toString(),
 );
 });
 _save();
 }
 }
 } catch (e) {
 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KAZ AI failed: $e')));
 } finally {
 if (mounted) setState(() => _kazAiRegenerating[key] = false);
 }
 }

 void _save() {
 if (_suspendSave || !_hasLoaded) return;
 Future.microtask(() {
 if (mounted) _persistData();
 });
 }

 Future<void> _loadData() async {
 if (_hasLoaded || _projectId == null) return;
 _suspendSave = true;
 try {
 final r =
 await LaunchPhaseService.loadDemobilizeTeam(projectId: _projectId!);
 if (!mounted) return;
 setState(() {
 _teamRoster = r.teamRoster;
 _knowledgeTransfers = r.knowledgeTransfers;
 _vendorOffboarding = r.vendorOffboarding;
 _communications = r.communications;
 _debriefNotes = r.debriefNotes;
 _isLoading = false;
 _hasLoaded = true;
 });
 if (_teamRoster.isEmpty &&
 _knowledgeTransfers.isEmpty &&
 _vendorOffboarding.isEmpty &&
 _communications.isEmpty) {
 await _autoPopulateFromPriorPhases();
 }
 if (_teamRoster.isEmpty &&
 _knowledgeTransfers.isEmpty &&
 _vendorOffboarding.isEmpty &&
 _communications.isEmpty) {
 await _populateFromAi();
 }
 } catch (e) {
 debugPrint('Demobilize load error: $e');
 if (mounted) setState(() => _isLoading = false);
 }
 _suspendSave = false;
 }

 Future<void> _persistData() async {
 if (_projectId == null) return;
 try {
 await LaunchPhaseService.saveDemobilizeTeam(
 projectId: _projectId!,
 teamRoster: _teamRoster,
 knowledgeTransfers: _knowledgeTransfers,
 vendorOffboarding: _vendorOffboarding,
 communications: _communications,
 debriefNotes: _debriefNotes);
 } catch (e) {
 debugPrint('Demobilize save error: $e');
 }
 }

 Future<void> _autoPopulateFromPriorPhases() async {
 if (_projectId == null) return;
 try {
 final cp = await LaunchPhaseAiSeed.loadCrossPhaseData(_projectId!);

 if (!mounted) return;

 // Pre-fill team roster from staffing
 if (_teamRoster.isEmpty && cp.staffing.isNotEmpty) {
 setState(() => _teamRoster.addAll(cp.staffing));
 }

 // Pre-fill knowledge transfers from team data
 final ktExisting = _knowledgeTransfers.map((k) => k.topic).toSet();
 final newKts = <LaunchKnowledgeTransfer>[];
 for (final s in cp.staffing) {
 if (s.name.isNotEmpty && !ktExisting.contains('KT: ${s.role}')) {
 newKts.add(LaunchKnowledgeTransfer(
 topic: 'KT: ${s.role}',
 fromPerson: s.name,
 status: 'Pending',
 ));
 }
 }
 if (newKts.isNotEmpty) {
 setState(() => _knowledgeTransfers.addAll(newKts));
 }

 // Pre-fill vendor offboarding from vendors
 final vendorExisting = _vendorOffboarding.map((v) => v.title).toSet();
 final newVendors = <LaunchFollowUpItem>[];
 for (final v in cp.vendors) {
 if (v.vendorName.isNotEmpty && !vendorExisting.contains('Offboard: ${v.vendorName}')) {
 newVendors.add(LaunchFollowUpItem(
 title: 'Offboard: ${v.vendorName}',
 details: 'Contract: ${v.contractRef}, Status: ${v.accountStatus}',
 status: 'Pending',
 ));
 }
 }
 if (newVendors.isNotEmpty) {
 setState(() => _vendorOffboarding.addAll(newVendors));
 }

 // Pre-fill communications from stakeholders
 final commsExisting = _communications.map((c) => c.audience).toSet();
 final newComms = <LaunchCommunicationItem>[];
 for (final sh in cp.stakeholders) {
 final name = sh['name'] ?? sh['stakeholder'] ?? '';
 if (name.isNotEmpty && !commsExisting.contains(name)) {
 newComms.add(LaunchCommunicationItem(
 audience: name,
 message: 'Project close-out notification',
 status: 'Planned',
 ));
 }
 }
 // Add team-wide communication if there are team members
 if (cp.staffing.isNotEmpty && !commsExisting.contains('All Team Members')) {
 newComms.add(LaunchCommunicationItem(
 audience: 'All Team Members',
 message: 'Project wrap-up and debrief',
 status: 'Planned',
 ));
 }
 if (newComms.isNotEmpty) {
 setState(() => _communications.addAll(newComms));
 }

 if (_teamRoster.isNotEmpty || newKts.isNotEmpty || newVendors.isNotEmpty || newComms.isNotEmpty) {
 await _persistData();
 }
 } catch (e) {
 debugPrint('Demobilize auto-populate error: $e');
 }
 }

 Future<void> _populateFromAi() async {
 if (_isGenerating) return;
 setState(() => _isGenerating = true);
 LaunchAiResult? result;
 try {
 result = await LaunchPhaseAiSeed.generateEntries(
 context: context,
 sectionLabel: 'Demobilize Team',
 sections: const {
 'team_roster': 'Team members with "name", "role", "release_status"',
 'knowledge_transfer':
 'Knowledge transfer sessions with "topic", "from_person", "to_person", "method", "status"',
 'vendor_offboarding': 'Vendor offboarding tasks with "title", "details", "status"',
 'communications':
 'Communications with "audience", "message", "channel", "send_date", "status"',
 },
 itemsPerSection: 3,
 );
 } catch (e) {
 debugPrint('Demobilize AI error: $e');
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

 final hasData = _teamRoster.isNotEmpty ||
 _knowledgeTransfers.isNotEmpty ||
 _vendorOffboarding.isNotEmpty ||
 _communications.isNotEmpty;
 if (hasData) {
 setState(() => _isGenerating = false);
 return;
 }
 setState(() {
 _teamRoster = (generated['team_roster'] ?? [])
 .map((m) => LaunchTeamMember(
 name: _s(m['title']),
 role: _s(m['details']),
 releaseStatus: 'Active'))
 .where((i) => i.name.isNotEmpty)
 .toList();
 _knowledgeTransfers = (generated['knowledge_transfer'] ?? [])
 .map((m) => LaunchKnowledgeTransfer(
 topic: _s(m['title']), status: _ns(m['status'], 'Pending')))
 .where((i) => i.topic.isNotEmpty)
 .toList();
 _vendorOffboarding = (generated['vendor_offboarding'] ?? [])
 .map((m) => LaunchFollowUpItem(
 title: _s(m['title']),
 details: _s(m['details']),
 status: _ns(m['status'], 'Pending')))
 .where((i) => i.title.isNotEmpty)
 .toList();
 _communications = (generated['communications'] ?? [])
 .map((m) => LaunchCommunicationItem(
 audience: _s(m['title']),
 message: _s(m['details']),
 status: _ns(m['status'], 'Planned')))
 .where((i) => i.audience.isNotEmpty)
 .toList();
 _isGenerating = false;
 });
 await _persistData();
 }

 String _s(dynamic v) => (v ?? '').toString().trim();
 String _ns(dynamic v, String fb) => _s(v).isEmpty ? fb : _s(v);

 Future<void> _exportPdf() async {
 setState(() => _isExporting = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final projectName = projectData.projectName;
 final now = DateTime.now();
 final stamp =
 '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
 final filename =
 'demobilize_team_${projectName.replaceAll(' ', '_')}_$stamp.pdf';

 final doc = pw.Document();

 doc.addPage(
 pw.MultiPage(
 pageFormat: PdfPageFormat.a4,
 margin: const pw.EdgeInsets.all(32),
 build: (_) => [
 pw.Text(
 'Demobilize Team',
 style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
 ),
 pw.SizedBox(height: 4),
 pw.Text(
 '$projectName — Generated ${now.toLocal().toIso8601String()}',
 style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
 ),
 pw.SizedBox(height: 16),
 _pdfSectionTitle('Team Ramp-Down Roster'),
 pw.SizedBox(height: 6),
 if (_teamRoster.isEmpty)
 pw.Text('No team members.',
 style:
 const pw.TextStyle(fontSize: 9, color: PdfColors.grey500))
 else
 pw.TableHelper.fromTextArray(
 headerStyle:
 pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 headerDecoration:
 const pw.BoxDecoration(color: PdfColor(0.93, 0.95, 0.98)),
 cellStyle: const pw.TextStyle(fontSize: 8.5),
 cellAlignment: pw.Alignment.topLeft,
 headerAlignment: pw.Alignment.centerLeft,
 cellPadding:
 const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
 headers: const ['Name', 'Role', 'Contact', 'Status'],
 data: _teamRoster
 .map((m) => [
 _pc(m.name),
 _pc(m.role),
 _pc(m.contact),
 _pc(m.releaseStatus),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Knowledge Transfer'),
 pw.SizedBox(height: 6),
 if (_knowledgeTransfers.isEmpty)
 pw.Text('No knowledge transfers.',
 style:
 const pw.TextStyle(fontSize: 9, color: PdfColors.grey500))
 else
 pw.TableHelper.fromTextArray(
 headerStyle:
 pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 headerDecoration:
 const pw.BoxDecoration(color: PdfColor(0.93, 0.95, 0.98)),
 cellStyle: const pw.TextStyle(fontSize: 8.5),
 cellAlignment: pw.Alignment.topLeft,
 headerAlignment: pw.Alignment.centerLeft,
 cellPadding:
 const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
 headers: const [
 'Topic',
 'From',
 'To',
 'Method',
 'Status'
 ],
 data: _knowledgeTransfers
 .map((k) => [
 _pc(k.topic),
 _pc(k.fromPerson),
 _pc(k.toPerson),
 _pc(k.method),
 _pc(k.status),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Vendor Offboarding'),
 pw.SizedBox(height: 6),
 if (_vendorOffboarding.isEmpty)
 pw.Text('No vendor offboarding items.',
 style:
 const pw.TextStyle(fontSize: 9, color: PdfColors.grey500))
 else
 pw.TableHelper.fromTextArray(
 headerStyle:
 pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 headerDecoration:
 const pw.BoxDecoration(color: PdfColor(0.93, 0.95, 0.98)),
 cellStyle: const pw.TextStyle(fontSize: 8.5),
 cellAlignment: pw.Alignment.topLeft,
 headerAlignment: pw.Alignment.centerLeft,
 cellPadding:
 const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
 headers: const ['Task', 'Details', 'Owner', 'Status'],
 data: _vendorOffboarding
 .map((v) => [
 _pc(v.title),
 _pc(v.details),
 _pc(v.owner),
 _pc(v.status),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Communications & People Care'),
 pw.SizedBox(height: 6),
 if (_communications.isEmpty)
 pw.Text('No communications.',
 style:
 const pw.TextStyle(fontSize: 9, color: PdfColors.grey500))
 else
 pw.TableHelper.fromTextArray(
 headerStyle:
 pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 headerDecoration:
 const pw.BoxDecoration(color: PdfColor(0.93, 0.95, 0.98)),
 cellStyle: const pw.TextStyle(fontSize: 8.5),
 cellAlignment: pw.Alignment.topLeft,
 headerAlignment: pw.Alignment.centerLeft,
 cellPadding:
 const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
 headers: const [
 'Audience',
 'Message',
 'Channel',
 'Send Date',
 'Status'
 ],
 data: _communications
 .map((c) => [
 _pc(c.audience),
 _pc(c.message),
 _pc(c.channel),
 _pc(c.sendDate),
 _pc(c.status),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Team Debrief Notes'),
 pw.SizedBox(height: 6),
 pw.Text(
 _debriefNotes.notes.trim().isEmpty
 ? 'No debrief notes recorded.'
 : _debriefNotes.notes.trim(),
 style: const pw.TextStyle(fontSize: 9),
 ),
 ],
 ),
 );

 final bytes = await doc.save();
 if (kIsWeb) {
 download_helper.downloadFile(bytes, filename,
 mimeType: 'application/pdf');
 } else {
 await Printing.sharePdf(bytes: bytes, filename: filename);
 }

 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('PDF exported: $filename')),
 );
 }
 } catch (e) {
 debugPrint('PDF export error: $e');
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Failed to generate PDF: $e')),
 );
 }
 }
 if (mounted) setState(() => _isExporting = false);
 }

 pw.Widget _pdfSectionTitle(String title) {
 return pw.Container(
 width: double.infinity,
 padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
 decoration: const pw.BoxDecoration(
 color: PdfColor(0.06, 0.27, 0.45),
 borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
 ),
 child: pw.Text(title,
 style: pw.TextStyle(
 fontSize: 11,
 fontWeight: pw.FontWeight.bold,
 color: PdfColors.white)),
 );
 }

 String _pc(String v) => v.trim().isEmpty ? '-' : v.trim();
  // Launch Insights: KPIs + completion donut (auto-derived from project data)
  Widget _buildLaunchInsights() {
    final projectData = ProjectDataHelper.getData(context);
    final totalPeople = projectData.teamMembers.length +
            projectData.contractors.length +
            projectData.vendors.length;
        final totalMs = projectData.keyMilestones.length;
        final doneMs = projectData.keyMilestones
            .where((m) =>
                m.comments.toLowerCase().contains('complete') ||
                m.comments.toLowerCase().contains('done'))
            .length;
        final completionPct = totalMs == 0
            ? (totalPeople == 0 ? 0.0 : 0.1)
            : doneMs / totalMs;
    return LaunchInsightsHeader(
      sectionTitle: 'Team Demobilization Progress',
      sectionSubtitle: 'Offboarding, reassignments, and operations/production transition',
      sectionIcon: Icons.groups_outlined,
      sectionColor: const Color(0xFF64748B),
      completionPercent: completionPct,
      completionLabel: 'DEMOB',
      completionCaption:
          '${(completionPct * 100).round()}% complete - auto-derived from project data',
      kpiTiles: [
        LaunchKpiTile(
              label: 'Team Members',
              value: '${projectData.teamMembers.length}',
              icon: Icons.people_outline,
              color: const Color(0xFF2563EB),
              delta: 'to demobilize',
            ),
            LaunchKpiTile(
              label: 'Contractors',
              value: '${projectData.contractors.length}',
              icon: Icons.construction_outlined,
              color: const Color(0xFFF59E0B),
              delta: 'to release',
            ),
            LaunchKpiTile(
              label: 'Vendors',
              value: '${projectData.vendors.length}',
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFF7C3AED),
              delta: 'to close out',
            ),
            LaunchKpiTile(
              label: 'Milestones',
              value: '${projectData.keyMilestones.length}',
              icon: Icons.flag_outlined,
              color: const Color(0xFF10B981),
              delta: 'completed checkpoints',
            ),
      ],
    );
  }


}
