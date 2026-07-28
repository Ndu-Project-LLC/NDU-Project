import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ndu_project/screens/punchlist_actions_screen.dart';
import 'package:ndu_project/screens/scope_completion_screen.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/launch_editable_section.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/app_strings.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
class GapAnalysisScopeReconcillationScreen extends StatefulWidget {
 const GapAnalysisScopeReconcillationScreen({
 super.key,
 this.activeItemLabel = 'Gap Analysis And Scope Reconcillation',
 });

 final String activeItemLabel;

 static void open(BuildContext context,
 {String activeItemLabel = 'Gap Analysis And Scope Reconcillation'}) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => GapAnalysisScopeReconcillationScreen(
 activeItemLabel: activeItemLabel)),
 );
 }

 @override
 State<GapAnalysisScopeReconcillationScreen> createState() =>
 _GapAnalysisScopeReconcillationScreenState();
}

class _GapAnalysisScopeReconcillationScreenState
 extends State<GapAnalysisScopeReconcillationScreen> {
 final List<_GapEntry> _gapEntries = [];
 final List<_RootCauseItem> _rootCauseThemes = [];
 final List<_RootCauseItem> _mitigationConfidence = [];
 final List<_PlanEntry> _reconciliationPlans = [];
 final List<_ImpactRow> _impactRows = [];
 final List<_WorkflowStep> _workflowSteps = [];
 final List<String> _lessonsLearned = [];
 bool _loadedEntries = false;
 bool _aiGenerated = false;
 bool _isGenerating = false;
 final _Debouncer _saveDebouncer = _Debouncer();

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _loadEntries();
 });
 }

 @override
 void dispose() {
 _saveDebouncer.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 20 : 32;

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: InitiationLikeSidebar(
 activeItemLabel: widget.activeItemLabel),
 ),
 Expanded(
 child: Stack(
 children: [
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 28),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const _PageHeader(),
 const SizedBox(height: 20),
 _InfoStrip(isMobile: isMobile),
 const SizedBox(height: 24),
 _PrimarySections(
 gapEntries: _gapEntries,
 rootCauseThemes: _rootCauseThemes,
 mitigationConfidence: _mitigationConfidence,
 reconciliationPlans: _reconciliationPlans,
 onGapEntriesChanged: _updateGapEntries,
 onRootCauseUpdated: _updateRootCauseThemes,
 onMitigationUpdated: _updateMitigationConfidence,
 onPlansUpdated: _updateReconciliationPlans,
 ),
 const SizedBox(height: 24),
 _SecondarySections(
 gapEntries: _gapEntries,
 reconciliationPlans: _reconciliationPlans,
 impacts: _impactRows,
 workflowSteps: _workflowSteps,
 lessons: _lessonsLearned,
 onImpactsUpdated: _updateImpactRows,
 onWorkflowUpdated: (updated) {
 setState(() {
 _workflowSteps
 ..clear()
 ..addAll(updated);
 });
 _schedulePersist();
 },
 onLessonsUpdated: _updateLessonsLearned,
 ),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Scope Completion',
 nextLabel: 'Next: Punchlist Actions',
 onBack: () => ScopeCompletionScreen.open(context),
 onNext: () => PunchlistActionsScreen.open(context),
 ),
 const SizedBox(height: 48),
 ],
 ),
 ),
 const KazAiChatBubble(),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Future<void> _loadEntries() async {
 if (_loadedEntries) return;
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 try {
 var doc = await _executionDocRef(projectId).get();
 if (!doc.exists) {
 // Backward compatibility with older saves that wrote this screen under
 // launch-phase storage.
 doc = await _legacyLaunchDocRef(projectId).get();
 }
 if (doc.exists) {
 final data = doc.data() ?? {};
 final gapEntries = (data['gapRegister'] as List?)
 ?.whereType<Map>()
 .map((e) => _GapEntry.fromJson(Map<String, dynamic>.from(e)))
 .toList() ??
 [];
 final rootCauses = (data['rootCauseThemes'] as List?)
 ?.whereType<Map>()
 .map((e) =>
 _RootCauseItem.fromJson(Map<String, dynamic>.from(e)))
 .toList() ??
 [];
 final mitigation = (data['mitigationConfidence'] as List?)
 ?.whereType<Map>()
 .map((e) =>
 _RootCauseItem.fromJson(Map<String, dynamic>.from(e)))
 .toList() ??
 [];
 final plans = (data['reconciliationPlans'] as List?)
 ?.whereType<Map>()
 .map((e) => _PlanEntry.fromJson(Map<String, dynamic>.from(e)))
 .toList() ??
 [];
 final impacts = (data['impactAssessment'] as List?)
 ?.whereType<Map>()
 .map((e) => _ImpactRow.fromJson(Map<String, dynamic>.from(e)))
 .toList() ??
 [];
 final workflow = (data['reconciliationWorkflow'] as List?)
 ?.whereType<Map>()
 .map(
 (e) => _WorkflowStep.fromJson(Map<String, dynamic>.from(e)))
 .toList() ??
 [];
 final lessons = (data['lessonsLearned'] as List?)
 ?.map((e) => e.toString())
 .where((e) => e.trim().isNotEmpty)
 .toList() ??
 [];
 if (!mounted) return;
 setState(() {
 _gapEntries
 ..clear()
 ..addAll(gapEntries);
 _rootCauseThemes
 ..clear()
 ..addAll(rootCauses);
 _mitigationConfidence
 ..clear()
 ..addAll(mitigation);
 _reconciliationPlans
 ..clear()
 ..addAll(plans);
 _impactRows
 ..clear()
 ..addAll(impacts);
 _workflowSteps
 ..clear()
 ..addAll(workflow);
 _lessonsLearned
 ..clear()
 ..addAll(lessons);
 });
 }
 _loadedEntries = true;
 if (_gapEntries.isEmpty &&
 _rootCauseThemes.isEmpty &&
 _mitigationConfidence.isEmpty &&
 _reconciliationPlans.isEmpty &&
 _impactRows.isEmpty &&
 _workflowSteps.isEmpty &&
 _lessonsLearned.isEmpty) {
 await _populateFromAi();
 }
 } catch (error) {
 debugPrint('Failed to load gap analysis entries: $error');
 }
 }

 Future<void> _populateFromAi() async {
 if (_aiGenerated || _isGenerating) return;
 setState(() => _isGenerating = true);
 Map<String, List<LaunchEntry>> generated = {};
 try {
 generated = await ExecutionPhaseAiSeed.generateEntries(
 context: context,
 section: 'Gap Analysis & Scope Reconciliation',
 sections: const {
 'gap_register': 'Gap register items with owner and next step',
 'root_causes': 'Root cause themes driving the gaps',
 'mitigation_confidence': 'Mitigation confidence insights',
 'reconciliation_plans': 'Reconciliation plans with due dates',
 'impact_assessment': 'Impact assessment results',
 'reconciliation_workflow': 'Reconciliation workflow & backlog',
 'lessons_learned': 'Lessons learned & prevention',
 },
 itemsPerSection: 3,
 );
 } catch (error) {
 debugPrint('Gap analysis AI call failed: $error');
 }

 if (!mounted) return;
 if (_gapEntries.isNotEmpty ||
 _rootCauseThemes.isNotEmpty ||
 _mitigationConfidence.isNotEmpty ||
 _reconciliationPlans.isNotEmpty ||
 _impactRows.isNotEmpty ||
 _workflowSteps.isNotEmpty ||
 _lessonsLearned.isNotEmpty) {
 setState(() => _isGenerating = false);
 _aiGenerated = true;
 return;
 }

 setState(() {
 _gapEntries
 ..clear()
 ..addAll(_mapGapEntries(generated['gap_register']));
 _rootCauseThemes
 ..clear()
 ..addAll(_mapRootCauseItems(generated['root_causes']));
 _mitigationConfidence
 ..clear()
 ..addAll(_mapRootCauseItems(generated['mitigation_confidence']));
 _reconciliationPlans
 ..clear()
 ..addAll(_mapPlanEntries(generated['reconciliation_plans']));
 _impactRows
 ..clear()
 ..addAll(_mapImpactRows(generated['impact_assessment']));
 _workflowSteps
 ..clear()
 ..addAll(_mapWorkflowSteps(generated['reconciliation_workflow']));
 _lessonsLearned
 ..clear()
 ..addAll(_mapLessons(generated['lessons_learned']));
 _isGenerating = false;
 });
 _aiGenerated = true;
 await _persistEntries();
 }

 String _extractField(String text, String key) {
 final match = RegExp('$key\\s*[:=-]\\s*([^|;\\n]+)',
 caseSensitive: false)
 .firstMatch(text);
 return match?.group(1)?.trim() ?? '';
 }

 List<_GapEntry> _mapGapEntries(List<LaunchEntry>? raw) {
 if (raw == null) return [];
 return raw
 .map((entry) {
 final details = entry.details;
 final owner = _extractField(details, 'Owner');
 final nextStep = _extractField(details, 'Next');
 return _GapEntry(
 uid: DateTime.now().microsecondsSinceEpoch.toString(),
 id: entry.title.trim().isEmpty ? 'GAP' : entry.title.trim(),
 title: entry.title.trim(),
 stage: entry.status?.trim().isNotEmpty == true
 ? entry.status!.trim()
 : 'Moderate',
 owner: owner,
 nextStep: nextStep.isNotEmpty
 ? nextStep
 : entry.details.trim().isNotEmpty
 ? entry.details.trim()
 : 'Define next step',
 );
 })
 .where((entry) => entry.title.isNotEmpty)
 .toList();
 }

 List<_RootCauseItem> _mapRootCauseItems(List<LaunchEntry>? raw) {
 if (raw == null) return [];
 return raw
 .map((entry) => _RootCauseItem(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 text: entry.title.trim().isNotEmpty
 ? entry.title.trim()
 : entry.details.trim(),
 ))
 .where((item) => item.text.isNotEmpty)
 .toList();
 }

 List<_PlanEntry> _mapPlanEntries(List<LaunchEntry>? raw) {
 if (raw == null) return [];
 return raw
 .map((entry) {
 final details = entry.details;
 final owner = _extractField(details, 'Owner');
 final due = _extractField(details, 'Due');
 return _PlanEntry(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 title: entry.title.trim(),
 due: due.isNotEmpty ? due : entry.status?.trim() ?? '',
 owner: owner,
 status: entry.status?.trim().isNotEmpty == true
 ? entry.status!.trim()
 : 'On track',
 );
 })
 .where((plan) => plan.title.isNotEmpty)
 .toList();
 }

 List<_ImpactRow> _mapImpactRows(List<LaunchEntry>? raw) {
 if (raw == null) return [];
 return raw
 .map((entry) => _ImpactRow.fromLaunchEntry({
 'title': entry.title,
 'details': entry.details,
 'status': entry.status ?? '',
 }))
 .where((row) => row.area.isNotEmpty)
 .toList();
 }

 List<_WorkflowStep> _mapWorkflowSteps(List<LaunchEntry>? raw) {
 if (raw == null) return [];
 return raw
 .map((entry) => _WorkflowStep.fromLaunchEntry({
 'title': entry.title,
 'details': entry.details,
 'status': entry.status ?? '',
 }))
 .where((step) => step.label.isNotEmpty)
 .toList();
 }

 List<String> _mapLessons(List<LaunchEntry>? raw) {
 if (raw == null) return [];
 return raw
 .map((entry) => entry.title.trim().isNotEmpty
 ? entry.title.trim()
 : entry.details.trim())
 .where((text) => text.isNotEmpty)
 .toList();
 }

 Future<void> _persistEntries() async {
 final provider = ProjectDataHelper.getProvider(context);
 final projectId = provider.projectData.projectId;
 if (projectId == null || projectId.isEmpty) return;

 final payload = {
 'gapRegister': _gapEntries.map((e) => e.toJson()).toList(),
 'rootCauseThemes': _rootCauseThemes.map((e) => e.toJson()).toList(),
 'mitigationConfidence':
 _mitigationConfidence.map((e) => e.toJson()).toList(),
 'reconciliationPlans':
 _reconciliationPlans.map((e) => e.toJson()).toList(),
 'impactAssessment': _impactRows.map((e) => e.toJson()).toList(),
 'reconciliationWorkflow': _workflowSteps.map((e) => e.toJson()).toList(),
 'lessonsLearned': _lessonsLearned,
 'updatedAt': FieldValue.serverTimestamp(),
 };

 await _executionDocRef(projectId).set(payload, SetOptions(merge: true));
 }

 DocumentReference<Map<String, dynamic>> _executionDocRef(String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('execution_phase_entries')
 .doc('gap_analysis_scope_reconciliation');
 }

 DocumentReference<Map<String, dynamic>> _legacyLaunchDocRef(
 String projectId) {
 return FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('launch_phase')
 .doc('gap_analysis_scope_reconciliation');
 }

 void _schedulePersist() {
 _saveDebouncer.run(_persistEntries);
 }

 void _updateGapEntries(List<_GapEntry> updated) {
 setState(() {
 _gapEntries
 ..clear()
 ..addAll(updated);
 });
 _schedulePersist();
 }

 void _updateRootCauseThemes(List<_RootCauseItem> updated) {
 setState(() {
 _rootCauseThemes
 ..clear()
 ..addAll(updated);
 });
 _schedulePersist();
 }

 void _updateMitigationConfidence(List<_RootCauseItem> updated) {
 setState(() {
 _mitigationConfidence
 ..clear()
 ..addAll(updated);
 });
 _schedulePersist();
 }

 void _updateReconciliationPlans(List<_PlanEntry> updated) {
 setState(() {
 _reconciliationPlans
 ..clear()
 ..addAll(updated);
 });
 _schedulePersist();
 }

 void _updateImpactRows(List<_ImpactRow> updated) {
 setState(() {
 _impactRows
 ..clear()
 ..addAll(updated);
 });
 _schedulePersist();
 }

 void _updateLessonsLearned(List<String> updated) {
 setState(() {
 _lessonsLearned
 ..clear()
 ..addAll(updated);
 });
 _schedulePersist();
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Gap Analysis & Scope Reconciliation',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_gap_analysis_scope_reconcillation_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _PageHeader extends StatelessWidget {
 const _PageHeader();

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text(
 'Gap Analysis & Scope Reconciliation',
 style: TextStyle(
 fontSize: 30,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 SizedBox(height: 8),
 Text(
 'Assess active scope gaps, align remediation plans, and ensure stakeholders stay synchronized before handover.',
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280)),
 ),
 ],
 );
 }
}

class _InfoStrip extends StatelessWidget {
 const _InfoStrip({required this.isMobile});

 final bool isMobile;

 /// Maps a [currentCheckpoint] string to a human-readable delivery stage.
 static String _resolveDeliveryStage(String checkpoint) {
 final token = checkpoint.toLowerCase();
 if (token.isEmpty) return 'Initiation';
 if (token.startsWith('fep_')) return 'Front End Planning';
 if (token.contains('launch') || token.contains('go_live')) return 'Launch';
 if (token.contains('execution') ||
 token.contains('progress_tracking') ||
 token.contains('vendor_tracking') ||
 token.contains('contracts_tracking')) {
 return 'Execution';
 }
 if (token.startsWith('design_') || token == 'design') return 'Design';
 if (token.contains('close_out') ||
 token.contains('closure') ||
 token.contains('finalize')) {
 return 'Close-out';
 }
 if (token.contains('project_') ||
 token.contains('schedule') ||
 token.contains('wbs') ||
 token.contains('scope_tracking') ||
 token.contains('cost_estimate')) {
 return 'Planning';
 }
 if (token.contains('business_case') ||
 token.contains('potential_solutions') ||
 token.contains('preferred_solution') ||
 token.contains('charter')) {
 return 'Initiation';
 }
 if (token.contains('planning') || token.contains('procurement')) {
 return 'Planning';
 }
 return 'Initiation';
 }

 /// Resolves the project track from [overallFramework].
 static String _resolveTrack(String? overallFramework) {
 if (overallFramework == null || overallFramework.isEmpty) {
 return 'Project delivery & execution';
 }
 final fw = overallFramework.toLowerCase();
 if (fw.contains('agile')) return 'Agile delivery';
 if (fw.contains('waterfall')) return 'Waterfall delivery';
 if (fw.contains('hybrid')) return 'Hybrid delivery';
 return overallFramework;
 }

 @override
 Widget build(BuildContext context) {
 final provider = ProjectDataInherited.maybeOf(context);
 final projectData = provider?.projectData;

 final projectName =
 projectData?.projectName.isNotEmpty == true
 ? projectData!.projectName
 : AppStrings.appName;
 final track = _resolveTrack(projectData?.overallFramework);
 final deliveryStage = _resolveDeliveryStage(
 projectData?.currentCheckpoint ?? 'initiation');

 final lastUpdated = projectData?.updatedAt;
 final cadenceValue = lastUpdated != null
 ? 'Last updated ${_formatRelative(lastUpdated)}'
 : 'Real-time sync';

 final chips = [
 _InfoChipData(label: 'Project', value: projectName),
 _InfoChipData(label: 'Track', value: track),
 _InfoChipData(label: 'Delivery stage', value: deliveryStage),
 _InfoChipData(label: 'Sync status', value: cadenceValue),
 ];

 return Wrap(
 spacing: 12,
 runSpacing: 12,
 alignment: WrapAlignment.start,
 children: chips
 .map((chip) => _InfoChip(
 data: chip,
 isCompact: isMobile,
 ))
 .toList(),
 );
 }

 /// Formats a [DateTime] as a relative time string.
 static String _formatRelative(DateTime dt) {
 final now = DateTime.now();
 final diff = now.difference(dt);
 if (diff.inMinutes < 1) return 'just now';
 if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
 if (diff.inHours < 24) return '${diff.inHours}h ago';
 if (diff.inDays < 7) return '${diff.inDays}d ago';
 return '${dt.day} ${_monthAbbr(dt.month)} ${dt.year}';
 }

 static String _monthAbbr(int m) => const [
 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
 ][m - 1];
}


// ignore: unused_element
class _SummaryGrid extends StatelessWidget {
 const _SummaryGrid();

 static const _SummaryCardData _healthCard = _SummaryCardData(
 title: 'Overall reconciliation health',
 headline: '82% aligned',
 annotation: 'Remaining gaps: 3 critical · 4 moderate',
 accentColor: Color(0xFF2563EB),
 icon: Icons.insights_outlined,
 bullets: [
 'Material gaps tracked across design, ops, and adoption streams',
 'Integration hand-offs validated for 4 of 5 impacted squads',
 ],
 progress: 0.82,
 );

 static const _SummaryCardData _gapsCard = _SummaryCardData(
 title: 'Gaps',
 headline: '12 active',
 annotation: '5 closed this sprint · 2 newly logged',
 accentColor: Color(0xFF0891B2),
 icon: Icons.warning_amber_outlined,
 bullets: [
 'Critical: Prod-ready data sync · Release deployment',
 'Moderate: Support playbooks · API throttling policy',
 ],
 );

 static const _SummaryCardData _scopeCard = _SummaryCardData(
 title: 'Scope',
 headline: '3 packages in review',
 annotation: 'Procurement lead-time risk easing',
 accentColor: Color(0xFF7C3AED),
 icon: Icons.layers_outlined,
 bullets: [
 'MVP scope freeze by 18 Dec · Consumer onboarding locked',
 'Ops enablement kit staged for final sign-off',
 ],
 );

 static const _SummaryCardData _impactCard = _SummaryCardData(
 title: 'Impacts',
 headline: 'High impact areas',
 annotation: 'Primary: Deployment timeline · Secondary: Support load',
 accentColor: Color(0xFFEA580C),
 icon: Icons.auto_graph_outlined,
 bullets: [
 'Schedule: -4 days variance absorbed with overtime budget',
 'Cost: +3.2% attributed to additional QA automation',
 ],
 );

 static const _SummaryCardData _stakeholderCard = _SummaryCardData(
 title: 'Stakeholder alignment',
 headline: 'Managers synced',
 annotation: 'Last exec review: Mon, 2:00 PM',
 accentColor: Color(0xFF059669),
 icon: Icons.groups_outlined,
 bullets: [
 'Adoption: GTM + Customer success validated mitigation path',
 'Ops: Support + Reliability sign-off scheduled for Friday',
 ],
 );

 static const cards = [
 _healthCard,
 _gapsCard,
 _scopeCard,
 _impactCard,
 _stakeholderCard
 ];

 @override
 Widget build(BuildContext context) {
 return LayoutBuilder(
 builder: (context, constraints) {
 final maxWidth = constraints.maxWidth;
 double targetWidth;

 if (maxWidth >= 1100) {
 targetWidth = (maxWidth - 40) / 3;
 } else if (maxWidth >= 760) {
 targetWidth = (maxWidth - 20) / 2;
 } else {
 targetWidth = maxWidth;
 }

 final childWidth =
 maxWidth < 260 ? maxWidth : targetWidth.clamp(260.0, maxWidth);

 return Wrap(
 spacing: 20,
 runSpacing: 20,
 children: cards
 .map(
 (card) => _SummaryCard(
 data: card,
 width: childWidth,
 ),
 )
 .toList(),
 );
 },
 );
 }
}

class _SummaryCard extends StatelessWidget {
 const _SummaryCard({required this.data, required this.width});

 final _SummaryCardData data;
 final double width;

 @override
 Widget build(BuildContext context) {
 final cardContent = Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 40,
 height: 40,
 decoration: BoxDecoration(
 color: data.accentColor.withOpacity(0.12),
 borderRadius: BorderRadius.circular(12)),
 child: Icon(data.icon, color: data.accentColor, size: 22),
 ),
 const Spacer(),
 if (data.progress != null)
 SizedBox(
 width: 48,
 height: 48,
 child: Stack(
 fit: StackFit.expand,
 children: [
 CircularProgressIndicator(
 value: data.progress,
 strokeWidth: 5,
 backgroundColor: const Color(0xFFE5E7EB),
 valueColor:
 AlwaysStoppedAnimation<Color>(data.accentColor),
 ),
 Center(
 child: Text(
 '${(data.progress! * 100).round()}%',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 Text(
 data.title,
 style: const TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 const SizedBox(height: 10),
 Text(
 data.headline,
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: data.accentColor),
 ),
 const SizedBox(height: 6),
 Text(
 data.annotation,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 14),
 ...data.bullets.map(
 (bullet) => Padding(
 padding: const EdgeInsets.only(bottom: 8),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Padding(
 padding: EdgeInsets.only(top: 6),
 child: Icon(Icons.circle, size: 6, color: Color(0xFF9CA3AF)),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 bullet,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF4B5563)),
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 );

 return Container(
 constraints: BoxConstraints(minWidth: width),
 width: width,
 padding: const EdgeInsets.all(22),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.05),
 blurRadius: 18,
 offset: const Offset(0, 14)),
 ],
 ),
 child: cardContent,
 );
 }
}

class _PrimarySections extends StatelessWidget {
 const _PrimarySections({
 required this.gapEntries,
 required this.rootCauseThemes,
 required this.mitigationConfidence,
 required this.reconciliationPlans,
 required this.onGapEntriesChanged,
 required this.onRootCauseUpdated,
 required this.onMitigationUpdated,
 required this.onPlansUpdated,
 });

 final List<_GapEntry> gapEntries;
 final List<_RootCauseItem> rootCauseThemes;
 final List<_RootCauseItem> mitigationConfidence;
 final List<_PlanEntry> reconciliationPlans;
 final ValueChanged<List<_GapEntry>> onGapEntriesChanged;
 final ValueChanged<List<_RootCauseItem>> onRootCauseUpdated;
 final ValueChanged<List<_RootCauseItem>> onMitigationUpdated;
 final ValueChanged<List<_PlanEntry>> onPlansUpdated;

 @override
 Widget build(BuildContext context) {
 return LayoutBuilder(
 builder: (context, constraints) {
 final sectionWidth = constraints.maxWidth;

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _GapRegisterCard(
 width: sectionWidth,
 entries: gapEntries,
 onChanged: onGapEntriesChanged,
 ),
 const SizedBox(height: 20),
 _GapAnalysisRootCauseCard(
 width: sectionWidth,
 rootCauseThemes: rootCauseThemes,
 mitigationConfidence: mitigationConfidence,
 onRootCauseUpdated: onRootCauseUpdated,
 onMitigationUpdated: onMitigationUpdated,
 ),
 const SizedBox(height: 20),
 _ReconciliationPlanningCard(
 width: sectionWidth,
 plans: reconciliationPlans,
 onPlansUpdated: onPlansUpdated,
 ),
 ],
 );
 },
 );
 }
}

class _SecondarySections extends StatelessWidget {
 const _SecondarySections({
 required this.gapEntries,
 required this.reconciliationPlans,
 required this.impacts,
 required this.workflowSteps,
 required this.lessons,
 required this.onImpactsUpdated,
 required this.onWorkflowUpdated,
 required this.onLessonsUpdated,
 });

 final List<_GapEntry> gapEntries;
 final List<_PlanEntry> reconciliationPlans;
 final List<_ImpactRow> impacts;
 final List<_WorkflowStep> workflowSteps;
 final List<String> lessons;
 final ValueChanged<List<_ImpactRow>> onImpactsUpdated;
 final ValueChanged<List<_WorkflowStep>> onWorkflowUpdated;
 final ValueChanged<List<String>> onLessonsUpdated;

 @override
 Widget build(BuildContext context) {
 return LayoutBuilder(
 builder: (context, constraints) {
 final sectionWidth = constraints.maxWidth;

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _ImpactAssessmentCard(
 width: sectionWidth,
 impacts: impacts,
 onImpactsUpdated: onImpactsUpdated,
 gaps: gapEntries,
 plans: reconciliationPlans,
 ),
 const SizedBox(height: 20),
 _ReconciliationWorkflowCard(
 width: sectionWidth,
 steps: workflowSteps,
 onWorkflowUpdated: onWorkflowUpdated,
 ),
 const SizedBox(height: 20),
 _LessonsLearnedCard(
 width: sectionWidth,
 lessons: lessons,
 onLessonsUpdated: onLessonsUpdated,
 ),
 ],
 );
 },
 );
 }
}

class _GapRegisterCard extends StatelessWidget {
 const _GapRegisterCard({
 required this.width,
 required this.entries,
 required this.onChanged,
 });

 final double width;
 final List<_GapEntry> entries;
 final ValueChanged<List<_GapEntry>> onChanged;

 static const List<String> _priorityOptions = [
 'Critical',
 'Moderate',
 'Low',
 'Resolved',
 ];

 static const List<String> _categoryOptions = [
 'Scope',
 'Schedule',
 'Cost',
 'Quality',
 'Compliance',
 'Resource',
 'Technical',
 'Process',
 ];

 static const List<String> _severityOptions = [
 'Critical',
 'High',
 'Medium',
 'Low',
 ];

 @override
 Widget build(BuildContext context) {
 final counts = <String, int>{
 for (final option in _priorityOptions) option: 0
 };
 for (final entry in entries) {
 final key = _priorityOptions.firstWhere(
 (option) => option.toLowerCase() == entry.stage.toLowerCase(),
 orElse: () => 'Moderate',
 );
 counts[key] = (counts[key] ?? 0) + 1;
 }

 return _SectionShell(
 width: width,
 title: 'Gap register & catalog',
 subtitle:
 'Comprehensive gap register aligned with PMI PMBOK Control Scope (5.6) and '
 'FIDIC variation management conventions. Track each scope discrepancy by '
 'category, severity, root cause, owner, and remediation status.',
 trailing: TextButton.icon(
 onPressed: () => _showGapEntryEditor(context),
 icon: const Icon(Icons.add_circle_outline),
 label: const Text('Log new gap'),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 _Pill(
 label: 'Critical · ${counts['Critical'] ?? 0}',
 color: const Color(0xFFDC2626)),
 _Pill(
 label: 'Moderate · ${counts['Moderate'] ?? 0}',
 color: const Color(0xFFF97316)),
 _Pill(
 label: 'Low · ${counts['Low'] ?? 0}',
 color: const Color(0xFF059669)),
 _Pill(
 label: 'Resolved · ${counts['Resolved'] ?? 0}',
 color: const Color(0xFF2563EB)),
 ],
 ),
 const SizedBox(height: 18),
 if (entries.isEmpty)
 const _EmptyPanel(label: 'No gaps logged yet.')
 else
 LayoutBuilder(
 builder: (context, constraints) {
 final tableWidth =
 constraints.maxWidth < 1080 ? 1080.0 : constraints.maxWidth;
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: tableWidth,
 child: Container(
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 decoration: const BoxDecoration(
 color: Color(0xFFF9FAFB),
 borderRadius: BorderRadius.vertical(
 top: Radius.circular(16)),
 ),
 child: const Row(
 children: [
 SizedBox(width: 20),
 Expanded(
 flex: 4,
 child: Text('GAP DESCRIPTION',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8))),
 SizedBox(
 width: 120,
 child: Text('CATEGORY',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 120,
 child: Text('SEVERITY',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 120,
 child: Text('PRIORITY',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 130,
 child: Text('OWNER',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 120,
 child: Text('TARGET',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 60,
 child: Text('',
 style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 ..._sortedEntries.map((entry) {
 final isLast =
 entry == _sortedEntries.last;
 return _GapEntryRow(
 entry: entry,
 onEdit: () =>
 _showGapEntryEditor(context, existing: entry),
 onDelete: () => _confirmDeleteEntry(context, entry),
 showDivider: !isLast,
 );
 }),
 ],
 ),
 ),
 ),
 );
 },
 ),
 ],
 ),
 );
 }

 List<_GapEntry> get _sortedEntries {
 const priorityOrder = {'Critical': 0, 'Moderate': 1, 'Low': 2, 'Resolved': 3};
 final sorted = List<_GapEntry>.from(entries);
 sorted.sort((a, b) =>
 (priorityOrder[a.stage] ?? 99).compareTo(priorityOrder[b.stage] ?? 99));
 return sorted;
 }

 void _showGapEntryEditor(BuildContext context, {_GapEntry? existing}) {
 final isEdit = existing != null;
 final idController =
 TextEditingController(text: existing?.id ?? 'GAP-${DateTime.now().millisecondsSinceEpoch % 10000}');
 final titleController =
 TextEditingController(text: existing?.title ?? '');
 final ownerController =
 TextEditingController(text: existing?.owner ?? '');
 final nextStepController =
 TextEditingController(text: existing?.nextStep ?? '');
 final impactAreaController =
 TextEditingController(text: existing?.impactArea ?? '');
 final targetDateController =
 TextEditingController(text: existing?.targetDate ?? '');
 final evidenceController =
 TextEditingController(text: existing?.evidence ?? '');
 String selectedStage = existing?.stage ?? 'Moderate';
 String selectedCategory = existing?.category ?? 'Scope';
 String selectedSeverity = existing?.severity ?? 'Medium';

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDialogState) => AlertDialog(
 title: Text(isEdit ? 'Edit Gap Entry' : 'Log New Gap'),
 content: SingleChildScrollView(
 child: SizedBox(
 width: 480,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: idController,
 decoration: const InputDecoration(
 labelText: 'Gap ID *',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: titleController,
 decoration: const InputDecoration(
 labelText: 'Gap description *',
 isDense: true,
 ),
 maxLines: 2,
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: selectedCategory,
 decoration: const InputDecoration(
 labelText: 'Category *',
 isDense: true,
 ),
 items: _categoryOptions
 .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) {
 if (v != null) setDialogState(() => selectedCategory = v);
 },
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 value: selectedSeverity,
 decoration: const InputDecoration(
 labelText: 'Severity *',
 isDense: true,
 ),
 items: _severityOptions
 .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) {
 if (v != null) setDialogState(() => selectedSeverity = v);
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: _priorityOptions.contains(selectedStage)
 ? selectedStage
 : _priorityOptions.first,
 decoration: const InputDecoration(
 labelText: 'Priority *',
 isDense: true,
 ),
 items: _priorityOptions
 .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) {
 if (v != null) setDialogState(() => selectedStage = v);
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: ownerController,
 decoration: const InputDecoration(
 labelText: 'Owner *',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: targetDateController,
 decoration: const InputDecoration(
 labelText: 'Target closure date',
 hintText: 'e.g., 2025-08-15',
 isDense: true,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: nextStepController,
 decoration: const InputDecoration(
 labelText: 'Remediation / next step *',
 isDense: true,
 ),
 maxLines: 2,
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: impactAreaController,
 decoration: const InputDecoration(
 labelText: 'Impact area',
 hintText: 'e.g., Milestone 3 delivery',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: evidenceController,
 decoration: const InputDecoration(
 labelText: 'Evidence / reference',
 hintText: 'e.g., Audit finding AF-2024-017',
 isDense: true,
 ),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 if (titleController.text.trim().isEmpty) return;
 final entry = _GapEntry(
 uid: existing?.uid ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 id: idController.text.trim(),
 title: titleController.text.trim(),
 stage: selectedStage,
 owner: ownerController.text.trim(),
 nextStep: nextStepController.text.trim(),
 category: selectedCategory,
 severity: selectedSeverity,
 impactArea: impactAreaController.text.trim(),
 targetDate: targetDateController.text.trim(),
 evidence: evidenceController.text.trim(),
 );
 final updated = isEdit
 ? [for (final e in entries) e.uid == entry.uid ? entry : e]
 : [...entries, entry];
 onChanged(updated);
 Navigator.pop(ctx);
 },
 child: Text(isEdit ? 'Update' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 void _confirmDeleteEntry(BuildContext context, _GapEntry entry) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete Gap Entry'),
 content: Text(
 'Remove "${entry.title.isNotEmpty ? entry.title : entry.id}" from the gap register?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 onChanged(entries.where((e) => e.uid != entry.uid).toList());
 Navigator.pop(ctx);
 },
 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
 child: const Text('Delete', style: TextStyle(color: Colors.white)),
 ),
 ],
 ),
 );
 }
}

class _GapAnalysisRootCauseCard extends StatelessWidget {
 const _GapAnalysisRootCauseCard({
 required this.width,
 required this.rootCauseThemes,
 required this.mitigationConfidence,
 required this.onRootCauseUpdated,
 required this.onMitigationUpdated,
 });

 final double width;
 final List<_RootCauseItem> rootCauseThemes;
 final List<_RootCauseItem> mitigationConfidence;
 final ValueChanged<List<_RootCauseItem>> onRootCauseUpdated;
 final ValueChanged<List<_RootCauseItem>> onMitigationUpdated;

 static const List<String> _categoryOptions = [
 'Process',
 'People',
 'Technology',
 'Requirements',
 'Governance',
 'External',
 'Design',
 'Communication',
 ];

 static const List<String> _methodologyOptions = [
 '5 Whys',
 'Fishbone (Ishikawa)',
 'Pareto Analysis',
 'Fault Tree',
 'Root Cause Matrix',
 'Gap-Effect Diagram',
 ];

 static const List<String> _impactOptions = [
 'Critical',
 'High',
 'Medium',
 'Low',
 ];

 static const List<String> _statusOptions = [
 'Open',
 'Under Investigation',
 'Remediation In Progress',
 'Verified Closed',
 'Accepted Risk',
 ];

 @override
 Widget build(BuildContext context) {
 return _SectionShell(
 width: width,
 title: 'Gap analysis & root cause',
 subtitle: 'Root cause identification aligned with PMI PMBOK Quality '
 'Management (8.2) and PRINCE2 Issue and Risk evaluation. Uses '
 'structured methodologies (5 Whys, Ishikawa, Pareto) to trace '
 'each scope discrepancy to its systemic source.',
 trailing: TextButton.icon(
 onPressed: () => _showRootCauseEditor(context),
 icon: const Icon(Icons.playlist_add_check_circle_outlined),
 label: const Text('Log root cause'),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Root cause themes',
 style: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
 ),
 const SizedBox(height: 12),
 if (rootCauseThemes.isEmpty)
 const _EmptyPanel(label: 'No root cause themes identified yet.')
 else
 LayoutBuilder(
 builder: (context, constraints) {
 final tableWidth =
 constraints.maxWidth < 1080 ? 1080.0 : constraints.maxWidth;
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: tableWidth,
 child: Container(
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 decoration: const BoxDecoration(
 color: Color(0xFFF9FAFB),
 borderRadius: BorderRadius.vertical(
 top: Radius.circular(16)),
 ),
 child: const Row(
 children: [
 SizedBox(width: 20),
 Expanded(
 flex: 4,
 child: Text('ROOT CAUSE',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8))),
 SizedBox(
 width: 130,
 child: Text('CATEGORY',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 130,
 child: Text('METHOD',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 130,
 child: Text('IMPACT',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 130,
 child: Text('STATUS',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 60,
 child: Text('',
 style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 ...rootCauseThemes.map((item) {
 final isLast = item == rootCauseThemes.last;
 return _RootCauseRow(
 item: item,
 onEdit: () =>
 _showRootCauseEditor(context, existing: item),
 onDelete: () =>
 _confirmDeleteRootCause(context, item),
 showDivider: !isLast,
 );
 }),
 ],
 ),
 ),
 ),
 );
 },
 ),
 const SizedBox(height: 24),
 Text(
 'Mitigation confidence',
 style: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
 ),
 const SizedBox(height: 12),
 if (mitigationConfidence.isEmpty)
 const _EmptyPanel(
 label: 'No mitigation confidence entries yet.')
 else
 LayoutBuilder(
 builder: (context, constraints) {
 final tableWidth =
 constraints.maxWidth < 1080 ? 1080.0 : constraints.maxWidth;
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: tableWidth,
 child: Container(
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 decoration: const BoxDecoration(
 color: Color(0xFFF9FAFB),
 borderRadius: BorderRadius.vertical(
 top: Radius.circular(16)),
 ),
 child: const Row(
 children: [
 SizedBox(width: 20),
 Expanded(
 flex: 5,
 child: Text('MITIGATION ACTION',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8))),
 SizedBox(
 width: 130,
 child: Text('IMPACT',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 130,
 child: Text('STATUS',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 60,
 child: Text('',
 style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 ...mitigationConfidence.map((item) {
 final isLast = item == mitigationConfidence.last;
 return _RootCauseRow(
 item: item,
 onEdit: () => _showMitigationEditor(
 context, existing: item),
 onDelete: () =>
 _confirmDeleteMitigation(context, item),
 showDivider: !isLast,
 );
 }),
 ],
 ),
 ),
 ),
 );
 },
 ),
 ],
 ),
 );
 }

 void _showRootCauseEditor(BuildContext context, {_RootCauseItem? existing}) {
 _showInsightEditor(
 context,
 existing: existing,
 items: rootCauseThemes,
 onSaved: onRootCauseUpdated,
 title: existing != null ? 'Edit Root Cause' : 'Log Root Cause',
 );
 }

 void _showMitigationEditor(BuildContext context,
 {_RootCauseItem? existing}) {
 _showInsightEditor(
 context,
 existing: existing,
 items: mitigationConfidence,
 onSaved: onMitigationUpdated,
 title: existing != null ? 'Edit Mitigation' : 'Add Mitigation Action',
 );
 }

 void _showInsightEditor(
 BuildContext context, {
 required List<_RootCauseItem> items,
 required ValueChanged<List<_RootCauseItem>> onSaved,
 required String title,
 _RootCauseItem? existing,
 }) {
 final isEdit = existing != null;
 final textController =
 TextEditingController(text: existing?.text ?? '');
 final freqController =
 TextEditingController(text: existing?.frequency ?? '');
 final recController =
 TextEditingController(text: existing?.recommendation ?? '');
 String selectedCategory = existing?.category ?? 'Process';
 String selectedMethod = existing?.methodology ?? '5 Whys';
 String selectedImpact = existing?.impact ?? 'Medium';
 String selectedStatus = existing?.status ?? 'Open';

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDialogState) => AlertDialog(
 title: Text(title),
 content: SingleChildScrollView(
 child: SizedBox(
 width: 480,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: textController,
 decoration: const InputDecoration(
 labelText: 'Description *',
 isDense: true,
 ),
 maxLines: 2,
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: selectedCategory,
 decoration: const InputDecoration(
 labelText: 'Category *',
 isDense: true,
 ),
 items: _categoryOptions
 .map((c) => DropdownMenuItem(
 value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedCategory = v);
 }
 },
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: selectedMethod,
 decoration: const InputDecoration(
 labelText: 'Analysis method *',
 isDense: true,
 ),
 items: _methodologyOptions
 .map((m) => DropdownMenuItem(
 value: m, child: Text(m, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedMethod = v);
 }
 },
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 value: selectedImpact,
 decoration: const InputDecoration(
 labelText: 'Impact *',
 isDense: true,
 ),
 items: _impactOptions
 .map((i) => DropdownMenuItem(
 value: i, child: Text(i, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedImpact = v);
 }
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: selectedStatus,
 decoration: const InputDecoration(
 labelText: 'Status *',
 isDense: true,
 ),
 items: _statusOptions
 .map((s) => DropdownMenuItem(
 value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedStatus = v);
 }
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: freqController,
 decoration: const InputDecoration(
 labelText: 'Occurrence frequency',
 hintText: 'e.g., Recurring, One-time',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: recController,
 decoration: const InputDecoration(
 labelText: 'Recommendation',
 isDense: true,
 ),
 maxLines: 2,
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 if (textController.text.trim().isEmpty) return;
 final item = _RootCauseItem(
 id: existing?.id ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 text: textController.text.trim(),
 category: selectedCategory,
 methodology: selectedMethod,
 impact: selectedImpact,
 frequency: freqController.text.trim(),
 recommendation: recController.text.trim(),
 status: selectedStatus,
 );
 final updated = isEdit
 ? [for (final i in items) i.id == item.id ? item : i]
 : [...items, item];
 onSaved(updated);
 Navigator.pop(ctx);
 },
 child: Text(isEdit ? 'Update' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 void _confirmDeleteRootCause(BuildContext context, _RootCauseItem item) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete Root Cause'),
 content: Text('Remove this root cause entry?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 onRootCauseUpdated(
 rootCauseThemes.where((i) => i.id != item.id).toList());
 Navigator.pop(ctx);
 },
 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
 child: const Text('Delete', style: TextStyle(color: Colors.white)),
 ),
 ],
 ),
 );
 }

 void _confirmDeleteMitigation(BuildContext context, _RootCauseItem item) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete Mitigation'),
 content: Text('Remove this mitigation entry?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 onMitigationUpdated(
 mitigationConfidence.where((i) => i.id != item.id).toList());
 Navigator.pop(ctx);
 },
 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
 child: const Text('Delete', style: TextStyle(color: Colors.white)),
 ),
 ],
 ),
 );
 }
}

class _GapEntryRow extends StatefulWidget {
 const _GapEntryRow({
 required this.entry,
 required this.onEdit,
 required this.onDelete,
 required this.showDivider,
 });

 final _GapEntry entry;
 final VoidCallback onEdit;
 final VoidCallback onDelete;
 final bool showDivider;

 @override
 State<_GapEntryRow> createState() => _GapEntryRowState();
}

class _GapEntryRowState extends State<_GapEntryRow> {
 bool _isHovering = false;

 Color _categoryColor(String cat) {
 switch (cat) {
 case 'Scope':
 return const Color(0xFF2563EB);
 case 'Schedule':
 return const Color(0xFFF59E0B);
 case 'Cost':
 return const Color(0xFF059669);
 case 'Quality':
 return const Color(0xFF7C3AED);
 case 'Compliance':
 return const Color(0xFFDC2626);
 case 'Resource':
 return const Color(0xFFEA580C);
 case 'Technical':
 return const Color(0xFF0D9488);
 case 'Process':
 return const Color(0xFF4F46E5);
 default:
 return const Color(0xFF64748B);
 }
 }

 Color _severityColor(String sev) {
 switch (sev) {
 case 'Critical':
 return const Color(0xFFDC2626);
 case 'High':
 return const Color(0xFFEF4444);
 case 'Medium':
 return const Color(0xFFF59E0B);
 case 'Low':
 return const Color(0xFF10B981);
 default:
 return const Color(0xFF9CA3AF);
 }
 }

 Color _priorityColor(String stage) {
 switch (stage) {
 case 'Critical':
 return const Color(0xFFDC2626);
 case 'Moderate':
 return const Color(0xFFF97316);
 case 'Low':
 return const Color(0xFF059669);
 case 'Resolved':
 return const Color(0xFF2563EB);
 default:
 return const Color(0xFF9CA3AF);
 }
 }

 IconData _priorityIcon(String stage) {
 switch (stage) {
 case 'Critical':
 return Icons.error_outline;
 case 'Moderate':
 return Icons.warning_amber_outlined;
 case 'Low':
 return Icons.info_outline;
 case 'Resolved':
 return Icons.check_circle_outline;
 default:
 return Icons.radio_button_unchecked;
 }
 }

 @override
 Widget build(BuildContext context) {
 final e = widget.entry;
 final catColor = _categoryColor(e.category);
 final sevColor = _severityColor(e.severity);
 final prioColor = _priorityColor(e.stage);

 return MouseRegion(
 onEnter: (_) => Future.microtask(() {
 if (mounted) setState(() => _isHovering = true);
 }),
 onExit: (_) => Future.microtask(() {
 if (mounted) setState(() => _isHovering = false);
 }),
 child: Column(
 children: [
 Container(
 color: _isHovering ? const Color(0xFFF9FAFB) : Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 // Gap ID + description
 Expanded(
 flex: 4,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: const Color(0xFFF1F5F9),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 e.id,
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: Color(0xFF64748B),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Text(
 e.title.trim().isEmpty ? 'Untitled gap' : e.title,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827),
 height: 1.4,
 ),
 ),
 if (e.nextStep.trim().isNotEmpty) ...[
 const SizedBox(height: 3),
 Text(
 e.nextStep,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ],
 ),
 ),
 // Category
 SizedBox(
 width: 120,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: catColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: catColor.withOpacity(0.18)),
 ),
 child: Text(
 e.category,
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: catColor,
 ),
 ),
 ),
 ),
 ),
 // Severity
 SizedBox(
 width: 120,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: sevColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 6,
 height: 6,
 decoration: BoxDecoration(color: sevColor, shape: BoxShape.circle),
 ),
 const SizedBox(width: 6),
 Text(
 e.severity,
 style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sevColor),
 ),
 ],
 ),
 ),
 ),
 ),
 // Priority
 SizedBox(
 width: 120,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: prioColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(_priorityIcon(e.stage), size: 13, color: prioColor),
 const SizedBox(width: 5),
 Flexible(
 child: Text(
 e.stage,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: prioColor),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 // Owner
 SizedBox(
 width: 130,
 child: Center(
 child: Text(
 e.owner.trim().isEmpty ? 'Unassigned' : e.owner,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: e.owner.trim().isEmpty ? const Color(0xFF9CA3AF) : const Color(0xFF334155),
 ),
 ),
 ),
 ),
 // Target date
 SizedBox(
 width: 120,
 child: Center(
 child: Text(
 e.targetDate.trim().isEmpty ? '—' : e.targetDate,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF475569),
 ),
 ),
 ),
 ),
 // Actions
 SizedBox(
 width: 60,
 child: _isHovering
 ? Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF64748B)),
 onPressed: widget.onEdit,
 tooltip: 'Edit',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFEF4444)),
 onPressed: widget.onDelete,
 tooltip: 'Delete',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
   onPressed: () {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('KAZ AI: Generating suggestions...'), duration: Duration(seconds: 2)),
     );
   },
   icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFF59E0B)),
   tooltip: 'KAZ AI',
   padding: EdgeInsets.zero,
   constraints: const BoxConstraints(minWidth: 28),
 ),
 ],
 )
 : const SizedBox(width: 56),
 ),
 ],
 ),
 ),
 if (widget.showDivider)
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
 ],
 ),
 );
 }
}

class _RootCauseRow extends StatefulWidget {
 const _RootCauseRow({
 required this.item,
 required this.onEdit,
 required this.onDelete,
 required this.showDivider,
 });

 final _RootCauseItem item;
 final VoidCallback onEdit;
 final VoidCallback onDelete;
 final bool showDivider;

 @override
 State<_RootCauseRow> createState() => _RootCauseRowState();
}

class _RootCauseRowState extends State<_RootCauseRow> {
 bool _isHovering = false;

 Color _categoryColor(String cat) {
 switch (cat) {
 case 'Process':
 return const Color(0xFF4F46E5);
 case 'People':
 return const Color(0xFF2563EB);
 case 'Technology':
 return const Color(0xFF0D9488);
 case 'Requirements':
 return const Color(0xFF7C3AED);
 case 'Governance':
 return const Color(0xFFDC2626);
 case 'External':
 return const Color(0xFFEA580C);
 case 'Design':
 return const Color(0xFF059669);
 case 'Communication':
 return const Color(0xFFF59E0B);
 default:
 return const Color(0xFF64748B);
 }
 }

 Color _impactColor(String impact) {
 switch (impact) {
 case 'Critical':
 return const Color(0xFFDC2626);
 case 'High':
 return const Color(0xFFEF4444);
 case 'Medium':
 return const Color(0xFFF59E0B);
 case 'Low':
 return const Color(0xFF10B981);
 default:
 return const Color(0xFF9CA3AF);
 }
 }

 Color _statusColor(String status) {
 switch (status) {
 case 'Open':
 return const Color(0xFF9CA3AF);
 case 'Under Investigation':
 return const Color(0xFF2563EB);
 case 'Remediation In Progress':
 return const Color(0xFFF59E0B);
 case 'Verified Closed':
 return const Color(0xFF10B981);
 case 'Accepted Risk':
 return const Color(0xFF8B5CF6);
 default:
 return const Color(0xFF9CA3AF);
 }
 }

 IconData _statusIcon(String status) {
 switch (status) {
 case 'Open':
 return Icons.radio_button_unchecked;
 case 'Under Investigation':
 return Icons.search;
 case 'Remediation In Progress':
 return Icons.sync_outlined;
 case 'Verified Closed':
 return Icons.check_circle_outline;
 case 'Accepted Risk':
 return Icons.shield_outlined;
 default:
 return Icons.radio_button_unchecked;
 }
 }

 @override
 Widget build(BuildContext context) {
 final item = widget.item;
 final catColor = _categoryColor(item.category);
 final impactColor = _impactColor(item.impact);
 final statusColor = _statusColor(item.status);

 return MouseRegion(
 onEnter: (_) => Future.microtask(() {
 if (mounted) setState(() => _isHovering = true);
 }),
 onExit: (_) => Future.microtask(() {
 if (mounted) setState(() => _isHovering = false);
 }),
 child: Column(
 children: [
 Container(
 color: _isHovering ? const Color(0xFFF9FAFB) : Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 // Root cause description
 Expanded(
 flex: 4,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 item.text.trim().isEmpty ? 'Unnamed root cause' : item.text,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827),
 height: 1.4,
 ),
 ),
 if (item.recommendation.trim().isNotEmpty) ...[
 const SizedBox(height: 3),
 Text(
 item.recommendation,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ],
 ),
 ),
 // Category
 SizedBox(
 width: 130,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: catColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: catColor.withOpacity(0.18)),
 ),
 child: Text(
 item.category,
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: catColor,
 ),
 ),
 ),
 ),
 ),
 // Method
 SizedBox(
 width: 130,
 child: Center(
 child: Text(
 item.methodology,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF475569),
 ),
 ),
 ),
 ),
 // Impact
 SizedBox(
 width: 130,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: impactColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 6,
 height: 6,
 decoration: BoxDecoration(color: impactColor, shape: BoxShape.circle),
 ),
 const SizedBox(width: 6),
 Flexible(
 child: Text(
 item.impact,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: impactColor),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 // Status
 SizedBox(
 width: 130,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
 decoration: BoxDecoration(
 color: statusColor.withOpacity(0.1),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(_statusIcon(item.status), size: 13, color: statusColor),
 const SizedBox(width: 5),
 Flexible(
 child: Text(
 item.status,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 // Actions
 SizedBox(
 width: 60,
 child: _isHovering
 ? Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF64748B)),
 onPressed: widget.onEdit,
 tooltip: 'Edit',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFEF4444)),
 onPressed: widget.onDelete,
 tooltip: 'Delete',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
   onPressed: () {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('KAZ AI: Generating suggestions...'), duration: Duration(seconds: 2)),
     );
   },
   icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFF59E0B)),
   tooltip: 'KAZ AI',
   padding: EdgeInsets.zero,
   constraints: const BoxConstraints(minWidth: 28),
 ),
 ],
 )
 : const SizedBox(width: 56),
 ),
 ],
 ),
 ),
 if (widget.showDivider)
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
 ],
 ),
 );
 }
}

class _ReconciliationPlanningCard extends StatelessWidget {
 const _ReconciliationPlanningCard({
 required this.width,
 required this.plans,
 required this.onPlansUpdated,
 });

 final double width;
 final List<_PlanEntry> plans;
 final ValueChanged<List<_PlanEntry>> onPlansUpdated;

 static const _statusOptions = [
 'Not started',
 'In progress',
 'On track',
 'At risk',
 'In review',
 'Complete',
 'Deferred',
 ];

 static const _phaseOptions = [
 'Execution',
 'Close-out',
 'Handover',
 'Remediation',
 'Verification',
 'Post-project',
 ];

 @override
 Widget build(BuildContext context) {
 return _SectionShell(
 width: width,
 title: 'Reconciliation planning',
 subtitle: 'Sequenced closure plan aligned with PMI PMBOK Close Project '
 '(4.7) and PRINCE2 Closing a Project processes. Each action maps to '
 'a specific gap with clear ownership, timeline dependencies, and '
 'verifiable completion criteria.',
 trailing: TextButton.icon(
 onPressed: () => _showPlanEditor(context),
 icon: const Icon(Icons.add_circle_outline),
 label: const Text('Add step'),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (plans.isEmpty)
 const _EmptyPanel(label: 'No reconciliation steps yet.')
 else
 LayoutBuilder(
 builder: (context, constraints) {
 final tableWidth =
 constraints.maxWidth < 1120 ? 1120.0 : constraints.maxWidth;
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: tableWidth,
 child: Container(
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 decoration: const BoxDecoration(
 color: Color(0xFFF9FAFB),
 borderRadius: BorderRadius.vertical(
 top: Radius.circular(16)),
 ),
 child: const Row(
 children: [
 SizedBox(width: 20),
 Expanded(
 flex: 4,
 child: Text('RECONCILIATION ACTION',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8))),
 SizedBox(
 width: 130,
 child: Text('PHASE',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 120,
 child: Text('GAP REF',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 120,
 child: Text('OWNER',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 120,
 child: Text('DUE',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 130,
 child: Text('PROGRESS',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 130,
 child: Text('STATUS',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 60,
 child: Text('',
 style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 ...plans.map((plan) {
 final isLast = plan == plans.last;
 return _ReconPlanRow(
 plan: plan,
 onEdit: () =>
 _showPlanEditor(context, existing: plan),
 onDelete: () =>
 _confirmDeletePlan(context, plan),
 showDivider: !isLast,
 );
 }),
 ],
 ),
 ),
 ),
 );
 },
 ),
 ],
 ),
 );
 }

 void _showPlanEditor(BuildContext context, {_PlanEntry? existing}) {
 final isEdit = existing != null;
 final titleController =
 TextEditingController(text: existing?.title ?? '');
 final dueController =
 TextEditingController(text: existing?.due ?? '');
 final ownerController =
 TextEditingController(text: existing?.owner ?? '');
 final gapRefController =
 TextEditingController(text: existing?.gapReference ?? '');
 final depController =
 TextEditingController(text: existing?.dependency ?? '');
 final notesController =
 TextEditingController(text: existing?.notes ?? '');
 String selectedStatus = existing?.status ?? 'Not started';
 String selectedPhase = existing?.phase ?? 'Execution';
 int completionPct = existing?.completionPct ?? 0;

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDialogState) => AlertDialog(
 title: Text(isEdit ? 'Edit Reconciliation Step' : 'Add Reconciliation Step'),
 content: SingleChildScrollView(
 child: SizedBox(
 width: 500,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: titleController,
 decoration: const InputDecoration(
 labelText: 'Action description *',
 isDense: true,
 ),
 maxLines: 2,
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 value: selectedPhase,
 decoration: const InputDecoration(
 labelText: 'Phase *',
 isDense: true,
 ),
 items: _phaseOptions
 .map((p) => DropdownMenuItem(
 value: p, child: Text(p, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedPhase = v);
 }
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: _statusOptions.contains(selectedStatus)
 ? selectedStatus
 : _statusOptions.first,
 decoration: const InputDecoration(
 labelText: 'Status *',
 isDense: true,
 ),
 items: _statusOptions
 .map((s) => DropdownMenuItem(
 value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedStatus = v);
 }
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: ownerController,
 decoration: const InputDecoration(
 labelText: 'Owner *',
 isDense: true,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextField(
 controller: dueController,
 decoration: const InputDecoration(
 labelText: 'Due date',
 hintText: 'e.g., 2025-09-30',
 isDense: true,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: gapRefController,
 decoration: const InputDecoration(
 labelText: 'Gap reference',
 hintText: 'e.g., GAP-001',
 isDense: true,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Completion: $completionPct%',
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
 Slider(
 value: completionPct.toDouble(),
 min: 0,
 max: 100,
 divisions: 10,
 label: '$completionPct%',
 onChanged: (v) {
 setDialogState(() => completionPct = v.round());
 },
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 VoiceTextField(
 controller: depController,
 decoration: const InputDecoration(
 labelText: 'Dependency',
 hintText: 'e.g., Requires GAP-003 closure first',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: notesController,
 decoration: const InputDecoration(
 labelText: 'Notes',
 isDense: true,
 ),
 maxLines: 2,
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 if (titleController.text.trim().isEmpty) return;
 final plan = _PlanEntry(
 id: existing?.id ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 title: titleController.text.trim(),
 due: dueController.text.trim(),
 owner: ownerController.text.trim(),
 status: selectedStatus,
 phase: selectedPhase,
 gapReference: gapRefController.text.trim(),
 dependency: depController.text.trim(),
 completionPct: completionPct,
 notes: notesController.text.trim(),
 );
 final updated = isEdit
 ? [for (final p in plans) p.id == plan.id ? plan : p]
 : [...plans, plan];
 onPlansUpdated(updated);
 Navigator.pop(ctx);
 },
 child: Text(isEdit ? 'Update' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 void _confirmDeletePlan(BuildContext context, _PlanEntry plan) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete Reconciliation Step'),
 content: Text(
 'Remove "${plan.title.isNotEmpty ? plan.title : 'this step'}" from the plan?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 onPlansUpdated(plans.where((p) => p.id != plan.id).toList());
 Navigator.pop(ctx);
 },
 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
 child: const Text('Delete', style: TextStyle(color: Colors.white)),
 ),
 ],
 ),
 );
 }
}

class _ImpactAssessmentCard extends StatelessWidget {
 const _ImpactAssessmentCard({
 required this.width,
 required this.impacts,
 required this.onImpactsUpdated,
 required this.gaps,
 required this.plans,
 });

 final double width;
 final List<_ImpactRow> impacts;
 final ValueChanged<List<_ImpactRow>> onImpactsUpdated;
 final List<_GapEntry> gaps;
 final List<_PlanEntry> plans;

 static const _ratingOptions = ['Low', 'Medium', 'High', 'Critical'];
 static const _trendOptions = ['Improving', 'Stable', 'Needs attention', 'Deteriorating'];
 static const _domainOptions = [
 'Schedule',
 'Cost',
 'Quality',
 'Scope',
 'Compliance',
 'Safety',
 'Reputation',
 'Operations',
 ];

 @override
 Widget build(BuildContext context) {
 return _SectionShell(
 width: width,
 title: 'Impact assessment results',
 subtitle: 'Impact evaluation aligned with PMI PMBOK Monitor Risks (11.7) '
 'and PRINCE2 Risk Management. Assess each unresolved gap across '
 'schedule, cost, quality, and compliance dimensions with trend '
 'indicators and financial exposure estimates.',
 trailing: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 TextButton.icon(
 onPressed: () => _showImpactEditor(context),
 icon: const Icon(Icons.add_circle_outline),
 label: const Text('Add impact'),
 ),
 const SizedBox(width: 8),
 TextButton.icon(
 onPressed: () {
 showDialog<void>(
 context: context,
 barrierColor: Colors.black.withOpacity(0.35),
 builder: (_) => _ScenarioMatrixDialog(
 impacts: impacts,
 gaps: gaps,
 plans: plans,
 ),
 );
 },
 icon: const Icon(Icons.analytics_outlined),
 label: const Text('Scenario matrix'),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (impacts.isEmpty)
 const _EmptyPanel(label: 'No impact assessment items yet.')
 else
 LayoutBuilder(
 builder: (context, constraints) {
 final tableWidth =
 constraints.maxWidth < 1160 ? 1160.0 : constraints.maxWidth;
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: tableWidth,
 child: Container(
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 20, vertical: 12),
 decoration: const BoxDecoration(
 color: Color(0xFFF9FAFB),
 borderRadius: BorderRadius.vertical(
 top: Radius.circular(16)),
 ),
 child: const Row(
 children: [
 SizedBox(width: 20),
 Expanded(
 flex: 4,
 child: Text('IMPACT AREA',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8))),
 SizedBox(
 width: 120,
 child: Text('DOMAIN',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 130,
 child: Text('RATING',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 130,
 child: Text('TREND',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 120,
 child: Text('OWNER',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 120,
 child: Text('EXPOSURE',
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: Color(0xFF6B7280),
 letterSpacing: 0.8),
 textAlign: TextAlign.center)),
 SizedBox(
 width: 60,
 child: Text('',
 style: TextStyle(fontSize: 10))),
 ],
 ),
 ),
 ...impacts.map((impact) {
 final isLast = impact == impacts.last;
 return _ImpactAssessmentRow(
 impact: impact,
 onEdit: () =>
 _showImpactEditor(context, existing: impact),
 onDelete: () =>
 _confirmDeleteImpact(context, impact),
 showDivider: !isLast,
 );
 }),
 ],
 ),
 ),
 ),
 );
 },
 ),
 ],
 ),
 );
 }

 void _showImpactEditor(BuildContext context, {_ImpactRow? existing}) {
 final isEdit = existing != null;
 final areaController =
 TextEditingController(text: existing?.area ?? '');
 final detailController =
 TextEditingController(text: existing?.detail ?? '');
 final deliverableController =
 TextEditingController(text: existing?.affectedDeliverable ?? '');
 final exposureController =
 TextEditingController(text: existing?.financialExposure ?? '');
 final ownerController =
 TextEditingController(text: existing?.owner ?? '');
 final mitigationController =
 TextEditingController(text: existing?.mitigationLink ?? '');
 String selectedRating = existing?.rating ?? 'Medium';
 String selectedTrend = existing?.trend ?? 'Stable';
 String selectedDomain = existing?.domain ?? 'Schedule';

 showDialog(
 context: context,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDialogState) => AlertDialog(
 title: Text(isEdit ? 'Edit Impact Assessment' : 'Add Impact Assessment'),
 content: SingleChildScrollView(
 child: SizedBox(
 width: 500,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: areaController,
 decoration: const InputDecoration(
 labelText: 'Impact area *',
 isDense: true,
 ),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: detailController,
 decoration: const InputDecoration(
 labelText: 'Description *',
 isDense: true,
 ),
 maxLines: 2,
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 value: selectedDomain,
 decoration: const InputDecoration(
 labelText: 'Domain *',
 isDense: true,
 ),
 items: _domainOptions
 .map((d) => DropdownMenuItem(
 value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedDomain = v);
 }
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: DropdownButtonFormField<String>(
 value: _ratingOptions.contains(selectedRating)
 ? selectedRating
 : _ratingOptions.first,
 decoration: const InputDecoration(
 labelText: 'Rating *',
 isDense: true,
 ),
 items: _ratingOptions
 .map((r) => DropdownMenuItem(
 value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedRating = v);
 }
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: DropdownButtonFormField<String>(
 value: _trendOptions.contains(selectedTrend)
 ? selectedTrend
 : _trendOptions.first,
 decoration: const InputDecoration(
 labelText: 'Trend *',
 isDense: true,
 ),
 items: _trendOptions
 .map((t) => DropdownMenuItem(
 value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
 .toList(),
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => selectedTrend = v);
 }
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextField(
 controller: ownerController,
 decoration: const InputDecoration(
 labelText: 'Owner',
 isDense: true,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: exposureController,
 decoration: const InputDecoration(
 labelText: 'Financial exposure',
 hintText: 'e.g., \$150K',
 isDense: true,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextField(
 controller: deliverableController,
 decoration: const InputDecoration(
 labelText: 'Affected deliverable',
 isDense: true,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: mitigationController,
 decoration: const InputDecoration(
 labelText: 'Mitigation plan reference',
 hintText: 'e.g., Linked to GAP-002 remediation',
 isDense: true,
 ),
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 if (areaController.text.trim().isEmpty) return;
 final impact = _ImpactRow(
 id: existing?.id ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 area: areaController.text.trim(),
 rating: selectedRating,
 trend: selectedTrend,
 detail: detailController.text.trim(),
 domain: selectedDomain,
 affectedDeliverable: deliverableController.text.trim(),
 financialExposure: exposureController.text.trim(),
 owner: ownerController.text.trim(),
 mitigationLink: mitigationController.text.trim(),
 );
 final updated = isEdit
 ? [for (final i in impacts) i.id == impact.id ? impact : i]
 : [...impacts, impact];
 onImpactsUpdated(updated);
 Navigator.pop(ctx);
 },
 child: Text(isEdit ? 'Update' : 'Add'),
 ),
 ],
 ),
 ),
 );
 }

 void _confirmDeleteImpact(BuildContext context, _ImpactRow impact) {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete Impact Assessment'),
 content: Text(
 'Remove "${impact.area.isNotEmpty ? impact.area : 'this impact'}" from the assessment?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 onImpactsUpdated(
 impacts.where((i) => i.id != impact.id).toList());
 Navigator.pop(ctx);
 },
 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
 child: const Text('Delete', style: TextStyle(color: Colors.white)),
 ),
 ],
 ),
 );
 }
}

class _ReconPlanRow extends StatefulWidget {
 const _ReconPlanRow({
 required this.plan,
 required this.onEdit,
 required this.onDelete,
 required this.showDivider,
 });

 final _PlanEntry plan;
 final VoidCallback onEdit;
 final VoidCallback onDelete;
 final bool showDivider;

 @override
 State<_ReconPlanRow> createState() => _ReconPlanRowState();
}

class _ReconPlanRowState extends State<_ReconPlanRow> {
 bool _isHovering = false;

 Color _phaseColor(String phase) {
 switch (phase) {
 case 'Execution':
 return const Color(0xFF2563EB);
 case 'Close-out':
 return const Color(0xFF7C3AED);
 case 'Handover':
 return const Color(0xFF059669);
 case 'Remediation':
 return const Color(0xFFEF4444);
 case 'Verification':
 return const Color(0xFFF59E0B);
 case 'Post-project':
 return const Color(0xFF64748B);
 default:
 return const Color(0xFF64748B);
 }
 }

 Color _statusColor(String status) {
 switch (status) {
 case 'Not started':
 return const Color(0xFF9CA3AF);
 case 'In progress':
 return const Color(0xFF2563EB);
 case 'On track':
 return const Color(0xFF10B981);
 case 'At risk':
 return const Color(0xFFEF4444);
 case 'In review':
 return const Color(0xFFF59E0B);
 case 'Complete':
 return const Color(0xFF059669);
 case 'Deferred':
 return const Color(0xFF8B5CF6);
 default:
 return const Color(0xFF9CA3AF);
 }
 }

 IconData _statusIcon(String status) {
 switch (status) {
 case 'Not started':
 return Icons.radio_button_unchecked;
 case 'In progress':
 return Icons.sync_outlined;
 case 'On track':
 return Icons.check_circle_outline;
 case 'At risk':
 return Icons.warning_amber_outlined;
 case 'In review':
 return Icons.visibility_outlined;
 case 'Complete':
 return Icons.task_alt_outlined;
 case 'Deferred':
 return Icons.schedule_outlined;
 default:
 return Icons.radio_button_unchecked;
 }
 }

 Color _progressColor(int pct) {
 if (pct >= 80) return const Color(0xFF10B981);
 if (pct >= 50) return const Color(0xFF2563EB);
 if (pct >= 25) return const Color(0xFFF59E0B);
 return const Color(0xFFEF4444);
 }

 @override
 Widget build(BuildContext context) {
 final p = widget.plan;
 final phaseColor = _phaseColor(p.phase);
 final statusColor = _statusColor(p.status);
 final pct = p.completionPct ?? 0;
 final progressColor = _progressColor(pct);

 return MouseRegion(
 onEnter: (_) => setState(() => _isHovering = true),
 onExit: (_) => setState(() => _isHovering = false),
 child: Column(
 children: [
 Container(
 color: _isHovering ? const Color(0xFFF9FAFB) : Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 // Action title + gap ref + notes
 Expanded(
 flex: 4,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 p.title.trim().isEmpty ? 'Untitled action' : p.title,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827),
 height: 1.4,
 ),
 ),
 if (p.dependency.trim().isNotEmpty) ...[
 const SizedBox(height: 3),
 Text(
 'Depends on: ${p.dependency}',
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w500,
 color: Color(0xFF9CA3AF),
 ),
 ),
 ],
 ],
 ),
 ),
 // Phase
 SizedBox(
 width: 130,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: phaseColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: phaseColor.withOpacity(0.18)),
 ),
 child: Text(
 p.phase,
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: phaseColor,
 ),
 ),
 ),
 ),
 ),
 // Gap reference
 SizedBox(
 width: 120,
 child: Center(
 child: Text(
 p.gapReference.trim().isEmpty ? '—' : p.gapReference,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: p.gapReference.trim().isEmpty
 ? const Color(0xFF9CA3AF)
 : const Color(0xFF475569),
 ),
 ),
 ),
 ),
 // Owner
 SizedBox(
 width: 120,
 child: Center(
 child: Text(
 p.owner.trim().isEmpty ? 'Unassigned' : p.owner,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: p.owner.trim().isEmpty
 ? const Color(0xFF9CA3AF)
 : const Color(0xFF334155),
 ),
 ),
 ),
 ),
 // Due
 SizedBox(
 width: 120,
 child: Center(
 child: Text(
 p.due.trim().isEmpty ? '—' : p.due,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF475569),
 ),
 ),
 ),
 ),
 // Progress
 SizedBox(
 width: 130,
 child: Center(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 '$pct%',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: progressColor,
 ),
 ),
 const SizedBox(height: 4),
 ClipRRect(
 borderRadius: BorderRadius.circular(4),
 child: LinearProgressIndicator(
 value: pct / 100.0,
 backgroundColor: const Color(0xFFE5E7EB),
 valueColor: AlwaysStoppedAnimation(progressColor),
 minHeight: 4,
 ),
 ),
 ],
 ),
 ),
 ),
 // Status
 SizedBox(
 width: 130,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
 decoration: BoxDecoration(
 color: statusColor.withOpacity(0.1),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(_statusIcon(p.status), size: 13, color: statusColor),
 const SizedBox(width: 5),
 Flexible(
 child: Text(
 p.status,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: statusColor,
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 // Actions
 SizedBox(
 width: 60,
 child: _isHovering
 ? Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF64748B)),
 onPressed: widget.onEdit,
 tooltip: 'Edit',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFEF4444)),
 onPressed: widget.onDelete,
 tooltip: 'Delete',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
   onPressed: () {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('KAZ AI: Generating suggestions...'), duration: Duration(seconds: 2)),
     );
   },
   icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFF59E0B)),
   tooltip: 'KAZ AI',
   padding: EdgeInsets.zero,
   constraints: const BoxConstraints(minWidth: 28),
 ),
 ],
 )
 : const SizedBox(width: 56),
 ),
 ],
 ),
 ),
 if (widget.showDivider)
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
 ],
 ),
 );
 }
}

class _ImpactAssessmentRow extends StatefulWidget {
 const _ImpactAssessmentRow({
 required this.impact,
 required this.onEdit,
 required this.onDelete,
 required this.showDivider,
 });

 final _ImpactRow impact;
 final VoidCallback onEdit;
 final VoidCallback onDelete;
 final bool showDivider;

 @override
 State<_ImpactAssessmentRow> createState() => _ImpactAssessmentRowState();
}

class _ImpactAssessmentRowState extends State<_ImpactAssessmentRow> {
 bool _isHovering = false;

 Color _domainColor(String domain) {
 switch (domain) {
 case 'Schedule':
 return const Color(0xFF2563EB);
 case 'Cost':
 return const Color(0xFF059669);
 case 'Quality':
 return const Color(0xFF7C3AED);
 case 'Scope':
 return const Color(0xFFEA580C);
 case 'Compliance':
 return const Color(0xFFDC2626);
 case 'Safety':
 return const Color(0xFFEF4444);
 case 'Reputation':
 return const Color(0xFFF59E0B);
 case 'Operations':
 return const Color(0xFF0D9488);
 default:
 return const Color(0xFF64748B);
 }
 }

 Color _ratingColor(String rating) {
 switch (rating) {
 case 'Critical':
 return const Color(0xFFDC2626);
 case 'High':
 return const Color(0xFFEF4444);
 case 'Medium':
 return const Color(0xFFF59E0B);
 case 'Low':
 return const Color(0xFF10B981);
 default:
 return const Color(0xFF9CA3AF);
 }
 }

 IconData _ratingIcon(String rating) {
 switch (rating) {
 case 'Critical':
 return Icons.error_outline;
 case 'High':
 return Icons.warning_amber_outlined;
 case 'Medium':
 return Icons.info_outline;
 case 'Low':
 return Icons.check_circle_outline;
 default:
 return Icons.radio_button_unchecked;
 }
 }

 Color _trendColor(String trend) {
 switch (trend) {
 case 'Improving':
 return const Color(0xFF10B981);
 case 'Stable':
 return const Color(0xFF2563EB);
 case 'Needs attention':
 return const Color(0xFFF59E0B);
 case 'Deteriorating':
 return const Color(0xFFEF4444);
 default:
 return const Color(0xFF9CA3AF);
 }
 }

 IconData _trendIcon(String trend) {
 switch (trend) {
 case 'Improving':
 return Icons.trending_up;
 case 'Stable':
 return Icons.trending_flat;
 case 'Needs attention':
 return Icons.trending_down;
 case 'Deteriorating':
 return Icons.south_outlined;
 default:
 return Icons.trending_flat;
 }
 }

 @override
 Widget build(BuildContext context) {
 final i = widget.impact;
 final domainColor = _domainColor(i.domain);
 final ratingColor = _ratingColor(i.rating);
 final trendColor = _trendColor(i.trend);

 return MouseRegion(
 onEnter: (_) => setState(() => _isHovering = true),
 onExit: (_) => setState(() => _isHovering = false),
 child: Column(
 children: [
 Container(
 color: _isHovering ? const Color(0xFFF9FAFB) : Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 // Impact area + description
 Expanded(
 flex: 4,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 i.area.trim().isEmpty ? 'Unnamed impact' : i.area,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827),
 ),
 ),
 if (i.detail.trim().isNotEmpty) ...[
 const SizedBox(height: 3),
 Text(
 i.detail,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 height: 1.4,
 ),
 ),
 ],
 if (i.affectedDeliverable.trim().isNotEmpty) ...[
 const SizedBox(height: 2),
 Text(
 'Deliverable: ${i.affectedDeliverable}',
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w500,
 color: Color(0xFF9CA3AF),
 ),
 ),
 ],
 ],
 ),
 ),
 // Domain
 SizedBox(
 width: 120,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: domainColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: domainColor.withOpacity(0.18)),
 ),
 child: Text(
 i.domain,
 textAlign: TextAlign.center,
 style: TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: domainColor,
 ),
 ),
 ),
 ),
 ),
 // Rating
 SizedBox(
 width: 130,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: ratingColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(_ratingIcon(i.rating), size: 13, color: ratingColor),
 const SizedBox(width: 5),
 Flexible(
 child: Text(
 i.rating,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ratingColor),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 // Trend
 SizedBox(
 width: 130,
 child: Center(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: trendColor.withOpacity(0.08),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(_trendIcon(i.trend), size: 14, color: trendColor),
 const SizedBox(width: 5),
 Flexible(
 child: Text(
 i.trend,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: trendColor),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 // Owner
 SizedBox(
 width: 120,
 child: Center(
 child: Text(
 i.owner.trim().isEmpty ? 'Unassigned' : i.owner,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: i.owner.trim().isEmpty
 ? const Color(0xFF9CA3AF)
 : const Color(0xFF334155),
 ),
 ),
 ),
 ),
 // Financial exposure
 SizedBox(
 width: 120,
 child: Center(
 child: Text(
 i.financialExposure.trim().isEmpty ? '—' : i.financialExposure,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF475569),
 ),
 ),
 ),
 ),
 // Actions
 SizedBox(
 width: 60,
 child: _isHovering
 ? Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 IconButton(
 icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF64748B)),
 onPressed: widget.onEdit,
 tooltip: 'Edit',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFEF4444)),
 onPressed: widget.onDelete,
 tooltip: 'Delete',
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
 ),
 IconButton(
   onPressed: () {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('KAZ AI: Generating suggestions...'), duration: Duration(seconds: 2)),
     );
   },
   icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFF59E0B)),
   tooltip: 'KAZ AI',
   padding: EdgeInsets.zero,
   constraints: const BoxConstraints(minWidth: 28),
 ),
 ],
 )
 : const SizedBox(width: 56),
 ),
 ],
 ),
 ),
 if (widget.showDivider)
 const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
 ],
 ),
 );
 }
}

class _ScenarioMatrixDialog extends StatefulWidget {
 const _ScenarioMatrixDialog({
 required this.impacts,
 required this.gaps,
 required this.plans,
 });

 final List<_ImpactRow> impacts;
 final List<_GapEntry> gaps;
 final List<_PlanEntry> plans;

 @override
 State<_ScenarioMatrixDialog> createState() => _ScenarioMatrixDialogState();
}

class _ScenarioMatrixDialogState extends State<_ScenarioMatrixDialog> {
 final TextEditingController _searchController = TextEditingController();
 final Set<String> _categoryFilters = {'All'};

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Gap Analysis & Scope Reconciliation',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_gap_analysis_scope_reconcillation_notes'] ?? 'No data recorded.'),
 ],
 );
 }

 @override
 void dispose() {
 _searchController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final scenarios = _buildScenarios();
 final filtered = _filterScenarios(scenarios);

 return Dialog(
 insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 760),
 child: Padding(
 padding: const EdgeInsets.all(20),
 child: Column(
 children: [
 PlanningPhaseHeader(
 title: 'Gap Analysis and Scope Reconciliation',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _buildHeader(context, scenarios.length),
 const SizedBox(height: 16),
 _buildControls(),
 const SizedBox(height: 16),
 Expanded(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(flex: 3, child: _buildMatrix(filtered)),
 const SizedBox(width: 16),
 Expanded(flex: 2, child: _buildInsightsPanel(filtered)),
 ],
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 Widget _buildHeader(BuildContext context, int totalCount) {
 return Row(
 children: [
 Container(
 width: 42,
 height: 42,
 decoration: BoxDecoration(
 color: const Color(0xFFEEF2FF),
 borderRadius: BorderRadius.circular(14),
 ),
 child: const Icon(Icons.grid_view_rounded, color: Color(0xFF4338CA)),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Scenario Matrix',
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 Text(
 'Synthesized from your gap register, impact ratings, and plan milestones.',
 style: TextStyle(fontSize: 12, color: Colors.grey[600]),
 ),
 ],
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(999),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Text('$totalCount scenarios',
 style:
 const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
 ),
 const SizedBox(width: 8),
 IconButton(
 tooltip: 'Add scenario',
 onPressed: () {
 final fep = ProjectDataHelper.getData(context).frontEndPlanning;
 _openEditDialog(context, currentList: fep.scenarioMatrixItems);
 },
 icon: const Icon(Icons.add, color: Color(0xFF94A3B8)),
 ),
 IconButton(
 tooltip: 'Close',
 onPressed: () => Navigator.of(context).pop(),
 icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
 ),
 ],
 );
 }

 Future<void> _openEditDialog(BuildContext context,
 {ScenarioRecord? record, List<ScenarioRecord>? currentList}) async {
 final id = record?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
 final titleCtrl = TextEditingController(text: record?.title ?? '');
 final detailCtrl = TextEditingController(text: record?.detail ?? '');
 var category = record?.category ?? 'Custom';
 var owner = record?.owner ?? '';
 var severity = record?.severity ?? 2;
 var likelihood = record?.likelihood ?? 2;

 final saved = await showDialog<bool>(
 context: context,
 builder: (_) => AlertDialog(
 title: Text(record == null ? 'Add scenario' : 'Edit scenario'),
 content: SingleChildScrollView(
 child: Column(
 children: [
 VoiceTextField(
 controller: titleCtrl,
 decoration: const InputDecoration(labelText: 'Title')),
 const SizedBox(height: 8),
 VoiceTextField(
 controller: detailCtrl,
 decoration: const InputDecoration(labelText: 'Detail')),
 const SizedBox(height: 8),
 VoiceTextField(
 onChanged: (v) => owner = v,
 controller: TextEditingController(text: owner),
 decoration: const InputDecoration(labelText: 'Owner')),
 const SizedBox(height: 8),
 DropdownButtonFormField<String>(
 value: category,
 items: ['Custom', 'Impact', 'Gap', 'Plan']
 .map((c) => DropdownMenuItem(value: c, child: Text(c)))
 .toList(),
 onChanged: (v) => category = v ?? 'Custom',
 decoration: const InputDecoration(labelText: 'Category')),
 const SizedBox(height: 8),
 Row(children: [
 Expanded(
 child: DropdownButtonFormField<int>(
 value: severity,
 items: [1, 2, 3]
 .map((i) => DropdownMenuItem(
 value: i, child: Text('Severity $i')))
 .toList(),
 onChanged: (v) => severity = v ?? 2,
 decoration:
 const InputDecoration(labelText: 'Severity'))),
 const SizedBox(width: 8),
 Expanded(
 child: DropdownButtonFormField<int>(
 value: likelihood,
 items: [1, 2, 3]
 .map((i) => DropdownMenuItem(
 value: i, child: Text('Likelihood $i')))
 .toList(),
 onChanged: (v) => likelihood = v ?? 2,
 decoration:
 const InputDecoration(labelText: 'Likelihood'))),
 ])
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(false),
 child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () => Navigator.of(context).pop(true),
 child: const Text('Save')),
 ],
 ),
 );

 if (saved != true) return;

 if (!mounted) return;

 final newRecord = ScenarioRecord(
 id: id,
 title: titleCtrl.text.trim(),
 detail: detailCtrl.text.trim(),
 category: category,
 owner: owner,
 severity: severity,
 likelihood: likelihood);
 // update provider
 await ProjectDataHelper.updateAndSave(
 context: super.context,
 checkpoint: 'gap_analysis_scope_reconcillation',
 dataUpdater: (current) {
 final fep = current.frontEndPlanning;
 final updated = FrontEndPlanningData(
 requirements: fep.requirements,
 requirementsNotes: fep.requirementsNotes,
 risks: fep.risks,
 opportunities: fep.opportunities,
 contractVendorQuotes: fep.contractVendorQuotes,
 procurement: fep.procurement,
 security: fep.security,
 allowance: fep.allowance,
 summary: fep.summary,
 technology: fep.technology,
 personnel: fep.personnel,
 infrastructure: fep.infrastructure,
 contracts: fep.contracts,
 requirementItems: fep.requirementItems,
 technicalDebtItems: fep.technicalDebtItems,
 technicalDebtRootCauses: fep.technicalDebtRootCauses,
 technicalDebtTracks: fep.technicalDebtTracks,
 technicalDebtOwners: fep.technicalDebtOwners,
 scenarioMatrixItems: [
 ...fep.scenarioMatrixItems.where((s) => s.id != id),
 newRecord
 ],
 );
 return current.copyWith(frontEndPlanning: updated);
 },
 );
 }

 Widget _buildControls() {
 const categories = ['All', 'Impact', 'Gap', 'Plan'];
 return Row(
 children: [
 Expanded(
 child: VoiceTextField(
 controller: _searchController,
 onChanged: (_) => setState(() {}),
 decoration: InputDecoration(
 hintText: 'Search scenarios, owners, or tags',
 prefixIcon: const Icon(Icons.search, size: 20),
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide:
 const BorderSide(color: Color(0xFF4338CA), width: 1.6)),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Wrap(
 spacing: 8,
 children: categories.map((category) {
 final selected = _categoryFilters.contains(category);
 return ChoiceChip(
 label: Text(category),
 selected: selected,
 onSelected: (value) {
 setState(() {
 _categoryFilters
 ..clear()
 ..add(value ? category : 'All');
 if (category != 'All' && value) {
 _categoryFilters.remove('All');
 }
 if (_categoryFilters.isEmpty) {
 _categoryFilters.add('All');
 }
 });
 },
 selectedColor: const Color(0xFF111827),
 backgroundColor: Colors.white,
 labelStyle: TextStyle(
 color: selected ? Colors.white : const Color(0xFF475569),
 fontWeight: FontWeight.w600,
 ),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(999),
 side: const BorderSide(color: Color(0xFFE2E8F0))),
 );
 }).toList(),
 ),
 ],
 );
 }

 Widget _buildMatrix(List<_ScenarioPoint> scenarios) {
 final grouped = _groupByCell(scenarios);
 const likelihoodLabels = [
 'Low likelihood',
 'Medium likelihood',
 'High likelihood'
 ];
 const impactLabels = ['Low impact', 'Medium impact', 'High impact'];

 return Column(
 children: [
 Row(
 children: [
 const SizedBox(width: 110),
 for (int i = 0; i < 3; i++)
 Expanded(
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 6),
 child: _AxisHeader(label: likelihoodLabels[i]),
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Expanded(
 child: Column(
 children: [
 for (int row = 2; row >= 0; row--)
 Expanded(
 child: Row(
 children: [
 SizedBox(
 width: 130,
 child: _AxisHeader(
 label: impactLabels[row], isVertical: true)),
 for (int col = 0; col < 3; col++)
 Expanded(
 child: Padding(
 padding: const EdgeInsets.all(6),
 child: _MatrixCell(
 scenarios:
 grouped[_cellKey(row, col)] ?? const [],
 tone: _cellTone(row, col),
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 ],
 );
 }

 Widget _buildInsightsPanel(List<_ScenarioPoint> scenarios) {
 final persisted = ProjectDataHelper.getData(context)
 .frontEndPlanning
 .scenarioMatrixItems
 .map((r) {
 return _ScenarioPoint(
 title: r.title,
 detail: r.detail,
 category: r.category,
 owner: r.owner,
 severity: r.severity,
 likelihood: r.likelihood);
 }).toList();

 final merged = [...scenarios, ...persisted];
 final sorted = [...merged]..sort((a, b) => b.score.compareTo(a.score));
 final topThree = sorted.take(3).toList();
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('Priority scenarios',
 style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
 const SizedBox(height: 6),
 Text(
 'Highest impact and likelihood combinations based on your inputs.',
 style: TextStyle(fontSize: 12, color: Colors.grey[600])),
 const SizedBox(height: 16),
 if (topThree.isEmpty)
 const Text('No scenarios match the current filters.',
 style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
 else
 ...topThree.map((scenario) {
 // locate persisted record id if any
 final match = ProjectDataHelper.getData(context)
 .frontEndPlanning
 .scenarioMatrixItems
 .firstWhere(
 (r) =>
 r.title == scenario.title &&
 r.detail == scenario.detail,
 orElse: () => ScenarioRecord(
 id: '',
 title: '',
 detail: '',
 category: '',
 owner: '',
 severity: 2,
 likelihood: 2));
 final isPersisted = match.id.isNotEmpty;
 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(scenario.title,
 style: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w700)),
 ),
 _ScorePill(score: scenario.score),
 const SizedBox(width: 8),
 if (isPersisted)
 IconButton(
 tooltip: 'Edit',
 onPressed: () {
 final rec = ProjectDataHelper.getData(context)
 .frontEndPlanning
 .scenarioMatrixItems
 .firstWhere((r) => r.id == match.id);
 _openEditDialog(context, record: rec);
 },
 icon: const Icon(Icons.edit, size: 18),
 ),
 if (isPersisted)
 IconButton(
 tooltip: 'Delete',
 onPressed: () async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (_) => AlertDialog(
 title: const Text('Delete scenario?'),
 content: const Text(
 'This will remove the scenario from the project.'),
 actions: [
 TextButton(
 onPressed: () =>
 Navigator.of(context)
 .pop(false),
 child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () =>
 Navigator.of(context)
 .pop(true),
 child: const Text('Delete'))
 ]));
 if (!mounted) return;
 if (confirmed == true) {
 await ProjectDataHelper.updateAndSave(
 context: super.context,
 checkpoint:
 'gap_analysis_scope_reconcillation',
 dataUpdater: (current) {
 final fep = current.frontEndPlanning;
 final updated = FrontEndPlanningData(
 requirements: fep.requirements,
 requirementsNotes:
 fep.requirementsNotes,
 risks: fep.risks,
 opportunities: fep.opportunities,
 contractVendorQuotes:
 fep.contractVendorQuotes,
 procurement: fep.procurement,
 security: fep.security,
 allowance: fep.allowance,
 summary: fep.summary,
 technology: fep.technology,
 personnel: fep.personnel,
 infrastructure: fep.infrastructure,
 contracts: fep.contracts,
 requirementItems: fep.requirementItems,
 technicalDebtItems:
 fep.technicalDebtItems,
 technicalDebtRootCauses:
 fep.technicalDebtRootCauses,
 technicalDebtTracks:
 fep.technicalDebtTracks,
 technicalDebtOwners:
 fep.technicalDebtOwners,
 scenarioMatrixItems: fep
 .scenarioMatrixItems
 .where((s) => s.id != match.id)
 .toList(),
 );
 return current.copyWith(
 frontEndPlanning: updated);
 });
 setState(() {});
 }
 },
 icon: const Icon(Icons.delete_outline, size: 18),
 ),
 ],
 ),
 const SizedBox(height: 6),
 Text(scenario.detail,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF475569))),
 const SizedBox(height: 8),
 Row(
 children: [
 _Tag(label: scenario.category),
 const SizedBox(width: 6),
 _Tag(label: scenario.owner),
 ],
 ),
 ],
 ),
 );
 }),
 const Spacer(),
 OutlinedButton.icon(
 onPressed: () {},
 icon: const Icon(Icons.ios_share_outlined, size: 16),
 label: const Text('Export matrix'),
 style: OutlinedButton.styleFrom(
 foregroundColor: const Color(0xFF111827),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 ),
 ),
 ],
 ),
 );
 }

 List<_ScenarioPoint> _buildScenarios() {
 final scenarios = <_ScenarioPoint>[];
 for (final impact in widget.impacts) {
 final severity = _severityFromRating(impact.rating);
 final likelihood = _likelihoodFromTrend(impact.trend);
 scenarios.add(
 _ScenarioPoint(
 title: '${impact.area} exposure',
 detail: impact.detail,
 category: 'Impact',
 owner: impact.area,
 severity: severity,
 likelihood: likelihood,
 ),
 );
 }
 for (final gap in widget.gaps) {
 final severity = _severityFromStage(gap.stage);
 final likelihood = severity;
 scenarios.add(
 _ScenarioPoint(
 title: gap.title,
 detail: gap.nextStep,
 category: 'Gap',
 owner: gap.owner,
 severity: severity,
 likelihood: likelihood,
 ),
 );
 }
 for (final plan in widget.plans) {
 final severity = _severityFromPlanStatus(plan.status);
 final likelihood = _likelihoodFromPlanStatus(plan.status);
 scenarios.add(
 _ScenarioPoint(
 title: plan.title,
 detail: '${plan.due} · ${plan.owner}',
 category: 'Plan',
 owner: plan.owner,
 severity: severity,
 likelihood: likelihood,
 ),
 );
 }
 return scenarios;
 }

 List<_ScenarioPoint> _filterScenarios(List<_ScenarioPoint> scenarios) {
 final query = _searchController.text.trim().toLowerCase();
 return scenarios.where((scenario) {
 final matchesCategory = _categoryFilters.contains('All') ||
 _categoryFilters.contains(scenario.category);
 final matchesQuery = query.isEmpty ||
 scenario.title.toLowerCase().contains(query) ||
 scenario.detail.toLowerCase().contains(query) ||
 scenario.owner.toLowerCase().contains(query);
 return matchesCategory && matchesQuery;
 }).toList();
 }

 Map<String, List<_ScenarioPoint>> _groupByCell(
 List<_ScenarioPoint> scenarios) {
 final map = <String, List<_ScenarioPoint>>{};
 for (final scenario in scenarios) {
 final key = _cellKey(scenario.severity - 1, scenario.likelihood - 1);
 map.putIfAbsent(key, () => []).add(scenario);
 }
 return map;
 }

 int _severityFromRating(String rating) {
 switch (rating.toLowerCase()) {
 case 'high':
 return 3;
 case 'medium':
 return 2;
 case 'low':
 return 1;
 default:
 return 2;
 }
 }

 int _severityFromStage(String stage) {
 switch (stage.toLowerCase()) {
 case 'critical':
 return 3;
 case 'moderate':
 return 2;
 case 'low':
 return 1;
 default:
 return 2;
 }
 }

 int _severityFromPlanStatus(String status) {
 switch (status.toLowerCase()) {
 case 'at risk':
 return 3;
 case 'in review':
 return 2;
 case 'not started':
 return 3;
 default:
 return 1;
 }
 }

 int _likelihoodFromTrend(String trend) {
 switch (trend.toLowerCase()) {
 case 'needs attention':
 return 3;
 case 'stable':
 return 2;
 case 'improving':
 return 1;
 default:
 return 2;
 }
 }

 int _likelihoodFromPlanStatus(String status) {
 switch (status.toLowerCase()) {
 case 'at risk':
 return 3;
 case 'in review':
 return 2;
 case 'not started':
 return 3;
 default:
 return 1;
 }
 }

 String _cellKey(int severityIndex, int likelihoodIndex) =>
 '$severityIndex-$likelihoodIndex';

 Color _cellTone(int severityIndex, int likelihoodIndex) {
 final score = (severityIndex + 1) * (likelihoodIndex + 1);
 if (score >= 7) return const Color(0xFFFEE2E2);
 if (score >= 4) return const Color(0xFFFEF3C7);
 return const Color(0xFFECFDF3);
 }
}

class _ScenarioPoint {
 const _ScenarioPoint({
 required this.title,
 required this.detail,
 required this.category,
 required this.owner,
 required this.severity,
 required this.likelihood,
 });

 final String title;
 final String detail;
 final String category;
 final String owner;
 final int severity;
 final int likelihood;

 int get score => severity * likelihood;
}

class _MatrixCell extends StatelessWidget {
 const _MatrixCell({required this.scenarios, required this.tone});

 final List<_ScenarioPoint> scenarios;
 final Color tone;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: tone,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text(
 '${scenarios.length} scenario${scenarios.length == 1 ? '' : 's'}',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937))),
 const Spacer(),
 if (scenarios.isNotEmpty)
 _ScorePill(
 score: scenarios
 .map((s) => s.score)
 .reduce((a, b) => a > b ? a : b)),
 ],
 ),
 const SizedBox(height: 8),
 Expanded(
 child: scenarios.isEmpty
 ? const Center(
 child:
 Text('—', style: TextStyle(color: Color(0xFF94A3B8))))
 : ListView.separated(
 physics: const NeverScrollableScrollPhysics(),
 itemCount: scenarios.length.clamp(0, 3),
 separatorBuilder: (_, __) => const SizedBox(height: 6),
 itemBuilder: (context, index) {
 final scenario = scenarios[index];
 return Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 8),
 decoration: BoxDecoration(
 color: Colors.white.withOpacity(0.8),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Row(
 children: [
 Expanded(
 child: Text(
 scenario.title,
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 ),
 const SizedBox(width: 6),
 _Tag(label: scenario.category),
 ],
 ),
 );
 },
 ),
 ),
 ],
 ),
 );
 }
}

class _AxisHeader extends StatelessWidget {
 const _AxisHeader({required this.label, this.isVertical = false});

 final String label;
 final bool isVertical;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Text(
 label,
 textAlign: isVertical ? TextAlign.right : TextAlign.center,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF475569)),
 ),
 );
 }
}

class _ScorePill extends StatelessWidget {
 const _ScorePill({required this.score});

 final int score;

 @override
 Widget build(BuildContext context) {
 Color color;
 if (score >= 7) {
 color = const Color(0xFFDC2626);
 } else if (score >= 4) {
 color = const Color(0xFFF59E0B);
 } else {
 color = const Color(0xFF10B981);
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text('Score $score',
 style: TextStyle(
 fontSize: 10, fontWeight: FontWeight.w700, color: color)),
 );
 }
}

class _Tag extends StatelessWidget {
 const _Tag({required this.label});

 final String label;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFF1F5F9),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(label,
 style: const TextStyle(
 fontSize: 10,
 fontWeight: FontWeight.w600,
 color: Color(0xFF475569))),
 );
 }
}

class _ReconciliationWorkflowCard extends StatefulWidget {
 const _ReconciliationWorkflowCard({
 required this.width,
 required this.steps,
 required this.onWorkflowUpdated,
 });

 final double width;
 final List<_WorkflowStep> steps;
 final ValueChanged<List<_WorkflowStep>> onWorkflowUpdated;

 @override
 State<_ReconciliationWorkflowCard> createState() =>
 _ReconciliationWorkflowCardState();
}

class _ReconciliationWorkflowCardState
 extends State<_ReconciliationWorkflowCard> {
 static const _columns = [
 _WorkflowBoardColumnConfig(
 keyName: 'planned',
 label: 'Planned',
 accent: Color(0xFF94A3B8),
 ),
 _WorkflowBoardColumnConfig(
 keyName: 'active',
 label: 'Active',
 accent: Color(0xFF2563EB),
 ),
 _WorkflowBoardColumnConfig(
 keyName: 'in_progress',
 label: 'In Progress',
 accent: Color(0xFFF59E0B),
 ),
 _WorkflowBoardColumnConfig(
 keyName: 'ongoing',
 label: 'Ongoing',
 accent: Color(0xFF10B981),
 ),
 _WorkflowBoardColumnConfig(
 keyName: 'complete',
 label: 'Complete',
 accent: Color(0xFF16A34A),
 ),
 ];

 late Map<String, List<_WorkflowStep>> _grouped;

 @override
 void initState() {
 super.initState();
 _grouped = _buildGrouped(widget.steps);
 }

 @override
 void didUpdateWidget(covariant _ReconciliationWorkflowCard oldWidget) {
 super.didUpdateWidget(oldWidget);
 if (oldWidget.steps != widget.steps) {
 _grouped = _buildGrouped(widget.steps);
 }
 }

 String _statusKey(String status) {
 final value = status.toLowerCase();
 if (value.contains('ongoing')) return 'ongoing';
 if (value.contains('active')) return 'active';
 if (value.contains('progress')) return 'in_progress';
 if (value.contains('complete') || value.contains('done')) return 'complete';
 if (value.contains('review')) return 'review';
 return 'planned';
 }

 Map<String, List<_WorkflowStep>> _buildGrouped(List<_WorkflowStep> steps) {
 final grouped = <String, List<_WorkflowStep>>{};
 for (final step in steps) {
 final key = _statusKey(step.status);
 grouped.putIfAbsent(key, () => []).add(step);
 }
 return grouped;
 }

 Future<void> _openAddWorkflowItem() async {
 final titleController = TextEditingController();
 final descController = TextEditingController();
 String status = _columns.first.label;

 final result = await showDialog<_WorkflowStep>(
 context: context,
 builder: (context) {
 return AlertDialog(
 title: const Text('Add workflow item'),
 content: SizedBox(
 width: 420,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 VoiceTextField(
 controller: titleController,
 decoration: const InputDecoration(labelText: 'Title'),
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: descController,
 maxLines: 3,
 decoration: const InputDecoration(labelText: 'Description'),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: status,
 items: _columns
 .map((col) => DropdownMenuItem<String>(
 value: col.label,
 child: Text(col.label),
 ))
 .toList(),
 onChanged: (value) {
 if (value != null) {
 status = value;
 }
 },
 decoration: const InputDecoration(labelText: 'Status'),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(context).pop(),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () {
 final title = titleController.text.trim();
 if (title.isEmpty) {
 return;
 }
 Navigator.of(context).pop(
 _WorkflowStep(
 label: title,
 status: status,
 description: descController.text.trim().isEmpty
 ? 'Define workflow details.'
 : descController.text.trim(),
 ),
 );
 },
 child: const Text('Add'),
 ),
 ],
 );
 },
 );

 if (result == null) return;
 setState(() {
 _grouped = _buildGrouped([..._grouped.values.expand((e) => e), result]);
 });
 final updatedList = <_WorkflowStep>[];
 for (final column in _columns) {
 updatedList.addAll(_grouped[column.keyName] ?? const []);
 }
 widget.onWorkflowUpdated(updatedList);
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);

 return _SectionShell(
 width: widget.width,
 title: 'Reconciliation workflow & backlog',
 subtitle:
 'Track the lifecycle of gap discovery through launch readiness.',
 trailing: TextButton.icon(
 onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Workflow board is shown below in the Reconciliation workflow section.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 },
 icon: const Icon(Icons.view_kanban_outlined),
 label: const Text('Open workflow board'),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (widget.steps.isEmpty)
 const _EmptyPanel(label: 'No workflow items yet.'),
 if (widget.steps.isNotEmpty) ...[
 const Text(
 'Open workflow board',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 12),
 LayoutBuilder(
 builder: (context, constraints) {
 final double availWidth = constraints.maxWidth;
 final int colCount = _columns.length;
 const double spacing = 12;
 final double colWidth =
 (availWidth - (spacing * (colCount - 1))) / colCount;
 return Wrap(
 spacing: spacing,
 runSpacing: spacing,
 children: _columns.map((column) {
 final items =
 _grouped[column.keyName] ?? const <_WorkflowStep>[];
 return SizedBox(
 width: isMobile ? double.infinity : colWidth,
 child: _WorkflowBoardColumn(
 label: column.label,
 accent: column.accent,
 items: items,
 onAccept: (step) {
 setState(() {
 for (final list in _grouped.values) {
 list.removeWhere((item) =>
 item.label == step.label &&
 item.description == step.description);
 }
 final updated = _WorkflowStep(
 label: step.label,
 status: column.label,
 description: step.description,
 );
 _grouped
 .putIfAbsent(column.keyName, () => [])
 .add(updated);
 });
 final updatedList = <_WorkflowStep>[];
 for (final column in _columns) {
 updatedList
 .addAll(_grouped[column.keyName] ?? const []);
 }
 widget.onWorkflowUpdated(updatedList);
 },
 onDelete: (step) {
 setState(() {
 for (final list in _grouped.values) {
 list.removeWhere((item) =>
 item.label == step.label &&
 item.description == step.description);
 }
 });
 final updatedList = <_WorkflowStep>[];
 for (final column in _columns) {
 updatedList
 .addAll(_grouped[column.keyName] ?? const []);
 }
 widget.onWorkflowUpdated(updatedList);
 },
 ),
 );
 }).toList(),
 );
 },
 ),
 const SizedBox(height: 12),
 ],
 Align(
 alignment: Alignment.centerLeft,
 child: TextButton.icon(
 onPressed: _openAddWorkflowItem,
 icon: const Icon(Icons.add_circle_outline),
 label: const Text('Add workflow item'),
 ),
 ),
 ],
 ),
 );
 }
}

class _WorkflowBoardColumnConfig {
 const _WorkflowBoardColumnConfig({
 required this.keyName,
 required this.label,
 required this.accent,
 });

 final String keyName;
 final String label;
 final Color accent;
}

class _WorkflowBoardColumn extends StatelessWidget {
 const _WorkflowBoardColumn({
 required this.label,
 required this.accent,
 required this.items,
 required this.onAccept,
 required this.onDelete,
 });

 final String label;
 final Color accent;
 final List<_WorkflowStep> items;
 final ValueChanged<_WorkflowStep> onAccept;
 final ValueChanged<_WorkflowStep> onDelete;

 @override
 Widget build(BuildContext context) {
 return DragTarget<_WorkflowStep>(
 onWillAcceptWithDetails: (_) => true,
 onAcceptWithDetails: (details) => onAccept(details.data),
 builder: (context, candidateData, rejectedData) {
 final isActive = candidateData.isNotEmpty;
 return AnimatedContainer(
 duration: const Duration(milliseconds: 150),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: isActive
 ? accent.withOpacity(0.08)
 : const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(16),
 border:
 Border.all(color: isActive ? accent : const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 8,
 height: 8,
 decoration:
 BoxDecoration(color: accent, shape: BoxShape.circle),
 ),
 const SizedBox(width: 8),
 Text(
 label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const Spacer(),
 Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: accent.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 '${items.length}',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: accent),
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 if (items.isEmpty && !isActive)
 const Text(
 'No items yet',
 style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
 ),
 if (items.isEmpty && isActive)
 const Text(
 'Drop here',
 style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 if (items.isNotEmpty)
 ...items.map(
 (item) => _DraggableWorkflowCard(
 step: item,
 accent: accent,
 onDelete: onDelete,
 ),
 ),
 ],
 ),
 );
 },
 );
 }
}

class _DraggableWorkflowCard extends StatelessWidget {
 const _DraggableWorkflowCard({
 required this.step,
 required this.accent,
 required this.onDelete,
 });

 final _WorkflowStep step;
 final Color accent;
 final ValueChanged<_WorkflowStep> onDelete;

 @override
 Widget build(BuildContext context) {
 final card = _WorkflowBoardCard(
 label: step.label,
 description: step.description,
 accent: accent,
 onDelete: () => onDelete(step),
 );
 return LongPressDraggable<_WorkflowStep>(
 data: step,
 feedback: Material(
 color: Colors.transparent,
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 240),
 child: card,
 ),
 ),
 childWhenDragging: Opacity(opacity: 0.4, child: card),
 child: card,
 );
 }
}

class _WorkflowBoardCard extends StatelessWidget {
 const _WorkflowBoardCard({
 required this.label,
 required this.description,
 required this.accent,
 required this.onDelete,
 });

 final String label;
 final String description;
 final Color accent;
 final VoidCallback onDelete;

 @override
 Widget build(BuildContext context) {
 return Container(
 margin: const EdgeInsets.only(bottom: 10),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 4)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Expanded(
 child: Text(
 label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 ),
 IconButton(
 onPressed: onDelete,
 icon: const Icon(Icons.delete_outline,
 size: 16, color: Color(0xFFEF4444)),
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(),
 splashRadius: 18,
 tooltip: 'Delete card',
 ),
 Container(
 width: 6,
 height: 18,
 decoration: BoxDecoration(
 color: accent.withOpacity(0.5),
 borderRadius: BorderRadius.circular(999),
 ),
 ),
 ],
 ),
 const SizedBox(height: 6),
 Text(
 description,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF4B5563), height: 1.35),
 ),
 ],
 ),
 );
 }
}

class _LessonsLearnedCard extends StatelessWidget {
 const _LessonsLearnedCard({
 required this.width,
 required this.lessons,
 required this.onLessonsUpdated,
 });

 final double width;
 final List<String> lessons;
 final ValueChanged<List<String>> onLessonsUpdated;

 @override
 Widget build(BuildContext context) {
 return _SectionShell(
 width: width,
 title: 'Lessons learned & prevention',
 subtitle:
 'Document leading indicators and preventative practices for future launches.',
 trailing: TextButton.icon(
 onPressed: () {
 onLessonsUpdated([...lessons, 'New follow-up insight — click to edit']);
 },
 icon: const Icon(Icons.history_edu_outlined),
 label: const Text('Log follow-up insight'),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (lessons.isEmpty)
 const _EmptyPanel(label: 'No lessons captured yet.')
 else
 ...lessons.asMap().entries.map(
 (entry) => Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Padding(
 padding: EdgeInsets.only(top: 6),
 child: Icon(Icons.check_circle,
 size: 18, color: Color(0xFF22C55E)),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: VoiceTextFormField(
 key: ValueKey('lesson-${entry.key}'),
 initialValue: entry.value,
 decoration: _inputDecoration('Lesson learned'),
 maxLines: 2,
 onChanged: (value) =>
 _updateLesson(entry.key, value),
 ),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline,
 color: Color(0xFFEF4444)),
 onPressed: () => _deleteLesson(entry.key),
 ),
 ],
 ),
 ),
 ),
 const SizedBox(height: 8),
 TextButton.icon(
 onPressed: _addLesson,
 icon: const Icon(Icons.add_circle_outline),
 label: const Text('Add lesson'),
 ),
 ],
 ),
 );
 }

 void _addLesson() {
 final updated = [...lessons, ''];
 onLessonsUpdated(updated);
 }

 void _updateLesson(int index, String value) {
 final updated = [...lessons];
 updated[index] = value;
 onLessonsUpdated(updated);
 }

 void _deleteLesson(int index) {
 final updated = [...lessons]..removeAt(index);
 onLessonsUpdated(updated);
 }
}

class _EmptyPanel extends StatelessWidget {
 const _EmptyPanel({required this.label});

 final String label;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 const Icon(Icons.info_outline, size: 18, color: Color(0xFF9CA3AF)),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 label,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280)),
 ),
 ),
 ],
 ),
 );
 }
}

class _SectionShell extends StatelessWidget {
 const _SectionShell({
 required this.width,
 required this.title,
 required this.subtitle,
 required this.child,
 this.trailing,
 });

 final double width;
 final String title;
 final String subtitle;
 final Widget child;
 final Widget? trailing;

 @override
 Widget build(BuildContext context) {
 final content = Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 6),
 Text(
 subtitle,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 if (trailing != null)
 Padding(
 padding: const EdgeInsets.only(left: 12),
 child: trailing!,
 ),
 ],
 ),
 const SizedBox(height: 18),
 child,
 ],
 );

 return Container(
 width: width,
 constraints: BoxConstraints(minWidth: width, maxWidth: width),
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.05),
 blurRadius: 20,
 offset: const Offset(0, 12)),
 ],
 ),
 child: content,
 );
 }
}

class _InfoChip extends StatelessWidget {
 const _InfoChip({required this.data, required this.isCompact});

 final _InfoChipData data;
 final bool isCompact;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withOpacity(0.04),
 blurRadius: 14,
 offset: const Offset(0, 12)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 data.label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 6),
 Text(
 data.value,
 style: TextStyle(
 fontSize: isCompact ? 13 : 14,
 fontWeight: FontWeight.w600,
 color: const Color(0xFF1F2937)),
 ),
 ],
 ),
 );
 }
}

// ignore: unused_element
class _GapTitleCell extends StatelessWidget {
 const _GapTitleCell({required this.entry});

 final _GapEntry entry;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 entry.id,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 4),
 Text(
 entry.title,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: Color(0xFF1F2937)),
 ),
 ],
 );
 }
}

// ignore: unused_element
class _PriorityBadge extends StatelessWidget {
 const _PriorityBadge({required this.label});

 final String label;

 Color _badgeColor() {
 switch (label.toLowerCase()) {
 case 'critical':
 return const Color(0xFFFECACA);
 case 'moderate':
 return const Color(0xFFFDE68A);
 case 'low':
 return const Color(0xFFCFFAFE);
 default:
 return const Color(0xFFE0E7FF);
 }
 }

 Color _textColor() {
 switch (label.toLowerCase()) {
 case 'critical':
 return const Color(0xFFB91C1C);
 case 'moderate':
 return const Color(0xFFB45309);
 case 'low':
 return const Color(0xFF0F766E);
 default:
 return const Color(0xFF3730A3);
 }
 }

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: _badgeColor(), borderRadius: BorderRadius.circular(30)),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 12, fontWeight: FontWeight.w700, color: _textColor()),
 ),
 );
 }
}

// ignore: unused_element
class _StatusBadge extends StatelessWidget {
 const _StatusBadge({required this.label});

 final String label;

 Color _statusColor() {
 switch (label.toLowerCase()) {
 case 'on track':
 return const Color(0xFF16A34A);
 case 'at risk':
 return const Color(0xFFF97316);
 case 'in review':
 return const Color(0xFF2563EB);
 case 'not started':
 return const Color(0xFF4B5563);
 case 'complete':
 return const Color(0xFF0F766E);
 case 'upcoming':
 return const Color(0xFF6366F1);
 case 'planned':
 return const Color(0xFF5B21B6);
 default:
 return const Color(0xFF111827);
 }
 }

 @override
 Widget build(BuildContext context) {
 final color = _statusColor();
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(30)),
 child: Text(
 label,
 style:
 TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
 ),
 );
 }
}

// ignore: unused_element
class _TrendPill extends StatelessWidget {
 const _TrendPill({required this.label});

 final String label;

 Color _trendColor() {
 switch (label.toLowerCase()) {
 case 'improving':
 return const Color(0xFF16A34A);
 case 'stable':
 return const Color(0xFF2563EB);
 case 'needs attention':
 return const Color(0xFFDC2626);
 default:
 return const Color(0xFF4B5563);
 }
 }

 @override
 Widget build(BuildContext context) {
 final color = _trendColor();
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(30)),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 label.toLowerCase() == 'needs attention'
 ? Icons.warning_amber_outlined
 : Icons.trending_up,
 size: 16,
 color: color,
 ),
 const SizedBox(width: 6),
 Text(
 label,
 style: TextStyle(
 fontSize: 12, fontWeight: FontWeight.w700, color: color),
 ),
 ],
 ),
 );
 }
}

class _Pill extends StatelessWidget {
 const _Pill({required this.label, required this.color});

 final String label;
 final Color color;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(16)),
 child: Text(
 label,
 style:
 TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
 ),
 );
 }
}

class _InfoChipData {
 const _InfoChipData({required this.label, required this.value});

 final String label;
 final String value;
}

class _SummaryCardData {
 const _SummaryCardData({
 required this.title,
 required this.headline,
 required this.annotation,
 required this.accentColor,
 required this.icon,
 required this.bullets,
 this.progress,
 });

 final String title;
 final String headline;
 final String annotation;
 final Color accentColor;
 final IconData icon;
 final List<String> bullets;
 final double? progress;
}

class _GapEntry {
 const _GapEntry({
 required this.uid,
 required this.id,
 required this.title,
 required this.stage,
 required this.owner,
 required this.nextStep,
 this.category = 'Scope',
 this.impactArea = '',
 this.targetDate = '',
 this.evidence = '',
 this.severity = 'Medium',
 });

 final String uid;
 final String id;
 final String title;
 final String stage;
 final String owner;
 final String nextStep;
 final String category;
 final String impactArea;
 final String targetDate;
 final String evidence;
 final String severity;

 _GapEntry copyWith({
 String? uid,
 String? id,
 String? title,
 String? stage,
 String? owner,
 String? nextStep,
 String? category,
 String? impactArea,
 String? targetDate,
 String? evidence,
 String? severity,
 }) {
 return _GapEntry(
 uid: uid ?? this.uid,
 id: id ?? this.id,
 title: title ?? this.title,
 stage: stage ?? this.stage,
 owner: owner ?? this.owner,
 nextStep: nextStep ?? this.nextStep,
 category: category ?? this.category,
 impactArea: impactArea ?? this.impactArea,
 targetDate: targetDate ?? this.targetDate,
 evidence: evidence ?? this.evidence,
 severity: severity ?? this.severity,
 );
 }

 Map<String, dynamic> toJson() => {
 'uid': uid,
 'id': id,
 'title': title,
 'stage': stage,
 'owner': owner,
 'nextStep': nextStep,
 'category': category,
 'impactArea': impactArea,
 'targetDate': targetDate,
 'evidence': evidence,
 'severity': severity,
 };

 factory _GapEntry.fromJson(Map<String, dynamic> json) {
 return _GapEntry(
 uid: json['uid']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 id: json['id']?.toString() ?? '',
 title: json['title']?.toString() ?? '',
 stage: json['stage']?.toString() ?? 'Moderate',
 owner: json['owner']?.toString() ?? '',
 nextStep: json['nextStep']?.toString() ?? '',
 category: json['category']?.toString() ?? 'Scope',
 impactArea: json['impactArea']?.toString() ?? '',
 targetDate: json['targetDate']?.toString() ?? '',
 evidence: json['evidence']?.toString() ?? '',
 severity: json['severity']?.toString() ?? 'Medium',
 );
 }
}

class _PlanEntry {
 const _PlanEntry({
 required this.id,
 required this.title,
 required this.due,
 required this.owner,
 required this.status,
 this.phase = 'Execution',
 this.gapReference = '',
 this.dependency = '',
 this.completionPct,
 this.notes = '',
 });

 final String id;
 final String title;
 final String due;
 final String owner;
 final String status;
 final String phase;
 final String gapReference;
 final String dependency;
 final int? completionPct;
 final String notes;

 _PlanEntry copyWith({
 String? title,
 String? due,
 String? owner,
 String? status,
 String? phase,
 String? gapReference,
 String? dependency,
 int? completionPct,
 String? notes,
 }) {
 return _PlanEntry(
 id: id,
 title: title ?? this.title,
 due: due ?? this.due,
 owner: owner ?? this.owner,
 status: status ?? this.status,
 phase: phase ?? this.phase,
 gapReference: gapReference ?? this.gapReference,
 dependency: dependency ?? this.dependency,
 completionPct: completionPct ?? this.completionPct,
 notes: notes ?? this.notes,
 );
 }

 Map<String, dynamic> toJson() => {
 'id': id,
 'title': title,
 'due': due,
 'owner': owner,
 'status': status,
 'phase': phase,
 'gapReference': gapReference,
 'dependency': dependency,
 'completionPct': completionPct,
 'notes': notes,
 };

 factory _PlanEntry.fromJson(Map<String, dynamic> json) {
 return _PlanEntry(
 id: json['id']?.toString() ?? '',
 title: json['title']?.toString() ?? '',
 due: json['due']?.toString() ?? '',
 owner: json['owner']?.toString() ?? '',
 status: json['status']?.toString() ?? 'Not started',
 phase: json['phase']?.toString() ?? 'Execution',
 gapReference: json['gapReference']?.toString() ?? '',
 dependency: json['dependency']?.toString() ?? '',
 completionPct: json['completionPct'] is int
 ? json['completionPct'] as int
 : null,
 notes: json['notes']?.toString() ?? '',
 );
 }
}

class _ImpactRow {
 const _ImpactRow({
 required this.id,
 required this.area,
 required this.rating,
 required this.trend,
 required this.detail,
 this.domain = 'Schedule',
 this.affectedDeliverable = '',
 this.financialExposure = '',
 this.owner = '',
 this.mitigationLink = '',
 });

 final String id;
 final String area;
 final String rating;
 final String trend;
 final String detail;
 final String domain;
 final String affectedDeliverable;
 final String financialExposure;
 final String owner;
 final String mitigationLink;

 Map<String, dynamic> toJson() => {
 'id': id,
 'area': area,
 'rating': rating,
 'trend': trend,
 'detail': detail,
 'domain': domain,
 'affectedDeliverable': affectedDeliverable,
 'financialExposure': financialExposure,
 'owner': owner,
 'mitigationLink': mitigationLink,
 };

 factory _ImpactRow.fromJson(Map<String, dynamic> json) {
 return _ImpactRow(
 id: json['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 area: json['area']?.toString() ?? '',
 rating: json['rating']?.toString() ?? 'Medium',
 trend: json['trend']?.toString() ?? 'Stable',
 detail: json['detail']?.toString() ?? '',
 domain: json['domain']?.toString() ?? 'Schedule',
 affectedDeliverable: json['affectedDeliverable']?.toString() ?? '',
 financialExposure: json['financialExposure']?.toString() ?? '',
 owner: json['owner']?.toString() ?? '',
 mitigationLink: json['mitigationLink']?.toString() ?? '',
 );
 }

 _ImpactRow copyWith({
 String? area,
 String? rating,
 String? trend,
 String? detail,
 String? domain,
 String? affectedDeliverable,
 String? financialExposure,
 String? owner,
 String? mitigationLink,
 }) {
 return _ImpactRow(
 id: id,
 area: area ?? this.area,
 rating: rating ?? this.rating,
 trend: trend ?? this.trend,
 detail: detail ?? this.detail,
 domain: domain ?? this.domain,
 affectedDeliverable: affectedDeliverable ?? this.affectedDeliverable,
 financialExposure: financialExposure ?? this.financialExposure,
 owner: owner ?? this.owner,
 mitigationLink: mitigationLink ?? this.mitigationLink,
 );
 }

 factory _ImpactRow.fromLaunchEntry(Map<String, dynamic> json) {
 final title = (json['title'] ?? '').toString().trim();
 final detail = (json['details'] ?? '').toString().trim();
 final status = (json['status'] ?? '').toString().trim();
 var rating = 'Medium';
 var trend = 'Stable';
 if (status.isNotEmpty) {
 final parts = status
 .split(RegExp(r'[|/,-]'))
 .map((part) => part.trim())
 .where((part) => part.isNotEmpty)
 .toList();
 if (parts.length >= 2) {
 rating = parts[0];
 trend = parts[1];
 } else if (parts.length == 1) {
 rating = parts[0];
 }
 }
 return _ImpactRow(
 id: DateTime.now().microsecondsSinceEpoch.toString(),
 area: title,
 rating: rating,
 trend: trend,
 detail: detail.isEmpty ? 'Update impact details.' : detail,
 );
 }
}

class _RootCauseItem {
 const _RootCauseItem({
 required this.id,
 required this.text,
 this.category = 'Process',
 this.methodology = '5 Whys',
 this.frequency = '',
 this.impact = 'Medium',
 this.recommendation = '',
 this.status = 'Open',
 });

 final String id;
 final String text;
 final String category;
 final String methodology;
 final String frequency;
 final String impact;
 final String recommendation;
 final String status;

 _RootCauseItem copyWith({
 String? text,
 String? category,
 String? methodology,
 String? frequency,
 String? impact,
 String? recommendation,
 String? status,
 }) {
 return _RootCauseItem(
 id: id,
 text: text ?? this.text,
 category: category ?? this.category,
 methodology: methodology ?? this.methodology,
 frequency: frequency ?? this.frequency,
 impact: impact ?? this.impact,
 recommendation: recommendation ?? this.recommendation,
 status: status ?? this.status,
 );
 }

 Map<String, dynamic> toJson() => {
 'id': id,
 'text': text,
 'category': category,
 'methodology': methodology,
 'frequency': frequency,
 'impact': impact,
 'recommendation': recommendation,
 'status': status,
 };

 factory _RootCauseItem.fromJson(Map<String, dynamic> json) {
 return _RootCauseItem(
 id: json['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 text: json['text']?.toString() ?? '',
 category: json['category']?.toString() ?? 'Process',
 methodology: json['methodology']?.toString() ?? '5 Whys',
 frequency: json['frequency']?.toString() ?? '',
 impact: json['impact']?.toString() ?? 'Medium',
 recommendation: json['recommendation']?.toString() ?? '',
 status: json['status']?.toString() ?? 'Open',
 );
 }
}

class _WorkflowStep {
 const _WorkflowStep(
 {required this.label, required this.status, required this.description});

 final String label;
 final String status;
 final String description;

 Map<String, dynamic> toJson() => {
 'label': label,
 'status': status,
 'description': description,
 };

 factory _WorkflowStep.fromJson(Map<String, dynamic> json) {
 return _WorkflowStep(
 label: json['label']?.toString() ?? '',
 status: json['status']?.toString() ?? 'Planned',
 description: json['description']?.toString() ?? '',
 );
 }

 factory _WorkflowStep.fromLaunchEntry(Map<String, dynamic> json) {
 final label = (json['title'] ?? '').toString().trim();
 final description = (json['details'] ?? '').toString().trim();
 final status = (json['status'] ?? '').toString().trim();
 return _WorkflowStep(
 label: label,
 status: status.isEmpty ? 'Planned' : status,
 description:
 description.isEmpty ? 'Define workflow details.' : description,
 );
 }
}

InputDecoration _inputDecoration(String hintText, {bool dense = false}) {
 return InputDecoration(
 hintText: hintText,
 isDense: dense,
 filled: true,
 fillColor: Colors.white,
 contentPadding: EdgeInsets.symmetric(
 horizontal: 12,
 vertical: dense ? 8 : 12,
 ),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Color(0xFF93C5FD)),
 ),
 );
}

class _Debouncer {
 _Debouncer({Duration? delay})
 : delay = delay ?? const Duration(milliseconds: 600);

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
