import 'dart:convert';
import 'dart:async';
import 'package:ndu_project/screens/execution_plan_interface_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/execution_plan_shared.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/csv_table_import_button.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';

Future<void> _exportPdf(BuildContext context) async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Stakeholder Identification',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['execution_stakeholder_identification'] ?? 'No data recorded.'),
 ],
 );
}

class ExecutionPlanStakeholderIdentificationScreen extends StatelessWidget {
 const ExecutionPlanStakeholderIdentificationScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const ExecutionPlanStakeholderIdentificationScreen()),
 );
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 20 : 40;

 return ResponsiveScaffold(
 activeItemLabel: 'Execution Stakeholder Identification',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 32),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 ExecutionPlanHeader(
 onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'execution_plan_stakeholder_identification'),
 onNext: () => PlanningPhaseNavigation.goToNext(context, 'execution_plan_stakeholder_identification'), onExportPdf: () => _exportPdf(context)),
 const SizedBox(height: 32),
 const SectionIntro(
 title: 'Execution Stakeholder Identification'),
 const SizedBox(height: 16),
 const CrossReferenceNote(standalonePage: 'Stakeholder Management'),
 const SizedBox(height: 24),
 const ExecutionPlanForm(
 title: 'Execution Stakeholder Identification',
 hintText:
 'Capture stakeholder groups, engagement strategies, and key concerns.',
 noteKey: 'execution_stakeholder_identification',
 ),
 const SizedBox(height: 32),
 const _StakeholderIdentificationSection(),
 const SizedBox(height: 56),
 ],
 ),
 ),
 );
 }
}

class _StakeholderIdentificationSection extends StatefulWidget {
 const _StakeholderIdentificationSection();

 @override
 State<_StakeholderIdentificationSection> createState() =>
 _StakeholderIdentificationSectionState();
}

class _StakeholderIdentificationSectionState
 extends State<_StakeholderIdentificationSection> {
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Stakeholder Identification',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['execution_plan_stakeholder_identification_screen'] ?? 'No data recorded.'),
 ],
 );
 }

 final List<Map<String, String>> _rows = [];
 bool _didHydrateRows = false;

 @override
 void didChangeDependencies() {
 super.didChangeDependencies();
 if (_didHydrateRows) return;
 _didHydrateRows = true;
 _hydrateRowsFromNotes();
 }

 Map<String, String> _emptyRow() => {
 'stakeholderGroup': '',
 'category': '',
 'influence': '',
 'keyConcerns': '',
 'engagementStrategy': '',
 'comments': '',
 };

 Map<String, String> _normalizeRow(Map<dynamic, dynamic> source) => {
 'stakeholderGroup': (source['stakeholderGroup'] ?? '').toString(),
 'category': (source['category'] ?? '').toString(),
 'influence': (source['influence'] ?? '').toString(),
 'keyConcerns': (source['keyConcerns'] ?? '').toString(),
 'engagementStrategy': (source['engagementStrategy'] ?? '').toString(),
 'comments': (source['comments'] ?? '').toString(),
 };

 void _hydrateRowsFromNotes() {
 final rawJson = ProjectDataHelper.getData(context)
 .planningNotes[executionStakeholderRowsNotesKey];
 if (rawJson == null || rawJson.trim().isEmpty) return;
 try {
 final decoded = jsonDecode(rawJson);
 if (decoded is! List) return;
 final loaded = decoded
 .whereType<Map>()
 .map((row) => _normalizeRow(row))
 .toList(growable: false);
 if (loaded.isEmpty) return;
 setState(() {
 _rows
 ..clear()
 ..addAll(loaded);
 });
 } catch (error) {
 debugPrint('Failed to parse stakeholder identification rows: $error');
 }
 }

 Future<void> _persistRows() async {
 final rowsJson = jsonEncode(_rows);
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: resolveExecutionCheckpoint(
 'execution_stakeholder_identification',
 ),
 dataUpdater: (data) => data.copyWith(
 planningNotes: {
 ...data.planningNotes,
 executionStakeholderRowsNotesKey: rowsJson,
 },
 ),
 showSnackbar: false,
 );
 }

 Future<void> _openRowDialog({int? index}) async {
 final isEdit = index != null;
 final base = isEdit ? _rows[index] : _emptyRow();

 final stakeholderGroupController =
 TextEditingController(text: base['stakeholderGroup'] ?? '');
 final categoryController =
 TextEditingController(text: base['category'] ?? '');
 final influenceController =
 TextEditingController(text: base['influence'] ?? '');
 final keyConcernsController =
 TextEditingController(text: base['keyConcerns'] ?? '');
 final engagementStrategyController =
 TextEditingController(text: base['engagementStrategy'] ?? '');
 final commentsController =
 TextEditingController(text: base['comments'] ?? '');

 await showDialog<void>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: Text(isEdit ? 'Edit Stakeholder' : 'Add Stakeholder'),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: stakeholderGroupController,
 decoration:
 const InputDecoration(labelText: 'Stakeholder Group *'),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: categoryController,
 decoration: const InputDecoration(labelText: 'Category'),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: influenceController,
 decoration: const InputDecoration(labelText: 'Influence'),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: keyConcernsController,
 decoration: const InputDecoration(labelText: 'Key Concerns'),
 maxLines: 2,
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: engagementStrategyController,
 decoration:
 const InputDecoration(labelText: 'Engagement Strategy'),
 maxLines: 2,
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: commentsController,
 decoration: const InputDecoration(labelText: 'Comments'),
 maxLines: 2,
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext),
 child: const Text('Cancel'),
 ),
 FilledButton(
 onPressed: () async {
 final stakeholderGroup = stakeholderGroupController.text.trim();
 if (stakeholderGroup.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Stakeholder Group is required.'),
 ),
 );
 return;
 }

 final updatedRow = _normalizeRow({
 'stakeholderGroup': stakeholderGroup,
 'category': categoryController.text.trim(),
 'influence': influenceController.text.trim(),
 'keyConcerns': keyConcernsController.text.trim(),
 'engagementStrategy': engagementStrategyController.text.trim(),
 'comments': commentsController.text.trim(),
 });

 setState(() {
 if (index != null) {
 _rows[index] = updatedRow;
 } else {
 _rows.add(updatedRow);
 }
 });
 Navigator.pop(dialogContext);
 await _persistRows();
 },
 child: Text(isEdit ? 'Update' : 'Add'),
 ),
 ],
 ),
 );
 }

 Future<void> _deleteRow(int index) async {
 final removed = _rows[index];
 setState(() => _rows.removeAt(index));
 await _persistRows();

 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: const Text('Stakeholder row deleted'),
 action: SnackBarAction(
 label: 'Undo',
 onPressed: () async {
 setState(() => _rows.insert(index, removed));
 await _persistRows();
 },
 ),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Stakeholder Identification',
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 28),
 _StakeholderIdentificationTable(
 rows: _rows,
 onEditRow: (rowIndex) => _openRowDialog(index: rowIndex),
 onDeleteRow: _deleteRow,
 ),
 const SizedBox(height: 20),
 Align(
 alignment: Alignment.centerRight,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CsvTableImportButton(
 tableTitle: 'Stakeholders',
 columns: [
 CsvColumnSpec(key: 'stakeholderGroup', label: 'Stakeholder Group', required: true, sampleValue: 'Local Government'),
 CsvColumnSpec(key: 'category', label: 'Category', sampleValue: 'External'),
 CsvColumnSpec(key: 'influence', label: 'Influence', sampleValue: 'High'),
 CsvColumnSpec(key: 'keyConcerns', label: 'Key Concerns', sampleValue: 'Environmental impact'),
 CsvColumnSpec(key: 'engagementStrategy', label: 'Engagement Strategy', sampleValue: 'Regular meetings'),
 CsvColumnSpec(key: 'comments', label: 'Comments', sampleValue: 'Monthly updates required'),
 ],
 onImport: (rows) async {
 var imported = 0;
 for (final row in rows) {
 final normalized = _normalizeRow({
 'stakeholderGroup': row['stakeholderGroup'] ?? '',
 'category': row['category'] ?? '',
 'influence': row['influence'] ?? '',
 'keyConcerns': row['keyConcerns'] ?? '',
 'engagementStrategy': row['engagementStrategy'] ?? '',
 'comments': row['comments'] ?? '',
 });
 if (normalized['stakeholderGroup']!.isEmpty) continue;
 setState(() => _rows.add(normalized));
 imported++;
 }
 if (imported > 0) {
 await _persistRows();
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Imported $imported stakeholder(s) successfully')),
 );
 }
 }
 },
 ),
 const SizedBox(width: 12),
 AddRowButton(onPressed: () => _openRowDialog()),
 ],
 ),
 ),
 const SizedBox(height: 44),
 if (isMobile)
 _MobileStakeholderIdentificationActions()
 else
 const _DesktopStakeholderIdentificationActions(),
 ],
 );
 }
}

class _StakeholderIdentificationTable extends StatelessWidget {
 const _StakeholderIdentificationTable({
 required this.rows,
 required this.onEditRow,
 required this.onDeleteRow,
 });

 final List<Map<String, String>> rows;
 final ValueChanged<int> onEditRow;
 final ValueChanged<int> onDeleteRow;

 @override
 Widget build(BuildContext context) {
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
 2: FlexColumnWidth(2),
 3: FlexColumnWidth(2),
 4: FlexColumnWidth(2),
 5: FlexColumnWidth(2),
 6: FlexColumnWidth(2),
 7: FixedColumnWidth(100),
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
 buildCell('Stakeholder Group', isHeader: true),
 buildCell('Category', isHeader: true),
 buildCell('Influence', isHeader: true),
 buildCell('Key Concerns', isHeader: true),
 buildCell('Engagement Strategy', isHeader: true),
 buildCell('Comments', isHeader: true),
 buildCell('Actions', isHeader: true, align: TextAlign.center),
 ],
 ),
 if (rows.isEmpty)
 TableRow(
 children: [
 buildCell('', align: TextAlign.center),
 buildCell('No stakeholders added yet',
 style: const TextStyle(
 color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
 buildCell(''),
 buildCell(''),
 buildCell(''),
 buildCell(''),
 buildCell(''),
 buildCell(''),
 ],
 )
 else
 ...rows.asMap().entries.map((entry) {
 final index = entry.key;
 final row = entry.value;
 return TableRow(
 children: [
 buildCell('${index + 1}', align: TextAlign.center),
 buildCell(row['stakeholderGroup'] ?? ''),
 buildCell(row['category'] ?? ''),
 buildCell(row['influence'] ?? ''),
 buildCell(row['keyConcerns'] ?? ''),
 buildCell(row['engagementStrategy'] ?? ''),
 buildCell(row['comments'] ?? ''),
 Container(
 color: Colors.white,
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 icon: const Icon(Icons.edit,
 size: 18, color: Color(0xFF64748B)),
 onPressed: () => onEditRow(index),
 tooltip: 'Edit',
 ),
 IconButton(
 icon: const Icon(Icons.delete,
 size: 18, color: Color(0xFFEF4444)),
 onPressed: () => onDeleteRow(index),
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
 }
}

class _DesktopStakeholderIdentificationActions extends StatelessWidget {
 const _DesktopStakeholderIdentificationActions();

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
 'Identify all parties affected by or influencing execution, and map their interests and influence levels.',
 ),
 ),
 ),
 ),
 const SizedBox(width: 24),
 YellowActionButton(
 label: 'Next',
 onPressed: () => ExecutionPlanInterfaceManagementScreen.open(context),
 ),
 ],
 );
 }
}

class _MobileStakeholderIdentificationActions extends StatelessWidget {
 const _MobileStakeholderIdentificationActions();

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 const InfoBadge(),
 const SizedBox(height: 20),
 const AiTipCard(
 text:
 'Identify all parties affected by or influencing execution, and map their interests and influence levels.',
 ),
 const SizedBox(height: 20),
 YellowActionButton(
 label: 'Next',
 onPressed: () => ExecutionPlanInterfaceManagementScreen.open(context),
 ),
 ],
 );
 }
}
