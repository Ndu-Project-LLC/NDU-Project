import 'package:flutter/material.dart';

import 'package:ndu_project/screens/detailed_design_screen.dart';
import 'package:ndu_project/screens/scope_tracking_implementation_screen.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/epic_feature_service.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/utils/form_validation_engine.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/agile_iteration_table_widget.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';
import 'package:ndu_project/widgets/page_regenerate_all_button.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/execution_phase_ai_seed.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/widgets/milestone_picker_dialog.dart';
class AgileDevelopmentIterationsScreen extends StatefulWidget {
 const AgileDevelopmentIterationsScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(
 builder: (_) => const AgileDevelopmentIterationsScreen()),
 );
 }

 @override
 State<AgileDevelopmentIterationsScreen> createState() =>
 _AgileDevelopmentIterationsScreenState();
}

class _AgileDevelopmentIterationsScreenState
 extends State<AgileDevelopmentIterationsScreen> {
  final Set<String> _selectedFilters = {'All'};
  List<AgileTask> _tasks = [];
  List<Epic> _epics = [];
  Map<String, List<Feature>> _featuresByEpic = {};
  List<String> _availableRoles = [];
  bool _isLoading = false;
  bool _isRegeneratingAll = false;
  bool _autoGenerationTriggered = false;
  bool _isAutoGenerating = false;

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
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _loadTasks();
 _loadAvailableRoles();
 });
 }

  Future<void> _loadTasks() async {
    final projectId = _projectId;
    if (projectId == null) return;

    setState(() => _isLoading = true);
    try {
      final tasks =
          await ExecutionPhaseService.loadAgileTasks(projectId: projectId);
      // Also load epics and features for grouping
      final epics = await EpicFeatureService.loadEpics(projectId);
      final featuresByEpic = <String, List<Feature>>{};
      for (final epic in epics) {
        featuresByEpic[epic.id] =
            await EpicFeatureService.loadFeatures(projectId, epic.id);
      }
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _epics = epics;
          _featuresByEpic = featuresByEpic;
          _isLoading = false;
        });
      }
      await _autoGenerateIfNeeded();
    } catch (e) {
      debugPrint('Error loading agile tasks: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

 Future<void> _loadAvailableRoles() async {
 final projectId = _projectId;
 if (projectId == null) return;

 try {
 final staffRows =
 await ExecutionPhaseService.loadStaffingRows(projectId: projectId);
 if (mounted) {
 setState(() {
 _availableRoles = staffRows
 .map((row) => row.role)
 .where((role) => role.isNotEmpty)
 .toSet()
 .toList();
 });
 }
 await _autoGenerateIfNeeded();
 } catch (e) {
 debugPrint('Error loading staff roles: $e');
 }
 }

 Future<void> _autoGenerateIfNeeded() async {
 if (!mounted || _autoGenerationTriggered || _isAutoGenerating) return;
 if (_tasks.isNotEmpty) return;
 if (_projectId == null) return;

 _autoGenerationTriggered = true;
 _isAutoGenerating = true;
 try {
 final generated = await ExecutionPhaseAiSeed.generateEntries(
 context: context,
 section: 'Agile Development Iterations',
 sections: const {
 'agileTasks': 'Agile user stories and tasks for execution',
 },
 itemsPerSection: 4,
 );
 final entries = generated['agileTasks'] ?? const [];
 if (entries.isEmpty) return;

 final roleFallback =
 _availableRoles.isNotEmpty ? _availableRoles.first : '';
 final newTasks = entries
 .map(
 (entry) => AgileTask(
 userStory: entry.title,
 assignedRole: roleFallback,
 storyPoints: 3,
 priority: 'Medium',
 status: 'To-Do',
 taskDescription: entry.details,
 acceptanceCriteria: entry.details.isNotEmpty
 ? '. ${entry.details}'
 : '',
 ),
 )
 .toList();

 if (!mounted) return;
 setState(() => _tasks = newTasks);
 final projectId = _projectId;
 if (projectId != null) {
 await ExecutionPhaseService.saveAgileTasks(
 projectId: projectId,
 tasks: newTasks,
 );
 }
 } catch (e) {
 debugPrint('Error auto-generating agile tasks: $e');
 } finally {
 _isAutoGenerating = false;
 }
 }

 @override
 Widget build(BuildContext context) {
 final bool isMobile = AppBreakpoints.isMobile(context);
 final double horizontalPadding = isMobile ? 18 : 32;

 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 DraggableSidebar(
 openWidth: AppBreakpoints.sidebarWidth(context),
 child: const InitiationLikeSidebar(
 activeItemLabel: 'Agile Development Iterations'),
 ),
 Expanded(
 child: Stack(
 children: [
 SingleChildScrollView(
 padding: EdgeInsets.symmetric(
 horizontal: horizontalPadding, vertical: 28),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (_isLoading)
 const LinearProgressIndicator(minHeight: 2),
 if (_isLoading) const SizedBox(height: 16),
 PlanningPhaseHeader(
 title: 'Agile Development Iterations',
showNavigationButtons: false, onExportPdf: _exportPdf),
 const SizedBox(height: 16),
 _buildPageHeader(context),
 const SizedBox(height: 20),
 _buildFilterChips(context),
 const SizedBox(height: 24),
 _buildIterationTable(),
 const SizedBox(height: 24),
 _buildFooterNavigation(context),
 const SizedBox(height: 48),
 ],
 ),
 ),
 MobileSidebarHamburger(
 sidebar: const InitiationLikeSidebar(
 activeItemLabel: 'Agile Development Iterations',
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

 Widget _buildPageHeader(BuildContext context) {
 final isMobile = AppBreakpoints.isMobile(context);
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: const Color(0xFFFFC812),
 borderRadius: BorderRadius.circular(4),
 ),
 child: const Text(
 'AGILE DELIVERY',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: Colors.black,
 letterSpacing: 0.5,
 ),
 ),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Agile Development Iterations',
 style: Theme.of(context).textTheme.headlineLarge?.copyWith(
 fontSize: 26,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 6),
 const Text(
 'Manage sprint cycles, track velocity, and synchronize development tasks with design components.',
 style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
 ),
 ],
 ),
 ),
 if (!isMobile) _buildHeaderActions(),
 ],
 ),
 if (isMobile) ...[
 const SizedBox(height: 12),
 _buildHeaderActions(),
 ],
 ],
 );
 }

 Widget _buildHeaderActions() {
 return Wrap(
 spacing: 10,
 runSpacing: 10,
 children: [
 Tooltip(
 message: 'Regenerate all task descriptions',
 child: PageRegenerateAllButton(
 isLoading: _isRegeneratingAll,
 onRegenerateAll: _regenerateAllTaskDescriptions,
 ),
 ),
 OutlinedButton.icon(
 onPressed: () => _showAddTaskDialog(context),
 icon: const Icon(Icons.add, size: 18, color: Color(0xFF64748B)),
 label: const Text('Add Task',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF64748B))),
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 ),
 OutlinedButton.icon(
 onPressed: () {},
 icon: const Icon(Icons.description_outlined,
 size: 18, color: Color(0xFF64748B)),
 label: const Text('Export',
 style: TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF64748B))),
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 shape:
 RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 ),
 ],
 );
 }

 Future<void> _regenerateAllTaskDescriptions() async {
 if (_isRegeneratingAll || _tasks.isEmpty) return;
 final projectId = _projectId;
 final provider = ProjectDataInherited.maybeOf(context);
 if (projectId == null || provider == null) return;

 final confirmed = await showRegenerateAllConfirmation(context);
 if (!confirmed) return;

 setState(() => _isRegeneratingAll = true);
 try {
 final designComponents = await ExecutionPhaseService.loadDesignComponents(
 projectId: projectId,
 );
 final componentNames =
 designComponents.map((c) => c.componentName).toList();
 final contextText = ProjectDataHelper.buildExecutivePlanContext(
 provider.projectData,
 sectionLabel: 'Agile Development Iterations',
 );
 final ai = OpenAiServiceSecure();
 final updated = <AgileTask>[];
 for (final task in _tasks) {
 try {
 final breakdown = await ai.breakDownUserStory(
 context: contextText,
 userStory: task.userStory,
 designComponents: componentNames,
 );
 updated.add(task.copyWith(taskDescription: breakdown));
 } catch (e) {
 updated.add(task);
 }
 }
 if (!mounted) return;
 setState(() => _tasks = updated);
 await ExecutionPhaseService.saveAgileTasks(
 projectId: projectId,
 tasks: updated,
 );
 } finally {
 if (mounted) setState(() => _isRegeneratingAll = false);
 }
 }

 Widget _buildFilterChips(BuildContext context) {
 final List<String> filters = [
 'All',
 'To-Do',
 'In-Progress',
 'Testing',
 'Done'
 ];

 return Wrap(
 spacing: 10,
 runSpacing: 10,
 children: filters.map((label) {
 final isSelected = _selectedFilters.contains(label);
 return GestureDetector(
 onTap: () => setState(() {
 _selectedFilters.clear();
 _selectedFilters.add(label);
 }),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 decoration: BoxDecoration(
 color: isSelected ? const Color(0xFF1F2937) : Colors.white,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE5E7EB)),
 ),
 child: Text(
 label,
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: isSelected ? Colors.white : const Color(0xFF374151),
 ),
 ),
 ),
 );
 }).toList(),
 );
 }

 Widget _buildStatsRow(bool isNarrow) {
 // Calculate metrics from tasks
 final totalTasks = _tasks.length;
 final completedTasks = _tasks.where((t) => t.status == 'Done').length;
 final iterationProgress =
 totalTasks > 0 ? ((completedTasks / totalTasks) * 100).round() : 0;
 final sprintVelocity =
 _tasks.fold<int>(0, (sum, task) => sum + task.storyPoints);
 final activeBlockers = _tasks
 .where((t) => t.status == 'To-Do' && t.priority == 'Critical')
 .length;

 final stats = [
 _StatCardData('Iteration Progress', '$iterationProgress%',
 '$completedTasks/$totalTasks tasks', const Color(0xFF0EA5E9)),
 _StatCardData('Sprint Velocity', '$sprintVelocity', 'Total story points',
 const Color(0xFF6366F1)),
 _StatCardData('Active Blockers', '$activeBlockers',
 'Critical tasks pending', const Color(0xFFEF4444)),
 ];

 if (isNarrow) {
 return Wrap(
 spacing: 12,
 runSpacing: 12,
 children: stats.map((stat) => _buildStatCard(stat)).toList(),
 );
 }

 return Row(
 children: stats
 .map((stat) => Expanded(
 child: Padding(
 padding: const EdgeInsets.only(right: 12),
 child: _buildStatCard(stat),
 ),
 ))
 .toList(),
 );
 }

 Widget _buildStatCard(_StatCardData data) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 data.label,
 style: const TextStyle(
 fontSize: 12,
 color: Color(0xFF64748B),
 fontWeight: FontWeight.w600),
 ),
 const SizedBox(height: 8),
 Text(
 data.value,
 style: TextStyle(
 fontSize: 24, fontWeight: FontWeight.w700, color: data.color),
 ),
 const SizedBox(height: 4),
 Text(
 data.subtitle,
 style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
 ),
 ],
 ),
 );
 }

  String _epicTitleForTask(AgileTask task) {
    final epic = _epics.where((e) => e.id == task.epicId);
    return epic.isNotEmpty ? epic.first.title : 'Unassigned';
  }

  String _featureTitleForTask(AgileTask task) {
    if (task.featureId.isEmpty) return 'General';
    for (final features in _featuresByEpic.values) {
      final f = features.where((fe) => fe.id == task.featureId);
      if (f.isNotEmpty) return f.first.title;
    }
    return 'General';
  }

  Widget _buildIterationTable() {
    final filteredTasks = _selectedFilters.contains('All')
        ? _tasks
        : _tasks.where((t) => _selectedFilters.contains(t.status)).toList();

    // Group tasks by Epic → Feature
    final Map<String, Map<String, List<AgileTask>>> grouped = {};
    for (final task in filteredTasks) {
      final epicTitle = _epicTitleForTask(task);
      final featureTitle = _featureTitleForTask(task);
      grouped.putIfAbsent(epicTitle, () => {});
      grouped[epicTitle]!.putIfAbsent(featureTitle, () => []);
      grouped[epicTitle]![featureTitle]!.add(task);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Agile Iteration Table',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track user stories, assign roles, and manage sprint velocity.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          if (grouped.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No tasks match the current filter.',
                    style: TextStyle(color: Color(0xFF6B7280))),
              ),
            )
          else
            ...grouped.entries.map((epicEntry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.speed, size: 16,
                              color: const Color(0xFF7C3AED)),
                          const SizedBox(width: 8),
                          Text(
                            epicEntry.key,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${epicEntry.value.values.fold<int>(0, (sum, tasks) => sum + tasks.fold<int>(0, (s, t) => s + t.storyPoints))} pts',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...epicEntry.value.entries.map((featureEntry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 12, bottom: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.flag, size: 14,
                                      color: const Color(0xFFF59E0B)),
                                  const SizedBox(width: 6),
                                  Text(
                                    featureEntry.key,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${featureEntry.value.length} stories',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AgileIterationTableWidget(
                              tasks: featureEntry.value,
                              availableRoles: _availableRoles,
                              onUpdated: (task) {
                                setState(() {
                                  final index = _tasks.indexWhere(
                                      (t) => t.id == task.id);
                                  if (index != -1) {
                                    _tasks[index] = task;
                                  } else {
                                    _tasks.add(task);
                                  }
                                });
                              },
                              onDeleted: (task) {
                                setState(() {
                                  _tasks.removeWhere(
                                      (t) => t.id == task.id);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

 void _showAddTaskDialog(BuildContext context) {
 final userStoryController = TextEditingController();
 final taskDescriptionController = RichTextEditingController();
 final acceptanceCriteriaController = RichAutoBulletTextController();
 final iterationNotesController = RichTextEditingController();
 final userStoryFieldKey = GlobalKey();
 final assignedRoleFieldKey = GlobalKey();
  String selectedRole = '';
  int selectedStoryPoints = 1;
  String selectedPriority = 'Medium';
  String selectedStatus = 'To-Do';
   String selectedEpicId = _epics.isNotEmpty ? _epics.first.id : '';
   String selectedFeatureId = '';
   List<String> selectedMilestoneIds = [];
   Map<String, String> validationErrors = const {};

 OutlineInputBorder fieldBorder(bool hasError) {
 return OutlineInputBorder(
 borderRadius: BorderRadius.circular(8),
 borderSide: BorderSide(
 color: hasError ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
 ),
 );
 }

 showDialog(
 context: context,
 builder: (dialogContext) => StatefulBuilder(
 builder: (dialogContext, setDialogState) {
 return AlertDialog(
 title: const Text('Add New Task'),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 VoiceTextField(
 key: userStoryFieldKey,
 controller: userStoryController,
 onChanged: (_) {
 if (!validationErrors.containsKey('user_story')) return;
 setDialogState(() {
 validationErrors =
 Map<String, String>.from(validationErrors)
 ..remove('user_story');
 });
 },
 decoration: InputDecoration(
 labelText: 'User Story/Task *',
 errorText: validationErrors['user_story'],
 border:
 fieldBorder(validationErrors['user_story'] != null),
 enabledBorder:
 fieldBorder(validationErrors['user_story'] != null),
 focusedBorder:
 fieldBorder(validationErrors['user_story'] != null),
 errorBorder: fieldBorder(true),
 focusedErrorBorder: fieldBorder(true),
 ),
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 key: assignedRoleFieldKey,
 value: _availableRoles.isEmpty
 ? null
 : (_availableRoles.contains(selectedRole)
 ? selectedRole
 : null),
 decoration: InputDecoration(
 labelText: 'Assigned Role *',
 errorText: validationErrors['assigned_role'],
 border: fieldBorder(
 validationErrors['assigned_role'] != null),
 enabledBorder: fieldBorder(
 validationErrors['assigned_role'] != null),
 focusedBorder: fieldBorder(
 validationErrors['assigned_role'] != null),
 errorBorder: fieldBorder(true),
 focusedErrorBorder: fieldBorder(true),
 ),
 items: _availableRoles.map((role) {
 return DropdownMenuItem<String>(
 value: role, child: Text(role));
 }).toList(),
 onChanged: (value) {
 setDialogState(() {
 selectedRole = value ?? '';
 if (selectedRole.isNotEmpty) {
 validationErrors =
 Map<String, String>.from(validationErrors)
 ..remove('assigned_role');
 }
 });
 },
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<int>(
 value: selectedStoryPoints,
 decoration:
 const InputDecoration(labelText: 'Story Points *'),
 items: const [1, 2, 3, 5, 8].map((points) {
 return DropdownMenuItem<int>(
 value: points, child: Text('$points'));
 }).toList(),
 onChanged: (value) => selectedStoryPoints = value ?? 1,
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: selectedPriority,
 decoration: const InputDecoration(labelText: 'Priority *'),
 items: const ['Critical', 'High', 'Medium', 'Low'].map((p) {
 return DropdownMenuItem<String>(value: p, child: Text(p));
 }).toList(),
 onChanged: (value) => selectedPriority = value ?? 'Medium',
 ),
 const SizedBox(height: 12),
 DropdownButtonFormField<String>(
 value: selectedStatus,
 decoration: const InputDecoration(labelText: 'Status *'),
 items: const ['To-Do', 'In-Progress', 'Testing', 'Done']
 .map((s) {
 return DropdownMenuItem<String>(value: s, child: Text(s));
 }).toList(),
  onChanged: (value) => selectedStatus = value ?? 'To-Do',
            ),
            const SizedBox(height: 12),
            if (_epics.isNotEmpty)
              DropdownButtonFormField<String>(
                value: selectedEpicId,
                decoration: const InputDecoration(
                    labelText: 'Epic *'),
                items: _epics.map((e) => DropdownMenuItem<String>(
                      value: e.id,
                      child: Text(e.title.isNotEmpty
                          ? e.title
                          : 'Unnamed Epic'),
                    )).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedEpicId = value ?? '';
                    selectedFeatureId =
                        ''; // reset feature when epic changes
                  });
                },
              ),
            if (selectedEpicId.isNotEmpty &&
                (_featuresByEpic[selectedEpicId]?.isNotEmpty == true))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DropdownButtonFormField<String>(
                  value: selectedFeatureId.isNotEmpty
                      ? selectedFeatureId
                      : null,
                  decoration: const InputDecoration(
                      labelText: 'Feature'),
                  items: _featuresByEpic[selectedEpicId]!
                      .map((f) => DropdownMenuItem<String>(
                            value: f.id,
                            child: Text(f.title.isNotEmpty
                                ? f.title
                                : 'Unnamed Feature'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedFeatureId = value ?? '';
                    });
                  },
                ),
              ),
            const SizedBox(height: 12),
            VoiceTextField(
              controller: taskDescriptionController,
 decoration:
 const InputDecoration(labelText: 'Task Description'),
 maxLines: 3,
 ),
 const SizedBox(height: 12),
  const SizedBox(height: 6),
  VoiceTextField(
  controller: iterationNotesController,
  decoration: const InputDecoration(
  labelText: 'Iteration Notes (manual input only)'),
  maxLines: 2,
  ),
  const SizedBox(height: 12),
  _MilestoneLinkButton(
    milestoneIds: selectedMilestoneIds,
    onPick: () async {
      final data = await _loadMilestonesForPicker();
      if (data == null) return;
      final picked = await showDialog<List<String>>(
        context: dialogContext,
        builder: (ctx) => MilestonePickerDialog(
          title: 'Link Milestones',
          allMilestones: data,
          selectedIds: selectedMilestoneIds,
        ),
      );
      if (picked != null) {
        setDialogState(() => selectedMilestoneIds = picked);
      }
    },
  ),
  ],
  ),
  ),
  actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogContext),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: () async {
 final validation = FormValidationEngine.validateForm([
 ValidationFieldRule(
 id: 'user_story',
 label: 'User Story/Task',
 section: 'Task Details',
 type: ValidationFieldType.text,
 value: userStoryController.text,
 fieldKey: userStoryFieldKey,
 ),
 ValidationFieldRule(
 id: 'assigned_role',
 label: 'Assigned Role',
 section: 'Task Details',
 type: ValidationFieldType.dropdown,
 value: selectedRole,
 fieldKey: assignedRoleFieldKey,
 ),
 ]);

 if (!validation.isValid) {
 setDialogState(() {
 validationErrors = validation.errorByFieldId;
 });
 FormValidationEngine.showValidationSnackBar(
 this.context,
 validation,
 intro:
 'Please complete the required task fields before adding this task.',
 backgroundColor: const Color(0xFFF59E0B),
 );
 return;
 }

   final newTask = AgileTask(
     userStory: userStoryController.text,
     assignedRole: selectedRole,
     storyPoints: selectedStoryPoints,
     priority: selectedPriority,
     status: selectedStatus,
     taskDescription: taskDescriptionController.text,
     acceptanceCriteria: acceptanceCriteriaController.text,
     iterationNotes: iterationNotesController.text,
     epicId: selectedEpicId,
     featureId: selectedFeatureId,
     milestoneIds: selectedMilestoneIds,
   );

 setState(() {
 _tasks.add(newTask);
 });

 final projectId = _projectId;
 if (projectId != null) {
 try {
 await ExecutionPhaseService.saveAgileTasks(
 projectId: projectId,
 tasks: _tasks,
 );
 } catch (e) {
 debugPrint('Error saving task: $e');
 }
 }

 if (dialogContext.mounted) {
 Navigator.pop(dialogContext);
 }
 },
 child: const Text('Add'),
 ),
 ],
 );
 },
 ),
 );
 }

 Widget _buildFooterNavigation(BuildContext context) {
 return LaunchPhaseNavigation(
 backLabel: 'Back: Detailed Design',
 nextLabel: 'Next: Scope Tracking Implementation',
 onBack: () => DetailedDesignScreen.open(context),
 onNext: () => ScopeTrackingImplementationScreen.open(context),
 );
 }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Agile Development Iterations',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
          {'Solution Title': projectData.solutionTitle ?? 'N/A'},
        ]),
        PdfSection.text('Notes', projectData.planningNotes['planning_agile_development_iterations_notes'] ?? 'No data recorded.'),
      ],
    );
  }

  Future<List<Milestone>?> _loadMilestonesForPicker() async {
    try {
      final data = ProjectDataHelper.getData(context, listen: false);
      final milestones = data.keyMilestones
          .where((m) => m.name.trim().isNotEmpty)
          .toList();
      if (milestones.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No milestones available. Add them in Front End Planning > Milestone.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return null;
      }
      return milestones;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load milestones: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }
}

class _StatCardData {
  const _StatCardData(this.label, this.value, this.subtitle, this.color);

  final String label;
  final String value;
  final String subtitle;
  final Color color;
}

class _MilestoneLinkButton extends StatelessWidget {
  final List<String> milestoneIds;
  final VoidCallback onPick;

  const _MilestoneLinkButton({
    required this.milestoneIds,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          children: [
            const Icon(Icons.flag_outlined,
                size: 16, color: Color(0xFFFFC107)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                milestoneIds.isEmpty
                    ? 'Tap to link FEP milestones...'
                    : '${milestoneIds.length} milestone${milestoneIds.length == 1 ? '' : 's'} linked',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: milestoneIds.isEmpty
                      ? const Color(0xFF64748B)
                      : const Color(0xFF1E293B),
                ),
              ),
            ),
            const Icon(Icons.edit_outlined,
                size: 14, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}
