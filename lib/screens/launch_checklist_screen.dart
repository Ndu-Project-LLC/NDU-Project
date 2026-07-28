import 'package:ndu_project/utils/download_helper_stub.dart'
 if (dart.library.html) 'package:ndu_project/utils/download_helper_web.dart' as loader;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:ndu_project/screens/deliver_project_closure_screen.dart';
import 'package:ndu_project/screens/risk_tracking_screen.dart';
import 'package:ndu_project/screens/update_ops_maintenance_plans_screen.dart';
import 'package:ndu_project/utils/launch_phase_ai_seed.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_data_table.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';

class LaunchChecklistScreen extends StatefulWidget {
 const LaunchChecklistScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const LaunchChecklistScreen()),
 );
 }

 @override
 State<LaunchChecklistScreen> createState() => _LaunchChecklistScreenState();
}

class _LaunchChecklistScreenState extends State<LaunchChecklistScreen> {
 List<_ChecklistItemData> _checklistItems = [];
 List<_ApprovalData> _approvals = [];
 List<_MilestoneData> _milestones = [];
 List<_TimelineStage> _timelineStages = [];

 bool _isLoading = true;
 bool _isGenerating = false;
 bool _isExporting = false;
 bool _hasLoaded = false;
 bool _suspendSave = false;
 String _selectedView = 'full'; // 'full' or 'summary'

 String? get _projectId => ProjectDataHelper.getData(context).projectId;

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
 }

 // ── Save ────────────────────────────────────────────────────────

 void _save() {
 if (_suspendSave || !_hasLoaded) return;
 Future.microtask(() {
 if (mounted) _persistData();
 });
 }

 // ── Load ────────────────────────────────────────────────────────

 Future<void> _loadData() async {
 if (_hasLoaded || _projectId == null) return;
 _suspendSave = true;
 try {
 final doc = await FirebaseFirestore.instance
 .collection('projects')
 .doc(_projectId!)
 .collection('execution_phase_sections')
 .doc('launch_checklist')
 .get();
 final data = doc.data() ?? {};

 final checklist = _ChecklistItemData.fromList(data['checklistItems']);
 final approvals = _ApprovalData.fromList(data['approvals']);
 final milestones = _MilestoneData.fromList(data['milestones']);
 final stages = _TimelineStage.fromList(data['timelineStages']);

 final hasContent = checklist.isNotEmpty ||
 approvals.isNotEmpty ||
 milestones.isNotEmpty ||
 stages.isNotEmpty;

 if (!mounted) return;
 setState(() {
 _checklistItems =
 checklist.isEmpty ? _defaultChecklistItems() : checklist;
 _approvals = approvals.isEmpty ? _defaultApprovals() : approvals;
 _milestones = milestones.isEmpty ? _defaultMilestones() : milestones;
 _timelineStages =
 stages.isEmpty ? _defaultTimelineStages() : stages;
 _isLoading = false;
 _hasLoaded = true;
 });

 if (!hasContent) {
 await _autoPopulateFromPriorPhases();
 }
 if (_checklistItems.isEmpty &&
 _approvals.isEmpty &&
 _milestones.isEmpty &&
 _timelineStages.isEmpty) {
 await _populateFromAi();
 }
 } catch (e) {
 debugPrint('Launch checklist load error: $e');
 if (mounted) setState(() => _isLoading = false);
 }
 _suspendSave = false;
 }

 // ── Persist ─────────────────────────────────────────────────────

 Future<void> _persistData() async {
 if (_projectId == null) return;
 try {
 await FirebaseFirestore.instance
 .collection('projects')
 .doc(_projectId!)
 .collection('execution_phase_sections')
 .doc('launch_checklist')
 .set({
 'checklistItems': _checklistItems.map((e) => e.toMap()).toList(),
 'approvals': _approvals.map((e) => e.toMap()).toList(),
 'milestones': _milestones.map((e) => e.toMap()).toList(),
 'timelineStages': _timelineStages.map((e) => e.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));
 } catch (e) {
 debugPrint('Launch checklist save error: $e');
 }
 }

 // ── Auto-populate from prior phases ─────────────────────────────

 Future<void> _autoPopulateFromPriorPhases() async {
 if (_projectId == null) return;
 try {
 final cp = await LaunchPhaseAiSeed.loadCrossPhaseData(_projectId!);
 if (!mounted) return;

 final checklistExisting = _checklistItems.map((c) => c.title).toSet();
 final newItems = <_ChecklistItemData>[];
 for (final d in cp.scopeTracking) {
 if (d.deliverable.isNotEmpty &&
 !checklistExisting.contains(d.deliverable)) {
 newItems.add(_ChecklistItemData(
 title: d.deliverable,
 detail: d.notes,
 owner: '',
 due: '',
 status: d.status == 'Verified' ? 'Complete' : 'On track',
 ));
 }
 }
 if (newItems.isNotEmpty) {
 setState(() => _checklistItems.addAll(newItems));
 }

 final approvalExisting = _approvals.map((a) => a.label).toSet();
 final newApprovals = <_ApprovalData>[];
 for (final c in cp.contracts) {
 if (c.contractName.isNotEmpty &&
 !approvalExisting.contains(c.contractName)) {
 newApprovals.add(_ApprovalData(
 label: '${c.contractName} sign-off',
 detail: 'Vendor: ${c.vendor}',
 status: c.closeOutStatus == 'Closed' ? 'Complete' : 'Pending',
 approver: '',
 ));
 }
 }
 if (newApprovals.isNotEmpty) {
 setState(() => _approvals.addAll(newApprovals));
 }

 final milestoneExisting = _milestones.map((m) => m.title).toSet();
 final newMilestones = <_MilestoneData>[];
 for (final d in cp.deliverableRows) {
 final title = d['title']?.toString() ?? '';
 if (title.isNotEmpty && !milestoneExisting.contains(title)) {
 newMilestones.add(_MilestoneData(
 title: title,
 detail: '',
 due: '',
 status: (d['status']?.toString() ?? '').toLowerCase() == 'completed'
 ? 'Complete'
 : 'Upcoming',
 ));
 }
 }
 if (newMilestones.isNotEmpty) {
 setState(() => _milestones.addAll(newMilestones));
 }

 final timelineExisting = _timelineStages.map((t) => t.label).toSet();
 final newStages = <_TimelineStage>[];
 for (final s in cp.planningSprints) {
 final goal =
 s['goal']?.toString() ?? s['title']?.toString() ?? '';
 if (goal.isNotEmpty && !timelineExisting.contains(goal)) {
 newStages.add(_TimelineStage(
 label: goal,
 detail: '',
 date: '',
 status: (s['status']?.toString() ?? '').toLowerCase() == 'completed'
 ? 'Complete'
 : 'Upcoming',
 ));
 }
 }
 if (newStages.isNotEmpty) {
 setState(() => _timelineStages.addAll(newStages));
 }

 if (newItems.isNotEmpty ||
 newApprovals.isNotEmpty ||
 newMilestones.isNotEmpty ||
 newStages.isNotEmpty) {
 await _persistData();
 }
 } catch (e) {
 debugPrint('Launch checklist auto-populate error: $e');
 }
 }

 // ── AI generation ───────────────────────────────────────────────

 Future<void> _populateFromAi() async {
 if (_isGenerating) return;
 setState(() => _isGenerating = true);
 LaunchAiResult? result;
 try {
 result = await LaunchPhaseAiSeed.generateEntries(
 context: context,
 sectionLabel: 'Launch Checklist',
 sections: const {
 'checklist_items':
 'Launch checklist action items with "title", "details", "status"',
 'approvals':
 'Approvals and sign-offs with "title", "details", "status"',
 'milestones':
 'Key launch milestones with "title", "details", "status"',
 'timeline_stages':
 'Timeline stages toward go-live with "title", "details", "status"',
 },
 itemsPerSection: 3,
 );
 } catch (e) {
 debugPrint('Launch checklist AI error: $e');
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

 final hasData = _checklistItems.isNotEmpty ||
 _approvals.isNotEmpty ||
 _milestones.isNotEmpty ||
 _timelineStages.isNotEmpty;
 if (hasData) {
 setState(() => _isGenerating = false);
 return;
 }
 setState(() {
 _checklistItems = (generated['checklist_items'] ?? [])
 .map((m) => _ChecklistItemData(
 title: _s(m['title']),
 detail: _s(m['details']),
 owner: _extractField(_s(m['details']), 'Owner'),
 due: _extractField(_s(m['details']), 'Due'),
 status: _ns(m['status'], 'Pending'),
 ))
 .where((i) => i.title.isNotEmpty)
 .toList();
 _approvals = (generated['approvals'] ?? [])
 .map((m) => _ApprovalData(
 label: _s(m['title']),
 detail: _s(m['details']),
 status: _ns(m['status'], 'Pending'),
 approver: _extractField(_s(m['details']), 'Approver'),
 ))
 .where((i) => i.label.isNotEmpty)
 .toList();
 _milestones = (generated['milestones'] ?? [])
 .map((m) => _MilestoneData(
 title: _s(m['title']),
 detail: _s(m['details']),
 due: _extractField(_s(m['details']), 'Due'),
 status: _ns(m['status'], 'Upcoming'),
 ))
 .where((i) => i.title.isNotEmpty)
 .toList();
 _timelineStages = (generated['timeline_stages'] ?? [])
 .map((m) => _TimelineStage(
 label: _s(m['title']),
 detail: _s(m['details']),
 date: _extractField(_s(m['details']), 'Date'),
 status: _ns(m['status'], 'Upcoming'),
 ))
 .where((i) => i.label.isNotEmpty)
 .toList();
 _isGenerating = false;
 });
 await _persistData();
 }

 Future<void> _exportPdf() async {
 setState(() => _isExporting = true);
 try {
 final projectData = ProjectDataHelper.getData(context);
 final projectName = projectData.projectName ?? 'Project';
 final now = DateTime.now();
 final stamp =
 '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
 final filename = 'launch_checklist_${projectName.replaceAll(' ', '_')}_$stamp.pdf';

 final doc = pw.Document();

 doc.addPage(
 pw.MultiPage(
 pageFormat: PdfPageFormat.a4,
 margin: const pw.EdgeInsets.all(32),
 build: (_) => [
 pw.Text('Launch Checklist', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
 pw.SizedBox(height: 4),
 pw.Text('$projectName — Generated ${now.toLocal().toIso8601String()}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
 pw.SizedBox(height: 16),

 // Checklist Items
 _pdfSectionTitle('Launch Checklist'),
 pw.SizedBox(height: 6),
 if (_checklistItems.isEmpty)
 _pdfCell('No checklist items recorded.')
 else
 pw.Table.fromTextArray(
 headers: ['Task', 'Detail', 'Owner', 'Due', 'Status'],
 data: _checklistItems.map((c) => [c.title, c.detail, c.owner, c.due, c.status]).toList(),
 headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 cellStyle: const pw.TextStyle(fontSize: 9),
 headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
 cellPadding: const pw.EdgeInsets.all(6),
 ),
 pw.SizedBox(height: 14),

 // Approvals
 _pdfSectionTitle('Approvals & Sign-offs'),
 pw.SizedBox(height: 6),
 if (_approvals.isEmpty)
 _pdfCell('No approvals recorded.')
 else
 pw.Table.fromTextArray(
 headers: ['Approval', 'Detail', 'Approver', 'Status'],
 data: _approvals.map((a) => [a.label, a.detail, a.approver, a.status]).toList(),
 headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 cellStyle: const pw.TextStyle(fontSize: 9),
 headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
 cellPadding: const pw.EdgeInsets.all(6),
 ),
 pw.SizedBox(height: 14),

 // Milestones
 _pdfSectionTitle('Launch Milestones'),
 pw.SizedBox(height: 6),
 if (_milestones.isEmpty)
 _pdfCell('No milestones recorded.')
 else
 pw.Table.fromTextArray(
 headers: ['Milestone', 'Detail', 'Due', 'Status'],
 data: _milestones.map((m) => [m.title, m.detail, m.due, m.status]).toList(),
 headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 cellStyle: const pw.TextStyle(fontSize: 9),
 headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
 cellPadding: const pw.EdgeInsets.all(6),
 ),
 pw.SizedBox(height: 14),

 // Timeline Stages
 _pdfSectionTitle('Launch Timeline'),
 pw.SizedBox(height: 6),
 if (_timelineStages.isEmpty)
 _pdfCell('No timeline stages recorded.')
 else
 pw.Table.fromTextArray(
 headers: ['Stage', 'Detail', 'Date', 'Status'],
 data: _timelineStages.map((t) => [t.label, t.detail, t.date, t.status]).toList(),
 headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
 cellStyle: const pw.TextStyle(fontSize: 9),
 headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
 cellPadding: const pw.EdgeInsets.all(6),
 ),
 ],
 ),
 );

 final bytes = await doc.save();
 if (!mounted) return;
 loader.downloadFile(bytes, filename, mimeType: 'application/pdf');
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF export failed: ${e.toString()}')));
 }
 } finally {
 if (mounted) setState(() => _isExporting = false);
 }
 }

 pw.Widget _pdfSectionTitle(String title) {
 return pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold));
 }

 pw.Widget _pdfHeaderCell(String text) {
 return pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)));
 }

 pw.Widget _pdfCell(String text) {
 return pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)));
 }

 String _s(dynamic v) => (v ?? '').toString().trim();
 String _ns(dynamic v, String fb) => _s(v).isEmpty ? fb : _s(v);

 String _extractField(String text, String key) {
 final match = RegExp('$key\\s*[:=-]\\s*([^|;\\n]+)', caseSensitive: false)
 .firstMatch(text);
 return match?.group(1)?.trim() ?? '';
 }

 // ── Defaults ────────────────────────────────────────────────────

 List<_ChecklistItemData> _defaultChecklistItems() => [
 _ChecklistItemData(
 title: 'Cutover rehearsals signed off',
 detail: 'Dry run #2 captured follow-up items',
 owner: 'Operations lead',
 due: 'Aug 12',
 status: 'Complete',
 ),
 _ChecklistItemData(
 title: 'Rollback playbook distributed',
 detail: 'Share final rollback guide with war room',
 owner: 'Program manager',
 due: 'Aug 09',
 status: 'At risk',
 ),
 _ChecklistItemData(
 title: 'Hypercare squad roster confirmed',
 detail: 'Roster, shifts, and bridge details communicated',
 owner: 'Launch director',
 due: 'Aug 15',
 status: 'On track',
 ),
 _ChecklistItemData(
 title: 'Customer comms final approval',
 detail: 'Exec sign-off on launch narratives',
 owner: 'Comms lead',
 due: 'Aug 14',
 status: 'In review',
 ),
 ];

 List<_ApprovalData> _defaultApprovals() => [
 _ApprovalData(
 label: 'Cutover rehearsal sign-off',
 detail: 'Delivery, platform, and ops leads approved',
 status: 'Complete',
 approver: 'Ops Director',
 ),
 _ApprovalData(
 label: 'Business readiness validation',
 detail: 'Support staffing matrix ready',
 status: 'Complete',
 approver: 'Business Owner',
 ),
 _ApprovalData(
 label: 'Comms go-live bundle',
 detail: 'Legal + comms reviewing final messaging',
 status: 'In review',
 approver: 'Legal Counsel',
 ),
 ];

 List<_MilestoneData> _defaultMilestones() => [
 _MilestoneData(
 title: 'Cutover rehearsal playback',
 detail: 'Ops + Engineering walk-through',
 due: 'Aug 09',
 status: 'Complete',
 ),
 _MilestoneData(
 title: 'Go / no-go rehearsal',
 detail: 'Dry run with scenario walk-through',
 due: 'Aug 11',
 status: 'Upcoming',
 ),
 _MilestoneData(
 title: 'Launch day',
 detail: 'Go-live execution',
 due: 'Aug 18',
 status: 'Upcoming',
 ),
 ];

 List<_TimelineStage> _defaultTimelineStages() => [
 _TimelineStage(
 label: 'Final readiness review',
 detail: 'All cutover artefacts verified',
 date: 'Aug 10',
 status: 'Complete',
 ),
 _TimelineStage(
 label: 'Go / no-go rehearsal',
 detail: 'Dry run with escalation practices',
 date: 'Aug 11',
 status: 'In progress',
 ),
 _TimelineStage(
 label: 'Launch day execution',
 detail: 'Go-live cutover',
 date: 'Aug 18',
 status: 'Upcoming',
 ),
 ];

 // ── Build ───────────────────────────────────────────────────────

 @override
 Widget build(BuildContext context) {
 final bool isMobile = MediaQuery.sizeOf(context).width < 980;

 return ResponsiveScaffold(
 activeItemLabel: 'Launch Checklist',
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
 title: 'Launch Checklist',
showNavigationButtons: false, onExportPdf: _exportPdf),
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
 label: _selectedView == 'full' ? 'Summary View' : 'Full View',
 icon: _selectedView == 'full' ? Icons.summarize_outlined : Icons.list_alt,
 tone: ExecutionActionTone.secondary,
 onPressed: () => setState(() {
 _selectedView = _selectedView == 'full' ? 'summary' : 'full';
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
 const SizedBox(height: 20),
 _buildChecklistPanel(),
 const SizedBox(height: 16),
 _buildApprovalsPanel(),
 const SizedBox(height: 16),
 _buildMilestonesPanel(),
 const SizedBox(height: 16),
 _buildTimelinePanel(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Update Ops & Maintenance Plans',
 nextLabel: 'Next: Risk Tracking',
 onBack: () => UpdateOpsMaintenancePlansScreen.open(context),
 onNext: () => RiskTrackingScreen.open(context),
 ),
 const SizedBox(height: 48),
 ],
 ),
 ),
 );
 }



 // ── Metrics ─────────────────────────────────────────────────────

 Widget _buildMetricsRow() {
 final approvalsDone =
 _approvals.where((a) => a.status == 'Complete').length;
 final milestonesHit =
 _milestones.where((m) => m.status == 'Complete').length;
 return ExecutionMetricsGrid(
 metrics: [
 ExecutionMetricData(
 label: 'Checklist Items',
 value: '${_checklistItems.length}',
 icon: Icons.checklist_rounded,
 emphasisColor: const Color(0xFF2563EB),
 ),
 ExecutionMetricData(
 label: 'Approvals Done',
 value: '$approvalsDone',
 icon: Icons.approval_rounded,
 emphasisColor: const Color(0xFF10B981),
 ),
 ExecutionMetricData(
 label: 'Milestones Hit',
 value: '$milestonesHit',
 icon: Icons.flag_outlined,
 emphasisColor: const Color(0xFF8B5CF6),
 ),
 ExecutionMetricData(
 label: 'Timeline Stages',
 value: '${_timelineStages.length}',
 icon: Icons.timeline_rounded,
 emphasisColor: const Color(0xFFF59E0B),
 ),
 ],
 );
 }

 // ── Checklist Panel ─────────────────────────────────────────────

 Widget _buildChecklistPanel() {
 return LaunchDataTable(
 title: 'Launch Checklist',
 subtitle: 'Critical action items with owners and due dates',
 columns: const [
 LaunchColumn(label: 'Task', flexible: true, fieldType: LaunchFieldType.text, hint: 'Task'),
 LaunchColumn(label: 'Detail', flexible: true, fieldType: LaunchFieldType.text, hint: 'Detail'),
 LaunchColumn(label: 'Owner', width: 120, fieldType: LaunchFieldType.text, hint: 'Owner'),
 LaunchColumn(label: 'Due', width: 130, fieldType: LaunchFieldType.date, hint: 'Due'),
 LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Complete', 'On track', 'At risk', 'In review', 'Pending'], hint: 'Status'),
 ],
 rowCount: _checklistItems.length,
 onAddValues: (values) {
 setState(() => _checklistItems.add(_ChecklistItemData(
 title: values['Task'] ?? '',
 detail: values['Detail'] ?? '',
 owner: values['Owner'] ?? '',
 due: values['Due'] ?? '',
 status: values['Status'] ?? 'Pending',
 )));
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'task', label: 'Task', sampleValue: 'Cutover rehearsals signed off'),
 CsvColumnSpec(key: 'detail', label: 'Detail', sampleValue: 'Dry run #2 captured follow-up items'),
 CsvColumnSpec(key: 'owner', label: 'Owner', sampleValue: 'Operations lead'),
 CsvColumnSpec(key: 'due', label: 'Due', sampleValue: 'Aug 12'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Pending', allowedValues: ['Complete', 'On track', 'At risk', 'In review', 'Pending']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _checklistItems.add(_ChecklistItemData(
 title: row['task'] ?? '',
 detail: row['detail'] ?? '',
 owner: row['owner'] ?? '',
 due: row['due'] ?? '',
 status: row['status'] ?? 'Pending',
 ));
 });
 }
 _save();
 },
 emptyMessage:
 'No checklist items yet. Add critical action items before go-live.',
 cellBuilder: (context, i) {
 final item = _checklistItems[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirmed = await launchConfirmDelete(context,
 itemName: 'checklist item');
 if (!confirmed || !mounted) return;
 setState(() => _checklistItems.removeAt(i));
 _save();
 },
 cells: [
 LaunchEditableCell(
 value: item.title,
 hint: 'Task',
 bold: true,
 expand: true,
 onChanged: (v) {
 _checklistItems[i] = item.copyWith(title: v);
 _save();
 },
 ),
 LaunchEditableCell(
 value: item.detail,
 hint: 'Detail',
 expand: true,
 onChanged: (v) {
 _checklistItems[i] = item.copyWith(detail: v);
 _save();
 },
 ),
 LaunchEditableCell(
 value: item.owner,
 hint: 'Owner',
 width: 120,
 onChanged: (v) {
 _checklistItems[i] = item.copyWith(owner: v);
 _save();
 },
 ),
 LaunchEditableCell(
 value: item.due,
 hint: 'Due',
 width: 130,
 onChanged: (v) {
 _checklistItems[i] = item.copyWith(due: v);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: item.status,
 items: const [
 'Complete',
 'On track',
 'At risk',
 'In review',
 'Pending'
 ],
 width: 120,
 onChanged: (v) {
 if (v == null) return;
 _checklistItems[i] = item.copyWith(status: v);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 // ── Approvals Panel ─────────────────────────────────────────────

 Widget _buildApprovalsPanel() {
 return LaunchDataTable(
 title: 'Approvals & Sign-offs',
 subtitle: 'Required approvals before go-live',
 columns: const [
 LaunchColumn(label: 'Approval', flexible: true, fieldType: LaunchFieldType.text, hint: 'Approval'),
 LaunchColumn(label: 'Detail', flexible: true, fieldType: LaunchFieldType.text, hint: 'Detail'),
 LaunchColumn(label: 'Approver', width: 120, fieldType: LaunchFieldType.text, hint: 'Approver'),
 LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Complete', 'In review', 'Pending'], hint: 'Status'),
 ],
 rowCount: _approvals.length,
 onAddValues: (values) {
 setState(() => _approvals.add(_ApprovalData(
 label: values['Approval'] ?? '',
 detail: values['Detail'] ?? '',
 status: values['Status'] ?? 'Pending',
 approver: values['Approver'] ?? '',
 )));
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'approval', label: 'Approval', sampleValue: 'Cutover sign-off'),
 CsvColumnSpec(key: 'detail', label: 'Detail', sampleValue: 'Delivery and ops leads approved'),
 CsvColumnSpec(key: 'approver', label: 'Approver', sampleValue: 'Ops Director'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Pending', allowedValues: ['Complete', 'In review', 'Pending']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _approvals.add(_ApprovalData(
 label: row['approval'] ?? '',
 detail: row['detail'] ?? '',
 status: row['status'] ?? 'Pending',
 approver: row['approver'] ?? '',
 ));
 });
 }
 _save();
 },
 emptyMessage:
 'No approvals yet. Track required sign-offs before launch.',
 cellBuilder: (context, i) {
 final item = _approvals[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirmed = await launchConfirmDelete(context,
 itemName: 'approval');
 if (!confirmed || !mounted) return;
 setState(() => _approvals.removeAt(i));
 _save();
 },
 cells: [
 LaunchEditableCell(
 value: item.label,
 hint: 'Approval',
 bold: true,
 expand: true,
 onChanged: (v) {
 _approvals[i] = item.copyWith(label: v);
 _save();
 },
 ),
 LaunchEditableCell(
 value: item.detail,
 hint: 'Detail',
 expand: true,
 onChanged: (v) {
 _approvals[i] = item.copyWith(detail: v);
 _save();
 },
 ),
 LaunchEditableCell(
 value: item.approver,
 hint: 'Approver',
 width: 120,
 onChanged: (v) {
 _approvals[i] = item.copyWith(approver: v);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: item.status,
 items: const ['Complete', 'In review', 'Pending'],
 width: 120,
 onChanged: (v) {
 if (v == null) return;
 _approvals[i] = item.copyWith(status: v);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 // ── Milestones Panel ────────────────────────────────────────────

 Widget _buildMilestonesPanel() {
 return LaunchDataTable(
 title: 'Launch Milestones',
 subtitle: 'Key milestones leading to go-live',
 columns: const [
 LaunchColumn(label: 'Milestone', flexible: true, fieldType: LaunchFieldType.text, hint: 'Milestone'),
 LaunchColumn(label: 'Detail', flexible: true, fieldType: LaunchFieldType.text, hint: 'Detail'),
 LaunchColumn(label: 'Due', width: 130, fieldType: LaunchFieldType.date, hint: 'Due'),
 LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Complete', 'Upcoming', 'In progress', 'Delayed'], hint: 'Status'),
 ],
 rowCount: _milestones.length,
 onAddValues: (values) {
 setState(() => _milestones.add(_MilestoneData(
 title: values['Milestone'] ?? '',
 detail: values['Detail'] ?? '',
 due: values['Due'] ?? '',
 status: values['Status'] ?? 'Upcoming',
 )));
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'milestone', label: 'Milestone', sampleValue: 'Go / no-go rehearsal'),
 CsvColumnSpec(key: 'detail', label: 'Detail', sampleValue: 'Dry run with scenario walk-through'),
 CsvColumnSpec(key: 'due', label: 'Due', sampleValue: 'Aug 11'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Upcoming', allowedValues: ['Complete', 'Upcoming', 'In progress', 'Delayed']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _milestones.add(_MilestoneData(
 title: row['milestone'] ?? '',
 detail: row['detail'] ?? '',
 due: row['due'] ?? '',
 status: row['status'] ?? 'Upcoming',
 ));
 });
 }
 _save();
 },
 emptyMessage:
 'No milestones yet. Add key milestones leading to go-live.',
 cellBuilder: (context, i) {
 final item = _milestones[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirmed = await launchConfirmDelete(context,
 itemName: 'milestone');
 if (!confirmed || !mounted) return;
 setState(() => _milestones.removeAt(i));
 _save();
 },
 cells: [
 LaunchEditableCell(
 value: item.title,
 hint: 'Milestone',
 bold: true,
 expand: true,
 onChanged: (v) {
 _milestones[i] = item.copyWith(title: v);
 _save();
 },
 ),
 LaunchEditableCell(
 value: item.detail,
 hint: 'Detail',
 expand: true,
 onChanged: (v) {
 _milestones[i] = item.copyWith(detail: v);
 _save();
 },
 ),
 LaunchEditableCell(
 value: item.due,
 hint: 'Due',
 width: 130,
 onChanged: (v) {
 _milestones[i] = item.copyWith(due: v);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: item.status,
 items: const ['Complete', 'Upcoming', 'In progress', 'Delayed'],
 width: 120,
 onChanged: (v) {
 if (v == null) return;
 _milestones[i] = item.copyWith(status: v);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }

 // ── Timeline Panel ──────────────────────────────────────────────

 Widget _buildTimelinePanel() {
 return LaunchDataTable(
 title: 'Launch Timeline',
 subtitle: 'Timeline stages toward go-live',
 columns: const [
 LaunchColumn(label: 'Stage', flexible: true, fieldType: LaunchFieldType.text, hint: 'Stage'),
 LaunchColumn(label: 'Detail', flexible: true, fieldType: LaunchFieldType.text, hint: 'Detail'),
 LaunchColumn(label: 'Date', width: 130, fieldType: LaunchFieldType.date, hint: 'Date'),
 LaunchColumn(label: 'Status', width: 120, fieldType: LaunchFieldType.dropdown, dropdownItems: ['Complete', 'In progress', 'Upcoming', 'Delayed'], hint: 'Status'),
 ],
 rowCount: _timelineStages.length,
 onAddValues: (values) {
 setState(() => _timelineStages.add(_TimelineStage(
 label: values['Stage'] ?? '',
 detail: values['Detail'] ?? '',
 date: values['Date'] ?? '',
 status: values['Status'] ?? 'Upcoming',
 )));
 _save();
 },
 csvColumns: const [
 CsvColumnSpec(key: 'stage', label: 'Stage', sampleValue: 'Final readiness review'),
 CsvColumnSpec(key: 'detail', label: 'Detail', sampleValue: 'All cutover artefacts verified'),
 CsvColumnSpec(key: 'date', label: 'Date', sampleValue: 'Aug 10'),
 CsvColumnSpec(key: 'status', label: 'Status', sampleValue: 'Upcoming', allowedValues: ['Complete', 'In progress', 'Upcoming', 'Delayed']),
 ],
 onCsvImport: (rows) async {
 for (final row in rows) {
 setState(() {
 _timelineStages.add(_TimelineStage(
 label: row['stage'] ?? '',
 detail: row['detail'] ?? '',
 date: row['date'] ?? '',
 status: row['status'] ?? 'Upcoming',
 ));
 });
 }
 _save();
 },
 emptyMessage:
 'No timeline stages yet. Add stages leading to go-live.',
 cellBuilder: (context, i) {
 final stage = _timelineStages[i];
 return LaunchDataRow(
 onEdit: () => _save(),
 onDelete: () async {
 final confirmed = await launchConfirmDelete(context,
 itemName: 'timeline stage');
 if (!confirmed || !mounted) return;
 setState(() => _timelineStages.removeAt(i));
 _save();
 },
 cells: [
 LaunchEditableCell(
 value: stage.label,
 hint: 'Stage',
 bold: true,
 expand: true,
 onChanged: (v) {
 _timelineStages[i] = stage.copyWith(label: v);
 _save();
 },
 ),
 LaunchEditableCell(
 value: stage.detail,
 hint: 'Detail',
 expand: true,
 onChanged: (v) {
 _timelineStages[i] = stage.copyWith(detail: v);
 _save();
 },
 ),
 LaunchEditableCell(
 value: stage.date,
 hint: 'Date',
 width: 130,
 onChanged: (v) {
 _timelineStages[i] = stage.copyWith(date: v);
 _save();
 },
 ),
 LaunchStatusDropdown(
 value: stage.status,
 items: const [
 'Complete',
 'In progress',
 'Upcoming',
 'Delayed'
 ],
 width: 120,
 onChanged: (v) {
 if (v == null) return;
 _timelineStages[i] = stage.copyWith(status: v);
 _save();
 setState(() {});
 },
 ),
 ],
 );
 },
 );
 }
}

// ── Private Data Models (Firestore-compatible) ─────────────────────

class _ChecklistItemData {
 const _ChecklistItemData({
 required this.title,
 required this.detail,
 required this.owner,
 required this.due,
 required this.status,
 });

 final String title;
 final String detail;
 final String owner;
 final String due;
 final String status;

 _ChecklistItemData copyWith({
 String? title,
 String? detail,
 String? owner,
 String? due,
 String? status,
 }) {
 return _ChecklistItemData(
 title: title ?? this.title,
 detail: detail ?? this.detail,
 owner: owner ?? this.owner,
 due: due ?? this.due,
 status: status ?? this.status,
 );
 }

 Map<String, dynamic> toMap() => {
 'title': title,
 'detail': detail,
 'owner': owner,
 'due': due,
 'status': status,
 };

 static List<_ChecklistItemData> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _ChecklistItemData(
 title: map['title']?.toString() ?? '',
 detail: map['detail']?.toString() ?? '',
 owner: map['owner']?.toString() ?? '',
 due: map['due']?.toString() ?? '',
 status: map['status']?.toString() ?? 'Pending',
 );
 }).toList();
 }
}

class _ApprovalData {
 const _ApprovalData({
 required this.label,
 required this.detail,
 required this.status,
 required this.approver,
 });

 final String label;
 final String detail;
 final String status;
 final String approver;

 _ApprovalData copyWith({
 String? label,
 String? detail,
 String? status,
 String? approver,
 }) {
 return _ApprovalData(
 label: label ?? this.label,
 detail: detail ?? this.detail,
 status: status ?? this.status,
 approver: approver ?? this.approver,
 );
 }

 Map<String, dynamic> toMap() => {
 'label': label,
 'detail': detail,
 'status': status,
 'approver': approver,
 };

 static List<_ApprovalData> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _ApprovalData(
 label: map['label']?.toString() ?? '',
 detail: map['detail']?.toString() ?? '',
 status: map['status']?.toString() ?? 'Pending',
 approver: map['approver']?.toString() ?? '',
 );
 }).toList();
 }
}

class _MilestoneData {
 const _MilestoneData({
 required this.title,
 required this.detail,
 required this.due,
 required this.status,
 });

 final String title;
 final String detail;
 final String due;
 final String status;

 _MilestoneData copyWith({
 String? title,
 String? detail,
 String? due,
 String? status,
 }) {
 return _MilestoneData(
 title: title ?? this.title,
 detail: detail ?? this.detail,
 due: due ?? this.due,
 status: status ?? this.status,
 );
 }

 Map<String, dynamic> toMap() => {
 'title': title,
 'detail': detail,
 'due': due,
 'status': status,
 };

 static List<_MilestoneData> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _MilestoneData(
 title: map['title']?.toString() ?? '',
 detail: map['detail']?.toString() ?? '',
 due: map['due']?.toString() ?? '',
 status: map['status']?.toString() ?? 'Upcoming',
 );
 }).toList();
 }
}

class _TimelineStage {
 const _TimelineStage({
 required this.label,
 required this.detail,
 required this.date,
 required this.status,
 });

 final String label;
 final String detail;
 final String date;
 final String status;

 _TimelineStage copyWith({
 String? label,
 String? detail,
 String? date,
 String? status,
 }) {
 return _TimelineStage(
 label: label ?? this.label,
 detail: detail ?? this.detail,
 date: date ?? this.date,
 status: status ?? this.status,
 );
 }

 Map<String, dynamic> toMap() => {
 'label': label,
 'detail': detail,
 'date': date,
 'status': status,
 };

 static List<_TimelineStage> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _TimelineStage(
 label: map['label']?.toString() ?? '',
 detail: map['detail']?.toString() ?? '',
 date: map['date']?.toString() ?? '',
 status: map['status']?.toString() ?? 'Upcoming',
 );
 }).toList();
 }
}
