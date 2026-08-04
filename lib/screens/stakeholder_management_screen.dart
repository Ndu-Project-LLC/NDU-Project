import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/models/project_data_model.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

class StakeholderManagementScreen extends StatefulWidget {
  const StakeholderManagementScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StakeholderManagementScreen()),
    );
  }

  @override
  State<StakeholderManagementScreen> createState() =>
      _StakeholderManagementScreenState();
}

class _StakeholderManagementScreenState
    extends State<StakeholderManagementScreen> {
  int _activeTabIndex = 1; // 0 = Stakeholders, 1 = Engagement Plans

  final _stakeholderSaveDebounce = _Debouncer();
  final _planSaveDebounce = _Debouncer();
  final ScrollController _pageScrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Data is managed by ProjectDataHelper and Provider
  }

  @override
  void dispose() {
    _stakeholderSaveDebounce.dispose();
    _planSaveDebounce.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double horizontalPadding = isMobile ? 20 : 36;
    final projectData = ProjectDataHelper.getDataListening(context);

    // Filter stakeholders and plans based on search
    final filteredStakeholders = projectData.stakeholderEntries.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.organization.toLowerCase().contains(q) ||
          s.role.toLowerCase().contains(q);
    }).toList();

    final filteredPlans = projectData.engagementPlanEntries.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.stakeholder.toLowerCase().contains(q) ||
          p.objective.toLowerCase().contains(q);
    }).toList();

    final sidebarWidth = AppBreakpoints.sidebarWidth(context);

    final header = PlanningPhaseHeader(
        title: 'Stakeholder Management',
        breadcrumbPhase: 'Planning Phase',
        breadcrumbTitle: 'Stakeholder Management',
        onBack: () => PlanningPhaseNavigation.goToPrevious(
            context, 'stakeholder_management'),
        onForward: () =>
            PlanningPhaseNavigation.goToNext(context, 'stakeholder_management'),
        onExportPdf: _exportPdf);

    final scrollableContent = SingleChildScrollView(
      controller: _pageScrollController,
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TitleSection(
              showButtonsBelow: isMobile,
              onExport: () {},
              onAddProject: () {},
              onAutoPopulate: _autoPopulateFromInitiation,
            ),
            const SizedBox(height: 24),
            const PlanningAiNotesCard(
              title: 'Stakeholder Notes',
              sectionLabel: 'Stakeholder Management',
              noteKey: 'planning_stakeholder_notes',
              checkpoint: 'stakeholder_management',
              description:
                  'Capture overall stakeholder strategy, risks, and communication protocols.',
            ),
            const SizedBox(height: 32),
            _StatsRow(
              totalStakeholders: projectData.stakeholderEntries.length,
              externalCount: projectData.stakeholderEntries
                  .where((s) => s.organization.toLowerCase() != 'internal')
                  .length,
            ),
            const SizedBox(height: 32),
            _InfluenceInterestMatrix(
                stakeholders: projectData.stakeholderEntries),
            const SizedBox(height: 32),
            _EngagementSection(
              activeTabIndex: _activeTabIndex,
              onTabChanged: (idx) => setState(() => _activeTabIndex = idx),
              stakeholderTable: FullScreenTableWrapper(
                title: 'Stakeholders',
                child: _StakeholdersTable(
                  entries: filteredStakeholders,
                  isLoading: false,
                  onChanged: _updateStakeholder,
                  onDelete: _deleteStakeholder,
                ),
                tableBuilder: (fsContext) => _StakeholdersTable(
                  entries: filteredStakeholders,
                  isLoading: false,
                  onChanged: _updateStakeholder,
                  onDelete: _deleteStakeholder,
                ),
              ),
              planTable: FullScreenTableWrapper(
                title: 'Engagement Plans',
                child: _EngagementPlansTable(
                  entries: filteredPlans,
                  isLoading: false,
                  onChanged: _updateEngagementPlan,
                  onDelete: _deleteEngagementPlan,
                ),
                tableBuilder: (fsContext) => _EngagementPlansTable(
                  entries: filteredPlans,
                  isLoading: false,
                  onChanged: _updateEngagementPlan,
                  onDelete: _deleteEngagementPlan,
                ),
              ),
              onAdd:
                  _activeTabIndex == 0 ? _addStakeholder : _addEngagementPlan,
              onSearch: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 32),
            // ── Project Team Communication Roster ─────────────────────────
            // Lists every PT member pulled from the staffing plan / team
            // members list. Project Team is treated as a "Manage Closely"
            // stakeholder group: all emails must be captured (especially
            // for positions without site access) so the engagement plan
            // can reach them out-of-band.
            _ProjectTeamRosterSection(
              teamMembers: projectData.teamMembers,
              engagementPlanEntries: projectData.engagementPlanEntries,
              onMemberChanged: _updateTeamMember,
              onSyncToEngagementPlans: _syncTeamToEngagementPlans,
            ),
            const SizedBox(height: 24),
            LaunchPhaseNavigation(
              backLabel:
                  PlanningPhaseNavigation.backLabel('stakeholder_management'),
              nextLabel:
                  PlanningPhaseNavigation.nextLabel('stakeholder_management'),
              onBack: () => PlanningPhaseNavigation.goToPrevious(
                  context, 'stakeholder_management'),
              onNext: () => PlanningPhaseNavigation.goToNext(
                  context, 'stakeholder_management'),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );

    // --- Mobile layout ---
    if (isMobile) {
      return Scaffold(
        backgroundColor: Colors.white,
        drawer: Drawer(
          width: sidebarWidth,
          child: const SafeArea(
            child: InitiationLikeSidebar(
              activeItemLabel: 'Stakeholder Management',
              showHeader: true,
            ),
          ),
        ),
        body: SafeArea(
          top: true,
          child: Column(
            children: [
              header,
              Expanded(
                child: Stack(
                  children: [
                    const MobileSidebarHamburger(
                      sidebar: InitiationLikeSidebar(
                        activeItemLabel: 'Stakeholder Management',
                      ),
                    ),
                    scrollableContent,
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

    // --- Desktop layout ---
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            header,
            Expanded(
              child: Row(
                children: [
                  DraggableSidebar(
                    openWidth: sidebarWidth,
                    child: const InitiationLikeSidebar(
                        activeItemLabel: 'Stakeholder Management'),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        scrollableContent,
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
          ],
        ),
      ),
    );
  }

  // Manual persistence methods removed as we now use ProjectDataHelper.updateAndSave

  void _addStakeholder() async {
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'stakeholder_management',
      dataUpdater: (d) => d.copyWith(
        stakeholderEntries: [...d.stakeholderEntries, StakeholderEntry.empty()],
      ),
    );
    _scrollToLatestInlineRow();
  }

  void _updateStakeholder(StakeholderEntry updated) async {
    final provider = ProjectDataHelper.getProvider(context);
    final entries =
        List<StakeholderEntry>.from(provider.projectData.stakeholderEntries);
    final index = entries.indexWhere((entry) => entry.id == updated.id);
    if (index == -1) return;
    entries[index] = updated.copyWith(updatedAt: DateTime.now());

    // Update local state immediately for responsive UI (matrix updates),
    // then debounce the remote save to reduce write volume.
    provider.updateField((d) => d.copyWith(stakeholderEntries: entries));
    _stakeholderSaveDebounce.run(() async {
      await provider.saveToFirebase(checkpoint: 'stakeholder_management');
    });
  }

  void _deleteStakeholder(String id) async {
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'stakeholder_management',
      dataUpdater: (d) => d.copyWith(
        stakeholderEntries:
            d.stakeholderEntries.where((e) => e.id != id).toList(),
      ),
    );
  }

  void _addEngagementPlan() async {
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'stakeholder_management',
      dataUpdater: (d) => d.copyWith(
        engagementPlanEntries: [
          ...d.engagementPlanEntries,
          EngagementPlanEntry.empty()
        ],
      ),
    );
    _scrollToLatestInlineRow();
  }

  void _updateEngagementPlan(EngagementPlanEntry updated) async {
    final projectData = ProjectDataHelper.getDataListening(context);
    final entries =
        List<EngagementPlanEntry>.from(projectData.engagementPlanEntries);
    final index = entries.indexWhere((entry) => entry.id == updated.id);
    if (index == -1) return;
    entries[index] = updated.copyWith(updatedAt: DateTime.now());

    _planSaveDebounce.run(() async {
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'stakeholder_management',
        showSnackbar: false,
        dataUpdater: (d) => d.copyWith(engagementPlanEntries: entries),
      );
    });
  }

  void _deleteEngagementPlan(String id) async {
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'stakeholder_management',
      dataUpdater: (d) => d.copyWith(
        engagementPlanEntries:
            d.engagementPlanEntries.where((e) => e.id != id).toList(),
      ),
    );
  }

  /// Persist edits made to a [TeamMember] from the Project Team
  /// Communication Roster (email, phone, location, hasSiteAccess). The
  /// team_members list lives on the project doc, so the same
  /// `stakeholder_management` checkpoint write path is reused — keeping
  /// all engagement-plan-related edits in one debounced save flow.
  void _updateTeamMember(TeamMember updated) async {
    _planSaveDebounce.run(() async {
      await ProjectDataHelper.updateAndSave(
        context: context,
        checkpoint: 'stakeholder_management',
        showSnackbar: false,
        dataUpdater: (d) {
          final members = List<TeamMember>.from(d.teamMembers);
          final index = members.indexWhere((m) => m.id == updated.id);
          if (index == -1) return d;
          members[index] = updated;
          return d.copyWith(teamMembers: members);
        },
      );
    });
  }

  /// Auto-create one "Manage Closely" engagement plan row per Project
  /// Team member that doesn't already have one. Each row is pre-filled
  /// with the member's name + role as the stakeholder, "Project Team"
  /// as the group, weekly frequency (PT members need the tightest
  /// cadence), and `manageClosely = true`. The member's email is also
  /// copied into `dataShareLinks` so the plan immediately surfaces the
  /// out-of-band email channel for any PT members without site access.
  Future<void> _syncTeamToEngagementPlans() async {
    final projectData = ProjectDataHelper.getDataListening(context);
    final teamMembers = projectData.teamMembers;
    if (teamMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No Project Team members found. Add team members in the Team Management screen first.'),
        ),
      );
      return;
    }

    final existingByMemberId = {
      for (final e in projectData.engagementPlanEntries)
        if (e.teamMemberId.isNotEmpty) e.teamMemberId: e,
    };

    final newEntries = <EngagementPlanEntry>[];
    final now = DateTime.now();
    for (final m in teamMembers) {
      if (existingByMemberId.containsKey(m.id)) continue;
      final stakeholderLabel = m.name.isEmpty
          ? (m.role.isEmpty ? 'Project Team Member' : m.role)
          : m.name;
      newEntries.add(EngagementPlanEntry(
        id: now.microsecondsSinceEpoch.toString() + m.id,
        stakeholder: stakeholderLabel,
        objective:
            'Engage ${m.name.isEmpty ? m.role : m.name} as a Project Team member',
        method: m.hasSiteAccess
            ? 'In-app + Email + Standups'
            : 'Email (no site access) + Phone',
        frequency: 'Weekly',
        owner: 'Project Manager',
        status: 'Planned',
        nextTouchpoint: '',
        notes: m.hasSiteAccess
            ? 'Role: ${m.role}'
            : 'No site access — must be emailed at ${m.email.isEmpty ? '(email to be added)' : m.email}',
        stakeholderGroup: 'Project Team',
        manageClosely: true,
        dataShareLinks: m.email.isEmpty ? '' : 'Email: ${m.email}',
        teamMemberId: m.id,
        createdAt: now,
        updatedAt: now,
      ));
    }

    if (newEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'All Project Team members already have engagement plan rows.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'stakeholder_management',
      dataUpdater: (d) => d.copyWith(
        engagementPlanEntries: [...d.engagementPlanEntries, ...newEntries],
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Synced ${newEntries.length} Project Team '
          'member(s) into the Engagement Plans tab as "Manage Closely" rows.',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF059669),
      ),
    );
  }

  void _scrollToLatestInlineRow() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted || !_pageScrollController.hasClients) return;
      final position = _pageScrollController.position;
      await _pageScrollController.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _autoPopulateFromInitiation() async {
    final projectData = ProjectDataHelper.getProvider(context).projectData;
    final coreStakeholders = projectData.coreStakeholdersData;
    if (coreStakeholders == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No stakeholder data found in Initiation Phase.')));
      return;
    }

    final solutionData = coreStakeholders.solutionStakeholderData.firstWhere(
      (s) => s.solutionTitle == projectData.preferredSolution?.title,
      orElse: () => coreStakeholders.solutionStakeholderData.isNotEmpty
          ? coreStakeholders.solutionStakeholderData.first
          : SolutionStakeholderData(),
    );

    if (solutionData.solutionTitle.isEmpty &&
        coreStakeholders.solutionStakeholderData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No stakeholder data found in Initiation Phase.')));
      return;
    }

    final List<StakeholderEntry> newEntries = [];

    void parseAndAdd(String text, String org) {
      final lines = text.split('\n');
      for (var line in lines) {
        final cleaned = line.replaceAll(RegExp(r'^[-*•]\s*'), '').trim();
        if (cleaned.isNotEmpty) {
          newEntries.add(StakeholderEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString() +
                cleaned.hashCode.toString(),
            name: cleaned,
            organization: org,
            role: 'TBD',
            contactInfo: '',
            influence: 'Medium',
            interest: 'Medium',
            channel: 'Email',
            owner: 'Project Manager',
            notes: 'Added from Initiation Phase',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }
      }
    }

    parseAndAdd(solutionData.internalStakeholders, 'Internal');
    parseAndAdd(solutionData.externalStakeholders, 'External');

    // Also parse organisation context for additional internal teams/groups
    // that may influence or be influenced by the project.
    final orgContext = coreStakeholders.organisationContext.trim();
    if (orgContext.isNotEmpty) {
      // Extract team/group names from organisation description
      // Look for lines or phrases mentioning teams, departments, groups
      final orgLines = orgContext.split('\n');
      for (var line in orgLines) {
        final cleaned = line.replaceAll(RegExp(r'^[-*•]\s*'), '').trim();
        if (cleaned.isNotEmpty &&
            !newEntries
                .any((e) => e.name.toLowerCase() == cleaned.toLowerCase())) {
          // Only add if it looks like a team/group/department reference
          final lowerLine = cleaned.toLowerCase();
          if (lowerLine.contains('team') ||
              lowerLine.contains('department') ||
              lowerLine.contains('group') ||
              lowerLine.contains('division') ||
              lowerLine.contains('unit') ||
              lowerLine.contains('office') ||
              lowerLine.contains('finance') ||
              lowerLine.contains('it ') ||
              lowerLine.contains('operations') ||
              lowerLine.contains('hr') ||
              lowerLine.contains('legal') ||
              lowerLine.contains('marketing') ||
              lowerLine.contains('sales') ||
              lowerLine.contains('engineering') ||
              lowerLine.contains('design') ||
              lowerLine.contains('quality') ||
              lowerLine.contains('security')) {
            newEntries.add(StakeholderEntry(
              id: DateTime.now().microsecondsSinceEpoch.toString() +
                  cleaned.hashCode.toString(),
              name: cleaned,
              organization: 'Internal',
              role: 'Team/Group',
              contactInfo: '',
              influence: 'Medium',
              interest: 'Medium',
              channel: 'Email',
              owner: 'Project Manager',
              notes: 'Identified from organisation context in Initiation Phase',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
          }
        }
      }
    }

    // Show prompt asking about additional teams/groups
    if (mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Teams & Groups Check'),
          content: const Text(
              'Are there any other teams or groups in your organisation that would '
              'influence this project or be influenced by it?\n\n'
              'Consider:\n'
              '• Teams that will contribute resources or expertise\n'
              '• Departments affected by the project outcomes\n'
              '• Groups that need to be consulted or informed\n'
              '• External partners or vendors with influence\n\n'
              'You can add them manually using the "Add Stakeholder" button.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }

    if (newEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No stakeholders found in Initiation Phase.')));
      return;
    }

    // Generate engagement plans for each stakeholder
    final now = DateTime.now();
    final engagementPlans = newEntries
        .map((s) => EngagementPlanEntry(
              id: '${now.microsecondsSinceEpoch}_${s.id}',
              stakeholder: s.name,
              objective:
                  'Engage ${s.name} to align on project objectives and gather input',
              method: 'Regular meetings',
              frequency: 'Weekly',
              owner: 'Project Manager',
              status: 'Planned',
              nextTouchpoint: '',
              notes: 'Auto-generated from Initiation Phase stakeholder data',
              createdAt: now,
              updatedAt: now,
            ))
        .toList();

    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'stakeholder_management',
      dataUpdater: (d) => d.copyWith(
        stakeholderEntries: newEntries,
        engagementPlanEntries: [
          ...d.engagementPlanEntries,
          ...engagementPlans,
        ],
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Loaded ${newEntries.length} stakeholders and ${engagementPlans.length} engagement plans from Initiation Phase.',
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getDataListening(context);

    // Build a compact text summary of engagement plans so the exported
    // PDF includes the full quarterly plan + data-share links rather
    // than just the notes field.
    final plansBuffer = StringBuffer();
    if (projectData.engagementPlanEntries.isEmpty) {
      plansBuffer.writeln('No engagement plans defined.');
    } else {
      for (var i = 0; i < projectData.engagementPlanEntries.length; i++) {
        final e = projectData.engagementPlanEntries[i];
        plansBuffer.writeln('${i + 1}. ${e.stakeholder}'
            '${e.stakeholderGroup.isNotEmpty ? ' [${e.stakeholderGroup}]' : ''}'
            '${e.manageClosely ? ' (Manage Closely)' : ''}');
        if (e.objective.isNotEmpty)
          plansBuffer.writeln('   Objective: ${e.objective}');
        if (e.method.isNotEmpty) plansBuffer.writeln('   Method: ${e.method}');
        if (e.frequency.isNotEmpty)
          plansBuffer.writeln('   Frequency: ${e.frequency}');
        if (e.owner.isNotEmpty) plansBuffer.writeln('   Owner: ${e.owner}');
        if (e.status.isNotEmpty) plansBuffer.writeln('   Status: ${e.status}');
        if (e.q1Plan.isNotEmpty ||
            e.q2Plan.isNotEmpty ||
            e.q3Plan.isNotEmpty ||
            e.q4Plan.isNotEmpty) {
          plansBuffer.writeln('   Quarterly Plan:');
          if (e.q1Plan.isNotEmpty) plansBuffer.writeln('     Q1: ${e.q1Plan}');
          if (e.q2Plan.isNotEmpty) plansBuffer.writeln('     Q2: ${e.q2Plan}');
          if (e.q3Plan.isNotEmpty) plansBuffer.writeln('     Q3: ${e.q3Plan}');
          if (e.q4Plan.isNotEmpty) plansBuffer.writeln('     Q4: ${e.q4Plan}');
        }
        if (e.dataShareLinks.isNotEmpty) {
          plansBuffer.writeln('   Data Sharing Links:');
          for (final line in e.dataShareLinks.split('\n')) {
            if (line.trim().isNotEmpty)
              plansBuffer.writeln('     - ${line.trim()}');
          }
        }
        plansBuffer.writeln('');
      }
    }

    // Project Team Communication Roster — name / role / email / phone /
    // location / site-access status. The PT is the "Manage Closely"
    // stakeholder group, so include it in the PDF for downstream
    // out-of-band engagement (especially for members without site access).
    final rosterBuffer = StringBuffer();
    if (projectData.teamMembers.isEmpty) {
      rosterBuffer.writeln('No Project Team members defined.');
    } else {
      for (var i = 0; i < projectData.teamMembers.length; i++) {
        final m = projectData.teamMembers[i];
        rosterBuffer
            .writeln('${i + 1}. ${m.name.isEmpty ? "(unnamed)" : m.name}'
                '${m.role.isNotEmpty ? ' — ${m.role}' : ''}');
        rosterBuffer.writeln(
            '   Email: ${m.email.isEmpty ? "(not provided)" : m.email}');
        rosterBuffer.writeln(
            '   Location: ${m.location.isEmpty ? "(not provided)" : m.location}');
        rosterBuffer.writeln(
            '   Phone: ${m.phone.isEmpty ? "(not provided)" : m.phone}');
        rosterBuffer.writeln(
            '   Site Access: ${m.hasSiteAccess ? "Yes" : "No (engage via email/phone)"}');
        rosterBuffer.writeln('');
      }
    }

    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Stakeholder Management',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
          {'Solution Title': projectData.solutionTitle ?? 'N/A'},
        ]),
        PdfSection.text(
          'Engagement Plans',
          plansBuffer.toString().trimRight(),
        ),
        PdfSection.text(
          'Project Team Communication Roster',
          rosterBuffer.toString().trimRight(),
        ),
        PdfSection.text(
          'Notes',
          projectData.planningNotes['planning_stakeholder_management_notes'] ??
              'No data recorded.',
        ),
      ],
    );
  }
}

class _TitleSection extends StatelessWidget {
  const _TitleSection(
      {required this.showButtonsBelow,
      required this.onExport,
      required this.onAddProject,
      this.onAutoPopulate});

  final bool showButtonsBelow;
  final VoidCallback onExport;
  final VoidCallback onAddProject;
  final VoidCallback? onAutoPopulate;

  @override
  Widget build(BuildContext context) {
    const buttons = SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stakeholder Management',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827)),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Manage stakeholders, communication plans, and engagement strategies',
                    style: TextStyle(
                        fontSize: 15, color: Color(0xFF6B7280), height: 1.5),
                  ),
                ],
              ),
            ),
            if (!showButtonsBelow) ...[
              if (onAutoPopulate != null)
                _topButton(
                    label: 'Auto-populate',
                    icon: Icons.auto_awesome,
                    color: const Color(0xFFFFC107),
                    textColor: Colors.black,
                    onPressed: onAutoPopulate!),
              const SizedBox(width: 12),
              buttons,
            ],
          ],
        ),
        if (showButtonsBelow) ...[
          const SizedBox(height: 16),
          if (onAutoPopulate != null) ...[
            _topButton(
                label: 'Auto-populate from Initiation',
                icon: Icons.auto_awesome,
                color: const Color(0xFFFFC107),
                textColor: Colors.black,
                onPressed: onAutoPopulate!),
            const SizedBox(height: 12),
          ],
          buttons,
        ],
      ],
    );
  }

  Widget _topButton(
      {required String label,
      required IconData icon,
      required Color color,
      required Color textColor,
      required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: textColor),
      label: Text(label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.totalStakeholders,
    required this.externalCount,
  });

  final int totalStakeholders;
  final int externalCount;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);

    final children = [
      _MetricCard(
        title: 'Total Stakeholders',
        value: totalStakeholders.toString(),
        icon: Icons.people_alt_outlined,
        accentColor: const Color(0xFF60A5FA),
      ),
      _MetricCard(
        title: 'External Partners',
        value: externalCount.toString(),
        icon: Icons.public_rounded,
        accentColor: const Color(0xFF10B981),
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i != 0) const SizedBox(height: 16),
            children[i],
          ],
        ],
      );
    }

    return Row(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i != 0) const SizedBox(width: 16),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.accentColor});

  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 26),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827))),
            ],
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _InfoCardsRow extends StatelessWidget {
  const _InfoCardsRow({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final cards = [
      const _CommunicationFrequencyCard(),
      const _LevelDistributionCard(),
    ];

    if (isMobile) {
      return Column(
        children: [
          cards[0],
          const SizedBox(height: 16),
          cards[1],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 16),
        Expanded(child: cards[1]),
      ],
    );
  }
}

class _CommunicationFrequencyCard extends StatelessWidget {
  const _CommunicationFrequencyCard();

  static const List<String> _items = [];

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const _SectionEmptyState(
        title: 'No cadence defined',
        message: 'Add communication frequency to align stakeholders.',
        icon: Icons.forum_outlined,
      );
    }
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Communication Frequency',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 16),
          for (var item in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child:
                        Icon(Icons.circle, size: 8, color: Color(0xFF111827)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF374151))),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LevelDistributionCard extends StatelessWidget {
  const _LevelDistributionCard();

  @override
  Widget build(BuildContext context) {
    return const _SectionEmptyState(
      title: 'No influence distribution yet',
      message: 'Map stakeholder influence to visualize engagement tiers.',
      icon: Icons.pie_chart_outline,
    );
  }
}

class _InfluenceInterestMatrix extends StatelessWidget {
  const _InfluenceInterestMatrix({required this.stakeholders});

  final List<StakeholderEntry> stakeholders;

  @override
  Widget build(BuildContext context) {
    final hHighILow = stakeholders
        .where((s) => s.influence == 'High' && s.interest == 'Low')
        .toList();
    final hHighIHigh = stakeholders
        .where((s) => s.influence == 'High' && s.interest == 'High')
        .toList();
    final hLowILow = stakeholders
        .where((s) => s.influence == 'Low' && s.interest == 'Low')
        .toList();
    final hLowIHigh = stakeholders
        .where((s) => s.influence == 'Low' && s.interest == 'High')
        .toList();
    // NOTE: Medium/keep-informed/monitor buckets were previously computed here
    // but unused in the UI.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Influence / Interest Matrix',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827)),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 10,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              // Column Headers (Interest)
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 40), // Spacing for Y-axis label
                    Expanded(child: _axisHeader('LOW INTEREST')),
                    Expanded(child: _axisHeader('HIGH INTEREST')),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Y-axis label (Influence)
                  _verticalAxisLabel('HIGH INFLUENCE'),
                  Expanded(
                    child: _matrixQuadrant(
                      label: 'Keep Satisfied',
                      color: const Color(0xFFEFF6FF), // Blue
                      accentColor: const Color(0xFF3B82F6),
                      stakeholders: hHighILow,
                    ),
                  ),
                  Expanded(
                    child: _matrixQuadrant(
                      label: 'Manage Closely (Key Players)',
                      color: const Color(0xFFFEF2F2), // Red
                      accentColor: const Color(0xFFEF4444),
                      stakeholders: hHighIHigh,
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _verticalAxisLabel('LOW INFLUENCE'),
                  Expanded(
                    child: _matrixQuadrant(
                      label: 'Monitor (Minimal Effort)',
                      color: const Color(0xFFF9FAFB), // Grey
                      accentColor: const Color(0xFF6B7280),
                      stakeholders: hLowILow,
                    ),
                  ),
                  Expanded(
                    child: _matrixQuadrant(
                      label: 'Keep Informed',
                      color: const Color(0xFFECFDF5), // Green
                      accentColor: const Color(0xFF10B981),
                      stakeholders: hLowIHigh,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _axisHeader(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Color(0xFF9CA3AF)),
      ),
    );
  }

  Widget _verticalAxisLabel(String text) {
    return Container(
      width: 40,
      height: 140,
      alignment: Alignment.center,
      child: RotatedBox(
        quarterTurns: 3,
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFF9CA3AF)),
        ),
      ),
    );
  }

  Widget _matrixQuadrant({
    required String label,
    required Color color,
    required Color accentColor,
    required List<StakeholderEntry> stakeholders,
  }) {
    return Container(
      height: 140,
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: accentColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accentColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: stakeholders.isEmpty
                ? Center(
                    child: Text(
                      'None',
                      style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: accentColor.withValues(alpha: 0.5)),
                    ),
                  )
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: stakeholders
                          .map((s) => _stakeholderChip(s, accentColor))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stakeholderChip(StakeholderEntry s, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Text(
        s.name.isEmpty ? 'Unnamed' : s.name,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color.withValues(alpha: 0.8)),
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

class _EngagementSection extends StatelessWidget {
  const _EngagementSection({
    required this.activeTabIndex,
    required this.onTabChanged,
    required this.stakeholderTable,
    required this.planTable,
    required this.onAdd,
    required this.onSearch,
  });

  final int activeTabIndex;
  final ValueChanged<int> onTabChanged;
  final Widget stakeholderTable;
  final Widget planTable;
  final VoidCallback onAdd;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF4F5FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                _tabButton(title: 'Stakeholders', index: 0),
                _tabButton(title: 'Engagement Plans', index: 1),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SearchField(
                        enabled: true,
                        value: '', // Managed externally now
                        onChanged: onSearch,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: Text(
                          activeTabIndex == 0 ? 'Add stakeholder' : 'Add plan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD84D),
                        foregroundColor: const Color(0xFF1F2937),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                IndexedStack(
                  index: activeTabIndex,
                  children: [
                    stakeholderTable,
                    planTable,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({required String title, required int index}) {
    final active = activeTabIndex == index;
    return InkWell(
      onTap: () => onTabChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF1F2937) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? const Color(0xFF1F2937) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField(
      {required this.enabled, required this.value, required this.onChanged});

  final bool enabled;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return VoiceTextField(
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search stakeholders...',
        prefixIcon:
            const Icon(Icons.search, size: 20, color: Color(0xFF9CA3AF)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFC812), width: 1.2),
        ),
      ),
    );
  }
}

// _FilterButton removed as per plan

class _StakeholdersTable extends StatelessWidget {
  const _StakeholdersTable({
    required this.entries,
    required this.isLoading,
    required this.onChanged,
    required this.onDelete,
  });

  final List<StakeholderEntry> entries;
  final bool isLoading;
  final ValueChanged<StakeholderEntry> onChanged;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final columns = [
      const _TableColumnDef('#', 72),
      const _TableColumnDef('Stakeholder', 200),
      const _TableColumnDef('Organization', 180),
      const _TableColumnDef('Role/Title', 160),
      const _TableColumnDef('Contact Info', 200),
      const _TableColumnDef('Influence', 140),
      const _TableColumnDef('Interest', 140),
      const _TableColumnDef('Channel', 180),
      const _TableColumnDef('Owner', 160),
      const _TableColumnDef('Notes', 240),
      const _TableColumnDef('', 70),
    ];

    if (isLoading) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    if (entries.isEmpty) {
      return const _SectionEmptyState(
        title: 'No stakeholders yet',
        message: 'Add stakeholders to build your engagement register.',
        icon: Icons.group_outlined,
      );
    }

    return _EditableTable(
      columns: columns,
      rows: [
        for (int index = 0; index < entries.length; index++)
          _EditableRow(
            key: ValueKey(entries[index].id),
            columns: columns,
            cells: [
              _IndexCell(number: index + 1),
              _TextCell(
                value: entries[index].name,
                fieldKey: '${entries[index].id}_name',
                hintText: 'Name',
                onChanged: (value) =>
                    onChanged(entries[index].copyWith(name: value)),
              ),
              _TextCell(
                value: entries[index].organization,
                fieldKey: '${entries[index].id}_organization',
                hintText: 'Organization',
                onChanged: (value) =>
                    onChanged(entries[index].copyWith(organization: value)),
              ),
              _TextCell(
                value: entries[index].role,
                fieldKey: '${entries[index].id}_role',
                hintText: 'Role/Title',
                onChanged: (value) =>
                    onChanged(entries[index].copyWith(role: value)),
              ),
              _TextCell(
                value: entries[index].contactInfo,
                fieldKey: '${entries[index].id}_contactInfo',
                hintText: 'Email/Phone',
                onChanged: (value) =>
                    onChanged(entries[index].copyWith(contactInfo: value)),
              ),
              _DropdownCell(
                value: entries[index].influence,
                fieldKey: '${entries[index].id}_influence',
                options: const ['High', 'Medium', 'Low'],
                onChanged: (value) =>
                    onChanged(entries[index].copyWith(influence: value)),
              ),
              _DropdownCell(
                value: entries[index].interest,
                fieldKey: '${entries[index].id}_interest',
                options: const ['High', 'Medium', 'Low'],
                onChanged: (value) =>
                    onChanged(entries[index].copyWith(interest: value)),
              ),
              _TextCell(
                value: entries[index].channel,
                fieldKey: '${entries[index].id}_channel',
                hintText: 'Channel',
                onChanged: (value) =>
                    onChanged(entries[index].copyWith(channel: value)),
              ),
              _TextCell(
                value: entries[index].owner,
                fieldKey: '${entries[index].id}_owner',
                hintText: 'Owner',
                onChanged: (value) =>
                    onChanged(entries[index].copyWith(owner: value)),
              ),
              _TextCell(
                value: entries[index].notes,
                fieldKey: '${entries[index].id}_notes',
                hintText: 'Notes',
                minLines: 1,
                maxLines: null,
                onChanged: (value) =>
                    onChanged(entries[index].copyWith(notes: value)),
              ),
              _DeleteCell(
                itemName:
                    'stakeholder "${entries[index].name.trim().isEmpty ? 'Untitled' : entries[index].name.trim()}"',
                onPressed: () => onDelete(entries[index].id),
              ),
            ],
          ),
      ],
    );
  }
}

class _EngagementPlansTable extends StatefulWidget {
  const _EngagementPlansTable({
    required this.entries,
    required this.isLoading,
    required this.onChanged,
    required this.onDelete,
  });

  final List<EngagementPlanEntry> entries;
  final bool isLoading;
  final ValueChanged<EngagementPlanEntry> onChanged;
  final ValueChanged<String> onDelete;

  @override
  State<_EngagementPlansTable> createState() => _EngagementPlansTableState();
}

class _EngagementPlansTableState extends State<_EngagementPlansTable> {
  /// Per-row expand state — keyed by EngagementPlanEntry.id. When a row is
  /// expanded it reveals a quarterly plan grid (Q1-Q4) + a data-share
  /// links textarea + a "Manage Closely" checkbox, so the user can author
  /// the full communication plan without leaving the row.
  final Set<String> _expandedRowIds = <String>{};

  static const List<String> _frequencyOptions = [
    '',
    'Daily',
    'Weekly',
    'Bi-weekly',
    'Monthly',
    'Quarterly',
    'Ad-hoc',
  ];

  static const List<String> _stakeholderGroupOptions = [
    '',
    'Project Team',
    'Sponsor',
    'Steering Committee',
    'Customer',
    'End User',
    'Vendor',
    'Regulator',
    'External Partner',
    'Internal Team',
    'Other',
  ];

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedRowIds.contains(id)) {
        _expandedRowIds.remove(id);
      } else {
        _expandedRowIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final columns = [
      const _TableColumnDef('#', 56),
      const _TableColumnDef('Stakeholder', 180),
      const _TableColumnDef('Group', 140),
      const _TableColumnDef('Manage Closely', 110),
      const _TableColumnDef('Objective', 200),
      const _TableColumnDef('Method', 140),
      const _TableColumnDef('Frequency', 130),
      const _TableColumnDef('Owner', 140),
      const _TableColumnDef('Status', 130),
      const _TableColumnDef('Next Touchpoint', 140),
      const _TableColumnDef('Notes', 200),
      const _TableColumnDef('', 90),
    ];

    if (widget.isLoading) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    if (widget.entries.isEmpty) {
      return const _SectionEmptyState(
        title: 'No engagement plans yet',
        message:
            'Add engagement plans to define how each stakeholder group will be engaged per quarter, the frequency of communication, and where data will be shared.',
        icon: Icons.playlist_add_check_outlined,
      );
    }

    return _EditableTable(
      columns: columns,
      rows: [
        for (int index = 0; index < widget.entries.length; index++)
          _EngagementPlanRow(
            key: ValueKey(widget.entries[index].id),
            entry: widget.entries[index],
            index: index,
            columns: columns,
            isExpanded: _expandedRowIds.contains(widget.entries[index].id),
            onToggleExpand: () => _toggleExpand(widget.entries[index].id),
            frequencyOptions: _frequencyOptions,
            stakeholderGroupOptions: _stakeholderGroupOptions,
            onChanged: widget.onChanged,
            onDelete: widget.onDelete,
          ),
      ],
    );
  }
}

/// A single engagement plan row that can expand to reveal a quarterly
/// engagement plan (Q1-Q4) + data-share links textarea. The expanded
/// panel replaces the wide table layout with a vertical card so the user
/// has room to author detailed quarterly plans without column-width
/// constraints.
class _EngagementPlanRow extends StatelessWidget {
  const _EngagementPlanRow({
    super.key,
    required this.entry,
    required this.index,
    required this.columns,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.frequencyOptions,
    required this.stakeholderGroupOptions,
    required this.onChanged,
    required this.onDelete,
  });

  final EngagementPlanEntry entry;
  final int index;
  final List<_TableColumnDef> columns;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final List<String> frequencyOptions;
  final List<String> stakeholderGroupOptions;
  final ValueChanged<EngagementPlanEntry> onChanged;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditableRow(
          columns: columns,
          cells: [
            _IndexCell(number: index + 1),
            _TextCell(
              value: entry.stakeholder,
              fieldKey: '${entry.id}_stakeholder',
              hintText: 'Stakeholder',
              onChanged: (value) =>
                  onChanged(entry.copyWith(stakeholder: value)),
            ),
            _DropdownCell(
              value: entry.stakeholderGroup,
              fieldKey: '${entry.id}_group',
              options: stakeholderGroupOptions,
              onChanged: (value) =>
                  onChanged(entry.copyWith(stakeholderGroup: value)),
            ),
            _ManageCloselyCell(
              value: entry.manageClosely,
              onChanged: (value) =>
                  onChanged(entry.copyWith(manageClosely: value)),
            ),
            _TextCell(
              value: entry.objective,
              fieldKey: '${entry.id}_objective',
              hintText: 'Objective',
              minLines: 1,
              maxLines: null,
              onChanged: (value) => onChanged(entry.copyWith(objective: value)),
            ),
            _TextCell(
              value: entry.method,
              fieldKey: '${entry.id}_method',
              hintText: 'Method',
              onChanged: (value) => onChanged(entry.copyWith(method: value)),
            ),
            _DropdownCell(
              value: entry.frequency,
              fieldKey: '${entry.id}_frequency',
              options: frequencyOptions,
              onChanged: (value) => onChanged(entry.copyWith(frequency: value)),
            ),
            _TextCell(
              value: entry.owner,
              fieldKey: '${entry.id}_owner',
              hintText: 'Owner',
              onChanged: (value) => onChanged(entry.copyWith(owner: value)),
            ),
            _DropdownCell(
              value: entry.status,
              fieldKey: '${entry.id}_status',
              options: const ['Planned', 'In progress', 'At risk', 'Completed'],
              onChanged: (value) => onChanged(entry.copyWith(status: value)),
            ),
            _TextCell(
              value: entry.nextTouchpoint,
              fieldKey: '${entry.id}_next_touchpoint',
              hintText: 'Next touchpoint',
              onChanged: (value) =>
                  onChanged(entry.copyWith(nextTouchpoint: value)),
            ),
            _TextCell(
              value: entry.notes,
              fieldKey: '${entry.id}_notes',
              hintText: 'Notes',
              minLines: 1,
              maxLines: null,
              onChanged: (value) => onChanged(entry.copyWith(notes: value)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: isExpanded
                      ? 'Collapse quarterly plan'
                      : 'Expand quarterly plan & data-share links',
                  icon: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: const Color(0xFF6B7280),
                  ),
                  onPressed: onToggleExpand,
                ),
                _DeleteCell(
                  itemName:
                      'engagement plan for "${entry.stakeholder.trim().isEmpty ? 'Untitled' : entry.stakeholder.trim()}"',
                  onPressed: () => onDelete(entry.id),
                ),
              ],
            ),
          ],
        ),
        if (isExpanded) _buildExpandedPanel(),
      ],
    );
  }

  Widget _buildExpandedPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_view_month,
                  size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              const Text(
                'Quarterly Engagement Plan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              if (entry.manageClosely)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: const Text(
                    'MANAGE CLOSELY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Q1-Q4 grid - each cell is a multi-line text area so the user
          // can author per-quarter engagement plans (kickoff, demos,
          // retrospectives, etc.).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _QuarterPlanField(
                  label: 'Q1',
                  value: entry.q1Plan,
                  hint: 'Kickoff, discovery, alignment',
                  onChanged: (v) => onChanged(entry.copyWith(q1Plan: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuarterPlanField(
                  label: 'Q2',
                  value: entry.q2Plan,
                  hint: 'Build, demos, mid-point review',
                  onChanged: (v) => onChanged(entry.copyWith(q2Plan: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuarterPlanField(
                  label: 'Q3',
                  value: entry.q3Plan,
                  hint: 'UAT, training, rollout prep',
                  onChanged: (v) => onChanged(entry.copyWith(q3Plan: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuarterPlanField(
                  label: 'Q4',
                  value: entry.q4Plan,
                  hint: 'Go-live, retro, handover',
                  onChanged: (v) => onChanged(entry.copyWith(q4Plan: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Data-share links - free-text textarea. One URL/path/DL per
          // line. Surfaces where the stakeholder group will receive
          // project artefacts (status reports, dashboards, demos, etc.).
          const Row(
            children: [
              Icon(Icons.link, size: 16, color: Color(0xFF6B7280)),
              SizedBox(width: 8),
              Text(
                'Data Sharing Links',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Where shared artefacts will be published for this stakeholder group - one URL/path/email DL per line. Examples: SharePoint folder, Google Drive, email distribution list.',
            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          _DataLinksField(
            value: entry.dataShareLinks,
            fieldKey: '${entry.id}_data_links',
            onChanged: (v) => onChanged(entry.copyWith(dataShareLinks: v)),
          ),
        ],
      ),
    );
  }
}

class _ManageCloselyCell extends StatelessWidget {
  const _ManageCloselyCell({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _TableFieldShell(
      child: Align(
        alignment: Alignment.center,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: value ? const Color(0xFFFEF3C7) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color:
                    value ? const Color(0xFFF59E0B) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  value ? Icons.star : Icons.star_border,
                  size: 12,
                  color:
                      value ? const Color(0xFFB45309) : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 4),
                Text(
                  value ? 'Yes' : 'No',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: value
                        ? const Color(0xFF92400E)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuarterPlanField extends StatefulWidget {
  const _QuarterPlanField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_QuarterPlanField> createState() => _QuarterPlanFieldState();
}

class _QuarterPlanFieldState extends State<_QuarterPlanField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_QuarterPlanField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD84D),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        const SizedBox(height: 6),
        VoiceTextFormField(
          controller: _controller,
          minLines: 2,
          maxLines: null,
          decoration: InputDecoration(
            hintText: widget.hint,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFFFFD700), width: 1.2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

class _DataLinksField extends StatefulWidget {
  const _DataLinksField({
    required this.value,
    required this.fieldKey,
    required this.onChanged,
  });

  final String value;
  final String fieldKey;
  final ValueChanged<String> onChanged;

  @override
  State<_DataLinksField> createState() => _DataLinksFieldState();
}

class _DataLinksFieldState extends State<_DataLinksField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_DataLinksField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VoiceTextFormField(
      controller: _controller,
      minLines: 3,
      maxLines: null,
      decoration: InputDecoration(
        hintText:
            'https://drive.google.com/...\nSharePoint: /PMO/Project Alpha/Reports\nEmail DL: project-alpha-team@nduproject.com',
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF111827),
        fontFamily: 'monospace',
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _EditableTable extends StatelessWidget {
  const _EditableTable({required this.columns, required this.rows});

  final List<_TableColumnDef> columns;
  final List<_EditableRow> rows;

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 16.0;
    final contentWidth =
        columns.fold<double>(0, (total, column) => total + column.width);
    final minTableWidth = contentWidth + (horizontalPadding * 2);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        color: Colors.white,
      ),
      child: LayoutBuilder(
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
                  Container(
                    width: tableWidth,
                    padding: const EdgeInsets.symmetric(
                        horizontal: horizontalPadding, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18)),
                    ),
                    child: Row(
                      children: columns
                          .map((column) => SizedBox(
                                width: column.width,
                                child: Center(
                                  child: Text(
                                    column.label.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.8,
                                        color: Color(0xFF6B7280)),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  for (int i = 0; i < rows.length; i++)
                    Container(
                      width: tableWidth,
                      padding: const EdgeInsets.symmetric(
                          horizontal: horizontalPadding, vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            i.isEven ? Colors.white : const Color(0xFFF9FAFB),
                        border: Border(
                          top: BorderSide(
                              color: const Color(0xFFE5E7EB),
                              width: i == 0 ? 1 : 0.5),
                        ),
                      ),
                      child: rows[i],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IndexCell extends StatelessWidget {
  const _IndexCell({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$number',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4B5563),
        ),
      ),
    );
  }
}

class _TableFieldShell extends StatelessWidget {
  const _TableFieldShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: child,
    );
  }
}

class _EditableRow extends StatelessWidget {
  const _EditableRow({super.key, required this.columns, required this.cells});

  final List<_TableColumnDef> columns;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        cells.length,
        (index) => SizedBox(width: columns[index].width, child: cells[index]),
      ),
    );
  }
}

class _TableColumnDef {
  const _TableColumnDef(this.label, this.width);

  final String label;
  final double width;
}

class _TextCell extends StatefulWidget {
  const _TextCell({
    required this.value,
    required this.fieldKey,
    required this.onChanged,
    this.hintText,
    this.minLines = 1,
    this.maxLines,
  });

  final String value;
  final String fieldKey;
  final String? hintText;
  final int minLines;
  final int? maxLines;
  final ValueChanged<String> onChanged;

  @override
  State<_TextCell> createState() => _TextCellState();
}

class _TextCellState extends State<_TextCell> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_TextCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TableFieldShell(
      child: VoiceTextFormField(
        controller: _controller,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          hintText: widget.hintText,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _DropdownCell extends StatelessWidget {
  const _DropdownCell({
    required this.value,
    required this.fieldKey,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final String fieldKey;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final resolvedValue = options.contains(value) ? value : options.first;
    return _TableFieldShell(
      child: DropdownButtonFormField<String>(
        key: ValueKey(fieldKey),
        initialValue: resolvedValue,
        items: options
            .map((option) => DropdownMenuItem(
                value: option,
                child: Text(option, style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        decoration: InputDecoration(
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
      ),
    );
  }
}

class _DeleteCell extends StatelessWidget {
  const _DeleteCell({
    required this.onPressed,
    this.itemName = 'this item',
  });

  final VoidCallback onPressed;
  final String itemName;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: IconButton(
        icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
        onPressed: () => _showDeleteConfirmation(context, onPressed),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    VoidCallback onConfirm,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete $itemName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onConfirm();
    }
  }
}

// Private entry classes removed in favor of StakeholderEntry and EngagementPlanEntry in project_data_model.dart

// ─── Project Team Communication Roster ──────────────────────────────────────
// A dedicated subsection that surfaces every Project Team member pulled
// from the staffing plan / team members list. The Project Team is the
// canonical "Manage Closely" stakeholder group, so this roster is the
// single source of truth for PT contact details (name, email, location,
// phone) — especially for positions that do not have site access and
// therefore MUST be engaged via email.

class _ProjectTeamRosterSection extends StatelessWidget {
  const _ProjectTeamRosterSection({
    required this.teamMembers,
    required this.engagementPlanEntries,
    required this.onMemberChanged,
    required this.onSyncToEngagementPlans,
  });

  final List<TeamMember> teamMembers;
  final List<EngagementPlanEntry> engagementPlanEntries;
  final ValueChanged<TeamMember> onMemberChanged;
  final VoidCallback onSyncToEngagementPlans;

  @override
  Widget build(BuildContext context) {
    final ptMembersInPlan = engagementPlanEntries
        .where((e) =>
            e.teamMemberId.isNotEmpty &&
            teamMembers.any((m) => m.id == e.teamMemberId))
        .length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section header ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.groups,
                      size: 22, color: Color(0xFFB45309)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Project Team Communication Roster',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(width: 8),
                          _ManageCloselyBadge(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All Project Team members (pulled from the staffing plan). '
                        'Email is required for every PT member — especially for '
                        'positions that do not have site access and must be '
                        'engaged out-of-band.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Sync action ──
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: onSyncToEngagementPlans,
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text(
                    'Sync Project Team to Engagement Plans',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD84D),
                    foregroundColor: const Color(0xFF1F2937),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (ptMembersInPlan > 0)
                  Text(
                    '$ptMembersInPlan of ${teamMembers.length} PT member(s) already have engagement plan rows',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Roster table ──
            if (teamMembers.isEmpty)
              const _SectionEmptyState(
                title: 'No Project Team members yet',
                message:
                    'Add team members in the Team Management screen — they will appear here automatically with email, phone, and location fields ready to fill in.',
                icon: Icons.group_add_outlined,
              )
            else
              _ProjectTeamRosterTable(
                members: teamMembers,
                onMemberChanged: onMemberChanged,
              ),
          ],
        ),
      ),
    );
  }
}

class _ManageCloselyBadge extends StatelessWidget {
  const _ManageCloselyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 10, color: Color(0xFFB45309)),
          SizedBox(width: 4),
          Text(
            'MANAGE CLOSELY',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectTeamRosterTable extends StatelessWidget {
  const _ProjectTeamRosterTable({
    required this.members,
    required this.onMemberChanged,
  });

  final List<TeamMember> members;
  final ValueChanged<TeamMember> onMemberChanged;

  @override
  Widget build(BuildContext context) {
    final columns = [
      const _TableColumnDef('#', 48),
      const _TableColumnDef('Name', 160),
      const _TableColumnDef('Role', 140),
      const _TableColumnDef('Email Address', 200),
      const _TableColumnDef('Location', 140),
      const _TableColumnDef('Phone (country + area)', 180),
      const _TableColumnDef('Site Access', 110),
    ];

    return _EditableTable(
      columns: columns,
      rows: [
        for (int i = 0; i < members.length; i++)
          _EditableRow(
            key: ValueKey('pt_${members[i].id}'),
            columns: columns,
            cells: [
              _IndexCell(number: i + 1),
              _TextCell(
                value: members[i].name,
                fieldKey: 'pt_${members[i].id}_name',
                hintText: 'Name',
                onChanged: (v) => onMemberChanged(members[i].copyWith(name: v)),
              ),
              _TextCell(
                value: members[i].role,
                fieldKey: 'pt_${members[i].id}_role',
                hintText: 'Role',
                onChanged: (v) => onMemberChanged(members[i].copyWith(role: v)),
              ),
              _EmailCell(
                value: members[i].email,
                fieldKey: 'pt_${members[i].id}_email',
                hintText: 'name@example.com',
                required: !members[i].hasSiteAccess,
                onChanged: (v) =>
                    onMemberChanged(members[i].copyWith(email: v)),
              ),
              _TextCell(
                value: members[i].location,
                fieldKey: 'pt_${members[i].id}_location',
                hintText: 'City, Country',
                onChanged: (v) =>
                    onMemberChanged(members[i].copyWith(location: v)),
              ),
              _TextCell(
                value: members[i].phone,
                fieldKey: 'pt_${members[i].id}_phone',
                hintText: '+260 97 123 4567',
                onChanged: (v) =>
                    onMemberChanged(members[i].copyWith(phone: v)),
              ),
              _SiteAccessCell(
                value: members[i].hasSiteAccess,
                onChanged: (v) =>
                    onMemberChanged(members[i].copyWith(hasSiteAccess: v)),
              ),
            ],
          ),
      ],
    );
  }
}

/// Email cell that highlights itself with a red "Email required" hint
/// when the PT member does not have site access — the email becomes the
/// primary out-of-band communication channel in that case.
class _EmailCell extends StatefulWidget {
  const _EmailCell({
    required this.value,
    required this.fieldKey,
    required this.hintText,
    required this.onChanged,
    this.required = false,
  });

  final String value;
  final String fieldKey;
  final String hintText;
  final ValueChanged<String> onChanged;
  final bool required;

  @override
  State<_EmailCell> createState() => _EmailCellState();
}

class _EmailCellState extends State<_EmailCell> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_EmailCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.value.trim().isEmpty;
    final showRequired = widget.required && isEmpty;
    return _TableFieldShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          VoiceTextFormField(
            controller: _controller,
            minLines: 1,
            maxLines: null,
            decoration: InputDecoration(
              hintText: widget.hintText,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: showRequired
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: showRequired
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: showRequired
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFFFD700),
                  width: 1.2,
                ),
              ),
              filled: true,
              fillColor: showRequired ? const Color(0xFFFEF2F2) : Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
            onChanged: widget.onChanged,
          ),
          if (showRequired)
            const Padding(
              padding: EdgeInsets.only(top: 4, left: 2),
              child: Text(
                'Email required (no site access)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Toggle cell for the "Site Access" column. When on, the PT member can
/// log in to the NDU Project site/app. When off, they must be engaged
/// via email/phone only — and their email cell turns red to flag the
/// requirement.
class _SiteAccessCell extends StatelessWidget {
  const _SiteAccessCell({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _TableFieldShell(
      child: Align(
        alignment: Alignment.center,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: value ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    value ? const Color(0xFF059669) : const Color(0xFFEF4444),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  value ? Icons.check_circle : Icons.cancel,
                  size: 12,
                  color:
                      value ? const Color(0xFF059669) : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 4),
                Text(
                  value ? 'Has access' : 'No access',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: value
                        ? const Color(0xFF065F46)
                        : const Color(0xFF991B1B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Debouncer {
  _Debouncer({Duration? delay})
      : delay = delay ?? const Duration(milliseconds: 700);

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
