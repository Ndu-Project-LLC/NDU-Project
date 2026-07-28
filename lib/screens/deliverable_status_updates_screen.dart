import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/deliverable_row.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/recurring_deliverables_screen.dart';
import 'package:ndu_project/screens/progress_tracking_screen.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';
import 'package:ndu_project/widgets/deliverables_tracking_widget.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

/// Dedicated screen for tracking deliverable status updates across the
/// execution phase. Follows project management conventions from PMI's PMBOK
/// Guide: monitor-and-control deliverables through defined acceptance criteria,
/// owner accountability, due-date adherence, and status-driven workflows.
///
/// Each deliverable follows the standard lifecycle:
/// Not Started → In Progress → Completed | At Risk | Blocked
///
/// The screen surfaces:
/// - A timeline view for visualizing delivery cadence
/// - Inline-editable rows for rapid status updates
/// - AI-assisted delay prediction and mitigation suggestions
/// - Real-time overdue and at-risk indicators
class DeliverableStatusUpdatesScreen extends StatefulWidget {
 const DeliverableStatusUpdatesScreen({super.key});

 static void open(BuildContext context) {
 PhaseTransitionHelper.pushPhaseAware(
 context: context,
 builder: (_) => const DeliverableStatusUpdatesScreen(),
 destinationCheckpoint: 'deliverable_status_updates',
 );
 }

 @override
 State<DeliverableStatusUpdatesScreen> createState() =>
 _DeliverableStatusUpdatesScreenState();
}

class _DeliverableStatusUpdatesScreenState
 extends State<DeliverableStatusUpdatesScreen> {
 List<DeliverableRow> _deliverables = [];
 bool _loading = true;
 bool _autoGenerationTriggered = false;
 bool _isAutoGenerating = false;
 Timer? _autoSaveDebounce;

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
 if (mounted) setState(() => _loading = false);
 return;
 }

 try {
 final List<DeliverableRow> deliverables =
 await ExecutionPhaseService.loadDeliverableRows(projectId: projectId);

 if (!mounted) return;
 setState(() {
 _deliverables = deliverables;
 _loading = false;
 });

 await _autoGenerateIfNeeded();
 } catch (e) {
 debugPrint('Error loading deliverable status updates: $e');
 if (mounted) setState(() => _loading = false);
 }
 }

 Future<void> _autoGenerateIfNeeded() async {
 if (!mounted || _autoGenerationTriggered || _isAutoGenerating) return;
 if (_deliverables.isNotEmpty) return;

 _autoGenerationTriggered = true;
 _isAutoGenerating = true;
 try {
 final String contextText =
 ExecutionPhaseAiSeed.buildContext(context, section: 'Deliverable Status Updates');
 if (contextText.isEmpty) return;

 final generated = await ExecutionPhaseAiSeed.generateEntries(
 context: context,
 section: 'Deliverable Status Updates',
 sections: const {
 'deliverables': 'Key execution deliverables to track and update',
 },
 itemsPerSection: 3,
 );

 if (!mounted) return;
 setState(() {
 _deliverables = _deliverables.isEmpty
 ? (generated['deliverables'] ?? const [])
 .map((entry) => DeliverableRow(
 title: entry.title,
 description: entry.details,
 owner: 'Project Lead',
 status: entry.status?.toString().isNotEmpty == true
 ? entry.status!
 : 'Not Started',
 ))
 .toList()
 : _deliverables;
 });
 _persistChanges();
 } catch (e) {
 debugPrint('Error auto-generating deliverables: $e');
 } finally {
 _isAutoGenerating = false;
 }
 }

 void _persistChanges() {
 final String? projectId = _projectId;
 if (projectId == null || projectId.isEmpty) return;

 _autoSaveDebounce?.cancel();
 _autoSaveDebounce = Timer(const Duration(milliseconds: 1500), () async {
 try {
 await ExecutionPhaseService.saveDeliverableRows(
 projectId: projectId,
 rows: _deliverables,
 userId: _userId,
 );
 } catch (e) {
 debugPrint('Error persisting deliverables: $e');
 }
 });
 }

 void _handleDeliverablesChanged(List<DeliverableRow> updated) {
 setState(() => _deliverables = updated);
 _persistChanges();
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 16 : 32;

 return ResponsiveScaffold(
 activeItemLabel: 'Deliverable Status Updates',
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
 title: 'Deliverable Status Updates',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _buildInfoPanel(),
 const SizedBox(height: 20),
 if (_loading)
 const Center(
 child: Padding(
 padding: EdgeInsets.all(32),
 child: CircularProgressIndicator(),
 ),
 )
 else ...[
 DeliverablesTrackingWidget(
 deliverables: _deliverables,
 onDeliverablesChanged: _handleDeliverablesChanged,
 ),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Progress Tracking',
 nextLabel: 'Next: Recurring Deliverables',
 onBack: () => ProgressTrackingScreen.open(context),
 onNext: () => RecurringDeliverablesScreen.open(context),
 ),
 ],
 const SizedBox(height: 48),
 ],
 ),
 ),
 );
 }

 Widget _buildInfoPanel() {
 return ExecutionPanelShell(
 title: 'Deliverable management best practices',
 subtitle:
 'Aligned with PMI PMBOK Monitor & Control Project Work and Validate Scope processes. '
 'Deliverables should be tracked with clear owners, acceptance criteria, and due dates. '
 'The at-risk and overdue indicators help teams proactively address issues before they '
 'become blockers. Status reports should flow from deliverable data to maintain '
 'consistency between execution tracking and stakeholder communication.',
 collapsible: true,
 initiallyExpanded: false,
 headerIcon: Icons.lightbulb_outline_rounded,
 headerIconColor: const Color(0xFFF59E0B),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildGuidelineRow(
 Icons.check_circle_outline,
 'Acceptance Criteria',
 'Define measurable criteria for each deliverable before work begins. This ensures '
 'the team and stakeholders share a common definition of "done" and prevents scope disputes.',
 ),
 const SizedBox(height: 14),
 _buildGuidelineRow(
 Icons.person_outline,
 'Single Owner Accountability',
 'Assign one accountable owner per deliverable. The owner is responsible for status '
 'updates, risk escalation, and coordinating dependencies across teams.',
 ),
 const SizedBox(height: 14),
 _buildGuidelineRow(
 Icons.warning_amber_outlined,
 'Proactive Risk Flagging',
 'Items flagged as At Risk (due within 7 days) or Blocked require immediate '
 'attention. Escalate blockers in team stand-ups and status reports to maintain momentum.',
 ),
 const SizedBox(height: 14),
 _buildGuidelineRow(
 Icons.timeline_outlined,
 'Baseline vs Actual Tracking',
 'Compare planned delivery dates against actual completion to identify schedule '
 'variance. Use variance data to inform forecasting and resource reallocation decisions.',
 ),
 ],
 ),
 );
 }

 Widget _buildGuidelineRow(IconData icon, String title, String description) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: const Color(0xFFF0F9FF),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(icon, size: 18, color: const Color(0xFF0284C7)),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 description,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 height: 1.5,
 ),
 ),
 ],
 ),
 ),
 ],
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Deliverable Status Updates',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_deliverable_status_updates_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}
