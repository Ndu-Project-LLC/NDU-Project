import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/deliverable_row.dart';
import 'package:ndu_project/models/recurring_deliverable_row.dart';
import 'package:ndu_project/models/status_report_row.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/contracts_tracking_screen.dart';
import 'package:ndu_project/screens/team_meetings_screen.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';
import 'package:ndu_project/widgets/deliverables_tracking_widget.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/launch_editable_section.dart';
import 'package:ndu_project/widgets/progress_tracking_dashboard.dart';
import 'package:ndu_project/widgets/recurring_deliverables_widget.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/status_reports_widget.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

class ProgressTrackingScreen extends StatefulWidget {
 const ProgressTrackingScreen({super.key});

 static void open(BuildContext context) {
 PhaseTransitionHelper.pushPhaseAware(
 context: context,
 builder: (_) => const ProgressTrackingScreen(),
 destinationCheckpoint: 'progress_tracking',
 );
 }

 @override
 State<ProgressTrackingScreen> createState() => _ProgressTrackingScreenState();
}

enum _ProgressWorkspaceView {
 deliverables,
 recurring,
 reports,
}

class _ProgressTrackingScreenState extends State<ProgressTrackingScreen> {
 List<DeliverableRow> _deliverables = [];
 List<RecurringDeliverableRow> _recurringDeliverables = [];
 List<StatusReportRow> _statusReports = [];
 bool _loading = true;
 bool _autoGenerationTriggered = false;
 bool _isAutoGenerating = false;
 Timer? _autoSaveDebounce;
 _ProgressWorkspaceView _activeView = _ProgressWorkspaceView.deliverables;

 String? get _projectId {
 try {
 final provider = ProjectDataInherited.maybeOf(context);
 return provider?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 String? get _userId => FirebaseAuth.instance.currentUser?.uid;

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
 }

 @override
 void dispose() {
 _autoSaveDebounce?.cancel();
 super.dispose();
 }

 Future<void> _loadData() async {
 final String? projectId = _projectId;
 if (projectId == null || projectId.isEmpty) {
 if (mounted) {
 setState(() => _loading = false);
 }
 return;
 }

 try {
 final List<DeliverableRow> deliverables =
 await ExecutionPhaseService.loadDeliverableRows(projectId: projectId);
 final List<RecurringDeliverableRow> recurring =
 await ExecutionPhaseService.loadRecurringDeliverableRows(
 projectId: projectId,
 );
 final List<StatusReportRow> reports =
 await ExecutionPhaseService.loadStatusReportRows(projectId: projectId);

 if (!mounted) return;
 setState(() {
 _deliverables = deliverables;
 _recurringDeliverables = recurring;
 _statusReports = reports;
 _loading = false;
 });

 await _autoGenerateIfNeeded();
 } catch (e) {
 debugPrint('Error loading progress tracking data: $e');
 if (mounted) {
 setState(() => _loading = false);
 }
 }
 }

 Future<void> _autoGenerateIfNeeded() async {
 if (!mounted || _autoGenerationTriggered || _isAutoGenerating) return;
 if (_deliverables.isNotEmpty ||
 _recurringDeliverables.isNotEmpty ||
 _statusReports.isNotEmpty) {
 return;
 }

 _autoGenerationTriggered = true;
 _isAutoGenerating = true;
 try {
 final String contextText =
 ExecutionPhaseAiSeed.buildContext(context, section: 'Progress Tracking');
 if (contextText.isEmpty) return;

 final generated = await ExecutionPhaseAiSeed.generateEntries(
 context: context,
 section: 'Progress Tracking',
 sections: const {
 'deliverables': 'Key execution deliverables to track',
 'recurringDeliverables': 'Recurring deliverables or checkpoints',
 'statusReports': 'Status report types for stakeholders',
 },
 itemsPerSection: 3,
 );

 if (!mounted) return;
 setState(() {
 _deliverables = _deliverables.isEmpty
 ? _mapDeliverables(generated['deliverables'] ?? const [])
 : _deliverables;
 _recurringDeliverables = _recurringDeliverables.isEmpty
 ? _mapRecurring(generated['recurringDeliverables'] ?? const [])
 : _recurringDeliverables;
 _statusReports = _statusReports.isEmpty
 ? _mapReports(generated['statusReports'] ?? const [])
 : _statusReports;
 });
 _persistChanges();
 } catch (e) {
 debugPrint('Error auto-generating progress tracking data: $e');
 } finally {
 _isAutoGenerating = false;
 }
 }

 List<DeliverableRow> _mapDeliverables(List<LaunchEntry> entries) {
 return entries
 .map(
 (entry) => DeliverableRow(
 title: entry.title,
 description: entry.details,
 owner: 'Project Lead',
 status:
 entry.status?.toString().isNotEmpty == true ? entry.status! : 'Not Started',
 ),
 )
 .toList();
 }

 List<RecurringDeliverableRow> _mapRecurring(List<LaunchEntry> entries) {
 return entries
 .map(
 (entry) => RecurringDeliverableRow(
 title: entry.title,
 description: entry.details,
 frequency: _extractFrequency(entry.details),
 owner: 'Ops Lead',
 status:
 entry.status?.toString().isNotEmpty == true ? entry.status! : 'Active',
 ),
 )
 .toList();
 }

 List<StatusReportRow> _mapReports(List<LaunchEntry> entries) {
 final DateTime now = DateTime.now();
 return entries
 .map(
 (entry) => StatusReportRow(
 reportType: entry.title,
 stakeholder: 'Project Sponsors',
 reportDate: now,
 summary: entry.details,
 status:
 entry.status?.toString().isNotEmpty == true ? entry.status! : 'Draft',
 ),
 )
 .toList();
 }

 String _extractFrequency(String text) {
 final String lower = text.toLowerCase();
 if (lower.contains('daily')) return 'Daily';
 if (lower.contains('bi-weekly') || lower.contains('bi weekly')) {
 return 'Bi-Weekly';
 }
 if (lower.contains('weekly')) return 'Weekly';
 if (lower.contains('monthly')) return 'Monthly';
 if (lower.contains('quarter')) return 'Quarterly';
 return 'Weekly';
 }

 void _persistChanges() {
 final String? projectId = _projectId;
 if (projectId == null || projectId.isEmpty) return;

 _autoSaveDebounce?.cancel();
 _autoSaveDebounce = Timer(const Duration(milliseconds: 1500), () async {
 try {
 await Future.wait([
 ExecutionPhaseService.saveDeliverableRows(
 projectId: projectId,
 rows: _deliverables,
 userId: _userId,
 ),
 ExecutionPhaseService.saveRecurringDeliverableRows(
 projectId: projectId,
 rows: _recurringDeliverables,
 userId: _userId,
 ),
 ExecutionPhaseService.saveStatusReportRows(
 projectId: projectId,
 rows: _statusReports,
 userId: _userId,
 ),
 ]);
 } catch (e) {
 debugPrint('Error persisting progress tracking data: $e');
 }
 });
 }

 Future<void> _addAiDraftsForActiveView() async {
 if (_isAutoGenerating) return;

 setState(() => _isAutoGenerating = true);
 try {
 final generated = await ExecutionPhaseAiSeed.generateEntries(
 context: context,
 section: 'Progress Tracking',
 sections: {
 _activeSectionKey: _activeSectionPrompt,
 },
 itemsPerSection: 2,
 );

 if (!mounted) return;
 setState(() {
 switch (_activeView) {
 case _ProgressWorkspaceView.deliverables:
 _deliverables = [
 ..._deliverables,
 ..._mapDeliverables(generated[_activeSectionKey] ?? const []),
 ];
 break;
 case _ProgressWorkspaceView.recurring:
 _recurringDeliverables = [
 ..._recurringDeliverables,
 ..._mapRecurring(generated[_activeSectionKey] ?? const []),
 ];
 break;
 case _ProgressWorkspaceView.reports:
 _statusReports = [
 ..._statusReports,
 ..._mapReports(generated[_activeSectionKey] ?? const []),
 ];
 break;
 }
 });
 _persistChanges();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('AI draft items added to $_activeViewLabel.')),
 );
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to generate AI drafts: $e')),
 );
 } finally {
 if (mounted) {
 setState(() => _isAutoGenerating = false);
 }
 }
 }

 void _addBlankItemForActiveView() {
 setState(() {
 switch (_activeView) {
 case _ProgressWorkspaceView.deliverables:
 _deliverables = [
 DeliverableRow(
 title: '',
 description: '',
 owner: '',
 status: 'Not Started',
 ),
 ..._deliverables,
 ];
 break;
 case _ProgressWorkspaceView.recurring:
 _recurringDeliverables = [
 RecurringDeliverableRow(
 title: '',
 description: '',
 frequency: 'Weekly',
 status: 'Active',
 ),
 ..._recurringDeliverables,
 ];
 break;
 case _ProgressWorkspaceView.reports:
 _statusReports = [
 StatusReportRow(
 reportType: '',
 stakeholder: '',
 reportDate: DateTime.now(),
 status: 'Draft',
 ),
 ..._statusReports,
 ];
 break;
 }
 });
 _persistChanges();
 }

 void _handleDeliverablesChanged(List<DeliverableRow> updated) {
 setState(() => _deliverables = updated);
 _persistChanges();
 }

 void _handleRecurringChanged(List<RecurringDeliverableRow> updated) {
 setState(() => _recurringDeliverables = updated);
 _persistChanges();
 }

 void _handleStatusReportsChanged(List<StatusReportRow> updated) {
 setState(() => _statusReports = updated);
 _persistChanges();
 }

 String get _activeViewLabel {
 switch (_activeView) {
 case _ProgressWorkspaceView.deliverables:
 return 'Deliverable Status Updates';
 case _ProgressWorkspaceView.recurring:
 return 'Recurring Deliverables';
 case _ProgressWorkspaceView.reports:
 return 'Status Reports';
 }
 }

 String get _activeSectionKey {
 switch (_activeView) {
 case _ProgressWorkspaceView.deliverables:
 return 'deliverables';
 case _ProgressWorkspaceView.recurring:
 return 'recurringDeliverables';
 case _ProgressWorkspaceView.reports:
 return 'statusReports';
 }
 }

 String get _activeSectionPrompt {
 switch (_activeView) {
 case _ProgressWorkspaceView.deliverables:
 return 'Key execution deliverables to track and update';
 case _ProgressWorkspaceView.recurring:
 return 'Recurring deliverables, checkpoints, and review rituals';
 case _ProgressWorkspaceView.reports:
 return 'Status report drafts, stakeholder summaries, and asks';
 }
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 16 : 32;

 return ResponsiveScaffold(
 activeItemLabel: 'Progress Tracking',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding,
 vertical: isMobile ? 16 : 28,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_loading) const LinearProgressIndicator(minHeight: 2),
 if (_loading) const SizedBox(height: 16),
 PlanningPhaseHeader(
 title: 'Progress Tracking',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 20),
 if (_loading)
 const Center(
 child: Padding(
 padding: EdgeInsets.all(32),
 child: CircularProgressIndicator(),
 ),
 )
 else ...[
 // Action buttons (moved from removed header)
 Padding(
 padding: const EdgeInsets.only(bottom: 16),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.end,
 children: [
 FilledButton.icon(
 onPressed: _loading ? null : _addBlankItemForActiveView,
 icon: const Icon(Icons.add, size: 16),
 label: const Text('Add item',
 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFF0F172A),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 ),
 const SizedBox(width: 10),
 OutlinedButton.icon(
 onPressed: _loading ? null : _addAiDraftsForActiveView,
 icon: _isAutoGenerating
 ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
 : const Icon(Icons.auto_awesome_outlined, size: 16),
 label: const Text('Add AI draft',
 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF7C3AED),
 side: const BorderSide(color: Color(0xFFDDD6FE)),
 backgroundColor: const Color(0xFFF5F3FF),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 ),
 ],
 ),
 ),
 ProgressTrackingDashboard(
 deliverables: _deliverables,
 recurringDeliverables: _recurringDeliverables,
 statusReports: _statusReports,
 onDeliverablesChanged: _handleDeliverablesChanged,
 onRecurringChanged: _handleRecurringChanged,
 onStatusReportsChanged: _handleStatusReportsChanged,
 ),
 const SizedBox(height: 20),
 ExecutionPanelShell(
 title: 'Workspace views',
 subtitle:
 'Switch between live deliverables, recurring execution work, and stakeholder reporting without nested tables or fixed-height tabs.',
 collapsible: true,
 initiallyExpanded: false,
 headerIcon: Icons.view_timeline_outlined,
 headerIconColor: const Color(0xFFD97706),
 child: Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _buildViewChip(
 view: _ProgressWorkspaceView.deliverables,
 label: 'Deliverables',
 count: _deliverables.length,
 ),
 _buildViewChip(
 view: _ProgressWorkspaceView.recurring,
 label: 'Recurring',
 count: _recurringDeliverables.length,
 ),
 _buildViewChip(
 view: _ProgressWorkspaceView.reports,
 label: 'Reports',
 count: _statusReports.length,
 ),
 ],
 ),
 ),
 const SizedBox(height: 20),
 _buildActiveWorkspace(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Team Meetings',
 nextLabel: 'Next: Contracts Tracking',
 onBack: () => TeamMeetingsScreen.open(context),
 onNext: () => ContractsTrackingScreen.open(context),
 ),
 ],
 const SizedBox(height: 48),
 ],
 ),
 ),
 );
 }

 Widget _buildHeader() {
 return ExecutionPageHeader(
 badge: 'Execution Progress',
 title: 'Progress Tracking Command Center',
 description:
 'Monitor execution health, track deliverables, manage recurring operating work, and shape stakeholder-ready status reporting from one connected workspace.',
 trailing: ExecutionActionBar(
 actions: [
 ExecutionActionItem(
 label: 'Add item',
 icon: Icons.add,
 tone: ExecutionActionTone.primary,
 onPressed: _loading ? null : _addBlankItemForActiveView,
 ),
 ExecutionActionItem(
 label: 'Add AI draft',
 icon: Icons.auto_awesome_outlined,
 tone: ExecutionActionTone.ai,
 isLoading: _isAutoGenerating,
 onPressed: _loading ? null : _addAiDraftsForActiveView,
 ),
 ],
 ),
 );
 }

 Widget _buildViewChip({
 required _ProgressWorkspaceView view,
 required String label,
 required int count,
 }) {
 final bool selected = _activeView == view;
 return ChoiceChip(
 label: Text('$label · $count'),
 selected: selected,
 onSelected: (_) => setState(() => _activeView = view),
 showCheckmark: false,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
 selectedColor: const Color(0xFFFFF7E6),
 backgroundColor: Colors.white,
 side: BorderSide(
 color: selected ? const Color(0xFF7DD3FC) : const Color(0xFFE2E8F0),
 ),
 labelStyle: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: selected ? const Color(0xFFB45309) : const Color(0xFF475569),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 );
 }

 Widget _buildActiveWorkspace() {
 switch (_activeView) {
 case _ProgressWorkspaceView.deliverables:
 return DeliverablesTrackingWidget(
 deliverables: _deliverables,
 onDeliverablesChanged: _handleDeliverablesChanged,
 );
 case _ProgressWorkspaceView.recurring:
 return RecurringDeliverablesWidget(
 recurringDeliverables: _recurringDeliverables,
 onRecurringChanged: _handleRecurringChanged,
 );
 case _ProgressWorkspaceView.reports:
 return StatusReportsWidget(
 statusReports: _statusReports,
 onStatusReportsChanged: _handleStatusReportsChanged,
 );
 }
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Progress Tracking',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_progress_tracking_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}
