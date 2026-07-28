import 'package:ndu_project/widgets/launch_notes_section.dart';
import 'package:ndu_project/widgets/launch_insights_widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:ndu_project/models/launch_phase_models.dart';
import 'package:ndu_project/screens/actual_vs_planned_gap_analysis_screen.dart';
import 'package:ndu_project/screens/demobilize_team_screen.dart';
import 'package:ndu_project/services/launch_phase_service.dart';
import 'package:ndu_project/utils/download_helper.dart' as download_helper;
import 'package:ndu_project/utils/launch_phase_ai_seed.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
class ProjectCloseOutScreen extends StatefulWidget {
 const ProjectCloseOutScreen({
 super.key,
 this.summarized = false,
 this.activeItemLabel = '11. Project Closeout',
 });

 final bool summarized;
 final String activeItemLabel;

 static void open(
 BuildContext context, {
 bool summarized = false,
 String activeItemLabel = '11. Project Closeout',
 }) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => ProjectCloseOutScreen(
 summarized: summarized,
 activeItemLabel: activeItemLabel,
 ),
 ),
 );
 }

 @override
 State<ProjectCloseOutScreen> createState() => _ProjectCloseOutScreenState();
}

class _ProjectCloseOutScreenState extends State<ProjectCloseOutScreen> {
 List<LaunchCloseOutCheckItem> _closeOutChecklist = [];
  final TextEditingController _notesController = TextEditingController();
 List<LaunchApproval> _approvals = [];
 List<LaunchArchiveItem> _archive = [];
 LaunchClosureNotes _lessonsLearned = LaunchClosureNotes();

 bool _isLoading = true;
 bool _isGenerating = false;
 bool _hasLoaded = false;
 bool _suspendSave = false;
 bool _isExporting = false;
 late _CloseOutView _selectedView;

 @override
 void initState() {
 super.initState();
 _selectedView =
 widget.summarized ? _CloseOutView.summarized : _CloseOutView.longForm;
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
 }

 String? get _projectId => ProjectDataHelper.getData(context).projectId;

 @override
 Widget build(BuildContext context) {
 final bool isMobile = MediaQuery.sizeOf(context).width < 980;

 return ResponsiveScaffold(
 activeItemLabel: widget.activeItemLabel,
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
 title: 'Project Closeout',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 16),
            _buildLaunchInsights(),
            const SizedBox(height: 16),
 Row(
 children: [
 const Spacer(),
 ExecutionActionBar(
 actions: [
 ExecutionActionItem(
 label: _isExporting ? 'Exporting…' : 'Export PDF',
 icon: Icons.picture_as_pdf_outlined,
 tone: ExecutionActionTone.secondary,
 isLoading: _isExporting,
 onPressed: _isExporting ? null : _exportPdf,
 ),
 ExecutionActionItem(
 label: _selectedView == _CloseOutView.longForm
 ? 'Summary View'
 : 'Full View',
 icon: _selectedView == _CloseOutView.longForm
 ? Icons.summarize_outlined
 : Icons.list_alt,
 tone: ExecutionActionTone.secondary,
 onPressed: () => setState(() {
 _selectedView = _selectedView == _CloseOutView.longForm
 ? _CloseOutView.summarized
 : _CloseOutView.longForm;
 }),
 ),
 ExecutionActionItem(
 label: _isGenerating ? 'Generating…' : 'AI Assist',
 icon: Icons.auto_awesome_outlined,
 tone: ExecutionActionTone.ai,
 isLoading: _isGenerating,
 onPressed: _isGenerating ? null : _populateFromAi,
 ),
 ],
 ),
 ],
 ),
 const SizedBox(height: 12),
 _buildMetricsRow(),
 const SizedBox(height: 16),
            LaunchNotesSection(
              controller: _notesController,
              onChanged: (v) {},
            ),
            const SizedBox(height: 20),
 if (_selectedView == _CloseOutView.longForm) ...[
 _buildChecklistPanel(),
 const SizedBox(height: 16),
 _buildApprovalsPanel(),
 const SizedBox(height: 16),
 _buildArchivePanel(),
 const SizedBox(height: 16),
 _buildLessonsLearnedPanel(),
 ] else
 ..._buildSummarizedView(),
 const SizedBox(height: 24),
 _buildNavigation(),
 const SizedBox(height: 48),
 ],
 ),
 ),
 );
 }



 Widget _buildMetricsRow() {
 final total = _closeOutChecklist.length;
 final done = _closeOutChecklist.where((c) => c.status == 'Complete').length;
 final approved = _approvals.where((a) => a.status == 'Approved').length;
 final archived = _archive.where((a) => a.status == 'Complete').length;
 final pct = total > 0 ? (done / total * 100).round() : 0;

 return ExecutionMetricsGrid(
 metrics: [
 ExecutionMetricData(
 label: 'Close-Out Progress',
 value: '$pct%',
 icon: Icons.task_alt_outlined,
 emphasisColor:
 pct >= 80 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
 helper: '$done / $total items complete',
 ),
 ExecutionMetricData(
 label: 'Approvals',
 value: '$approved / ${_approvals.length}',
 icon: Icons.assignment_turned_in_outlined,
 emphasisColor: approved == _approvals.length && _approvals.isNotEmpty
 ? const Color(0xFF10B981)
 : const Color(0xFFD97706),
 ),
 ExecutionMetricData(
 label: 'Archived Items',
 value: '$archived / ${_archive.length}',
 icon: Icons.folder_outlined,
 emphasisColor: const Color(0xFF8B5CF6),
 ),
 ExecutionMetricData(
 label: 'Lessons Learned',
 value: _lessonsLearned.notes.isNotEmpty ? 'Captured' : 'Pending',
 icon: Icons.lightbulb_outline,
 emphasisColor: _lessonsLearned.notes.isNotEmpty
 ? const Color(0xFF10B981)
 : const Color(0xFF9CA3AF),
 ),
 ],
 );
 }

 Widget _buildChecklistPanel() {
 return LaunchDataTable(
 title: 'Close-Out Checklist',
 subtitle:
 'Verify all items are addressed before formally closing the project.',
 columns: const [LaunchColumn(label: 'Category', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: LaunchCloseOutCheckItem.categories), LaunchColumn(label: 'Item', flexible: true, fieldType: LaunchFieldType.text, hint: 'Item'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Pending', 'In Progress', 'Complete']), LaunchColumn(label: 'Notes', flexible: true, fieldType: LaunchFieldType.text, hint: 'Notes')],
 rowCount: _closeOutChecklist.length,
 onAddValues: (values) {
 setState(() {
 _closeOutChecklist.add(LaunchCloseOutCheckItem(
 category: values['Category'] ?? 'Deliverables',
 item: values['Item'] ?? '',
 status: values['Status'] ?? 'Pending',
 notes: values['Notes'] ?? '',
 ));
 });
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'category', label: 'Category', sampleValue: 'Deliverables', allowedValues: ['Deliverables', 'Contracts', 'Vendors', 'Team', 'Documentation', 'Finance']),
 CsvColumnSpec(key: 'item', label: 'Item', sampleValue: 'Verify final deliverables'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Pending', allowedValues: ['Pending', 'In Progress', 'Complete']),
 CsvColumnSpec(key: 'notes', label: 'Notes', sampleValue: 'On track'),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _closeOutChecklist.add(LaunchCloseOutCheckItem(
 category: row['category'] ?? '',
 item: row['item'] ?? '',
 status: row['status'] ?? 'Pending',
 notes: row['notes'] ?? '',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'Add close-out verification tasks by category.',
 cellBuilder: (context, i) {
 final c = _closeOutChecklist[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirmed =
 await launchConfirmDelete(context, itemName: 'checklist item');
 if (!confirmed) return;
 setState(() => _closeOutChecklist.removeAt(i));
 _save();
 },
 cells: [
 LaunchStatusDropdown(
 value: c.category,
 items: LaunchCloseOutCheckItem.categories,
 width: 120,
 onChanged: (s) {
 if (s == null) return;
 _closeOutChecklist[i] = c.copyWith(category: s);
 _save();
 setState(() {});
 },
 ),
 LaunchEditableCell(
 value: c.item,
 hint: 'Item',
 bold: true,
 expand: true,
 onChanged: (s) {
 _closeOutChecklist[i] = c.copyWith(item: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: c.status,
 items: const ['Pending', 'In Progress', 'Complete'],
 width: 120,
 onChanged: (s) {
 if (s == null) return;
 _closeOutChecklist[i] = c.copyWith(status: s);
 _save();
 setState(() {});
 },
 ),
 LaunchEditableCell(
 value: c.notes,
 hint: 'Notes',
 expand: true,
 onChanged: (s) {
 _closeOutChecklist[i] = c.copyWith(notes: s);
 _save();
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildApprovalsPanel() {
 return LaunchDataTable(
 title: 'Final Approvals',
 subtitle:
 'Stakeholders who must sign off before the project is formally closed.',
 columns: const [LaunchColumn(label: 'Stakeholder', flexible: true, fieldType: LaunchFieldType.text, hint: 'Name'), LaunchColumn(label: 'Role', width: 120, fieldType: LaunchFieldType.text, hint: 'Role'), LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Pending', 'Approved', 'Rejected']), LaunchColumn(label: 'Date', width: 130, fieldType: LaunchFieldType.date, hint: 'Date'), LaunchColumn(label: 'Notes', flexible: true, fieldType: LaunchFieldType.text, hint: 'Notes')],
 rowCount: _approvals.length,
 onAddValues: (values) {
 setState(() {
 _approvals.add(LaunchApproval(
 stakeholder: values['Stakeholder'] ?? '',
 role: values['Role'] ?? '',
 status: values['Status'] ?? 'Pending',
 date: values['Date'] ?? '',
 notes: values['Notes'] ?? '',
 ));
 });
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'stakeholder', label: 'Stakeholder', sampleValue: 'Jane Smith'),
 CsvColumnSpec(key: 'role', label: 'Role', sampleValue: 'Project Sponsor'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Pending', allowedValues: ['Pending', 'Approved', 'Rejected']),
 CsvColumnSpec(key: 'date', label: 'Date', sampleValue: '2025-01-15'),
 CsvColumnSpec(key: 'notes', label: 'Notes', sampleValue: 'Awaiting review'),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _approvals.add(LaunchApproval(
 stakeholder: row['stakeholder'] ?? '',
 role: row['role'] ?? '',
 status: row['status'] ?? 'Pending',
 date: row['date'] ?? '',
 notes: row['notes'] ?? '',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'Add stakeholders who need to sign off.',
 cellBuilder: (context, i) {
 final a = _approvals[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirmed =
 await launchConfirmDelete(context, itemName: 'approval entry');
 if (!confirmed) return;
 setState(() => _approvals.removeAt(i));
 _save();
 },
 cells: [
 LaunchEditableCell(
 value: a.stakeholder,
 hint: 'Name',
 bold: true,
 expand: true,
 onChanged: (s) {
 _approvals[i] = a.copyWith(stakeholder: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: a.role,
 hint: 'Role',
 expand: true,
 onChanged: (s) {
 _approvals[i] = a.copyWith(role: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: a.status,
 items: const ['Pending', 'Approved', 'Rejected'],
 width: 110,
 onChanged: (s) {
 if (s == null) return;
 _approvals[i] = a.copyWith(status: s);
 _save();
 setState(() {});
 },
 ),
 LaunchDateCell(
 value: a.date,
 hint: 'Date',
 width: 130,
 onChanged: (s) {
 _approvals[i] = a.copyWith(date: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: a.notes,
 hint: 'Notes',
 expand: true,
 onChanged: (s) {
 _approvals[i] = a.copyWith(notes: s);
 _save();
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildArchivePanel() {
 return LaunchDataTable(
 title: 'Archive & Access',
 subtitle:
 'Document repositories, code, and access changes required for closure.',
 columns: const [
 LaunchColumn(label: 'Repository', flexible: true, fieldType: LaunchFieldType.text, hint: 'Repository'),
 LaunchColumn(label: 'Type', width: 130, fieldType: LaunchFieldType.text, hint: 'Type'),
 LaunchColumn(label: 'Retention', width: 130, fieldType: LaunchFieldType.text, hint: 'Retention'),
 LaunchColumn(label: 'Access Change', width: 120, fieldType: LaunchFieldType.text, hint: 'Access'),
 LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Pending', 'In Progress', 'Complete']),
 ],
 rowCount: _archive.length,
 onAddValues: (values) {
 setState(() {
 _archive.add(LaunchArchiveItem(
 repository: values['Repository'] ?? '',
 documentType: values['Type'] ?? '',
 retentionPeriod: values['Retention'] ?? '',
 accessChange: values['Access Change'] ?? '',
 status: values['Status'] ?? 'Pending',
 ));
 });
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'repository', label: 'Repository', sampleValue: 'GitHub Repo'),
 CsvColumnSpec(key: 'documentType', label: 'Type', sampleValue: 'Source Code'),
 CsvColumnSpec(key: 'retentionPeriod', label: 'Retention', sampleValue: '5 years'),
 CsvColumnSpec(key: 'accessChange', label: 'Access Change', sampleValue: 'Read-only'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Pending', allowedValues: ['Pending', 'In Progress', 'Complete']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _archive.add(LaunchArchiveItem(
 repository: row['repository'] ?? '',
 documentType: row['documentType'] ?? '',
 retentionPeriod: row['retentionPeriod'] ?? '',
 accessChange: row['accessChange'] ?? '',
 status: row['status'] ?? 'Pending',
 ));
 });
 }
 _save();
 },
 emptyMessage: 'List repositories and documents for archival.',
 cellBuilder: (context, i) {
 final a = _archive[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirmed =
 await launchConfirmDelete(context, itemName: 'archive item');
 if (!confirmed) return;
 setState(() => _archive.removeAt(i));
 _save();
 },
 cells: [
 LaunchEditableCell(
 value: a.repository,
 hint: 'Repository',
 bold: true,
 expand: true,
 onChanged: (s) {
 _archive[i] = a.copyWith(repository: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: a.documentType,
 hint: 'Type',
 expand: true,
 onChanged: (s) {
 _archive[i] = a.copyWith(documentType: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: a.retentionPeriod,
 hint: 'Retention',
 width: 130,
 onChanged: (s) {
 _archive[i] = a.copyWith(retentionPeriod: s);
 _save();
 },
 ),
 LaunchEditableCell(
 value: a.accessChange,
 hint: 'Access',
 width: 130,
 onChanged: (s) {
 _archive[i] = a.copyWith(accessChange: s);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: a.status,
 items: const ['Pending', 'In Progress', 'Complete'],
 width: 120,
 onChanged: (s) {
 if (s == null) return;
 _archive[i] = a.copyWith(status: s);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 Widget _buildLessonsLearnedPanel() {
 return ExecutionPanelShell(
 title: 'Lessons Learned',
 subtitle:
 'What went well, what to improve, and recommendations for future projects.',
 collapsible: true,
 initiallyExpanded: false,
 headerIcon: Icons.auto_stories_outlined,
 headerIconColor: const Color(0xFFF59E0B),
 child: VoiceTextFormField(
 initialValue: _lessonsLearned.notes,
 maxLines: 8,
 style: const TextStyle(fontSize: 13, height: 1.6),
 decoration: InputDecoration(
 hintText:
 'Capture lessons learned, wins, improvement areas, and recommendations…',
 hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFFFD700))),
 ),
 onChanged: (v) {
 _lessonsLearned = LaunchClosureNotes(notes: v);
 _save();
 },
 ),
 );
 }

 List<Widget> _buildSummarizedView() {
 final byCategory = <String, List<LaunchCloseOutCheckItem>>{};
 for (final c in _closeOutChecklist) {
 byCategory.putIfAbsent(c.category, () => []).add(c);
 }

 return [
 ExecutionPanelShell(
 title: 'Close-Out Summary',
 subtitle: 'Aggregated view of all close-out progress.',
 collapsible: true,
 initiallyExpanded: false,
 headerIcon: Icons.assignment_outlined,
 headerIconColor: const Color(0xFF10B981),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Wrap(
 spacing: 16,
 runSpacing: 16,
 children: LaunchCloseOutCheckItem.categories.map((cat) {
 final items = byCategory[cat] ?? [];
 final done = items.where((i) => i.status == 'Complete').length;
 return Container(
 width: 180,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(cat,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF64748B))),
 const SizedBox(height: 8),
 Text('$done / ${items.length}',
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827))),
 ],
 ),
 );
 }).toList(),
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),
 ExecutionPanelShell(
 title: 'Approvals Snapshot',
 subtitle:
 '${_approvals.where((a) => a.status == 'Approved').length} of ${_approvals.length} approved.',
 collapsible: true,
 initiallyExpanded: false,
 headerIcon: Icons.fact_check_outlined,
 headerIconColor: const Color(0xFF6366F1),
 child: _approvals.isEmpty
 ? const Text('No approvals captured yet.',
 style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)))
 : Column(
 children: _approvals
 .map((a) => Padding(
 padding: const EdgeInsets.only(bottom: 8),
 child: Row(children: [
 Icon(
 a.status == 'Approved'
 ? Icons.check_circle
 : Icons.pending,
 size: 16,
 color: a.status == 'Approved'
 ? const Color(0xFF10B981)
 : const Color(0xFF9CA3AF)),
 const SizedBox(width: 10),
 Text('${a.stakeholder} — ${a.role}',
 style: const TextStyle(
 fontSize: 13, color: Color(0xFF374151))),
 ]),
 ))
 .toList()),
 ),
 ];
 }

 Widget _buildNavigation() {
 return LaunchPhaseNavigation(
 backLabel: 'Back: Team Demobilization & Operations/Production Transition',
 nextLabel: 'Finalize & Close Project',
 onBack: () => DemobilizeTeamScreen.open(context),
 onNext: () {
 Navigator.of(context).maybePop();
 },
 );
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
 await LaunchPhaseService.loadProjectCloseOut(projectId: _projectId!);
 if (!mounted) return;
 setState(() {
 _closeOutChecklist = r.closeOutChecklist;
 _approvals = r.approvals;
 _archive = r.archive;
 _lessonsLearned = r.lessonsLearned;
 _isLoading = false;
 _hasLoaded = true;
 });
 if (_closeOutChecklist.isEmpty &&
 _approvals.isEmpty &&
 _archive.isEmpty) {
 await _autoPopulateFromPriorPhases();
 }
 if (_closeOutChecklist.isEmpty &&
 _approvals.isEmpty &&
 _archive.isEmpty) {
 await _populateFromAi();
 }
 } catch (e) {
 debugPrint('Close-out load error: $e');
 if (mounted) setState(() => _isLoading = false);
 }
 _suspendSave = false;
 }

 Future<void> _persistData() async {
 if (_projectId == null) return;
 try {
 await LaunchPhaseService.saveProjectCloseOut(
 projectId: _projectId!,
 closeOutChecklist: _closeOutChecklist,
 approvals: _approvals,
 archive: _archive,
 lessonsLearned: _lessonsLearned);
 } catch (e) {
 debugPrint('Close-out save error: $e');
 }
 }

 Future<void> _autoPopulateFromPriorPhases() async {
 if (_projectId == null) return;
 try {
 final cp = await LaunchPhaseAiSeed.loadCrossPhaseData(_projectId!);

 if (!mounted) return;

 final checklistExisting = _closeOutChecklist.map((c) => c.item).toSet();
 final newChecklistItems = <LaunchCloseOutCheckItem>[];

 for (final d in cp.deliverableRows) {
 final title = d['title']?.toString() ?? '';
 if (title.isNotEmpty && !checklistExisting.contains(title)) {
 newChecklistItems.add(LaunchCloseOutCheckItem(
 category: 'Deliverables',
 item: title,
 status: d['status']?.toString() ?? 'Pending',
 notes: '',
 ));
 }
 }

 for (final c in cp.contracts) {
 if (!checklistExisting.contains(c.contractName)) {
 newChecklistItems.add(LaunchCloseOutCheckItem(
 category: 'Contracts',
 item: c.contractName,
 status: c.closeOutStatus == 'Closed' ? 'Complete' : 'Pending',
 notes: '',
 ));
 }
 }

 for (final v in cp.vendors) {
 if (!checklistExisting.contains(v.vendorName)) {
 newChecklistItems.add(LaunchCloseOutCheckItem(
 category: 'Vendors',
 item: v.vendorName,
 status: v.accountStatus == 'Inactive' ? 'Complete' : 'Pending',
 notes: '',
 ));
 }
 }

 for (final s in cp.staffing) {
 if (!checklistExisting.contains(s.name)) {
 newChecklistItems.add(LaunchCloseOutCheckItem(
 category: 'Team',
 item: s.name,
 status: s.releaseStatus == 'Released' ? 'Complete' : 'Pending',
 notes: '',
 ));
 }
 }

 for (final pd in cp.planningDeliverables) {
 final title = pd['title']?.toString() ?? '';
 if (title.isNotEmpty && !checklistExisting.contains(title)) {
 newChecklistItems.add(LaunchCloseOutCheckItem(
 category: 'Documentation',
 item: title,
 status: 'Pending',
 notes: '',
 ));
 }
 }

 // Add finance category checklist from budget data
 if (cp.totalPlannedBudget > 0 && !checklistExisting.contains('Budget reconciliation')) {
 newChecklistItems.add(LaunchCloseOutCheckItem(
 category: 'Finance',
 item: 'Budget reconciliation',
 status: cp.budgetVariance.abs() < cp.totalPlannedBudget * 0.05 ? 'Complete' : 'Pending',
 notes: 'Variance: \$${cp.budgetVariance.toStringAsFixed(0)}',
 ));
 }

 if (newChecklistItems.isNotEmpty) {
 setState(() => _closeOutChecklist.addAll(newChecklistItems));
 }

 final approvalsExisting = _approvals.map((a) => a.stakeholder).toSet();
 final newApprovals = <LaunchApproval>[];
 for (final sh in cp.stakeholders) {
 final name = sh['name'] ?? sh['stakeholder'] ?? '';
 if (name.isNotEmpty && !approvalsExisting.contains(name)) {
 newApprovals.add(LaunchApproval(
 stakeholder: name,
 role: sh['role'] ?? '',
 status: 'Pending',
 ));
 }
 }
 if (newApprovals.isNotEmpty) {
 setState(() => _approvals.addAll(newApprovals));
 }

 final archiveExisting = _archive.map((a) => a.repository).toSet();
 final newArchiveItems = <LaunchArchiveItem>[];
 for (final pd in cp.planningDeliverables) {
 final title = pd['title']?.toString() ?? '';
 if (title.isNotEmpty && !archiveExisting.contains(title)) {
 newArchiveItems.add(LaunchArchiveItem(
 repository: title,
 documentType: pd['type']?.toString() ?? 'Deliverable',
 status: 'Pending',
 ));
 }
 }
 if (newArchiveItems.isNotEmpty) {
 setState(() => _archive.addAll(newArchiveItems));
 }

 if (newChecklistItems.isNotEmpty || newApprovals.isNotEmpty || newArchiveItems.isNotEmpty) {
 await _persistData();
 }
 } catch (e) {
 debugPrint('Close-out auto-populate error: $e');
 }
 }

 Future<void> _populateFromAi() async {
 if (_isGenerating) return;
 setState(() => _isGenerating = true);
 LaunchAiResult? result;
 try {
 result = await LaunchPhaseAiSeed.generateEntries(
 context: context,
 sectionLabel: 'Project Close Out',
 sections: const {
 'checklist':
 'Close-out checklist items with "category", "item", "status", "notes"',
 'approvals': 'Final approvers with "stakeholder", "role", "status"',
 'archive':
 'Archive items with "repository", "document_type", "retention_period", "status"',
 },
 itemsPerSection: 3,
 );
 } catch (e) {
 debugPrint('Close-out AI error: $e');
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

 final hasData = _closeOutChecklist.isNotEmpty ||
 _approvals.isNotEmpty ||
 _archive.isNotEmpty;
 if (hasData) {
 setState(() => _isGenerating = false);
 return;
 }
 setState(() {
 _closeOutChecklist = (generated['checklist'] ?? [])
 .map((m) => LaunchCloseOutCheckItem(
 item: _s(m['title']),
 notes: _s(m['details']),
 status: _ns(m['status'], 'Pending')))
 .where((i) => i.item.isNotEmpty)
 .toList();
 _approvals = (generated['approvals'] ?? [])
 .map((m) => LaunchApproval(
 stakeholder: _s(m['title']),
 role: _s(m['details']),
 status: _ns(m['status'], 'Pending')))
 .where((i) => i.stakeholder.isNotEmpty)
 .toList();
 _archive = (generated['archive'] ?? [])
 .map((m) => LaunchArchiveItem(
 repository: _s(m['title']),
 documentType: _s(m['details']),
 status: _ns(m['status'], 'Pending')))
 .where((i) => i.repository.isNotEmpty)
 .toList();
 _isGenerating = false;
 });
 await _persistData();
 }

 Future<void> _exportPdf() async {
 setState(() => _isExporting = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final projectName = projectData.projectName;
 final now = DateTime.now();
 final stamp =
 '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
 final filename =
 'project_close_out_${projectName.replaceAll(' ', '_')}_$stamp.pdf';

 final doc = pw.Document();

 doc.addPage(
 pw.MultiPage(
 pageFormat: PdfPageFormat.a4,
 margin: const pw.EdgeInsets.all(32),
 build: (_) => [
 pw.Text(
 'Project Close-Out Report',
 style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
 ),
 pw.SizedBox(height: 4),
 pw.Text(
 '$projectName — Generated ${now.toLocal().toIso8601String()}',
 style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
 ),
 pw.SizedBox(height: 16),
 _pdfSectionTitle('Close-Out Checklist'),
 pw.SizedBox(height: 6),
 if (_closeOutChecklist.isEmpty)
 pw.Text('No checklist items.',
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
 headers: const ['Category', 'Item', 'Status', 'Notes'],
 data: _closeOutChecklist
 .map((c) => [
 _pc(c.category),
 _pc(c.item),
 _pc(c.status),
 _pc(c.notes),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Final Approvals'),
 pw.SizedBox(height: 6),
 if (_approvals.isEmpty)
 pw.Text('No approval records.',
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
 'Stakeholder',
 'Role',
 'Status',
 'Date',
 'Notes'
 ],
 data: _approvals
 .map((a) => [
 _pc(a.stakeholder),
 _pc(a.role),
 _pc(a.status),
 _pc(a.date),
 _pc(a.notes),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Archive Plan'),
 pw.SizedBox(height: 6),
 if (_archive.isEmpty)
 pw.Text('No archive items.',
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
 'Repository',
 'Document Type',
 'Retention',
 'Access Change',
 'Status'
 ],
 data: _archive
 .map((a) => [
 _pc(a.repository),
 _pc(a.documentType),
 _pc(a.retentionPeriod),
 _pc(a.accessChange),
 _pc(a.status),
 ])
 .toList(),
 ),
 pw.SizedBox(height: 20),
 _pdfSectionTitle('Lessons Learned'),
 pw.SizedBox(height: 6),
 pw.Text(
 _lessonsLearned.notes.trim().isEmpty
 ? 'No lessons learned recorded.'
 : _lessonsLearned.notes.trim(),
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

 String _s(dynamic v) => (v ?? '').toString().trim();
 String _ns(dynamic v, String fb) => _s(v).isEmpty ? fb : _s(v);
  // Launch Insights: KPIs + completion donut (auto-derived from project data)
  Widget _buildLaunchInsights() {
    final projectData = ProjectDataHelper.getData(context);
    var checksPassed = 0;
        if (projectData.charterApprovalDate != null) checksPassed++;
        final risks = projectData.frontEndPlanning.riskRegisterItems;
        if (risks.isEmpty || risks.every((r) => r.status.toLowerCase() == 'closed' || r.status.toLowerCase() == 'mitigated')) checksPassed++;
        final ms = projectData.keyMilestones;
        if (ms.isEmpty || ms.every((m) => m.comments.toLowerCase().contains('complete') || m.comments.toLowerCase().contains('done'))) checksPassed++;
        final allowances = projectData.frontEndPlanning.allowanceItems;
        if (allowances.isEmpty || allowances.every((a) => a.releaseStatus == 'Closed' || a.releaseStatus == 'Consumed')) checksPassed++;
        final completionPct = checksPassed / 4;
    return LaunchInsightsHeader(
      sectionTitle: 'Project Closeout Status',
      sectionSubtitle: 'Final documentation, archive, lessons learned, and stakeholder sign-off',
      sectionIcon: Icons.task_alt_outlined,
      sectionColor: const Color(0xFF10B981),
      completionPercent: completionPct,
      completionLabel: 'CLOSED',
      completionCaption:
          '${(completionPct * 100).round()}% complete - auto-derived from project data',
      kpiTiles: [
        LaunchKpiTile(
              label: 'Charter Approved',
              value: projectData.charterApprovalDate != null ? 'Yes' : 'No',
              icon: Icons.verified_outlined,
              color: projectData.charterApprovalDate != null
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              delta: projectData.charterApprovalDate != null
                  ? 'project formally approved'
                  : 'awaiting approval',
            ),
            LaunchKpiTile(
              label: 'Milestones',
              value: '${projectData.keyMilestones.length}',
              icon: Icons.flag_outlined,
              color: const Color(0xFFD97706),
              delta: '${projectData.keyMilestones.where((m) => m.comments.toLowerCase().contains('complete') || m.comments.toLowerCase().contains('done')).length} done',
            ),
            LaunchKpiTile(
              label: 'Risks Logged',
              value: '${projectData.frontEndPlanning.riskRegisterItems.length}',
              icon: Icons.warning_amber_outlined,
              color: const Color(0xFFF59E0B),
              delta: '${projectData.frontEndPlanning.riskRegisterItems.where((r) => r.status.toLowerCase() == 'closed').length} closed',
            ),
            LaunchKpiTile(
              label: 'Allowances',
              value: '${projectData.frontEndPlanning.allowanceItems.length}',
              icon: Icons.savings_outlined,
              color: const Color(0xFFD97706),
              delta: 'contingency reconciled',
            ),
      ],
    );
  }


}

enum _CloseOutView { longForm, summarized }
