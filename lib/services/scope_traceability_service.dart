import 'package:ndu_project/models/scope_tracking_item.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/cbs_element_model.dart';
import 'package:ndu_project/models/obs_element_model.dart';
import 'package:ndu_project/models/control_account_model.dart';

/// ── P3.7: Scope Traceability Automation Service ──
///
/// Automatically links [ScopeTrackingItem]s to their corresponding WBS, CBS,
/// and OBS elements based on matching rules. This ensures full traceability
/// across the project controls hierarchy without manual cross-referencing.
///
/// Traceability rules:
/// 1. **WBS linkage**: Match by `wbsId` if set; otherwise by `scheduleActivityId`
///    (find the activity's `wbsId`).
/// 2. **CBS linkage**: Match by `cbsId` if set; otherwise find the CBS element
///    whose `wbsId` matches the scope item's `wbsId` (same work element = same cost).
/// 3. **OBS linkage**: Match by `obsId` if set; otherwise find the OBS element
///    whose `wbsId` matches (responsible org for that work element).
/// 4. **Control Account linkage**: Find the control account at the WBS+OBS
///    intersection for the scope item's work element.
/// 5. **Weight assignment**: Auto-assign equal weight if unset.
class ScopeTraceabilityService {
  /// Auto-link scope tracking items to WBS/CBS/OBS/control accounts.
  ///
  /// Returns a new list of [ScopeTrackingItem]s with cross-references populated.
  /// Items that already have cross-references set are left unchanged.
  static List<ScopeTrackingItem> autoLink({
    required List<ScopeTrackingItem> scopeItems,
    required List<ScheduleActivity> activities,
    required List<WorkPackage> workPackages,
    required List<ControlAccount> controlAccounts,
    required List<CbsElement> cbsElements,
    required List<ObsElement> obsElements,
    required List<WorkItem> wbsTree,
  }) {
    // Build lookup maps
    final activityById = {for (final a in activities) a.id: a};
    final workPackageById = {for (final wp in workPackages) wp.id: wp};
    final caByWbsId = <String, ControlAccount>{};
    for (final ca in controlAccounts) {
      if (ca.wbsId.isNotEmpty) {
        caByWbsId[ca.wbsId] = ca;
      }
    }
    final cbsByWbsId = <String, CbsElement>{};
    for (final cbs in cbsElements) {
      if (cbs.wbsId.isNotEmpty) {
        cbsByWbsId[cbs.wbsId] = cbs;
      }
    }
    final obsByWbsId = <String, ObsElement>{};
    for (final obs in obsElements) {
      if (obs.wbsId.isNotEmpty) {
        obsByWbsId[obs.wbsId] = obs;
      }
    }

    // Flatten WBS tree for ID-based lookups
    final wbsById = <String, WorkItem>{};
    void flattenWbs(List<WorkItem> items) {
      for (final item in items) {
        wbsById[item.id] = item;
        flattenWbs(item.children);
      }
    }
    flattenWbs(wbsTree);

    // Count items needing weight assignment per group
    final unweightedCount = scopeItems.where((s) => s.weight == 0).length;

    return scopeItems.map((item) {
      String wbsId = item.wbsId;
      String cbsId = item.cbsId;
      String obsId = item.obsId;
      String controlAccountId = item.controlAccountId;
      double weight = item.weight;

      // ── Step 1: Resolve WBS ID ──
      if (wbsId.isEmpty && item.scheduleActivityId.isNotEmpty) {
        final activity = activityById[item.scheduleActivityId];
        if (activity != null && activity.wbsId.isNotEmpty) {
          wbsId = activity.wbsId;
        }
      }

      // ── Step 2: Resolve CBS ID ──
      if (cbsId.isEmpty && wbsId.isNotEmpty) {
        final cbs = cbsByWbsId[wbsId];
        if (cbs != null) {
          cbsId = cbs.id;
        }
      }

      // ── Step 3: Resolve OBS ID ──
      if (obsId.isEmpty && wbsId.isNotEmpty) {
        final obs = obsByWbsId[wbsId];
        if (obs != null) {
          obsId = obs.id;
        }
      }

      // ── Step 4: Resolve Control Account ID ──
      if (controlAccountId.isEmpty && wbsId.isNotEmpty) {
        final ca = caByWbsId[wbsId];
        if (ca != null) {
          controlAccountId = ca.id;
        }
        // Also check if the schedule activity has a control account
        if (controlAccountId.isEmpty && item.scheduleActivityId.isNotEmpty) {
          final activity = activityById[item.scheduleActivityId];
          if (activity != null && activity.controlAccountId.isNotEmpty) {
            controlAccountId = activity.controlAccountId;
          }
        }
      }

      // ── Step 5: Auto-assign equal weight ──
      if (weight == 0 && unweightedCount > 0) {
        weight = 1.0 / unweightedCount;
      }

      // Only return a new item if any field changed
      if (wbsId == item.wbsId &&
          cbsId == item.cbsId &&
          obsId == item.obsId &&
          controlAccountId == item.controlAccountId &&
          weight == item.weight) {
        return item;
      }

      return item.copyWith(
        wbsId: wbsId,
        cbsId: cbsId,
        obsId: obsId,
        controlAccountId: controlAccountId,
        weight: weight,
      );
    }).toList();
  }

  /// Build a traceability matrix showing which scope items link to which
  /// WBS/CBS/OBS elements. Useful for gap analysis and compliance reporting.
  ///
  /// Returns a list of maps, each representing one scope item's traceability:
  /// ```
  /// {
  ///   'scopeItemId': '...',
  ///   'scopeItem': '...',
  ///   'wbsId': '...', 'wbsCode': '...', 'wbsTitle': '...',
  ///   'cbsId': '...', 'cbsCode': '...', 'cbsName': '...',
  ///   'obsId': '...', 'obsName': '...', 'obsManager': '...',
  ///   'controlAccountId': '...', 'caTitle': '...',
  ///   'isFullyTraced': true/false,
  /// }
  /// ```
  static List<Map<String, dynamic>> buildTraceabilityMatrix({
    required List<ScopeTrackingItem> scopeItems,
    required List<WorkItem> wbsTree,
    required List<CbsElement> cbsElements,
    required List<ObsElement> obsElements,
    required List<ControlAccount> controlAccounts,
  }) {
    final wbsById = <String, WorkItem>{};
    void flattenWbs(List<WorkItem> items) {
      for (final item in items) {
        wbsById[item.id] = item;
        flattenWbs(item.children);
      }
    }
    flattenWbs(wbsTree);

    final cbsById = {for (final cbs in cbsElements) cbs.id: cbs};
    final obsById = {for (final obs in obsElements) obs.id: obs};
    final caById = {for (final ca in controlAccounts) ca.id: ca};

    return scopeItems.map((item) {
      final wbs = wbsById[item.wbsId];
      final cbs = cbsById[item.cbsId];
      final obs = obsById[item.obsId];
      final ca = caById[item.controlAccountId];

      final hasWbs = item.wbsId.isNotEmpty;
      final hasCbs = item.cbsId.isNotEmpty;
      final hasObs = item.obsId.isNotEmpty;
      final hasCa = item.controlAccountId.isNotEmpty;

      return {
        'scopeItemId': item.id,
        'scopeItem': item.scopeItem,
        'wbsId': item.wbsId,
        'wbsCode': wbs?.wbsCode ?? '',
        'wbsTitle': wbs?.title ?? '',
        'cbsId': item.cbsId,
        'cbsCode': cbs?.code ?? '',
        'cbsName': cbs?.name ?? '',
        'obsId': item.obsId,
        'obsName': obs?.name ?? '',
        'obsManager': obs?.manager ?? '',
        'controlAccountId': item.controlAccountId,
        'caTitle': ca?.title ?? '',
        'isFullyTraced': hasWbs && hasCbs && hasObs && hasCa,
      };
    }).toList();
  }

  /// Find scope items with missing traceability links.
  /// Returns items that are not linked to WBS, CBS, OBS, or control account.
  static List<ScopeTrackingItem> findUntracedItems(
      List<ScopeTrackingItem> scopeItems) {
    return scopeItems
        .where((item) =>
            item.wbsId.isEmpty ||
            item.cbsId.isEmpty ||
            item.obsId.isEmpty ||
            item.controlAccountId.isEmpty)
        .toList();
  }
}
