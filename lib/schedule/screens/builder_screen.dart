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
import 'package:ndu_project/utils/item_name_key.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/utils/download_helper.dart';
import 'package:ndu_project/models/project_data_model.dart'
    hide ScheduleActivity;
import 'package:ndu_project/cost_estimate/widgets/treasury_components.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';

class BuilderScreen extends StatefulWidget {
  const BuilderScreen({super.key});

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

/// One agile story with the epic and feature it hangs off, plus the sprint and
/// release labels resolved from their ids.
typedef _AgileStoryEntry = ({
  AgileTask story,
  String epicTitle,
  String featureTitle,
  String? sprintLabel,
  String? releaseLabel,
});

class _BuilderScreenState extends State<BuilderScreen> {
  /// How the Activity Tree renders. Table is the DEFAULT (Lusaka 28 follow-up):
  /// a compact, small-row table shows many more line items at once than the
  /// card tree; the Cards view keeps the original tree for deep-nesting work.
  bool _activityTreeAsTable = true;

  /// True while one of the action-row imports is running.
  ///
  /// The imports read Firestore and write the whole activity tree, so a second
  /// press while the first is in flight would run the same import again on top
  /// of a half-written tree.
  bool _busy = false;

  /// Runs [action] with the action row locked, and unlocks it whatever happens.
  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Auto-populate disabled — unified sync runs from ScheduleModuleScreen.
  }

  Future<void> _createActivitiesFromPackages() async {
    await _runAction(() async {
      try {
        await _createActivitiesFromPackagesUnsafe();
      } catch (error, stackTrace) {
        debugPrint('Work package schedule import failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Could not import work packages. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  /// Generates a schedule activity for every integrated work package that does
  /// not already have one, then wires the package chain into finish-to-start
  /// dependencies.
  ///
  /// Idempotent by construction. This used to read `data.scheduleActivities` to
  /// decide what was already imported — a legacy flat list that a different
  /// screen owns and that this import never writes to — so the check always
  /// came back empty and every press stacked a fresh copy of the whole package
  /// chain onto the schedule. It now compares against the tree this import
  /// actually writes to (work package id, then WBS node, then name), so
  /// running it again only adds what is genuinely new and tops up the
  /// dependencies of the rows that are already there.
  Future<void> _createActivitiesFromPackagesUnsafe() async {
    final scheduleProvider = context.read<ScheduleProvider>();
    final data = ProjectDataHelper.getData(context, listen: false);

    final packages = data.workPackages;
    if (packages.isEmpty) {
      _toast(
        'No work packages found. Create them in Execution Work Packages first.',
        warning: true,
      );
      return;
    }

    final schedule = scheduleProvider.schedule;
    if (schedule == null || schedule.activities.isEmpty) {
      _toast('Schedule is still loading. Please try again.', warning: true);
      return;
    }
    final root = schedule.activities.first;

    // What the schedule already carries, keyed the same way the shared
    // duplicate guard keys rows: work package id, then WBS node, then name.
    final existing = _ScheduleLinkIndex(root);

    /// The activity already standing for [pkg], or null when the import still
    /// has to create one.
    ScheduleActivity? existingFor(WorkPackage pkg) => existing.find(pkg);

    final newPackages =
        packages.where((pkg) => existingFor(pkg) == null).toList();
    final alreadyImported = packages.length - newPackages.length;
    final duplicateWbsPackages = newPackages
        .where((p) =>
            p.wbsItemId.isNotEmpty && existing.byWbsId.containsKey(p.wbsItemId))
        .length;
    if (newPackages.isEmpty) {
      _toast(
        'All $alreadyImported work packages are already on the schedule. Nothing to import.',
      );
      return;
    }

    // Package → activity id for the WHOLE set, not just the new ones, so a
    // newly created package can depend on a package that was imported earlier.
    // Linking only within the new batch left every successor pointing at an
    // activity id that was never written — a dangling dependency that CPM then
    // reported as missing, and the chain never actually formed.
    final pkgToActId = <String, String>{};
    final existingActivityById = <String, ScheduleActivity>{};
    for (final pkg in packages) {
      final existing = existingFor(pkg);
      if (existing != null) {
        pkgToActId[pkg.id] = existing.id;
        existingActivityById[pkg.id] = existing;
      } else {
        pkgToActId[pkg.id] = newSchedId('act');
      }
    }
    final packageIdSet = packages.map((p) => p.id).toSet();

    final newChildren = [...root.children];

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

    /// The predecessors this package's activity should carry, resolved against
    /// [pkgToActId] so they point at real activities.
    List<ActivityDependency> dependenciesFor(WorkPackage pkg) {
      return depPackageIds0(pkg)
          .where((depId) => pkgToActId[depId] != pkgToActId[pkg.id])
          .map((depId) => ActivityDependency(
                activityId: pkgToActId[depId]!,
                type: DependencyType.finishToStart,
              ))
          .toList();
    }

    for (final pkg in newPackages) {
      final domain = _domainForPackage(pkg);
      final activityType = _typeForPackage(pkg);
      final activityId = pkgToActId[pkg.id]!;

      final dependencies = dependenciesFor(pkg);

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
        workPackageId: pkg.id,
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

    // Top up the dependencies of the rows that were already on the schedule.
    // A chain whose successor was imported before its predecessor could only be
    // completed by a second run, so each run finishes the wiring rather than
    // leaving the successor permanently unlinked. Existing dates, owners and
    // progress are never touched — only missing links are added.
    var toppedUp = 0;
    final mergedDepsByActivityId = <String, List<ActivityDependency>>{};
    for (final pkg in packages) {
      final existing = existingActivityById[pkg.id];
      if (existing == null) continue;
      final existingIds =
          existing.dependencies.map((d) => d.activityId).toSet();
      final additions = dependenciesFor(pkg)
          .where((d) => !existingIds.contains(d.activityId))
          .toList();
      if (additions.isEmpty) continue;
      mergedDepsByActivityId[existing.id] = [
        ...existing.dependencies,
        ...additions,
      ];
      toppedUp++;
    }

    final updatedRoot = recalcActivityCodes(
      mergedDepsByActivityId.isEmpty
          ? root.copyWith(children: newChildren)
          : _withDependencies(root, mergedDepsByActivityId),
    );
    scheduleProvider.setActivities([updatedRoot]);

    final notes = <String>[
      if (alreadyImported > 0) '$alreadyImported already imported',
      if (toppedUp > 0) '$toppedUp dependency links completed',
      if (duplicateWbsPackages > 0)
        '$duplicateWbsPackages share a WBS link with an existing row',
    ];
    _toast(
      'Created ${newPackages.length} schedule activities from work packages'
      '${notes.isEmpty ? '.' : ' · ${notes.join(' · ')}.'}',
    );
  }

  /// [root] with the dependency lists named in [dependenciesByActivityId]
  /// replaced. Activity ids are unique, so the ids not named here come back
  /// untouched.
  static ScheduleActivity _withDependencies(
    ScheduleActivity node,
    Map<String, List<ActivityDependency>> dependenciesByActivityId,
  ) {
    final replacement = dependenciesByActivityId[node.id];
    return node.copyWith(
      dependencies: replacement ?? node.dependencies,
      children: node.children
          .map((child) => _withDependencies(child, dependenciesByActivityId))
          .toList(),
    );
  }

  /// The agile backlog for this project, grouped ready for import.
  ///
  /// Returns null — with a message explaining what is missing — when the project
  /// has no id or no epics at all, so the caller can report the real reason
  /// instead of "nothing happened".
  Future<({List<_AgileStoryEntry> stories, int epicCount, String? problem})>
      _loadAgileStories() async {
    final projectData = ProjectDataHelper.getData(context, listen: false);
    final pid = projectData.projectId;
    if (pid == null || pid.isEmpty) {
      return (
        stories: const <_AgileStoryEntry>[],
        epicCount: 0,
        problem: 'No project ID found.'
      );
    }

    final epics = await EpicFeatureService.loadEpics(pid);
    if (epics.isEmpty) {
      return (
        stories: const <_AgileStoryEntry>[],
        epicCount: 0,
        problem:
            'No epics found. Sync from WBS or create epics first in the Agile Delivery Model.',
      );
    }

    final tasks = await ExecutionPhaseService.loadAgileTasks(projectId: pid);
    final sprintData = await RoadmapService.loadSprints(projectId: pid);
    final releaseData = await AgileWireframeService.loadReleasePlans(pid);
    final sprintLabelById = {
      for (final sprint in sprintData) sprint.id: sprint.name
    };
    final releaseLabelById = {
      for (final release in releaseData) release.id: release.releaseLabel
    };

    final stories = <_AgileStoryEntry>[];
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
        }
      }
    }

    if (stories.isEmpty) {
      return (
        stories: const <_AgileStoryEntry>[],
        epicCount: epics.length,
        problem:
            'No stories found assigned to features. Create stories in Agile Development Iterations first.',
      );
    }
    return (stories: stories, epicCount: epics.length, problem: null);
  }

  /// The `AgileTask` ids the schedule already carries a story for.
  Set<String> _scheduledAgileTaskIds(ScheduleProvider provider) {
    final schedule = provider.schedule;
    if (schedule == null) return const {};
    return {
      for (final activity in schedule.activities
          .expand((root) => ScheduleCpmService.flatten([root])))
        if ((activity.agileTaskId ?? '').trim().isNotEmpty)
          activity.agileTaskId!.trim(),
    };
  }

  /// Imports the agile backlog, reporting what the run actually changed.
  Future<void> _importStories() async {
    await _runAction(() async {
      try {
        await _importStoriesUnsafe();
      } catch (error, stackTrace) {
        debugPrint('Agile story import failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _toast('Could not import agile stories. Please try again.',
            warning: true);
      }
    });
  }

  Future<void> _importStoriesUnsafe() async {
    final scheduleProvider = context.read<ScheduleProvider>();
    final loaded = await _loadAgileStories();
    final problem = loaded.problem;
    if (problem != null) {
      if (mounted) _toast(problem, warning: true);
      return;
    }
    if (!mounted) return;

    final stories = loaded.stories;
    // Captured BEFORE the import: afterwards every story this run added is on
    // the schedule, so asking the schedule what is already imported then would
    // report the run's own work as pre-existing.
    final alreadyScheduled = _scheduledAgileTaskIds(scheduleProvider);
    final summary = scheduleProvider.importStoriesFromAgile(stories: stories);

    if (summary.isEmpty) {
      _toast(
        'All ${stories.length} stories from ${loaded.epicCount} epics are '
        'already on the schedule. Nothing to import.',
      );
      return;
    }

    // Readiness is reported on the stories this run added — warning about the
    // whole backlog (including the ones already scheduled) buried the signal.
    final added = stories
        .where((entry) => !alreadyScheduled.contains(entry.story.id))
        .toList();
    final missingSprint =
        added.where((e) => e.story.plannedSprintId.isEmpty).length;
    final missingRelease =
        added.where((e) => e.story.plannedReleaseId.isEmpty).length;
    final notReady = added
        .where((e) => e.story.readinessStatus != 'Ready for Sprint')
        .length;

    final notes = <String>[];
    if (summary.storiesSkipped > 0) {
      notes.add('${summary.storiesSkipped} already on the schedule');
    }
    if (missingSprint > 0) notes.add('$missingSprint without sprint');
    if (missingRelease > 0) notes.add('$missingRelease without release');
    if (notReady > 0) notes.add('$notReady not sprint-ready');

    _toast(
      'Imported ${summary.storiesAdded} stories '
      '(${summary.epicsAdded + summary.epicsReused} epics, '
      '${summary.featuresAdded + summary.featuresReused} features)'
      '${notes.isEmpty ? '.' : ' · ${notes.join(' · ')}.'}',
      warning: notes.isNotEmpty,
    );
  }

  /// Runs a CPM pass and shows what came out of it.
  ///
  /// The pass itself only produced a one-line snackbar with a day count, and
  /// silently dropped every diagnostic the CPM engine had raised. A planner
  /// whose critical path looked wrong had no way to find out that a dependency
  /// pointed at a deleted activity or that two activities formed a cycle, so
  /// the result sheet now names both the outcome and the problems.
  ///
  /// Dates already set by hand are preserved; only empty dates are filled in
  /// from the schedule's baseline (see [ScheduleProvider.computeCpm]). The
  /// sheet offers the destructive re-baseline explicitly instead of doing it
  /// behind a button labelled "Run CPM".
  void _runCpm() {
    final scheduleProvider = context.read<ScheduleProvider>();
    final result = scheduleProvider.computeCpm(overwriteDates: false);
    if (result == null) {
      _toast('No activities to compute CPM on.', warning: true);
      return;
    }
    _showCpmResultSheet(scheduleProvider, result);
  }

  /// The CPM result sheet: headline numbers, the data-quality problems the
  /// engine found, and the critical path itself.
  void _showCpmResultSheet(
    ScheduleProvider provider,
    CpmResult result,
  ) {
    final schedule = provider.schedule;
    final nameById = <String, String>{
      if (schedule != null)
        for (final activity in schedule.activities
            .expand((r) => ScheduleCpmService.flatten([r])))
          activity.id: activity.name,
    };
    // The same day the CPM offsets were measured from, so the finish date shown
    // here is the date the schedule actually holds, not a recomputation that
    // could disagree with it.
    final anchor = provider.cpmAnchorDate;
    final finish =
        anchor?.add(Duration(days: result.projectDurationDays.ceil()));

    final critical = result.criticalPathIds
        .map((id) => nameById[id] ?? id)
        .where((name) => name.trim().isNotEmpty)
        .toList();
    final blocking = result.criticalPathIds
        .map((id) => result.activitiesById[id])
        .whereType<CpmActivityResult>()
        .where((a) => a.totalFloat.abs() < 0.001)
        .length;
    final withFloat =
        result.activitiesById.values.where((a) => a.totalFloat > 0).length;

    // Diagnostics say "this result is only as good as the links it was built
    // from", so they lead — a cycle silently truncates the critical path.
    final issues = <({String message, CpmDiagnosticType type})>[
      for (final diagnostic in result.diagnostics)
        (
          message: describeCpmDiagnostic(diagnostic, nameById),
          type: diagnostic.type,
        ),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CpmResultSheet(
        projectDurationDays: result.projectDurationDays,
        finishDate: finish,
        criticalCount: blocking,
        floatCount: withFloat,
        criticalNames: critical,
        issues: issues,
        onRebaseline: () {
          Navigator.pop(sheetContext);
          provider.computeCpm(overwriteDates: true);
          _toast('Dates re-baselined from the current network.');
        },
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
                    valueColor:
                        AlwaysStoppedAnimation<Color>(LightModeColors.accent),
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
                    if (_busy)
                      // The imports read Firestore and can take a moment;
                      // without this the row looked dead and every button
                      // stayed tappable, so a second press ran the import twice.
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        child: SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                LightModeColors.accent),
                          ),
                        ),
                      )
                    else ...[
                      _TreasuryActionPill(
                        icon: Icons.upload_outlined,
                        label: 'Import by Methodology',
                        enabled: !schedule.isLocked,
                        onTap: () => _showMethodologyImportDialog(schedule),
                      ),
                      _TreasuryActionPill(
                        icon: Icons.work_outline,
                        label: 'From Work Packages',
                        enabled: !schedule.isLocked,
                        onTap: _createActivitiesFromPackages,
                      ),
                      if (schedule.basis.deliveryModel == 'AGILE' ||
                          schedule.basis.deliveryModel == 'HYBRID')
                        _TreasuryActionPill(
                          icon: Icons.auto_stories_outlined,
                          label: 'Import Agile Stories',
                          enabled: !schedule.isLocked,
                          onTap: _importStories,
                        ),
                      _TreasuryActionPill(
                        icon: Icons.calculate_outlined,
                        label: 'Run CPM',
                        enabled: !schedule.isLocked,
                        onTap: _runCpm,
                      ),
                      _TreasuryActionPill(
                        icon: Icons.download_outlined,
                        label: 'Export',
                        onTap: () => _showExportSheet(schedule),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // ═══════════════════════════════════════════════════════════════
              // TREASURY KPI STRIP — at-a-glance schedule vitals
              // ═══════════════════════════════════════════════════════════════
              TreasuryKpiStrip(
                kpis: _buildScheduleKpis(root, schedule),
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
              // ACTIVITY TREE — compact table by default (Lusaka 28 follow-up);
              // the card tree remains available via the view toggle.
              // ═══════════════════════════════════════════════════════════════
              Row(
                children: [
                  const Spacer(),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.table_rows_outlined, size: 14),
                        label: Text('Table', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.account_tree_outlined, size: 14),
                        label: Text('Cards', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    selected: {_activityTreeAsTable},
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onSelectionChanged: (selection) {
                      setState(() => _activityTreeAsTable = selection.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Shared section header (title + counts) above both views.
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
              if (_activityTreeAsTable)
                _ActivityTreeTable(
                  root: root,
                  provider: provider,
                  isLocked: schedule.isLocked,
                )
              else
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

  /// Build the KPI strip for the schedule builder. Cost lives in the Cost
  /// Estimate module and on the "Drawing From" banner, so it has no KPI here.
  List<TreasuryKpiSpec> _buildScheduleKpis(
    ScheduleActivity root,
    Schedule schedule,
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

  /// "Import by Methodology" — decides which import this project's methodology
  /// wants, shows exactly what that import would change, and runs it.
  ///
  /// This used to be an information dialog whose only action was to tell the
  /// user to go and press a different button. It now answers the three
  /// questions the user actually has — which source is right, how much is new,
  /// and what happens to the rest — and performs the import in one step.
  void _showMethodologyImportDialog(Schedule schedule) {
    final provider = context.read<ScheduleProvider>();
    final data = ProjectDataHelper.getData(context, listen: false);
    final packages = data.workPackages;
    final deliveryModel = schedule.basis.deliveryModel.toUpperCase();
    final isAgileFlow = deliveryModel == 'AGILE' || deliveryModel == 'HYBRID';
    final root = schedule.activities.isEmpty ? null : schedule.activities.first;

    // Work-package counts are known without touching the network.
    var packageTotal = packages.length;
    var packagesAlreadyOnSchedule = 0;
    if (root != null) {
      final index = _ScheduleLinkIndex(root);
      packagesAlreadyOnSchedule =
          packages.where((pkg) => index.find(pkg) != null).length;
    }
    final packagesToAdd = packageTotal - packagesAlreadyOnSchedule;

    // Read at most once, however many times the dialog rebuilds while the user
    // switches sources. Declared outside the builder so the memo survives the
    // rebuilds — a local would start the read again on every toggle, and the
    // counts shown could disagree with the import that follows.
    Future<({int total, int already, String? problem})>? storiesCountFuture;
    Future<({int total, int already, String? problem})> storiesCounts() {
      return storiesCountFuture ??= () async {
        final loaded = await _loadAgileStories();
        final problem = loaded.problem;
        if (problem != null) {
          return (total: 0, already: 0, problem: problem);
        }
        // Clamped because the backlog can hold stories the schedule has
        // since dropped, and a count above the total would render as
        // "−3 to add".
        final already = _scheduledAgileTaskIds(provider)
            .length
            .clamp(0, loaded.stories.length);
        return (
          total: loaded.stories.length,
          already: already,
          problem: null,
        );
      }();
    }

    // Which source is chosen lives OUTSIDE the builder: `StatefulBuilder`
    // re-runs its builder from scratch on every setState, so a `var` declared
    // in there would be re-initialised and the selection would snap back the
    // moment the user tapped it.
    var source = isAgileFlow ? _ImportSource.stories : _ImportSource.packages;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          // Agile counts come from Firestore, so they arrive after the dialog
          // is already up. The read is memoised outside the builder so
          // switching sources back and forth does not re-query the backlog on
          // every rebuild — and so the numbers cannot disagree between the card
          // and the import that follows it.
          final storiesFuture =
              source == _ImportSource.stories ? storiesCounts() : null;

          final packageEnabled = packageTotal > 0;
          final storiesBlock =
              FutureBuilder<({int total, int already, String? problem})>(
            future: storiesFuture,
            builder: (context, snapshot) {
              // Nothing has been read yet: the card is an invitation, not a
              // result. Showing a spinner here would leave it turning for ever
              // until the user happened to select it.
              if (storiesFuture == null) {
                return _ImportSourceCard(
                  icon: Icons.auto_stories_outlined,
                  title: 'Agile stories',
                  subtitle: isAgileFlow
                      ? 'Select to count the stories in the backlog'
                      : 'Not the methodology for this project — available to review',
                  selected: false,
                  enabled: true,
                  onTap: () => setDialogState(() {
                    source = _ImportSource.stories;
                  }),
                );
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Counting agile stories…',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                );
              }
              final data = snapshot.data;
              if (data == null || data.problem != null) {
                return _ImportSourceCard(
                  icon: Icons.auto_stories_outlined,
                  title: 'Agile stories',
                  subtitle: data?.problem ?? 'Could not read the backlog.',
                  selected: source == _ImportSource.stories,
                  enabled: false,
                  onTap: null,
                );
              }
              final toAdd = data.total - data.already;
              return _ImportSourceCard(
                icon: Icons.auto_stories_outlined,
                title: 'Agile stories',
                subtitle: toAdd == 0
                    ? 'All ${data.total} stories are already on the schedule'
                    : '${data.total} stories in the backlog · ${data.already} already scheduled · $toAdd to add',
                selected: source == _ImportSource.stories,
                enabled: true,
                onTap: () => setDialogState(() {
                  source = _ImportSource.stories;
                }),
              );
            },
          );

          return AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE4E7EC))),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: LightModeColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome_motion_outlined,
                      size: 17, color: LightModeColors.accent),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Import by Methodology',
                      style: TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _methodologyRationale(deliveryModel, isAgileFlow),
                    style: const TextStyle(
                        color: Color(0xFF495057), fontSize: 12.5, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  _ImportSourceCard(
                    icon: Icons.work_outline,
                    title: 'Integrated work packages',
                    subtitle: packageTotal == 0
                        ? 'None yet — generate package chains in Execution Work Packages'
                        : '$packageTotal packages · $packagesAlreadyOnSchedule already scheduled · $packagesToAdd to add',
                    selected: source == _ImportSource.packages,
                    enabled: packageEnabled,
                    onTap: packageEnabled
                        ? () => setDialogState(() {
                              source = _ImportSource.packages;
                            })
                        : null,
                  ),
                  const SizedBox(height: 8),
                  storiesBlock,
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 14, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          source == _ImportSource.packages
                              ? 'Only packages that are not on the schedule yet are added. Dependencies are wired from the package chain, and links already in place are left alone.'
                              : 'Only stories that are not on the schedule yet are added, grouped under their feature and epic. Running this again tops the schedule up rather than duplicating it.',
                          style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 11,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  if (source == _ImportSource.packages) {
                    _createActivitiesFromPackages();
                  } else {
                    _importStories();
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: LightModeColors.accent,
                  foregroundColor: LightModeColors.lightOnPrimary,
                ),
                child: Text(source == _ImportSource.packages
                    ? 'Import $packagesToAdd packages'
                    : 'Import agile stories'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Why this delivery model imports the way it does.
  String _methodologyRationale(String deliveryModel, bool isAgileFlow) {
    return isAgileFlow
        ? 'This project is set to ${_titleCase(deliveryModel)} delivery, so the '
            'schedule is built from agile stories grouped under features and epics. '
            'Work packages remain available for the engineering scope that feeds them.'
        : 'This project is set to ${_titleCase(deliveryModel)} delivery, so the '
            'schedule is built from integrated work packages and their dependency '
            'chain rather than raw WBS nodes.';
  }

  static String _titleCase(String value) => value.isEmpty
      ? value
      : value[0].toUpperCase() + value.substring(1).toLowerCase();

  /// Offers the schedule as a file the user can actually send on.
  ///
  /// This used to copy JSON to the clipboard and call that an export — there was
  /// no file, no PDF and nothing a recipient could open without the app. The
  /// three formats below cover the three real destinations: a PDF for an issue or
  /// approval pack, CSV for Excel / P6 hand-offs, and JSON for the clipboard.
  void _showExportSheet(Schedule schedule) {
    final activities = schedule.activities.isEmpty
        ? const <ScheduleActivity>[]
        : ScheduleCpmService.flatten(schedule.activities);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ExportSheet(
        activityCount: activities.where((a) => a.level > 0).length,
        onExportPdf: () {
          Navigator.pop(sheetContext);
          _exportScheduleAsPdf(schedule, activities);
        },
        onExportCsv: () {
          Navigator.pop(sheetContext);
          _exportScheduleAsCsv(schedule, activities);
        },
        onExportJson: () {
          Navigator.pop(sheetContext);
          _copyScheduleAsJson(schedule);
        },
      ),
    );
  }

  /// A readable PDF of the schedule: a summary table of the tree plus the
  /// critical path, so the document answers the questions a reviewer asks
  /// rather than only restating the rows.
  Future<void> _exportScheduleAsPdf(
      Schedule schedule, List<ScheduleActivity> activities) async {
    final rows = activities.where((a) => a.level > 0).toList();
    final critical = rows.where((a) => a.isCriticalPath).toList();
    final dateFormat = DateFormat('dd MMM yyyy');
    final sections = <PdfSection>[
      PdfSection.keyValue('Schedule', [
        {'Project': schedule.projectName},
        {'Delivery model': schedule.basis.deliveryModel},
        {'Status': schedule.status.label},
        {'Locked': schedule.isLocked ? 'Yes' : 'No'},
        {'Activities': '${rows.length}'},
        {
          'Project start': schedule.activities.isEmpty
              ? '—'
              : (schedule.activities.first.startDate == null
                  ? '—'
                  : dateFormat.format(schedule.activities.first.startDate!))
        },
        {
          'Project finish': schedule.activities.isEmpty
              ? '—'
              : (schedule.activities.first.endDate == null
                  ? '—'
                  : dateFormat.format(schedule.activities.first.endDate!))
        },
        {'Critical path activities': '${critical.length}'},
      ]),
      PdfSection.table(
        'Activity schedule',
        headers: const [
          'Code',
          'Activity',
          'Type',
          'Duration',
          'Start',
          'Finish',
          'Owner',
          'Critical'
        ],
        rows: [
          for (final activity in rows)
            [
              activity.code,
              activity.name,
              activity.type.label,
              activity.duration == null
                  ? '—'
                  : '${_trimNumber(activity.duration!)} ${activity.durationUnit ?? 'day'}${activity.durationUnit == 'day' ? '' : 's'}',
              activity.startDate == null
                  ? '—'
                  : dateFormat.format(activity.startDate!),
              activity.endDate == null
                  ? '—'
                  : dateFormat.format(activity.endDate!),
              activity.owner ?? '—',
              activity.isCriticalPath ? 'Yes' : '',
            ],
        ],
      ),
      if (critical.isNotEmpty)
        PdfSection.table(
          'Critical path',
          headers: const ['#', 'Activity', 'Start', 'Finish'],
          rows: [
            for (var i = 0; i < critical.length; i++)
              [
                '${i + 1}',
                critical[i].name,
                critical[i].startDate == null
                    ? '—'
                    : dateFormat.format(critical[i].startDate!),
                critical[i].endDate == null
                    ? '—'
                    : dateFormat.format(critical[i].endDate!),
              ],
          ],
        ),
    ];
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Schedule',
      sections: sections,
      filenamePrefix: 'schedule',
      // The tree is the document; a screenshot of the builder would only add
      // the buttons the reader already has.
      includeScreenCapture: false,
    );
  }

  /// The schedule as a CSV one row per activity — the shape PM tools and Excel
  /// expect, so the plan can leave the app without being retyped.
  void _exportScheduleAsCsv(
      Schedule schedule, List<ScheduleActivity> activities) {
    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final nameById = <String, String>{
        for (final activity in activities) activity.id: activity.name,
      };
      final buffer = StringBuffer()
        ..writeln('code,name,level,type,domain,duration,duration_unit,'
            'start_date,end_date,owner,status,progress,critical,'
            'wbs_node_id,work_package_id,agile_task_id,sprint,release,'
            'predecessors');
      for (final activity in activities) {
        if (activity.level == 0) continue;
        buffer.writeln([
          _csv(activity.code),
          _csv(activity.name),
          '${activity.level}',
          _csv(activity.type.name),
          _csv(activity.domain.name),
          activity.duration == null ? '' : _trimNumber(activity.duration!),
          _csv(activity.durationUnit ?? ''),
          _csv(activity.startDate == null
              ? ''
              : dateFormat.format(activity.startDate!)),
          _csv(activity.endDate == null
              ? ''
              : dateFormat.format(activity.endDate!)),
          _csv(activity.owner ?? ''),
          _csv(activity.status ?? ''),
          activity.progress == null ? '' : _trimNumber(activity.progress!),
          activity.isCriticalPath ? 'YES' : '',
          _csv(activity.wbsNodeId ?? ''),
          _csv(activity.workPackageId ?? ''),
          _csv(activity.agileTaskId ?? ''),
          _csv(activity.sprintLabel ?? ''),
          _csv(activity.releaseLabel ?? ''),
          _csv(activity.dependencies
              .map((d) => nameById[d.activityId] ?? d.activityId)
              .join('; ')),
        ].join(','));
      }
      downloadFile(
        Uint8List.fromList(utf8.encode(buffer.toString())),
        '${_exportFileBase(schedule)}_schedule.csv',
        mimeType: 'text/csv',
      );
      _toast(
          'Exported ${activities.where((a) => a.level > 0).length} activities to CSV.');
    } catch (error) {
      _toast('CSV export failed: $error', warning: true);
    }
  }

  Future<void> _copyScheduleAsJson(Schedule schedule) async {
    final json = const JsonEncoder.withIndent('  ').convert({
      'id': schedule.id,
      'projectName': schedule.projectName,
      'deliveryModel': schedule.basis.deliveryModel,
      'status': schedule.status.name,
      'isLocked': schedule.isLocked,
      'startDate': schedule.activities.isEmpty
          ? null
          : schedule.activities.first.startDate?.toIso8601String(),
      'endDate': schedule.activities.isEmpty
          ? null
          : schedule.activities.first.endDate?.toIso8601String(),
      'activities': schedule.activities.isEmpty
          ? null
          : _activityToJson(schedule.activities.first),
    });
    await Clipboard.setData(ClipboardData(text: json));
    _toast('Schedule JSON copied to clipboard.');
  }

  /// The activity tree as JSON — the shape the app persists, so a copy can be
  /// diffed or archived and read back without guessing at field names.
  Map<String, dynamic> _activityToJson(ScheduleActivity node) {
    return {
      'id': node.id,
      'code': node.code,
      'name': node.name,
      'level': node.level,
      'type': node.type.name,
      'domain': node.domain.name,
      if (node.description != null) 'description': node.description,
      if (node.duration != null) 'duration': node.duration,
      if (node.durationUnit != null) 'durationUnit': node.durationUnit,
      if (node.owner != null) 'owner': node.owner,
      if (node.status != null) 'status': node.status,
      if (node.progress != null) 'progress': node.progress,
      if (node.startDate != null)
        'startDate': node.startDate!.toIso8601String(),
      if (node.endDate != null) 'endDate': node.endDate!.toIso8601String(),
      'isCriticalPath': node.isCriticalPath,
      if (node.wbsNodeId != null) 'wbsNodeId': node.wbsNodeId,
      if (node.workPackageId != null) 'workPackageId': node.workPackageId,
      if (node.agileTaskId != null) 'agileTaskId': node.agileTaskId,
      if (node.sprintLabel != null) 'sprint': node.sprintLabel,
      if (node.releaseLabel != null) 'release': node.releaseLabel,
      'dependencies': node.dependencies
          .map((d) => {
                'activityId': d.activityId,
                'type': d.type.name,
              })
          .toList(),
      'children': node.children.map(_activityToJson).toList(),
    };
  }

  /// `HH:mm` without the trailing zeros, so a 5.0-day duration reads "5 days"
  /// rather than "5.0 days".
  static String _trimNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  static String _csv(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains(';')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _exportFileBase(Schedule schedule) {
    final name = schedule.projectName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return name.isEmpty ? 'schedule' : name;
  }

  /// One message, one place — every action reports the same way.
  void _toast(String message, {bool warning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              warning ? const Color(0xFFF59E0B) : LightModeColors.accent,
          duration: Duration(seconds: warning ? 5 : 3),
        ),
      );
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
  })  : primary = false,
        enabled = true;

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

/// Asks before an activity is removed from the Activity Tree, then removes it.
///
/// Both row views (the card tree and the table) route their trash button here
/// so the two behave identically. The prompt is not ceremony: the button sits
/// on every row, one press removes the node **and everything under it**, and
/// `ScheduleProvider.removeActivity` persists the result — so a mis-tap on a
/// summary row silently drops a dozen dated activities with no way back. The
/// dialog names the activity and counts the descendants that go with it, and
/// Cancel is the default way out.
///
/// Returns once the removal has happened, so a test can await it.
Future<void> confirmActivityRemoval(
  BuildContext context, {
  required ScheduleProvider provider,
  required ScheduleActivity activity,
  required bool isLocked,
}) async {
  // A locked schedule is read-only; the button is hidden, but the same guard
  // lives here so no caller can delete through it.
  if (isLocked) return;

  final descendants = ScheduleCpmService.flatten([activity]).length - 1;
  final confirmed = await showDeleteConfirmationDialog(
    context,
    title:
        descendants == 0 ? 'Delete activity' : 'Delete activity and its rows',
    itemLabel: activity.name,
    message: descendants == 0
        ? null
        : 'Deleting "${activity.name}" also deletes the $descendants '
            '${descendants == 1 ? 'activity' : 'activities'} nested under it, '
            'dates and dependencies included. This cannot be undone.',
  );
  if (!confirmed) return;

  provider.removeActivity(activity.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(descendants == 0
          ? 'Deleted "${activity.name}".'
          : 'Deleted "${activity.name}" and $descendants '
              '${descendants == 1 ? 'activity' : 'activities'} under it.'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
}

/// Which source an import-by-methodology run should use.
enum _ImportSource { packages, stories }

/// Turns a CPM diagnostic into something a planner can act on.
///
/// The engine's own message names activity ids, which nobody recognises on a
/// schedule. Naming the activity turns "Missing dependency act_1234" into
/// "Platform Foundation depends on an activity that is not on this schedule".
String describeCpmDiagnostic(
  CpmDiagnostic diagnostic,
  Map<String, String> nameById,
) {
  final name = nameById[diagnostic.activityId];
  final label = (name == null || name.trim().isEmpty)
      ? 'An activity that is not on the schedule'
      : '"$name"';
  return switch (diagnostic.type) {
    CpmDiagnosticType.cycle =>
      '$label sits in a dependency cycle, so CPM could not sequence past it. '
          'Remove one of the links between the activities in the cycle.',
    CpmDiagnosticType.selfDependency =>
      '$label depends on itself. Remove that dependency.',
    CpmDiagnosticType.missingDependency =>
      '$label depends on an activity that is not on this schedule. Remove the '
          'link or restore the activity.',
    CpmDiagnosticType.missingDuration =>
      '$label has no duration, so CPM assumed 1 day for it. Set a duration to '
          'make the result reliable.',
  };
}

/// The sheet "Export" opens: three destinations, each labelled with what it
/// produces rather than just its format.
class _ExportSheet extends StatelessWidget {
  final int activityCount;
  final VoidCallback onExportPdf;
  final VoidCallback onExportCsv;
  final VoidCallback onExportJson;

  const _ExportSheet({
    required this.activityCount,
    required this.onExportPdf,
    required this.onExportCsv,
    required this.onExportJson,
  });

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Export schedule',
      subtitle: '$activityCount activities · pick a format',
      children: [
        _SheetOption(
          icon: Icons.picture_as_pdf_outlined,
          title: 'PDF document',
          subtitle: 'Activity table, summary and critical path',
          onTap: onExportPdf,
        ),
        const SizedBox(height: 8),
        _SheetOption(
          icon: Icons.table_chart_outlined,
          title: 'CSV spreadsheet',
          subtitle: 'One row per activity for Excel or P6 hand-off',
          onTap: onExportCsv,
        ),
        const SizedBox(height: 8),
        _SheetOption(
          icon: Icons.data_object_outlined,
          title: 'JSON to clipboard',
          subtitle: 'Full tree including dates and dependencies',
          onTap: onExportJson,
        ),
      ],
    );
  }
}

/// The sheet "Run CPM" opens.
class _CpmResultSheet extends StatelessWidget {
  final double projectDurationDays;
  final DateTime? finishDate;
  final int criticalCount;
  final int floatCount;
  final List<String> criticalNames;
  final List<({String message, CpmDiagnosticType type})> issues;
  final VoidCallback onRebaseline;

  const _CpmResultSheet({
    required this.projectDurationDays,
    required this.finishDate,
    required this.criticalCount,
    required this.floatCount,
    required this.criticalNames,
    required this.issues,
    required this.onRebaseline,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return _SheetFrame(
      title: 'CPM results',
      subtitle: issues.isEmpty
          ? 'Dependencies are clean'
          : '${issues.length} dependency ${issues.length == 1 ? 'issue' : 'issues'} to fix',
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Duration',
                value:
                    projectDurationDays == projectDurationDays.roundToDouble()
                        ? '${projectDurationDays.round()} days'
                        : '${projectDurationDays.toStringAsFixed(1)} days',
                hint: finishDate == null
                    ? 'no start date set'
                    : 'finishes ${dateFormat.format(finishDate!)}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'Critical path',
                value: '$criticalCount',
                hint: criticalCount == 1 ? 'activity' : 'activities',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'Has float',
                value: '$floatCount',
                hint: 'can slip without moving the finish',
              ),
            ),
          ],
        ),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDBA74)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: Color(0xFFB45309)),
                    SizedBox(width: 8),
                    Text(
                      'Fix these before trusting the dates',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final issue in issues.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: SizedBox(
                            width: 4,
                            height: 4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFFB45309),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            issue.message,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.45,
                              color: Color(0xFF7C2D12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (issues.length > 6)
                  Text(
                    '+ ${issues.length - 6} more',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309)),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (criticalNames.isNotEmpty) ...[
          const Text(
            'Critical path, in sequence',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1D1F)),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < criticalNames.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  LightModeColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: LightModeColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              criticalNames[i],
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Color(0xFF1A1D1F)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            const Expanded(
              child: Text(
                'Dates you set by hand were kept; only empty dates were filled in.',
                style: TextStyle(
                    fontSize: 11, height: 1.45, color: Color(0xFF6B7280)),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280)),
              child: const Text('Close'),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: onRebaseline,
              style: FilledButton.styleFrom(
                backgroundColor: LightModeColors.accent,
                foregroundColor: LightModeColors.lightOnPrimary,
              ),
              child: const Text('Re-baseline dates'),
            ),
          ],
        ),
      ],
    );
  }
}

/// A headline number in the CPM sheet.
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String hint;

  const _StatTile({
    required this.label,
    required this.value,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1D1F),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

/// A selectable source in the import-by-methodology dialog.
class _ImportSourceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _ImportSourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? LightModeColors.accent : const Color(0xFFE4E7EC);
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: selected
                  ? LightModeColors.accent.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon,
                    size: 17,
                    color: selected
                        ? LightModeColors.accent
                        : const Color(0xFF6B7280)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1D1F),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 1),
                    child: Icon(Icons.check_circle,
                        size: 16, color: LightModeColors.accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row in the export sheet.
class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF6B7280)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1D1F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 11.5, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: Color(0xFFD1D5DB)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared chrome for the bottom sheets on this page.
class _SheetFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SheetFrame({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1D1F),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18),
                  color: const Color(0xFF6B7280),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Close',
                ),
              ],
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// What the schedule already carries, indexed the way a work-package import
/// matches rows against it.
///
/// The lookup order is work package id → WBS node id → activity name. The
/// first two are exact; the name is the fallback for rows imported before the
/// schedule recorded which package they came from.
class _ScheduleLinkIndex {
  _ScheduleLinkIndex(ScheduleActivity root) {
    for (final activity in ScheduleCpmService.flatten([root])) {
      if (activity.level == 0) continue;
      final workPackageId = (activity.workPackageId ?? '').trim();
      if (workPackageId.isNotEmpty) {
        byWorkPackageId.putIfAbsent(workPackageId, () => activity);
      }
      final wbsId = (activity.wbsNodeId ?? '').trim();
      if (wbsId.isNotEmpty) byWbsId.putIfAbsent(wbsId, () => activity);
      final nameKey = itemNameKey(activity.name);
      if (nameKey.isNotEmpty) byName.putIfAbsent(nameKey, () => activity);
    }
  }

  final Map<String, ScheduleActivity> byWorkPackageId = {};
  final Map<String, ScheduleActivity> byWbsId = {};
  final Map<String, ScheduleActivity> byName = {};

  /// The activity already standing for [pkg], or null when the import still
  /// has to create one.
  ScheduleActivity? find(WorkPackage pkg) {
    final byWorkPackage = byWorkPackageId[pkg.id.trim()];
    if (byWorkPackage != null) return byWorkPackage;
    final wbsId = pkg.wbsItemId.trim();
    if (wbsId.isNotEmpty) {
      final byWbs = byWbsId[wbsId];
      if (byWbs != null) return byWbs;
    }
    return byName[
        itemNameKey(IntegratedWorkPackageService.packageActivityName(pkg))];
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
    final allChips = <Widget>[
      ..._traceabilityChips(),
    ];
    return GestureDetector(
      onTap: () => _showActivityEditDialog(context),
      child: Container(
        margin: EdgeInsets.only(bottom: 4, left: isRoot ? 0 : 24),
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
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Domain icon tile
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: domainColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                              color: domainColor.withValues(alpha: 0.28)),
                        ),
                        child: Icon(
                            isRoot
                                ? Icons.flag_rounded
                                : (activity.type == ActivityType.summary
                                    ? Icons.folder_outlined
                                    : Icons.task_alt_rounded),
                            size: 14,
                            color: domainColor),
                      ),
                      const SizedBox(width: 10),
                      // Code chip
                      if (activity.code.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
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
                          decoration: BoxDecoration(
                              color: domainColor, shape: BoxShape.circle),
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
                      if (formatDuration(
                              activity.duration, activity.durationUnit) !=
                          '—')
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: TreasuryTokens.infoSoft,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: TreasuryTokens.info
                                      .withValues(alpha: 0.22)),
                            ),
                            child: Text(
                                formatDuration(
                                    activity.duration, activity.durationUnit),
                                style: const TextStyle(
                                    color: TreasuryTokens.info,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ])),
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
                                      color: TreasuryTokens.success
                                          .withValues(alpha: 0.35)),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: TreasuryTokens.successSoft,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: TreasuryTokens.success
                                      .withValues(alpha: 0.3)),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: TreasuryTokens.warningSoft,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: TreasuryTokens.warning
                                      .withValues(alpha: 0.3)),
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
                      if (!isRoot && !isLocked)
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 14, color: Color(0xFFB91C1C)),
                          tooltip: 'Delete activity',
                          onPressed: () => confirmActivityRemoval(
                            context,
                            provider: provider,
                            activity: activity,
                            isLocked: isLocked,
                          ),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
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
    showActivityEditDialog(
      context,
      activity: activity,
      provider: provider,
      isLocked: isLocked,
      isRoot: isRoot,
    );
  }

  /// Row editor shared by the card tree and the compact table (Lusaka 28
  /// follow-up). Static so both views open the identical dialog.
  static void showActivityEditDialog(
    BuildContext context, {
    required ScheduleActivity activity,
    required ScheduleProvider provider,
    required bool isLocked,
    bool isRoot = false,
  }) {
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

/// Compact default table view of the Activity Tree (Lusaka 28 follow-up).
///
/// The card tree is readable but tall — one card per activity meant scrolling
/// screen after screen on a synced schedule (89 L1 · 105 total in the review).
/// This table keeps every column the cards carried (code, name, domain,
/// duration, start, finish, actions) but with SMALL rows: 26px,
/// hairline dividers, no card chrome. Indentation preserves the tree
/// structure and summary rows can expand/collapse their children.
class _ActivityTreeTable extends StatefulWidget {
  const _ActivityTreeTable({
    required this.root,
    required this.provider,
    required this.isLocked,
  });

  final ScheduleActivity root;
  final ScheduleProvider provider;
  final bool isLocked;

  @override
  State<_ActivityTreeTable> createState() => _ActivityTreeTableState();
}

class _ActivityTreeTableState extends State<_ActivityTreeTable> {
  static const double _indentWidth = 14;
  static const double _rowHeight = 26;

  final Set<String> _collapsed = <String>{};

  @override
  Widget build(BuildContext context) {
    final rows = <_TreeRowSpec>[];

    void visit(ScheduleActivity node, int depth) {
      final isRoot = depth == 0;
      final hasChildren = node.children.isNotEmpty;
      final collapsed = _collapsed.contains(node.id);
      rows.add(_TreeRowSpec(
        activity: node,
        depth: depth,
        isRoot: isRoot,
        hasChildren: hasChildren,
        collapsed: collapsed,
      ));
      if (hasChildren && !collapsed) {
        for (final child in node.children) {
          visit(child, depth + 1);
        }
      }
    }

    visit(widget.root, 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TreasuryTokens.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        // IntrinsicWidth + minWidth mirrors the card tree's bounded-width
        // trick: inside the horizontal scroll view the incoming width is
        // unbounded, and an Expanded in the header/name cells would throw
        // "RenderFlex children have non-zero flex but incoming width
        // constraints are unbounded". IntrinsicWidth converts that to a
        // bounded width (max of minWidth and intrinsic content width).
        child: IntrinsicWidth(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerRow(),
                ...rows.map((spec) => _row(context, spec)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerRow() {
    Widget cell(String text, double w, {bool right = false}) => SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            child: Text(
              text,
              textAlign: right ? TextAlign.right : TextAlign.left,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: TreasuryTokens.muted,
                letterSpacing: 0.4,
              ),
            ),
          ),
        );

    return Container(
      color: TreasuryTokens.surfaceAlt,
      child: Row(
        children: [
          const SizedBox(width: 24), // expander gutter
          cell('Code', 60),
          Expanded(child: cell('Activity', 0)),
          cell('Domain', 92),
          cell('Duration', 66, right: true),
          cell('Start', 74, right: true),
          cell('Finish', 74, right: true),
          const SizedBox(width: 60), // actions gutter
        ],
      ),
    );
  }

  Widget _row(BuildContext context, _TreeRowSpec spec) {
    final a = spec.activity;
    final domainColor = Color(a.domain.color);
    final isMilestone = a.type == ActivityType.milestone;

    final durationText = formatDuration(a.duration, a.durationUnit);

    return InkWell(
      onTap: () => _ActivityNode.showActivityEditDialog(
        context,
        activity: a,
        provider: widget.provider,
        isLocked: widget.isLocked,
        isRoot: spec.isRoot,
      ),
      child: Container(
        height: _rowHeight,
        decoration: BoxDecoration(
          border: const Border(
            bottom: BorderSide(color: TreasuryTokens.hairline, width: 0.5),
          ),
          color: spec.isRoot ? TreasuryTokens.surfaceAlt : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24 + spec.depth * _indentWidth,
              child: spec.hasChildren
                  ? InkWell(
                      onTap: () => setState(() {
                        _collapsed.contains(a.id)
                            ? _collapsed.remove(a.id)
                            : _collapsed.add(a.id);
                      }),
                      child: Icon(
                        spec.collapsed
                            ? Icons.keyboard_arrow_right
                            : Icons.keyboard_arrow_down,
                        size: 14,
                        color: TreasuryTokens.muted,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            // Code
            SizedBox(
              width: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Text(
                  a.code,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: appFontFamily,
                    fontWeight: FontWeight.w800,
                    color: isMilestone
                        ? LightModeColors.accent
                        : TreasuryTokens.inkSoft,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Name (with domain dot / milestone diamond)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    if (isMilestone)
                      Transform.rotate(
                        angle: 3.14159 / 4,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: domainColor,
                            border: Border.all(color: Colors.white, width: 0.8),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: domainColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        a.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: TreasuryTokens.ink,
                          fontWeight: spec.isRoot
                              ? FontWeight.w800
                              : (a.type == ActivityType.summary
                                  ? FontWeight.w700
                                  : FontWeight.w500),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Domain
            SizedBox(
              width: 92,
              child: Text(
                a.domain.label,
                style: const TextStyle(
                    fontSize: 10, color: TreasuryTokens.inkSoft),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Duration
            SizedBox(
              width: 66,
              child: Text(
                durationText,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 10,
                  color: TreasuryTokens.info,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            // Start
            SizedBox(
              width: 74,
              child: Text(
                a.startDate != null
                    ? DateFormat('MM/dd/yy').format(a.startDate!)
                    : '—',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF047857),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            // Finish
            SizedBox(
              width: 74,
              child: Text(
                a.endDate != null
                    ? DateFormat('MM/dd/yy').format(a.endDate!)
                    : '—',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFFB45309),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            // Actions
            SizedBox(
              width: 60,
              child: spec.isRoot || widget.isLocked
                  ? const SizedBox.shrink()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 12, color: Color(0xFFB91C1C)),
                          tooltip: 'Delete activity',
                          onPressed: () => confirmActivityRemoval(
                            context,
                            provider: widget.provider,
                            activity: a,
                            isLocked: widget.isLocked,
                          ),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(2),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One visible row of [_ActivityTreeTable].
class _TreeRowSpec {
  const _TreeRowSpec({
    required this.activity,
    required this.depth,
    required this.isRoot,
    required this.hasChildren,
    required this.collapsed,
  });

  final ScheduleActivity activity;
  final int depth;
  final bool isRoot;
  final bool hasChildren;
  final bool collapsed;
}
