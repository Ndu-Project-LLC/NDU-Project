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
import 'package:ndu_project/widgets/responsive_table_widgets.dart';
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';
import 'package:ndu_project/cost_estimate/widgets/treasury_components.dart';
import 'package:ndu_project/schedule/widgets/integrated_schedule_methodology.dart';

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
    try {
      await _createActivitiesFromPackagesUnsafe(autoMode: autoMode);
    } catch (error, stackTrace) {
      debugPrint('Work package schedule import failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not import work packages. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createActivitiesFromPackagesUnsafe({
    bool autoMode = false,
  }) async {
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

    final schedule = scheduleProvider.schedule;
    if (schedule == null || schedule.activities.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule is still loading. Please try again.'),
          ),
        );
      }
      return;
    }
    final root = schedule.activities.first;
    var newChildren = [...root.children];

    List<String> depPackageIds0(WorkPackage pkg) {
      final deps = <String>{};
      void addIfPresent(String id) {
        if (id.trim().isNotEmpty && packageIdSet.contains(id.trim())) {
          deps.add(id.trim());
        }
      }

      switch (pkg.packageClassification) {
        case IntegratedWorkPackageService.procurementPackage:
          for (final id in pkg.linkedEngineeringPackageIds) {
            addIfPresent(id);
          }
          addIfPresent(pkg.parentPackageId);
        case IntegratedWorkPackageService.constructionCwp:
        case IntegratedWorkPackageService.implementationWorkPackage:
        case IntegratedWorkPackageService.agileIterationPackage:
          for (final id in pkg.linkedEngineeringPackageIds) {
            addIfPresent(id);
          }
          for (final id in pkg.linkedProcurementPackageIds) {
            addIfPresent(id);
          }
          addIfPresent(pkg.parentPackageId);
        case IntegratedWorkPackageService.preCommissioningPackage:
          addIfPresent(pkg.parentPackageId);
          for (final id in pkg.linkedEngineeringPackageIds) {
            addIfPresent(id);
          }
        case IntegratedWorkPackageService.commissioningPackage:
          addIfPresent(pkg.parentPackageId);
          for (final id in pkg.linkedEngineeringPackageIds) {
            addIfPresent(id);
          }
        default:
          break;
      }
      return deps.toList();
    }

    for (final pkg in newPackages) {
      final domain = _domainForPackage(pkg);
      final activityType = _typeForPackage(pkg);
      final activityId = pkgToActId[pkg.id]!;

      final depPackageIds = depPackageIds0(pkg);
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
        final schedule = provider.schedule;
        if (schedule == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(LightModeColors.accent),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading schedule...',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          );
        }
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══════════════════════════════════════════════════════════════
              // SLIM HEADER ROW — compact page title + primary actions.
              // (Yellow hero band removed; Add Activity / Setup Timeline kept)
              // ═══════════════════════════════════════════════════════════════
              Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                decoration: BoxDecoration(
                  color: TreasuryTokens.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TreasuryTokens.hairline),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const Text(
                      'Schedule',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: TreasuryTokens.ink,
                      ),
                    ),
                    TreasuryHeroAction(
                      icon: Icons.add_rounded,
                      label: 'Add Activity',
                      primary: true,
                      onTap: schedule.isLocked
                          ? () {}
                          : () => _showAddDialog(context, provider, root.id, 1),
                    ),
                    if (!schedule.isLocked)
                      TreasuryHeroAction(
                        icon: Icons.date_range_rounded,
                        label: 'Setup Timeline',
                        primary: false,
                        onTap: () =>
                            _showTimelineSetupDialog(context, provider, root),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // —— Secondary action row (overflow actions) ——
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: TreasuryTokens.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TreasuryTokens.hairline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TreasuryActionPill(
                      icon: Icons.upload_outlined,
                      label: 'Import by Methodology',
                      enabled: !schedule.isLocked,
                      onTap: () => _showImportInfo(context),
                    ),
                    _TreasuryActionPill(
                      icon: Icons.work_outline,
                      label: 'From Work Packages',
                      enabled: !schedule.isLocked,
                      onTap: () => _createActivitiesFromPackages(),
                    ),
                    if (schedule.basis.deliveryModel == 'AGILE' ||
                        schedule.basis.deliveryModel == 'HYBRID')
                      _TreasuryActionPill(
                        icon: Icons.auto_stories_outlined,
                        label: 'Import Agile Stories',
                        enabled: !schedule.isLocked,
                        onTap: () => _importStories(),
                      ),
                    _TreasuryActionPill(
                      icon: Icons.calculate_outlined,
                      label: 'Run CPM',
                      enabled: !schedule.isLocked,
                      onTap: () => _runCpm(),
                    ),
                    _TreasuryActionPill(
                      icon: Icons.download_outlined,
                      label: 'Export',
                      enabled: true,
                      onTap: () => _exportSchedule(context, schedule),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // ═══════════════════════════════════════════════════════════════
              // TREASURY KPI STRIP — at-a-glance schedule vitals
              // ═══════════════════════════════════════════════════════════════
              TreasuryKpiStrip(
                kpis: _buildScheduleKpis(
                    root, schedule, costTotal, currency, estimate),
              ),
              const SizedBox(height: 20),
              // ═══════════════════════════════════════════════════════════════
              // ESTIMATE BASIS — assumptions / methods / data sources
              // ═══════════════════════════════════════════════════════════════
              const EstimateBasisCard(),
              const SizedBox(height: 18),
              // ═══════════════════════════════════════════════════════════════
              // SCHEDULE READINESS RULES — pre-CWP gate checklist
              // ═══════════════════════════════════════════════════════════════
              const ScheduleReadinessRules(),
              const SizedBox(height: 18),
              // ═══════════════════════════════════════════════════════════════
              // SCHEDULE LEVELS CONVENTION CARD
              // ═══════════════════════════════════════════════════════════════
              TreasurySectionCard(
                title: 'Schedule Level Convention',
                subtitle: 'How activity levels map to your delivery model',
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: TreasuryTokens.brandSoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: TreasuryTokens.brand.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.layers_outlined,
                          size: 12, color: TreasuryTokens.brandDeep),
                      SizedBox(width: 5),
                      Text('L0 — L8',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: TreasuryTokens.brandDeep,
                              letterSpacing: 0.6)),
                    ],
                  ),
                ),
                child: const _TreasuryLevelLegend(),
              ),
              const SizedBox(height: 14),
              // ═══════════════════════════════════════════════════════════════
              // DRAWING FROM CONTEXT BANNER
              // ═══════════════════════════════════════════════════════════════
              _DrawingFromBanner(
                wbs: wbs,
                wbsCounts: wbsCounts,
                costTotal: costTotal,
                currency: currency,
                hasEstimate: estimate != null,
              ),
              const SizedBox(height: 22),
              // ═══════════════════════════════════════════════════════════════
              // PROJECT TIMELINE (Gantt)
              // ═══════════════════════════════════════════════════════════════
              _TimelineVisualization(
                activities: [root, ...root.children],
                provider: provider,
                isLocked: schedule.isLocked,
              ),
              const SizedBox(height: 22),
              // ═══════════════════════════════════════════════════════════════
              // ACTIVITY TREE (full width)
              // ═══════════════════════════════════════════════════════════════
              // ACTIVITY TREE (full width, scrollable on narrow screens)
              // ═══════════════════════════════════════════════════════════════
              SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  // IntrinsicWidth gives the subtree a BOUNDED width
                  // (max of minWidth and intrinsic content width). Without it
                  // the horizontal scroll view passes unbounded width down
                  // and the Expanded inside _ActivityNode's Row throws
                  // "RenderFlex children have non-zero flex but incoming
                  // width constraints are unbounded", which poisons the whole
                  // layout pass and renders the tab content BLANK.
                  child: IntrinsicWidth(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width - 40,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: TreasuryTokens.brandSoft,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                      color: TreasuryTokens.brand.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(Icons.account_tree_rounded,
                                    size: 16, color: TreasuryTokens.brandDeep),
                              ),
                              const SizedBox(width: 10),
                              const Text('Activity Tree',
                                  style: TextStyle(
                                      color: TreasuryTokens.ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.1)),
                              const SizedBox(width: 8),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: TreasuryTokens.surfaceAlt,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: TreasuryTokens.hairline),
                                ),
                                child: Text(
                                    '${root.children.length} L1 · ${_countTotalActivities(root)} total',
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: TreasuryTokens.muted,
                                        letterSpacing: 0.3)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _ActivityNode(
                              activity: root,
                              isRoot: true,
                              provider: provider,
                              isLocked: schedule.isLocked),
                          ...root.children.map((child) => _ActivityNode(
                              activity: child,
                              provider: provider,
                              isLocked: schedule.isLocked)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Sample activity table (preview of what Gantt/List will show).
              // Give the panel the actual bounded content width. The table
              // owns its horizontal scroll view, so wide columns remain
              // accessible without shrinking the panel or leaving a blank
              // strip at the right edge of the page.
              LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    child: _ActivityScheduleTable(
                      schedule: schedule,
                      rootActivity: root,
                      onImportFromWorkPackages: () =>
                          _createActivitiesFromPackages(autoMode: true),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              // Footer note — Treasury info card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TreasuryTokens.infoSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: TreasuryTokens.info.withValues(alpha: 0.22)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: TreasuryTokens.info.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.tips_and_updates_outlined,
                          size: 15, color: TreasuryTokens.info),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'The Activity Schedule above is populated from your WBS '
                        'and Work Packages. Use the action pills at the top of '
                        'the page to import more activities, or tap "Add '
                        'activity" below the table. Each row maps to an EWP, '
                        'CWP, or activity in your delivery model.',
                        style: TextStyle(
                            color: TreasuryTokens.inkSoft,
                            fontSize: 12,
                            height: 1.55,
                            fontWeight: FontWeight.w500),
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

  /// Build the 4-KPI strip for the schedule builder.
  List<TreasuryKpiSpec> _buildScheduleKpis(
    ScheduleActivity root,
    Schedule schedule,
    double costTotal,
    String currency,
    CostEstimate? estimate,
  ) {
    final totalActivities = _countTotalActivities(root);
    final l1Count = root.children.length;
    final hasTimeline = root.startDate != null && root.endDate != null;
    final timelineSpan =
        hasTimeline ? root.endDate!.difference(root.startDate!).inDays : 0;
    // Domain breakdown
    final domainCounts = <int, int>{};
    void walk(ScheduleActivity a) {
      domainCounts[a.domain.color] = (domainCounts[a.domain.color] ?? 0) + 1;
      for (final c in a.children) {
        walk(c);
      }
    }

    walk(root);
    final topDomainColor = domainCounts.entries.isNotEmpty
        ? domainCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key
        : ScheduleDomain.engineering.color;
    return [
      TreasuryKpiSpec(
        label: 'Total Activities',
        value: treasuryFmt(totalActivities.toDouble()),
        sub: '$l1Count Level 1 · ${totalActivities - l1Count} nested',
        icon: Icons.account_tree_rounded,
        tint: TreasuryTokens.brandDeep,
        tintSoft: TreasuryTokens.brandSoft,
      ),
      TreasuryKpiSpec(
        label: 'Timeline Span',
        value: hasTimeline ? '$timelineSpan d' : '—',
        sub: hasTimeline
            ? '${DateFormat('MMM d').format(root.startDate!)} → ${DateFormat('MMM d').format(root.endDate!)}'
            : 'Setup timeline to begin',
        icon: Icons.calendar_month_rounded,
        tint: const Color(0xFFB8860B),
        tintSoft: TreasuryTokens.infoSoft,
      ),
      TreasuryKpiSpec(
        label: 'Cost Budget',
        value: estimate != null ? formatCurrency(costTotal, currency) : '—',
        sub: estimate != null ? 'From Cost Estimate' : 'No estimate linked',
        icon: Icons.attach_money_rounded,
        tint: TreasuryTokens.success,
        tintSoft: TreasuryTokens.successSoft,
      ),
      TreasuryKpiSpec(
        label: 'Top Domain',
        value: _domainLabelFromColor(topDomainColor),
        sub: '${domainCounts.length} domains active',
        icon: Icons.hub_outlined,
        tint: const Color(0xFFD97706),
        tintSoft: const Color(0xFFFFF8E1),
      ),
    ];
  }

  /// Count total activities in the tree (root + all descendants).
  int _countTotalActivities(ScheduleActivity root) {
    int count = 1;
    for (final c in root.children) {
      count += _countTotalActivities(c);
    }
    return count;
  }

  /// Map a domain color back to a short label for the KPI tile.
  String _domainLabelFromColor(int color) {
    for (final d in ScheduleDomain.values) {
      if (d.color == color) {
        return d.name[0].toUpperCase() + d.name.substring(1);
      }
    }
    return 'Mixed';
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
      const SnackBar(
        content: Text('Schedule JSON copied to clipboard'),
        duration: Duration(seconds: 2),
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
  }) : primary = false, enabled = true;

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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        side: BorderSide(
            color:
                disabled ? const Color(0xFFE4E7EC) : const Color(0xFFE4E7EC)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Treasury-styled secondary action pill — used for the overflow action row
/// (Import by Methodology, From Work Packages, Run CPM, Export, etc.).
class _TreasuryActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _TreasuryActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = !enabled;
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  disabled ? TreasuryTokens.surfaceAlt : TreasuryTokens.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: disabled
                    ? TreasuryTokens.hairlineSoft
                    : TreasuryTokens.hairline,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 14,
                    color: disabled
                        ? TreasuryTokens.mutedSoft
                        : TreasuryTokens.inkSoft),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: disabled
                        ? TreasuryTokens.mutedSoft
                        : TreasuryTokens.ink,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Treasury-styled schedule level legend — L0 through L8 with color dots.
class _TreasuryLevelLegend extends StatelessWidget {
  const _TreasuryLevelLegend();

  static const _levels = [
    ('L0', 'Project', Icons.flag_outlined),
    ('L1', 'Major Deliverable', Icons.view_module_outlined),
    ('L2', 'Epic / Sub-Deliverable', Icons.category_outlined),
    ('L3', 'EWP / Procurement / CWP', Icons.inventory_2_outlined),
    ('L4', 'Activity / Story', Icons.checklist_outlined),
    ('L5—8', 'Task', Icons.task_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Schedule levels: L0=Project · L1=Major Deliverable · L2=Epic/Sub-Deliverable · L3=EWP/Procurement/CWP · L4=Activity/Story · L5–8=Task. Waterfall/Hybrid schedules should be built from integrated work packages; Agile schedules should be built from story-level AgileTask items.',
          style: TextStyle(
            color: TreasuryTokens.inkSoft,
            fontSize: 12,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: _levels.map((lvl) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: TreasuryTokens.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TreasuryTokens.hairline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(lvl.$3, size: 13, color: TreasuryTokens.brandDeep),
                  const SizedBox(width: 6),
                  Text(lvl.$1,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: TreasuryTokens.ink,
                          fontFamily: appFontFamily,
                          letterSpacing: 0.3)),
                  const SizedBox(width: 6),
                  Text(lvl.$2,
                      style: const TextStyle(
                          fontSize: 11,
                          color: TreasuryTokens.muted,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
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
    if (activity.importSource != null &&
        activity.importSource == 'fep_milestone') {
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
        color: TreasuryTokens.surfaceAlt,
        border: Border.all(color: TreasuryTokens.hairline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: TreasuryTokens.muted),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5,
                  color: TreasuryTokens.inkSoft,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final domainColor = Color(activity.domain.color);
    return GestureDetector(
      onTap: () => _showActivityEditDialog(context),
      child: Container(
        margin: EdgeInsets.only(bottom: 8, left: isRoot ? 0 : 24),
        decoration: BoxDecoration(
          color: TreasuryTokens.surface,
          borderRadius: BorderRadius.circular(12),
          // Uniform border only: a per-side colored Border + borderRadius
          // throws "A borderRadius can only be given on borders with uniform
          // colors" during paint. The domain accent is drawn as an inner 3px
          // stripe below instead, clipped to the rounded corners.
          border: Border.all(color: TreasuryTokens.hairline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: domainColor.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          // IntrinsicHeight gives the Row a bounded height even when this node
          // sits inside the vertically-unbounded Builder scroll view — required
          // because CrossAxisAlignment.stretch (below) needs a bounded cross
          // extent, and it makes the 3px accent stripe span the full row.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Domain accent stripe (replaces the old non-uniform left border)
            Container(width: 3, color: domainColor),
            // Original padded content
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
            // Domain icon tile
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: domainColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: domainColor.withValues(alpha: 0.28)),
              ),
              child: Icon(
                  isRoot
                      ? Icons.flag_rounded
                      : (activity.type == ActivityType.summary
                          ? Icons.folder_outlined
                          : Icons.task_alt_rounded),
                  size: 15,
                  color: domainColor),
            ),
            const SizedBox(width: 10),
            // Code chip
            if (activity.code.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: TreasuryTokens.surfaceAlt,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: TreasuryTokens.hairline),
                ),
                child: Text(activity.code,
                    style: const TextStyle(
                        color: TreasuryTokens.inkSoft,
                        fontSize: 10.5,
                        fontFamily: appFontFamily,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3)),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: domainColor, shape: BoxShape.circle),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(activity.name,
                  style: const TextStyle(
                      color: TreasuryTokens.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
            ),
            if (formatDuration(activity.duration, activity.durationUnit) != '—')
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: TreasuryTokens.infoSoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: TreasuryTokens.info.withValues(alpha: 0.22)),
                  ),
                  child: Text(
                      formatDuration(activity.duration, activity.durationUnit),
                      style: const TextStyle(
                          color: TreasuryTokens.info,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ),
              ),
            // Dependency type chips
            if (activity.dependencies.isNotEmpty)
              ...activity.dependencies.map((dep) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: TreasuryTokens.successSoft,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color:
                                TreasuryTokens.success.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        dep.type.short,
                        style: const TextStyle(
                            color: Color(0xFF047857),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3),
                      ),
                    ),
                  )),
            // Inline start/end date chips
            if (activity.startDate != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: TreasuryTokens.successSoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: TreasuryTokens.success.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Start: ${activity.startDate!.month}/${activity.startDate!.day}/${activity.startDate!.year.toString().substring(2)}',
                    style: const TextStyle(
                        color: Color(0xFF047857),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
              ),
            if (activity.endDate != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: TreasuryTokens.warningSoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: TreasuryTokens.warning.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'End: ${activity.endDate!.month}/${activity.endDate!.day}/${activity.endDate!.year.toString().substring(2)}',
                    style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
              ),
            if (_traceabilityChips().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 260,
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
                  style: const TextStyle(
                      fontSize: 11,
                      color: TreasuryTokens.muted,
                      fontWeight: FontWeight.w500),
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
            ),
            ],
          ),
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
                            initialValue: dep.type,
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
/// Activity Schedule table — renders the SAME WBS-derived activities that the
/// Activity Tree above renders, but in a columnar view (ID, Name, Duration,
/// Start, Finish, Predecessors, Resources). Each row also shows its WBS Code
/// and Level chips when linked to a WBS node.
///
/// Includes an "Add activity" popup dialog (which calls the real
/// ScheduleProvider.addActivity when a schedule is bound, falling back to a
/// draft row otherwise) and KAZ AI generation for new activities.
///
/// When the schedule has no real activities yet (root has no children), a
/// prominent empty-state card with a CTA replaces the table to guide the user
/// toward importing from WBS / Work Packages.
class _ActivityScheduleTable extends StatefulWidget {
  final Schedule schedule;
  final ScheduleActivity rootActivity;
  final VoidCallback? onImportFromWorkPackages;

  const _ActivityScheduleTable({
    required this.schedule,
    required this.rootActivity,
    this.onImportFromWorkPackages,
  });

  @override
  State<_ActivityScheduleTable> createState() => _ActivityScheduleTableState();
}

class _ActivityScheduleTableState extends State<_ActivityScheduleTable> {
  /// User-added or AI-generated draft rows (NOT persisted to the schedule).
  /// They render below the real WBS-derived activities and can be removed
  /// inline. Real activities (from `rootActivity`) cannot be removed here —
  /// they're managed via the Activity Tree or Work Packages module.
  late List<_ActivityRow> _draftRows;
  bool _isGenerating = false;
  int _nextId = 1;

  @override
  void initState() {
    super.initState();
    _draftRows = [];
    _nextId = _computeNextId();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Compute the next draft-row ID by looking at existing activity codes &
  /// draft-row IDs, so newly added rows don't collide with WBS-derived ones.
  int _computeNextId() {
    int max = 0;
    for (final r in _flattenActivities()) {
      final n = int.tryParse(r.id) ?? 0;
      if (n > max) max = n;
    }
    for (final r in _draftRows) {
      final n = int.tryParse(r.id) ?? 0;
      if (n > max) max = n;
    }
    return max + 1;
  }

  String _formatDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';

  /// Walk the activity tree depth-first and produce a flat list of rows.
  /// Excludes the root (Level 0) — only real child activities are shown.
  List<_ActivityRow> _flattenActivities() {
    final rows = <_ActivityRow>[];
    void walk(ScheduleActivity node) {
      for (final c in node.children) {
        rows.add(_ActivityRow.fromActivity(c));
        walk(c);
      }
    }
    walk(widget.rootActivity);
    return rows;
  }



  Future<void> _showAddSampleDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: _formatDate(DateTime.now()));
    final finishCtrl = TextEditingController(
        text: _formatDate(DateTime.now().add(const Duration(days: 30))));
    final predsCtrl = TextEditingController();
    final resourcesCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE4E7EC))),
        title: const Text('Add activity',
            style: TextStyle(
                color: Color(0xFF1A1D1F), fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: durationCtrl,
                decoration: const InputDecoration(labelText: 'Duration (e.g. 10 d)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(labelText: 'Start (MM/DD/YY)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: finishCtrl,
                decoration: const InputDecoration(labelText: 'Finish (MM/DD/YY)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: predsCtrl,
                decoration: const InputDecoration(labelText: 'Predecessors (e.g. 6FS)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: resourcesCtrl,
                decoration: const InputDecoration(labelText: 'Resources (e.g. Crew (4))'),
              ),
            ],
          ),
        ),
          actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final scheduleProvider = context.read<ScheduleProvider>();
                final sch = scheduleProvider.schedule;
                if (sch != null && sch.activities.isNotEmpty) {
                  final parentId = sch.activities[0].id;
                  scheduleProvider.addActivity(
                    parentId,
                    ScheduleActivity(
                      id: '',
                      level: 0,
                      code: '',
                      name: nameCtrl.text.trim(),
                      type: ActivityType.activity,
                      domain: ScheduleDomain.execution,
                      dependencies: [],
                      aiGenerated: false,
                      children: [],
                    ),
                  );
                } else {
                  // Fallback to local draft rows when no real schedule is set up
                  setState(() {
                    _draftRows.add(_ActivityRow.draft(
                      id: (_nextId++).toString(),
                      name: nameCtrl.text.trim(),
                      duration: durationCtrl.text.trim().isNotEmpty ? durationCtrl.text.trim() : '—',
                      start: startCtrl.text.trim().isNotEmpty ? startCtrl.text.trim() : '—',
                      finish: finishCtrl.text.trim().isNotEmpty ? finishCtrl.text.trim() : '—',
                      predecessors: predsCtrl.text.trim().isNotEmpty ? predsCtrl.text.trim() : '—',
                      resources: resourcesCtrl.text.trim().isNotEmpty ? resourcesCtrl.text.trim() : '—',
                      domainColor: ScheduleDomain.execution.color,
                    ));
                  });
                }
              } catch (e) {
                // If provider isn't available, fall back to draft rows
                setState(() {
                  _draftRows.add(_ActivityRow.draft(
                    id: (_nextId++).toString(),
                    name: nameCtrl.text.trim(),
                    duration: durationCtrl.text.trim().isNotEmpty ? durationCtrl.text.trim() : '—',
                    start: startCtrl.text.trim().isNotEmpty ? startCtrl.text.trim() : '—',
                    finish: finishCtrl.text.trim().isNotEmpty ? finishCtrl.text.trim() : '—',
                    predecessors: predsCtrl.text.trim().isNotEmpty ? predsCtrl.text.trim() : '—',
                    resources: resourcesCtrl.text.trim().isNotEmpty ? resourcesCtrl.text.trim() : '—',
                    domainColor: ScheduleDomain.execution.color,
                  ));
                });
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    // dispose controllers
    nameCtrl.dispose();
    durationCtrl.dispose();
    startCtrl.dispose();
    finishCtrl.dispose();
    predsCtrl.dispose();
    resourcesCtrl.dispose();
  }

  void _removeDraftRow(int index) {
    if (index < 0 || index >= _draftRows.length) return;
    setState(() => _draftRows.removeAt(index));
  }

  Future<void> _generateWithKazAi() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      final projectName = widget.schedule.projectName;
      final deliveryModel = widget.schedule.basis.deliveryModel;
      final realRows = _flattenActivities();
      final existingCount = realRows.length + _draftRows.length;

      final ai = OpenAiServiceSecure();
      final result = await ai.generateCompletion(
        'You are a project schedule expert. Generate 3-5 additional schedule '
        'activities for a project called "$projectName" using the '
        '$deliveryModel delivery model. There are already $existingCount '
        'activities covering engineering, procurement, execution, '
        'construction, and commissioning. Suggest realistic follow-on or '
        'parallel activities with typical durations and resource assignments.\n\n'
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
          _draftRows.add(_ActivityRow.draft(
            id: (_nextId++).toString(),
            name: name,
            duration: duration,
            start: start,
            finish: finish,
            predecessors: predecessors,
            resources: resources,
            domainColor: domainColor,
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
    final realRows = _flattenActivities();
    final allRows = [...realRows, ..._draftRows];
    final hasAny = allRows.isNotEmpty;
    final wbsLinkedCount = realRows.where((r) => r.wbsLinked).length;

    return Container(
      // NOTE: no width: double.infinity here — this widget sits inside a
      // horizontal SingleChildScrollView where max width is unbounded; an
      // infinite width request throws "BoxConstraints forces an infinite
      // width". The IntrinsicWidth wrapper in the parent section provides a
      // bounded width (>= screen width - 40) instead.
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
                const Text('Activity Schedule',
                    style: TextStyle(
                        color: Color(0xFF1A1D1F),
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                if (wbsLinkedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: TreasuryTokens.infoSoft,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color:
                              TreasuryTokens.info.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_tree_outlined,
                            size: 10, color: TreasuryTokens.info),
                        const SizedBox(width: 3),
                        Text('$wbsLinkedCount WBS linked',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: TreasuryTokens.info)),
                      ],
                    ),
                  ),
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
                  child: Text('${allRows.length} activities',
                      style: const TextStyle(
                          color: Color(0xFF495057),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE4E7EC), height: 1),
          // Empty state when no activities exist
          if (!hasAny) _buildEmptyState(),
          // Data table when there are activities (real or draft)
          if (hasAny)
            FullScreenTableWrapper(
              title: 'Schedule Builder Activities',
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: buildNduDataTable(
                  context: context,
                  zebra: false,
                  headingRowColor: const Color(0xFFF9FAFB),
                  headingRowHeight: 48,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 52,
                  columnSpacing: 24,
                  horizontalMargin: 16,
                  autoWrapCells: false,
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
                    // Data rows — real WBS-derived activities + user draft rows
                    ...allRows.asMap().entries.map((entry) {
                      final i = entry.key;
                      final r = entry.value;
                      final isDraft = i >= realRows.length;
                      final draftIdx = i - realRows.length;
                      return DataRow(
                        color: WidgetStateProperty.all(
                          isDraft ? const Color(0xFFFFFBEB) : null,
                        ),
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
                              if (r.level > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Color(r.domainColor)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: Color(r.domainColor)
                                            .withValues(alpha: 0.35))),
                                  child: Text('L${r.level}',
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(r.domainColor),
                                          letterSpacing: 0.3)),
                                ),
                              if (r.wbsLinked && r.wbsCode.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: TreasuryTokens.infoSoft,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: TreasuryTokens.info
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.account_tree_outlined,
                                          size: 9, color: TreasuryTokens.info),
                                      const SizedBox(width: 3),
                                      Text(r.wbsCode,
                                          style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: TreasuryTokens.info,
                                              fontFamily: appFontFamily,
                                              letterSpacing: 0.2)),
                                    ],
                                  ),
                                )
                              else if (isDraft)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7E0),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: const Color(0xFFFDE68A)),
                                  ),
                                  child: const Text('DRAFT',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF92400E),
                                          letterSpacing: 0.4)),
                                ),
                              Flexible(
                                child: Text(r.name,
                                    style: const TextStyle(
                                        color: Color(0xFF1A1D1F),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis),
                              ),
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
                            isDraft
                                ? IconButton(
                                    icon: const Icon(Icons.remove_circle_outline,
                                        size: 16, color: Color(0xFFEF4444)),
                                    onPressed: () => _removeDraftRow(draftIdx),
                                    tooltip: 'Remove draft row',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 28, minHeight: 28),
                                  )
                                : const Icon(Icons.lock_outline,
                                    size: 14, color: Color(0xFFCBD5E1)),
                          ),
                        ],
                      );
                    }),
                    // Replace inline add row with a single button that opens the
                    // Add Activity modal so items are added via a popup.
                    DataRow(cells: [
                      DataCell(Container()),
                      DataCell(FilledButton.icon(
                        onPressed: () => _showAddSampleDialog(context),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add activity'),
                        style: FilledButton.styleFrom(
                          backgroundColor: LightModeColors.accent.withValues(alpha: 0.06),
                          foregroundColor: LightModeColors.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      )),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                    ]),
                  ],
                ),
              ),
              tableBuilder: (fsContext) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: buildNduDataTable(
                  context: fsContext,
                  zebra: false,
                  headingRowColor: const Color(0xFFF9FAFB),
                  headingRowHeight: 48,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 52,
                  columnSpacing: 24,
                  horizontalMargin: 16,
                  autoWrapCells: false,
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
                    // Data rows — real WBS-derived activities + user draft rows
                    ...allRows.asMap().entries.map((entry) {
                      final i = entry.key;
                      final r = entry.value;
                      final isDraft = i >= realRows.length;
                      final draftIdx = i - realRows.length;
                      return DataRow(
                        color: WidgetStateProperty.all(
                          isDraft ? const Color(0xFFFFFBEB) : null,
                        ),
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
                              if (r.level > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Color(r.domainColor)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: Color(r.domainColor)
                                            .withValues(alpha: 0.35))),
                                  child: Text('L${r.level}',
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(r.domainColor),
                                          letterSpacing: 0.3)),
                                ),
                              if (r.wbsLinked && r.wbsCode.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: TreasuryTokens.infoSoft,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: TreasuryTokens.info
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.account_tree_outlined,
                                          size: 9, color: TreasuryTokens.info),
                                      const SizedBox(width: 3),
                                      Text(r.wbsCode,
                                          style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: TreasuryTokens.info,
                                              fontFamily: appFontFamily,
                                              letterSpacing: 0.2)),
                                    ],
                                  ),
                                )
                              else if (isDraft)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7E0),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: const Color(0xFFFDE68A)),
                                  ),
                                  child: const Text('DRAFT',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF92400E),
                                          letterSpacing: 0.4)),
                                ),
                              Flexible(
                                child: Text(r.name,
                                    style: const TextStyle(
                                        color: Color(0xFF1A1D1F),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis),
                              ),
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
                            isDraft
                                ? IconButton(
                                    icon: const Icon(Icons.remove_circle_outline,
                                        size: 16, color: Color(0xFFEF4444)),
                                    onPressed: () => _removeDraftRow(draftIdx),
                                    tooltip: 'Remove draft row',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 28, minHeight: 28),
                                  )
                                : const Icon(Icons.lock_outline,
                                    size: 14, color: Color(0xFFCBD5E1)),
                          ),
                        ],
                      );
                    }),
                    DataRow(cells: [
                      DataCell(Container()),
                      DataCell(FilledButton.icon(
                        onPressed: () => _showAddSampleDialog(context),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add activity'),
                        style: FilledButton.styleFrom(
                          backgroundColor: LightModeColors.accent.withValues(alpha: 0.06),
                          foregroundColor: LightModeColors.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      )),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                    ]),
                  ],
                ),
              ),
            ),
          // Footnote — adapts to whether there are real activities or just drafts
          if (allRows.length <= 7)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined,
                      size: 12, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      realRows.isEmpty
                          ? 'No WBS-derived activities yet. Use the action pills '
                              'at the top of the page to import from Work '
                              'Packages, or tap "Add activity" below to add a '
                              'custom row. KAZ AI can also auto-generate.'
                          : 'Locked rows (lock icon) are WBS-derived activities — '
                              'manage them via the Activity Tree or Work Packages '
                              'module. Draft rows can be removed inline. Use '
                              'KAZ AI to auto-generate more.',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// World-class empty state — shown when no real or draft activities exist.
  /// Replaces the table with a prominent, helpful CTA card.
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: TreasuryTokens.brandSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: TreasuryTokens.brand.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.account_tree_outlined,
                size: 30, color: TreasuryTokens.brandDeep),
          ),
          const SizedBox(height: 14),
          const Text('No activities yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: TreasuryTokens.ink)),
          const SizedBox(height: 6),
          const Text(
            'Your Activity Schedule is empty. Populate it from your WBS and '
            'Work Packages, or add a custom activity below.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.5,
                color: TreasuryTokens.muted,
                height: 1.55,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 18),
          if (widget.onImportFromWorkPackages != null)
            FilledButton.icon(
              onPressed: widget.onImportFromWorkPackages,
              icon: const Icon(Icons.work_outline, size: 16),
              label: const Text('Import from Work Packages'),
              style: FilledButton.styleFrom(
                backgroundColor: TreasuryTokens.brand,
                foregroundColor: TreasuryTokens.ink,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _isGenerating ? null : _generateWithKazAi,
            icon: const Icon(Icons.auto_awesome, size: 14),
            label: const Text('Generate with KAZ AI'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF92400E),
              textStyle: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single activity row in the Activity Schedule table. Holds either a
/// real WBS-derived [ScheduleActivity] (when constructed via [fromActivity])
/// or a draft row added by the user / KAZ AI (when constructed via [draft]).
class _ActivityRow {
  final String id;
  final String name;
  final String duration;
  final String start;
  final String finish;
  final String predecessors;
  final String resources;
  final int domainColor;
  final int level;
  final String wbsCode;
  final bool wbsLinked;

  const _ActivityRow._({
    required this.id,
    required this.name,
    required this.duration,
    required this.start,
    required this.finish,
    required this.predecessors,
    required this.resources,
    required this.domainColor,
    required this.level,
    required this.wbsCode,
    required this.wbsLinked,
  });

  /// Build a row from a real [ScheduleActivity] derived from the WBS tree.
  factory _ActivityRow.fromActivity(ScheduleActivity a) {
    final depLabel = a.dependencies.isEmpty
        ? '—'
        : a.dependencies
            .map((d) => '${d.activityId}${d.type.short}')
            .join(', ');
    return _ActivityRow._(
      id: a.code.isNotEmpty ? a.code : a.id,
      name: a.name,
      duration: formatDuration(a.duration, a.durationUnit),
      start: formatDate(a.startDate),
      finish: formatDate(a.endDate),
      predecessors: depLabel,
      resources: a.owner?.isNotEmpty == true ? a.owner! : '—',
      domainColor: a.domain.color,
      level: a.level,
      wbsCode: a.wbsCode ?? '',
      wbsLinked: a.wbsNodeId != null && a.wbsNodeId!.isNotEmpty,
    );
  }

  /// Build a draft row from user input / KAZ AI output.
  const factory _ActivityRow.draft({
    required String id,
    required String name,
    required String duration,
    required String start,
    required String finish,
    required String predecessors,
    required String resources,
    required int domainColor,
  }) = _DraftActivityRow;
}

/// Concrete draft-row subclass (kept separate so the const factory above
/// can produce a const instance — required because [String] fields aren't
/// const-constructable via the private all-required constructor alone).
class _DraftActivityRow extends _ActivityRow {
  const _DraftActivityRow({
    required super.id,
    required super.name,
    required super.duration,
    required super.start,
    required super.finish,
    required super.predecessors,
    required super.resources,
    required super.domainColor,
  }) : super._(
          level: 0,
          wbsCode: '',
          wbsLinked: false,
        );
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
            colorScheme: const ColorScheme.light(
              primary: LightModeColors.accent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1A1D1F),
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
        color: TreasuryTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TreasuryTokens.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: TreasuryTokens.brand.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Treasury Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: TreasuryTokens.brandSoft,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: TreasuryTokens.brand.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.timeline_rounded,
                      size: 17, color: TreasuryTokens.brandDeep),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Project Timeline',
                        style: TextStyle(
                            color: TreasuryTokens.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.1)),
                    const SizedBox(height: 2),
                    Text('$totalDays-day span · ${months.length} month markers',
                        style: const TextStyle(
                            color: TreasuryTokens.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
                const Spacer(),
                if (!widget.isLocked)
                  _TimelineKazAiButton(
                      activities: widget.activities, provider: widget.provider),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: TreasuryTokens.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: TreasuryTokens.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.date_range_rounded,
                          size: 12, color: TreasuryTokens.muted),
                      const SizedBox(width: 5),
                      Text(
                        '${DateFormat('MMM d').format(rangeStart)} — ${DateFormat('MMM d, y').format(rangeEnd)}',
                        style: const TextStyle(
                            color: TreasuryTokens.inkSoft,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: TreasuryTokens.hairline, height: 1),
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
                                    const Center(
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TreasuryTokens.warningSoft,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: TreasuryTokens.warning.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: TreasuryTokens.warning.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.info_outline,
                  size: 16, color: TreasuryTokens.warning),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'No WBS or Cost Estimate data found yet. Set up the WBS and Cost Estimate modules first to enrich the schedule context.',
                style: TextStyle(
                    color: TreasuryTokens.inkSoft,
                    fontSize: 12,
                    height: 1.55,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    // Build context chips for the data sources
    final chips = <Widget>[];
    if (hasWbs) {
      chips.add(_DrawingFromChip(
        icon: Icons.account_tree_outlined,
        label: 'WBS',
        value: '$l1Count $l1Label · $l2Count $l2Label',
        tint: TreasuryTokens.info,
        tintSoft: TreasuryTokens.infoSoft,
      ));
    }
    if (hasEstimate) {
      chips.add(_DrawingFromChip(
        icon: Icons.attach_money_rounded,
        label: 'Cost Estimate',
        value: formatCurrency(costTotal, currency),
        tint: TreasuryTokens.success,
        tintSoft: TreasuryTokens.successSoft,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TreasuryTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TreasuryTokens.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: TreasuryTokens.brandSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: TreasuryTokens.brand.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.input_rounded,
                    size: 15, color: TreasuryTokens.brandDeep),
              ),
              const SizedBox(width: 10),
              const Text('Drawing from',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: TreasuryTokens.muted,
                      letterSpacing: 0.8)),
              const SizedBox(width: 8),
              const Text('—',
                  style:
                      TextStyle(fontSize: 11, color: TreasuryTokens.mutedSoft)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Activities you add here should map to WBS nodes and consume the cost budget above.',
                  style: TextStyle(
                      color: TreasuryTokens.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: chips,
          ),
        ],
      ),
    );
  }
}

/// Treasury-styled context chip used inside the DrawingFromBanner.
class _DrawingFromChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final Color tintSoft;

  const _DrawingFromChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    required this.tintSoft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tintSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tint.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: tint.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: TreasuryTokens.ink,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
