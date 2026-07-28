import 'dart:async';
import 'package:ndu_project/screens/execution_plan_details_screen.dart';
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
 screenTitle: 'Execution Plan Solutions',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['execution_plan_solutions_screen'] ?? 'No data recorded.'),
 ],
 );
}

class ExecutionPlanSolutionsScreen extends StatefulWidget {
  const ExecutionPlanSolutionsScreen({super.key});

  static void open(BuildContext context) {
  Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const ExecutionPlanSolutionsScreen()),
  );
  }

  @override
  State<ExecutionPlanSolutionsScreen> createState() => _ExecutionPlanSolutionsScreenState();
}

class _ExecutionPlanSolutionsScreenState extends State<ExecutionPlanSolutionsScreen> {
  @override
  void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) => _autoGenerateNotesIfNeeded());
  }

  Future<void> _autoGenerateNotesIfNeeded() async {
  if (!mounted) return;
  final provider = ProjectDataInherited.maybeOf(context);
  if (provider == null) return;
  final data = provider.projectData;
  const noteKey = 'execution_plan_strategy';
  const sectionTitle = 'Execution Plan Strategy';
  final existing = data.planningNotes[noteKey] ?? '';
  if (existing.trim().isNotEmpty) return;

  final ctx = ProjectDataHelper.buildExecutivePlanContext(data, sectionLabel: sectionTitle);
  if (ctx.trim().isEmpty) return;

  try {
  final ai = OpenAiServiceSecure();
  final result = await ai.generateExecutionPlanSectionFields(
  section: sectionTitle,
  context: ctx,
  fields: {'notes': 'Execution strategy notes capturing approach, sequence of activities, and key execution decisions'},
  );
  if (!mounted) return;
  if (result.containsKey('notes') && result['notes']!.trim().isNotEmpty) {
  await ProjectDataHelper.updateAndSave(
  context: context,
  checkpoint: 'execution_plan_strategy',
  showSnackbar: false,
  dataUpdater: (data) {
  final notes = Map<String, String>.from(data.planningNotes);
  notes[noteKey] = result['notes']!;
  return data.copyWith(planningNotes: notes);
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
  activeItemLabel: 'Executive Plan Strategy',
  backgroundColor: Colors.white,
  floatingActionButton: const KazAiChatBubble(positioned: false),
  body: SingleChildScrollView(
  padding: EdgeInsets.symmetric(
  horizontal: horizontalPadding, vertical: 32),
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  ExecutionPlanHeader(
  onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'execution_plan_strategy'),
  onNext: () => PlanningPhaseNavigation.goToNext(context, 'execution_plan_strategy'), onExportPdf: () => _exportPdf(context)),
  const SizedBox(height: 32),
  const SectionIntro(title: 'Executive Plan Strategy'),
  const SizedBox(height: 28),
  ExecutionPlanForm(
  title: 'Executive Plan Strategy',
  hintText: 'Input your notes here...',
  noteKey: 'execution_plan_strategy',
  ),
  const SizedBox(height: 28),
  const _ExecutionPlanTable(),
  const SizedBox(height: 20),
  Align(
  alignment: Alignment.centerRight,
  child: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
  CsvTableImportButton(
  tableTitle: 'Execution Tools',
  columns: [
  CsvColumnSpec(key: 'tool', label: 'Tool', required: true, sampleValue: 'Hammer Drill'),
  CsvColumnSpec(key: 'description', label: 'Description', required: true, sampleValue: 'Heavy-duty drilling tool'),
  CsvColumnSpec(key: 'source', label: 'Source', required: true, sampleValue: 'Vendor A'),
  CsvColumnSpec(key: 'comments', label: 'Comments', required: true, sampleValue: 'Required for Phase 1'),
  ],
  onImport: (rows) async {
  final projectId = _ExecutionPlanTable._getProjectIdStatic(context);
  if (projectId == null) return;
  var imported = 0;
  for (final row in rows) {
  try {
  await ExecutionService.createTool(
  projectId: projectId,
  tool: row['tool'] ?? '',
  description: row['description'] ?? '',
  source: row['source'] ?? '',
  cost: null,
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
  SnackBar(content: Text('Imported $imported tool(s) successfully')),
  );
  }
  },
  ),
  const SizedBox(width: 12),
  AddSolutionButton(
  onPressed: () =>
  _ExecutionPlanTable.showAddDialog(context)),
  ],
  ),
  ),
  const SizedBox(height: 44),
  Wrap(
  spacing: 20,
  runSpacing: 16,
  alignment: WrapAlignment.spaceBetween,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
  const InfoBadge(),
  Wrap(
  spacing: 16,
  runSpacing: 12,
  crossAxisAlignment: WrapCrossAlignment.center,
  alignment: WrapAlignment.end,
  children: [
  const AiTipCard(),
  YellowActionButton(
  label: 'Next',
  onPressed: () =>
  ExecutionPlanDetailsScreen.open(context),
  ),
  ],
  ),
  ],
  ),
  const SizedBox(height: 56),
  ],
  ),
  ),
  );
  }
}

// _TeamSummaryCard removed — hardcoded data (StackOne / 12 Members) was misleading.
// To restore: connect to real Organization Plan → Staffing Plan data.

class _ExecutionPlanTable extends StatelessWidget {
 const _ExecutionPlanTable();

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
 await ExecutionService.deleteTool(
 projectId: projectId, toolId: tool.id);
 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Tool deleted successfully')),
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
 await ExecutionService.updateTool(
 projectId: projectId,
 toolId: tool.id,
 tool: toolController.text,
 description: descriptionController.text,
 source: sourceController.text,
 cost: costController.text.isEmpty
 ? null
 : costController.text,
 comments: commentsController.text,
 );
 } else {
 await ExecutionService.createTool(
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
 stream: ExecutionService.streamTools(projectId),
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
 buildCell('Source', isHeader: true),
 buildCell('Comments', isHeader: true),
 buildCell('Actions', isHeader: true, align: TextAlign.center),
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
 buildCell(tool.source),
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



