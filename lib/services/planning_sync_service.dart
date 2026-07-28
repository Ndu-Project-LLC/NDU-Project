import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/project_data_model.dart' as dm;
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/integrated_work_package_service.dart';
import 'package:ndu_project/services/milestone_schedule_sync_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

/// Result returned by [PlanningSyncService.syncAll].
class PlanningSyncResult {
  final int packagesImported;
  final int storiesImported;
  final int milestonesImported;

  const PlanningSyncResult({
    this.packagesImported = 0,
    this.storiesImported = 0,
    this.milestonesImported = 0,
  });

  int get total => packagesImported + storiesImported + milestonesImported;

  String get message {
    final parts = <String>[];
    if (packagesImported > 0) parts.add('$packagesImported work packages');
    if (storiesImported > 0) parts.add('$storiesImported agile stories');
    if (milestonesImported > 0) parts.add('$milestonesImported milestones');
    if (parts.isEmpty) return 'No new items to import';
    return 'Imported ${parts.join(', ')}';
  }
}

/// Unified service that syncs all planning-phase items (EWPs, agile stories,
/// FEP milestones) into the schedule activity tree in one pass.
///
/// Called once on first module load and on-demand via "Resync from Planning".
class PlanningSyncService {
  PlanningSyncService._();

  /// Tag used to identify nodes imported by this service so they can be
  /// replaced during a resync.
  static const String importSourceWorkPackage = 'work_package';
  static const String importSourceAgileStory = 'agile_story';
  static const String importSourceMilestone = 'fep_milestone';

  /// The set of all import sources managed by this service.
  static const Set<String> _managedSources = {
    importSourceWorkPackage,
    importSourceAgileStory,
    importSourceMilestone,
  };

  static const String _milestoneGroupId = 'planning_sync_milestones';

  /// Sync all planning items into the schedule provider tree.
  ///
  /// [replaceExisting] — if true, replaces all previously imported nodes.
  /// If false (default), only imports items not already present.
  static Future<PlanningSyncResult> syncAll({
    required BuildContext context,
    required ScheduleProvider provider,
    bool replaceExisting = false,
  }) async {
    final schedule = provider.schedule;
    if (schedule == null) return const PlanningSyncResult();

    final data = ProjectDataHelper.getData(context, listen: false);
    var root = schedule.activities[0];

    // Preserve user-created nodes (those not managed by this service).
    final preserved = <ScheduleActivity>[];
    for (final child in root.children) {
      if (!_managedSources.contains(child.importSource) &&
          child.name != 'Planning Milestones') {
        preserved.add(child);
      }
    }

    int packages = 0;
    int stories = 0;
    int milestones = 0;

    // 1) Import work packages
    final allMs = data.keyMilestones;
    final packageActivities = _buildPackageActivities(data.workPackages, allMs);
    preserved.addAll(packageActivities);
    packages = packageActivities.length;

    // 2) Import agile stories
    if (data.projectId != null && data.projectId!.isNotEmpty) {
      final storyActivities = await _buildStoryActivities(
        projectId: data.projectId!,
        context: context,
      );
      preserved.addAll(storyActivities);
      stories = storyActivities.length;
    }

    // 3) Import FEP milestones
    final fepMilestones = data.keyMilestones
        .where((m) => m.name.trim().isNotEmpty)
        .toList();
    if (fepMilestones.isNotEmpty) {
      final milestoneActivities =
          MilestoneScheduleSyncService.toScheduleModuleActivities(
              fepMilestones);
      preserved.add(
        ScheduleActivity(
          id: _milestoneGroupId,
          level: 1,
          code: '',
          name: 'Planning Milestones',
          type: ActivityType.summary,
          domain: ScheduleDomain.engineering,
          dependencies: const [],
          aiGenerated: true,
          importSource: importSourceMilestone,
          children: milestoneActivities,
        ),
      );
      milestones = milestoneActivities.length;
    }

    final updatedRoot = recalcActivityCodes(
      root.copyWith(children: preserved),
    );
    provider.setActivities([updatedRoot]);

    return PlanningSyncResult(
      packagesImported: packages,
      storiesImported: stories,
      milestonesImported: milestones,
    );
  }

  /// Builds [ScheduleActivity] nodes from [WorkPackage]s.
  static List<ScheduleActivity> _buildPackageActivities(
      List<dm.WorkPackage> packages,
      List<dm.Milestone> allMilestones) {
    if (packages.isEmpty) return const [];

    String milestoneNamesFor(List<String> ids) {
      final names = allMilestones
          .where((m) => ids.contains(m.id) && m.name.trim().isNotEmpty)
          .map((m) => m.name.trim())
          .toList();
      return names.isEmpty ? '' : 'Milestones: ${names.join(', ')}';
    }

    final pkgToActId = <String, String>{};
    for (final pkg in packages) {
      pkgToActId[pkg.id] = newSchedId('pkg');
    }
    final packageIdSet = packages.map((p) => p.id).toSet();

    List<String> depPackageIds(dm.WorkPackage pkg) {
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

    ScheduleDomain domainForPackage(dm.WorkPackage pkg) {
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

    ActivityType typeForPackage(dm.WorkPackage pkg) {
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

    String formatPackageName(dm.WorkPackage pkg) {
      final readable = pkg.packageClassification
          .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}')
          .trim();
      final title = pkg.title.isNotEmpty ? pkg.title : 'Untitled';
      return '$readable: $title';
    }

    final activities = <ScheduleActivity>[];
    for (final pkg in packages) {
      final domain = domainForPackage(pkg);
      final activityType = typeForPackage(pkg);
      final activityId = pkgToActId[pkg.id]!;

      final depPkgIds = depPackageIds(pkg);
      final dependencies = depPkgIds
          .where((depId) => pkgToActId.containsKey(depId))
          .map((depId) => ActivityDependency(
                activityId: pkgToActId[depId]!,
                type: DependencyType.finishToStart,
              ))
          .toList();

      final level = pkg.wbsLevel2Id.isNotEmpty ? 3 : 2;
      final descBuf = StringBuffer();
      if (pkg.description.isNotEmpty) descBuf.writeln(pkg.description);
      if (pkg.deliverables.isNotEmpty) {
        descBuf.writeln(
            'Deliverables: ${pkg.deliverables.map((d) => d.title).join(', ')}');
      }
      final msNames = milestoneNamesFor(pkg.milestoneIds);
      if (msNames.isNotEmpty) descBuf.writeln(msNames);

      activities.add(ScheduleActivity(
        id: activityId,
        level: level,
        code: '',
        name: formatPackageName(pkg),
        description: descBuf.toString().trim(),
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
        importSource: importSourceWorkPackage,
        children: [],
      ));
    }

    return activities;
  }

  /// Builds [ScheduleActivity] nodes from agile stories.
  static Future<List<ScheduleActivity>> _buildStoryActivities({
    required String projectId,
    required BuildContext context,
  }) async {
    final data = ProjectDataHelper.getData(context, listen: false);
    final stories = await ExecutionPhaseService.loadAgileTasks(projectId: projectId);

    if (stories.isEmpty) return const [];

    // Group by epic → feature
    final Map<String, Map<String, List<AgileTask>>> grouped = {};
    for (final story in stories) {
      grouped.putIfAbsent(story.epicId, () => {});
      grouped[story.epicId]!.putIfAbsent(story.featureId, () => []);
      grouped[story.epicId]![story.featureId]!.add(story);
    }

    final List<ScheduleActivity> epicActivities = [];
    for (final epicEntry in grouped.entries) {
      final featureActivities = <ScheduleActivity>[];
      for (final featureEntry in epicEntry.value.entries) {
        final storyActivities = featureEntry.value.map((s) {
          final descBuf = StringBuffer();
          if (s.taskDescription.isNotEmpty) descBuf.writeln(s.taskDescription);
          if (s.milestoneIds.isNotEmpty) {
            final milestoneNames = _resolveMilestoneNamesForTask(
                s.milestoneIds, data.keyMilestones);
            if (milestoneNames.isNotEmpty) {
              descBuf.writeln('Milestones: ${milestoneNames.join(', ')}');
            }
          }
          return ScheduleActivity(
            id: newSchedId('stry'),
            level: 4,
            code: '',
            name: s.userStory,
            description: descBuf.toString().trim(),
            type: ActivityType.activity,
            domain: ScheduleDomain.execution,
            duration: null,
            dependencies: [],
            storyPoints: s.storyPoints.toDouble(),
            sprintId: s.plannedSprintId.isNotEmpty ? s.plannedSprintId : null,
            releaseId:
                s.plannedReleaseId.isNotEmpty ? s.plannedReleaseId : null,
            agileEpicTitle: epicEntry.key,
            agileFeatureTitle: featureEntry.key,
            estimationMethod: EstimationMethod.storyPoints,
            aiGenerated: false,
            children: [],
            agileTaskId: s.id,
            wbsNodeId: s.wbsId.isNotEmpty ? s.wbsId : null,
            importSource: importSourceAgileStory,
            prerequisites: s.dependencyTaskIds.isEmpty
                ? null
                : List<String>.from(s.dependencyTaskIds),
          );
        }).toList();

        featureActivities.add(
          ScheduleActivity(
            id: newSchedId('feat'),
            level: 3,
            code: '',
            name: featureEntry.key,
            type: ActivityType.summary,
            domain: ScheduleDomain.execution,
            dependencies: [],
            aiGenerated: false,
            children: storyActivities,
          ),
        );
      }

      epicActivities.add(
        ScheduleActivity(
          id: newSchedId('epic'),
          level: 2,
          code: '',
          name: epicEntry.key,
          type: ActivityType.summary,
          domain: ScheduleDomain.execution,
          dependencies: [],
          aiGenerated: false,
          children: featureActivities,
        ),
      );
    }

    return epicActivities;
  }

  static List<String> _resolveMilestoneNamesForTask(
    List<String> milestoneIds,
    List<dm.Milestone> allMilestones,
  ) {
    final ids = Set<String>.from(milestoneIds);
    return allMilestones
        .where((m) => ids.contains(m.id) && m.name.trim().isNotEmpty)
        .map((m) => m.name.trim())
        .toList();
  }
}
