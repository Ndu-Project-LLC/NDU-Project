import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/activity_log_service.dart';
import 'package:ndu_project/services/project_navigation_service.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
// Theme constants used via AppSemanticColors and LightModeColors are
// imported transitively through project_data_provider.
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/responsive_scaffold.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';


class TechnicalDevelopmentScreen extends StatefulWidget {
 const TechnicalDevelopmentScreen({super.key});

 @override
 State<TechnicalDevelopmentScreen> createState() =>
 _TechnicalDevelopmentScreenState();
}

class _TechnicalDevelopmentScreenState
 extends State<TechnicalDevelopmentScreen> {
 final TextEditingController _notesController = TextEditingController();
 final TextEditingController _approachController = TextEditingController();
 final _Debouncer _saveDebouncer = _Debouncer();
 bool _isLoading = false;
 bool _suspendSave = false;
 bool _didSeedDefaults = false;
 bool _frameworkGuideExpanded = false;
 Map<String, dynamic>? _engineeringContext;
 Map<String, dynamic>? _backendDesignContext;

 // Build strategy chips data
 List<_ChipItem> _standardsChips = [];

 // Workstreams data
 List<_WorkstreamItem> _workstreams = [];

 // Readiness checklist items
 List<_ReadinessItem> _readinessItems = [];

 // Editable build components
 List<_BuildComponentRow> _buildComponents = [];

 // Editable integrations
 List<_IntegrationRow> _integrations = [];

 // Editable issues
 List<_IssueRow> _issues = [];

 // Risk signals (user-added)
 List<_RiskSignalRow> _riskSignals = [];

 static const List<String> _workstreamStatusOptions = [
 'Team staffed',
 'Backlog ready',
 'Depends on vendor access',
 'In planning',
 'At risk',
 'Blocked',
 'In Production',
 'Delivered',
 ];

 static const List<String> _readinessStatusOptions = [
 'Ready',
 'In review',
 'Partially ready',
 'Draft',
 'Blocked',
 ];

 static const List<String> _buildStatusOptions = [
 'Delivered',
 'In Production',
 'In Progress',
 'Pending',
 'Blocked',
 ];

 static const List<String> _integrationStatusOptions = [
 'Connected',
 'Pending',
 'In Progress',
 'Blocked',
 ];

 static const List<String> _severityOptions = [
 'Critical',
 'High',
 'Medium',
 'Low',
 ];

 List<String> _ownerOptions({String? currentValue}) {
 final provider = ProjectDataInherited.maybeOf(context);
 final members = provider?.projectData.teamMembers ?? [];
 final names = members
 .map((member) {
 final name = member.name.trim();
 if (name.isNotEmpty) return name;
 final email = member.email.trim();
 if (email.isNotEmpty) return email;
 return member.role.trim();
 })
 .where((value) => value.isNotEmpty)
 .toList();
 final options = names.isEmpty ? <String>['Owner'] : names.toSet().toList();
 final normalized = currentValue?.trim() ?? '';
 if (normalized.isNotEmpty && !options.contains(normalized)) {
 return [normalized, ...options];
 }
 return options;
 }

 @override
 void initState() {
 super.initState();
 _standardsChips = _defaultStandards();
 _workstreams = _defaultWorkstreams();
 _readinessItems = _defaultReadinessItems();
 _buildComponents = _defaultBuildComponents();
 _integrations = _defaultIntegrations();
 _issues = _defaultIssues();
 _riskSignals = [];
 WidgetsBinding.instance.addPostFrameCallback((_) async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId != null && projectId.isNotEmpty) {
 await ProjectNavigationService.instance.saveLastPage(
 projectId,
 'technical_development',
 );
 }
 await _loadFromFirestore();
 });
 _notesController.addListener(_scheduleSave);
 _approachController.addListener(_scheduleSave);
 }

 
 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Technical Development',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['technical_development_screen'] ?? 'No data recorded.'),
 ],
 );
 }
@override
 void dispose() {
 _notesController.dispose();
 _approachController.dispose();
 _saveDebouncer.dispose();
 super.dispose();
 }

 DocumentReference<Map<String, dynamic>> _docFor(String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('design_phase_sections')
 .doc('technical_development');
 }

 void _scheduleSave() {
 if (_suspendSave) return;
 _saveDebouncer.run(_saveToFirestore);
 }

 Future<void> _loadFromFirestore() async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;
 if (!mounted) return;
 setState(() => _isLoading = true);
 bool shouldSeedDefaults = false;
 try {
 final docFuture = _docFor(projectId).get();
 final engineeringFuture = FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('design_phase_sections')
 .doc('engineering_design')
 .get();
 final backendFuture = FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('design_phase_sections')
 .doc('backend_design')
 .get();
 final results =
 await Future.wait<DocumentSnapshot<Map<String, dynamic>>>([
 docFuture,
 engineeringFuture,
 backendFuture,
 ]);
 final doc = results[0];
 final engineeringDoc = results[1];
 final backendDoc = results[2];
 final data = doc.data() ?? {};
 shouldSeedDefaults = data.isEmpty && !_didSeedDefaults;
 _suspendSave = true;
 if (!mounted) return;
 setState(() {
 _engineeringContext = engineeringDoc.data();
 _backendDesignContext = backendDoc.data();
 final chips = _ChipItem.fromList(data['standardsChips']);
 final workstreams = _WorkstreamItem.fromList(data['workstreams']);
 final readiness = _ReadinessItem.fromList(data['readinessItems']);
 final buildComps = _BuildComponentRow.fromList(data['buildComponents']);
 final integrations = _IntegrationRow.fromList(data['integrations']);
 final issues = _IssueRow.fromList(data['issues']);
 final riskSignals = _RiskSignalRow.fromList(data['riskSignals']);
 if (shouldSeedDefaults) {
 _didSeedDefaults = true;
 _notesController.text =
 'Production readiness now covers software build packs, fabrication packages, integration proving, mock venue rehearsals, and release controls before tools integration begins.';
 _approachController.text =
 'Run mixed software and physical workstreams in parallel, freeze interfaces early, validate prototypes before procurement, and push only after quality, safety, and rollback checks are complete.';
 _standardsChips = _defaultStandards();
 _workstreams = _defaultWorkstreams();
 _readinessItems = _defaultReadinessItems();
 _buildComponents = _defaultBuildComponents();
 _integrations = _defaultIntegrations();
 _issues = _defaultIssues();
 _riskSignals = [];
 } else {
 _notesController.text = data['notes']?.toString() ?? '';
 _approachController.text = data['approach']?.toString() ?? '';
 _standardsChips = chips.isEmpty ? _defaultStandards() : chips;
 _workstreams =
 workstreams.isEmpty ? _defaultWorkstreams() : workstreams;
 _readinessItems =
 readiness.isEmpty ? _defaultReadinessItems() : readiness;
 _buildComponents =
 buildComps.isEmpty ? _defaultBuildComponents() : buildComps;
 _integrations =
 integrations.isEmpty ? _defaultIntegrations() : integrations;
 _issues = issues.isEmpty ? _defaultIssues() : issues;
 _riskSignals = riskSignals;
 }
 });
 } catch (error) {
 debugPrint('Technical development load error: $error');
 } finally {
 _suspendSave = false;
 if (mounted) setState(() => _isLoading = false);
 if (shouldSeedDefaults) _scheduleSave();
 }
 }

 Future<void> _saveToFirestore() async {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectId = provider?.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;
 try {
 await _docFor(projectId).set({
 'notes': _notesController.text.trim(),
 'approach': _approachController.text.trim(),
 'standardsChips': _standardsChips.map((e) => e.toMap()).toList(),
 'workstreams': _workstreams.map((e) => e.toMap()).toList(),
 'readinessItems': _readinessItems.map((e) => e.toMap()).toList(),
 'buildComponents': _buildComponents.map((e) => e.toMap()).toList(),
 'integrations': _integrations.map((e) => e.toMap()).toList(),
 'issues': _issues.map((e) => e.toMap()).toList(),
 'riskSignals': _riskSignals.map((e) => e.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));
 await ActivityLogService.instance.logActivity(
 projectId: projectId,
 phase: 'Design Phase',
 page: 'Technical Development',
 action: 'Updated Technical Development data',
 );
 } catch (error) {
 debugPrint('Technical development save error: $error');
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'Unable to save Technical Development changes right now. Please try again.',
 ),
 ),
 );
 }
 }

 // ─── Default data generators ──────────────────────────────────────────

 List<_ChipItem> _defaultStandards() {
 return [
 _ChipItem(id: _newId(), label: 'Coding guidelines signed off'),
 _ChipItem(id: _newId(), label: 'Fabrication tolerances locked'),
 _ChipItem(id: _newId(), label: 'Interface freeze before sprint cut-off'),
 _ChipItem(
 id: _newId(),
 label: 'Safety protocols cleared for site assembly',
 ),
 ];
 }

 List<_WorkstreamItem> _defaultWorkstreams() {
 return [
 _WorkstreamItem(
 id: _newId(),
 title: 'Login Module',
 subtitle: 'Auth flows, session guardrails, and code review readiness',
 status: 'Team staffed',
 owner: 'Software lead',
 progress: 55,
 ),
 _WorkstreamItem(
 id: _newId(),
 title: 'Main Stage Fabrication',
 subtitle:
 'Deck framing, material sign-off, and installation sequencing',
 status: 'Backlog ready',
 owner: 'Production manager',
 progress: 40,
 ),
 _WorkstreamItem(
 id: _newId(),
 title: 'API and Lighting Integration',
 subtitle: 'Platform endpoints, control triggers, and interface proving',
 status: 'Depends on vendor access',
 owner: 'Integration lead',
 progress: 25,
 ),
 _WorkstreamItem(
 id: _newId(),
 title: 'Release and Site Assembly',
 subtitle: 'Staging cut-over, mock run, and handover playbook',
 status: 'In planning',
 owner: 'Release manager',
 progress: 15,
 ),
 ];
 }

 List<_ReadinessItem> _defaultReadinessItems() {
 return [
 _ReadinessItem(
 id: _newId(),
 title: 'API contracts and ticket scanner mappings frozen',
 owner: 'Backend lead',
 status: 'Ready',
 ),
 _ReadinessItem(
 id: _newId(),
 title: 'Load sign-off for stage truss and rigging package',
 owner: 'Structural engineer',
 status: 'In review',
 ),
 _ReadinessItem(
 id: _newId(),
 title: 'Staging environment and mock venue access available',
 owner: 'DevOps',
 status: 'Partially ready',
 ),
 _ReadinessItem(
 id: _newId(),
 title: 'Go-live runbook, rollback path, and radio comms plan drafted',
 owner: 'Release manager',
 status: 'Draft',
 ),
 ];
 }

 List<_BuildComponentRow> _defaultBuildComponents() {
 return [
 _BuildComponentRow(
 id: _newId(),
 name: 'Login Module',
 owner: 'Software lead',
 status: 'In Progress',
 type: 'Software',
 ),
 _BuildComponentRow(
 id: _newId(),
 name: 'Main Stage',
 owner: 'Production manager',
 status: 'In Production',
 type: 'Physical',
 ),
 _BuildComponentRow(
 id: _newId(),
 name: 'API Gateway',
 owner: 'Backend lead',
 status: 'Delivered',
 type: 'Software',
 ),
 _BuildComponentRow(
 id: _newId(),
 name: 'Lighting Rig',
 owner: 'AV engineer',
 status: 'Pending',
 type: 'Physical',
 ),
 ];
 }

 List<_IntegrationRow> _defaultIntegrations() {
 return [
 _IntegrationRow(
 id: _newId(),
 label: 'API to DB',
 description: 'Auth and content payloads proving against staging data.',
 status: 'Connected',
 ),
 _IntegrationRow(
 id: _newId(),
 label: 'Stage to Lighting',
 description: 'Control trigger and power handoff still being validated.',
 status: 'Pending',
 ),
 _IntegrationRow(
 id: _newId(),
 label: 'Scanner to Ticket Server',
 description: 'Real-time barcode validation pipeline under test.',
 status: 'In Progress',
 ),
 ];
 }

 List<_IssueRow> _defaultIssues() {
 return [
 _IssueRow(
 id: _newId(),
 title: 'Code Review Queue',
 detail:
 'Auth and integration branches need final sign-off before merge.',
 severity: 'High',
 ),
 _IssueRow(
 id: _newId(),
 title: 'Fabrication Tolerance Clash',
 detail:
 'Stage deck edge detailing still conflicts with lighting cable path.',
 severity: 'Critical',
 ),
 _IssueRow(
 id: _newId(),
 title: 'Environment Config Drift',
 detail:
 'Staging and production configs have diverged; alignment required.',
 severity: 'Medium',
 ),
 ];
 }

 String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

 void _logActivity(String action, {Map<String, dynamic>? details}) {
 final projectId =
 ProjectDataInherited.maybeOf(context)?.projectData.projectId?.trim() ??
 '';
 if (projectId.isEmpty) return;
 unawaited(
 ActivityLogService.instance.logActivity(
 projectId: projectId,
 phase: 'Design Phase',
 page: 'Technical Development',
 action: action,
 details: details,
 ),
 );
 }

 // ── KAZ AI row generator ──
 void _kazAiForRow() {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('KAZ AI: Generating suggestions for this row...'),
 duration: Duration(seconds: 2),
 ),
 );
 }

 // ─── Build method ─────────────────────────────────────────────────────

 @override
 Widget build(BuildContext context) {
 final isNarrow = MediaQuery.sizeOf(context).width < 980;
 final padding = AppBreakpoints.pagePadding(context);

 return ResponsiveScaffold(
 activeItemLabel: 'Technical Development',
 backgroundColor: Colors.white,
 floatingActionButton: const KazAiChatBubble(positioned: false),
 body: Column(
 children: [
 PlanningPhaseHeader(
 title: 'Technical Development',
showNavigationButtons: false, onExportPdf: _exportPdf),
 Expanded(
 child: SingleChildScrollView(
 padding: EdgeInsets.all(padding),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_isLoading) const LinearProgressIndicator(minHeight: 2),
 if (_isLoading) const SizedBox(height: 16),
 _buildFrameworkGuide(isNarrow),
 const SizedBox(height: 24),
 _buildWorkstreamRegisterPanel(),
 const SizedBox(height: 20),
 _buildComponentBuildPanel(),
 const SizedBox(height: 20),
 _buildIntegrationPanel(),
 const SizedBox(height: 20),
 _buildIssueTrackerPanel(),
 const SizedBox(height: 20),
 _buildRiskSignalsPanel(),
 const SizedBox(height: 20),
 _buildReadinessChecklistPanel(),
 const SizedBox(height: 20),
 _buildStandardsGatesPanel(),
 const SizedBox(height: 20),
 _buildDocumentationPanel(),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Engineering Design',
 nextLabel: 'Next: Tools Integration',
 onBack: () => context.go('/${AppRoutes.engineeringDesign}'),
 onNext: () => context.push('/${AppRoutes.toolsIntegration}'),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 // ─── Shared button helpers ────────────────────────────────────────────

 Widget _actionButton(IconData icon, String label,
 {VoidCallback? onPressed}) {
 final enabled = onPressed != null;
 return OutlinedButton.icon(
 onPressed: onPressed,
 icon: Icon(icon,
 size: 18,
 color: enabled ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
 label: Text(label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color:
 enabled ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 );
 }

 // ─── Technical Development Framework Guide ─────────────────────────────

 Widget _buildFrameworkGuide(bool isNarrow) {
 return Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Clickable header row
 InkWell(
 onTap: () => setState(() => _frameworkGuideExpanded = !_frameworkGuideExpanded),
 borderRadius: BorderRadius.circular(16),
 child: Padding(
 padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
 child: Row(
 children: [
 const Expanded(
 child: Text('Technical development framework',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
 ),
 AnimatedRotation(
 duration: const Duration(milliseconds: 200),
 turns: _frameworkGuideExpanded ? 0.5 : 0,
 child: Icon(Icons.expand_more, size: 22, color: const Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 ),
 // Collapsible content
 AnimatedCrossFade(
 firstChild: const SizedBox(width: double.infinity, height: 0),
 secondChild: Padding(
 padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Aligned with PMI PMBOK 4.3 (Direct & Manage Project Work), IEEE 1220 Systems Engineering, '
 'Agile Scrum/Kanban sprint execution, and ISO 9001 quality management principles.',
 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280), height: 1.5),
 ),
 const SizedBox(height: 18),
 isNarrow
 ? Column(children: _frameworkCards())
 : Row(
 children: _frameworkCards()
 .map((card) => Expanded(child: Padding(
 padding: const EdgeInsets.only(right: 12),
 child: card,
 )))
 .toList(),
 ),
 ],
 ),
 ),
 crossFadeState: _frameworkGuideExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
 duration: const Duration(milliseconds: 250),
 sizeCurve: Curves.easeInOut,
 ),
 ],
 ),
 );
 }

 List<Widget> _frameworkCards() {
 return [
 _FrameworkGuideCard(
 icon: Icons.code_rounded,
 title: 'Build & Sprint Execution',
 description:
 'Parallel workstreams, sprint sequencing, burndown tracking, and continuous integration.',
 color: const Color(0xFF0EA5E9),
 ),
 _FrameworkGuideCard(
 icon: Icons.link_rounded,
 title: 'Integration & Interface Proving',
 description:
 'Contract testing, API validation, physical system handoff, and integration verification.',
 color: const Color(0xFF059669),
 ),
 _FrameworkGuideCard(
 icon: Icons.verified_user_rounded,
 title: 'Quality & Defect Management',
 description:
 'Code review, fabrication tolerance, rework control, and ISO 9001 compliance gates.',
 color: const Color(0xFFF59E0B),
 ),
 _FrameworkGuideCard(
 icon: Icons.rocket_launch_rounded,
 title: 'Release & Deployment Readiness',
 description:
 'Go-live gates, rollback paths, handover playbooks, and production cut-over controls.',
 color: const Color(0xFFEF4444),
 ),
 ];
 }

 // ─── Workstream Register Panel (MAIN TABLE) ───────────────────────────

 Widget _buildWorkstreamRegisterPanel() {
 return _PanelShell(
 title: 'Workstream register',
 subtitle: 'Track build workstreams, ownership, and sprint progress',
 trailing: _actionButton(Icons.add, 'Add workstream',
 onPressed: () => _showWorkstreamDialog()),
 child: _workstreams.isEmpty
 ? _buildEmptyState('No workstreams added yet.',
 () => _showWorkstreamDialog())
 : Column(
 children: [
 _buildTableHeader(const [
 ('WORKSTREAM', 3),
 ('STATUS', 2),
 ('OWNER', 2),
 ('PROGRESS', 2),
 ('ACTIONS', 1),
 ]),
 const SizedBox(height: 4),
 ..._workstreams.asMap().entries.map((entry) {
 final item = entry.value;
 final idx = entry.key;
 return _buildWorkstreamRow(item, idx);
 }),
 ],
 ),
 );
 }

 Widget _buildWorkstreamRow(_WorkstreamItem item, int idx) {
 final progressColor = item.progress >= 80
 ? const Color(0xFF059669)
 : item.progress >= 40
 ? const Color(0xFFF59E0B)
 : const Color(0xFF0EA5E9);
 return Container(
 margin: const EdgeInsets.only(bottom: 3),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: idx.isEven ? Colors.white : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 ),
 child: Row(
 children: [
 // WORKSTREAM (flex 3)
 Expanded(
 flex: 3,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(item.title,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600)),
 if (item.subtitle.isNotEmpty)
 Padding(
 padding: const EdgeInsets.only(top: 2),
 child: Text(item.subtitle,
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF6B7280))),
 ),
 ],
 ),
 ),
 // STATUS (flex 2)
 Expanded(
 flex: 2,
 child: _buildStatusBadge(item.status),
 ),
 // OWNER (flex 2)
 Expanded(
 flex: 2,
 child: Text(item.owner,
 style:
 const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ),
 // PROGRESS (flex 2)
 Expanded(
 flex: 2,
 child: Row(
 children: [
 Expanded(
 child: ClipRRect(
 borderRadius: BorderRadius.circular(3),
 child: LinearProgressIndicator(
 value: (item.progress / 100).clamp(0.0, 1.0),
 minHeight: 5,
 backgroundColor: const Color(0xFFE5E7EB),
 valueColor:
 AlwaysStoppedAnimation<Color>(progressColor),
 ),
 ),
 ),
 const SizedBox(width: 6),
 Text('${item.progress}%',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: progressColor)),
 ],
 ),
 ),
 // ACTIONS (flex 1)
 Expanded(
 flex: 1,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 InkWell(
 onTap: () => _showWorkstreamDialog(existing: item),
 child: const Icon(Icons.edit_outlined,
 size: 14, color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 4),
 InkWell(
 onTap: () => _deleteWorkstreamWithConfirm(item),
 child: const Icon(Icons.delete_outline,
 size: 14, color: Color(0xFFEF4444)),
 ),

                                  InkWell(
                                    onTap: () => _kazAiForRow(),
                                    child: const Icon(Icons.auto_awesome,
                                        size: 14, color: Color(0xFFF59E0B)),
                                  ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // ─── Component Build Register Panel ───────────────────────────────────

 Widget _buildComponentBuildPanel() {
 return _PanelShell(
 title: 'Component build register',
 subtitle:
 'Track deliverables across software modules, fabrication packages, and site build items',
 trailing: _actionButton(Icons.add, 'Add component',
 onPressed: () => _showBuildComponentDialog()),
 child: _buildComponents.isEmpty
 ? _buildEmptyState('No components added yet.',
 () => _showBuildComponentDialog())
 : Column(
 children: [
 _buildTableHeader(const [
 ('COMPONENT', 3),
 ('OWNER', 2),
 ('STATUS', 2),
 ('TYPE', 1),
 ('ACTIONS', 1),
 ]),
 const SizedBox(height: 4),
 ..._buildComponents.asMap().entries.map((entry) {
 final item = entry.value;
 final idx = entry.key;
 return _buildComponentRow(item, idx);
 }),
 ],
 ),
 );
 }

 Widget _buildComponentRow(_BuildComponentRow item, int idx) {
 return Container(
 margin: const EdgeInsets.only(bottom: 3),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: idx.isEven ? Colors.white : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 ),
 child: Row(
 children: [
 Expanded(
 flex: 3,
 child: Text(item.name,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600)),
 ),
 Expanded(
 flex: 2,
 child: Text(item.owner,
 style:
 const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ),
 Expanded(
 flex: 2,
 child: _buildStatusBadge(item.status),
 ),
 Expanded(
 flex: 1,
 child: _buildTypeBadge(item.type),
 ),
 Expanded(
 flex: 1,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 InkWell(
 onTap: () => _showBuildComponentDialog(existing: item),
 child: const Icon(Icons.edit_outlined,
 size: 14, color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 4),
 InkWell(
 onTap: () => _deleteBuildComponentWithConfirm(item),
 child: const Icon(Icons.delete_outline,
 size: 14, color: Color(0xFFEF4444)),
 ),

                                  InkWell(
                                    onTap: () => _kazAiForRow(),
                                    child: const Icon(Icons.auto_awesome,
                                        size: 14, color: Color(0xFFF59E0B)),
                                  ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // ─── Integration & Interface Panel ────────────────────────────────────

 Widget _buildIntegrationPanel() {
 return _PanelShell(
 title: 'Integration & interface realization',
 subtitle:
 'Live connection checks between build components, services, and physical systems',
 trailing: _actionButton(Icons.add, 'Add integration',
 onPressed: () => _showIntegrationDialog()),
 child: _integrations.isEmpty
 ? _buildEmptyState('No integrations added yet.',
 () => _showIntegrationDialog())
 : Column(
 children: [
 _buildTableHeader(const [
 ('INTERFACE', 3),
 ('STATUS', 2),
 ('DESCRIPTION', 3),
 ('ACTIONS', 1),
 ]),
 const SizedBox(height: 4),
 ..._integrations.asMap().entries.map((entry) {
 final item = entry.value;
 final idx = entry.key;
 return _buildIntegrationRow(item, idx);
 }),
 ],
 ),
 );
 }

 Widget _buildIntegrationRow(_IntegrationRow item, int idx) {
 return Container(
 margin: const EdgeInsets.only(bottom: 3),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: idx.isEven ? Colors.white : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 ),
 child: Row(
 children: [
 Expanded(
 flex: 3,
 child: Text(item.label,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600)),
 ),
 Expanded(
 flex: 2,
 child: _buildStatusBadge(item.status),
 ),
 Expanded(
 flex: 3,
 child: Text(item.description,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF6B7280))),
 ),
 Expanded(
 flex: 1,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 InkWell(
 onTap: () => _showIntegrationDialog(existing: item),
 child: const Icon(Icons.edit_outlined,
 size: 14, color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 4),
 InkWell(
 onTap: () => _deleteIntegrationWithConfirm(item),
 child: const Icon(Icons.delete_outline,
 size: 14, color: Color(0xFFEF4444)),
 ),

                                  InkWell(
                                    onTap: () => _kazAiForRow(),
                                    child: const Icon(Icons.auto_awesome,
                                        size: 14, color: Color(0xFFF59E0B)),
                                  ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // ─── Defect & Issue Tracker Panel ─────────────────────────────────────

 Widget _buildIssueTrackerPanel() {
 return _PanelShell(
 title: 'Defect & issue tracker',
 subtitle:
 'Current build blockers, production exceptions, and technical rework items',
 trailing: _actionButton(Icons.add, 'Add issue',
 onPressed: () => _showIssueDialog()),
 child: _issues.isEmpty
 ? _buildEmptyState('No issues added yet.',
 () => _showIssueDialog())
 : Column(
 children: [
 _buildTableHeader(const [
 ('ISSUE', 3),
 ('SEVERITY', 1),
 ('DETAIL', 3),
 ('ACTIONS', 1),
 ]),
 const SizedBox(height: 4),
 ..._issues.asMap().entries.map((entry) {
 final item = entry.value;
 final idx = entry.key;
 return _buildIssueRow(item, idx);
 }),
 ],
 ),
 );
 }

 Widget _buildIssueRow(_IssueRow item, int idx) {
 return Container(
 margin: const EdgeInsets.only(bottom: 3),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: idx.isEven ? Colors.white : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 ),
 child: Row(
 children: [
 Expanded(
 flex: 3,
 child: Text(item.title,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600)),
 ),
 Expanded(
 flex: 1,
 child: _buildSeverityBadge(item.severity),
 ),
 Expanded(
 flex: 3,
 child: Text(item.detail,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF6B7280))),
 ),
 Expanded(
 flex: 1,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 InkWell(
 onTap: () => _showIssueDialog(existing: item),
 child: const Icon(Icons.edit_outlined,
 size: 14, color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 4),
 InkWell(
 onTap: () => _deleteIssueWithConfirm(item),
 child: const Icon(Icons.delete_outline,
 size: 14, color: Color(0xFFEF4444)),
 ),

                                  InkWell(
                                    onTap: () => _kazAiForRow(),
                                    child: const Icon(Icons.auto_awesome,
                                        size: 14, color: Color(0xFFF59E0B)),
                                  ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // ─── Risk Signals Panel ───────────────────────────────────────────────

 Widget _buildRiskSignalsPanel() {
 // Auto-detected signals from workstream analysis
 final autoSignals = <_RiskSignalRow>[];
 final atRiskWorkstreams =
 _workstreams.where((w) => w.status.toLowerCase().contains('risk')).length;
 final blockedWorkstreams =
 _workstreams.where((w) => w.status.toLowerCase().contains('blocked')).length;
 final blockedIntegrations =
 _integrations.where((i) => i.status.toLowerCase().contains('blocked')).length;
 final criticalIssues =
 _issues.where((i) => i.severity.toLowerCase() == 'critical').length;

 if (atRiskWorkstreams > 0) {
 autoSignals.add(_RiskSignalRow(
 id: 'auto_atrisk',
 signal: 'At-risk workstreams',
 description:
 '$atRiskWorkstreams workstream${atRiskWorkstreams > 1 ? 's' : ''} flagged at risk.',
 severity: 'High',
 category: 'Workstream status',
 owner: 'Project Manager',
 source: 'Auto-detected',
 status: 'Open',
 ));
 }
 if (blockedWorkstreams > 0) {
 autoSignals.add(_RiskSignalRow(
 id: 'auto_blocked',
 signal: 'Blocked workstreams',
 description:
 '$blockedWorkstreams workstream${blockedWorkstreams > 1 ? 's' : ''} currently blocked.',
 severity: 'Critical',
 category: 'Workstream status',
 owner: 'Technical Lead',
 source: 'Auto-detected',
 status: 'Open',
 ));
 }
 if (blockedIntegrations > 0) {
 autoSignals.add(_RiskSignalRow(
 id: 'auto_intblocked',
 signal: 'Integration blockers',
 description:
 '$blockedIntegrations integration${blockedIntegrations > 1 ? 's' : ''} blocked.',
 severity: 'High',
 category: 'Integration status',
 owner: 'Integration Lead',
 source: 'Auto-detected',
 status: 'Monitoring',
 ));
 }
 if (criticalIssues > 0) {
 autoSignals.add(_RiskSignalRow(
 id: 'auto_critical',
 signal: 'Critical defects',
 description:
 '$criticalIssues critical issue${criticalIssues > 1 ? 's' : ''} unresolved.',
 severity: 'Critical',
 category: 'Defect tracker',
 owner: 'QA Lead',
 source: 'Auto-detected',
 status: 'Open',
 ));
 }

 final allSignals = [...autoSignals, ..._riskSignals];

 return _PanelShell(
 title: 'Risk signals',
 subtitle: 'Auto-detected and user-added risk alerts across the build',
 trailing: TextButton.icon(
 onPressed: () => _showRiskSignalDialog(),
 icon: const Icon(Icons.add_rounded, size: 16),
 label: const Text('Add signal'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF4154F1),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 ),
 child: allSignals.isEmpty
 ? Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.shield_outlined,
 size: 36,
 color: const Color(0xFF10B981).withOpacity(0.6)),
 const SizedBox(height: 8),
 const Text('No active risk signals',
 style: TextStyle(
 color: Color(0xFF10B981),
 fontWeight: FontWeight.w600)),
 ],
 ),
 ),
 )
 : Column(
 children: [
 // Table header
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: const BoxDecoration(
 color: Color(0xFF1F2937),
 borderRadius: BorderRadius.only(
 topLeft: Radius.circular(8),
 topRight: Radius.circular(8),
 ),
 ),
 child: const Row(
 children: [
 Expanded(flex: 2, child: Text('SIGNAL', style: _tableHeaderStyle)),
 Expanded(flex: 1, child: Text('SEVERITY', style: _tableHeaderStyle)),
 Expanded(flex: 3, child: Text('DESCRIPTION', style: _tableHeaderStyle)),
 Expanded(flex: 1, child: Text('SOURCE', style: _tableHeaderStyle)),
 Expanded(flex: 1, child: Text('', style: _tableHeaderStyle)),
 ],
 ),
 ),
 const SizedBox(height: 4),
 ...allSignals.asMap().entries.map((entry) {
 final signal = entry.value;
 final idx = entry.key;
 final isAuto = signal.source == 'Auto-detected';
 return Container(
 margin: const EdgeInsets.only(bottom: 3),
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: idx.isEven
 ? Colors.white
 : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(6),
 border:
 Border.all(color: const Color(0xFFF3F4F6)),
 ),
 child: Row(
 children: [
 Expanded(
 flex: 2,
 child: Text(signal.signal,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600)),
 ),
 Expanded(
 flex: 1,
 child: _buildSeverityBadge(signal.severity),
 ),
 Expanded(
 flex: 3,
 child: Text(signal.description,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 11,
 color: Color(0xFF6B7280))),
 ),
 Expanded(
 flex: 1,
 child: Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: isAuto
 ? const Color(0xFFEFF6FF)
 : const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(signal.source,
 style: TextStyle(
 fontSize: 9,
 fontWeight: FontWeight.w600,
 color: isAuto
 ? const Color(0xFF2563EB)
 : const Color(0xFF6B7280))),
 ),
 ),
 Expanded(
 flex: 1,
 child: isAuto
 ? const SizedBox.shrink()
 : Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 InkWell(
 onTap: () => _showRiskSignalDialog(
 existing: signal),
 child: const Icon(Icons.edit_outlined,
 size: 14,
 color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 4),
 InkWell(
 onTap: () =>
 _deleteRiskSignalWithConfirm(signal),
 child: const Icon(Icons.delete_outline,
 size: 14,
 color: Color(0xFFEF4444)),
 ),

                                  InkWell(
                                    onTap: () => _kazAiForRow(),
                                    child: const Icon(Icons.auto_awesome,
                                        size: 14, color: Color(0xFFF59E0B)),
                                  ),
 ],
 ),
 ),
 ],
 ),
 );
 }),
 if (_riskSignals.isNotEmpty)
 Padding(
 padding: const EdgeInsets.only(top: 6),
 child: Text(
 '${_riskSignals.length} custom signal${_riskSignals.length != 1 ? 's' : ''}',
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF9CA3AF))),
 ),
 ],
 ),
 );
 }

 // ─── Readiness Checklist Panel ────────────────────────────────────────

 Widget _buildReadinessChecklistPanel() {
 return _PanelShell(
 title: 'Deployment readiness checklist',
 subtitle:
 'Go-live control pack with final QA checks and handover readiness',
 trailing: _actionButton(Icons.add, 'Add item',
 onPressed: () => _showReadinessDialog()),
 child: _readinessItems.isEmpty
 ? _buildEmptyState('No readiness items added yet.',
 () => _showReadinessDialog())
 : Column(
 children: [
 _buildTableHeader(const [
 ('CHECKLIST ITEM', 4),
 ('OWNER', 2),
 ('STATUS', 2),
 ('ACTIONS', 1),
 ]),
 const SizedBox(height: 4),
 ..._readinessItems.asMap().entries.map((entry) {
 final item = entry.value;
 final idx = entry.key;
 return _buildReadinessRow(item, idx);
 }),
 ],
 ),
 );
 }

 Widget _buildReadinessRow(_ReadinessItem item, int idx) {
 return Container(
 margin: const EdgeInsets.only(bottom: 3),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: idx.isEven ? Colors.white : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 ),
 child: Row(
 children: [
 Expanded(
 flex: 4,
 child: Text(item.title,
 style: const TextStyle(
 fontSize: 12, fontWeight: FontWeight.w600)),
 ),
 Expanded(
 flex: 2,
 child: Text(item.owner,
 style:
 const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
 ),
 Expanded(
 flex: 2,
 child: _buildStatusBadge(item.status),
 ),
 Expanded(
 flex: 1,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 InkWell(
 onTap: () => _showReadinessDialog(existing: item),
 child: const Icon(Icons.edit_outlined,
 size: 14, color: Color(0xFF6B7280)),
 ),
 const SizedBox(width: 4),
 InkWell(
 onTap: () => _deleteReadinessWithConfirm(item),
 child: const Icon(Icons.delete_outline,
 size: 14, color: Color(0xFFEF4444)),
 ),

                                  InkWell(
                                    onTap: () => _kazAiForRow(),
                                    child: const Icon(Icons.auto_awesome,
                                        size: 14, color: Color(0xFFF59E0B)),
                                  ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // ─── Standards Gates Panel ────────────────────────────────────────────

 Widget _buildStandardsGatesPanel() {
 return _PanelShell(
 title: 'Technical standards gates',
 subtitle: 'Active quality gates spanning software and physical controls',
 trailing: TextButton.icon(
 onPressed: _addStandardChip,
 icon: const Icon(Icons.add_rounded, size: 16),
 label: const Text('Add standard'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF4154F1),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 ),
 child: Wrap(
 spacing: 8,
 runSpacing: 8,
 children: [
 ..._standardsChips.map(_buildEditableChip),
 ],
 ),
 );
 }

 Widget _buildEditableChip(_ChipItem chip) {
 final isActive = chip.label.toLowerCase().contains('signed') ||
 chip.label.toLowerCase().contains('active') ||
 chip.label.toLowerCase().contains('cleared') ||
 chip.label.toLowerCase().contains('locked');
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: isActive
 ? const Color(0xFFECFDF5)
 : const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: isActive
 ? const Color(0xFF059669).withOpacity(0.3)
 : const Color(0xFFD1D5DB),
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 isActive ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
 size: 14,
 color: isActive ? const Color(0xFF059669) : const Color(0xFF9CA3AF),
 ),
 const SizedBox(width: 6),
 InkWell(
 onTap: () => _openStandardsChipDialog(existing: chip),
 child: Text(chip.label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: isActive
 ? const Color(0xFF059669)
 : const Color(0xFF6B7280),
 )),
 ),
 const SizedBox(width: 4),
 InkWell(
 onTap: () => _deleteStandardChipWithConfirm(chip),
 child: const Icon(Icons.close, size: 14, color: Color(0xFF9CA3AF)),
 ),
 ],
 ),
 );
 }

 // ─── Documentation & Notes Panel ──────────────────────────────────────

 Widget _buildDocumentationPanel() {
 return _PanelShell(
 title: 'Documentation & notes',
 subtitle: 'Build approach, production notes, and reference material',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Approach',
 style:
 TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
 const SizedBox(height: 8),
 VoiceTextField(
 controller: _approachController,
 minLines: 2,
 maxLines: null,
 decoration: InputDecoration(
 hintText:
 'Describe the delivery approach, prototype loops, and release gates.',
 hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFF0EA5E9)),
 ),
 ),
 style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
 ),
 const SizedBox(height: 16),
 const Text('Notes',
 style:
 TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
 const SizedBox(height: 8),
 VoiceTextField(
 controller: _notesController,
 minLines: 3,
 maxLines: null,
 decoration: InputDecoration(
 hintText:
 'Capture build decisions, fabrication notes, environment assumptions, and release dependencies.',
 hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFF0EA5E9)),
 ),
 ),
 style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
 ),
 ],
 ),
 );
 }

 // ─── Shared table helpers ─────────────────────────────────────────────

 static const _tableHeaderStyle = TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: Color(0xFFD1D5DB),
 letterSpacing: 0.5,
 );

 Widget _buildTableHeader(List<(String, int)> columns) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: const BoxDecoration(
 color: Color(0xFF1F2937),
 borderRadius: BorderRadius.only(
 topLeft: Radius.circular(8),
 topRight: Radius.circular(8),
 ),
 ),
 child: Row(
 children: columns
 .map((col) => Expanded(
 flex: col.$2,
 child: Text(col.$1, style: _tableHeaderStyle),
 ))
 .toList(),
 ),
 );
 }

 Widget _buildStatusBadge(String status) {
 final color = _colorForStatus(status);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: color.withOpacity(0.2)),
 ),
 child: Text(status,
 style: TextStyle(
 fontSize: 11, fontWeight: FontWeight.w700, color: color)),
 );
 }

 Widget _buildSeverityBadge(String severity) {
 final color = _colorForSeverity(severity);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: color.withOpacity(0.2)),
 ),
 child: Text(severity,
 style: TextStyle(
 fontSize: 11, fontWeight: FontWeight.w700, color: color)),
 );
 }

 Widget _buildTypeBadge(String type) {
 final isSoftware = type.toLowerCase().contains('software');
 final color =
 isSoftware ? const Color(0xFF2563EB) : const Color(0xFFD97706);
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: color.withOpacity(0.2)),
 ),
 child: Text(type,
 style: TextStyle(
 fontSize: 10, fontWeight: FontWeight.w700, color: color)),
 );
 }

 Widget _buildEmptyState(String message, VoidCallback onAdd) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(message,
 style: const TextStyle(color: Color(0xFF64748B))),
 const SizedBox(height: 12),
 ElevatedButton.icon(
 onPressed: onAdd,
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add first item'),
 ),
 ],
 ),
 ),
 );
 }

 Color _colorForStatus(String status) {
 final lower = status.toLowerCase();
 if (lower.contains('delivered') ||
 lower.contains('ready') ||
 lower.contains('connected') ||
 lower.contains('validated') ||
 lower.contains('active') ||
 lower.contains('current') ||
 lower.contains('pass') ||
 lower.contains('staffed')) {
 return const Color(0xFF059669);
 }
 if (lower.contains('blocked') ||
 lower.contains('critical') ||
 lower.contains('fail') ||
 lower.contains('risk')) {
 return const Color(0xFFDC2626);
 }
 if (lower.contains('production') ||
 lower.contains('progress') ||
 lower.contains('review') ||
 lower.contains('partially') ||
 lower.contains('pending') ||
 lower.contains('watch') ||
 lower.contains('backlog')) {
 return const Color(0xFFF59E0B);
 }
 if (lower.contains('draft') ||
 lower.contains('planning') ||
 lower.contains('depends')) {
 return const Color(0xFF64748B);
 }
 return const Color(0xFF0EA5E9);
 }

 Color _colorForSeverity(String severity) {
 final lower = severity.toLowerCase();
 if (lower == 'critical') return const Color(0xFFDC2626);
 if (lower == 'high') return const Color(0xFFF97316);
 if (lower == 'medium') return const Color(0xFFF59E0B);
 return const Color(0xFF6B7280);
 }

 // ─── CRUD Dialogs: Workstreams ────────────────────────────────────────

 void _showWorkstreamDialog({_WorkstreamItem? existing}) {
 final isEdit = existing != null;
 final titleCtl = TextEditingController(text: existing?.title ?? '');
 final subtitleCtl = TextEditingController(text: existing?.subtitle ?? '');
 final ownerCtl = TextEditingController(text: existing?.owner ?? '');
 String status = existing?.status ?? _workstreamStatusOptions.first;
 int progress = existing?.progress ?? 0;

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Row(
 children: [
 Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
 size: 20, color: const Color(0xFF4154F1)),
 const SizedBox(width: 8),
 Text(isEdit ? 'Edit workstream' : 'Add workstream',
 style: const TextStyle(fontSize: 16)),
 ],
 ),
 content: SizedBox(
 width: 520,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: titleCtl,
 decoration: const InputDecoration(
 labelText: 'Workstream title',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: subtitleCtl,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Scope / notes',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: _workstreamStatusOptions.contains(status)
 ? status
 : _workstreamStatusOptions.first,
 items: _workstreamStatusOptions
 .map((option) => DropdownMenuItem(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setModalState(() => status = value);
 },
 decoration: const InputDecoration(
 labelText: 'Status',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: ownerCtl,
 decoration: const InputDecoration(
 labelText: 'Owner',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 12),
 SizedBox(
 width: 100,
 child: VoiceTextField(
 controller: TextEditingController(
 text: progress.toString()),
 keyboardType: TextInputType.number,
 decoration: const InputDecoration(
 labelText: 'Progress %',
 isDense: true,
 border: OutlineInputBorder(),
 suffixText: '%',
 ),
 onChanged: (value) {
 final parsed = int.tryParse(value) ?? 0;
 progress = parsed.clamp(0, 100);
 },
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final item = _WorkstreamItem(
 id: existing?.id ?? _newId(),
 title: titleCtl.text.trim(),
 subtitle: subtitleCtl.text.trim(),
 status: status,
 owner: ownerCtl.text.trim(),
 progress: progress,
 );
 setState(() {
 if (isEdit) {
 final idx =
 _workstreams.indexWhere((w) => w.id == item.id);
 if (idx != -1) _workstreams[idx] = item;
 } else {
 _workstreams.add(item);
 }
 });
 _scheduleSave();
 _logActivity(
 isEdit
 ? 'Edited workstream row'
 : 'Added workstream row',
 details: {'itemId': item.id},
 );
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFF4154F1),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8))),
 child: Text(isEdit ? 'Save' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 void _deleteWorkstreamWithConfirm(_WorkstreamItem item) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete workstream?'),
 content: Text(
 'Are you sure you want to delete "${item.title}"? This action can be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final removed = item;
 setState(() => _workstreams.removeWhere((w) => w.id == item.id));
 _scheduleSave();
 _logActivity('Deleted workstream row',
 details: {'itemId': item.id});
 Navigator.of(ctx).pop();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Workstream "${removed.title}" deleted'),
 action: SnackBarAction(
 label: 'Undo',
 onPressed: () {
 setState(() => _workstreams.add(removed));
 _scheduleSave();
 },
 ),
 ),
 );
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFEF4444)),
 child: const Text('Delete'),
 ),
 ],
 ),
 );
 }

 // ─── CRUD Dialogs: Build Components ───────────────────────────────────

 void _showBuildComponentDialog({_BuildComponentRow? existing}) {
 final isEdit = existing != null;
 final nameCtl = TextEditingController(text: existing?.name ?? '');
 final ownerCtl = TextEditingController(text: existing?.owner ?? '');
 String status = existing?.status ?? _buildStatusOptions.first;
 String type = existing?.type ?? 'Software';

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Row(
 children: [
 Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
 size: 20, color: const Color(0xFF4154F1)),
 const SizedBox(width: 8),
 Text(isEdit ? 'Edit component' : 'Add component',
 style: const TextStyle(fontSize: 16)),
 ],
 ),
 content: SizedBox(
 width: 480,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: nameCtl,
 decoration: const InputDecoration(
 labelText: 'Component name',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: ownerCtl,
 decoration: const InputDecoration(
 labelText: 'Owner',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 value: _buildStatusOptions.contains(status)
 ? status
 : _buildStatusOptions.first,
 items: _buildStatusOptions
 .map((option) => DropdownMenuItem(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setModalState(() => status = value);
 },
 decoration: const InputDecoration(
 labelText: 'Status',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: type,
 items: ['Software', 'Physical', 'Mixed']
 .map((option) => DropdownMenuItem(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setModalState(() => type = value);
 },
 decoration: const InputDecoration(
 labelText: 'Type',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final item = _BuildComponentRow(
 id: existing?.id ?? _newId(),
 name: nameCtl.text.trim(),
 owner: ownerCtl.text.trim(),
 status: status,
 type: type,
 );
 setState(() {
 if (isEdit) {
 final idx =
 _buildComponents.indexWhere((c) => c.id == item.id);
 if (idx != -1) _buildComponents[idx] = item;
 } else {
 _buildComponents.add(item);
 }
 });
 _scheduleSave();
 _logActivity(
 isEdit ? 'Edited build component' : 'Added build component',
 details: {'itemId': item.id},
 );
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFF4154F1),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8))),
 child: Text(isEdit ? 'Save' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 void _deleteBuildComponentWithConfirm(_BuildComponentRow item) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete component?'),
 content: Text(
 'Are you sure you want to delete "${item.name}"? This action can be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final removed = item;
 setState(
 () => _buildComponents.removeWhere((c) => c.id == item.id));
 _scheduleSave();
 Navigator.of(ctx).pop();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Component "${removed.name}" deleted'),
 action: SnackBarAction(
 label: 'Undo',
 onPressed: () {
 setState(() => _buildComponents.add(removed));
 _scheduleSave();
 },
 ),
 ),
 );
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFEF4444)),
 child: const Text('Delete'),
 ),
 ],
 ),
 );
 }

 // ─── CRUD Dialogs: Integrations ───────────────────────────────────────

 void _showIntegrationDialog({_IntegrationRow? existing}) {
 final isEdit = existing != null;
 final labelCtl = TextEditingController(text: existing?.label ?? '');
 final descCtl =
 TextEditingController(text: existing?.description ?? '');
 String status = existing?.status ?? _integrationStatusOptions.first;

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Row(
 children: [
 Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
 size: 20, color: const Color(0xFF4154F1)),
 const SizedBox(width: 8),
 Text(isEdit ? 'Edit integration' : 'Add integration',
 style: const TextStyle(fontSize: 16)),
 ],
 ),
 content: SizedBox(
 width: 480,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: labelCtl,
 decoration: const InputDecoration(
 labelText: 'Interface name',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: descCtl,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Description',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: _integrationStatusOptions.contains(status)
 ? status
 : _integrationStatusOptions.first,
 items: _integrationStatusOptions
 .map((option) => DropdownMenuItem(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setModalState(() => status = value);
 },
 decoration: const InputDecoration(
 labelText: 'Status',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final item = _IntegrationRow(
 id: existing?.id ?? _newId(),
 label: labelCtl.text.trim(),
 description: descCtl.text.trim(),
 status: status,
 );
 setState(() {
 if (isEdit) {
 final idx =
 _integrations.indexWhere((i) => i.id == item.id);
 if (idx != -1) _integrations[idx] = item;
 } else {
 _integrations.add(item);
 }
 });
 _scheduleSave();
 _logActivity(
 isEdit ? 'Edited integration' : 'Added integration',
 details: {'itemId': item.id},
 );
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFF4154F1),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8))),
 child: Text(isEdit ? 'Save' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 void _deleteIntegrationWithConfirm(_IntegrationRow item) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete integration?'),
 content: Text(
 'Are you sure you want to delete "${item.label}"? This action can be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final removed = item;
 setState(
 () => _integrations.removeWhere((i) => i.id == item.id));
 _scheduleSave();
 Navigator.of(ctx).pop();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Integration "${removed.label}" deleted'),
 action: SnackBarAction(
 label: 'Undo',
 onPressed: () {
 setState(() => _integrations.add(removed));
 _scheduleSave();
 },
 ),
 ),
 );
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFEF4444)),
 child: const Text('Delete'),
 ),
 ],
 ),
 );
 }

 // ─── CRUD Dialogs: Issues ─────────────────────────────────────────────

 void _showIssueDialog({_IssueRow? existing}) {
 final isEdit = existing != null;
 final titleCtl = TextEditingController(text: existing?.title ?? '');
 final detailCtl = TextEditingController(text: existing?.detail ?? '');
 String severity = existing?.severity ?? _severityOptions[1]; // Default to High

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Row(
 children: [
 Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
 size: 20, color: const Color(0xFF4154F1)),
 const SizedBox(width: 8),
 Text(isEdit ? 'Edit issue' : 'Add issue',
 style: const TextStyle(fontSize: 16)),
 ],
 ),
 content: SizedBox(
 width: 480,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: titleCtl,
 decoration: const InputDecoration(
 labelText: 'Issue title',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: _severityOptions.contains(severity)
 ? severity
 : _severityOptions[1],
 items: _severityOptions
 .map((option) => DropdownMenuItem(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setModalState(() => severity = value);
 },
 decoration: const InputDecoration(
 labelText: 'Severity',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: detailCtl,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Detail',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final item = _IssueRow(
 id: existing?.id ?? _newId(),
 title: titleCtl.text.trim(),
 detail: detailCtl.text.trim(),
 severity: severity,
 );
 setState(() {
 if (isEdit) {
 final idx =
 _issues.indexWhere((i) => i.id == item.id);
 if (idx != -1) _issues[idx] = item;
 } else {
 _issues.add(item);
 }
 });
 _scheduleSave();
 _logActivity(
 isEdit ? 'Edited issue' : 'Added issue',
 details: {'itemId': item.id},
 );
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFF4154F1),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8))),
 child: Text(isEdit ? 'Save' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 void _deleteIssueWithConfirm(_IssueRow item) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete issue?'),
 content: Text(
 'Are you sure you want to delete "${item.title}"? This action can be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final removed = item;
 setState(() => _issues.removeWhere((i) => i.id == item.id));
 _scheduleSave();
 Navigator.of(ctx).pop();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Issue "${removed.title}" deleted'),
 action: SnackBarAction(
 label: 'Undo',
 onPressed: () {
 setState(() => _issues.add(removed));
 _scheduleSave();
 },
 ),
 ),
 );
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFEF4444)),
 child: const Text('Delete'),
 ),
 ],
 ),
 );
 }

 // ─── CRUD Dialogs: Risk Signals ───────────────────────────────────────

 void _showRiskSignalDialog({_RiskSignalRow? existing}) {
 final isEdit = existing != null;
 final signalCtl = TextEditingController(text: existing?.signal ?? '');
 final descCtl =
 TextEditingController(text: existing?.description ?? '');
 final categoryCtl =
 TextEditingController(text: existing?.category ?? '');
 final ownerCtl = TextEditingController(text: existing?.owner ?? '');
 String severity = existing?.severity ?? 'High';

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Row(
 children: [
 Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
 size: 20, color: const Color(0xFF4154F1)),
 const SizedBox(width: 8),
 Text(isEdit ? 'Edit risk signal' : 'Add risk signal',
 style: const TextStyle(fontSize: 16)),
 ],
 ),
 content: SizedBox(
 width: 520,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: signalCtl,
 decoration: const InputDecoration(
 labelText: 'Signal name',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: _severityOptions.contains(severity)
 ? severity
 : _severityOptions[1],
 items: _severityOptions
 .map((option) => DropdownMenuItem(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setModalState(() => severity = value);
 },
 decoration: const InputDecoration(
 labelText: 'Severity',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: descCtl,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Description',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: categoryCtl,
 decoration: const InputDecoration(
 labelText: 'Category',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextField(
 controller: ownerCtl,
 decoration: const InputDecoration(
 labelText: 'Owner',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final item = _RiskSignalRow(
 id: existing?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
 signal: signalCtl.text.trim(),
 description: descCtl.text.trim(),
 severity: severity,
 category: categoryCtl.text.trim(),
 owner: ownerCtl.text.trim(),
 source: 'Manual',
 status: 'Open',
 );
 setState(() {
 if (isEdit) {
 final idx = _riskSignals
 .indexWhere((r) => r.id == item.id);
 if (idx != -1) _riskSignals[idx] = item;
 } else {
 _riskSignals.add(item);
 }
 });
 _scheduleSave();
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFF4154F1),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8))),
 child: Text(isEdit ? 'Save' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 void _deleteRiskSignalWithConfirm(_RiskSignalRow item) {
 setState(() => _riskSignals.removeWhere((r) => r.id == item.id));
 _scheduleSave();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Signal "${item.signal}" deleted'),
 action: SnackBarAction(
 label: 'Undo',
 onPressed: () {
 setState(() => _riskSignals.add(item));
 _scheduleSave();
 },
 ),
 ),
 );
 }

 // ─── CRUD Dialogs: Readiness Items ────────────────────────────────────

 void _showReadinessDialog({_ReadinessItem? existing}) {
 final isEdit = existing != null;
 final titleCtl = TextEditingController(text: existing?.title ?? '');
 String owner = existing?.owner ??
 _ownerOptions(currentValue: existing?.owner).first;
 String status = existing?.status ?? _readinessStatusOptions.first;

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (context, setModalState) => AlertDialog(
 title: Row(
 children: [
 Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
 size: 20, color: const Color(0xFF4154F1)),
 const SizedBox(width: 8),
 Text(isEdit ? 'Edit checklist item' : 'Add checklist item',
 style: const TextStyle(fontSize: 16)),
 ],
 ),
 content: SizedBox(
 width: 520,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: titleCtl,
 decoration: const InputDecoration(
 labelText: 'Checklist item',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: _ownerOptions(currentValue: owner).contains(owner)
 ? owner
 : _ownerOptions(currentValue: owner).first,
 items: _ownerOptions(currentValue: owner)
 .map((option) => DropdownMenuItem(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setModalState(() => owner = value);
 },
 decoration: const InputDecoration(
 labelText: 'Owner',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: _readinessStatusOptions.contains(status)
 ? status
 : _readinessStatusOptions.first,
 items: _readinessStatusOptions
 .map((option) => DropdownMenuItem(
 value: option,
 child: Text(option),
 ))
 .toList(),
 onChanged: (value) {
 if (value == null) return;
 setModalState(() => status = value);
 },
 decoration: const InputDecoration(
 labelText: 'Status',
 isDense: true,
 border: OutlineInputBorder(),
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final item = _ReadinessItem(
 id: existing?.id ?? _newId(),
 title: titleCtl.text.trim(),
 owner: owner,
 status: status,
 );
 setState(() {
 if (isEdit) {
 final idx = _readinessItems
 .indexWhere((r) => r.id == item.id);
 if (idx != -1) _readinessItems[idx] = item;
 } else {
 _readinessItems.add(item);
 }
 });
 _scheduleSave();
 _logActivity(
 isEdit
 ? 'Edited readiness row'
 : 'Added readiness row',
 details: {'itemId': item.id},
 );
 Navigator.of(ctx).pop();
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFF4154F1),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8))),
 child: Text(isEdit ? 'Save' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 void _deleteReadinessWithConfirm(_ReadinessItem item) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete checklist item?'),
 content: Text(
 'Are you sure you want to delete this item? This action can be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Cancel')),
 FilledButton(
 onPressed: () {
 final removed = item;
 setState(() =>
 _readinessItems.removeWhere((r) => r.id == item.id));
 _scheduleSave();
 Navigator.of(ctx).pop();
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content:
 Text('Checklist item deleted'),
 action: SnackBarAction(
 label: 'Undo',
 onPressed: () {
 setState(() => _readinessItems.add(removed));
 _scheduleSave();
 },
 ),
 ),
 );
 },
 style: FilledButton.styleFrom(
 backgroundColor: const Color(0xFFEF4444)),
 child: const Text('Delete'),
 ),
 ],
 ),
 );
 }

 // ─── CRUD: Standards Chips ────────────────────────────────────────────

 void _addStandardChip() {
 _openStandardsChipDialog();
 }

 void _deleteStandardChipWithConfirm(_ChipItem chip) {
 setState(() => _standardsChips.removeWhere((item) => item.id == chip.id));
 _scheduleSave();
 _logActivity('Deleted standards chip', details: {'itemId': chip.id});
 }

 Future<void> _openStandardsChipDialog({_ChipItem? existing}) async {
 final controller = TextEditingController(text: existing?.label ?? '');
 final saved = await showDialog<bool>(
 context: context,
 builder: (dialogContext) => AlertDialog(
 title: Text(existing == null
 ? 'Add quality standard'
 : 'Edit quality standard'),
 content: SizedBox(
 width: 420,
 child: VoiceTextField(
 controller: controller,
 decoration: const InputDecoration(
 labelText: 'Standard / quality code',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(dialogContext).pop(false),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () => Navigator.of(dialogContext).pop(true),
 child: Text(existing == null ? 'Add standard' : 'Save changes'),
 ),
 ],
 ),
 );
 if (saved != true) return;
 final item =
 _ChipItem(id: existing?.id ?? _newId(), label: controller.text.trim());
 setState(() {
 if (existing == null) {
 _standardsChips.add(item);
 } else {
 final index =
 _standardsChips.indexWhere((entry) => entry.id == existing.id);
 if (index != -1) _standardsChips[index] = item;
 }
 });
 _scheduleSave();
 _logActivity(
 existing == null ? 'Added standards chip' : 'Edited standards chip',
 details: {'itemId': item.id},
 );
 }

}

// ═══════════════════════════════════════════════════════════════════════════
// DATA MODEL CLASSES
// ═══════════════════════════════════════════════════════════════════════════

class _WorkstreamItem {
 final String id;
 final String title;
 final String subtitle;
 final String status;
 final String owner;
 final int progress;

 _WorkstreamItem({
 required this.id,
 required this.title,
 required this.subtitle,
 required this.status,
 this.owner = '',
 this.progress = 0,
 });

 _WorkstreamItem copyWith({
 String? title,
 String? subtitle,
 String? status,
 String? owner,
 int? progress,
 }) {
 return _WorkstreamItem(
 id: id,
 title: title ?? this.title,
 subtitle: subtitle ?? this.subtitle,
 status: status ?? this.status,
 owner: owner ?? this.owner,
 progress: progress ?? this.progress,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'title': title,
 'subtitle': subtitle,
 'status': status,
 'owner': owner,
 'progress': progress,
 };

 static List<_WorkstreamItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _WorkstreamItem(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 title: map['title']?.toString() ?? '',
 subtitle: map['subtitle']?.toString() ?? '',
 status: map['status']?.toString() ?? 'In planning',
 owner: map['owner']?.toString() ?? '',
 progress: (map['progress'] is int)
 ? map['progress'] as int
 : int.tryParse(map['progress']?.toString() ?? '0') ?? 0,
 );
 }).toList();
 }
}

class _ReadinessItem {
 final String id;
 final String title;
 final String owner;
 final String status;

 _ReadinessItem({
 required this.id,
 required this.title,
 required this.owner,
 required this.status,
 });

 _ReadinessItem copyWith({String? title, String? owner, String? status}) {
 return _ReadinessItem(
 id: id,
 title: title ?? this.title,
 owner: owner ?? this.owner,
 status: status ?? this.status,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'title': title,
 'owner': owner,
 'status': status,
 };

 static List<_ReadinessItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _ReadinessItem(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 title: map['title']?.toString() ?? '',
 owner: map['owner']?.toString() ?? '',
 status: map['status']?.toString() ?? 'Draft',
 );
 }).toList();
 }
}

class _ChipItem {
 final String id;
 final String label;

 _ChipItem({required this.id, required this.label});

 _ChipItem copyWith({String? label}) =>
 _ChipItem(id: id, label: label ?? this.label);

 Map<String, dynamic> toMap() => {
 'id': id,
 'label': label,
 };

 static List<_ChipItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _ChipItem(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 label: map['label']?.toString() ?? '',
 );
 }).toList();
 }
}

class _BuildComponentRow {
 final String id;
 final String name;
 final String owner;
 final String status;
 final String type;

 const _BuildComponentRow({
 required this.id,
 required this.name,
 required this.owner,
 required this.status,
 required this.type,
 });

 Map<String, dynamic> toMap() => {
 'id': id,
 'name': name,
 'owner': owner,
 'status': status,
 'type': type,
 };

 static List<_BuildComponentRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _BuildComponentRow(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 name: map['name']?.toString() ?? '',
 owner: map['owner']?.toString() ?? '',
 status: map['status']?.toString() ?? 'In Progress',
 type: map['type']?.toString() ?? 'Software',
 );
 }).toList();
 }
}

class _IntegrationRow {
 final String id;
 final String label;
 final String description;
 final String status;

 const _IntegrationRow({
 required this.id,
 required this.label,
 required this.description,
 required this.status,
 });

 Map<String, dynamic> toMap() => {
 'id': id,
 'label': label,
 'description': description,
 'status': status,
 };

 static List<_IntegrationRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _IntegrationRow(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 label: map['label']?.toString() ?? '',
 description: map['description']?.toString() ?? '',
 status: map['status']?.toString() ?? 'Pending',
 );
 }).toList();
 }
}

class _IssueRow {
 final String id;
 final String title;
 final String detail;
 final String severity;

 const _IssueRow({
 required this.id,
 required this.title,
 required this.detail,
 required this.severity,
 });

 Map<String, dynamic> toMap() => {
 'id': id,
 'title': title,
 'detail': detail,
 'severity': severity,
 };

 static List<_IssueRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _IssueRow(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 title: map['title']?.toString() ?? '',
 detail: map['detail']?.toString() ?? '',
 severity: map['severity']?.toString() ?? 'Medium',
 );
 }).toList();
 }
}

class _RiskSignalRow {
 const _RiskSignalRow({
 required this.id,
 required this.signal,
 required this.description,
 required this.severity,
 required this.category,
 required this.owner,
 required this.source,
 required this.status,
 });
 final String id;
 final String signal;
 final String description;
 final String severity;
 final String category;
 final String owner;
 final String source;
 final String status;

 Map<String, dynamic> toMap() => {
 'id': id,
 'signal': signal,
 'description': description,
 'severity': severity,
 'category': category,
 'owner': owner,
 'source': source,
 'status': status,
 };

 static List<_RiskSignalRow> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _RiskSignalRow(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 signal: map['signal']?.toString() ?? '',
 description: map['description']?.toString() ?? '',
 severity: map['severity']?.toString() ?? 'High',
 category: map['category']?.toString() ?? '',
 owner: map['owner']?.toString() ?? '',
 source: map['source']?.toString() ?? 'Manual',
 status: map['status']?.toString() ?? 'Open',
 );
 }).toList();
 }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED UI WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

/// Panel shell wrapper matching the Vendor Tracking page pattern.
class _PanelShell extends StatelessWidget {
 const _PanelShell({
 required this.title,
 required this.subtitle,
 required this.child,
 this.trailing,
 });

 final String title;
 final String subtitle;
 final Widget child;
 final Widget? trailing;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 Stack(
 children: [
 Align(
 alignment: Alignment.topCenter,
 child: Padding(
 padding: EdgeInsets.only(
 left: trailing == null ? 0 : 140,
 right: trailing == null ? 0 : 140,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Text(title,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 16, fontWeight: FontWeight.w700)),
 const SizedBox(height: 4),
 Text(subtitle,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF64748B))),
 ],
 ),
 ),
 ),
 if (trailing != null)
 Align(
 alignment: Alignment.topRight,
 child: trailing!,
 ),
 ],
 ),
 const SizedBox(height: 16),
 child,
 ],
 ),
 );
 }
}

/// Framework guide card for the technical development framework section.
class _FrameworkGuideCard extends StatelessWidget {
 const _FrameworkGuideCard({
 required this.icon,
 required this.title,
 required this.description,
 required this.color,
 });

 final IconData icon;
 final String title;
 final String description;
 final Color color;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: color.withOpacity(0.04),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: color.withOpacity(0.15)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(icon, size: 18, color: color),
 ),
 const SizedBox(height: 12),
 Text(title,
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: color)),
 const SizedBox(height: 6),
 Text(description,
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF6B7280), height: 1.4)),
 ],
 ),
 );
 }
}

class _TechnicalDevelopmentDashboardSnapshot {
 const _TechnicalDevelopmentDashboardSnapshot({
 required this.projectLabel,
 required this.workflowStages,
 required this.buildRegister,
 required this.integrations,
 required this.prototypeItems,
 required this.issueItems,
 required this.qualityStandards,
 required this.guideDocuments,
 required this.releaseChecklist,
 required this.releaseTarget,
 required this.releaseCountdown,
 required this.aiSignalCount,
 });

 final String projectLabel;
 final List<_WorkflowStageItem> workflowStages;
 final List<_BuildRegisterRow> buildRegister;
 final List<_IntegrationItem> integrations;
 final List<_PrototypeCardItem> prototypeItems;
 final List<_IssueItem> issueItems;
 final List<_QualityStandardItem> qualityStandards;
 final List<_GuideDocumentItem> guideDocuments;
 final List<_ReleaseChecklistItem> releaseChecklist;
 final String releaseTarget;
 final String releaseCountdown;
 final int aiSignalCount;

 int get deliveredCount =>
 buildRegister.where((item) => item.status == 'Delivered').length;
 int get connectedCount =>
 integrations.where((item) => item.status == 'Connected').length;
 int get releaseReadyCount => releaseChecklist
 .where((item) => item.status.toLowerCase() == 'ready')
 .length;

 factory _TechnicalDevelopmentDashboardSnapshot.from({
 required ProjectDataModel projectData,
 required Map<String, dynamic>? engineeringContext,
 required Map<String, dynamic>? backendDesignContext,
 required String notes,
 required String approach,
 required List<_ChipItem> standardsChips,
 required List<_WorkstreamItem> workstreams,
 required List<_ReadinessItem> readinessItems,
 }) {
 final projectLabel = projectData.projectName.trim().isNotEmpty
 ? projectData.projectName.trim()
 : 'the current production package';
 final engineeringComponents =
 _mapList(engineeringContext?['components']).take(6).toList();
 final engineeringReadiness =
 _mapList(engineeringContext?['readinessItems']).take(6).toList();
 final backendArchitecture = Map<String, dynamic>.from(
 backendDesignContext?['architecture'] as Map? ?? const {},
 );
 final backendFlows = _mapList(backendArchitecture['dataFlows']);
 final backendDocuments = _mapList(backendArchitecture['documents']);
 final deliverables = projectData.designDeliverablesData.register;
 final pipeline = projectData.designDeliverablesData.pipeline;
 final dependencyHints = projectData.designDeliverablesData.dependencies;

 final workflowStages = <_WorkflowStageItem>[];
 for (final entry in pipeline.take(4).toList().asMap().entries) {
 final item = entry.value;
 final label = 'PHASE ${(entry.key + 1).toString().padLeft(2, '0')}';
 final title =
 item.label.trim().isNotEmpty ? item.label.trim() : 'Build phase';
 final status =
 item.status.trim().isNotEmpty ? item.status.trim() : 'In progress';
 workflowStages.add(
 _WorkflowStageItem(
 label: label,
 title: title,
 note: status,
 progress: _progressForStatus(status),
 ),
 );
 }
 if (workflowStages.isEmpty) {
 for (final entry in workstreams.take(4).toList().asMap().entries) {
 final item = entry.value;
 workflowStages.add(
 _WorkflowStageItem(
 label: 'SPRINT ${(entry.key + 1).toString().padLeft(2, '0')}',
 title: item.title.trim().isNotEmpty
 ? item.title.trim()
 : 'Technical build slice',
 note: item.subtitle.trim().isNotEmpty
 ? item.subtitle.trim()
 : item.status.trim(),
 progress: _progressForStatus(item.status),
 ),
 );
 }
 }
 if (workflowStages.isEmpty) {
 workflowStages.addAll(const [
 _WorkflowStageItem(
 label: 'SPRINT 01',
 title: 'Foundation Build',
 note: 'Auth, environments, and fabrication prep',
 progress: 0.35,
 ),
 _WorkflowStageItem(
 label: 'SPRINT 02',
 title: 'Integration Realization',
 note: 'API handshakes, control systems, and vendor proving',
 progress: 0.58,
 ),
 _WorkflowStageItem(
 label: 'SPRINT 03',
 title: 'Prototype Validation',
 note: 'Mockups, dry-runs, and rework closure',
 progress: 0.72,
 ),
 _WorkflowStageItem(
 label: 'SPRINT 04',
 title: 'Release Readiness',
 note: 'Go-live pack, assembly sequencing, and QA gate',
 progress: 0.82,
 ),
 ]);
 }

 final buildRegister = <_BuildRegisterRow>[];
 for (final deliverable in deliverables.take(4)) {
 final name = deliverable.name.trim();
 if (name.isEmpty) continue;
 buildRegister.add(
 _BuildRegisterRow(
 name: name,
 owner: deliverable.owner.trim().isNotEmpty
 ? deliverable.owner.trim()
 : _ownerFromTeam(projectData.teamMembers, buildRegister.length),
 status: _buildStatusFromText(deliverable.status),
 contextLabel: _contextLabelFor(name, deliverable.risk),
 detail: deliverable.risk.trim().isNotEmpty
 ? deliverable.risk.trim()
 : 'Scheduled build package moving through production controls.',
 ),
 );
 }
 for (final component in engineeringComponents) {
 final name = component['name']?.toString().trim() ?? '';
 if (name.isEmpty ||
 buildRegister
 .any((row) => row.name.toLowerCase() == name.toLowerCase())) {
 continue;
 }
 final detail = component['responsibility']?.toString().trim() ??
 'Engineering detail package in motion.';
 buildRegister.add(
 _BuildRegisterRow(
 name: name,
 owner: _ownerForComponent(
 name,
 projectData.teamMembers,
 engineeringReadiness,
 buildRegister.length,
 ),
 status:
 _buildStatusFromText(component['statusLabel']?.toString() ?? ''),
 contextLabel: _contextLabelFor(name, detail),
 detail:
 detail.isNotEmpty ? detail : 'Component build is being prepared.',
 ),
 );
 if (buildRegister.length >= 6) break;
 }
 for (final item in workstreams) {
 final name = item.title.trim();
 if (name.isEmpty ||
 buildRegister
 .any((row) => row.name.toLowerCase() == name.toLowerCase())) {
 continue;
 }
 buildRegister.add(
 _BuildRegisterRow(
 name: name,
 owner: _ownerFromTeam(projectData.teamMembers, buildRegister.length),
 status: _buildStatusFromText(item.status),
 contextLabel: _contextLabelFor(name, item.subtitle),
 detail: item.subtitle.trim().isNotEmpty
 ? item.subtitle.trim()
 : 'Workstream execution path is being prepared.',
 ),
 );
 if (buildRegister.length >= 6) break;
 }
 if (!buildRegister
 .any((row) => _looksSoftware('${row.name} ${row.detail}'))) {
 buildRegister.insert(
 0,
 const _BuildRegisterRow(
 name: 'Login Module',
 owner: 'Software lead',
 status: 'In Progress',
 contextLabel: 'Software Build',
 detail:
 'Credential flow, API contract wiring, and release guardrails.',
 ),
 );
 }
 if (!buildRegister
 .any((row) => _looksPhysical('${row.name} ${row.detail}'))) {
 buildRegister.add(
 const _BuildRegisterRow(
 name: 'Main Stage',
 owner: 'Production manager',
 status: 'In Production',
 contextLabel: 'Site Fabrication',
 detail: 'Structural framing, decking, and on-site assembly package.',
 ),
 );
 }

 final snapshotIntegrations = <_IntegrationItem>[];
 for (final flow in backendFlows.take(5)) {
 final source = flow['source']?.toString().trim() ?? '';
 final destination = flow['destination']?.toString().trim() ?? '';
 if (source.isEmpty || destination.isEmpty) continue;
 final detail = flow['notes']?.toString().trim();
 snapshotIntegrations.add(
 _IntegrationItem(
 label: '$source to $destination',
 detail: detail != null && detail.isNotEmpty
 ? detail
 : 'Protocol: ${flow['protocol']?.toString().trim().isNotEmpty == true ? flow['protocol'] : 'Manual handoff'}',
 status: _integrationStatusFromText(
 detail ?? flow['protocol']?.toString() ?? '',
 ),
 ),
 );
 }
 for (final hint in dependencyHints.take(4)) {
 final label = hint.trim();
 if (label.isEmpty ||
 snapshotIntegrations.any(
 (item) => item.label.toLowerCase().contains(label.toLowerCase()),
 )) {
 continue;
 }
 snapshotIntegrations.add(
 _IntegrationItem(
 label: label,
 detail: 'Dependency from the deliverables register awaiting proof.',
 status: 'Pending',
 ),
 );
 if (snapshotIntegrations.length >= 4) break;
 }
 if (!snapshotIntegrations
 .any((item) => _looksSoftware('${item.label} ${item.detail}'))) {
 snapshotIntegrations.insert(
 0,
 const _IntegrationItem(
 label: 'API to DB',
 detail: 'Auth and content payloads proving against staging data.',
 status: 'Connected',
 ),
 );
 }
 if (!snapshotIntegrations
 .any((item) => _looksPhysical('${item.label} ${item.detail}'))) {
 snapshotIntegrations.add(
 const _IntegrationItem(
 label: 'Stage to Lighting',
 detail: 'Control trigger and power handoff still being validated.',
 status: 'Pending',
 ),
 );
 }

 final prototypeItems = <_PrototypeCardItem>[
 for (final row in buildRegister.take(4))
 _PrototypeCardItem(
 title: row.name,
 contextLabel: _prototypeContextLabel(row.contextLabel, row.name),
 caption: row.detail,
 outcome: row.status == 'Delivered' ? 'Validated' : 'Needs Rework',
 previewType: _prototypeTypeFor('${row.name} ${row.contextLabel}'),
 ),
 ];

 final issueItems = <_IssueItem>[];
 for (final item in workstreams.where((w) {
 final status = w.status.toLowerCase();
 return status.contains('risk') ||
 status.contains('blocked') ||
 status.contains('depends');
 })) {
 issueItems.add(
 _IssueItem(
 title:
 item.title.trim().isNotEmpty ? item.title.trim() : 'Build issue',
 detail: item.subtitle.trim().isNotEmpty
 ? item.subtitle.trim()
 : 'Active workstream exception requires resolution.',
 severity: item.status.toLowerCase().contains('blocked')
 ? 'Critical'
 : 'Major',
 ),
 );
 if (issueItems.length >= 4) break;
 }
 for (final solutionRisk in projectData.solutionRisks) {
 for (final risk in solutionRisk.risks) {
 final value = risk.trim();
 if (value.isEmpty) continue;
 issueItems.add(
 _IssueItem(
 title: solutionRisk.solutionTitle.trim().isNotEmpty
 ? solutionRisk.solutionTitle.trim()
 : 'Project risk',
 detail: value,
 severity: _severityForText(value),
 ),
 );
 if (issueItems.length >= 4) break;
 }
 if (issueItems.length >= 4) break;
 }
 if (issueItems.isEmpty) {
 issueItems.addAll(const [
 _IssueItem(
 title: 'Code Review Queue',
 detail:
 'Auth and integration branches need final sign-off before merge.',
 severity: 'Major',
 ),
 _IssueItem(
 title: 'Fabrication Tolerance Clash',
 detail:
 'Stage deck edge detailing still conflicts with lighting cable path.',
 severity: 'Critical',
 ),
 ]);
 }

 final qualityStandards = <_QualityStandardItem>[];
 for (final chip in standardsChips.take(5)) {
 final label = chip.label.trim();
 if (label.isEmpty) continue;
 qualityStandards.add(
 _QualityStandardItem(
 label: label,
 status: _qualityStatusFromText(label, notes, approach),
 ),
 );
 }

 final guideDocuments = <_GuideDocumentItem>[];
 for (final document in backendDocuments.take(4)) {
 final title = document['title']?.toString().trim() ?? '';
 if (title.isEmpty) continue;
 guideDocuments.add(
 _GuideDocumentItem(
 name: title,
 specification: document['location']?.toString().trim().isNotEmpty ==
 true
 ? document['location'].toString().trim()
 : (document['description']?.toString().trim().isNotEmpty == true
 ? document['description'].toString().trim()
 : 'Reference pack for production teams.'),
 versionStatus:
 _documentStatusFromText(document['status']?.toString() ?? ''),
 ),
 );
 }

 final releaseChecklist = <_ReleaseChecklistItem>[];
 for (final item in readinessItems.take(5)) {
 final label = item.title.trim();
 if (label.isEmpty) continue;
 releaseChecklist.add(
 _ReleaseChecklistItem(
 label: label,
 status: item.status.trim().isNotEmpty ? item.status.trim() : 'Draft',
 ),
 );
 }

 final milestoneWithDate = projectData.keyMilestones.firstWhere(
 (milestone) => milestone.dueDate.trim().isNotEmpty,
 orElse: () => Milestone(),
 );
 final releaseTarget = milestoneWithDate.dueDate.trim().isNotEmpty
 ? milestoneWithDate.dueDate.trim()
 : projectData.keyMilestones
 .map((item) => item.name.trim())
 .firstWhere((name) => name.isNotEmpty, orElse: () => 'Date TBD');
 final releaseCountdown = _countdownLabelFor(milestoneWithDate.dueDate);

 final aiSignalCount = projectData.aiUsageCounts.values.fold<int>(
 0,
 (total, value) => total + value,
 ) +
 projectData.aiIntegrations.length +
 projectData.aiRecommendations.length;

 return _TechnicalDevelopmentDashboardSnapshot(
 projectLabel: projectLabel,
 workflowStages: workflowStages,
 buildRegister: buildRegister.take(6).toList(),
 integrations: snapshotIntegrations.take(4).toList(),
 prototypeItems: prototypeItems.take(4).toList(),
 issueItems: issueItems.take(4).toList(),
 qualityStandards: qualityStandards.take(5).toList(),
 guideDocuments: guideDocuments.take(4).toList(),
 releaseChecklist: releaseChecklist.take(4).toList(),
 releaseTarget: releaseTarget,
 releaseCountdown: releaseCountdown,
 aiSignalCount: aiSignalCount,
 );
 }
}

// ═══════════════════════════════════════════════════════════════════════════
// SNAPSHOT-INTERNAL DATA MODELS (kept for dashboard read-only metrics)
// ═══════════════════════════════════════════════════════════════════════════

class _WorkflowStageItem {
 const _WorkflowStageItem({
 required this.label,
 required this.title,
 required this.note,
 required this.progress,
 });

 final String label;
 final String title;
 final String note;
 final double progress;

 String get percentLabel => '${(progress * 100).round()}%';
}

class _BuildRegisterRow {
 const _BuildRegisterRow({
 required this.name,
 required this.owner,
 required this.status,
 required this.contextLabel,
 required this.detail,
 });

 final String name;
 final String owner;
 final String status;
 final String contextLabel;
 final String detail;
}

class _IntegrationItem {
 const _IntegrationItem({
 required this.label,
 required this.detail,
 required this.status,
 });

 final String label;
 final String detail;
 final String status;
}

class _PrototypeCardItem {
 const _PrototypeCardItem({
 required this.title,
 required this.contextLabel,
 required this.caption,
 required this.outcome,
 required this.previewType,
 });

 final String title;
 final String contextLabel;
 final String caption;
 final String outcome;
 final _PrototypePreviewType previewType;
}

enum _PrototypePreviewType {
 appScreen,
 wireframe,
 stageMockup,
 siteAssembly,
}

class _IssueItem {
 const _IssueItem({
 required this.title,
 required this.detail,
 required this.severity,
 });

 final String title;
 final String detail;
 final String severity;
}

class _QualityStandardItem {
 const _QualityStandardItem({
 required this.label,
 required this.status,
 });

 final String label;
 final String status;
}

class _GuideDocumentItem {
 const _GuideDocumentItem({
 required this.name,
 required this.specification,
 required this.versionStatus,
 });

 final String name;
 final String specification;
 final String versionStatus;
}

class _ReleaseChecklistItem {
 const _ReleaseChecklistItem({
 required this.label,
 required this.status,
 });

 final String label;
 final String status;
}

// ═══════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS (kept from original for snapshot computation)
// ═══════════════════════════════════════════════════════════════════════════

List<Map<String, dynamic>> _mapList(dynamic data) {
 if (data is! List) return const [];
 return data
 .whereType<Map>()
 .map((item) => Map<String, dynamic>.from(item))
 .toList();
}

bool _looksSoftware(String value) {
 final text = value.toLowerCase();
 return text.contains('api') ||
 text.contains('app') ||
 text.contains('ui') ||
 text.contains('ux') ||
 text.contains('module') ||
 text.contains('screen') ||
 text.contains('auth') ||
 text.contains('code') ||
 text.contains('db') ||
 text.contains('server') ||
 text.contains('endpoint');
}

bool _looksPhysical(String value) {
 final text = value.toLowerCase();
 return text.contains('stage') ||
 text.contains('site') ||
 text.contains('floor') ||
 text.contains('fabrication') ||
 text.contains('lighting') ||
 text.contains('rigging') ||
 text.contains('hall') ||
 text.contains('venue') ||
 text.contains('assembly') ||
 text.contains('truss') ||
 text.contains('hvac');
}

double _progressForStatus(String value) {
 final text = value.toLowerCase();
 if (text.contains('approved') ||
 text.contains('done') ||
 text.contains('ready')) {
 return 0.9;
 }
 if (text.contains('review') || text.contains('production')) return 0.7;
 if (text.contains('staffed') || text.contains('backlog')) return 0.55;
 if (text.contains('depends') || text.contains('planning')) return 0.42;
 if (text.contains('blocked') || text.contains('risk')) return 0.22;
 return 0.38;
}

String _buildStatusFromText(String value) {
 final text = value.toLowerCase();
 if (text.contains('approved') ||
 text.contains('done') ||
 text.contains('delivered') ||
 text.contains('ready') ||
 text.contains('complete') ||
 text.contains('live')) {
 return 'Delivered';
 }
 if (text.contains('review') ||
 text.contains('production') ||
 text.contains('depends') ||
 text.contains('planning') ||
 text.contains('risk')) {
 return 'In Production';
 }
 return 'In Progress';
}

String _integrationStatusFromText(String value) {
 final text = value.toLowerCase();
 if (text.contains('pending') ||
 text.contains('manual') ||
 text.contains('blocked') ||
 text.contains('review')) {
 return 'Pending';
 }
 return 'Connected';
}

String _qualityStatusFromText(String label, String notes, String approach) {
 final combined = '$notes $approach'.toLowerCase();
 final keyword = label.toLowerCase();
 if (combined.contains(keyword.split(' ').first)) return 'Active';
 return label.toLowerCase().contains('safety') ||
 label.toLowerCase().contains('coding')
 ? 'Active'
 : 'Pending';
}

String _documentStatusFromText(String value) {
 final text = value.toLowerCase();
 if (text.contains('approved') || text.contains('live')) return 'Current';
 if (text.contains('review') || text.contains('draft')) return 'Updating';
 return 'Draft';
}

String _contextLabelFor(String name, String detail) {
 final combined = '$name $detail';
 if (_looksPhysical(combined)) return 'Site Fabrication';
 if (_looksSoftware(combined)) return 'Software Build';
 return 'Mixed Build';
}

String _prototypeContextLabel(String current, String name) {
 if (_looksPhysical('$current $name')) return 'Site Assembly';
 if (_looksSoftware('$current $name')) return 'Mobile App';
 return 'Prototype';
}

_PrototypePreviewType _prototypeTypeFor(String value) {
 final text = value.toLowerCase();
 if (text.contains('wire') || text.contains('flow')) {
 return _PrototypePreviewType.wireframe;
 }
 if (_looksPhysical(value) && text.contains('stage')) {
 return _PrototypePreviewType.stageMockup;
 }
 if (_looksPhysical(value)) return _PrototypePreviewType.siteAssembly;
 return _PrototypePreviewType.appScreen;
}

String _ownerFromTeam(List<TeamMember> members, int index) {
 if (members.isEmpty) return 'Owner';
 final member = members[index % members.length];
 if (member.name.trim().isNotEmpty) return member.name.trim();
 if (member.email.trim().isNotEmpty) return member.email.trim();
 if (member.role.trim().isNotEmpty) return member.role.trim();
 return 'Owner';
}

String _ownerForComponent(
 String componentName,
 List<TeamMember> members,
 List<Map<String, dynamic>> readiness,
 int index,
) {
 final lowerName = componentName.toLowerCase();
 for (final item in readiness) {
 final title = item['title']?.toString().toLowerCase() ?? '';
 final owner = item['owner']?.toString().trim() ?? '';
 if (owner.isEmpty) continue;
 final keywords = componentName
 .split(' ')
 .map((part) => part.toLowerCase())
 .where((part) => part.length > 3);
 if (keywords.any(title.contains) || title.contains(lowerName)) {
 return owner;
 }
 }
 return _ownerFromTeam(members, index);
}

String _severityForText(String value) {
 final text = value.toLowerCase();
 if (text.contains('critical') ||
 text.contains('safety') ||
 text.contains('fire') ||
 text.contains('blocked') ||
 text.contains('security')) {
 return 'Critical';
 }
 return 'Major';
}

String _countdownLabelFor(String dueDate) {
 final parsed = _tryParseLooseDate(dueDate.trim());
 if (parsed == null) return 'Countdown unavailable - schedule pending';
 final today = DateTime.now();
 final startOfToday = DateTime(today.year, today.month, today.day);
 final startOfTarget = DateTime(parsed.year, parsed.month, parsed.day);
 final difference = startOfTarget.difference(startOfToday).inDays;
 if (difference > 0) return 'D-$difference to release window';
 if (difference == 0) return 'Release window is today';
 return '${difference.abs()} days past target window';
}

DateTime? _tryParseLooseDate(String value) {
 if (value.isEmpty) return null;
 final direct = DateTime.tryParse(value);
 if (direct != null) return direct;
 final slashMatch = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
 if (slashMatch != null) {
 final day = int.parse(slashMatch.group(1)!);
 final month = int.parse(slashMatch.group(2)!);
 final year = int.parse(slashMatch.group(3)!);
 return DateTime(year, month, day);
 }
 return null;
}

class _Debouncer {
 _Debouncer({Duration? delay})
 : delay = delay ?? const Duration(milliseconds: 700);

 final Duration delay;
 Timer? _timer;

 void run(void Function() action) {
 _timer?.cancel();
 _timer = Timer(delay, action);
 }

 void dispose() {
 _timer?.cancel();
 }
}
