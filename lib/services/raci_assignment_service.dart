import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';

/// Central read-side service that exposes RACI Deliverable Matrix assignments
/// to the rest of the application.
///
/// This service is the single source of truth for "who is responsible for X"
/// queries. It feeds:
///   * the **Project Activities Log** — every deliverable row contributes
///     activity context (responsible/approver roles + the named person, if
///     any).
///   * **personal dashboards** — each user's dashboard can call
///     [deliverablesForPerson] / [deliverablesForRole] to render the
///     "My Deliverables" panel across every phase of the project.
///
/// Assignments are keyed by **role title** (lowercased), not by person name.
/// This is the mechanism that powers the "replacement inherits items" rule:
/// when the Staffing Plan swaps person A for person B on a given role, every
/// RACI cell attached to that role is automatically inherited by B — no
/// migration needed.
class RaciAssignmentService {
  RaciAssignmentService._();
  static final RaciAssignmentService instance = RaciAssignmentService._();

  /// Normalize a role title into a stable lookup key.
  static String roleKey(String roleTitle) =>
      roleTitle.trim().toLowerCase();

  /// Lookup the person currently filling [roleTitle] on the staffing plan,
  /// or empty string if no staffing requirement matches the role.
  static String personForRole(
      String roleTitle, List<StaffingRequirement> staffing) {
    final key = roleKey(roleTitle);
    for (final s in staffing) {
      if (roleKey(s.title) == key && s.personName.trim().isNotEmpty) {
        return s.personName.trim();
      }
    }
    return '';
  }

  /// Return every deliverable row where [roleTitle] has any non-empty
  /// designation. Used by personal dashboards' "My Deliverables" panel.
  List<RaciDeliverableRow> deliverablesForRole(
      String roleTitle, ProjectDataModel data) {
    final key = roleKey(roleTitle);
    if (key.isEmpty) return const [];
    return data.raciDeliverableRows
        .where((row) => (row.assignments[key] ?? '').trim().isNotEmpty)
        .toList(growable: false);
  }

  /// Return every deliverable row where the person currently filling
  /// [roleTitle] is responsible, approver, or reviewer (i.e. they have
  /// active work to do). Used by the personal dashboard's "Action Items"
  /// card.
  List<RaciDeliverableRow> actionItemsForRole(
      String roleTitle, ProjectDataModel data) {
    final key = roleKey(roleTitle);
    if (key.isEmpty) return const [];
    const active = {'R', 'A', 'RV'};
    return data.raciDeliverableRows.where((row) {
      final code = (row.assignments[key] ?? '').toUpperCase();
      return active.contains(code);
    }).toList(growable: false);
  }

  /// Return every deliverable row where [personName] is the current fill
  /// for some role on the staffing plan AND that role has any designation
  /// on the row. Falls back to role-based lookup if [personName] is empty.
  List<RaciDeliverableRow> deliverablesForPerson(
      String personName, ProjectDataModel data) {
    final needle = personName.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final roles = data.staffingRequirements
        .where((s) => s.personName.trim().toLowerCase() == needle)
        .map((s) => roleKey(s.title))
        .toSet();
    if (roles.isEmpty) return const [];
    return data.raciDeliverableRows.where((row) {
      return row.assignments.entries
          .any((e) => roles.contains(e.key) && e.value.trim().isNotEmpty);
    }).toList(growable: false);
  }

  /// Roles (with their designation code) that have any assignment on the
  /// given sidebar [checkpoint]. Used by the project activities log to show
  /// "owners" of a deliverable.
  List<({String roleTitle, String personName, String designation})>
      ownersForDeliverable(
          String checkpoint, ProjectDataModel data) {
    final row = data.raciDeliverableRows
        .firstWhere((r) => r.checkpoint == checkpoint,
            orElse: () => RaciDeliverableRow());
    if (row.id.isEmpty) return const [];
    final out =
        <({String roleTitle, String personName, String designation})>[];
    final staffingByRole = <String, StaffingRequirement>{};
    for (final s in data.staffingRequirements) {
      staffingByRole.putIfAbsent(roleKey(s.title), () => s);
    }
    for (final entry in row.assignments.entries) {
      final designation = entry.value.trim().toUpperCase();
      if (designation.isEmpty) continue;
      final staff = staffingByRole[entry.key];
      out.add((
        roleTitle: staff?.title ?? entry.key,
        personName: staff?.personName ?? '',
        designation: designation,
      ));
    }
    return out;
  }

  /// Return only the "Responsible" (R) roles for a deliverable. Falls back
  /// to Approvers (A) if no R is assigned. Used by the activities log for
  /// the "Owner" column.
  List<({String roleTitle, String personName})> responsibleForDeliverable(
      String checkpoint, ProjectDataModel data) {
    final owners = ownersForDeliverable(checkpoint, data);
    final r = owners
        .where((o) => o.designation == RaciDesignation.responsible)
        .map((o) => (roleTitle: o.roleTitle, personName: o.personName))
        .toList();
    if (r.isNotEmpty) return r;
    return owners
        .where((o) => o.designation == RaciDesignation.approver)
        .map((o) => (roleTitle: o.roleTitle, personName: o.personName))
        .toList();
  }

  /// Returns true if the matrix has been approved and is therefore the
  /// "live" basis for downstream personal dashboards / activities log.
  bool isMatrixApproved(ProjectDataModel data) =>
      data.raciApprovalStatus.isApproved;

  /// Sidebar items (Planning → Launch) that should appear as deliverable
  /// rows on the matrix. Items outside this range (Initiation, Front End
  /// Planning) are intentionally excluded — they are pre-execution
  /// governance steps that the matrix does not cover.
  List<SidebarItem> matrixScopeSidebarItems() {
    const phases = {
      'Planning Phase',
      'Design Phase',
      'Execution Phase',
      'Launch Phase',
    };
    return SidebarNavigationService.allItems
        .where((item) => phases.contains(
            SidebarNavigationService.phaseForCheckpoint(item.checkpoint) ?? ''))
        .toList(growable: false);
  }
}
