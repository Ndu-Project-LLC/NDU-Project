import 'package:ndu_project/models/agile_release_plan.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/models/project_data_model.dart';

/// One row of the release-plan table: a release and one of the epics it covers.
class ReleasePlanTableRow {
  const ReleasePlanTableRow({
    required this.release,
    required this.epic,
    required this.milestones,
    required this.storyCount,
    required this.storyPoints,
  });

  final AgileReleasePlan release;

  /// Null when the release links no epic — the row still shows, so a release
  /// with an empty scope is visible instead of silently missing.
  final Epic? epic;

  /// Project milestones this release shows because of [epic] — resolved, never
  /// hand-picked.
  final List<Milestone> milestones;

  final int storyCount;
  final int storyPoints;
}

/// An epic and the milestones the project ties to it, shown as reference on the
/// Release Plan so the user can see what exists before scoping a release.
class EpicMilestoneRow {
  const EpicMilestoneRow({required this.epic, required this.milestones});

  final Epic epic;
  final List<Milestone> milestones;
}

/// The rules behind the Release Plan: which epics a release covers and which
/// project milestones come with them.
///
/// The review complained that the plan "doesn't tell me anything" and asked for
/// it to show the epics and the already-identified milestones, with the
/// milestones tied automatically to their work ("the milestones should be
/// reflected automatically with the associated [WBS] item") and a blank start
/// when nothing is saved. Keeping this pure means all of that is testable
/// without Firestore.
class AgileReleaseScope {
  AgileReleaseScope._();

  /// The marker the UI shows on a milestone it resolved by itself.
  static const String autoBadge = 'AUTO';

  /// A release that starts empty: no label, no scope, no dates.
  ///
  /// "This should start with a blank" — a new plan used to be pre-named
  /// `Release N` with nothing else, which read as content but was not.
  static AgileReleasePlan blankPlan({String? id}) => AgileReleasePlan(id: id);

  /// Every epic id a release covers: the ones it lists, plus any epic reached
  /// through a selected feature, so a release that only picked features still
  /// shows the epic above them.
  static Set<String> scopeEpicIds({
    required AgileReleasePlan release,
    required Map<String, List<Feature>> featuresByEpic,
  }) {
    final ids = <String>{
      for (final id in release.epicIds)
        if (id.trim().isNotEmpty) id,
    };
    if (release.featureIds.isEmpty) return ids;
    for (final entry in featuresByEpic.entries) {
      for (final feature in entry.value) {
        if (release.featureIds.contains(feature.id)) ids.add(entry.key);
      }
    }
    return ids;
  }

  /// The epics a release covers, in epic order.
  static List<Epic> epicsFor({
    required AgileReleasePlan release,
    required List<Epic> epics,
    required Map<String, List<Feature>> featuresByEpic,
  }) {
    final ids =
        scopeEpicIds(release: release, featuresByEpic: featuresByEpic);
    return [for (final epic in epics) if (ids.contains(epic.id)) epic];
  }

  /// Milestone ids the project ties to [epic].
  ///
  /// Two links already exist in the data and both are honoured:
  ///  * **Stories** — `AgileTask.milestoneIds` is how a story records the FEP
  ///    milestones it serves, and a story reaches an epic through its feature.
  ///  * **WBS** — a work package carries `milestoneIds` and names the WBS item
  ///    it belongs to, and an epic carries the WBS element it maps to, so a
  ///    package on the epic's WBS item brings its milestones with it.
  static Set<String> milestoneIdsForEpic({
    required Epic epic,
    required Map<String, List<Feature>> featuresByEpic,
    required List<AgileTask> stories,
    List<WorkPackage> workPackages = const [],
  }) {
    final ids = <String>{};
    final featureIds = <String>{
      for (final feature in featuresByEpic[epic.id] ?? const <Feature>[])
        feature.id,
    };
    for (final story in stories) {
      final inEpic = story.epicId == epic.id ||
          (story.epicId.isEmpty && featureIds.contains(story.featureId));
      if (!inEpic) continue;
      ids.addAll(story.milestoneIds.where((id) => id.trim().isNotEmpty));
    }
    final wbsItem = epic.wbsId.trim();
    if (wbsItem.isNotEmpty) {
      for (final pkg in workPackages) {
        if (pkg.wbsItemId.trim() != wbsItem) continue;
        ids.addAll(pkg.milestoneIds.where((id) => id.trim().isNotEmpty));
      }
    }
    return ids;
  }

  /// The project milestones tied to [epic], in the project's own order.
  static List<Milestone> milestonesForEpic({
    required Epic epic,
    required Map<String, List<Feature>> featuresByEpic,
    required List<AgileTask> stories,
    required List<Milestone> milestones,
    List<WorkPackage> workPackages = const [],
  }) {
    final ids = milestoneIdsForEpic(
      epic: epic,
      featuresByEpic: featuresByEpic,
      stories: stories,
      workPackages: workPackages,
    );
    return [
      for (final milestone in milestones)
        if (ids.contains(milestone.id)) milestone,
    ];
  }

  /// The project milestones a release shows without the user re-selecting them,
  /// in the project's own milestone order.
  static List<Milestone> milestonesForRelease({
    required AgileReleasePlan release,
    required List<Epic> epics,
    required Map<String, List<Feature>> featuresByEpic,
    required List<AgileTask> stories,
    required List<Milestone> milestones,
    List<WorkPackage> workPackages = const [],
  }) {
    final wanted = <String>{};
    for (final epic in epicsFor(
      release: release,
      epics: epics,
      featuresByEpic: featuresByEpic,
    )) {
      wanted.addAll(milestoneIdsForEpic(
        epic: epic,
        featuresByEpic: featuresByEpic,
        stories: stories,
        workPackages: workPackages,
      ));
    }
    return [
      for (final milestone in milestones)
        if (wanted.contains(milestone.id)) milestone,
    ];
  }

  /// Project milestones no release in [releases] claims, so the plan can say
  /// what is still unassigned instead of leaving it invisible.
  static List<Milestone> milestonesOutsideReleases({
    required List<AgileReleasePlan> releases,
    required List<Epic> epics,
    required Map<String, List<Feature>> featuresByEpic,
    required List<AgileTask> stories,
    required List<Milestone> milestones,
    List<WorkPackage> workPackages = const [],
  }) {
    final claimed = <String>{};
    for (final release in releases) {
      for (final milestone in milestonesForRelease(
        release: release,
        epics: epics,
        featuresByEpic: featuresByEpic,
        stories: stories,
        milestones: milestones,
        workPackages: workPackages,
      )) {
        claimed.add(milestone.id);
      }
    }
    return [
      for (final milestone in milestones)
        if (!claimed.contains(milestone.id)) milestone,
    ];
  }

  /// Stories credited to [epic] for [release]: the ones the release lists, plus
  /// every story under the epic once the whole epic is in scope.
  static List<AgileTask> storiesForEpic({
    required AgileReleasePlan release,
    required Epic epic,
    required Map<String, List<Feature>> featuresByEpic,
    required List<AgileTask> stories,
  }) {
    final featureIds = <String>{
      for (final feature in featuresByEpic[epic.id] ?? const <Feature>[])
        feature.id,
    };
    final epicInScope = release.epicIds.contains(epic.id);
    return [
      for (final story in stories)
        if (story.epicId == epic.id ||
            featureIds.contains(story.featureId))
          if (epicInScope || release.storyIds.contains(story.id)) story,
    ];
  }

  /// Rows for the release-plan table, one per release and the epic it covers.
  /// A release with no epics contributes a single row with a null epic.
  static List<ReleasePlanTableRow> tableRows({
    required List<AgileReleasePlan> releases,
    required List<Epic> epics,
    required Map<String, List<Feature>> featuresByEpic,
    required List<AgileTask> stories,
    required List<Milestone> milestones,
    List<WorkPackage> workPackages = const [],
  }) {
    final rows = <ReleasePlanTableRow>[];
    for (final release in releases) {
      final releaseEpics = epicsFor(
        release: release,
        epics: epics,
        featuresByEpic: featuresByEpic,
      );
      final releaseMilestones = milestonesForRelease(
        release: release,
        epics: epics,
        featuresByEpic: featuresByEpic,
        stories: stories,
        milestones: milestones,
        workPackages: workPackages,
      );
      if (releaseEpics.isEmpty) {
        final listed = [
          for (final story in stories)
            if (release.storyIds.contains(story.id)) story,
        ];
        rows.add(ReleasePlanTableRow(
          release: release,
          epic: null,
          milestones: releaseMilestones,
          storyCount: listed.length,
          storyPoints:
              listed.fold<int>(0, (sum, story) => sum + story.storyPoints),
        ));
        continue;
      }
      for (final epic in releaseEpics) {
        final epicStories = storiesForEpic(
          release: release,
          epic: epic,
          featuresByEpic: featuresByEpic,
          stories: stories,
        );
        rows.add(ReleasePlanTableRow(
          release: release,
          epic: epic,
          milestones: milestonesForEpic(
            epic: epic,
            featuresByEpic: featuresByEpic,
            stories: stories,
            milestones: milestones,
            workPackages: workPackages,
          ),
          storyCount: epicStories.length,
          storyPoints: epicStories.fold<int>(
              0, (sum, story) => sum + story.storyPoints),
        ));
      }
    }
    return rows;
  }

  /// The project's epics and the milestones tied to each, for the reference
  /// section above the plan.
  static List<EpicMilestoneRow> epicMilestoneRows({
    required List<Epic> epics,
    required Map<String, List<Feature>> featuresByEpic,
    required List<AgileTask> stories,
    required List<Milestone> milestones,
    List<WorkPackage> workPackages = const [],
  }) {
    return [
      for (final epic in epics)
        EpicMilestoneRow(
          epic: epic,
          milestones: milestonesForEpic(
            epic: epic,
            featuresByEpic: featuresByEpic,
            stories: stories,
            milestones: milestones,
            workPackages: workPackages,
          ),
        ),
    ];
  }
}
