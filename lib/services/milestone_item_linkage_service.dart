import 'package:flutter/material.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/milestone_picker_dialog.dart';

class MilestoneItemLinkageService {
  MilestoneItemLinkageService._();

  /// Opens a dialog to pick milestones for a work package.
  /// Returns the updated [WorkPackage] with selected milestone IDs,
  /// or null if the user cancelled.
  static Future<WorkPackage?> pickForWorkPackage({
    required BuildContext context,
    required WorkPackage workPackage,
    required List<Milestone> allMilestones,
  }) async {
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => MilestonePickerDialog(
        title: 'Link Milestones — ${workPackage.title}',
        allMilestones: allMilestones,
        selectedIds: workPackage.milestoneIds,
      ),
    );
    if (picked == null) return null;
    return workPackage.copyWith(milestoneIds: picked);
  }

  /// Opens a dialog to pick milestones for an agile task.
  /// Returns the updated [AgileTask] with selected milestone IDs,
  /// or null if the user cancelled.
  static Future<AgileTask?> pickForAgileTask({
    required BuildContext context,
    required AgileTask task,
    required List<Milestone> allMilestones,
  }) async {
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => MilestonePickerDialog(
        title: 'Link Milestones — ${task.userStory}',
        allMilestones: allMilestones,
        selectedIds: task.milestoneIds,
      ),
    );
    if (picked == null) return null;
    return task.copyWith(milestoneIds: picked);
  }

  /// Returns goal labels for milestones linked to a given work package.
  static List<String> linkedMilestoneNames(
    WorkPackage workPackage,
    List<Milestone> allMilestones,
  ) {
    final ids = Set<String>.from(workPackage.milestoneIds);
    return allMilestones
        .where((m) => ids.contains(m.id) && m.name.trim().isNotEmpty)
        .map((m) => m.name.trim())
        .toList();
  }

  /// Returns goal labels for milestones linked to a given agile task.
  static List<String> linkedMilestoneNamesForTask(
    AgileTask task,
    List<Milestone> allMilestones,
  ) {
    final ids = Set<String>.from(task.milestoneIds);
    return allMilestones
        .where((m) => ids.contains(m.id) && m.name.trim().isNotEmpty)
        .map((m) => m.name.trim())
        .toList();
  }

  /// Loads all milestones from the project data.
  static List<Milestone> loadMilestones(BuildContext context) {
    try {
      return ProjectDataHelper.getData(context, listen: false).keyMilestones;
    } catch (e) {
      debugPrint('MilestoneItemLinkageService.loadMilestones error: $e');
      return [];
    }
  }
}
