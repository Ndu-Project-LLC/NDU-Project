import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/screens/planning_requirements_screen.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/planning_goal_milestone_mapping_service.dart';
import 'package:ndu_project/utils/milestone_date.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';

import 'package:ndu_project/widgets/collapsible_notes_section.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/screens/wbs_module_screen.dart';
import 'package:ndu_project/wbs/utils/wbs_to_work_item_converter.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';

const Color _kAccentColor = Color(0xFFFFC107);
const Color _kPrimaryText = Color(0xFF1E293B);
const Color _kSecondaryText = Color(0xFF64748B);
const Color _kBorderColor = Color(0xFFE2E8F0);
const Color _kCardShadow = Color(0x14000000);
const Color _kLightYellow = Color(0xFFFFF8E1);
const Color _kLightBlue = Color(0xFFFFF8E1);
const Color _kGreenBrand = Color(0xFF22C55E);
const Color _kLightGray = Color(0xFFF1F5F9);
const List<String> _kPriorityOptions = [
  'High Priority',
  'Medium Priority',
  'Low Priority'
];

/// How the milestones section is presented. The owner asked for tabs on the
/// milestones area: "I think we need tabs here."
enum _MilestoneView { table, timeline }

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
    context.push('/project-framework-next');
  }

  @override
  State<ProjectFrameworkNextScreen> createState() =>
      _ProjectFrameworkNextScreenState();
}

class _ProjectFrameworkNextScreenState
    extends State<ProjectFrameworkNextScreen> {
  final List<TextEditingController> _goalTitleControllers = [];
  final List<TextEditingController> _goalDescControllers = [];
  final List<TextEditingController> _goalYearControllers = [];
  final List<String> _goalIds = [];
  final List<List<String>> _goalMilestoneIds = [];
  final List<String> _goalPriorities = [];

  /// The WBS Level-1 code each goal slot came from ("G1"). Persisted with the
  /// goal so the milestone mapping survives the WBS node being re-created with
  /// a new id.
  final List<String> _goalWbsCodes = [];

  /// Signature of the WBS goals currently laid out in the slots. The page
  /// rebuilds the slots when the WBS's goals change underneath it.
  String _goalSignature = '';
  final DateFormat _dateFormat = DateFormat('MMM d, y');
  late final OpenAiServiceSecure _openAi;
  final Set<int> _regeneratingMilestoneSuggestions = <int>{};

  /// Whether the goals shown came from the WBS (rather than from the goals
  /// already saved on the project, which is the fallback for a project whose
  /// WBS has not been built yet).
  bool _goalsComeFromWbs = false;

  /// Whether this project's WBS is Agile, where Level-1 items are epics.
  bool _wbsIsAgile = false;

  /// True once the first load has laid the page out. The WBS-change hook stays
  /// out of the way until then, so it cannot fight the initial load.
  bool _pageLoaded = false;

  /// Which tab of the milestones section is showing.
  _MilestoneView _milestoneView = _MilestoneView.table;

  /// Signature of the milestone list the user has confirmed (Lusaka 15 item 3:
  /// the milestones are validated *before* they are mapped to goals). Empty
  /// means not confirmed; it is compared against the current list, so editing a
  /// milestone reopens the step.
  String _confirmedMilestoneSignature = '';

  // FocusNodes for auto-save on blur
  final List<FocusNode> _titleFocusNodes = [];
  final List<FocusNode> _descFocusNodes = [];
  final List<FocusNode> _yearFocusNodes = [];

  String _potentialSolution = '';
  String _projectObjective = '';
  String _currentFilter = 'View All';
  final TextEditingController _notesController = SpellCheckTextEditingController();

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
    for (int i = 0; i < _goalTitleControllers.length; i++) {
      planningGoals.add(PlanningGoal(
        id: _goalIds[i].trim().isNotEmpty ? _goalIds[i] : null,
        goalNumber: i + 1,
        title: _goalTitleControllers[i].text.trim(),
        description: _goalDescControllers[i].text.trim(),
        targetYear: _goalYearControllers[i].text.trim(),
        priority: _goalPriorities[i],
        wbsCode: _goalWbsCodes[i],
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
          'planning_milestones_validated': _confirmedMilestoneSignature,
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

      // Goals are the WBS's Level-1 items (Lusaka 15). [_rebuildGoalSlots]
      // lays the slots out and is re-run if the WBS changes while this page is
      // open.
      _rebuildGoalSlots(projectData);

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

      // Setup focus listeners for auto-save on blur
      for (int i = 0; i < _goalTitleControllers.length; i++) {
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
      _confirmedMilestoneSignature =
          projectData.planningNotes['planning_milestones_validated'] ?? '';

      // Setup notes controller auto-save
      _notesController.addListener(_onFieldChanged);

      // Remember which WBS goals are on screen so a later WBS change is noticed.
      _goalSignature = _goalSignatureFor(_wbsGoalItems());
      _pageLoaded = true;

      setState(() {});
    });
  }

  /// The project goals as the WBS holds them: its Level-1 items.
  ///
  /// Lusaka 15: "they should not be able to add any goal here … The WBS is the
  /// source of truth for the project goals because they are just the second
  /// layer of the WBS." The live WBS is preferred — it is what the builder
  /// edits — with the saved `wbsTree` as the fallback for a project whose WBS
  /// has not been built in this session.
  List<WorkItem> _wbsGoalItems() {
    final wbs = _wbsProviderOrNull()?.wbs;
    if (wbs != null && wbs.level0.children.isNotEmpty) {
      return wbsNodeToWorkItems(wbs.level0)
          .where((item) => item.title.trim().isNotEmpty)
          .toList(growable: false);
    }
    return ProjectDataHelper.getData(context)
        .wbsTree
        .where((item) => item.title.trim().isNotEmpty)
        .toList(growable: false);
  }

  /// The WBS provider, or null where none is mounted (widget tests and deep
  /// links that render this page outside the shell) — the page then falls back
  /// to the saved WBS tree instead of throwing.
  WBSProvider? _wbsProviderOrNull() {
    try {
      return Provider.of<WBSProvider>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// The goal already saved on the project that a WBS-derived goal maps to.
  ///
  /// Matched on the WBS code first (stable when the node is re-created), then
  /// on the node id, then on the title, so renaming or rebuilding a goal in the
  /// WBS still carries its priority and its milestone mapping across.
  PlanningGoal? _savedGoalFor(
    List<PlanningGoal> saved, {
    required String id,
    required String wbsCode,
    required String title,
  }) {
    final code = wbsCode.trim().toLowerCase();
    if (code.isNotEmpty) {
      for (final goal in saved) {
        if (goal.wbsCode.trim().toLowerCase() == code) return goal;
      }
    }
    final trimmedId = id.trim();
    if (trimmedId.isNotEmpty) {
      for (final goal in saved) {
        if (goal.id.trim() == trimmedId) return goal;
      }
    }
    final normalizedTitle = title.trim().toLowerCase();
    if (normalizedTitle.isNotEmpty) {
      for (final goal in saved) {
        if (goal.title.trim().toLowerCase() == normalizedTitle) return goal;
      }
    }
    return null;
  }

  /// Identity of the goal slots currently laid out, in order.
  List<({String id, String wbsCode, String title})> get _currentGoalIdentity {
    return List<({String id, String wbsCode, String title})>.generate(
      _goalTitleControllers.length,
      (i) => (
        id: _goalIds[i],
        wbsCode: _goalWbsCodes[i],
        title: _goalTitleControllers[i].text.trim(),
      ),
      growable: false,
    );
  }

  /// The slot that a goal source was already being shown in, or -1.
  int _carriedSlotFor(
    List<({String id, String wbsCode, String title})> previous,
    ({String id, String wbsCode, String title}) source,
  ) {
    final code = source.wbsCode.trim().toLowerCase();
    final id = source.id.trim();
    final title = source.title.trim().toLowerCase();
    for (var i = 0; i < previous.length; i++) {
      if (code.isNotEmpty &&
          previous[i].wbsCode.trim().toLowerCase() == code) {
        return i;
      }
    }
    for (var i = 0; i < previous.length; i++) {
      if (id.isNotEmpty && previous[i].id.trim() == id) return i;
    }
    for (var i = 0; i < previous.length; i++) {
      if (title.isNotEmpty &&
          previous[i].title.trim().toLowerCase() == title) {
        return i;
      }
    }
    return -1;
  }

  /// Lays out the goal slots from the WBS (and its fallbacks).
  ///
  /// The WBS owns the goals — they are its Level-1 items — so nothing here
  /// invents one. What this page owns, the priority and the milestone mapping,
  /// is carried over from the in-memory slot first, then from the goal saved on
  /// the project, so a rebuild never drops a mapping.
  void _rebuildGoalSlots(ProjectDataModel projectData) {
    final wbsGoals = _wbsGoalItems();
    _goalsComeFromWbs = wbsGoals.isNotEmpty;
    final savedGoals = projectData.planningGoals
        .where((g) =>
            g.title.trim().isNotEmpty || g.description.trim().isNotEmpty)
        .toList(growable: false);

    final sources =
        <({String id, String wbsCode, String title, String description})>[];
    if (wbsGoals.isNotEmpty) {
      for (final item in wbsGoals) {
        sources.add((
          id: item.id,
          wbsCode: item.wbsCode.trim(),
          title: item.title.trim(),
          description: item.description.trim(),
        ));
      }
    } else if (savedGoals.isNotEmpty) {
      for (final goal in savedGoals) {
        sources.add((
          id: goal.id,
          wbsCode: goal.wbsCode.trim(),
          title: goal.title.trim(),
          description: goal.description.trim(),
        ));
      }
    } else {
      for (final goal in projectData.projectGoals) {
        sources.add((
          id: '',
          wbsCode: '',
          title: goal.name.trim(),
          description: goal.description.trim(),
        ));
      }
    }

    final previous = _currentGoalIdentity;
    final carried = <int,
        ({String priority, String targetYear, List<String> milestoneIds})>{};
    for (var i = 0; i < previous.length; i++) {
      carried[i] = (
        priority: _goalPriorities[i],
        targetYear: _goalYearControllers[i].text,
        milestoneIds: List<String>.from(_goalMilestoneIds[i]),
      );
    }

    final staleTitle = _goalTitleControllers.toList(growable: false);
    final staleDesc = _goalDescControllers.toList(growable: false);
    final staleYear = _goalYearControllers.toList(growable: false);
    final staleFocus = <FocusNode>[
      ..._titleFocusNodes,
      ..._descFocusNodes,
      ..._yearFocusNodes,
    ];

    _goalTitleControllers.clear();
    _goalDescControllers.clear();
    _goalYearControllers.clear();
    _goalIds.clear();
    _goalMilestoneIds.clear();
    _goalPriorities.clear();
    _goalWbsCodes.clear();
    _titleFocusNodes.clear();
    _descFocusNodes.clear();
    _yearFocusNodes.clear();

    for (final source in sources) {
      final saved = _savedGoalFor(
        savedGoals,
        id: source.id,
        wbsCode: source.wbsCode,
        title: source.title,
      );
      final carriedSlot = carried[_carriedSlotFor(previous, (
        id: source.id,
        wbsCode: source.wbsCode,
        title: source.title,
      ))];

      final priority = carriedSlot?.priority ??
          ((saved != null && saved.priority.isNotEmpty)
              ? saved.priority
              : 'Medium Priority');
      final targetYear = carriedSlot?.targetYear ?? saved?.targetYear ?? '';
      final milestoneIds = carriedSlot?.milestoneIds ??
          (saved == null ? <String>[] : List<String>.from(saved.milestoneIds));

      final title = SpellCheckTextEditingController(text: source.title);
      final desc = SpellCheckTextEditingController(text: source.description);
      final year = SpellCheckTextEditingController(text: targetYear);
      final titleFocus = FocusNode();
      final descFocus = FocusNode();
      final yearFocus = FocusNode();

      _goalTitleControllers.add(title);
      _goalDescControllers.add(desc);
      _goalYearControllers.add(year);
      _goalIds.add(source.id);
      _goalMilestoneIds.add(milestoneIds);
      _goalPriorities.add(priority);
      _goalWbsCodes.add(source.wbsCode);
      _titleFocusNodes.add(titleFocus);
      _descFocusNodes.add(descFocus);
      _yearFocusNodes.add(yearFocus);

      // Keep the goal filter pills in step with the titles.
      title.addListener(() {
        if (mounted) setState(() {});
      });
      for (final controller in <TextEditingController>[title, desc, year]) {
        controller.addListener(_onFieldChanged);
      }
      titleFocus.addListener(() {
        if (!titleFocus.hasFocus) _saveData();
      });
      descFocus.addListener(() {
        if (!descFocus.hasFocus) _saveData();
      });
      yearFocus.addListener(() {
        if (!yearFocus.hasFocus) _saveData();
      });
    }

    // The replaced controllers belong to widgets that are about to be unmounted
    // by the rebuild that follows, so let the frame finish before disposing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in <TextEditingController>[
        ...staleTitle,
        ...staleDesc,
        ...staleYear,
      ]) {
        controller.dispose();
      }
      for (final node in staleFocus) {
        node.dispose();
      }
    });
  }

  /// Signature of a WBS goal list, used to notice that the goals changed.
  String _goalSignatureFor(List<WorkItem> goals) => goals
      .map((g) => '${g.wbsCode.trim()}|${g.id}|${g.title.trim()}')
      .join('~');

  /// Rebuilds the goal slots when the WBS's goals change while the page is open
  /// (a goal added in another tab, or through the WBS deep link).
  void _maybeRebuildGoalSlots() {
    if (!_pageLoaded) return;
    final signature = _goalSignatureFor(_wbsGoalItems());
    if (signature == _goalSignature) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_goalSignatureFor(_wbsGoalItems()) != signature) return;
      if (signature == _goalSignature) return;
      _rebuildGoalSlots(ProjectDataHelper.getData(context));
      setState(() {});
    });
  }

  /// Opens the Work Breakdown Structure — where the goals are authored.
  void _openWorkBreakdownStructure() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WBSModuleScreen()),
    );
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
    for (int i = 0; i < _goalTitleControllers.length; i++) {
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

    final planningGoals = List.generate(_goalTitleControllers.length, (i) {
      return PlanningGoal(
        id: _goalIds[i].trim().isNotEmpty ? _goalIds[i] : null,
        goalNumber: i + 1,
        title: _goalTitleControllers[i].text.trim(),
        description: _goalDescControllers[i].text.trim(),
        targetYear: _goalYearControllers[i].text.trim(),
        priority: _goalPriorities[i],
        wbsCode: _goalWbsCodes[i],
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

  /// Subscribes to the WBS so a goal added or renamed there reaches this page
  /// without a reload. Absent providers are fine — the saved WBS tree still
  /// drives the goals.
  ///
  /// Returns whether the WBS is Agile, so the page can call its Level-1 items
  /// epics rather than goals ("For waterfall, we are calling them goals … for
  /// agile … that is the epic").
  bool _watchWbs() {
    try {
      return context.watch<WBSProvider>().wbs?.methodology ==
          ProjectMethodology.agile;
    } on ProviderNotFoundException {
      // No WBS provider mounted (widget tests, deep links).
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    _wbsIsAgile = _watchWbs();
    _maybeRebuildGoalSlots();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: isMobile
          ? Drawer(
              width: AppBreakpoints.sidebarWidth(context),
              child: const SafeArea(
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
                        const MobileSidebarHamburger(
                          sidebar: InitiationLikeSidebar(
                            activeItemLabel: 'Project Goals & Milestones',
                          ),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 80),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            // Landing order (Lusaka 15): Project Goals first,
                            // then the milestone table, then the goal↔milestone
                            // mapping. The owner: "I think this project goals has
                            // to be at the top. … And then the milestones has to
                            // be under it. And then the mapping has to happen."
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildNotesSection(),
                                const SizedBox(height: 16),
                                _buildContextSection(),
                                const SizedBox(height: 16),
                                _buildGoalsSection(isMobile: isMobile),
                                const SizedBox(height: 16),
                                _buildMilestonesSection(),
                                const SizedBox(height: 16),
                                _buildGoalMappingSection(isMobile: isMobile),
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

  // ─── Notes Section ──────────────────────────────────────────────
  // Starts collapsed: the owner's ask is that the notes editor stays hidden
  // ("it's great to have the notes at the top where it needs to be hidden") so
  // the page opens on usable content instead of a large notes box.
  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderColor),
        boxShadow: const [
          BoxShadow(color: _kCardShadow, blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: CollapsibleNotesSection(
        title: 'Notes',
        icon: Icons.description_outlined,
        iconColor: _kAccentColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
  /// What the WBS's Level-1 items are called on this page.
  ///
  /// Waterfall calls them goals; Agile calls them epics ("For waterfall, we are
  /// calling them goals … for agile … that is the epic"). The WBS itself labels
  /// Level 1 as "Epic" for Agile, so the page follows the project's
  /// methodology and the two never disagree.
  String get _level1Noun => _wbsIsAgile ? 'Epic' : 'Goal';
  String get _level1NounPlural => _wbsIsAgile ? 'Epics' : 'Goals';
  String get _level1NounLower => _wbsIsAgile ? 'epic' : 'goal';

  Widget _buildGoalsSection({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                  text: 'Project $_level1NounPlural',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _kPrimaryText)),                const TextSpan(
                    text:
                        ' (The second level of the Work Breakdown Structure)',
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
              for (int i = 0; i < _goalTitleControllers.length; i++) ...[
                _buildFilterPill(
                  label: '$_level1Noun ${i + 1}',
                  value: '$_level1Noun ${i + 1}',
                  isActive: _currentFilter == '$_level1Noun ${i + 1}',
                  activeColor: i % 2 == 0 ? _kAccentColor : const Color(0xFFFFC812),
                  activeBgColor: i % 2 == 0 ? _kLightYellow : _kLightBlue,
                ),
                const SizedBox(width: 8),
              ],
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: Color(0xFFFFC812)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_level1Noun milestones would be a foundation for the project schedule. Focus on the key milestones required for project success.',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFFFC812), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Goal cards
        if (isMobile || _currentFilter != 'View All')
          ...List.generate(_goalTitleControllers.length, (i) {
            if (_currentFilter != 'View All' &&
                _currentFilter != '$_level1Noun ${i + 1}') {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildGoalCard(i),
            );
          })
        else
          Wrap(
            spacing: 12,
            runSpacing: 16,
            children: List.generate(_goalTitleControllers.length, (i) {
              return SizedBox(
                width: 350,
                child: _buildGoalCard(i),
              );
            }),
          ),
        const SizedBox(height: 16),
        // No "Add goal" affordance: goals are the WBS's Level-1 items, so
        // they are added, renamed and removed in the WBS.
        _buildWbsGoalsNotice(),
      ],
    );
  }

  /// Says where goals are authored and takes the user there.
  ///
  /// Replaces the old "Add Goal" button: the owner's ask is that a goal cannot
  /// be created on this page at all ("they should not be able to add any goal
  /// here. If that goal should take them to the WBS section.").
  Widget _buildWbsGoalsNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_tree_outlined,
              size: 18, color: _kSecondaryText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _goalsComeFromWbs
                  ? 'These ${_level1NounLower}s come from the Work Breakdown '
                      'Structure — they are its second level. Add, rename or '
                      'remove them there and they flow through to this page.'
                  : 'No ${_level1NounLower}s are defined yet. $_level1NounPlural '
                      'are the second level of the Work Breakdown Structure — '
                      'create them there and they appear here.',
              style: const TextStyle(
                  fontSize: 12.5, color: _kSecondaryText, height: 1.4),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _openWorkBreakdownStructure,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open Work Breakdown Structure'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kAccentColor,
              side: const BorderSide(color: _kAccentColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
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

  // ─── Milestone validation (before mapping) ──────────────────────
  /// Identity of a milestone list. Confirming the list stores this, so adding,
  /// renaming, re-dating or removing a milestone invalidates the confirmation
  /// and sends the user back through the validate step.
  String _milestoneSignatureOf(List<Milestone> milestones) {
    final parts = milestones
        .map((m) => '${m.id}|${m.name.trim()}|${m.dueDate.trim()}')
        .toList(growable: false)
      ..sort();
    return parts.join('~');
  }

  String get _currentMilestoneSignature => _milestoneSignatureOf(
        ProjectDataHelper.getData(context).keyMilestones,
      );

  bool get _milestonesConfirmed =>
      _confirmedMilestoneSignature.isNotEmpty &&
      _confirmedMilestoneSignature == _currentMilestoneSignature;

  void _confirmMilestones() {
    setState(
        () => _confirmedMilestoneSignature = _currentMilestoneSignature);
    _saveData();
  }

  void _reopenMilestoneValidation() {
    setState(() => _confirmedMilestoneSignature = '');
    _saveData();
  }

  /// The validate step itself.
  ///
  /// The owner: "start from like the milestones, validate the milestones so
  /// there'll be a prompt … validate them and then add any milestones in the
  /// list and then delete any, if they don't need those. Before they then go to
  /// the goals and then they should be able to open each goal up and map the
  /// applicable milestones to each goal."
  Widget _buildMilestoneValidationRow() {
    final confirmed = _milestonesConfirmed;
    final hasMilestones = _sortedMilestones.isNotEmpty;
    const confirmedGreen = Color(0xFF10B981);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: confirmed ? const Color(0xFFECFDF5) : _kLightGray,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: confirmed ? confirmedGreen : _kBorderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            confirmed ? Icons.verified_outlined : Icons.rule_outlined,
            size: 18,
            color: confirmed ? confirmedGreen : _kSecondaryText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              confirmed
                  ? 'Milestone list validated. The $_level1NounLower mapping '
                      'below is open; changing a milestone reopens this step.'
                  : 'Validate the milestone list first — add, edit or delete '
                      'milestones in Front End Planning → Milestone, then '
                      'confirm. The $_level1NounLower mapping below opens once '
                      'it is confirmed.',
              style: const TextStyle(
                  fontSize: 12, color: _kSecondaryText, height: 1.4),
            ),
          ),
          const SizedBox(width: 12),
          if (confirmed)
            TextButton(
              onPressed: _reopenMilestoneValidation,
              child: const Text('Change milestones'),
            )
          else
            FilledButton(
              onPressed: hasMilestones ? _confirmMilestones : null,
              style: FilledButton.styleFrom(
                backgroundColor: _kAccentColor,
                foregroundColor: _kPrimaryText,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: const Color(0xFF9CA3AF),
              ),
              child: const Text('Confirm milestone list'),
            ),
        ],
      ),
    );
  }

  /// Shown in place of the mapping until the milestones are validated.
  Widget _buildMappingGate(bool hasMilestones) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Text(
        hasMilestones
            ? 'Confirm the milestone list in the Milestones section above '
                'first — the mapping opens once it is validated.'
            : 'No milestones to map yet. Add them in Front End Planning → '
                'Milestone, then come back and confirm the list.',
        style: const TextStyle(
            fontSize: 13, color: Color(0xFF9A3412), height: 1.4),
      ),
    );
  }

  // ─── Goal → Milestone mapping ───────────────────────────────────
  /// The mapping step, below the goals and the milestone table.
  ///
  /// The goals themselves are defined in the section above; this is where each
  /// goal is opened and the Front End Planning milestones that support it are
  /// ticked. The owner: "they should be able to open each goal up and map the
  /// applicable milestones to each goal."
  Widget _buildGoalMappingSection({required bool isMobile}) {
    final milestones = _sortedMilestones;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Project $_level1NounPlural → Milestones',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _kPrimaryText)),
        const SizedBox(height: 4),
        Text(
          _goalTitleControllers.isEmpty
              ? 'No ${_level1NounLower}s to map yet — define them in the Work '
                  'Breakdown Structure first.'
              : milestones.isEmpty
                  ? 'No milestones to map yet. Add them in Front End Planning → '
                      'Milestone first.'
                  : 'Map the milestones that support each $_level1NounLower. '
                      'A milestone can support more than one $_level1NounLower.',
          style: const TextStyle(
              fontSize: 13, color: _kSecondaryText, height: 1.4),
        ),
        const SizedBox(height: 16),
        // The mapping used to sit in 350-wide cards, which the owner read as
        // "very small and it's hard to tell what is happening". It is now one
        // full-width card per goal, with no scroll inside a scroll.
        if (!_milestonesConfirmed)
          _buildMappingGate(milestones.isNotEmpty)
        else if (_goalTitleControllers.isEmpty)
          Text(
            'No ${_level1NounLower}s to map yet — define them in the Work '
            'Breakdown Structure.',
            style: const TextStyle(fontSize: 13, color: _kSecondaryText),
          )
        else
          ...List.generate(_goalTitleControllers.length, (i) {
            if (_currentFilter != 'View All' &&
                _currentFilter != '$_level1Noun ${i + 1}') {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildGoalMappingCard(i),
            );
          }),
      ],
    );
  }

  // ─── Goal Card (new HTML design) ────────────────────────────────
  Widget _buildGoalCard(int index) {
    return _GoalCardWidget(
      showGoalDetails: true,
      showMilestoneMapping: false,
      level1Noun: _level1Noun,
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

  /// One goal's milestone mapping, with the goal it belongs to named at the
  /// top so the card stands alone in the mapping section.
  Widget _buildGoalMappingCard(int index) {
    return _GoalCardWidget(
      showGoalDetails: false,
      showMilestoneMapping: true,
      level1Noun: _level1Noun,
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

  /// Every milestone, **earliest first** — the chronological order the owner
  /// asked for ("starting from December, 2026. This is the first milestone.").
  ///
  /// Target dates are free text, so the comparison goes through
  /// [parseMilestoneDate], which reads the month / quarter forms as well as
  /// ISO. Milestones with no readable date sort last, by name.
  List<Milestone> get _sortedMilestones {
    final data = ProjectDataHelper.getData(context);
    final milestones = List<Milestone>.from(data.keyMilestones)
      ..removeWhere((m) => m.id.trim().isEmpty);
    milestones.sort((a, b) {
      final aDate = parseMilestoneDate(a.dueDate);
      final bDate = parseMilestoneDate(b.dueDate);
      if (aDate == null && bDate == null) return a.name.compareTo(b.name);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return milestones;
  }

  /// How a milestone's target date is shown.
  ///
  /// An ISO date gets the house format. Free-text values (`Q3 2026`,
  /// `December 2026`) are already readable and are shown as typed rather than
  /// being rendered as the first day of the period, which would imply a
  /// precision the milestone does not have.
  String _formatDateString(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return 'No date';
    final parsed = DateTime.tryParse(text);
    if (parsed != null && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(text)) {
      return _dateFormat.format(parsed);
    }
    return text;
  }

  /// The goals a milestone is mapped to, by name.
  ///
  /// This walks the live goal lists rather than a fixed three slots: the
  /// columns are filled asynchronously, so on an early build (the milestone
  /// table renders before the goals have loaded) indexing slot 0 of an empty
  /// list threw a RangeError and took the page down.
  List<String> _goalLabelsForMilestone(String milestoneId) {
    final labels = <String>[];
    final count = _goalMilestoneIds.length;
    for (int i = 0; i < count; i++) {
      final ids = _goalMilestoneIds[i];
      if (ids.contains(milestoneId)) {
        final title = i < _goalTitleControllers.length
            ? _goalTitleControllers[i].text.trim()
            : '';
        labels.add(title.isNotEmpty ? title : '$_level1Noun ${i + 1}');
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
      final goalLabel =
          goalTitle.isNotEmpty ? goalTitle : '$_level1Noun ${index + 1}';
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

  // ─── Milestones (Table | Timeline tabs) ─────────────────────────
  /// The milestones area: one section with **Table / Timeline** tabs instead of
  /// two stacked sections.
  ///
  /// The table is the default because it is the validate-and-edit step (every
  /// milestone with its date, discipline, mapped goals, references and
  /// comments); the timeline renders the same milestones in chronological
  /// order, earliest first. The section starts expanded so the page opens on
  /// usable content rather than a collapsed heading.
  Widget _buildMilestonesSection() {
    final milestones = _sortedMilestones;
    return _CollapsibleSection(
      title: 'Milestones',
      subtitle:
          'Every milestone from Front End Planning, earliest first. Add or edit them in Front End Planning → Milestone, then map them to goals below.',
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildMilestoneTab('Table', _MilestoneView.table),
              const SizedBox(width: 8),
              _buildMilestoneTab('Timeline', _MilestoneView.timeline),
            ],
          ),
          const SizedBox(height: 12),
          if (milestones.isEmpty)
            const Text(
              'No milestones available yet. Add them in Front End Planning → Milestone.',
              style: TextStyle(fontSize: 13, color: _kSecondaryText),
            )
          else if (_milestoneView == _MilestoneView.table)
            _buildMilestoneTable(milestones)
          else
            _buildMilestoneTimeline(milestones),
          const SizedBox(height: 12),
          _buildMilestoneValidationRow(),
        ],
      ),
    );
  }

  Widget _buildMilestoneTab(String label, _MilestoneView view) {
    final isActive = _milestoneView == view;
    return GestureDetector(
      onTap: () => setState(() => _milestoneView = view),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _kLightYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? _kAccentColor : _kBorderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? _kPrimaryText : _kSecondaryText,
          ),
        ),
      ),
    );
  }

  /// The milestones read left-to-right in date order. [_sortedMilestones]
  /// already puts them earliest first, so nothing here re-orders them.
  Widget _buildMilestoneTimeline(List<Milestone> milestones) {
    // Readability (Lusaka 15 item 4): say what the order is, number the
    // sequence, and lead each card with the date — the owner's complaint was
    // that the view was "not user friendly at all".
    final earliest = _formatDateString(milestones.first.dueDate);
    final latest = _formatDateString(milestones.last.dueDate);
    final datedCount = milestones
        .where((m) => parseMilestoneDate(m.dueDate) != null)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Earliest first · ${milestones.length} milestone'
          '${milestones.length == 1 ? '' : 's'}'
          '${datedCount == 0 ? '' : ' · $earliest → $latest'}',
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimaryText),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
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
                    step: i + 1,
                    level1Noun: _level1Noun,
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
      ],
    );
  }

  Widget _buildMilestoneTable(List<Milestone> milestones) {
    return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: buildNduDataTable(context: context, 
                columnSpacing: 20,
                horizontalMargin: 12,
                headingRowColor: const Color(0xFFF5F7FB),
                columns: [
                  const DataColumn(
                      label: Text('Milestone',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: _kPrimaryText))),
                  const DataColumn(
                      label: Text('Date',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: _kPrimaryText))),
                  const DataColumn(
                      label: Text('Discipline',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: _kPrimaryText))),
                  DataColumn(
                      label: Text('Mapped $_level1NounPlural',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: _kPrimaryText))),
                  const DataColumn(
                      label: Text('References',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: _kPrimaryText))),
                  const DataColumn(
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

  /// Whether the section starts open. Defaults to false — a section is closed
  /// until the user opens it — but the milestones section opts in so the page
  /// lands on usable content (owner: "You have to have like content that is
  /// usable.").
  final bool initiallyExpanded;

  const _CollapsibleSection({
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded = widget.initiallyExpanded;
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
    // An initially-open section must start at the end of the animation, or the
    // size animation would still be collapsed on the first frame.
    if (_expanded) _animCtrl.value = 1.0;
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
    required this.step,
    required this.title,
    required this.date,
    required this.discipline,
    required this.goalCount,
    this.level1Noun = 'Goal',
  });

  /// Position in the chronological sequence, shown as "1", "2", … so the order
  /// is readable at a glance.
  final int step;
  final String title;
  final String date;
  final String discipline;
  final int goalCount;

  /// What this project calls a Level-1 WBS item: a goal, or an epic (Agile).
  final String level1Noun;

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
                // The date leads: "so it should be clear what those main
                // milestone dates are."
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _kAccentColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$step',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _kPrimaryText)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(date,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kPrimaryText)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kSecondaryText)),
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
                        : '$goalCount ${level1Noun.toLowerCase()}'
                            '${goalCount == 1 ? '' : 's'}',
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
    this.showGoalDetails = true,
    this.showMilestoneMapping = true,
    this.level1Noun = 'Goal',
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

  /// Whether the goal's title / priority / description are editable here.
  ///
  /// The landing page defines goals in its own section and maps milestones in
  /// the one below it, so the two halves of this card are shown separately.
  final bool showGoalDetails;

  /// Whether the "Mapped FEP Milestones" picker is shown here.
  final bool showMilestoneMapping;

  /// What this project calls a Level-1 WBS item: a goal, or an epic (Agile).
  final String level1Noun;

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
    final text = raw.trim();
    if (text.isEmpty) return 'No date';
    final parsed = DateTime.tryParse(text);
    if (parsed != null && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(text)) {
      return _dateFormat.format(parsed);
    }
    return text;
  }

  /// Names the goal whose milestones this card maps. Shown instead of the
  /// editable title bar when the card is rendered in the mapping section.
  Widget _buildMappingHeader() {
    final title = widget.titleController.text.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: _kBorderColor)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kLightYellow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _kAccentColor),
            ),
            child: Text(
              '${widget.level1Noun} ${widget.goalIndex + 1}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kPrimaryText,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title.isEmpty
                  ? 'Untitled ${widget.level1Noun.toLowerCase()}'
                  : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: title.isEmpty ? _kSecondaryText : _kPrimaryText,
              ),
            ),
          ),
        ],
      ),
    );
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
          // ── Header ──
          // The mapping section renders only the milestones half of the card,
          // so it gets a compact header naming the goal instead of the
          // editable title bar.
          if (!widget.showGoalDetails) _buildMappingHeader(),
          if (widget.showGoalDetails)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: _kBorderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Read-only: the goal is defined in the WBS. Editing it here
                // was how a goal could be created independently of the WBS.
                VoiceTextField(
                  controller: widget.titleController,
                  focusNode: widget.titleFocusNode,
                  maxLines: 3,
                  readOnly: true,
                  enabled: false,
                  enableVoice: false,
                  enableKazAi: false,
                  enableDocxImport: false,
                  enableTextFormatting: false,
                  decoration: InputDecoration(
                    hintText:
                        '${widget.level1Noun} ${widget.goalIndex + 1} Title',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _kPrimaryText),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
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
              ],
            ),
          ),
          // ── Card body ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description (from the WBS)
                if (widget.showGoalDetails)
                const Text('Description',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _kSecondaryText)),
                if (widget.showGoalDetails) const SizedBox(height: 6),
                if (widget.showGoalDetails)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 80),
                  child: VoiceTextField(
                    controller: widget.descController,
                    focusNode: widget.descFocusNode,
                    maxLines: 2,
                    minLines: 1,
                    // Read-only for the same reason as the title: the WBS owns
                    // the goal's wording.
                    readOnly: true,
                    enabled: false,
                    enableVoice: false,
                    enableKazAi: false,
                    enableDocxImport: false,
                    enableTextFormatting: false,
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
                ),
                if (widget.showGoalDetails && widget.showMilestoneMapping)
                  const SizedBox(height: 16),
                // ── Milestones sub-section (mapped from FEP) ──
                if (widget.showGoalDetails && widget.showMilestoneMapping)
                  const Divider(height: 1, color: _kLightGray),
                if (widget.showGoalDetails && widget.showMilestoneMapping)
                  const SizedBox(height: 12),
                if (widget.showMilestoneMapping)
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
                        // No nested scroll (Lusaka 15 item 5): the picker used
                        // to scroll inside the page's scroll ("scroll down and
                        // scroll inside the scroll"). Every milestone is listed
                        // and the page scrolls as one.
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: widget.availableMilestones
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
                                          IgnorePointer(
                                            child: Checkbox(
                                              value: selected,
                                              onChanged: (_) {},
                                              activeColor: _kAccentColor,
                                              visualDensity: VisualDensity.compact,
                                            ),
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
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: _kPrimaryText),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_formatMilestoneDate(milestone.dueDate)}${milestone.discipline.trim().isEmpty ? '' : ' • ${milestone.discipline.trim()}'}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
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
                            ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: widget.onClear,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Text(
                              'Clear ${widget.level1Noun.toLowerCase()}',
                              style: const TextStyle(
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
