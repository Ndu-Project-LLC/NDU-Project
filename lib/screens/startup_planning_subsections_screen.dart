import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/download_helper.dart' as download_helper;
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
class StartUpPlanningOperationsScreen extends StatelessWidget {
 const StartUpPlanningOperationsScreen({super.key});

 @override
 Widget build(BuildContext context) =>
 const _StartUpPlanningDetailScreen(config: _PageConfig.operations());
}

class StartUpPlanningHypercareScreen extends StatelessWidget {
 const StartUpPlanningHypercareScreen({super.key});

 @override
 Widget build(BuildContext context) =>
 const _StartUpPlanningDetailScreen(config: _PageConfig.hypercare());
}

class StartUpPlanningDevOpsScreen extends StatelessWidget {
 const StartUpPlanningDevOpsScreen({super.key});

 @override
 Widget build(BuildContext context) =>
 const _StartUpPlanningDetailScreen(config: _PageConfig.devOps());
}

class StartUpPlanningCloseOutPlanScreen extends StatelessWidget {
 const StartUpPlanningCloseOutPlanScreen({super.key});

 @override
 Widget build(BuildContext context) =>
 const _StartUpPlanningDetailScreen(config: _PageConfig.closeOut());
}

class _StartUpPlanningDetailScreen extends StatefulWidget {
 const _StartUpPlanningDetailScreen({required this.config});

 final _PageConfig config;

 @override
 State<_StartUpPlanningDetailScreen> createState() =>
 _StartUpPlanningDetailScreenState();
}

class _StartUpPlanningDetailScreenState
 extends State<_StartUpPlanningDetailScreen> {
 final _Debouncer _debouncer = _Debouncer();
 bool _isLoading = true;
 bool _isSaving = false;
 bool _isUploading = false;
 bool _isHydrating = true;
 bool _legacyImported = false;
 DateTime? _lastSavedAt;
 _PlanningPageState _state = _PlanningPageState.empty();

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _load());
 }

 @override
 void dispose() {
 _debouncer.dispose();
 super.dispose();
 }

 Future<void> _load() async {
 final projectId = ProjectDataHelper.getData(context).projectId;
 final projectData = ProjectDataHelper.getData(context);
 var nextState = _PlanningPageState.forConfig(widget.config, projectData);
 bool importedLegacy = false;
 DateTime? lastSavedAt;

 if (projectId != null && projectId.isNotEmpty) {
 try {
 final doc = await _docRef(projectId).get();
 if (doc.exists) {
 nextState = _PlanningPageState.fromJson(
 widget.config,
 projectData,
 doc.data() ?? <String, dynamic>{},
 );
 lastSavedAt = _readTimestamp((doc.data() ?? {})['updatedAt']);
 } else {
 final legacyDoc = await _legacyDocRef(projectId).get();
 if (legacyDoc.exists) {
 nextState = _PlanningPageState.fromLegacy(
 widget.config,
 projectData,
 legacyDoc.data() ?? <String, dynamic>{},
 );
 importedLegacy = true;
 }
 }
 } catch (error) {
 debugPrint('Failed to load startup planning page: $error');
 }
 }

 if (!mounted) return;
 setState(() {
 _state = nextState;
 _legacyImported = importedLegacy;
 _lastSavedAt = lastSavedAt;
 _isLoading = false;
 _isHydrating = false;
 });

 if (importedLegacy) {
 await _save(showToast: false);
 }
 }

 Future<void> _save({bool showToast = false}) async {
 final projectId = ProjectDataHelper.getData(context).projectId;
 if (projectId == null || projectId.isEmpty) {
 if (showToast && mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Select a project to save this page.')),
 );
 }
 return;
 }

 if (mounted) setState(() => _isSaving = true);
 try {
 await _docRef(projectId).set(
 _state.toJson(widget.config),
 SetOptions(merge: true),
 );
 if (!mounted) return;
 setState(() {
 _isSaving = false;
 _lastSavedAt = DateTime.now();
 });
 if (showToast) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Page saved.')),
 );
 }
 } catch (error) {
 if (!mounted) return;
 setState(() => _isSaving = false);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Failed to save page: $error')),
 );
 }
 }

 void _scheduleSave() {
 if (_isHydrating) return;
 _debouncer.run(() => _save(showToast: false));
 }

 Future<void> _pickDate(
 DateTime? current,
 ValueChanged<DateTime?> onPicked,
 ) async {
 final now = DateTime.now();
 final picked = await showDatePicker(
 context: context,
 initialDate: current ?? now,
 firstDate: DateTime(now.year - 3),
 lastDate: DateTime(now.year + 5),
 );
 if (picked == null) return;
 setState(() => onPicked(picked));
 _scheduleSave();
 }

 Future<void> _attachFile() async {
 final projectId = ProjectDataHelper.getData(context).projectId;
 if (projectId == null || projectId.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Select a project to attach files.')),
 );
 return;
 }

 try {
 final result = await FilePicker.pickFiles(
 type: FileType.any,
 withData: true,
 );
 if (result == null || result.files.isEmpty) return;
 final file = result.files.first;
 final bytes = file.bytes;
 if (bytes == null) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Unable to read file bytes.')),
 );
 return;
 }

 setState(() => _isUploading = true);
 final extension = file.extension?.toLowerCase();
 final fileName = file.name;
 final storagePath =
 'projects/$projectId/startup_planning/${widget.config.documentId}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
 final storageRef = FirebaseStorage.instance.ref(storagePath);
 final snapshot = await storageRef.putData(
 bytes,
 SettableMetadata(contentType: _contentTypeForExtension(extension)),
 );
 final downloadUrl = await snapshot.ref.getDownloadURL();
 final attachment = _AttachmentMeta(
 id: storagePath,
 name: fileName,
 sizeBytes: file.size,
 extension: extension ?? '',
 storagePath: storagePath,
 downloadUrl: downloadUrl,
 uploadedAt: DateTime.now(),
 );
 if (!mounted) return;
 setState(() {
 _state.attachments = [..._state.attachments, attachment];
 _isUploading = false;
 });
 _scheduleSave();
 } catch (error) {
 if (!mounted) return;
 setState(() => _isUploading = false);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Failed to upload file: $error')),
 );
 }
 }

 Future<void> _removeAttachment(_AttachmentMeta attachment) async {
 setState(() {
 _state.attachments = [
 for (final item in _state.attachments)
 if (item.id != attachment.id) item,
 ];
 });
 _scheduleSave();
 if (attachment.storagePath.trim().isEmpty) return;
 try {
 await FirebaseStorage.instance.ref(attachment.storagePath).delete();
 } catch (error) {
 debugPrint('Failed to delete storage object: $error');
 }
 }

 Future<void> _exportPdf() async {
 try {
 final bytes = await _buildPdf();
 final filename =
 '${widget.config.documentId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
 if (kIsWeb) {
 download_helper.downloadFile(
 bytes,
 filename,
 mimeType: 'application/pdf',
 );
 } else {
 await Printing.sharePdf(bytes: bytes, filename: filename);
 }
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('PDF ready: $filename')),
 );
 } catch (error) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Failed to create PDF: $error')),
 );
 }
 }

 Future<Uint8List> _buildPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 final doc = pw.Document();
 final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
 final summary = _state.exportSections(widget.config);
 final metrics = _state.metrics(widget.config, projectData);

 pw.Widget block(String title, String value) {
 final display = value.trim().isEmpty ? 'Not provided' : value.trim();
 return pw.Padding(
 padding: const pw.EdgeInsets.only(bottom: 10),
 child: pw.Column(
 crossAxisAlignment: pw.CrossAxisAlignment.start,
 children: [
 pw.Text(
 title,
 style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
 ),
 pw.SizedBox(height: 4),
 pw.Text(display, style: const pw.TextStyle(fontSize: 11)),
 ],
 ),
 );
 }

 pw.Widget bulletSection(String title, List<String> items) {
 return pw.Padding(
 padding: const pw.EdgeInsets.only(bottom: 12),
 child: pw.Column(
 crossAxisAlignment: pw.CrossAxisAlignment.start,
 children: [
 pw.Text(
 title,
 style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
 ),
 pw.SizedBox(height: 4),
 if (items.isEmpty)
 pw.Text('No entries.', style: const pw.TextStyle(fontSize: 11))
 else
 pw.Column(
 crossAxisAlignment: pw.CrossAxisAlignment.start,
 children: items
 .map(
 (item) => pw.Padding(
 padding: const pw.EdgeInsets.only(bottom: 3),
 child: pw.Bullet(text: item),
 ),
 )
 .toList(),
 ),
 ],
 ),
 );
 }

 final projectLabel = projectData.projectName.trim().isNotEmpty
 ? projectData.projectName.trim()
 : projectData.solutionTitle.trim().isNotEmpty
 ? projectData.solutionTitle.trim()
 : 'Untitled Project';

 doc.addPage(
 pw.MultiPage(
 pageFormat: PdfPageFormat.a4,
 margin: const pw.EdgeInsets.all(30),
 build: (_) => [
 pw.Text(
 widget.config.title,
 style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
 ),
 pw.SizedBox(height: 6),
 pw.Text('Project: $projectLabel', style: const pw.TextStyle(fontSize: 11)),
 pw.Text('Generated: $now', style: const pw.TextStyle(fontSize: 10)),
 pw.SizedBox(height: 14),
 block('Purpose', widget.config.exportPurpose),
 bulletSection(
 'Readiness metrics',
 metrics.map((metric) => '${metric.label}: ${metric.value}').toList(),
 ),
 block('Narrative summary', _state.narrativeSummary),
 for (final entry in summary.entries) bulletSection(entry.key, entry.value),
 ],
 ),
 );
 return doc.save();
 }

 DocumentReference<Map<String, dynamic>> _docRef(String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('startup_planning')
 .doc(widget.config.documentId);
 }

 DocumentReference<Map<String, dynamic>> _legacyDocRef(String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('startup_planning_sections')
 .doc(widget.config.legacySectionId);
 }

 DateTime? _readTimestamp(dynamic value) {
 if (value is Timestamp) return value.toDate();
 if (value is DateTime) return value;
 if (value is String) return DateTime.tryParse(value);
 return null;
 }

 String _formatTime(DateTime? dateTime) {
 if (dateTime == null) return 'Not saved yet';
 return DateFormat('MMM d, HH:mm').format(dateTime);
 }

 String _contentTypeForExtension(String? extension) {
 switch ((extension ?? '').toLowerCase()) {
 case 'pdf':
 return 'application/pdf';
 case 'doc':
 return 'application/msword';
 case 'docx':
 return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
 case 'xls':
 return 'application/vnd.ms-excel';
 case 'xlsx':
 return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
 case 'png':
 return 'image/png';
 case 'jpg':
 case 'jpeg':
 return 'image/jpeg';
 case 'csv':
 return 'text/csv';
 default:
 return 'application/octet-stream';
 }
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final horizontalPadding = isMobile ? 20.0 : 32.0;
 final projectData = ProjectDataHelper.getData(context);
 final metrics = _state.metrics(widget.config, projectData);
 final blockers = _state.blockers(widget.config);
 final readiness = _state.readiness(widget.config);

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: InitiationLikeSidebar(
 activeItemLabel: widget.config.activeItemLabel,
 ),
 ),
 Expanded(
 child: Stack(
 children: [
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Start-Up Planning - Operations Plan and Manual',
 ),
 ),
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding,
 vertical: 24,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(
 title: widget.config.title,
 breadcrumbPhase: 'Planning Phase',
 breadcrumbTitle: 'Startup Planning',
 onBack: () => PlanningPhaseNavigation.goToPrevious(
 context,
 widget.config.checkpoint,
 ), onExportPdf: _exportPdf),
 const SizedBox(height: 12),
 Text(
 widget.config.subtitle,
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF6B7280),
 ),
 ),
 const SizedBox(height: 8),
 Text(
 widget.config.goalStatement,
 style: const TextStyle(
 fontSize: 13,
 height: 1.45,
 color: Color(0xFF374151),
 ),
 ),
 const SizedBox(height: 20),
 PlanningAiNotesCard(
 title: 'Context / Decisions',
 sectionLabel: widget.config.title,
 noteKey: widget.config.noteKey,
 checkpoint: widget.config.checkpoint,
 description:
 'Capture the project context, decisions, dependencies, and assumptions that shape this document.',
 ),
 const SizedBox(height: 20),
 if (_legacyImported)
 Container(
 width: double.infinity,
 margin: const EdgeInsets.only(bottom: 20),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFFFFBEB),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFFCD34D)),
 ),
 child: const Text(
 'Legacy content from the old startup planning page was imported into the new document structure. Review the generated summary and structured fields before sharing.',
 style: TextStyle(
 fontSize: 12,
 height: 1.5,
 color: Color(0xFF92400E),
 ),
 ),
 ),
 if (_isLoading) const LinearProgressIndicator(minHeight: 2),
 _ReadinessHero(
 readiness: readiness,
 blockers: blockers,
 owner: _state.primaryOwner,
 lastSavedLabel: _formatTime(_lastSavedAt),
 isSaving: _isSaving,
 isUploading: _isUploading,
 ),
 const SizedBox(height: 20),
 _MetricGrid(metrics: metrics),
 const SizedBox(height: 24),
 _DocumentControlBar(
 documentLabel: widget.config.exportLabel,
 summary: _state.documentStatusSummary(widget.config),
 onAttach: _attachFile,
 onExport: _exportPdf,
 onSave: () => _save(showToast: true),
 isSaving: _isSaving,
 ),
 const SizedBox(height: 16),
 _buildPageBody(projectData),
 const SizedBox(height: 20),
 _NarrativeSummaryCard(
 title: widget.config.summaryLabel,
 hintText: widget.config.summaryHint,
 value: _state.narrativeSummary,
 onChanged: (value) {
 setState(() => _state.narrativeSummary = value);
 _scheduleSave();
 },
 ),
 const SizedBox(height: 20),
 _AttachmentList(
 attachments: _state.attachments,
 onRemove: _removeAttachment,
 ),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel(
 widget.config.checkpoint,
 ),
 nextLabel: PlanningPhaseNavigation.nextLabel(
 widget.config.checkpoint,
 ),
 onBack: () => PlanningPhaseNavigation.goToPrevious(
 context,
 widget.config.checkpoint,
 ),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context,
 widget.config.checkpoint,
 ),
 ),
 const SizedBox(height: 40),
 ],
 ),
 ),
 const Positioned(
 right: 24,
 bottom: 24,
 child: KazAiChatBubble(positioned: false),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildPageBody(ProjectDataModel projectData) {
 switch (widget.config.pageType) {
 case _PageType.operations:
 return _OperationsPageBody(
 state: _state,
 onChanged: (state) {
 setState(() => _state = state);
 _scheduleSave();
 },
 );
 case _PageType.hypercare:
 return _HypercarePageBody(
 state: _state,
 onChanged: (state) {
 setState(() => _state = state);
 _scheduleSave();
 },
 onPickDate: _pickDate,
 );
 case _PageType.devops:
 return _DevOpsPageBody(
 state: _state,
 onChanged: (state) {
 setState(() => _state = state);
 _scheduleSave();
 },
 );
 case _PageType.closeout:
 return _CloseOutPageBody(
 state: _state,
 onChanged: (state) {
 setState(() => _state = state);
 _scheduleSave();
 },
 onPickDate: _pickDate,
 );
 }
 }
}

enum _PageType { operations, hypercare, devops, closeout }

class _PageConfig {
 const _PageConfig({
 required this.pageType,
 required this.title,
 required this.subtitle,
 required this.goalStatement,
 required this.noteKey,
 required this.checkpoint,
 required this.activeItemLabel,
 required this.documentId,
 required this.legacySectionId,
 required this.exportLabel,
 required this.exportPurpose,
 required this.summaryLabel,
 required this.summaryHint,
 });

 final _PageType pageType;
 final String title;
 final String subtitle;
 final String goalStatement;
 final String noteKey;
 final String checkpoint;
 final String activeItemLabel;
 final String documentId;
 final String legacySectionId;
 final String exportLabel;
 final String exportPurpose;
 final String summaryLabel;
 final String summaryHint;

 const _PageConfig.operations()
 : this(
 pageType: _PageType.operations,
 title: 'Operations Plan & Manual',
 subtitle:
 'Define the steady-state operating model, service controls, and operational handoff needed before go-live.',
 goalStatement:
 'This page should prove the solution can be operated safely on day 1 without relying on the project team as the fallback support model.',
 noteKey: 'planning_startup_operations_notes',
 checkpoint: 'startup_planning_operations',
 activeItemLabel: 'Start-Up Planning - Operations Plan and Manual',
 documentId: 'operations_plan_manual',
 legacySectionId: 'startup_operations_plan',
 exportLabel: 'Operational readiness document',
 exportPurpose:
 'Steady-state support readiness, service controls, runbooks, monitoring, recovery, and sign-off before go-live.',
 summaryLabel: 'Operational narrative summary',
 summaryHint:
 'Summarize how the service will be operated in steady state, including support ownership, runbook coverage, and operational guardrails.',
 );

 const _PageConfig.hypercare()
 : this(
 pageType: _PageType.hypercare,
 title: 'Hypercare Plan',
 subtitle:
 'Plan the short-term stabilization window in advance, with dates, owners, war-room cadence, and exit criteria.',
 goalStatement:
 'This page should define how the team will stabilize the solution immediately after go-live, not how the service operates forever.',
 noteKey: 'planning_startup_hypercare_notes',
 checkpoint: 'startup_planning_hypercare',
 activeItemLabel: 'Start-Up Planning - Hypercare Plan',
 documentId: 'hypercare_plan',
 legacySectionId: 'startup_hypercare_plan',
 exportLabel: 'Hypercare execution plan',
 exportPurpose:
 'Projected post-go-live support coverage, triage cadence, risk watchlist, user-support plan, and exit criteria.',
 summaryLabel: 'Hypercare narrative summary',
 summaryHint:
 'Describe the stabilization strategy, daily triage model, communications plan, and how the team will exit hypercare cleanly.',
 );

 const _PageConfig.devOps()
 : this(
 pageType: _PageType.devops,
 title: 'DevOps',
 subtitle:
 'Confirm the production delivery system is safe, observable, and recoverable before launch.',
 goalStatement:
 'This page should prove that releases can be deployed safely, monitored immediately, and restored quickly if anything fails.',
 noteKey: 'planning_startup_devops_notes',
 checkpoint: 'startup_planning_devops',
 activeItemLabel: 'Start-Up Planning - DevOps',
 documentId: 'devops_readiness',
 legacySectionId: 'startup_devops',
 exportLabel: 'DevOps readiness document',
 exportPurpose:
 'Environment topology, release controls, rollback strategy, observability, secrets/configuration, and DORA-style readiness baseline.',
 summaryLabel: 'DevOps narrative summary',
 summaryHint:
 'Describe the release path, deployment controls, rollback plan, observability posture, and what makes production change safe.',
 );

 const _PageConfig.closeOut()
 : this(
 pageType: _PageType.closeout,
 title: 'Close Out Plan',
 subtitle:
 'Define how delivery work, support handoff, knowledge transfer, and residual actions will be closed after launch.',
 goalStatement:
 'This page should close delivery cleanly by transferring ownership, open actions, lessons, and support knowledge without leaving hidden work behind.',
 noteKey: 'planning_startup_closeout_notes',
 checkpoint: 'startup_planning_closeout',
 activeItemLabel: 'Start-Up Planning - Close Out Plan',
 documentId: 'closeout_plan',
 legacySectionId: 'startup_closeout_plan',
 exportLabel: 'Close-out handoff document',
 exportPurpose:
 'Delivery and support handoff closure, knowledge transfer, residual action transfer, lessons learned, and follow-on ownership.',
 summaryLabel: 'Close-out narrative summary',
 summaryHint:
 'Summarize how the project will hand over support, close delivery ownership, transfer residual work, and preserve lessons learned.',
 );
}

class _PlanningMetric {
 const _PlanningMetric(this.label, this.value, this.color, this.helper);

 final String label;
 final String value;
 final Color color;
 final String helper;
}

class _PlanningPageState {
 _PlanningPageState({
 required this.primaryOwner,
 required this.secondaryOwner,
 required this.reviewCadence,
 required this.narrativeSummary,
 required this.operations,
 required this.hypercare,
 required this.devops,
 required this.closeout,
 required this.attachments,
 required this.legacyNarrative,
 });

 String primaryOwner;
 String secondaryOwner;
 String reviewCadence;
 String narrativeSummary;
 _OperationsData operations;
 _HypercareData hypercare;
 _DevOpsData devops;
 _CloseOutData closeout;
 List<_AttachmentMeta> attachments;
 String legacyNarrative;

 factory _PlanningPageState.empty() => _PlanningPageState(
 primaryOwner: '',
 secondaryOwner: '',
 reviewCadence: '',
 narrativeSummary: '',
 operations: _OperationsData.empty(),
 hypercare: _HypercareData.empty(),
 devops: _DevOpsData.empty(),
 closeout: _CloseOutData.empty(),
 attachments: const [],
 legacyNarrative: '',
 );

 factory _PlanningPageState.forConfig(
 _PageConfig config,
 ProjectDataModel projectData,
 ) {
 return _PlanningPageState(
 primaryOwner: '',
 secondaryOwner: '',
 reviewCadence: config.pageType == _PageType.hypercare ? 'Daily' : 'Weekly',
 narrativeSummary: '',
 operations: _OperationsData.seed(projectData),
 hypercare: _HypercareData.seed(projectData),
 devops: _DevOpsData.seed(projectData),
 closeout: _CloseOutData.seed(projectData),
 attachments: const [],
 legacyNarrative: '',
 );
 }

 factory _PlanningPageState.fromJson(
 _PageConfig config,
 ProjectDataModel projectData,
 Map<String, dynamic> json,
 ) {
 final seeded = _PlanningPageState.forConfig(config, projectData);
 return _PlanningPageState(
 primaryOwner: (json['primaryOwner'] as String?) ?? seeded.primaryOwner,
 secondaryOwner: (json['secondaryOwner'] as String?) ?? seeded.secondaryOwner,
 reviewCadence: (json['reviewCadence'] as String?) ?? seeded.reviewCadence,
 narrativeSummary: (json['narrativeSummary'] as String?) ?? seeded.narrativeSummary,
 operations: _OperationsData.fromJson(
 Map<String, dynamic>.from((json['operations'] as Map?) ?? const <String, dynamic>{}),
 seeded.operations,
 ),
 hypercare: _HypercareData.fromJson(
 Map<String, dynamic>.from((json['hypercare'] as Map?) ?? const <String, dynamic>{}),
 seeded.hypercare,
 ),
 devops: _DevOpsData.fromJson(
 Map<String, dynamic>.from((json['devops'] as Map?) ?? const <String, dynamic>{}),
 seeded.devops,
 ),
 closeout: _CloseOutData.fromJson(
 Map<String, dynamic>.from((json['closeout'] as Map?) ?? const <String, dynamic>{}),
 seeded.closeout,
 ),
 attachments: _decodeAttachments(json['attachments']),
 legacyNarrative: (json['legacyNarrative'] as String?) ?? '',
 );
 }

 factory _PlanningPageState.fromLegacy(
 _PageConfig config,
 ProjectDataModel projectData,
 Map<String, dynamic> json,
 ) {
 final seeded = _PlanningPageState.forConfig(config, projectData);
 final legacyBody = (json['body'] as String?) ?? '';
 final legacyMetrics = (json['metrics'] as List?)
 ?.whereType<Map>()
 .map((item) => '${item['label'] ?? 'Metric'}: ${item['value'] ?? ''}')
 .join('\n') ??
 '';
 final legacySections = (json['sections'] as List?)
 ?.whereType<Map>()
 .map((item) => (item['title'] ?? '').toString())
 .where((item) => item.trim().isNotEmpty)
 .join(', ') ??
 '';
 final imported = _PlanningPageState(
 primaryOwner: seeded.primaryOwner,
 secondaryOwner: seeded.secondaryOwner,
 reviewCadence: seeded.reviewCadence,
 narrativeSummary: legacyBody.trim(),
 operations: seeded.operations,
 hypercare: seeded.hypercare,
 devops: seeded.devops,
 closeout: seeded.closeout,
 attachments: _decodeAttachments(json['attachments']),
 legacyNarrative: [legacyBody, legacyMetrics, legacySections]
 .where((part) => part.trim().isNotEmpty)
 .join('\n\n'),
 );
 switch (config.pageType) {
 case _PageType.operations:
 imported.operations.manualMeasures = [if (legacyMetrics.trim().isNotEmpty) legacyMetrics.trim()];
 break;
 case _PageType.hypercare:
 imported.hypercare.watchItems = [if (legacySections.trim().isNotEmpty) _ChecklistEntry(title: legacySections.trim(), done: false)];
 break;
 case _PageType.devops:
 imported.devops.manualMeasures = [if (legacyMetrics.trim().isNotEmpty) legacyMetrics.trim()];
 break;
 case _PageType.closeout:
 imported.closeout.followOnActions = [if (legacySections.trim().isNotEmpty) _ChecklistEntry(title: legacySections.trim(), done: false)];
 break;
 }
 return imported;
 }

 Map<String, dynamic> toJson(_PageConfig config) => {
 'primaryOwner': primaryOwner,
 'secondaryOwner': secondaryOwner,
 'reviewCadence': reviewCadence,
 'narrativeSummary': narrativeSummary,
 'legacyNarrative': legacyNarrative,
 'attachments': attachments.map((item) => item.toJson()).toList(),
 'operations': operations.toJson(),
 'hypercare': hypercare.toJson(),
 'devops': devops.toJson(),
 'closeout': closeout.toJson(),
 'updatedAt': FieldValue.serverTimestamp(),
 'pageType': config.pageType.name,
 'documentTitle': config.title,
 };

 List<_PlanningMetric> metrics(_PageConfig config, ProjectDataModel projectData) {
 switch (config.pageType) {
 case _PageType.operations:
 return operations.metrics(primaryOwner);
 case _PageType.hypercare:
 return hypercare.metrics(primaryOwner);
 case _PageType.devops:
 return devops.metrics(primaryOwner);
 case _PageType.closeout:
 return closeout.metrics(primaryOwner);
 }
 }

 int readiness(_PageConfig config) {
 switch (config.pageType) {
 case _PageType.operations:
 return operations.readiness(primaryOwner);
 case _PageType.hypercare:
 return hypercare.readiness(primaryOwner);
 case _PageType.devops:
 return devops.readiness(primaryOwner);
 case _PageType.closeout:
 return closeout.readiness(primaryOwner);
 }
 }

 List<String> blockers(_PageConfig config) {
 switch (config.pageType) {
 case _PageType.operations:
 return operations.blockers(primaryOwner);
 case _PageType.hypercare:
 return hypercare.blockers(primaryOwner);
 case _PageType.devops:
 return devops.blockers(primaryOwner);
 case _PageType.closeout:
 return closeout.blockers(primaryOwner);
 }
 }

 Map<String, List<String>> exportSections(_PageConfig config) {
 switch (config.pageType) {
 case _PageType.operations:
 return operations.exportSections();
 case _PageType.hypercare:
 return hypercare.exportSections();
 case _PageType.devops:
 return devops.exportSections();
 case _PageType.closeout:
 return closeout.exportSections();
 }
 }

 String documentStatusSummary(_PageConfig config) {
 final base = switch (config.pageType) {
 _PageType.operations => 'Steady-state operating model',
 _PageType.hypercare => 'Projected stabilization plan',
 _PageType.devops => 'Production delivery safety model',
 _PageType.closeout => 'Delivery and support handoff plan',
 };
 return '$base • ${readiness(config)}% ready';
 }
}

class _OperationsData {
 _OperationsData({required this.serviceTier,required this.supportHours,required this.opsOwner,required this.engineeringOwner,required this.primarySupportTeam,required this.secondaryEscalationTeam,required this.sla,required this.slo,required this.rto,required this.rpo,required this.runbooks,required this.runbookRegister,required this.monitoringItems,required this.recoveryItems,required this.vendors,required this.manualMeasures,required this.goLiveApproved});
 String serviceTier; String supportHours; String opsOwner; String engineeringOwner; String primarySupportTeam; String secondaryEscalationTeam; String sla; String slo; String rto; String rpo; List<_ChecklistEntry> runbooks; List<_RunbookEntry> runbookRegister; List<_ChecklistEntry> monitoringItems; List<_ChecklistEntry> recoveryItems; List<_ContactEntry> vendors; List<String> manualMeasures; bool goLiveApproved;
 factory _OperationsData.empty() => _OperationsData.seed(ProjectDataModel());
 factory _OperationsData.seed(ProjectDataModel data) => _OperationsData(serviceTier:'Tier 2',supportHours:'Business hours with on-call escalation',opsOwner:'',engineeringOwner:'',primarySupportTeam:'Operations',secondaryEscalationTeam:'Engineering',sla:'',slo:'',rto:'',rpo:'',runbooks:const[_ChecklistEntry(title:'Startup and shutdown procedure',done:false),_ChecklistEntry(title:'Incident triage and escalation',done:false),_ChecklistEntry(title:'Known failure modes and rollback path',done:false)],runbookRegister:const[_RunbookEntry(name:'Startup and shutdown procedure',owner:'',documentLink:'',reviewDate:'',status:'Draft')],monitoringItems:const[_ChecklistEntry(title:'Golden signals defined',done:false),_ChecklistEntry(title:'Alert routing configured',done:false),_ChecklistEntry(title:'Dashboards linked in runbooks',done:false)],recoveryItems:const[_ChecklistEntry(title:'Backup procedure documented',done:false),_ChecklistEntry(title:'Restore test completed',done:false),_ChecklistEntry(title:'Disaster recovery owner confirmed',done:false)],vendors:const[_ContactEntry(name:'',role:'',contact:'')],manualMeasures:const[],goLiveApproved:false);
 factory _OperationsData.fromJson(Map<String,dynamic> json,_OperationsData seeded)=>_OperationsData(serviceTier:(json['serviceTier'] as String?)??seeded.serviceTier,supportHours:(json['supportHours'] as String?)??seeded.supportHours,opsOwner:(json['opsOwner'] as String?)??seeded.opsOwner,engineeringOwner:(json['engineeringOwner'] as String?)??seeded.engineeringOwner,primarySupportTeam:(json['primarySupportTeam'] as String?)??seeded.primarySupportTeam,secondaryEscalationTeam:(json['secondaryEscalationTeam'] as String?)??seeded.secondaryEscalationTeam,sla:(json['sla'] as String?)??seeded.sla,slo:(json['slo'] as String?)??seeded.slo,rto:(json['rto'] as String?)??seeded.rto,rpo:(json['rpo'] as String?)??seeded.rpo,runbooks:_decodeChecklistEntries(json['runbooks'],seeded.runbooks),runbookRegister:_decodeRunbooks(json['runbookRegister'],seeded.runbookRegister),monitoringItems:_decodeChecklistEntries(json['monitoringItems'],seeded.monitoringItems),recoveryItems:_decodeChecklistEntries(json['recoveryItems'],seeded.recoveryItems),vendors:_decodeContacts(json['vendors'],seeded.vendors),manualMeasures:_decodeStrings(json['manualMeasures']),goLiveApproved:(json['goLiveApproved'] as bool?)??false);
 Map<String,dynamic> toJson()=>{'serviceTier':serviceTier,'supportHours':supportHours,'opsOwner':opsOwner,'engineeringOwner':engineeringOwner,'primarySupportTeam':primarySupportTeam,'secondaryEscalationTeam':secondaryEscalationTeam,'sla':sla,'slo':slo,'rto':rto,'rpo':rpo,'runbooks':runbooks.map((e)=>e.toJson()).toList(),'runbookRegister':runbookRegister.map((e)=>e.toJson()).toList(),'monitoringItems':monitoringItems.map((e)=>e.toJson()).toList(),'recoveryItems':recoveryItems.map((e)=>e.toJson()).toList(),'vendors':vendors.map((e)=>e.toJson()).toList(),'manualMeasures':manualMeasures,'goLiveApproved':goLiveApproved};
 List<_PlanningMetric> metrics(String owner){final runbookReady=_percent(runbooks);final reviewedRunbooks=runbookRegister.where((r)=>r.status.toLowerCase()=='ready').length;final monitoringReady=_percent(monitoringItems);final recoveryReady=_percent(recoveryItems);final supportDefined=[opsOwner,engineeringOwner,primarySupportTeam].where((v)=>v.trim().isNotEmpty).length>=3;return[_PlanningMetric('Runbook coverage','$runbookReady%',_metricColor(runbookReady),'Derived from completed runbooks'),_PlanningMetric('Ready runbooks','$reviewedRunbooks/${runbookRegister.length}',reviewedRunbooks==runbookRegister.length?const Color(0xFF10B981):const Color(0xFFF59E0B),'Page-specific runbook register'),_PlanningMetric('Monitoring readiness','$monitoringReady%',_metricColor(monitoringReady),'Derived from alerting and dashboard setup'),_PlanningMetric('Recovery readiness','$recoveryReady%',_metricColor(recoveryReady),'Derived from backup, restore, and DR checks'),_PlanningMetric('Support model',supportDefined?'Defined':'Incomplete',supportDefined?const Color(0xFF10B981):const Color(0xFFF59E0B),'Auto-derived from owner and team fields')];}
 int readiness(String owner){final checks=<bool>[opsOwner.trim().isNotEmpty,engineeringOwner.trim().isNotEmpty,sla.trim().isNotEmpty||slo.trim().isNotEmpty,runbooks.any((i)=>i.done),monitoringItems.any((i)=>i.done),recoveryItems.any((i)=>i.done),goLiveApproved];return((checks.where((i)=>i).length/checks.length)*100).round();}
 List<String> blockers(String owner){final out=<String>[];if(opsOwner.trim().isEmpty) out.add('Assign an operations owner.');if(engineeringOwner.trim().isEmpty) out.add('Assign an engineering owner for escalations.');if(!runbooks.any((i)=>i.done)) out.add('Complete at least one production runbook.');if(!monitoringItems.any((i)=>i.done)) out.add('Define monitoring coverage and alert routing.');if(!goLiveApproved) out.add('Operational sign-off is still pending.');return out;}
 Map<String,List<String>> exportSections()=>{'Service overview':['Service tier: $serviceTier','Support hours: $supportHours',if(opsOwner.trim().isNotEmpty)'Ops owner: $opsOwner',if(engineeringOwner.trim().isNotEmpty)'Engineering owner: $engineeringOwner',if(primarySupportTeam.trim().isNotEmpty)'Primary support team: $primarySupportTeam',if(secondaryEscalationTeam.trim().isNotEmpty)'Escalation team: $secondaryEscalationTeam'],'Service targets':[if(sla.trim().isNotEmpty)'SLA: $sla',if(slo.trim().isNotEmpty)'SLO: $slo',if(rto.trim().isNotEmpty)'RTO: $rto',if(rpo.trim().isNotEmpty)'RPO: $rpo'],'Runbook register':runbookRegister.map((i)=>i.exportLine()).toList(),'Monitoring and alerting':monitoringItems.map((i)=>i.exportLine()).toList(),'Recovery and resilience':recoveryItems.map((i)=>i.exportLine()).toList(),'Dependencies and contacts':vendors.where((i)=>i.hasContent).map((i)=>i.exportLine()).toList(),if(manualMeasures.isNotEmpty)'Manual operating measures':manualMeasures};
}

class _HypercareData {
 _HypercareData({required this.startDate,required this.endDate,required this.coverageHours,required this.hypercareLead,required this.supportLead,required this.businessLead,required this.warRoomChannel,required this.dailyReviewTime,required this.severityModel,required this.validationChecks,required this.watchItems,required this.watchRegister,required this.exitCriteria,required this.communicationSteps,required this.handoverReady});
 DateTime? startDate; DateTime? endDate; String coverageHours; String hypercareLead; String supportLead; String businessLead; String warRoomChannel; String dailyReviewTime; String severityModel; List<_ChecklistEntry> validationChecks; List<_ChecklistEntry> watchItems; List<_WatchItemEntry> watchRegister; List<_ChecklistEntry> exitCriteria; List<String> communicationSteps; bool handoverReady;
 factory _HypercareData.empty()=>_HypercareData.seed(ProjectDataModel());
 factory _HypercareData.seed(ProjectDataModel data){final start=DateTime.now().add(const Duration(days:30));return _HypercareData(startDate:start,endDate:start.add(const Duration(days:14)),coverageHours:'07:00 - 19:00 daily',hypercareLead:'',supportLead:'',businessLead:'',warRoomChannel:'',dailyReviewTime:'09:00',severityModel:'P1/P2/P3 with 30-minute triage on P1',validationChecks:const[_ChecklistEntry(title:'Post-go-live smoke checks defined',done:false),_ChecklistEntry(title:'Transaction/data validation checks defined',done:false),_ChecklistEntry(title:'Adoption signal review defined',done:false)],watchItems:const[_ChecklistEntry(title:'Known high-risk integration',done:false),_ChecklistEntry(title:'Support process confusion risk',done:false)],watchRegister:const[_WatchItemEntry(item:'Known high-risk integration',owner:'',severity:'High',signal:'',response:'')],exitCriteria:const[_ChecklistEntry(title:'No open severity 1 issues',done:false),_ChecklistEntry(title:'Operational owner accepts steady-state handoff',done:false),_ChecklistEntry(title:'User-support backlog normalized',done:false)],communicationSteps:const['Daily stakeholder update'],handoverReady:false);} 
 factory _HypercareData.fromJson(Map<String,dynamic> json,_HypercareData seeded)=>_HypercareData(startDate:_readDate(json['startDate'])??seeded.startDate,endDate:_readDate(json['endDate'])??seeded.endDate,coverageHours:(json['coverageHours'] as String?)??seeded.coverageHours,hypercareLead:(json['hypercareLead'] as String?)??seeded.hypercareLead,supportLead:(json['supportLead'] as String?)??seeded.supportLead,businessLead:(json['businessLead'] as String?)??seeded.businessLead,warRoomChannel:(json['warRoomChannel'] as String?)??seeded.warRoomChannel,dailyReviewTime:(json['dailyReviewTime'] as String?)??seeded.dailyReviewTime,severityModel:(json['severityModel'] as String?)??seeded.severityModel,validationChecks:_decodeChecklistEntries(json['validationChecks'],seeded.validationChecks),watchItems:_decodeChecklistEntries(json['watchItems'],seeded.watchItems),watchRegister:_decodeWatchItems(json['watchRegister'],seeded.watchRegister),exitCriteria:_decodeChecklistEntries(json['exitCriteria'],seeded.exitCriteria),communicationSteps:_decodeStrings(json['communicationSteps']).isEmpty?seeded.communicationSteps:_decodeStrings(json['communicationSteps']),handoverReady:(json['handoverReady'] as bool?)??false);
 Map<String,dynamic> toJson()=>{'startDate':_encodeDate(startDate),'endDate':_encodeDate(endDate),'coverageHours':coverageHours,'hypercareLead':hypercareLead,'supportLead':supportLead,'businessLead':businessLead,'warRoomChannel':warRoomChannel,'dailyReviewTime':dailyReviewTime,'severityModel':severityModel,'validationChecks':validationChecks.map((e)=>e.toJson()).toList(),'watchItems':watchItems.map((e)=>e.toJson()).toList(),'watchRegister':watchRegister.map((e)=>e.toJson()).toList(),'exitCriteria':exitCriteria.map((e)=>e.toJson()).toList(),'communicationSteps':communicationSteps,'handoverReady':handoverReady};
 List<_PlanningMetric> metrics(String owner){final exitReady=_percent(exitCriteria);final validationsReady=_percent(validationChecks);final watchTracked=watchRegister.where((i)=>i.item.trim().isNotEmpty).length;final plannedWindow=startDate!=null&&endDate!=null?endDate!.difference(startDate!).inDays:0;return[_PlanningMetric('Coverage window',plannedWindow>0?'$plannedWindow days':'Not set',plannedWindow>=7?const Color(0xFF10B981):const Color(0xFFF59E0B),'Auto-derived from planned start/end dates'),_PlanningMetric('Validation readiness','$validationsReady%',_metricColor(validationsReady),'Derived from defined validation checks'),_PlanningMetric('Exit criteria','$exitReady%',_metricColor(exitReady),'Derived from completed exit conditions'),_PlanningMetric('Risk watchlist','$watchTracked tracked',watchTracked>0?const Color(0xFF2563EB):const Color(0xFFF59E0B),'Page-specific watch register')];}
 int readiness(String owner){final checks=<bool>[startDate!=null,endDate!=null,hypercareLead.trim().isNotEmpty,supportLead.trim().isNotEmpty,warRoomChannel.trim().isNotEmpty,validationChecks.any((i)=>i.done),exitCriteria.any((i)=>i.done),handoverReady];return((checks.where((i)=>i).length/checks.length)*100).round();}
 List<String> blockers(String owner){final out=<String>[];if(hypercareLead.trim().isEmpty) out.add('Assign the hypercare lead.');if(supportLead.trim().isEmpty) out.add('Assign the support lead for the stabilization window.');if(warRoomChannel.trim().isEmpty) out.add('Define the war-room or triage channel.');if(!validationChecks.any((i)=>i.done)) out.add('Define and complete at least one post-go-live validation check.');if(!handoverReady) out.add('Handover back to steady-state support is not yet ready.');return out;}
 Map<String,List<String>> exportSections()=>{'Hypercare window':['Start date: ${_formatDate(startDate)}','End date: ${_formatDate(endDate)}','Coverage hours: $coverageHours',if(dailyReviewTime.trim().isNotEmpty)'Daily review time: $dailyReviewTime'],'Owners and command structure':[if(hypercareLead.trim().isNotEmpty)'Hypercare lead: $hypercareLead',if(supportLead.trim().isNotEmpty)'Support lead: $supportLead',if(businessLead.trim().isNotEmpty)'Business lead: $businessLead',if(warRoomChannel.trim().isNotEmpty)'War room channel: $warRoomChannel',if(severityModel.trim().isNotEmpty)'Severity model: $severityModel'],'Validation checks':validationChecks.map((i)=>i.exportLine()).toList(),'Risk watchlist register':watchRegister.map((i)=>i.exportLine()).toList(),'Exit criteria':exitCriteria.map((i)=>i.exportLine()).toList(),'Communication plan':communicationSteps};
}
class _DevOpsData {
 _DevOpsData({required this.environmentTopology,required this.releaseOwner,required this.platformOwner,required this.deploymentStrategy,required this.rollbackStrategy,required this.approvalGates,required this.environments,required this.observabilityChecks,required this.observabilityRegister,required this.secretsChecks,required this.releaseChecklist,required this.doraDeploymentFrequency,required this.doraLeadTime,required this.doraChangeFailureRate,required this.doraRestoreTime,required this.manualMeasures,required this.devOpsApproved});
 String environmentTopology; String releaseOwner; String platformOwner; String deploymentStrategy; String rollbackStrategy; String approvalGates; List<_EnvironmentEntry> environments; List<_ChecklistEntry> observabilityChecks; List<_ObservabilityEntry> observabilityRegister; List<_ChecklistEntry> secretsChecks; List<_ChecklistEntry> releaseChecklist; String doraDeploymentFrequency; String doraLeadTime; String doraChangeFailureRate; String doraRestoreTime; List<String> manualMeasures; bool devOpsApproved;
 factory _DevOpsData.empty()=>_DevOpsData.seed(ProjectDataModel());
 factory _DevOpsData.seed(ProjectDataModel data)=>_DevOpsData(environmentTopology:'Dev -> Test -> Staging -> Production',releaseOwner:'',platformOwner:'',deploymentStrategy:'Progressive rollout',rollbackStrategy:'',approvalGates:'',environments:const[_EnvironmentEntry(name:'Staging',purpose:'Pre-production validation',ready:false),_EnvironmentEntry(name:'Production',purpose:'Live service',ready:false)],observabilityChecks:const[_ChecklistEntry(title:'Logs available in production',done:false),_ChecklistEntry(title:'Metrics dashboard linked',done:false),_ChecklistEntry(title:'Alerting tested end-to-end',done:false)],observabilityRegister:const[_ObservabilityEntry(component:'Core service',logs:'',metrics:'',alerts:'',dashboardLink:'',owner:'')],secretsChecks:const[_ChecklistEntry(title:'Secrets storage documented',done:false),_ChecklistEntry(title:'Config promotion path defined',done:false),_ChecklistEntry(title:'Drift control or change review defined',done:false)],releaseChecklist:const[_ChecklistEntry(title:'Rollback trigger defined',done:false),_ChecklistEntry(title:'Post-deploy validation checklist defined',done:false),_ChecklistEntry(title:'Approval gates confirmed',done:false)],doraDeploymentFrequency:'',doraLeadTime:'',doraChangeFailureRate:'',doraRestoreTime:'',manualMeasures:const[],devOpsApproved:false);
 factory _DevOpsData.fromJson(Map<String,dynamic> json,_DevOpsData seeded)=>_DevOpsData(environmentTopology:(json['environmentTopology'] as String?)??seeded.environmentTopology,releaseOwner:(json['releaseOwner'] as String?)??seeded.releaseOwner,platformOwner:(json['platformOwner'] as String?)??seeded.platformOwner,deploymentStrategy:(json['deploymentStrategy'] as String?)??seeded.deploymentStrategy,rollbackStrategy:(json['rollbackStrategy'] as String?)??seeded.rollbackStrategy,approvalGates:(json['approvalGates'] as String?)??seeded.approvalGates,environments:_decodeEnvironments(json['environments'],seeded.environments),observabilityChecks:_decodeChecklistEntries(json['observabilityChecks'],seeded.observabilityChecks),observabilityRegister:_decodeObservability(json['observabilityRegister'],seeded.observabilityRegister),secretsChecks:_decodeChecklistEntries(json['secretsChecks'],seeded.secretsChecks),releaseChecklist:_decodeChecklistEntries(json['releaseChecklist'],seeded.releaseChecklist),doraDeploymentFrequency:(json['doraDeploymentFrequency'] as String?)??seeded.doraDeploymentFrequency,doraLeadTime:(json['doraLeadTime'] as String?)??seeded.doraLeadTime,doraChangeFailureRate:(json['doraChangeFailureRate'] as String?)??seeded.doraChangeFailureRate,doraRestoreTime:(json['doraRestoreTime'] as String?)??seeded.doraRestoreTime,manualMeasures:_decodeStrings(json['manualMeasures']),devOpsApproved:(json['devOpsApproved'] as bool?)??false);
 Map<String,dynamic> toJson()=>{'environmentTopology':environmentTopology,'releaseOwner':releaseOwner,'platformOwner':platformOwner,'deploymentStrategy':deploymentStrategy,'rollbackStrategy':rollbackStrategy,'approvalGates':approvalGates,'environments':environments.map((e)=>e.toJson()).toList(),'observabilityChecks':observabilityChecks.map((e)=>e.toJson()).toList(),'observabilityRegister':observabilityRegister.map((e)=>e.toJson()).toList(),'secretsChecks':secretsChecks.map((e)=>e.toJson()).toList(),'releaseChecklist':releaseChecklist.map((e)=>e.toJson()).toList(),'doraDeploymentFrequency':doraDeploymentFrequency,'doraLeadTime':doraLeadTime,'doraChangeFailureRate':doraChangeFailureRate,'doraRestoreTime':doraRestoreTime,'manualMeasures':manualMeasures,'devOpsApproved':devOpsApproved};
 List<_PlanningMetric> metrics(String owner){final releaseReady=_percent(releaseChecklist);final observabilityReady=_percent(observabilityChecks);final coverageCount=observabilityRegister.where((i)=>i.component.trim().isNotEmpty).length;final configReady=_percent(secretsChecks);final envReady=environments.where((i)=>i.ready).length;return[_PlanningMetric('Release safety','$releaseReady%',_metricColor(releaseReady),'Derived from release and rollback controls'),_PlanningMetric('Observability','$observabilityReady%',_metricColor(observabilityReady),'Derived from logs, metrics, and alerts'),_PlanningMetric('Coverage rows','$coverageCount',coverageCount>0?const Color(0xFF2563EB):const Color(0xFFF59E0B),'Page-specific observability matrix'),_PlanningMetric('Secrets / config','$configReady%',_metricColor(configReady),'Derived from secrets and config controls'),_PlanningMetric('Ready environments','$envReady/${environments.length}',envReady==environments.length?const Color(0xFF10B981):const Color(0xFFF59E0B),'Manual readiness by environment')];}
 int readiness(String owner){final checks=<bool>[releaseOwner.trim().isNotEmpty,platformOwner.trim().isNotEmpty,rollbackStrategy.trim().isNotEmpty,approvalGates.trim().isNotEmpty,releaseChecklist.any((i)=>i.done),observabilityChecks.any((i)=>i.done),secretsChecks.any((i)=>i.done),devOpsApproved];return((checks.where((i)=>i).length/checks.length)*100).round();}
 List<String> blockers(String owner){final out=<String>[];if(releaseOwner.trim().isEmpty) out.add('Assign the release owner.');if(platformOwner.trim().isEmpty) out.add('Assign the platform owner.');if(rollbackStrategy.trim().isEmpty) out.add('Define the rollback or restore strategy.');if(!observabilityChecks.any((i)=>i.done)) out.add('Complete observability readiness checks.');if(!devOpsApproved) out.add('DevOps readiness approval is pending.');return out;}
 Map<String,List<String>> exportSections()=>{'Environment topology':['Topology: $environmentTopology',if(releaseOwner.trim().isNotEmpty)'Release owner: $releaseOwner',if(platformOwner.trim().isNotEmpty)'Platform owner: $platformOwner',if(deploymentStrategy.trim().isNotEmpty)'Deployment strategy: $deploymentStrategy',if(approvalGates.trim().isNotEmpty)'Approval gates: $approvalGates',if(rollbackStrategy.trim().isNotEmpty)'Rollback strategy: $rollbackStrategy'],'Environment readiness':environments.map((i)=>i.exportLine()).toList(),'Observability matrix':observabilityRegister.map((i)=>i.exportLine()).toList(),'Secrets and configuration':secretsChecks.map((i)=>i.exportLine()).toList(),'Release controls':releaseChecklist.map((i)=>i.exportLine()).toList(),'DORA baseline':[if(doraDeploymentFrequency.trim().isNotEmpty)'Deployment frequency: $doraDeploymentFrequency',if(doraLeadTime.trim().isNotEmpty)'Lead time: $doraLeadTime',if(doraChangeFailureRate.trim().isNotEmpty)'Change failure rate: $doraChangeFailureRate',if(doraRestoreTime.trim().isNotEmpty)'Time to restore service: $doraRestoreTime'],if(manualMeasures.isNotEmpty)'Manual DevOps measures':manualMeasures};
}

class _CloseOutData {
 _CloseOutData({required this.targetCloseDate,required this.deliveryOwner,required this.supportOwner,required this.acceptanceItems,required this.handoverArtifacts,required this.knowledgeTransfer,required this.residualActions,required this.residualRegister,required this.followOnActions,required this.lessonsLearned,required this.benefitsOwner,required this.benefitsReviewDate,required this.closeoutApproved});
 DateTime? targetCloseDate; String deliveryOwner; String supportOwner; List<_ChecklistEntry> acceptanceItems; List<_ChecklistEntry> handoverArtifacts; List<_ChecklistEntry> knowledgeTransfer; List<_ChecklistEntry> residualActions; List<_ResidualActionEntry> residualRegister; List<_ChecklistEntry> followOnActions; List<String> lessonsLearned; String benefitsOwner; DateTime? benefitsReviewDate; bool closeoutApproved;
 factory _CloseOutData.empty()=>_CloseOutData.seed(ProjectDataModel());
 factory _CloseOutData.seed(ProjectDataModel data)=>_CloseOutData(targetCloseDate:DateTime.now().add(const Duration(days:45)),deliveryOwner:'',supportOwner:'',acceptanceItems:const[_ChecklistEntry(title:'Business acceptance recorded',done:false),_ChecklistEntry(title:'Support handoff accepted',done:false),_ChecklistEntry(title:'Residual risks transferred',done:false)],handoverArtifacts:const[_ChecklistEntry(title:'Runbooks and SOPs shared',done:false),_ChecklistEntry(title:'Monitoring dashboard links shared',done:false),_ChecklistEntry(title:'Escalation contact sheet shared',done:false)],knowledgeTransfer:const[_ChecklistEntry(title:'Ops KT session complete',done:false),_ChecklistEntry(title:'Support KT session complete',done:false),_ChecklistEntry(title:'Open issues walkthrough complete',done:false)],residualActions:const[_ChecklistEntry(title:'Residual action owner assigned',done:false)],residualRegister:const[_ResidualActionEntry(action:'Residual action owner assigned',owner:'',dueDate:'',destinationTeam:'',status:'Open',handoffNote:'')],followOnActions:const[_ChecklistEntry(title:'Post-project improvement backlog created',done:false)],lessonsLearned:const[''],benefitsOwner:'',benefitsReviewDate:DateTime.now().add(const Duration(days:90)),closeoutApproved:false);
 factory _CloseOutData.fromJson(Map<String,dynamic> json,_CloseOutData seeded)=>_CloseOutData(targetCloseDate:_readDate(json['targetCloseDate'])??seeded.targetCloseDate,deliveryOwner:(json['deliveryOwner'] as String?)??seeded.deliveryOwner,supportOwner:(json['supportOwner'] as String?)??seeded.supportOwner,acceptanceItems:_decodeChecklistEntries(json['acceptanceItems'],seeded.acceptanceItems),handoverArtifacts:_decodeChecklistEntries(json['handoverArtifacts'],seeded.handoverArtifacts),knowledgeTransfer:_decodeChecklistEntries(json['knowledgeTransfer'],seeded.knowledgeTransfer),residualActions:_decodeChecklistEntries(json['residualActions'],seeded.residualActions),residualRegister:_decodeResidualActions(json['residualRegister'],seeded.residualRegister),followOnActions:_decodeChecklistEntries(json['followOnActions'],seeded.followOnActions),lessonsLearned:_decodeStrings(json['lessonsLearned']).isEmpty?seeded.lessonsLearned:_decodeStrings(json['lessonsLearned']),benefitsOwner:(json['benefitsOwner'] as String?)??seeded.benefitsOwner,benefitsReviewDate:_readDate(json['benefitsReviewDate'])??seeded.benefitsReviewDate,closeoutApproved:(json['closeoutApproved'] as bool?)??false);
 Map<String,dynamic> toJson()=>{'targetCloseDate':_encodeDate(targetCloseDate),'deliveryOwner':deliveryOwner,'supportOwner':supportOwner,'acceptanceItems':acceptanceItems.map((e)=>e.toJson()).toList(),'handoverArtifacts':handoverArtifacts.map((e)=>e.toJson()).toList(),'knowledgeTransfer':knowledgeTransfer.map((e)=>e.toJson()).toList(),'residualActions':residualActions.map((e)=>e.toJson()).toList(),'residualRegister':residualRegister.map((e)=>e.toJson()).toList(),'followOnActions':followOnActions.map((e)=>e.toJson()).toList(),'lessonsLearned':lessonsLearned,'benefitsOwner':benefitsOwner,'benefitsReviewDate':_encodeDate(benefitsReviewDate),'closeoutApproved':closeoutApproved};
 List<_PlanningMetric> metrics(String owner){final acceptanceReady=_percent(acceptanceItems);final handoffReady=_percent(handoverArtifacts);final knowledgeReady=_percent(knowledgeTransfer);final residualOpen=residualRegister.where((i)=>i.status.toLowerCase()!='closed').length;return[_PlanningMetric('Acceptance','$acceptanceReady%',_metricColor(acceptanceReady),'Derived from close-out acceptance items'),_PlanningMetric('Support handoff','$handoffReady%',_metricColor(handoffReady),'Derived from handoff artifacts'),_PlanningMetric('Knowledge transfer','$knowledgeReady%',_metricColor(knowledgeReady),'Derived from KT completion items'),_PlanningMetric('Residual actions open','$residualOpen',residualOpen==0?const Color(0xFF10B981):const Color(0xFFF59E0B),'Page-specific residual action register')];}
 int readiness(String owner){final checks=<bool>[deliveryOwner.trim().isNotEmpty,supportOwner.trim().isNotEmpty,acceptanceItems.any((i)=>i.done),handoverArtifacts.any((i)=>i.done),knowledgeTransfer.any((i)=>i.done),benefitsOwner.trim().isNotEmpty,closeoutApproved];return((checks.where((i)=>i).length/checks.length)*100).round();}
 List<String> blockers(String owner){final out=<String>[];if(deliveryOwner.trim().isEmpty) out.add('Assign the delivery owner.');if(supportOwner.trim().isEmpty) out.add('Assign the support owner.');if(!acceptanceItems.any((i)=>i.done)) out.add('Record at least one completed acceptance item.');if(!knowledgeTransfer.any((i)=>i.done)) out.add('Complete at least one knowledge-transfer action.');if(!closeoutApproved) out.add('Close-out approval is pending.');return out;}
 Map<String,List<String>> exportSections()=>{'Close-out timing and ownership':['Target close date: ${_formatDate(targetCloseDate)}',if(deliveryOwner.trim().isNotEmpty)'Delivery owner: $deliveryOwner',if(supportOwner.trim().isNotEmpty)'Support owner: $supportOwner',if(benefitsOwner.trim().isNotEmpty)'Benefits owner: $benefitsOwner','Benefits review date: ${_formatDate(benefitsReviewDate)}'],'Acceptance and closure':acceptanceItems.map((i)=>i.exportLine()).toList(),'Support handoff artifacts':handoverArtifacts.map((i)=>i.exportLine()).toList(),'Knowledge transfer':knowledgeTransfer.map((i)=>i.exportLine()).toList(),'Residual action register':residualRegister.map((i)=>i.exportLine()).toList(),'Follow-on actions':followOnActions.map((i)=>i.exportLine()).toList(),'Lessons learned':lessonsLearned.where((i)=>i.trim().isNotEmpty).toList()};
}

class _ChecklistEntry {
 const _ChecklistEntry({
 required this.title,
 required this.done,
 this.owner = '',
 this.notes = '',
 });

 final String title;
 final bool done;
 final String owner;
 final String notes;

 Map<String, dynamic> toJson() => {
 'title': title,
 'done': done,
 'owner': owner,
 'notes': notes,
 };

 String exportLine() {
 final meta = [
 if (owner.trim().isNotEmpty) 'Owner: ${owner.trim()}',
 if (notes.trim().isNotEmpty) 'Notes: ${notes.trim()}',
 ].join(' | ');
 return meta.isEmpty
 ? '${done ? '[Done]' : '[Open]'} $title'
 : '${done ? '[Done]' : '[Open]'} $title ($meta)';
 }
}
class _RunbookEntry { const _RunbookEntry({required this.name,required this.owner,required this.documentLink,required this.reviewDate,required this.status}); final String name; final String owner; final String documentLink; final String reviewDate; final String status; Map<String,dynamic> toJson()=>{'name':name,'owner':owner,'documentLink':documentLink,'reviewDate':reviewDate,'status':status}; String exportLine()=>[name,if(owner.trim().isNotEmpty)'Owner: $owner',if(documentLink.trim().isNotEmpty)'Link: $documentLink',if(reviewDate.trim().isNotEmpty)'Review: $reviewDate','Status: $status'].join(' | '); }
class _WatchItemEntry { const _WatchItemEntry({required this.item,required this.owner,required this.severity,required this.signal,required this.response}); final String item; final String owner; final String severity; final String signal; final String response; Map<String,dynamic> toJson()=>{'item':item,'owner':owner,'severity':severity,'signal':signal,'response':response}; String exportLine()=>[item,if(owner.trim().isNotEmpty)'Owner: $owner','Severity: $severity',if(signal.trim().isNotEmpty)'Signal: $signal',if(response.trim().isNotEmpty)'Response: $response'].join(' | '); }
class _ObservabilityEntry { const _ObservabilityEntry({required this.component,required this.logs,required this.metrics,required this.alerts,required this.dashboardLink,required this.owner}); final String component; final String logs; final String metrics; final String alerts; final String dashboardLink; final String owner; Map<String,dynamic> toJson()=>{'component':component,'logs':logs,'metrics':metrics,'alerts':alerts,'dashboardLink':dashboardLink,'owner':owner}; String exportLine()=>[component,if(logs.trim().isNotEmpty)'Logs: $logs',if(metrics.trim().isNotEmpty)'Metrics: $metrics',if(alerts.trim().isNotEmpty)'Alerts: $alerts',if(dashboardLink.trim().isNotEmpty)'Dashboard: $dashboardLink',if(owner.trim().isNotEmpty)'Owner: $owner'].join(' | '); }
class _ResidualActionEntry { const _ResidualActionEntry({required this.action,required this.owner,required this.dueDate,required this.destinationTeam,required this.status,required this.handoffNote}); final String action; final String owner; final String dueDate; final String destinationTeam; final String status; final String handoffNote; Map<String,dynamic> toJson()=>{'action':action,'owner':owner,'dueDate':dueDate,'destinationTeam':destinationTeam,'status':status,'handoffNote':handoffNote}; String exportLine()=>[action,if(owner.trim().isNotEmpty)'Owner: $owner',if(dueDate.trim().isNotEmpty)'Due: $dueDate',if(destinationTeam.trim().isNotEmpty)'Team: $destinationTeam','Status: $status',if(handoffNote.trim().isNotEmpty)'Note: $handoffNote'].join(' | '); }
class _ContactEntry { const _ContactEntry({required this.name,required this.role,required this.contact}); final String name; final String role; final String contact; bool get hasContent=>name.trim().isNotEmpty||role.trim().isNotEmpty||contact.trim().isNotEmpty; Map<String,dynamic> toJson()=>{'name':name,'role':role,'contact':contact}; String exportLine()=>[if(name.trim().isNotEmpty)name.trim(),if(role.trim().isNotEmpty)role.trim(),if(contact.trim().isNotEmpty)contact.trim()].join(' | '); }
class _EnvironmentEntry { const _EnvironmentEntry({required this.name,required this.purpose,required this.ready}); final String name; final String purpose; final bool ready; Map<String,dynamic> toJson()=>{'name':name,'purpose':purpose,'ready':ready}; String exportLine()=> '${ready ? '[Ready]' : '[Open]'} $name - $purpose'; }
class _AttachmentMeta { const _AttachmentMeta({required this.id,required this.name,required this.sizeBytes,required this.extension,required this.storagePath,required this.downloadUrl,required this.uploadedAt}); final String id; final String name; final int sizeBytes; final String extension; final String storagePath; final String downloadUrl; final DateTime uploadedAt; Map<String,dynamic> toJson()=>{'id':id,'name':name,'sizeBytes':sizeBytes,'extension':extension,'storagePath':storagePath,'downloadUrl':downloadUrl,'uploadedAt':Timestamp.fromDate(uploadedAt)}; }
List<_AttachmentMeta> _decodeAttachments(dynamic raw){ if(raw is! List) return []; return raw.whereType<Map>().map((item){final data=Map<String,dynamic>.from(item);return _AttachmentMeta(id:(data['id'] as String?)??'',name:(data['name'] as String?)??'Attachment',sizeBytes:(data['sizeBytes'] as num?)?.toInt()??0,extension:(data['extension'] as String?)??'',storagePath:(data['storagePath'] as String?)??'',downloadUrl:(data['downloadUrl'] as String?)??'',uploadedAt:_readDate(data['uploadedAt'])??DateTime.now());}).toList(); }
List<_ChecklistEntry> _decodeChecklistEntries(dynamic raw,List<_ChecklistEntry> fallback){ if(raw is! List) return fallback; final parsed=raw.whereType<Map>().map((item){final data=Map<String,dynamic>.from(item);return _ChecklistEntry(title:(data['title'] as String?)??'',done:(data['done'] as bool?)??false,owner:(data['owner'] as String?)??'',notes:(data['notes'] as String?)??'');}).toList(); return parsed.isEmpty?fallback:parsed; }
List<_RunbookEntry> _decodeRunbooks(dynamic raw,List<_RunbookEntry> fallback){ if(raw is! List) return fallback; final parsed=raw.whereType<Map>().map((item){final data=Map<String,dynamic>.from(item);return _RunbookEntry(name:(data['name'] as String?)??'',owner:(data['owner'] as String?)??'',documentLink:(data['documentLink'] as String?)??'',reviewDate:(data['reviewDate'] as String?)??'',status:(data['status'] as String?)??'Draft');}).toList(); return parsed.isEmpty?fallback:parsed; }
List<_WatchItemEntry> _decodeWatchItems(dynamic raw,List<_WatchItemEntry> fallback){ if(raw is! List) return fallback; final parsed=raw.whereType<Map>().map((item){final data=Map<String,dynamic>.from(item);return _WatchItemEntry(item:(data['item'] as String?)??'',owner:(data['owner'] as String?)??'',severity:(data['severity'] as String?)??'Medium',signal:(data['signal'] as String?)??'',response:(data['response'] as String?)??'');}).toList(); return parsed.isEmpty?fallback:parsed; }
List<_ObservabilityEntry> _decodeObservability(dynamic raw,List<_ObservabilityEntry> fallback){ if(raw is! List) return fallback; final parsed=raw.whereType<Map>().map((item){final data=Map<String,dynamic>.from(item);return _ObservabilityEntry(component:(data['component'] as String?)??'',logs:(data['logs'] as String?)??'',metrics:(data['metrics'] as String?)??'',alerts:(data['alerts'] as String?)??'',dashboardLink:(data['dashboardLink'] as String?)??'',owner:(data['owner'] as String?)??'');}).toList(); return parsed.isEmpty?fallback:parsed; }
List<_ResidualActionEntry> _decodeResidualActions(dynamic raw,List<_ResidualActionEntry> fallback){ if(raw is! List) return fallback; final parsed=raw.whereType<Map>().map((item){final data=Map<String,dynamic>.from(item);return _ResidualActionEntry(action:(data['action'] as String?)??'',owner:(data['owner'] as String?)??'',dueDate:(data['dueDate'] as String?)??'',destinationTeam:(data['destinationTeam'] as String?)??'',status:(data['status'] as String?)??'Open',handoffNote:(data['handoffNote'] as String?)??'');}).toList(); return parsed.isEmpty?fallback:parsed; }
List<_ContactEntry> _decodeContacts(dynamic raw,List<_ContactEntry> fallback){ if(raw is! List) return fallback; final parsed=raw.whereType<Map>().map((item){final data=Map<String,dynamic>.from(item);return _ContactEntry(name:(data['name'] as String?)??'',role:(data['role'] as String?)??'',contact:(data['contact'] as String?)??'');}).toList(); return parsed.isEmpty?fallback:parsed; }
List<_EnvironmentEntry> _decodeEnvironments(dynamic raw,List<_EnvironmentEntry> fallback){ if(raw is! List) return fallback; final parsed=raw.whereType<Map>().map((item){final data=Map<String,dynamic>.from(item);return _EnvironmentEntry(name:(data['name'] as String?)??'',purpose:(data['purpose'] as String?)??'',ready:(data['ready'] as bool?)??false);}).toList(); return parsed.isEmpty?fallback:parsed; }
List<String> _decodeStrings(dynamic raw){ if(raw is! List) return []; return raw.map((item)=>item.toString()).toList(); }
DateTime? _readDate(dynamic value){ if(value is Timestamp) return value.toDate(); if(value is DateTime) return value; if(value is String) return DateTime.tryParse(value); return null; }
String? _encodeDate(DateTime? value)=>value?.toIso8601String();
int _percent(List<_ChecklistEntry> items){ final active=items.where((i)=>i.title.trim().isNotEmpty).toList(); if(active.isEmpty) return 0; return ((active.where((i)=>i.done).length/active.length)*100).round(); }
Color _metricColor(int percent){ if(percent>=80) return const Color(0xFF10B981); if(percent>=50) return const Color(0xFFF59E0B); return const Color(0xFFEF4444); }
String _formatDate(DateTime? value){ if(value==null) return 'Not set'; return DateFormat('yyyy-MM-dd').format(value); }

class _ReadinessHero extends StatelessWidget { const _ReadinessHero({required this.readiness,required this.blockers,required this.owner,required this.lastSavedLabel,required this.isSaving,required this.isUploading}); final int readiness; final List<String> blockers; final String owner; final String lastSavedLabel; final bool isSaving; final bool isUploading; @override Widget build(BuildContext context){ final color=_metricColor(readiness); return Container(width:double.infinity,padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFFE5E7EB))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(width:64,height:64,decoration:BoxDecoration(color:color.withOpacity(0.12),borderRadius:BorderRadius.circular(20)),child:Center(child:Text('$readiness%',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:color)))),const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Document readiness',style:TextStyle(fontSize:16,fontWeight:FontWeight.w700)),const SizedBox(height:6),Text(blockers.isEmpty?'No blocking gaps are currently detected.':blockers.first,style:const TextStyle(fontSize:13,color:Color(0xFF4B5563),height:1.4))])),_StatusChip(label:owner.trim().isEmpty?'Owner not set':owner,color:const Color(0xFF2563EB),background:const Color(0xFFDBEAFE))]),const SizedBox(height:14),Wrap(spacing:8,runSpacing:8,children:[_StatusChip(label:'Saved $lastSavedLabel',color:const Color(0xFF16A34A),background:const Color(0xFFECFDF3)),if(isSaving) const _StatusChip(label:'Saving...',color:Color(0xFF64748B),background:Color(0xFFE2E8F0)),if(isUploading) const _StatusChip(label:'Uploading attachment...',color:Color(0xFF0F172A),background:Color(0xFFE2E8F0)),_StatusChip(label:'${blockers.length} blockers',color:blockers.isEmpty?const Color(0xFF16A34A):const Color(0xFFB45309),background:blockers.isEmpty?const Color(0xFFECFDF3):const Color(0xFFFEF3C7))]),if(blockers.isNotEmpty)...[const SizedBox(height:12),for(final blocker in blockers.take(4)) Padding(padding:const EdgeInsets.only(bottom:4),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Padding(padding:EdgeInsets.only(top:5),child:Icon(Icons.report_problem_outlined,size:14,color:Color(0xFFF59E0B))),const SizedBox(width:8),Expanded(child:Text(blocker,style:const TextStyle(fontSize:12,color:Color(0xFF4B5563),height:1.4)))]))]])); } }

class _MetricGrid extends StatelessWidget { const _MetricGrid({required this.metrics}); final List<_PlanningMetric> metrics; @override Widget build(BuildContext context)=>Wrap(spacing:16,runSpacing:16,children:metrics.map((metric)=>SizedBox(width:220,child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFFE5E7EB))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(metric.label,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:Color(0xFF6B7280))),const SizedBox(height:10),Text(metric.value,style:TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:metric.color)),const SizedBox(height:8),Text(metric.helper,style:const TextStyle(fontSize:11,height:1.4,color:Color(0xFF6B7280)))])))).toList()); }
class _DocumentControlBar extends StatelessWidget { const _DocumentControlBar({required this.documentLabel,required this.summary,required this.onAttach,required this.onExport,required this.onSave,required this.isSaving}); final String documentLabel; final String summary; final VoidCallback onAttach; final VoidCallback onExport; final VoidCallback onSave; final bool isSaving; @override Widget build(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFFE5E7EB))),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(documentLabel,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700)),const SizedBox(height:6),Text(summary,style:const TextStyle(fontSize:12,color:Color(0xFF6B7280)))])),const SizedBox(width:12),OutlinedButton.icon(onPressed:onAttach,icon:const Icon(Icons.attach_file,size:18),label:const Text('Attach')),const SizedBox(width:8),OutlinedButton.icon(onPressed:onExport,icon:const Icon(Icons.picture_as_pdf_outlined,size:18),label:const Text('Export PDF')),const SizedBox(width:8),ElevatedButton.icon(onPressed:isSaving?null:onSave,icon:const Icon(Icons.save_outlined,size:18),label:const Text('Save'))])); }
class _NarrativeSummaryCard extends StatelessWidget { const _NarrativeSummaryCard({required this.title,required this.hintText,required this.value,required this.onChanged}); final String title; final String hintText; final String value; final ValueChanged<String> onChanged; @override Widget build(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFFE5E7EB))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700)),const SizedBox(height:10),TextFormField(initialValue:value,maxLines:null,decoration:_fieldDecoration(hintText),onChanged:onChanged)])); }
class _AttachmentList extends StatelessWidget { const _AttachmentList({required this.attachments,required this.onRemove}); final List<_AttachmentMeta> attachments; final ValueChanged<_AttachmentMeta> onRemove; @override Widget build(BuildContext context){ if(attachments.isEmpty) return const SizedBox.shrink(); return Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFFE5E7EB))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Attachments',style:TextStyle(fontSize:16,fontWeight:FontWeight.w700)),const SizedBox(height:10),          for (final attachment in attachments)
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(attachment.name),
                subtitle: Text(
                    '${attachment.extension.toUpperCase()} • ${attachment.sizeBytes} bytes'),
                trailing: IconButton(
                    onPressed: () => onRemove(attachment),
                    icon: const Icon(Icons.delete_outline)),
              ),
            ) ])); } }

class _OperationsPageBody extends StatelessWidget {
 const _OperationsPageBody({required this.state, required this.onChanged});
 final _PlanningPageState state;
 final ValueChanged<_PlanningPageState> onChanged;
 @override
 Widget build(BuildContext context) {
 final data = state.operations;
 return Column(children: [
 _SimpleFormCard(
 title: 'Service and ownership',
 children: [
 _SimpleField(label: 'Document owner', initialValue: state.primaryOwner, onChanged: (v) { state.primaryOwner = v.trim(); onChanged(state); }),
 _SimpleField(label: 'Ops owner', initialValue: data.opsOwner, onChanged: (v) { data.opsOwner = v.trim(); onChanged(state); }),
 _SimpleField(label: 'Engineering owner', initialValue: data.engineeringOwner, onChanged: (v) { data.engineeringOwner = v.trim(); onChanged(state); }),
 _SimpleField(label: 'Support hours', initialValue: data.supportHours, onChanged: (v) { data.supportHours = v.trim(); onChanged(state); }),
 _SimpleField(label: 'SLA / SLO', initialValue: '${data.sla}${data.slo.isNotEmpty ? ' | ${data.slo}' : ''}', onChanged: (v) { final parts = v.split('|'); data.sla = parts.first.trim(); data.slo = parts.length > 1 ? parts[1].trim() : ''; onChanged(state); }),
 _SimpleField(label: 'RTO / RPO', initialValue: '${data.rto}${data.rpo.isNotEmpty ? ' | ${data.rpo}' : ''}', onChanged: (v) { final parts = v.split('|'); data.rto = parts.first.trim(); data.rpo = parts.length > 1 ? parts[1].trim() : ''; onChanged(state); }),
 ],
 ),
 const SizedBox(height: 16),
 _RunbookRegisterCard(rows: data.runbookRegister, onChanged: (rows) { data.runbookRegister = rows; onChanged(state); }),
 const SizedBox(height: 16),
 _ChecklistCard(title: 'Monitoring and alerting register', items: data.monitoringItems, onChanged: (items) { data.monitoringItems = items; onChanged(state); }),
 const SizedBox(height: 16),
 _ChecklistCard(title: 'Recovery and resilience register', items: data.recoveryItems, onChanged: (items) { data.recoveryItems = items; onChanged(state); }),
 const SizedBox(height: 16),
 SwitchListTile.adaptive(value: data.goLiveApproved, title: const Text('Operational sign-off complete'), onChanged: (v) { data.goLiveApproved = v; onChanged(state); }),
 ]);
 }
}

class _HypercarePageBody extends StatelessWidget {
 const _HypercarePageBody({required this.state, required this.onChanged, required this.onPickDate});
 final _PlanningPageState state;
 final ValueChanged<_PlanningPageState> onChanged;
 final Future<void> Function(DateTime?, ValueChanged<DateTime?>) onPickDate;
 @override
 Widget build(BuildContext context) {
 final data = state.hypercare;
 return Column(children: [
 _SimpleFormCard(
 title: 'Projected hypercare window',
 children: [
 _SimpleField(label: 'Document owner', initialValue: state.primaryOwner, onChanged: (v) { state.primaryOwner = v.trim(); onChanged(state); }),
 _DateButton(label: 'Start date', value: data.startDate, onTap: () => onPickDate(data.startDate, (picked) => data.startDate = picked)),
 _DateButton(label: 'End date', value: data.endDate, onTap: () => onPickDate(data.endDate, (picked) => data.endDate = picked)),
 _SimpleField(label: 'Hypercare lead', initialValue: data.hypercareLead, onChanged: (v) { data.hypercareLead = v.trim(); onChanged(state); }),
 _SimpleField(label: 'Support lead', initialValue: data.supportLead, onChanged: (v) { data.supportLead = v.trim(); onChanged(state); }),
 _SimpleField(label: 'War-room channel', initialValue: data.warRoomChannel, onChanged: (v) { data.warRoomChannel = v.trim(); onChanged(state); }),
 ],
 ),
 const SizedBox(height: 16),
 _ChecklistCard(title: 'Validation register', items: data.validationChecks, onChanged: (items) { data.validationChecks = items; onChanged(state); }),
 const SizedBox(height: 16),
 _WatchRegisterCard(rows: data.watchRegister, onChanged: (rows) { data.watchRegister = rows; onChanged(state); }),
 const SizedBox(height: 16),
 _ChecklistCard(title: 'Exit criteria register', items: data.exitCriteria, onChanged: (items) { data.exitCriteria = items; onChanged(state); }),
 const SizedBox(height: 16),
 _SimpleFieldBlock(label: 'Communication plan', initialValue: data.communicationSteps.join('\n'), onChanged: (v) { data.communicationSteps = v.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(); onChanged(state); }),
 const SizedBox(height: 16),
 SwitchListTile.adaptive(value: data.handoverReady, title: const Text('Ready to exit hypercare'), onChanged: (v) { data.handoverReady = v; onChanged(state); }),
 ]);
 }
}

class _DevOpsPageBody extends StatelessWidget {
 const _DevOpsPageBody({required this.state, required this.onChanged});
 final _PlanningPageState state;
 final ValueChanged<_PlanningPageState> onChanged;
 @override
 Widget build(BuildContext context) {
 final data = state.devops;
 return Column(children: [
 _SimpleFormCard(
 title: 'Release ownership and controls',
 children: [
 _SimpleField(label: 'Document owner', initialValue: state.primaryOwner, onChanged: (v) { state.primaryOwner = v.trim(); onChanged(state); }),
 _SimpleField(label: 'Release owner', initialValue: data.releaseOwner, onChanged: (v) { data.releaseOwner = v.trim(); onChanged(state); }),
 _SimpleField(label: 'Platform owner', initialValue: data.platformOwner, onChanged: (v) { data.platformOwner = v.trim(); onChanged(state); }),
 _SimpleField(label: 'Environment topology', initialValue: data.environmentTopology, onChanged: (v) { data.environmentTopology = v.trim(); onChanged(state); }),
 _SimpleField(label: 'Deployment strategy', initialValue: data.deploymentStrategy, onChanged: (v) { data.deploymentStrategy = v.trim(); onChanged(state); }),
 _SimpleField(label: 'Rollback strategy', initialValue: data.rollbackStrategy, onChanged: (v) { data.rollbackStrategy = v.trim(); onChanged(state); }),
 ],
 ),
 const SizedBox(height: 16),
 _ObservabilityRegisterCard(rows: data.observabilityRegister, onChanged: (rows) { data.observabilityRegister = rows; onChanged(state); }),
 const SizedBox(height: 16),
 _ChecklistCard(title: 'Secrets and configuration register', items: data.secretsChecks, onChanged: (items) { data.secretsChecks = items; onChanged(state); }),
 const SizedBox(height: 16),
 _ChecklistCard(title: 'Release controls register', items: data.releaseChecklist, onChanged: (items) { data.releaseChecklist = items; onChanged(state); }),
 const SizedBox(height: 16),
 _SimpleFieldBlock(label: 'DORA baseline', initialValue: 'Deployment frequency: ${data.doraDeploymentFrequency}\nLead time: ${data.doraLeadTime}\nChange failure rate: ${data.doraChangeFailureRate}\nRestore time: ${data.doraRestoreTime}', onChanged: (v) { final lines = v.split('\n'); data.doraDeploymentFrequency = lines.isNotEmpty ? lines[0].replaceFirst('Deployment frequency:', '').trim() : ''; data.doraLeadTime = lines.length > 1 ? lines[1].replaceFirst('Lead time:', '').trim() : ''; data.doraChangeFailureRate = lines.length > 2 ? lines[2].replaceFirst('Change failure rate:', '').trim() : ''; data.doraRestoreTime = lines.length > 3 ? lines[3].replaceFirst('Restore time:', '').trim() : ''; onChanged(state); }),
 const SizedBox(height: 16),
 SwitchListTile.adaptive(value: data.devOpsApproved, title: const Text('DevOps readiness approved'), onChanged: (v) { data.devOpsApproved = v; onChanged(state); }),
 ]);
 }
}

class _CloseOutPageBody extends StatelessWidget {
 const _CloseOutPageBody({required this.state, required this.onChanged, required this.onPickDate});
 final _PlanningPageState state;
 final ValueChanged<_PlanningPageState> onChanged;
 final Future<void> Function(DateTime?, ValueChanged<DateTime?>) onPickDate;
 @override
 Widget build(BuildContext context) {
 final data = state.closeout;
 return Column(children: [
 _SimpleFormCard(
 title: 'Close-out ownership',
 children: [
 _SimpleField(label: 'Document owner', initialValue: state.primaryOwner, onChanged: (v) { state.primaryOwner = v.trim(); onChanged(state); }),
 _DateButton(label: 'Target close date', value: data.targetCloseDate, onTap: () => onPickDate(data.targetCloseDate, (picked) => data.targetCloseDate = picked)),
 _SimpleField(label: 'Delivery owner', initialValue: data.deliveryOwner, onChanged: (v) { data.deliveryOwner = v.trim(); onChanged(state); }),
 _SimpleField(label: 'Support owner', initialValue: data.supportOwner, onChanged: (v) { data.supportOwner = v.trim(); onChanged(state); }),
 _SimpleField(label: 'Benefits owner', initialValue: data.benefitsOwner, onChanged: (v) { data.benefitsOwner = v.trim(); onChanged(state); }),
 _DateButton(label: 'Benefits review date', value: data.benefitsReviewDate, onTap: () => onPickDate(data.benefitsReviewDate, (picked) => data.benefitsReviewDate = picked)),
 ],
 ),
 const SizedBox(height: 16),
 _ChecklistCard(title: 'Acceptance register', items: data.acceptanceItems, onChanged: (items) { data.acceptanceItems = items; onChanged(state); }),
 const SizedBox(height: 16),
 _ChecklistCard(title: 'Support handoff register', items: data.handoverArtifacts, onChanged: (items) { data.handoverArtifacts = items; onChanged(state); }),
 const SizedBox(height: 16),
 _ChecklistCard(title: 'Knowledge transfer register', items: data.knowledgeTransfer, onChanged: (items) { data.knowledgeTransfer = items; onChanged(state); }),
 const SizedBox(height: 16),
 _ResidualActionRegisterCard(rows: data.residualRegister, onChanged: (rows) { data.residualRegister = rows; onChanged(state); }),
 const SizedBox(height: 16),
 _SimpleFieldBlock(label: 'Lessons learned', initialValue: data.lessonsLearned.join('\n'), onChanged: (v) { data.lessonsLearned = v.split('\n'); onChanged(state); }),
 const SizedBox(height: 16),
 SwitchListTile.adaptive(value: data.closeoutApproved, title: const Text('Close-out approved'), onChanged: (v) { data.closeoutApproved = v; onChanged(state); }),
 ]);
 }
}

class _SimpleFormCard extends StatelessWidget {
 const _SimpleFormCard({required this.title, required this.children});
 final String title;
 final List<Widget> children;
 @override
 Widget build(BuildContext context) => Container(
 width: double.infinity,
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 12), Wrap(spacing: 12, runSpacing: 12, children: children)]),
 );
}

class _SimpleField extends StatelessWidget {
 const _SimpleField({required this.label, required this.initialValue, required this.onChanged});
 final String label;
 final String initialValue;
 final ValueChanged<String> onChanged;
 @override
 Widget build(BuildContext context) => SizedBox(
 width: 280,
 child: VoiceTextFormField(initialValue: initialValue, decoration: _fieldDecoration(label), onChanged: onChanged),
 );
}

class _SimpleFieldBlock extends StatelessWidget {
 const _SimpleFieldBlock({required this.label, required this.initialValue, required this.onChanged});
 final String label;
 final String initialValue;
 final ValueChanged<String> onChanged;
 @override
 Widget build(BuildContext context) => Container(
 width: double.infinity,
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 12), VoiceTextFormField(initialValue: initialValue, maxLines: null, decoration: _fieldDecoration(label), onChanged: onChanged)]),
 );
}

class _DateButton extends StatelessWidget {
 const _DateButton({required this.label, required this.value, required this.onTap});
 final String label;
 final DateTime? value;
 final VoidCallback onTap;
 @override
 Widget build(BuildContext context) => SizedBox(
 width: 280,
 child: OutlinedButton(
 onPressed: onTap,
 child: Text('$label: ${_formatDate(value)}'),
 ),
 );
}

class _ChecklistCard extends StatelessWidget {
 const _ChecklistCard({
 required this.title,
 required this.items,
 required this.onChanged,
 });

 final String title;
 final List<_ChecklistEntry> items;
 final ValueChanged<List<_ChecklistEntry>> onChanged;

 @override
 Widget build(BuildContext context) {
 final safeItems =
 items.isEmpty ? const [_ChecklistEntry(title: '', done: false)] : items;
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 12),
 for (var i = 0; i < safeItems.length; i++)
 Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _ChecklistRow(
 entry: safeItems[i],
 onChanged: (updated) {
 final copy = [...safeItems];
 copy[i] = updated;
 onChanged(copy);
 },
 onRemove: safeItems.length <= 1
 ? null
 : () {
 final copy = [...safeItems]..removeAt(i);
 onChanged(copy);
 },
 ),
 ),
 TextButton.icon(
 onPressed: () => onChanged([
 ...safeItems,
 const _ChecklistEntry(title: '', done: false),
 ]),
 icon: const Icon(Icons.add),
 label: const Text('Add row'),
 ),
 ],
 ),
 );
 }
}

class _ChecklistRow extends StatelessWidget {
 const _ChecklistRow({
 required this.entry,
 required this.onChanged,
 this.onRemove,
 });

 final _ChecklistEntry entry;
 final ValueChanged<_ChecklistEntry> onChanged;
 final VoidCallback? onRemove;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 children: [
 Row(
 children: [
 Checkbox(
 value: entry.done,
 onChanged: (value) => onChanged(
 _ChecklistEntry(
 title: entry.title,
 done: value ?? false,
 owner: entry.owner,
 notes: entry.notes,
 ),
 ),
 ),
 Expanded(
 flex: 3,
 child: VoiceTextFormField(
 initialValue: entry.title,
 decoration: _fieldDecoration('Item / deliverable'),
 onChanged: (value) => onChanged(
 _ChecklistEntry(
 title: value.trim(),
 done: entry.done,
 owner: entry.owner,
 notes: entry.notes,
 ),
 ),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 flex: 2,
 child: VoiceTextFormField(
 initialValue: entry.owner,
 decoration: _fieldDecoration('Owner'),
 onChanged: (value) => onChanged(
 _ChecklistEntry(
 title: entry.title,
 done: entry.done,
 owner: value.trim(),
 notes: entry.notes,
 ),
 ),
 ),
 ),
 if (onRemove != null)
 IconButton(
 onPressed: onRemove,
 icon: const Icon(Icons.delete_outline),
 ),
 ],
 ),
 const SizedBox(height: 8),
 VoiceTextFormField(
 initialValue: entry.notes,
 maxLines: 2,
 decoration: _fieldDecoration('Notes / evidence / link / trigger'),
 onChanged: (value) => onChanged(
 _ChecklistEntry(
 title: entry.title,
 done: entry.done,
 owner: entry.owner,
 notes: value.trim(),
 ),
 ),
 ),
 ],
 ),
 );
 }
}

class _RunbookRegisterCard extends StatelessWidget {
 const _RunbookRegisterCard({required this.rows, required this.onChanged});
 final List<_RunbookEntry> rows;
 final ValueChanged<List<_RunbookEntry>> onChanged;
 @override
 Widget build(BuildContext context) {
 final safeRows = rows.isEmpty ? const [_RunbookEntry(name: '', owner: '', documentLink: '', reviewDate: '', status: 'Draft')] : rows;
 return _RegisterShell(
 title: 'Runbook register',
 child: Column(children: [
 for (var i = 0; i < safeRows.length; i++)
 Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _RegisterRow(
 onRemove: safeRows.length <= 1 ? null : () { final copy = [...safeRows]..removeAt(i); onChanged(copy); },
 children: [
 _registerField('Runbook', safeRows[i].name, (v) { final copy = [...safeRows]; copy[i] = _RunbookEntry(name: v.trim(), owner: copy[i].owner, documentLink: copy[i].documentLink, reviewDate: copy[i].reviewDate, status: copy[i].status); onChanged(copy); }),
 _registerField('Owner', safeRows[i].owner, (v) { final copy = [...safeRows]; copy[i] = _RunbookEntry(name: copy[i].name, owner: v.trim(), documentLink: copy[i].documentLink, reviewDate: copy[i].reviewDate, status: copy[i].status); onChanged(copy); }),
 _registerField('Link / doc', safeRows[i].documentLink, (v) { final copy = [...safeRows]; copy[i] = _RunbookEntry(name: copy[i].name, owner: copy[i].owner, documentLink: v.trim(), reviewDate: copy[i].reviewDate, status: copy[i].status); onChanged(copy); }),
 _registerField('Review date', safeRows[i].reviewDate, (v) { final copy = [...safeRows]; copy[i] = _RunbookEntry(name: copy[i].name, owner: copy[i].owner, documentLink: copy[i].documentLink, reviewDate: v.trim(), status: copy[i].status); onChanged(copy); }),
 _registerField('Status', safeRows[i].status, (v) { final copy = [...safeRows]; copy[i] = _RunbookEntry(name: copy[i].name, owner: copy[i].owner, documentLink: copy[i].documentLink, reviewDate: copy[i].reviewDate, status: v.trim()); onChanged(copy); }),
 ],
 ),
 ),
 Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => onChanged([...safeRows, const _RunbookEntry(name: '', owner: '', documentLink: '', reviewDate: '', status: 'Draft')]), icon: const Icon(Icons.add), label: const Text('Add runbook'))),
 ]),
 );
 }
}

class _WatchRegisterCard extends StatelessWidget {
 const _WatchRegisterCard({required this.rows, required this.onChanged});
 final List<_WatchItemEntry> rows;
 final ValueChanged<List<_WatchItemEntry>> onChanged;
 @override
 Widget build(BuildContext context) {
 final safeRows = rows.isEmpty ? const [_WatchItemEntry(item: '', owner: '', severity: 'Medium', signal: '', response: '')] : rows;
 return _RegisterShell(
 title: 'Risk watchlist register',
 child: Column(children: [
 for (var i = 0; i < safeRows.length; i++)
 Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _RegisterRow(
 onRemove: safeRows.length <= 1 ? null : () { final copy = [...safeRows]..removeAt(i); onChanged(copy); },
 children: [
 _registerField('Risk / watch item', safeRows[i].item, (v) { final copy = [...safeRows]; copy[i] = _WatchItemEntry(item: v.trim(), owner: copy[i].owner, severity: copy[i].severity, signal: copy[i].signal, response: copy[i].response); onChanged(copy); }),
 _registerField('Owner', safeRows[i].owner, (v) { final copy = [...safeRows]; copy[i] = _WatchItemEntry(item: copy[i].item, owner: v.trim(), severity: copy[i].severity, signal: copy[i].signal, response: copy[i].response); onChanged(copy); }),
 _registerField('Severity', safeRows[i].severity, (v) { final copy = [...safeRows]; copy[i] = _WatchItemEntry(item: copy[i].item, owner: copy[i].owner, severity: v.trim(), signal: copy[i].signal, response: copy[i].response); onChanged(copy); }),
 _registerField('Signal', safeRows[i].signal, (v) { final copy = [...safeRows]; copy[i] = _WatchItemEntry(item: copy[i].item, owner: copy[i].owner, severity: copy[i].severity, signal: v.trim(), response: copy[i].response); onChanged(copy); }),
 _registerField('Response', safeRows[i].response, (v) { final copy = [...safeRows]; copy[i] = _WatchItemEntry(item: copy[i].item, owner: copy[i].owner, severity: copy[i].severity, signal: copy[i].signal, response: v.trim()); onChanged(copy); }),
 ],
 ),
 ),
 Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => onChanged([...safeRows, const _WatchItemEntry(item: '', owner: '', severity: 'Medium', signal: '', response: '')]), icon: const Icon(Icons.add), label: const Text('Add watch item'))),
 ]),
 );
 }
}

class _ObservabilityRegisterCard extends StatelessWidget {
 const _ObservabilityRegisterCard({required this.rows, required this.onChanged});
 final List<_ObservabilityEntry> rows;
 final ValueChanged<List<_ObservabilityEntry>> onChanged;
 @override
 Widget build(BuildContext context) {
 final safeRows = rows.isEmpty ? const [_ObservabilityEntry(component: '', logs: '', metrics: '', alerts: '', dashboardLink: '', owner: '')] : rows;
 return _RegisterShell(
 title: 'Observability matrix',
 child: Column(children: [
 for (var i = 0; i < safeRows.length; i++)
 Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _RegisterRow(
 onRemove: safeRows.length <= 1 ? null : () { final copy = [...safeRows]..removeAt(i); onChanged(copy); },
 children: [
 _registerField('Component', safeRows[i].component, (v) { final copy = [...safeRows]; copy[i] = _ObservabilityEntry(component: v.trim(), logs: copy[i].logs, metrics: copy[i].metrics, alerts: copy[i].alerts, dashboardLink: copy[i].dashboardLink, owner: copy[i].owner); onChanged(copy); }),
 _registerField('Logs', safeRows[i].logs, (v) { final copy = [...safeRows]; copy[i] = _ObservabilityEntry(component: copy[i].component, logs: v.trim(), metrics: copy[i].metrics, alerts: copy[i].alerts, dashboardLink: copy[i].dashboardLink, owner: copy[i].owner); onChanged(copy); }),
 _registerField('Metrics', safeRows[i].metrics, (v) { final copy = [...safeRows]; copy[i] = _ObservabilityEntry(component: copy[i].component, logs: copy[i].logs, metrics: v.trim(), alerts: copy[i].alerts, dashboardLink: copy[i].dashboardLink, owner: copy[i].owner); onChanged(copy); }),
 _registerField('Alerts', safeRows[i].alerts, (v) { final copy = [...safeRows]; copy[i] = _ObservabilityEntry(component: copy[i].component, logs: copy[i].logs, metrics: copy[i].metrics, alerts: v.trim(), dashboardLink: copy[i].dashboardLink, owner: copy[i].owner); onChanged(copy); }),
 _registerField('Dashboard', safeRows[i].dashboardLink, (v) { final copy = [...safeRows]; copy[i] = _ObservabilityEntry(component: copy[i].component, logs: copy[i].logs, metrics: copy[i].metrics, alerts: copy[i].alerts, dashboardLink: v.trim(), owner: copy[i].owner); onChanged(copy); }),
 _registerField('Owner', safeRows[i].owner, (v) { final copy = [...safeRows]; copy[i] = _ObservabilityEntry(component: copy[i].component, logs: copy[i].logs, metrics: copy[i].metrics, alerts: copy[i].alerts, dashboardLink: copy[i].dashboardLink, owner: v.trim()); onChanged(copy); }),
 ],
 ),
 ),
 Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => onChanged([...safeRows, const _ObservabilityEntry(component: '', logs: '', metrics: '', alerts: '', dashboardLink: '', owner: '')]), icon: const Icon(Icons.add), label: const Text('Add component'))),
 ]),
 );
 }
}

class _ResidualActionRegisterCard extends StatelessWidget {
 const _ResidualActionRegisterCard({required this.rows, required this.onChanged});
 final List<_ResidualActionEntry> rows;
 final ValueChanged<List<_ResidualActionEntry>> onChanged;
 @override
 Widget build(BuildContext context) {
 final safeRows = rows.isEmpty ? const [_ResidualActionEntry(action: '', owner: '', dueDate: '', destinationTeam: '', status: 'Open', handoffNote: '')] : rows;
 return _RegisterShell(
 title: 'Residual action register',
 child: Column(children: [
 for (var i = 0; i < safeRows.length; i++)
 Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _RegisterRow(
 onRemove: safeRows.length <= 1 ? null : () { final copy = [...safeRows]..removeAt(i); onChanged(copy); },
 children: [
 _registerField('Action', safeRows[i].action, (v) { final copy = [...safeRows]; copy[i] = _ResidualActionEntry(action: v.trim(), owner: copy[i].owner, dueDate: copy[i].dueDate, destinationTeam: copy[i].destinationTeam, status: copy[i].status, handoffNote: copy[i].handoffNote); onChanged(copy); }),
 _registerField('Owner', safeRows[i].owner, (v) { final copy = [...safeRows]; copy[i] = _ResidualActionEntry(action: copy[i].action, owner: v.trim(), dueDate: copy[i].dueDate, destinationTeam: copy[i].destinationTeam, status: copy[i].status, handoffNote: copy[i].handoffNote); onChanged(copy); }),
 _registerField('Due date', safeRows[i].dueDate, (v) { final copy = [...safeRows]; copy[i] = _ResidualActionEntry(action: copy[i].action, owner: copy[i].owner, dueDate: v.trim(), destinationTeam: copy[i].destinationTeam, status: copy[i].status, handoffNote: copy[i].handoffNote); onChanged(copy); }),
 _registerField('Destination team', safeRows[i].destinationTeam, (v) { final copy = [...safeRows]; copy[i] = _ResidualActionEntry(action: copy[i].action, owner: copy[i].owner, dueDate: copy[i].dueDate, destinationTeam: v.trim(), status: copy[i].status, handoffNote: copy[i].handoffNote); onChanged(copy); }),
 _registerField('Status', safeRows[i].status, (v) { final copy = [...safeRows]; copy[i] = _ResidualActionEntry(action: copy[i].action, owner: copy[i].owner, dueDate: copy[i].dueDate, destinationTeam: copy[i].destinationTeam, status: v.trim(), handoffNote: copy[i].handoffNote); onChanged(copy); }),
 _registerField('Handoff note', safeRows[i].handoffNote, (v) { final copy = [...safeRows]; copy[i] = _ResidualActionEntry(action: copy[i].action, owner: copy[i].owner, dueDate: copy[i].dueDate, destinationTeam: copy[i].destinationTeam, status: copy[i].status, handoffNote: v.trim()); onChanged(copy); }),
 ],
 ),
 ),
 Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => onChanged([...safeRows, const _ResidualActionEntry(action: '', owner: '', dueDate: '', destinationTeam: '', status: 'Open', handoffNote: '')]), icon: const Icon(Icons.add), label: const Text('Add residual action'))),
 ]),
 );
 }
}

class _RegisterShell extends StatelessWidget {
 const _RegisterShell({required this.title, required this.child});
 final String title;
 final Widget child;
 @override
 Widget build(BuildContext context) => Container(
 width: double.infinity,
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 12), child]),
 );
}

class _RegisterRow extends StatelessWidget {
 const _RegisterRow({required this.children, this.onRemove});
 final List<Widget> children;
 final VoidCallback? onRemove;
 @override
 Widget build(BuildContext context) => Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
 child: Column(children: [
 Wrap(spacing: 8, runSpacing: 8, children: [...children, if (onRemove != null) IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline))]),
 ]),
 );
}

Widget _registerField(String label, String initialValue, ValueChanged<String> onChanged) => SizedBox(width: 180, child: VoiceTextFormField(initialValue: initialValue, decoration: _fieldDecoration(label), onChanged: onChanged));
InputDecoration _fieldDecoration(String hintText)=>InputDecoration(hintText:hintText,isDense:true,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:Color(0xFFE5E7EB))),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:Color(0xFFE5E7EB))));
class _StatusChip extends StatelessWidget { const _StatusChip({required this.label,required this.color,this.background}); final String label; final Color color; final Color? background; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:background??color.withOpacity(0.12),borderRadius:BorderRadius.circular(999)),child:Text(label,style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:color))); }
class _Debouncer { _Debouncer({Duration? delay}):delay=delay??const Duration(milliseconds:700); final Duration delay; Timer? _timer; void run(void Function() action){_timer?.cancel();_timer=Timer(delay,action);} void dispose(){_timer?.cancel();} }
