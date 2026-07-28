import 'package:ndu_project/screens/execution_plan_communication_plan_screen.dart';
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
 screenTitle: 'Interface Management',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['execution_plan_interface_management_screen'] ?? 'No data recorded.'),
 ],
 );
}

class ExecutionPlanInterfaceManagementScreen extends StatelessWidget {
 const ExecutionPlanInterfaceManagementScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const ExecutionPlanInterfaceManagementScreen()),
 );
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 20 : 40;

 return ResponsiveScaffold(
 activeItemLabel: 'Execution Interface Management',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 ExecutionPlanHeader(
 onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'execution_plan_interface_management'),
 onNext: () => PlanningPhaseNavigation.goToNext(context, 'execution_plan_interface_management'), onExportPdf: () => _exportPdf(context)),
  const SizedBox(height: 24),
 const CrossReferenceNote(standalonePage: 'Interface Management'),
 const SizedBox(height: 24),
 const ExecutionPlanForm(
 title: 'Execution Interface Management',
 hintText:
 'Summarize interface dependencies, coordination protocols, and governance.',
 noteKey: 'execution_interface_management',
 ),
 const SizedBox(height: 32),
 const _InterfaceManagementSection(),
 const SizedBox(height: 56),
 ],
 ),
 ),
 );
 }
}

class _InterfaceManagementSection extends StatelessWidget {
 const _InterfaceManagementSection();

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Interface Register',
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 28),
 const _InterfaceRegisterTable(),
 const SizedBox(height: 20),
 Align(
 alignment: Alignment.centerRight,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 tableTitle: 'Interface Register',
 columns: [
 CsvColumnSpec(key: 'interfaceId', label: 'Interface ID', required: true, sampleValue: 'IF-001'),
 CsvColumnSpec(key: 'interfaceName', label: 'Name', required: true, sampleValue: 'Site Access Road'),
 CsvColumnSpec(key: 'interfaceType', label: 'Type', allowedValues: ['Physical', 'Contractual', 'Organizational', 'Technical', 'Procedural'], defaultValue: 'Physical', sampleValue: 'Physical'),
 CsvColumnSpec(key: 'partyA', label: 'Party A', required: true, sampleValue: 'Contractor A'),
 CsvColumnSpec(key: 'partyB', label: 'Party B', required: true, sampleValue: 'Contractor B'),
 CsvColumnSpec(key: 'status', label: 'Status', allowedValues: ['Active', 'Pending', 'Closed', 'Resolved'], defaultValue: 'Active', sampleValue: 'Active'),
 CsvColumnSpec(key: 'frequency', label: 'Frequency', allowedValues: ['Daily', 'Weekly', 'Bi-weekly', 'Monthly', 'Quarterly', 'As Needed'], defaultValue: 'Daily', sampleValue: 'Weekly'),
 CsvColumnSpec(key: 'comments', label: 'Comments', sampleValue: 'Coordinate schedule'),
 ],
 onImport: (rows) async {
 final projectId = _InterfaceRegisterTable._getProjectIdStatic(context);
 if (projectId == null) return;
 var imported = 0;
 for (final row in rows) {
 try {
 await ExecutionService.createInterfaceRegister(
 projectId: projectId,
 interfaceId: row['interfaceId'] ?? '',
 interfaceName: row['interfaceName'] ?? '',
 interfaceType: row['interfaceType']?.isNotEmpty == true ? row['interfaceType']! : 'Physical',
 partyA: row['partyA'] ?? '',
 partyB: row['partyB'] ?? '',
 status: row['status']?.isNotEmpty == true ? row['status']! : 'Active',
 frequency: row['frequency']?.isNotEmpty == true ? row['frequency']! : 'Daily',
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
 SnackBar(content: Text('Imported $imported interface entr(ies) successfully')),
 );
 }
 },
 ),
 const SizedBox(width: 12),
 AddRowButton(
 onPressed: () => _InterfaceRegisterTable.showAddDialog(context)),
 ],
 ),
 ),
 const SizedBox(height: 44),
 if (isMobile)
 _MobileInterfaceManagementActions()
 else
 const _DesktopInterfaceManagementActions(),
 ],
 );
 }
}

class _InterfaceRegisterTable extends StatelessWidget {
 const _InterfaceRegisterTable();

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
 _showInterfaceDialog(context, null, projectId);
 }

 static void showEditDialog(
 BuildContext context, InterfaceRegisterModel entry) {
 final projectId = _getProjectIdStatic(context);
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No project selected. Please open a project first.')),
 );
 return;
 }
 _showInterfaceDialog(context, entry, projectId);
 }

 static void showDeleteDialog(
 BuildContext context, InterfaceRegisterModel entry) {
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
 title: const Text('Delete Interface Entry'),
 content: Text(
 'Are you sure you want to delete "${entry.interfaceName}"? This action cannot be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () async {
 try {
 await ExecutionService.deleteInterfaceRegister(
 projectId: projectId, registerId: entry.id);
 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Interface entry deleted successfully')),
 );
 }
 } catch (e) {
 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Error deleting interface entry: $e')),
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

 static void _showInterfaceDialog(
 BuildContext context, InterfaceRegisterModel? entry, String projectId) {
 final isEdit = entry != null;
 final interfaceIdController =
 TextEditingController(text: entry?.interfaceId ?? '');
 final interfaceNameController =
 TextEditingController(text: entry?.interfaceName ?? '');
 String interfaceType = entry?.interfaceType ?? 'Physical';
 final partyAController = TextEditingController(text: entry?.partyA ?? '');
 final partyBController = TextEditingController(text: entry?.partyB ?? '');
 String status = entry?.status ?? 'Active';
 String frequency = entry?.frequency ?? 'Daily';
 final commentsController =
 TextEditingController(text: entry?.comments ?? '');

 const interfaceTypes = [
 'Physical',
 'Contractual',
 'Organizational',
 'Technical',
 'Procedural'
 ];
 const statuses = ['Active', 'Pending', 'Closed', 'Resolved'];
 const frequencies = [
 'Daily',
 'Weekly',
 'Bi-weekly',
 'Monthly',
 'Quarterly',
 'As Needed'
 ];

 showDialog(
 context: context,
 builder: (context) => StatefulBuilder(
 builder: (context, setState) => AlertDialog(
 title:
 Text(isEdit ? 'Edit Interface Entry' : 'Add New Interface Entry'),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: interfaceIdController,
 decoration:
 const InputDecoration(labelText: 'Interface ID *')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: interfaceNameController,
 decoration:
 const InputDecoration(labelText: 'Interface Name *')),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: interfaceType,
 decoration: const InputDecoration(labelText: 'Type *'),
 items: interfaceTypes
 .map((t) => DropdownMenuItem(value: t, child: Text(t)))
 .toList(),
 onChanged: (v) =>
 setState(() => interfaceType = v ?? 'Physical'),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: partyAController,
 decoration: const InputDecoration(labelText: 'Party A *')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: partyBController,
 decoration: const InputDecoration(labelText: 'Party B *')),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: status,
 decoration: const InputDecoration(labelText: 'Status *'),
 items: statuses
 .map((s) => DropdownMenuItem(value: s, child: Text(s)))
 .toList(),
 onChanged: (v) => setState(() => status = v ?? 'Active'),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: frequency,
 decoration: const InputDecoration(labelText: 'Frequency *'),
 items: frequencies
 .map((f) => DropdownMenuItem(value: f, child: Text(f)))
 .toList(),
 onChanged: (v) => setState(() => frequency = v ?? 'Daily'),
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
 if (interfaceIdController.text.isEmpty ||
 interfaceNameController.text.isEmpty ||
 partyAController.text.isEmpty ||
 partyBController.text.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Please fill in all required fields')),
 );
 return;
 }

 try {
 if (isEdit) {
 await ExecutionService.updateInterfaceRegister(
 projectId: projectId,
 registerId: entry.id,
 interfaceId: interfaceIdController.text,
 interfaceName: interfaceNameController.text,
 interfaceType: interfaceType,
 partyA: partyAController.text,
 partyB: partyBController.text,
 status: status,
 frequency: frequency,
 comments: commentsController.text,
 );
 } else {
 await ExecutionService.createInterfaceRegister(
 projectId: projectId,
 interfaceId: interfaceIdController.text,
 interfaceName: interfaceNameController.text,
 interfaceType: interfaceType,
 partyA: partyAController.text,
 partyB: partyBController.text,
 status: status,
 frequency: frequency,
 comments: commentsController.text,
 );
 }

 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(isEdit
 ? 'Interface entry updated successfully'
 : 'Interface entry added successfully')),
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

 return StreamBuilder<List<InterfaceRegisterModel>>(
 stream: ExecutionService.streamInterfaceRegister(projectId),
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
 child: Text('Error loading interface entries: ${snapshot.error}',
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
 1: FixedColumnWidth(120),
 2: FixedColumnWidth(140),
 3: FixedColumnWidth(110),
 4: FixedColumnWidth(110),
 5: FixedColumnWidth(110),
 6: FixedColumnWidth(100),
 7: FixedColumnWidth(100),
 8: FixedColumnWidth(150),
 9: FixedColumnWidth(100),
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
 buildCell('Interface ID', isHeader: true),
 buildCell('Name', isHeader: true),
 buildCell('Type', isHeader: true),
 buildCell('Party A', isHeader: true),
 buildCell('Party B', isHeader: true),
 buildCell('Status', isHeader: true),
 buildCell('Frequency', isHeader: true),
 buildCell('Comments', isHeader: true),
 buildCell('Actions',
 isHeader: true, align: TextAlign.center),
 ],
 ),
 if (entries.isEmpty)
 TableRow(
 children: [
 buildCell('', align: TextAlign.center),
 buildCell('No interface entries added yet',
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
 buildCell(item.interfaceId),
 buildCell(item.interfaceName),
 buildCell(item.interfaceType),
 buildCell(item.partyA),
 buildCell(item.partyB),
 buildCell(item.status),
 buildCell(item.frequency),
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

class _DesktopInterfaceManagementActions extends StatelessWidget {
 const _DesktopInterfaceManagementActions();

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
 'Define clear ownership for each interface to prevent coordination gaps between parties.',
 ),
 ),
 ),
 ),
 const SizedBox(width: 24),
 YellowActionButton(
 label: 'Next',
 onPressed: () => ExecutionPlanCommunicationPlanScreen.open(context),
 ),
 ],
 );
 }
}

class _MobileInterfaceManagementActions extends StatelessWidget {
 const _MobileInterfaceManagementActions();

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 const InfoBadge(),
 const SizedBox(height: 20),
 const AiTipCard(
 text:
 'Define clear ownership for each interface to prevent coordination gaps between parties.',
 ),
 const SizedBox(height: 20),
 YellowActionButton(
 label: 'Next',
 onPressed: () => ExecutionPlanCommunicationPlanScreen.open(context),
 ),
 ],
 );
 }
}
