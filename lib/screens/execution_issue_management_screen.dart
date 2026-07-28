import 'dart:async';

import 'package:ndu_project/screens/execution_plan_lessons_learned_screen.dart';
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
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';

Future<void> _exportPdf(BuildContext context) async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Issue Management',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['execution_issue_management_screen'] ?? 'No data recorded.'),
 ],
 );
}

class ExecutionIssueManagementScreen extends StatelessWidget {
 const ExecutionIssueManagementScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const ExecutionIssueManagementScreen()),
 );
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 20 : 40;

 return ResponsiveScaffold(
 activeItemLabel: 'Execution Issue Management',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 ExecutionPlanHeader(
 onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'execution_issue_management'),
 onNext: () => PlanningPhaseNavigation.goToNext(context, 'execution_issue_management'), onExportPdf: () => _exportPdf(context)),
  const SizedBox(height: 24),
 const CrossReferenceNote(standalonePage: 'Issue Management'),
 const SizedBox(height: 24),
 const ExecutionPlanForm(
 title: 'Execution Issue Management',
 hintText:
 'Summarize issue tracking, escalation paths, and mitigation cadence.',
 noteKey: 'execution_issue_management',
 ),
 const SizedBox(height: 32),
 const _IssuesManagementSection(),
 const SizedBox(height: 56),
 ],
 ),
 ),
 );
 }
}

class _IssuesManagementSection extends StatefulWidget {
  const _IssuesManagementSection();

  @override
  State<_IssuesManagementSection> createState() => _IssuesManagementSectionState();
}

class _IssuesManagementSectionState extends State<_IssuesManagementSection> {
  bool _autoGenerationTriggered = false;
  bool _isAutoGenerating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoGenerateIfNeeded());
  }

  String? _getProjectId() {
    try {
      final provider = ProjectDataInherited.maybeOf(context);
      return provider?.projectData.projectId;
    } catch (e) {
      return null;
    }
  }

  Future<void> _autoGenerateIfNeeded() async {
    if (_autoGenerationTriggered || _isAutoGenerating) return;

    final projectId = _getProjectId();
    if (projectId == null) return;

    _autoGenerationTriggered = true;
    _isAutoGenerating = true;
    if (mounted) setState(() {});

    try {
      final existing = await ExecutionService.streamIssues(projectId).first;
      if (existing.isNotEmpty) {
        if (mounted) setState(() => _isAutoGenerating = false);
        return;
      }
      if (!mounted) return;

      final data = ProjectDataHelper.getData(context);
      final issueLog = data.issueLogItems;

      if (issueLog.isNotEmpty) {
        var count = 0;
        for (final item in issueLog) {
          await ExecutionService.createIssue(
            projectId: projectId,
            issueTopic: item.title,
            description: item.description,
            discipline: item.type,
            raisedBy: item.assignee,
            scheduleImpact: '',
            costImpact: '',
            approved: false,
            comments: 'Severity: ${item.severity}, Status: ${item.status}',
          );
          count++;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$count issue(s) auto-populated from planning phase')),
          );
        }
        if (mounted) setState(() => _isAutoGenerating = false);
        return;
      }
      if (!mounted) return;

      final ctx = ExecutionPhaseAiSeed.buildContext(context, section: 'Execution Issue Management');
      if (ctx.isNotEmpty) {
        final generated = await ExecutionPhaseAiSeed.generateEntries(
          context: context,
          section: 'Execution Issue Management',
          sections: {'issues': 'Issues with topic, description, and impact'},
          itemsPerSection: 5,
        );
        final entries = generated['issues'] ?? [];
        for (final entry in entries) {
          await ExecutionService.createIssue(
            projectId: projectId,
            issueTopic: entry.title,
            description: entry.details,
            discipline: '',
            raisedBy: '',
            scheduleImpact: '',
            costImpact: '',
            approved: false,
            comments: entry.status ?? '',
          );
        }
        if (mounted && entries.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${entries.length} issue(s) AI-generated')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-generation error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAutoGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Issues Management',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            if (_isAutoGenerating) ...[
              const SizedBox(width: 16),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        if (_isAutoGenerating)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Auto-populating issues…',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 28),
        const _IssuesManagementTable(),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CsvTableImportButton(
                tableTitle: 'Issues',
                columns: [
                  CsvColumnSpec(key: 'issueTopic', label: 'Issue Topic', required: true, sampleValue: 'Delay in permits'),
                  CsvColumnSpec(key: 'description', label: 'Description', required: true, sampleValue: 'Permit approval pending'),
                  CsvColumnSpec(key: 'discipline', label: 'Discipline', required: true, sampleValue: 'Engineering'),
                  CsvColumnSpec(key: 'raisedBy', label: 'Raised By', required: true, sampleValue: 'Project Manager'),
                  CsvColumnSpec(key: 'scheduleImpact', label: 'Schedule Impact', required: true, sampleValue: '2 weeks delay'),
                  CsvColumnSpec(key: 'costImpact', label: 'Cost Impact', required: true, sampleValue: '\$10,000'),
                  CsvColumnSpec(key: 'approved', label: 'Approved', allowedValues: ['Yes', 'No'], defaultValue: 'No', sampleValue: 'No'),
                  CsvColumnSpec(key: 'comments', label: 'Comments', required: true, sampleValue: 'Follow up with authorities'),
                ],
                onImport: (rows) async {
                  final projectId = _IssuesManagementTable._getProjectIdStatic(context);
                  if (projectId == null) return;
                  var imported = 0;
                  for (final row in rows) {
                    try {
                      await ExecutionService.createIssue(
                        projectId: projectId,
                        issueTopic: row['issueTopic'] ?? '',
                        description: row['description'] ?? '',
                        discipline: row['discipline'] ?? '',
                        raisedBy: row['raisedBy'] ?? '',
                        scheduleImpact: row['scheduleImpact'] ?? '',
                        costImpact: row['costImpact'] ?? '',
                        approved: (row['approved'] ?? '').toLowerCase() == 'yes',
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
                      SnackBar(content: Text('Imported $imported issue(s) successfully')),
                    );
                  }
                },
              ),
              const SizedBox(width: 12),
              AddRowButton(
                onPressed: () => _IssuesManagementTable.showAddDialog(context)),
            ],
          ),
        ),
        const SizedBox(height: 44),
        if (isMobile)
          _MobileIssueManagementActions()
        else
          const _DesktopIssueManagementActions(),
      ],
    );
  }
}

class _IssuesManagementTable extends StatelessWidget {
 const _IssuesManagementTable();

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
 _showIssueDialog(context, null, projectId);
 }

 static void showEditDialog(BuildContext context, ExecutionIssueModel issue) {
 final projectId = _getProjectIdStatic(context);
 if (projectId == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No project selected. Please open a project first.')),
 );
 return;
 }
 _showIssueDialog(context, issue, projectId);
 }

 static void showDeleteDialog(
 BuildContext context, ExecutionIssueModel issue) {
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
 title: const Text('Delete Issue'),
 content: Text(
 'Are you sure you want to delete "${issue.issueTopic}"? This action cannot be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () async {
 try {
 await ExecutionService.deleteIssue(
 projectId: projectId, issueId: issue.id);
 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Issue deleted successfully')),
 );
 }
 } catch (e) {
 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Error deleting issue: $e')),
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

 static void _showIssueDialog(
 BuildContext context, ExecutionIssueModel? issue, String projectId) {
 final isEdit = issue != null;
 final topicController =
 TextEditingController(text: issue?.issueTopic ?? '');
 final descriptionController =
 TextEditingController(text: issue?.description ?? '');
 final disciplineController =
 TextEditingController(text: issue?.discipline ?? '');
 final raisedByController =
 TextEditingController(text: issue?.raisedBy ?? '');
 final scheduleImpactController =
 TextEditingController(text: issue?.scheduleImpact ?? '');
 final costImpactController =
 TextEditingController(text: issue?.costImpact ?? '');
 final commentsController =
 TextEditingController(text: issue?.comments ?? '');
 bool approved = issue?.approved ?? false;

 showDialog(
 context: context,
 builder: (context) => StatefulBuilder(
 builder: (context, setState) => AlertDialog(
 title: Text(isEdit ? 'Edit Issue' : 'Add New Issue'),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: topicController,
 decoration:
 const InputDecoration(labelText: 'Issue Topic *')),
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
 await ExecutionService.updateIssue(
 projectId: projectId,
 issueId: issue.id,
 issueTopic: topicController.text,
 description: descriptionController.text,
 discipline: disciplineController.text,
 raisedBy: raisedByController.text,
 scheduleImpact: scheduleImpactController.text,
 costImpact: costImpactController.text,
 approved: approved,
 comments: commentsController.text,
 );
 } else {
 await ExecutionService.createIssue(
 projectId: projectId,
 issueTopic: topicController.text,
 description: descriptionController.text,
 discipline: disciplineController.text,
 raisedBy: raisedByController.text,
 scheduleImpact: scheduleImpactController.text,
 costImpact: costImpactController.text,
 approved: approved,
 comments: commentsController.text,
 );
 }

 if (context.mounted) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(isEdit
 ? 'Issue updated successfully'
 : 'Issue added successfully')),
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
 stream: ExecutionService.streamIssues(projectId),
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
 child: Text('Error loading issues: ${snapshot.error}',
 style: const TextStyle(color: Colors.red)),
 ),
 );
 }

 final issues = snapshot.data ?? [];

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
 2: FixedColumnWidth(160),
 3: FixedColumnWidth(130),
 4: FixedColumnWidth(130),
 5: FixedColumnWidth(130),
 6: FixedColumnWidth(130),
 7: FixedColumnWidth(130),
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
 buildCell('Issue Topic', isHeader: true),
 buildCell('Description', isHeader: true),
 buildCell('Discipline', isHeader: true),
 buildCell('Raised by', isHeader: true),
 buildCell('Schedule In', isHeader: true),
 buildCell('Cost Impact', isHeader: true),
 buildCell('Approved?', isHeader: true),
 buildCell('Comments', isHeader: true),
 buildCell('Actions',
 isHeader: true, align: TextAlign.center),
 ],
 ),
 if (issues.isEmpty)
 TableRow(
 children: [
 buildCell('', align: TextAlign.center),
 buildCell('No issues added yet',
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
 ...issues.asMap().entries.map((entry) {
 final index = entry.key;
 final issue = entry.value;
 return TableRow(
 children: [
 buildCell('${index + 1}', align: TextAlign.center),
 buildCell(issue.issueTopic),
 buildCell(issue.description),
 buildCell(issue.discipline),
 buildCell(issue.raisedBy),
 buildCell(issue.scheduleImpact),
 buildCell(issue.costImpact),
 buildCell(issue.approved ? 'Yes' : 'No'),
 buildCell(issue.comments),
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
 onPressed: () => showEditDialog(context, issue),
 tooltip: 'Edit',
 ),
 IconButton(
 icon: const Icon(Icons.delete,
 size: 18, color: Color(0xFFEF4444)),
 onPressed: () =>
 showDeleteDialog(context, issue),
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

class _DesktopIssueManagementActions extends StatelessWidget {
 const _DesktopIssueManagementActions();

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
 'Define how issues will be identified, escalated, and resolved during execution.',
 ),
 ),
 ),
 ),
 const SizedBox(width: 24),
 YellowActionButton(
 label: 'Next',
 onPressed: () => ExecutionPlanLessonsLearnedScreen.open(context),
 ),
 ],
 );
 }
}

class _MobileIssueManagementActions extends StatelessWidget {
 const _MobileIssueManagementActions();

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 const InfoBadge(),
 const SizedBox(height: 20),
 const AiTipCard(
 text:
 'Define how issues will be identified, escalated, and resolved during execution.',
 ),
 const SizedBox(height: 20),
 YellowActionButton(
 label: 'Next',
 onPressed: () => ExecutionPlanLessonsLearnedScreen.open(context),
 ),
 ],
 );
 }
}
