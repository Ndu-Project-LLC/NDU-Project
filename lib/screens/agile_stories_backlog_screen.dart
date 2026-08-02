import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ndu_project/models/agile_release_plan.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/models/roadmap_sprint.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';
import 'package:ndu_project/services/epic_feature_service.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/roadmap_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

const Color _kBackground = Colors.white;
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);
const Color _kAccent = Color(0xFFD97706);

class AgileStoriesBacklogScreen extends StatefulWidget {
  const AgileStoriesBacklogScreen({super.key});

  @override
  State<AgileStoriesBacklogScreen> createState() =>
      _AgileStoriesBacklogScreenState();
}

class _AgileStoriesBacklogScreenState extends State<AgileStoriesBacklogScreen> {
  List<Epic> _epics = [];
  Map<String, List<Feature>> _featuresByEpic = {};
  List<AgileTask> _stories = [];
  List<RoadmapSprint> _sprints = [];
  List<AgileReleasePlan> _releases = [];
  bool _isLoading = true;
  bool _isSaving = false;
  Timer? _saveDebounce;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedEpicId;

  String? get _projectId {
    try {
      return ProjectDataInherited.maybeOf(context)?.projectData.projectId;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isLoading = true);
    try {
      final epics = await EpicFeatureService.loadEpics(pid);
      final featuresByEpic = <String, List<Feature>>{};
      for (final epic in epics) {
        featuresByEpic[epic.id] =
            await EpicFeatureService.loadFeatures(pid, epic.id);
      }
      final tasks = await ExecutionPhaseService.loadAgileTasks(projectId: pid);
      final sprints = await RoadmapService.loadSprints(projectId: pid);
      final releases = await AgileWireframeService.loadReleasePlans(pid);
      if (!mounted) return;
      setState(() {
        _epics = epics;
        _featuresByEpic = featuresByEpic;
        _stories = tasks
          ..sort((a, b) => a.backlogOrder.compareTo(b.backlogOrder));
        _sprints = sprints;
        _releases = releases;
        _selectedEpicId =
            _selectedEpicId ?? (epics.isNotEmpty ? epics.first.id : null);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Feature> get _visibleFeatures {
    if (_selectedEpicId == null) return [];
    return _featuresByEpic[_selectedEpicId] ?? [];
  }

  List<AgileTask> _storiesForFeature(String featureId) {
    final filtered = _stories.where((story) => story.featureId == featureId);
    if (_searchQuery.trim().isEmpty) {
      return filtered.toList()
        ..sort((a, b) => a.backlogOrder.compareTo(b.backlogOrder));
    }
    final q = _searchQuery.toLowerCase();
    return filtered.where((story) {
      return story.userStory.toLowerCase().contains(q) ||
          story.taskDescription.toLowerCase().contains(q) ||
          story.acceptanceCriteria.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.backlogOrder.compareTo(b.backlogOrder));
  }

  Future<void> _persistStories() async {
    final pid = _projectId;
    if (pid == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ExecutionPhaseService.saveAgileTasks(
          projectId: pid, tasks: _stories);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Backlog stories saved'),
              duration: Duration(seconds: 1)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _persistStories);
  }

  void _addStory(Feature feature) {
    final nextOrder =
        _stories.where((s) => s.featureId == feature.id).length + 1;
    final story = AgileTask(
      epicId: feature.epicId,
      featureId: feature.id,
      userStory: 'New story ${nextOrder}',
      storyPoints: 3,
      priority: 'Medium',
      status: 'To-Do',
      readinessStatus: 'Draft',
      backlogOrder: nextOrder,
    );
    setState(() => _stories.add(story));
    _scheduleSave();
  }

  void _deleteStory(AgileTask story) {
    setState(() => _stories.removeWhere((s) => s.id == story.id));
    _scheduleSave();
  }

  void _updateStory(AgileTask story) {
    final index = _stories.indexWhere((s) => s.id == story.id);
    if (index == -1) return;
    _stories[index] = story;
    _scheduleSave();
  }

  String _releaseLabel(String id) {
    if (id.isEmpty) return 'Unassigned';
    final match = _releases.where((r) => r.id == id);
    if (match.isEmpty) return 'Unknown release';
    return match.first.releaseLabel.isNotEmpty
        ? match.first.releaseLabel
        : 'Unnamed release';
  }

  String _sprintLabel(String id) {
    if (id.isEmpty) return 'Unassigned';
    final match = _sprints.where((s) => s.id == id);
    if (match.isEmpty) return 'Unknown sprint';
    return match.first.name.isNotEmpty ? match.first.name : 'Unnamed sprint';
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double hp = isMobile ? 20 : 40;

    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                activeItemLabel:
                    'Agile Delivery Model - Stories & Backlog Breakdown',
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: hp, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlanningPhaseHeader(
                          title: 'Stories & Backlog Breakdown',
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                              context, 'agile_stories_backlog'),
                          onForward: () => PlanningPhaseNavigation.goToNext(
                              context, 'agile_stories_backlog'),
                          onExportPdf: _exportPdf,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Break features into backlog stories, size them, set sprint/release targets, and prepare the same AgileTask items that execution Kanban and schedule import will use.',
                          style: TextStyle(fontSize: 15, color: _kMuted),
                        ),
                        const SizedBox(height: 20),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          _buildSummaryBar(),
                          const SizedBox(height: 16),
                          VoiceTextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search stories...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                          const SizedBox(height: 16),
                          _buildEpicTabs(),
                          const SizedBox(height: 16),
                          if (_visibleFeatures.isEmpty)
                            _buildEmptyState(
                                'No features found for this epic. Define features first in Epics & Features.')
                          else
                            ..._visibleFeatures.map(_buildFeatureSection),
                          const SizedBox(height: 24),
                          LaunchPhaseNavigation(
                            backLabel: PlanningPhaseNavigation.backLabel(
                                'agile_stories_backlog'),
                            nextLabel: PlanningPhaseNavigation.nextLabel(
                                'agile_stories_backlog'),
                            onBack: () => PlanningPhaseNavigation.goToPrevious(
                                context, 'agile_stories_backlog'),
                            onNext: () => PlanningPhaseNavigation.goToNext(
                                context, 'agile_stories_backlog'),
                          ),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel:
                          'Agile Delivery Model - Stories & Backlog Breakdown',
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

  Widget _buildSummaryBar() {
    final totalStories = _stories.length;
    final totalPoints = _stories.fold<int>(0, (sum, s) => sum + s.storyPoints);
    final readyStories =
        _stories.where((s) => s.readinessStatus == 'Ready for Sprint').length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _summaryChip(Icons.list_alt_outlined, 'Stories', '$totalStories'),
        _summaryChip(Icons.auto_graph_outlined, 'Story Points', '$totalPoints'),
        _summaryChip(
            Icons.check_circle_outline, 'Sprint Ready', '$readyStories'),
        _summaryChip(Icons.calendar_today_outlined, 'Configured Sprints',
            '${_sprints.length}'),
        _summaryChip(Icons.rocket_launch_outlined, 'Configured Releases',
            '${_releases.length}'),
      ],
    );
  }

  Widget _summaryChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _kAccent),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(color: _kMuted)),
        ],
      ),
    );
  }

  Widget _buildEpicTabs() {
    if (_epics.isEmpty) {
      return _buildEmptyState(
          'No epics found. Define epics before breaking work into stories.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _epics.map((epic) {
        final selected = epic.id == _selectedEpicId;
        return ChoiceChip(
          label: Text(epic.title.isNotEmpty ? epic.title : 'Untitled Epic'),
          selected: selected,
          onSelected: (_) => setState(() => _selectedEpicId = epic.id),
          selectedColor: _kAccent.withOpacity(0.12),
          labelStyle: TextStyle(
            color: selected ? _kAccent : _kHeadline,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureSection(Feature feature) {
    final stories = _storiesForFeature(feature.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.title.isNotEmpty
                            ? feature.title
                            : 'Untitled Feature',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _kHeadline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feature.description.isNotEmpty
                            ? feature.description
                            : 'No feature description yet.',
                        style: const TextStyle(color: _kMuted),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addStory(feature),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Story'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kAccent,
                    side: const BorderSide(color: _kAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (stories.isEmpty)
              Text(
                _searchQuery.isNotEmpty
                    ? 'No stories for this feature match your search.'
                    : 'No stories planned for this feature yet.',
                style: const TextStyle(color: _kMuted),
              )
            else
              ...stories.map((story) => _buildStoryCard(story, feature)),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCard(AgileTask story, Feature feature) {
    final titleCtrl = TextEditingController(text: story.userStory);
    final descCtrl = TextEditingController(text: story.taskDescription);
    final acCtrl = TextEditingController(text: story.acceptanceCriteria);
    final depCtrl =
        TextEditingController(text: story.dependencyTaskIds.join(', '));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Story ${story.backlogOrder == 0 ? '-' : story.backlogOrder}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (story.wbsId.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('WBS linked',
                      style: TextStyle(fontSize: 11, color: Colors.blue[700])),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 18),
                onPressed: () => _deleteStory(story),
              ),
            ],
          ),
          const SizedBox(height: 8),
          VoiceTextField(
            controller: titleCtrl,
            decoration:
                const InputDecoration(labelText: 'User story / backlog item'),
            onChanged: (v) {
              story.userStory = v;
              _updateStory(story);
            },
          ),
          const SizedBox(height: 10),
          VoiceTextField(
            controller: descCtrl,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 3,
            onChanged: (v) {
              story.taskDescription = v;
              _updateStory(story);
            },
          ),
          const SizedBox(height: 10),
          VoiceTextField(
            controller: acCtrl,
            decoration: const InputDecoration(labelText: 'Acceptance criteria'),
            maxLines: 3,
            onChanged: (v) {
              story.acceptanceCriteria = v;
              _updateStory(story);
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _dropdownField<int>(
                label: 'Story points',
                value: story.storyPoints,
                items: const [1, 2, 3, 5, 8, 13],
                itemLabel: (v) => '$v',
                onChanged: (v) {
                  if (v == null) return;
                  story.storyPoints = v;
                  _updateStory(story);
                },
              ),
              _dropdownField<String>(
                label: 'Priority',
                value: story.priority,
                items: const ['Critical', 'High', 'Medium', 'Low'],
                itemLabel: (v) => v,
                onChanged: (v) {
                  if (v == null) return;
                  story.priority = v;
                  _updateStory(story);
                },
              ),
              _dropdownField<String>(
                label: 'Readiness',
                value: story.readinessStatus,
                items: const [
                  'Draft',
                  'Ready for Refinement',
                  'Ready for Sprint'
                ],
                itemLabel: (v) => v,
                onChanged: (v) {
                  if (v == null) return;
                  story.readinessStatus = v;
                  _updateStory(story);
                },
              ),
              _dropdownField<String>(
                label: 'Target sprint',
                value: story.plannedSprintId.isEmpty
                    ? null
                    : story.plannedSprintId,
                items: _sprints.map((s) => s.id).toList(),
                itemLabel: _sprintLabel,
                onChanged: (v) {
                  story.plannedSprintId = v ?? '';
                  _updateStory(story);
                },
              ),
              _dropdownField<String>(
                label: 'Target release',
                value: story.plannedReleaseId.isEmpty
                    ? null
                    : story.plannedReleaseId,
                items: _releases.map((r) => r.id).toList(),
                itemLabel: _releaseLabel,
                onChanged: (v) {
                  story.plannedReleaseId = v ?? '';
                  _updateStory(story);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: VoiceTextField(
                  controller: depCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dependencies (comma-separated story IDs)',
                  ),
                  onChanged: (v) {
                    story.dependencyTaskIds = v
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();
                    _updateStory(story);
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: VoiceTextField(
                  controller: TextEditingController(
                      text: story.backlogOrder.toString()),
                  decoration: const InputDecoration(labelText: 'Backlog order'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    story.backlogOrder = int.tryParse(v) ?? story.backlogOrder;
                    _updateStory(story);
                  },
                ),
              ),
            ],
          ),
          if (feature.weight > 0 || feature.percentComplete > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Feature roll-up context · Weight ${feature.weight.toStringAsFixed(2)} · % complete ${(feature.percentComplete * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, color: _kMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: _kMuted)),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Stories & Backlog Breakdown',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName},
          {'Solution Title': projectData.solutionTitle},
        ]),
        PdfSection.keyValue('Backlog Summary', [
          {'Stories': _stories.length.toString()},
          {
            'Story Points': _stories
                .fold<int>(0, (sum, s) => sum + s.storyPoints)
                .toString()
          },
          {
            'Sprint Ready': _stories
                .where((s) => s.readinessStatus == 'Ready for Sprint')
                .length
                .toString()
          },
        ]),
      ],
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T item) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<T>(
        value: items.contains(value) ? value : null,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        items: items
            .map((item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
