import 'dart:async';
import 'package:ndu_project/screens/execution_issue_management_screen.dart';
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
 screenTitle: 'Enabling Work Plan',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['execution_enabling_work_plan_screen'] ?? 'No data recorded.'),
 ],
 );
}

class ExecutionEnablingWorkPlanScreen extends StatefulWidget {
  const ExecutionEnablingWorkPlanScreen({super.key});

  static void open(BuildContext context) {
  Navigator.of(context).push(
  MaterialPageRoute(
  builder: (_) => const ExecutionEnablingWorkPlanScreen()),
  );
  }

  @override
  State<ExecutionEnablingWorkPlanScreen> createState() => _ExecutionEnablingWorkPlanScreenState();
}

class _ExecutionEnablingWorkPlanScreenState extends State<ExecutionEnablingWorkPlanScreen> {
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
  const noteKey = 'execution_enabling_work_plan';
  const sectionTitle = 'Execution Enabling Work Plan';
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
  checkpoint: 'execution_enabling_work_plan',
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
  activeItemLabel: 'Execution Enabling Work Plan',
  backgroundColor: Colors.white,
  floatingActionButton: const KazAiChatBubble(positioned: false),
  body: SingleChildScrollView(
  padding: EdgeInsets.symmetric(
  horizontal: horizontalPadding, vertical: 32),
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  ExecutionPlanHeader(
  onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'execution_enabling_work_plan'),
  onNext: () => PlanningPhaseNavigation.goToNext(context, 'execution_enabling_work_plan'), onExportPdf: () => _exportPdf(context)),
  const SizedBox(height: 32),
  const SectionIntro(title: 'Execution Enabling Work Plan'),
  const SizedBox(height: 24),
  const ExecutionPlanForm(
  title: 'Execution Enabling Work Plan',
  hintText:
  'Capture enabling works, dependencies, and resourcing needs.',
  noteKey: 'execution_enabling_work_plan',
  ),
  const SizedBox(height: 32),
  const _EnablingWorksPlanSection(),
  const SizedBox(height: 56),
  ],
  ),
  ),
  );
  }
}

class _EnablingWorksPlanSection extends StatelessWidget {
 const _EnablingWorksPlanSection();

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Enabling Works Plan',
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 28),
 const _EnablingWorksPlanTable(),
 const SizedBox(height: 20),
 Align(
 alignment: Alignment.centerRight,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 tableTitle: 'Enabling Works',
 columns: [
 CsvColumnSpec(key: 'aspect', label: 'Enabling Work Aspect', required: true, sampleValue: 'Site Access'),
 CsvColumnSpec(key: 'description', label: 'Description', required: true, sampleValue: 'Road construction to site'),
 CsvColumnSpec(key: 'duration', label: 'Duration', required: true, sampleValue: '2 weeks'),
 CsvColumnSpec(key: 'cost', label: 'Cost', required: true, sampleValue: '10000'),
 CsvColumnSpec(key: 'comments', label: 'Comments', required: true, sampleValue: 'Must be completed first'),
 ],
 onImport: (rows) async {
 final projectId = _EnablingWorksPlanTable._getProjectIdStatic(context);
 if (projectId == null) return;
 var imported = 0;
 for (final row in rows) {
 try {
 await ExecutionService.createEnablingWork(
 projectId: projectId,
 aspect: row['aspect'] ?? '',
 description: row['description'] ?? '',
 duration: row['duration'] ?? '',
 cost: row['cost'] ?? '',
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
 SnackBar(content: Text('Imported $imported enabling work(s) successfully')),
 );
 }
 },
 ),
 const SizedBox(width: 12),
 AddRowButton(
 onPressed: () => _EnablingWorksPlanTable.showAddDialog(context)),
 ],
 ),
 ),
 const SizedBox(height: 44),
 if (isMobile)
 _MobileEnablingWorksActions()
 else
 const _DesktopEnablingWorksActions(),
 ],
 );
 }
}

class _EnablingWorksPlanTable extends StatelessWidget {
 const _EnablingWorksPlanTable();

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
 _showEnablingWorkDialog(context, null, projectId);
 }

 static void showEditDialog(
 BuildContext context, ExecutionEnablingWorkModel work) {
 final projectId = _getProjectIdStatic(context);
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No project selected. Please open a project first.')),
 );
 return;
 }
 _showEnablingWorkDialog(context, work, projectId);
 }

 static void showDeleteDialog(
 BuildContext context, ExecutionEnablingWorkModel work) {
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
 title: const Text('Delete Enabling Work'),
 content: Text(
 'Are you sure you want to delete "${work.aspect}"? This action cannot be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () async {
 try {
 await ExecutionService.deleteEnablingWork(
 projectId: projectId, workId: work.id);
 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Enabling work deleted successfully')),
 );
 }
 } catch (e) {
 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error deleting enabling work: $e')),
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

 static void _showEnablingWorkDialog(BuildContext context,
 ExecutionEnablingWorkModel? work, String projectId) {
 final isEdit = work != null;
 final aspectController = TextEditingController(text: work?.aspect ?? '');
 final descriptionController =
 TextEditingController(text: work?.description ?? '');
 final durationController =
 TextEditingController(text: work?.duration ?? '');
 final costController = TextEditingController(text: work?.cost ?? '');
 final commentsController =
 TextEditingController(text: work?.comments ?? '');

 showDialog(
 context: context,
 builder: (context) => AlertDialog(
 title: Text(isEdit ? 'Edit Enabling Work' : 'Add New Enabling Work'),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: aspectController,
 decoration: const InputDecoration(labelText: 'Aspect *')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: descriptionController,
 decoration: const InputDecoration(labelText: 'Description *'),
 maxLines: 2),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: durationController,
 decoration: const InputDecoration(labelText: 'Duration *')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: costController,
 decoration: const InputDecoration(labelText: 'Cost *')),
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
 if (aspectController.text.isEmpty ||
 descriptionController.text.isEmpty ||
 durationController.text.isEmpty ||
 costController.text.isEmpty ||
 commentsController.text.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Please fill in all required fields')),
 );
 return;
 }

 try {
 if (isEdit) {
 await ExecutionService.updateEnablingWork(
 projectId: projectId,
 workId: work.id,
 aspect: aspectController.text,
 description: descriptionController.text,
 duration: durationController.text,
 cost: costController.text,
 comments: commentsController.text,
 );
 } else {
 await ExecutionService.createEnablingWork(
 projectId: projectId,
 aspect: aspectController.text,
 description: descriptionController.text,
 duration: durationController.text,
 cost: costController.text,
 comments: commentsController.text,
 );
 }

 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(isEdit
 ? 'Enabling work updated successfully'
 : 'Enabling work added successfully')),
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

 return StreamBuilder<List<ExecutionEnablingWorkModel>>(
 stream: ExecutionService.streamEnablingWorks(projectId),
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
 child: Text('Error loading enabling works: ${snapshot.error}',
 style: const TextStyle(color: Colors.red)),
 ),
 );
 }

 final works = snapshot.data ?? [];

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
 2: FlexColumnWidth(2.5),
 3: FlexColumnWidth(2),
 4: FlexColumnWidth(2),
 5: FlexColumnWidth(2),
 6: FixedColumnWidth(100),
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
 buildCell('Enabling work Aspect', isHeader: true),
 buildCell('Description', isHeader: true),
 buildCell('Duration', isHeader: true),
 buildCell('Cost', isHeader: true),
 buildCell('Comments', isHeader: true),
 buildCell('Actions', isHeader: true, align: TextAlign.center),
 ],
 ),
 if (works.isEmpty)
 TableRow(
 children: [
 buildCell('', align: TextAlign.center),
 buildCell('No enabling works added yet',
 style: const TextStyle(
 color: Color(0xFF64748B),
 fontStyle: FontStyle.italic)),
 buildCell(''),
 buildCell(''),
 buildCell(''),
 buildCell(''),
 buildCell(''),
 ],
 )
 else
 ...works.asMap().entries.map((entry) {
 final index = entry.key;
 final work = entry.value;
 return TableRow(
 children: [
 buildCell('${index + 1}', align: TextAlign.center),
 buildCell(work.aspect),
 buildCell(work.description),
 buildCell(work.duration),
 buildCell(work.cost),
 buildCell(work.comments),
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
 onPressed: () => showEditDialog(context, work),
 tooltip: 'Edit',
 ),
 IconButton(
 icon: const Icon(Icons.delete,
 size: 18, color: Color(0xFFEF4444)),
 onPressed: () => showDeleteDialog(context, work),
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

class _DesktopEnablingWorksActions extends StatelessWidget {
 const _DesktopEnablingWorksActions();

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
 onPressed: () => ExecutionIssueManagementScreen.open(context),
 ),
 ],
 );
 }
}

class _MobileEnablingWorksActions extends StatelessWidget {
 const _MobileEnablingWorksActions();

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
 onPressed: () => ExecutionIssueManagementScreen.open(context),
 ),
 ],
 );
 }
}

