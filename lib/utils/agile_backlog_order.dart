import 'package:ndu_project/models/agile_task.dart';

/// The rules behind prioritising the planning backlog.
///
/// The review asked for the backlog to be draggable — "you can just drag them
/// up and down to prioritize them" — instead of typing a position into each
/// story's Backlog order field. Priority is stored in
/// [AgileTask.backlogOrder], so a drop is a renumbering.
///
/// Pure on purpose: the backlog screen cannot be widget-tested without
/// Firestore, so the move semantics live here where they can be.
class AgileBacklogOrdering {
  AgileBacklogOrdering._();

  /// [stories] ordered by their stored priority.
  ///
  /// Ties are broken by the order they arrived in, so an unnumbered backlog
  /// (every story at 0) still renders in a stable, predictable order rather
  /// than shuffling on each rebuild.
  static List<AgileTask> sorted(List<AgileTask> stories) {
    final indexed = List<AgileTask>.of(stories);
    final originalIndex = {
      for (var i = 0; i < indexed.length; i++) indexed[i].id: i,
    };
    indexed.sort((a, b) {
      final byOrder = a.backlogOrder.compareTo(b.backlogOrder);
      if (byOrder != 0) return byOrder;
      return (originalIndex[a.id] ?? 0).compareTo(originalIndex[b.id] ?? 0);
    });
    return indexed;
  }

  /// [stories] filtered to [featureId], in priority order.
  static List<AgileTask> forFeature(List<AgileTask> stories, String featureId) {
    return [
      for (final story in sorted(stories))
        if (story.featureId == featureId) story,
    ];
  }

  /// Flutter's reorder contract: `newIndex` is the slot *before* the item is
  /// removed, so a downward move is one too far.
  static int adjustedIndex(int oldIndex, int newIndex) =>
      newIndex > oldIndex ? newIndex - 1 : newIndex;

  /// [stories] with [featureId]'s stories in the order they were dropped.
  ///
  /// The feature's stories stay a single block where they already were, and
  /// every other story keeps its relative order — dragging inside one feature
  /// prioritises that feature without reshuffling the whole backlog.
  ///
  /// The returned stories have `backlogOrder` reassigned to their new one-based
  /// position, which is what the backlog, the table, and the export all read.
  static List<AgileTask> moveWithinFeature({
    required List<AgileTask> stories,
    required String featureId,
    required int oldIndex,
    required int newIndex,
  }) {
    final ordered = sorted(stories);
    final positions = <int>[
      for (var i = 0; i < ordered.length; i++)
        if (ordered[i].featureId == featureId) i,
    ];
    if (positions.isEmpty) return ordered;
    if (oldIndex < 0 || oldIndex >= positions.length) return ordered;

    final target =
        adjustedIndex(oldIndex, newIndex).clamp(0, positions.length - 1);
    if (target == oldIndex) return ordered;

    final block = [for (final position in positions) ordered[position]];
    final moved = block.removeAt(oldIndex);
    block.insert(target, moved);

    final reordered = <AgileTask>[];
    var next = 0;
    for (var i = 0; i < ordered.length; i++) {
      if (next < positions.length && positions[next] == i) {
        reordered.add(block[next]);
        next++;
      } else {
        reordered.add(ordered[i]);
      }
    }

    return [
      for (var i = 0; i < reordered.length; i++)
        reordered[i].copyWith(backlogOrder: i + 1),
    ];
  }

  /// [stories] with [storyId] moved one step earlier or later among its
  /// feature's stories — the table view's explicit move actions, where there is
  /// no drop position to interpret.
  ///
  /// A nudge off either end of the feature is a no-op, so the buttons never
  /// have to know where the ends are.
  static List<AgileTask> nudgeWithinFeature({
    required List<AgileTask> stories,
    required String storyId,
    required int delta,
  }) {
    if (delta == 0) return sorted(stories);
    final ordered = sorted(stories);
    final found = ordered.indexWhere((story) => story.id == storyId);
    if (found == -1) return ordered;
    final featureId = ordered[found].featureId;
    if (featureId.isEmpty) return ordered;

    final siblings = forFeature(ordered, featureId);
    final index = siblings.indexWhere((story) => story.id == storyId);
    if (index == -1) return ordered;
    final landing = index + delta;
    if (landing < 0 || landing >= siblings.length) return ordered;

    return moveWithinFeature(
      stories: ordered,
      featureId: featureId,
      oldIndex: index,
      // moveWithinFeature takes an insertion slot, which is one past the
      // landing spot for a downward move.
      newIndex: delta > 0 ? landing + 1 : landing,
    );
  }

  /// Whether [story] matches a backlog search.
  ///
  /// The review asked to "search for epic, feature, story", so the parent
  /// titles are part of the match and not only the story's own text.
  static bool matches(
    AgileTask story, {
    required String query,
    String featureTitle = '',
    String epicTitle = '',
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return story.userStory.toLowerCase().contains(q) ||
        story.taskDescription.toLowerCase().contains(q) ||
        story.acceptanceCriteria.toLowerCase().contains(q) ||
        featureTitle.toLowerCase().contains(q) ||
        epicTitle.toLowerCase().contains(q);
  }
}
