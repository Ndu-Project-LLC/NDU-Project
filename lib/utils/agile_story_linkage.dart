import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';

/// The rule the review asked for: **every story belongs to a feature**, and the
/// feature's epic is the story's epic.
///
/// Epic → Feature → Story is the chain the backlog rolls up through ("every
/// story comes from the feature … you have to be linked to one of the
/// features"), so a story that sits under no feature can reach nothing. Every
/// place that creates a story or re-parents one goes through here, so the two
/// ids cannot drift apart.
class AgileStoryLinkage {
  AgileStoryLinkage._();

  /// Default title for a story spawned from a feature.
  static const String defaultStoryTitle = 'New story';

  /// Put [story] under [feature]: the feature's id plus the epic that feature
  /// belongs to, replacing whatever the story pointed at before.
  static AgileTask link(AgileTask story, Feature feature) => story.copyWith(
        featureId: feature.id,
        epicId: feature.epicId,
      );

  /// A new story under [feature], ordered after the stories [existing] already
  /// holds for it.
  ///
  /// The order is the highest one in use plus one, not a count of siblings, so
  /// deleting a story and adding another cannot hand two stories the same
  /// backlog position.
  static AgileTask newStoryFor({
    required Feature feature,
    Iterable<AgileTask> existing = const [],
    String? title,
  }) {
    final siblings = existing.where((story) => story.featureId == feature.id);
    final lastOrder = siblings.isEmpty
        ? 0
        : siblings
            .map((story) => story.backlogOrder)
            .reduce((a, b) => a > b ? a : b);
    final order = lastOrder + 1;
    final trimmed = title?.trim() ?? '';
    return AgileTask(
      epicId: feature.epicId,
      featureId: feature.id,
      userStory: trimmed.isEmpty ? '$defaultStoryTitle $order' : trimmed,
      storyPoints: 3,
      priority: 'Medium',
      status: 'To-Do',
      readinessStatus: 'Draft',
      backlogOrder: order,
    );
  }

  /// Whether [story]'s feature link resolves to a feature we can see.
  ///
  /// Stories created before this rule existed have no feature id, so callers
  /// must treat `false` as "surface it and offer to fix it", not "hide it".
  static bool isLinked(
    AgileTask story, {
    required Map<String, List<Feature>> featuresByEpic,
  }) =>
      featureFor(story, featuresByEpic: featuresByEpic) != null;

  /// How many of [stories] are not under a resolvable feature.
  ///
  /// Used to report the gap on save rather than block it: a story that is not
  /// linked is still the user's work, but the backlog has to say how many are
  /// drifting outside the epic → feature → story chain.
  static int countUnlinked(
    Iterable<AgileTask> stories, {
    required Map<String, List<Feature>> featuresByEpic,
  }) =>
      stories
          .where((story) =>
              !isLinked(story, featuresByEpic: featuresByEpic))
          .length;

  /// The feature [story] points at, or null when it points at nothing or at a
  /// feature that no longer exists.
  static Feature? featureFor(
    AgileTask story, {
    required Map<String, List<Feature>> featuresByEpic,
  }) {
    if (story.featureId.isEmpty) return null;
    for (final features in featuresByEpic.values) {
      for (final feature in features) {
        if (feature.id == story.featureId) return feature;
      }
    }
    return null;
  }

  /// Every feature across [epics], in epic then feature order.
  static List<Feature> allFeatures({
    required List<Epic> epics,
    required Map<String, List<Feature>> featuresByEpic,
  }) =>
      [
        for (final epic in epics)
          ...featuresByEpic[epic.id] ?? const <Feature>[],
      ];

  /// Picker label for a feature: "Epic · Feature", falling back for unnamed
  /// rows so an option is never blank.
  static String optionLabel({
    required Feature feature,
    required String epicTitle,
  }) {
    final epic = epicTitle.trim().isEmpty ? 'Untitled epic' : epicTitle.trim();
    final name =
        feature.title.trim().isEmpty ? 'Untitled feature' : feature.title.trim();
    return '$epic · $name';
  }

  /// Feature id → "Epic · Feature" label, for feature pickers.
  static Map<String, String> optionLabels({
    required List<Epic> epics,
    required Map<String, List<Feature>> featuresByEpic,
  }) =>
      {
        for (final epic in epics)
          for (final feature in featuresByEpic[epic.id] ?? const <Feature>[])
            feature.id: optionLabel(feature: feature, epicTitle: epic.title),
      };
}
