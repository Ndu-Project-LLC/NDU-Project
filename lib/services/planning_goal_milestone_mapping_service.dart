import 'package:ndu_project/models/project_data_model.dart';

class PlanningGoalMilestoneMappingResult {
  final List<PlanningGoal> planningGoals;
  final List<Milestone> keyMilestones;
  final bool changed;

  const PlanningGoalMilestoneMappingResult({
    required this.planningGoals,
    required this.keyMilestones,
    required this.changed,
  });
}

class PlanningGoalMilestoneMappingService {
  PlanningGoalMilestoneMappingService._();

  static PlanningGoalMilestoneMappingResult migrateLegacyMappings({
    required List<PlanningGoal> planningGoals,
    required List<Milestone> keyMilestones,
  }) {
    var changed = false;
    final normalizedMilestones = <Milestone>[];
    final milestoneByKey = <String, Milestone>{};

    for (final milestone in keyMilestones) {
      final normalized = _ensureMilestoneId(milestone);
      if (!identical(normalized, milestone)) changed = true;
      normalizedMilestones.add(normalized);
      final key = _milestoneMatchKey(normalized.name, normalized.dueDate);
      if (key.isNotEmpty) {
        milestoneByKey.putIfAbsent(key, () => normalized);
      }
    }

    final updatedGoals = <PlanningGoal>[];

    for (final goal in planningGoals) {
      final updatedGoal = _ensureGoalId(goal);
      var goalChanged = !identical(updatedGoal, goal);
      final mergedIds = <String>{
        ...updatedGoal.milestoneIds.where((id) => id.trim().isNotEmpty)
      };

      if (mergedIds.isEmpty) {
        for (final legacyMilestone in updatedGoal.milestones) {
          final title = legacyMilestone.title.trim();
          final deadline = legacyMilestone.deadline.trim();
          if (title.isEmpty && deadline.isEmpty) continue;

          final key = _milestoneMatchKey(title, deadline);
          Milestone? match = key.isNotEmpty ? milestoneByKey[key] : null;
          if (match == null) {
            match = Milestone(
              name: title,
              dueDate: deadline,
              comments: 'Migrated from planning goal milestone',
            );
            normalizedMilestones.add(match);
            if (key.isNotEmpty) {
              milestoneByKey[key] = match;
            }
            changed = true;
          }
          mergedIds.add(match.id);
        }

        if (mergedIds.isNotEmpty) {
          goalChanged = true;
        }
      }

      updatedGoals.add(
        goalChanged
            ? PlanningGoal(
                id: updatedGoal.id,
                goalNumber: updatedGoal.goalNumber,
                title: updatedGoal.title,
                description: updatedGoal.description,
                targetYear: updatedGoal.targetYear,
                priority: updatedGoal.priority,
                milestoneIds: mergedIds.toList(),
                milestones: updatedGoal.milestones,
              )
            : updatedGoal,
      );
      changed = changed || goalChanged;
    }

    return PlanningGoalMilestoneMappingResult(
      planningGoals: updatedGoals,
      keyMilestones: normalizedMilestones,
      changed: changed,
    );
  }

  static PlanningGoal _ensureGoalId(PlanningGoal goal) {
    if (goal.id.trim().isNotEmpty) return goal;
    return PlanningGoal(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      goalNumber: goal.goalNumber,
      title: goal.title,
      description: goal.description,
      targetYear: goal.targetYear,
      priority: goal.priority,
      milestoneIds: goal.milestoneIds,
      milestones: goal.milestones,
    );
  }

  static Milestone _ensureMilestoneId(Milestone milestone) {
    if (milestone.id.trim().isNotEmpty) return milestone;
    return Milestone(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: milestone.name,
      discipline: milestone.discipline,
      dueDate: milestone.dueDate,
      references: milestone.references,
      comments: milestone.comments,
    );
  }

  static String _milestoneMatchKey(String title, String dueDate) {
    final normalizedTitle = _normalize(title);
    final normalizedDate = _normalize(dueDate);
    if (normalizedTitle.isEmpty && normalizedDate.isEmpty) return '';
    return '$normalizedTitle|$normalizedDate';
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
