/// Schedule ↔ WBS work-package bridge.
///
/// Product rule (voice note, 2026-09-10):
///
/// > "the schedule should be able to put out everything that's like on the WBS
/// > should be able to find itself on the schedule"
///
/// and, on the same card the owner was looking at:
///
/// > "this card is supposed to show the WBS packages"
///
/// So the Schedule must be able to *show* every package the WBS decomposed —
/// whether or not it has been scheduled yet — and then bring the missing ones
/// onto the schedule in one action, carrying the package's planned window
/// (`WBSNode.plannedStart` / `plannedFinish`) with it.
///
/// This file is the pure, testable half. Nothing here touches a provider, a
/// BuildContext or the network: it reads a [WBS] and the schedule's activity
/// tree and answers "which packages exist, where are they on the schedule, and
/// which ones are still missing?" The provider does the writing.
library;

import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/utils/schedule_wbs_timelines.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';

/// One WBS work package as the Schedule sees it.
///
/// Carries both halves of the timeline link so the card can show the owner the
/// whole picture in one row:
///
/// - `plannedStart` / `plannedFinish` — the package's own planned window on the
///   WBS node (written by `WBSProvider.applyScheduleTimelines`, or entered
///   directly in the WBS module);
/// - `scheduledStart` / `scheduledFinish` — the window rolled up from the
///   schedule activities linked to this node (see [collectScheduleTimelines]).
class WbsPackageRow {
  const WbsPackageRow({
    required this.nodeId,
    required this.code,
    required this.name,
    required this.level,
    required this.plannedStart,
    required this.plannedFinish,
    required this.scheduledStart,
    required this.scheduledFinish,
    required this.activityIds,
    required this.activityNames,
    required this.costLineIds,
  });

  final String nodeId;

  /// WBS code (`1.2.3`), or an empty string when the node has none.
  final String code;
  final String name;

  /// Depth below the project root — 1 for a Level 1 package.
  final int level;

  final DateTime? plannedStart;
  final DateTime? plannedFinish;
  final DateTime? scheduledStart;
  final DateTime? scheduledFinish;

  /// Ids of the schedule activities linked to this node (`wbsNodeId` match).
  final List<String> activityIds;

  /// Names of those activities, for the card's detail line.
  final List<String> activityNames;

  /// Every cost line reachable from this package — the node's own
  /// `costLineIds` plus the `costLineId` stamped on any linked activity.
  final List<String> costLineIds;

  /// True when the schedule already carries this package.
  bool get onSchedule => activityIds.isNotEmpty;

  /// True when at least one linked activity has a date, so the package has a
  /// real place on the timeline.
  bool get hasScheduleDates =>
      scheduledStart != null || scheduledFinish != null;

  /// True when the package itself carries a planned window on the WBS.
  bool get hasPlannedWindow => plannedStart != null || plannedFinish != null;

  /// True when a cost line is attached — either on the activity (stamped when
  /// the schedule attaches a cost item) or on the node (linked from the Cost
  /// Estimate / Cost by WBS side).
  bool get isPriced => costLineIds.isNotEmpty;

  /// The label the module shows for the package: `code — name`.
  String get label {
    final c = code.trim();
    final n = name.trim();
    if (c.isEmpty) return n;
    if (n.isEmpty) return c;
    return '$c — $n';
  }

  /// A linked activity whose dates are missing while the package has a planned
  /// window — the case the "attach the WBS timeline" action fixes.
  bool get needsScheduleDates => onSchedule && !hasScheduleDates;
}

/// A WBS package the schedule does not carry yet, ready to be added.
class WbsPackagePull {
  const WbsPackagePull({
    required this.nodeId,
    required this.code,
    required this.name,
    required this.level,
    required this.description,
    required this.plannedStart,
    required this.plannedFinish,
  });

  final String nodeId;
  final String code;
  final String name;
  final int level;
  final String? description;
  final DateTime? plannedStart;
  final DateTime? plannedFinish;

  /// The activity name to create — `code — name`, matching the card.
  String get label {
    final c = code.trim();
    final n = name.trim();
    if (c.isEmpty) return n;
    if (n.isEmpty) return c;
    return '$c — $n';
  }
}

/// Builds one row per WBS node below the project root.
///
/// The project root (`wbs.level0`) is the project itself, never a work package,
/// so it is skipped. Everything else is included — *deliberately*, and for the
/// same reason `collectScheduleWorkPackages` includes unclassified leaves: the
/// owner's complaint was that packages were missing from the views, not that
/// extra ones showed up. A node with no name is skipped (it is not a package
/// anyone can work with) but its children are still walked.
///
/// Rows come back in WBS tree order, which is the order the owner reads the
/// breakdown in.
List<WbsPackageRow> buildWbsPackageRows({
  required WBS? wbs,
  required List<ScheduleActivity> activities,
}) {
  if (wbs == null) return const [];

  // The schedule side of the link, indexed once for the whole walk.
  final timelines = collectScheduleTimelines(activities);
  final linkedActivities = _indexActivitiesByWbsNode(activities);

  final rows = <WbsPackageRow>[];

  void walk(WBSNode node, int level) {
    final name = node.name.trim();
    if (name.isNotEmpty) {
      final window = timelines[node.id];
      final linked = linkedActivities[node.id] ?? const <ScheduleActivity>[];
      final costLineIds = <String>{
        ...?node.costLineIds,
        for (final a in linked)
          if ((a.costLineId ?? '').trim().isNotEmpty) a.costLineId!.trim(),
      }.toList(growable: false);

      rows.add(WbsPackageRow(
        nodeId: node.id,
        code: node.code.trim(),
        name: name,
        level: level,
        plannedStart: node.plannedStart,
        plannedFinish: node.plannedFinish,
        scheduledStart: window?.start,
        scheduledFinish: window?.finish,
        activityIds: linked.map((a) => a.id).toList(growable: false),
        activityNames: linked
            .map((a) => a.name.trim())
            .where((n) => n.isNotEmpty)
            .toList(growable: false),
        costLineIds: costLineIds,
      ));
    }
    for (final child in node.children) {
      walk(child, level + 1);
    }
  }

  for (final child in wbs.level0.children) {
    walk(child, 1);
  }
  return rows;
}

/// The packages the schedule is missing, in WBS order — what the card's
/// "add to schedule" action pulls.
///
/// A package counts as present when any activity in the tree is linked to its
/// node id, so the pull is naturally idempotent: re-running it after some rows
/// have been added offers only the remainder.
List<WbsPackagePull> wbsPackagesMissingFromSchedule({
  required WBS? wbs,
  required List<ScheduleActivity> activities,
}) {
  return buildWbsPackageRows(wbs: wbs, activities: activities)
      .where((row) => !row.onSchedule)
      .map((row) => WbsPackagePull(
            nodeId: row.nodeId,
            code: row.code,
            name: row.name,
            level: row.level,
            description: null,
            plannedStart: row.plannedStart,
            plannedFinish: row.plannedFinish,
          ))
      .toList(growable: false);
}

/// Number of scheduled packages whose activities still carry no dates, so the
/// card can offer "attach the WBS timeline" only when it would do something.
int countPackagesAwaitingScheduleDates(List<WbsPackageRow> rows) =>
    rows.where((row) => row.needsScheduleDates).length;

/// Indexes every activity in [roots] by the WBS node it is linked to.
///
/// Unlinked activities (no `wbsNodeId`) are skipped — they belong to no
/// package and can never satisfy coverage. The node id is trimmed on the way
/// in so `' n1 '` and `'n1'` are the same link, matching
/// `collectScheduleTimelines`.
Map<String, List<ScheduleActivity>> _indexActivitiesByWbsNode(
    List<ScheduleActivity> roots) {
  final byNode = <String, List<ScheduleActivity>>{};

  void walk(ScheduleActivity activity) {
    final nodeId = (activity.wbsNodeId ?? '').trim();
    if (nodeId.isNotEmpty) {
      byNode.putIfAbsent(nodeId, () => <ScheduleActivity>[]).add(activity);
    }
    for (final child in activity.children) {
      walk(child);
    }
  }

  for (final root in roots) {
    walk(root);
  }
  return byNode;
}
