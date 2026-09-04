/// Scheduled-purchase detection for the Schedule ↔ Cost Estimate link.
///
/// Product rule (voice note, 2026-09-03): purchases already visible in the
/// Schedule (\"buy CPE\", \"buy this\", procurement packages tied to work
/// packages) must be pulled into the Cost Estimate as core data movement —
/// never by AI, never retyped. This file is the pure, testable side of that
/// rule: it finds the activities that represent buys so the Schedule module
/// can offer a one-click pull.
///
/// Pull policy (deterministic, no free-text heuristics):
///   - An activity is a *purchase* when its domain is
///     [ScheduleDomain.procurement] or its type is
///     [ActivityType.procurementPackage].
///   - Container rows (a purchase whose children are themselves purchases)
///     are NOT pulled individually — the leaf purchases under them are, so
///     the same buy is never counted twice.
library;

import 'package:ndu_project/schedule/models/schedule_models.dart';

/// True when [activity] represents a buyable purchase work package.
bool isScheduledPurchaseActivity(ScheduleActivity activity) =>
    activity.domain == ScheduleDomain.procurement ||
    activity.type == ActivityType.procurementPackage;

bool _hasPurchaseDescendant(ScheduleActivity activity) {
  for (final child in activity.children) {
    if (isScheduledPurchaseActivity(child) ||
        _hasPurchaseDescendant(child)) {
      return true;
    }
  }
  return false;
}

/// Collect the purchase work packages that should flow into the Cost
/// Estimate, walking every root in [roots] (pass `schedule.activities`).
///
/// Returns leaf-level purchases only — a purchase node that still has
/// purchase descendants is a container and is skipped (its leaf purchases
/// are collected instead). Non-purchase containers can still contain a
/// purchase child deeper down; that child is collected.
List<ScheduleActivity> collectPullablePurchases(
    List<ScheduleActivity> roots) {
  final out = <ScheduleActivity>[];
  void walk(ScheduleActivity node) {
    if (isScheduledPurchaseActivity(node)) {
      if (!_hasPurchaseDescendant(node)) {
        out.add(node);
        return; // Do not descend into a pulled purchase's internal steps.
      }
      // Purchase container — descend to its purchase leaves.
      for (final child in node.children) {
        walk(child);
      }
      return;
    }
    for (final child in node.children) {
      walk(child);
    }
  }

  for (final root in roots) {
    walk(root);
  }
  return out;
}

/// Depth-first search for an activity by id across [roots].
ScheduleActivity? findActivityById(
    List<ScheduleActivity> roots, String id) {
  ScheduleActivity? search(ScheduleActivity node) {
    if (node.id == id) return node;
    for (final child in node.children) {
      final hit = search(child);
      if (hit != null) return hit;
    }
    return null;
  }

  for (final root in roots) {
    final hit = search(root);
    if (hit != null) return hit;
  }
  return null;
}
