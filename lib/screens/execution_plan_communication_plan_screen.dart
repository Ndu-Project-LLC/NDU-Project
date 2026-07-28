import 'package:ndu_project/screens/execution_plan_interface_management_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/execution_plan_shared.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/execution_service.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/csv_table_import_button.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';

Future<void> _exportPdf(BuildContext context) async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Communication Plan',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['execution_plan_communication_plan_screen'] ?? 'No data recorded.'),
 ],
 );
}

class ExecutionPlanCommunicationPlanScreen extends StatelessWidget {
 const ExecutionPlanCommunicationPlanScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const ExecutionPlanCommunicationPlanScreen()),
 );
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 20 : 40;

 return ResponsiveScaffold(
 activeItemLabel: 'Execution Plan - Communication Plan',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 ExecutionPlanHeader(
 onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'execution_plan_communication_plan'),
 onNext: () => PlanningPhaseNavigation.goToNext(context, 'execution_plan_communication_plan'), onExportPdf: () => _exportPdf(context)),
 const SizedBox(height: 32),
 const SectionIntro(
 title: 'Execution Plan - Communication Plan'),
 const SizedBox(height: 24),
 const ExecutionPlanForm(
 title: 'Execution Plan - Communication Plan',
 hintText:
 'Outline communication cadence, channels, and stakeholder updates.',
 noteKey: 'execution_communication_plan',
 ),
 const SizedBox(height: 32),
 const _CommunicationPlanSection(),
 const SizedBox(height: 56),
 ],
 ),
 ),
 );
 }
}

class _CommunicationPlanSection extends StatelessWidget {
 const _CommunicationPlanSection();

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Communication Matrix',
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 28),
 const _CommunicationPlanTable(),
 const SizedBox(height: 20),
 Align(
 alignment: Alignment.centerRight,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 tableTitle: 'Communication Plan',
 columns: [
 CsvColumnSpec(key: 'stakeholder', label: 'Stakeholder', required: true, sampleValue: 'Project Sponsor'),
 CsvColumnSpec(key: 'infoType', label: 'Info Type', required: true, sampleValue: 'Status Update'),
 CsvColumnSpec(key: 'frequency', label: 'Frequency', allowedValues: ['Daily', 'Weekly', 'Bi-weekly', 'Monthly', 'Quarterly'], defaultValue: 'Weekly', sampleValue: 'Weekly'),
 CsvColumnSpec(key: 'channel', label: 'Channel', allowedValues: ['Email', 'Meeting', 'Report', 'Dashboard', 'Portal', 'Phone'], defaultValue: 'Email', sampleValue: 'Email'),
 CsvColumnSpec(key: 'owner', label: 'Owner', required: true, sampleValue: 'PMO Lead'),
 CsvColumnSpec(key: 'status', label: 'Status', allowedValues: ['Planned', 'Active', 'On Hold', 'Completed'], defaultValue: 'Planned', sampleValue: 'Planned'),
 CsvColumnSpec(key: 'comments', label: 'Comments', sampleValue: 'Weekly progress report'),
 ],
 onImport: (rows) async {
 final projectId = _CommunicationPlanTable._getProjectIdStatic(context);
 if (projectId == null) return;
 var imported = 0;
 for (final row in rows) {
 try {
 await ExecutionService.createCommunicationPlan(
 projectId: projectId,
 stakeholder: row['stakeholder'] ?? '',
 infoType: row['infoType'] ?? '',
 frequency: row['frequency']?.isNotEmpty == true ? row['frequency']! : 'Weekly',
 channel: row['channel']?.isNotEmpty == true ? row['channel']! : 'Email',
 owner: row['owner'] ?? '',
 status: row['status']?.isNotEmpty == true ? row['status']! : 'Planned',
 comments: row['comments'] ?? '',
 );
 imported++;
 } catch (e) {
 if (context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error importing row: $e')),
 );
 }
 }
 }
 if (context.mounted && imported > 0) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Imported $imported communication entr(ies) successfully')),
 );
 }
 },
 ),
 const SizedBox(width: 12),
 AddRowButton(
 onPressed: () => _CommunicationPlanTable.showAddDialog(context)),
 ],
 ),
 ),
 const SizedBox(height: 44),
 if (isMobile)
 _MobileCommunicationPlanActions()
 else
 const _DesktopCommunicationPlanActions(),
 ],
 );
 }
}

class _CommunicationPlanTable extends StatelessWidget {
 const _CommunicationPlanTable();

 String? _getProjectId(BuildContext context) {
 try {
 final provider = ProjectDataInherited.maybeOf(context);
 return provider?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 static String? _getProjectIdStatic(BuildContext context) {
 try {
 final provider = ProjectDataInherited.maybeOf(context);
 return provider?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 static void showAddDialog(BuildContext context) {
 final projectId = _getProjectIdStatic(context);
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No project selected. Please open a project first.')),
 );
 return;
 }
 _showCommunicationDialog(context, null, projectId);
 }

 static void showEditDialog(
 BuildContext context, CommunicationPlanModel entry) {
 final projectId = _getProjectIdStatic(context);
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No project selected. Please open a project first.')),
 );
 return;
 }
 _showCommunicationDialog(context, entry, projectId);
 }

 static void showDeleteDialog(
 BuildContext context, CommunicationPlanModel entry) {
 final projectId = _getProjectIdStatic(context);
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No project selected. Please open a project first.')),
 );
 return;
 }

 showDialog(
 context: context,
 builder: (context) => AlertDialog(
 title: const Text('Delete Communication Entry'),
 content: Text(
 'Are you sure you want to delete the entry for "${entry.stakeholder}"? This action cannot be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () async {
 try {
 await ExecutionService.deleteCommunicationPlan(
 projectId: projectId, planId: entry.id);
 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content:
 Text('Communication entry deleted successfully')),
 );
 }
 } catch (e) {
 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content:
 Text('Error deleting communication entry: $e')),
 );
 }
 }
 },
 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
 child: const Text('Delete', style: TextStyle(color: Colors.white)),
 ),
 ],
 ),
 );
 }

 static void _showCommunicationDialog(
 BuildContext context, CommunicationPlanModel? entry, String projectId) {
 final isEdit = entry != null;
 final stakeholderController =
 TextEditingController(text: entry?.stakeholder ?? '');
 final infoTypeController =
 TextEditingController(text: entry?.infoType ?? '');
 String frequency = entry?.frequency ?? 'Weekly';
 String channel = entry?.channel ?? 'Email';
 final ownerController = TextEditingController(text: entry?.owner ?? '');
 String status = entry?.status ?? 'Planned';
 final commentsController =
 TextEditingController(text: entry?.comments ?? '');

 const frequencies = [
 'Daily',
 'Weekly',
 'Bi-weekly',
 'Monthly',
 'Quarterly'
 ];
 const channels = [
 'Email',
 'Meeting',
 'Report',
 'Dashboard',
 'Portal',
 'Phone'
 ];
 const statuses = ['Planned', 'Active', 'On Hold', 'Completed'];

 showDialog(
 context: context,
 builder: (context) => StatefulBuilder(
 builder: (context, setState) => AlertDialog(
 title: Text(isEdit
 ? 'Edit Communication Entry'
 : 'Add New Communication Entry'),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: stakeholderController,
 decoration:
 const InputDecoration(labelText: 'Stakeholder *')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: infoTypeController,
 decoration:
 const InputDecoration(labelText: 'Info Type *')),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: frequency,
 decoration: const InputDecoration(labelText: 'Frequency *'),
 items: frequencies
 .map((f) => DropdownMenuItem(value: f, child: Text(f)))
 .toList(),
 onChanged: (v) => setState(() => frequency = v ?? 'Weekly'),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: channel,
 decoration: const InputDecoration(labelText: 'Channel *'),
 items: channels
 .map((c) => DropdownMenuItem(value: c, child: Text(c)))
 .toList(),
 onChanged: (v) => setState(() => channel = v ?? 'Email'),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: ownerController,
 decoration: const InputDecoration(labelText: 'Owner *')),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: status,
 decoration: const InputDecoration(labelText: 'Status *'),
 items: statuses
 .map((s) => DropdownMenuItem(value: s, child: Text(s)))
 .toList(),
 onChanged: (v) => setState(() => status = v ?? 'Planned'),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: commentsController,
 decoration: const InputDecoration(labelText: 'Comments'),
 maxLines: 3),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () async {
 if (stakeholderController.text.isEmpty ||
 infoTypeController.text.isEmpty ||
 ownerController.text.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Please fill in all required fields')),
 );
 return;
 }

 try {
 if (isEdit) {
 await ExecutionService.updateCommunicationPlan(
 projectId: projectId,
 planId: entry.id,
 stakeholder: stakeholderController.text,
 infoType: infoTypeController.text,
 frequency: frequency,
 channel: channel,
 owner: ownerController.text,
 status: status,
 comments: commentsController.text,
 );
 } else {
 await ExecutionService.createCommunicationPlan(
 projectId: projectId,
 stakeholder: stakeholderController.text,
 infoType: infoTypeController.text,
 frequency: frequency,
 channel: channel,
 owner: ownerController.text,
 status: status,
 comments: commentsController.text,
 );
 }

 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(isEdit
 ? 'Communication entry updated successfully'
 : 'Communication entry added successfully')),
 );
 }
 } catch (e) {
 if (context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error: $e')),
 );
 }
 }
 },
 child: Text(isEdit ? 'Update' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 final projectId = _getProjectId(context);
 if (projectId == null) {
 return const Center(
 child: Padding(
 padding: EdgeInsets.all(24.0),
 child: Text('No project selected. Please open a project first.',
 style: TextStyle(color: Color(0xFF64748B))),
 ),
 );
 }

 return StreamBuilder<List<CommunicationPlanModel>>(
 stream: ExecutionService.streamCommunicationPlan(projectId),
 builder: (context, snapshot) {
 if (snapshot.connectionState == ConnectionState.waiting) {
 return const Center(
 child: Padding(
 padding: EdgeInsets.all(24.0),
 child: CircularProgressIndicator()));
 }

 if (snapshot.hasError) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Text(
 'Error loading communication entries: ${snapshot.error}',
 style: const TextStyle(color: Colors.red)),
 ),
 );
 }

 final entries = snapshot.data ?? [];

 const headerStyle = TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 );
 const cellStyle = TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF4B5563),
 height: 1.5,
 );

 Widget buildCell(String text,
 {bool isHeader = false,
 TextAlign align = TextAlign.left,
 TextStyle? style}) {
 return Container(
 color: isHeader ? const Color(0xFFF3F4F6) : Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
 child: Text(
 text,
 textAlign: align,
 style: style ?? (isHeader ? headerStyle : cellStyle),
 ),
 );
 }

 return Container(
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 clipBehavior: Clip.antiAlias,
 child: SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: Table(
 columnWidths: const {
 0: FixedColumnWidth(70),
 1: FixedColumnWidth(140),
 2: FixedColumnWidth(120),
 3: FixedColumnWidth(110),
 4: FixedColumnWidth(110),
 5: FixedColumnWidth(120),
 6: FixedColumnWidth(100),
 7: FixedColumnWidth(150),
 8: FixedColumnWidth(100),
 },
 border: const TableBorder(
 horizontalInside: BorderSide(color: Color(0xFFE5E7EB)),
 verticalInside: BorderSide(color: Color(0xFFE5E7EB)),
 top: BorderSide(color: Color(0xFFE5E7EB)),
 bottom: BorderSide(color: Color(0xFFE5E7EB)),
 left: BorderSide(color: Color(0xFFE5E7EB)),
 right: BorderSide(color: Color(0xFFE5E7EB)),
 ),
 children: [
 TableRow(
 children: [
 buildCell('No', isHeader: true, align: TextAlign.center),
 buildCell('Stakeholder', isHeader: true),
 buildCell('Info Type', isHeader: true),
 buildCell('Frequency', isHeader: true),
 buildCell('Channel', isHeader: true),
 buildCell('Owner', isHeader: true),
 buildCell('Status', isHeader: true),
 buildCell('Comments', isHeader: true),
 buildCell('Actions',
 isHeader: true, align: TextAlign.center),
 ],
 ),
 if (entries.isEmpty)
 TableRow(
 children: [
 buildCell('', align: TextAlign.center),
 buildCell('No communication entries added yet',
 style: const TextStyle(
 color: Color(0xFF64748B),
 fontStyle: FontStyle.italic)),
 buildCell(''),
 buildCell(''),
 buildCell(''),
 buildCell(''),
 buildCell(''),
 buildCell(''),
 buildCell(''),
 ],
 )
 else
 ...entries.asMap().entries.map((entry) {
 final index = entry.key;
 final item = entry.value;
 return TableRow(
 children: [
 buildCell('${index + 1}', align: TextAlign.center),
 buildCell(item.stakeholder),
 buildCell(item.infoType),
 buildCell(item.frequency),
 buildCell(item.channel),
 buildCell(item.owner),
 buildCell(item.status),
 buildCell(item.comments),
 Container(
 color: Colors.white,
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 18),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 icon: const Icon(Icons.edit,
 size: 18, color: Color(0xFF64748B)),
 onPressed: () => showEditDialog(context, item),
 tooltip: 'Edit',
 ),
 IconButton(
 icon: const Icon(Icons.delete,
 size: 18, color: Color(0xFFEF4444)),
 onPressed: () =>
 showDeleteDialog(context, item),
 tooltip: 'Delete',
 ),
 ],
 ),
 ),
 ],
 );
 }),
 ],
 ),
 ),
 );
 },
 );
 }
}

class _DesktopCommunicationPlanActions extends StatelessWidget {
 const _DesktopCommunicationPlanActions();

 @override
 Widget build(BuildContext context) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 const InfoBadge(),
 const SizedBox(width: 32),
 Expanded(
 child: Align(
 alignment: Alignment.centerLeft,
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 420),
 child: const AiTipCard(
 text:
 'Match communication frequency to stakeholder influence — high-influence stakeholders need more frequent updates.',
 ),
 ),
 ),
 ),
 const SizedBox(width: 24),
 YellowActionButton(
 label: 'Next',
 onPressed: () =>
 ExecutionPlanInterfaceManagementPlanScreen.open(context),
 ),
 ],
 );
 }
}

class _MobileCommunicationPlanActions extends StatelessWidget {
 const _MobileCommunicationPlanActions();

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 const InfoBadge(),
 const SizedBox(height: 20),
 const AiTipCard(
 text:
 'Match communication frequency to stakeholder influence — high-influence stakeholders need more frequent updates.',
 ),
 const SizedBox(height: 20),
 YellowActionButton(
 label: 'Next',
 onPressed: () =>
 ExecutionPlanInterfaceManagementPlanScreen.open(context),
 ),
 ],
 );
 }
}
