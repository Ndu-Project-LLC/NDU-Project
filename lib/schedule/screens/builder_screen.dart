library;

/// Builder Screen — decompose WBS into a multi-level schedule.
///
/// Activity tree (Level 0→8) with add/edit/delete/reorder. Tapping a row opens
/// its editor, which carries the activity's dates and dependencies — the
/// columnar and timeline views of the same activities live on the List View and
/// Gantt tabs.
///
/// A "Drawing from" context banner is rendered below the KPI strip so the user
/// can see that this page consumes the WBS (deliverables +
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
import 'package:ndu_project/services/integrated_work_package_service.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/epic_feature_service.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';
import 'package:ndu_project/services/roadmap_service.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart'
    hide ScheduleActivity;
import 'package:ndu_project/cost_estimate/widgets/treasury_components.dart';
import 'package:ndu_project/cost_estimate/widgets/add_line_dialog.dart';
import 'package:ndu_project/schedule/utils/schedule_purchase_cost.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';

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
        name: IntegratedWorkPackageService.packageActivityName(pkg),
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
    final startCtrl = SpellCheckTextEditingController(
      text: root.startDate != null
          ? DateFormat('MM/dd/yy').format(root.startDate!)
          : '01/06/26',
    );
    final endCtrl = SpellCheckTextEditingController(
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
                        'This sets the project-wide date range. To date an individual activity, tap its row in the Activity Tree and pick its start and finish.',
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
    final nameCtrl = SpellCheckTextEditingController();
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

  /// Priced/unpriced chip shown on rows whose activity is linked to a cost
  /// line — the visual confirmation that a pull (or manual entry) landed.
  Widget _costStatusChip(CostLine line) {
    final priced = isPricedCostLine(line);
    final color = priced
        ? const Color(0xFF16A34A)
        : const Color(0xFFB45309);
    final soft = priced
        ? const Color(0xFFE7F8F0)
        : const Color(0xFFFFF3E0);
    final label =
        priced ? 'Cost: \$${_fmtCostAmount(line.total)}' : 'Cost: not priced yet';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: soft,
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_money, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  color: color,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  static String _fmtCostAmount(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

  static bool isPricedCostLine(CostLine? line) =>
      line != null &&
      (line.total > 0 ||
          ((line.quantity ?? 0) > 0 && (line.rate ?? 0) > 0));

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
    // Linked cost line for the priced/unpriced row badge (live watch so the
    // badge updates right after a pull or a manual price edit).
    CostLine? linkedCostLine;
    final linkedCostId = (activity.costLineId ?? '').trim();
    if (linkedCostId.isNotEmpty) {
      final estimate = context.watch<CostEstimateProvider>().estimate;
      if (estimate != null) {
        for (final line in estimate.lines) {
          if (line.id == linkedCostId) {
            linkedCostLine = line;
            break;
          }
        }
      }
    }
    final allChips = <Widget>[
      if (linkedCostLine != null) _costStatusChip(linkedCostLine),
      ..._traceabilityChips(),
    ];
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
            if (allChips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 260,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allChips,
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
            if (!isRoot && !isLocked) ...[..._buildCostActions(context, linkedCostLine), IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 14, color: Color(0xFFB91C1C)),
                onPressed: () => provider.removeActivity(activity.id),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              )],
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
    var startDate = activity.startDate;
    var endDate = activity.endDate;

    /// Pick the start or finish of this activity. A start can never sit after
    /// the finish (and vice versa) — the later date is dragged along so a
    /// saved row is never inverted.
    Future<void> pickDate(
      StateSetter setDialogState, {
      required bool isStart,
    }) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: (isStart ? startDate : endDate) ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked == null) return;
      setDialogState(() {
        if (isStart) {
          startDate = picked;
          if (endDate != null && endDate!.isBefore(picked)) endDate = picked;
        } else {
          endDate = picked;
          if (startDate != null && picked.isBefore(startDate!)) {
            startDate = picked;
          }
        }
      });
    }

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
                const Text('Dates',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InlineDateChip(
                      label: 'Start',
                      date: startDate,
                      onTap: () => pickDate(setDialogState, isStart: true),
                    ),
                    _InlineDateChip(
                      label: 'Finish',
                      date: endDate,
                      onTap: () => pickDate(setDialogState, isStart: false),
                    ),
                  ],
                ),
                const Divider(height: 24),
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
                  activity.copyWith(
                    dependencies: deps,
                    startDate: startDate,
                    endDate: endDate,
                  ),
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
  /// Cost actions for this activity row: edit an existing linked cost line,
  /// or add a new one directly on a leaf work package (core functionality —
  /// no AI). Returns an empty list when the row should not offer cost entry.
  List<Widget> _buildCostActions(
    BuildContext context,
    CostLine? linkedLine,
  ) {
    final canAddNew = activity.children.isEmpty;
    if (linkedLine == null && !canAddNew) return const [];

    final priced = isPricedCostLine(linkedLine);
    final color = linkedLine == null
        ? const Color(0xFF6B7280)
        : (priced ? const Color(0xFF16A34A) : const Color(0xFFB45309));
    return [
      IconButton(
        tooltip: linkedLine != null
            ? (priced
                ? 'Edit cost line for this work package'
                : 'Edit cost line (not priced yet)')
            : 'Add cost for this work package',
        icon: Icon(
          linkedLine != null
              ? Icons.paid_outlined
              : Icons.attach_money_outlined,
          size: 14,
          color: color,
        ),
        onPressed: () =>
            _openCostDialog(context, linkedLine),
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(4),
      ),
    ];
  }

  /// Open the manual cost-line dialog for this activity. New lines are
  /// pre-linked to the activity's WBS node (when known) and pre-described
  /// from the activity name. After save/update the activity's `costLineId`
  /// is stamped so the Schedule ↔ Cost link is bidirectional and repeat
  /// pulls stay idempotent.
  Future<void> _openCostDialog(
    BuildContext context,
    CostLine? linkedLine,
  ) async {
    final savedId = await showDialog<String>(
      context: context,
      builder: (ctx) => AddLineDialog(
        defaultCategory: isScheduledPurchaseActivity(activity)
            ? CostCategory.procurement
            : CostCategory.materials,
        editingLine: linkedLine,
        initialWbsRef: activity.wbsCode,
        initialDescription: '${activity.name} — scheduled work package cost',
      ),
    );
    if (savedId == null || savedId.isEmpty) return;
    if ((activity.costLineId ?? '') != savedId) {
      provider.updateActivity(
        activity.id,
        activity.copyWith(costLineId: savedId),
      );
    }
  }
}

/// Inline date chip used by the activity row editor for its start and finish.
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
/// naturally between the KPI strip and the activity tree.
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
