import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/raci_assignment_service.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';

/// Builds the AI-seeded RACI Deliverable Matrix.
///
/// Strategy:
///   1. Rows = every sidebar item from Planning Phase → Launch Phase
///      (the "first level" deliverables the user sees on the left of the
///      matrix). Initiation + Front End Planning are intentionally
///      excluded because they happen *before* the matrix is baselined.
///
///   2. Columns = the project's identified roles. We pull these from the
///      **Staffing Plan** first (because the Staffing Plan carries the
///      named person), then add any roles from the Roles &
///      Responsibilities screen that aren't already on the Staffing Plan.
///      This is the "ONLY the applicable roles identified to have access
///      to the program per the Staffing Plan" rule.
///
///   3. Cell value = R/A/C/RV/I/V, picked by a rule-based AI first pass
///      that considers:
///        - the deliverable's phase (Planning/Design/Execution/Launch)
///        - the deliverable's checkpoint family (schedule, cost, risk,
///          contracts, design, agile, etc.)
///        - the role's discipline (Management/Engineering/QA/Operations...)
///        - the role's framework (Agile/Waterfall/Both)
///
///   4. When the matrix is regenerated, any existing manual assignments
///      for the SAME role+deliverable pair are preserved. Only empty cells
///      are filled by the AI pass — this keeps the AI "first stab"
///      semantic while not destroying user edits.
class RaciMatrixSeeder {
  RaciMatrixSeeder._();

  /// Build a fresh AI-seeded matrix for [data] using current Staffing Plan
  /// + Roles & Responsibilities. Returns new rows (caller persists).
  static List<RaciDeliverableRow> seed(ProjectDataModel data) {
    final sidebarItems =
        RaciAssignmentService.instance.matrixScopeSidebarItems();
    final roles = _applicableRoles(data);
    final priorByCheckpoint = <String, RaciDeliverableRow>{};
    for (final row in data.raciDeliverableRows) {
      if (row.checkpoint.isNotEmpty) {
        priorByCheckpoint[row.checkpoint] = row;
      }
    }

    final rows = <RaciDeliverableRow>[];
    for (final item in sidebarItems) {
      final phase = SidebarNavigationService.phaseForCheckpoint(
              item.checkpoint) ??
          'Planning Phase';
      final prior = priorByCheckpoint[item.checkpoint];
      final assignments = <String, String>{};
      for (final role in roles) {
        final key = RaciAssignmentService.roleKey(role.title);
        final existing = prior?.assignments[key];
        if (existing != null && existing.trim().isNotEmpty) {
          assignments[key] = existing.toUpperCase();
        } else {
          final code = _suggest(
              checkpoint: item.checkpoint,
              label: item.label,
              phase: phase,
              role: role);
          if (code != null) assignments[key] = code;
        }
      }
      rows.add(RaciDeliverableRow(
        id: prior?.id,
        checkpoint: item.checkpoint,
        label: item.label,
        phase: phase,
        assignments: assignments,
      ));
    }
    return rows;
  }

  /// Merge newly-added roles into the existing matrix — gives every new
  /// role an AI-suggested designation for every existing deliverable row
  /// without touching existing assignments.
  static List<RaciDeliverableRow> syncRoles(ProjectDataModel data) {
    final sidebarItems =
        RaciAssignmentService.instance.matrixScopeSidebarItems();
    final roles = _applicableRoles(data);
    final existingByCheckpoint = <String, RaciDeliverableRow>{};
    for (final row in data.raciDeliverableRows) {
      existingByCheckpoint[row.checkpoint] = row;
    }

    // Ensure every sidebar item has a row (add missing rows).
    final rows = <RaciDeliverableRow>[];
    for (final item in sidebarItems) {
      final phase = SidebarNavigationService.phaseForCheckpoint(
              item.checkpoint) ??
          'Planning Phase';
      var row = existingByCheckpoint[item.checkpoint];
      row ??= RaciDeliverableRow(
          checkpoint: item.checkpoint,
          label: item.label,
          phase: phase,
        );
      // Add assignments for new roles.
      for (final role in roles) {
        final key = RaciAssignmentService.roleKey(role.title);
        if ((row.assignments[key] ?? '').isEmpty) {
          final code = _suggest(
              checkpoint: item.checkpoint,
              label: item.label,
              phase: phase,
              role: role);
          if (code != null) row.assignments[key] = code;
        }
      }
      // Drop assignments for roles that no longer exist on the staffing
      // plan / roles list — keeps the matrix tidy when a role is removed.
      final validKeys = roles
          .map((r) => RaciAssignmentService.roleKey(r.title))
          .toSet();
      row.assignments.removeWhere((k, v) => !validKeys.contains(k));
      rows.add(row);
    }
    return rows;
  }

  /// Return the deduplicated list of roles that should appear as columns.
  /// Staffing Plan positions take priority; project-level roles fill any
  /// gaps not covered by the staffing plan.
  static List<RoleDefinition> _applicableRoles(ProjectDataModel data) {
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
    // Fallback: if neither staffing plan nor roles list is populated, use
    // a minimal core set so the matrix isn't empty.
    if (out.isEmpty) {
      const fallback = [
        'Project Sponsor',
        'Project Manager',
        'Project Engineer',
        'Quality Lead',
        'Procurement Manager',
      ];
      for (final title in fallback) {
        out.add(RoleDefinition(title: title, workstream: 'Management'));
      }
    }
    return out;
  }

  /// Pick a designation (or null = "no assignment") for [role] on the
  /// given deliverable. Uses keyword heuristics on the checkpoint and
  /// label, plus the role's discipline and title.
  static String? _suggest({
    required String checkpoint,
    required String label,
    required String phase,
    required RoleDefinition role,
  }) {
    final cp = checkpoint.toLowerCase();
    final lbl = label.toLowerCase();
    final roleTitle = role.title.toLowerCase();
    final discipline = role.workstream.toLowerCase();

    // ── Sponsor / Owner ────────────────────────────────────────────
    if (roleTitle.contains('sponsor') || roleTitle.contains('owner')) {
      if (_isFinancial(cp, lbl)) return RaciDesignation.approver;
      if (_isClosure(cp, lbl)) return RaciDesignation.approver;
      if (_isGovernance(cp, lbl)) return RaciDesignation.approver;
      return RaciDesignation.informed;
    }

    // ── Project Manager ───────────────────────────────────────────
    if (roleTitle == 'project manager' ||
        roleTitle.startsWith('project manager')) {
      if (_isGovernance(cp, lbl)) return RaciDesignation.responsible;
      if (_isSchedule(cp, lbl)) return RaciDesignation.responsible;
      if (_isRisk(cp, lbl)) return RaciDesignation.responsible;
      if (_isChange(cp, lbl)) return RaciDesignation.responsible;
      if (_isStatus(cp, lbl)) return RaciDesignation.responsible;
      if (_isClosure(cp, lbl)) return RaciDesignation.responsible;
      if (_isFinancial(cp, lbl)) return RaciDesignation.consulted;
      return RaciDesignation.responsible;
    }

    // ── PMO ───────────────────────────────────────────────────────
    if (roleTitle.contains('pmo')) {
      if (_isStatus(cp, lbl)) return RaciDesignation.responsible;
      if (_isGovernance(cp, lbl)) return RaciDesignation.consulted;
      if (_isRisk(cp, lbl)) return RaciDesignation.consulted;
      if (_isChange(cp, lbl)) return RaciDesignation.consulted;
      return RaciDesignation.informed;
    }

    // ── Program Manager ───────────────────────────────────────────
    if (roleTitle.contains('program manager')) {
      if (_isGovernance(cp, lbl)) return RaciDesignation.approver;
      return RaciDesignation.consulted;
    }

    // ── Project Controls Manager ──────────────────────────────────
    if (roleTitle.contains('controls')) {
      if (_isSchedule(cp, lbl)) return RaciDesignation.responsible;
      if (_isFinancial(cp, lbl)) return RaciDesignation.responsible;
      if (_isStatus(cp, lbl)) return RaciDesignation.responsible;
      return RaciDesignation.consulted;
    }

    // ── Cost roles ────────────────────────────────────────────────
    if (roleTitle.contains('cost') || roleTitle.contains('finance') ||
        roleTitle.contains('account')) {
      if (_isFinancial(cp, lbl)) return RaciDesignation.responsible;
      if (_isClosure(cp, lbl) && cp.contains('financial')) {
        return RaciDesignation.responsible;
      }
      return RaciDesignation.consulted;
    }

    // ── Schedule roles ────────────────────────────────────────────
    if (roleTitle.contains('schedule') || roleTitle.contains('scheduler')) {
      if (_isSchedule(cp, lbl)) return RaciDesignation.responsible;
      return RaciDesignation.consulted;
    }

    // ── Contracts / Procurement ───────────────────────────────────
    if (roleTitle.contains('contract') || roleTitle.contains('procurement')) {
      if (_isContracts(cp, lbl)) return RaciDesignation.responsible;
      if (_isClosure(cp, lbl) &&
          (cp.contains('contract') || cp.contains('vendor'))) {
        return RaciDesignation.responsible;
      }
      return RaciDesignation.consulted;
    }

    // ── Quality roles ─────────────────────────────────────────────
    if (roleTitle.contains('quality') || roleTitle.contains('qa') ||
        roleTitle.contains('tester') || roleTitle.contains('test lead')) {
      if (_isDesign(cp, lbl)) return RaciDesignation.reviewer;
      if (_isDetailedDesign(cp, lbl)) return RaciDesignation.responsible;
      if (_isClosure(cp, lbl) && cp.contains('scope')) {
        return RaciDesignation.reviewer;
      }
      return RaciDesignation.reviewer;
    }

    // ── Engineering / Design roles ────────────────────────────────
    if (roleTitle.contains('engineer') || roleTitle.contains('design') ||
        roleTitle.contains('architect') || roleTitle.contains('technical')) {
      if (_isDesign(cp, lbl) || _isDetailedDesign(cp, lbl)) {
        return RaciDesignation.responsible;
      }
      if (_isTechDev(cp, lbl)) return RaciDesignation.responsible;
      return RaciDesignation.consulted;
    }

    // ── Construction / Startup ────────────────────────────────────
    if (roleTitle.contains('construction') ||
        roleTitle.contains('startup') || roleTitle.contains('start-up')) {
      if (phase == 'Execution Phase') return RaciDesignation.responsible;
      if (phase == 'Launch Phase') return RaciDesignation.responsible;
      return RaciDesignation.consulted;
    }

    // ── Dev / DevOps ──────────────────────────────────────────────
    if (roleTitle.contains('developer') || roleTitle.contains('devops') ||
        roleTitle.contains('automation')) {
      if (_isTechDev(cp, lbl)) return RaciDesignation.responsible;
      if (_isAgile(cp, lbl)) return RaciDesignation.responsible;
      if (cp.contains('devops')) return RaciDesignation.responsible;
      return RaciDesignation.consulted;
    }

    // ── Agile / Scrum roles ───────────────────────────────────────
    if (roleTitle.contains('scrum') || roleTitle.contains('product owner') ||
        roleTitle.contains('release')) {
      if (_isAgile(cp, lbl)) return RaciDesignation.responsible;
      return RaciDesignation.consulted;
    }

    // ── Interface Manager ─────────────────────────────────────────
    if (roleTitle.contains('interface')) {
      if (cp.contains('interface')) return RaciDesignation.responsible;
      return RaciDesignation.consulted;
    }

    // ── Change Manager ────────────────────────────────────────────
    if (roleTitle.contains('change')) {
      if (_isChange(cp, lbl)) return RaciDesignation.responsible;
      return RaciDesignation.consulted;
    }

    // ── Operations / Hypercare ────────────────────────────────────
    if (roleTitle.contains('operations') || roleTitle.contains('hypercare') ||
        roleTitle.contains('devops')) {
      if (phase == 'Launch Phase') return RaciDesignation.responsible;
      if (cp.contains('ops') || cp.contains('maintenance')) {
        return RaciDesignation.responsible;
      }
      return RaciDesignation.informed;
    }

    // ── Discipline-based fallback ─────────────────────────────────
    if (discipline.contains('management')) {
      if (_isGovernance(cp, lbl)) return RaciDesignation.consulted;
      return RaciDesignation.informed;
    }
    if (discipline.contains('engineering')) {
      if (_isDesign(cp, lbl)) return RaciDesignation.consulted;
      return RaciDesignation.informed;
    }

    // ── Default: Viewer (least-privilege) ─────────────────────────
    return RaciDesignation.viewer;
  }

  // ─── Keyword families ────────────────────────────────────────────
  static bool _isGovernance(String cp, String lbl) =>
      cp.contains('framework') ||
      cp.contains('charter') ||
      cp.contains('baseline') ||
      cp.contains('project_plan') ||
      cp.contains('lessons_learned') ||
      lbl.contains('overview') ||
      lbl.contains('baseline');

  static bool _isSchedule(String cp, String lbl) =>
      cp.contains('schedule') || lbl.contains('schedule');

  static bool _isFinancial(String cp, String lbl) =>
      cp.contains('cost') ||
      cp.contains('financial') ||
      cp.contains('budget') ||
      lbl.contains('cost') ||
      lbl.contains('financial') ||
      lbl.contains('budget');

  static bool _isRisk(String cp, String lbl) =>
      cp.contains('risk') || lbl.contains('risk');

  static bool _isChange(String cp, String lbl) =>
      cp.contains('change') || lbl.contains('change');

  static bool _isStatus(String cp, String lbl) =>
      cp.contains('status') ||
      cp.contains('progress') ||
      cp.contains('deliverable_status') ||
      cp.contains('recurring') ||
      lbl.contains('status') ||
      lbl.contains('progress');

  static bool _isContracts(String cp, String lbl) =>
      cp.contains('contract') ||
      cp.contains('vendor') ||
      cp.contains('procurement') ||
      lbl.contains('contract') ||
      lbl.contains('vendor') ||
      lbl.contains('procurement');

  static bool _isDesign(String cp, String lbl) =>
      cp.startsWith('design_') ||
      cp.contains('ui_ux') ||
      cp.contains('backend_design') ||
      cp.contains('specialized_design') ||
      lbl.startsWith('Design') ||
      lbl.contains('UI/UX');

  static bool _isDetailedDesign(String cp, String lbl) =>
      cp == 'detailed_design' || lbl.contains('Detailed Design');

  static bool _isTechDev(String cp, String lbl) =>
      cp.contains('technical_development') ||
      cp.contains('development_set') ||
      cp.contains('tools_integration') ||
      cp.contains('long_lead') ||
      lbl.contains('Technical Development') ||
      lbl.contains('Tools Integration');

  static bool _isAgile(String cp, String lbl) =>
      cp.startsWith('agile_') ||
      lbl.startsWith('Agile') ||
      lbl.contains('Scrum') ||
      lbl.contains('Kanban') ||
      lbl.contains('Epic') ||
      lbl.contains('Sprint') ||
      lbl.contains('Release Plan');

  static bool _isClosure(String cp, String lbl) =>
      cp.contains('close') ||
      cp.contains('closeout') ||
      cp.contains('demobil') ||
      lbl.contains('Closeout') ||
      lbl.contains('Closure') ||
      lbl.contains('Demobiliz');
}
