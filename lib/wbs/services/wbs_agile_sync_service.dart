import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/services/epic_feature_service.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';

/// Result summary returned by [WbsAgileSyncService.syncWbsToAgile].
class WbsAgileSyncResult {
  final int epicsCreated;
  final int featuresCreated;
  final int storiesCreated;

  const WbsAgileSyncResult({
    required this.epicsCreated,
    required this.featuresCreated,
    required this.storiesCreated,
  });

  int get total => epicsCreated + featuresCreated + storiesCreated;
}

/// Synchronises the WBS tree (for Agile framework) into Firestore Epic,
/// Feature and AgileTask (Story) records.
///
/// Only operates on nodes whose effective methodology is Agile.
/// Sync is additive — existing records matched by wbsId are not overwritten.
class WbsAgileSyncService {
  /// Walk the given WBS tree and create Epic/Feature/Story records in
  /// Firestore for any WBS nodes that do not yet have corresponding records.
  static Future<WbsAgileSyncResult> syncWbsToAgile({
    required String projectId,
    required WBS wbs,
  }) async {
    if (wbs.methodology == ProjectMethodology.waterfall) {
      return const WbsAgileSyncResult(
        epicsCreated: 0,
        featuresCreated: 0,
        storiesCreated: 0,
      );
    }

    return _syncNode(
      projectId: projectId,
      node: wbs.level0,
      wbs: wbs,
    );
  }

  static Future<WbsAgileSyncResult> _syncNode({
    required String projectId,
    required WBSNode node,
    required WBS wbs,
    String? parentEpicId,
    String? parentFeatureId,
  }) async {
    int epicsCreated = 0;
    int featuresCreated = 0;
    int storiesCreated = 0;

    for (final child in node.children) {
      final effectiveMethodology =
          child.methodology ?? wbs.methodology.name;
      if (effectiveMethodology == 'waterfall') continue;

      final level = child.level.value;

      if (level == 1) {
        // Level 1 → Epic
        final existingEpics = await EpicFeatureService.loadEpics(projectId);
        final match = existingEpics.where((e) => e.wbsId == child.id);

        String epicId;
        if (match.isEmpty) {
          final epic = Epic(
            title: child.name,
            description: child.description ?? '',
            wbsId: child.id,
          );
          await EpicFeatureService.saveEpic(
            projectId: projectId,
            epic: epic,
          );
          epicId = epic.id;
          epicsCreated++;
        } else {
          epicId = match.first.id;
        }

        // Recurse into Level 1 children to create Features
        final sub = await _syncNode(
          projectId: projectId,
          node: child,
          wbs: wbs,
          parentEpicId: epicId,
        );
        epicsCreated += sub.epicsCreated;
        featuresCreated += sub.featuresCreated;
        storiesCreated += sub.storiesCreated;
      } else if (level == 2 && parentEpicId != null) {
        // Level 2 → Feature
        final existingFeatures = await EpicFeatureService.loadFeatures(
          projectId,
          parentEpicId,
        );
        final match =
            existingFeatures.where((f) => f.wbsId == child.id);

        String featureId;
        if (match.isEmpty) {
          final feature = Feature(
            epicId: parentEpicId,
            title: child.name,
            description: child.description ?? '',
            wbsId: child.id,
          );
          await EpicFeatureService.saveFeature(
            projectId: projectId,
            epicId: parentEpicId,
            feature: feature,
          );
          featureId = feature.id;
          featuresCreated++;
        } else {
          featureId = match.first.id;
        }

        // Recurse into Level 2 children to create Stories
        final sub = await _syncNode(
          projectId: projectId,
          node: child,
          wbs: wbs,
          parentEpicId: parentEpicId,
          parentFeatureId: featureId,
        );
        featuresCreated += sub.featuresCreated;
        storiesCreated += sub.storiesCreated;
      } else if (level == 3 && parentFeatureId != null && parentEpicId != null) {
        // Level 3 → Story (AgileTask)
        final existingTasks = await ExecutionPhaseService.loadAgileTasks(
          projectId: projectId,
        );
        final match =
            existingTasks.where((t) => t.wbsId == child.id);

        if (match.isEmpty) {
          final task = AgileTask(
            userStory: child.name,
            taskDescription: child.description ?? '',
            epicId: parentEpicId,
            featureId: parentFeatureId,
            wbsId: child.id,
          );
          existingTasks.add(task);
          await ExecutionPhaseService.saveAgileTasks(
            projectId: projectId,
            tasks: existingTasks,
          );
          storiesCreated++;
        }
      } else {
        // Deeper levels — just recurse to find any Agile nodes
        final sub = await _syncNode(
          projectId: projectId,
          node: child,
          wbs: wbs,
          parentEpicId: parentEpicId,
          parentFeatureId: parentFeatureId,
        );
        epicsCreated += sub.epicsCreated;
        featuresCreated += sub.featuresCreated;
        storiesCreated += sub.storiesCreated;
      }
    }

    return WbsAgileSyncResult(
      epicsCreated: epicsCreated,
      featuresCreated: featuresCreated,
      storiesCreated: storiesCreated,
    );
  }
}
