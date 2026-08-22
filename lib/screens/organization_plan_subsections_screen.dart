import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/screens/team_training_building_screen.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/services/raci_assignment_service.dart';
import 'package:ndu_project/services/raci_matrix_seeder.dart';
import 'package:ndu_project/services/subscription_service.dart';
import 'package:ndu_project/services/subscription_pricing_service.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/staffing_reminder_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/user_model.dart';
import 'package:ndu_project/widgets/premium_edit_dialog.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';
import 'package:ndu_project/widgets/raci_deliverable_matrix.dart';

import 'package:ndu_project/widgets/delete_success_snackbar.dart';
Future<void> _exportPlanningSubsectionPdf(BuildContext context) async {
  final projectData = ProjectDataHelper.getData(context);
  await PdfExportHelper.exportScreenPdf(
    context: context,
    screenTitle: 'Organization Plan',
    sections: [
      PdfSection.keyValue('Project Info', [
        {
          'Project Name':
              projectData.projectName.isEmpty ? 'N/A' : projectData.projectName
        },
        {
          'Solution Title': projectData.solutionTitle.isEmpty
              ? 'N/A'
              : projectData.solutionTitle
        },
      ]),
      PdfSection.text(
          'Notes',
          projectData.planningNotes[
                  'planning_organization_plan_subsections_notes'] ??
              'No data recorded.'),
    ],
  );
}

class OrganizationRolesResponsibilitiesScreen extends StatefulWidget {
  const OrganizationRolesResponsibilitiesScreen({super.key});

  @override
  State<OrganizationRolesResponsibilitiesScreen> createState() =>
      _OrganizationRolesResponsibilitiesScreenState();
}

/// Standalone screen for the "Staffing Plan" sidebar entry.
///
/// Renders the dedicated staffing plan table (not the Roles & Responsibilities
/// card/table view) with all personnel allocation columns: Position, Name,
/// Location, Employment (FT/PT), Category (Employee/Contractor), Start Date
/// (Mobilization), Release Date, NDU Project Access, Status, and Actions.
/// Also surfaces reminder banners (overdue / upcoming mobilizations and
/// releases) and an AI suggestion engine that picks which positions should
/// get NDU Project Delivery platform access based on the active subscription
/// tier, the currently selected roles, and the project scope.
class OrganizationStaffingPlanScreen extends StatefulWidget {
  const OrganizationStaffingPlanScreen({super.key});

  @override
  State<OrganizationStaffingPlanScreen> createState() =>
      _OrganizationStaffingPlanScreenState();
}

/// ─────────────────────────────────────────────────────────────────────────
/// Staffing Plan state — owns the staffing plan table, popup editor, AI
/// suggestion engine for NDU Project Access, reminder banners, and the
/// tabbed view (Staffing Plan table, Staffing Timeline Gantt, and the
/// restricted Estimated Cost tab).
/// ─────────────────────────────────────────────────────────────────────────
class _OrganizationStaffingPlanScreenState
    extends State<OrganizationStaffingPlanScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Position title options reused from the Roles & Responsibilities bank
  // (kept here locally so the dialog doesn't depend on the parent class).
  static const List<String> _positionOptions = [
    'Project Manager',
    'Project Sponsor (Owner)',
    'Program Manager',
    'Product Owner',
    'Scrum Master',
    'Business Analyst',
    'PMO Lead',
    'PMO Manager',
    'Delivery Manager',
    'Operations Manager',
    'Risk Manager',
    'Quality Assurance Lead',
    'Quality Lead',
    'Change Manager',
    'Stakeholder Manager',
    'Planning Engineer',
    'Project Coordinator',
    'Portfolio Manager',
    'SSHER Lead',
    'Contracts Manager',
    'Contracts Lead',
    'Procurement Manager',
    'Tech Lead',
    'Lead Developer',
    'Lead Designer',
    'Engineering Manager',
    'Technical Manager',
    'Construction Manager',
    'Startup Manager',
    'Release Manager',
    'Cost Lead',
    'Cost Estimator',
    'Schedule Lead',
    'Scheduler',
    'Test Lead',
    'Technical Architect',
    'Solutions Architect',
    'Design Engineer',
    'Data Specialist',
    'Developer - Backend',
    'Developer - Frontend',
    'Business Manager',
    'Project Engineer',
    'Engineer',
  ];
  static const String _customPositionOption = 'Custom';

  static const List<String> _employmentOptions = ['Full Time', 'Part Time'];
  static const List<String> _categoryOptions = ['Employee', 'Contractor'];
  static const List<String> _statusOptions = [
    'Not Started',
    'Open',
    'Mobilized',
    'Active',
    'On Hold',
    'Released',
    'Hired',
  ];

  Future<void> _saveStaffing(
      BuildContext context, List<StaffingRequirement> updated) async {
    await ProjectDataHelper.saveAndNavigate(
      context: context,
      checkpoint: 'organization_staffing_plan',
      saveInBackground: true,
      nextScreenBuilder: () => const OrganizationStaffingPlanScreen(),
      dataUpdater: (d) => d.copyWith(staffingRequirements: updated),
    );
    if (mounted) setState(() {});
  }

  // ── Add / Edit / Delete / Toggle ──────────────────────────────────────────

  Future<void> _addStaffing(BuildContext context) async {
    final projectData = ProjectDataHelper.getData(context);
    final result = await showDialog<StaffingRequirement>(
      context: context,
      builder: (dialogContext) => _StaffingRequirementDialog(
        title: 'Add Staffing Position',
        requirement: StaffingRequirement(
          // Auto-fill location from project location if available.
          location: projectData.location,
          status: 'Not Started',
        ),
        positionOptions: _positionOptions,
        customPositionOption: _customPositionOption,
        employmentOptions: _employmentOptions,
        categoryOptions: _categoryOptions,
        statusOptions: _statusOptions,
        projectLocation: projectData.location,
      ),
    );
    if (result == null) return;
    final updated = [
      ...ProjectDataHelper.getData(context).staffingRequirements,
      result,
    ];
    await _saveStaffing(context, updated);
  }

  Future<void> _editStaffing(
      BuildContext context, int index, StaffingRequirement req) async {
    final projectData = ProjectDataHelper.getData(context);
    final result = await showDialog<StaffingRequirement>(
      context: context,
      builder: (dialogContext) => _StaffingRequirementDialog(
        title: 'Edit Staffing Position',
        requirement: req,
        positionOptions: _positionOptions,
        customPositionOption: _customPositionOption,
        employmentOptions: _employmentOptions,
        categoryOptions: _categoryOptions,
        statusOptions: _statusOptions,
        projectLocation: projectData.location,
      ),
    );
    if (result == null) return;
    final updated =
        List<StaffingRequirement>.from(projectData.staffingRequirements);
    if (index >= 0 && index < updated.length) {
      updated[index] = result;
    }
    await _saveStaffing(context, updated);
  }

  Future<void> _deleteStaffing(BuildContext context, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Position?'),
        content: const Text(
            'This will remove this row from the staffing plan. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = List<StaffingRequirement>.from(
        ProjectDataHelper.getData(context).staffingRequirements);
    if (index >= 0 && index < updated.length) {
      updated.removeAt(index);
    }
    await _saveStaffing(context, updated);
      showDeleteSuccessSnackBar(context, itemLabel: 'Staffing');
  }

  Future<void> _toggleNduAccess(BuildContext context, int index, bool value) async {
    final projectData = ProjectDataHelper.getData(context);
    final updated =
        List<StaffingRequirement>.from(projectData.staffingRequirements);
    if (index < 0 || index >= updated.length) return;
    updated[index] = updated[index].copyWith(nduProjectAccess: value);
    await _saveStaffing(context, updated);
  }

  // ── AI Suggestion Engine ─────────────────────────────────────────────────
  //
  // Picks which positions should get NDU Project Delivery platform access
  // based on the active subscription tier, the roles currently in the
  // staffing plan, and the project scope. The recommendation is presented
  // as a dialog with checkboxes the user can review + accept.

  Future<void> _showNduSuggestionDialog(BuildContext context) async {
    final projectData = ProjectDataHelper.getData(context);
    final staffing = projectData.staffingRequirements;

    // Resolve the active subscription tier (fallback to Project tier defaults
    // if the user is offline or has no record yet).
    SubscriptionTier? subTier;
    try {
      final sub = await SubscriptionService.getCurrentSubscription();
      subTier = sub?.tier;
    } catch (_) {
      subTier = null;
    }
    final pricingTierId = subTier == SubscriptionTier.portfolio
        ? PricingTierId.portfolio
        : subTier == SubscriptionTier.program
            ? PricingTierId.program
            : subTier == SubscriptionTier.project
                ? PricingTierId.project
                : PricingTierId.basicProject;
    final tierConfig = TierPricingConfig.defaults.firstWhere(
      (t) => t.id == pricingTierId,
      orElse: () => TierPricingConfig.defaultProject,
    );

    // Pre-flight: if there are no positions yet, suggest the canonical
    // starter set for the project tier.
    final bool emptyStaffing = staffing.isEmpty;
    final List<StaffingRequirement> suggestedAdditions = emptyStaffing
        ? _canonicalStarterSetForTier(pricingTierId)
        : const [];

    // Build suggestions for NDU access on existing rows.
    // Priority: leadership / operational roles first, then by tier capacity.
    final priorityTitles = [
      'Project Manager',
      'Project Sponsor (Owner)',
      'Tech Lead',
      'Lead Developer',
      'Developer - Backend',
      'Developer - Frontend',
      'Quality Assurance Lead',
      'Quality Lead',
      'SSHER Lead',
      'Contracts Lead',
      'Contracts Manager',
      'Procurement Manager',
      'Engineering Manager',
      'Technical Manager',
      'Construction Manager',
      'Planning Engineer',
      'Schedule Lead',
      'Cost Lead',
      'Scrum Master',
      'Product Owner',
    ];
    final int tierCapacity = tierConfig.includedUsers;
    final int alreadyYes =
        staffing.where((s) => s.nduProjectAccess).length;
    final int slotsRemaining = tierCapacity - alreadyYes;

    final suggestedIndices = <int>{};
    if (slotsRemaining > 0) {
      for (final title in priorityTitles) {
        if (suggestedIndices.length >= slotsRemaining) break;
        for (var i = 0; i < staffing.length; i++) {
          if (suggestedIndices.contains(i)) continue;
          if (staffing[i].nduProjectAccess) continue;
          if (staffing[i].title.toLowerCase().contains(title.toLowerCase())) {
            suggestedIndices.add(i);
            break;
          }
        }
      }
    }

    // Show the suggestion dialog.
    if (!context.mounted) return;
    final accepted = await showDialog<_NduSuggestionResult>(
      context: context,
      builder: (dialogContext) => _NduSuggestionDialog(
        tierLabel: tierConfig.label,
        tierCapacity: tierCapacity,
        includedUsers: tierConfig.includedUsers,
        maxUsers: tierConfig.maxUsers,
        currentStaffing: staffing,
        suggestedIndices: suggestedIndices,
        suggestedAdditions: suggestedAdditions,
        projectScope: _projectScopeSummary(projectData),
      ),
    );
    if (accepted == null) return;

    // Apply: 1) add the new positions (if any), 2) flip NDU access on
    // the accepted indices.
    final updated = List<StaffingRequirement>.from(staffing);
    for (final addition in accepted.additions) {
      updated.add(addition.copyWith(nduProjectAccess: true));
    }
    for (final idx in accepted.acceptedIndices) {
      if (idx >= 0 && idx < updated.length) {
        updated[idx] = updated[idx].copyWith(nduProjectAccess: true);
      }
    }
    await _saveStaffing(context, updated);
  }

  /// Canonical starter set of staffing positions for a tier when the user
  /// has nothing on the staffing plan yet. Based on the user's example:
  /// Project Manager, SSHER Lead, Quality Person, Tech Lead, Developer,
  /// Contracts Lead — capped to the tier's `includedUsers` count and
  /// optionally extended to cover additional scope.
  List<StaffingRequirement> _canonicalStarterSetForTier(PricingTierId tier) {
    final int budget = tier == PricingTierId.basicProject
        ? 1
        : tier == PricingTierId.project
            ? 7
            : tier == PricingTierId.program
                ? 12
                : 24;
    // The first six are the user's explicit example for a Regular Project.
    // Higher tiers expand to add Coverage roles for broader scope.
    // Notes carry the role description for display in the dialog.
    final candidates = <StaffingRequirement>[
      StaffingRequirement(
          title: 'Project Manager',
          notes: 'Overall project leadership, planning, and coordination.'),
      StaffingRequirement(
          title: 'SSHER Lead',
          notes: 'Safety, Security, Health, Environmental, and Regulatory lead.'),
      StaffingRequirement(
          title: 'Quality Assurance Lead',
          notes: 'Quality planning, QA/QC processes, and compliance.'),
      StaffingRequirement(
          title: 'Tech Lead',
          notes: 'Technical leadership, architecture oversight.'),
      StaffingRequirement(
          title: 'Lead Developer',
          notes: 'Development team leadership and code quality.'),
      StaffingRequirement(
          title: 'Contracts Lead',
          notes: 'Contract administration, negotiation, compliance.'),
      StaffingRequirement(
          title: 'Procurement Manager',
          notes: 'Procurement strategy, vendor selection, supply chain.'),
      StaffingRequirement(
          title: 'Planning Engineer',
          notes: 'Project schedules, WBS, progress tracking.'),
      StaffingRequirement(
          title: 'Cost Lead',
          notes: 'Cost estimation leadership and budget control.'),
      StaffingRequirement(
          title: 'Schedule Lead',
          notes: 'Schedule planning, critical path analysis.'),
      StaffingRequirement(
          title: 'Construction Manager',
          notes: 'On-site construction execution and field coordination.'),
      StaffingRequirement(
          title: 'Stakeholder Manager',
          notes: 'Stakeholder engagement and communication.'),
      StaffingRequirement(
          title: 'Risk Manager',
          notes: 'Risk identification, assessment, mitigation.'),
      StaffingRequirement(
          title: 'Change Manager',
          notes: 'Change control process ownership.'),
      StaffingRequirement(
          title: 'Test Lead',
          notes: 'Testing strategy, test plan ownership, QA execution.'),
      StaffingRequirement(
          title: 'Business Analyst',
          notes: 'Requirements elicitation, analysis, documentation.'),
      StaffingRequirement(
          title: 'Technical Architect',
          notes: 'System architecture design and technology selection.'),
      StaffingRequirement(
          title: 'Data Specialist',
          notes: 'Data modeling, migration, analytics.'),
      StaffingRequirement(
          title: 'PMO Lead',
          notes: 'Project Management Office oversight, governance.'),
      StaffingRequirement(
          title: 'Operations Manager',
          notes: 'Day-to-day operations and resource allocation.'),
      StaffingRequirement(
          title: 'Engineering Manager',
          notes: 'Engineering team leadership.'),
      StaffingRequirement(
          title: 'Technical Manager',
          notes: 'Technical team management.'),
      StaffingRequirement(
          title: 'Release Manager',
          notes: 'Release planning, deployment coordination.'),
      StaffingRequirement(
          title: 'Design Engineer',
          notes: 'Engineering design and technical drawings.'),
    ];
    return candidates.take(budget).toList();
  }

  String _projectScopeSummary(ProjectDataModel data) {
    final bits = <String>[];
    if (data.projectName.trim().isNotEmpty) bits.add(data.projectName);
    if (data.solutionTitle.trim().isNotEmpty) bits.add(data.solutionTitle);
    if (data.location.trim().isNotEmpty) bits.add('Site: ${data.location}');
    if (data.projectRoles.isNotEmpty) {
      bits.add('${data.projectRoles.length} roles in Roles & Responsibilities');
    }
    if (data.raciDeliverableRows.isNotEmpty) {
      bits.add('${data.raciDeliverableRows.length} deliverables on the RACI matrix');
    }
    return bits.isEmpty ? 'No project scope defined yet.' : bits.join(' • ');
  }

  // ── AI Auto-Suggest Start/Stop Dates ────────────────────────────────────
  //
  // Reads the project's milestone schedule (key milestones) and overall
  // scope (planned start/end dates), then proposes a start (mobilization)
  // and release date for every staffing row that doesn't yet have one.
  // The user reviews the suggestions in a dialog and accepts selectively.

  Future<void> _showAiSuggestDatesDialog(BuildContext context) async {
    final projectData = ProjectDataHelper.getData(context);
    final staffing = projectData.staffingRequirements;

    if (staffing.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Add at least one staffing position before AI-suggesting dates.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    // Build the project schedule window from milestones (preferring
    // milestones with real due dates) and fall back to project start/end.
    final milestones = projectData.keyMilestones
        .where((m) => m.dueDate.trim().isNotEmpty)
        .toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a.dueDate) ?? DateTime(2100);
        final db = DateTime.tryParse(b.dueDate) ?? DateTime(2100);
        return da.compareTo(db);
      });

    DateTime? projectStart;
    DateTime? projectEnd;
    if (milestones.isNotEmpty) {
      projectStart = DateTime.tryParse(milestones.first.dueDate);
      projectEnd = DateTime.tryParse(milestones.last.dueDate);
    }

    // If we have no milestones to anchor on, suggest a window starting
    // today running for a default 6-month engagement.
    final today = DateTime.now();
    projectStart ??= today;
    projectEnd ??= today.add(const Duration(days: 180));

    final suggestions = <int, _DateSuggestion>{};
    for (var i = 0; i < staffing.length; i++) {
      final req = staffing[i];
      final title = req.title.toLowerCase();

      // Determine the role's natural start (slightly before its milestone)
      // and end (slightly after).
      DateTime? suggestedStart;
      DateTime? suggestedEnd;

      // Match role title to milestone discipline where possible.
      Milestone? matchedMilestone;
      for (final m in milestones) {
        final discipline = m.discipline.toLowerCase();
        final mName = m.name.toLowerCase();
        if (title.contains('project manager') ||
            title.contains('sponsor') ||
            title.contains('pmo')) {
          if (discipline.contains('management') ||
              mName.contains('kickoff') ||
              mName.contains('planning')) {
            matchedMilestone = m;
            break;
          }
        } else if (title.contains('tech') ||
            title.contains('developer') ||
            title.contains('engineer') ||
            title.contains('architect')) {
          if (discipline.contains('technical') ||
              discipline.contains('engineering') ||
              mName.contains('execution') ||
              mName.contains('design')) {
            matchedMilestone = m;
            break;
          }
        } else if (title.contains('quality') || title.contains('test')) {
          if (discipline.contains('quality') ||
              mName.contains('completion') ||
              mName.contains('launch')) {
            matchedMilestone = m;
            break;
          }
        } else if (title.contains('contract') ||
            title.contains('procurement')) {
          if (discipline.contains('contracts') ||
              discipline.contains('procurement') ||
              mName.contains('planning')) {
            matchedMilestone = m;
            break;
          }
        } else if (title.contains('ssher') || title.contains('safety')) {
          if (discipline.contains('safety') ||
              discipline.contains('ssher') ||
              mName.contains('kickoff')) {
            matchedMilestone = m;
            break;
          }
        }
      }

      // Mobilization generally starts 2 weeks before the matched milestone
      // (or 2 weeks before project start for early roles).
      if (matchedMilestone != null) {
        final milestoneDate = DateTime.tryParse(matchedMilestone.dueDate);
        if (milestoneDate != null) {
          suggestedStart = milestoneDate.subtract(const Duration(days: 14));
          suggestedEnd = milestoneDate.add(const Duration(days: 60));
        }
      }

      // Leadership roles (PM, Sponsor) span the entire project.
      if (title.contains('project manager') ||
          title.contains('sponsor') ||
          title.contains('pmo') ||
          title.contains('program manager')) {
        suggestedStart = projectStart;
        suggestedEnd = projectEnd;
      }

      // Late-stage roles (release, launch, transition) start late.
      if (title.contains('release') ||
          title.contains('transition') ||
          title.contains('startup') ||
          title.contains('launch')) {
        suggestedStart =
            projectEnd.subtract(const Duration(days: 90));
        suggestedEnd = projectEnd;
      }

      // Default fallback: span the whole project window.
      suggestedStart ??= projectStart;
      suggestedEnd ??= projectEnd;

      // Honor any existing user-set dates — only suggest if missing.
      if (req.startDate.trim().isNotEmpty &&
          req.endDate.trim().isNotEmpty) {
        continue;
      }

      suggestions[i] = _DateSuggestion(
        position: req.title.isEmpty ? 'Untitled Position' : req.title,
        personName: req.personName,
        matchedMilestone: matchedMilestone?.name,
        suggestedStart: suggestedStart,
        suggestedEnd: suggestedEnd,
        existingStart: req.startDate,
        existingEnd: req.endDate,
      );
    }

    if (suggestions.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'All staffing positions already have start and release dates.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final accepted = await showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) => _AiSuggestDatesDialog(
        projectScope: _projectScopeSummary(projectData),
        milestoneCount: milestones.length,
        projectStart: projectStart!,
        projectEnd: projectEnd!,
        suggestions: suggestions,
      ),
    );

    if (accepted == null || accepted.isEmpty) return;

    final updated = List<StaffingRequirement>.from(staffing);
    for (final idx in accepted) {
      final s = suggestions[idx]!;
      final fmt = DateFormat('yyyy-MM-dd');
      updated[idx] = updated[idx].copyWith(
        startDate: updated[idx].startDate.trim().isEmpty
            ? fmt.format(s.suggestedStart)
            : updated[idx].startDate,
        endDate: updated[idx].endDate.trim().isEmpty
            ? fmt.format(s.suggestedEnd)
            : updated[idx].endDate,
      );
    }
    await _saveStaffing(context, updated);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final horizontalPadding = isMobile ? 20.0 : 32.0;
    final projectData = ProjectDataHelper.getData(context);
    final staffing = projectData.staffingRequirements;

    final totalPersonnel = staffing.fold<int>(
        0, (sum, s) => sum + (s.headcount > 0 ? s.headcount : 1));
    final nduAccessCount =
        staffing.where((s) => s.nduProjectAccess).length;
    final reminders = StaffingReminderHelper.generateReminders(staffing);

    final metrics = <_MetricData>[
      _MetricData('Total Positions', staffing.length.toString(),
          const Color(0xFFFFC812)),
      _MetricData(
          'Total Personnel', totalPersonnel.toString(), const Color(0xFFB8860B)),
      _MetricData('NDU Access', nduAccessCount.toString(),
          const Color(0xFF10B981)),
      _MetricData('Active Reminders', reminders.length.toString(),
          const Color(0xFFEF4444)),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                activeItemLabel: 'Organization Plan - Staffing Plan',
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  const MobileSidebarHamburger(
                    sidebar: InitiationLikeSidebar(
                      activeItemLabel: 'Organization Plan - Staffing Plan',
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlanningPhaseHeader(
                          title: 'Staffing Plan',
                          onExportPdf: () =>
                              _exportPlanningSubsectionPdf(context),
                        ),
                        const SizedBox(height: 16),
                        _TopHeader(
                          title: 'Staffing Plan',
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                              context, 'organization_staffing_plan'),
                          onNext: () => PlanningPhaseNavigation.goToNext(
                              context, 'organization_staffing_plan'),
                          onAdd: () => _addStaffing(context),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Reflect the planned allocation of project personnel '
                          'by role and time to support resource planning, workload '
                          'management, and successful project delivery.',
                          style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                              height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        const PlanningAiNotesCard(
                          title: 'Notes',
                          sectionLabel: 'Staffing Plan',
                          noteKey: 'planning_organization_staffing_plan',
                          checkpoint: 'organization_staffing_plan',
                          description:
                              'Capture staffing assumptions, mobilization risks, '
                              'and role coverage decisions.',
                        ),
                        const SizedBox(height: 24),
                        _MetricsRow(metrics: metrics),
                        const SizedBox(height: 20),
                        if (reminders.isNotEmpty)
                          _StaffingRemindersBanner(reminders: reminders),
                        if (reminders.isNotEmpty)
                          const SizedBox(height: 20),
                        // AI suggestion banner
                        _NduSuggestionBanner(
                          tierLabel: _resolvedTierLabel(),
                          onSuggest: () =>
                              _showNduSuggestionDialog(context),
                          onAddPosition: () => _addStaffing(context),
                        ),
                        const SizedBox(height: 20),
                        // ── Tabbed Staffing Plan view ──
                        //   Tab 1: Staffing Plan table (existing) + AI Suggest Dates
                        //   Tab 2: Staffing Timeline (Gantt chart view)
                        //   Tab 3: Estimated Cost (restricted — same lock rules as
                        //          the Personnel Rates tab in the R&R section)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFE5E7EB)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Padding(
                                padding: EdgeInsets.fromLTRB(
                                    16, 12, 12, 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.table_rows_outlined,
                                        size: 18,
                                        color: Color(0xFF6B7280)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Staffing Plan',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Tab bar
                              Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  indicator: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x14000000),
                                        blurRadius: 4,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  indicatorSize:
                                      TabBarIndicatorSize.tab,
                                  dividerColor: Colors.transparent,
                                  labelColor: const Color(0xFF111827),
                                  unselectedLabelColor:
                                      const Color(0xFF6B7280),
                                  labelStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                  unselectedLabelStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  padding: const EdgeInsets.all(4),
                                  tabs: const [
                                    Tab(
                                      icon: Icon(Icons.table_chart_outlined,
                                          size: 16),
                                      text: 'Staffing Plan',
                                    ),
                                    Tab(
                                      icon: Icon(Icons.timeline_outlined,
                                          size: 16),
                                      text: 'Staffing Timeline',
                                    ),
                                    Tab(
                                      icon: Icon(Icons.lock_outline,
                                          size: 16),
                                      text: 'Estimated Cost',
                                    ),
                                  ],
                                ),
                              ),
                              // Tab content
                              SizedBox(
                                height: 600,
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    // ── Tab 1: Staffing Plan table ──
                                    _StaffingPlanTabContent(
                                      requirements: staffing,
                                      onEdit: (i, req) =>
                                          _editStaffing(context, i, req),
                                      onDelete: (i) =>
                                          _deleteStaffing(context, i),
                                      onToggleNduAccess: (i, v) =>
                                          _toggleNduAccess(context, i, v),
                                      onAddPosition: () =>
                                          _addStaffing(context),
                                      onAiSuggestDates: () =>
                                          _showAiSuggestDatesDialog(context),
                                    ),
                                    // ── Tab 2: Staffing Timeline (Gantt) ──
                                    _StaffingTimelineTab(
                                      requirements: staffing,
                                      onEdit: (i, req) =>
                                          _editStaffing(context, i, req),
                                    ),
                                    // ── Tab 3: Estimated Cost (restricted) ──
                                    _EstimatedCostTab(
                                      requirements: staffing,
                                      projectData: projectData,
                                      onEdit: (i, req) =>
                                          _editStaffing(context, i, req),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        LaunchPhaseNavigation(
                          backLabel: PlanningPhaseNavigation.backLabel(
                              'organization_staffing_plan'),
                          nextLabel: PlanningPhaseNavigation.nextLabel(
                              'organization_staffing_plan'),
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                              context, 'organization_staffing_plan'),
                          onNext: () => PlanningPhaseNavigation.goToNext(
                              context, 'organization_staffing_plan'),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  const Positioned(
                    right: 24,
                    bottom: 24,
                    child: KazAiChatBubble(positioned: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolvedTierLabel() {
    // The tier is per-user (subscription), not per-project. We surface a
    // best-effort label for the banner; the dialog itself fetches the
    // real subscription at click time.
    return 'your active subscription tier';
  }
}

/// Result returned by the NDU suggestion dialog.
class _NduSuggestionResult {
  final Set<int> acceptedIndices;
  final List<StaffingRequirement> additions;
  const _NduSuggestionResult({
    required this.acceptedIndices,
    required this.additions,
  });
}

/// Banner above the staffing plan table that invites the user to click
/// "AI Suggest NDU Access" — opens the suggestion dialog.
class _NduSuggestionBanner extends StatelessWidget {
  const _NduSuggestionBanner({
    required this.tierLabel,
    required this.onSuggest,
    required this.onAddPosition,
  });

  final String tierLabel;
  final VoidCallback onSuggest;
  final VoidCallback onAddPosition;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFFFFC812), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Suggest NDU Project Access',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB8860B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We\'ll suggest which positions should have access to the '
                  'NDU Project Delivery operating system platform based on '
                  '$tierLabel, the roles in your plan, and your project scope. '
                  'You can review and adjust before applying.',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF4B5563), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onAddPosition,
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: const Text('Add Position'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFC812),
                  side: const BorderSide(color: Color(0xFFFDE68A)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: onSuggest,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('AI Suggest NDU Access'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC812),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Banner that surfaces active staffing reminders (overdue mobilizations,
/// upcoming releases, unfilled positions, etc.) generated by
/// [StaffingReminderHelper].
class _StaffingRemindersBanner extends StatelessWidget {
  const _StaffingRemindersBanner({required this.reminders});

  final List<StaffingReminder> reminders;

  @override
  Widget build(BuildContext context) {
    final stats = StaffingReminderHelper.getReminderStats(reminders);
    final criticalCount = stats['critical'] ?? 0;
    final highCount = stats['high'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: criticalCount > 0
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: criticalCount > 0
              ? const Color(0xFFFECACA)
              : const Color(0xFFFDE68A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                criticalCount > 0
                    ? Icons.notification_important
                    : Icons.notifications_active,
                color: criticalCount > 0
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFD97706),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Staffing Reminders (${reminders.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: criticalCount > 0
                        ? const Color(0xFF991B1B)
                        : const Color(0xFF92400E),
                  ),
                ),
              ),
              if (criticalCount > 0 || highCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: criticalCount > 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$criticalCount critical • $highCount high',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...reminders.take(5).map((r) => Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(r.typeIcon, size: 16, color: r.priorityColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.message,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF374151)),
                      ),
                    ),
                  ],
                ),
              )),
          if (reminders.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                '+ ${reminders.length - 5} more reminders',
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}

/// AI Suggestion dialog — shows the user the recommended NDU Project Access
/// picks and lets them review + accept.
class _NduSuggestionDialog extends StatefulWidget {
  const _NduSuggestionDialog({
    required this.tierLabel,
    required this.tierCapacity,
    required this.includedUsers,
    required this.maxUsers,
    required this.currentStaffing,
    required this.suggestedIndices,
    required this.suggestedAdditions,
    required this.projectScope,
  });

  final String tierLabel;
  final int tierCapacity;
  final int includedUsers;
  final int maxUsers;
  final List<StaffingRequirement> currentStaffing;
  final Set<int> suggestedIndices;
  final List<StaffingRequirement> suggestedAdditions;
  final String projectScope;

  @override
  State<_NduSuggestionDialog> createState() => _NduSuggestionDialogState();
}

class _NduSuggestionDialogState extends State<_NduSuggestionDialog> {
  late Set<int> _acceptedIndices;
  late List<bool> _additionSelected;

  @override
  void initState() {
    super.initState();
    _acceptedIndices = {...widget.suggestedIndices};
    _additionSelected =
        List.filled(widget.suggestedAdditions.length, true);
  }

  @override
  Widget build(BuildContext context) {
    final alreadyYes =
        widget.currentStaffing.where((s) => s.nduProjectAccess).length;
    final acceptedCount = _acceptedIndices.length;
    final additionsCount =
        _additionSelected.where((b) => b).length;
    final totalAfter = alreadyYes + acceptedCount + additionsCount;
    final overTier = totalAfter > widget.tierCapacity;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Color(0xFFFFC812)),
          SizedBox(width: 8),
          Expanded(
            child: Text('AI Suggested NDU Project Access'),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tier summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tier: ${widget.tierLabel}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Includes ${widget.includedUsers} user${widget.includedUsers == 1 ? '' : 's'} '
                      '(max ${widget.maxUsers}). $alreadyYes role${alreadyYes == 1 ? '' : 's'} already '
                      'have NDU access. After applying: $totalAfter role${totalAfter == 1 ? '' : 's'} will have access.',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF4B5563)),
                    ),
                    if (overTier) ...[
                      const SizedBox(height: 6),
                      const Text(
                        '⚠ Exceeds tier included capacity — additional users '
                        'may incur add-on charges.',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Project Scope',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                widget.projectScope,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              if (widget.currentStaffing.isEmpty &&
                  widget.suggestedAdditions.isEmpty) ...[
                const Text(
                  'No staffing positions yet, and no suggestions available. '
                  'Add at least one position to begin.',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontStyle: FontStyle.italic),
                ),
              ],
              if (widget.currentStaffing.isNotEmpty) ...[
                const Text(
                  'Existing Positions',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.currentStaffing.length,
                    itemBuilder: (ctx, i) {
                      final req = widget.currentStaffing[i];
                      final hasAccess = req.nduProjectAccess;
                      final suggested =
                          widget.suggestedIndices.contains(i);
                      final accepted = _acceptedIndices.contains(i);
                      return CheckboxListTile(
                        dense: true,
                        value: hasAccess || accepted,
                        onChanged: hasAccess
                            ? null
                            : (val) {
                                setState(() {
                                  if (val == true) {
                                    _acceptedIndices.add(i);
                                  } else {
                                    _acceptedIndices.remove(i);
                                  }
                                });
                              },
                        title: Text(
                          req.title.isEmpty ? 'Untitled Position' : req.title,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          hasAccess
                              ? 'Already has access'
                              : suggested
                                  ? 'AI suggested${req.personName.isNotEmpty ? ' — ${req.personName}' : ''}'
                                  : (req.personName.isNotEmpty
                                      ? req.personName
                                      : 'No name assigned'),
                          style: TextStyle(
                              fontSize: 11,
                              color: hasAccess
                                  ? const Color(0xFF059669)
                                  : suggested
                                      ? const Color(0xFFFFC812)
                                      : const Color(0xFF6B7280),
                              fontWeight: hasAccess || suggested
                                  ? FontWeight.w700
                                  : FontWeight.w400),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (widget.suggestedAdditions.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Suggested Additional Positions',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your tier allows more roles — consider adding these to '
                  'cover additional scope. New positions will be created '
                  'with NDU access = Yes.',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.suggestedAdditions.length,
                    itemBuilder: (ctx, i) {
                      final add = widget.suggestedAdditions[i];
                      return CheckboxListTile(
                        dense: true,
                        value: _additionSelected[i],
                        onChanged: (val) {
                          setState(() {
                            _additionSelected[i] = val ?? false;
                          });
                        },
                        title: Text(
                          add.title,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          add.notes.isEmpty
                              ? 'New suggested position'
                              : add.notes,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final additions = <StaffingRequirement>[];
            for (var i = 0; i < widget.suggestedAdditions.length; i++) {
              if (_additionSelected[i]) {
                additions.add(widget.suggestedAdditions[i]);
              }
            }
            Navigator.pop(
              context,
              _NduSuggestionResult(
                acceptedIndices: _acceptedIndices,
                additions: additions,
              ),
            );
          },
          icon: const Icon(Icons.check, size: 16),
          label: Text('Apply ($totalAfter role${totalAfter == 1 ? '' : 's'})'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC812),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Popup editor for adding / editing a [StaffingRequirement]. Implements
/// the typeable Name field with autocomplete from existing site users, the
/// split Type column (Employment FT/PT + Category Employee/Contractor), the
/// Start Date (Mobilization) and Release Date pickers, the NDU Project
/// Access Yes/No toggle, and the location field (auto-fill from project
/// location on add).
class _StaffingRequirementDialog extends StatefulWidget {
  const _StaffingRequirementDialog({
    required this.title,
    required this.requirement,
    required this.positionOptions,
    required this.customPositionOption,
    required this.employmentOptions,
    required this.categoryOptions,
    required this.statusOptions,
    required this.projectLocation,
  });

  final String title;
  final StaffingRequirement requirement;
  final List<String> positionOptions;
  final String customPositionOption;
  final List<String> employmentOptions;
  final List<String> categoryOptions;
  final List<String> statusOptions;
  final String projectLocation;

  @override
  State<_StaffingRequirementDialog> createState() =>
      _StaffingRequirementDialogState();
}

class _StaffingRequirementDialogState
    extends State<_StaffingRequirementDialog> {
  late String _selectedPosition;
  late TextEditingController _customPositionCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _monthlyCostCtrl;
  late TextEditingController _plannedMonthsCtrl;
  late String _employmentLabel; // Full Time / Part Time
  late String _categoryLabel; // Employee / Contractor
  late String _startDate;
  late String _releaseDate;
  late String _status;
  late bool _nduAccess;
  late int _headcount;

  List<UserModel> _userSuggestions = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    final r = widget.requirement;
    final hasPosition =
        widget.positionOptions.contains(r.title);
    _selectedPosition = hasPosition ? r.title : widget.customPositionOption;
    _customPositionCtrl = TextEditingController(
      text: _selectedPosition == widget.customPositionOption ? r.title : '',
    );
    _nameCtrl = TextEditingController(text: r.personName);
    _locationCtrl = TextEditingController(text: r.location);
    _notesCtrl = TextEditingController(text: r.notes);
    _monthlyCostCtrl = TextEditingController(
        text: r.monthlyCost > 0 ? r.monthlyCost.toStringAsFixed(0) : '');
    _plannedMonthsCtrl = TextEditingController(
        text: r.plannedMonths > 0 ? r.plannedMonths.toStringAsFixed(1) : '');
    _employmentLabel = r.employmentType == 'PT' ? 'Part Time' : 'Full Time';
    _categoryLabel = r.employeeType.trim().isEmpty
        ? 'Employee'
        : (widget.categoryOptions.contains(r.employeeType)
            ? r.employeeType
            : 'Employee');
    _startDate = r.startDate;
    _releaseDate = r.endDate;
    _status = r.status.trim().isEmpty ? 'Not Started' : r.status;
    _nduAccess = r.nduProjectAccess;
    _headcount = r.headcount > 0 ? r.headcount : 1;
  }

  @override
  void dispose() {
    _customPositionCtrl.dispose();
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    _monthlyCostCtrl.dispose();
    _plannedMonthsCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _userSuggestions = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await UserService.searchUsers(query);
      if (mounted) {
        setState(() {
          _userSuggestions = results;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userSuggestions = const [];
          _searching = false;
        });
      }
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_parseDate(_startDate) ?? now)
        : (_parseDate(_releaseDate) ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    final formatted = DateFormat('yyyy-MM-dd').format(picked);
    setState(() {
      if (isStart) {
        _startDate = formatted;
      } else {
        _releaseDate = formatted;
      }
    });
  }

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    try {
      return DateFormat('yyyy-MM-dd').parse(s);
    } catch (_) {
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }
  }

  StaffingRequirement _buildResult() {
    final titleValue = _selectedPosition == widget.customPositionOption
        ? _customPositionCtrl.text.trim()
        : _selectedPosition;
    final employmentCode = _employmentLabel == 'Part Time' ? 'PT' : 'FT';
    return StaffingRequirement(
      id: widget.requirement.id,
      title: titleValue,
      headcount: _headcount,
      monthlyCost:
          double.tryParse(_monthlyCostCtrl.text.trim()) ?? 0,
      plannedMonths:
          double.tryParse(_plannedMonthsCtrl.text.trim()) ?? 0,
      startDate: _startDate,
      endDate: _releaseDate,
      status: _status,
      personName: _nameCtrl.text.trim(),
      employmentType: employmentCode,
      location: _locationCtrl.text.trim(),
      employeeType: _categoryLabel,
      notes: _notesCtrl.text.trim(),
      nduProjectAccess: _nduAccess,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.badge_outlined, color: Color(0xFFFFC812)),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Position title
              const _DialogLabel('Position'),
              DropdownButtonFormField<String>(
                initialValue: _selectedPosition,
                items: [
                  ...widget.positionOptions,
                  widget.customPositionOption,
                ]
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedPosition = v);
                },
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'Select a position'),
              ),
              if (_selectedPosition == widget.customPositionOption) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customPositionCtrl,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: 'Enter custom position title'),
                ),
              ],
              const SizedBox(height: 14),
              // Name (typeable + autocomplete from site users)
              const _DialogLabel('Name'),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  hintText: 'Type a name — site members appear instantly',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                  suffixIcon: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: (value) {
                  _searchUsers(value);
                },
              ),
              if (_userSuggestions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _userSuggestions.length,
                    itemBuilder: (ctx, i) {
                      final user = _userSuggestions[i];
                      final alreadySelected =
                          _nameCtrl.text.trim() == user.displayName;
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFFF8E1),
                          child: Text(
                            (user.displayName.isNotEmpty
                                    ? user.displayName[0]
                                    : (user.email.isNotEmpty
                                        ? user.email[0]
                                        : '?'))
                                .toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFF4338CA),
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(user.displayName,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(user.email,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF6B7280))),
                        trailing: alreadySelected
                            ? const Icon(Icons.check, color: Color(0xFF059669))
                            : const Icon(Icons.add_circle_outline,
                                color: Color(0xFFFFC812)),
                        onTap: () {
                          setState(() {
                            _nameCtrl.text = user.displayName;
                            _userSuggestions = const [];
                            if (_locationCtrl.text.trim().isEmpty) {
                              _locationCtrl.text = widget.projectLocation;
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ] else if (_nameCtrl.text.trim().isNotEmpty &&
                  _nameCtrl.text.trim().length >= 2 &&
                  !_searching) ...[
                const SizedBox(height: 4),
                const Text(
                  'Not found on site? No problem — this name will be saved as-is. '
                  'You can also add them later as a site member.',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 14),
              // Location + Headcount side by side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _DialogLabel('Location'),
                        TextField(
                          controller: _locationCtrl,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            isDense: true,
                            hintText: 'e.g. Lusaka, Zambia',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.my_location, size: 16),
                              tooltip: 'Use project location',
                              onPressed: () {
                                setState(() {
                                  _locationCtrl.text = widget.projectLocation;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _DialogLabel('Headcount'),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 20),
                              onPressed: _headcount <= 1
                                  ? null
                                  : () => setState(() => _headcount--),
                            ),
                            Text('$_headcount',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 20),
                              onPressed: () =>
                                  setState(() => _headcount++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Employment + Category side by side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _DialogLabel('Employment'),
                        DropdownButtonFormField<String>(
                          initialValue: _employmentLabel,
                          items: widget.employmentOptions
                              .map((e) => DropdownMenuItem(
                                  value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _employmentLabel = v);
                          },
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(), isDense: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _DialogLabel('Category'),
                        DropdownButtonFormField<String>(
                          initialValue: _categoryLabel,
                          items: widget.categoryOptions
                              .map((e) => DropdownMenuItem(
                                  value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _categoryLabel = v);
                          },
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(), isDense: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Start Date + Release Date side by side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _DialogLabel('Start Date (Mobilization)'),
                        InkWell(
                          onTap: () => _pickDate(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFFD1D5DB)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event,
                                    size: 16, color: Color(0xFF6B7280)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _startDate.isEmpty
                                        ? 'Pick a date'
                                        : _startDate,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: _startDate.isEmpty
                                            ? const Color(0xFF9CA3AF)
                                            : const Color(0xFF111827)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _DialogLabel('Release Date'),
                        InkWell(
                          onTap: () => _pickDate(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFFD1D5DB)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_busy,
                                    size: 16, color: Color(0xFF6B7280)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _releaseDate.isEmpty
                                        ? 'Pick a date'
                                        : _releaseDate,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: _releaseDate.isEmpty
                                            ? const Color(0xFF9CA3AF)
                                            : const Color(0xFF111827)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // NDU Access + Status side by side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _DialogLabel('NDU Project Access'),
                        InkWell(
                          onTap: () => setState(() => _nduAccess = !_nduAccess),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: _nduAccess
                                  ? const Color(0xFFD1FAE5)
                                  : const Color(0xFFF3F4F6),
                              border: Border.all(
                                  color: _nduAccess
                                      ? const Color(0xFFA7F3D0)
                                      : const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _nduAccess
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  size: 18,
                                  color: _nduAccess
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _nduAccess ? 'Yes' : 'No',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _nduAccess
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                                const Spacer(),
                                const Text('Tap to toggle',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6B7280))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _DialogLabel('Status'),
                        DropdownButtonFormField<String>(
                          initialValue: _status,
                          items: widget.statusOptions
                              .map((e) => DropdownMenuItem(
                                  value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _status = v);
                          },
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(), isDense: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Monthly Cost + Planned Months (kept for cost calcs, hidden from table)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Cost & Duration (optional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Used for cost roll-ups on the Cost Estimate screen.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _DialogLabel('Monthly Cost (USD)'),
                            TextField(
                              controller: _monthlyCostCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  hintText: '0'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _DialogLabel('Planned Months'),
                            TextField(
                              controller: _plannedMonthsCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  hintText: '0.0'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _DialogLabel('Notes'),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: 'Optional notes — certifications, '
                            'clearances, special conditions, etc.'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final result = _buildResult();
            if (result.title.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Please enter a position title.')));
              return;
            }
            Navigator.pop(context, result);
          },
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Save'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC107),
            foregroundColor: Colors.black,
          ),
        ),
      ],
    );
  }
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151)),
      ),
    );
  }
}

class _OrganizationRolesResponsibilitiesScreenState
    extends State<OrganizationRolesResponsibilitiesScreen> {
  static const List<String> _roleTitleOptions = [
    'Project Manager',
    'Program Manager',
    'Product Owner',
    'Scrum Master',
    'Business Analyst',
    'PMO Lead',
    'Delivery Manager',
    'Operations Manager',
    'Risk Manager',
    'Quality Assurance Lead',
    'Change Manager',
    'Stakeholder Manager',
    'Planning Engineer',
    'Project Coordinator',
    'Portfolio Manager',
  ];
  static const String _customRoleOption = 'Custom';

  /// Role bank: maps role title → (description, workstream).
  /// When a user selects a title from the dropdown, the description is auto-filled.
  static const Map<String, _RoleBankEntry> _roleBank = {
    'Project Manager': _RoleBankEntry(
      description:
          'Overall project leadership, planning, and coordination across all phases.',
      workstream: 'Management',
    ),
    'Program Manager': _RoleBankEntry(
      description:
          'Multi-project program coordination and strategic alignment.',
      workstream: 'Management',
    ),
    'Product Owner': _RoleBankEntry(
      description:
          'Agile product owner — backlog prioritization and stakeholder representation.',
      workstream: 'Management',
    ),
    'Scrum Master': _RoleBankEntry(
      description:
          'Facilitates Agile ceremonies, removes impediments, and coaches the team on Scrum practices.',
      workstream: 'Management',
    ),
    'Business Analyst': _RoleBankEntry(
      description:
          'Elicits, documents, and manages requirements. Bridges business stakeholders and delivery teams.',
      workstream: 'Management',
    ),
    'PMO Lead': _RoleBankEntry(
      description:
          'Project Management Office oversight, governance, and standards.',
      workstream: 'Management',
    ),
    'Delivery Manager': _RoleBankEntry(
      description:
          'Coordinates delivery across teams, manages dependencies, and ensures timely execution.',
      workstream: 'Management',
    ),
    'Operations Manager': _RoleBankEntry(
      description:
          'Manages day-to-day operations, resource allocation, and process optimization.',
      workstream: 'Operations',
    ),
    'Risk Manager': _RoleBankEntry(
      description:
          'Identifies, assesses, and mitigates project risks. Maintains the risk register.',
      workstream: 'Management',
    ),
    'Quality Assurance Lead': _RoleBankEntry(
      description:
          'Owns quality planning, QA/QC processes, and compliance with standards.',
      workstream: 'Quality',
    ),
    'Change Manager': _RoleBankEntry(
      description:
          'Manages organizational change, stakeholder adoption, and transition planning.',
      workstream: 'Management',
    ),
    'Stakeholder Manager': _RoleBankEntry(
      description:
          'Manages stakeholder engagement, communication, and alignment throughout the project.',
      workstream: 'Management',
    ),
    'Planning Engineer': _RoleBankEntry(
      description:
          'Develops and maintains project schedules, WBS, and progress tracking.',
      workstream: 'Engineering',
    ),
    'Project Coordinator': _RoleBankEntry(
      description:
          'Supports project administration, documentation, and meeting coordination.',
      workstream: 'Management',
    ),
    'Portfolio Manager': _RoleBankEntry(
      description:
          'Oversees portfolio of projects, prioritizes investments, and aligns with strategic objectives.',
      workstream: 'Management',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final projectData = ProjectDataHelper.getData(context);
    final roles = projectData.projectRoles;

    final totalPersonnel = roles.fold<int>(
        0, (sum, role) => sum + (role.headcount > 0 ? role.headcount : 1));

    final List<_MetricData> metrics = [
      _MetricData(
          'Total Roles', roles.length.toString(), const Color(0xFFFFC812)),
      _MetricData(
          'Total Personnel',
          totalPersonnel.toString(),
          const Color(0xFFB8860B)),
      _MetricData(
          'Disciplines',
          roles.map<String>((r) => r.workstream).toSet().length.toString(),
          const Color(0xFF10B981)),
    ];

    final List<_SectionData> sections =
        roles.asMap().entries.map<_SectionData>((entry) {
      final index = entry.key;
      final role = entry.value;
      return _SectionData(
        title: role.title,
        subtitle: role.workstream,
        bullets: [
          _BulletData(role.description, false),
        ],
        headcount: role.headcount > 0 ? role.headcount : 1,
        onEdit: () => _editRole(context, index, role),
        onDelete: () => _deleteRole(context, index),
      );
    }).toList();

    return _PlanningSubsectionScreen(
      config: _PlanningSubsectionConfig(
        title: 'Roles & Responsibilities',
        subtitle: 'Clarify ownership across workstreams and decision points.',
        noteKey: 'planning_organization_roles_responsibilities',
        checkpoint: 'organization_roles_responsibilities',
        activeItemLabel: 'Organization Plan - Roles & Responsibilities',
        metrics: metrics,
        sections: sections,
        roles: roles,
        showTableView: true,
      ),
      onAdd: () => _addRole(context),
      onAddPredefined: () => _showPredefinedRolesDialog(context),
      onEditRole: (index, role) => _editRole(context, index, role),
      onDeleteRole: (index) => _deleteRole(context, index),
      onUpdateRoleHeadcount: (index, headcount) =>
          _updateRoleHeadcount(context, index, headcount),
    );
  }

  Future<void> _updateRoleHeadcount(
      BuildContext context, int index, int headcount) async {
    final rootContext = context;
    if (headcount < 1) return;
    final updatedRoles = List<RoleDefinition>.from(
        ProjectDataHelper.getProvider(rootContext).projectData.projectRoles);
    if (index < 0 || index >= updatedRoles.length) return;
    updatedRoles[index] =
        updatedRoles[index].copyWith(headcount: headcount);
    await ProjectDataHelper.saveAndNavigate(
      context: rootContext,
      checkpoint: 'organization_roles_responsibilities',
      saveInBackground: true,
      nextScreenBuilder: () =>
          const OrganizationRolesResponsibilitiesScreen(),
      dataUpdater: (d) => d.copyWith(projectRoles: updatedRoles),
    );
    if (mounted) setState(() {});
  }

  void _showPredefinedRolesDialog(BuildContext context) {
    final rootContext = context;
    // ── Standard roles from the Role-Based Access spreadsheet (June 2022) ──
    // All 48 roles are organized by Framework category (Both / Waterfall / Agile)
    // and mapped to user-friendly workstream labels.
    final List<RoleDefinition> predefined = [
      // ── Management ──
      RoleDefinition(
          title: 'Project Sponsor (Owner)',
          description:
              'Executive sponsor and project owner. Provides strategic direction and funding approval.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Project Manager',
          description:
              'Overall project leadership, planning, and coordination across all phases.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'PMO Manager',
          description:
              'Project Management Office oversight, governance, and standards.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Program Manager',
          description:
              'Multi-project program coordination and strategic alignment.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Product Owner',
          description:
              'Agile product owner — backlog prioritization and stakeholder representation.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Project Controls Manager',
          description: 'Cost, schedule, and performance baseline management.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Interface Manager',
          description:
              'Cross-project interface coordination and conflict resolution.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Business Manager',
          description:
              'Business operations and stakeholder relationship management.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Contracts Manager',
          description: 'Contract administration, negotiation, and compliance.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Procurement Manager',
          description:
              'Procurement strategy, vendor selection, and supply chain.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Release Manager',
          description:
              'Agile release planning, deployment coordination, and go-live governance.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Startup Manager',
          description:
              'Commissioning and startup planning for waterfall projects.',
          workstream: 'Management',
          isPredefined: true),
      RoleDefinition(
          title: 'Construction Manager',
          description: 'On-site construction execution and field coordination.',
          workstream: 'Management',
          isPredefined: true),
      // ── Engineering ──
      RoleDefinition(
          title: 'Project Engineer',
          description: 'Technical engineering across all project phases.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Engineering Manager',
          description:
              'Engineering team leadership and technical deliverable ownership.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Technical Manager',
          description:
              'Agile technical team management and architecture oversight.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Change Manager',
          description:
              'Change control process ownership and impact assessment.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Quality Lead',
          description: 'Quality assurance leadership and compliance oversight.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Lead Designer',
          description: 'Agile design leadership and UX direction.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Design Lead',
          description:
              'Waterfall design team leadership and technical drawing ownership.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Lead Developer',
          description: 'Agile development team leadership and code quality.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Schedule Lead',
          description:
              'Schedule planning, critical path analysis, and progress tracking.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Cost Lead',
          description: 'Cost estimation leadership and budget control.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Test Lead',
          description:
              'Testing strategy, test plan ownership, and QA execution.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Change Lead',
          description:
              'Change request analysis and implementation coordination.',
          workstream: 'Engineering',
          isPredefined: true),
      RoleDefinition(
          title: 'Scrum Master',
          description: 'Agile ceremony facilitation and team coaching.',
          workstream: 'Engineering',
          isPredefined: true),
      // ── Specialists ──
      RoleDefinition(
          title: 'Cost Estimator',
          description: 'Detailed cost estimation and quantity takeoff.',
          workstream: 'Specialist',
          isPredefined: true),
      RoleDefinition(
          title: 'Scheduler',
          description: 'Schedule development, updates, and milestone tracking.',
          workstream: 'Specialist',
          isPredefined: true),
      RoleDefinition(
          title: 'Business Analyst',
          description: 'Requirements elicitation, analysis, and documentation.',
          workstream: 'Specialist',
          isPredefined: true),
      RoleDefinition(
          title: 'Technical Architect',
          description: 'System architecture design and technology selection.',
          workstream: 'Specialist',
          isPredefined: true),
      RoleDefinition(
          title: 'Solutions Architect',
          description:
              'End-to-end solution design and integration architecture.',
          workstream: 'Specialist',
          isPredefined: true),
      RoleDefinition(
          title: 'Design Engineer',
          description: 'Engineering design and technical drawing development.',
          workstream: 'Specialist',
          isPredefined: true),
      RoleDefinition(
          title: 'Engineer',
          description: 'General engineering support across disciplines.',
          workstream: 'Specialist',
          isPredefined: true),
      RoleDefinition(
          title: 'Data Specialist',
          description: 'Data modeling, migration, and analytics.',
          workstream: 'Specialist',
          isPredefined: true),
      // ── Development ──
      RoleDefinition(
          title: 'Developer - Backend',
          description: 'Server-side development and API implementation.',
          workstream: 'Development',
          isPredefined: true),
      RoleDefinition(
          title: 'Developer - Frontend',
          description: 'Client-side UI development and user experience.',
          workstream: 'Development',
          isPredefined: true),
      RoleDefinition(
          title: 'Developer - Fullstack',
          description: 'End-to-end development across frontend and backend.',
          workstream: 'Development',
          isPredefined: true),
      RoleDefinition(
          title: 'DevOps Engineer',
          description:
              'CI/CD pipelines, infrastructure automation, and deployment.',
          workstream: 'Development',
          isPredefined: true),
      RoleDefinition(
          title: 'Automation',
          description: 'Test automation and process scripting.',
          workstream: 'Development',
          isPredefined: true),
      // ── Design ──
      RoleDefinition(
          title: 'Designer - UX',
          description:
              'User experience research, wireframing, and prototyping.',
          workstream: 'Design',
          isPredefined: true),
      RoleDefinition(
          title: 'Designer - UI',
          description: 'Visual design, component styling, and design system.',
          workstream: 'Design',
          isPredefined: true),
      // ── QA ──
      RoleDefinition(
          title: 'Tester',
          description: 'Quality assurance and testing of deliverables.',
          workstream: 'QA',
          isPredefined: true),
      RoleDefinition(
          title: 'Quality Control',
          description:
              'Quality inspection, defect tracking, and compliance verification.',
          workstream: 'QA',
          isPredefined: true),
      // ── Operations ──
      RoleDefinition(
          title: 'Procurement',
          description: 'Purchase order processing and vendor coordination.',
          workstream: 'Operations',
          isPredefined: true),
      RoleDefinition(
          title: 'Interface',
          description: 'Interface management and cross-team coordination.',
          workstream: 'Operations',
          isPredefined: true),
      RoleDefinition(
          title: 'Operations Liason',
          description:
              'Operational handover and production support coordination.',
          workstream: 'Operations',
          isPredefined: true),
      RoleDefinition(
          title: 'Hypercare',
          description: 'Post-go-live hypercare support and issue resolution.',
          workstream: 'Operations',
          isPredefined: true),
      // ── Custom ──
      RoleDefinition(
          title: 'Create Role',
          description: 'Define a custom role not listed above.',
          workstream: 'Custom',
          isPredefined: true),
    ];

    final currentRoles =
        ProjectDataHelper.getProvider(context).projectData.projectRoles;
    final selectedIndices = <int>{};
    final headcounts = <int, int>{};

    showDialog(
      context: rootContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Standard Roles'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Tick the roles you want to add, then set the number of personnel for each in one pass.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 460),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: predefined.length,
                    itemBuilder: (context, index) {
                      final role = predefined[index];
                      final alreadyAdded =
                          currentRoles.any((r) => r.title == role.title);
                      final isSelected =
                          selectedIndices.contains(index) || alreadyAdded;
                      final headcount = headcounts[index] ?? 1;
                      return _PredefinedRoleRow(
                        title: role.title,
                        workstream: role.workstream,
                        isSelected: isSelected,
                        enabled: !alreadyAdded,
                        headcount: headcount,
                        onToggle: alreadyAdded
                            ? null
                            : (val) {
                                setDialogState(() {
                                  if (val == true) {
                                    selectedIndices.add(index);
                                    headcounts[index] = 1;
                                  } else {
                                    selectedIndices.remove(index);
                                    headcounts.remove(index);
                                  }
                                });
                              },
                        onHeadcountChanged: alreadyAdded || !isSelected
                            ? null
                            : (value) {
                                setDialogState(() {
                                  headcounts[index] = value;
                                });
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedIndices.isEmpty
                  ? null
                  : () async {
                      final newRoles = selectedIndices.map((i) {
                        final base = predefined[i];
                        final hc = headcounts[i] ?? 1;
                        return base.copyWith(
                            headcount: hc < 1 ? 1 : hc, isPredefined: true);
                      }).toList();
                      Navigator.pop(dialogContext);
                      await ProjectDataHelper.saveAndNavigate(
                        context: rootContext,
                        checkpoint: 'organization_roles_responsibilities',
                        saveInBackground: true,
                        nextScreenBuilder: () =>
                            const OrganizationRolesResponsibilitiesScreen(),
                        dataUpdater: (d) => d.copyWith(
                            projectRoles: [...d.projectRoles, ...newRoles]),
                      );
                      if (mounted) setState(() {});
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black),
              child: const Text('Add Selected'),
            ),
          ],
        ),
      ),
    );
  }

  void _editRole(BuildContext context, int index, RoleDefinition role) {
    final rootContext = context;
    String selectedTitle =
        _roleTitleOptions.contains(role.title) ? role.title : _customRoleOption;
    final customTitleController = TextEditingController(
      text: selectedTitle == _customRoleOption ? role.title : '',
    );
    final workstreamController = TextEditingController(text: role.workstream);
    final descController = TextEditingController(text: role.description);
    int headcount = role.headcount > 0 ? role.headcount : 1;

    showDialog(
      context: rootContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PremiumEditDialog(
          title: 'Edit Role',
          icon: Icons.badge_outlined,
          onSave: () async {
            final updatedRoles = List<RoleDefinition>.from(
                ProjectDataHelper.getProvider(rootContext)
                    .projectData
                    .projectRoles);
            final titleValue = selectedTitle == _customRoleOption
                ? customTitleController.text.trim()
                : selectedTitle;
            updatedRoles[index] = updatedRoles[index].copyWith(
              title: titleValue,
              workstream: workstreamController.text.trim(),
              description: descController.text.trim(),
              headcount: headcount,
            );
            Navigator.pop(dialogContext);
            await ProjectDataHelper.saveAndNavigate(
              context: rootContext,
              checkpoint: 'organization_roles_responsibilities',
              saveInBackground: true,
              nextScreenBuilder: () =>
                  const OrganizationRolesResponsibilitiesScreen(),
              dataUpdater: (d) => d.copyWith(projectRoles: updatedRoles),
            );
            if (mounted) setState(() {});
          },
          children: [
            PremiumEditDialog.fieldLabel('Title'),
            DropdownButtonFormField<String>(
              initialValue: selectedTitle,
              items: [
                ..._roleTitleOptions,
                _customRoleOption,
              ]
                  .map((title) =>
                      DropdownMenuItem(value: title, child: Text(title)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setDialogState(() {
                  selectedTitle = value;
                  // Auto-fill description and workstream from role bank
                  final entry = _roleBank[value];
                  if (entry != null) {
                    descController.text = entry.description;
                    workstreamController.text = entry.workstream;
                  }
                });
              },
              decoration: const InputDecoration(
                hintText: 'Select a role title',
                border: OutlineInputBorder(),
              ),
            ),
            if (selectedTitle == _customRoleOption) ...[
              const SizedBox(height: 12),
              PremiumEditDialog.textField(
                controller: customTitleController,
                hint: 'Enter custom role title',
              ),
            ],
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Discipline'),
            PremiumEditDialog.textField(
                controller: workstreamController, hint: 'e.g. Management'),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Number of personnel'),
            _DialogHeadcountStepper(
              headcount: headcount,
              onChanged: (value) =>
                  setDialogState(() => headcount = value),
            ),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Description'),
            PremiumEditDialog.textField(
                controller: descController,
                hint: 'Role responsibilities...',
                maxLines: 4),
          ],
        ),
      ),
    );
  }

  void _addRole(BuildContext context) {
    final rootContext = context;
    String selectedTitle = _roleTitleOptions.first;
    final customTitleController = TextEditingController();
    final workstreamController = TextEditingController();
    final descController = TextEditingController();
    int headcount = 1;

    showDialog(
      context: rootContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PremiumEditDialog(
          title: 'Add Role',
          icon: Icons.badge_outlined,
          onSave: () async {
            final titleValue = selectedTitle == _customRoleOption
                ? customTitleController.text.trim()
                : selectedTitle;
            final workstream = workstreamController.text.trim();
            final description = descController.text.trim();
            final newRole = RoleDefinition(
              title: titleValue.isNotEmpty ? titleValue : 'New Role',
              workstream: workstream.isNotEmpty ? workstream : 'Default',
              description:
                  description.isNotEmpty ? description : 'Role description',
              headcount: headcount,
            );
            Navigator.pop(dialogContext);
            await ProjectDataHelper.saveAndNavigate(
              context: rootContext,
              checkpoint: 'organization_roles_responsibilities',
              saveInBackground: true,
              nextScreenBuilder: () =>
                  const OrganizationRolesResponsibilitiesScreen(),
              dataUpdater: (d) =>
                  d.copyWith(projectRoles: [...d.projectRoles, newRole]),
            );
            if (mounted) setState(() {});
          },
          children: [
            PremiumEditDialog.fieldLabel('Title'),
            DropdownButtonFormField<String>(
              initialValue: selectedTitle,
              items: [
                ..._roleTitleOptions,
                _customRoleOption,
              ]
                  .map((title) =>
                      DropdownMenuItem(value: title, child: Text(title)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setDialogState(() {
                  selectedTitle = value;
                  // Auto-fill description and workstream from role bank
                  final entry = _roleBank[value];
                  if (entry != null) {
                    descController.text = entry.description;
                    workstreamController.text = entry.workstream;
                  }
                });
              },
              decoration: const InputDecoration(
                hintText: 'Select a role title',
                border: OutlineInputBorder(),
              ),
            ),
            if (selectedTitle == _customRoleOption) ...[
              const SizedBox(height: 12),
              PremiumEditDialog.textField(
                controller: customTitleController,
                hint: 'Enter custom role title',
              ),
            ],
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Discipline'),
            PremiumEditDialog.textField(
                controller: workstreamController, hint: 'e.g. Management'),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Number of personnel'),
            _DialogHeadcountStepper(
              headcount: headcount,
              onChanged: (value) =>
                  setDialogState(() => headcount = value),
            ),
            const SizedBox(height: 16),
            PremiumEditDialog.fieldLabel('Description'),
            PremiumEditDialog.textField(
                controller: descController,
                hint: 'Role responsibilities...',
                maxLines: 4),
          ],
        ),
      ),
    );
  }

  void _deleteRole(BuildContext context, int index) {
    final rootContext = context;
    showDialog(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Role'),
        content: const Text('Are you sure you want to delete this role?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final updatedRoles = List<RoleDefinition>.from(
                  ProjectDataHelper.getProvider(rootContext)
                      .projectData
                      .projectRoles);
              updatedRoles.removeAt(index);
              showDeleteSuccessSnackBar(context, itemLabel: 'Role');
              Navigator.pop(dialogContext);
              await ProjectDataHelper.saveAndNavigate(
                context: rootContext,
                checkpoint: 'organization_roles_responsibilities',
                saveInBackground: true,
                nextScreenBuilder: () =>
                    const OrganizationRolesResponsibilitiesScreen(),
                dataUpdater: (d) => d.copyWith(projectRoles: updatedRoles),
              );
              if (mounted) setState(() {});
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class OrganizationRaciMatrixScreen extends StatefulWidget {
  const OrganizationRaciMatrixScreen({super.key});

  @override
  State<OrganizationRaciMatrixScreen> createState() =>
      _OrganizationRaciMatrixScreenState();
}

class _OrganizationRaciMatrixScreenState
    extends State<OrganizationRaciMatrixScreen> {
  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final horizontalPadding = isMobile ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                activeItemLabel: 'Organization Plan - RACI Matrix',
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  const MobileSidebarHamburger(
                    sidebar: InitiationLikeSidebar(
                      activeItemLabel: 'Organization Plan - RACI Matrix',
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlanningPhaseHeader(
                          title: 'RACI Matrix',
                          onExportPdf: _exportRaciPdf,
                        ),
                        const SizedBox(height: 16),
                        _TopHeader(
                          title: 'RACI Matrix',
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                            context,
                            'organization_raci_matrix',
                          ),
                          onNext: () => PlanningPhaseNavigation.goToNext(
                            context,
                            'organization_raci_matrix',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Auto-customized to your project scope. The matrix '
                          'pulls every sidebar deliverable (Planning → '
                          'Launch) and every position identified on the '
                          'Roles & Responsibilities page, then takes a '
                          'first stab at distributing RACI designations '
                          'based on the Staffing Plan.',
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFF6B7280), height: 1.45),
                        ),
                        const SizedBox(height: 20),
                        const PlanningAiNotesCard(
                          title: 'Notes',
                          sectionLabel: 'RACI Matrix',
                          noteKey: 'planning_organization_raci_matrix',
                          checkpoint: 'organization_raci_matrix',
                          description:
                              'Capture tailoring decisions for responsibility ownership and governance.',
                        ),
                        const SizedBox(height: 24),
                        const RaciDeliverableMatrix(),
                        const SizedBox(height: 24),
                        LaunchPhaseNavigation(
                          backLabel: PlanningPhaseNavigation.backLabel(
                            'organization_raci_matrix',
                          ),
                          nextLabel: PlanningPhaseNavigation.nextLabel(
                            'organization_raci_matrix',
                          ),
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                            context,
                            'organization_raci_matrix',
                          ),
                          onNext: () => PlanningPhaseNavigation.goToNext(
                            context,
                            'organization_raci_matrix',
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  const Positioned(
                    right: 24,
                    bottom: 24,
                    child: KazAiChatBubble(positioned: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportRaciPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    final rows = projectData.raciDeliverableRows;
    // Build dedup'd column list (Staffing Plan first, then any extra
    // roles from Roles & Responsibilities).
    final dedup = <String>[];
    for (final c in [
      ...projectData.staffingRequirements.map((s) => s.title.trim()),
      ...projectData.projectRoles.map((r) => r.title.trim()),
    ]) {
      if (c.isEmpty) continue;
      final key = c.toLowerCase();
      if (dedup.any((d) => d.toLowerCase() == key)) continue;
      dedup.add(c);
    }
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'RACI Deliverable Matrix',
      sections: [
        PdfSection.keyValue('Project Info', [
          {
            'Project Name': projectData.projectName.isEmpty
                ? 'N/A'
                : projectData.projectName
          },
          {
            'Solution Title': projectData.solutionTitle.isEmpty
                ? 'N/A'
                : projectData.solutionTitle
          },
          {
            'Approval Status': projectData.raciApprovalStatus.isApproved
                ? 'Approved by ${projectData.raciApprovalStatus.approverName}'
                : 'Draft'
          },
        ]),
        PdfSection.table(
          'RACI Matrix',
          headers: ['Deliverable', 'Phase', ...dedup],
          rows: rows
              .map((row) => [
                    row.label,
                    row.phase,
                    ...dedup.map((c) =>
                        row.assignments[c.toLowerCase()]?.toUpperCase() ?? ''),
                  ])
              .toList(),
        ),
      ],
    );
  }
}

class _PlanningSubsectionScreen extends StatefulWidget {
  const _PlanningSubsectionScreen(
      {required this.config,
      this.onAdd,
      this.onAddPredefined,
      this.onEditRole,
      this.onDeleteRole,
      this.onUpdateRoleHeadcount});

  final _PlanningSubsectionConfig config;
  final VoidCallback? onAdd;
  final VoidCallback? onAddPredefined;
  final void Function(int index, RoleDefinition role)? onEditRole;
  final void Function(int index)? onDeleteRole;
  final void Function(int index, int headcount)? onUpdateRoleHeadcount;

  @override
  State<_PlanningSubsectionScreen> createState() =>
      _PlanningSubsectionScreenState();
}

class _PlanningSubsectionScreenState extends State<_PlanningSubsectionScreen> {
  bool _isTableView = false;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final isMobile = AppBreakpoints.isMobile(context);
    final horizontalPadding = isMobile ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: InitiationLikeSidebar(
                  activeItemLabel: config.activeItemLabel),
            ),
            Expanded(
              child: Stack(
                children: [
                  const MobileSidebarHamburger(
                    sidebar: InitiationLikeSidebar(
                      activeItemLabel: 'Organization Plan - Staffing Plan',
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        const gap = 24.0;
                        final twoCol = width >= 980;
                        final halfWidth = twoCol ? (width - gap) / 2 : width;
                        final hasContent = config.metrics.isNotEmpty ||
                            config.sections.isNotEmpty;
                        final showViewToggle =
                            config.showTableView && config.roles.isNotEmpty;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PlanningPhaseHeader(
                                title: 'Roles & Responsibilities',
                                onExportPdf: () =>
                                    _exportPlanningSubsectionPdf(context)),
                            const SizedBox(height: 16),
                            _TopHeader(
                              title: config.title,
                              onBack: () =>
                                  PlanningPhaseNavigation.goToPrevious(
                                      context, config.checkpoint),
                              onNext: () => PlanningPhaseNavigation.goToNext(
                                  context, config.checkpoint),
                              onAdd: widget.onAdd,
                              onAddPredefined: widget.onAddPredefined,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              config.subtitle,
                              style: const TextStyle(
                                  fontSize: 14, color: Color(0xFF6B7280)),
                            ),
                            const SizedBox(height: 20),
                            PlanningAiNotesCard(
                              title: 'Notes',
                              sectionLabel: config.title,
                              noteKey: config.noteKey,
                              checkpoint: config.checkpoint,
                              description:
                                  'Capture ownership, staffing needs, and role coverage.',
                            ),
                            const SizedBox(height: 24),
                            if (hasContent) ...[
                              _MetricsRow(metrics: config.metrics),
                              const SizedBox(height: 24),
                              if (showViewToggle) ...[
                                Row(
                                  children: [
                                    _ViewToggle(
                                      isTableView: _isTableView,
                                      onChanged: (value) => setState(
                                          () => _isTableView = value),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (_isTableView && config.roles.isNotEmpty)
                                _RolesTable(
                                  roles: config.roles,
                                  onEdit: widget.onEditRole,
                                  onDelete: widget.onDeleteRole,
                                  onUpdateHeadcount:
                                      widget.onUpdateRoleHeadcount,
                                )
                              else
                                Wrap(
                                  spacing: gap,
                                  runSpacing: gap,
                                  children: config.sections
                                      .map((section) => SizedBox(
                                          width: halfWidth,
                                          child: _SectionCard(data: section)))
                                      .toList(),
                                ),
                            ] else
                              const _SectionEmptyState(
                                title: 'No staffing details yet',
                                message:
                                    'Add roles, responsibilities, and staffing notes to populate this view.',
                                icon: Icons.group_outlined,
                              ),
                            const SizedBox(height: 24),
                            LaunchPhaseNavigation(
                              backLabel: PlanningPhaseNavigation.backLabel(
                                  config.checkpoint),
                              nextLabel: PlanningPhaseNavigation.nextLabel(
                                  config.checkpoint),
                              onBack: () =>
                                  PlanningPhaseNavigation.goToPrevious(
                                      context, config.checkpoint),
                              onNext: () => PlanningPhaseNavigation.goToNext(
                                  context, config.checkpoint),
                            ),
                            const SizedBox(height: 40),
                          ],
                        );
                      },
                    ),
                  ),
                  const Positioned(
                      right: 24,
                      bottom: 24,
                      child: KazAiChatBubble(positioned: false)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.isTableView, required this.onChanged});

  final bool isTableView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleItem(
            label: 'Cards',
            icon: Icons.dashboard_outlined,
            selected: !isTableView,
            onTap: () => onChanged(false),
          ),
          _toggleItem(
            label: 'Table',
            icon: Icons.table_rows_outlined,
            selected: isTableView,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _toggleItem({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  const BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? const Color(0xFF111827)
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF111827)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Roles table view with inline headcount editing.
class _RolesTable extends StatelessWidget {
  const _RolesTable({
    required this.roles,
    this.onEdit,
    this.onDelete,
    this.onUpdateHeadcount,
  });

  final List<RoleDefinition> roles;
  final void Function(int index, RoleDefinition role)? onEdit;
  final void Function(int index)? onDelete;
  final void Function(int index, int headcount)? onUpdateHeadcount;

  @override
  Widget build(BuildContext context) {
    const rowPadding =
        EdgeInsets.symmetric(horizontal: 12, vertical: 12);
    const columns = <_RoleColumnDef>[
      _RoleColumnDef('#', 56),
      _RoleColumnDef('Position', 220),
      _RoleColumnDef('Discipline', 150),
      _RoleColumnDef('Description', 320),
      _RoleColumnDef('Headcount', 140),
      _RoleColumnDef('Actions', 110),
    ];

    final contentWidth =
        columns.fold<double>(0, (sum, column) => sum + column.width);
    final minTableWidth = contentWidth + 24;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth > minTableWidth
            ? constraints.maxWidth
            : minTableWidth;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  // Header row
                  Container(
                    width: tableWidth,
                    padding: rowPadding,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: columns
                          .map(
                            (column) => SizedBox(
                              width: column.width,
                              child: Text(
                                column.label.toUpperCase(),
                                textAlign: column.label == '#'
                                    ? TextAlign.center
                                    : column.label == 'Headcount' ||
                                            column.label == 'Actions'
                                        ? TextAlign.center
                                        : TextAlign.left,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  // Body rows
                  if (roles.isEmpty)
                    Container(
                      width: tableWidth,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 32),
                      child: const Center(
                        child: Text(
                          'No roles yet. Use "Add Role" or "Standard Roles" to begin.',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: roles.length,
                      itemBuilder: (context, i) {
                        final role = roles[i];
                        return Container(
                          width: tableWidth,
                          padding: rowPadding,
                          decoration: BoxDecoration(
                            color: i.isEven
                                ? Colors.white
                                : const Color(0xFFF9FAFB),
                            border: const Border(
                              top: BorderSide(
                                color: Color(0xFFE5E7EB),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: _RolesTableRow(
                            index: i,
                            role: role,
                            columns: columns,
                            onEdit: onEdit != null
                                ? () => onEdit!(i, role)
                                : null,
                            onDelete: onDelete != null
                                ? () => onDelete!(i)
                                : null,
                            onUpdateHeadcount: onUpdateHeadcount != null
                                ? (value) =>
                                    onUpdateHeadcount!(i, value)
                                : null,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RolesTableRow extends StatelessWidget {
  const _RolesTableRow({
    required this.index,
    required this.role,
    required this.columns,
    this.onEdit,
    this.onDelete,
    this.onUpdateHeadcount,
  });

  final int index;
  final RoleDefinition role;
  final List<_RoleColumnDef> columns;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<int>? onUpdateHeadcount;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      Center(
        child: Text(
          '${index + 1}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4B5563),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          role.title.trim().isEmpty ? 'Untitled Role' : role.title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            role.workstream.trim().isEmpty
                ? 'Uncategorized'
                : role.workstream,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4338CA),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          role.description.trim().isEmpty
              ? '—'
              : role.description,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Color(0xFF374151),
          ),
        ),
      ),
      _HeadcountCell(
        headcount: role.headcount,
        onChanged: onUpdateHeadcount,
      ),
      Align(
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: Color(0xFF6B7280),
              ),
              tooltip: 'Edit role',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Color(0xFFEF4444),
              ),
              tooltip: 'Delete role',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(
        cells.length,
        (cellIndex) => SizedBox(
            width: columns[cellIndex].width, child: cells[cellIndex]),
      ),
    );
  }
}

class _HeadcountCell extends StatefulWidget {
  const _HeadcountCell({
    required this.headcount,
    required this.onChanged,
  });

  final int headcount;
  final ValueChanged<int>? onChanged;

  @override
  State<_HeadcountCell> createState() => _HeadcountCellState();
}

class _HeadcountCellState extends State<_HeadcountCell> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.headcount.toString());
  }

  @override
  void didUpdateWidget(covariant _HeadcountCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentText = _controller.text.trim();
    final currentValue = int.tryParse(currentText) ?? 0;
    if (currentValue != widget.headcount) {
      _controller.text = widget.headcount.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCallback = widget.onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _HeadcountStepButton(
            icon: Icons.remove,
            onTap: hasCallback
                ? () {
                    final current =
                        int.tryParse(_controller.text.trim()) ?? 1;
                    final next = current > 1 ? current - 1 : 1;
                    _controller.text = next.toString();
                    widget.onChanged!(next);
                  }
                : null,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 54,
            child: TextFormField(
              controller: _controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 8),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: Color(0xFF111827), width: 1.4),
                ),
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed == null) return;
                if (parsed < 1) return;
                widget.onChanged?.call(parsed);
              },
            ),
          ),
          const SizedBox(width: 6),
          _HeadcountStepButton(
            icon: Icons.add,
            onTap: hasCallback
                ? () {
                    final current =
                        int.tryParse(_controller.text.trim()) ?? 1;
                    final next = current + 1;
                    _controller.text = next.toString();
                    widget.onChanged!(next);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _HeadcountStepButton extends StatelessWidget {
  const _HeadcountStepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFFFEF3C7)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? const Color(0xFFFCD34D)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled
              ? const Color(0xFF92400E)
              : const Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

class _RoleColumnDef {
  const _RoleColumnDef(this.label, this.width);

  final String label;
  final double width;
}

class _PlanningSubsectionConfig {
  _PlanningSubsectionConfig({
    required this.title,
    required this.subtitle,
    required this.noteKey,
    required this.checkpoint,
    required this.activeItemLabel,
    required this.metrics,
    required this.sections,
    this.roles = const [],
    this.showTableView = false,
  });

  final String title;
  final String subtitle;
  final String noteKey;
  final String checkpoint;
  final String activeItemLabel;
  final List<_MetricData> metrics;
  final List<_SectionData> sections;
  final List<RoleDefinition> roles;
  final bool showTableView;
}

class _StaffingPlanTable extends StatelessWidget {
  const _StaffingPlanTable({
    required this.requirements,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleNduAccess,
  });

  final List<StaffingRequirement> requirements;
  final void Function(int index, StaffingRequirement req) onEdit;
  final ValueChanged<int> onDelete;
  /// Flips the per-row NDU Project Access flag (Yes ↔ No).
  final void Function(int index, bool value) onToggleNduAccess;

  @override
  Widget build(BuildContext context) {
    const rowPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 14);
    // ── New column set (Staffing Plan v2) ──
    //   #   Position   Name   Location   Employment   Category
    //   Start Date (Mobilization)   Release Date   NDU Access
    //   Status   Actions
    // "Person" → "Name", "Type" split into Employment + Category,
    // "Est. Cost" repurposed for Start Date, "Load" repurposed for
    // Release Date, "Timeline" removed (Start/Release are now separate),
    // new "NDU Access" column with Yes/No toggle.
    const columns = <_StaffingColumnDef>[
      _StaffingColumnDef('#', 56),
      _StaffingColumnDef('Position', 200),
      _StaffingColumnDef('Name', 180),
      _StaffingColumnDef('Location', 150),
      _StaffingColumnDef('Employment', 120),
      _StaffingColumnDef('Category', 130),
      _StaffingColumnDef('Start Date (Mobilization)', 160),
      _StaffingColumnDef('Release Date', 140),
      _StaffingColumnDef('NDU Project Access', 140),
      _StaffingColumnDef('Status', 140),
      _StaffingColumnDef('Actions', 100),
    ];

    final contentWidth =
        columns.fold<double>(0, (sum, column) => sum + column.width);
    final minTableWidth = contentWidth + 32;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth > minTableWidth
            ? constraints.maxWidth
            : minTableWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                // ── Header row ──
                Container(
                  width: tableWidth,
                  padding: rowPadding,
                  color: const Color(0xFFF9FAFB),
                  child: Row(
                    children: columns
                        .map(
                          (column) => SizedBox(
                            width: column.width,
                            child: Text(
                              column.label.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                // ── Data rows ──
                if (requirements.isEmpty)
                  Container(
                    width: tableWidth,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 36),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'No staffing positions yet. Click "+ Add Position" '
                        'or "AI Suggest NDU Access" to begin.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: requirements.length,
                    itemBuilder: (context, i) => Container(
                      width: tableWidth,
                      padding: rowPadding,
                      decoration: BoxDecoration(
                        color:
                            i.isEven ? Colors.white : const Color(0xFFF9FAFB),
                        border: Border(
                          top: BorderSide(
                            color: const Color(0xFFE5E7EB),
                            width: i == 0 ? 1 : 0.5,
                          ),
                        ),
                      ),
                      child: _StaffingTableRow(
                        index: i,
                        requirement: requirements[i],
                        columns: columns,
                        onEdit: () => onEdit(i, requirements[i]),
                        onDelete: () => onDelete(i),
                        onToggleNduAccess: (value) =>
                            onToggleNduAccess(i, value),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StaffingTableRow extends StatelessWidget {
  const _StaffingTableRow({
    required this.index,
    required this.requirement,
    required this.columns,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleNduAccess,
  });

  final int index;
  final StaffingRequirement requirement;
  final List<_StaffingColumnDef> columns;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleNduAccess;

  @override
  Widget build(BuildContext context) {
    final employmentLabel = requirement.employmentType == 'PT'
        ? 'Part Time'
        : (requirement.employmentType == 'FT' ? 'Full Time' : '—');
    final categoryLabel =
        requirement.employeeType.trim().isEmpty ? '—' : requirement.employeeType;
    final startLabel = requirement.startDate.trim().isEmpty
        ? 'TBD'
        : requirement.startDate;
    final releaseLabel = requirement.endDate.trim().isEmpty
        ? 'TBD'
        : requirement.endDate;

    final cells = <Widget>[
      // #
      Center(
        child: Text(
          '${index + 1}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4B5563),
          ),
        ),
      ),
      // Position
      _StaffingTextCell(
        requirement.title.trim().isEmpty
            ? 'Untitled Position'
            : requirement.title,
        fontWeight: FontWeight.w700,
        textAlign: TextAlign.center,
      ),
      // Name (was "Person")
      _StaffingTextCell(
        requirement.personName.trim().isEmpty ? 'TBD' : requirement.personName,
        textAlign: TextAlign.center,
      ),
      // Location
      _StaffingTextCell(
        requirement.location.trim().isEmpty ? 'TBD' : requirement.location,
        textAlign: TextAlign.center,
      ),
      // Employment (Full Time / Part Time) — split from Type
      _StaffingTextCell(employmentLabel, textAlign: TextAlign.center),
      // Category (Employee / Contractor) — split from Type
      _StaffingTextCell(categoryLabel, textAlign: TextAlign.center),
      // Start Date (Mobilization) — repurposed from "Est. Cost"
      _StaffingTextCell(startLabel, textAlign: TextAlign.center),
      // Release Date — repurposed from "Load"
      _StaffingTextCell(releaseLabel, textAlign: TextAlign.center),
      // NDU Project Access (Yes / No)
      Center(
        child: _NduAccessToggle(
          value: requirement.nduProjectAccess,
          onChanged: onToggleNduAccess,
        ),
      ),
      // Status
      Center(
        child: _StaffingStatusPill(
          label:
              requirement.status.trim().isEmpty ? 'Open' : requirement.status,
        ),
      ),
      // Actions
      Align(
        alignment: Alignment.topCenter,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: Color(0xFF6B7280),
              ),
              tooltip: 'Edit position',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Color(0xFFEF4444),
              ),
              tooltip: 'Delete position',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(
        cells.length,
        (cellIndex) =>
            SizedBox(width: columns[cellIndex].width, child: cells[cellIndex]),
      ),
    );
  }
}

/// Compact Yes/No pill toggle for the NDU Project Access column.
/// Tap to flip. Yes → green, No → grey.
class _NduAccessToggle extends StatelessWidget {
  const _NduAccessToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final yes = value;
    final bgColor =
        yes ? const Color(0xFFD1FAE5) : const Color(0xFFF3F4F6);
    final fgColor =
        yes ? const Color(0xFF059669) : const Color(0xFF6B7280);
    return InkWell(
      onTap: () => onChanged(!yes),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: yes ? const Color(0xFFA7F3D0) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              yes ? Icons.check_circle : Icons.cancel,
              size: 14,
              color: fgColor,
            ),
            const SizedBox(width: 6),
            Text(
              yes ? 'Yes' : 'No',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffingTextCell extends StatelessWidget {
  const _StaffingTextCell(
    this.text, {
    this.fontWeight = FontWeight.w500,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final FontWeight fontWeight;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        text,
        textAlign: textAlign,
        softWrap: true,
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          fontWeight: fontWeight,
          color: const Color(0xFF111827),
        ),
      ),
    );
  }
}

class _StaffingStatusPill extends StatelessWidget {
  const _StaffingStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.trim().toLowerCase();
    final bool hired = normalized == 'hired';
    final bool active =
        normalized == 'active' || normalized == 'mobilized' || hired;
    final bgColor =
        hired || active ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7);
    final fgColor =
        hired || active ? const Color(0xFF059669) : const Color(0xFFD97706);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        softWrap: true,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fgColor,
        ),
      ),
    );
  }
}

class _StaffingColumnDef {
  const _StaffingColumnDef(this.label, this.width);

  final String label;
  final double width;
}

/// ─────────────────────────────────────────────────────────────────────────
/// Tab 1 — Staffing Plan table content with action bar
/// ─────────────────────────────────────────────────────────────────────────
/// Wraps the existing [_StaffingPlanTable] with an action row containing
/// "Add Position" and "AI Suggest Dates" buttons, plus a pop-out "Expand"
/// affordance that opens the table in a full-screen dialog for easier
/// viewing on small viewports.
class _StaffingPlanTabContent extends StatelessWidget {
  const _StaffingPlanTabContent({
    required this.requirements,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleNduAccess,
    required this.onAddPosition,
    required this.onAiSuggestDates,
  });

  final List<StaffingRequirement> requirements;
  final void Function(int index, StaffingRequirement req) onEdit;
  final ValueChanged<int> onDelete;
  final void Function(int index, bool value) onToggleNduAccess;
  final VoidCallback onAddPosition;
  final VoidCallback onAiSuggestDates;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: onAddPosition,
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: const Text('Add Position'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFC812),
                  side: const BorderSide(color: Color(0xFFFDE68A)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: onAiSuggestDates,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('AI Suggest Dates'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB8860B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showExpandedView(context),
                icon: const Icon(Icons.fullscreen, size: 16),
                label: const Text('Expand'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Table wrapped in a vertical scroll so the tab can grow tall
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: _StaffingPlanTable(
                  requirements: requirements,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  onToggleNduAccess: onToggleNduAccess,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExpandedView(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.table_chart_outlined,
                      size: 20, color: Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  const Text(
                    'Staffing Plan — Expanded View',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: _StaffingPlanTable(
                      requirements: requirements,
                      onEdit: onEdit,
                      onDelete: onDelete,
                      onToggleNduAccess: onToggleNduAccess,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Holds the AI-suggested start/stop dates for a single staffing row.
class _DateSuggestion {
  const _DateSuggestion({
    required this.position,
    required this.personName,
    required this.matchedMilestone,
    required this.suggestedStart,
    required this.suggestedEnd,
    required this.existingStart,
    required this.existingEnd,
  });

  final String position;
  final String personName;
  final String? matchedMilestone;
  final DateTime suggestedStart;
  final DateTime suggestedEnd;
  final String existingStart;
  final String existingEnd;
}

/// Dialog showing AI-suggested start/stop dates for each staffing row,
/// letting the user accept selectively.
class _AiSuggestDatesDialog extends StatefulWidget {
  const _AiSuggestDatesDialog({
    required this.projectScope,
    required this.milestoneCount,
    required this.projectStart,
    required this.projectEnd,
    required this.suggestions,
  });

  final String projectScope;
  final int milestoneCount;
  final DateTime projectStart;
  final DateTime projectEnd;
  final Map<int, _DateSuggestion> suggestions;

  @override
  State<_AiSuggestDatesDialog> createState() => _AiSuggestDatesDialogState();
}

class _AiSuggestDatesDialogState extends State<_AiSuggestDatesDialog> {
  late final Set<int> _accepted;

  @override
  void initState() {
    super.initState();
    _accepted = widget.suggestions.keys.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd');
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF8E1),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Color(0xFFB8860B), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Suggested Start & Release Dates',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Based on ${widget.milestoneCount} project milestone(s) '
                          'and overall scope (${fmt.format(widget.projectStart)} → '
                          '${fmt.format(widget.projectEnd)}).',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Scope summary
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Project scope: ${widget.projectScope}',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF6B7280), height: 1.4),
              ),
            ),
            // List
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                trackVisibility: true,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  children: widget.suggestions.entries.map((entry) {
                    final idx = entry.key;
                    final s = entry.value;
                    final isAccepted = _accepted.contains(idx);
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isAccepted
                            ? const Color(0xFFFFF8E1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isAccepted
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: isAccepted,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _accepted.add(idx);
                                } else {
                                  _accepted.remove(idx);
                                }
                              });
                            },
                            activeColor: const Color(0xFFB8860B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.position,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827)),
                                ),
                                if (s.personName.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      s.personName,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF6B7280)),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    _DateChip(
                                      label: 'Start',
                                      value: fmt.format(s.suggestedStart),
                                      color: const Color(0xFF10B981),
                                    ),
                                    _DateChip(
                                      label: 'Release',
                                      value: fmt.format(s.suggestedEnd),
                                      color: const Color(0xFFEF4444),
                                    ),
                                    if (s.matchedMilestone != null)
                                      _DateChip(
                                        label: 'Milestone',
                                        value: s.matchedMilestone!,
                                        color: const Color(0xFFB8860B),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_accepted.length} of ${widget.suggestions.length} selected',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _accepted.isEmpty
                            ? null
                            : () => Navigator.pop(context, _accepted),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB8860B),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Apply Selected'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.9)),
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Tab 2 — Staffing Timeline (Gantt chart view)
/// ─────────────────────────────────────────────────────────────────────────
/// Renders each staffing position as a horizontal bar across a weekly /
/// monthly time axis. Bars are computed from `startDate` and `endDate`
/// on the [StaffingRequirement]. Positions without dates show a placeholder
/// "TBD" pill instead of a bar.
class _StaffingTimelineTab extends StatelessWidget {
  const _StaffingTimelineTab({
    required this.requirements,
    required this.onEdit,
  });

  final List<StaffingRequirement> requirements;
  final void Function(int index, StaffingRequirement req) onEdit;

  @override
  Widget build(BuildContext context) {
    if (requirements.isEmpty) {
      return const _EmptyTimelineState();
    }

    // Parse all valid dates and compute the timeline window.
    final parsed = <_ParsedRow>[];
    for (var i = 0; i < requirements.length; i++) {
      final r = requirements[i];
      final start = DateTime.tryParse(r.startDate);
      final end = DateTime.tryParse(r.endDate);
      parsed.add(_ParsedRow(index: i, requirement: r, start: start, end: end));
    }

    final validBars = parsed.where((p) => p.start != null && p.end != null).toList();
    if (validBars.isEmpty) {
      return const _EmptyTimelineState(
        message: 'No staffing positions have start and release dates yet. '
            'Use "AI Suggest Dates" on the Staffing Plan tab to populate them.',
      );
    }

    // Compute the global time window (with a small padding on each side).
    var windowStart = validBars
        .map((p) => p.start!)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    var windowEnd = validBars
        .map((p) => p.end!)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    // Pad the window by a few days on each side for visual breathing room.
    windowStart = windowStart.subtract(const Duration(days: 7));
    windowEnd = windowEnd.add(const Duration(days: 7));
    final totalDays = windowEnd.difference(windowStart).inDays;
    if (totalDays <= 0) {
      return const _EmptyTimelineState(
        message: 'Timeline window is too narrow to render. Check the start and release dates.',
      );
    }

    // Build the list of month markers across the window.
    final monthMarkers = <_MonthMarker>[];
    var cur = DateTime(windowStart.year, windowStart.month, 1);
    while (cur.isBefore(windowEnd)) {
      final nextMonth = DateTime(cur.year, cur.month + 1, 1);
      final startOffset = cur.difference(windowStart).inDays.toDouble();
      final endOffset = nextMonth.difference(windowStart).inDays.toDouble();
      monthMarkers.add(_MonthMarker(
        label: DateFormat('MMM yy').format(cur),
        startOffset: startOffset.clamp(0, totalDays.toDouble()),
        endOffset: endOffset.clamp(0, totalDays.toDouble()),
      ));
      cur = nextMonth;
    }

    // Build the list of weekly tick marks.
    final weekMarkers = <double>[];
    var weekCursor = windowStart;
    while (weekCursor.isBefore(windowEnd)) {
      final offset = weekCursor.difference(windowStart).inDays.toDouble();
      if (offset >= 0 && offset <= totalDays) {
        weekMarkers.add(offset);
      }
      weekCursor = weekCursor.add(const Duration(days: 7));
    }

    const double leftColumnWidth = 220;
    const double rowHeight = 44;
    const double headerHeight = 52;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showExpandedTimeline(context),
                icon: const Icon(Icons.fullscreen, size: 16),
                label: const Text('Expand'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    width: leftColumnWidth + (totalDays * 6.0) + 40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row: empty left corner + month labels
                        SizedBox(
                          height: headerHeight,
                          child: Row(
                            children: [
                              const SizedBox(
                                width: leftColumnWidth,
                                child: Padding(
                                  padding: EdgeInsets.only(left: 12),
                                  child: Text(
                                    'POSITION',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: Color(0xFF6B7280)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: _TimelineHeaderPainter(
                                    monthMarkers: monthMarkers,
                                    weekMarkers: weekMarkers,
                                    totalDays: totalDays.toDouble(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Body rows
                        ...parsed.map((p) => _TimelineRow(
                              parsed: p,
                              windowStart: windowStart,
                              totalDays: totalDays.toDouble(),
                              leftColumnWidth: leftColumnWidth,
                              rowHeight: rowHeight,
                              weekMarkers: weekMarkers,
                              onEdit: () => onEdit(p.index, p.requirement),
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExpandedTimeline(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.timeline_outlined,
                      size: 20, color: Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  const Text(
                    'Staffing Timeline — Expanded View',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              Expanded(
                child: _StaffingTimelineTab(
                  requirements: requirements,
                  onEdit: onEdit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParsedRow {
  const _ParsedRow({
    required this.index,
    required this.requirement,
    required this.start,
    required this.end,
  });

  final int index;
  final StaffingRequirement requirement;
  final DateTime? start;
  final DateTime? end;

  bool get hasDates => start != null && end != null;
}

class _MonthMarker {
  const _MonthMarker({
    required this.label,
    required this.startOffset,
    required this.endOffset,
  });

  final String label;
  final double startOffset;
  final double endOffset;
}

class _EmptyTimelineState extends StatelessWidget {
  const _EmptyTimelineState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timeline_outlined,
                size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              message ??
                  'No staffing positions yet. Add positions on the Staffing '
                      'Plan tab to see them on the timeline.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineHeaderPainter extends CustomPainter {
  const _TimelineHeaderPainter({
    required this.monthMarkers,
    required this.weekMarkers,
    required this.totalDays,
  });

  final List<_MonthMarker> monthMarkers;
  final List<double> weekMarkers;
  final double totalDays;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background
    final bgPaint = Paint()..color = const Color(0xFFF9FAFB);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Week ticks (light vertical lines)
    final weekPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 0.5;
    for (final offset in weekMarkers) {
      final x = (offset / totalDays) * w;
      canvas.drawLine(Offset(x, 0), Offset(x, h), weekPaint);
    }

    // Month markers + labels
    final monthDividerPaint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 1;
    for (final m in monthMarkers) {
      final startX = (m.startOffset / totalDays) * w;
      final endX = (m.endOffset / totalDays) * w;
      canvas.drawLine(Offset(startX, 0), Offset(startX, h), monthDividerPaint);
      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: m.label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B5563)),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout();
      final labelX = (startX + endX) / 2 - tp.width / 2;
      tp.paint(canvas, Offset(labelX.clamp(2, w - tp.width - 2), 6));
    }

    // Bottom border
    final borderPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, h - 0.5), Offset(w, h - 0.5), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _TimelineHeaderPainter old) {
    return old.totalDays != totalDays || old.monthMarkers != monthMarkers;
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.parsed,
    required this.windowStart,
    required this.totalDays,
    required this.leftColumnWidth,
    required this.rowHeight,
    required this.weekMarkers,
    required this.onEdit,
  });

  final _ParsedRow parsed;
  final DateTime windowStart;
  final double totalDays;
  final double leftColumnWidth;
  final double rowHeight;
  final List<double> weekMarkers;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd');
    final title = parsed.requirement.title.trim().isEmpty
        ? 'Untitled Position'
        : parsed.requirement.title;
    final person = parsed.requirement.personName.trim().isEmpty
        ? 'TBD'
        : parsed.requirement.personName;

    return InkWell(
      onTap: onEdit,
      child: Container(
        height: rowHeight,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF3F4F6), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Left: position label
            SizedBox(
              width: leftColumnWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827)),
                    ),
                    Text(
                      person,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ),
            // Right: bar area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  if (!parsed.hasDates) {
                    return Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: const Text(
                          'TBD — set dates',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF92400E)),
                        ),
                      ),
                    );
                  }
                  final startOffset =
                      parsed.start!.difference(windowStart).inDays.toDouble();
                  final endOffset =
                      parsed.end!.difference(windowStart).inDays.toDouble();
                  final barStart =
                      (startOffset / totalDays * w).clamp(0.0, w);
                  final barEnd =
                      (endOffset / totalDays * w).clamp(0.0, w);
                  final barWidth = (barEnd - barStart).clamp(8.0, w);

                  // Bar color shifts based on role.
                  final title = parsed.requirement.title.toLowerCase();
                  Color barColor = const Color(0xFFFFC812);
                  if (title.contains('manager') || title.contains('lead')) {
                    barColor = const Color(0xFFB8860B);
                  } else if (title.contains('developer') ||
                      title.contains('tech') ||
                      title.contains('engineer') ||
                      title.contains('architect')) {
                    barColor = const Color(0xFF10B981);
                  } else if (title.contains('quality') ||
                      title.contains('test')) {
                    barColor = const Color(0xFFF59E0B);
                  } else if (title.contains('contract') ||
                      title.contains('procurement')) {
                    barColor = const Color(0xFFD97706);
                  } else if (title.contains('ssher') ||
                      title.contains('safety')) {
                    barColor = const Color(0xFFEF4444);
                  }

                  return Stack(
                    children: [
                      // Background week ticks
                      ...weekMarkers.map((offset) {
                        final x = (offset / totalDays) * w;
                        return Positioned(
                          left: x,
                          top: 0,
                          bottom: 0,
                          child: Container(
                              width: 0.5, color: const Color(0xFFF3F4F6)),
                        );
                      }),
                      // The bar
                      Positioned(
                        left: barStart,
                        top: 8,
                        bottom: 8,
                        width: barWidth,
                        child: Tooltip(
                          message:
                              '$title\n${fmt.format(parsed.start!)} → ${fmt.format(parsed.end!)}',
                          child: Container(
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: barColor.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            alignment: Alignment.center,
                            child: Text(
                              '${fmt.format(parsed.start!)} → ${fmt.format(parsed.end!)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Tab 3 — Estimated Cost (restricted)
/// ─────────────────────────────────────────────────────────────────────────
/// Mirrors the access policy of the Personnel Rates tab in the R&R section:
/// locked for Basic Plan projects and for users without elevated access.
/// When locked, shows a lock placeholder with upgrade guidance. When
/// unlocked, shows the per-position cost table with monthly and total
/// estimated costs.
class _EstimatedCostTab extends StatefulWidget {
  const _EstimatedCostTab({
    required this.requirements,
    required this.projectData,
    required this.onEdit,
  });

  final List<StaffingRequirement> requirements;
  final ProjectDataModel projectData;
  final void Function(int index, StaffingRequirement req) onEdit;

  @override
  State<_EstimatedCostTab> createState() => _EstimatedCostTabState();
}

class _EstimatedCostTabState extends State<_EstimatedCostTab> {
  bool _unlocked = false;

  /// Determine whether the current user/project context permits access
  /// to the Estimated Cost tab. Mirrors the Personnel Rates lock:
  ///   1. Basic Plan projects → locked
  ///   2. Otherwise → user must explicitly unlock (simulate the same
  ///      "Admin / Premium" gating the Personnel Rates dialog uses)
  bool get _isLockedByPlan {
    try {
      return widget.projectData.isBasicPlanProject;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _isLockedByPlan && !_unlocked;
    if (locked) {
      return _LockedCostPlaceholder(
        isBasicPlan: _isLockedByPlan,
        onUnlockRequested: () {
          // For non-Basic-Plan projects the user can self-unlock the tab.
          // Basic Plan projects must upgrade their plan first.
          if (_isLockedByPlan) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Estimated Cost is a premium feature. Upgrade from '
                    'Basic Plan to access per-personnel cost details.'),
                backgroundColor: Color(0xFFF59E0B),
                duration: Duration(seconds: 4),
              ),
            );
          } else {
            setState(() => _unlocked = true);
          }
        },
      );
    }

    return _EstimatedCostTable(
      requirements: widget.requirements,
      onEdit: widget.onEdit,
    );
  }
}

class _LockedCostPlaceholder extends StatelessWidget {
  const _LockedCostPlaceholder({
    required this.isBasicPlan,
    required this.onUnlockRequested,
  });

  final bool isBasicPlan;
  final VoidCallback onUnlockRequested;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.lock_outline,
                  color: Color(0xFFF59E0B), size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Estimated Cost is Restricted',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827)),
            ),
            const SizedBox(height: 8),
            Text(
              isBasicPlan
                  ? 'This tab mirrors the Personnel Rates access policy in the '
                      'R&R section. Upgrade from Basic Plan to view per-personnel '
                      'cost details, monthly rates, and projected totals.'
                  : 'This tab mirrors the Personnel Rates access policy in the '
                      'R&R section. Confirm access to view per-personnel cost '
                      'details, monthly rates, and projected totals.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280), height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onUnlockRequested,
              icon: const Icon(Icons.lock_open_outlined, size: 16),
              label: Text(isBasicPlan ? 'Upgrade Plan' : 'Unlock Access'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimatedCostTable extends StatelessWidget {
  const _EstimatedCostTable({
    required this.requirements,
    required this.onEdit,
  });

  final List<StaffingRequirement> requirements;
  final void Function(int index, StaffingRequirement req) onEdit;

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    const columns = <_StaffingColumnDef>[
      _StaffingColumnDef('#', 48),
      _StaffingColumnDef('Position', 180),
      _StaffingColumnDef('Name', 150),
      _StaffingColumnDef('Category', 110),
      _StaffingColumnDef('Employment', 110),
      _StaffingColumnDef('Headcount', 90),
      _StaffingColumnDef('Monthly Rate', 120),
      _StaffingColumnDef('Planned Months', 110),
      _StaffingColumnDef('Estimated Total', 140),
      _StaffingColumnDef('Actions', 80),
    ];
    final contentWidth =
        columns.fold<double>(0, (sum, c) => sum + c.width) + 32;

    final totalHeadcount = requirements.fold<int>(
        0, (sum, r) => sum + (r.headcount > 0 ? r.headcount : 1));
    final grandTotal = requirements.fold<double>(
        0, (sum, r) => sum + r.estimatedTotal);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showExpanded(context),
                icon: const Icon(Icons.fullscreen, size: 16),
                label: const Text('Expand'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.summarize,
                        size: 14, color: Color(0xFF047857)),
                    const SizedBox(width: 6),
                    Text(
                      'Grand Total: ${currencyFmt.format(grandTotal)} '
                      '($totalHeadcount personnel)',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          color: const Color(0xFFF9FAFB),
                          child: Row(
                            children: columns
                                .map((c) => SizedBox(
                                      width: c.width,
                                      child: Text(
                                        c.label.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                            color: Color(0xFF6B7280)),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                        if (requirements.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 36),
                            child: const Center(
                              child: Text(
                                'No staffing positions yet. Add positions on the '
                                    'Staffing Plan tab to see cost estimates.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                    fontStyle: FontStyle.italic),
                              ),
                            ),
                          )
                        else
                          ...requirements.asMap().entries.map((entry) {
                            final i = entry.key;
                            final r = entry.value;
                            final monthly = r.monthlyCost;
                            final total = r.estimatedTotal;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: i.isEven
                                    ? Colors.white
                                    : const Color(0xFFF9FAFB),
                                border: const Border(
                                  top: BorderSide(
                                      color: Color(0xFFE5E7EB), width: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                      width: columns[0].width,
                                      child: Center(
                                          child: Text('${i + 1}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF4B5563))))),
                                  SizedBox(
                                      width: columns[1].width,
                                      child: Text(
                                          r.title.isEmpty
                                              ? 'Untitled Position'
                                              : r.title,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF111827)))),
                                  SizedBox(
                                      width: columns[2].width,
                                      child: Text(
                                          r.personName.isEmpty
                                              ? 'TBD'
                                              : r.personName,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF374151)))),
                                  SizedBox(
                                      width: columns[3].width,
                                      child: Text(
                                          r.employeeType.isEmpty
                                              ? '—'
                                              : r.employeeType,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF374151)))),
                                  SizedBox(
                                      width: columns[4].width,
                                      child: Text(
                                          r.employmentType == 'PT'
                                              ? 'Part Time'
                                              : 'Full Time',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF374151)))),
                                  SizedBox(
                                      width: columns[5].width,
                                      child: Center(
                                          child: Text('${r.headcount}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF374151))))),
                                  SizedBox(
                                      width: columns[6].width,
                                      child: Text(
                                          currencyFmt.format(monthly),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF111827)))),
                                  SizedBox(
                                      width: columns[7].width,
                                      child: Text(
                                          r.plannedMonths.toStringAsFixed(1),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF374151)))),
                                  SizedBox(
                                      width: columns[8].width,
                                      child: Text(
                                          currencyFmt.format(total),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF047857)))),
                                  SizedBox(
                                    width: columns[9].width,
                                    child: Center(
                                      child: IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 16,
                                            color: Color(0xFF6B7280)),
                                        onPressed: () => onEdit(i, r),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        // Totals row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: const BoxDecoration(
                            color: Color(0xFFECFDF5),
                            border: Border(
                              top: BorderSide(
                                  color: Color(0xFFA7F3D0), width: 1.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: columns[0].width +
                                      columns[1].width +
                                      columns[2].width +
                                      columns[3].width +
                                      columns[4].width,
                                  child: const Text('GRAND TOTAL',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF047857)))),
                              SizedBox(
                                  width: columns[5].width,
                                  child: Text('$totalHeadcount',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF047857)))),
                              SizedBox(width: columns[6].width),
                              SizedBox(width: columns[7].width),
                              SizedBox(
                                  width: columns[8].width,
                                  child: Text(currencyFmt.format(grandTotal),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF047857)))),
                              SizedBox(width: columns[9].width),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExpanded(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.payments_outlined,
                      size: 20, color: Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  const Text(
                    'Estimated Cost — Expanded View',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              Expanded(
                child: _EstimatedCostTable(
                  requirements: requirements,
                  onEdit: onEdit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader(
      {required this.title,
      required this.onBack,
      this.onNext,
      this.onAdd,
      this.onAddPredefined});

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final VoidCallback? onAdd;
  final VoidCallback? onAddPredefined;

  @override
  Widget build(BuildContext context) {
    // Per Tasks 10 + 11: strip the R&R header down to ONLY the "+ Add Role"
    // button. Navigation arrows, page title, "Standard Roles" button, and
    // user profile chip were all removed to declutter the header.
    return Row(
      children: [
        if (onAdd != null)
          _yellowButton(
            label: 'Add Role',
            icon: Icons.add,
            onPressed: onAdd!,
          ),
      ],
    );
  }

  Widget _yellowButton(
      {required String label,
      required IconData icon,
      required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: const Color(0xFF1F2933),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon}) : onTap = null;

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email ?? 'User';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage:
                user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            child: user?.photoURL == null
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151)),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          RepaintBoundary(
            child: StreamBuilder<bool>(
              stream: UserService.watchAdminStatus(),
              builder: (context, snapshot) {
                final email = user?.email ?? '';
                final isAdmin =
                    snapshot.data ?? UserService.isAdminEmail(email);
                final role = isAdmin ? 'Admin' : 'Member';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(displayName,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(role,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF6B7280))),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down,
              size: 18, color: Color(0xFF9CA3AF)),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: metrics
          .map((metric) => _MetricCard(
              label: metric.label, value: metric.value, accent: metric.color))
          .toList(),
    );
  }
}

class _MetricData {
  _MetricData(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.label, required this.value, required this.accent});

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: accent),
          ),
        ],
      ),
    );
  }
}

class _SectionData {
  _SectionData({
    required this.title,
    required this.subtitle,
    this.bullets = const [],
    // ignore: unused_element_parameter
    this.statusRows = const [],
    this.headcount = 0,
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final List<_BulletData> bullets;
  final List<_StatusRowData> statusRows;
  final int headcount;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
}

class _BulletData {
  _BulletData(this.text, this.isCheck);

  final String text;
  final bool isCheck;
}

class _StatusRowData {
  _StatusRowData(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.data});

  final _SectionData data;

  @override
  Widget build(BuildContext context) {
    final showBullets = data.bullets.isNotEmpty;
    final showStatus = data.statusRows.isNotEmpty;
    final showHeadcount = data.headcount > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(data.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
              ),
              if (showHeadcount)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.groups_2,
                          size: 13, color: Color(0xFF92400E)),
                      const SizedBox(width: 4),
                      Text(
                        '${data.headcount} ${data.headcount == 1 ? 'person' : 'people'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              if (data.onEdit != null || data.onDelete != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data.onEdit != null)
                      IconButton(
                        onPressed: data.onEdit,
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: Color(0xFF6B7280)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    if (data.onDelete != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: data.onDelete,
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: Color(0xFFEF4444)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(data.subtitle,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280), height: 1.4)),
          const SizedBox(height: 16),
          if (showBullets)
            ...data.bullets.map((bullet) => _BulletRow(data: bullet)),
          if (showStatus)
            ...data.statusRows.map((row) => _StatusRow(data: row)),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.data});

  final _BulletData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            data.isCheck ? Icons.check_circle_outline : Icons.circle,
            size: data.isCheck ? 16 : 8,
            color: data.isCheck
                ? const Color(0xFF10B981)
                : const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              data.text,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF374151), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.data});

  final _StatusRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              data.label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              data.value,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: data.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState(
      {required this.title, required this.message, required this.icon});

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
                const SizedBox(height: 6),
                Text(message,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Entry in the role bank — maps a role title to a description and workstream.
class _RoleBankEntry {
  final String description;
  final String workstream;

  const _RoleBankEntry({
    required this.description,
    required this.workstream,
  });
}

/// A single row in the Standard Roles picker dialog.
/// Shows a checkbox + role name on the left, and a headcount stepper on the right
/// that is enabled only when the checkbox is ticked.
class _PredefinedRoleRow extends StatelessWidget {
  const _PredefinedRoleRow({
    required this.title,
    required this.workstream,
    required this.isSelected,
    required this.enabled,
    required this.headcount,
    required this.onToggle,
    required this.onHeadcountChanged,
  });

  final String title;
  final String workstream;
  final bool isSelected;
  final bool enabled;
  final int headcount;
  final ValueChanged<bool?>? onToggle;
  final ValueChanged<int>? onHeadcountChanged;

  @override
  Widget build(BuildContext context) {
    final alreadyAdded = !enabled && isSelected;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFCD34D)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: onToggle,
            activeColor: const Color(0xFFF59E0B),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: alreadyAdded
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alreadyAdded ? 'Already added' : workstream,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CompactHeadcountStepper(
            headcount: headcount,
            enabled: isSelected && enabled,
            onChanged: onHeadcountChanged,
          ),
        ],
      ),
    );
  }
}

/// Compact headcount stepper used inside the Standard Roles dialog rows.
class _CompactHeadcountStepper extends StatelessWidget {
  const _CompactHeadcountStepper({
    required this.headcount,
    required this.enabled,
    required this.onChanged,
  });

  final int headcount;
  final bool enabled;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepButton(
          icon: Icons.remove,
          onTap: enabled
              ? () {
                  final next = headcount > 1 ? headcount - 1 : 1;
                  onChanged?.call(next);
                }
              : null,
        ),
        const SizedBox(width: 4),
        Container(
          width: 44,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled
                  ? const Color(0xFFE5E7EB)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            '$headcount',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: enabled
                  ? const Color(0xFF111827)
                  : const Color(0xFF9CA3AF),
            ),
          ),
        ),
        const SizedBox(width: 4),
        _stepButton(
          icon: Icons.add,
          onTap: enabled
              ? () {
                  final next = headcount + 1;
                  onChanged?.call(next);
                }
              : null,
        ),
      ],
    );
  }

  Widget _stepButton({required IconData icon, required VoidCallback? onTap}) {
    final active = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFFEF3C7)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? const Color(0xFFFCD34D)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: active
              ? const Color(0xFF92400E)
              : const Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

/// Headcount stepper used inside the Add/Edit Role dialogs (larger variant).
class _DialogHeadcountStepper extends StatefulWidget {
  const _DialogHeadcountStepper({
    required this.headcount,
    required this.onChanged,
  });

  final int headcount;
  final ValueChanged<int> onChanged;

  @override
  State<_DialogHeadcountStepper> createState() =>
      _DialogHeadcountStepperState();
}

class _DialogHeadcountStepperState extends State<_DialogHeadcountStepper> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.headcount}');
  }

  @override
  void didUpdateWidget(covariant _DialogHeadcountStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = int.tryParse(_controller.text.trim()) ?? 1;
    if (current != widget.headcount) {
      _controller.text = '${widget.headcount}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              final current =
                  int.tryParse(_controller.text.trim()) ?? 1;
              final next = current > 1 ? current - 1 : 1;
              _controller.text = '$next';
              widget.onChanged(next);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFCD34D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.remove,
                size: 18,
                color: Color(0xFF1F2933),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed == null || parsed < 1) return;
                widget.onChanged(parsed);
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.headcount == 1 ? 'person' : 'people',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () {
              final current =
                  int.tryParse(_controller.text.trim()) ?? 1;
              final next = current + 1;
              _controller.text = '$next';
              widget.onChanged(next);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFCD34D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add,
                size: 18,
                color: Color(0xFF1F2933),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
