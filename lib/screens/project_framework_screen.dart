import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ndu_project/models/design_phase_models.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/widgets/planning_ai_notes_card.dart';
import 'package:ndu_project/wbs/screens/wbs_module_screen.dart';
import 'project_framework_next_screen.dart';
import 'package:ndu_project/screens/ssher_stacked_screen.dart';
import 'package:ndu_project/services/sidebar_navigation_service.dart';
import 'package:ndu_project/utils/phase_transition_helper.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/widgets/proceed_confirmation_gate.dart';
import 'package:ndu_project/widgets/scroll_indicator_overlay.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/field_regenerate_undo_buttons.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

// ─── Design Tokens ───────────────────────────────────────────────────────────
class _Tokens {
 _Tokens._();

 // Surface
 static const surface = Colors.white;
 static const surfaceDim = Color(0xFFD8DADC);
 static const surfaceBright = Color(0xFFFFFFFF);
 static const surfaceContainerLowest = Color(0xFFFFFFFF);
 static const surfaceContainerLow = Color(0xFFF2F4F6);
 static const surfaceContainer = Color(0xFFEBEDEF);
 static const surfaceContainerHigh = Color(0xFFE6E8EA);
 static const surfaceContainerHighest = Color(0xFFE0E2E4);

 // On-Surface
 static const onSurface = Color(0xFF191C1D);
 static const onSurfaceVariant = Color(0xFF40484C);

 // Primary (Yellow)
 static const primary = Color(0xFFFFCC00);
 static const primaryOn = Color(0xFF000000);
 static const primaryContainer = Color(0xFFFFE480);
 static const primaryOnContainer = Color(0xFF1A1400);

 // Outline
 static const outline = Color(0xFF71787D);
 static const outlineVariant = Color(0xFFC0C7CD);

 // Error
 static const error = Color(0xFFBA1A1A);

 // Text
 static const textDark = Color(0xFF191C1D);
 static const textMuted = Color(0xFF40484C);
 static const textLight = Color(0xFF71787D);
}

class ProjectFrameworkScreen extends StatefulWidget {
 const ProjectFrameworkScreen({super.key});

 static void open(BuildContext context) {
 PhaseTransitionHelper.pushPhaseAware(
 context: context,
 builder: (_) => const ProjectFrameworkScreen(),
 destinationCheckpoint: 'project_framework',
 );
 }

 @override
 State<ProjectFrameworkScreen> createState() => _ProjectFrameworkScreenState();
}

class _ProjectFrameworkScreenState extends State<ProjectFrameworkScreen> {
 final ScrollController _mainContentScrollController = ScrollController();
 String? _selectedOverallFramework;
 final List<_Goal> _goals = [_Goal(id: 1, name: 'Goal 1', framework: null)];
 late TextEditingController _projectNameController;
 late TextEditingController _projectObjectiveController;
 late FocusNode _projectNameFocus;
 late FocusNode _projectObjectiveFocus;
 late final OpenAiServiceSecure _openAi;
 bool _isGeneratingObjective = false;
 bool _objectiveGenerationAttempted = false;
  bool _isGeneratingGoals = false;
  bool _goalsGenerationAttempted = false;
  bool _reviewConfirmed = false;
  Timer? _saveDebounce;

  // ── KAZ AI Field History ──
  final Map<String, List<String>> _fieldHistories = {};
  final Map<String, int> _fieldHistoryIndices = {};
  final Map<String, bool> _fieldIsAiGenerated = {};

  bool _isRegeneratingName = false;
  bool _isRegeneratingObjective = false;
  final Set<int> _regeneratingGoalIds = {};

 void _onFieldChanged() {
 _saveDebounce?.cancel();
 _saveDebounce = Timer(const Duration(milliseconds: 300), () {
 if (mounted) _saveData();
 });
 }

  void _pushFieldHistory(String key, String value) {
    final history = _fieldHistories.putIfAbsent(key, () => []);
    final idx = _fieldHistoryIndices[key] ?? -1;
    // Remove any future history beyond current index
    if (idx >= 0 && idx < history.length - 1) {
      history.removeRange(idx + 1, history.length);
    }
    history.add(value);
    _fieldHistoryIndices[key] = history.length - 1;
  }

  bool _canUndoField(String key) => (_fieldHistoryIndices[key] ?? -1) > 0;

  bool _canRedoField(String key) {
    final idx = _fieldHistoryIndices[key] ?? -1;
    final history = _fieldHistories[key] ?? [];
    return idx >= 0 && idx < history.length - 1;
  }

  void _undoField(String key, TextEditingController controller) {
    if (!_canUndoField(key)) return;
    final idx = _fieldHistoryIndices[key]! - 1;
    _fieldHistoryIndices[key] = idx;
    controller.text = _fieldHistories[key]![idx];
    _onFieldChanged();
  }

  void _redoField(String key, TextEditingController controller) {
    if (!_canRedoField(key)) return;
    final idx = _fieldHistoryIndices[key]! + 1;
    _fieldHistoryIndices[key] = idx;
    controller.text = _fieldHistories[key]![idx];
    _onFieldChanged();
  }

  Future<void> _regenerateProjectName() async {
    if (_isRegeneratingName) return;
    setState(() => _isRegeneratingName = true);
    _pushFieldHistory('project_name', _projectNameController.text);
    _fieldIsAiGenerated['project_name'] = true;
    final projectData = ProjectDataHelper.getData(context);
    final contextText =
        ProjectDataHelper.buildProjectObjectiveContext(projectData).trim();
    try {
      final name = await _openAi.generateCompletion(
        'You are a project naming expert. Suggest exactly one concise, professional project name (max 6 words). Return ONLY the name, nothing else.\n\n${contextText.isNotEmpty ? 'Based on this project context, suggest a professional project name: $contextText' : 'Suggest a generic professional project name for a business initiative.'}',
        maxTokens: 30,
        temperature: 0.7,
      );
      if (!mounted) return;
      final cleaned = name.trim();
      if (cleaned.isNotEmpty && cleaned.length < 60) {
        _projectNameController.text = cleaned;
        _onFieldChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Regenerate failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegeneratingName = false);
    }
  }

  Future<void> _regenerateProjectObjective() async {
    if (_isRegeneratingObjective) return;
    setState(() => _isRegeneratingObjective = true);
    _pushFieldHistory('project_objective', _projectObjectiveController.text);
    _fieldIsAiGenerated['project_objective'] = true;
    final projectData = ProjectDataHelper.getData(context);
    final contextText =
        ProjectDataHelper.buildProjectObjectiveContext(projectData).trim();
    try {
      final obj = await _openAi.generateCompletion(
        'You are a project management expert. Write a clear, compelling project objective statement (2-4 sentences). Focus on the purpose, scope, and expected outcomes.\n\n${contextText.isNotEmpty ? 'Based on this context, write a project objective: $contextText' : 'Write a generic project objective statement.'}',
        maxTokens: 150,
        temperature: 0.7,
      );
      if (!mounted) return;
      final cleaned = obj.trim();
      if (cleaned.isNotEmpty) {
        _projectObjectiveController.text = cleaned;
        _onFieldChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Regenerate failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegeneratingObjective = false);
    }
  }

  Future<void> _regenerateGoalDescription(int goalId) async {
    if (_regeneratingGoalIds.contains(goalId)) return;
    final goal = _goals.where((g) => g.id == goalId).firstOrNull;
    if (goal == null) return;

    setState(() => _regeneratingGoalIds.add(goalId));
    _pushFieldHistory('goal_desc_$goalId', goal.controller.text);
    _fieldIsAiGenerated['goal_desc_$goalId'] = true;

    final projectData = ProjectDataHelper.getData(context);
    final objective = projectData.projectObjective.trim();
    final overallFramework = _selectedOverallFramework ?? '';
    final name = goal.nameController.text.trim();
    try {
      final desc = await _openAi.generateCompletion(
        'You are a project planning expert. Write a concise goal description (2-3 sentences) explaining what this project goal entails, its purpose, and expected outcomes.\n\nProject: ${objective.isNotEmpty ? objective : "General"}\nFramework: $overallFramework\nGoal: $name\n\nWrite a description for this project goal.',
        maxTokens: 150,
        temperature: 0.7,
      );
      if (!mounted) return;
      final cleaned = desc.trim();
      if (cleaned.isNotEmpty) {
        goal.controller.text = cleaned;
        _onFieldChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Regenerate failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _regeneratingGoalIds.remove(goalId));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _projectNameController = TextEditingController();
    _projectObjectiveController = RichTextEditingController();
    _projectNameFocus = FocusNode()..addListener(_onFocusChange);
    _projectObjectiveFocus = FocusNode()..addListener(_onFocusChange);
    _openAi = OpenAiServiceSecure();
    ApiKeyManager.initializeApiKey();

 WidgetsBinding.instance.addPostFrameCallback((_) async {
 final projectData = ProjectDataHelper.getData(context);
 _selectedOverallFramework = projectData.overallFramework;

 // Enhanced project name population with fallback hierarchy
 String projectName = projectData.projectName;
 if (projectName.isEmpty) {
 projectName = projectData.solutionTitle;
 }
 if (projectName.isEmpty) {
 projectName = projectData.potentialSolution;
 }
 if (projectName.isEmpty && projectData.potentialSolutions.isNotEmpty) {
 projectName = projectData.potentialSolutions.first.title;
 }
 _projectNameController.text = projectName;
 _projectNameController.addListener(_onFieldChanged);

 _projectObjectiveController.text = projectData.projectObjective.trim();
 _projectObjectiveController.addListener(_onFieldChanged);

 if (projectData.projectGoals.isNotEmpty) {
 _goals.clear();
 for (int i = 0; i < projectData.projectGoals.length; i++) {
 final goal = projectData.projectGoals[i];
 final g = _Goal(
 id: i + 1,
 name: goal.name.isEmpty ? 'Goal ${i + 1}' : goal.name,
 framework: goal.framework,
 description: goal.description,
 );
 _attachGoalListeners(g);
 _goals.add(g);
 _setupGoalNomenclature(g);
 }
 setState(() {});
 } else if (projectData.planningGoals.isNotEmpty &&
 projectData.planningGoals.any((g) => g.title.isNotEmpty)) {
 _goals.clear();
 int idCounter = 1;
 for (final planGoal in projectData.planningGoals) {
 if (planGoal.title.isNotEmpty) {
 final g = _Goal(
 id: idCounter++,
 name: planGoal.title,
 description: planGoal.description.isNotEmpty
 ? planGoal.description
 : null,
 framework: null);
 _attachGoalListeners(g);
 _goals.add(g);
 _setupGoalNomenclature(g);
 }
 }
 if (_goals.isEmpty) {
 final g = _Goal(id: 1, name: 'Goal 1', framework: null);
 _attachGoalListeners(g);
 _goals.add(g);
 _setupGoalNomenclature(g);
 }
 setState(() {});
 }

 // Cleanup: If specific auto-generated text is present in notes, clear it.
 final fwNotes =
 projectData.planningNotes['planning_framework_notes'] ?? '';
 if (fwNotes.startsWith(
 'The Project Management Framework for the Ndu tests project is designed')) {
 ProjectDataHelper.getProvider(context).updateField((d) {
 final newNotes = Map<String, String>.from(d.planningNotes);
 newNotes['planning_framework_notes'] = '';
 return d.copyWith(planningNotes: newNotes);
 });
 }

 await _ensureProjectObjectiveSummary(projectData);
 await _ensureProjectGoalsFromContext(projectData);
 });
 }

 void _onFocusChange() {
 if (!_projectNameFocus.hasFocus && !_projectObjectiveFocus.hasFocus) {
 _saveData();
 }
 }

 void _attachGoalListeners(_Goal goal) {
 goal.nameFocus.addListener(() {
 if (!goal.nameFocus.hasFocus) _saveData();
 });
 goal.descFocus.addListener(() {
 if (!goal.descFocus.hasFocus) _saveData();
 });
 goal.nameController.addListener(_onFieldChanged);
 goal.controller.addListener(_onFieldChanged);
 }

 DesignManagementData? _syncedDesignManagementData(ProjectDataModel data) {
 final mappedMethodology =
 ProjectDataHelper.projectMethodologyFromOverallFramework(
 _selectedOverallFramework,
 );
 if (mappedMethodology == null) return data.designManagementData;
 return (data.designManagementData ?? DesignManagementData()).copyWith(
 methodology: mappedMethodology,
 );
 }

 Future<void> _saveData() async {
 if (!mounted) return;

 final projectGoals = _goals
 .map((g) => ProjectGoal(
 name: g.nameController.text.trim(),
 description: g.controller.text.trim(),
 framework: g.framework,
 ))
 .toList();

 try {
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'project_framework',
 dataUpdater: (data) {
 return data.copyWith(
 projectName: _projectNameController.text.trim(),
 projectObjective: _projectObjectiveController.text.trim(),
 overallFramework: _selectedOverallFramework,
 projectGoals: projectGoals,
 designManagementData: _syncedDesignManagementData(data),
 );
 },
 showSnackbar: false,
 );
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Error saving data: ${e.toString()}'),
 backgroundColor: Colors.red,
 duration: const Duration(seconds: 3),
 ),
 );
 }
 }
 }

 Future<void> _ensureProjectObjectiveSummary(
 ProjectDataModel projectData) async {
 if (_objectiveGenerationAttempted || _isGeneratingObjective) return;

 final existing = projectData.projectObjective.trim();
 final fallbackCandidates = [
 projectData.businessCase.trim(),
 projectData.solutionDescription.trim(),
 projectData.charterAssumptions.trim(),
 ];
 final isFallback = existing.isEmpty ||
 fallbackCandidates.any((v) => v.isNotEmpty && v == existing);

 if (!isFallback) return;

 final objectiveContext =
 ProjectDataHelper.buildProjectObjectiveContext(projectData).trim();
 if (objectiveContext.isEmpty) return;

 _objectiveGenerationAttempted = true;
 setState(() => _isGeneratingObjective = true);

 try {
 final summary = await _openAi.generateProjectObjectiveSummary(
 context: objectiveContext,
 );
 final cleaned = _clampToMaxSentences(summary.trim(), 5);
 if (cleaned.isEmpty || !mounted) return;
 _projectObjectiveController.text = cleaned;
 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'project_framework',
 dataUpdater: (data) => data.copyWith(projectObjective: cleaned),
 showSnackbar: false,
 );
 } catch (e) {
 debugPrint('Error generating project objective summary: $e');
 } finally {
 if (mounted) {
 setState(() => _isGeneratingObjective = false);
 }
 }
 }

 String _clampToMaxSentences(String text, int maxSentences) {
 if (text.isEmpty) return text;
 final sentences = text
 .split(RegExp(r'(?<=[.!?])\s+'))
 .where((s) => s.isNotEmpty)
 .toList();
 if (sentences.length <= maxSentences) return text;
 return sentences.take(maxSentences).join(' ').trim();
 }

 Future<void> _ensureProjectGoalsFromContext(
 ProjectDataModel projectData) async {
 if (_goalsGenerationAttempted || _isGeneratingGoals) return;

 bool isMeaningfulName(String name) {
 final trimmed = name.trim();
 if (trimmed.isEmpty) return false;
 final isDefaultName =
 RegExp(r'^Goal\s+\d+$', caseSensitive: false).hasMatch(trimmed);
 return !isDefaultName;
 }

 final hasMeaningfulGoals = _goals.any((g) {
 final name = g.nameController.text.trim();
 final desc = g.controller.text.trim();
 return isMeaningfulName(name) || desc.isNotEmpty;
 });
 if (hasMeaningfulGoals) return;

 final goalContext =
 ProjectDataHelper.buildProjectObjectiveContext(projectData).trim();
 if (goalContext.isEmpty) return;

 _goalsGenerationAttempted = true;
 setState(() => _isGeneratingGoals = true);

 try {
 final result =
 await _openAi.suggestProjectFrameworkGoals(context: goalContext);
 if (!mounted) return;

 final generatedGoals = result.goals.take(5).toList();
 if (generatedGoals.isEmpty) return;

 setState(() {
 _goals.clear();
 for (int i = 0; i < generatedGoals.length; i++) {
 final g = generatedGoals[i];
 final goal = _Goal(
 id: i + 1,
 name: g.name.isNotEmpty ? g.name : 'Goal ${i + 1}',
 description: g.description,
 framework: (_selectedOverallFramework == 'Waterfall' ||
 _selectedOverallFramework == 'Agile')
 ? _selectedOverallFramework
 : null,
 );
 _attachGoalListeners(goal);
 _goals.add(goal);
 _setupGoalNomenclature(goal);
 }
 if ((_selectedOverallFramework ?? '').isEmpty &&
 result.framework.isNotEmpty) {
 _selectedOverallFramework = result.framework;
 }
 });

 await ProjectDataHelper.updateAndSave(
 context: context,
 checkpoint: 'project_framework',
 dataUpdater: (data) {
 return data.copyWith(
 overallFramework: _selectedOverallFramework,
 projectGoals: _goals
 .map((g) => ProjectGoal(
 name: g.nameController.text.trim(),
 description: g.controller.text.trim(),
 framework: g.framework,
 ))
 .toList(),
 designManagementData: _syncedDesignManagementData(data),
 );
 },
 showSnackbar: false,
 );
 } catch (e) {
 debugPrint('Error generating project goals: $e');
 } finally {
 if (mounted) {
 setState(() => _isGeneratingGoals = false);
 }
 }
 }

 @override
 void dispose() {
 _saveDebounce?.cancel();
 _projectNameController.removeListener(_onFieldChanged);
 _projectObjectiveController.removeListener(_onFieldChanged);
 _mainContentScrollController.dispose();
 _projectNameController.dispose();
 _projectObjectiveController.dispose();
 _projectNameFocus.dispose();
 _projectObjectiveFocus.dispose();
 for (var goal in _goals) {
 goal.nameController.removeListener(_onFieldChanged);
 goal.controller.removeListener(_onFieldChanged);
 goal.dispose();
 }
 super.dispose();
 }

 void _addGoal() {
 if (_goals.length >= 5) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Maximum of 5 goals allowed'),
 backgroundColor: Color(0xFFEF4444),
 ),
 );
 return;
 }
 setState(() {
 final g = _Goal(
 id: _goals.length + 1,
 name: 'Goal ${_goals.length + 1}',
 framework: (_selectedOverallFramework == 'Waterfall' ||
 _selectedOverallFramework == 'Agile')
 ? _selectedOverallFramework
 : null);
 _attachGoalListeners(g);
 _goals.add(g);
 _setupGoalNomenclature(g);
 });
 _saveData();
 }

 void _setupGoalNomenclature(_Goal goal) {
 goal.controller.addListener(() {
 final text = goal.controller.text.trim();
 if (text.isNotEmpty) {
 final words = text.split(RegExp(r'\s+')).take(3);
 final initials = words
 .where((w) => w.isNotEmpty)
 .map((w) => w[0].toUpperCase())
 .join();
 if (initials.isNotEmpty) {
 final newTitle = 'S${goal.id} $initials';
 if (goal.nameController.text != newTitle) {
 goal.nameController.text = newTitle;
 }
 }
 } else {
 final defaultTitle = 'Goal ${goal.id}';
 if (goal.nameController.text != defaultTitle) {
 goal.nameController.text = defaultTitle;
 }
 }
 });
 }

 void _deleteGoal(int goalId) {
 setState(() {
 final goal = _goals.firstWhere((g) => g.id == goalId);
 goal.nameController.removeListener(_onFieldChanged);
 goal.controller.removeListener(_onFieldChanged);
 goal.dispose();
 _goals.removeWhere((g) => g.id == goalId);
 });
 }

 Future<void> _handleNextPressed() async {
 final projectGoals = _goals
 .map((g) => ProjectGoal(
 name: g.nameController.text.trim(),
 description: g.controller.text.trim(),
 framework: g.framework,
 ))
 .toList();

 final missingFields = <String>[];
 if (_selectedOverallFramework == null ||
 _selectedOverallFramework!.isEmpty) {
 missingFields.add('Overall Framework');
 }
 if (projectGoals.isEmpty) {
 missingFields.add('Project Goals');
 }

 if (missingFields.isNotEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 'Continuing with partial project details. Missing: ${missingFields.join(', ')}.',
 ),
 backgroundColor: const Color(0xFFD97706),
 duration: const Duration(seconds: 3),
 ),
 );
 }

 final isBasicPlan =
 ProjectDataHelper.getProvider(context).projectData.isBasicPlanProject;

 final nextItem = SidebarNavigationService.instance
 .getNextAccessibleItem('project_framework', isBasicPlan);

 Widget nextScreen;
 if (nextItem?.checkpoint == 'project_goals_milestones') {
 nextScreen = const ProjectFrameworkNextScreen();
 } else if (nextItem?.checkpoint == 'work_breakdown_structure') {
 nextScreen = const WBSModuleScreen();
 } else if (nextItem?.checkpoint == 'ssher') {
 nextScreen = const SsherStackedScreen();
 } else {
 nextScreen = const WBSModuleScreen();
 }

 if (projectGoals.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Please add at least one Project Goal before proceeding.'),
 backgroundColor: Color(0xFFEF4444),
 duration: Duration(seconds: 3),
 ),
 );
 return;
 }

 await ProjectDataHelper.saveAndNavigate(
 context: context,
 checkpoint: 'project_framework',
 saveInBackground: true,
 nextScreenBuilder: () => nextScreen,
 dataUpdater: (data) {
 return data.copyWith(
 projectName: _projectNameController.text.trim(),
 projectObjective: _projectObjectiveController.text.trim(),
 overallFramework: _selectedOverallFramework,
 projectGoals: projectGoals,
 designManagementData: _syncedDesignManagementData(data),
 );
 },
 );
 }

 // ─── Mobile Layout ─────────────────────────────────────────────────────────
 Widget _buildMobileLayout() {
 return Scaffold(
 backgroundColor: _Tokens.surface,
 drawer: Drawer(
 width: AppBreakpoints.sidebarWidth(context),
 child: SafeArea(
 child: InitiationLikeSidebar(
 activeItemLabel: 'Project Details',
 showHeader: true,
 ),
 ),
 ),
 body: SafeArea(
 bottom: false,
 child: Column(
 children: [
 // ── Sticky TopAppBar ──
 _MobileTopBar(),
 // ── Action Buttons Row ──
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 child: Wrap(
 spacing: 8,
 runSpacing: 6,
 children: [
 ],
 ),
 ),
 // ── Scrollable Content ──
 Expanded(
 child: ScrollIndicatorOverlay(
 controller: _mainContentScrollController,
 child: SingleChildScrollView(
 controller: _mainContentScrollController,
 padding: const EdgeInsets.only(
 left: 16, right: 16, top: 16, bottom: 100),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Page Title
 const Text(
 'Project Details',
 style: TextStyle(
 fontSize: 24,
 fontWeight: FontWeight.w700,
 color: _Tokens.onSurface,
 letterSpacing: -0.3,
 ),
 ),
 const SizedBox(height: 4),
 const Text(
 'Manage your project details, objectives, and overall framework structure.',
 style: TextStyle(
 fontSize: 13,
 color: _Tokens.onSurfaceVariant,
 height: 1.4),
 ),
 const SizedBox(height: 24),

 // ── Notes Section ──
 const PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Project Details',
 noteKey: 'planning_framework_notes',
 checkpoint: 'project_framework',
 description:
 'Capture the framework approach, governance model, and key objectives.',
 ),
 const SizedBox(height: 20),          // ── Project Information ──
          _MobileProjectInfoSection(
            projectNameController: _projectNameController,
            projectObjectiveController:
                _projectObjectiveController,
            projectNameFocus: _projectNameFocus,
            projectObjectiveFocus: _projectObjectiveFocus,
            onBeforeUndo: _saveData,
            isNameAiGenerated: _fieldIsAiGenerated['project_name'] ?? false,
            isObjectiveAiGenerated: _fieldIsAiGenerated['project_objective'] ?? false,
            isRegeneratingName: _isRegeneratingName,
            isRegeneratingObjective: _isRegeneratingObjective,
            canUndoName: _canUndoField('project_name'),
            canRedoName: _canRedoField('project_name'),
            canUndoObjective: _canUndoField('project_objective'),
            canRedoObjective: _canRedoField('project_objective'),
            onRegenerateName: () => _regenerateProjectName(),
            onRegenerateObjective: () => _regenerateProjectObjective(),
            onUndoName: () => _undoField('project_name', _projectNameController),
            onRedoName: () => _redoField('project_name', _projectNameController),
            onUndoObjective: () => _undoField('project_objective', _projectObjectiveController),
            onRedoObjective: () => _redoField('project_objective', _projectObjectiveController),
          ),
          const SizedBox(height: 24),

          // ── Project Framework ──
          _MobileFrameworkSection(
            selectedFramework: _selectedOverallFramework,
            onChanged: (value) {
              setState(() {
                _selectedOverallFramework = value;
                if (value == 'Waterfall' || value == 'Agile') {
                  for (var goal in _goals) {
                    goal.framework = value;
                  }
                }
              });
              _saveData();
            },
          ),
          const SizedBox(height: 24),

          // ── Project Goals ──
          _MobileGoalsSection(
            goals: _goals,
            onAddGoal: _addGoal,
            onDeleteGoal: (goalId) {
              _deleteGoal(goalId);
              _saveData();
            },
            fieldIsAiGenerated: _fieldIsAiGenerated,
            canUndoField: _canUndoField,
            canRedoField: _canRedoField,
            undoField: _undoField,
            redoField: _redoField,
            regenerateGoalDesc: _regenerateGoalDescription,
            regeneratingGoalIds: _regeneratingGoalIds,
          ),
 const SizedBox(height: 16),

 // ── Confirmation ──
 ProceedConfirmationGate(
 value: _reviewConfirmed,
 onChanged: (value) {
 setState(() => _reviewConfirmed = value);
 },
 scrollController: _mainContentScrollController,
 ),
 ],
 ),
 ),
 ),
 ),
 ],
 ),
 ),
 // ── Fixed Bottom Navigation ──
 bottomNavigationBar: _MobileBottomNav(
 backLabel: PlanningPhaseNavigation.backLabel('project_framework'),
 nextLabel: PlanningPhaseNavigation.nextLabel('project_framework'),
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(context, 'project_framework'),
 onNext: () => _handleNextPressed(),
 nextEnabled: _reviewConfirmed,
 ),
 // ── Floating Chat Bubble ──
 floatingActionButton: const KazAiChatBubble(positioned: false),
 floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
 );
 }

 // ─── Desktop / Tablet Layout ───────────────────────────────────────────────
 Widget _buildDesktopLayout() {
 return Scaffold(
 backgroundColor: _Tokens.surface,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Project Details'),
 ),
 Expanded(
 child: Stack(
 children: [
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // ── Desktop Header Bar ──
 PlanningPhaseHeader(
 title: 'Project Details', onExportPdf: _exportPdf),
 Expanded(
 child: ScrollIndicatorOverlay(
 controller: _mainContentScrollController,
 child: SingleChildScrollView(
 controller: _mainContentScrollController,
 padding: const EdgeInsets.symmetric(
 horizontal: 40, vertical: 24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Page Title
 const Text(
 'Project Details',
 style: TextStyle(
 fontSize: 26,
 fontWeight: FontWeight.w700,
 color: _Tokens.onSurface,
 letterSpacing: -0.3,
 ),
 ),
 const SizedBox(height: 4),
 const Text(
 'Manage your project details, objectives, and overall framework structure.',
 style: TextStyle(
 fontSize: 14,
 color: _Tokens.onSurfaceVariant,
 height: 1.4),
 ),
 const SizedBox(height: 28),

 // ── Notes Section ──
 const PlanningAiNotesCard(
 title: 'Notes',
 sectionLabel: 'Project Details',
 noteKey: 'planning_framework_notes',
 checkpoint: 'project_framework',
 description:
 'Capture the framework approach, governance model, and key objectives.',
 ),
 const SizedBox(height: 24),          // ── Project Information ──
          _MobileProjectInfoSection(
            projectNameController:
                _projectNameController,
            projectObjectiveController:
                _projectObjectiveController,
            projectNameFocus: _projectNameFocus,
            projectObjectiveFocus:
                _projectObjectiveFocus,
            onBeforeUndo: _saveData,
            isNameAiGenerated: _fieldIsAiGenerated['project_name'] ?? false,
            isObjectiveAiGenerated: _fieldIsAiGenerated['project_objective'] ?? false,
            isRegeneratingName: _isRegeneratingName,
            isRegeneratingObjective: _isRegeneratingObjective,
            canUndoName: _canUndoField('project_name'),
            canRedoName: _canRedoField('project_name'),
            canUndoObjective: _canUndoField('project_objective'),
            canRedoObjective: _canRedoField('project_objective'),
            onRegenerateName: () => _regenerateProjectName(),
            onRegenerateObjective: () => _regenerateProjectObjective(),
            onUndoName: () => _undoField('project_name', _projectNameController),
            onRedoName: () => _redoField('project_name', _projectNameController),
            onUndoObjective: () => _undoField('project_objective', _projectObjectiveController),
            onRedoObjective: () => _redoField('project_objective', _projectObjectiveController),
          ),
          const SizedBox(height: 28),

          // ── Project Framework ──
          _MobileFrameworkSection(
            selectedFramework:
                _selectedOverallFramework,
            onChanged: (value) {
              setState(() {
                _selectedOverallFramework = value;
                if (value == 'Waterfall' ||
                    value == 'Agile') {
                  for (var goal in _goals) {
                    goal.framework = value;
                  }
                }
              });
              _saveData();
            },
          ),
          const SizedBox(height: 28),

          // ── Project Goals ──
          _MobileGoalsSection(
            goals: _goals,
            onAddGoal: _addGoal,
            onDeleteGoal: (goalId) {
              _deleteGoal(goalId);
              _saveData();
            },
            fieldIsAiGenerated: _fieldIsAiGenerated,
            canUndoField: _canUndoField,
            canRedoField: _canRedoField,
            undoField: _undoField,
            redoField: _redoField,
            regenerateGoalDesc: _regenerateGoalDescription,
            regeneratingGoalIds: _regeneratingGoalIds,
          ),
 const SizedBox(height: 16),

 // ── Confirmation ──
 ProceedConfirmationGate(
 value: _reviewConfirmed,
 onChanged: (value) {
 setState(
 () => _reviewConfirmed = value);
 },
 scrollController:
 _mainContentScrollController,
 ),
 const SizedBox(height: 16),

 // ── Navigation (inline for desktop) ──
 LaunchPhaseNavigation(
 backLabel:
 PlanningPhaseNavigation.backLabel(
 'project_framework'),
 nextLabel:
 PlanningPhaseNavigation.nextLabel(
 'project_framework'),
 onBack: () =>
 PlanningPhaseNavigation.goToPrevious(
 context, 'project_framework'),
 onNext: () => _handleNextPressed(),
 nextEnabled: _reviewConfirmed,
 ),
 const SizedBox(height: 40),
 ],
 ),
 ),
 ),
 ),
 ],
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Project Details',
 ),
 ),
 const KazAiChatBubble(),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 if (AppBreakpoints.isMobile(context)) {
 return _buildMobileLayout();
 }
 return _buildDesktopLayout();
 }

 Future<void> _exportPdf() async {
 final projectData = ProjectDataHelper.getData(context);
 await PdfExportHelper.exportScreenPdf(
 context: context,
 screenTitle: 'Project Framework',
 sections: [
 PdfSection.keyValue('Project Info', [
 {'Project Name': projectData.projectName ?? 'N/A'},
 {'Solution Title': projectData.solutionTitle ?? 'N/A'},
 ]),
 PdfSection.text('Notes', projectData.planningNotes['planning_project_framework_notes'] ?? 'No data recorded.'),
 ],
 );
 }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED DATA MODEL
// ═══════════════════════════════════════════════════════════════════════════════

class _Goal {
 _Goal({
 required this.id,
 String? name,
 this.framework,
 String? description,
 }) : controller = TextEditingController(text: description),
 nameController = TextEditingController(text: name),
 nameFocus = FocusNode(),
 descFocus = FocusNode();

 final int id;
 final TextEditingController nameController;
 final TextEditingController controller;
 final FocusNode nameFocus;
 final FocusNode descFocus;
 String? framework;

 void dispose() {
 nameController.dispose();
 controller.dispose();
 nameFocus.dispose();
 descFocus.dispose();
 }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOBILE TOP BAR
// ═══════════════════════════════════════════════════════════════════════════════

class _MobileTopBar extends StatelessWidget {
 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: const BoxDecoration(
 color: _Tokens.surfaceBright,
 border: Border(
 bottom: BorderSide(color: _Tokens.surfaceContainer, width: 1),
 ),
 boxShadow: [
 BoxShadow(
 color: Color(0x0D000000),
 blurRadius: 6,
 offset: Offset(0, 2),
 ),
 ],
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 // Main header row
 SizedBox(
 height: 56,
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 child: Row(
 children: [
 IconButton(
 onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
 icon: const Icon(Icons.menu, size: 24),
 color: _Tokens.onSurface,
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(
 minWidth: 48, minHeight: 48),
 ),
 const SizedBox(width: 8),
 const Text(
 'NDUPROJECT',
 style: TextStyle(
 fontSize: 17,
 fontWeight: FontWeight.w700,
 letterSpacing: -0.3,
 color: _Tokens.onSurface,
 ),
 ),
 const Spacer(),
 IconButton(
 onPressed: () {},
 icon: const Icon(Icons.notifications_none, size: 22),
 color: _Tokens.onSurfaceVariant,
 padding: EdgeInsets.zero,
 constraints: const BoxConstraints(
 minWidth: 48, minHeight: 48),
 ),
 const SizedBox(width: 4),
 Container(
 width: 32,
 height: 32,
 decoration: const BoxDecoration(
 color: _Tokens.primary,
 shape: BoxShape.circle,
 ),
 alignment: Alignment.center,
 child: const Text(
 'C',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: _Tokens.primaryOn,
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 // Breadcrumb
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 decoration: const BoxDecoration(
 color: _Tokens.surface,
 border: Border(
 bottom:
 BorderSide(color: _Tokens.surfaceContainerLow, width: 1),
 ),
 ),
 child: const Row(
 children: [
 Text(
 'Planning Phase',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: _Tokens.onSurfaceVariant,
 ),
 ),
 SizedBox(width: 4),
 Icon(Icons.chevron_right, size: 14,
 color: _Tokens.outlineVariant),
 SizedBox(width: 4),
 Text(
 'Project Details',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w500,
 color: _Tokens.onSurface,
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

// ═══════════════════════════════════════════════════════════════════════════════
// MOBILE BOTTOM NAVIGATION
// ═══════════════════════════════════════════════════════════════════════════════

class _MobileBottomNav extends StatelessWidget {
 const _MobileBottomNav({
 required this.backLabel,
 required this.nextLabel,
 required this.onBack,
 required this.onNext,
 required this.nextEnabled,
 });

 final String backLabel;
 final String nextLabel;
 final VoidCallback onBack;
 final VoidCallback onNext;
 final bool nextEnabled;

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: const BoxDecoration(
 color: _Tokens.surfaceBright,
 border: Border(
 top: BorderSide(color: _Tokens.surfaceContainer, width: 1),
 ),
 boxShadow: [
 BoxShadow(
 color: Color(0x0D000000),
 blurRadius: 8,
 offset: Offset(0, -3),
 ),
 ],
 ),
 padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
 child: SafeArea(
 top: false,
 child: Row(
 children: [
 // Back button
 Expanded(
 child: OutlinedButton.icon(
 onPressed: onBack,
 icon: const Icon(Icons.arrow_back, size: 18,
 color: _Tokens.onSurface),
 label: const Text(
 'Back',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: _Tokens.onSurface,
 ),
 ),
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: _Tokens.outlineVariant),
 padding: const EdgeInsets.symmetric(vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10)),
 ),
 ),
 ),
 const SizedBox(width: 12),
 // Next button (wider)
 Expanded(
 flex: 2,
 child: ElevatedButton.icon(
 onPressed: nextEnabled
 ? onNext
 : () async {
 final proceed =
 await showProceedWithoutReviewDialog(
 context,
 title:
 'Please confirm you have reviewed and understood this step',
 message:
 'You have not confirmed this page yet. You can continue now and return to update missing information later, or stay and complete it now.',
 );
 if (proceed) onNext();
 },
 icon: const Icon(Icons.arrow_forward, size: 18,
 color: _Tokens.primaryOn),
 label: Text(
 'Next: Work Breakdown Structure',
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: _Tokens.primaryOn,
 ),
 ),
 style: ElevatedButton.styleFrom(
 backgroundColor: _Tokens.primary,
 foregroundColor: _Tokens.primaryOn,
 padding: const EdgeInsets.symmetric(vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10)),
 elevation: 1,
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOBILE PROJECT INFO SECTION
// ═══════════════════════════════════════════════════════════════════════════════

class _MobileProjectInfoSection extends StatelessWidget {
  const _MobileProjectInfoSection({
    required this.projectNameController,
    required this.projectObjectiveController,
    required this.projectNameFocus,
    required this.projectObjectiveFocus,
    required this.onBeforeUndo,
    // KAZ AI callbacks
    this.isNameAiGenerated = false,
    this.isObjectiveAiGenerated = false,
    this.isRegeneratingName = false,
    this.isRegeneratingObjective = false,
    this.canUndoName = false,
    this.canRedoName = false,
    this.canUndoObjective = false,
    this.canRedoObjective = false,
    this.onRegenerateName,
    this.onRegenerateObjective,
    this.onUndoName,
    this.onRedoName,
    this.onUndoObjective,
    this.onRedoObjective,
  });

  final TextEditingController projectNameController;
  final TextEditingController projectObjectiveController;
  final FocusNode projectNameFocus;
  final FocusNode projectObjectiveFocus;
  final VoidCallback onBeforeUndo;
  // KAZ AI fields
  final bool isNameAiGenerated;
  final bool isObjectiveAiGenerated;
  final bool isRegeneratingName;
  final bool isRegeneratingObjective;
  final bool canUndoName;
  final bool canRedoName;
  final bool canUndoObjective;
  final bool canRedoObjective;
  final VoidCallback? onRegenerateName;
  final VoidCallback? onRegenerateObjective;
  final VoidCallback? onUndoName;
  final VoidCallback? onRedoName;
  final VoidCallback? onUndoObjective;
  final VoidCallback? onRedoObjective;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [          // ── Project Name ──
          const Text(
            'Project Name',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _Tokens.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          HoverableFieldControls(
            isAiGenerated: isNameAiGenerated,
            isLoading: isRegeneratingName,
            canUndo: canUndoName,
            canRedo: canRedoName,
            onUndo: () => onUndoName?.call(),
            onRedo: () => onRedoName?.call(),
            onRegenerate: () => onRegenerateName?.call(),
            child: VoiceTextField(
              controller: projectNameController,
              focusNode: projectNameFocus,
              decoration: InputDecoration(
                hintText: 'Enter project name...',
                filled: true,
                fillColor: _Tokens.surfaceBright,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _Tokens.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _Tokens.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: _Tokens.primary, width: 1.5),
                ),
              ),
              style: const TextStyle(fontSize: 14, color: _Tokens.onSurface),
            ),
          ),
 const SizedBox(height: 20),          // ── Project Objective ──
          const Text(
            'Project Objective',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _Tokens.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          HoverableFieldControls(
            isAiGenerated: isObjectiveAiGenerated,
            isLoading: isRegeneratingObjective,
            canUndo: canUndoObjective,
            canRedo: canRedoObjective,
            onUndo: () => onUndoObjective?.call(),
            onRedo: () => onRedoObjective?.call(),
            onRegenerate: () => onRegenerateObjective?.call(),
            child: Container(
              decoration: BoxDecoration(
                color: _Tokens.surfaceBright,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _Tokens.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Formatting toolbar
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: const BoxDecoration(
                      color: _Tokens.surfaceContainerLowest,
                      border: Border(
                        bottom: BorderSide(
                          color: _Tokens.surfaceContainerLow, width: 1),
                      ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Row(
                      children: [
                        _ToolbarIconButton(
                          icon: Icons.format_bold, onTap: () {}),
                        _ToolbarIconButton(
                          icon: Icons.format_italic, onTap: () {}),
                      ],
                    ),
                  ),
                  // Textarea
                  Focus(
                    onFocusChange: (hasFocus) {
                      // Dynamic border color handled by parent Container
                    },
                    child: VoiceTextField(
                      controller: projectObjectiveController,
                      focusNode: projectObjectiveFocus,
                      maxLines: null,
                      minLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            'What is the main objective of this project?',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: _Tokens.onSurface,
                        height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
 ],
 );
 }
}

class _ToolbarIconButton extends StatelessWidget {
 const _ToolbarIconButton({required this.icon, required this.onTap});
 final IconData icon;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 return Material(
 color: Colors.transparent,
 borderRadius: BorderRadius.circular(6),
 child: InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(6),
 child: Padding(
 padding: const EdgeInsets.all(8),
 child: Icon(icon, size: 18, color: _Tokens.onSurfaceVariant),
 ),
 ),
 );
 }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOBILE FRAMEWORK SECTION
// ═══════════════════════════════════════════════════════════════════════════════

class _MobileFrameworkSection extends StatelessWidget {
 const _MobileFrameworkSection({
 required this.selectedFramework,
 required this.onChanged,
 });

 final String? selectedFramework;
 final ValueChanged<String?> onChanged;

 @override
 Widget build(BuildContext context) {
 const options = [
 _FrameworkOption(
 value: 'Waterfall',
 title: 'Waterfall',
 description:
 'A linear project method where work is completed in sequential phases. Most suitable for traditional and physical projects.',
 ),
 _FrameworkOption(
 value: 'Agile',
 title: 'Agile',
 description:
 'A flexible, iterative project method where work is delivered in small increments, allowing continuous feedback, adaptation, and improvement throughout the project. Most suitable for software projects.',
 ),
 _FrameworkOption(
 value: 'Hybrid',
 title: 'Hybrid',
 description:
 'A combination of Waterfall and Agile approaches, using structured planning for some phases and flexible, iterative development for others.',
 ),
 ];

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Project Framework',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: _Tokens.onSurface,
 ),
 ),
 const SizedBox(height: 4),
 const Text(
 'If \'Waterfall\' or \'Agile\' is chosen, all goals will inherit this framework. If \'Hybrid\' is chosen, set a framework for each goal in the WBS.',
 style: TextStyle(
 fontSize: 11, color: _Tokens.onSurfaceVariant, height: 1.4),
 ),
 const SizedBox(height: 12),
 ...options.map((option) => Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: _FrameworkRadioCard(
 title: option.title,
 description: option.description,
 isSelected: selectedFramework == option.value,
 onTap: () => onChanged(option.value),
 ),
 )),
 ],
 );
 }
}

class _FrameworkOption {
 const _FrameworkOption({
 required this.value,
 required this.title,
 required this.description,
 });
 final String value;
 final String title;
 final String description;
}

class _FrameworkRadioCard extends StatelessWidget {
 const _FrameworkRadioCard({
 required this.title,
 required this.description,
 required this.isSelected,
 required this.onTap,
 });

 final String title;
 final String description;
 final bool isSelected;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 final borderColor =
 isSelected ? _Tokens.primary : _Tokens.outlineVariant;
 return Material(
 color: _Tokens.surfaceBright,
 borderRadius: BorderRadius.circular(10),
 child: InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(10),
 child: Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(10),
 border: Border.all(
 color: borderColor,
 width: isSelected ? 1.5 : 1,
 ),
 boxShadow: isSelected
 ? [
 BoxShadow(
 color: _Tokens.primary.withValues(alpha: 0.08),
 blurRadius: 8,
 offset: const Offset(0, 2),
 ),
 ]
 : [
 const BoxShadow(
 color: Color(0x05000000),
 blurRadius: 4,
 offset: Offset(0, 1),
 ),
 ],
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: const TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: _Tokens.onSurface,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 description,
 style: const TextStyle(
 fontSize: 11.5,
 height: 1.35,
 color: _Tokens.onSurfaceVariant,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 // Radio dot
 Container(
 width: 20,
 height: 20,
 margin: const EdgeInsets.only(top: 2),
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: isSelected
 ? _Tokens.primary
 : _Tokens.surfaceBright,
 border: Border.all(
 color: isSelected
 ? _Tokens.primary
 : _Tokens.outlineVariant,
 width: isSelected ? 6 : 1.5,
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

// ═══════════════════════════════════════════════════════════════════════════════
// MOBILE GOALS SECTION
// ═══════════════════════════════════════════════════════════════════════════════

class _MobileGoalsSection extends StatelessWidget {
  const _MobileGoalsSection({
    required this.goals,
    required this.onAddGoal,
    required this.onDeleteGoal,
    // KAZ AI callback map
    required this.fieldIsAiGenerated,
    required this.canUndoField,
    required this.canRedoField,
    required this.undoField,
    required this.redoField,
    required this.regenerateGoalDesc,
    required this.regeneratingGoalIds,
  });

  final List<_Goal> goals;
  final VoidCallback onAddGoal;
  final void Function(int goalId) onDeleteGoal;
  // KAZ AI helpers
  final Map<String, bool> fieldIsAiGenerated;
  final bool Function(String key) canUndoField;
  final bool Function(String key) canRedoField;
  final void Function(String key, TextEditingController) undoField;
  final void Function(String key, TextEditingController) redoField;
  final Future<void> Function(int goalId) regenerateGoalDesc;
  final Set<int> regeneratingGoalIds;

 @override
 Widget build(BuildContext context) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Header row
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text(
 'Project Goals',
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: _Tokens.onSurface,
 ),
 ),
 SizedBox(height: 2),
 Text(
 'Indicate upto 5 key high-level outcomes for this project',
 style: TextStyle(
 fontSize: 11,
 color: _Tokens.onSurfaceVariant,
 height: 1.3),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Material(
 color: _Tokens.primary.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(8),
 child: InkWell(
 onTap: onAddGoal,
 borderRadius: BorderRadius.circular(8),
 child: Container(
 padding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 child: const Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.add, size: 16,
 color: _Tokens.primaryOnContainer),
 SizedBox(width: 4),
 Text(
 'Add Goal',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: _Tokens.primaryOnContainer,
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),

 // Goal cards
 ...goals.asMap().entries.map((entry) {
 final index = entry.key;
 final goal = entry.value;
 return Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child:          _MobileGoalCard(
            index: index,
            goal: goal,
            onDelete: () => onDeleteGoal(goal.id),
            isDescriptionAiGenerated: fieldIsAiGenerated['goal_desc_${goal.id}'] ?? false,
            isRegeneratingDesc: regeneratingGoalIds.contains(goal.id),
            canUndoDesc: canUndoField('goal_desc_${goal.id}'),
            canRedoDesc: canRedoField('goal_desc_${goal.id}'),
            onRegenerateDesc: () => regenerateGoalDesc(goal.id),
            onUndoDesc: () => undoField('goal_desc_${goal.id}', goal.controller),
            onRedoDesc: () => redoField('goal_desc_${goal.id}', goal.controller),
          ),
 );
 }),
 ],
 );
 }
}

class _MobileGoalCard extends StatelessWidget {
  const _MobileGoalCard({
    required this.index,
    required this.goal,
    required this.onDelete,
    // KAZ AI callbacks
    this.isDescriptionAiGenerated = false,
    this.isRegeneratingDesc = false,
    this.canUndoDesc = false,
    this.canRedoDesc = false,
    this.onRegenerateDesc,
    this.onUndoDesc,
    this.onRedoDesc,
  });

  final int index;
  final _Goal goal;
  final VoidCallback onDelete;
  // KAZ AI fields
  final bool isDescriptionAiGenerated;
  final bool isRegeneratingDesc;
  final bool canUndoDesc;
  final bool canRedoDesc;
  final VoidCallback? onRegenerateDesc;
  final VoidCallback? onUndoDesc;
  final VoidCallback? onRedoDesc;

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: _Tokens.surfaceBright,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: _Tokens.surfaceContainer),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Goal header row
 Row(
 children: [
 // Numbered circle
 Container(
 width: 24,
 height: 24,
 decoration: BoxDecoration(
 color: _Tokens.surfaceContainerHigh,
 shape: BoxShape.circle,
 ),
 alignment: Alignment.center,
 child: Text(
 '${index + 1}',
 style: const TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: _Tokens.onSurfaceVariant,
 ),
 ),
 ),
 const SizedBox(width: 8),
 // Goal name as dropdown-style
 Expanded(
 child: Text(
 goal.nameController.text.isEmpty
 ? 'Goal ${index + 1}'
 : goal.nameController.text,
 style: const TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: _Tokens.onSurface,
 ),
 ),
 ),
 // Delete button
 IconButton(
 onPressed: onDelete,
 icon: const Icon(Icons.delete_outline, size: 20),
 color: _Tokens.error,
 padding: EdgeInsets.zero,
 constraints:
 const BoxConstraints(minWidth: 36, minHeight: 36),
 tooltip: 'Delete Goal',
 ),
 ],
 ),
 const SizedBox(height: 8),          // Description textarea
          HoverableFieldControls(
            isAiGenerated: isDescriptionAiGenerated,
            isLoading: isRegeneratingDesc,
            canUndo: canUndoDesc,
            canRedo: canRedoDesc,
            onUndo: () => onUndoDesc?.call(),
            onRedo: () => onRedoDesc?.call(),
            onRegenerate: () => onRegenerateDesc?.call(),
            child: VoiceTextField(
              controller: goal.controller,
              focusNode: goal.descFocus,
              maxLines: null,
              minLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter goal description...',
                filled: true,
                fillColor: _Tokens.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _Tokens.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _Tokens.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: _Tokens.primary, width: 1.5),
                ),
              ),
              style: const TextStyle(fontSize: 13, color: _Tokens.onSurface, height: 1.4),
            ),
          ),
 ],
 ),
 );
 }
}
