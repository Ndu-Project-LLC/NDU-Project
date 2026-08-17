import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/agile_release_plan.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';
import 'package:ndu_project/services/epic_feature_service.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

import 'package:ndu_project/widgets/delete_success_snackbar.dart';
const Color _kBackground = Colors.white;
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kAccent = Color(0xFFD97706);

class AgileReleasePlanScreen extends StatefulWidget {
  const AgileReleasePlanScreen({super.key});

  @override
  State<AgileReleasePlanScreen> createState() => _AgileReleasePlanScreenState();
}

class _AgileReleasePlanScreenState extends State<AgileReleasePlanScreen> {
  List<AgileReleasePlan> _plans = [];
  List<AgileTask> _stories = [];
  bool _isLoading = true;
  final DateFormat _df = DateFormat('MMM dd, yyyy');
  final Set<int> _expandedCards = {};

  String? get _projectId {
    try {
      return ProjectDataInherited.maybeOf(context)?.projectData.projectId;
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isLoading = true);
    try {
      final plans = await AgileWireframeService.loadReleasePlans(pid);
      final stories =
          await ExecutionPhaseService.loadAgileTasks(projectId: pid);
      if (mounted) {
        setState(() {
          _plans = plans;
          _stories = stories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addPlan() {
    final plan = AgileReleasePlan(
      releaseLabel: 'Release ${_plans.length + 1}',
    );
    final pid = _projectId;
    showDialog(
      context: context,
      builder: (ctx) => _ReleasePlanEditDialog(
        plan: plan,
        projectId: pid ?? '',
        onSave: (updated) {
          if (pid == null) return;
          AgileWireframeService.saveReleasePlan(projectId: pid, plan: updated);
          setState(() => _plans.add(updated));
        },
      ),
    );
  }

  void _editPlan(int index) {
    final plan = _plans[index];
    final pid = _projectId;
    showDialog(
      context: context,
      builder: (ctx) => _ReleasePlanEditDialog(
        plan: plan,
        projectId: pid ?? '',
        onSave: (updated) {
          if (pid == null) return;
          AgileWireframeService.saveReleasePlan(projectId: pid, plan: updated);
          setState(() => _plans[index] = updated);
        },
      ),
    );
  }

  void _deletePlan(int index) {
    final pid = _projectId;
    final plan = _plans[index];
    if (pid == null) return;
    AgileWireframeService.deleteReleasePlan(projectId: pid, planId: plan.id);
    setState(() => _plans.removeAt(index));
      showDeleteSuccessSnackBar(context, itemLabel: 'Plan');
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double hp = isMobile ? 20 : 40;

    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Agile Delivery Model - Release Plan'),
            ),
            Expanded(
              child: Stack(
                children: [
                  const MobileSidebarHamburger(
                    sidebar: InitiationLikeSidebar(
                      activeItemLabel: 'Agile Delivery Model - Release Plan',
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: hp, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlanningPhaseHeader(
                            title: 'Release Plan',
                            onBack: () => PlanningPhaseNavigation.goToPrevious(
                                context, 'agile_release_plan'),
                            onForward: () => PlanningPhaseNavigation.goToNext(
                                context, 'agile_release_plan'),
                            onExportPdf: _exportPdf),
                        const SizedBox(height: 32),
                        const Text(
                            'Plan releases, PI increments, and versioned deployments.',
                            style:
                                TextStyle(fontSize: 15, color: _kMuted)),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          if (_plans.isEmpty)
                            _buildEmptyState(
                                'No release plans yet. Create your first release.')
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _plans.length,
                              itemBuilder: (context, i) =>
                                  _buildPlanCard(i, _plans[i]),
                            ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _addPlan,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Release Plan'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kAccent,
                              side: const BorderSide(color: _kAccent),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        LaunchPhaseNavigation(
                          backLabel: PlanningPhaseNavigation.backLabel(
                              'agile_release_plan'),
                          nextLabel: PlanningPhaseNavigation.nextLabel(
                              'agile_release_plan'),
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                              context, 'agile_release_plan'),
                          onNext: () => PlanningPhaseNavigation.goToNext(
                              context, 'agile_release_plan'),
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

  int _releaseStoryPoints(AgileReleasePlan plan) {
    return _stories
        .where((story) => plan.storyIds.contains(story.id))
        .fold<int>(0, (sum, story) => sum + story.storyPoints);
  }

  int _releaseFeatureCount(AgileReleasePlan plan) => plan.featureIds.length;
  int _releaseStoryCount(AgileReleasePlan plan) => plan.storyIds.length;
  int _releaseReadyStoryCount(AgileReleasePlan plan) => _stories
      .where((story) =>
          plan.storyIds.contains(story.id) &&
          story.readinessStatus == 'Ready for Sprint')
      .length;
  int _releaseUnassignedSprintCount(AgileReleasePlan plan) => _stories
      .where((story) =>
          plan.storyIds.contains(story.id) && story.plannedSprintId.isEmpty)
      .length;

  Widget _buildPlanCard(int index, AgileReleasePlan plan) {
    final dateStr =
        plan.releaseDate != null ? _df.format(plan.releaseDate!) : 'Date TBD';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.rocket_launch_outlined,
                      size: 18, color: _kAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          plan.releaseLabel.isNotEmpty
                              ? plan.releaseLabel
                              : 'Untitled Release',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(dateStr,
                          style: const TextStyle(fontSize: 12, color: _kMuted)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusBgColor(plan.status),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(plan.status,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _statusFgColor(plan.status))),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _editPlan(index);
                    if (v == 'delete') _deletePlan(index);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            if (plan.releaseGoal.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(plan.releaseGoal,
                  style: const TextStyle(fontSize: 13, color: _kMuted)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTag('${plan.epicIds.length} epics'),
                _buildTag('${_releaseFeatureCount(plan)} features'),
                _buildTag('${_releaseStoryCount(plan)} stories'),
                _buildTag('${_releaseStoryPoints(plan)} pts'),
                _buildTag('${_releaseReadyStoryCount(plan)} sprint-ready'),
              ],
            ),
            if (_releaseUnassignedSprintCount(plan) > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFF59E0B)),
                ),
                child: Text(
                  '${_releaseUnassignedSprintCount(plan)} story(ies) in this release do not yet have a target sprint. Assign sprint targets before schedule import for better forecast quality.',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9A3412), height: 1.4),
                ),
              ),
            ],
            if (plan.version.isNotEmpty || plan.piNumber != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (plan.version.isNotEmpty) _buildTag('v${plan.version}'),
                  if (plan.version.isNotEmpty && plan.piNumber != null)
                    const SizedBox(width: 6),
                  if (plan.piNumber != null) _buildTag('PI ${plan.piNumber}'),
                  if (plan.trainName.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _buildTag(plan.trainName),
                  ],
                ],
              ),
            ],
            if (plan.cadenceType.isNotEmpty ||
                plan.deploymentStrategy.isNotEmpty ||
                plan.definitionOfDone.isNotEmpty ||
                plan.rollbackPlan.isNotEmpty ||
                plan.monitoringPlan.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (plan.cadenceType.isNotEmpty) _buildTag(plan.cadenceType),
                  if (plan.deploymentStrategy.isNotEmpty)
                    _buildTag(plan.deploymentStrategy),
                  if (plan.definitionOfDone.isNotEmpty) _buildTag('DoD defined'),
                  if (plan.rollbackPlan.isNotEmpty) _buildTag('Rollback defined'),
                  if (plan.monitoringPlan.isNotEmpty)
                    _buildTag('Monitoring defined'),
                ],
              ),
            ],
            const SizedBox(height: 6),
            InkWell(
              onTap: () {
                setState(() {
                  if (_expandedCards.contains(index)) {
                    _expandedCards.remove(index);
                  } else {
                    _expandedCards.add(index);
                  }
                });
              },
              child: Row(
                children: [
                  Text(
                    _expandedCards.contains(index)
                        ? 'Hide Details'
                        : 'Show Details',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFD97706),
                        fontWeight: FontWeight.w500),
                  ),
                  Icon(
                    _expandedCards.contains(index)
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 16,
                    color: const Color(0xFFD97706),
                  ),
                ],
              ),
            ),
            if (_expandedCards.contains(index)) ...[
              const SizedBox(height: 8),
              _buildReleaseDetails(plan),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReleaseDetails(AgileReleasePlan plan) {
    final entries = <String, String>{
      if (plan.releaseFrequency.isNotEmpty)
        'Release Frequency': plan.releaseFrequency,
      if (plan.sprintLengthDays != null)
        'Sprint Length': '${plan.sprintLengthDays} days',
      if (plan.numberOfSprintsInRelease != null)
        'Sprints in Release': plan.numberOfSprintsInRelease.toString(),
      if (plan.definitionOfDone.isNotEmpty)
        'Definition of Done': plan.definitionOfDone,
      if (plan.qualityGates.isNotEmpty) 'Quality Gates': plan.qualityGates,
      if (plan.testingRequirements.isNotEmpty)
        'Testing Requirements': plan.testingRequirements,
      if (plan.approvalRequirements.isNotEmpty)
        'Approval Requirements': plan.approvalRequirements,
      if (plan.deploymentEnvironments.isNotEmpty)
        'Deployment Environments': plan.deploymentEnvironments,
      if (plan.featureFlagPlan.isNotEmpty)
        'Feature Flag Plan': plan.featureFlagPlan,
      if (plan.keyDependencies.isNotEmpty)
        'Key Dependencies': plan.keyDependencies,
      if (plan.assumptions.isNotEmpty) 'Assumptions': plan.assumptions,
      if (plan.releaseRisks.isNotEmpty) 'Release Risks': plan.releaseRisks,
      if (plan.rollbackPlan.isNotEmpty) 'Rollback Plan': plan.rollbackPlan,
      if (plan.recoveryProcedures.isNotEmpty)
        'Recovery Procedures': plan.recoveryProcedures,
      if (plan.communicationPlan.isNotEmpty)
        'Communication Plan': plan.communicationPlan,
      if (plan.trainingPlan.isNotEmpty) 'Training Plan': plan.trainingPlan,
      if (plan.monitoringPlan.isNotEmpty)
        'Monitoring Plan': plan.monitoringPlan,
      if (plan.feedbackCollection.isNotEmpty)
        'Feedback Collection': plan.feedbackCollection,
      if (plan.continuousImprovement.isNotEmpty)
        'Continuous Improvement': plan.continuousImprovement,
    };

    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text('${e.key}:',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280))),
                    ),
                    Expanded(
                      child: Text(e.value,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF374151))),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Color(0xFFFFC812).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child:
          Text(text, style: TextStyle(fontSize: 11, color: Color(0xFFB8860B))),
    );
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green.withValues(alpha: 0.1);
      case 'Ready':
        return Color(0xFFFFC812).withValues(alpha: 0.1);
      default:
        return Colors.grey.withValues(alpha: 0.1);
    }
  }

  Color _statusFgColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green[700]!;
      case 'Ready':
        return Color(0xFFB8860B)!;
      default:
        return Colors.grey[700]!;
    }
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child:
            Text(message, style: const TextStyle(color: _kMuted, fontSize: 15)),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Agile Release Plan',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName},
          {'Solution Title': projectData.solutionTitle},
        ]),
        PdfSection.text(
            'Notes',
            projectData.planningNotes['planning_agile_release_plan_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}

class _ReleasePlanEditDialog extends StatefulWidget {
  final AgileReleasePlan plan;
  final String projectId;
  final ValueChanged<AgileReleasePlan> onSave;

  const _ReleasePlanEditDialog({
    required this.plan,
    required this.projectId,
    required this.onSave,
  });

  @override
  State<_ReleasePlanEditDialog> createState() => _ReleasePlanEditDialogState();
}

class _ReleasePlanEditDialogState extends State<_ReleasePlanEditDialog> {
  late TextEditingController _labelCtrl;
  late TextEditingController _goalCtrl;
  late TextEditingController _scopeCtrl;
  late TextEditingController _versionCtrl;
  late TextEditingController _piCtrl;
  late TextEditingController _trainCtrl;
  DateTime? _releaseDate;
  String _status = 'Draft';
  List<Epic> _epics = [];
  Map<String, List<Feature>> _featuresByEpic = {};
  List<AgileTask> _stories = [];
  Set<String> _selectedEpicIds = {};
  Set<String> _selectedFeatureIds = {};
  Set<String> _selectedStoryIds = {};
  String _cadenceType = '';
  late TextEditingController _sprintLengthCtrl;
  late TextEditingController _numSprintsCtrl;
  late TextEditingController _releaseFreqCtrl;
  late TextEditingController _dodCtrl;
  late TextEditingController _qualityGatesCtrl;
  late TextEditingController _testingReqCtrl;
  late TextEditingController _approvalReqCtrl;
  String _deploymentStrategy = '';
  late TextEditingController _depEnvironmentsCtrl;
  late TextEditingController _featureFlagCtrl;
  late TextEditingController _dependenciesCtrl;
  late TextEditingController _assumptionsCtrl;
  late TextEditingController _risksCtrl;
  late TextEditingController _rollbackCtrl;
  late TextEditingController _recoveryCtrl;
  late TextEditingController _communicationCtrl;
  late TextEditingController _trainingCtrl;
  late TextEditingController _monitoringCtrl;
  late TextEditingController _feedbackCtrl;
  late TextEditingController _improvementCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _labelCtrl = TextEditingController(text: p.releaseLabel);
    _goalCtrl = TextEditingController(text: p.releaseGoal);
    _scopeCtrl = TextEditingController(text: p.scope);
    _versionCtrl = TextEditingController(text: p.version);
    _piCtrl = TextEditingController(text: p.piNumber?.toString() ?? '');
    _trainCtrl = TextEditingController(text: p.trainName);
    _releaseDate = p.releaseDate;
    _status = p.status;
    _selectedEpicIds = Set.from(p.epicIds);
    _selectedFeatureIds = Set.from(p.featureIds);
    _selectedStoryIds = Set.from(p.storyIds);
    _cadenceType = p.cadenceType;
    _sprintLengthCtrl = TextEditingController(text: p.sprintLengthDays?.toString() ?? '');
    _numSprintsCtrl = TextEditingController(text: p.numberOfSprintsInRelease?.toString() ?? '');
    _releaseFreqCtrl = TextEditingController(text: p.releaseFrequency);
    _dodCtrl = TextEditingController(text: p.definitionOfDone);
    _qualityGatesCtrl = TextEditingController(text: p.qualityGates);
    _testingReqCtrl = TextEditingController(text: p.testingRequirements);
    _approvalReqCtrl = TextEditingController(text: p.approvalRequirements);
    _deploymentStrategy = p.deploymentStrategy;
    _depEnvironmentsCtrl = TextEditingController(text: p.deploymentEnvironments);
    _featureFlagCtrl = TextEditingController(text: p.featureFlagPlan);
    _dependenciesCtrl = TextEditingController(text: p.keyDependencies);
    _assumptionsCtrl = TextEditingController(text: p.assumptions);
    _risksCtrl = TextEditingController(text: p.releaseRisks);
    _rollbackCtrl = TextEditingController(text: p.rollbackPlan);
    _recoveryCtrl = TextEditingController(text: p.recoveryProcedures);
    _communicationCtrl = TextEditingController(text: p.communicationPlan);
    _trainingCtrl = TextEditingController(text: p.trainingPlan);
    _monitoringCtrl = TextEditingController(text: p.monitoringPlan);
    _feedbackCtrl = TextEditingController(text: p.feedbackCollection);
    _improvementCtrl = TextEditingController(text: p.continuousImprovement);
    _loadEpics();
  }

  Future<void> _loadEpics() async {
    if (widget.projectId.isEmpty) return;
    try {
      final epics = await EpicFeatureService.loadEpics(widget.projectId);
      final featuresByEpic = <String, List<Feature>>{};
      for (final epic in epics) {
        featuresByEpic[epic.id] =
            await EpicFeatureService.loadFeatures(widget.projectId, epic.id);
      }
      final stories = await ExecutionPhaseService.loadAgileTasks(
          projectId: widget.projectId);
      if (mounted) {
        setState(() {
          _epics = epics;
          _featuresByEpic = featuresByEpic;
          _stories = stories;
        });
      }
    } catch (e) {
      debugPrint('Error loading epics: $e');
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _goalCtrl.dispose();
    _scopeCtrl.dispose();
    _versionCtrl.dispose();
    _piCtrl.dispose();
    _trainCtrl.dispose();
    _sprintLengthCtrl.dispose();
    _numSprintsCtrl.dispose();
    _releaseFreqCtrl.dispose();
    _dodCtrl.dispose();
    _qualityGatesCtrl.dispose();
    _testingReqCtrl.dispose();
    _approvalReqCtrl.dispose();
    _depEnvironmentsCtrl.dispose();
    _featureFlagCtrl.dispose();
    _dependenciesCtrl.dispose();
    _assumptionsCtrl.dispose();
    _risksCtrl.dispose();
    _rollbackCtrl.dispose();
    _recoveryCtrl.dispose();
    _communicationCtrl.dispose();
    _trainingCtrl.dispose();
    _monitoringCtrl.dispose();
    _feedbackCtrl.dispose();
    _improvementCtrl.dispose();
    super.dispose();
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      children: [
        const Divider(height: 1),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {int maxLines = 1, String hint = ''}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: VoiceTextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint.isEmpty ? null : hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildDropdown(
      String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value.isEmpty ? null : value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat df = DateFormat('MMM dd, yyyy');
    return AlertDialog(
      title: const Text('Release Plan Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VoiceTextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                  labelText: 'Release Label', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: VoiceTextField(
                    controller: _versionCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Version', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: VoiceTextField(
                    controller: _piCtrl,
                    decoration: const InputDecoration(
                        labelText: 'PI Number', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            VoiceTextField(
              controller: _trainCtrl,
              decoration: const InputDecoration(
                  labelText: 'Release Train / ART Name',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _releaseDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _releaseDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Release Date', border: OutlineInputBorder()),
                child: Text(_releaseDate != null
                    ? df.format(_releaseDate!)
                    : 'Select date'),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                  labelText: 'Status', border: OutlineInputBorder()),
              items: ['Draft', 'Ready', 'Approved']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
            const SizedBox(height: 10),
            VoiceTextField(
              controller: _goalCtrl,
              decoration: const InputDecoration(
                  labelText: 'Release Goal', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Linked Scope',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_epics.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No epics defined yet.',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF9CA3AF))),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _epics.length,
                      itemBuilder: (context, epicIdx) {
                        final epic = _epics[epicIdx];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              title: Text(epic.title,
                                  style: const TextStyle(fontSize: 13)),
                              subtitle: epic.theme.isNotEmpty
                                  ? Text(epic.theme,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF6B7280)))
                                  : null,
                              value: _selectedEpicIds.contains(epic.id),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedEpicIds.add(epic.id);
                                  } else {
                                    _selectedEpicIds.remove(epic.id);
                                  }
                                });
                              },
                            ),
                            ...(_featuresByEpic[epic.id] ?? []).map(
                              (feature) => Padding(
                                padding: const EdgeInsets.only(left: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      title: Text(
                                        feature.title.isNotEmpty
                                            ? feature.title
                                            : 'Untitled Feature',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      value: _selectedFeatureIds
                                          .contains(feature.id),
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedFeatureIds.add(feature.id);
                                            _selectedEpicIds.add(epic.id);
                                          } else {
                                            _selectedFeatureIds
                                                .remove(feature.id);
                                          }
                                        });
                                      },
                                    ),
                                    ..._stories
                                        .where((story) =>
                                            story.featureId == feature.id)
                                        .map(
                                          (story) => Padding(
                                            padding:
                                                const EdgeInsets.only(left: 24),
                                            child: CheckboxListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              title: Text(
                                                story.userStory.isNotEmpty
                                                    ? story.userStory
                                                    : 'Untitled Story',
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                              subtitle: Text(
                                                '${story.storyPoints} pts · ${story.readinessStatus}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF6B7280)),
                                              ),
                                              value: _selectedStoryIds
                                                  .contains(story.id),
                                              onChanged: (checked) {
                                                setState(() {
                                                  if (checked == true) {
                                                    _selectedStoryIds
                                                        .add(story.id);
                                                    _selectedFeatureIds
                                                        .add(feature.id);
                                                    _selectedEpicIds
                                                        .add(epic.id);
                                                  } else {
                                                    _selectedStoryIds
                                                        .remove(story.id);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
            _buildSectionHeader('Release Cadence'),
            _buildDropdown(
              'Cadence Type',
              _cadenceType,
              ['Sprint-based', 'Time-based', 'On-demand'],
              (v) {
                if (v != null) setState(() => _cadenceType = v);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: VoiceTextField(
                    controller: _sprintLengthCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Sprint Length (Days)',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: VoiceTextField(
                    controller: _numSprintsCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Sprints in Release',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            _buildField('Release Frequency', _releaseFreqCtrl,
                hint: 'e.g. Every sprint, Every 2 sprints, Quarterly'),
            _buildSectionHeader('Release Criteria'),
            _buildField('Definition of Done', _dodCtrl, maxLines: 3,
                hint: 'Completion criteria for release acceptance'),
            _buildField('Quality Gates', _qualityGatesCtrl, maxLines: 3,
                hint: 'QA checkpoints, code review requirements, performance thresholds'),
            _buildField('Testing Requirements', _testingReqCtrl, maxLines: 3,
                hint: 'Test coverage, regression testing, UAT sign-off'),
            _buildField('Approval Requirements', _approvalReqCtrl, maxLines: 2,
                hint: 'Go/no-go decision makers and process'),
            _buildSectionHeader('Deployment Strategy'),
            _buildDropdown(
              'Deployment Strategy',
              _deploymentStrategy,
              ['Full Deployment', 'Phased Rollout', 'Blue-Green', 'Canary', 'Feature Flags'],
              (v) {
                if (v != null) setState(() => _deploymentStrategy = v);
              },
            ),
            _buildField('Deployment Environments', _depEnvironmentsCtrl, maxLines: 3,
                hint: 'Dev \u2192 Test \u2192 Staging \u2192 Production promotion plan'),
            _buildField('Feature Flag Plan', _featureFlagCtrl, maxLines: 3,
                hint: 'Flag naming, rollout percentages, kill switches'),
            _buildSectionHeader('Dependencies & Risks'),
            _buildField('Key Dependencies', _dependenciesCtrl, maxLines: 3,
                hint: 'External systems, third-party releases, infrastructure prerequisites'),
            _buildField('Assumptions', _assumptionsCtrl, maxLines: 3,
                hint: 'Assumptions made for this release to succeed'),
            _buildField('Release Risks', _risksCtrl, maxLines: 3,
                hint: 'Identified risks with mitigation strategies'),
            _buildSectionHeader('Rollback & Recovery'),
            _buildField('Rollback Plan', _rollbackCtrl, maxLines: 3,
                hint: 'Steps to roll back if release fails'),
            _buildField('Recovery Procedures', _recoveryCtrl, maxLines: 3,
                hint: 'Data restoration, environment recovery, fallback activation'),
            _buildSectionHeader('Communication & Training'),
            _buildField('Communication Plan', _communicationCtrl, maxLines: 3,
                hint: 'Stakeholder notifications, release announcements, status updates'),
            _buildField('Training Plan', _trainingCtrl, maxLines: 3,
                hint: 'User readiness, support team training, documentation updates'),
            _buildSectionHeader('Post-Release Support'),
            _buildField('Monitoring Plan', _monitoringCtrl, maxLines: 3,
                hint: 'Key metrics, dashboards, alerting thresholds'),
            _buildField('Feedback Collection', _feedbackCtrl, maxLines: 3,
                hint: 'User feedback channels, NPS surveys, issue tracking'),
            _buildField('Continuous Improvement', _improvementCtrl, maxLines: 3,
                hint: 'Retrospective follow-up, action items, process improvements'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final updated = AgileReleasePlan(
              id: widget.plan.id,
              releaseLabel: _labelCtrl.text,
              releaseDate: _releaseDate,
              releaseGoal: _goalCtrl.text,
              scope: _scopeCtrl.text,
              status: _status,
              version: _versionCtrl.text,
              piNumber: int.tryParse(_piCtrl.text),
              trainName: _trainCtrl.text,
              epicIds: _selectedEpicIds.toList(),
              featureIds: _selectedFeatureIds.toList(),
              storyIds: _selectedStoryIds.toList(),
              cadenceType: _cadenceType,
              sprintLengthDays: int.tryParse(_sprintLengthCtrl.text),
              numberOfSprintsInRelease: int.tryParse(_numSprintsCtrl.text),
              releaseFrequency: _releaseFreqCtrl.text,
              definitionOfDone: _dodCtrl.text,
              qualityGates: _qualityGatesCtrl.text,
              testingRequirements: _testingReqCtrl.text,
              approvalRequirements: _approvalReqCtrl.text,
              deploymentStrategy: _deploymentStrategy,
              deploymentEnvironments: _depEnvironmentsCtrl.text,
              featureFlagPlan: _featureFlagCtrl.text,
              keyDependencies: _dependenciesCtrl.text,
              assumptions: _assumptionsCtrl.text,
              releaseRisks: _risksCtrl.text,
              rollbackPlan: _rollbackCtrl.text,
              recoveryProcedures: _recoveryCtrl.text,
              communicationPlan: _communicationCtrl.text,
              trainingPlan: _trainingCtrl.text,
              monitoringPlan: _monitoringCtrl.text,
              feedbackCollection: _feedbackCtrl.text,
              continuousImprovement: _improvementCtrl.text,
            );
            widget.onSave(updated);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
