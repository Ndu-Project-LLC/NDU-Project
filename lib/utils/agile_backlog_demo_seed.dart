import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/feature_model.dart';

/// Seeds a demo-ready backlog (Lusaka 27 follow-up).
///
/// The owner, ahead of the schedule/cost walkthrough:
///
///   "if you're going to demonstrate this … build us stories there, some story
///    points and stuff like that. And then all the features … so that way we
///    can test the schedule … it should meet the milestones and the timeline."
///
/// So: two to three sized stories per feature, every story linked to its
/// feature (and through it the epic), with story points, priority and To-Do
/// status — the same `AgileTask` items execution Kanban and the schedule
/// import read. Pure module: it decides nothing about persistence, the screen
/// saves the result the same way it saves an added story.
class AgileBacklogDemoSeed {
  AgileBacklogDemoSeed._();

  /// Story points cycle so the demo shows varied sizes, not a wall of 3s.
  static const List<int> _pointCycle = [3, 5, 2, 8];

  /// Ties the cycle to the feature so sibling features differ.
  static int _pointsFor(int featureIndex, int storyIndex) =>
      _pointCycle[(featureIndex * 2 + storyIndex) % _pointCycle.length];

  static const List<String> _priorities = ['High', 'Medium', 'Low'];

  /// Stories to seed for [feature]: 2 for the first feature of an epic, 3 for
  /// later ones — enough to prioritise, not enough to bury the walkthrough.
  ///
  /// [existing] keeps the numbering (and any real stories) intact: seeds are
  /// appended after the feature's current stories.
  static List<AgileTask> storiesForFeature(
    Feature feature, {
    required int featureIndex,
    Iterable<AgileTask> existing = const [],
  }) {
    final siblings = existing.where((story) => story.featureId == feature.id);
    final lastOrder = siblings.isEmpty
        ? 0
        : siblings.map((story) => story.backlogOrder).reduce((a, b) => a > b ? a : b);
    final count = featureIndex == 0 ? 2 : 3;
    final titles = _titlesFor(feature.title);
    return [
      for (var i = 0; i < count; i++)
        AgileTask(
          epicId: feature.epicId,
          featureId: feature.id,
          userStory: titles[i % titles.length],
          storyPoints: _pointsFor(featureIndex, i),
          priority: _priorities[i % _priorities.length],
          status: 'To-Do',
          taskDescription:
              'Demo story for ${feature.title.isEmpty ? 'this feature' : feature.title}. '
              'Linked so the schedule and cost tests have real work to drive.',
          backlogOrder: lastOrder + i + 1,
          plannedSprintId: feature.sprintId ?? '',
        ),
    ];
  }

  /// Whether the backlog still needs demo stories: at least one feature
  /// carries no sized story. A project that seeded (or wrote) stories for
  /// every feature should not import the demo set again.
  static bool backlogNeedsSeeding(
      Iterable<Feature> features,
      {required Iterable<AgileTask> stories}) {
    if (features.isEmpty) return false;
    for (final feature in features) {
      final featureStories =
          stories.where((story) => story.featureId == feature.id);
      if (!featureStories.any((story) => story.storyPoints > 0)) return true;
    }
    return false;
  }

  /// Story titles derived from the feature, so a produce-delivery project and
  /// a road project both read plausibly. Stable per feature title.
  static List<String> _titlesFor(String featureTitle) {
    final topic = featureTitle.trim().isEmpty ? 'the feature' : featureTitle.trim();
    return [
      'As a user, I can use $topic end to end',
      'As a user, I can see the status of $topic at a glance',
      'As an operator, I can configure $topic for this project',
    ];
  }
}
