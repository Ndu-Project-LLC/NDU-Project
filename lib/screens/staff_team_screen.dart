import 'dart:async';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/models/staffing_row.dart';
import 'package:ndu_project/models/team_management_plan.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/team_management_service.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/staff_team_resource_grid.dart';
import 'package:ndu_project/widgets/launch_editable_section.dart' as launch;
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

class StaffTeamScreen extends StatefulWidget {
  const StaffTeamScreen({super.key});

  static void open(BuildContext context) {
    PhaseTransitionHelper.pushPhaseAware(
      context: context,
      builder: (_) => const StaffTeamScreen(),
      destinationCheckpoint: 'staff_team',
    );
  }

  @override
  State<StaffTeamScreen> createState() => _StaffTeamScreenState();
}

class _StaffTeamScreenState extends State<StaffTeamScreen> {
  List<StaffingRow> _staffingRows = [];
  List<launch.LaunchEntry> _onboardingActions = [];
  List<launch.LaunchEntry> _coverageRisks = [];
  bool _loading = true;
  bool _autoGenerationTriggered = false;
  bool _isAutoGenerating = false;
  Timer? _autoSaveDebounce;

  // ── Mobilization plan (consumed from the Planning-phase Team Management
  // screen). Stored at projects/{projectId}/team_management/plan.
  TeamManagementPlan _mobilizationPlan = TeamManagementPlan.empty();
  bool _loadingMobilization = true;

  String? get _projectId {
    try {
      final provider = ProjectDataInherited.maybeOf(context);
      return provider?.projectData.projectId;
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Staff Team',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
        ]),
        PdfSection.text(
            'Notes',
            projectData.planningNotes['staff_team_screen'] ??
                'No data recorded.'),
      ],
    );
  }

  Future<void> _loadData() async {
    final projectId = _projectId;
    if (projectId == null || projectId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final rows =
          await ExecutionPhaseService.loadStaffingRows(projectId: projectId);

      final data = await ExecutionPhaseService.loadPageData(
        projectId: projectId,
        pageKey: 'staff_team',
      );

      if (mounted) {
        setState(() {
          _staffingRows = rows;
          _onboardingActions = data?['onboardingActions']
                  ?.map((e) => launch.LaunchEntry(
                        title: e.title,
                        details: e.details,
                        status: e.status,
                      ))
                  .toList() ??
              [];
          _coverageRisks = data?['coverageRisks']
                  ?.map((e) => launch.LaunchEntry(
                        title: e.title,
                        details: e.details,
                        status: e.status,
                      ))
                  .toList() ??
              [];
          _loading = false;
        });
      }
      await _autoGenerateIfNeeded();
      await _loadMobilizationPlan();
    } catch (e) {
      debugPrint('Error loading staff team data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Mobilization plan persistence (Firestore) ─────────────────────
  // Loads the plan authored on the Planning-phase Team Management screen
  // so the Execution-phase Staff Team screen can display and advance each
  // member's mobilization checklist.
  Future<void> _loadMobilizationPlan() async {
    final projectId = _projectId;
    if (projectId == null || projectId.isEmpty) {
      if (mounted) setState(() => _loadingMobilization = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('team_management')
          .doc('plan')
          .get();
      if (doc.exists && doc.data() != null) {
        if (!mounted) return;
        setState(() {
          _mobilizationPlan = TeamManagementPlan.fromJson(doc.data()!);
          _loadingMobilization = false;
        });
      } else {
        if (mounted) setState(() => _loadingMobilization = false);
      }
    } catch (e) {
      debugPrint('StaffTeam: failed to load mobilization plan: $e');
      if (mounted) setState(() => _loadingMobilization = false);
    }
  }

  Future<void> _saveMobilizationPlan() async {
    final projectId = _projectId;
    if (projectId == null || projectId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('team_management')
          .doc('plan')
          .set(_mobilizationPlan.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('StaffTeam: failed to save mobilization plan: $e');
    }
  }

  void _toggleChecklistItem(String memberId, int index) {
    setState(() {
      final mobIndex = _mobilizationPlan.memberMobilizations
          .indexWhere((m) => m.memberId == memberId);
      if (mobIndex == -1) return;
      final mob = _mobilizationPlan.memberMobilizations[mobIndex];
      if (index < 0 || index >= mob.checklist.length) return;
      final item = mob.checklist[index];
      final now = DateTime.now().toIso8601String();
      final user = FirebaseAuth.instance.currentUser;
      final newlyChecked = !item.isChecked;
      mob.checklist[index] = item.copyWith(
        isChecked: newlyChecked,
        completedAt: newlyChecked ? now : null,
        completedBy: newlyChecked ? user?.uid : null,
      );
      // Stamp mobilizedAt when every item is checked; clear it otherwise.
      _mobilizationPlan.memberMobilizations[mobIndex].mobilizedAt =
          mob.checklist.every((i) => i.isChecked) ? now : null;
    });
    _saveMobilizationPlan();
  }

  Future<void> _autoGenerateIfNeeded() async {
    if (!mounted || _autoGenerationTriggered || _isAutoGenerating) return;
    if (_staffingRows.isNotEmpty ||
        _onboardingActions.isNotEmpty ||
        _coverageRisks.isNotEmpty) {
      return;
    }

    _autoGenerationTriggered = true;
    _isAutoGenerating = true;

    try {
      final data = ProjectDataHelper.getData(context);
      var contextText = ProjectDataHelper.buildExecutivePlanContext(
        data,
        sectionLabel: 'Staff Team Orchestration',
      );
      if (contextText.trim().isEmpty) {
        contextText = ProjectDataHelper.buildProjectContextScan(
          data,
          sectionLabel: 'Staff Team Orchestration',
        );
      }
      final safeContext = contextText.trim().isEmpty
          ? 'Project context unavailable.'
          : contextText;

      final ai = OpenAiServiceSecure();
      final staffingRows = await ai.generateStaffingRows(
        context: safeContext,
        maxRows: 4,
      );
      Map<String, List<Map<String, dynamic>>> sections = {};
      if (contextText.trim().isNotEmpty) {
        sections = await ai.generateLaunchPhaseEntries(
          context: contextText,
          sections: const {
            'onboardingActions': 'Onboarding actions and ownership assignments',
            'coverageRisks': 'Coverage gaps and staffing risks',
          },
          itemsPerSection: 3,
        );
      }

      List<launch.LaunchEntry> onboarding =
          (sections['onboardingActions'] ?? [])
              .map(
                (e) => launch.LaunchEntry(
                  title: e['title']?.toString() ?? '',
                  details: e['details']?.toString() ?? '',
                  status: e['status']?.toString(),
                ),
              )
              .where((entry) => entry.title.trim().isNotEmpty)
              .toList();
      List<launch.LaunchEntry> coverage = (sections['coverageRisks'] ?? [])
          .map(
            (e) => launch.LaunchEntry(
              title: e['title']?.toString() ?? '',
              details: e['details']?.toString() ?? '',
              status: e['status']?.toString(),
            ),
          )
          .where((entry) => entry.title.trim().isNotEmpty)
          .toList();

      if (onboarding.isEmpty) {
        onboarding = const [
          launch.LaunchEntry(
            title: 'Confirm onboarding timeline',
            details: 'Assign owners and due dates for new team members.',
            status: 'Planned',
          ),
          launch.LaunchEntry(
            title: 'Access and tooling setup',
            details: 'Provision credentials and tools before start date.',
            status: 'Planned',
          ),
        ];
      }
      if (coverage.isEmpty) {
        coverage = const [
          launch.LaunchEntry(
            title: 'Coverage gap in critical role',
            details: 'Identify backfill or interim owner for key workstream.',
            status: 'Open',
          ),
          launch.LaunchEntry(
            title: 'Skill overlap risk',
            details: 'Ensure cross-training for high-dependency roles.',
            status: 'Open',
          ),
        ];
      }

      if (!mounted) return;
      setState(() {
        if (staffingRows.isNotEmpty) {
          _staffingRows = staffingRows;
        }
        if (onboarding.isNotEmpty) {
          _onboardingActions = onboarding;
        }
        if (coverage.isNotEmpty) {
          _coverageRisks = coverage;
        }
      });

      await _persistChanges();
    } catch (e) {
      debugPrint('Error auto-generating staff team data: $e');
    } finally {
      _isAutoGenerating = false;
    }
  }

  void _onStaffingRowsChanged(List<StaffingRow> rows) {
    setState(() => _staffingRows = rows);
    _autoSave();
  }

  void _autoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 1500), () {
      _persistChanges();
    });
  }

  Future<void> _persistChanges() async {
    final projectId = _projectId;
    if (projectId == null || projectId.isEmpty) return;

    try {
      await ExecutionPhaseService.saveStaffingRows(
        projectId: projectId,
        rows: _staffingRows,
        userId: FirebaseAuth.instance.currentUser?.uid,
      );

      await ExecutionPhaseService.savePageData(
        projectId: projectId,
        pageKey: 'staff_team',
        sections: {
          'onboardingActions': _onboardingActions,
          'coverageRisks': _coverageRisks,
        },
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
    } catch (e) {
      debugPrint('Error persisting staff team data: $e');
    }
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final double horizontalPadding = isMobile ? 20 : 40;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: const KazAiChatBubble(positioned: false),
      body: SafeArea(
        child: isMobile
            ? _buildMobileLayout(horizontalPadding)
            : _buildDesktopLayout(horizontalPadding),
      ),
    );
  }

  Widget _buildDesktopLayout(double hPad) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DraggableSidebar(
          openWidth: AppBreakpoints.sidebarWidth(context),
          child: const InitiationLikeSidebar(activeItemLabel: 'Staff Team'),
        ),
        Expanded(child: _buildScrollContent(hPad)),
      ],
    );
  }

  Widget _buildMobileLayout(double hPad) {
    return _buildScrollContent(hPad);
  }

  Widget _buildScrollContent(double hPad) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlanningPhaseHeader(
              title: 'Staff Team',
              showNavigationButtons: false,
              onExportPdf: _exportPdf),
          const SizedBox(height: 16),
          _buildSectionIntro(),
          const SizedBox(height: 28),
          if (_loading)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ))
          else ...[
            StaffTeamResourceGrid(
              rows: _staffingRows,
              onRowsChanged: _onStaffingRowsChanged,
            ),
            const SizedBox(height: 28),
            _buildMobilizationBoard(),
            const SizedBox(height: 28),
            launch.LaunchEditableSection(
              title: 'Onboarding actions',
              description:
                  'List onboarding steps and owners to get people productive.',
              entries: _onboardingActions,
              onAdd: () => _addOnboardingAction(),
              onRemove: (i) {
                setState(() => _onboardingActions.removeAt(i));
                _autoSave();
              },
              onEdit: (i, entry) => _editOnboardingAction(i, entry),
            ),
            const SizedBox(height: 20),
            launch.LaunchEditableSection(
              title: 'Coverage risks',
              description: 'Document gaps or risks in team coverage.',
              entries: _coverageRisks,
              onAdd: () => _addCoverageRisk(),
              onRemove: (i) {
                setState(() => _coverageRisks.removeAt(i));
                _autoSave();
              },
              onEdit: (i, entry) => _editCoverageRisk(i, entry),
            ),
          ],
          const SizedBox(height: 36),
          _buildBottomActionBar(context),
          const SizedBox(height: 56),
        ],
      ),
    );
  }

  // ── Mobilization Board ────────────────────────────────────────────
  // Consumes the Team Management plan authored during the Planning phase
  // (projects/{projectId}/team_management/plan) and surfaces each team
  // member's mobilization checklist so the Execution phase can track and
  // advance mobilization. Checking off all items marks the member as
  // "mobilized" for Execution.
  Widget _buildMobilizationBoard() {
    if (_loadingMobilization) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final projectData = ProjectDataHelper.getData(context);
    final members = projectData.teamMembers;

    if (members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.rocket_launch_outlined,
                    size: 20, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 12),
              const Text('Team Mobilization',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827))),
            ]),
            const SizedBox(height: 16),
            const Text(
              'No team members found. Add team members on the Team Management '
              'screen (Planning phase) to track their mobilization checklists here.',
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
            ),
          ],
        ),
      );
    }

    // Seed any missing member mobilization records from the default
    // checklist template so the board is immediately actionable.
    bool planChanged = false;
    for (final member in members) {
      final exists = _mobilizationPlan.memberMobilizations
          .any((m) => m.memberId == member.id);
      if (!exists) {
        _mobilizationPlan.memberMobilizations.add(
          TeamManagementService.getOrCreateMemberMobilization(
            plan: _mobilizationPlan,
            memberId: member.id,
          ),
        );
        planChanged = true;
      }
    }
    if (planChanged) _saveMobilizationPlan();

    final overallProgress =
        TeamManagementService.overallMobilizationProgress(_mobilizationPlan);
    final mobilizedCount = _mobilizationPlan.memberMobilizations
        .where((m) => m.isFullyMobilized)
        .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + overall progress
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.rocket_launch_outlined,
                    size: 20, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Team Mobilization',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827))),
                    SizedBox(height: 2),
                    Text(
                      'Per-member onboarding checklists from the Team Management '
                      'plan. Complete all items to mobilize each member for Execution.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          height: 1.4),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$mobilizedCount/${members.length} mobilized',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
            ),
          ),
          // Mobilization process text (authored on the Planning screen)
          if (_mobilizationPlan.mobilizationProcess.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.description_outlined,
                        size: 16, color: Color(0xFF6B7280)),
                    SizedBox(width: 6),
                    Text('Mobilization Process',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151))),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    _mobilizationPlan.mobilizationProcess,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                        height: 1.5),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Per-member checklists
          ...members.map((member) => _buildMemberChecklist(member)),
        ],
      ),
    );
  }

  Widget _buildMemberChecklist(TeamMember member) {
    MemberMobilization mob;
    final idx = _mobilizationPlan.memberMobilizations
        .indexWhere((m) => m.memberId == member.id);
    if (idx == -1) {
      mob = TeamManagementService.getOrCreateMemberMobilization(
        plan: _mobilizationPlan,
        memberId: member.id,
      );
    } else {
      mob = _mobilizationPlan.memberMobilizations[idx];
    }

    final progress = mob.progress;
    final isMobilized = mob.isFullyMobilized;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isMobilized
                ? const Color(0xFF86EFAC)
                : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isMobilized
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFFF8E1),
                    child: Text(
                      (member.name.isNotEmpty ? member.name : '?')[0]
                          .toUpperCase(),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isMobilized
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF4338CA)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            member.name.isNotEmpty
                                ? member.name
                                : 'Unknown member',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827))),
                        if (member.role.isNotEmpty)
                          Text(member.role,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                ]),
              ),
              if (isMobilized)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(children: [
                    Icon(Icons.check_circle,
                        size: 12, color: Color(0xFF16A34A)),
                    SizedBox(width: 3),
                    Text('MOBILIZED',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A))),
                  ]),
                )
              else
                Text('${(progress * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706))),
            ],
          ),
          if (mob.checklist.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                  'No checklist items. Add items on the Team Management screen.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                      fontStyle: FontStyle.italic)),
            )
          else ...[
            const SizedBox(height: 10),
            ...mob.checklist.asMap().entries.map((entry) {
              return _buildChecklistItem(member.id, entry.key, entry.value);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistItem(
      String memberId, int index, MobilizationChecklistItem item) {
    return InkWell(
      onTap: () => _toggleChecklistItem(memberId, index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: item.isChecked,
                onChanged: (_) => _toggleChecklistItem(memberId, index),
                activeColor: const Color(0xFF16A34A),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  color: item.isChecked
                      ? const Color(0xFF6B7280)
                      : const Color(0xFF374151),
                  decoration: item.isChecked
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.groups_rounded,
                  size: 22, color: Color(0xFF4338CA)),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff Plan',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Strategize your project's human capital requirements. Identify core roles, determine resource allocation, and align staffing costs with your project's execution timeline.",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: LaunchPhaseNavigation(
        backLabel: PlanningPhaseNavigation.backLabel('staff_team'),
        nextLabel: PlanningPhaseNavigation.nextLabel('staff_team'),
        onBack: () => PlanningPhaseNavigation.goToPrevious(context, 'staff_team'),
        onNext: () => PlanningPhaseNavigation.goToNext(context, 'staff_team'),
      ),
    );
  }

  Future<void> _addOnboardingAction() async {
    final entry = await launch.showLaunchEntryDialog(
      context,
      titleLabel: 'Action / owner',
      detailsLabel: 'Details',
      includeStatus: true,
    );
    if (entry != null && mounted) {
      setState(() => _onboardingActions.add(entry));
      _autoSave();
    }
  }

  Future<void> _editOnboardingAction(
      int index, launch.LaunchEntry currentEntry) async {
    final entry = await launch.showLaunchEntryDialog(
      context,
      titleLabel: 'Action / owner',
      detailsLabel: 'Details',
      includeStatus: true,
      initialEntry: currentEntry,
    );
    if (entry != null && mounted) {
      setState(() => _onboardingActions[index] = entry);
      _autoSave();
    }
  }

  Future<void> _addCoverageRisk() async {
    final entry = await launch.showLaunchEntryDialog(
      context,
      titleLabel: 'Risk',
      detailsLabel: 'Details',
      includeStatus: true,
    );
    if (entry != null && mounted) {
      setState(() => _coverageRisks.add(entry));
      _autoSave();
    }
  }

  Future<void> _editCoverageRisk(
      int index, launch.LaunchEntry currentEntry) async {
    final entry = await launch.showLaunchEntryDialog(
      context,
      titleLabel: 'Risk',
      detailsLabel: 'Details',
      includeStatus: true,
      initialEntry: currentEntry,
    );
    if (entry != null && mounted) {
      setState(() => _coverageRisks[index] = entry);
      _autoSave();
    }
  }
}
