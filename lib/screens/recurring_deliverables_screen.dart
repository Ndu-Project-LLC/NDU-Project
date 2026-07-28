import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/recurring_deliverable_row.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/deliverable_status_updates_screen.dart';
import 'package:ndu_project/screens/status_reports_screen.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/recurring_deliverables_widget.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

/// Dedicated screen for managing recurring deliverables during the execution
/// phase. Recurring deliverables are periodic outputs that the project team
/// must produce on a regular cadence — daily stand-ups, weekly status reports,
/// bi-weekly sprint reviews, monthly governance packs, and quarterly audits.
///
/// Following PMI PMBOK Direct and Manage Project Work processes, recurring
/// deliverables ensure sustained operational rhythm and continuous stakeholder
/// engagement throughout execution. They differ from one-off deliverables in
/// that they reset on each cycle and accumulate completion counts over time.
///
/// The screen supports:
/// - Configurable frequency (Daily, Weekly, Bi-Weekly, Monthly, Quarterly)
/// - Automatic next-occurrence calculation based on completion history
/// - Active/Paused/Completed status lifecycle
/// - AI-assisted population of common recurring deliverable patterns
class RecurringDeliverablesScreen extends StatefulWidget {
 const RecurringDeliverablesScreen({super.key});

 static void open(BuildContext context) {
 PhaseTransitionHelper.pushPhaseAware(
 context: context,
 builder: (_) => const RecurringDeliverablesScreen(),
 destinationCheckpoint: 'recurring_deliverables',
 );
 }

 @override
 State<RecurringDeliverablesScreen> createState() =>
 _RecurringDeliverablesScreenState();
}

class _RecurringDeliverablesScreenState
 extends State<RecurringDeliverablesScreen> {
 List<RecurringDeliverableRow> _recurringDeliverables = [];
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
 final List<RecurringDeliverableRow> recurring =
 await ExecutionPhaseService.loadRecurringDeliverableRows(
 projectId: projectId);

 if (!mounted) return;
 setState(() {
 _recurringDeliverables = recurring;
 _loading = false;
 });

 await _autoGenerateIfNeeded();
 } catch (e) {
 debugPrint('Error loading recurring deliverables: $e');
 if (mounted) setState(() => _loading = false);
 }
 }

 Future<void> _autoGenerateIfNeeded() async {
 if (!mounted || _autoGenerationTriggered || _isAutoGenerating) return;
 if (_recurringDeliverables.isNotEmpty) return;

 _autoGenerationTriggered = true;
 _isAutoGenerating = true;
 try {
 final String contextText =
 ExecutionPhaseAiSeed.buildContext(context, section: 'Recurring Deliverables');
 if (contextText.isEmpty) return;

 final generated = await ExecutionPhaseAiSeed.generateEntries(
 context: context,
 section: 'Recurring Deliverables',
 sections: const {
 'recurringDeliverables': 'Recurring deliverables, checkpoints, and review rituals',
 },
 itemsPerSection: 3,
 );

 if (!mounted) return;
 setState(() {
 _recurringDeliverables = _recurringDeliverables.isEmpty
 ? (generated['recurringDeliverables'] ?? const [])
 .map((entry) => RecurringDeliverableRow(
 title: entry.title,
 description: entry.details,
 frequency: _extractFrequency(entry.details),
 owner: 'Ops Lead',
 status: entry.status?.toString().isNotEmpty == true
 ? entry.status!
 : 'Active',
 ))
 .toList()
 : _recurringDeliverables;
 });
 _persistChanges();
 } catch (e) {
 debugPrint('Error auto-generating recurring deliverables: $e');
 } finally {
 _isAutoGenerating = false;
 }
 }

 String _extractFrequency(String text) {
 final String lower = text.toLowerCase();
 if (lower.contains('daily')) return 'Daily';
 if (lower.contains('bi-weekly') || lower.contains('bi weekly')) return 'Bi-Weekly';
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
 await ExecutionPhaseService.saveRecurringDeliverableRows(
 projectId: projectId,
 rows: _recurringDeliverables,
 userId: _userId,
 );
 } catch (e) {
 debugPrint('Error persisting recurring deliverables: $e');
 }
 });
 }

 Future<void> _addAiDrafts() async {
 if (_isAutoGenerating) return;
 setState(() => _isAutoGenerating = true);
 try {
 final generated = await ExecutionPhaseAiSeed.generateEntries(
 context: context,
 section: 'Recurring Deliverables',
 sections: const {
 'recurringDeliverables': 'Recurring deliverables, checkpoints, and review rituals',
 },
 itemsPerSection: 2,
 );

 if (!mounted) return;
 setState(() {
 _recurringDeliverables = [
 ..._recurringDeliverables,
 ...(generated['recurringDeliverables'] ?? const [])
 .map((entry) => RecurringDeliverableRow(
 title: entry.title,
 description: entry.details,
 frequency: _extractFrequency(entry.details),
 owner: 'Ops Lead',
 status: entry.status?.toString().isNotEmpty == true
 ? entry.status!
 : 'Active',
 )),
 ];
 });
 _persistChanges();
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('AI draft recurring deliverables added.')),
 );
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Unable to generate AI drafts: $e')),
 );
 }
 } finally {
 if (mounted) setState(() => _isAutoGenerating = false);
 }
 }

 void _addBlankItem() {
 setState(() {
 _recurringDeliverables = [
 RecurringDeliverableRow(
 title: '',
 description: '',
 frequency: 'Weekly',
 status: 'Active',
 ),
 ..._recurringDeliverables,
 ];
 });
 _persistChanges();
 }

 void _handleRecurringChanged(List<RecurringDeliverableRow> updated) {
 setState(() => _recurringDeliverables = updated);
 _persistChanges();
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 16 : 32;

 return ResponsiveScaffold(
 activeItemLabel: 'Recurring Deliverables',
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
 title: 'Recurring Deliverables',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _buildHeader(),
 const SizedBox(height: 20),
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
 RecurringDeliverablesWidget(
 recurringDeliverables: _recurringDeliverables,
 onRecurringChanged: _handleRecurringChanged,
 ),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Deliverable Status Updates',
 nextLabel: 'Next: Status Reports',
 onBack: () => DeliverableStatusUpdatesScreen.open(context),
 onNext: () => StatusReportsScreen.open(context),
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
 badge: 'Execution · Recurring',
 title: 'Recurring Deliverables',
 description:
 'Manage periodic outputs that sustain operational rhythm throughout execution. '
 'Recurring deliverables — stand-ups, sprint reviews, governance packs, compliance '
 'checkpoints — run on defined cadences and ensure the project maintains momentum '
 'and stakeholder alignment without needing ad-hoc coordination for each cycle.',
 trailing: ExecutionActionBar(
 actions: [
 ExecutionActionItem(
 label: 'Add item',
 icon: Icons.add,
 tone: ExecutionActionTone.primary,
 onPressed: _loading ? null : _addBlankItem,
 ),
 ExecutionActionItem(
 label: 'Add AI draft',
 icon: Icons.auto_awesome_outlined,
 tone: ExecutionActionTone.ai,
 isLoading: _isAutoGenerating,
 onPressed: _loading ? null : _addAiDrafts,
 ),
 ],
 ),
 );
 }

 Widget _buildInfoPanel() {
 return ExecutionPanelShell(
 title: 'Recurring deliverable cadence guide',
 subtitle:
 'Based on PMI PMBOK Direct and Manage Project Work and PRINCE2 stage-gate '
 'conventions. Recurring deliverables differ from milestones in that they repeat '
 'on a fixed cadence, accumulating completion counts over the project lifecycle. '
 'They anchor the project\'s operational heartbeat and provide predictable '
 'touchpoints for governance, quality assurance, and team coordination.',
 collapsible: true,
 initiallyExpanded: false,
 headerIcon: Icons.schedule_outlined,
 headerIconColor: const Color(0xFF7C3AED),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildCadenceRow(
 'Daily',
 'Stand-ups, issue triage, deployment checks, safety briefings',
 const Color(0xFF10B981),
 ),
 const SizedBox(height: 10),
 _buildCadenceRow(
 'Weekly',
 'Status reports, risk reviews, sprint planning, timesheet approvals',
 const Color(0xFFD97706),
 ),
 const SizedBox(height: 10),
 _buildCadenceRow(
 'Bi-Weekly',
 'Sprint reviews, retrospectives, resource reallocation, dependency checks',
 const Color(0xFF7C3AED),
 ),
 const SizedBox(height: 10),
 _buildCadenceRow(
 'Monthly',
 'Governance packs, financial reviews, change control board meetings, KPI dashboards',
 const Color(0xFFF59E0B),
 ),
 const SizedBox(height: 10),
 _buildCadenceRow(
 'Quarterly',
 'Steering committee reviews, audit readiness checks, vendor performance reviews',
 const Color(0xFFEF4444),
 ),
 ],
 ),
 );
 }

 Widget _buildCadenceRow(String frequency, String examples, Color color) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: color.withOpacity(0.06),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: color.withOpacity(0.15)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.15),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 frequency,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w800,
 color: color,
 ),
 ),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Text(
 examples,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF4B5563),
 height: 1.45,
 ),
 ),
 ),
 ],
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Recurring Deliverables',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_recurring_deliverables_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}
