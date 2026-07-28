import 'package:ndu_project/screens/execution_plan_best_practices_screen.dart';
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
 screenTitle: 'Lessons Learned',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['execution_plan_lessons_learned_screen'] ?? 'No data recorded.'),
 ],
 );
}

class ExecutionPlanLessonsLearnedScreen extends StatelessWidget {
 const ExecutionPlanLessonsLearnedScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const ExecutionPlanLessonsLearnedScreen()),
 );
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 20 : 40;

 return ResponsiveScaffold(
 activeItemLabel: 'Execution Lessons Learned',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 ExecutionPlanHeader(
 onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'execution_plan_lessons_learned'),
 onNext: () => PlanningPhaseNavigation.goToNext(context, 'execution_plan_lessons_learned'), onExportPdf: () => _exportPdf(context)),
  const SizedBox(height: 24),
 const CrossReferenceNote(standalonePage: 'Lessons Learned'),
 const SizedBox(height: 24),
 const ExecutionPlanForm(
 title: 'Execution Lessons Learned',
 hintText:
 'Capture lessons learned and how they influence execution.',
 noteKey: 'execution_lessons_learned',
 ),
 const SizedBox(height: 32),
 const _LessonsLearnedSection(),
 const SizedBox(height: 56),
 ],
 ),
 ),
 );
 }
}

class _LessonsLearnedSection extends StatelessWidget {
 const _LessonsLearnedSection();

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Lessons Learned',
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 28),
 const LessonsLearnedTable(),
 const SizedBox(height: 20),
 Align(
 alignment: Alignment.centerRight,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 tableTitle: 'Lessons Learned',
 columns: [
 CsvColumnSpec(key: 'issueTopic', label: 'Topic', required: true, sampleValue: 'Late vendor delivery'),
 CsvColumnSpec(key: 'description', label: 'Description', required: true, sampleValue: 'Vendor delivered 2 weeks late'),
 CsvColumnSpec(key: 'discipline', label: 'Discipline', required: true, sampleValue: 'Procurement'),
 CsvColumnSpec(key: 'impacted', label: 'Impacted', sampleValue: 'Schedule'),
 CsvColumnSpec(key: 'raisedBy', label: 'Raised By', required: true, sampleValue: 'Team Lead'),
 CsvColumnSpec(key: 'scheduleImpact', label: 'Schedule Impact', required: true, sampleValue: '2 weeks delay'),
 CsvColumnSpec(key: 'costImpact', label: 'Cost Impact', required: true, sampleValue: '\$5,000'),
 CsvColumnSpec(key: 'approved', label: 'Approved', allowedValues: ['Yes', 'No'], defaultValue: 'No', sampleValue: 'No'),
 CsvColumnSpec(key: 'comments', label: 'Comments', required: true, sampleValue: 'Add buffer for future orders'),
 ],
 onImport: (rows) async {
 final projectId = LessonsLearnedTable._getProjectIdStatic(context);
 if (projectId == null) return;
 var imported = 0;
 for (final row in rows) {
 try {
 await ExecutionService.createChangeRequest(
 projectId: projectId,
 issueTopic: row['issueTopic'] ?? '',
 description: row['description'] ?? '',
 discipline: row['discipline'] ?? '',
 raisedBy: row['raisedBy'] ?? '',
 scheduleImpact: row['scheduleImpact'] ?? '',
 costImpact: row['costImpact'] ?? '',
 approved: (row['approved'] ?? '').toLowerCase() == 'yes',
 comments: row['comments'] ?? '',
 llOrBp: 'LL',
 impacted: (row['impacted'] ?? '').isEmpty ? null : row['impacted'],
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
 SnackBar(content: Text('Imported $imported lesson(s) learned successfully')),
 );
 }
 },
 ),
 const SizedBox(width: 12),
 AddRowButton(
 onPressed: () => LessonsLearnedTable.showAddDialog(context)),
 ],
 ),
 ),
 const SizedBox(height: 44),
 if (isMobile)
 _MobileLessonsLearnedActions()
 else
 const _DesktopLessonsLearnedActions(),
 ],
 );
 }
}

class LessonsLearnedTable extends StatelessWidget {
 const LessonsLearnedTable({super.key});

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
 showChangeRequestDialog(context, null, projectId, 'LL');
 }

 static void showEditDialog(
 BuildContext context, ExecutionIssueModel request) {
 final projectId = _getProjectIdStatic(context);
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No project selected. Please open a project first.')),
 );
 return;
 }
 showChangeRequestDialog(context, request, projectId, 'LL');
 }

 static void showDeleteDialog(
 BuildContext context, ExecutionIssueModel request) {
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
 title: const Text('Delete Lesson Learned'),
 content: Text(
 'Are you sure you want to delete "${request.issueTopic}"? This action cannot be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () async {
 try {
 await ExecutionService.deleteChangeRequest(
 projectId: projectId, requestId: request.id);
 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Lesson learned deleted successfully')),
 );
 }
 } catch (e) {
 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Error deleting lesson learned: $e')),
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

 static void showChangeRequestDialog(BuildContext context,
 ExecutionIssueModel? request, String projectId, String llOrBp) {
 final isEdit = request != null;
 final topicController =
 TextEditingController(text: request?.issueTopic ?? '');
 final descriptionController =
 TextEditingController(text: request?.description ?? '');
 final disciplineController =
 TextEditingController(text: request?.discipline ?? '');
 final raisedByController =
 TextEditingController(text: request?.raisedBy ?? '');
 final scheduleImpactController =
 TextEditingController(text: request?.scheduleImpact ?? '');
 final costImpactController =
 TextEditingController(text: request?.costImpact ?? '');
 final commentsController =
 TextEditingController(text: request?.comments ?? '');
 final impactedController =
 TextEditingController(text: request?.impacted ?? '');
 bool approved = request?.approved ?? false;

 showDialog(
 context: context,
 builder: (context) => StatefulBuilder(
 builder: (context, setState) => AlertDialog(
 title: Text(isEdit
 ? 'Edit ${llOrBp == 'LL' ? 'Lesson Learned' : 'Best Practice'}'
 : 'Add New ${llOrBp == 'LL' ? 'Lesson Learned' : 'Best Practice'}'),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: topicController,
 decoration: const InputDecoration(labelText: 'Topic *')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: descriptionController,
 decoration:
 const InputDecoration(labelText: 'Description *'),
 maxLines: 2),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: disciplineController,
 decoration:
 const InputDecoration(labelText: 'Discipline *')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: impactedController,
 decoration: const InputDecoration(labelText: 'Impacted')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: raisedByController,
 decoration:
 const InputDecoration(labelText: 'Raised By *')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: scheduleImpactController,
 decoration:
 const InputDecoration(labelText: 'Schedule Impact *')),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: costImpactController,
 decoration:
 const InputDecoration(labelText: 'Cost Impact *')),
 const SizedBox(height: 12),
 CheckboxListTile(
 title: const Text('Approved'),
 value: approved,
 onChanged: (value) =>
 setState(() => approved = value ?? false),
 ),
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
 if (topicController.text.isEmpty ||
 descriptionController.text.isEmpty ||
 disciplineController.text.isEmpty ||
 raisedByController.text.isEmpty ||
 scheduleImpactController.text.isEmpty ||
 costImpactController.text.isEmpty ||
 commentsController.text.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Please fill in all required fields')),
 );
 return;
 }

 try {
 if (isEdit) {
 await ExecutionService.updateChangeRequest(
 projectId: projectId,
 requestId: request.id,
 issueTopic: topicController.text,
 description: descriptionController.text,
 discipline: disciplineController.text,
 raisedBy: raisedByController.text,
 scheduleImpact: scheduleImpactController.text,
 costImpact: costImpactController.text,
 approved: approved,
 comments: commentsController.text,
 llOrBp: llOrBp,
 impacted: impactedController.text.isEmpty
 ? null
 : impactedController.text,
 );
 } else {
 await ExecutionService.createChangeRequest(
 projectId: projectId,
 issueTopic: topicController.text,
 description: descriptionController.text,
 discipline: disciplineController.text,
 raisedBy: raisedByController.text,
 scheduleImpact: scheduleImpactController.text,
 costImpact: costImpactController.text,
 approved: approved,
 comments: commentsController.text,
 llOrBp: llOrBp,
 impacted: impactedController.text.isEmpty
 ? null
 : impactedController.text,
 );
 }

 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(isEdit
 ? '${llOrBp == 'LL' ? 'Lesson learned' : 'Best practice'} updated successfully'
 : '${llOrBp == 'LL' ? 'Lesson learned' : 'Best practice'} added successfully')),
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

 return StreamBuilder<List<ExecutionIssueModel>>(
 stream: ExecutionService.streamChangeRequests(projectId),
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
 child: Text('Error loading lessons learned: ${snapshot.error}',
 style: const TextStyle(color: Colors.red)),
 ),
 );
 }

 // Filter for Lessons Learned (LL)
 final allRequests = snapshot.data ?? [];
 final lessonsLearned = allRequests
 .where((r) =>
 (r.llOrBp ?? '').toLowerCase().contains('ll') ||
 (r.llOrBp ?? '').isEmpty)
 .toList();

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
 1: FixedColumnWidth(130),
 2: FixedColumnWidth(120),
 3: FixedColumnWidth(130),
 4: FixedColumnWidth(130),
 5: FixedColumnWidth(130),
 6: FixedColumnWidth(130),
 7: FixedColumnWidth(130),
 8: FixedColumnWidth(130),
 9: FixedColumnWidth(150),
 10: FixedColumnWidth(100),
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
 buildCell('Topic', isHeader: true),
 buildCell('LL or BP?', isHeader: true),
 buildCell('Discipline', isHeader: true),
 buildCell('Impacted', isHeader: true),
 buildCell('Raised by', isHeader: true),
 buildCell('Schedule', isHeader: true),
 buildCell('Cost Impact', isHeader: true),
 buildCell('Approved?', isHeader: true),
 buildCell('Comments', isHeader: true),
 buildCell('Actions',
 isHeader: true, align: TextAlign.center),
 ],
 ),
 if (lessonsLearned.isEmpty)
 TableRow(
 children: [
 buildCell('', align: TextAlign.center),
 buildCell('No lessons learned added yet',
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
 buildCell(''),
 ],
 )
 else
 ...lessonsLearned.asMap().entries.map((entry) {
 final index = entry.key;
 final request = entry.value;
 return TableRow(
 children: [
 buildCell('${index + 1}', align: TextAlign.center),
 buildCell(request.issueTopic),
 buildCell(request.llOrBp ?? 'N/A'),
 buildCell(request.discipline),
 buildCell(request.impacted ?? 'N/A'),
 buildCell(request.raisedBy),
 buildCell(request.scheduleImpact),
 buildCell(request.costImpact),
 buildCell(request.approved ? 'Yes' : 'No'),
 buildCell(request.comments),
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
 onPressed: () =>
 showEditDialog(context, request),
 tooltip: 'Edit',
 ),
 IconButton(
 icon: const Icon(Icons.delete,
 size: 18, color: Color(0xFFEF4444)),
 onPressed: () =>
 showDeleteDialog(context, request),
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

class _DesktopLessonsLearnedActions extends StatelessWidget {
 const _DesktopLessonsLearnedActions();

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
 'Capture insights from past projects to avoid repeating mistakes and improve future performance.',
 ),
 ),
 ),
 ),
 const SizedBox(width: 24),
 YellowActionButton(
 label: 'Next',
 onPressed: () => ExecutionPlanBestPracticesScreen.open(context),
 ),
 ],
 );
 }
}

class _MobileLessonsLearnedActions extends StatelessWidget {
 const _MobileLessonsLearnedActions();

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 const InfoBadge(),
 const SizedBox(height: 20),
 const AiTipCard(
 text:
 'Capture insights from past projects to avoid repeating mistakes and improve future performance.',
 ),
 const SizedBox(height: 20),
 YellowActionButton(
 label: 'Next',
 onPressed: () => ExecutionPlanBestPracticesScreen.open(context),
 ),
 ],
 );
 }
}
