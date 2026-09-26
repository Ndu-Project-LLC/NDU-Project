/// CR → Project Controls variance attribution (Lusaka 22 ask 7).
///
/// When a change request is approved/implemented, the affected work
/// packages' cost and schedule move off the baseline. Project Controls must
/// show that actual-vs-plan delta with the *reason* being the change request
/// number — "the reason will be because of the change request 101, or CR01,
/// whatever the number of this change request is."
///
/// [syncCrVarianceAttribution] is a pure read-and-stamp pass: it walks the
/// CM module's approved/implemented/closed change requests, matches each
/// affected work package against the Project Controls `WorkPackageControl`
/// rows (by id, WBS code, or name), and upserts the schedule-variance
/// attribution through the provider. Re-runnable and idempotent — a CR that
/// is already named on a variance row is not re-stamped.
library;

import 'package:ndu_project/project_controls/models/project_controls_models.dart';
import 'package:ndu_project/project_controls/providers/project_controls_provider.dart';
import 'package:ndu_project/project_controls/models/change_management_models.dart'
    as cm;

/// Statuses whose impact is live in Project Controls: approved (baseline
/// rebaselined), implemented, or closed.
const Set<cm.CMStatus> _liveStatuses = {
  cm.CMStatus.approved,
  cm.CMStatus.implemented,
  cm.CMStatus.closed,
};

/// Composes the delay-reason line for a change request, e.g.
/// `CR-2026-003: Accelerate Steel Delivery (+14d schedule)`.
String varianceReasonFor(cm.CMChangeRequest cr) {
  final buf = StringBuffer('${cr.crNumber}: ${cr.title.trim()}');
  final sched = cr.scheduleDaysImpact ?? 0;
  if (sched > 0) {
    buf.write(' (+${sched}d schedule)');
  } else if (sched < 0) {
    buf.write(' (${sched}d schedule)');
  }
  return buf.toString();
}

/// True when [cr] affects the work package [wpc] — matched by implementation
/// task id/name, WBS code, or work-package name.
bool changeRequestAffectsWorkPackage(
  cm.CMChangeRequest cr,
  WorkPackageControl wpc,
) {
  final name = wpc.name.trim().toLowerCase();
  final code = wpc.wbsCode.trim().toLowerCase();
  if (name.isEmpty && code.isEmpty) return false;

  for (final task in cr.implementationTasks) {
    if (task.workPackageId.trim() == wpc.id.trim()) return true;
    final taskName = task.workPackageName.trim().toLowerCase();
    if (taskName.isNotEmpty && taskName == name) return true;
  }
  for (final raw in cr.affectedWorkPackages) {
    final wp = raw.trim();
    if (wp.isEmpty) continue;
    final lower = wp.toLowerCase();
    if (code.isNotEmpty && lower.contains(code)) return true;
    if (lower == name) return true;
    if (name.isNotEmpty && lower.contains(name)) return true;
  }
  return false;
}

/// Stamps every Project Controls work package affected by a live (approved /
/// implemented / closed) change request with that CR's number as the variance
/// reason. Returns the number of variance rows attributed.
int syncCrVarianceAttribution({
  required List<cm.CMChangeRequest> changeRequests,
  required ProjectControlsProvider provider,
}) {
  var stamped = 0;
  final live =
      changeRequests.where((cr) => _liveStatuses.contains(cr.status)).toList();
  if (live.isEmpty) return 0;

  final workPackages =
      List<WorkPackageControl>.from(provider.state.workPackages);
  for (final cr in live) {
    final reason = varianceReasonFor(cr);
    for (final wpc in workPackages) {
      if (!changeRequestAffectsWorkPackage(cr, wpc)) continue;
      provider.attributeScheduleVarianceToChangeRequest(
        wpc.id,
        crNumber: cr.crNumber,
        reason: reason,
      );
      stamped++;
    }
  }
  return stamped;
}
