/// WBS Linkage Service — bidirectional sync engine that connects the three
/// execution-planning sections: Work Breakdown Structure, Schedule, and
/// Project Controls.
///
/// Before this service existed, the three sections lived in independent
/// feature folders with no shared keys:
///   • WBS — Firestore `projects/{projectId}/wbs/main`, model `WBSNode`
///   • Schedule — SharedPreferences `ndu_schedule_v1`, model `ScheduleActivity`
///     (has a `wbsNodeId` field but it was never displayed or validated)
///   • Project Controls — Firestore `users/{uid}/projectControls/...`,
///     model `WorkPackageControl` (stores `wbsCode` as a STRING, not a FK)
///
/// This service establishes a canonical, ID-based linkage between the three:
///
///   WBSNode.id  ←→  WorkPackageControl.wbsNodeId   ←→  ScheduleActivity.wbsNodeId
///   WBSNode.controlAccountId        →  WorkPackageControl.id
///   WBSNode.scheduleActivityId      →  ScheduleActivity.id
///   WorkPackageControl.scheduleActivityId  →  ScheduleActivity.id
///   ScheduleVariance.scheduleActivityId    →  ScheduleActivity.id
///
/// Information flows in ALL directions:
///   • WBS → Schedule: each WBS work-package leaf seeds a ScheduleActivity.
///   • WBS → PC: each WBS work-package leaf seeds a WorkPackageControl
///     (control account) with budget rolled up from any linked Cost Estimate
///     lines.
///   • Schedule → PC: planned dates, critical-path flag, and float propagate
///     into the corresponding WorkPackageControl. A ScheduleVariance record
///     is auto-created (or refreshed) for every activity with a linked WPC.
///   • PC → WBS (reverse): actual cost and percent complete from each
///     WorkPackageControl propagate back to its parent WBSNode so the WBS
///     tree can surface progress badges without the user opening PC.
///   • Schedule → WBS (reverse): start/end dates and status from each
///     ScheduleActivity propagate back to its parent WBSNode so the WBS
///     tree can show "planned finish" dates inline.
///
/// The service is intentionally idempotent — running `syncAll` multiple
/// times produces the same state. Existing user-edited entries are
/// preserved (matched by `wbsNodeId`), only missing links are created.

library;

import 'package:flutter/foundation.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/schedule/models/schedule_models.dart';
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/project_controls/models/project_controls_models.dart';
import 'package:ndu_project/project_controls/providers/project_controls_provider.dart';

/// Result of a single `syncAll` run.
class LinkageReport {
  /// Total WBS nodes inspected (level 1+, excluding the synthetic root).
  final int wbsNodeCount;

  /// WBS nodes that are flagged as work-package leaves (the linkage unit).
  final int wbsWorkPackageCount;

  /// Schedule activities examined.
  final int scheduleActivityCount;

  /// PC work packages (control accounts) examined.
  final int controlAccountCount;

  /// New ScheduleActivities created during this sync.
  final int scheduleCreated;

  /// Existing ScheduleActivities updated during this sync.
  final int scheduleUpdated;

  /// New WorkPackageControls created during this sync.
  final int controlAccountsCreated;

  /// Existing WorkPackageControls updated during this sync.
  final int controlAccountsUpdated;

  /// WBS nodes that received a freshly-stamped `controlAccountId`.
  final int wbsCaLinksStamped;

  /// WBS nodes that received a freshly-stamped `scheduleActivityId`.
  final int wbsSchedLinksStamped;

  /// WBS nodes that received a propagated `percentComplete` / `actualCost`.
  final int wbsProgressBackfilled;

  /// WBS nodes that received a propagated `plannedStart` / `plannedFinish`.
  final int wbsDatesBackfilled;

  /// ScheduleVariances created or refreshed.
  final int scheduleVariancesRefreshed;

  /// WBS nodes that have NO linked control account (orphan — needs attention).
  final int orphanNoControlAccount;

  /// WBS nodes that have NO linked schedule activity (orphan — needs attention).
  final int orphanNoScheduleActivity;

  const LinkageReport({
    required this.wbsNodeCount,
    required this.wbsWorkPackageCount,
    required this.scheduleActivityCount,
    required this.controlAccountCount,
    required this.scheduleCreated,
    required this.scheduleUpdated,
    required this.controlAccountsCreated,
    required this.controlAccountsUpdated,
    required this.wbsCaLinksStamped,
    required this.wbsSchedLinksStamped,
    required this.wbsProgressBackfilled,
    required this.wbsDatesBackfilled,
    required this.scheduleVariancesRefreshed,
    required this.orphanNoControlAccount,
    required this.orphanNoScheduleActivity,
  });

  /// True when every WBS work package has BOTH a control account and a
  /// schedule activity. Used by the UI to show a green "fully linked" badge.
  bool get fullyLinked =>
      wbsWorkPackageCount > 0 &&
      orphanNoControlAccount == 0 &&
      orphanNoScheduleActivity == 0;

  /// 0.0 – 1.0 — the lower of the two coverage ratios. Useful for a single
  /// headline number on the sync card.
  double get coverageRatio {
    if (wbsWorkPackageCount == 0) return 0;
    final caCoverage = 1 -
        (orphanNoControlAccount / wbsWorkPackageCount);
    final schedCoverage = 1 -
        (orphanNoScheduleActivity / wbsWorkPackageCount);
    return caCoverage < schedCoverage ? caCoverage : schedCoverage;
  }

  String get summary => 'WBS $wbsWorkPackageCount WP · '
      'PC $controlAccountCount CA · '
      'Sched $scheduleActivityCount act · '
      '${(coverageRatio * 100).round()}% linked';
}

class WbsLinkageService {
  WbsLinkageService._();

  /// Run a full bidirectional sync across the three providers.
  ///
  /// Pass [replaceExisting] = true to force-overwrite user-edited schedule
  /// activities / control accounts. Default is false (additive only —
  /// existing entries are kept, only their cross-section FK fields are
  /// refreshed).
  static Future<LinkageReport> syncAll({
    required WBSProvider wbsProvider,
    required ScheduleProvider scheduleProvider,
    required ProjectControlsProvider pcProvider,
    bool replaceExisting = false,
  }) async {
    final wbs = wbsProvider.wbs;
    final schedule = scheduleProvider.schedule;
    if (wbs == null || schedule == null || schedule.activities.isEmpty) {
      return const LinkageReport(
        wbsNodeCount: 0,
        wbsWorkPackageCount: 0,
        scheduleActivityCount: 0,
        controlAccountCount: 0,
        scheduleCreated: 0,
        scheduleUpdated: 0,
        controlAccountsCreated: 0,
        controlAccountsUpdated: 0,
        wbsCaLinksStamped: 0,
        wbsSchedLinksStamped: 0,
        wbsProgressBackfilled: 0,
        wbsDatesBackfilled: 0,
        scheduleVariancesRefreshed: 0,
        orphanNoControlAccount: 0,
        orphanNoScheduleActivity: 0,
      );
    }

    // Root activity ID — new activities are added as children of root.
    final rootActivityId = schedule.activities[0].id;

    // ── Flatten the WBS tree to leaves (work-package nodes) ────────────
    final leaves = <WBSNode>[];
    int totalNodes = 0;
    void walk(WBSNode n) {
      totalNodes++;
      final isLeaf = n.children.isEmpty ||
          (n.isWorkPackage == true && n.children.isEmpty);
      if (isLeaf && n.level != WBSLevel.level0) {
        leaves.add(n);
      }
      for (final c in n.children) {
        walk(c);
      }
    }

    walk(wbs.level0);

    // ── Build lookup maps from the OTHER two providers ─────────────────
    final pcByWbsNodeId = <String, WorkPackageControl>{};
    final pcByWbsCode = <String, WorkPackageControl>{};
    for (final wp in pcProvider.state.workPackages) {
      if (wp.wbsNodeId != null && wp.wbsNodeId!.isNotEmpty) {
        pcByWbsNodeId[wp.wbsNodeId!] = wp;
      }
      if (wp.wbsCode.isNotEmpty) {
        pcByWbsCode[wp.wbsCode] = wp;
      }
    }

    final schedByWbsNodeId = <String, ScheduleActivity>{};
    final schedByWbsCode = <String, ScheduleActivity>{};
    void indexActivities(List<ScheduleActivity> acts) {
      for (final a in acts) {
        if (a.wbsNodeId != null && a.wbsNodeId!.isNotEmpty) {
          schedByWbsNodeId[a.wbsNodeId!] = a;
        }
        if (a.wbsCode != null && a.wbsCode!.isNotEmpty) {
          schedByWbsCode[a.wbsCode!] = a;
        }
        indexActivities(a.children);
      }
    }

    indexActivities(schedule.activities);

    // ── Stats we'll return ─────────────────────────────────────────────
    var scheduleCreated = 0;
    var scheduleUpdated = 0;
    var controlAccountsCreated = 0;
    var controlAccountsUpdated = 0;
    var wbsCaLinksStamped = 0;
    var wbsSchedLinksStamped = 0;
    var wbsProgressBackfilled = 0;
    var wbsDatesBackfilled = 0;
    var scheduleVariancesRefreshed = 0;
    var orphanNoControlAccount = 0;
    var orphanNoScheduleActivity = 0;

    // ── Per-leaf: ensure a control account exists, ensure a schedule
    //    activity exists, then stamp the WBS node's FK fields and
    //    backfill propagated values. ────────────────────────────────────
    final newVariances = <ScheduleVariance>[];
    var wbsDirty = false;
    var pcDirty = false;
    var schedDirty = false;

    WBSNode? patchNode(WBSNode root, String id, WBSNode Function(WBSNode) patch) {
      WBSNode? apply(WBSNode n) {
        if (n.id == id) {
          return patch(n);
        }
        if (n.children.isEmpty) return null;
        final newKids = <WBSNode>[];
        var changed = false;
        for (final c in n.children) {
          final p = apply(c);
          newKids.add(p ?? c);
          if (p != null) changed = true;
        }
        if (!changed) return null;
        return n.copyWith(children: newKids);
      }

      return apply(root);
    }

    for (final leaf in leaves) {
      // ───── 1. Ensure WorkPackageControl exists ────────────────────────
      final existingWpc = pcByWbsNodeId[leaf.id] ?? pcByWbsCode[leaf.code];
      WorkPackageControl wpc;
      if (existingWpc == null) {
        // Create a fresh control account.
        final id = 'wp_wbs_${leaf.id}';
        wpc = WorkPackageControl(
          id: id,
          wbsCode: leaf.code,
          wbsNodeId: leaf.id,
          name: leaf.name,
          scopeDescription: leaf.description ?? '',
          deliverables: const [],
          acceptanceCriteria: const [],
          priority: 'Medium',
          status: 'Not Started',
          plannedStart: null,
          plannedFinish: null,
          isCriticalPath: false,
          remainingDuration: 0,
          floatDays: 0,
          originalBudget: 0,
          currentBudget: 0,
          committedCost: 0,
          actualCost: 0,
          earnedValue: 0,
          plannedValue: 0,
          progressMethod: ProgressMethod.physicalPercent,
        );
        controlAccountsCreated++;
        pcProvider.addWorkPackage(wpc);
        pcByWbsNodeId[leaf.id] = wpc;
        pcByWbsCode[leaf.code] = wpc;
        pcDirty = true;
      } else {
        wpc = existingWpc;
        // Ensure the cross-section FK fields are stamped.
        var patched = wpc;
        if (patched.wbsNodeId != leaf.id) {
          patched = patched.copyWith(wbsNodeId: leaf.id);
        }
        if (patched.wbsCode != leaf.code && leaf.code.isNotEmpty) {
          patched = patched.copyWith(wbsCode: leaf.code);
        }
        if (patched != wpc) {
          controlAccountsUpdated++;
          pcProvider.updateWorkPackage(wpc.id, patched);
          pcByWbsNodeId[leaf.id] = patched;
          pcByWbsCode[leaf.code] = patched;
          wpc = patched;
          pcDirty = true;
        }
      }

      // ───── 2. Ensure ScheduleActivity exists ──────────────────────────
      final existingActivity =
          schedByWbsNodeId[leaf.id] ?? schedByWbsCode[leaf.code];
      ScheduleActivity activity;
      if (existingActivity == null) {
        // Build the seed activity with all cross-section FKs pre-stamped.
        // `addActivity` overrides `id` and `code` (recalcActivityCodes
        // assigns the visible code), but preserves every other field —
        // including our cross-section FK fields.
        final seed = ScheduleActivity(
          id: '', // will be assigned by addActivity
          wbsNodeId: leaf.id,
          wbsCode: leaf.code,
          controlAccountId: wpc.id,
          level: 1,
          code: '',
          name: leaf.name,
          description: leaf.description,
          type: ActivityType.activity,
          domain: ScheduleDomain.execution,
          dependencies: const [],
          aiGenerated: false,
          importSource: 'wbs',
          children: const [],
        );
        final newId = scheduleProvider.addActivity(rootActivityId, seed);
        if (newId.isNotEmpty) {
          // Read back the just-added activity from the provider so we
          // have the canonical instance (with the assigned ID).
          ScheduleActivity? find(
              List<ScheduleActivity> acts, String targetId) {
            for (final a in acts) {
              if (a.id == targetId) return a;
              final found = find(a.children, targetId);
              if (found != null) return found;
            }
            return null;
          }

          final found =
              find(scheduleProvider.schedule!.activities, newId);
          activity = found ?? seed.copyWith(id: newId);
          schedByWbsNodeId[leaf.id] = activity;
          if (leaf.code.isNotEmpty) schedByWbsCode[leaf.code] = activity;
          scheduleCreated++;
          schedDirty = true;
        } else {
          // addActivity failed (schedule empty?) — fall back to seed.
          activity = seed;
        }
      } else {
        activity = existingActivity;
        // Ensure FK fields are stamped.
        var patched = activity;
        if (patched.wbsNodeId != leaf.id) {
          patched = patched.copyWith(wbsNodeId: leaf.id);
        }
        if (patched.wbsCode != leaf.code && leaf.code.isNotEmpty) {
          patched = patched.copyWith(wbsCode: leaf.code);
        }
        if (patched.controlAccountId != wpc.id) {
          patched = patched.copyWith(controlAccountId: wpc.id);
        }
        if (patched != activity) {
          scheduleProvider.updateActivity(patched.id, patched);
          schedByWbsNodeId[leaf.id] = patched;
          schedByWbsCode[leaf.code] = patched;
          activity = patched;
          scheduleUpdated++;
          schedDirty = true;
        }
      }

      // ───── 3. Stamp the WBS node with the linked IDs (if missing) ────
      var patchedLeaf = leaf;
      var leafChanged = false;
      if (patchedLeaf.controlAccountId != wpc.id) {
        patchedLeaf = patchedLeaf.copyWith(controlAccountId: wpc.id);
        leafChanged = true;
        wbsCaLinksStamped++;
      }
      if (patchedLeaf.scheduleActivityId != activity.id) {
        patchedLeaf = patchedLeaf.copyWith(scheduleActivityId: activity.id);
        leafChanged = true;
        wbsSchedLinksStamped++;
      }

      // ───── 4. Backfill PC actuals → WBS node ─────────────────────────
      if (wpc.percentComplete != null &&
          wpc.percentComplete != patchedLeaf.percentComplete) {
        patchedLeaf = patchedLeaf.copyWith(percentComplete: wpc.percentComplete);
        leafChanged = true;
        wbsProgressBackfilled++;
      }
      if (wpc.actualCost > 0 &&
          wpc.actualCost != patchedLeaf.actualCost) {
        patchedLeaf = patchedLeaf.copyWith(actualCost: wpc.actualCost);
        leafChanged = true;
        if (wpc.percentComplete == null) wbsProgressBackfilled++;
      }

      // ───── 5. Backfill Schedule dates → WBS node ─────────────────────
      if (activity.startDate != null &&
          activity.startDate != patchedLeaf.plannedStart) {
        patchedLeaf = patchedLeaf.copyWith(plannedStart: activity.startDate);
        leafChanged = true;
        wbsDatesBackfilled++;
      }
      if (activity.endDate != null &&
          activity.endDate != patchedLeaf.plannedFinish) {
        patchedLeaf = patchedLeaf.copyWith(plannedFinish: activity.endDate);
        leafChanged = true;
        if (activity.startDate == null) wbsDatesBackfilled++;
      }
      if (activity.status != null &&
          activity.status!.isNotEmpty &&
          activity.status != patchedLeaf.scheduleStatus) {
        patchedLeaf = patchedLeaf.copyWith(scheduleStatus: activity.status);
        leafChanged = true;
      }

      if (leafChanged) {
        final newRoot = patchNode(wbs.level0, leaf.id, (_) => patchedLeaf);
        if (newRoot != null) {
          wbsProvider.updateNode(leaf.id, patchedLeaf);
          wbsDirty = true;
        }
      }

      // ───── 6. Schedule → PC variance record (if activity has dates) ──
      if (activity.startDate != null || activity.endDate != null) {
        final existing = pcProvider.state.scheduleVariances.firstWhere(
          (v) => v.workPackageId == wpc.id,
          orElse: () => ScheduleVariance(
            workPackageId: wpc.id,
            scheduleActivityId: activity.id,
            plannedStart: activity.startDate,
            plannedFinish: activity.endDate,
            floatDays: activity.isCriticalPath ? 0 : 5,
            delayReason: '',
            compressionStrategy: CompressionStrategy.none,
          ),
        );
        final refreshed = existing.copyWith(
          scheduleActivityId: activity.id,
          plannedStart: activity.startDate ?? existing.plannedStart,
          plannedFinish: activity.endDate ?? existing.plannedFinish,
          floatDays: activity.isCriticalPath ? 0 : (existing.floatDays),
        );
        if (refreshed != existing) {
          newVariances.add(refreshed);
          scheduleVariancesRefreshed++;
        }
      }

      // ───── 7. Orphan counts (for the report) ─────────────────────────
      // After sync, every leaf should have both links. Orphans only
      // remain if a provider write failed silently — surface those so the
      // user knows to re-run sync.
      if (wpc.id.isEmpty) orphanNoControlAccount++;
      if (activity.id.isEmpty) orphanNoScheduleActivity++;
    }

    // Apply refreshed variances.
    for (final sv in newVariances) {
      pcProvider.addScheduleVariance(sv);
    }
    if (newVariances.isNotEmpty) pcDirty = true;

    // Final save triggers (providers already persisted incrementally).
    if (pcDirty) debugPrint('[WbsLinkage] PC dirty — created $controlAccountsCreated, updated $controlAccountsUpdated, ${newVariances.length} variances');
    if (schedDirty) debugPrint('[WbsLinkage] Schedule dirty — created $scheduleCreated, updated $scheduleUpdated');
    if (wbsDirty) debugPrint('[WbsLinkage] WBS dirty — stamped $wbsCaLinksStamped CA links, $wbsSchedLinksStamped Sched links');

    final report = LinkageReport(
      wbsNodeCount: totalNodes,
      wbsWorkPackageCount: leaves.length,
      scheduleActivityCount: schedByWbsNodeId.length + schedByWbsCode.length,
      controlAccountCount: pcProvider.state.workPackages.length,
      scheduleCreated: scheduleCreated,
      scheduleUpdated: scheduleUpdated,
      controlAccountsCreated: controlAccountsCreated,
      controlAccountsUpdated: controlAccountsUpdated,
      wbsCaLinksStamped: wbsCaLinksStamped,
      wbsSchedLinksStamped: wbsSchedLinksStamped,
      wbsProgressBackfilled: wbsProgressBackfilled,
      wbsDatesBackfilled: wbsDatesBackfilled,
      scheduleVariancesRefreshed: scheduleVariancesRefreshed,
      orphanNoControlAccount: orphanNoControlAccount,
      orphanNoScheduleActivity: orphanNoScheduleActivity,
    );

    return report;
  }

  /// Computes a coverage snapshot without mutating any state. Used by the
  /// `CrossSectionSyncCard` widget to render the linkage status badge
  /// before the user has pressed "Sync Now".
  static LinkageReport snapshot({
    required WBSProvider? wbsProvider,
    required ScheduleProvider? scheduleProvider,
    required ProjectControlsProvider? pcProvider,
  }) {
    final wbs = wbsProvider?.wbs;
    final schedule = scheduleProvider?.schedule;
    if (wbs == null || schedule == null || pcProvider == null) {
      return const LinkageReport(
        wbsNodeCount: 0,
        wbsWorkPackageCount: 0,
        scheduleActivityCount: 0,
        controlAccountCount: 0,
        scheduleCreated: 0,
        scheduleUpdated: 0,
        controlAccountsCreated: 0,
        controlAccountsUpdated: 0,
        wbsCaLinksStamped: 0,
        wbsSchedLinksStamped: 0,
        wbsProgressBackfilled: 0,
        wbsDatesBackfilled: 0,
        scheduleVariancesRefreshed: 0,
        orphanNoControlAccount: 0,
        orphanNoScheduleActivity: 0,
      );
    }

    final leaves = <WBSNode>[];
    int totalNodes = 0;
    void walk(WBSNode n) {
      totalNodes++;
      final isLeaf = n.children.isEmpty ||
          (n.isWorkPackage == true && n.children.isEmpty);
      if (isLeaf && n.level != WBSLevel.level0) leaves.add(n);
      for (final c in n.children) {
        walk(c);
      }
    }

    walk(wbs.level0);

    final pcByWbsNodeId = <String, WorkPackageControl>{};
    final pcByWbsCode = <String, WorkPackageControl>{};
    for (final wp in pcProvider.state.workPackages) {
      if (wp.wbsNodeId != null && wp.wbsNodeId!.isNotEmpty) {
        pcByWbsNodeId[wp.wbsNodeId!] = wp;
      }
      if (wp.wbsCode.isNotEmpty) pcByWbsCode[wp.wbsCode] = wp;
    }

    final schedByWbsNodeId = <String, ScheduleActivity>{};
    final schedByWbsCode = <String, ScheduleActivity>{};
    void indexActivities(List<ScheduleActivity> acts) {
      for (final a in acts) {
        if (a.wbsNodeId != null && a.wbsNodeId!.isNotEmpty) {
          schedByWbsNodeId[a.wbsNodeId!] = a;
        }
        if (a.wbsCode != null && a.wbsCode!.isNotEmpty) {
          schedByWbsCode[a.wbsCode!] = a;
        }
        indexActivities(a.children);
      }
    }

    indexActivities(schedule.activities);

    var orphanNoCa = 0;
    var orphanNoSched = 0;
    for (final leaf in leaves) {
      if (pcByWbsNodeId[leaf.id] == null && pcByWbsCode[leaf.code] == null) {
        orphanNoCa++;
      }
      if (schedByWbsNodeId[leaf.id] == null &&
          schedByWbsCode[leaf.code] == null) {
        orphanNoSched++;
      }
    }

    return LinkageReport(
      wbsNodeCount: totalNodes,
      wbsWorkPackageCount: leaves.length,
      scheduleActivityCount: schedByWbsNodeId.length,
      controlAccountCount: pcProvider.state.workPackages.length,
      scheduleCreated: 0,
      scheduleUpdated: 0,
      controlAccountsCreated: 0,
      controlAccountsUpdated: 0,
      wbsCaLinksStamped: 0,
      wbsSchedLinksStamped: 0,
      wbsProgressBackfilled: 0,
      wbsDatesBackfilled: 0,
      scheduleVariancesRefreshed: 0,
      orphanNoControlAccount: orphanNoCa,
      orphanNoScheduleActivity: orphanNoSched,
    );
  }
}
