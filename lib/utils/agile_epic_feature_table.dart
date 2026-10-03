import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/utils/agile_feature_editor.dart';

/// One row of the Epics & Features list view: a feature plus the epic it hangs
/// off, resolved once so the UI does not have to look the epic up per cell.
///
/// The review's complaint was that the epic cards were "not very efficient" to
/// work in — a feature is only visible after selecting its epic. This row is
/// what the flat, cross-epic list is built from.
class FeatureTableRow {
  const FeatureTableRow({
    required this.feature,
    required this.epicId,
    required this.epicTitle,
    this.epicIsMissing = false,
  });

  final Feature feature;

  /// The epic the feature was loaded under.
  final String epicId;

  /// Resolved epic title, or '' when the epic no longer exists.
  final String epicTitle;

  /// Set when the screen held features for an epic id it no longer has.
  final bool epicIsMissing;

  /// What to show for the feature, so a blank title is never an empty cell.
  String get title => AgileFeatureEditor.displayTitle(feature);

  /// What the list should say when the parent epic cannot be resolved.
  String get epicLabel =>
      epicIsMissing ? 'Epic no longer exists' : epicTitle;
}

/// Builds the all-features list and the summary around it.
///
/// Pure and service-free on purpose: the screen cannot be widget-tested
/// without Firestore, so the ordering, search, and gap reporting live here
/// where they can be.
class AgileEpicFeatureTable {
  AgileEpicFeatureTable._();

  /// Title to show for an epic that has not been named.
  static String displayEpicTitle(Epic epic) {
    final title = epic.title.trim();
    return title.isEmpty ? 'Untitled epic' : title;
  }

  /// Every feature in [featuresByEpic], ordered epic by epic and otherwise
  /// left in the order it loaded, so nothing is silently rearranged.
  ///
  /// Features whose epic id is not in [epics] are kept at the end rather than
  /// dropped — a feature is more useful shown as orphaned than missing.
  static List<FeatureTableRow> build(
    List<Epic> epics,
    Map<String, List<Feature>> featuresByEpic,
  ) {
    final rows = <FeatureTableRow>[];
    final seen = <String>{};
    for (final epic in epics) {
      seen.add(epic.id);
      for (final feature in featuresByEpic[epic.id] ?? const <Feature>[]) {
        rows.add(FeatureTableRow(
          feature: feature,
          epicId: epic.id,
          epicTitle: displayEpicTitle(epic),
        ));
      }
    }
    for (final entry in featuresByEpic.entries) {
      if (seen.contains(entry.key)) continue;
      for (final feature in entry.value) {
        rows.add(FeatureTableRow(
          feature: feature,
          epicId: entry.key,
          epicTitle: '',
          epicIsMissing: true,
        ));
      }
    }
    return rows;
  }

  /// Whether [row] matches a free-text search across feature, epic, and the
  /// stored vocabulary. Matching the epic title is what makes "type the epic
  /// name" work without a separate picker.
  static bool matches(FeatureTableRow row, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final feature = row.feature;
    return <String>[
      feature.title,
      feature.description,
      feature.priority,
      feature.status,
      feature.wbsId,
      row.epicTitle,
    ].any((value) => value.toLowerCase().contains(q));
  }

  /// [rows] narrowed to the ones matching [query], or all of them when the
  /// query is blank.
  static List<FeatureTableRow> filter(
    List<FeatureTableRow> rows,
    String query,
  ) {
    if (query.trim().isEmpty) return List<FeatureTableRow>.of(rows);
    return [
      for (final row in rows)
        if (matches(row, query)) row,
    ];
  }

  /// Epics that have no features yet — the breakdown gap the flat list has to
  /// admit to, since an epic with no features simply contributes no row.
  static List<Epic> epicsWithoutFeatures(
    List<Epic> epics,
    Map<String, List<Feature>> featuresByEpic,
  ) {
    return [
      for (final epic in epics)
        if ((featuresByEpic[epic.id] ?? const <Feature>[]).isEmpty) epic,
    ];
  }

  /// How many distinct epics the rows cover.
  static int epicCount(List<FeatureTableRow> rows) =>
      rows.map((row) => row.epicId).toSet().length;

  /// Summed story-point estimates across [rows].
  static double totalPoints(List<FeatureTableRow> rows) =>
      rows.fold<double>(0, (sum, row) => sum + row.feature.storyPointEstimate);
}
