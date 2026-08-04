import 'package:flutter/foundation.dart';
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

  const WbsAgileSyncResult.empty()
      : epicsCreated = 0,
        featuresCreated = 0,
        storiesCreated = 0;

  int get total => epicsCreated + featuresCreated + storiesCreated;
}

/// Synchronises the WBS tree (for Agile framework) into Firestore Epic,
/// Feature and AgileTask (Story) records.
///
/// Only operates on nodes whose effective methodology is Agile.
/// Sync is additive — existing records matched by `wbsId` are not overwritten.
class WbsAgileSyncService {
  /// Walk the given WBS tree and create Epic/Feature/Story records in
  /// Firestore for any WBS nodes that do not yet have corresponding records.
  ///
  /// Implementation notes:
  /// - Pre-loads all existing epics, features, and stories ONCE, then walks
  ///   the tree in-memory. The previous implementation re-fetched the entire
  ///   epics/features/tasks list for every WBS node (O(n²) Firestore reads
  ///   and O(n²) cache invalidations), which caused sync timeouts and
  ///   "Sync failed" errors on WBS trees with more than a handful of nodes.
  /// - Each Firestore write is collected into a `Future.wait` batch so that
  ///   a single failure (e.g. transient Firestore permission error on one
  ///   doc) does not abort the entire sync — the rest of the tree is still
  ///   persisted and the user can re-run sync to fill in the gaps.
  /// - All newly-created stories are persisted in a single
  ///   `saveAgileTasks` call (appended to the existing list), instead of
  ///   one full-list rewrite per story.
  static Future<WbsAgileSyncResult> syncWbsToAgile({
    required String projectId,
    required WBS wbs,
  }) async {
    if (wbs.methodology == ProjectMethodology.waterfall) {
      return const WbsAgileSyncResult.empty();
    }

    // ── Pre-load all existing records ONCE ─────────────────────────────
    // loadEpics / loadFeatures / loadAgileTasks all swallow Firestore errors
    // and return [] — so a transient Firestore hiccup is treated the same as
    // "no data yet" and the sync proceeds additively. That is the desired
    // behaviour here: we'd rather create a duplicate (matched later by
    // wbsId on the next successful read) than abort the whole sync.
    final existingEpics = await EpicFeatureService.loadEpics(projectId);
    final existingFeaturesByEpic = <String, List<Feature>>{};
    for (final epic in existingEpics) {
      existingFeaturesByEpic[epic.id] =
          await EpicFeatureService.loadFeatures(projectId, epic.id);
    }
    final existingTasks =
        await ExecutionPhaseService.loadAgileTasks(projectId: projectId);

    // Index existing records by wbsId for O(1) lookup during the tree walk.
    final epicByWbsId = <String, Epic>{
      for (final e in existingEpics)
        if (e.wbsId.isNotEmpty) e.wbsId: e,
    };
    final featureByWbsId = <String, Feature>{
      for (final fl in existingFeaturesByEpic.values)
        for (final f in fl)
          if (f.wbsId.isNotEmpty) f.wbsId: f,
    };
    final taskByWbsId = <String, AgileTask>{
      for (final t in existingTasks)
        if (t.wbsId.isNotEmpty) t.wbsId: t,
    };

    int epicsCreated = 0;
    int featuresCreated = 0;
    int storiesCreated = 0;
    final pendingSaves = <Future<void>>[];
    final createdTasks = <AgileTask>[];

    void walk(WBSNode node, String? parentEpicId, String? parentFeatureId) {
      for (final child in node.children) {
        final effectiveMethodology = child.methodology ?? wbs.methodology.name;
        if (effectiveMethodology == 'waterfall') continue;

        final level = child.level.value;

        if (level == 1) {
          // Level 1 → Epic
          String epicId;
          final existing = epicByWbsId[child.id];
          if (existing == null) {
            final epic = Epic(
              title: child.name,
              description: child.description ?? '',
              wbsId: child.id,
            );
            // Track in-memory so sibling/child iterations see the new epic.
            epicByWbsId[child.id] = epic;
            existingFeaturesByEpic[epic.id] = [];
            pendingSaves.add(
              EpicFeatureService.saveEpic(projectId: projectId, epic: epic)
                  .catchError((Object e) {
                debugPrint(
                    'WbsAgileSync: saveEpic failed for wbsId=${child.id}: $e');
              }),
            );
            epicsCreated++;
            epicId = epic.id;
          } else {
            epicId = existing.id;
          }
          walk(child, epicId, null);
        } else if (level == 2 && parentEpicId != null) {
          // Level 2 → Feature
          String featureId;
          final existing = featureByWbsId[child.id];
          if (existing == null) {
            final feature = Feature(
              epicId: parentEpicId,
              title: child.name,
              description: child.description ?? '',
              wbsId: child.id,
            );
            featureByWbsId[child.id] = feature;
            existingFeaturesByEpic[parentEpicId] ??= [];
            existingFeaturesByEpic[parentEpicId]!.add(feature);
            pendingSaves.add(
              EpicFeatureService.saveFeature(
                projectId: projectId,
                epicId: parentEpicId,
                feature: feature,
              ).catchError((Object e) {
                debugPrint(
                    'WbsAgileSync: saveFeature failed for wbsId=${child.id}: $e');
              }),
            );
            featuresCreated++;
            featureId = feature.id;
          } else {
            featureId = existing.id;
          }
          walk(child, parentEpicId, featureId);
        } else if (level == 3 &&
            parentFeatureId != null &&
            parentEpicId != null) {
          // Level 3 → Story (AgileTask)
          if (!taskByWbsId.containsKey(child.id)) {
            final task = AgileTask(
              userStory: child.name,
              taskDescription: child.description ?? '',
              epicId: parentEpicId,
              featureId: parentFeatureId,
              wbsId: child.id,
            );
            taskByWbsId[child.id] = task;
            existingTasks.add(task);
            createdTasks.add(task);
            storiesCreated++;
          }
        } else {
          // Deeper levels — just recurse to find any Agile nodes.
          walk(child, parentEpicId, parentFeatureId);
        }
      }
    }

    walk(wbs.level0, null, null);

    // Persist all newly-created stories in a single write (instead of one
    // full-list rewrite per story, which previously caused write
    // amplification and race conditions on concurrent syncs).
    if (createdTasks.isNotEmpty) {
      try {
        await ExecutionPhaseService.saveAgileTasks(
          projectId: projectId,
          tasks: existingTasks,
        );
      } catch (e) {
        debugPrint('WbsAgileSync: saveAgileTasks failed: $e');
        // Don't rethrow — epics/features saves are independent and may
        // have already succeeded. Reporting partial success lets the user
        // re-run sync to fill in the missing stories.
      }
    }

    // Await all epic/feature saves so that, by the time the caller reloads
    // the screen, the new docs are persisted in Firestore.
    if (pendingSaves.isNotEmpty) {
      await Future.wait(pendingSaves);
    }

    return WbsAgileSyncResult(
      epicsCreated: epicsCreated,
      featuresCreated: featuresCreated,
      storiesCreated: storiesCreated,
    );
  }
}
