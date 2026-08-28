import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:ndu_project/models/stakeholder_announcement.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/openai/openai_config.dart';
import 'package:go_router/go_router.dart';

import 'package:ndu_project/widgets/delete_success_snackbar.dart';
class StakeholderManagementScreen extends StatefulWidget {
  const StakeholderManagementScreen({super.key});

  static void open(BuildContext context) {
    context.push('/stakeholder-management');
  }

  @override
  State<StakeholderManagementScreen> createState() =>
      _StakeholderManagementScreenState();
}

class _StakeholderManagementScreenState
    extends State<StakeholderManagementScreen> {
  // 0 = Stakeholders (default — must be the first thing the user sees so
  //    they can review/auto-populate the stakeholder register before
  //    diving into per-group engagement plans).
  // 1 = Stakeholder Mapping (AI-suggested ratings per stakeholder with
  //    color-coded cells indicating where they land on the influence /
  //    interest matrix).
  // 2 = Engagement Plans
  int _activeTabIndex = 0;

  final _stakeholderSaveDebounce = _Debouncer();
  final _planSaveDebounce = _Debouncer();
  final ScrollController _pageScrollController = ScrollController();
  String _searchQuery = '';

  /// Guards against re-firing the auto-populate flow every time the widget
  /// rebuilds. Set to true after the first attempt (success or failure) so
  /// the user's manual deletions are never silently re-added.
  bool _hasAttemptedAutoPopulate = false;

  /// Sort/filter mode for the Stakeholders tab. 'all' = no filter; the other
  /// values map directly to the four quadrants of the Influence/Interest
  /// matrix so the user can quickly see "who is in Manage Closely?" etc.
  /// Medium influence/interest values are bucketed into the nearest
  /// higher-attention quadrant (Medium+Medium → Keep Informed, etc.) so
  /// no stakeholder is hidden by the filter.
  String _matrixFilter = 'all';

  // ── Announcements (4th tab) ──────────────────────────────────────────
  // Announcements live in their own Firestore subcollection
  // (projects/{id}/stakeholder_announcements) so they can grow
  // independently of the project doc and don't bloat the doc size.
  List<StakeholderAnnouncement> _announcements = [];
  bool _loadingAnnouncements = true;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _announcementsSub;

  @override
  void initState() {
    super.initState();
    // Defer the auto-populate check until after the first frame so that
    // ProjectDataHelper has a Provider wired up and we can safely read
    // projectData.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hasAttemptedAutoPopulate) return;
      _hasAttemptedAutoPopulate = true;
      _maybeAutoPopulateStakeholders();
      _subscribeToAnnouncements();
    });
  }

  @override
  void dispose() {
    _stakeholderSaveDebounce.dispose();
    _planSaveDebounce.dispose();
    _pageScrollController.dispose();
    _announcementsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double horizontalPadding = isMobile ? 20 : 36;
    final projectData = ProjectDataHelper.getDataListening(context);

    // Filter stakeholders and plans based on search
    var filteredStakeholders = projectData.stakeholderEntries.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.organization.toLowerCase().contains(q) ||
          s.role.toLowerCase().contains(q);
    }).toList();

    // Apply the matrix-quarter filter on top of the search filter.
    // Stakeholders with Medium influence/interest are bucketed into the
    // nearest higher-attention quadrant so no one is hidden when a filter
    // is active. (Medium+Medium → Manage Closely, because if we're unsure
    // we'd rather over-engage than under-engage.)
    if (_matrixFilter != 'all') {
      bool matches(String influence, String interest, String filter) {
        final hi = influence == 'High';
        final medI = influence == 'Medium';
        final hiI = interest == 'High';
        final medInt = interest == 'Medium';
        switch (filter) {
          case 'manage_closely':
            return (hi || medI) && (hiI || medInt);
          case 'keep_satisfied':
            return (hi || medI) && interest == 'Low';
          case 'keep_informed':
            return influence == 'Low' && (hiI || medInt);
          case 'monitor':
            return influence == 'Low' && interest == 'Low';
          default:
            return true;
        }
      }

      filteredStakeholders = filteredStakeholders
          .where((s) => matches(s.influence, s.interest, _matrixFilter))
          .toList();
    }

    final filteredPlans = projectData.engagementPlanEntries.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.stakeholder.toLowerCase().contains(q) ||
          p.objective.toLowerCase().contains(q);
    }).toList();

    final sidebarWidth = AppBreakpoints.sidebarWidth(context);

    final header = PlanningPhaseHeader(
        title: 'Stakeholder Management Plan',
        breadcrumbPhase: 'Planning Phase',
        breadcrumbTitle: 'Stakeholder Management Plan',
        onBack: () => PlanningPhaseNavigation.goToPrevious(
            context, 'stakeholder_management'),
        onForward: () =>
            PlanningPhaseNavigation.goToNext(context, 'stakeholder_management'),
        // Export PDF remains in the Engagement toolbar. On desktop this
        // header is constrained to the content column beside the sidebar.
        showExportPdf: false,
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
              mappingTable: _StakeholderMappingTable(
                entries: projectData.stakeholderEntries,
                onChanged: _updateStakeholder,
                onDelete: _deleteStakeholder,
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
              onAdd: _activeTabIndex == 0
                  ? _addStakeholder
                  : (_activeTabIndex == 1
                      ? _addStakeholder
                      : (_activeTabIndex == 3
                          ? () {}
                          : _addEngagementPlan)),
              onSearch: (v) => setState(() => _searchQuery = v),
              onAiReview: _aiReviewStakeholders,
              onAiSuggestRatings: _aiSuggestRatings,
              onExportPdf: _exportPdf,
              matrixFilter: _matrixFilter,
              onMatrixFilterChanged: (v) =>
                  setState(() => _matrixFilter = v),
              announcements: _announcements,
              loadingAnnouncements: _loadingAnnouncements,
              onSaveAnnouncement: _saveAnnouncement,
              onDeleteAnnouncement: _deleteAnnouncement,
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: true,
        child: Row(
          children: [
            DraggableSidebar(
              openWidth: sidebarWidth,
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Stakeholder Management'),
            ),
            Expanded(
              child: ColoredBox(
                color: Colors.white,
                child: Column(
                  children: [
                    header,
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
      showDeleteSuccessSnackBar(context, itemLabel: 'Stakeholder');
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
      showDeleteSuccessSnackBar(context, itemLabel: 'Engagement Plan');
  }

  // ── Announcements persistence (Firestore subcollection) ─────────────
  //
  // Announcements are stored in
  //   projects/{projectId}/stakeholder_announcements/{announcementId}
  //
  // We use a real-time StreamSubscription so the feed updates live when
  // another user (or another tab) creates / edits / deletes an
  // announcement. This mirrors how the project doc itself is reactive
  // via the ProjectDataProvider.
  void _subscribeToAnnouncements() {
    final provider = ProjectDataHelper.getProvider(context);
    final projectId = provider.projectData.projectId;
    if (projectId == null || projectId.isEmpty) {
      setState(() => _loadingAnnouncements = false);
      return;
    }
    _announcementsSub = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('stakeholder_announcements')
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        final items = snapshot.docs
            .map((doc) =>
                StakeholderAnnouncement.fromJson(doc.data()))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        setState(() {
          _announcements = items;
          _loadingAnnouncements = false;
        });
      },
      onError: (e) {
        debugPrint('Announcements stream error: $e');
        if (!mounted) return;
        setState(() => _loadingAnnouncements = false);
      },
    );
  }

  Future<void> _saveAnnouncement(StakeholderAnnouncement a) async {
    final provider = ProjectDataHelper.getProvider(context);
    final projectId = provider.projectData.projectId;
    if (projectId == null || projectId.isEmpty) return;
    final updated = a.copyWith(updatedAt: DateTime.now());
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('stakeholder_announcements')
        .doc(updated.id)
        .set(updated.toJson(), SetOptions(merge: true));
  }

  Future<void> _deleteAnnouncement(String id) async {
    final provider = ProjectDataHelper.getProvider(context);
    final projectId = provider.projectData.projectId;
    if (projectId == null || projectId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('stakeholder_announcements')
        .doc(id)
        .delete();
      showDeleteSuccessSnackBar(context, itemLabel: 'Announcement');
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

  /// Auto-populates the stakeholder register on first visit when it is empty.
  ///
  /// Pulls from three sources so the user lands on a pre-filled table they
  /// can edit, rather than a blank screen:
  ///   1. Initiation Phase — Core Stakeholders (internal + external lists
  ///      captured during the Identify Stakeholders step).
  ///   2. Staffing Plan — every team member becomes a "Project Team"
  ///      stakeholder row so they show up in the matrix.
  ///   3. Common project stakeholders — a curated prompt list of roles
  ///      every project should consider (Sponsor, Steering Committee,
  ///      Customer, End User, Vendor, Regulator, etc.). The user keeps
  ///      what applies and deletes the rest.
  ///
  /// Silently no-ops if the register already has entries — the user's
  /// manual edits are never overwritten.
  Future<void> _maybeAutoPopulateStakeholders() async {
    if (!mounted) return;
    final projectData = ProjectDataHelper.getProvider(context).projectData;
    if (projectData.stakeholderEntries.isNotEmpty) return;

    final List<StakeholderEntry> newEntries = [];
    final now = DateTime.now();
    String id(String seed) =>
        '${now.microsecondsSinceEpoch}_${seed.hashCode.abs()}';

    // ── 1. Initiation Phase core stakeholders ──────────────────────────
    final coreStakeholders = projectData.coreStakeholdersData;
    if (coreStakeholders != null) {
      final solutionData =
          coreStakeholders.solutionStakeholderData.firstWhere(
        (s) => s.solutionTitle == projectData.preferredSolution?.title,
        orElse: () => coreStakeholders.solutionStakeholderData.isNotEmpty
            ? coreStakeholders.solutionStakeholderData.first
            : SolutionStakeholderData(),
      );

      void parseAndAdd(String text, String org) {
        for (var line in text.split('\n')) {
          final cleaned = line.replaceAll(RegExp(r'^[-*•]\s*'), '').trim();
          if (cleaned.isEmpty) continue;
          if (newEntries.any((e) =>
              e.name.toLowerCase() == cleaned.toLowerCase())) {
            continue;
          }
          newEntries.add(StakeholderEntry(
            id: id('init_$cleaned'),
            name: cleaned,
            organization: org,
            role: 'TBD',
            contactInfo: '',
            influence: 'Medium',
            interest: 'Medium',
            channel: 'Email',
            owner: 'Project Manager',
            notes: 'Auto-loaded from Initiation Phase',
            createdAt: now,
            updatedAt: now,
          ));
        }
      }

      parseAndAdd(solutionData.internalStakeholders, 'Internal');
      parseAndAdd(solutionData.externalStakeholders, 'External');
    }

    // ── 2. Project Team (from staffing plan) ──────────────────────────
    // Each team member becomes a stakeholder row tagged "Project Team" so
    // they appear in the matrix. This is distinct from the Project Team
    // Communication Roster section below — the roster is the contact
    // directory; these rows are the matrix entries.
    for (final m in projectData.teamMembers) {
      final name = m.name.trim();
      if (name.isEmpty) continue;
      if (newEntries.any((e) =>
          e.name.toLowerCase() == name.toLowerCase())) {
        continue;
      }
      newEntries.add(StakeholderEntry(
        id: id('pt_${m.id}'),
        name: name,
        organization: 'Project Team',
        role: m.role.isEmpty ? 'TBD' : m.role,
        contactInfo: m.email,
        influence: 'High',
        interest: 'High',
        channel: 'Email',
        owner: 'Project Manager',
        notes: 'Auto-loaded from staffing plan',
        createdAt: now,
        updatedAt: now,
      ));
    }

    // ── 3. Common project stakeholders prompt list ────────────────────
    // Curated set of roles every project should consider. The user keeps
    // the ones that apply and deletes the rest. Marked as "suggested" so
    // the user can tell where they came from.
    const commonStakeholders = <(String, String, String, String)>[
      // (name, organization, role, notes)
      ('Project Sponsor', 'Internal', 'Executive Sponsor',
          'Suggested — confirm name'),
      ('Steering Committee', 'Internal', 'Governance Body',
          'Suggested — confirm members'),
      ('Project Manager', 'Project Team', 'PM',
          'Suggested — confirm name'),
      ('Customer / Client', 'External', 'Funding Authority',
          'Suggested — confirm name'),
      ('End Users', 'External', 'User Group',
          'Suggested — identify representative'),
      ('Vendor / Supplier', 'External', 'Supplier',
          'Suggested — confirm primary contact'),
      ('Regulator / Compliance Authority', 'External', 'Regulator',
          'Suggested — identify jurisdiction'),
      ('Finance Department', 'Internal', 'Finance',
          'Suggested — confirm lead'),
      ('IT Department', 'Internal', 'IT',
          'Suggested — confirm lead'),
      ('HR Department', 'Internal', 'HR',
          'Suggested — confirm lead'),
      ('Legal / Contracts', 'Internal', 'Legal',
          'Suggested — confirm lead'),
      ('Quality Assurance', 'Internal', 'QA',
          'Suggested — confirm lead'),
      ('Health, Safety & Environment', 'Internal', 'HSE',
          'Suggested — confirm lead'),
      ('Communications / PR', 'Internal', 'Comms',
          'Suggested — confirm lead'),
      ('Community / Public', 'External', 'Affected Community',
          'Suggested — identify representative'),
    ];
    for (final (name, org, role, note) in commonStakeholders) {
      if (newEntries.any((e) =>
          e.name.toLowerCase() == name.toLowerCase())) {
        continue;
      }
      newEntries.add(StakeholderEntry(
        id: id('sugg_$name'),
        name: name,
        organization: org,
        role: role,
        contactInfo: '',
        influence: org == 'Internal' ? 'Medium' : 'High',
        interest: 'Medium',
        channel: 'Email',
        owner: 'Project Manager',
        notes: note,
        createdAt: now,
        updatedAt: now,
      ));
    }

    if (newEntries.isEmpty || !mounted) return;

    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'stakeholder_management',
      dataUpdater: (d) => d.copyWith(stakeholderEntries: newEntries),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pre-filled ${newEntries.length} suggested stakeholders. '
          'Review the list and delete any that don\'t apply.',
        ),
        duration: const Duration(seconds: 5),
      ),
    );
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

  /// Calls AI to review the current stakeholder register and suggest
  /// additions (stakeholders the project should consider but hasn't listed)
  /// and removals (stakeholders who are likely duplicates or not relevant).
  ///
  /// Shows a dialog with the AI's suggestions and prompts the user to
  /// update the table — they can accept additions, ignore suggestions, or
  /// dismiss the dialog without changes. Nothing is auto-applied; the
  /// user is always in control of the final list.
  Future<void> _aiReviewStakeholders() async {
    final projectData = ProjectDataHelper.getProvider(context).projectData;
    final entries = projectData.stakeholderEntries;

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Add at least one stakeholder before running AI review.')));
      return;
    }

    // Bail out gracefully if OpenAI isn't configured — don't crash the
    // tap. Surface a helpful message so the user knows why nothing
    // happened.
    if (!OpenAiConfig.isConfigured) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI not configured'),
          content: const Text(
              'OpenAI is not configured for this project, so the AI '
              'review is unavailable. You can still add or remove '
              'stakeholders manually using the buttons above the table.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    // Show a loading indicator while the AI is thinking.
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 16),
              Text('Reviewing stakeholders with AI…'),
            ],
          ),
        ),
      ),
    );

    final currentList = entries
        .map((e) => '- ${e.name}'
            '${e.organization.isNotEmpty ? ' (${e.organization})' : ''}'
            '${e.role.isNotEmpty ? ' — ${e.role}' : ''}')
        .join('\n');

    final projectName = projectData.projectName.isEmpty
        ? '(unnamed)'
        : projectData.projectName;
    final solutionTitle = projectData.preferredSolution?.title ?? '(none)';
    final objective = projectData.projectGoals.isEmpty
        ? '(not defined)'
        : projectData.projectGoals
            .map((g) => g.name.isEmpty ? g.description : g.name)
            .where((s) => s.isNotEmpty)
            .join('; ');

    final prompt = '''You are a project stakeholder analyst. Review the
current stakeholder register for the project below and suggest additions
and removals.

Project name: $projectName
Preferred solution: $solutionTitle
Project objective: $objective

Current stakeholder register:
$currentList

Return your review in this exact format (no markdown, no extra prose):

SUGGESTED ADDITIONS:
- <stakeholder name> | <organization> | <role> | <one-line reason>
- ...

SUGGESTED REMOVALS:
- <stakeholder name> | <one-line reason it may be a duplicate or not relevant>
- ...

Keep suggestions practical and specific to this project. If there is
nothing to add or remove, write "None" under that heading.''';

    String aiResponse;
    try {
      final service = OpenAiServiceSecure();
      aiResponse = await service.generateCompletion(prompt, maxTokens: 1500);
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // dismiss loading dialog
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI review failed: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading dialog
    if (!mounted) return;

    // Parse the AI response into additions / removals lists.
    final lines = aiResponse.split('\n');
    String section = '';
    final additions = <String>[];
    final removals = <String>[];
    for (final line in lines) {
      final t = line.trim();
      if (t.toUpperCase().startsWith('SUGGESTED ADDITIONS')) {
        section = 'add';
        continue;
      }
      if (t.toUpperCase().startsWith('SUGGESTED REMOVALS')) {
        section = 'remove';
        continue;
      }
      if (t.isEmpty) continue;
      if (t.startsWith('- ') || t.startsWith('• ')) {
        final item = t.substring(2).trim();
        if (section == 'add') additions.add(item);
        if (section == 'remove') removals.add(item);
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Stakeholder Review'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'The AI reviewed your stakeholder register and made the '
                  'following suggestions. Add the ones that apply — your '
                  'current list is not changed until you confirm.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                const Text('Suggested additions:',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (additions.isEmpty)
                  const Text('None',
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF9CA3AF)))
                else
                  ...additions.map((a) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(color: Color(0xFF10B981))),
                            Expanded(
                                child: Text(a,
                                    style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      )),
                const SizedBox(height: 16),
                const Text('Suggested removals:',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (removals.isEmpty)
                  const Text('None',
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF9CA3AF)))
                else
                  ...removals.map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(color: Color(0xFFEF4444))),
                            Expanded(
                                child: Text(r,
                                    style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          if (additions.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _applyAiAdditions(additions);
              },
              icon: const Icon(Icons.add, size: 16),
              label: Text('Add ${additions.length} suggested'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD84D),
                foregroundColor: const Color(0xFF1F2937),
              ),
            ),
        ],
      ),
    );
  }

  /// Parses AI-suggested additions (format: "Name | Org | Role | reason")
  /// and appends them to the stakeholder register. Skips entries whose
  /// name already exists (case-insensitive) to avoid duplicates.
  void _applyAiAdditions(List<String> additions) async {
    final projectData = ProjectDataHelper.getProvider(context).projectData;
    final existingNames = projectData.stakeholderEntries
        .map((e) => e.name.toLowerCase())
        .toSet();

    final now = DateTime.now();
    final newEntries = <StakeholderEntry>[];
    for (final line in additions) {
      final parts = line.split('|').map((s) => s.trim()).toList();
      if (parts.isEmpty) continue;
      final name = parts[0];
      if (name.isEmpty) continue;
      if (existingNames.contains(name.toLowerCase())) continue;
      newEntries.add(StakeholderEntry(
        id: '${now.microsecondsSinceEpoch}_${name.hashCode.abs()}',
        name: name,
        organization: parts.length > 1 ? parts[1] : 'External',
        role: parts.length > 2 ? parts[2] : 'TBD',
        contactInfo: '',
        influence: 'Medium',
        interest: 'Medium',
        channel: 'Email',
        owner: 'Project Manager',
        notes: parts.length > 3
            ? 'AI suggestion: ${parts[3]}'
            : 'AI suggestion — review and confirm',
        createdAt: now,
        updatedAt: now,
      ));
      existingNames.add(name.toLowerCase());
    }

    if (newEntries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No new stakeholders added — all suggestions already exist.')));
      return;
    }

    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'stakeholder_management',
      dataUpdater: (d) => d.copyWith(
        stakeholderEntries: [...d.stakeholderEntries, ...newEntries],
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Added ${newEntries.length} AI-suggested stakeholder(s). '
            'Review and edit details as needed.'),
      ),
    );
  }

  /// Calls the AI to suggest a matrix rating (Keep Satisfied / Manage
  /// Closely / Monitor / Keep Informed) for each stakeholder based on
  /// project context and each stakeholder's role/organization. The
  /// suggestion is stored on `aiSuggestedRating` and the manual
  /// influence/interest fields are also updated so the matrix display
  /// and the Stakeholder Mapping tab stay in sync.
  Future<void> _aiSuggestRatings() async {
    final projectData = ProjectDataHelper.getProvider(context).projectData;
    final entries = projectData.stakeholderEntries;

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Add at least one stakeholder before running AI rating suggestions.')));
      return;
    }

    if (!OpenAiConfig.isConfigured) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI not configured'),
          content: const Text(
              'OpenAI is not configured for this project, so AI rating '
              'suggestions are unavailable. You can still set ratings '
              'manually using the dropdown in the Stakeholder Mapping tab.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 16),
              Text('Suggesting ratings with AI…'),
            ],
          ),
        ),
      ),
    );

    final projectName =
        projectData.projectName.isEmpty ? '(unnamed)' : projectData.projectName;
    final solutionTitle = projectData.preferredSolution?.title ?? '(none)';
    final objective = projectData.projectGoals.isEmpty
        ? '(not defined)'
        : projectData.projectGoals
            .map((g) => g.name.isEmpty ? g.description : g.name)
            .where((s) => s.isNotEmpty)
            .join('; ');

    final stakeholderList = entries
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value.name}'
            '${e.value.organization.isNotEmpty ? ' (${e.value.organization})' : ''}'
            '${e.value.role.isNotEmpty ? ' — ${e.value.role}' : ''}'
            '${e.value.notes.isNotEmpty ? ' | notes: ${e.value.notes}' : ''}')
        .join('\n');

    final prompt = '''You are a senior project stakeholder analyst. For each
stakeholder listed below, recommend one of the four standard influence /
interest matrix designations:

- "Manage Closely" — high influence, high interest (key players; engage
  regularly and co-create)
- "Keep Satisfied" — high influence, low interest (powerful but passive;
  keep them supportive with targeted updates)
- "Keep Informed" — low influence, high interest (interested but limited
  power; update regularly so they stay supportive)
- "Monitor" — low influence, low interest (monitor for changes; minimal
  effort)

Project context:
- Project name: $projectName
- Preferred solution: $solutionTitle
- Project objective: $objective

Stakeholder register:
$stakeholderList

Return your recommendations in this exact format (one line per
stakeholder, no markdown, no extra prose):

<stakeholder name> | <Manage Closely | Keep Satisfied | Keep Informed | Monitor> | <one short reason>

Use the stakeholder's name exactly as it appears above. If two
stakeholders have the same name, also append the organization in
parentheses to disambiguate.''';

    String aiResponse;
    try {
      final service = OpenAiServiceSecure();
      aiResponse = await service.generateCompletion(prompt, maxTokens: 1500);
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // dismiss loading dialog
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI rating suggestion failed: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading dialog
    if (!mounted) return;

    // Parse the AI response into a map of stakeholder name → suggested rating.
    final suggestions = <String, String>{};
    for (final line in aiResponse.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (t.startsWith('- ') || t.startsWith('• ')) {
        // Skip list bullet markers; the actual content is after.
      }
      final parts = t.split('|').map((s) => s.trim()).toList();
      if (parts.length < 2) continue;
      final name = parts[0];
      final rating = parts[1];
      // Normalize the rating to one of the four canonical values.
      final lower = rating.toLowerCase();
      String normalized;
      if (lower.contains('manage closely')) {
        normalized = 'Manage Closely';
      } else if (lower.contains('keep satisfied')) {
        normalized = 'Keep Satisfied';
      } else if (lower.contains('keep informed')) {
        normalized = 'Keep Informed';
      } else if (lower.contains('monitor')) {
        normalized = 'Monitor';
      } else {
        continue; // Skip unrecognized ratings.
      }
      suggestions[name] = normalized;
    }

    if (suggestions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'AI returned no rating suggestions. Try again or set ratings manually.')));
      return;
    }

    // Apply suggestions to the stakeholder entries. We update both
    // `aiSuggestedRating` and the manual influence/interest fields so the
    // matrix display, the Stakeholder Mapping tab, and the filter dropdown
    // all stay in sync.
    final updatedEntries = <StakeholderEntry>[];
    int appliedCount = 0;
    for (final entry in entries) {
      // Try exact name match first, then case-insensitive, then with
      // organization appended.
      String? suggested;
      if (suggestions.containsKey(entry.name)) {
        suggested = suggestions[entry.name]!;
      } else {
        final lowerName = entry.name.toLowerCase();
        for (final key in suggestions.keys) {
          if (key.toLowerCase() == lowerName) {
            suggested = suggestions[key]!;
            break;
          }
        }
      }
      if (suggested == null) {
        updatedEntries.add(entry);
        continue;
      }
      appliedCount++;
      // Map the suggested rating back to influence/interest so the
      // matrix and filter dropdown stay consistent with the suggestion.
      String influence;
      String interest;
      switch (suggested) {
        case 'Manage Closely':
          influence = 'High';
          interest = 'High';
          break;
        case 'Keep Satisfied':
          influence = 'High';
          interest = 'Low';
          break;
        case 'Keep Informed':
          influence = 'Low';
          interest = 'High';
          break;
        case 'Monitor':
        default:
          influence = 'Low';
          interest = 'Low';
          break;
      }
      updatedEntries.add(entry.copyWith(
        aiSuggestedRating: suggested,
        influence: influence,
        interest: interest,
        updatedAt: DateTime.now(),
      ));
    }

    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'stakeholder_management',
      dataUpdater: (d) => d.copyWith(stakeholderEntries: updatedEntries),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'AI suggested ratings for $appliedCount of ${entries.length} '
            'stakeholder(s). Review and adjust as needed.'),
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
        if (e.objective.isNotEmpty) {
          plansBuffer.writeln('   Objective: ${e.objective}');
        }
        if (e.method.isNotEmpty) plansBuffer.writeln('   Method: ${e.method}');
        if (e.frequency.isNotEmpty) {
          plansBuffer.writeln('   Frequency: ${e.frequency}');
        }
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
            if (line.trim().isNotEmpty) {
              plansBuffer.writeln('     - ${line.trim()}');
            }
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
                    'Stakeholder Management Plan',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827)),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Define how each influence/interest stakeholder group will be '
                    'engaged, communicated with, and managed throughout the project. '
                    'AI should help develop a landing plan that states how each of '
                    'the sections would be communicated with (email, meetings, '
                    'announcements, etc.)',
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
        accentColor: const Color(0xFFFFC812),
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

class _InfluenceInterestMatrix extends StatefulWidget {
  const _InfluenceInterestMatrix({required this.stakeholders});

  final List<StakeholderEntry> stakeholders;

  @override
  State<_InfluenceInterestMatrix> createState() =>
      _InfluenceInterestMatrixState();
}

class _InfluenceInterestMatrixState extends State<_InfluenceInterestMatrix> {
  /// Per-quadrant sort mode. Keys are the four rating labels
  /// ('Keep Satisfied', 'Manage Closely', 'Monitor', 'Keep Informed').
  /// Values: 'name_asc', 'name_desc', 'org_asc', 'role_asc'.
  final Map<String, String> _sortModes = {
    'Keep Satisfied': 'name_asc',
    'Manage Closely': 'name_asc',
    'Monitor': 'name_asc',
    'Keep Informed': 'name_asc',
  };

  /// Per-quadrant expanded state. When true, the quadrant shows all
  /// stakeholders in a scrollable list (with a sort dropdown). When false,
  /// it shows just a count and the first few chips.
  final Map<String, bool> _expanded = {
    'Keep Satisfied': false,
    'Manage Closely': false,
    'Monitor': false,
    'Keep Informed': false,
  };

  List<StakeholderEntry> _sorted(
      String rating, List<StakeholderEntry> list) {
    final sorted = [...list];
    final mode = _sortModes[rating] ?? 'name_asc';
    int cmp(StakeholderEntry a, StakeholderEntry b) {
      switch (mode) {
        case 'name_desc':
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case 'org_asc':
          return a.organization.toLowerCase().compareTo(
                  b.organization.toLowerCase());
        case 'role_asc':
          return a.role.toLowerCase().compareTo(b.role.toLowerCase());
        case 'name_asc':
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    }

    sorted.sort(cmp);
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    // Bucket stakeholders by derived matrix rating. This fixes the previous
    // bug where Medium influence/interest values were silently dropped from
    // the matrix display. We use the same bucketing logic as the filter
    // dropdown (Medium → nearest higher-attention quadrant) so the matrix
    // and the filter always agree.
    final keepSatisfied = <StakeholderEntry>[];
    final manageClosely = <StakeholderEntry>[];
    final monitor = <StakeholderEntry>[];
    final keepInformed = <StakeholderEntry>[];
    for (final s in widget.stakeholders) {
      switch (s.derivedMatrixRating) {
        case 'Keep Satisfied':
          keepSatisfied.add(s);
          break;
        case 'Manage Closely':
          manageClosely.add(s);
          break;
        case 'Monitor':
          monitor.add(s);
          break;
        case 'Keep Informed':
          keepInformed.add(s);
          break;
      }
    }

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
                      color: const Color(0xFFFFF8E1), // Blue
                      accentColor: const Color(0xFFFFC812),
                      stakeholders: _sorted('Keep Satisfied', keepSatisfied),
                    ),
                  ),
                  Expanded(
                    child: _matrixQuadrant(
                      label: 'Manage Closely (Key Players)',
                      color: const Color(0xFFFEF2F2), // Red
                      accentColor: const Color(0xFFEF4444),
                      stakeholders:
                          _sorted('Manage Closely', manageClosely),
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
                      stakeholders: _sorted('Monitor', monitor),
                    ),
                  ),
                  Expanded(
                    child: _matrixQuadrant(
                      label: 'Keep Informed',
                      color: const Color(0xFFECFDF5), // Green
                      accentColor: const Color(0xFF10B981),
                      stakeholders: _sorted('Keep Informed', keepInformed),
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

  /// Resolve the canonical rating key from the (possibly longer) quadrant
  /// label so we can look up sort/expand state.
  String _ratingKeyFor(String label) {
    if (label.startsWith('Manage Closely')) return 'Manage Closely';
    if (label.startsWith('Keep Satisfied')) return 'Keep Satisfied';
    if (label.startsWith('Monitor')) return 'Monitor';
    if (label.startsWith('Keep Informed')) return 'Keep Informed';
    return label;
  }

  Widget _matrixQuadrant({
    required String label,
    required Color color,
    required Color accentColor,
    required List<StakeholderEntry> stakeholders,
  }) {
    final ratingKey = _ratingKeyFor(label);
    final isExpanded = _expanded[ratingKey] ?? false;
    final sortMode = _sortModes[ratingKey] ?? 'name_asc';

    return Container(
      // When expanded, the quadrant grows tall enough to show the full list.
      // Otherwise, the original 140px height is preserved.
      height: isExpanded ? 320 : 140,
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
              // Count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${stakeholders.length}',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accentColor),
                ),
              ),
            ],
          ),
          // Sort + expand controls (only render when there are stakeholders).
          if (stakeholders.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                // Sort dropdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.15)),
                    ),
                    child: DropdownButton<String>(
                      value: sortMode,
                      underline: const SizedBox(),
                      isDense: true,
                      isExpanded: true,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: accentColor),
                      icon: Icon(Icons.sort, size: 12, color: accentColor),
                      items: const [
                        DropdownMenuItem(
                            value: 'name_asc', child: Text('Sort: Name A→Z')),
                        DropdownMenuItem(
                            value: 'name_desc', child: Text('Sort: Name Z→A')),
                        DropdownMenuItem(
                            value: 'org_asc',
                            child: Text('Sort: Organization')),
                        DropdownMenuItem(
                            value: 'role_asc', child: Text('Sort: Role')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _sortModes[ratingKey] = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Expand / collapse toggle
                InkWell(
                  onTap: () =>
                      setState(() => _expanded[ratingKey] = !isExpanded),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isExpanded
                              ? Icons.unfold_less
                              : Icons.unfold_more,
                          size: 12,
                          color: accentColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isExpanded ? 'Show less' : 'Show all',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accentColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Magnify / zoom button
                InkWell(
                  onTap: () => _openMagnifiedView(
                    context,
                    label: label,
                    color: color,
                    accentColor: accentColor,
                    stakeholders: stakeholders,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.zoom_out_map,
                          size: 12,
                          color: accentColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Expand',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accentColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
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
                : isExpanded
                    ? ListView(
                        padding: EdgeInsets.zero,
                        children: stakeholders
                            .map((s) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: _stakeholderChip(s, accentColor),
                                ))
                            .toList(),
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

  void _openMagnifiedView(
    BuildContext context, {
    required String label,
    required Color color,
    required Color accentColor,
    required List<StakeholderEntry> stakeholders,
  }) {
    final ratingKey = _ratingKeyFor(label);
    final sortMode = _sortModes[ratingKey] ?? 'name_asc';
    final sorted = _sorted(ratingKey, stakeholders);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${stakeholders.length} stakeholder${stakeholders.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: Icon(Icons.close, color: accentColor),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              // Sort controls
              if (stakeholders.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort, size: 16, color: accentColor),
                        const SizedBox(width: 8),
                        Text(
                          'Sort: $sortMode',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Stakeholder list
              Expanded(
                child: stakeholders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: accentColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No stakeholders in this category',
                              style: TextStyle(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                color: accentColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: sorted
                              .map((s) => _magnifiedStakeholderChip(s, accentColor))
                              .toList(),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _magnifiedStakeholderChip(StakeholderEntry s, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.name.isEmpty ? 'Unnamed' : s.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (s.role.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              s.role,
              style: TextStyle(
                fontSize: 13,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (s.organization.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              s.organization,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.6),
              ),
            ),
          ],
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
    required this.mappingTable,
    required this.planTable,
    required this.onAdd,
    required this.onSearch,
    required this.onAiReview,
    required this.onAiSuggestRatings,
    required this.onExportPdf,
    required this.matrixFilter,
    required this.onMatrixFilterChanged,
    required this.announcements,
    required this.loadingAnnouncements,
    required this.onSaveAnnouncement,
    required this.onDeleteAnnouncement,
  });

  final int activeTabIndex;
  final ValueChanged<int> onTabChanged;
  final Widget stakeholderTable;
  final Widget mappingTable;
  final Widget planTable;
  final VoidCallback onAdd;
  final ValueChanged<String> onSearch;
  final VoidCallback onAiReview;
  final VoidCallback onAiSuggestRatings;
  final VoidCallback onExportPdf;
  final String matrixFilter;
  final ValueChanged<String> onMatrixFilterChanged;

  // ── Announcements tab (index 3) ─────────────────────────────────────
  final List<StakeholderAnnouncement> announcements;
  final bool loadingAnnouncements;
  final Future<void> Function(StakeholderAnnouncement) onSaveAnnouncement;
  final Future<void> Function(String) onDeleteAnnouncement;

  @override
  Widget build(BuildContext context) {
    // The Announcements tab (index 3) has its own composer UI + template
    // picker, so we hide the standard search/add/export toolbar when it
    // is active. The other three tabs share the standard toolbar.
    final bool isAnnouncementsTab = activeTabIndex == 3;
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
                _tabButton(title: 'Stakeholder Mapping', index: 1),
                _tabButton(title: 'Engagement Plans', index: 2),
                _tabButton(title: 'Announcements', index: 3),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Toolbar row 1: search + add + export PDF ──
                // Export PDF lives here (right side of the toolbar) instead
                // of in the PlanningPhaseHeader because the header's Wrap
                // row visually sits above the sidebar zone. Moving the
                // button into the Engagement Section toolbar keeps it out
                // of the sidebar column entirely.
                //
                // The Announcements tab (index 3) has its own composer +
                // template picker UI, so the standard search/add/export
                // toolbar is hidden when that tab is active.
                if (!isAnnouncementsTab) ...[
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
                      OutlinedButton.icon(
                        onPressed: onExportPdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined,
                            size: 18),
                        label: const Text('Export PDF',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                          foregroundColor: const Color(0xFF1F2937),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add),
                        label: Text(activeTabIndex == 2
                            ? 'Add plan'
                            : 'Add stakeholder'),
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
                  // ── Toolbar row 2: matrix filter + AI buttons ──
                  // The matrix filter + AI Review buttons only show on the
                  // Stakeholders tab. On the Stakeholder Mapping tab we show
                  // the AI Suggest Ratings button instead. The Engagement
                  // Plans tab shows nothing here.
                  if (activeTabIndex == 0 || activeTabIndex == 1) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (activeTabIndex == 0) ...[
                          // Matrix quarter filter
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.filter_list,
                                    size: 16, color: Color(0xFF6B7280)),
                                const SizedBox(width: 8),
                                const Text('Filter by matrix quarter:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280))),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: matrixFilter,
                                  underline: const SizedBox(),
                                  isDense: true,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827)),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'all',
                                        child: Text('All stakeholders')),
                                    DropdownMenuItem(
                                        value: 'manage_closely',
                                        child: Text(
                                            'Manage Closely (High influence / High interest)')),
                                    DropdownMenuItem(
                                        value: 'keep_satisfied',
                                        child: Text(
                                            'Keep Satisfied (High influence / Low interest)')),
                                    DropdownMenuItem(
                                        value: 'keep_informed',
                                        child: Text(
                                            'Keep Informed (Low influence / High interest)')),
                                    DropdownMenuItem(
                                        value: 'monitor',
                                        child: Text(
                                            'Monitor (Low influence / Low interest)')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) onMatrixFilterChanged(v);
                                  },
                                ),
                              ],
                            ),
                          ),
                          // AI review stakeholders
                          ElevatedButton.icon(
                            onPressed: onAiReview,
                            icon: const Icon(Icons.auto_awesome,
                                size: 16, color: Color(0xFF1F2937)),
                            label: const Text('AI Review Stakeholders',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937))),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC107),
                              foregroundColor: const Color(0xFF1F2937),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                        if (activeTabIndex == 1)
                          // AI suggest ratings (Stakeholder Mapping tab)
                          ElevatedButton.icon(
                            onPressed: onAiSuggestRatings,
                            icon: const Icon(Icons.auto_awesome,
                                size: 16, color: Color(0xFF1F2937)),
                            label: const Text('AI Suggest Ratings',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937))),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC107),
                              foregroundColor: const Color(0xFF1F2937),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
                IndexedStack(
                  index: activeTabIndex,
                  children: [
                    stakeholderTable,
                    mappingTable,
                    planTable,
                    _AnnouncementsTab(
                      announcements: announcements,
                      loading: loadingAnnouncements,
                      onSave: onSaveAnnouncement,
                      onDelete: onDeleteAnnouncement,
                    ),
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
      const _TableColumnDef('#', 56),
      const _TableColumnDef('Stakeholder', 240),
      const _TableColumnDef('Organization', 160),
      const _TableColumnDef('Role/Title', 180),
      const _TableColumnDef('Contact Info', 220),
      const _TableColumnDef('Influence', 130),
      const _TableColumnDef('Interest', 130),
      const _TableColumnDef('Channel', 150),
      const _TableColumnDef('Owner', 160),
      const _TableColumnDef('Notes', 260),
      const _TableColumnDef('Actions', 130),
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
              _RowActions(
                itemName:
                    'stakeholder "${entries[index].name.trim().isEmpty ? 'Untitled' : entries[index].name.trim()}"',
                onDelete: () => onDelete(entries[index].id),
                entry: entries[index],
                onEdit: onChanged,
              ),
            ],
          ),
      ],
    );
  }
}

/// Color-coded mapping table — groups each stakeholder into one of the
/// four influence/interest matrix designations (Manage Closely / Keep
/// Satisfied / Keep Informed / Monitor). Each rating cell is colored to
/// match the matrix quadrant:
///   - Manage Closely → red/pink
///   - Keep Satisfied  → blue
///   - Keep Informed   → green
///   - Monitor         → gray
/// The rating shown is the AI suggestion if one exists, otherwise the
/// rating derived from the stakeholder's manual influence/interest values.
/// The user can override either by editing the dropdown directly in
/// this tab or by running "AI Suggest Ratings" (button in the toolbar
/// above this table).
class _StakeholderMappingTable extends StatelessWidget {
  const _StakeholderMappingTable({
    required this.entries,
    required this.onChanged,
    this.onDelete,
  });

  final List<StakeholderEntry> entries;
  final ValueChanged<StakeholderEntry> onChanged;
  final ValueChanged<String>? onDelete;

  /// Quadrant color palette — must stay in sync with
  /// [_InfluenceInterestMatrix._matrixQuadrant].
  static const Map<String, _QuadrantPalette> _palettes = {
    'Manage Closely': _QuadrantPalette(
        name: 'Manage Closely',
        bg: Color(0xFFFEF2F2),
        accent: Color(0xFFEF4444),
        description: 'High influence / High interest'),
    'Keep Satisfied': _QuadrantPalette(
        name: 'Keep Satisfied',
        bg: Color(0xFFFFF8E1),
        accent: Color(0xFFFFC812),
        description: 'High influence / Low interest'),
    'Keep Informed': _QuadrantPalette(
        name: 'Keep Informed',
        bg: Color(0xFFECFDF5),
        accent: Color(0xFF10B981),
        description: 'Low influence / High interest'),
    'Monitor': _QuadrantPalette(
        name: 'Monitor',
        bg: Color(0xFFF9FAFB),
        accent: Color(0xFF6B7280),
        description: 'Low influence / Low interest'),
  };

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _SectionEmptyState(
        title: 'No stakeholders to map',
        message: 'Add stakeholders on the Stakeholders tab first, then use '
            '"AI Suggest Ratings" to auto-classify them into matrix quadrants.',
        icon: Icons.grid_view_outlined,
      );
    }

    final columns = [
      const _TableColumnDef('#', 56),
      const _TableColumnDef('Stakeholder', 200),
      const _TableColumnDef('Organization', 150),
      const _TableColumnDef('Role/Title', 160),
      const _TableColumnDef('Influence', 110),
      const _TableColumnDef('Interest', 110),
      const _TableColumnDef('Suggested Rating', 220),
      const _TableColumnDef('Source', 130),
      const _TableColumnDef('Actions', 100),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Quadrant legend — color swatches with their labels.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: _palettes.values.map((p) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: p.bg,
                      border: Border.all(color: p.accent, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${p.name} (${p.description})',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: p.accent),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _EditableTable(
          columns: columns,
          rows: [
            for (int index = 0; index < entries.length; index++)
              _EditableRow(
                key: ValueKey('mapping_${entries[index].id}'),
                columns: columns,
                cells: _buildRowCells(index, entries[index]),
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildRowCells(int index, StakeholderEntry entry) {
    // Use the AI-suggested rating if available, otherwise derive from
    // the manual influence/interest values.
    final rating = entry.aiSuggestedRating.isNotEmpty
        ? entry.aiSuggestedRating
        : entry.derivedMatrixRating;
    final palette = _palettes[rating] ?? _palettes['Monitor']!;
    final source = entry.aiSuggestedRating.isNotEmpty ? 'AI' : 'Manual';

    return [
      _IndexCell(number: index + 1),
      _TextCell(
        value: entry.name,
        fieldKey: 'mapping_${entry.id}_name',
        hintText: 'Name',
        onChanged: (value) => onChanged(entry.copyWith(name: value)),
      ),
      _TextCell(
        value: entry.organization,
        fieldKey: 'mapping_${entry.id}_organization',
        hintText: 'Organization',
        onChanged: (value) => onChanged(entry.copyWith(organization: value)),
      ),
      _TextCell(
        value: entry.role,
        fieldKey: 'mapping_${entry.id}_role',
        hintText: 'Role/Title',
        onChanged: (value) => onChanged(entry.copyWith(role: value)),
      ),
      _DropdownCell(
        value: entry.influence,
        fieldKey: 'mapping_${entry.id}_influence',
        options: const ['High', 'Medium', 'Low'],
        onChanged: (value) => onChanged(entry.copyWith(
            influence: value, updatedAt: DateTime.now())),
      ),
      _DropdownCell(
        value: entry.interest,
        fieldKey: 'mapping_${entry.id}_interest',
        options: const ['High', 'Medium', 'Low'],
        onChanged: (value) => onChanged(entry.copyWith(
            interest: value, updatedAt: DateTime.now())),
      ),
      // Color-coded suggested rating cell — a dropdown that lets the
      // user override the rating. Selecting a new rating updates both
      // the aiSuggestedRating and the manual influence/interest so the
      // matrix, filter, and this tab stay in sync.
      _RatingCell(
        rating: rating,
        palette: palette,
        onChanged: (newRating) {
          String influence;
          String interest;
          switch (newRating) {
            case 'Manage Closely':
              influence = 'High';
              interest = 'High';
              break;
            case 'Keep Satisfied':
              influence = 'High';
              interest = 'Low';
              break;
            case 'Keep Informed':
              influence = 'Low';
              interest = 'High';
              break;
            case 'Monitor':
            default:
              influence = 'Low';
              interest = 'Low';
              break;
          }
          onChanged(entry.copyWith(
            aiSuggestedRating: newRating,
            influence: influence,
            interest: interest,
            updatedAt: DateTime.now(),
          ));
        },
      ),
      _SourceCell(source: source),
      _MappingRowActions(
        entry: entry,
        onEdit: onChanged,
        onDelete: onDelete,
      ),
    ];
  }
}

/// Quadrant color palette descriptor.
class _QuadrantPalette {
  const _QuadrantPalette({
    required this.name,
    required this.bg,
    required this.accent,
    required this.description,
  });

  final String name;
  final Color bg;
  final Color accent;
  final String description;
}

/// Color-coded rating cell. The cell's background color matches the
/// matrix quadrant the rating falls in.
class _RatingCell extends StatelessWidget {
  const _RatingCell({
    required this.rating,
    required this.palette,
    required this.onChanged,
  });

  final String rating;
  final _QuadrantPalette palette;
  final ValueChanged<String> onChanged;

  static const _options = [
    'Manage Closely',
    'Keep Satisfied',
    'Keep Informed',
    'Monitor',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.accent.withValues(alpha: 0.4)),
      ),
      child: DropdownButton<String>(
        value: _options.contains(rating) ? rating : 'Monitor',
        underline: const SizedBox(),
        isExpanded: true,
        isDense: true,
        icon: Icon(Icons.arrow_drop_down, color: palette.accent, size: 18),
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: palette.accent),
        items: _options
            .map((option) => DropdownMenuItem(
                  value: option,
                  child: Text(option),
                ))
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

/// Small badge showing whether the rating was AI-suggested or set
/// manually.
class _SourceCell extends StatelessWidget {
  const _SourceCell({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final isAi = source == 'AI';
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isAi
              ? const Color(0xFFFFC107).withValues(alpha: 0.15)
              : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          source,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isAi
                  ? const Color(0xFFB45309)
                  : const Color(0xFF6B7280)),
        ),
      ),
    );
  }
}

/// Actions cell for the stakeholder mapping table — Edit + Delete buttons.
class _MappingRowActions extends StatelessWidget {
  const _MappingRowActions({
    required this.entry,
    required this.onEdit,
    this.onDelete,
  });

  final StakeholderEntry entry;
  final ValueChanged<StakeholderEntry> onEdit;
  final ValueChanged<String>? onDelete;

  @override
  Widget build(BuildContext context) {
    return _TableFieldShell(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Edit stakeholder',
            child: IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: Color(0xFF1F2937)),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(
                  minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () => _openEditDialog(context),
            ),
          ),
          if (onDelete != null)
            Tooltip(
              message: 'Delete stakeholder',
              child: IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Color(0xFFEF4444)),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: () => _confirmDelete(context),
              ),
            ),
        ],
      ),
    );
  }

  void _openEditDialog(BuildContext context) {
    final nameController = TextEditingController(text: entry.name);
    final orgController = TextEditingController(text: entry.organization);
    final roleController = TextEditingController(text: entry.role);
    String influence = entry.influence;
    String interest = entry.interest;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Stakeholder'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Stakeholder Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orgController,
                    decoration: const InputDecoration(
                      labelText: 'Organization',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: roleController,
                    decoration: const InputDecoration(
                      labelText: 'Role/Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: influence,
                          decoration: const InputDecoration(
                            labelText: 'Influence',
                            border: OutlineInputBorder(),
                          ),
                          items: ['High', 'Medium', 'Low']
                              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => influence = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: interest,
                          decoration: const InputDecoration(
                            labelText: 'Interest',
                            border: OutlineInputBorder(),
                          ),
                          items: ['High', 'Medium', 'Low']
                              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => interest = v);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                onEdit(entry.copyWith(
                  name: nameController.text.trim(),
                  organization: orgController.text.trim(),
                  role: roleController.text.trim(),
                  influence: influence,
                  interest: interest,
                  updatedAt: DateTime.now(),
                ));
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Stakeholder'),
        content: Text('Are you sure you want to delete ${entry.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && onDelete != null) onDelete!(entry.id);
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
      const _TableColumnDef('Stakeholder', 220),
      const _TableColumnDef('Group', 150),
      const _TableColumnDef('Manage Closely', 120),
      const _TableColumnDef('Objective', 240),
      const _TableColumnDef('Method', 160),
      const _TableColumnDef('Frequency', 140),
      const _TableColumnDef('Owner', 150),
      const _TableColumnDef('Status', 130),
      const _TableColumnDef('Next Touchpoint', 160),
      const _TableColumnDef('Notes', 220),
      const _TableColumnDef('Actions', 130),
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
          // Per-cell voice/AI/format icons disabled — these actions live at
          // the row level via [_RowActions] instead.
          enableVoice: false,
          enableKazAi: false,
          enableTextFormatting: false,
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
      // Per-cell voice/AI/format icons disabled — these actions live at the
      // row level via [_RowActions] / the expanded panel header instead.
      enableVoice: false,
      enableKazAi: false,
      enableTextFormatting: false,
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
  final List<Widget> rows;

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
        // Per-cell voice/AI/format icons are disabled here to keep the
        // table legible. These actions are surfaced once per row via
        // [_RowActions] at the end of each row instead — see the user
        // feedback about per-cell icons taking up too much space.
        enableVoice: false,
        enableKazAi: false,
        enableTextFormatting: false,
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

/// Row-level action bar that replaces the per-cell voice/AI/delete icons.
///
/// Why this exists: previously every text cell in the stakeholder and
/// engagement-plan tables rendered its own mic + sparkles + trash icons
/// (because the cells used [VoiceTextFormField] with all features enabled).
/// That made each row visually noisy and stole horizontal space from the
/// actual content. The user asked for these actions to be available
/// "for the entire row, not each cell" — so we now disable them per-cell
/// and surface them once here, at the end of the row.
///
/// The bar is intentionally compact (three small icon buttons) so it fits
/// in a narrow trailing column.
class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.itemName,
    required this.onDelete,
    this.entry,
    this.onEdit,
  });

  final String itemName;
  final VoidCallback onDelete;
  final StakeholderEntry? entry;
  final ValueChanged<StakeholderEntry>? onEdit;

  @override
  Widget build(BuildContext context) {
    return _TableFieldShell(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Voice input (row-level)',
            child: IconButton(
              icon: const Icon(Icons.mic_outlined,
                  size: 18, color: Color(0xFFB45309)),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(
                  minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Tap a text field in this row to use voice input — '
                        'the mic icon now lives inside the field only when '
                        'focused.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
          ),
          Tooltip(
            message: 'AI assist (row-level)',
            child: IconButton(
              icon: const Icon(Icons.auto_awesome_outlined,
                  size: 18, color: Color(0xFFB45309)),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(
                  minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Use the "AI Review Stakeholders" button above the '
                        'table to get AI-suggested additions and removals.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
          ),
          if (entry != null && onEdit != null)
            Tooltip(
              message: 'Edit stakeholder',
              child: IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: Color(0xFF1F2937)),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: () => _openEditDialog(context),
              ),
            ),
          Tooltip(
            message: 'Delete row',
            child: IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Color(0xFFEF4444)),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(
                  minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () => _confirmDelete(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Stakeholder'),
        content: Text('Are you sure you want to delete $itemName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }

  void _openEditDialog(BuildContext context) {
    if (entry == null || onEdit == null) return;
    final e = entry!;
    final nameController = TextEditingController(text: e.name);
    final orgController = TextEditingController(text: e.organization);
    final roleController = TextEditingController(text: e.role);
    final contactController = TextEditingController(text: e.contactInfo);
    final channelController = TextEditingController(text: e.channel);
    final ownerController = TextEditingController(text: e.owner);
    final notesController = TextEditingController(text: e.notes);
    String influence = e.influence;
    String interest = e.interest;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Stakeholder'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Stakeholder Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orgController,
                    decoration: const InputDecoration(
                      labelText: 'Organization',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: roleController,
                    decoration: const InputDecoration(
                      labelText: 'Role/Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Info (Email/Phone)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: influence,
                          decoration: const InputDecoration(
                            labelText: 'Influence',
                            border: OutlineInputBorder(),
                          ),
                          items: ['High', 'Medium', 'Low']
                              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => influence = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: interest,
                          decoration: const InputDecoration(
                            labelText: 'Interest',
                            border: OutlineInputBorder(),
                          ),
                          items: ['High', 'Medium', 'Low']
                              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => interest = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: channelController,
                    decoration: const InputDecoration(
                      labelText: 'Channel',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ownerController,
                    decoration: const InputDecoration(
                      labelText: 'Owner',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                onEdit!(e.copyWith(
                  name: nameController.text.trim(),
                  organization: orgController.text.trim(),
                  role: roleController.text.trim(),
                  contactInfo: contactController.text.trim(),
                  channel: channelController.text.trim(),
                  owner: ownerController.text.trim(),
                  notes: notesController.text.trim(),
                  influence: influence,
                  interest: interest,
                ));
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                      SizedBox(height: 4),
                      Text(
                        'All Project Team members (pulled from the staffing plan). '
                        'Email is required for every PT member — especially for '
                        'positions that do not have site access and must be '
                        'engaged out-of-band.',
                        style: TextStyle(
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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Announcements tab (4th tab of _EngagementSection)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Per user spec: "A fourth tab should be included here for Announcements
// and should have announcement templates that can be used for each
// Engagement Plan/level including the project team section."
//
// Layout:
//   1. Template picker — chips grouped by audience level (5 groups).
//      Tapping a chip pre-fills the composer with the template's subject
//      and body, but the user can still tailor before saving.
//   2. Composer — title, audience, channel, status, body, Save / Cancel.
//      Collapsed by default; expands when "New Announcement" is tapped
//      or a template chip is picked.
//   3. Saved announcements feed — list of cards showing title, audience
//      pill, channel pill, status pill, created date, body preview,
//      edit / delete actions.
//
// All state is local to the widget except persistence, which is delegated
// to the parent via onSave / onDelete callbacks (Firestore subcollection).
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _AnnouncementsTab extends StatefulWidget {
  const _AnnouncementsTab({
    required this.announcements,
    required this.loading,
    required this.onSave,
    required this.onDelete,
  });

  final List<StakeholderAnnouncement> announcements;
  final bool loading;
  final Future<void> Function(StakeholderAnnouncement) onSave;
  final Future<void> Function(String) onDelete;

  @override
  State<_AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<_AnnouncementsTab> {
  bool _composerOpen = false;
  bool _isEditing = false;
  String _editingId = '';

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _audienceLevel = 'Manage Closely';
  String _channel = 'Email';
  String _status = 'Draft';
  String _templateId = '';

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _openComposerForNew() {
    setState(() {
      _isEditing = false;
      _editingId = '';
      _templateId = '';
      _titleController.clear();
      _bodyController.clear();
      _audienceLevel = 'Manage Closely';
      _channel = 'Email';
      _status = 'Draft';
      _composerOpen = true;
    });
  }

  void _openComposerForEdit(StakeholderAnnouncement a) {
    setState(() {
      _isEditing = true;
      _editingId = a.id;
      _templateId = a.templateId;
      _titleController.text = a.title;
      _bodyController.text = a.body;
      _audienceLevel = a.audienceLevel;
      _channel = a.channel;
      _status = a.status;
      _composerOpen = true;
    });
  }

  void _closeComposer() {
    setState(() => _composerOpen = false);
  }

  void _applyTemplate(StakeholderAnnouncementTemplate t) {
    setState(() {
      _isEditing = false;
      _editingId = '';
      _templateId = t.id;
      _titleController.text = t.subject;
      _bodyController.text = t.body;
      _audienceLevel = t.audienceLevel;
      _channel = t.channel;
      _status = 'Draft';
      _composerOpen = true;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty && body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a title or body before saving the announcement.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final announcement = StakeholderAnnouncement(
      id: _isEditing ? _editingId : null,
      title: title.isEmpty ? '(Untitled announcement)' : title,
      body: body,
      audienceLevel: _audienceLevel,
      channel: _channel,
      status: _status,
      templateId: _templateId,
    );
    await widget.onSave(announcement);
    if (!mounted) return;
    _closeComposer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing
            ? 'Announcement updated.'
            : 'Announcement saved as $_status.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF059669),
      ),
    );
  }

  Future<void> _delete(StakeholderAnnouncement a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete announcement?'),
        content: Text(
            'This will permanently delete "${a.title.isEmpty ? '(Untitled)' : a.title}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onDelete(a.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Announcement deleted.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row: title + New Announcement button ──
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stakeholder Announcements',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Templates for each engagement level (Manage Closely, '
                    'Keep Satisfied, Keep Informed, Monitor) and the Project '
                    'Team section. Pick a template to seed the composer, then '
                    'tailor before saving.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed:
                  _composerOpen ? null : _openComposerForNew,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Announcement',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
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
        const SizedBox(height: 20),

        // ── Template picker (always visible) ──
        _AnnouncementTemplatePicker(
          onPick: _applyTemplate,
        ),

        const SizedBox(height: 20),

        // ── Composer (collapsible) ──
        if (_composerOpen) ...[
          _AnnouncementComposer(
            titleController: _titleController,
            bodyController: _bodyController,
            audienceLevel: _audienceLevel,
            channel: _channel,
            status: _status,
            isEditing: _isEditing,
            onAudienceLevelChanged: (v) =>
                setState(() => _audienceLevel = v),
            onChannelChanged: (v) => setState(() => _channel = v),
            onStatusChanged: (v) => setState(() => _status = v),
            onSave: _save,
            onCancel: _closeComposer,
          ),
          const SizedBox(height: 20),
        ],

        // ── Saved announcements feed ──
        if (widget.announcements.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFE5E7EB), style: BorderStyle.solid),
            ),
            child: const Column(
              children: [
                Icon(Icons.campaign_outlined,
                    size: 36, color: Color(0xFF9CA3AF)),
                SizedBox(height: 12),
                Text(
                  'No announcements yet',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280)),
                ),
                SizedBox(height: 4),
                Text(
                  'Pick a template above or tap "New Announcement" to compose one.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${widget.announcements.length} announcement${widget.announcements.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              ...widget.announcements.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AnnouncementCard(
                    announcement: a,
                    onEdit: () => _openComposerForEdit(a),
                    onDelete: () => _delete(a),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Template picker — renders one section per audience level, with each
/// section listing its templates as pickable chips. Tapping a chip calls
/// `onPick(template)` which seeds the parent composer.
class _AnnouncementTemplatePicker extends StatelessWidget {
  const _AnnouncementTemplatePicker({required this.onPick});

  final void Function(StakeholderAnnouncementTemplate) onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.style_outlined,
                  size: 18, color: Color(0xFF6B7280)),
              SizedBox(width: 8),
              Text(
                'Announcement Templates',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(width: 8),
              Text(
                '— tap to seed the composer',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...kStakeholderAnnouncementAudienceLevels.map(
            (level) => _AudienceTemplateGroup(
              audienceLevel: level,
              templates:
                  StakeholderAnnouncementTemplates.forAudience(level),
              onPick: onPick,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceTemplateGroup extends StatelessWidget {
  const _AudienceTemplateGroup({
    required this.audienceLevel,
    required this.templates,
    required this.onPick,
  });

  final String audienceLevel;
  final List<StakeholderAnnouncementTemplate> templates;
  final void Function(StakeholderAnnouncementTemplate) onPick;

  static const Map<String, Color> _audienceColors = {
    'Manage Closely': Color(0xFFEF4444),
    'Keep Satisfied': Color(0xFFFFC812),
    'Keep Informed': Color(0xFF10B981),
    'Monitor': Color(0xFF6B7280),
    'Project Team': Color(0xFFB8860B),
  };

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) return const SizedBox.shrink();
    final color = _audienceColors[audienceLevel] ?? const Color(0xFF6B7280);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                audienceLevel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${templates.length})',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: templates
                .map(
                  (t) => ActionChip(
                    label: Text(t.title,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    avatar: const Icon(Icons.description_outlined,
                        size: 14, color: Color(0xFF6B7280)),
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    onPressed: () => onPick(t),
                    tooltip: t.useCase,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// The composer — title, audience, channel, status, body, Save / Cancel.
class _AnnouncementComposer extends StatelessWidget {
  const _AnnouncementComposer({
    required this.titleController,
    required this.bodyController,
    required this.audienceLevel,
    required this.channel,
    required this.status,
    required this.isEditing,
    required this.onAudienceLevelChanged,
    required this.onChannelChanged,
    required this.onStatusChanged,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final String audienceLevel;
  final String channel;
  final String status;
  final bool isEditing;
  final ValueChanged<String> onAudienceLevelChanged;
  final ValueChanged<String> onChannelChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFFFD84D), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_note,
                    color: Color(0xFFB45309), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEditing
                      ? 'Edit announcement'
                      : 'Compose new announcement',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Cancel',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Title row
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Subject / Title',
              labelStyle: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              hintText: 'e.g., Weekly Status — Project Alpha (Week 12)',
              hintStyle: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFFFD84D), width: 1.5),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 12),
          // Audience / Channel / Status row
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _DropdownField(
                label: 'Audience',
                value: audienceLevel,
                items: kStakeholderAnnouncementAudienceLevels,
                onChanged: onAudienceLevelChanged,
              ),
              _DropdownField(
                label: 'Channel',
                value: channel,
                items: kStakeholderAnnouncementChannels,
                onChanged: onChannelChanged,
              ),
              _DropdownField(
                label: 'Status',
                value: status,
                items: kStakeholderAnnouncementStatuses,
                onChanged: onStatusChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Body
          TextField(
            controller: bodyController,
            maxLines: 10,
            minLines: 6,
            decoration: const InputDecoration(
              labelText: 'Body',
              labelStyle: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              hintText: 'Compose the announcement body. Use {{placeholders}} '
                  'for variables you will replace before sending.',
              hintStyle: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFFFD84D), width: 1.5),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF111827),
                fontFamily: bodyController.text.isEmpty ? null : 'monospace',
                height: 1.5),
          ),
          const SizedBox(height: 16),
          // Actions
          Row(
            children: [
              const Spacer(),
              OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.check, size: 16),
                label: Text(isEditing ? 'Save Changes' : 'Save Announcement',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD84D),
                  foregroundColor: const Color(0xFF1F2937),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact dropdown with label — used inside the composer for audience,
/// channel, and status.
class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label:',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            isDense: true,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827)),
            items: items
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(item),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

/// A saved announcement card in the feed.
class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.onEdit,
    required this.onDelete,
  });

  final StakeholderAnnouncement announcement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const Map<String, Color> _audienceColors = {
    'Manage Closely': Color(0xFFFEE2E2),
    'Keep Satisfied': Color(0xFFFEF3C7),
    'Keep Informed': Color(0xFFD1FAE5),
    'Monitor': Color(0xFFF3F4F6),
    'Project Team': Color(0xFFFFF8E1),
  };

  static const Map<String, Color> _audienceTextColors = {
    'Manage Closely': Color(0xFF991B1B),
    'Keep Satisfied': Color(0xFFFFC812),
    'Keep Informed': Color(0xFF065F46),
    'Monitor': Color(0xFF374151),
    'Project Team': Color(0xFFB8860B),
  };

  static const Map<String, Color> _statusColors = {
    'Draft': Color(0xFFF3F4F6),
    'Scheduled': Color(0xFFFEF3C7),
    'Sent': Color(0xFFD1FAE5),
  };

  static const Map<String, Color> _statusTextColors = {
    'Draft': Color(0xFF4B5563),
    'Scheduled': Color(0xFF92400E),
    'Sent': Color(0xFF065F46),
  };

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final audienceBg =
        _audienceColors[a.audienceLevel] ?? const Color(0xFFF3F4F6);
    final audienceFg =
        _audienceTextColors[a.audienceLevel] ?? const Color(0xFF374151);
    final statusBg = _statusColors[a.status] ?? const Color(0xFFF3F4F6);
    final statusFg = _statusTextColors[a.status] ?? const Color(0xFF4B5563);
    final bodyPreview = a.body.isEmpty
        ? '(no body)'
        : (a.body.length > 180 ? '${a.body.substring(0, 180)}…' : a.body);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.title.isEmpty ? '(Untitled announcement)' : a.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: Color(0xFF6B7280)),
                tooltip: 'Edit',
                splashRadius: 18,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Color(0xFFEF4444)),
                tooltip: 'Delete',
                splashRadius: 18,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Pill(
                label: a.audienceLevel,
                backgroundColor: audienceBg,
                foregroundColor: audienceFg,
              ),
              _Pill(
                label: a.channel,
                backgroundColor: const Color(0xFFF3F4F6),
                foregroundColor: const Color(0xFF374151),
              ),
              _Pill(
                label: a.status,
                backgroundColor: statusBg,
                foregroundColor: statusFg,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              bodyPreview,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule_outlined,
                  size: 12, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text(
                'Created ${_formatDate(a.createdAt)}'
                '${a.updatedAt != null ? ' · Updated ${_formatDate(a.updatedAt!)}' : ''}',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foregroundColor,
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
