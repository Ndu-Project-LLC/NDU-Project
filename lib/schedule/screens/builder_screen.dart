library;

/// Builder Screen — decompose WBS into a multi-level schedule.
///
/// Activity tree (Level 0→8) with add/edit/delete/reorder. Below the live
/// activity tree, a sample activity table demonstrates the columnar view that
/// will appear on the Gantt and List View tabs once activities are added.
///
/// A "Drawing from" context banner is rendered below the level-convention
/// card so the user can see that this page consumes the WBS (deliverables +
/// sub-deliverables) and the Cost Estimate (total budget) from earlier in
/// the Planning Phase.
///
/// Rendered inside the parent module's `ResponsiveScaffold` body — no
/// per-screen Scaffold wrapper (parent provides white background).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/schedule/services/schedule_cpm_service.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/services/integrated_work_package_service.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/epic_feature_service.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';
import 'package:ndu_project/services/roadmap_service.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart'
    hide ScheduleActivity;

class BuilderScreen extends StatefulWidget {
  const BuilderScreen({super.key});

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-populate disabled — unified sync runs from ScheduleModuleScreen.
  }

  Future<void> _createActivitiesFromPackages({bool autoMode = false}) async {
    final scheduleProvider = context.read<ScheduleProvider>();
    final data = ProjectDataHelper.getData(context, listen: false);

    final packages = data.workPackages;
    if (packages.isEmpty) {
      if (mounted && !autoMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No work packages found. Create them in Execution Work Packages first.')),
        );
      }
      return;
    }

    final existingActivityWpIds = data.scheduleActivities
        .map((a) => a.workPackageId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final existingWbsIds = data.scheduleActivities
        .map((a) => a.wbsId)
        .where((id) => id.isNotEmpty)
        .toSet();

    final newPackages =
        packages.where((p) => !existingActivityWpIds.contains(p.id)).toList();
    final duplicateWbsPackages = newPackages
        .where((p) =>
            p.wbsItemId.isNotEmpty && existingWbsIds.contains(p.wbsItemId))
        .length;
    if (newPackages.isEmpty) {
      if (mounted && !autoMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('All work packages already have schedule activities.')),
        );
      }
      return;
    }

    final pkgToActId = <String, String>{};
    for (final pkg in newPackages) {
      pkgToActId[pkg.id] = newSchedId('act');
    }
    final packageIdSet = newPackages.map((p) => p.id).toSet();

    final root = scheduleProvider.schedule!.activities[0];
    var newChildren = [...root.children];

    List<String> _depPackageIds(WorkPackage pkg) {
      final deps = <String>{};
      void addIfPresent(String id) {
        if (id.trim().isNotEmpty && packageIdSet.contains(id.trim())) {
          deps.add(id.trim());
        }
      }

      switch (pkg.packageClassification) {
        case IntegratedWorkPackageService.procurementPackage:
          for (final id in pkg.linkedEngineeringPackageIds) addIfPresent(id);
          addIfPresent(pkg.parentPackageId);
        case IntegratedWorkPackageService.constructionCwp:
        case IntegratedWorkPackageService.implementationWorkPackage:
        case IntegratedWorkPackageService.agileIterationPackage:
          for (final id in pkg.linkedEngineeringPackageIds) addIfPresent(id);
          for (final id in pkg.linkedProcurementPackageIds) addIfPresent(id);
          addIfPresent(pkg.parentPackageId);
        case IntegratedWorkPackageService.preCommissioningPackage:
          addIfPresent(pkg.parentPackageId);
          for (final id in pkg.linkedEngineeringPackageIds) addIfPresent(id);
        case IntegratedWorkPackageService.commissioningPackage:
          addIfPresent(pkg.parentPackageId);
          for (final id in pkg.linkedEngineeringPackageIds) addIfPresent(id);
        default:
          break;
      }
      return deps.toList();
    }

    for (final pkg in newPackages) {
      final domain = _domainForPackage(pkg);
      final activityType = _typeForPackage(pkg);
      final activityId = pkgToActId[pkg.id]!;

      final depPackageIds = _depPackageIds(pkg);
      final dependencies = depPackageIds
          .where((depId) => pkgToActId.containsKey(depId))
          .map((depId) => ActivityDependency(
                activityId: pkgToActId[depId]!,
                type: DependencyType.finishToStart,
              ))
          .toList();

      final level = pkg.wbsLevel2Id.isNotEmpty ? 3 : 2;
      final description = StringBuffer();
      if (pkg.description.isNotEmpty) description.writeln(pkg.description);
      if (pkg.deliverables.isNotEmpty) {
        description.writeln(
            'Deliverables: ${pkg.deliverables.map((d) => d.title).join(', ')}');
      }

      newChildren.add(ScheduleActivity(
        id: activityId,
        level: level,
        code: '',
        name: _formatPackageName(pkg),
        description: description.toString().trim(),
        type: activityType,
        domain: domain,
        duration:
            IntegratedWorkPackageService.estimateDurationDays(pkg).toDouble(),
        durationUnit: 'day',
        owner: pkg.owner.isNotEmpty ? pkg.owner : pkg.contractorOrCrew,
        dependencies: dependencies,
        aiGenerated: false,
        wbsNodeId: pkg.wbsItemId,
        startDate: pkg.plannedStart != null && pkg.plannedStart!.isNotEmpty
            ? DateTime.tryParse(pkg.plannedStart!)
            : null,
        endDate: pkg.plannedEnd != null && pkg.plannedEnd!.isNotEmpty
            ? DateTime.tryParse(pkg.plannedEnd!)
            : null,
        status: pkg.releaseStatus.isNotEmpty ? pkg.releaseStatus : 'draft',
        progress: pkg.percentComplete,
        importSource: 'work_package',
        children: [],
      ));
    }

    final updatedRoot =
        recalcActivityCodes(root.copyWith(children: newChildren));
    scheduleProvider.setActivities([updatedRoot]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(autoMode
              ? 'Auto-populated ${newPackages.length} schedule activities from integrated work packages${duplicateWbsPackages > 0 ? ' · $duplicateWbsPackages share WBS links with existing schedule rows' : ''}.'
              : 'Created ${newPackages.length} schedule activities from work packages${duplicateWbsPackages > 0 ? ' · $duplicateWbsPackages share WBS links with existing schedule rows' : ''}.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: LightModeColors.accent,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _importStories() async {
    final scheduleProvider = context.read<ScheduleProvider>();
    final projectData = ProjectDataHelper.getData(context, listen: false);
    final pid = projectData.projectId;
    if (pid == null || pid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No project ID found.')),
        );
      }
      return;
    }

    // Load epics + features + stories from Firestore
    final epics = await EpicFeatureService.loadEpics(pid);
    if (epics.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No epics found. Sync from WBS or create epics first in the Agile Delivery Model.')),
        );
      }
      return;
    }

    final stories = <({
      AgileTask story,
      String epicTitle,
      String featureTitle,
      String? sprintLabel,
      String? releaseLabel
    })>[];
    int totalStories = 0;

    final tasks = await ExecutionPhaseService.loadAgileTasks(projectId: pid);
    final sprintData = await RoadmapService.loadSprints(projectId: pid);
    final releaseData = await AgileWireframeService.loadReleasePlans(pid);
    final sprintLabelById = {
      for (final sprint in sprintData) sprint.id: sprint.name
    };
    final releaseLabelById = {
      for (final release in releaseData) release.id: release.releaseLabel
    };

    for (final epic in epics) {
      final features = await EpicFeatureService.loadFeatures(pid, epic.id);
      for (final feature in features) {
        final matchingTasks = tasks
            .where((t) => t.epicId == epic.id && t.featureId == feature.id);
        for (final task in matchingTasks) {
          stories.add((
            story: task,
            epicTitle: epic.title.isNotEmpty ? epic.title : 'Unnamed Epic',
            featureTitle:
                feature.title.isNotEmpty ? feature.title : 'Unnamed Feature',
            sprintLabel: sprintLabelById[task.plannedSprintId],
            releaseLabel: releaseLabelById[task.plannedReleaseId],
          ));
          totalStories++;
        }
      }
    }

    if (stories.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No stories found assigned to features. Create stories in Agile Development Iterations first.')),
        );
      }
      return;
    }

    final missingSprint =
        stories.where((entry) => entry.story.plannedSprintId.isEmpty).length;
    final missingRelease =
        stories.where((entry) => entry.story.plannedReleaseId.isEmpty).length;
    final notReady = stories
        .where((entry) => entry.story.readinessStatus != 'Ready for Sprint')
        .length;

    scheduleProvider.importStoriesFromAgile(stories: stories);

    if (mounted) {
      final warningParts = <String>[];
      if (missingSprint > 0) warningParts.add('$missingSprint without sprint');
      if (missingRelease > 0) {
        warningParts.add('$missingRelease without release');
      }
      if (notReady > 0) warningParts.add('$notReady not sprint-ready');
      final existingAgileIds = scheduleProvider.schedule?.activities
              .expand((root) => ScheduleCpmService.flatten([root]))
              .where((a) => a.agileTaskId != null && a.agileTaskId!.isNotEmpty)
              .map((a) => a.agileTaskId!)
              .toSet() ??
          <String>{};
      final duplicateStories = stories
          .where((entry) => existingAgileIds.contains(entry.story.id))
          .length;
      if (duplicateStories > 0) {
        warningParts.add('$duplicateStories already imported');
      }
      final warningSuffix =
          warningParts.isEmpty ? '' : ' Warning: ${warningParts.join(' · ')}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Imported $totalStories stories from ${epics.length} epics into schedule.$warningSuffix'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: warningParts.isEmpty
              ? LightModeColors.accent
              : const Color(0xFFF59E0B),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _runCpm() {
    final scheduleProvider = context.read<ScheduleProvider>();
    final result = scheduleProvider.computeCpm(overwriteDates: false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No activities to compute CPM on.')),
      );
      return;
    }
    final critCount = result.criticalPathIds.length;
    final totalFloatItems =
        result.activitiesById.values.where((a) => a.totalFloat > 0).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'CPM: ${result.projectDurationDays.toStringAsFixed(1)} days total · '
          '$critCount critical activities · '
          '$totalFloatItems with float',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: LightModeColors.accent,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  String _formatPackageName(WorkPackage pkg) {
    final readable = pkg.packageClassification
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}')
        .trim();
    final title = pkg.title.isNotEmpty ? pkg.title : 'Untitled';
    return '$readable: $title';
  }

  ScheduleDomain _domainForPackage(WorkPackage pkg) {
    switch (pkg.packageClassification) {
      case 'engineeringEwp':
      case 'design':
        return ScheduleDomain.engineering;
      case 'procurementPackage':
        return ScheduleDomain.procurement;
      case 'constructionCwp':
        return ScheduleDomain.construction;
      case 'preCommissioningPackage':
      case 'commissioningPackage':
        return ScheduleDomain.commissioning;
      case 'implementationWorkPackage':
      case 'agileIterationPackage':
        return ScheduleDomain.execution;
      default:
        return ScheduleDomain.engineering;
    }
  }

  ActivityType _typeForPackage(WorkPackage pkg) {
    switch (pkg.packageClassification) {
      case 'engineeringEwp':
        return ActivityType.ewp;
      case 'procurementPackage':
        return ActivityType.procurementPackage;
      case 'constructionCwp':
        return ActivityType.cwp;
      case 'preCommissioningPackage':
      case 'commissioningPackage':
      case 'implementationWorkPackage':
      case 'agileIterationPackage':
        return ActivityType.activity;
      default:
        return ActivityType.summary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ScheduleProvider, WBSProvider, CostEstimateProvider>(
      builder: (context, provider, wbsProvider, costProvider, _) {
        final schedule = provider.schedule!;
        final root = schedule.activities[0];
        final wbs = wbsProvider.wbs;
        final wbsCounts = wbs != null ? countNodes(wbs) : null;
        final estimate = costProvider.estimate;
        final currency = estimate?.currency ?? 'USD';
        final costTotal = estimate != null
            ? estimate.lines.fold<double>(
                0, (s, l) => s + _effectiveScheduleBuilderLineTotal(l))
            : 0.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.folder_open,
                                color: LightModeColors.accent, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(schedule.projectName,
                                  style: const TextStyle(
                                      color: Color(0xFF1A1D1F),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${schedule.basis.deliveryModel} · ${root.children.length} Level 1 activities · Status: ${schedule.status.label}',
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ActionChip(
                        icon: Icons.add,
                        label: 'Add Activity',
                        primary: true,
                        enabled: !schedule.isLocked,
                        onTap: () =>
                            _showAddDialog(context, provider, root.id, 1),
                      ),
                      _ActionChip(
                        icon: Icons.date_range,
                        label: 'Setup Timeline',
                        enabled: !schedule.isLocked,
                        onTap: () =>
                            _showTimelineSetupDialog(context, provider, root),
                      ),
                      _ActionChip(
                        icon: Icons.upload_outlined,
                        label: 'Import by Methodology',
                        enabled: !schedule.isLocked,
                        onTap: () => _showImportInfo(context),
                      ),
                      _ActionChip(
                        icon: Icons.work_outline,
                        label: 'From Work Packages',
                        enabled: !schedule.isLocked,
                        onTap: () => _createActivitiesFromPackages(),
                      ),
                      if (schedule.basis.deliveryModel == 'AGILE' ||
                          schedule.basis.deliveryModel == 'HYBRID')
                        _ActionChip(
                          icon: Icons.auto_stories,
                          label: 'Import Agile Stories',
                          enabled: !schedule.isLocked,
                          onTap: () => _importStories(),
                        ),
                      _ActionChip(
                        icon: Icons.calculate_outlined,
                        label: 'Run CPM',
                        enabled: !schedule.isLocked,
                        onTap: () => _runCpm(),
                      ),
                      _ActionChip(
                        icon: Icons.download_outlined,
                        label: 'Export',
                        onTap: () => _exportSchedule(context, schedule),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Help / level-convention card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 16, color: LightModeColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Schedule levels: L0=Project · L1=Major Deliverable · L2=Epic/Sub-Deliverable · L3=EWP/Procurement/CWP · L4=Activity/Story · L5–8=Task. Waterfall/Hybrid schedules should be built from integrated work packages; Agile schedules should be built from story-level AgileTask items.',
                        style: TextStyle(
                            color: const Color(0xFF495057),
                            fontSize: 12,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // "Drawing from" context banner — shows the upstream WBS and
              // Cost Estimate data this builder is consuming.
              _DrawingFromBanner(
                wbs: wbs,
                wbsCounts: wbsCounts,
                costTotal: costTotal,
                currency: currency,
                hasEstimate: estimate != null,
              ),
              const SizedBox(height: 24),
              // Timeline Visualization
              const SizedBox(height: 8),
              _TimelineVisualization(
                activities: [root, ...root.children],
                provider: provider,
                isLocked: schedule.isLocked,
              ),
              const SizedBox(height: 24),
              // Live activity tree
              Text('Activity Tree',
                  style: const TextStyle(
                      color: Color(0xFF1A1D1F),
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _ActivityNode(
                  activity: root,
                  isRoot: true,
                  provider: provider,
                  isLocked: schedule.isLocked),
              ...root.children.map((child) => _ActivityNode(
                  activity: child,
                  provider: provider,
                  isLocked: schedule.isLocked)),
              const SizedBox(height: 32),
              // Sample activity table (preview of what Gantt/List will show)
              _SampleActivityTable(schedule: schedule),
              const SizedBox(height: 24),
              // Footer note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LightModeColors.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: LightModeColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: LightModeColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The table above shows a sample schedule for reference. Add your own activities via the Add Activity button to populate the Gantt and List View tabs. Each row maps to an EWP, CWP, or activity in your delivery model.',
                        style: TextStyle(
                            color: const Color(0xFF495057),
                            fontSize: 12,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Mirror of [ComputeUtils] effective line total so the schedule builder
  /// can show a variance-aware total without re-implementing the full totals
  /// computation. Kept private — this is the same logic the Cost Estimate
  /// module uses internally.
  double _effectiveScheduleBuilderLineTotal(CostLine l) {
    if (l.varianceType == VarianceType.remove) {
      return -(l.varianceBaselineTotal ?? 0);
    }
    if (l.varianceType == VarianceType.change) {
      return l.varianceDelta ?? 0;
    }
    return l.total;
  }

  void _showTimelineSetupDialog(
      BuildContext context, ScheduleProvider provider, ScheduleActivity root) {
    final startCtrl = TextEditingController(
      text: root.startDate != null
          ? DateFormat('MM/dd/yy').format(root.startDate!)
          : '01/06/26',
    );
    final endCtrl = TextEditingController(
      text: root.endDate != null
          ? DateFormat('MM/dd/yy').format(root.endDate!)
          : '12/31/26',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE4E7EC)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: LightModeColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.date_range,
                  size: 18, color: LightModeColors.accent),
            ),
            const SizedBox(width: 12),
            const Text('Setup Project Timeline',
                style: TextStyle(
                    color: Color(0xFF1A1D1F),
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set the overall project timeline. Individual activity dates can be adjusted below.',
                style: TextStyle(
                    color: Color(0xFF6B7280), fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Project Start',
                      controller: startCtrl,
                      icon: Icons.play_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'Project End',
                      controller: endCtrl,
                      icon: Icons.stop_circle_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.info_outline,
                        size: 14, color: Color(0xFF6B7280)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This sets the project-wide date range. Use the timeline view below to set dates for individual activities.',
                        style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            onPressed: () {
              final startDate = _parseDate(startCtrl.text);
              final endDate = _parseDate(endCtrl.text);
              if (startDate != null && endDate != null) {
                provider.updateActivity(
                    root.id,
                    root.copyWith(
                      startDate: startDate,
                      endDate: endDate,
                    ));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Project timeline set: ${DateFormat('MMM d, y').format(startDate)} — ${DateFormat('MMM d, y').format(endDate)}'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: LightModeColors.accent,
                    duration: const Duration(seconds: 3),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Please enter valid dates in MM/DD/YY format')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: LightModeColors.accent,
              foregroundColor: LightModeColors.lightOnPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Apply Timeline'),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(String text) {
    try {
      final cleaned = text.trim();
      if (cleaned.isEmpty) return null;
      // Try MM/dd/yy first
      return DateFormat('MM/dd/yy').parse(cleaned);
    } catch (_) {
      try {
        return DateFormat('MM/dd/yyyy').parse(text.trim());
      } catch (_) {
        return null;
      }
    }
  }

  void _showAddDialog(BuildContext context, ScheduleProvider provider,
      String parentId, int level) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE4E7EC))),
        title: Text('Add Level $level Activity',
            style: const TextStyle(
                color: Color(0xFF1A1D1F), fontWeight: FontWeight.w600)),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: 'Activity name',
            labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: LightModeColors.accent, width: 1.6),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
            ),
          ),
          style: const TextStyle(color: Color(0xFF1A1D1F)),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                provider.addActivity(
                  parentId,
                  ScheduleActivity(
                    id: '',
                    level: 0,
                    code: '',
                    name: nameCtrl.text.trim(),
                    type: level <= 1
                        ? ActivityType.summary
                        : ActivityType.activity,
                    domain: ScheduleDomain.engineering,
                    dependencies: [],
                    aiGenerated: false,
                    children: [],
                  ),
                );
                Navigator.pop(ctx);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: LightModeColors.accent,
              foregroundColor: LightModeColors.lightOnPrimary,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showImportInfo(BuildContext context) {
    final wbsProvider = context.read<WBSProvider>();
    final wbs = wbsProvider.wbs;
    if (wbs == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE4E7EC))),
          title: const Text('No WBS Available',
              style: TextStyle(
                  color: Color(0xFF1A1D1F), fontWeight: FontWeight.w600)),
          content: const Text(
            'Open the WBS module from the sidebar to create your work breakdown structure first, then return here to continue schedule setup.',
            style:
                TextStyle(color: Color(0xFF495057), fontSize: 13, height: 1.5),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: LightModeColors.accent,
                foregroundColor: LightModeColors.lightOnPrimary,
              ),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }

    final methodology = wbs.methodology.name.toLowerCase();
    final isWaterfallLike =
        methodology == 'waterfall' || methodology == 'hybrid';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE4E7EC))),
        title: Text(
          isWaterfallLike
              ? 'Use work packages for schedule import'
              : 'Import agile stories into schedule',
          style: const TextStyle(
              color: Color(0xFF1A1D1F), fontWeight: FontWeight.w600),
        ),
        content: Text(
          isWaterfallLike
              ? 'For waterfall and hybrid projects, the schedule builder now prefers integrated work packages instead of direct WBS activities. Generate package chains first, then create schedule activities from packages.'
              : 'For agile projects, the schedule builder imports the lowest-level agile stories grouped under features and epics, rather than importing raw WBS nodes directly.',
          style: const TextStyle(
              color: Color(0xFF495057), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (isWaterfallLike) {
                _createActivitiesFromPackages();
              } else {
                _importStories();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: LightModeColors.accent,
              foregroundColor: LightModeColors.lightOnPrimary,
            ),
            child: Text(isWaterfallLike ? 'Use Packages' : 'Import Stories'),
          ),
        ],
      ),
    );
  }

  void _exportSchedule(BuildContext context, Schedule schedule) async {
    final json = const JsonEncoder.withIndent('  ').convert({
      'id': schedule.id,
      'projectName': schedule.projectName,
      'deliveryModel': schedule.basis.deliveryModel,
      'status': schedule.status.name,
      'isLocked': schedule.isLocked,
      'activities': _activityToJson(schedule.activities[0]),
    });
    await Clipboard.setData(ClipboardData(text: json));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Schedule JSON copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: LightModeColors.accent,
      ),
    );
  }

  Map<String, dynamic> _activityToJson(ScheduleActivity node) {
    return {
      'code': node.code,
      'name': node.name,
      'level': node.level,
      'type': node.type.name,
      'domain': node.domain.name,
      if (node.duration != null) 'duration': node.duration,
      if (node.durationUnit != null) 'durationUnit': node.durationUnit,
      if (node.owner != null) 'owner': node.owner,
      if (node.status != null) 'status': node.status,
      'children': node.children.map(_activityToJson).toList(),
    };
  }
}

/// Compact action chip used in the Builder header.
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = !enabled;
    if (primary && !disabled) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: LightModeColors.accent,
          foregroundColor: LightModeColors.lightOnPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: disabled ? null : onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor:
            disabled ? const Color(0xFF9CA3AF) : const Color(0xFF1A1D1F),
        backgroundColor: Colors.white,
        side: BorderSide(
            color:
                disabled ? const Color(0xFFE4E7EC) : const Color(0xFFE4E7EC)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// A single activity node in the live tree.
class _ActivityNode extends StatelessWidget {
  final ScheduleActivity activity;
  final bool isRoot;
  final ScheduleProvider provider;
  final bool isLocked;

  const _ActivityNode({
    required this.activity,
    this.isRoot = false,
    required this.provider,
    required this.isLocked,
  });

  List<Widget> _traceabilityChips() {
    final chips = <Widget>[];
    if (activity.importSource != null && activity.importSource == 'fep_milestone') {
      chips.add(_miniChip(Icons.flag_outlined, 'FEP Milestone'));
    } else if (activity.importSource != null &&
        activity.importSource == 'work_package') {
      chips.add(_miniChip(Icons.inventory_2_outlined, 'Package Import'));
    }
    if (activity.wbsNodeId != null && activity.wbsNodeId!.isNotEmpty) {
      chips.add(_miniChip(Icons.account_tree_outlined, 'WBS linked'));
    }
    if (activity.agileTaskId != null && activity.agileTaskId!.isNotEmpty) {
      chips.add(_miniChip(
          Icons.auto_stories_outlined,
          activity.agileFeatureTitle != null &&
                  activity.agileFeatureTitle!.isNotEmpty
              ? 'Story · ${activity.agileFeatureTitle!}'
              : 'Agile story'));
    }
    if (activity.sprintId != null && activity.sprintId!.isNotEmpty) {
      chips.add(_miniChip(
          Icons.calendar_today_outlined,
          activity.sprintLabel != null && activity.sprintLabel!.isNotEmpty
              ? activity.sprintLabel!
              : 'Sprint assigned'));
    }
    if (activity.releaseId != null && activity.releaseId!.isNotEmpty) {
      chips.add(_miniChip(
          Icons.rocket_launch_outlined,
          activity.releaseLabel != null && activity.releaseLabel!.isNotEmpty
              ? activity.releaseLabel!
              : 'Release assigned'));
    }
    if (activity.prerequisites != null && activity.prerequisites!.isNotEmpty) {
      chips.add(_miniChip(
          Icons.link_outlined, '${activity.prerequisites!.length} prereq'));
    }
    return chips;
  }

  Widget _miniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showActivityEditDialog(context),
      child: Container(
        margin: EdgeInsets.only(bottom: 6, left: isRoot ? 0 : 24),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: Color(activity.domain.color), width: 3),
            top: const BorderSide(color: Color(0xFFE4E7EC), width: 1),
            right: const BorderSide(color: Color(0xFFE4E7EC), width: 1),
            bottom: const BorderSide(color: Color(0xFFE4E7EC), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: Text(activity.code,
                  style: const TextStyle(
                      color: Color(0xFF495057),
                      fontSize: 11,
                      fontFamily: appFontFamily,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: Color(activity.domain.color), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(activity.name,
                  style: const TextStyle(
                      color: Color(0xFF1A1D1F),
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
            if (formatDuration(activity.duration, activity.durationUnit) != '—')
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                    formatDuration(activity.duration, activity.durationUnit),
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 11)),
              ),
            // Dependency type chips
            if (activity.dependencies.isNotEmpty)
              ...activity.dependencies.map((dep) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Text(
                        dep.type.short,
                        style: const TextStyle(
                            color: Color(0xFF166534),
                            fontSize: 9,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  )),
            // Inline start/end date chips
            if (activity.startDate != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    'Start: ${activity.startDate!.month}/${activity.startDate!.day}/${activity.startDate!.year.toString().substring(2)}',
                    style: const TextStyle(
                        color: Color(0xFF065F46),
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (activity.endDate != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    'End: ${activity.endDate!.month}/${activity.endDate!.day}/${activity.endDate!.year.toString().substring(2)}',
                    style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (_traceabilityChips().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 240,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _traceabilityChips(),
                  ),
                ),
              ),
            if (activity.agileEpicTitle != null &&
                activity.agileEpicTitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'Epic: ${activity.agileEpicTitle!}${activity.agileFeatureTitle != null && activity.agileFeatureTitle!.isNotEmpty ? ' · Feature: ${activity.agileFeatureTitle!}' : ''}',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ),
            if (!isRoot && !isLocked) ...[
              IconButton(
                icon: const Icon(Icons.add, size: 14, color: Color(0xFF6B7280)),
                onPressed: () {},
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 14, color: Color(0xFFB91C1C)),
                onPressed: () => provider.removeActivity(activity.id),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showActivityEditDialog(BuildContext context) {
    if (isRoot || isLocked) return;
    final deps = List<ActivityDependency>.from(activity.dependencies);
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit: ${activity.name}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dependencies',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                if (deps.isEmpty)
                  const Text('No dependencies',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                ...deps.asMap().entries.map((entry) {
                  final i = entry.key;
                  final dep = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(dep.activityId,
                              style: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 140,
                          child: DropdownButtonFormField<DependencyType>(
                            value: dep.type,
                            isDense: true,
                            items: DependencyType.values.map((t) {
                              return DropdownMenuItem(
                                  value: t,
                                  child: Text('${t.short} - ${t.label}',
                                      style: const TextStyle(fontSize: 11)));
                            }).toList(),
                            onChanged: (newType) {
                              if (newType != null) {
                                setDialogState(() {
                                  deps[i] = ActivityDependency(
                                      activityId: dep.activityId,
                                      type: newType);
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                provider.updateActivity(
                  activity.id,
                  activity.copyWith(dependencies: deps),
                );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive sample activity table with inline editing, add-row, and KAZ AI
/// generation. Demonstrates the full columnar view (ID, Name, Duration, Start,
/// Finish, Predecessors, Resources) that the Gantt and List View tabs render.
class _SampleActivityTable extends StatefulWidget {
  final Schedule schedule;
  const _SampleActivityTable({required this.schedule});

  @override
  State<_SampleActivityTable> createState() => _SampleActivityTableState();
}

class _SampleActivityTableState extends State<_SampleActivityTable> {
  late List<_SampleRow> _rows;

  final _nameCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _startCtrl = TextEditingController(text: '01/06/26');
  final _finishCtrl = TextEditingController(text: '01/30/26');
  final _predecessorsCtrl = TextEditingController();
  final _resourcesCtrl = TextEditingController();
  bool _isGenerating = false;
  int _nextId = 8;

  @override
  void initState() {
    super.initState();
    _rows = _sampleRows(
        widget.schedule.projectName, widget.schedule.basis.deliveryModel);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _durationCtrl.dispose();
    _startCtrl.dispose();
    _finishCtrl.dispose();
    _predecessorsCtrl.dispose();
    _resourcesCtrl.dispose();
    super.dispose();
  }

  void _addRow() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _rows.add(_SampleRow(
        (_nextId++).toString(),
        name,
        _durationCtrl.text.trim().isNotEmpty ? _durationCtrl.text.trim() : '—',
        _startCtrl.text.trim().isNotEmpty ? _startCtrl.text.trim() : '—',
        _finishCtrl.text.trim().isNotEmpty ? _finishCtrl.text.trim() : '—',
        _predecessorsCtrl.text.trim().isNotEmpty
            ? _predecessorsCtrl.text.trim()
            : '—',
        _resourcesCtrl.text.trim().isNotEmpty
            ? _resourcesCtrl.text.trim()
            : '—',
        ScheduleDomain.execution.color,
      ));
      _nameCtrl.clear();
      _durationCtrl.clear();
      _predecessorsCtrl.clear();
      _resourcesCtrl.clear();
      _startCtrl.text = '01/06/26';
      _finishCtrl.text = '01/30/26';
    });
  }

  void _removeRow(int index) {
    if (index < 0 || index >= _rows.length) return;
    setState(() => _rows.removeAt(index));
  }

  Future<void> _generateWithKazAi() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      final projectName = widget.schedule.projectName;
      final deliveryModel = widget.schedule.basis.deliveryModel;
      final existingCount = _rows.length;

      final ai = OpenAiServiceSecure();
      final result = await ai.generateCompletion(
        'You are a project schedule expert. Generate 3-5 additional schedule '
        'activities for a project called "$projectName" using the '
        '$deliveryModel delivery model. The existing $existingCount activities '
        'cover engineering, procurement, execution, construction, and '
        'commissioning. Suggest realistic follow-on or parallel activities '
        'with typical durations and resource assignments.\n\n'
        'Return the result as a pipe-delimited table with columns:\n'
        'ID|Activity Name|Duration|Start|Finish|Predecessors|Resources\n'
        'Use sequential IDs starting at $_nextId. Dates should be in MM/DD/YY format, '
        'continuing from mid-to-late 2026.\n\n'
        'Example:\n'
        '$_nextId|Site Preparation|15 d|08/24/26|09/11/26|7FS|Civil Crew (4)\n'
        'Return ONLY the pipe-delimited rows, one per line, no headers, no markdown.',
        maxTokens: 500,
        temperature: 0.7,
      );

      if (!mounted) return;

      final lines = result
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.contains('|'))
          .toList();

      if (lines.isEmpty) {
        _showInfo('Could not parse AI response. Try again.');
        return;
      }

      final domains = [
        ScheduleDomain.engineering.color,
        ScheduleDomain.procurement.color,
        ScheduleDomain.execution.color,
        ScheduleDomain.construction.color,
        ScheduleDomain.commissioning.color,
      ];

      setState(() {
        for (final line in lines) {
          final parts = line.split('|').map((p) => p.trim()).toList();
          if (parts.length < 7) continue;
          final name = parts[1];
          final duration = parts[2];
          final start = parts[3];
          final finish = parts[4];
          final predecessors = parts[5];
          final resources = parts[6];
          final domainColor = domains[_nextId % domains.length];
          _rows.add(_SampleRow(
            (_nextId++).toString(),
            name,
            duration,
            start,
            finish,
            predecessors,
            resources,
            domainColor,
          ));
        }
      });

      _showInfo(
          'Added ${lines.length} AI-generated activities to the schedule.');
    } catch (e) {
      if (mounted) {
        _showInfo('KAZ AI generation failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.table_chart,
                    size: 16, color: LightModeColors.accent),
                const SizedBox(width: 8),
                const Text('Sample Activity Schedule',
                    style: TextStyle(
                        color: Color(0xFF1A1D1F),
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                // KAZ AI generate button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _isGenerating
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isGenerating
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: InkWell(
                    onTap: _isGenerating ? null : _generateWithKazAi,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isGenerating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFF59E0B),
                                  ),
                                )
                              : const Icon(Icons.auto_awesome,
                                  size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 6),
                          Text(
                            _isGenerating ? 'Generating...' : 'KAZ AI',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                  ),
                  child: Text('${_rows.length} activities',
                      style: const TextStyle(
                          color: Color(0xFF495057),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE4E7EC), height: 1),
          // Data table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
              dataRowColor: WidgetStateProperty.all(Colors.transparent),
              columnSpacing: 24,
              horizontalMargin: 16,
              columns: const [
                DataColumn(
                    label: Text('ID',
                        style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Name',
                        style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Duration',
                        style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Start',
                        style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Finish',
                        style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Predecessors',
                        style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.w600))),
                DataColumn(
                    label: Text('Resources',
                        style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.w600))),
                DataColumn(label: SizedBox(width: 32)),
              ],
              rows: [
                // Data rows
                ..._rows.asMap().entries.map((entry) {
                  final i = entry.key;
                  final r = entry.value;
                  return DataRow(
                    cells: [
                      DataCell(Text(r.id,
                          style: const TextStyle(
                              color: Color(0xFF495057),
                              fontSize: 11,
                              fontFamily: appFontFamily,
                              fontWeight: FontWeight.bold))),
                      DataCell(Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: Color(r.domainColor),
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(r.name,
                              style: const TextStyle(
                                  color: Color(0xFF1A1D1F),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      )),
                      DataCell(Text(r.duration,
                          style: const TextStyle(
                              color: Color(0xFF495057), fontSize: 12))),
                      DataCell(Text(r.start,
                          style: const TextStyle(
                              color: Color(0xFF495057), fontSize: 12))),
                      DataCell(Text(r.finish,
                          style: const TextStyle(
                              color: Color(0xFF495057), fontSize: 12))),
                      DataCell(Text(r.predecessors,
                          style: const TextStyle(
                              color: Color(0xFF495057),
                              fontSize: 11,
                              fontFamily: appFontFamily))),
                      DataCell(Text(r.resources,
                          style: const TextStyle(
                              color: Color(0xFF495057), fontSize: 12))),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              size: 16, color: Color(0xFF9CA3AF)),
                          onPressed: () => _removeRow(i),
                          tooltip: 'Remove activity',
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      ),
                    ],
                  );
                }),
                // ── New-row edit fields ──
                DataRow(
                  color: WidgetStateProperty.all(const Color(0xFFFAFFFB)),
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 40,
                        child: Text(
                          _nextId.toString(),
                          style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 11,
                              fontFamily: appFontFamily,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 200,
                        child: VoiceTextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            hintText: 'New activity name...',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                          ),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF1A1D1F)),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _addRow(),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 80,
                        child: VoiceTextField(
                          controller: _durationCtrl,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 10 d',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                          ),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF1A1D1F)),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 80,
                        child: VoiceTextField(
                          controller: _startCtrl,
                          decoration: const InputDecoration(
                            hintText: 'MM/DD/YY',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                          ),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF1A1D1F)),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 80,
                        child: VoiceTextField(
                          controller: _finishCtrl,
                          decoration: const InputDecoration(
                            hintText: 'MM/DD/YY',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                          ),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF1A1D1F)),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: VoiceTextField(
                          controller: _predecessorsCtrl,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 6FS',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                          ),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF1A1D1F)),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 130,
                        child: VoiceTextField(
                          controller: _resourcesCtrl,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Crew (4)',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                          ),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF1A1D1F)),
                        ),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: Icon(
                          Icons.add_circle_outline,
                          size: 20,
                          color: _nameCtrl.text.trim().isNotEmpty
                              ? const Color(0xFF10B981)
                              : const Color(0xFF9CA3AF),
                        ),
                        onPressed:
                            _nameCtrl.text.trim().isNotEmpty ? _addRow : null,
                        tooltip: 'Add activity',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Footnote
          if (_rows.length <= 7)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined,
                      size: 12, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 6),
                  Text(
                    'Type an activity name and press Enter or tap + to add. '
                    'Use KAZ AI to auto-generate realistic schedule activities.',
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<_SampleRow> _sampleRows(String projectName, String deliveryModel) {
    return [
      _SampleRow('1', 'Engineering — Process Design', '20 d', '01/06/26',
          '01/30/26', '—', 'Process Eng (2)', ScheduleDomain.engineering.color),
      _SampleRow(
          '2',
          'Procurement — Long-Lead Vessels',
          '45 d',
          '02/02/26',
          '03/20/26',
          '1FS',
          'Buyer, Expediter',
          ScheduleDomain.procurement.color),
      _SampleRow('3', 'Execution — Fabrication Phase A', '60 d', '03/23/26',
          '05/22/26', '2FS', 'Fab Shop (6)', ScheduleDomain.execution.color),
      _SampleRow(
          '4',
          'Construction — Site Mobilization',
          '10 d',
          '05/25/26',
          '06/05/26',
          '3FS-5d',
          'Site Sup (3)',
          ScheduleDomain.construction.color),
      _SampleRow(
          '5',
          'Construction — Mechanical Install',
          '35 d',
          '06/08/26',
          '07/17/26',
          '4FS',
          'Mech Crew (8)',
          ScheduleDomain.construction.color),
      _SampleRow(
          '6',
          'Commissioning — Cold Commissioning',
          '15 d',
          '07/20/26',
          '08/07/26',
          '5FS',
          'Commissioning Eng (2)',
          ScheduleDomain.commissioning.color),
      _SampleRow(
          '7',
          'Commissioning — Hot Commissioning & Handover',
          '12 d',
          '08/10/26',
          '08/22/26',
          '6FS',
          'Commissioning Eng (2)',
          ScheduleDomain.commissioning.color),
    ];
  }
}

class _SampleRow {
  final String id;
  final String name;
  final String duration;
  final String start;
  final String finish;
  final String predecessors;
  final String resources;
  final int domainColor;
  const _SampleRow(this.id, this.name, this.duration, this.start, this.finish,
      this.predecessors, this.resources, this.domainColor);
}

/// Interactive Gantt-style timeline visualization showing all activities as
/// horizontal bars. Each bar is color-coded by domain, shows start/end dates,
/// and supports inline date editing per activity.
class _TimelineVisualization extends StatefulWidget {
  final List<ScheduleActivity> activities;
  final ScheduleProvider provider;
  final bool isLocked;

  const _TimelineVisualization({
    required this.activities,
    required this.provider,
    required this.isLocked,
  });

  @override
  State<_TimelineVisualization> createState() => _TimelineVisualizationState();
}

class _TimelineVisualizationState extends State<_TimelineVisualization> {
  int? _editingIndex;
  DateTime? _editStart;
  DateTime? _editEnd;

  /// Compute the overall timeline range from all activities.
  (DateTime, DateTime) _computeRange() {
    DateTime earliest = DateTime.now();
    DateTime latest = DateTime.now().add(const Duration(days: 365));
    bool hasDates = false;
    for (final a in widget.activities) {
      if (a.startDate != null && a.endDate != null) {
        if (!hasDates) {
          earliest = a.startDate!;
          latest = a.endDate!;
          hasDates = true;
        } else {
          if (a.startDate!.isBefore(earliest)) earliest = a.startDate!;
          if (a.endDate!.isAfter(latest)) latest = a.endDate!;
        }
      }
    }
    if (!hasDates) {
      // Default range: anchor around today
      final now = DateTime.now();
      earliest = DateTime(now.year, now.month - 1, 1);
      latest = DateTime(now.year + 1, now.month + 1, 0);
    }
    // Add padding
    earliest = DateTime(earliest.year, earliest.month - 1, 1);
    latest = DateTime(latest.year, latest.month + 2, 0);
    return (earliest, latest);
  }

  List<DateTime> _monthMarkers(DateTime start, DateTime end) {
    final months = <DateTime>[];
    var current = DateTime(start.year, start.month, 1);
    while (!current.isAfter(end)) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }
    return months;
  }

  Future<void> _pickDate(
      BuildContext context, bool isStart, int activityIndex) async {
    final activity = widget.activities[activityIndex];
    final current = isStart
        ? (activity.startDate ?? DateTime.now())
        : (activity.endDate ?? DateTime.now().add(const Duration(days: 30)));
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: LightModeColors.accent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF1A1D1F),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _editStart = picked;
      } else {
        _editEnd = picked;
      }
    });
  }

  void _saveActivityDates(int activityIndex) {
    final activity = widget.activities[activityIndex];
    final start = _editStart ?? activity.startDate;
    final end = _editEnd ?? activity.endDate;
    widget.provider.updateActivity(
        activity.id,
        activity.copyWith(
          startDate: start,
          endDate: end,
        ));
    setState(() {
      _editingIndex = null;
      _editStart = null;
      _editEnd = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final (rangeStart, rangeEnd) = _computeRange();
    final totalDays = rangeEnd.difference(rangeStart).inDays.clamp(1, 9999);
    final months = _monthMarkers(rangeStart, rangeEnd);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: LightModeColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.timeline,
                      size: 16, color: LightModeColors.accent),
                ),
                const SizedBox(width: 10),
                const Text('Project Timeline',
                    style: TextStyle(
                        color: Color(0xFF1A1D1F),
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                if (!widget.isLocked)
                  _TimelineKazAiButton(
                      activities: widget.activities, provider: widget.provider),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                  ),
                  child: Text(
                    '${DateFormat('MMM d').format(rangeStart)} — ${DateFormat('MMM d, y').format(rangeEnd)}',
                    style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE4E7EC), height: 1),
          // ── Month header ──
          SizedBox(
            height: 28,
            child: Row(
              children: [
                const SizedBox(width: 160),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: months.map((month) {
                          final dayOffset = month.difference(rangeStart).inDays;
                          final fraction = dayOffset / totalDays;
                          final xPos = fraction * constraints.maxWidth;
                          return Positioned(
                            left: xPos,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 1,
                              color: const Color(0xFFE4E7EC),
                            ),
                          );
                        }).toList()
                          ..addAll(months.map((month) {
                            final dayOffset =
                                month.difference(rangeStart).inDays;
                            final fraction = dayOffset / totalDays;
                            final xPos = fraction * constraints.maxWidth;
                            return Positioned(
                              left: xPos + 4,
                              top: 6,
                              child: Text(
                                DateFormat('MMM').format(month),
                                style: TextStyle(
                                  color: month.month == DateTime.now().month &&
                                          month.year == DateTime.now().year
                                      ? LightModeColors.accent
                                      : const Color(0xFF9CA3AF),
                                  fontSize: 10,
                                  fontWeight:
                                      month.month == DateTime.now().month &&
                                              month.year == DateTime.now().year
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                ),
                              ),
                            );
                          })),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFF3F4F6), height: 1),
          // ── Activity bars ──
          ...widget.activities.asMap().entries.map((entry) {
            final i = entry.key;
            final a = entry.value;
            final isEditing = _editingIndex == i;
            final barStart = _editStart ?? a.startDate;
            final barEnd = _editEnd ?? a.endDate;
            final hasDates = barStart != null && barEnd != null;
            final leftFrac = hasDates
                ? barStart.difference(rangeStart).inDays / totalDays
                : 0.0;
            final widthFrac =
                hasDates ? barEnd.difference(barStart).inDays / totalDays : 0.0;
            final clampedLeft = leftFrac.clamp(0.0, 1.0);
            final clampedWidth = widthFrac.clamp(0.01, 1.0 - clampedLeft);

            return Column(
              children: [
                const Divider(color: Color(0xFFF3F4F6), height: 1),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // ── Activity label (fixed width) ──
                      SizedBox(
                        width: 160,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Color(a.domain.color),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.code,
                                    style: const TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 9,
                                        fontFamily: appFontFamily),
                                  ),
                                  Text(
                                    a.name,
                                    style: const TextStyle(
                                        color: Color(0xFF1A1D1F),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Gantt bar area ──
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.isLocked
                              ? null
                              : () {
                                  setState(() {
                                    if (_editingIndex == i) {
                                      _editingIndex = null;
                                    } else {
                                      _editingIndex = i;
                                      _editStart = null;
                                      _editEnd = null;
                                    }
                                  });
                                },
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                children: [
                                  // Grid lines
                                  if (months.length > 1)
                                    ...months.map((month) {
                                      final xPos =
                                          month.difference(rangeStart).inDays /
                                              totalDays *
                                              constraints.maxWidth;
                                      return Positioned(
                                        left: xPos,
                                        top: 0,
                                        bottom: 0,
                                        child: Container(
                                            width: 1,
                                            color: const Color(0xFFF3F4F6)),
                                      );
                                    }),
                                  // Bar
                                  if (hasDates)
                                    Positioned(
                                      left: clampedLeft * constraints.maxWidth,
                                      top: 10,
                                      bottom: 10,
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 250),
                                        width: (clampedWidth *
                                                constraints.maxWidth)
                                            .clamp(20.0, constraints.maxWidth),
                                        decoration: BoxDecoration(
                                          color: Color(a.domain.color)
                                              .withValues(
                                                  alpha:
                                                      isEditing ? 0.5 : 0.25),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isEditing
                                                ? LightModeColors.accent
                                                : Color(a.domain.color)
                                                    .withValues(alpha: 0.5),
                                            width: isEditing ? 2 : 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${barStart.month}/${barStart.day} — ${barEnd.month}/${barEnd.day}',
                                            style: TextStyle(
                                              color: Color(a.domain.color),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Today marker
                                  if (DateTime.now().isAfter(rangeStart) &&
                                      DateTime.now().isBefore(rangeEnd))
                                    Positioned(
                                      left: DateTime.now()
                                              .difference(rangeStart)
                                              .inDays /
                                          totalDays *
                                          constraints.maxWidth,
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 2,
                                        color: const Color(0xFFEF4444)
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  // No-dates placeholder
                                  if (!hasDates && !widget.isLocked)
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF9FAFB),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: const Color(0xFFE4E7EC),
                                              style: BorderStyle.solid),
                                        ),
                                        child: const Text(
                                          'Click to set dates',
                                          style: TextStyle(
                                              color: Color(0xFF9CA3AF),
                                              fontSize: 10),
                                        ),
                                      ),
                                    ),
                                  if (!hasDates && widget.isLocked)
                                    Center(
                                      child: Text(
                                        'No dates set',
                                        style: TextStyle(
                                            color: Color(0xFF9CA3AF),
                                            fontSize: 10),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Inline date editor (when editing) ──
                if (isEditing)
                  Container(
                    margin: const EdgeInsets.fromLTRB(176, 0, 16, 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFFFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: LightModeColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_calendar,
                            size: 14, color: LightModeColors.accent),
                        const SizedBox(width: 8),
                        _InlineDateChip(
                          label: 'Start',
                          date: barStart,
                          onTap: () => _pickDate(context, true, i),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward,
                              size: 12, color: Color(0xFF9CA3AF)),
                        ),
                        _InlineDateChip(
                          label: 'End',
                          date: barEnd,
                          onTap: () => _pickDate(context, false, i),
                        ),
                        const Spacer(),
                        // Duration display
                        if (barStart != null && barEnd != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '${barEnd.difference(barStart).inDays} days',
                              style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        // Save button
                        SizedBox(
                          height: 28,
                          child: FilledButton(
                            onPressed: () => _saveActivityDates(i),
                            style: FilledButton.styleFrom(
                              backgroundColor: LightModeColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 0),
                            ),
                            child: const Text('Save',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Cancel button
                        TextButton(
                          onPressed: () => setState(() {
                            _editingIndex = null;
                            _editStart = null;
                            _editEnd = null;
                          }),
                          child: const Text('Cancel',
                              style: TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
          // ── Today legend ──
          Padding(
            padding: const EdgeInsets.fromLTRB(160, 6, 16, 10),
            child: Row(
              children: [
                Container(
                    width: 12,
                    height: 3,
                    color: const Color(0xFFEF4444).withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                const Text('Today',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 9)),
                const Spacer(),
                // Domain legend
                ...ScheduleDomain.values.map((d) => Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: Color(d.color),
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 3),
                          Text(d.label,
                              style: const TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 9)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// KAZ AI button that auto-suggests start/end dates for activities without dates.
class _TimelineKazAiButton extends StatefulWidget {
  final List<ScheduleActivity> activities;
  final ScheduleProvider provider;

  const _TimelineKazAiButton(
      {required this.activities, required this.provider});

  @override
  State<_TimelineKazAiButton> createState() => _TimelineKazAiButtonState();
}

class _TimelineKazAiButtonState extends State<_TimelineKazAiButton> {
  bool _isGenerating = false;

  Future<void> _suggestDates() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      final activitiesWithoutDates = widget.activities
          .where((a) => a.startDate == null || a.endDate == null)
          .toList();
      if (activitiesWithoutDates.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('All activities already have dates set.'),
                duration: Duration(seconds: 2)),
          );
        }
        return;
      }

      final activityNames =
          activitiesWithoutDates.map((a) => '${a.code}: ${a.name}').join(', ');
      final ai = OpenAiServiceSecure();
      final result = await ai.generateCompletion(
        'You are a project scheduling expert. Given these activities: $activityNames. '
        'Suggest realistic start and end dates for each activity. Activities should follow logical sequencing. '
        'The project should start in Q1 2026.\n\n'
        'Return ONLY a pipe-delimited table with columns:\n'
        'Code|StartDate(MM/dd/yy)|EndDate(MM/dd/yy)\n'
        'One row per activity, no headers, no markdown.',
        maxTokens: 400,
        temperature: 0.6,
      );

      if (!mounted) return;
      final lines = result
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.contains('|'))
          .toList();

      int applied = 0;
      for (final line in lines) {
        final parts = line.split('|').map((p) => p.trim()).toList();
        if (parts.length < 3) continue;
        final code = parts[0];
        final start = _tryParseDate(parts[1]);
        final end = _tryParseDate(parts[2]);
        if (start == null || end == null) continue;
        final matchIdx =
            activitiesWithoutDates.indexWhere((a) => a.code == code);
        if (matchIdx < 0) continue;
        final activity = activitiesWithoutDates[matchIdx];
        widget.provider.updateActivity(
            activity.id,
            activity.copyWith(
              startDate: start,
              endDate: end,
            ));
        applied++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(applied > 0
                ? 'KAZ AI set dates for $applied activities'
                : 'Could not parse AI suggestions. Try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: LightModeColors.accent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('KAZ AI failed: $e'),
              duration: const Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  DateTime? _tryParseDate(String text) {
    try {
      return DateFormat('MM/dd/yy').parse(text.trim());
    } catch (_) {
      try {
        return DateFormat('MM/dd/yyyy').parse(text.trim());
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color:
            _isGenerating ? const Color(0xFFFEF3C7) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              _isGenerating ? const Color(0xFFF59E0B) : const Color(0xFFFDE68A),
        ),
      ),
      child: InkWell(
        onTap: _isGenerating ? null : _suggestDates,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _isGenerating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFF59E0B)))
                  : const Icon(Icons.auto_awesome,
                      size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Text(
                _isGenerating ? 'Suggesting...' : 'KAZ AI Dates',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline date chip used in the timeline editor row.
class _InlineDateChip extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _InlineDateChip(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Text(
              date != null ? DateFormat('MMM d, y').format(date!) : 'Pick date',
              style: TextStyle(
                color: date != null
                    ? const Color(0xFF1A1D1F)
                    : const Color(0xFFF59E0B),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.calendar_today,
                size: 12,
                color: date != null
                    ? LightModeColors.accent
                    : const Color(0xFFF59E0B)),
          ],
        ),
      ),
    );
  }
}

/// "Drawing from" context banner shown at the top of the Schedule Builder.
///
/// Surfaces a one-line summary of the upstream Planning Phase data this page
/// is consuming — the WBS (with deliverable + sub-deliverable counts) and
/// the Cost Estimate total. Uses a soft accent-tinted surface so it sits
/// naturally between the level-convention card and the activity tree.
class _DateField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;

  const _DateField({
    required this.label,
    required this.controller,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'MM/DD/YY',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            prefixIcon: Icon(icon, size: 16, color: LightModeColors.accent),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: LightModeColors.accent, width: 1.6),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
            ),
          ),
          style: const TextStyle(color: Color(0xFF1A1D1F), fontSize: 13),
        ),
      ],
    );
  }
}

class _DrawingFromBanner extends StatelessWidget {
  final WBS? wbs;
  final ({
    int level0,
    int level1,
    int level2,
    int level3,
    int level4,
    int level5,
    int level6,
    int level7,
    int level8
  })? wbsCounts;
  final double costTotal;
  final String currency;
  final bool hasEstimate;

  const _DrawingFromBanner({
    required this.wbs,
    required this.wbsCounts,
    required this.costTotal,
    required this.currency,
    required this.hasEstimate,
  });

  @override
  Widget build(BuildContext context) {
    final hasWbs = wbs != null && wbsCounts != null;
    final l1Label = wbs?.framework.level1Label ?? 'deliverables';
    final l2Label = wbs?.framework.level2Label ?? 'sub-deliverables';
    final l1Count = wbsCounts?.level1 ?? 0;
    final l2Count = wbsCounts?.level2 ?? 0;

    final parts = <String>[];
    if (hasWbs) {
      parts.add('WBS ($l1Count $l1Label, $l2Count $l2Label)');
    }
    if (hasEstimate) {
      parts.add('Cost Estimate (${formatCurrency(costTotal, currency)})');
    }
    if (parts.isEmpty) {
      // Nothing to draw from yet — show a gentle hint instead.
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LightModeColors.accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: LightModeColors.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline,
                size: 16, color: LightModeColors.accent.withValues(alpha: 0.9)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No WBS or Cost Estimate data found yet. Set up the WBS and Cost Estimate modules first to enrich the schedule context.',
                style: TextStyle(
                    color: const Color(0xFF495057), fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LightModeColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: LightModeColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.input,
              size: 16, color: LightModeColors.accent.withValues(alpha: 0.9)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: Color(0xFF495057),
                    fontSize: 12,
                    height: 1.5,
                    fontFamily: appFontFamily),
                children: [
                  const TextSpan(
                    text: 'Drawing from: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: parts.join(' and ')),
                  const TextSpan(
                    text:
                        ' — activities you add here should map to WBS nodes and consume the cost budget above.',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
