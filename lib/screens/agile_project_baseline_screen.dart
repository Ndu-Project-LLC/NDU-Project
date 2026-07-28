import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/agile_project_baseline.dart';
import 'package:ndu_project/models/agile_release_plan.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/roadmap_deliverable.dart';
import 'package:ndu_project/models/roadmap_sprint.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/agile_project_baseline_service.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';
import 'package:ndu_project/services/epic_feature_service.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/roadmap_service.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
const Color _kBackground = Colors.white;
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);

class AgileProjectBaselineScreen extends StatefulWidget {
 const AgileProjectBaselineScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const AgileProjectBaselineScreen()),
 );
 }

 @override
 State<AgileProjectBaselineScreen> createState() =>
 _AgileProjectBaselineScreenState();
}

class _AgileProjectBaselineScreenState
 extends State<AgileProjectBaselineScreen> {
 static const List<String> _statusOptions = ['Draft', 'Ready', 'Approved'];
 static const List<String> _impactOptions = ['High', 'Medium', 'Low'];
 static const List<String> _assumptionCategories = [
 'Team',
 'Schedule',
 'Vendor',
 'Technical',
 'Business',
 'Compliance',
 'Other',
 ];

 final TextEditingController _releaseLabelController = TextEditingController();
 final TextEditingController _capacityController = TextEditingController();
 final TextEditingController _approverSearchController =
 TextEditingController();
 final FocusNode _approverFocusNode = FocusNode();
 final TextEditingController _approvalNotesController =
 RichTextEditingController();
 String _backlogDoD = '';
 double _epicTotalPoints = 0;
 final TextEditingController _changeControlController =
 RichTextEditingController();
 final List<_AssumptionRowState> _assumptionRows = [];
 final _Debouncer _saveDebouncer = _Debouncer();

 List<RoadmapSprint> _sprints = <RoadmapSprint>[];
 List<RoadmapDeliverable> _deliverables = <RoadmapDeliverable>[];
 List<_ApproverOption> _approverOptions = <_ApproverOption>[];
 String _selectedStatus = 'Draft';
 String? _selectedApproverId;
 DateTime? _selectedReleaseDate;
 DateTime? _selectedApprovalDate;
 int _formalRiskCount = 0;
 int _highRiskCount = 0;
 bool _isLoading = true;
 bool _isHydrating = true;
 bool _isSaving = false;
 DateTime? _lastSavedAt;

 String? get _projectId {
 try {
 return ProjectDataInherited.maybeOf(context)?.projectData.projectId;
 } catch (e) {
 return null;
 }
 }

 ProjectDataModel get _projectData => ProjectDataHelper.getData(context);

 @override
 void initState() {
 super.initState();
 for (final controller in _allControllers) {
 controller.addListener(_scheduleSave);
 }
 WidgetsBinding.instance.addPostFrameCallback((_) => _load());
 }

 List<TextEditingController> get _allControllers => [
 _releaseLabelController,
 _capacityController,
 _approverSearchController,
 _approvalNotesController,
 _changeControlController,
 ];

 @override
 void dispose() {
 _saveDebouncer.dispose();
 _approverFocusNode.dispose();
 for (final controller in _allControllers) {
 controller.dispose();
 }
 for (final row in _assumptionRows) {
 row.dispose();
 }
 super.dispose();
 }

 Future<void> _load() async {
 final projectId = _projectId;
 if (projectId == null || projectId.isEmpty) {
 if (mounted) setState(() => _isLoading = false);
 return;
 }

 final results = await Future.wait<dynamic>([
 AgileProjectBaselineService.load(projectId),
 RoadmapService.loadAll(projectId: projectId),
 _loadApproverOptions(_projectData),
 _loadRiskSummary(projectId),
 AgileWireframeService.loadBacklogGovernance(projectId),
 EpicFeatureService.loadEpics(projectId),
 AgileWireframeService.loadReleasePlans(projectId),
 ]);

 if (!mounted) return;

 final baseline = results[0] as AgileProjectBaseline;
 final roadmap = results[1] as ({
 List<RoadmapSprint> sprints,
 List<RoadmapDeliverable> deliverables
 });
 final approvers = results[2] as List<_ApproverOption>;
 final risk = results[3] as _RiskSummary;
 final backlogGov = results[4] as Map<String, dynamic>;
 final epics = results[5] as List<Epic>;
 final releasePlans = results[6] as List<AgileReleasePlan>;
 _backlogDoD = backlogGov['definition_of_done'] as String? ?? '';
 _epicTotalPoints = epics.fold<double>(
 0, (sum, e) => sum + e.totalStoryPoints);

 _sprints = roadmap.sprints;
 _deliverables = roadmap.deliverables;
 _approverOptions = approvers;
 _formalRiskCount = risk.totalCount;
 _highRiskCount = risk.highCount;
 _hydrateFromBaseline(baseline, releasePlans);

 setState(() {
 _isHydrating = false;
 _isLoading = false;
 });
 }

 void _hydrateFromBaseline(AgileProjectBaseline baseline,
 [List<AgileReleasePlan> releasePlans = const []]) {
 _selectedStatus = _statusOptions.contains(baseline.status)
 ? baseline.status
 : _statusOptions.first;
 _selectedApproverId =
 baseline.approverUserId.isEmpty ? null : baseline.approverUserId;
 _selectedApprovalDate = baseline.approvalDate;

 // Prefer baseline values, fall back to first release plan
 _selectedReleaseDate =
 baseline.targetReleaseDate ?? releasePlans.firstOrNull?.releaseDate;
 _releaseLabelController.text = baseline.targetReleaseLabel.isNotEmpty
 ? baseline.targetReleaseLabel
 : (releasePlans.firstOrNull?.releaseLabel ?? '');
 _capacityController.text = baseline.capacityThresholdPointsPerSprint == null
 ? ''
 : baseline.capacityThresholdPointsPerSprint.toString();
 if (baseline.approverUserId.isNotEmpty) {
 final match =
 _approverOptions.where((o) => o.id == baseline.approverUserId);
 _approverSearchController.text =
 match.isNotEmpty ? match.first.displayLabel : baseline.approverName;
 } else if (baseline.approverFallbackName.isNotEmpty) {
 _approverSearchController.text = baseline.approverFallbackName;
 }
 _approvalNotesController.text = baseline.approvalNotes;
 _changeControlController.text = baseline.changeControl;

 for (final row in _assumptionRows) {
 row.dispose();
 }
 _assumptionRows
 ..clear()
 ..addAll(
 (baseline.assumptions.isEmpty
 ? [AgileBaselineAssumption()]
 : baseline.assumptions)
 .map((item) => _AssumptionRowState(
 category: item.category,
 impact: item.impact,
 text: item.text,
 onChanged: _scheduleSave,
 )),
 );
 }

 Future<List<_ApproverOption>> _loadApproverOptions(
 ProjectDataModel data) async {
 final seen = <String>{};
 final options = <_ApproverOption>[];

 void addOption({
 required String id,
 required String name,
 required String email,
 required String role,
 required String source,
 }) {
 final key = id.trim().isNotEmpty
 ? 'id:${id.trim()}'
 : email.trim().isNotEmpty
 ? 'email:${email.trim().toLowerCase()}'
 : 'name:${name.trim().toLowerCase()}';
 if (name.trim().isEmpty && email.trim().isEmpty) return;
 if (!seen.add(key)) return;
 options.add(
 _ApproverOption(
 id: id.trim(),
 name: name.trim(),
 email: email.trim(),
 role: role.trim(),
 source: source,
 ),
 );
 }

 for (final member in data.teamMembers) {
 addOption(
 id: member.id,
 name: member.name,
 email: member.email,
 role: member.role,
 source: 'Project Team',
 );
 }

 try {
 final users = await UserService.searchUsers('');
 for (final user in users) {
 addOption(
 id: user.uid,
 name: user.displayName,
 email: user.email,
 role: user.isAdmin ? 'Admin' : 'Member',
 source: 'Company Members',
 );
 }
 } catch (e) { debugPrint('Error: $e'); }

 options.sort((a, b) =>
 a.displayLabel.toLowerCase().compareTo(b.displayLabel.toLowerCase()));
 return options;
 }

 Future<_RiskSummary> _loadRiskSummary(String projectId) async {
 try {
 final snapshot = await FirebaseFirestore.instance
 .collection('projects')
 .doc(projectId)
 .collection('risk_assessment_entries')
 .get();
 var total = 0;
 var high = 0;
 for (final doc in snapshot.docs) {
 final data = doc.data();
 final status = (data['status'] ?? '').toString().toLowerCase();
 if (status == 'closed') continue;
 total += 1;
 final probability =
 (data['probability'] ?? '').toString().toLowerCase();
 final impact = (data['impact'] ?? '').toString().toLowerCase();
 final score = (data['score'] ?? '').toString().toLowerCase();
 if (probability == 'high' || impact == 'high' || score == 'high') {
 high += 1;
 }
 }
 return _RiskSummary(totalCount: total, highCount: high);
 } catch (e) {
 return const _RiskSummary(totalCount: 0, highCount: 0);
 }
 }

 void _scheduleSave() {
 if (_isHydrating) return;
 _saveDebouncer.run(_save);
 if (mounted) setState(() {});
 }

 Future<void> _save() async {
 final projectId = _projectId;
 if (projectId == null || projectId.isEmpty) return;

 final user = FirebaseAuth.instance.currentUser;
 final searchTrimmed = _approverSearchController.text.trim();

 final selectedApprover = _approverOptions
 .where((option) {
 return option.id == _selectedApproverId;
 })
 .cast<_ApproverOption?>()
 .firstWhere(
 (option) => option != null,
 orElse: () => null,
 );

 final isFallback = selectedApprover == null && searchTrimmed.isNotEmpty;

 final baseline = AgileProjectBaseline(
 status: _selectedStatus,
 targetReleaseLabel: _releaseLabelController.text.trim(),
 targetReleaseDate: _selectedReleaseDate,
 approverUserId: _selectedApproverId ?? '',
 approverName: selectedApprover?.name ?? '',
 approverFallbackName: isFallback ? searchTrimmed : '',
 approvalDate: _selectedApprovalDate,
 approvalNotes: _approvalNotesController.text.trim(),
 capacityThresholdPointsPerSprint:
 int.tryParse(_capacityController.text.trim()),
 changeControl: _changeControlController.text.trim(),
 assumptions: _assumptionRows
 .map((row) => row.toAssumption())
 .where((item) =>
 item.category.trim().isNotEmpty || item.text.trim().isNotEmpty)
 .toList(),
 );

 if (baseline.status == 'Approved' && baseline.approvalDate == null) {
 baseline.approvalDate = DateTime.now();
 _selectedApprovalDate = baseline.approvalDate;
 }

 if (mounted) setState(() => _isSaving = true);
 try {
 await AgileProjectBaselineService.save(
 projectId: projectId,
 baseline: baseline,
 updatedBy: user?.uid ?? '',
 );
 if (!mounted) return;
 setState(() {
 _isSaving = false;
 _lastSavedAt = DateTime.now();
 });
 } catch (e) {
 if (!mounted) return;
 setState(() => _isSaving = false);
 }
 }

 Map<String, int> get _pointsBySprint {
 final map = <String, int>{};
 for (final deliverable in _deliverables) {
 if (deliverable.sprintId.trim().isEmpty) continue;
 map.update(
 deliverable.sprintId,
 (value) => value + deliverable.storyPoints,
 ifAbsent: () => deliverable.storyPoints,
 );
 }
 return map;
 }

 int get _totalPlannedPoints =>
 _deliverables.fold<int>(0, (total, item) => total + item.storyPoints);

 double get _averagePlannedVelocity {
 final values = _pointsBySprint.values.where((value) => value > 0).toList();
 if (values.isEmpty) return 0;
 final total = values.fold<int>(0, (acc, value) => acc + value);
 return total / values.length;
 }

 int get _highestSprintLoad {
 if (_pointsBySprint.isEmpty) return 0;
 return _pointsBySprint.values.reduce((a, b) => a > b ? a : b);
 }

 int get _blockedDeliverablesCount => _deliverables
 .where((item) => item.status == RoadmapDeliverableStatus.blocked)
 .length;

 int get _deliverablesWithoutSprintCount =>
 _deliverables.where((item) => item.sprintId.trim().isEmpty).length;

 int get _deliverablesWithoutEstimateCount =>
 _deliverables.where((item) => item.storyPoints <= 0).length;

 int get _dependencyCount => _deliverables.fold<int>(
 0, (total, item) => total + item.dependencies.length);

 int get _blockedDependencyCount {
 var count = 0;
 for (final item in _deliverables) {
 for (final depId in item.dependencies) {
 final dependency = _deliverables.cast<RoadmapDeliverable?>().firstWhere(
 (candidate) => candidate?.id == depId,
 orElse: () => null,
 );
 final unresolved = dependency == null ||
 dependency.status != RoadmapDeliverableStatus.completed;
 if (unresolved) count += 1;
 }
 }
 return count;
 }

 List<_SprintLoad> get _overCapacitySprints {
 final threshold = int.tryParse(_capacityController.text.trim());
 if (threshold == null || threshold <= 0) return <_SprintLoad>[];
 return _sprints
 .map((sprint) => _SprintLoad(
 sprint: sprint,
 points: _pointsBySprint[sprint.id] ?? 0,
 ))
 .where((item) => item.points > threshold)
 .toList();
 }

 List<_BaselineWarning> get _warnings {
 final items = <_BaselineWarning>[];

 void add(String title, String detail, Color color) {
 items.add(_BaselineWarning(title: title, detail: detail, color: color));
 }

 if (_releaseLabelController.text.trim().isEmpty) {
 add(
 'Release target missing',
 'Add a release label so the baseline has a named delivery target.',
 const Color(0xFFB45309),
 );
 }
 if ((_selectedApproverId ?? '').isEmpty &&
 _approverSearchController.text.trim().isEmpty) {
 add(
 'Approver missing',
 'Choose an approver from the user list or type a fallback name.',
 const Color(0xFFB45309),
 );
 }
 if (_changeControlController.text.trim().isEmpty) {
 add(
 'Change control missing',
 'Describe how scope and baseline changes are handled.',
 const Color(0xFFB45309),
 );
 }
 if (_assumptionRows.every((row) => row.isEmpty)) {
 add(
 'Assumptions missing',
 'Add structured assumptions with category and impact.',
 const Color(0xFFB45309),
 );
 }
 if (_deliverablesWithoutSprintCount > 0) {
 add(
 'Unscheduled deliverables',
 '$_deliverablesWithoutSprintCount deliverable(s) are not assigned to a sprint.',
 const Color(0xFFDC2626),
 );
 }
 if (_deliverablesWithoutEstimateCount > 0) {
 add(
 'Missing estimates',
 '$_deliverablesWithoutEstimateCount deliverable(s) have missing story points.',
 const Color(0xFFDC2626),
 );
 }
 if (_blockedDeliverablesCount > 0) {
 add(
 'Blocked work present',
 '$_blockedDeliverablesCount deliverable(s) are blocked in the roadmap.',
 const Color(0xFFDC2626),
 );
 }
 if (_overCapacitySprints.isNotEmpty) {
 add(
 'Over-capacity sprints',
 '${_overCapacitySprints.length} sprint(s) exceed the manual threshold.',
 const Color(0xFFDC2626),
 );
 }
 if (_formalRiskCount == 0) {
 add(
 'No formal risk register entries',
 'The risk register is empty, so only inferred risk is available.',
 const Color(0xFFD97706),
 );
 }
 return items;
 }

 String get _riskSummaryText {
 final parts = <String>[];
 if (_blockedDeliverablesCount > 0) parts.add('blocked delivery risk');
 if (_overCapacitySprints.isNotEmpty) parts.add('capacity risk');
 if (_deliverablesWithoutEstimateCount > 0 ||
 _deliverablesWithoutSprintCount > 0) {
 parts.add('planning hygiene risk');
 }
 if (_highRiskCount > 0) parts.add('formal high-risk items');
 if (parts.isEmpty) {
 return 'Low inferred risk. No blocked work, no over-capacity sprint, and no active high-risk signal were detected.';
 }
 return 'Risk signals detected: ${parts.join(', ')}.';
 }

 Future<void> _pickReleaseDate() async {
 final picked = await showDatePicker(
 context: context,
 initialDate: _selectedReleaseDate ?? DateTime.now(),
 firstDate: DateTime(2020),
 lastDate: DateTime(2100),
 );
 if (picked == null) return;
 setState(() => _selectedReleaseDate = picked);
 _scheduleSave();
 }

 Future<void> _pickApprovalDate() async {
 final picked = await showDatePicker(
 context: context,
 initialDate: _selectedApprovalDate ?? DateTime.now(),
 firstDate: DateTime(2020),
 lastDate: DateTime(2100),
 );
 if (picked == null) return;
 setState(() => _selectedApprovalDate = picked);
 _scheduleSave();
 }

 void _clearReleaseDate() {
 setState(() => _selectedReleaseDate = null);
 _scheduleSave();
 }

 void _addAssumption() {
 setState(() {
 _assumptionRows.add(
 _AssumptionRowState(
 category: '',
 impact: 'Medium',
 text: '',
 onChanged: _scheduleSave,
 ),
 );
 });
 _scheduleSave();
 }

  Future<void> _removeAssumption(_AssumptionRowState row) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Assumption',
      itemLabel: row.textController.text.isNotEmpty ? row.textController.text : null,
    );
    if (!confirmed) return;
    if (_assumptionRows.length == 1) {
      row.clear();
      _scheduleSave();
      return;
    }
    setState(() {
      row.dispose();
      _assumptionRows.remove(row);
    });
    _scheduleSave();
  }

 String _describeSprintCadence() {
 final durations = _sprints
 .where((sprint) => sprint.startDate != null && sprint.endDate != null)
 .map((sprint) => sprint.durationInDays)
 .toList();
 if (durations.isEmpty) return 'Sprint dates not fully defined';
 final avg = durations.reduce((a, b) => a + b) / durations.length;
 return '${avg.toStringAsFixed(0)} day average sprint length';
 }

 @override
 Widget build(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 final horizontalPadding = isMobile ? 20.0 : 32.0;

 return Scaffold(
 backgroundColor: _kBackground,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Agile Delivery Model - Project Baseline',
 ),
 ),
 Expanded(
 child: Stack(
 children: [
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Agile Delivery Model - Project Baseline',
 ),
 ),
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding,
 vertical: 24,
 ),
 child: LayoutBuilder(
 builder: (context, constraints) {
 final width = constraints.maxWidth;
 const gap = 24.0;
 final twoCol = width >= 980;
 final halfWidth = twoCol ? (width - gap) / 2 : width;
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 PlanningPhaseHeader(
 title: 'Agile Project Baseline',
onBack: () =>
 PlanningPhaseNavigation.goToPrevious(
 context, 'agile_project_baseline'),
 onForward: () => PlanningPhaseNavigation.goToNext(
 context, 'agile_project_baseline'), onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _TopHeader(
 status: _selectedStatus,
 isSaving: _isSaving,
 lastSavedAt: _lastSavedAt,
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(
 context, 'agile_project_baseline'),
 onForward: () => PlanningPhaseNavigation.goToNext(
 context, 'agile_project_baseline'),
 ),
 const SizedBox(height: 12),
 const Text(
 'Approve and tune the live agile baseline using roadmap scope, sprint loads, and delivery risk.',
 style: TextStyle(fontSize: 14, color: _kMuted),
 ),
 const SizedBox(height: 20),
 const PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Agile Project Baseline',
 noteKey: 'planning_agile_project_baseline_notes',
 checkpoint: 'agile_project_baseline',
 description:
 'Capture baseline context, approval rationale, and live roadmap decisions.',
 ),
 const SizedBox(height: 24),
 if (_isLoading)
 const Padding(
 padding: EdgeInsets.symmetric(vertical: 80),
 child:
 Center(child: CircularProgressIndicator()),
 )
 else ...[
 _MetricsRow(
 averageVelocity: _averagePlannedVelocity,
 capacityThreshold: int.tryParse(
 _capacityController.text.trim()),
 totalPoints: _totalPlannedPoints,
 sprintCount: _sprints.length,
 highestSprintLoad: _highestSprintLoad,
 epicTotalPoints: _epicTotalPoints,
 ),
 const SizedBox(height: 24),
 Wrap(
 spacing: gap,
 runSpacing: gap,
 children: [
 SizedBox(
 width: halfWidth,
 child: _buildApprovalForm(),
 ),
 SizedBox(
 width: halfWidth,
 child: _buildWarningsCard(),
 ),
 ],
 ),
 const SizedBox(height: 24),
 Wrap(
 spacing: gap,
 runSpacing: gap,
 children: [
 SizedBox(
 width: halfWidth,
 child: _ReadOnlyDoDCard(
 definitionOfDone: _backlogDoD,
 ),
 ),
 SizedBox(
 width: halfWidth,
 child: _RichTextCard(
 title: 'Change Control',
 subtitle:
 'Custom workflow for evaluating changes to the live baseline.',
 controller: _changeControlController,
 ),
 ),
 ],
 ),
 const SizedBox(height: 24),
 _buildAssumptionsCard(),
 const SizedBox(height: 24),
 Wrap(
 spacing: gap,
 runSpacing: gap,
 children: [
 SizedBox(
 width: halfWidth,
 child: _buildScopeCard(),
 ),
 SizedBox(
 width: halfWidth,
 child: _buildRiskCard(),
 ),
 ],
 ),
 ],
 const SizedBox(height: 24),
 LaunchPhaseNavigation(
 backLabel: PlanningPhaseNavigation.backLabel(
 'agile_project_baseline'),
 nextLabel: PlanningPhaseNavigation.nextLabel(
 'agile_project_baseline'),
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(
 context, 'agile_project_baseline'),
 onNext: () => PlanningPhaseNavigation.goToNext(
 context, 'agile_project_baseline'),
 ),
 const SizedBox(height: 40),
 ],
 );
 },
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

 Widget _buildApprovalForm() {
 final releaseDateText = _selectedReleaseDate == null
 ? 'Optional date'
 : DateFormat('dd MMM yyyy').format(_selectedReleaseDate!);
 final approvalDateText = _selectedApprovalDate == null
 ? 'Set approval date'
 : 'Approval Date: ${DateFormat('dd MMM yyyy').format(_selectedApprovalDate!)}';

 return _SectionCard(
 title: 'Baseline Approval Form',
 subtitle:
 'Edit release target, approver, approval state, and capacity policy.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Wrap(
 spacing: 16,
 runSpacing: 16,
 children: [
 SizedBox(
 width: 220,
 child: _DropdownField<String>(
 label: 'Status',
 value: _selectedStatus,
 items: _statusOptions,
 onChanged: (value) {
 if (value == null) return;
 setState(() {
 _selectedStatus = value;
 if (value == 'Approved' &&
 _selectedApprovalDate == null) {
 _selectedApprovalDate = DateTime.now();
 }
 });
 _scheduleSave();
 },
 ),
 ),
 SizedBox(
 width: 220,
 child: VoiceTextField(
 controller: _releaseLabelController,
 decoration: const InputDecoration(
 labelText: 'Release Label',
 hintText: 'Pilot Release / R1 / Wave 2',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 SizedBox(
 width: 220,
 child: VoiceTextField(
 controller: _capacityController,
 keyboardType: TextInputType.number,
 decoration: const InputDecoration(
 labelText: 'Capacity Threshold',
 hintText: 'Points per sprint',
 border: OutlineInputBorder(),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 SizedBox(
 width: 360,
 child: _ApproverAutocomplete(
 controller: _approverSearchController,
 focusNode: _approverFocusNode,
 options: _approverOptions,
 onSelectedOption: (option) {
 setState(() => _selectedApproverId = option.id);
 _scheduleSave();
 },
 onSubmittedFallback: (text) {
 setState(() => _selectedApproverId = null);
 _scheduleSave();
 },
 ),
 ),
 const SizedBox(height: 16),
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [
 OutlinedButton.icon(
 onPressed: _pickReleaseDate,
 icon: const Icon(Icons.event_outlined, size: 18),
 label: Text('Release Date: $releaseDateText'),
 ),
 if (_selectedReleaseDate != null)
 TextButton(
 onPressed: _clearReleaseDate,
 child: const Text('Clear release date'),
 ),
 OutlinedButton.icon(
 onPressed: _pickApprovalDate,
 icon: const Icon(Icons.verified_user_outlined, size: 18),
 label: Text(approvalDateText),
 ),
 ],
 ),
 const SizedBox(height: 16),
 const Text(
 'Approval Notes',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: _kHeadline,
 ),
 ),
 const SizedBox(height: 8),
 const SizedBox(height: 8),
 VoiceTextField(
 controller: _approvalNotesController,
 minLines: 4,
 maxLines: 8,
 decoration: const InputDecoration(
 hintText:
 'Record approval rationale, exceptions, or reviewer notes.',
 border: OutlineInputBorder(),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildWarningsCard() {
 final warnings = _warnings;
 return _SectionCard(
 title: 'Warnings & Checks',
 subtitle: 'Warnings stay visible, but they do not block approval.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [
 _MiniPill(
 label: '${warnings.length} warnings',
 color: warnings.isEmpty
 ? const Color(0xFF10B981)
 : const Color(0xFFF59E0B),
 ),
 _MiniPill(
 label: '${_overCapacitySprints.length} over capacity',
 color: _overCapacitySprints.isEmpty
 ? const Color(0xFF10B981)
 : const Color(0xFFEF4444),
 ),
 _MiniPill(
 label: '$_blockedDeliverablesCount blocked',
 color: _blockedDeliverablesCount == 0
 ? const Color(0xFF10B981)
 : const Color(0xFFEF4444),
 ),
 ],
 ),
 const SizedBox(height: 16),
 if (warnings.isEmpty)
 const Text(
 'No active baseline warnings.',
 style: TextStyle(color: _kMuted),
 )
 else
 ...warnings.map(
 (warning) => Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: _WarningTile(warning: warning),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildAssumptionsCard() {
 return _SectionCard(
 title: 'Structured Assumptions',
 subtitle:
 'Assumptions remain editable on the baseline with category and impact.',
 child: Column(
 children: [
 for (final row in _assumptionRows) ...[
 _AssumptionEditor(
 row: row,
 categories: _assumptionCategories,
 impacts: _impactOptions,
 onRemove: () => _removeAssumption(row),
 onChanged: _scheduleSave,
 ),
 const SizedBox(height: 12),
 ],
 Align(
 alignment: Alignment.centerLeft,
 child: OutlinedButton.icon(
 onPressed: _addAssumption,
 icon: const Icon(Icons.add, size: 18),
 label: const Text('Add assumption'),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildScopeCard() {
 return _SectionCard(
 title: 'Live Scope & Cadence',
 subtitle:
 'All roadmap deliverables are auto-included in this baseline summary.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _SummaryLine(label: 'Project', value: _projectData.projectName),
 _SummaryLine(
 label: 'Objective',
 value: _projectData.projectObjective.trim().isEmpty
 ? 'Not set'
 : _projectData.projectObjective.trim(),
 ),
 _SummaryLine(
 label: 'Release Target',
 value: _releaseLabelController.text.trim().isEmpty
 ? 'Not set'
 : _releaseLabelController.text.trim(),
 ),
 _SummaryLine(
 label: 'Sprint Cadence',
 value: _sprints.isEmpty
 ? 'No sprints defined'
 : _describeSprintCadence(),
 ),
 const SizedBox(height: 12),
 const Text(
 'Included Deliverables',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: _kHeadline,
 ),
 ),
 const SizedBox(height: 8),
 if (_deliverables.isEmpty)
 const Text(
 'No roadmap deliverables yet.',
 style: TextStyle(color: _kMuted),
 )
 else
 ..._deliverables.take(8).map(
 (item) => Padding(
 padding: const EdgeInsets.only(bottom: 8),
 child: Text(
 '${item.title} • ${item.storyPoints} pts${item.sprintId.trim().isEmpty ? ' • Unscheduled' : ''}',
 style: const TextStyle(fontSize: 13, color: _kHeadline),
 ),
 ),
 ),
 if (_deliverables.length > 8)
 Text(
 '+ ${_deliverables.length - 8} more deliverable(s)',
 style: const TextStyle(color: _kMuted),
 ),
 ],
 ),
 );
 }

 Widget _buildRiskCard() {
 return _SectionCard(
 title: 'Risk Synthesis',
 subtitle:
 'Formal risk register plus inferred delivery risk from the live roadmap.',
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [
 _MiniPill(
 label: '$_formalRiskCount formal risks',
 color: const Color(0xFFD97706),
 ),
 _MiniPill(
 label: '$_highRiskCount high formal risks',
 color: _highRiskCount == 0
 ? const Color(0xFF10B981)
 : const Color(0xFFEF4444),
 ),
 _MiniPill(
 label: '$_dependencyCount dependencies',
 color: const Color(0xFF8B5CF6),
 ),
 _MiniPill(
 label: '$_blockedDependencyCount unresolved deps',
 color: _blockedDependencyCount == 0
 ? const Color(0xFF10B981)
 : const Color(0xFFF59E0B),
 ),
 ],
 ),
 const SizedBox(height: 16),
 Text(
 _riskSummaryText,
 style: const TextStyle(
 fontSize: 13,
 color: _kHeadline,
 height: 1.5,
 ),
 ),
 if (_overCapacitySprints.isNotEmpty) ...[
 const SizedBox(height: 16),
 const Text(
 'Over-Capacity Sprints',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: _kHeadline,
 ),
 ),
 const SizedBox(height: 8),
 ..._overCapacitySprints.map(
 (item) => Padding(
 padding: const EdgeInsets.only(bottom: 8),
 child: Text(
 '${item.sprint.name} • ${item.points} pts planned',
 style: const TextStyle(fontSize: 13, color: _kHeadline),
 ),
 ),
 ),
 ],
 ],
 ),
 );
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Agile Project Baseline',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_agile_project_baseline_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

class _TopHeader extends StatelessWidget {
 const _TopHeader({
 required this.onBack,
 required this.onForward,
 required this.status,
 required this.isSaving,
 required this.lastSavedAt,
 });

 final VoidCallback onBack;
 final VoidCallback onForward;
 final String status;
 final bool isSaving;
 final DateTime? lastSavedAt;

 @override
 Widget build(BuildContext context) {
 final statusColor = switch (status) {
 'Approved' => const Color(0xFF10B981),
 'Ready' => const Color(0xFFD97706),
 _ => const Color(0xFFF59E0B),
 };

 final saveLabel = isSaving
 ? 'Saving...'
 : lastSavedAt == null
 ? 'Not saved yet'
 : 'Saved ${DateFormat('HH:mm').format(lastSavedAt!)}';

 return Row(
 children: [
 _CircleIconButton(
 icon: Icons.arrow_back_ios_new_rounded,
 onTap: onBack,
 ),
 const SizedBox(width: 12),
 _CircleIconButton(
 icon: Icons.arrow_forward_ios_rounded,
 onTap: onForward,
 ),
 const SizedBox(width: 16),
 const Expanded(
 child: Text(
 'Agile Project Baseline',
 style: TextStyle(
 fontSize: 22,
 fontWeight: FontWeight.w700,
 color: _kHeadline,
 ),
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: statusColor.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 status,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: statusColor,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Text(
 saveLabel,
 style: const TextStyle(fontSize: 12, color: _kMuted),
 ),
 const SizedBox(width: 16),
 const SizedBox(width: 12),
 const _UserChip(),
 ],
 );
 }
}

class _CircleIconButton extends StatelessWidget {
 const _CircleIconButton({required this.icon, this.onTap});

 final IconData icon;
 final VoidCallback? onTap;

 @override
 Widget build(BuildContext context) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(18),
 child: Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: Colors.white,
 shape: BoxShape.circle,
 border: Border.all(color: _kBorder),
 ),
 child: Icon(icon, size: 16, color: _kMuted),
 ),
 );
 }
}

class _UserChip extends StatelessWidget {
 const _UserChip();

 @override
 Widget build(BuildContext context) {
 final user = FirebaseAuth.instance.currentUser;
 final displayName =
 FirebaseAuthService.displayNameOrEmail(fallback: 'User');
 final email = user?.email ?? '';

 return StreamBuilder<bool>(
 stream: UserService.watchAdminStatus(),
 builder: (context, snapshot) {
 final isAdmin = snapshot.data ?? UserService.isAdminEmail(email);
 final role = isAdmin ? 'Admin' : 'Member';

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: _kBorder),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 CircleAvatar(
 radius: 16,
 backgroundColor: const Color(0xFFE5E7EB),
 backgroundImage: user?.photoURL != null
 ? NetworkImage(user!.photoURL!)
 : null,
 child: user?.photoURL == null
 ? Text(
 displayName.isNotEmpty
 ? displayName[0].toUpperCase()
 : 'U',
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF374151),
 ),
 )
 : null,
 ),
 const SizedBox(width: 8),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 displayName,
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 Text(
 role,
 style: const TextStyle(fontSize: 10, color: _kMuted),
 ),
 ],
 ),
 ],
 ),
 );
 },
 );
 }
}

class _MetricsRow extends StatelessWidget {
 const _MetricsRow({
 required this.averageVelocity,
 required this.capacityThreshold,
 required this.totalPoints,
 required this.sprintCount,
 required this.highestSprintLoad,
 required this.epicTotalPoints,
 });

 final double averageVelocity;
 final int? capacityThreshold;
 final int totalPoints;
 final int sprintCount;
 final int highestSprintLoad;
 final double epicTotalPoints;

 @override
 Widget build(BuildContext context) {
 return Wrap(
 spacing: 16,
 runSpacing: 16,
 children: [
 _MetricCard(
 label: 'Avg Planned Velocity',
 value: averageVelocity == 0
 ? '0 pts'
 : '${averageVelocity.toStringAsFixed(1)} pts',
 accent: const Color(0xFF10B981),
 ),
 _MetricCard(
 label: 'Capacity Threshold',
 value:
 capacityThreshold == null ? 'Not set' : '$capacityThreshold pts',
 accent: const Color(0xFFD97706),
 ),
 _MetricCard(
 label: 'Total Planned Points',
 value: '$totalPoints',
 accent: const Color(0xFFF59E0B),
 ),
 _MetricCard(
 label: 'Epic Story Points',
 value: epicTotalPoints.toStringAsFixed(0),
 accent: const Color(0xFF8B5CF6),
 ),
 _MetricCard(
 label: 'Sprint Count',
 value: '$sprintCount',
 accent: const Color(0xFFEC4899),
 ),
 _MetricCard(
 label: 'Highest Sprint Load',
 value: '$highestSprintLoad pts',
 accent: const Color(0xFFEF4444),
 ),
 ],
 );
 }
}

class _MetricCard extends StatelessWidget {
 const _MetricCard({
 required this.label,
 required this.value,
 required this.accent,
 });

 final String label;
 final String value;
 final Color accent;

 @override
 Widget build(BuildContext context) {
 return Container(
 width: 190,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: _kBorder),
 boxShadow: const [
 BoxShadow(
 color: Color(0x0A000000),
 blurRadius: 10,
 offset: Offset(0, 6),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: const TextStyle(fontSize: 12, color: _kMuted),
 ),
 const SizedBox(height: 6),
 Text(
 value,
 style: TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.w700,
 color: accent,
 ),
 ),
 ],
 ),
 );
 }
}

class _SectionCard extends StatelessWidget {
 const _SectionCard({
 required this.title,
 required this.subtitle,
 required this.child,
 });

 final String title;
 final String subtitle;
 final Widget child;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: _kBorder),
 boxShadow: const [
 BoxShadow(
 color: Color(0x08000000),
 blurRadius: 18,
 offset: Offset(0, 10),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: _kHeadline,
 ),
 ),
 const SizedBox(height: 6),
 Text(
 subtitle,
 style: const TextStyle(fontSize: 13, color: _kMuted, height: 1.5),
 ),
 const SizedBox(height: 18),
 child,
 ],
 ),
 );
 }
}

class _RichTextCard extends StatelessWidget {
 const _RichTextCard({
 required this.title,
 required this.subtitle,
 required this.controller,
 });

 final String title;
 final String subtitle;
 final TextEditingController controller;

 @override
 Widget build(BuildContext context) {
 return _SectionCard(
 title: title,
 subtitle: subtitle,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const SizedBox(height: 8),
 VoiceTextField(
 controller: controller,
 minLines: 8,
 maxLines: 12,
 decoration: const InputDecoration(
 border: OutlineInputBorder(),
 ),
 ),
 ],
 ),
 );
 }
}

class _ReadOnlyDoDCard extends StatelessWidget {
 const _ReadOnlyDoDCard({required this.definitionOfDone});

 final String definitionOfDone;

 @override
 Widget build(BuildContext context) {
 return _SectionCard(
 title: 'Definition of Done',
 subtitle: 'Managed in Backlog Governance — shown here for reference.',
 child: Container(
 width: double.infinity,
 constraints: const BoxConstraints(minHeight: 180),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(4),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Text(
 definitionOfDone.isEmpty
 ? 'No Definition of Done defined yet. Go to Backlog Governance to set one.'
 : definitionOfDone,
 style: TextStyle(
 fontSize: 14,
 color: definitionOfDone.isEmpty
 ? const Color(0xFF9CA3AF)
 : const Color(0xFF374151),
 height: 1.5,
 ),
 ),
 ),
 );
 }
}

class _DropdownField<T> extends StatelessWidget {
 const _DropdownField({
 required this.label,
 required this.value,
 required this.items,
 required this.onChanged,
 });

 final String label;
 final T? value;
 final List<T> items;
 final ValueChanged<T?> onChanged;

 @override
 Widget build(BuildContext context) {
 return DropdownButtonFormField<T>(
 value: items.contains(value) ? value : null,
 decoration: InputDecoration(
 labelText: label,
 border: const OutlineInputBorder(),
 ),
 items: items
 .map(
 (item) => DropdownMenuItem<T>(
 value: item,
 child: Text(item.toString()),
 ),
 )
 .toList(),
 onChanged: onChanged,
 );
 }
}

class _MiniPill extends StatelessWidget {
 const _MiniPill({required this.label, required this.color});

 final String label;
 final Color color;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: color.withOpacity(0.12),
 borderRadius: BorderRadius.circular(999),
 ),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: color,
 ),
 ),
 );
 }
}

class _WarningTile extends StatelessWidget {
 const _WarningTile({required this.warning});

 final _BaselineWarning warning;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: warning.color.withOpacity(0.3)),
 color: warning.color.withOpacity(0.08),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Icon(Icons.warning_amber_rounded, color: warning.color, size: 18),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 warning.title,
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: warning.color,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 warning.detail,
 style: const TextStyle(
 fontSize: 12,
 color: _kHeadline,
 height: 1.4,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }
}

class _SummaryLine extends StatelessWidget {
 const _SummaryLine({required this.label, required this.value});

 final String label;
 final String value;

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: RichText(
 text: TextSpan(
 style: const TextStyle(fontSize: 13, color: _kHeadline),
 children: [
 TextSpan(
 text: '$label: ',
 style: const TextStyle(fontWeight: FontWeight.w700),
 ),
 TextSpan(text: value.isEmpty ? 'Not set' : value),
 ],
 ),
 ),
 );
 }
}

class _AssumptionEditor extends StatelessWidget {
 const _AssumptionEditor({
 required this.row,
 required this.categories,
 required this.impacts,
 required this.onRemove,
 required this.onChanged,
 });

 final _AssumptionRowState row;
 final List<String> categories;
 final List<String> impacts;
 final VoidCallback onRemove;
 final VoidCallback onChanged;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: _kBorder),
 color: const Color(0xFFFDFEFE),
 ),
 child: Column(
 children: [
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: [
 SizedBox(
 width: 190,
 child: _DropdownField<String>(
 label: 'Category',
 value: row.category,
 items: categories,
 onChanged: (value) {
 row.category = value ?? '';
 onChanged();
 },
 ),
 ),
 SizedBox(
 width: 170,
 child: _DropdownField<String>(
 label: 'Impact',
 value: row.impact,
 items: impacts,
 onChanged: (value) {
 row.impact = value ?? 'Medium';
 onChanged();
 },
 ),
 ),
 IconButton(
 onPressed: onRemove,
 icon: const Icon(Icons.delete_outline),
 tooltip: 'Remove assumption',
 ),
 ],
 ),
 const SizedBox(height: 12),
 VoiceTextField(
 controller: row.textController,
 minLines: 2,
 maxLines: 4,
 decoration: const InputDecoration(
 labelText: 'Assumption',
 hintText: 'Describe the assumption and why it matters.',
 border: OutlineInputBorder(),
 ),
 ),
 ],
 ),
 );
 }
}

class _ApproverAutocomplete extends StatelessWidget {
 const _ApproverAutocomplete({
 required this.controller,
 required this.focusNode,
 required this.options,
 required this.onSelectedOption,
 required this.onSubmittedFallback,
 });

 final TextEditingController controller;
 final FocusNode focusNode;
 final List<_ApproverOption> options;
 final ValueChanged<_ApproverOption> onSelectedOption;
 final ValueChanged<String> onSubmittedFallback;

 static const String _createToken = 'CREATE:';

 Iterable<String> _buildOptions(String query) {
 final q = query.toLowerCase().trim();
 if (q.isEmpty) {
 return options.map((o) => o.displayLabel);
 }
 final filtered = options
 .where((o) => o.displayLabel.toLowerCase().contains(q))
 .map((o) => o.displayLabel)
 .toList();
 final exactMatch = filtered.any((l) => l.toLowerCase() == q);
 if (!exactMatch && q.isNotEmpty) {
 filtered.insert(0, '$_createToken$q');
 }
 return filtered;
 }

 String _displayLabel(String option) {
 if (!option.startsWith(_createToken)) return option;
 return option.substring(_createToken.length);
 }

 @override
 Widget build(BuildContext context) {
 return RawAutocomplete<String>(
 textEditingController: controller,
 focusNode: focusNode,
 optionsBuilder: (TextEditingValue textEditingValue) {
 return _buildOptions(textEditingValue.text);
 },
 displayStringForOption: _displayLabel,
 onSelected: (selected) {
 if (selected.startsWith(_createToken)) {
 final name = selected.substring(_createToken.length);
 controller.text = name;
 onSubmittedFallback(name);
 return;
 }
 final match = options.where((o) => o.displayLabel == selected);
 if (match.isNotEmpty) {
 controller.text = selected;
 onSelectedOption(match.first);
 }
 },
 fieldViewBuilder: (context, ctrl, fNode, onSubmitted) {
 return VoiceTextFormField(
 controller: ctrl,
 focusNode: fNode,
 decoration: const InputDecoration(
 labelText: 'Approver',
 hintText: 'Search team members or type a name',
 border: OutlineInputBorder(),
 suffixIcon: Icon(Icons.search, size: 20),
 ),
 onFieldSubmitted: (raw) {
 final value = raw.trim();
 if (value.isEmpty) return;
 final match = options.where(
 (o) => o.displayLabel.toLowerCase() == value.toLowerCase());
 if (match.isNotEmpty) {
 onSelectedOption(match.first);
 } else {
 onSubmittedFallback(value);
 }
 onSubmitted();
 },
 );
 },
 optionsViewBuilder: (context, onSelected, opts) {
 final list = opts.toList(growable: false);
 if (list.isEmpty) return const SizedBox.shrink();
 return Align(
 alignment: Alignment.topLeft,
 child: Material(
 elevation: 8,
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 child: ConstrainedBox(
 constraints: const BoxConstraints(
 maxHeight: 240,
 minWidth: 260,
 maxWidth: 440,
 ),
 child: ListView.separated(
 padding: const EdgeInsets.symmetric(vertical: 6),
 shrinkWrap: true,
 itemCount: list.length,
 separatorBuilder: (_, __) =>
 const Divider(height: 1, color: _kBorder),
 itemBuilder: (context, index) {
 final option = list[index];
 final isCreate = option.startsWith(_createToken);
 return InkWell(
 onTap: () => onSelected(option),
 child: Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 12,
 vertical: 10,
 ),
 child: Row(
 children: [
 Icon(
 isCreate ? Icons.add_circle : Icons.person,
 size: 18,
 color: isCreate ? const Color(0xFFD97706) : _kMuted,
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 isCreate
 ? 'Create "${option.substring(_createToken.length)}"'
 : option,
 style: TextStyle(
 fontSize: 14,
 color: isCreate ? const Color(0xFFD97706) : _kHeadline,
 ),
 ),
 ),
 ],
 ),
 ),
 );
 },
 ),
 ),
 ),
 );
 },
 );
 }
}

class _ApproverOption {
 const _ApproverOption({
 required this.id,
 required this.name,
 required this.email,
 required this.role,
 required this.source,
 });

 final String id;
 final String name;
 final String email;
 final String role;
 final String source;

 String get displayLabel {
 final parts = <String>[];
 if (name.isNotEmpty) {
 parts.add(name);
 } else if (email.isNotEmpty) {
 parts.add(email);
 }
 if (role.isNotEmpty) parts.add(role);
 if (source.isNotEmpty) parts.add(source);
 return parts.join(' • ');
 }
}

class _AssumptionRowState {
 _AssumptionRowState({
 required this.category,
 required this.impact,
 required String text,
 required VoidCallback onChanged,
 }) : textController = TextEditingController(text: text) {
 textController.addListener(onChanged);
 _listener = onChanged;
 }

 String category;
 String impact;
 final TextEditingController textController;
 late final VoidCallback _listener;

 bool get isEmpty =>
 category.trim().isEmpty && textController.text.trim().isEmpty;

 AgileBaselineAssumption toAssumption() {
 return AgileBaselineAssumption(
 category: category.trim(),
 impact: impact.trim().isEmpty ? 'Medium' : impact.trim(),
 text: textController.text.trim(),
 );
 }

 void clear() {
 category = '';
 impact = 'Medium';
 textController.clear();
 }

 void dispose() {
 textController.removeListener(_listener);
 textController.dispose();
 }
}

class _SprintLoad {
 const _SprintLoad({required this.sprint, required this.points});

 final RoadmapSprint sprint;
 final int points;
}

class _BaselineWarning {
 const _BaselineWarning({
 required this.title,
 required this.detail,
 required this.color,
 });

 final String title;
 final String detail;
 final Color color;
}

class _RiskSummary {
 const _RiskSummary({required this.totalCount, required this.highCount});

 final int totalCount;
 final int highCount;
}

class _Debouncer {
 static const Duration _duration = Duration(milliseconds: 700);

 Timer? _timer;

 void run(Future<void> Function() action) {
 _timer?.cancel();
 _timer = Timer(_duration, () => action());
 }

 void dispose() {
 _timer?.cancel();
 }
}
