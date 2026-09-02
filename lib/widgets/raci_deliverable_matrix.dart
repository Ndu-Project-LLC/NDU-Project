import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/raci_assignment_service.dart';
import 'package:ndu_project/services/raci_matrix_seeder.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';
import 'package:ndu_project/providers/user_role_provider.dart';

/// Renders the new RACI Deliverable Matrix.
///
/// **Layout**
///   * Rows (left): every sidebar deliverable from Planning Phase → Launch
///     Phase. The leftmost column is a frozen "Deliverable" column showing
///     the deliverable name + phase chip.
///   * Columns (top): one column per role identified on the Staffing Plan
///     (and any extra roles from the Roles & Responsibilities screen).
///     If the Staffing Plan has named a person for the role, their name
///     appears under the role title in the column header.
///   * Cells: a colored RACI pill (R / A / C / RV / I / V). Tapping a cell
///     opens a small dropdown to change the designation. Empty cells show
///     a dashed pill (no assignment).
///
/// **Scroll**
///   The matrix scrolls left/right and up/down. The first column (deliverable
///   label) is frozen via a horizontal scroll view + a parallel frozen
///   column widget.
///
/// **Expand**
///   A full-screen view is provided via [FullScreenTableWrapper].
///
/// **Approval**
///   An approval banner is rendered above the matrix. Clicking "Click to
///   approve Matrix" shows the confirmation text:
///     "I confirm stakeholder alignment on all deliverable responsibility
///     assignments, forming the basis for project execution."
///   On approval, [RaciApprovalStatus] is persisted with the approver name,
///   role, and timestamp. Any subsequent cell edit resets approval.
///
/// **Inheritance**
///   Assignments are keyed by **role title** (lowercased) — never by person
///   name. When the Staffing Plan changes the person filling a role, the
///   new person automatically inherits every cell attached to that role.
class RaciDeliverableMatrix extends StatefulWidget {
  const RaciDeliverableMatrix({
    super.key,
    this.compact = false,
    this.showHeader = true,
    this.showToolbar = true,
  });

  /// Compact mode — smaller padding/fonts for embedding inside other
  /// screens (e.g. a dashboard preview tile).
  final bool compact;

  /// Whether to render the screen-level header (title + description).
  final bool showHeader;

  /// Whether to render the toolbar (Sync, Reset, Add Custom, Export).
  final bool showToolbar;

  @override
  State<RaciDeliverableMatrix> createState() => _RaciDeliverableMatrixState();
}

class _RaciDeliverableMatrixState extends State<RaciDeliverableMatrix> {
  bool _isSeeding = false;

  // ─── Data accessors ────────────────────────────────────────────────
  ProjectDataModel _data(BuildContext context) =>
      ProjectDataHelper.getProvider(context).projectData;

  List<RoleDefinition> _columns(ProjectDataModel data) {
    final seen = <String>{};
    final out = <RoleDefinition>[];
    for (final s in data.staffingRequirements) {
      final title = s.title.trim();
      if (title.isEmpty) continue;
      final key = RaciAssignmentService.roleKey(title);
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(RoleDefinition(
        title: title,
        workstream: s.employeeType,
        description: s.notes,
        headcount: s.headcount,
      ));
    }
    for (final r in data.projectRoles) {
      final title = r.title.trim();
      if (title.isEmpty) continue;
      final key = RaciAssignmentService.roleKey(title);
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(r);
    }
    return out;
  }

  String _personFor(ProjectDataModel data, String roleTitle) {
    return RaciAssignmentService.personForRole(roleTitle, data.staffingRequirements);
  }

  // ─── Mutations ─────────────────────────────────────────────────────
  Future<void> _seedMatrix(BuildContext context) async {
    setState(() => _isSeeding = true);
    try {
      final data = _data(context);
      final rows = RaciMatrixSeeder.seed(data);
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'organization_raci_matrix',
        dataUpdater: (d) => d.copyWith(raciDeliverableRows: rows),
        showSnackbar: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'RACI Matrix auto-generated. Roles from the Staffing Plan '
                'have been distributed across all Planning → Launch deliverables.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  Future<void> _syncRoles(BuildContext context) async {
    setState(() => _isSeeding = true);
    try {
      final data = _data(context);
      final rows = RaciMatrixSeeder.syncRoles(data);
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'organization_raci_matrix',
        dataUpdater: (d) => d.copyWith(raciDeliverableRows: rows),
        showSnackbar: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Matrix synced with current Staffing Plan. New roles were '
                'auto-distributed; removed roles were cleared.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  /// Auto-fill empty RACI cells using roles from both the Staffing Plan
  /// and the Roles & Responsibilities page. Existing manual assignments
  /// are preserved — only empty cells are filled.
  Future<void> _prefillFromRoles(BuildContext context) async {
    setState(() => _isSeeding = true);
    try {
      final data = _data(context);
      final rows = RaciMatrixSeeder.syncRoles(data);
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'organization_raci_matrix',
        dataUpdater: (d) => d.copyWith(raciDeliverableRows: rows),
        showSnackbar: false,
      );
      if (mounted) {
        final roleCount = _columns(data).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'RACI auto-filled for $roleCount role${roleCount == 1 ? '' : 's'} '
                'from Staffing Plan & Roles & Responsibilities. Existing '
                'assignments were preserved.'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  Future<void> _setCell(BuildContext context, RaciDeliverableRow row,
      String roleKey, String designation) async {
    final data = _data(context);
    final rows = List<RaciDeliverableRow>.from(data.raciDeliverableRows);
    final idx = rows.indexWhere((r) => r.id == row.id);
    if (idx == -1) return;
    final newAssignments = Map<String, String>.from(rows[idx].assignments);
    if (designation.isEmpty) {
      newAssignments.remove(roleKey);
    } else {
      newAssignments[roleKey] = designation;
    }
    rows[idx] = rows[idx].copyWith(assignments: newAssignments);
    // Any cell edit resets approval — the matrix must be re-approved
    // before it can again be considered the basis for execution.
    final approval = data.raciApprovalStatus.copyWith(isApproved: false);
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'organization_raci_matrix',
      dataUpdater: (d) => d.copyWith(
        raciDeliverableRows: rows,
        raciApprovalStatus: approval,
      ),
      showSnackbar: false,
    );
    if (mounted) setState(() {});
  }

  Future<void> _setRowDesignation(
      BuildContext context, RaciDeliverableRow row, String designation) async {
    final data = _data(context);
    final rows = List<RaciDeliverableRow>.from(data.raciDeliverableRows);
    final idx = rows.indexWhere((r) => r.id == row.id);
    if (idx == -1) return;
    final columns = _columns(data);
    final newAssignments = <String, String>{};
    for (final role in columns) {
      final key = RaciAssignmentService.roleKey(role.title);
      final current = row.assignments[key] ?? '';
      // Only fill empty cells — preserve existing manual assignments.
      if (current.isEmpty && designation.isNotEmpty) {
        newAssignments[key] = designation;
      } else {
        newAssignments[key] = current;
      }
    }
    rows[idx] = rows[idx].copyWith(assignments: newAssignments);
    final approval = data.raciApprovalStatus.copyWith(isApproved: false);
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'organization_raci_matrix',
      dataUpdater: (d) => d.copyWith(
        raciDeliverableRows: rows,
        raciApprovalStatus: approval,
      ),
      showSnackbar: false,
    );
    if (mounted) setState(() {});
  }

  Future<void> _clearRow(BuildContext context, RaciDeliverableRow row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear row assignments?'),
        content: Text(
            'All RACI designations for "${row.label}" will be removed. '
            'The deliverable row itself is kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final data = _data(context);
    final rows = List<RaciDeliverableRow>.from(data.raciDeliverableRows);
    final idx = rows.indexWhere((r) => r.id == row.id);
    if (idx == -1) return;
    rows[idx] = rows[idx].copyWith(assignments: <String, String>{});
    final approval = data.raciApprovalStatus.copyWith(isApproved: false);
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'organization_raci_matrix',
      dataUpdater: (d) => d.copyWith(
        raciDeliverableRows: rows,
        raciApprovalStatus: approval,
      ),
      showSnackbar: false,
    );
    if (mounted) setState(() {});
  }

  // ─── Approval ──────────────────────────────────────────────────────
  Future<void> _openApprovalDialog(BuildContext context) async {
    final data = _data(context);
    final approval = data.raciApprovalStatus;
    
    // Auto-fill with authenticated user's details if fields are empty
    final currentUserDisplayName = FirebaseAuthService.displayNameOrEmail(fallback: '');
    final roleProvider = UserRoleInherited.of(context);
    final currentUserRole = roleProvider.siteRole.displayName;
    
    final approverNameController = TextEditingController(
      text: approval.approverName.isNotEmpty ? approval.approverName : currentUserDisplayName,
    );
    final approverRoleController = TextEditingController(
      text: approval.approverRole.isNotEmpty ? approval.approverRole : currentUserRole,
    );
    bool checked = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: const Row(
            children: [
              Icon(Icons.verified, color: Color(0xFFFFC812)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Approve RACI Matrix',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Approver details',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: approverNameController,
                  decoration: const InputDecoration(
                    labelText: 'Approver name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: approverRoleController,
                  decoration: const InputDecoration(
                    labelText: 'Approver role (e.g. Project Manager, Sponsor)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: checked,
                        onChanged: (v) =>
                            setState(() => checked = v ?? false),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            approval.confirmationText,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF334155),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: checked &&
                      approverNameController.text.trim().isNotEmpty
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD24C),
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Approve Matrix'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    final newApproval = RaciApprovalStatus(
      isApproved: true,
      approverName: approverNameController.text.trim(),
      approverRole: approverRoleController.text.trim(),
      approvedAt: DateTime.now(),
      confirmationText: approval.confirmationText,
    );
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'organization_raci_matrix',
      dataUpdater: (d) => d.copyWith(raciApprovalStatus: newApproval),
      showSnackbar: false,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'RACI Matrix approved by ${newApproval.approverName}. '
              'Assignments now feed the Project Activities Log and '
              'personal dashboards.'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _revokeApproval(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke approval?'),
        content: const Text(
            'The matrix will return to draft mode. Personal dashboards and '
            'the activities log will keep the last-approved assignments '
            'until a new approval is recorded.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final data = _data(context);
    final newApproval =
        data.raciApprovalStatus.copyWith(isApproved: false);
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'organization_raci_matrix',
      dataUpdater: (d) => d.copyWith(raciApprovalStatus: newApproval),
      showSnackbar: false,
    );
    if (mounted) setState(() {});
  }

  // ─── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final data = _data(context);
    final rows = data.raciDeliverableRows;
    final columns = _columns(data);
    final approval = data.raciApprovalStatus;
    final isCompact = widget.compact;

    // If matrix is empty, auto-seed on first render.
    if (rows.isEmpty && !_isSeeding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _data(context).raciDeliverableRows.isEmpty) {
          _seedMatrix(context);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          _buildHeader(approval),
          const SizedBox(height: 16),
        ],
        if (widget.showToolbar) ...[
          _buildToolbar(context, data),
          const SizedBox(height: 16),
        ],
        _buildApprovalBanner(context, approval),
        const SizedBox(height: 16),
        _buildLegend(),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          _buildEmptyState()
        else if (columns.isEmpty)
          _buildNoRolesState()
        else
          _buildMatrixCard(context, rows, columns, data, isCompact),
      ],
    );
  }

  // ─── Header ────────────────────────────────────────────────────────
  Widget _buildHeader(RaciApprovalStatus approval) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.grid_on, size: 22, color: Color(0xFF111827)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'RACI Deliverable Matrix',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            _ApprovalBadge(approved: approval.isApproved),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Auto-customized to your project scope. Sidebar deliverables '
          '(Planning → Launch) run down the left; positions identified on '
          'the Roles & Responsibilities page run across the top. AI takes '
          'the first stab at distributing each deliverable to the '
          'applicable roles per the Staffing Plan.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.45),
        ),
      ],
    );
  }

  // ─── Toolbar ───────────────────────────────────────────────────────
  Widget _buildToolbar(BuildContext context, ProjectDataModel data) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ElevatedButton.icon(
          onPressed: _isSeeding ? null : () => _syncRoles(context),
          icon: _isSeeding
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync, size: 16),
          label: const Text('Sync with Staffing Plan'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC107),
            foregroundColor: const Color(0xFF1F2933),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isSeeding ? null : () => _prefillFromRoles(context),
          icon: const Icon(Icons.person_add_outlined, size: 16),
          label: const Text('Auto-fill from Roles & Responsibilities'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _isSeeding ? null : () => _seedMatrix(context),
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: const Text('Reset AI Suggestions'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (data.raciApprovalStatus.isApproved)
          OutlinedButton.icon(
            onPressed: () => _revokeApproval(context),
            icon: const Icon(Icons.lock_open, size: 16),
            label: const Text('Revoke approval'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB91C1C),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
      ],
    );
  }

  // ─── Approval banner ───────────────────────────────────────────────
  Widget _buildApprovalBanner(
      BuildContext context, RaciApprovalStatus approval) {
    final isApproved = approval.isApproved;
    final color = isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7);
    final border =
        isApproved ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D);
    final fg =
        isApproved ? const Color(0xFF15803D) : const Color(0xFF92400E);
    final icon = isApproved ? Icons.verified : Icons.lock_clock;
    final title = isApproved
        ? 'Matrix approved — basis for project execution'
        : 'Matrix in draft — approval required to activate';
    final subtitle = isApproved
        ? 'Approved by ${approval.approverName}'
            '${approval.approverRole.isNotEmpty ? ' (${approval.approverRole})' : ''}'
            '${approval.approvedAt != null ? ' on ${_formatDate(approval.approvedAt!)}' : ''}. '
            'Assignments now feed the Project Activities Log and personal dashboards.'
        : 'Editing cells is enabled. Once the matrix reflects stakeholder '
            'alignment, the Project Manager (or highest role) must approve '
            'it before downstream activities pick up the assignments.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12.5, color: fg, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!isApproved)
            ElevatedButton(
              onPressed: () => _openApprovalDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Click to approve Matrix'),
            ),
        ],
      ),
    );
  }

  // ─── Legend ────────────────────────────────────────────────────────
  Widget _buildLegend() {
    final chips = [
      ('R', 'Responsible'),
      ('A', 'Approver'),
      ('C', 'Consulted'),
      ('RV', 'Reviewer'),
      ('I', 'Informed'),
      ('V', 'Viewer'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map((c) => _LegendChip(code: c.$1, label: c.$2))
          .toList(growable: false),
    );
  }

  // ─── Empty / no roles states ───────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), style: BorderStyle.solid),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_on_outlined, size: 36, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text('Building matrix…',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text(
              'The first pass is being generated from your Staffing Plan.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRolesState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_off, size: 36, color: Color(0xFFB45309)),
            SizedBox(height: 12),
            Text('No roles identified yet',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text(
              'Add positions to the Staffing Plan or Roles & Responsibilities '
              'page first — the matrix pulls its columns from there.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Matrix card ───────────────────────────────────────────────────
  Widget _buildMatrixCard(BuildContext context, List<RaciDeliverableRow> rows,
      List<RoleDefinition> columns, ProjectDataModel data, bool isCompact) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: FullScreenTableWrapper(
        title: 'RACI Deliverable Matrix',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: _RaciMatrixGrid(
            rows: rows,
            columns: columns,
            data: data,
            compact: isCompact,
            onCellTap: (row, roleKey) =>
                _showCellEditor(context, row, roleKey),
            onRowMenu: (row) => _showRowMenu(context, row),
          ),
        ),
        tableBuilder: (fsContext) => ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: _RaciMatrixGrid(
            rows: rows,
            columns: columns,
            data: data,
            compact: false,
            onCellTap: (row, roleKey) =>
                _showCellEditor(context, row, roleKey),
            onRowMenu: (row) => _showRowMenu(context, row),
          ),
        ),
      ),
    );
  }

  // ─── Cell editor ───────────────────────────────────────────────────
  Future<void> _showCellEditor(
      BuildContext context, RaciDeliverableRow row, String roleKey) async {
    final current = (row.assignments[roleKey] ?? '').toUpperCase();
    String? selected = current.isEmpty ? null : current;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(row.label.isEmpty ? 'Edit cell' : row.label),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phase: ${row.phase}',
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFF6B7280))),
                const SizedBox(height: 12),
                const Text('Choose a designation:',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final code in RaciDesignation.all)
                      ChoiceChip(
                        label: Text(
                            '$code — ${RaciDesignation.label(code)}',
                            style: const TextStyle(fontSize: 12)),
                        selected: selected == code,
                        onSelected: (sel) {
                          if (sel) {
                            setState(() => selected = code);
                          }
                        },
                        selectedColor:
                            Color(RaciDesignation.color(code).bg),
                        labelStyle: TextStyle(
                            color: Color(RaciDesignation.color(code).fg),
                            fontWeight: FontWeight.w700),
                      ),
                    ActionChip(
                      label: const Text('Clear cell',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFFB91C1C))),
                      onPressed: () {
                        Navigator.pop(ctx, '');
                      },
                    ),
                  ],
                ),
                if (selected != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      RaciDesignation.description(selected!),
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(ctx, selected),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await _setCell(context, row, roleKey, result);
  }

  Future<void> _showRowMenu(
      BuildContext context, RaciDeliverableRow row) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                row.label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFFFFC812)),
              title: const Text('Bulk-fill empty cells'),
              subtitle: const Text(
                  'Apply one designation to every empty cell on this row.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(sheetContext, 'bulk'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.clear, color: Color(0xFFB91C1C)),
              title: const Text('Clear all assignments on this row'),
              onTap: () => Navigator.pop(sheetContext, 'clear'),
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Color(0xFF6B7280)),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(sheetContext, null),
            ),
          ],
        ),
      ),
    );
    if (action == 'bulk') {
      final designation = await _pickDesignationForBulk(context);
      if (designation == null) return;
      await _setRowDesignation(context, row, designation);
    } else if (action == 'clear') {
      await _clearRow(context, row);
    }
  }

  Future<String?> _pickDesignationForBulk(BuildContext context) async {
    String? picked;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Bulk-fill designation'),
          content: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final code in RaciDesignation.all)
                ChoiceChip(
                  label: Text(
                      '$code — ${RaciDesignation.label(code)}',
                      style: const TextStyle(fontSize: 12)),
                  selected: picked == code,
                  onSelected: (sel) {
                    if (sel) setState(() => picked = code);
                  },
                  selectedColor: Color(RaciDesignation.color(code).bg),
                  labelStyle: TextStyle(
                      color: Color(RaciDesignation.color(code).fg),
                      fontWeight: FontWeight.w700),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: picked == null
                  ? null
                  : () => Navigator.pop(ctx, picked),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────

class _ApprovalBadge extends StatelessWidget {
  const _ApprovalBadge({required this.approved});
  final bool approved;

  @override
  Widget build(BuildContext context) {
    final color =
        approved ? const Color(0xFF15803D) : const Color(0xFFB45309);
    final bg =
        approved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7);
    final label = approved ? 'APPROVED' : 'DRAFT';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(approved ? Icons.verified : Icons.lock_clock,
              size: 12, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.code, required this.label});
  final String code;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = RaciDesignation.color(code);
    final bg = Color(c.bg);
    final fg = Color(c.fg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(code,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        ],
      ),
    );
  }
}

// ─── Matrix grid (frozen first column + scrollable columns) ──────────

class _RaciMatrixGrid extends StatelessWidget {
  const _RaciMatrixGrid({
    required this.rows,
    required this.columns,
    required this.data,
    required this.compact,
    required this.onCellTap,
    required this.onRowMenu,
  });

  final List<RaciDeliverableRow> rows;
  final List<RoleDefinition> columns;
  final ProjectDataModel data;
  final bool compact;
  final void Function(RaciDeliverableRow row, String roleKey) onCellTap;
  final void Function(RaciDeliverableRow row) onRowMenu;

  static const double _rowHeight = 56;
  static const double _headerHeight = 84;
  static const double _deliverableColWidth = 260;
  static const double _phaseColWidth = 110;
  static const double _roleColWidth = 150;
  static const double _actionsColWidth = 60;

  @override
  Widget build(BuildContext context) {
    final gridWidth = _deliverableColWidth +
        _phaseColWidth +
        columns.length * _roleColWidth +
        _actionsColWidth;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final needsHorizontalScroll = gridWidth > viewportWidth;

        // Vertical scroll wraps everything.
        return SingleChildScrollView(
          primary: false,
          child: needsHorizontalScroll
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: gridWidth,
                    child: _buildGrid(),
                  ),
                )
              : SizedBox(
                  width: gridWidth,
                  child: _buildGrid(),
                ),
        );
      },
    );
  }

  Widget _buildGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderRow(),
        ...rows.map((row) => _buildDataRow(row)),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return SizedBox(
      height: _headerHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerCell('Deliverable', _deliverableColWidth,
              align: Alignment.centerLeft),
          _headerCell('Phase', _phaseColWidth),
          ...columns.map((role) => _roleHeaderCell(role)),
          _headerCell('', _actionsColWidth),
        ],
      ),
    );
  }

  Widget _headerCell(String label, double width, {Alignment? align}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          right: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
      ),
      alignment: align ?? Alignment.center,
      child: Text(
        label.toUpperCase(),
        textAlign: align == Alignment.centerLeft ? TextAlign.left : TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _roleHeaderCell(RoleDefinition role) {
    final person =
        RaciAssignmentService.personForRole(role.title, data.staffingRequirements);
    return Container(
      width: _roleColWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          right: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            role.title.isEmpty ? 'Untitled role' : role.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          if (person.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                person,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFC812),
                ),
              ),
            )
          else
            const Text(
              '— vacant —',
              style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: Color(0xFF9CA3AF),
              ),
            ),
          if (role.headcount > 1) ...[
            const SizedBox(height: 2),
            Text(
              'HC: ${role.headcount}',
              style: const TextStyle(
                fontSize: 9.5,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataRow(RaciDeliverableRow row) {
    return SizedBox(
      height: _rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Deliverable label cell (frozen visually — first column).
          InkWell(
            onTap: () => onRowMenu(row),
            child: Container(
              width: _deliverableColWidth,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
                  right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label.isEmpty ? row.checkpoint : row.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                        height: 1.25,
                      ),
                    ),
                  ),
                  const Icon(Icons.more_vert,
                      size: 14, color: Color(0xFF9CA3AF)),
                ],
              ),
            ),
          ),
          // Phase cell.
          Container(
            width: _phaseColWidth,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
                right: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
              ),
            ),
            alignment: Alignment.center,
            child: _PhaseChip(phase: row.phase),
          ),
          // Role assignment cells.
          ...columns.map((role) {
            final key = RaciAssignmentService.roleKey(role.title);
            final value = (row.assignments[key] ?? '').toUpperCase();
            return _AssignmentCell(
              value: value,
              width: _roleColWidth,
              onTap: () => onCellTap(row, key),
            );
          }),
          // Actions column (currently empty — could host row delete/etc).
          Container(
            width: _actionsColWidth,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.phase});
  final String phase;

  @override
  Widget build(BuildContext context) {
    final palette = _phasePalette(phase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        phase.replaceAll(' Phase', ''),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: palette.fg,
        ),
      ),
    );
  }

  ({Color bg, Color fg}) _phasePalette(String p) {
    switch (p.toLowerCase()) {
      case 'planning phase':
        return (bg: const Color(0xFFFEF3C7), fg: const Color(0xFFFFC812));
      case 'design phase':
        return (bg: const Color(0xFFFFF8E1), fg: const Color(0xFFB8860B));
      case 'execution phase':
        return (bg: const Color(0xFFFFEDD5), fg: const Color(0xFFC2410C));
      case 'launch phase':
        return (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF15803D));
      default:
        return (bg: const Color(0xFFF3F4F6), fg: const Color(0xFF6B7280));
    }
  }
}

class _AssignmentCell extends StatelessWidget {
  const _AssignmentCell({
    required this.value,
    required this.width,
    required this.onTap,
  });

  final String value;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.isEmpty;
    final c = isEmpty
        ? (bg: 0xFFFAFAFA, fg: 0xFF9CA3AF)
        : RaciDesignation.color(value);
    final bg = Color(c.bg);
    final fg = Color(c.fg);

    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
            right: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 38,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: isEmpty
                ? Border.all(
                    color: const Color(0xFFE5E7EB),
                    style: BorderStyle.solid,
                  )
                : null,
          ),
          child: Text(
            isEmpty ? '—' : value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
