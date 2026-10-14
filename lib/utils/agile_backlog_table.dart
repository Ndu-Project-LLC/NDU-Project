import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';

/// Why a story is not sitting under a feature.
enum BacklogUnlinkedReason {
  /// The story has no feature id at all.
  none,

  /// The story points at a feature that no longer exists.
  missing,
}

/// One row of the planning backlog: a story plus the feature and epic it
/// descends from.
///
/// The review asked for the backlog to show "what the story is, what the
/// feature is, it's coming from it and of course the [epic] for each one" —
/// so the parent chain is resolved once per row rather than per cell.
class BacklogTableRow {
  const BacklogTableRow({
    required this.story,
    required this.epicTitle,
    required this.featureTitle,
    this.unlinkedReason,
    this.missingFeatureId,
  });

  final AgileTask story;

  /// Resolved epic title, or '' when the story has no feature chain.
  final String epicTitle;

  /// Resolved feature title, or '' when the story has no feature chain.
  final String featureTitle;

  /// Set when this story has no resolvable feature.
  final BacklogUnlinkedReason? unlinkedReason;

  /// The stale feature id, kept so the UI can say what it pointed at.
  final String? missingFeatureId;

  bool get isUnlinked => unlinkedReason != null;

  /// What the backlog should say about the missing parent.
  String get unlinkedLabel => switch (unlinkedReason) {
        null => '',
        BacklogUnlinkedReason.none => 'No feature set',
        BacklogUnlinkedReason.missing =>
          'Feature ${missingFeatureId ?? ''} no longer exists',
      };
}

/// Builds the planning backlog table: every story with its epic and feature,
/// ordered epic → feature → backlog order, with stories that have no reachable
/// feature grouped at the end.
///
/// Stories used to only appear inside their feature's card, so one whose
/// feature link was missing or stale simply vanished from the screen. Keeping
/// them in the table as an unlinked group is what makes that breakage visible
/// instead of silent.
class AgileBacklogTable {
  AgileBacklogTable._();

  static List<BacklogTableRow> build({
    required List<Epic> epics,
    required Map<String, List<Feature>> featuresByEpic,
    required List<AgileTask> stories,
    String query = '',
  }) {
    final featureById = <String, Feature>{};
    final epicTitleById = <String, String>{};
    final epicIndexById = <String, int>{};
    final featureIndexById = <String, int>{};

    for (var e = 0; e < epics.length; e++) {
      final epic = epics[e];
      epicTitleById[epic.id] = epic.title;
      epicIndexById[epic.id] = e;
      final features = featuresByEpic[epic.id] ?? const <Feature>[];
      for (var f = 0; f < features.length; f++) {
        featureById[features[f].id] = features[f];
        featureIndexById[features[f].id] = f;
      }
    }

    final sortable = <_SortableRow>[];
    for (final story in stories) {
      final feature =
          story.featureId.isEmpty ? null : featureById[story.featureId];
      if (feature == null) {
        sortable.add(_SortableRow(
          row: BacklogTableRow(
            story: story,
            epicTitle: '',
            featureTitle: '',
            unlinkedReason: story.featureId.isEmpty
                ? BacklogUnlinkedReason.none
                : BacklogUnlinkedReason.missing,
            missingFeatureId: story.featureId.isEmpty ? null : story.featureId,
          ),
          // Unlinked rows sort after every linked row.
          epicIndex: epics.length,
          featureIndex: 0,
        ));
        continue;
      }
      sortable.add(_SortableRow(
        row: BacklogTableRow(
          story: story,
          epicTitle: epicTitleById[feature.epicId] ?? '',
          featureTitle: feature.title,
        ),
        epicIndex: epicIndexById[feature.epicId] ?? epics.length,
        featureIndex: featureIndexById[feature.id] ?? 0,
      ));
    }

    final trimmed = query.trim();
    final matching = trimmed.isEmpty
        ? sortable
        : sortable.where((entry) => _matches(entry.row, trimmed)).toList();

    matching.sort((a, b) {
      if (a.epicIndex != b.epicIndex) return a.epicIndex.compareTo(b.epicIndex);
      if (a.featureIndex != b.featureIndex) {
        return a.featureIndex.compareTo(b.featureIndex);
      }
      final byOrder = a.row.story.backlogOrder
          .compareTo(b.row.story.backlogOrder);
      if (byOrder != 0) return byOrder;
      return a.row.story.userStory
          .toLowerCase()
          .compareTo(b.row.story.userStory.toLowerCase());
    });

    return [for (final entry in matching) entry.row];
  }

  /// Features that exist but still have no stories — the gap the review found
  /// on this section ("the ability to break the features down into stories").
  static List<Feature> featuresWithoutStories({
    required List<Epic> epics,
    required Map<String, List<Feature>> featuresByEpic,
    required List<AgileTask> stories,
  }) {
    final withStories = stories
        .map((story) => story.featureId)
        .where((id) => id.isNotEmpty)
        .toSet();
    return [
      for (final epic in epics)
        for (final feature in featuresByEpic[epic.id] ?? const <Feature>[])
          if (!withStories.contains(feature.id)) feature,
    ];
  }

  static bool _matches(BacklogTableRow row, String query) {
    final q = query.toLowerCase();
    final story = row.story;
    return story.userStory.toLowerCase().contains(q) ||
        story.taskDescription.toLowerCase().contains(q) ||
        story.acceptanceCriteria.toLowerCase().contains(q) ||
        row.epicTitle.toLowerCase().contains(q) ||
        row.featureTitle.toLowerCase().contains(q);
  }
}

/// A row carrying its own sort keys, so ordering never depends on shared
/// mutable state.
class _SortableRow {
  const _SortableRow({
    required this.row,
    required this.epicIndex,
    required this.featureIndex,
  });

  final BacklogTableRow row;
  final int epicIndex;
  final int featureIndex;
}
