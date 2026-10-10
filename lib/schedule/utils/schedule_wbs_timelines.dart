/// Schedule → WBS timeline linkage.
///
/// The Schedule ↔ WBS link is otherwise one-way: a [WBSNode] carries
/// `plannedStart` / `plannedFinish`, but nothing ever wrote them, so the WBS
/// could never show when a package is planned to start and finish (voice note,
/// 2026-09-10). This file is the pure, testable side of that: it turns the
/// scheduled activities into the date window each WBS node should carry.
library;

import 'package:ndu_project/schedule/models/schedule_models.dart';

/// Planned window for one WBS node, derived from the activities linked to it.
typedef WbsTimeline = ({DateTime? start, DateTime? finish});

/// Collects `WBSNode.id → {start, finish}` from every activity in [roots].
///
/// Only activities that are actually linked to a WBS node (`wbsNodeId` set)
/// contribute. When several activities share a node — the usual case, since a
/// package is normally several activities — the node gets the **widest**
/// window: the earliest start and the latest finish. That is the package's
/// planned span, not any single activity's.
///
/// Nodes whose activities carry no dates at all are omitted rather than
/// returned with two nulls, so callers can treat "present" as "has a date".
Map<String, WbsTimeline> collectScheduleTimelines(List<ScheduleActivity> roots) {
  final out = <String, WbsTimeline>{};

  void merge(String nodeId, DateTime? start, DateTime? finish) {
    if (start == null && finish == null) return;
    final existing = out[nodeId];
    DateTime? earliest(DateTime? a, DateTime? b) {
      if (a == null) return b;
      if (b == null) return a;
      return a.isBefore(b) ? a : b;
    }

    DateTime? latest(DateTime? a, DateTime? b) {
      if (a == null) return b;
      if (b == null) return a;
      return a.isAfter(b) ? a : b;
    }

    out[nodeId] = (
      start: earliest(existing?.start, start),
      finish: latest(existing?.finish, finish),
    );
  }

  void walk(ScheduleActivity activity) {
    final nodeId = (activity.wbsNodeId ?? '').trim();
    if (nodeId.isNotEmpty) {
      merge(nodeId, activity.startDate, activity.endDate);
    }
    for (final child in activity.children) {
      walk(child);
    }
  }

  for (final root in roots) {
    walk(root);
  }
  return out;
}
