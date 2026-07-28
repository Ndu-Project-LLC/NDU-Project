import 'dart:async';
import 'package:ndu_project/screens/execution_enabling_work_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/execution_plan_shared.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/execution_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
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
 screenTitle: 'Execution Plan Details',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['execution_plan_details_screen'] ?? 'No data recorded.'),
 ],
 );
}

class ExecutionPlanDetailsScreen extends StatefulWidget {
  const ExecutionPlanDetailsScreen({
  super.key,
  this.activeItemLabel = 'Execution Plan Details',
  this.showPlanDetails = true,
  this.showEarlyWorks = false,
  });

  final String activeItemLabel;
  final bool showPlanDetails;
  final bool showEarlyWorks;

  static void open(BuildContext context) {
  Navigator.of(context).push(
  MaterialPageRoute(
  builder: (_) => const ExecutionPlanDetailsScreen(
  activeItemLabel: 'Execution Plan Details',
  showPlanDetails: true,
  showEarlyWorks: false,
  ),
  ),
  );
  }

  static void openEarlyWorks(BuildContext context) {
  Navigator.of(context).push(
  MaterialPageRoute(
  builder: (_) => const ExecutionPlanDetailsScreen(
  activeItemLabel: 'Execution Early Works',
  showPlanDetails: false,
  showEarlyWorks: true,
  ),
  ),
  );
  }

  @override
  State<ExecutionPlanDetailsScreen> createState() => _ExecutionPlanDetailsScreenState();
}

class _ExecutionPlanDetailsScreenState extends State<ExecutionPlanDetailsScreen> {
  @override
  void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) => _autoGenerateNotesIfNeeded());
  }

  Future<void> _autoGenerateNotesIfNeeded() async {
  if (!mounted) return;
  final provider = ProjectDataInherited.maybeOf(context);
  if (provider == null) return;

  if (widget.showPlanDetails) {
  await _generateSection(
  noteKey: 'execution_plan_details',
  sectionTitle: 'Execution Plan Details',
  );
  }

  if (widget.showEarlyWorks) {
  await _generateSection(
  noteKey: 'execution_early_works',
  sectionTitle: 'Execution Early Works',
  );
  }
  }

  Future<void> _generateSection({
  required String noteKey,
  required String sectionTitle,
  }) async {
    if (!mounted) return;
    final provider = ProjectDataInherited.maybeOf(context);
    if (provider == null) return;
    final data = provider.projectData;
    final existing = data.planningNotes[noteKey] ?? '';
    if (existing.trim().isNotEmpty) return;

    final ctx = ProjectDataHelper.buildExecutivePlanContext(data, sectionLabel: sectionTitle);
    if (ctx.trim().isEmpty) return;

    try {
      final ai = OpenAiServiceSecure();
      final result = await ai.generateExecutionPlanSectionFields(
        section: sectionTitle,
        context: ctx,
        fields: {'notes': 'Detailed notes for $sectionTitle'},
      );
      if (!mounted) return;
      if (result.containsKey('notes') && result['notes']!.trim().isNotEmpty) {
        await ProjectDataHelper.updateAndSave(
          context: context,
          checkpoint: noteKey,
          showSnackbar: false,
          dataUpdater: (d) {
            final notes = Map<String, String>.from(d.planningNotes);
            notes[noteKey] = result['notes']!;
            return d.copyWith(planningNotes: notes);
          },
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
  final bool isMobile = AppBreakpoints.isMobile(context);
  final double horizontalPadding = isMobile ? 20 : 40;

  return ResponsiveScaffold(
  activeItemLabel: widget.activeItemLabel,
  backgroundColor: Colors.white,
  floatingActionButton: const KazAiChatBubble(positioned: false),
  body: SingleChildScrollView(
  padding: EdgeInsets.symmetric(
  horizontal: horizontalPadding, vertical: 32),
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  ExecutionPlanHeader(
  onBack: () => PlanningPhaseNavigation.goToPrevious(context, widget.showEarlyWorks ? 'execution_early_works' : 'execution_plan_details'),
  onNext: () => PlanningPhaseNavigation.goToNext(context, widget.showEarlyWorks ? 'execution_early_works' : 'execution_plan_details'),
  onExportPdf: () => _exportPdf(context)),
  const SizedBox(height: 32),
  if (widget.showPlanDetails) ...[
  ExecutionPlanForm(
  title: 'Execution Plan Details',
  hintText: 'Input your notes here...',
  noteKey: 'execution_plan_details',
  ),
  const SizedBox(height: 40),
  ],
  if (widget.showPlanDetails && !widget.showEarlyWorks) ...[
  Align(
  alignment: Alignment.centerRight,
  child: Wrap(
  spacing: 16,
  runSpacing: 12,
  crossAxisAlignment: WrapCrossAlignment.center,
  alignment: WrapAlignment.end,
  children: [
  const InfoBadge(),
  const AiTipCard(),
  YellowActionButton(
  label: 'Next',
  onPressed: () =>
  ExecutionPlanDetailsScreen.openEarlyWorks(
  context),
  ),
  ],
  ),
  ),
  const SizedBox(height: 56),
  ],
  if (widget.showEarlyWorks) ...[
  const ExecutionPlanForm(
  title: 'Execution Early Works',
  hintText:
  'Outline early works scope, sequencing, and handoffs.',
  noteKey: 'execution_early_works',
  ),
  const SizedBox(height: 32),
  const _EarlyWorksSection(),
  const SizedBox(height: 56),
  ],
  ],
  ),
  ),
  );
  }
}

class _EarlyWorksSection extends StatelessWidget {
 const _EarlyWorksSection();

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Early Works',
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 28),
 const _EarlyWorksTable(),
 const SizedBox(height: 20),
 Align(
 alignment: Alignment.centerRight,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 tableTitle: 'Early Works',
 columns: [
 CsvColumnSpec(key: 'tool', label: 'Execution Tool', required: true, sampleValue: 'Excavator'),
 CsvColumnSpec(key: 'description', label: 'Description', required: true, sampleValue: 'Site preparation work'),
 CsvColumnSpec(key: 'cost', label: 'Cost', sampleValue: '5000'),
 CsvColumnSpec(key: 'comments', label: 'Comments', required: true, sampleValue: 'Must complete before Phase 2'),
 ],
 onImport: (rows) async {
 final projectId = _EarlyWorksTable._getProjectIdStatic(context);
 if (projectId == null) return;
 var imported = 0;
 for (final row in rows) {
 try {
 await ExecutionService.createEarlyWork(
 projectId: projectId,
 tool: row['tool'] ?? '',
 description: row['description'] ?? '',
 source: '',
 cost: (row['cost'] ?? '').isEmpty ? null : row['cost'],
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
 SnackBar(content: Text('Imported $imported early work(s) successfully')),
 );
 }
 },
 ),
 const SizedBox(width: 12),
 AddSolutionButton(
 onPressed: () => _EarlyWorksTable.showAddDialog(context)),
 ],
 ),
 ),
 const SizedBox(height: 44),
 if (isMobile)
 _MobileEarlyWorksActions()
 else
 const _DesktopEarlyWorksActions(),
 ],
 );
 }
}

class _EarlyWorksTable extends StatelessWidget {
 const _EarlyWorksTable();

 String? _getProjectId(BuildContext context) {
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
 _showToolDialog(context, null, projectId);
 }

 static void showEditDialog(BuildContext context, ExecutionToolModel tool) {
 final projectId = _getProjectIdStatic(context);
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No project selected. Please open a project first.')),
 );
 return;
 }
 _showToolDialog(context, tool, projectId);
 }

 static void showDeleteDialog(BuildContext context, ExecutionToolModel tool) {
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
 title: const Text('Delete Tool'),
 content: Text(
 'Are you sure you want to delete "${tool.tool}"? This action cannot be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () async {
 try {
 await ExecutionService.deleteEarlyWork(
 projectId: projectId, workId: tool.id);
 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Early work item deleted successfully')),
 );
 }
 } catch (e) {
 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error deleting tool: $e')),
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

 static String? _getProjectIdStatic(BuildContext context) {
 try {
 final provider = ProjectDataInherited.maybeOf(context);
 return provider?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 static void _showToolDialog(
 BuildContext context, ExecutionToolModel? tool, String projectId) {
 final isEdit = tool != null;
 final toolController = TextEditingController(text: tool?.tool ?? '');
 final descriptionController =
 TextEditingController(text: tool?.description ?? '');
 final sourceController = TextEditingController(text: tool?.source ?? '');
 final costController = TextEditingController(text: tool?.cost ?? '');
 final commentsController =
 TextEditingController(text: tool?.comments ?? '');

 showDialog(
 context: context,
 builder: (context) => AlertDialog(
 title: Text(isEdit ? 'Edit Tool' : 'Add New Tool'),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: toolController,
 decoration: const InputDecoration(labelText: 'Tool *')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: descriptionController,
 decoration: const InputDecoration(labelText: 'Description *'),
 maxLines: 2),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: sourceController,
 decoration: const InputDecoration(labelText: 'Source *')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: costController,
 decoration: const InputDecoration(
 labelText: 'Cost', hintText: 'Optional')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: commentsController,
 decoration: const InputDecoration(labelText: 'Comments *'),
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
 if (toolController.text.isEmpty ||
 descriptionController.text.isEmpty ||
 sourceController.text.isEmpty ||
 commentsController.text.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Please fill in all required fields')),
 );
 return;
 }

 try {
 if (isEdit) {
 await ExecutionService.updateEarlyWork(
 projectId: projectId,
 workId: tool.id,
 tool: toolController.text,
 description: descriptionController.text,
 source: sourceController.text,
 cost: costController.text.isEmpty
 ? null
 : costController.text,
 comments: commentsController.text,
 );
 } else {
 await ExecutionService.createEarlyWork(
 projectId: projectId,
 tool: toolController.text,
 description: descriptionController.text,
 source: sourceController.text,
 cost: costController.text.isEmpty
 ? null
 : costController.text,
 comments: commentsController.text,
 );
 }

 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(isEdit
 ? 'Tool updated successfully'
 : 'Tool added successfully')),
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

 return StreamBuilder<List<ExecutionToolModel>>(
 stream: ExecutionService.streamEarlyWorks(projectId),
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
 child: Text('Error loading tools: ${snapshot.error}',
 style: const TextStyle(color: Colors.red)),
 ),
 );
 }

 final tools = snapshot.data ?? [];

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
 child: Table(
 columnWidths: const {
 0: FixedColumnWidth(70),
 1: FlexColumnWidth(2),
 2: FlexColumnWidth(3),
 3: FlexColumnWidth(2),
 4: FlexColumnWidth(2),
 5: FixedColumnWidth(100),
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
 buildCell('Execution Tool', isHeader: true),
 buildCell('Description', isHeader: true),
 buildCell('Cost', isHeader: true),
 buildCell('Comments', isHeader: true),
 buildCell('Actions', isHeader: true),
 ],
 ),
 if (tools.isEmpty)
 TableRow(
 children: [
 buildCell('', align: TextAlign.center),
 buildCell('No tools added yet',
 style: const TextStyle(
 color: Color(0xFF64748B),
 fontStyle: FontStyle.italic)),
 buildCell(''),
 buildCell(''),
 buildCell(''),
 buildCell(''),
 ],
 )
 else
 ...tools.asMap().entries.map((entry) {
 final index = entry.key;
 final tool = entry.value;
 return TableRow(
 children: [
 buildCell('${index + 1}', align: TextAlign.center),
 buildCell(tool.tool),
 buildCell(tool.description),
 buildCell(tool.cost ?? 'N/A'),
 buildCell(tool.comments),
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
 onPressed: () => showEditDialog(context, tool),
 tooltip: 'Edit',
 ),
 IconButton(
 icon: const Icon(Icons.delete,
 size: 18, color: Color(0xFFEF4444)),
 onPressed: () => showDeleteDialog(context, tool),
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
 );
 },
 );
 }
}

class _DesktopEarlyWorksActions extends StatelessWidget {
 const _DesktopEarlyWorksActions();

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
 child: const AiTipCard(),
 ),
 ),
 ),
 const SizedBox(width: 24),
 YellowActionButton(
 label: 'Next',
 onPressed: () => ExecutionEnablingWorkPlanScreen.open(context),
 ),
 ],
 );
 }
}

class _MobileEarlyWorksActions extends StatelessWidget {
 const _MobileEarlyWorksActions();

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 const InfoBadge(),
 const SizedBox(height: 20),
 const AiTipCard(),
 const SizedBox(height: 20),
 YellowActionButton(
 label: 'Next',
 onPressed: () => ExecutionEnablingWorkPlanScreen.open(context),
 ),
 ],
 );
 }
}

