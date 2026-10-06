/// Cost Estimate ← Schedule work packages.
///
/// Product rule (voice note, 2026-09-10): **the Cost Estimate starts from the
/// Schedule.** The WBS carries scope to level 2–3, the Schedule takes that
/// down to implementable work packages, and the Cost Estimate then estimates
/// *those* packages — that set is the core direct cost. Allowances, personnel,
/// scheduled purchases, procurement items and AI suggestions are additions on
/// top, never the base:
///
/// > "the cost estimate … is supposed to start with the work packages from the
/// > Schedule as a direct cost"
///
/// Deterministic, no AI: this file is the pure, testable half — it selects the
/// estimate-able work packages and maps each one's schedule domain to a direct
/// cost category. The provider does the data movement.
library;

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';

/// One scheduled work package to be estimated, plus the direct-cost category
/// its schedule domain maps to.
typedef ScheduleWorkPackage = ({
  String activityId,
  String title,
  String? wbsRef,
  String? activityCostLineId,
  CostCategory category,
});

/// Which **direct** cost bucket a schedule domain estimates into.
///
/// Every result is a direct category — per the owner's rule the scheduled work
/// packages *are* the direct cost, so indirect cost is never fed from the
/// schedule. Labour is the default because engineering, execution and
/// commissioning work is predominantly people-time; physical buyables and field
/// work map to procurement and construction instead.
CostCategory directCategoryForDomain(ScheduleDomain domain) => switch (domain) {
      ScheduleDomain.engineering => CostCategory.labor,
      ScheduleDomain.procurement => CostCategory.procurement,
      ScheduleDomain.construction => CostCategory.construction,
      ScheduleDomain.execution => CostCategory.labor,
      ScheduleDomain.commissioning => CostCategory.labor,
    };

/// Collect the estimate-able work packages from a schedule tree (pass
/// `schedule.activities`).
///
/// A work package is a **leaf** activity (`children` empty) that is not a
/// [ActivityType.milestone]:
///
/// - Leaf-only means an upper-level stage is never estimated on its own — it
///   rolls up, so the same work is never counted twice. This mirrors the
///   container rule in `schedule_purchase_cost.dart`.
/// - Milestones represent a point in time, not work, so they carry no cost.
/// - Everything else *is* included, deliberately. A work package whose
///   classification the schedule could not resolve is typed `summary` but is
///   still a real leaf, and the owner's complaint was about work packages
///   missing from the views — not about extras.
///
/// Activities with a blank name are skipped; they cannot be estimated or
/// matched later. `wbsRef` / `activityCostLineId` are normalised to `null` when
/// blank so callers can treat "present" as "usable".
List<ScheduleWorkPackage> collectScheduleWorkPackages(
    List<ScheduleActivity> roots) {
  final out = <ScheduleWorkPackage>[];

  void walk(ScheduleActivity node) {
    if (node.children.isNotEmpty) {
      for (final child in node.children) {
        walk(child);
      }
      return;
    }

    if (node.type == ActivityType.milestone) return;
    final title = node.name.trim();
    if (title.isEmpty) return;

    final ref = (node.wbsCode ?? '').trim();
    final linked = (node.costLineId ?? '').trim();
    out.add((
      activityId: node.id,
      title: title,
      wbsRef: ref.isEmpty ? null : ref,
      activityCostLineId: linked.isEmpty ? null : linked,
      category: directCategoryForDomain(node.domain),
    ));
  }

  for (final root in roots) {
    walk(root);
  }
  return out;
}
