import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/raci_assignment_service.dart';
import 'package:ndu_project/utils/navigation_route_resolver.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

/// "My RACI Assignments" — a personal dashboard tile that surfaces every
/// deliverable the current user is Responsible / Approver / Reviewer /
/// Consulted / Informed / Viewer for, grouped by phase.
///
/// This is one of the two consumers of [RaciAssignmentService] called out
/// by the user's RACI Matrix spec:
///
///   "FYI, this role assignment is what will feed the project activities
///    log and personal dashboards for all project activities throughout
///    the site."
///
/// The other consumer is [ProjectIntelligenceService._upsertRaciDeliverableActivities],
/// which writes one activity per assignment into `projectActivities`.
///
/// **Person resolution.** The widget tries three signals in order to
/// identify the current user against the Staffing Plan:
///   1. The optional [personName] parameter (caller knows who the user is).
///   2. `FirebaseAuth.instance.currentUser.displayName`.
///   3. `FirebaseAuth.instance.currentUser.email` (local-part match).
///
/// If no match is found, the panel collapses to a compact prompt that lets
/// the user pick themselves from the list of named people on the staffing
/// plan — so the panel is still useful even before the Staffing Plan is
/// fully populated.
///
/// **Inheritance.** All lookups go through [RaciAssignmentService], which
/// keys assignments by role title (not by person name). So when the
/// Staffing Plan swaps person A for person B on a role, B automatically
/// inherits every assignment that was previously A's — no migration
/// needed. This panel just reflects the current state.
class MyRaciAssignmentsPanel extends StatefulWidget {
  const MyRaciAssignmentsPanel({
    super.key,
    this.personName,
    this.compact = false,
    this.showHeader = true,
  });

  /// Hard-coded person name. When non-empty, the panel skips auto-detection
  /// and renders assignments for this person. Pass null to let the widget
  /// resolve the current user from Firebase Auth.
  final String? personName;

  /// Compact mode — smaller padding/fonts for embedding inside narrow
  /// columns or dashboard tiles. Defaults to false.
  final bool compact;

  /// Whether to render the panel header ("My RACI Assignments" + count).
  /// Defaults to true. Set false when nesting inside another card that
  /// already has its own title.
  final bool showHeader;

  @override
  State<MyRaciAssignmentsPanel> createState() => _MyRaciAssignmentsPanelState();
}

class _MyRaciAssignmentsPanelState extends State<MyRaciAssignmentsPanel> {
  /// Person the user has manually selected from the picker. Persists
  /// across rebuilds until they pick someone else.
  String? _manualPersonName;

  ProjectDataModel _data(BuildContext context) =>
      ProjectDataHelper.getData(context, listen: true);

  /// Try to identify the current user against the staffing plan. Returns
  /// the matching [StaffingRequirement.personName] (original casing) or
  /// null if no signal matched.
  String? _resolvePerson(ProjectDataModel data) {
    if (widget.personName != null && widget.personName!.trim().isNotEmpty) {
      return widget.personName!.trim();
    }
    if (_manualPersonName != null && _manualPersonName!.trim().isNotEmpty) {
      return _manualPersonName!.trim();
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final displayName = (user.displayName ?? '').trim().toLowerCase();
    final email = (user.email ?? '').trim().toLowerCase();
    final emailLocalPart = email.split('@').first;
    for (final s in data.staffingRequirements) {
      final personName = s.personName.trim();
      if (personName.isEmpty) continue;
      final lower = personName.toLowerCase();
      if (lower == displayName) return personName;
      if (lower == email) return personName;
      if (emailLocalPart.isNotEmpty && lower == emailLocalPart) {
        return personName;
      }
      // also match " FirstName LastName " against "firstname.lastname"
      final normalized = lower.replaceAll(RegExp(r'\s+'), '.');
      if (emailLocalPart.isNotEmpty && normalized == emailLocalPart) {
        return personName;
      }
    }
    return null;
  }

  /// All named people on the staffing plan, deduplicated, sorted. Used to
  /// populate the manual picker when auto-detection fails.
  List<String> _namedPeople(ProjectDataModel data) {
    final seen = <String>{};
    final out = <String>[];
    for (final s in data.staffingRequirements) {
      final name = s.personName.trim();
      if (name.isEmpty) continue;
      if (seen.add(name.toLowerCase())) out.add(name);
    }
    out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final data = _data(context);
    final isApproved =
        RaciAssignmentService.instance.isMatrixApproved(data);

    final personName = _resolvePerson(data);
    final namedPeople = _namedPeople(data);

    // Header + body.
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFF),
        borderRadius: BorderRadius.circular(widget.compact ? 12 : 16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeader) _buildHeader(isApproved, personName),
            if (widget.showHeader) const SizedBox(height: 12),
            if (!isApproved)
              _buildUnapprovedState()
            else if (personName == null && namedPeople.isEmpty)
              _buildEmptyState()
            else if (personName == null)
              _buildPersonPicker(namedPeople)
            else
              // ignore: unnecessary_non_null_assertion
              _buildAssignments(data, personName!),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isApproved, String? personName) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD24C),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.assignment_ind_outlined,
            color: Colors.black,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My RACI Assignments',
                style: TextStyle(
                  fontSize: widget.compact ? 14 : 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                personName != null
                    ? 'Showing assignments for $personName'
                    : 'Identify yourself to see your assignments',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        // Approval pill — keeps the user aware that these assignments
        // are only authoritative once the PM has approved the matrix.
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isApproved
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isApproved
                  ? const Color(0xFFBBF7D0)
                  : const Color(0xFFFDE68A),
            ),
          ),
          child: Text(
            isApproved ? 'Approved' : 'Pending approval',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isApproved
                  ? const Color(0xFF166534)
                  : const Color(0xFF92400E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnapprovedState() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 16, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'The RACI Matrix hasn\'t been approved yet. Once the PM '
              'approves it, your assignments will appear here and feed '
              'the Project Activities Log.',
              style: TextStyle(
                fontSize: widget.compact ? 11 : 12,
                color: const Color(0xFF92400E),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_off_outlined,
              size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No named people on the Staffing Plan yet. Add a person to '
              'a role on the Staffing Plan to see their RACI assignments '
              'here.',
              style: TextStyle(
                fontSize: widget.compact ? 11 : 12,
                color: const Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonPicker(List<String> namedPeople) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app_outlined,
                  size: 16, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Couldn\'t auto-detect your identity. Pick yourself from '
                  'the Staffing Plan:',
                  style: TextStyle(
                    fontSize: widget.compact ? 11 : 12,
                    color: const Color(0xFF1E3A8A),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              hintText: 'Select your name',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 10),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
            items: namedPeople
                .map((name) => DropdownMenuItem(
                      value: name,
                      child: Text(name,
                          style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _manualPersonName = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAssignments(ProjectDataModel data, String personName) {
    final rows = RaciAssignmentService.instance.deliverablesForPerson(
        personName, data);
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                size: 16, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'You have no RACI assignments yet. Once the matrix is '
                'seeded or assignments are added, your deliverables will '
                'appear here.',
                style: TextStyle(
                  fontSize: widget.compact ? 11 : 12,
                  color: const Color(0xFF475569),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Group by phase, then sort within phase by checkpoint.
    final byPhase = <String, List<RaciDeliverableRow>>{};
    final roleKeys = _roleKeysForPerson(data, personName);
    for (final row in rows) {
      byPhase.putIfAbsent(row.phase.isEmpty ? 'Planning Phase' : row.phase,
          () => []);
      byPhase[row.phase.isEmpty ? 'Planning Phase' : row.phase]!.add(row);
    }
    final phases = byPhase.keys.toList()
      ..sort((a, b) => _phaseOrder(a).compareTo(_phaseOrder(b)));

    final actionItems = RaciAssignmentService.instance
        .actionItemsForRole(_roleTitleForPerson(data, personName), data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stat strip — quick "you have X action items" summary.
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                label: 'Total',
                value: '${rows.length}',
                bg: const Color(0xFFE0E7FF),
                fg: const Color(0xFF4338CA),
              ),
              _pill(
                label: 'Action items (R/A/RV)',
                value: '${actionItems.length}',
                bg: const Color(0xFFFEE2E2),
                fg: const Color(0xFFB91C1C),
              ),
              _pill(
                label: 'Phases',
                value: '${phases.length}',
                bg: const Color(0xFFDCFCE7),
                fg: const Color(0xFF15803D),
              ),
            ],
          ),
        ),
        // Per-phase grouped sections.
        for (final phase in phases) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              phase,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 0.04,
              ),
            ),
          ),
          ...byPhase[phase]!.map((row) => _AssignmentTile(
                row: row,
                personName: personName,
                roleKeys: roleKeys,
                compact: widget.compact,
              )),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  /// Role keys (lowercased role titles) where [personName] is the
  /// current fill on the staffing plan. Used to look up the per-row
  /// designation for this person.
  Set<String> _roleKeysForPerson(ProjectDataModel data, String personName) {
    final needle = personName.trim().toLowerCase();
    return data.staffingRequirements
        .where((s) => s.personName.trim().toLowerCase() == needle)
        .map((s) => RaciAssignmentService.roleKey(s.title))
        .toSet();
  }

  /// Best-effort: pick the first role title for the person. Used to call
  /// [RaciAssignmentService.actionItemsForRole] which expects a single
  /// role. (A person can fill multiple roles; the action-items count is
  /// the union, but for the summary pill we just count the first role
  /// to keep the number stable. The detailed tiles below already show
  /// every assignment across all the person's roles.)
  String _roleTitleForPerson(ProjectDataModel data, String personName) {
    final needle = personName.trim().toLowerCase();
    for (final s in data.staffingRequirements) {
      if (s.personName.trim().toLowerCase() == needle) {
        return s.title;
      }
    }
    return '';
  }

  static int _phaseOrder(String phase) {
    switch (phase) {
      case 'Planning Phase':
        return 0;
      case 'Design Phase':
        return 1;
      case 'Execution Phase':
        return 2;
      case 'Launch Phase':
        return 3;
      default:
        return 9;
    }
  }

  Widget _pill({
    required String label,
    required String value,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: widget.compact ? 10 : 11,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
          children: [
            TextSpan(text: '$value '),
            TextSpan(
              text: label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single deliverable tile inside the "My RACI Assignments" panel.
/// Shows the deliverable name, the user's designation(s) on that row,
/// and (if applicable) the role title under which they're assigned.
class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.row,
    required this.personName,
    required this.roleKeys,
    required this.compact,
  });

  final RaciDeliverableRow row;
  final String personName;
  final Set<String> roleKeys;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Collect every (roleTitle, designation) pair where this person has
    // an assignment on this row. A person can be assigned under
    // multiple roles (e.g. both "Project Manager" and "Scrum Master")
    // — surface each so the user knows which hat they're wearing.
    final pairs = <_RoleDesignationPair>[];
    for (final entry in row.assignments.entries) {
      if (!roleKeys.contains(entry.key)) continue;
      final designation = entry.value.trim().toUpperCase();
      if (designation.isEmpty || !RaciDesignation.isValid(designation)) {
        continue;
      }
      pairs.add(_RoleDesignationPair(
        // entry.key is the lowercased role title — surface it as-is.
        // Original-casing lookup is done in the panel above; here we
        // accept the lowercased form for brevity.
        roleTitle: _prettyRoleTitle(entry.key),
        designation: designation,
      ));
    }
    if (pairs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _navigateToDeliverable(context),
          child: Container(
            padding: EdgeInsets.all(compact ? 8 : 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.label,
                        style: TextStyle(
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: pairs
                            .map((p) => _RoleChip(
                                  roleTitle: p.roleTitle,
                                  designation: p.designation,
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 16, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDeliverable(BuildContext context) {
    if (row.checkpoint.isEmpty) return;
    // Resolve the checkpoint → screen widget via the app's central
    // route resolver. This is the same mechanism the sidebar uses
    // (see _navigateWithCheckpoint in initiation_like_sidebar.dart),
    // minus the planning-phase requirement gating — we want users to
    // be able to open the deliverable even mid-planning so they can
    // see what work is waiting on them.
    final screen = NavigationRouteResolver.resolveCheckpointToScreen(
        row.checkpoint, context);
    if (screen == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static String _prettyRoleTitle(String lowercased) {
    if (lowercased.isEmpty) return lowercased;
    return lowercased
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

class _RoleDesignationPair {
  const _RoleDesignationPair({
    required this.roleTitle,
    required this.designation,
  });
  final String roleTitle;
  final String designation;
}

/// Small inline chip showing "Project Manager • R" with the
/// designation's brand color.
class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.roleTitle,
    required this.designation,
  });

  final String roleTitle;
  final String designation;

  @override
  Widget build(BuildContext context) {
    final color = RaciDesignation.color(designation);
    final bg = Color(color.bg);
    final fg = Color(color.fg);
    final designationLabel = RaciDesignation.label(designation);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
          children: [
            TextSpan(text: roleTitle),
            const TextSpan(
              text: ' · ',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            TextSpan(text: designationLabel),
          ],
        ),
      ),
    );
  }
}
