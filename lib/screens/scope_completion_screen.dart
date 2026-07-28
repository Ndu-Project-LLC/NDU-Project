import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/screens/gap_analysis_scope_reconcillation_screen.dart';
import 'package:ndu_project/screens/risk_tracking_workspace_screen.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/launch_editable_section.dart';
import 'package:ndu_project/widgets/launch_modal.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
class ScopeCompletionScreen extends StatefulWidget {
 const ScopeCompletionScreen({super.key});

 static void open(BuildContext context) {
 context.push('/${AppRoutes.scopeCompletion}');
 }

 @override
 State<ScopeCompletionScreen> createState() => _ScopeCompletionScreenState();
}

class _ScopeCompletionScreenState extends State<ScopeCompletionScreen> {
 final TextEditingController _overviewController = TextEditingController();
 final TextEditingController _statusSummaryController =
 TextEditingController();
 final TextEditingController _sponsorSummaryController =
 TextEditingController();
 final TextEditingController _changeSummaryController =
 TextEditingController();

 final TextEditingController _deliveredPercentController =
 TextEditingController();
 final TextEditingController _deliveredStatusController =
 TextEditingController();
 final TextEditingController _deferredCountController =
 TextEditingController();
 final TextEditingController _deferredStatusController =
 TextEditingController();
 final TextEditingController _criticalGapCountController =
 TextEditingController();
 final TextEditingController _criticalGapStatusController =
 TextEditingController();

 final TextEditingController _approvedChangesController =
 TextEditingController();
 final TextEditingController _unapprovedChangesController =
 TextEditingController();
 final TextEditingController _openRequestsController = TextEditingController();

 final List<_WorkPackageItem> _workPackages = [];
 final List<_CheckpointItem> _acceptanceCheckpoints = [];
 final List<_AcceptanceTagItem> _acceptanceTags = [];
 final List<_ScopeChangeItem> _scopeChanges = [];

 final _Debouncer _saveDebouncer = _Debouncer();
 bool _isLoading = false;
 bool _suspendSave = false;
 bool _autoGenerationTriggered = false;
 bool _isAutoGenerating = false;

 static const List<String> _workStatuses = [
 'Delivered',
 'Partially delivered',
 'Deferred',
 'Not started'
 ];
 static const List<String> _impactLevels = [
 'Critical',
 'High',
 'Medium',
 'Low'
 ];
 static const List<String> _checkpointStatuses = [
 'Pending',
 'Aligned',
 'Blocked',
 'Waived'
 ];
 static const List<String> _signalCategories = [
 'Sponsor',
 'Operations',
 'Technical',
 'Regulatory',
 ];
 static const List<String> _changeTypes = [
 'Scope',
 'Budget',
 'Schedule',
 'Quality'
 ];
 static const List<String> _changeStatuses = [
 'Open',
 'Approved',
 'Rejected',
 'Deferred'
 ];

 @override
 void initState() {
 super.initState();
 _registerListeners();
 WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromFirestore());
 }

 @override
 void dispose() {
 _overviewController.dispose();
 _statusSummaryController.dispose();
 _sponsorSummaryController.dispose();
 _changeSummaryController.dispose();
 _deliveredPercentController.dispose();
 _deliveredStatusController.dispose();
 _deferredCountController.dispose();
 _deferredStatusController.dispose();
 _criticalGapCountController.dispose();
 _criticalGapStatusController.dispose();
 _approvedChangesController.dispose();
 _unapprovedChangesController.dispose();
 _openRequestsController.dispose();
 _saveDebouncer.dispose();
 super.dispose();
 }

 String? _projectId() => ProjectDataHelper.getData(context).projectId;

 void _registerListeners() {
 final controllers = [
 _overviewController,
 _statusSummaryController,
 _sponsorSummaryController,
 _changeSummaryController,
 _deliveredPercentController,
 _deliveredStatusController,
 _deferredCountController,
 _deferredStatusController,
 _criticalGapCountController,
 _criticalGapStatusController,
 _approvedChangesController,
 _unapprovedChangesController,
 _openRequestsController,
 ];
 for (final controller in controllers) {
 controller.addListener(_scheduleSave);
 }
 }

 void _scheduleSave() {
 if (_suspendSave) return;
 _saveDebouncer.run(_saveToFirestore);
 }

 Future<void> _loadFromFirestore() async {
 final projectId = _projectId();
 if (projectId == null || projectId.isEmpty) return;
 if (!mounted) return;
 setState(() => _isLoading = true);
 try {
 final doc = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('execution_phase_sections')
 .doc('scope_completion')
 .get();
 final data = doc.data() ?? {};
 final metrics = Map<String, dynamic>.from(data['metrics'] ?? {});
 final packages = _WorkPackageItem.fromList(data['workPackages']);
 final checkpoints =
 _CheckpointItem.fromList(data['acceptanceCheckpoints']);
 final tags = _AcceptanceTagItem.fromList(data['acceptanceTags']);
 final changes = _ScopeChangeItem.fromList(data['scopeChanges']);

 final hasContent = _hasText(data['overview']) ||
 _hasText(data['statusSummary']) ||
 _hasText(data['sponsorSummary']) ||
 _hasText(data['changeSummary']) ||
 packages.isNotEmpty ||
 checkpoints.isNotEmpty ||
 tags.isNotEmpty ||
 changes.isNotEmpty ||
 _hasText(metrics['deliveredPercent']) ||
 _hasText(metrics['deliveredStatus']) ||
 _hasText(metrics['deferredCount']) ||
 _hasText(metrics['deferredStatus']) ||
 _hasText(metrics['criticalGapCount']) ||
 _hasText(metrics['criticalGapStatus']) ||
 _hasText(metrics['approvedChanges']) ||
 _hasText(metrics['unapprovedChanges']) ||
 _hasText(metrics['openRequests']);

 _suspendSave = true;
 _overviewController.text = data['overview']?.toString() ?? '';
 _statusSummaryController.text = data['statusSummary']?.toString() ?? '';
 _sponsorSummaryController.text = data['sponsorSummary']?.toString() ?? '';
 _changeSummaryController.text = data['changeSummary']?.toString() ?? '';
 _deliveredPercentController.text =
 metrics['deliveredPercent']?.toString() ?? '';
 _deliveredStatusController.text =
 metrics['deliveredStatus']?.toString() ?? '';
 _deferredCountController.text =
 metrics['deferredCount']?.toString() ?? '';
 _deferredStatusController.text =
 metrics['deferredStatus']?.toString() ?? '';
 _criticalGapCountController.text =
 metrics['criticalGapCount']?.toString() ?? '';
 _criticalGapStatusController.text =
 metrics['criticalGapStatus']?.toString() ?? '';
 _approvedChangesController.text =
 metrics['approvedChanges']?.toString() ?? '';
 _unapprovedChangesController.text =
 metrics['unapprovedChanges']?.toString() ?? '';
 _openRequestsController.text = metrics['openRequests']?.toString() ?? '';
 _suspendSave = false;

 if (!mounted) return;
 setState(() {
 _workPackages
 ..clear()
 ..addAll(packages);
 _acceptanceCheckpoints
 ..clear()
 ..addAll(checkpoints);
 _acceptanceTags
 ..clear()
 ..addAll(tags);
 _scopeChanges
 ..clear()
 ..addAll(changes);
 });
 if (!hasContent) {
 await _populateFromAi();
 }
 } catch (error) {
 debugPrint('Scope Completion load error: $error');
 } finally {
 if (mounted) {
 setState(() => _isLoading = false);
 }
 }
 }

 Future<void> _saveToFirestore() async {
 final projectId = _projectId();
 if (projectId == null || projectId.isEmpty) return;
 try {
 await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('execution_phase_sections')
 .doc('scope_completion')
 .set({
 'overview': _overviewController.text.trim(),
 'statusSummary': _statusSummaryController.text.trim(),
 'sponsorSummary': _sponsorSummaryController.text.trim(),
 'changeSummary': _changeSummaryController.text.trim(),
 'metrics': {
 'deliveredPercent': _deliveredPercentController.text.trim(),
 'deliveredStatus': _deliveredStatusController.text.trim(),
 'deferredCount': _deferredCountController.text.trim(),
 'deferredStatus': _deferredStatusController.text.trim(),
 'criticalGapCount': _criticalGapCountController.text.trim(),
 'criticalGapStatus': _criticalGapStatusController.text.trim(),
 'approvedChanges': _approvedChangesController.text.trim(),
 'unapprovedChanges': _unapprovedChangesController.text.trim(),
 'openRequests': _openRequestsController.text.trim(),
 },
 'workPackages': _workPackages.map((e) => e.toMap()).toList(),
 'acceptanceCheckpoints':
 _acceptanceCheckpoints.map((e) => e.toMap()).toList(),
 'acceptanceTags': _acceptanceTags.map((e) => e.toMap()).toList(),
 'scopeChanges': _scopeChanges.map((e) => e.toMap()).toList(),
 'updatedAt': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));
 } catch (error) {
 debugPrint('Scope Completion save error: $error');
 }
 }

 bool _hasText(dynamic value) =>
 value != null && value.toString().trim().isNotEmpty;

 Future<void> _populateFromAi() async {
 if (_autoGenerationTriggered || _isAutoGenerating) return;
 _autoGenerationTriggered = true;
 final generated = await ExecutionPhaseAiSeed.generateEntries(
 context: context,
 section: 'Scope Completion',
 sections: const {
 'overview': 'Scope completion overview summary',
 'status_summary':
 'Completion narrative with delivered scope, deferrals, and gaps',
 'sponsor_summary': 'Sponsor acceptance summary and sign-off status',
 'change_summary': 'Key scope change summary',
 'work_packages': 'Key work packages with owner, milestone, status',
 'acceptance_checkpoints': 'Acceptance checkpoints with owners',
 'acceptance_tags': 'Acceptance tags and readiness status',
 'scope_changes': 'Most impactful scope changes',
 'metrics':
 'Metrics such as percent delivered, deferred count, critical gaps',
 },
 itemsPerSection: 4,
 );

 if (!mounted) return;
 if (_isAutoGenerating) return;
 setState(() => _isAutoGenerating = true);

 final workPackages = _mapWorkPackages(generated['work_packages']);
 final checkpoints = _mapCheckpoints(generated['acceptance_checkpoints']);
 final tags = _mapAcceptanceTags(generated['acceptance_tags']);
 final changes = _mapScopeChanges(generated['scope_changes']);

 final deliveredCount = workPackages
 .where((item) => item.status.toLowerCase().contains('deliver'))
 .length;
 final deferredCount = workPackages
 .where((item) => item.status.toLowerCase().contains('defer'))
 .length;
 final criticalGaps = changes.length.clamp(0, 5);
 final totalPackages = workPackages.isEmpty ? 1 : workPackages.length;
 final deliveredPercent =
 ((deliveredCount / totalPackages) * 100).round().clamp(55, 98);

 final metricsEntries = generated['metrics'] ?? [];
 final deliveredOverride =
 _parseNumber(_findMetric(metricsEntries, 'deliver'));
 final deferredOverride = _parseNumber(_findMetric(metricsEntries, 'defer'));
 final criticalOverride =
 _parseNumber(_findMetric(metricsEntries, 'critical'));

 _suspendSave = true;
 _overviewController.text =
 _entryText(generated['overview']) ?? _overviewController.text.trim();
 _statusSummaryController.text = _entryText(generated['status_summary']) ??
 _statusSummaryController.text.trim();
 _sponsorSummaryController.text = _entryText(generated['sponsor_summary']) ??
 _sponsorSummaryController.text.trim();
 _changeSummaryController.text = _entryText(generated['change_summary']) ??
 _changeSummaryController.text.trim();

 _deliveredPercentController.text =
 deliveredOverride?.toString() ?? deliveredPercent.toString();
 _deliveredStatusController.text =
 deliveredPercent >= 85 ? 'On track' : 'Needs attention';
 _deferredCountController.text =
 deferredOverride?.toString() ?? deferredCount.toString();
 _deferredStatusController.text =
 deferredCount == 0 ? 'Clear' : 'Review required';
 _criticalGapCountController.text =
 criticalOverride?.toString() ?? criticalGaps.toString();
 _criticalGapStatusController.text =
 criticalGaps == 0 ? 'No critical gaps' : 'Open gaps';
 _approvedChangesController.text =
 (changes.length - 1).clamp(0, 99).toString();
 _unapprovedChangesController.text = (changes.length > 1 ? 1 : 0).toString();
 _openRequestsController.text = (changes.length > 2 ? 2 : 0).toString();

 setState(() {
 _workPackages
 ..clear()
 ..addAll(workPackages);
 _acceptanceCheckpoints
 ..clear()
 ..addAll(checkpoints);
 _acceptanceTags
 ..clear()
 ..addAll(tags);
 _scopeChanges
 ..clear()
 ..addAll(changes);
 _isAutoGenerating = false;
 });
 _suspendSave = false;
 await _saveToFirestore();
 }

 String? _entryText(List<LaunchEntry>? entries) {
 if (entries == null || entries.isEmpty) return null;
 final entry = entries.first;
 final title = entry.title.trim();
 final details = entry.details.trim();
 if (title.isNotEmpty && details.isNotEmpty) {
 return '$title: $details';
 }
 return title.isNotEmpty ? title : details;
 }

 String _extractField(String text, String key) {
 final match = RegExp('$key\\s*[:=-]\\s*([^|;\\n]+)', caseSensitive: false)
 .firstMatch(text);
 return match?.group(1)?.trim() ?? '';
 }

 String _findMetric(List<LaunchEntry> entries, String keyword) {
 for (final entry in entries) {
 final title = entry.title.toLowerCase();
 if (title.contains(keyword)) {
 return '${entry.title} ${entry.details} ${entry.status ?? ''}';
 }
 }
 return '';
 }

 int? _parseNumber(String text) {
 final match = RegExp(r'(\d{1,3})').firstMatch(text);
 return match != null ? int.tryParse(match.group(1) ?? '') : null;
 }

 List<_WorkPackageItem> _mapWorkPackages(List<LaunchEntry>? entries) {
 if (entries == null) return [];
 return entries
 .map((entry) {
 final details = entry.details;
 final owner = _extractField(details, 'Owner');
 final milestone = _extractField(details, 'Milestone');
 final impact = _extractField(details, 'Impact');
 final status = entry.status?.trim().isNotEmpty == true
 ? entry.status!.trim()
 : _workStatuses.first;
 return _WorkPackageItem(
 id: _newId(),
 title: entry.title.trim(),
 owner: owner,
 milestone: milestone,
 status: status,
 impact: impact.isNotEmpty ? impact : _impactLevels.first,
 );
 })
 .where((item) => item.title.isNotEmpty)
 .toList();
 }

 List<_CheckpointItem> _mapCheckpoints(List<LaunchEntry>? entries) {
 if (entries == null) return [];
 return entries
 .map((entry) {
 final details = entry.details;
 final owner = _extractField(details, 'Owner');
 final refCode = _extractField(details, 'Ref');
 final evidence = _extractField(details, 'Evidence');
 final status = entry.status?.trim().isNotEmpty == true
 ? entry.status!.trim()
 : _checkpointStatuses.first;
 return _CheckpointItem(
 id: _newId(),
 title: entry.title.trim(),
 owner: owner,
 status: status,
 refCode: refCode,
 evidence: evidence,
 );
 })
 .where((item) => item.title.isNotEmpty)
 .toList();
 }

 List<_AcceptanceTagItem> _mapAcceptanceTags(List<LaunchEntry>? entries) {
 if (entries == null) return [];
 return entries
 .map((entry) {
 final details = entry.details;
 final category = _extractField(details, 'Category');
 final verifiedBy = _extractField(details, 'Verified');
 final status = entry.status?.trim().isNotEmpty == true
 ? entry.status!.trim()
 : _checkpointStatuses.first;
 return _AcceptanceTagItem(
 id: _newId(),
 label: entry.title.trim(),
 status: status,
 category: _signalCategories.contains(category) ? category : 'Sponsor',
 verifiedBy: verifiedBy,
 );
 })
 .where((item) => item.label.isNotEmpty)
 .toList();
 }

 List<_ScopeChangeItem> _mapScopeChanges(List<LaunchEntry>? entries) {
 if (entries == null) return [];
 return entries
 .map((entry) {
 final details = entry.details;
 final crId = _extractField(details, 'CR');
 final changeType = _extractField(details, 'Type');
 final impactLevel = _extractField(details, 'Impact');
 final requestedBy = _extractField(details, 'Requested');
 final statusStr = entry.status?.trim().isNotEmpty == true
 ? entry.status!.trim()
 : 'Open';
 final matchedStatus = _changeStatuses
 .where((s) => s.toLowerCase() == statusStr.toLowerCase())
 .isNotEmpty
 ? _changeStatuses.firstWhere(
 (s) => s.toLowerCase() == statusStr.toLowerCase())
 : 'Open';
 final matchedType = _changeTypes
 .where((t) => t.toLowerCase() == changeType.toLowerCase())
 .isNotEmpty
 ? _changeTypes.firstWhere(
 (t) => t.toLowerCase() == changeType.toLowerCase())
 : 'Scope';
 return _ScopeChangeItem(
 id: _newId(),
 detail: entry.title.trim(),
 crId: crId,
 changeType: matchedType,
 impactLevel: _impactLevels
 .where((i) => i.toLowerCase() == impactLevel.toLowerCase())
 .isNotEmpty
 ? _impactLevels.firstWhere(
 (i) => i.toLowerCase() == impactLevel.toLowerCase())
 : 'Medium',
 requestedBy: requestedBy,
 status: matchedStatus,
 );
 })
 .where((item) => item.detail.isNotEmpty)
 .toList();
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 18 : 32;
 final theme = Theme.of(context);
 final textTheme = theme.textTheme.apply(fontFamily: appFontFamily);

 return Theme(
 data: theme.copyWith(
 textTheme: textTheme,
 primaryTextTheme: theme.primaryTextTheme.apply(
 fontFamily: appFontFamily,
 ),
 ),
 child: DefaultTextStyle.merge(
 style:
 textTheme.bodyMedium ?? const TextStyle(fontFamily: appFontFamily),
 child: Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Scope Completion'),
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
 if (_isLoading)
 const LinearProgressIndicator(minHeight: 2),
 if (_isLoading) const SizedBox(height: 16),
 const SizedBox(height: 20),
 _buildOverviewCard(context),
 const SizedBox(height: 20),
 _buildMainContentRow(context, isMobile),
 const SizedBox(height: 24),
 _buildTipRow(context),
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: 'Back: Risk Tracking',
 nextLabel:
 'Next: Gap Analysis & Scope Reconciliation',
 onBack: () =>
 RiskTrackingWorkspaceScreen.open(context),
 onNext: () =>
 GapAnalysisScopeReconcillationScreen.open(
 context),
 ),
 const SizedBox(height: 48),
 ],
 ),
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Scope Completion',
 ),
 ),
 const KazAiChatBubble(),
 ],
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }

 Widget _buildOverviewCard(BuildContext context) {
 return _ContentCard(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(
 title: 'Scope Completion',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _buildSectionHeader('Overview'),
 const SizedBox(height: 16),
 _buildLabeledField(
 label: 'Scope completion overview',
 controller: _overviewController,
 hintText:
 'Summarize how delivery matched the agreed scope and what is out-of-scope.',
 maxLines: 3,
 ),
 ],
 ),
 );
 }

 Widget _buildMainContentRow(BuildContext context, bool isMobile) {
 if (isMobile) {
 return Column(
 children: [
 _buildScopeCompletionStatusCard(context),
 const SizedBox(height: 16),
 _buildSponsorAcceptanceCard(context),
 const SizedBox(height: 16),
 _buildScopeChangeSummaryCard(context),
 ],
 );
 }

 return Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 _buildScopeCompletionStatusCard(context),
 const SizedBox(height: 16),
 _buildSponsorAcceptanceCard(context),
 const SizedBox(height: 16),
 _buildScopeChangeSummaryCard(context),
 ],
 );
 }

 Widget _buildScopeCompletionStatusCard(BuildContext context) {
 return _ContentCard(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 'Scope Completion Status',
 badge: 'Execution summary',
 ),
 const SizedBox(height: 16),
 _buildLabeledField(
 label: 'Completion narrative',
 controller: _statusSummaryController,
 hintText:
 'Explain delivery confidence, known deferrals, and remaining gaps.',
 maxLines: 3,
 ),
 const SizedBox(height: 16),
 _buildMetricsRow(context),
 const SizedBox(height: 20),
 _buildReadinessSummary(),
 const SizedBox(height: 20),
 _buildTableTitle('Key Work Packages Register'),
 const SizedBox(height: 10),
 _buildWorkPackagesTable(context),
 ],
 ),
 );
 }

 Widget _buildMetricsRow(BuildContext context) {
 return LayoutBuilder(
 builder: (context, constraints) {
 final compact = constraints.maxWidth < 760;
 final cards = [
 _buildMetricBox(
 label: 'Original scope delivered',
 valueController: _deliveredPercentController,
 statusController: _deliveredStatusController,
 ),
 _buildMetricBox(
 label: 'Items deferred',
 valueController: _deferredCountController,
 statusController: _deferredStatusController,
 ),
 _buildMetricBox(
 label: 'Critical gaps',
 valueController: _criticalGapCountController,
 statusController: _criticalGapStatusController,
 ),
 ];
 if (compact) {
 return Column(
 children: [
 for (final card in cards) ...[
 card,
 if (card != cards.last) const SizedBox(height: 12),
 ],
 ],
 );
 }
 return Row(
 children: [
 for (final card in cards) ...[
 Expanded(child: card),
 if (card != cards.last) const SizedBox(width: 12),
 ],
 ],
 );
 },
 );
 }

 Widget _buildMetricBox({
 required String label,
 required TextEditingController valueController,
 required TextEditingController statusController,
 }) {
 return Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 VoiceTextField(
 controller: valueController,
 keyboardType: TextInputType.number,
 textAlign: TextAlign.right,
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: Color(0xFF111827)),
 decoration: const InputDecoration(
 hintText: '0',
 border: InputBorder.none,
 isDense: true,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 label,
 style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 const SizedBox(height: 8),
 VoiceTextField(
 controller: statusController,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280)),
 decoration: const InputDecoration(
 hintText: 'Status note',
 border: InputBorder.none,
 isDense: true,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildWorkPackagesTable(BuildContext context) {
 return _buildResponsiveTable(
 minWidth: 1100,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Table header
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: const Color(0xFF1F2937),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Row(
 children: [
 Expanded(flex: 1, child: Text('WBS', style: _headerStyle)),
 Expanded(flex: 3, child: Text('Work Package', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Owner', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Baseline', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Actual', style: _headerStyle)),
 Expanded(flex: 1, child: Text('% Comp.', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Status', style: _headerStyle)),
 Expanded(flex: 1, child: Text('Impact', style: _headerStyle)),
 Expanded(flex: 1, child: Text('', style: _headerStyle)),
 ],
 ),
 ),
 const SizedBox(height: 6),
 if (_workPackages.isEmpty)
 _InlineEmptyState(
 title: 'No work packages yet',
 message: 'Add work packages to track delivered scope against baseline.',
 icon: Icons.inventory_2_outlined,
 )
 else
 ..._workPackages.asMap().entries.map(
 (entry) => _buildWorkPackageDisplayRow(entry.value, entry.key),
 ),
 const SizedBox(height: 10),
 // CRUD action bar
 Row(
 children: [
 TextButton.icon(
 onPressed: _addWorkPackage,
 icon: const Icon(Icons.add_rounded, size: 18),
 label: const Text('Add work package'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF1F2937),
 padding:
 const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 backgroundColor: const Color(0xFFFFF3C4),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 if (_workPackages.isNotEmpty) ...[
 const SizedBox(width: 8),
 TextButton.icon(
 onPressed: () => _duplicateAllWorkPackages(),
 icon: const Icon(Icons.content_copy_rounded, size: 16),
 label: const Text('Duplicate all'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF6B7280),
 padding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 const Spacer(),
 Text(
 '${_workPackages.length} package${_workPackages.length != 1 ? 's' : ''}',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF9CA3AF)),
 ),
 ],
 ],
 ),
 ],
 ),
 );
 }

 static const _headerStyle = TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFFE5E7EB),
 letterSpacing: 0.5,
 );

 Widget _buildWorkPackageDisplayRow(_WorkPackageItem item, int index) {
 final statusColor = _statusColor(item.status);
 final impactColor = _impactColor(item.impact);
 final progressColor = _progressColor(item.percentComplete);

 return Container(
 margin: const EdgeInsets.only(bottom: 4),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: index.isEven ? Colors.white : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 ),
 child: Row(
 children: [
 // WBS Code
 Expanded(
 flex: 1,
 child: Text(
 item.wbsCode.isNotEmpty ? item.wbsCode : '—',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280),
 fontFamily: appFontFamily),
 ),
 ),
 // Work Package
 Expanded(
 flex: 3,
 child: Text(
 item.title.isNotEmpty ? item.title : 'Untitled',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: item.title.isNotEmpty
 ? const Color(0xFF111827)
 : const Color(0xFF9CA3AF),
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 // Owner
 Expanded(
 flex: 2,
 child: Text(
 item.owner.isNotEmpty ? item.owner : '—',
 style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 // Baseline Date
 Expanded(
 flex: 2,
 child: Text(
 item.baselineDate != null
 ? _formatDate(item.baselineDate!)
 : '—',
 style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
 ),
 ),
 // Actual Date
 Expanded(
 flex: 2,
 child: Text(
 item.actualDate != null ? _formatDate(item.actualDate!) : '—',
 style: TextStyle(
 fontSize: 12,
 color: _isOverdue(item) ? const Color(0xFFEF4444) : const Color(0xFF374151),
 fontWeight: _isOverdue(item) ? FontWeight.w600 : FontWeight.normal,
 ),
 ),
 ),
 // % Complete
 Expanded(
 flex: 1,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 '${item.percentComplete}%',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: progressColor,
 ),
 ),
 const SizedBox(height: 3),
 ClipRRect(
 borderRadius: BorderRadius.circular(3),
 child: LinearProgressIndicator(
 value: item.percentComplete / 100,
 backgroundColor: const Color(0xFFE5E7EB),
 valueColor: AlwaysStoppedAnimation<Color>(progressColor),
 minHeight: 4,
 ),
 ),
 ],
 ),
 ),
 // Status chip
 Expanded(
 flex: 2,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: statusColor.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 item.status,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: statusColor,
 ),
 textAlign: TextAlign.center,
 ),
 ),
 ),
 // Impact chip
 Expanded(
 flex: 1,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
 decoration: BoxDecoration(
 color: impactColor.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 item.impact,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: impactColor,
 ),
 textAlign: TextAlign.center,
 ),
 ),
 ),
 // Actions
 Expanded(
 flex: 1,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 _actionIconButton(
 icon: Icons.edit_outlined,
 tooltip: 'Edit',
 onPressed: () => _showWorkPackageDialog(item),
 ),
 _actionIconButton(
 icon: Icons.content_copy,
 tooltip: 'Duplicate',
 onPressed: () => _duplicateWorkPackage(item),
 ),
 _actionIconButton(
 icon: Icons.delete_outline,
 tooltip: 'Delete',
 color: const Color(0xFFEF4444),
 onPressed: () => _confirmDeleteWorkPackage(item),
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
 ),
 ),
 ],
 ),
 );
 }

 Widget _actionIconButton({
 required IconData icon,
 required String tooltip,
 required VoidCallback onPressed,
 Color color = const Color(0xFF6B7280),
 }) {
 return Tooltip(
 message: tooltip,
 child: InkWell(
 onTap: onPressed,
 borderRadius: BorderRadius.circular(6),
 child: Padding(
 padding: const EdgeInsets.all(4),
 child: Icon(icon, size: 16, color: color),
 ),
 ),
 );
 }

 Color _statusColor(String status) {
 switch (status.toLowerCase()) {
 case 'delivered':
 return const Color(0xFF059669);
 case 'partially delivered':
 return const Color(0xFFD97706);
 case 'deferred':
 return const Color(0xFFDC2626);
 case 'not started':
 return const Color(0xFF9CA3AF);
 default:
 return const Color(0xFF6B7280);
 }
 }

 Color _impactColor(String impact) {
 switch (impact.toLowerCase()) {
 case 'critical':
 return const Color(0xFFDC2626);
 case 'high':
 return const Color(0xFFEA580C);
 case 'medium':
 return const Color(0xFFD97706);
 case 'low':
 return const Color(0xFF059669);
 default:
 return const Color(0xFF6B7280);
 }
 }

 Color _progressColor(int pct) {
 if (pct >= 80) return const Color(0xFF059669);
 if (pct >= 50) return const Color(0xFFD97706);
 return const Color(0xFFDC2626);
 }

 bool _isOverdue(_WorkPackageItem item) {
 if (item.baselineDate == null || item.actualDate == null) return false;
 return item.actualDate!.isAfter(item.baselineDate!);
 }

 Color _checkpointStatusColor(String status) {
 switch (status.toLowerCase()) {
 case 'aligned':
 return const Color(0xFF059669);
 case 'blocked':
 return const Color(0xFFDC2626);
 case 'waived':
 return const Color(0xFFD97706);
 case 'pending':
 return const Color(0xFF9CA3AF);
 default:
 return const Color(0xFF6B7280);
 }
 }

 Color _signalCategoryColor(String category) {
 switch (category.toLowerCase()) {
 case 'sponsor':
 return const Color(0xFF7C3AED);
 case 'operations':
 return const Color(0xFFD97706);
 case 'technical':
 return const Color(0xFF0D9488);
 case 'regulatory':
 return const Color(0xFFEA580C);
 default:
 return const Color(0xFF6B7280);
 }
 }

 Color _changeTypeColor(String type) {
 switch (type.toLowerCase()) {
 case 'scope':
 return const Color(0xFF7C3AED);
 case 'budget':
 return const Color(0xFFD97706);
 case 'schedule':
 return const Color(0xFFD97706);
 case 'quality':
 return const Color(0xFF0D9488);
 default:
 return const Color(0xFF6B7280);
 }
 }

 Color _changeStatusColor(String status) {
 switch (status.toLowerCase()) {
 case 'approved':
 return const Color(0xFF059669);
 case 'rejected':
 return const Color(0xFFDC2626);
 case 'deferred':
 return const Color(0xFFD97706);
 case 'open':
 return const Color(0xFFD97706);
 default:
 return const Color(0xFF6B7280);
 }
 }

 String _formatDate(DateTime dt) {
 const months = [
 '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
 ];
 return '${dt.day} ${months[dt.month]} ${dt.year}';
 }

 // ─── Work Package CRUD ─────────────────────────────────────────────

 void _showWorkPackageDialog([_WorkPackageItem? existing]) {
 final isEdit = existing != null;
 final titleCtl = TextEditingController(text: existing?.title ?? '');
 final ownerCtl = TextEditingController(text: existing?.owner ?? '');
 final milestoneCtl = TextEditingController(text: existing?.milestone ?? '');
 final wbsCtl = TextEditingController(text: existing?.wbsCode ?? '');
 final notesCtl = TextEditingController(text: existing?.notes ?? '');
 final pctCtl = TextEditingController(
 text: (existing?.percentComplete ?? 0).toString());
 String status = existing?.status ?? _workStatuses.first;
 String impact = existing?.impact ?? _impactLevels[2]; // Medium
 DateTime? baselineDate = existing?.baselineDate;
 DateTime? actualDate = existing?.actualDate;

 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDialogState) => LaunchModalShell(
 icon: isEdit ? Icons.edit_rounded : Icons.add_rounded,
 accent: const Color(0xFF4154F1),
 title: isEdit ? 'Edit Work Package' : 'Add Work Package',
 subtitle: isEdit
 ? 'Update the deliverable details below.'
 : 'Capture a new deliverable for scope acceptance tracking.',
 body: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LaunchModalTextField(
 label: 'WBS Code',
 controller: wbsCtl,
 hint: 'e.g. 1.2.3',
 style: const TextStyle(fontFamily: appFontFamily),
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Work Package Title *',
 controller: titleCtl,
 hint: 'Describe the deliverable',
 maxLines: 2,
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Owner',
 controller: ownerCtl,
 hint: 'Responsible person',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalTextField(
 label: 'Milestone',
 controller: milestoneCtl,
 hint: 'Target milestone',
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalDateField(
 label: 'Baseline Date',
 initialDate: baselineDate,
 onPicked: (d) =>
 setDialogState(() => baselineDate = d),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDateField(
 label: 'Actual Date',
 initialDate: actualDate,
 onPicked: (d) =>
 setDialogState(() => actualDate = d),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: '% Complete',
 controller: pctCtl,
 hint: '0–100',
 keyboardType: TextInputType.number,
 suffixText: '%',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Status',
 value: status,
 items: _workStatuses,
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => status = v);
 }
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Impact',
 value: impact,
 items: _impactLevels,
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => impact = v);
 }
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Notes',
 controller: notesCtl,
 hint: 'Additional context or remarks',
 maxLines: 3,
 ),
 ],
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.of(ctx).pop(),
 ),
 LaunchModalPrimaryButton(
 label: isEdit ? 'Save Changes' : 'Add Package',
 icon: isEdit ? Icons.check_rounded : Icons.add_rounded,
 onPressed: () {
 final pct =
 (int.tryParse(pctCtl.text.trim()) ?? 0).clamp(0, 100);
 final newItem = _WorkPackageItem(
 id: existing?.id ?? _newId(),
 title: titleCtl.text.trim(),
 owner: ownerCtl.text.trim(),
 milestone: milestoneCtl.text.trim(),
 status: status,
 impact: impact,
 wbsCode: wbsCtl.text.trim(),
 baselineDate: baselineDate,
 actualDate: actualDate,
 percentComplete: pct,
 notes: notesCtl.text.trim(),
 );
 if (isEdit) {
 _updateWorkPackage(newItem, notify: true);
 } else {
 setState(() => _workPackages.add(newItem));
 _scheduleSave();
 }
 Navigator.of(ctx).pop();
 },
 ),
 ],
 ),
 ),
 );
 }

 void _duplicateWorkPackage(_WorkPackageItem item) {
 setState(() {
 _workPackages.add(_WorkPackageItem(
 id: _newId(),
 title: '${item.title} (copy)',
 owner: item.owner,
 milestone: item.milestone,
 status: item.status,
 impact: item.impact,
 wbsCode: item.wbsCode,
 baselineDate: item.baselineDate,
 actualDate: item.actualDate,
 percentComplete: item.percentComplete,
 notes: item.notes,
 ));
 });
 _scheduleSave();
 }

 void _duplicateAllWorkPackages() {
 setState(() {
 for (final item in List.of(_workPackages)) {
 _workPackages.add(_WorkPackageItem(
 id: _newId(),
 title: '${item.title} (copy)',
 owner: item.owner,
 milestone: item.milestone,
 status: item.status,
 impact: item.impact,
 wbsCode: item.wbsCode,
 baselineDate: item.baselineDate,
 actualDate: item.actualDate,
 percentComplete: item.percentComplete,
 notes: item.notes,
 ));
 }
 });
 _scheduleSave();
 }

 void _confirmDeleteWorkPackage(_WorkPackageItem item) {
 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) => LaunchModalShell(
 icon: Icons.delete_outline_rounded,
 accent: const Color(0xFFEF4444),
 title: 'Delete Work Package',
 subtitle: 'This action cannot be undone.',
 body: Text(
 'Are you sure you want to delete "${item.title.isNotEmpty ? item.title : 'this package'}"? '
 'Once removed, the entry cannot be recovered.',
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF4B5563),
 height: 1.5,
 ),
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.of(ctx).pop(),
 ),
 LaunchModalDangerButton(
 label: 'Delete',
 onPressed: () {
 _deleteWorkPackage(item.id);
 Navigator.of(ctx).pop();
 },
 ),
 ],
 ),
 );
 }

 // ─── Checkpoint CRUD ────────────────────────────────────────────────

 Widget _buildSponsorAcceptanceCard(BuildContext context) {
 return _ContentCard(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 'Sponsor Acceptance',
 badge: 'Sign-off readiness',
 ),
 const SizedBox(height: 16),
 _buildLabeledField(
 label: 'Acceptance summary',
 controller: _sponsorSummaryController,
 hintText:
 'Capture sponsor alignment, remaining gaps, and ownership confirmation.',
 maxLines: 3,
 ),
 const SizedBox(height: 16),
 _buildTableTitle('Formal Acceptance Checkpoints'),
 const SizedBox(height: 10),
 _buildCheckpointsTable(context),
 const SizedBox(height: 20),
 _buildTableTitle('Acceptance Signals and Readiness Tags'),
 const SizedBox(height: 10),
 _buildAcceptanceTagsTable(context),
 ],
 ),
 );
 }

 Widget _buildCheckpointsTable(BuildContext context) {
 return _buildResponsiveTable(
 minWidth: 1200,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: const Color(0xFF1F2937),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Row(
 children: [
 Expanded(flex: 1, child: Text('Ref', style: _headerStyle)),
 Expanded(flex: 3, child: Text('Checkpoint', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Approver', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Due Date', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Sign-off', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Status', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Evidence', style: _headerStyle)),
 Expanded(flex: 1, child: Text('', style: _headerStyle)),
 ],
 ),
 ),
 const SizedBox(height: 6),
 if (_acceptanceCheckpoints.isEmpty)
 _InlineEmptyState(
 title: 'No checkpoints yet',
 message: 'List the acceptance checkpoints for sponsor sign-off.',
 icon: Icons.checklist_outlined,
 )
 else
 ..._acceptanceCheckpoints.asMap().entries.map(
 (entry) => _buildCheckpointDisplayRow(entry.value, entry.key),
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 TextButton.icon(
 onPressed: () => _showCheckpointDialog(),
 icon: const Icon(Icons.add_rounded, size: 18),
 label: const Text('Add checkpoint'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF1F2937),
 padding:
 const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 backgroundColor: const Color(0xFFFFF3C4),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 if (_acceptanceCheckpoints.isNotEmpty) ...[
 const SizedBox(width: 8),
 TextButton.icon(
 onPressed: () => _duplicateAllCheckpoints(),
 icon: const Icon(Icons.content_copy_rounded, size: 16),
 label: const Text('Duplicate all'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF6B7280),
 padding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 const Spacer(),
 Text(
 '${_acceptanceCheckpoints.length} checkpoint${_acceptanceCheckpoints.length != 1 ? 's' : ''}',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF9CA3AF)),
 ),
 ],
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildCheckpointDisplayRow(_CheckpointItem item, int index) {
 final statusColor = _checkpointStatusColor(item.status);
 final isOverdue = item.dueDate != null &&
 item.signOffDate == null &&
 item.dueDate!.isBefore(DateTime.now());

 return Container(
 margin: const EdgeInsets.only(bottom: 4),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: index.isEven ? Colors.white : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 ),
 child: Row(
 children: [
 // Ref
 Expanded(
 flex: 1,
 child: Text(
 item.refCode.isNotEmpty ? item.refCode : '—',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280),
 fontFamily: appFontFamily),
 ),
 ),
 // Checkpoint
 Expanded(
 flex: 3,
 child: Text(
 item.title.isNotEmpty ? item.title : 'Untitled',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: item.title.isNotEmpty
 ? const Color(0xFF111827)
 : const Color(0xFF9CA3AF),
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 // Approver
 Expanded(
 flex: 2,
 child: Text(
 item.owner.isNotEmpty ? item.owner : '—',
 style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 // Due Date
 Expanded(
 flex: 2,
 child: Text(
 item.dueDate != null ? _formatDate(item.dueDate!) : '—',
 style: TextStyle(
 fontSize: 12,
 color: isOverdue ? const Color(0xFFEF4444) : const Color(0xFF374151),
 fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
 ),
 ),
 ),
 // Sign-off Date
 Expanded(
 flex: 2,
 child: Text(
 item.signOffDate != null ? _formatDate(item.signOffDate!) : '—',
 style: TextStyle(
 fontSize: 12,
 color: isOverdue ? const Color(0xFFEF4444) : const Color(0xFF374151),
 fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
 ),
 ),
 ),
 // Status chip
 Expanded(
 flex: 2,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: statusColor.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 item.status,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: statusColor,
 ),
 textAlign: TextAlign.center,
 ),
 ),
 ),
 // Evidence
 Expanded(
 flex: 2,
 child: Text(
 item.evidence.isNotEmpty ? item.evidence : '—',
 style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
 overflow: TextOverflow.ellipsis,
 maxLines: 2,
 ),
 ),
 // Actions
 Expanded(
 flex: 1,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 _actionIconButton(
 icon: Icons.edit_outlined,
 tooltip: 'Edit',
 onPressed: () => _showCheckpointDialog(item),
 ),
 _actionIconButton(
 icon: Icons.content_copy,
 tooltip: 'Duplicate',
 onPressed: () => _duplicateCheckpoint(item),
 ),
 _actionIconButton(
 icon: Icons.delete_outline,
 tooltip: 'Delete',
 color: const Color(0xFFEF4444),
 onPressed: () => _confirmDeleteCheckpoint(item),
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
 ),
 ),
 ],
 ),
 );
 }

 void _showCheckpointDialog([_CheckpointItem? existing]) {
 final isEdit = existing != null;
 final titleCtl = TextEditingController(text: existing?.title ?? '');
 final ownerCtl = TextEditingController(text: existing?.owner ?? '');
 final refCodeCtl = TextEditingController(text: existing?.refCode ?? '');
 final evidenceCtl = TextEditingController(text: existing?.evidence ?? '');
 final notesCtl = TextEditingController(text: existing?.notes ?? '');
 String status = existing?.status ?? _checkpointStatuses.first;
 DateTime? dueDate = existing?.dueDate;
 DateTime? signOffDate = existing?.signOffDate;

 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDialogState) => LaunchModalShell(
 icon: isEdit ? Icons.edit_rounded : Icons.add_rounded,
 accent: const Color(0xFF4154F1),
 title: isEdit ? 'Edit Checkpoint' : 'Add Checkpoint',
 subtitle: isEdit
 ? 'Update the formal acceptance checkpoint details.'
 : 'Define a formal acceptance checkpoint for sponsor sign-off.',
 body: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LaunchModalTextField(
 label: 'Reference Code',
 controller: refCodeCtl,
 hint: 'e.g. ACC-001',
 style: const TextStyle(fontFamily: appFontFamily),
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Checkpoint Description *',
 controller: titleCtl,
 hint: 'Describe the acceptance checkpoint',
 maxLines: 2,
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Approver',
 controller: ownerCtl,
 hint: 'Approver name',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Status',
 value: status,
 items: _checkpointStatuses,
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => status = v);
 }
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalDateField(
 label: 'Due Date',
 initialDate: dueDate,
 onPicked: (d) =>
 setDialogState(() => dueDate = d),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDateField(
 label: 'Sign-off Date',
 initialDate: signOffDate,
 onPicked: (d) =>
 setDialogState(() => signOffDate = d),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Evidence / Artifact',
 controller: evidenceCtl,
 hint: 'Reference to evidence or artifact',
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Notes',
 controller: notesCtl,
 hint: 'Additional context or remarks',
 maxLines: 3,
 ),
 ],
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.of(ctx).pop(),
 ),
 LaunchModalPrimaryButton(
 label: isEdit ? 'Save Changes' : 'Add Checkpoint',
 icon: isEdit ? Icons.check_rounded : Icons.add_rounded,
 onPressed: () {
 final newItem = _CheckpointItem(
 id: existing?.id ?? _newId(),
 title: titleCtl.text.trim(),
 owner: ownerCtl.text.trim(),
 status: status,
 refCode: refCodeCtl.text.trim(),
 dueDate: dueDate,
 signOffDate: signOffDate,
 evidence: evidenceCtl.text.trim(),
 notes: notesCtl.text.trim(),
 );
 if (isEdit) {
 _updateCheckpoint(newItem, notify: true);
 } else {
 setState(() => _acceptanceCheckpoints.add(newItem));
 _scheduleSave();
 }
 Navigator.of(ctx).pop();
 },
 ),
 ],
 ),
 ),
 );
 }

 void _duplicateCheckpoint(_CheckpointItem item) {
 setState(() {
 _acceptanceCheckpoints.add(_CheckpointItem(
 id: _newId(),
 title: '${item.title} (copy)',
 owner: item.owner,
 status: item.status,
 refCode: item.refCode,
 dueDate: item.dueDate,
 signOffDate: item.signOffDate,
 evidence: item.evidence,
 notes: item.notes,
 ));
 });
 _scheduleSave();
 }

 void _duplicateAllCheckpoints() {
 setState(() {
 for (final item in List.of(_acceptanceCheckpoints)) {
 _acceptanceCheckpoints.add(_CheckpointItem(
 id: _newId(),
 title: '${item.title} (copy)',
 owner: item.owner,
 status: item.status,
 refCode: item.refCode,
 dueDate: item.dueDate,
 signOffDate: item.signOffDate,
 evidence: item.evidence,
 notes: item.notes,
 ));
 }
 });
 _scheduleSave();
 }

 void _confirmDeleteCheckpoint(_CheckpointItem item) {
 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) => LaunchModalShell(
 icon: Icons.delete_outline_rounded,
 accent: const Color(0xFFEF4444),
 title: 'Delete Checkpoint',
 subtitle: 'This action cannot be undone.',
 body: Text(
 'Are you sure you want to delete "${item.title.isNotEmpty ? item.title : 'this checkpoint'}"? '
 'Once removed, the entry cannot be recovered.',
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF4B5563),
 height: 1.5,
 ),
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.of(ctx).pop(),
 ),
 LaunchModalDangerButton(
 label: 'Delete',
 onPressed: () {
 _deleteCheckpoint(item.id);
 Navigator.of(ctx).pop();
 },
 ),
 ],
 ),
 );
 }

 // ─── Acceptance Tags CRUD ───────────────────────────────────────────

 Widget _buildAcceptanceTagsTable(BuildContext context) {
 return _buildResponsiveTable(
 minWidth: 900,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: const Color(0xFF1F2937),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Row(
 children: [
 Expanded(flex: 3, child: Text('Signal', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Category', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Status', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Verified By', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Date', style: _headerStyle)),
 Expanded(flex: 1, child: Text('', style: _headerStyle)),
 ],
 ),
 ),
 const SizedBox(height: 6),
 if (_acceptanceTags.isEmpty)
 _InlineEmptyState(
 title: 'No acceptance signals yet',
 message: 'Add sponsor and operations acceptance signals.',
 icon: Icons.verified_outlined,
 )
 else
 ..._acceptanceTags.asMap().entries.map(
 (entry) => _buildAcceptanceTagDisplayRow(entry.value, entry.key),
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 TextButton.icon(
 onPressed: () => _showAcceptanceTagDialog(),
 icon: const Icon(Icons.add_rounded, size: 18),
 label: const Text('Add signal'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF1F2937),
 padding:
 const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 backgroundColor: const Color(0xFFFFF3C4),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 if (_acceptanceTags.isNotEmpty) ...[
 const Spacer(),
 Text(
 '${_acceptanceTags.length} signal${_acceptanceTags.length != 1 ? 's' : ''}',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF9CA3AF)),
 ),
 ],
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildAcceptanceTagDisplayRow(_AcceptanceTagItem item, int index) {
 final categoryColor = _signalCategoryColor(item.category);
 final statusColor = _checkpointStatusColor(item.status);

 return Container(
 margin: const EdgeInsets.only(bottom: 4),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: index.isEven ? Colors.white : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 ),
 child: Row(
 children: [
 // Signal
 Expanded(
 flex: 3,
 child: Text(
 item.label.isNotEmpty ? item.label : 'Untitled',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: item.label.isNotEmpty
 ? const Color(0xFF111827)
 : const Color(0xFF9CA3AF),
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 // Category chip
 Expanded(
 flex: 2,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: categoryColor.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 item.category,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: categoryColor,
 ),
 textAlign: TextAlign.center,
 ),
 ),
 ),
 // Status chip
 Expanded(
 flex: 2,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: statusColor.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 item.status,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: statusColor,
 ),
 textAlign: TextAlign.center,
 ),
 ),
 ),
 // Verified By
 Expanded(
 flex: 2,
 child: Text(
 item.verifiedBy.isNotEmpty ? item.verifiedBy : '—',
 style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 // Date Verified
 Expanded(
 flex: 2,
 child: Text(
 item.dateVerified != null ? _formatDate(item.dateVerified!) : '—',
 style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
 ),
 ),
 // Actions
 Expanded(
 flex: 1,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 _actionIconButton(
 icon: Icons.edit_outlined,
 tooltip: 'Edit',
 onPressed: () => _showAcceptanceTagDialog(item),
 ),
 _actionIconButton(
 icon: Icons.content_copy,
 tooltip: 'Duplicate',
 onPressed: () => _duplicateAcceptanceTag(item),
 ),
 _actionIconButton(
 icon: Icons.delete_outline,
 tooltip: 'Delete',
 color: const Color(0xFFEF4444),
 onPressed: () => _confirmDeleteAcceptanceTag(item),
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
 ),
 ),
 ],
 ),
 );
 }

 void _showAcceptanceTagDialog([_AcceptanceTagItem? existing]) {
 final isEdit = existing != null;
 final labelCtl = TextEditingController(text: existing?.label ?? '');
 final verifiedByCtl = TextEditingController(text: existing?.verifiedBy ?? '');
 final notesCtl = TextEditingController(text: existing?.notes ?? '');
 String status = existing?.status ?? _checkpointStatuses.first;
 String category = existing?.category ?? _signalCategories.first;
 DateTime? dateVerified = existing?.dateVerified;

 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDialogState) => LaunchModalShell(
 icon: isEdit ? Icons.edit_rounded : Icons.add_rounded,
 accent: const Color(0xFF4154F1),
 title: isEdit ? 'Edit Signal' : 'Add Signal',
 subtitle: isEdit
 ? 'Update the acceptance signal details.'
 : 'Capture a sponsor or operations acceptance signal.',
 body: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LaunchModalTextField(
 label: 'Signal / Tag Name *',
 controller: labelCtl,
 hint: 'Name of the acceptance signal',
 maxLines: 2,
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Category',
 value: category,
 items: _signalCategories,
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => category = v);
 }
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Status',
 value: status,
 items: _checkpointStatuses,
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => status = v);
 }
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalTextField(
 label: 'Verified By',
 controller: verifiedByCtl,
 hint: 'Person who verified',
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDateField(
 label: 'Date Verified',
 initialDate: dateVerified,
 onPicked: (d) =>
 setDialogState(() => dateVerified = d),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Notes',
 controller: notesCtl,
 hint: 'Additional context or remarks',
 maxLines: 3,
 ),
 ],
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.of(ctx).pop(),
 ),
 LaunchModalPrimaryButton(
 label: isEdit ? 'Save Changes' : 'Add Signal',
 icon: isEdit ? Icons.check_rounded : Icons.add_rounded,
 onPressed: () {
 final newItem = _AcceptanceTagItem(
 id: existing?.id ?? _newId(),
 label: labelCtl.text.trim(),
 status: status,
 category: category,
 verifiedBy: verifiedByCtl.text.trim(),
 dateVerified: dateVerified,
 notes: notesCtl.text.trim(),
 );
 if (isEdit) {
 _updateAcceptanceTag(newItem, notify: true);
 } else {
 setState(() => _acceptanceTags.add(newItem));
 _scheduleSave();
 }
 Navigator.of(ctx).pop();
 },
 ),
 ],
 ),
 ),
 );
 }

 void _duplicateAcceptanceTag(_AcceptanceTagItem item) {
 setState(() {
 _acceptanceTags.add(_AcceptanceTagItem(
 id: _newId(),
 label: '${item.label} (copy)',
 status: item.status,
 category: item.category,
 verifiedBy: item.verifiedBy,
 dateVerified: item.dateVerified,
 notes: item.notes,
 ));
 });
 _scheduleSave();
 }

 void _confirmDeleteAcceptanceTag(_AcceptanceTagItem item) {
 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) => LaunchModalShell(
 icon: Icons.delete_outline_rounded,
 accent: const Color(0xFFEF4444),
 title: 'Delete Signal',
 subtitle: 'This action cannot be undone.',
 body: Text(
 'Are you sure you want to delete "${item.label.isNotEmpty ? item.label : 'this signal'}"? '
 'Once removed, the entry cannot be recovered.',
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF4B5563),
 height: 1.5,
 ),
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.of(ctx).pop(),
 ),
 LaunchModalDangerButton(
 label: 'Delete',
 onPressed: () {
 _deleteAcceptanceTag(item.id);
 Navigator.of(ctx).pop();
 },
 ),
 ],
 ),
 );
 }

 // ─── Scope Changes CRUD ─────────────────────────────────────────────

 Widget _buildScopeChangeSummaryCard(BuildContext context) {
 return _ContentCard(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildSectionHeader(
 'Scope Change Summary',
 badge: 'Change log',
 ),
 const SizedBox(height: 16),
 _buildLabeledField(
 label: 'Change summary',
 controller: _changeSummaryController,
 hintText:
 'Summarize the scope, budget, or timeline changes that mattered.',
 maxLines: 3,
 ),
 const SizedBox(height: 14),
 _buildTableTitle('Most Impactful Scope Changes'),
 const SizedBox(height: 8),
 _buildScopeChangesTable(context),
 const SizedBox(height: 14),
 _buildTableTitle('Change Control Metrics'),
 const SizedBox(height: 8),
 Wrap(
 spacing: 8,
 runSpacing: 6,
 children: [
 _buildMetricChip(
 label: 'Total approved changes',
 controller: _approvedChangesController,
 ),
 _buildMetricChip(
 label: 'Unapproved changes',
 controller: _unapprovedChangesController,
 ),
 _buildMetricChip(
 label: 'Open change requests',
 controller: _openRequestsController,
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildScopeChangesTable(BuildContext context) {
 return _buildResponsiveTable(
 minWidth: 1200,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: const Color(0xFF1F2937),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Row(
 children: [
 Expanded(flex: 1, child: Text('CR ID', style: _headerStyle)),
 Expanded(flex: 3, child: Text('Change Description', style: _headerStyle)),
 Expanded(flex: 1, child: Text('Type', style: _headerStyle)),
 Expanded(flex: 1, child: Text('Impact', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Requested By', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Date Raised', style: _headerStyle)),
 Expanded(flex: 2, child: Text('Status', style: _headerStyle)),
 Expanded(flex: 1, child: Text('', style: _headerStyle)),
 ],
 ),
 ),
 const SizedBox(height: 6),
 if (_scopeChanges.isEmpty)
 _InlineEmptyState(
 title: 'No scope changes yet',
 message: 'Add the most impactful scope changes.',
 icon: Icons.swap_horiz_outlined,
 )
 else
 ..._scopeChanges.asMap().entries.map(
 (entry) => _buildScopeChangeDisplayRow(entry.value, entry.key),
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 TextButton.icon(
 onPressed: () => _showScopeChangeDialog(),
 icon: const Icon(Icons.add_rounded, size: 18),
 label: const Text('Add scope change'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF1F2937),
 padding:
 const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 backgroundColor: const Color(0xFFFFF3C4),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 if (_scopeChanges.isNotEmpty) ...[
 const SizedBox(width: 8),
 TextButton.icon(
 onPressed: () => _duplicateAllScopeChanges(),
 icon: const Icon(Icons.content_copy_rounded, size: 16),
 label: const Text('Duplicate all'),
 style: TextButton.styleFrom(
 foregroundColor: const Color(0xFF6B7280),
 padding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12)),
 ),
 ),
 const Spacer(),
 Text(
 '${_scopeChanges.length} change${_scopeChanges.length != 1 ? 's' : ''}',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF9CA3AF)),
 ),
 ],
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildScopeChangeDisplayRow(_ScopeChangeItem item, int index) {
 final typeColor = _changeTypeColor(item.changeType);
 final impactColor = _impactColor(item.impactLevel);
 final statusColor = _changeStatusColor(item.status);

 return Container(
 margin: const EdgeInsets.only(bottom: 4),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: index.isEven ? Colors.white : const Color(0xFFFAFBFD),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 ),
 child: Row(
 children: [
 // CR ID
 Expanded(
 flex: 1,
 child: Text(
 item.crId.isNotEmpty ? item.crId : '—',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF6B7280),
 fontFamily: appFontFamily),
 ),
 ),
 // Change Description
 Expanded(
 flex: 3,
 child: Text(
 item.detail.isNotEmpty ? item.detail : 'Untitled',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: item.detail.isNotEmpty
 ? const Color(0xFF111827)
 : const Color(0xFF9CA3AF),
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 // Type chip
 Expanded(
 flex: 1,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
 decoration: BoxDecoration(
 color: typeColor.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 item.changeType,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: typeColor,
 ),
 textAlign: TextAlign.center,
 ),
 ),
 ),
 // Impact chip
 Expanded(
 flex: 1,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
 decoration: BoxDecoration(
 color: impactColor.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 item.impactLevel,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: impactColor,
 ),
 textAlign: TextAlign.center,
 ),
 ),
 ),
 // Requested By
 Expanded(
 flex: 2,
 child: Text(
 item.requestedBy.isNotEmpty ? item.requestedBy : '—',
 style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 // Date Raised
 Expanded(
 flex: 2,
 child: Text(
 item.dateRaised != null ? _formatDate(item.dateRaised!) : '—',
 style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
 ),
 ),
 // Status chip
 Expanded(
 flex: 2,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: statusColor.withOpacity(0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 item.status,
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: statusColor,
 ),
 textAlign: TextAlign.center,
 ),
 ),
 ),
 // Actions
 Expanded(
 flex: 1,
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 _actionIconButton(
 icon: Icons.edit_outlined,
 tooltip: 'Edit',
 onPressed: () => _showScopeChangeDialog(item),
 ),
 _actionIconButton(
 icon: Icons.content_copy,
 tooltip: 'Duplicate',
 onPressed: () => _duplicateScopeChange(item),
 ),
 _actionIconButton(
 icon: Icons.delete_outline,
 tooltip: 'Delete',
 color: const Color(0xFFEF4444),
 onPressed: () => _confirmDeleteScopeChange(item),
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
 ),
 ),
 ],
 ),
 );
 }

 void _showScopeChangeDialog([_ScopeChangeItem? existing]) {
 final isEdit = existing != null;
 final detailCtl = TextEditingController(text: existing?.detail ?? '');
 final crIdCtl = TextEditingController(text: existing?.crId ?? '');
 final requestedByCtl = TextEditingController(text: existing?.requestedBy ?? '');
 final notesCtl = TextEditingController(text: existing?.notes ?? '');
 String changeType = existing?.changeType ?? _changeTypes.first;
 String impactLevel = existing?.impactLevel ?? _impactLevels[2]; // Medium
 String status = existing?.status ?? _changeStatuses.first;
 DateTime? dateRaised = existing?.dateRaised;
 DateTime? decisionDate = existing?.decisionDate;

 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setDialogState) => LaunchModalShell(
 icon: isEdit ? Icons.edit_rounded : Icons.add_rounded,
 accent: const Color(0xFF4154F1),
 title: isEdit ? 'Edit Scope Change' : 'Add Scope Change',
 subtitle: isEdit
 ? 'Update the scope change request details.'
 : 'Log a new change request affecting the delivered scope.',
 body: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 LaunchModalTextField(
 label: 'Change Request ID',
 controller: crIdCtl,
 hint: 'e.g. CR-001',
 style: const TextStyle(fontFamily: appFontFamily),
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Change Description *',
 controller: detailCtl,
 hint: 'Describe the scope change',
 maxLines: 2,
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Type',
 value: changeType,
 items: _changeTypes,
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => changeType = v);
 }
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Impact',
 value: impactLevel,
 items: _impactLevels,
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => impactLevel = v);
 }
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDropdown<String>(
 label: 'Status',
 value: status,
 items: _changeStatuses,
 onChanged: (v) {
 if (v != null) {
 setDialogState(() => status = v);
 }
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Requested By',
 controller: requestedByCtl,
 hint: 'Who requested this change',
 ),
 const SizedBox(height: 12),
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: LaunchModalDateField(
 label: 'Date Raised',
 initialDate: dateRaised,
 onPicked: (d) =>
 setDialogState(() => dateRaised = d),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: LaunchModalDateField(
 label: 'Decision Date',
 initialDate: decisionDate,
 onPicked: (d) =>
 setDialogState(() => decisionDate = d),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 LaunchModalTextField(
 label: 'Notes',
 controller: notesCtl,
 hint: 'Additional context or remarks',
 maxLines: 3,
 ),
 ],
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.of(ctx).pop(),
 ),
 LaunchModalPrimaryButton(
 label: isEdit ? 'Save Changes' : 'Add Change',
 icon: isEdit ? Icons.check_rounded : Icons.add_rounded,
 onPressed: () {
 final newItem = _ScopeChangeItem(
 id: existing?.id ?? _newId(),
 detail: detailCtl.text.trim(),
 crId: crIdCtl.text.trim(),
 changeType: changeType,
 impactLevel: impactLevel,
 requestedBy: requestedByCtl.text.trim(),
 dateRaised: dateRaised,
 status: status,
 decisionDate: decisionDate,
 notes: notesCtl.text.trim(),
 );
 if (isEdit) {
 _updateScopeChange(newItem, notify: true);
 } else {
 setState(() => _scopeChanges.add(newItem));
 _scheduleSave();
 }
 Navigator.of(ctx).pop();
 },
 ),
 ],
 ),
 ),
 );
 }

 void _duplicateScopeChange(_ScopeChangeItem item) {
 setState(() {
 _scopeChanges.add(_ScopeChangeItem(
 id: _newId(),
 detail: '${item.detail} (copy)',
 crId: item.crId,
 changeType: item.changeType,
 impactLevel: item.impactLevel,
 requestedBy: item.requestedBy,
 dateRaised: item.dateRaised,
 status: item.status,
 decisionDate: item.decisionDate,
 notes: item.notes,
 ));
 });
 _scheduleSave();
 }

 void _duplicateAllScopeChanges() {
 setState(() {
 for (final item in List.of(_scopeChanges)) {
 _scopeChanges.add(_ScopeChangeItem(
 id: _newId(),
 detail: '${item.detail} (copy)',
 crId: item.crId,
 changeType: item.changeType,
 impactLevel: item.impactLevel,
 requestedBy: item.requestedBy,
 dateRaised: item.dateRaised,
 status: item.status,
 decisionDate: item.decisionDate,
 notes: item.notes,
 ));
 }
 });
 _scheduleSave();
 }

 void _confirmDeleteScopeChange(_ScopeChangeItem item) {
 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) => LaunchModalShell(
 icon: Icons.delete_outline_rounded,
 accent: const Color(0xFFEF4444),
 title: 'Delete Scope Change',
 subtitle: 'This action cannot be undone.',
 body: Text(
 'Are you sure you want to delete "${item.detail.isNotEmpty ? item.detail : 'this change'}"? '
 'Once removed, the entry cannot be recovered.',
 style: const TextStyle(
 fontSize: 14,
 color: Color(0xFF4B5563),
 height: 1.5,
 ),
 ),
 actions: [
 LaunchModalCancelButton(
 label: 'Cancel',
 onPressed: () => Navigator.of(ctx).pop(),
 ),
 LaunchModalDangerButton(
 label: 'Delete',
 onPressed: () {
 _deleteScopeChange(item.id);
 Navigator.of(ctx).pop();
 },
 ),
 ],
 ),
 );
 }

 // ─── Shared UI Helpers ──────────────────────────────────────────────

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
 borderSide: const BorderSide(color: Color(0xFFFDE68A)),
 ),
 );
 }

 Widget _buildMetricChip({
 required String label,
 required TextEditingController controller,
 }) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(16),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 '$label:',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: Color(0xFF374151)),
 ),
 const SizedBox(width: 8),
 SizedBox(
 width: 60,
 child: VoiceTextField(
 controller: controller,
 keyboardType: TextInputType.number,
 textAlign: TextAlign.right,
 style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
 decoration: const InputDecoration(
 hintText: '0',
 border: InputBorder.none,
 isDense: true,
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildLabeledField({
 required String label,
 required TextEditingController controller,
 required String hintText,
 int maxLines = 1,
 }) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151)),
 ),
 const SizedBox(height: 6),
 VoiceTextField(
 controller: controller,
 maxLines: maxLines,
 decoration: _inputDecoration(hintText),
 ),
 ],
 );
 }

 Widget _buildSectionHeader(String title, {String? badge}) {
 return Center(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 title,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 if (badge != null) ...[
 const SizedBox(height: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Text(
 badge,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Color(0xFF374151),
 ),
 ),
 ),
 ],
 ],
 ),
 );
 }

 Widget _buildTableTitle(String title) {
 return Center(
 child: Text(
 title,
 textAlign: TextAlign.center,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w800,
 color: Color(0xFF374151),
 ),
 ),
 );
 }

 Widget _buildResponsiveTable({
 required double minWidth,
 required Widget child,
 }) {
 return LayoutBuilder(
 builder: (context, constraints) {
 final tableWidth =
 constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: SizedBox(
 width: tableWidth,
 child: child,
 ),
 );
 },
 );
 }

 Widget _buildReadinessSummary() {
 final delivered = _parseNumber(_deliveredPercentController.text) ?? 0;
 final deferred = _parseNumber(_deferredCountController.text) ?? 0;
 final critical = _parseNumber(_criticalGapCountController.text) ?? 0;
 final approved = _parseNumber(_approvedChangesController.text) ?? 0;
 final unapproved = _parseNumber(_unapprovedChangesController.text) ?? 0;

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildTableTitle('Closeout Readiness Snapshot'),
 const SizedBox(height: 10),
 LayoutBuilder(
 builder: (context, constraints) {
 final compact = constraints.maxWidth < 820;
 final cards = [
 _ReadinessCard(
 title: 'Deliverables accepted',
 value: delivered >= 85 ? 'Ready' : 'Review',
 detail: '$delivered% of original scope recorded',
 icon: Icons.inventory_2_outlined,
 tone: delivered >= 85
 ? _ReadinessTone.success
 : _ReadinessTone.warning,
 ),
 _ReadinessCard(
 title: 'Open deferrals',
 value: deferred.toString(),
 detail: deferred == 0
 ? 'No deferred work logged'
 : 'Confirm owner and target date',
 icon: Icons.event_note_outlined,
 tone: deferred == 0
 ? _ReadinessTone.success
 : _ReadinessTone.warning,
 ),
 _ReadinessCard(
 title: 'Critical gaps',
 value: critical.toString(),
 detail: critical == 0
 ? 'No critical gaps logged'
 : 'Resolve before formal sign-off',
 icon: Icons.report_problem_outlined,
 tone: critical == 0
 ? _ReadinessTone.success
 : _ReadinessTone.danger,
 ),
 _ReadinessCard(
 title: 'Change control',
 value: '$approved/$unapproved',
 detail: 'Approved / unapproved changes',
 icon: Icons.rule_folder_outlined,
 tone: unapproved == 0
 ? _ReadinessTone.success
 : _ReadinessTone.warning,
 ),
 ];
 if (compact) {
 return Column(
 children: [
 for (final card in cards) ...[
 card,
 if (card != cards.last) const SizedBox(height: 10),
 ],
 ],
 );
 }
 return Row(
 children: [
 for (final card in cards) ...[
 Expanded(child: card),
 if (card != cards.last) const SizedBox(width: 10),
 ],
 ],
 );
 },
 ),
 ],
 );
 }

 // ─── Data mutation helpers ──────────────────────────────────────────

 void _addWorkPackage() {
 _showWorkPackageDialog();
 }

 void _updateWorkPackage(_WorkPackageItem item, {bool notify = false}) {
 final index = _workPackages.indexWhere((entry) => entry.id == item.id);
 if (index == -1) return;
 _workPackages[index] = item;
 if (notify && mounted) {
 setState(() {});
 }
 _scheduleSave();
 }

 void _deleteWorkPackage(String id) {
 setState(() => _workPackages.removeWhere((entry) => entry.id == id));
 _scheduleSave();
 }

 void _addCheckpoint() {
 _showCheckpointDialog();
 }

 void _updateCheckpoint(_CheckpointItem item, {bool notify = false}) {
 final index =
 _acceptanceCheckpoints.indexWhere((entry) => entry.id == item.id);
 if (index == -1) return;
 _acceptanceCheckpoints[index] = item;
 if (notify && mounted) {
 setState(() {});
 }
 _scheduleSave();
 }

 void _deleteCheckpoint(String id) {
 setState(
 () => _acceptanceCheckpoints.removeWhere((entry) => entry.id == id));
 _scheduleSave();
 }

 void _addAcceptanceTag() {
 _showAcceptanceTagDialog();
 }

 void _updateAcceptanceTag(_AcceptanceTagItem item, {bool notify = false}) {
 final index = _acceptanceTags.indexWhere((entry) => entry.id == item.id);
 if (index == -1) return;
 _acceptanceTags[index] = item;
 if (notify && mounted) {
 setState(() {});
 }
 _scheduleSave();
 }

 void _deleteAcceptanceTag(String id) {
 setState(() => _acceptanceTags.removeWhere((entry) => entry.id == id));
 _scheduleSave();
 }

 void _addScopeChange() {
 _showScopeChangeDialog();
 }

 void _updateScopeChange(_ScopeChangeItem item, {bool notify = false}) {
 final index = _scopeChanges.indexWhere((entry) => entry.id == item.id);
 if (index == -1) return;
 _scopeChanges[index] = item;
 if (notify && mounted) {
 setState(() {});
 }
 _scheduleSave();
 }

 void _deleteScopeChange(String id) {
 setState(() => _scopeChanges.removeWhere((entry) => entry.id == id));
 _scheduleSave();
 }

 String _newId() => DateTime.now().microsecondsSinceEpoch.toString();


 Widget _buildTipRow(BuildContext context) {
 return Row(
 children: [
 Icon(Icons.lightbulb_outline, size: 18, color: const Color(0xFFFFC812)),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 'If someone reads only this page, can they quickly see what was delivered, what moved, and that the right people have agreed?',
 style: TextStyle(
 fontSize: 13,
 color: const Color(0xFF9CA3AF),
 fontStyle: FontStyle.italic),
 ),
 ),
 ],
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Scope Completion',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_scope_completion_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

// ─── Widget Classes ────────────────────────────────────────────────────────

class _ContentCard extends StatelessWidget {
 final Widget child;

 const _ContentCard({required this.child});

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: child,
 );
 }
}


enum _ReadinessTone { success, warning, danger }

class _ReadinessCard extends StatelessWidget {
 const _ReadinessCard({
 required this.title,
 required this.value,
 required this.detail,
 required this.icon,
 required this.tone,
 });

 final String title;
 final String value;
 final String detail;
 final IconData icon;
 final _ReadinessTone tone;

 Color get _accent {
 switch (tone) {
 case _ReadinessTone.success:
 return const Color(0xFF059669);
 case _ReadinessTone.warning:
 return const Color(0xFFD97706);
 case _ReadinessTone.danger:
 return const Color(0xFFDC2626);
 }
 }

 Color get _background {
 switch (tone) {
 case _ReadinessTone.success:
 return const Color(0xFFECFDF5);
 case _ReadinessTone.warning:
 return const Color(0xFFFFFBEB);
 case _ReadinessTone.danger:
 return const Color(0xFFFEF2F2);
 }
 }

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: _background,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: _accent.withOpacity(0.18)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Icon(icon, size: 18, color: _accent),
 const Spacer(),
 Text(
 value,
 textAlign: TextAlign.right,
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w800,
 color: _accent,
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 Text(
 title,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w800,
 color: Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 4),
 Text(
 detail,
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w500,
 color: Color(0xFF6B7280),
 ),
 ),
 ],
 ),
 );
 }
}

class _InlineEmptyState extends StatelessWidget {
 const _InlineEmptyState({
 required this.title,
 required this.message,
 this.icon = Icons.info_outline,
 });

 final String title;
 final String message;
 final IconData icon;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Row(
 children: [
 Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
 const SizedBox(width: 8),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF111827)),
 ),
 const SizedBox(height: 2),
 Text(
 message,
 style:
 const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }
}

// ─── Data Model Classes ────────────────────────────────────────────────────

class _WorkPackageItem {
 _WorkPackageItem({
 required this.id,
 required this.title,
 required this.owner,
 required this.milestone,
 required this.status,
 required this.impact,
 this.wbsCode = '',
 this.baselineDate,
 this.actualDate,
 this.percentComplete = 0,
 this.notes = '',
 });

 final String id;
 final String title;
 final String owner;
 final String milestone;
 final String status;
 final String impact;
 final String wbsCode;
 final DateTime? baselineDate;
 final DateTime? actualDate;
 final int percentComplete;
 final String notes;

 _WorkPackageItem copyWith({
 String? title,
 String? owner,
 String? milestone,
 String? status,
 String? impact,
 String? wbsCode,
 DateTime? baselineDate,
 DateTime? actualDate,
 int? percentComplete,
 String? notes,
 }) {
 return _WorkPackageItem(
 id: id,
 title: title ?? this.title,
 owner: owner ?? this.owner,
 milestone: milestone ?? this.milestone,
 status: status ?? this.status,
 impact: impact ?? this.impact,
 wbsCode: wbsCode ?? this.wbsCode,
 baselineDate: baselineDate ?? this.baselineDate,
 actualDate: actualDate ?? this.actualDate,
 percentComplete: percentComplete ?? this.percentComplete,
 notes: notes ?? this.notes,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'title': title,
 'owner': owner,
 'milestone': milestone,
 'status': status,
 'impact': impact,
 'wbsCode': wbsCode,
 'baselineDate': baselineDate?.toIso8601String(),
 'actualDate': actualDate?.toIso8601String(),
 'percentComplete': percentComplete,
 'notes': notes,
 };

 static List<_WorkPackageItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _WorkPackageItem(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 title: map['title']?.toString() ?? '',
 owner: map['owner']?.toString() ?? '',
 milestone: map['milestone']?.toString() ?? '',
 status: map['status']?.toString() ?? 'Delivered',
 impact: map['impact']?.toString() ?? 'Medium',
 wbsCode: map['wbsCode']?.toString() ?? '',
 baselineDate: _parseDate(map['baselineDate']),
 actualDate: _parseDate(map['actualDate']),
 percentComplete: _parseInt(map['percentComplete']),
 notes: map['notes']?.toString() ?? '',
 );
 }).toList();
 }

 static DateTime? _parseDate(dynamic v) {
 if (v == null) return null;
 return DateTime.tryParse(v.toString());
 }

 static int _parseInt(dynamic v) {
 if (v == null) return 0;
 return int.tryParse(v.toString()) ?? 0;
 }
}

class _CheckpointItem {
 _CheckpointItem({
 required this.id,
 required this.title,
 required this.owner,
 required this.status,
 this.refCode = '',
 this.dueDate,
 this.signOffDate,
 this.evidence = '',
 this.notes = '',
 });

 final String id;
 final String title;
 final String owner;
 final String status;
 final String refCode;
 final DateTime? dueDate;
 final DateTime? signOffDate;
 final String evidence;
 final String notes;

 _CheckpointItem copyWith({
 String? title,
 String? owner,
 String? status,
 String? refCode,
 DateTime? dueDate,
 DateTime? signOffDate,
 String? evidence,
 String? notes,
 }) {
 return _CheckpointItem(
 id: id,
 title: title ?? this.title,
 owner: owner ?? this.owner,
 status: status ?? this.status,
 refCode: refCode ?? this.refCode,
 dueDate: dueDate ?? this.dueDate,
 signOffDate: signOffDate ?? this.signOffDate,
 evidence: evidence ?? this.evidence,
 notes: notes ?? this.notes,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'title': title,
 'owner': owner,
 'status': status,
 'refCode': refCode,
 'dueDate': dueDate?.toIso8601String(),
 'signOffDate': signOffDate?.toIso8601String(),
 'evidence': evidence,
 'notes': notes,
 };

 static List<_CheckpointItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _CheckpointItem(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 title: map['title']?.toString() ?? '',
 owner: map['owner']?.toString() ?? '',
 status: map['status']?.toString() ?? 'Pending',
 refCode: map['refCode']?.toString() ?? '',
 dueDate: _parseDate(map['dueDate']),
 signOffDate: _parseDate(map['signOffDate']),
 evidence: map['evidence']?.toString() ?? '',
 notes: map['notes']?.toString() ?? '',
 );
 }).toList();
 }

 static DateTime? _parseDate(dynamic v) {
 if (v == null) return null;
 return DateTime.tryParse(v.toString());
 }
}

class _AcceptanceTagItem {
 _AcceptanceTagItem({
 required this.id,
 required this.label,
 required this.status,
 this.category = 'Sponsor',
 this.verifiedBy = '',
 this.dateVerified,
 this.notes = '',
 });

 final String id;
 final String label;
 final String status;
 final String category;
 final String verifiedBy;
 final DateTime? dateVerified;
 final String notes;

 _AcceptanceTagItem copyWith({
 String? label,
 String? status,
 String? category,
 String? verifiedBy,
 DateTime? dateVerified,
 String? notes,
 }) {
 return _AcceptanceTagItem(
 id: id,
 label: label ?? this.label,
 status: status ?? this.status,
 category: category ?? this.category,
 verifiedBy: verifiedBy ?? this.verifiedBy,
 dateVerified: dateVerified ?? this.dateVerified,
 notes: notes ?? this.notes,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'label': label,
 'status': status,
 'category': category,
 'verifiedBy': verifiedBy,
 'dateVerified': dateVerified?.toIso8601String(),
 'notes': notes,
 };

 static List<_AcceptanceTagItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _AcceptanceTagItem(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 label: map['label']?.toString() ?? '',
 status: map['status']?.toString() ?? 'Pending',
 category: map['category']?.toString() ?? 'Sponsor',
 verifiedBy: map['verifiedBy']?.toString() ?? '',
 dateVerified: _parseDate(map['dateVerified']),
 notes: map['notes']?.toString() ?? '',
 );
 }).toList();
 }

 static DateTime? _parseDate(dynamic v) {
 if (v == null) return null;
 return DateTime.tryParse(v.toString());
 }
}

class _ScopeChangeItem {
 _ScopeChangeItem({
 required this.id,
 required this.detail,
 this.crId = '',
 this.changeType = 'Scope',
 this.impactLevel = 'Medium',
 this.requestedBy = '',
 this.dateRaised,
 this.status = 'Open',
 this.decisionDate,
 this.notes = '',
 });

 final String id;
 final String detail;
 final String crId;
 final String changeType;
 final String impactLevel;
 final String requestedBy;
 final DateTime? dateRaised;
 final String status;
 final DateTime? decisionDate;
 final String notes;

 _ScopeChangeItem copyWith({
 String? detail,
 String? crId,
 String? changeType,
 String? impactLevel,
 String? requestedBy,
 DateTime? dateRaised,
 String? status,
 DateTime? decisionDate,
 String? notes,
 }) {
 return _ScopeChangeItem(
 id: id,
 detail: detail ?? this.detail,
 crId: crId ?? this.crId,
 changeType: changeType ?? this.changeType,
 impactLevel: impactLevel ?? this.impactLevel,
 requestedBy: requestedBy ?? this.requestedBy,
 dateRaised: dateRaised ?? this.dateRaised,
 status: status ?? this.status,
 decisionDate: decisionDate ?? this.decisionDate,
 notes: notes ?? this.notes,
 );
 }

 Map<String, dynamic> toMap() => {
 'id': id,
 'detail': detail,
 'crId': crId,
 'changeType': changeType,
 'impactLevel': impactLevel,
 'requestedBy': requestedBy,
 'dateRaised': dateRaised?.toIso8601String(),
 'status': status,
 'decisionDate': decisionDate?.toIso8601String(),
 'notes': notes,
 };

 static List<_ScopeChangeItem> fromList(dynamic data) {
 if (data is! List) return [];
 return data.map((item) {
 final map = Map<String, dynamic>.from(item as Map? ?? {});
 return _ScopeChangeItem(
 id: map['id']?.toString() ??
 DateTime.now().microsecondsSinceEpoch.toString(),
 detail: map['detail']?.toString() ?? '',
 crId: map['crId']?.toString() ?? '',
 changeType: map['changeType']?.toString() ?? 'Scope',
 impactLevel: map['impactLevel']?.toString() ?? 'Medium',
 requestedBy: map['requestedBy']?.toString() ?? '',
 dateRaised: _parseDate(map['dateRaised']),
 status: map['status']?.toString() ?? 'Open',
 decisionDate: _parseDate(map['decisionDate']),
 notes: map['notes']?.toString() ?? '',
 );
 }).toList();
 }

 static DateTime? _parseDate(dynamic v) {
 if (v == null) return null;
 return DateTime.tryParse(v.toString());
 }
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
