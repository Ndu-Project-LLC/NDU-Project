import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';

/// The rules behind adding and editing a feature.
///
/// The review's ask was that a feature carries what the epic link needs — "you
/// have the title of the … description [and] the priority of that feature.
/// Because every feature will be tied to an epic" — and that adding one asks for
/// them instead of dropping an untitled row into the epic.
class AgileFeatureEditor {
  AgileFeatureEditor._();

  /// The priority vocabulary `Feature.priority` stores, in display order.
  static const List<String> priorities = ['critical', 'high', 'medium', 'low'];

  /// Title a brand new feature starts from, so it is never blank in a list.
  static const String defaultTitle = 'New feature';

  /// A new feature belonging to [epic], named so it is visible immediately.
  static Feature newFor(Epic epic, {String? title}) {
    final trimmed = title?.trim() ?? '';
    return Feature(
      epicId: epic.id,
      title: trimmed.isEmpty ? defaultTitle : trimmed,
    );
  }

  /// Whether moving [feature] to [epicId] is a re-parent, and therefore a save
  /// under the new epic plus a delete from the old one.
  static bool reparents(Feature feature, String epicId) =>
      epicId.trim().isNotEmpty && feature.epicId != epicId;

  /// [feature] re-parented onto [epicId], leaving everything else alone.
  static Feature moveToEpic(Feature feature, String epicId) =>
      feature.copyWith(epicId: epicId);

  /// What to show for a feature that has no title yet.
  static String displayTitle(Feature feature) {
    final title = feature.title.trim();
    return title.isEmpty ? 'Untitled feature' : title;
  }

  /// Normalise a typed priority onto the stored vocabulary, so a stray value
  /// cannot reach the model.
  static String normalisePriority(String priority) {
    final key = priority.trim().toLowerCase();
    return priorities.contains(key) ? key : 'medium';
  }
}
