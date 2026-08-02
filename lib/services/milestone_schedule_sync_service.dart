import 'package:ndu_project/models/project_data_model.dart' as dm;
import 'package:ndu_project/schedule/models/schedule_models.dart' as sched;

class MilestoneScheduleSyncService {
  MilestoneScheduleSyncService._();

  static const String _importSource = 'fep_milestone';

  /// Converts FEP milestones into schedule [sched.ScheduleActivity] nodes
  /// for the new schedule module.
  static List<sched.ScheduleActivity> toScheduleModuleActivities(
    List<dm.Milestone> milestones,
  ) {
    return milestones.map((m) {
      final dueDate = DateTime.tryParse(m.dueDate);
      return sched.ScheduleActivity(
        id: _fepActivityId(m.id),
        level: 1,
        code: '',
        name: m.name.trim().isEmpty ? 'Untitled milestone' : m.name.trim(),
        description: m.comments.trim().isEmpty ? null : m.comments.trim(),
        type: sched.ActivityType.milestone,
        domain: sched.ScheduleDomain.engineering,
        duration: 0,
        durationUnit: 'days',
        startDate: dueDate,
        endDate: dueDate,
        dependencies: const [],
        owner: null,
        status: 'Not Started',
        aiGenerated: true,
        importSource: _importSource,
        children: const [],
      );
    }).toList();
  }

  /// Converts FEP milestones into legacy [dm.ScheduleActivity] entries.
  static List<dm.ScheduleActivity> toLegacyActivities(
    List<dm.Milestone> milestones,
  ) {
    return milestones.map((m) {
      return dm.ScheduleActivity(
        id: _fepActivityId(m.id),
        title: m.name.trim().isEmpty ? 'Untitled milestone' : m.name.trim(),
        isMilestone: true,
        dueDate: m.dueDate,
        milestone: m.name.trim(),
        discipline: m.discipline.trim(),
        status: 'Not Started',
      );
    }).toList();
  }

  /// Merges FEP milestones into the schedule module's activity tree.
  ///
  /// Adds or updates milestone activities as children of the root node
  /// under a dedicated "Planning Milestones" summary group.
  static sched.ScheduleActivity mergeIntoModuleTree({
    required sched.ScheduleActivity root,
    required List<dm.Milestone> milestones,
  }) {
    final existingIds = <String>{};
    final otherChildren = <sched.ScheduleActivity>[];

    for (final child in root.children) {
      if (child.importSource == _importSource) {
        existingIds.add(child.id);
      } else if (child.name == 'Planning Milestones') {
        existingIds.addAll(child.children.map((c) => c.id));
      } else {
        otherChildren.add(child);
      }
    }

    final fepActivities = toScheduleModuleActivities(milestones);

    if (fepActivities.isEmpty) {
      return root.copyWith(children: otherChildren);
    }

    final milestoneGroup = sched.ScheduleActivity(
      id: '${_importSource}_group',
      level: 1,
      code: '',
      name: 'Planning Milestones',
      type: sched.ActivityType.summary,
      domain: sched.ScheduleDomain.engineering,
      dependencies: const [],
      aiGenerated: true,
      importSource: _importSource,
      children: fepActivities,
    );

    return root.copyWith(
      children: [...otherChildren, milestoneGroup],
    );
  }

  /// Syncs FEP milestones into the legacy schedule activities list.
  static List<dm.ScheduleActivity> mergeIntoLegacyList({
    required List<dm.ScheduleActivity> existing,
    required List<dm.Milestone> milestones,
  }) {
    final existingIds = existing.map((a) => a.id).toSet();
    final fepActivities = toLegacyActivities(milestones);
    final newEntries = fepActivities.where((a) => !existingIds.contains(a.id));
    final existingNonFep =
        existing.where((a) => !a.id.startsWith('${_importSource}_')).toList();
    return [...existingNonFep, ...newEntries];
  }

  /// Checks whether the schedule module tree already has FEP milestones imported.
  static bool hasMilestoneImport(sched.ScheduleActivity root) {
    return root.children.any((c) =>
        c.importSource == _importSource || c.name == 'Planning Milestones');
  }

  /// Counts how many FEP milestone activities are imported in the tree.
  static int countImportedInTree(List<sched.ScheduleActivity> roots) {
    int count = 0;
    void walk(sched.ScheduleActivity node) {
      if (node.importSource == _importSource &&
          node.type == sched.ActivityType.milestone) {
        count++;
      }
      for (final c in node.children) {
        walk(c);
      }
    }
    for (final r in roots) {
      walk(r);
    }
    return count;
  }

  static String _fepActivityId(String milestoneId) {
    return '${_importSource}_$milestoneId';
  }
}
