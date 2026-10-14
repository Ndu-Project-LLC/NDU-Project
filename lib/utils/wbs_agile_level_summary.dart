import 'package:ndu_project/wbs/models/wbs_models.dart';

/// One WBS level, ready to print: the label the framework uses for it and how
/// many nodes sit there.
class WbsLevelCount {
  const WbsLevelCount({
    required this.level,
    required this.label,
    required this.count,
  });

  final int level;
  final String label;
  final int count;

  /// How the level reads in a summary line, e.g. `12 User Story`.
  String get display => '$count $label';
}

/// The WBS's level summary.
///
/// The WBS is where the agile chain starts — its level convention is
/// Level 1 = Epic, Level 2 = Feature, Level 3 = User Story — but the WBS
/// Summary only ever reported the first two, so an Agile WBS that had been
/// broken down no further looked identical to one that had. This reports one
/// level deeper and says so when the story level is still empty.
///
/// Pure on purpose (a framework plus counts in, strings out) so it is testable
/// without Firestore or a provider.
class WbsLevelSummary {
  WbsLevelSummary._();

  /// How many levels the summary reports: Epic → Feature → Story in Agile, and
  /// the first three levels of any waterfall framework.
  static const int reportedDepth = 3;

  /// The levels to report, in order.
  ///
  /// A level with no nodes is skipped unless [includeEmpty] is set, so a
  /// waterfall WBS that legitimately stops at level 2 is not padded with
  /// zeroes — but an Agile WBS can still be asked to show the whole chain.
  static List<WbsLevelCount> breakdown({
    required WBSFramework framework,
    required Map<int, int> countsByLevel,
    bool includeEmpty = false,
    int depth = reportedDepth,
  }) {
    final levels = <WbsLevelCount>[];
    for (var level = 1; level <= depth; level++) {
      final count = countsByLevel[level] ?? 0;
      if (count == 0 && !includeEmpty) continue;
      levels.add(WbsLevelCount(
        level: level,
        label: framework.levelLabel(level),
        count: count,
      ));
    }
    return levels;
  }

  /// `3 Epic · 8 Feature · 12 User Story` — the labels come from the framework,
  /// so this reads correctly for waterfall too.
  static String summaryLine({
    required WBSFramework framework,
    required Map<int, int> countsByLevel,
    int depth = reportedDepth,
  }) {
    return breakdown(
      framework: framework,
      countsByLevel: countsByLevel,
      depth: depth,
    ).map((level) => level.display).join(' · ');
  }

  /// Why the story level is empty, or null when there is nothing to say.
  ///
  /// Only speaks up for an Agile WBS that *has* features to break down: a WBS
  /// with no features is unfinished at a higher level and the summary should
  /// not push it down the chain.
  static String? storyGapHint({
    required WBSFramework framework,
    required Map<int, int> countsByLevel,
  }) {
    if (framework != WBSFramework.agile) return null;
    if ((countsByLevel[2] ?? 0) == 0) return null;
    if ((countsByLevel[3] ?? 0) > 0) return null;
    return 'No ${framework.level3Label} level yet — break the features down '
        'so stories reach the backlog.';
  }
}
