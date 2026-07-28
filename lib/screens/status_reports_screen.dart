import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/status_report_row.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/screens/recurring_deliverables_screen.dart';
import 'package:ndu_project/screens/contracts_tracking_screen.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/widgets/status_reports_widget.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

/// Dedicated screen for managing stakeholder status reports during the
/// execution phase. Status reports are the primary communication vehicle
/// between the project team and stakeholders, providing structured updates
/// on progress, risks, blockers, and asks.
///
/// Following PMI PMBOK Manage Communications and Monitor Stakeholder
/// Engagement processes, each report is structured to convey:
/// - **Summary**: High-level progress narrative for the reporting period
/// - **Key Wins**: Accomplishments and milestones reached
/// - **Blockers**: Issues impeding progress that need escalation
/// - **Asks**: Specific requests for decisions, resources, or approvals
/// - **Follow-ups**: Carried-over action items from previous reports
///
/// Report types typically include:
/// - Weekly Project Status Update
/// - Executive Steering Committee Brief
/// - Stakeholder Engagement Summary
/// - Risk & Issue Escalation Report
///
/// Each report follows the lifecycle: Draft → Sent → Acknowledged
class StatusReportsScreen extends StatefulWidget {
 const StatusReportsScreen({super.key});

 static void open(BuildContext context) {
 PhaseTransitionHelper.pushPhaseAware(
 context: context,
 builder: (_) => const StatusReportsScreen(),
 destinationCheckpoint: 'status_reports',
 );
 }

 @override
 State<StatusReportsScreen> createState() => _StatusReportsScreenState();
}

class _StatusReportsScreenState extends State<StatusReportsScreen> {
 List<StatusReportRow> _statusReports = [];
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
 final List<StatusReportRow> reports =
 await ExecutionPhaseService.loadStatusReportRows(projectId: projectId);

 if (!mounted) return;
 setState(() {
 _statusReports = reports;
 _loading = false;
 });

 await _autoGenerateIfNeeded();
 } catch (e) {
 debugPrint('Error loading status reports: $e');
 if (mounted) setState(() => _loading = false);
 }
 }

 Future<void> _autoGenerateIfNeeded() async {
 if (!mounted || _autoGenerationTriggered || _isAutoGenerating) return;
 if (_statusReports.isNotEmpty) return;

 _autoGenerationTriggered = true;
 _isAutoGenerating = true;
 try {
 final String contextText =
 ExecutionPhaseAiSeed.buildContext(context, section: 'Status Reports');
 if (contextText.isEmpty) return;

 final generated = await ExecutionPhaseAiSeed.generateEntries(
 context: context,
 section: 'Status Reports',
 sections: const {
 'statusReports': 'Status report types, stakeholder summaries, and asks',
 },
 itemsPerSection: 3,
 );

 if (!mounted) return;
 final DateTime now = DateTime.now();
 setState(() {
 _statusReports = _statusReports.isEmpty
 ? (generated['statusReports'] ?? const [])
 .map((entry) => StatusReportRow(
 reportType: entry.title,
 stakeholder: 'Project Sponsors',
 reportDate: now,
 summary: entry.details,
 status: entry.status?.toString().isNotEmpty == true
 ? entry.status!
 : 'Draft',
 ))
 .toList()
 : _statusReports;
 });
 _persistChanges();
 } catch (e) {
 debugPrint('Error auto-generating status reports: $e');
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
 await ExecutionPhaseService.saveStatusReportRows(
 projectId: projectId,
 rows: _statusReports,
 userId: _userId,
 );
 } catch (e) {
 debugPrint('Error persisting status reports: $e');
 }
 });
 }

 Future<void> _addAiDrafts() async {
 if (_isAutoGenerating) return;
 setState(() => _isAutoGenerating = true);
 try {
 final generated = await ExecutionPhaseAiSeed.generateEntries(
 context: context,
 section: 'Status Reports',
 sections: const {
 'statusReports': 'Status report types, stakeholder summaries, and asks',
 },
 itemsPerSection: 2,
 );

 if (!mounted) return;
 final DateTime now = DateTime.now();
 setState(() {
 _statusReports = [
 ..._statusReports,
 ...(generated['statusReports'] ?? const [])
 .map((entry) => StatusReportRow(
 reportType: entry.title,
 stakeholder: 'Project Sponsors',
 reportDate: now,
 summary: entry.details,
 status: entry.status?.toString().isNotEmpty == true
 ? entry.status!
 : 'Draft',
 )),
 ];
 });
 _persistChanges();
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('AI draft status reports added.')),
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
 _statusReports = [
 StatusReportRow(
 reportType: '',
 stakeholder: '',
 reportDate: DateTime.now(),
 status: 'Draft',
 ),
 ..._statusReports,
 ];
 });
 _persistChanges();
 }

 void _handleStatusReportsChanged(List<StatusReportRow> updated) {
 setState(() => _statusReports = updated);
 _persistChanges();
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 16 : 32;

 return ResponsiveScaffold(
 activeItemLabel: 'Status Reports',
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
 title: 'Status Reports',
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
 StatusReportsWidget(
 statusReports: _statusReports,
 onStatusReportsChanged: _handleStatusReportsChanged,
 ),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Recurring Deliverables',
 nextLabel: 'Next: Contracts Tracking',
 onBack: () => RecurringDeliverablesScreen.open(context),
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
 badge: 'Execution · Reporting',
 title: 'Status Reports',
 description:
 'Create, track, and distribute structured status reports to project stakeholders. '
 'Each report captures the period\'s progress narrative, key accomplishments, '
 'active blockers, and explicit asks requiring stakeholder action. Use the '
 'Draft → Sent → Acknowledged workflow to maintain an auditable communication trail.',
 trailing: ExecutionActionBar(
 actions: [
 ExecutionActionItem(
 label: 'Add report',
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
 title: 'Effective status reporting framework',
 subtitle:
 'Grounded in PMI PMBOK Manage Communications (10.1) and PRINCE2 '
 'Highlight Report conventions. A well-structured status report answers '
 'three questions for every stakeholder: Where are we? What is blocking us? '
 'What do we need from you? Reports should be concise, action-oriented, and '
 'tied directly to deliverable data for consistency.',
 collapsible: true,
 initiallyExpanded: false,
 headerIcon: Icons.description_outlined,
 headerIconColor: const Color(0xFF0EA5E9),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildReportSection(
 Icons.summarize_outlined,
 'Weekly Project Status Update',
 'Summarize progress against the project baseline for the past week. '
 'Include schedule variance, cost performance index, and upcoming milestones. '
 'Target audience: Project Manager, Team Leads, PMO.',
 const Color(0xFFD97706),
 ),
 const SizedBox(height: 14),
 _buildReportSection(
 Icons.groups_outlined,
 'Executive Steering Committee Brief',
 'High-level narrative with RAG (Red/Amber/Green) status indicators. '
 'Focus on strategic risks, budget health, and decisions requiring '
 'steering committee approval. Target audience: Sponsors, Executives.',
 const Color(0xFF7C3AED),
 ),
 _buildReportSection(
 Icons.handshake_outlined,
 'Stakeholder Engagement Summary',
 'Track stakeholder sentiment, engagement actions taken, and upcoming '
 'communication events. Ensure alignment between project deliverables '
 'and stakeholder expectations. Target audience: Project Board, Key Stakeholders.',
 const Color(0xFF0D9488),
 ),
 const SizedBox(height: 14),
 _buildReportSection(
 Icons.warning_amber_outlined,
 'Risk & Issue Escalation Report',
 'Structured escalation of risks approaching thresholds and issues '
 'that exceed team-level resolution authority. Include impact assessment, '
 'proposed mitigations, and decision deadlines. Target audience: Risk Committee, Sponsors.',
 const Color(0xFFEF4444),
 ),
 const SizedBox(height: 14),
 _buildReportSection(
 Icons.trending_up_outlined,
 'Reporting Best Practices',
 'Keep reports under two pages. Lead with the most critical information. '
 'Use data from the deliverable tracker rather than subjective assessments. '
 'Every "ask" should name a specific person and a deadline. '
 'Archive all sent reports for audit trails and lessons learned.',
 const Color(0xFFF59E0B),
 ),
 ],
 ),
 );
 }

 Widget _buildReportSection(
 IconData icon, String title, String description, Color color) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: color.withOpacity(0.08),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(icon, size: 18, color: color),
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
 screenTitle: 'Status Reports',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_status_reports_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}
