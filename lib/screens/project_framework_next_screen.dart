import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/screens/planning_requirements_screen.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/planning_goal_milestone_mapping_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

const Color _kAccentColor = Color(0xFFFFC107);
const Color _kPrimaryText = Color(0xFF1E293B);
const Color _kSecondaryText = Color(0xFF64748B);
const Color _kBorderColor = Color(0xFFE2E8F0);
const Color _kCardShadow = Color(0x14000000);
const Color _kLightYellow = Color(0xFFFFF8E1);
const Color _kLightBlue = Color(0xFFE0F2FE);
const Color _kGreenBrand = Color(0xFF22C55E);
const Color _kLightGray = Color(0xFFF1F5F9);
const List<String> _kPriorityOptions = [
  'High Priority',
  'Medium Priority',
  'Low Priority'
];

Color _priorityColor(String priority) {
  switch (priority) {
    case 'High Priority':
      return const Color(0xFFDC2626);
    case 'Low Priority':
      return const Color(0xFF059669);
    case 'Medium Priority':
    default:
      return const Color(0xFFD97706);
  }
}

Color _priorityBackground(String priority) {
  switch (priority) {
    case 'High Priority':
      return const Color(0xFFFEE2E2);
    case 'Low Priority':
      return const Color(0xFFD1FAE5);
    case 'Medium Priority':
    default:
      return const Color(0xFFFEF3C7);
  }
}

class ProjectFrameworkNextScreen extends StatefulWidget {
  const ProjectFrameworkNextScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProjectFrameworkNextScreen()),
    );
  }

  @override
  State<ProjectFrameworkNextScreen> createState() =>
      _ProjectFrameworkNextScreenState();
}

class _ProjectFrameworkNextScreenState
    extends State<ProjectFrameworkNextScreen> {
  final List<TextEditingController> _goalTitleControllers =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> _goalDescControllers =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> _goalYearControllers =
      List.generate(3, (_) => TextEditingController());
  final List<String> _goalIds = List.generate(3, (_) => '');
  final List<List<String>> _goalMilestoneIds =
      List.generate(3, (_) => <String>[]);
  final List<String> _goalPriorities =
      List.generate(3, (_) => 'Medium Priority');
  final DateFormat _dateFormat = DateFormat('MMM d, y');
  late final OpenAiServiceSecure _openAi;
  final Set<int> _regeneratingMilestoneSuggestions = <int>{};

  // FocusNodes for auto-save on blur
  final List<FocusNode> _titleFocusNodes = List.generate(3, (_) => FocusNode());
  final List<FocusNode> _descFocusNodes = List.generate(3, (_) => FocusNode());
  final List<FocusNode> _yearFocusNodes = List.generate(3, (_) => FocusNode());

  String _potentialSolution = '';
  String _projectObjective = '';
  String _currentFilter = 'View All';
  final TextEditingController _notesController = TextEditingController();

  Timer? _saveDebounce;

  void _onFieldChanged() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _saveData();
    });
  }

  /// Saves goal data to provider when focus is lost
  void _saveData() {
    if (!mounted) return;

    final planningGoals = <PlanningGoal>[];
    for (int i = 0; i < 3; i++) {
      planningGoals.add(PlanningGoal(
        id: _goalIds[i].trim().isNotEmpty ? _goalIds[i] : null,
        goalNumber: i + 1,
        title: _goalTitleControllers[i].text.trim(),
        description: _goalDescControllers[i].text.trim(),
        targetYear: _goalYearControllers[i].text.trim(),
        priority: _goalPriorities[i],
        milestoneIds: List<String>.from(_goalMilestoneIds[i]),
        milestones: const [],
      ));
    }

    ProjectDataHelper.getProvider(context).updateField(
      (data) => data.copyWith(
        planningGoals: planningGoals,
        planningNotes: {
          ...data.planningNotes,
          'planning_project_framework_next_notes': _notesController.text.trim(),
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _openAi = OpenAiServiceSecure();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = ProjectDataHelper.getProvider(context);
      final migration =
          PlanningGoalMilestoneMappingService.migrateLegacyMappings(
        planningGoals: provider.projectData.planningGoals,
        keyMilestones: provider.projectData.keyMilestones,
      );
      final projectData = migration.changed
          ? provider.projectData.copyWith(
              planningGoals: migration.planningGoals,
              keyMilestones: migration.keyMilestones,
            )
          : provider.projectData;
      if (migration.changed) {
        provider.updateField(
          (data) => data.copyWith(
            planningGoals: migration.planningGoals,
            keyMilestones: migration.keyMilestones,
          ),
        );
      }

      // Populate from planning goals (preferred) - only if they have actual content
      final hasPlanningGoalContent = projectData.planningGoals.any(
        (g) => g.title.isNotEmpty || g.description.isNotEmpty,
      );
      if (hasPlanningGoalContent) {
        for (int i = 0; i < projectData.planningGoals.length && i < 3; i++) {
          final goal = projectData.planningGoals[i];
          _goalIds[i] = goal.id;
          _goalTitleControllers[i].text = goal.title;
          _goalDescControllers[i].text = goal.description;
          _goalYearControllers[i].text = goal.targetYear;
          _goalPriorities[i] =
              goal.priority.isNotEmpty ? goal.priority : 'Medium Priority';
          _goalMilestoneIds[i] = List<String>.from(goal.milestoneIds);
        }
      } else if (projectData.projectGoals.isNotEmpty) {
        // Fallback to project goals
        for (int i = 0; i < projectData.projectGoals.length && i < 3; i++) {
          final goal = projectData.projectGoals[i];
          _goalTitleControllers[i].text = goal.name;
          _goalDescControllers[i].text = goal.description;
        }
      }

      // Add listeners for real-time title updates in filters
      for (var controller in _goalTitleControllers) {
        controller.addListener(() {
          if (mounted) setState(() {});
        });
      }

      // Auto-save to provider on every change so data is never lost
      for (final c in _goalTitleControllers) {
        c.addListener(_onFieldChanged);
      }
      for (final c in _goalDescControllers) {
        c.addListener(_onFieldChanged);
      }
      for (final c in _goalYearControllers) {
        c.addListener(_onFieldChanged);
      }

      // Fetch context data
      final analysis = projectData.preferredSolutionAnalysis;
      // Heuristic: If selectedSolutionTitle exists, use it. Else first potential solution.
      if (analysis?.selectedSolutionTitle != null &&
          analysis!.selectedSolutionTitle!.isNotEmpty) {
        _potentialSolution = analysis.selectedSolutionTitle ?? '';
      } else if (projectData.potentialSolutions.isNotEmpty) {
        _potentialSolution = projectData.potentialSolutions.first.title;
      }

      // Fetch Objective (from Business Case Scope or similar if specialized field missing)
      // Assuming 'projectObjective' might not be a direct string on ProjectData yet based on imports.
      // Looking at usage in other screens, Scope Statement often serves as objective.
      _projectObjective = projectData.projectObjective.isNotEmpty
          ? projectData.projectObjective
          : (projectData.businessCase.isNotEmpty
              ? projectData.businessCase
              : '');

      // Setup nomenclature listeners
      for (int i = 0; i < 3; i++) {
        _setupGoalNomenclature(i);
      }

      // Setup focus listeners for auto-save on blur
      for (int i = 0; i < 3; i++) {
        _titleFocusNodes[i].addListener(() {
          if (!_titleFocusNodes[i].hasFocus) _saveData();
        });
        _descFocusNodes[i].addListener(() {
          if (!_descFocusNodes[i].hasFocus) _saveData();
        });
        _yearFocusNodes[i].addListener(() {
          if (!_yearFocusNodes[i].hasFocus) _saveData();
        });
      }

      // Load saved notes
      _notesController.text =
          projectData.planningNotes['planning_project_framework_next_notes'] ??
              '';

      // Setup notes controller auto-save
      _notesController.addListener(_onFieldChanged);

      setState(() {});
    });
  }

  void _setupGoalNomenclature(int index) {
    _goalDescControllers[index].addListener(() {
      final text = _goalDescControllers[index].text.trim();
      if (_goalTitleControllers[index].text.trim().isNotEmpty) {
        return;
      }
      if (text.isNotEmpty) {
        final words = text.split(RegExp(r'\s+')).take(3);
        final initials = words
            .where((w) => w.isNotEmpty)
            .map((w) => w[0].toUpperCase())
            .join();
        if (initials.isNotEmpty) {
          final newTitle = 'G${index + 1} $initials';
          if (_goalTitleControllers[index].text != newTitle) {
            _goalTitleControllers[index].text = newTitle;
          }
        }
      } else {
        final defaultTitle = 'Goal ${index + 1}';
        if (_goalTitleControllers[index].text != defaultTitle) {
          _goalTitleControllers[index].text = defaultTitle;
        }
      }
    });
  }

  void _clearGoal(int index) {
    setState(() {
      _goalTitleControllers[index].clear();
      _goalDescControllers[index].clear();
      _goalYearControllers[index].clear();
      _goalMilestoneIds[index] = <String>[];
      _goalPriorities[index] = 'Medium Priority';
    });
    _saveData();
  }

  void _setPriority(int index, String priority) {
    setState(() {
      _goalPriorities[index] = priority;
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    for (var c in _goalTitleControllers) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    for (var c in _goalDescControllers) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    for (var c in _goalYearControllers) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }

    // Dispose FocusNodes
    for (var node in _titleFocusNodes) {
      node.dispose();
    }
    for (var node in _descFocusNodes) {
      node.dispose();
    }
    for (var node in _yearFocusNodes) {
      node.dispose();
    }
    _notesController.removeListener(_onFieldChanged);
    _notesController.dispose();
    super.dispose();
  }

  // ignore: unused_element
  bool _areAllGoalsFilled() {
    for (int i = 0; i < 3; i++) {
      if (_goalTitleControllers[i].text.trim().isEmpty ||
          _goalDescControllers[i].text.trim().isEmpty ||
          _goalYearControllers[i].text.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  void _navigateToNext() async {
    // Validation removed to match top navigation behavior

    final planningGoals = List.generate(3, (i) {
      return PlanningGoal(
        id: _goalIds[i].trim().isNotEmpty ? _goalIds[i] : null,
        goalNumber: i + 1,
        title: _goalTitleControllers[i].text.trim(),
        description: _goalDescControllers[i].text.trim(),
        targetYear: _goalYearControllers[i].text.trim(),
        priority: _goalPriorities[i],
        milestoneIds: List<String>.from(_goalMilestoneIds[i]),
        milestones: const [],
      );
    });

    await ProjectDataHelper.saveAndNavigate(
      context: context,
      checkpoint: 'project_goals_milestones',
      saveInBackground: true,
      nextScreenBuilder: () =>
          PlanningPhaseNavigation.resolveNextScreen(
            context,
            'project_goals_milestones',
          ) ??
          const PlanningRequirementsScreen(),
      dataUpdater: (data) => data.copyWith(
        planningGoals: planningGoals,
        planningNotes: {
          ...data.planningNotes,
          'planning_project_framework_next_notes': _notesController.text.trim(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: isMobile
          ? Drawer(
              width: AppBreakpoints.sidebarWidth(context),
              child: SafeArea(
                child: InitiationLikeSidebar(
                  activeItemLabel: 'Project Goals & Milestones',
                  showHeader: true,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Project Goals & Milestones'),
            ),
            Expanded(
              child: Column(
                children: [
                  PlanningPhaseHeader(
                      title: 'Project Details',
                      breadcrumbPhase: 'Planning Phase',
                      breadcrumbTitle: 'Project Framework',
                      onBack: () => PlanningPhaseNavigation.goToPrevious(
                          context, 'project_goals_milestones'),
                      onForward: () => PlanningPhaseNavigation.goToNext(
                          context, 'project_goals_milestones'),
                      onExportPdf: _exportPdf),
                  Expanded(
                    child: Stack(
                      children: [
                        MobileSidebarHamburger(
                          sidebar: const InitiationLikeSidebar(
                            activeItemLabel: 'Project Goals & Milestones',
                          ),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 80),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: isMobile
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildNotesSection(),
                                      const SizedBox(height: 16),
                                      _buildContextSection(),
                                      const SizedBox(height: 16),
                                      _buildMilestoneTimelineSection(),
                                      const SizedBox(height: 16),
                                      _buildMilestoneTableSection(),
                                      const SizedBox(height: 16),
                                      _buildGoalsSection(isMobile: true),
                                      const SizedBox(height: 24),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildNotesSection(),
                                      const SizedBox(height: 16),
                                      _buildContextSection(),
                                      const SizedBox(height: 16),
                                      _buildMilestoneTimelineSection(),
                                      const SizedBox(height: 16),
                                      _buildMilestoneTableSection(),
                                      const SizedBox(height: 16),
                                      _buildGoalsSection(isMobile: false),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _buildFixedFooter(),
                        ),
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

  // ─── Mobile Header ──────────────────────────────────────────────
  Widget _buildMobileHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        FirebaseAuthService.displayNameOrEmail(fallback: 'User');
    final userInitial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final email = user?.email ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kBorderColor)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                InkWell(
                  onTap: () => PlanningPhaseNavigation.goToPrevious(
                      context, 'project_goals_milestones'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chevron_left,
                        size: 22, color: _kSecondaryText),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Planning Phase',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _kPrimaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!AppBreakpoints.isMobile(context))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(email,
                        style: const TextStyle(
                            fontSize: 13, color: _kSecondaryText)),
                  ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _kLightYellow,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(userInitial,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kAccentColor)),
                ),
              ],
            ),
          ),
          // Breadcrumb
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: _kLightGray,
              border: Border(top: BorderSide(color: _kBorderColor)),
            ),
            child: Row(
              children: [
                const Text('Planning Phase',
                    style: TextStyle(fontSize: 12, color: _kSecondaryText)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    size: 14, color: _kSecondaryText),
                const SizedBox(width: 4),
                const Text('Project Goals & Milestones',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _kPrimaryText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Notes Section ──────────────────────────────────────────────
  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderColor),
        boxShadow: const [
          BoxShadow(color: _kCardShadow, blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined,
                  size: 20, color: _kAccentColor),
              const SizedBox(width: 8),
              const Text('Notes',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kPrimaryText)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
              'Summarize planning goals, milestones, and delivery themes.',
              style: TextStyle(fontSize: 12, color: _kSecondaryText)),
          const SizedBox(height: 12),
          VoiceTextField(
            controller: _notesController,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              hintText:
                  'Capture the key decisions and details for this section...',
              hintStyle: const TextStyle(color: _kSecondaryText, fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kAccentColor, width: 1.5),
              ),
            ),
            style: const TextStyle(fontSize: 14, color: _kPrimaryText),
          ),
        ],
      ),
    );
  }

  // ─── Context Section ────────────────────────────────────────────
  Widget _buildContextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _potentialSolution.isNotEmpty
              ? _potentialSolution
              : 'Proposed Solution 1',
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: _kPrimaryText),
        ),
        const SizedBox(height: 12),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                  text: 'Project Objective ',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kPrimaryText)),
              TextSpan(
                  text: '(Detailed aim of the project.)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: _kSecondaryText)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorderColor),
            boxShadow: const [
              BoxShadow(
                  color: _kCardShadow, blurRadius: 4, offset: Offset(0, 1))
            ],
          ),
          child: Text(
            _projectObjective.isNotEmpty ? _projectObjective : 'Pending input',
            style: TextStyle(
              fontSize: 14,
              color: _projectObjective.isNotEmpty
                  ? _kPrimaryText
                  : _kSecondaryText,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Goals Section (with tabs) ──────────────────────────────────
  Widget _buildGoalsSection({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                  text: 'Project Goals',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _kPrimaryText)),
              TextSpan(
                  text:
                      ' (Breakdown the project objective into attainable areas)',
                  style: TextStyle(
                      fontSize: 13,
                      color: _kSecondaryText,
                      fontWeight: FontWeight.w400)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Tab navigation
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterPill(
                label: 'Goal 1',
                value: 'Goal 1',
                isActive: _currentFilter == 'Goal 1',
                activeColor: _kAccentColor,
                activeBgColor: _kLightYellow,
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                label: 'Goal 2',
                value: 'Goal 2',
                isActive: _currentFilter == 'Goal 2',
                activeColor: const Color(0xFF2563EB),
                activeBgColor: _kLightBlue,
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                label: 'Goal 3',
                value: 'Goal 3',
                isActive: _currentFilter == 'Goal 3',
                activeColor: _kAccentColor,
                activeBgColor: _kLightYellow,
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                label: 'View All',
                value: 'View All',
                isActive: _currentFilter == 'View All',
                activeColor: Colors.white,
                activeBgColor: _kGreenBrand,
                isInverted: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Info banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kLightBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: Color(0xFF1E40AF)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Goal milestones would be a foundation for the project schedule. Focus on the key milestones required for project success.',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF1E40AF), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Goal cards
        if (isMobile || _currentFilter != 'View All')
          ...List.generate(3, (i) {
            if (_currentFilter != 'View All' &&
                _currentFilter != 'Goal ${i + 1}') {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildGoalCard(i),
            );
          })
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(3, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
                  child: _buildGoalCard(i),
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildFilterPill({
    required String label,
    required String value,
    required bool isActive,
    required Color activeColor,
    required Color activeBgColor,
    bool isInverted = false,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _currentFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: isActive ? null : Border.all(color: _kBorderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isActive
                ? (isInverted ? Colors.white : activeColor)
                : _kSecondaryText,
          ),
        ),
      ),
    );
  }

  // ─── Goal Card (new HTML design) ────────────────────────────────
  Widget _buildGoalCard(int index) {
    return _GoalCardWidget(
      goalIndex: index,
      titleController: _goalTitleControllers[index],
      descController: _goalDescControllers[index],
      yearController: _goalYearControllers[index],
      availableMilestones: _sortedMilestones,
      selectedMilestoneIds: _goalMilestoneIds[index],
      priority: _goalPriorities[index],
      titleFocusNode: _titleFocusNodes[index],
      descFocusNode: _descFocusNodes[index],
      yearFocusNode: _yearFocusNodes[index],
      isSuggestingMilestones: _regeneratingMilestoneSuggestions.contains(index),
      onClear: () => _clearGoal(index),
      onPriorityChanged: (priority) => _setPriority(index, priority),
      onToggleMilestone: (milestoneId, selected) {
        if (milestoneId.trim().isEmpty) return;
        setState(() {
          final ids = _goalMilestoneIds[index];
          if (selected) {
            if (!ids.contains(milestoneId)) ids.add(milestoneId);
          } else {
            ids.remove(milestoneId);
          }
        });
        _saveData();
      },
      onSuggestMilestones: () => _suggestMilestonesForGoal(index),
    );
  }

  // ─── Fixed Footer ───────────────────────────────────────────────
  Widget _buildFixedFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorderColor)),
        boxShadow: [
          BoxShadow(color: _kCardShadow, blurRadius: 8, offset: Offset(0, -2))
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _navigateToNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAccentColor,
            foregroundColor: _kPrimaryText,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Next',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  List<Milestone> get _sortedMilestones {
    final data = ProjectDataHelper.getData(context);
    final milestones = List<Milestone>.from(data.keyMilestones)
      ..removeWhere((m) => m.id.trim().isEmpty);
    milestones.sort((a, b) {
      final aDate = DateTime.tryParse(a.dueDate);
      final bDate = DateTime.tryParse(b.dueDate);
      if (aDate == null && bDate == null) return a.name.compareTo(b.name);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return milestones;
  }

  String _formatDateString(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.trim().isEmpty ? 'No date' : raw.trim();
    return _dateFormat.format(parsed);
  }

  List<String> _goalLabelsForMilestone(String milestoneId) {
    final labels = <String>[];
    for (int i = 0; i < 3; i++) {
      final ids = _goalMilestoneIds[i];
      if (ids.contains(milestoneId)) {
        final title = _goalTitleControllers[i].text.trim();
        labels.add(title.isNotEmpty ? title : 'Goal ${i + 1}');
      }
    }
    return labels;
  }

  Future<void> _suggestMilestonesForGoal(int index) async {
    if (_regeneratingMilestoneSuggestions.contains(index)) return;
    final goalTitle = _goalTitleControllers[index].text.trim();
    final goalDescription = _goalDescControllers[index].text.trim();
    if (goalTitle.isEmpty && goalDescription.isEmpty) return;

    setState(() => _regeneratingMilestoneSuggestions.add(index));
    try {
      final data = ProjectDataHelper.getData(context);
      final goalLabel = goalTitle.isNotEmpty ? goalTitle : 'Goal ${index + 1}';
      final milestoneContext = _sortedMilestones.map((m) {
        return '- ${m.name.trim().isEmpty ? 'Untitled milestone' : m.name.trim()} | ${m.dueDate.trim().isEmpty ? 'No date' : m.dueDate.trim()} | ${m.discipline.trim().isEmpty ? 'No discipline' : m.discipline.trim()}';
      }).join('\n');

      final prompt = '''
You are helping map project goals to existing front-end planning milestones.

Project objective:
${data.projectObjective.trim().isEmpty ? data.businessCase.trim() : data.projectObjective.trim()}

Goal title: $goalLabel
Goal description: ${goalDescription.isEmpty ? 'None provided' : goalDescription}

Existing FEP milestones:
$milestoneContext

Return ONLY valid JSON in this exact shape:
{"recommendedMilestones": ["milestone name 1", "milestone name 2"]}

Rules:
- Recommend only milestones from the provided list.
- Prefer the smallest set of milestones that best supports the goal.
- Return no more than 5 milestone names.
''';

      final response = await _openAi.generateCompletion(
        prompt,
        maxTokens: 300,
        temperature: 0.2,
      );

      final decoded = jsonDecode(response) as Map<String, dynamic>;
      final names = (decoded['recommendedMilestones'] as List?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[];

      final matchedIds = <String>[];
      for (final name in names) {
        final match = _sortedMilestones.cast<Milestone?>().firstWhere(
              (m) =>
                  m != null &&
                  m.name.trim().toLowerCase() == name.toLowerCase(),
              orElse: () => null,
            );
        if (match != null) {
          matchedIds.add(match.id);
        }
      }

      if (matchedIds.isNotEmpty && mounted) {
        setState(() {
          final ids = _goalMilestoneIds[index];
          for (final id in matchedIds) {
            if (!ids.contains(id)) ids.add(id);
          }
        });
        _saveData();
      }
    } catch (_) {
      // Swallow AI parse/suggestion errors for now; UI remains unchanged.
    } finally {
      if (mounted) {
        setState(() => _regeneratingMilestoneSuggestions.remove(index));
      }
    }
  }

  Widget _buildMilestoneTimelineSection() {
    final milestones = _sortedMilestones;
    return _CollapsibleSection(
      title: 'Milestone Timeline',
      subtitle:
          'Front-end planning milestones ordered by date. These become the shared timeline context for goal mapping.',
      child: milestones.isEmpty
          ? const Text(
              'No milestones available yet. Add them in Front End Planning → Milestone.',
              style: TextStyle(fontSize: 13, color: _kSecondaryText))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: milestones.asMap().entries.map((entry) {
                  final i = entry.key;
                  final milestone = entry.value;
                  final goalLabels = _goalLabelsForMilestone(milestone.id);
                  return Row(
                    children: [
                      _TimelineMilestoneChip(
                        title: milestone.name.trim().isEmpty
                            ? 'Untitled milestone'
                            : milestone.name.trim(),
                        date: _formatDateString(milestone.dueDate),
                        discipline: milestone.discipline.trim(),
                        goalCount: goalLabels.length,
                      ),
                      if (i < milestones.length - 1)
                        Container(
                          width: 48,
                          height: 2,
                          margin: const EdgeInsets.only(bottom: 44),
                          color: _kBorderColor,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildMilestoneTableSection() {
    final milestones = _sortedMilestones;
    return _CollapsibleSection(
      title: 'Milestones Table',
      subtitle:
          'All shared milestones from FEP, with the goals currently mapped to each milestone.',
      child: milestones.isEmpty
          ? const Text('No milestones available yet.',
              style: TextStyle(fontSize: 13, color: _kSecondaryText))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                horizontalMargin: 12,
                headingRowColor:
                    WidgetStateProperty.all(const Color(0xFFF5F7FB)),
                columns: const [
                  DataColumn(
                      label: Text('Milestone',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: _kPrimaryText))),
                  DataColumn(
                      label: Text('Date',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: _kPrimaryText))),
                  DataColumn(
                      label: Text('Discipline',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: _kPrimaryText))),
                  DataColumn(
                      label: Text('Mapped Goals',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: _kPrimaryText))),
                  DataColumn(
                      label: Text('References',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: _kPrimaryText))),
                  DataColumn(
                      label: Text('Comments',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: _kPrimaryText))),
                ],
                rows: milestones.map((milestone) {
                  final goalLabels = _goalLabelsForMilestone(milestone.id);
                  return DataRow(cells: [
                    DataCell(Text(milestone.name.trim().isEmpty
                        ? 'Untitled milestone'
                        : milestone.name.trim())),
                    DataCell(Text(_formatDateString(milestone.dueDate))),
                    DataCell(Text(milestone.discipline.trim().isEmpty
                        ? '—'
                        : milestone.discipline.trim())),
                    DataCell(SizedBox(
                      width: 220,
                      child: Text(goalLabels.isEmpty
                          ? 'Unmapped'
                          : goalLabels.join(', ')),
                    )),
                    DataCell(SizedBox(
                      width: 160,
                      child: Text(milestone.references.trim().isEmpty
                          ? '—'
                          : milestone.references.trim()),
                    )),
                    DataCell(SizedBox(
                      width: 220,
                      child: Text(milestone.comments.trim().isEmpty
                          ? '—'
                          : milestone.comments.trim()),
                    )),
                  ]);
                }).toList(),
              ),
            ),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Project Goals & Milestones',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName},
          {'Solution Title': projectData.solutionTitle},
        ]),
        PdfSection.text(
            'Notes',
            projectData
                    .planningNotes['planning_project_framework_next_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}

// ─── Collapsible Section Widget ──────────────────────────────────────
class _CollapsibleSection extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _CollapsibleSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _animCtrl.forward();
      } else {
        _animCtrl.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderColor),
        boxShadow: const [
          BoxShadow(color: _kCardShadow, blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _kPrimaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kSecondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RotationTransition(
                    turns: _anim,
                    child: const Icon(
                      Icons.expand_more,
                      size: 24,
                      color: _kSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _anim,
            axisAlignment: -1.0,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineMilestoneChip extends StatelessWidget {
  const _TimelineMilestoneChip({
    required this.title,
    required this.date,
    required this.discipline,
    required this.goalCount,
  });

  final String title;
  final String date;
  final String discipline;
  final int goalCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: _kAccentColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kLightYellow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kPrimaryText)),
                const SizedBox(height: 4),
                Text(date,
                    style:
                        const TextStyle(fontSize: 12, color: _kSecondaryText)),
                if (discipline.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(discipline,
                      style: const TextStyle(
                          fontSize: 11, color: _kSecondaryText)),
                ],
                const SizedBox(height: 6),
                Text(
                    goalCount == 0
                        ? 'Unmapped'
                        : '$goalCount goal${goalCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kAccentColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── New Goal Card Widget matching HTML design ─────────────────────
class _GoalCardWidget extends StatefulWidget {
  const _GoalCardWidget({
    required this.goalIndex,
    required this.titleController,
    required this.descController,
    required this.yearController,
    required this.availableMilestones,
    required this.selectedMilestoneIds,
    required this.priority,
    required this.titleFocusNode,
    required this.descFocusNode,
    required this.yearFocusNode,
    required this.isSuggestingMilestones,
    required this.onClear,
    required this.onPriorityChanged,
    required this.onToggleMilestone,
    required this.onSuggestMilestones,
  });

  final int goalIndex;
  final TextEditingController titleController;
  final TextEditingController descController;
  final TextEditingController yearController;
  final List<Milestone> availableMilestones;
  final List<String> selectedMilestoneIds;
  final String priority;
  final FocusNode titleFocusNode;
  final FocusNode descFocusNode;
  final FocusNode yearFocusNode;
  final bool isSuggestingMilestones;
  final VoidCallback onClear;
  final ValueChanged<String> onPriorityChanged;
  final void Function(String milestoneId, bool selected) onToggleMilestone;
  final Future<void> Function() onSuggestMilestones;

  @override
  State<_GoalCardWidget> createState() => _GoalCardWidgetState();
}

class _GoalCardWidgetState extends State<_GoalCardWidget> {
  final DateFormat _dateFormat = DateFormat('MMM d, y');

  @override
  void initState() {
    super.initState();
  }

  String _formatMilestoneDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.trim().isEmpty ? 'No date' : raw.trim();
    return _dateFormat.format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(widget.priority);
    final priorityBg = _priorityBackground(widget.priority);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderColor),
        boxShadow: const [
          BoxShadow(color: _kCardShadow, blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gray header bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: _kBorderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: VoiceTextField(
                    controller: widget.titleController,
                    focusNode: widget.titleFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Goal ${widget.goalIndex + 1} Title',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _kPrimaryText),
                  ),
                ),
                const SizedBox(width: 8),
                // Priority badge pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: priorityColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        initialValue: widget.priority,
                        onSelected: widget.onPriorityChanged,
                        offset: const Offset(0, 28),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.priority,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: priorityColor,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 14, color: _kSecondaryText),
                          ],
                        ),
                        itemBuilder: (context) => _kPriorityOptions
                            .map((option) => PopupMenuItem(
                                value: option, child: Text(option)))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Delete/trash button
                InkWell(
                  onTap: widget.onClear,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 18, color: _kSecondaryText),
                  ),
                ),
              ],
            ),
          ),
          // ── Card body ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                const Text('Description',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _kSecondaryText)),
                const SizedBox(height: 6),
                VoiceTextField(
                  controller: widget.descController,
                  focusNode: widget.descFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Enter description',
                    hintStyle:
                        const TextStyle(color: _kSecondaryText, fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _kBorderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _kBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: _kAccentColor, width: 1.5),
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14, color: _kPrimaryText),
                ),
                const SizedBox(height: 16),
                // ── Milestones sub-section (mapped from FEP) ──
                const Divider(height: 1, color: _kLightGray),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kLightYellow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Mapped FEP Milestones',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _kPrimaryText),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: widget.isSuggestingMilestones
                                ? null
                                : widget.onSuggestMilestones,
                            icon: widget.isSuggestingMilestones
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_awesome, size: 16),
                            label: const Text('Suggest'),
                            style: TextButton.styleFrom(
                                foregroundColor: _kAccentColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select milestones defined in Front End Planning. A milestone can support multiple goals.',
                        style: TextStyle(
                            fontSize: 12, color: _kSecondaryText, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      if (widget.availableMilestones.isEmpty)
                        const Text(
                          'No FEP milestones available yet. Add them in Front End Planning → Milestone.',
                          style:
                              TextStyle(fontSize: 12, color: _kSecondaryText),
                        )
                      else
                        ...widget.availableMilestones
                            .where((m) => m.id.trim().isNotEmpty)
                            .map((milestone) {
                          final selected = widget.selectedMilestoneIds
                              .contains(milestone.id);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => widget.onToggleMilestone(
                                  milestone.id, !selected),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.white
                                      : const Color(0x80FFFFFF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selected
                                        ? _kAccentColor
                                        : const Color(0xFFFFE082),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: selected,
                                      onChanged: (value) =>
                                          widget.onToggleMilestone(
                                              milestone.id, value ?? false),
                                      activeColor: _kAccentColor,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            milestone.name.trim().isEmpty
                                                ? 'Untitled milestone'
                                                : milestone.name.trim(),
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _kPrimaryText),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_formatMilestoneDate(milestone.dueDate)}${milestone.discipline.trim().isEmpty ? '' : ' • ${milestone.discipline.trim()}'}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: _kSecondaryText),
                                          ),
                                          if (milestone.comments
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              milestone.comments.trim(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: _kSecondaryText),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: widget.onClear,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Text(
                              'Clear goal',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _kSecondaryText),
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
        ],
      ),
    );
  }
}
