import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ndu_project/models/acceptance_criteria.dart';
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
import 'package:ndu_project/utils/agile_backlog_order.dart';
import 'package:ndu_project/utils/agile_backlog_table.dart';
import 'package:ndu_project/utils/agile_story_linkage.dart';
import 'package:ndu_project/utils/agile_story_template.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/agile_backlog_table_view.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

import 'package:ndu_project/widgets/delete_success_snackbar.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';
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

  /// The User Story Template config, so a story added here starts with the
  /// default template's acceptance criteria instead of a blank field.
  AcceptanceCriteriaConfig _acConfig = AcceptanceCriteriaConfig();
  bool _isLoading = true;
  bool _isSaving = false;
  Timer? _saveDebounce;
  final TextEditingController _searchController = SpellCheckTextEditingController();
  String _searchQuery = '';
  String? _selectedEpicId;

  /// The table is the default view: the review found the card-only backlog
  /// "not very efficient" for seeing what a story is and which feature and
  /// epic it came from. Cards stay for editing.
  bool _tableView = true;

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
      final acConfig = await AgileWireframeService.loadAcceptanceCriteria(pid);
      if (!mounted) return;
      setState(() {
        _epics = epics;
        _featuresByEpic = featuresByEpic;
        _stories = tasks
          ..sort((a, b) => a.backlogOrder.compareTo(b.backlogOrder));
        _sprints = sprints;
        _releases = releases;
        _acConfig = acConfig;
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

  Feature? _featureFor(String featureId) {
    for (final features in _featuresByEpic.values) {
      for (final feature in features) {
        if (feature.id == featureId) return feature;
      }
    }
    return null;
  }

  String _epicTitleFor(String epicId) {
    for (final epic in _epics) {
      if (epic.id == epicId) return epic.title;
    }
    return '';
  }

  /// This feature's stories in priority order, narrowed by the search box.
  ///
  /// The search reaches the feature and epic titles too — the review asked to
  /// "search for epic, feature, story" — so typing an epic name surfaces its
  /// stories instead of nothing.
  List<AgileTask> _storiesForFeature(String featureId) {
    final stories = AgileBacklogOrdering.forFeature(_stories, featureId);
    final query = _searchQuery.trim();
    if (query.isEmpty) return stories;
    final feature = _featureFor(featureId);
    final epicTitle = feature == null ? '' : _epicTitleFor(feature.epicId);
    return [
      for (final story in stories)
        if (AgileBacklogOrdering.matches(
          story,
          query: query,
          featureTitle: feature?.title ?? '',
          epicTitle: epicTitle,
        ))
          story,
    ];
  }

  /// Reorder within a feature's story list. The drop is stored as the story's
  /// backlog position, so priority survives a reload instead of living in the
  /// widget.
  void _reorderStories(Feature feature, int oldIndex, int newIndex) {
    final reordered = AgileBacklogOrdering.moveWithinFeature(
      stories: _stories,
      featureId: feature.id,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    setState(() {
      _stories
        ..clear()
        ..addAll(reordered);
    });
    _scheduleSave();
  }

  Future<void> _persistStories() async {
    final pid = _projectId;
    if (pid == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ExecutionPhaseService.saveAgileTasks(
          projectId: pid, tasks: _stories);
      if (mounted) {
        // Report the breakdown gap on save: a story under no feature never
        // rolls up to an epic, and the review asked to be able to see that.
        final unlinked = AgileStoryLinkage.countUnlinked(
          _stories,
          featuresByEpic: _featuresByEpic,
        );
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(unlinked == 0
                ? 'Backlog stories saved'
                : 'Backlog stories saved · $unlinked still have no feature'),
            duration: const Duration(seconds: 2),
          ),
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
    // Every story is born under a feature: the linkage rule owns both ids and
    // the backlog position. The User Story Template then seeds its acceptance
    // criteria from whichever template is marked default.
    final story = AgileStoryTemplate.newStoryFor(
      feature: feature,
      existing: _stories,
      config: _acConfig,
    );
    setState(() => _stories.add(story));
    _scheduleSave();
  }

  /// Feature id → "Epic · Feature", for the per-story feature picker.
  Map<String, String> get _featureOptions => AgileStoryLinkage.optionLabels(
        epics: _epics,
        featuresByEpic: _featuresByEpic,
      );

  /// Re-parent a story onto a feature. The feature's epic comes with it.
  void _linkStoryToFeature(AgileTask story, String featureId) {
    final feature = AgileStoryLinkage.allFeatures(
      epics: _epics,
      featuresByEpic: _featuresByEpic,
    ).where((f) => f.id == featureId).firstOrNull;
    if (feature == null) return;
    final linked = AgileStoryLinkage.link(story, feature);
    setState(() => _updateStory(linked));
    _scheduleSave();
  }

  void _deleteStory(AgileTask story) {
    setState(() => _stories.removeWhere((s) => s.id == story.id));
    _scheduleSave();
      showDeleteSuccessSnackBar(context, itemLabel: 'Agile Task');
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
                        const Text(
                          'Break features into backlog stories, size them, set sprint/release targets, and prepare the same AgileTask items that execution Kanban and schedule import will use.',
                          style: TextStyle(fontSize: 15, color: _kMuted),
                        ),
                        const SizedBox(height: 20),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          _buildSummaryBar(),
                          const SizedBox(height: 16),
                          _buildViewToggle(),
                          const SizedBox(height: 12),
                          VoiceTextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search stories, features, epics...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                          const SizedBox(height: 16),
                          if (_tableView)
                            _buildBacklogTableView()
                          else ...[
                            _buildEpicTabs(),
                            const SizedBox(height: 16),
                            if (_visibleFeatures.isEmpty)
                              _buildEmptyState(
                                  'No features found for this epic. Define features first in Epics & Features.')
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _visibleFeatures.length,
                                itemBuilder: (context, i) =>
                                    _buildFeatureSection(_visibleFeatures[i]),
                              ),
                          ],
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
                  const MobileSidebarHamburger(
                    sidebar: InitiationLikeSidebar(
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

  /// Table (default) or the editable card view.
  Widget _buildViewToggle() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Backlog view:',
            style: TextStyle(fontSize: 13, color: _kMuted)),
        ChoiceChip(
          key: const ValueKey('backlog-view-table'),
          label: const Text('Table'),
          avatar: const Icon(Icons.table_rows_outlined, size: 16),
          selected: _tableView,
          onSelected: (_) => setState(() => _tableView = true),
          selectedColor: _kAccent.withValues(alpha: 0.12),
        ),
        ChoiceChip(
          key: const ValueKey('backlog-view-cards'),
          label: const Text('Cards'),
          avatar: const Icon(Icons.view_agenda_outlined, size: 16),
          selected: !_tableView,
          onSelected: (_) => setState(() => _tableView = false),
          selectedColor: _kAccent.withValues(alpha: 0.12),
        ),
      ],
    );
  }

  /// The whole backlog in one table: every story with the feature and epic it
  /// descends from, plus an explicit group for stories no feature claims.
  Widget _buildBacklogTableView() {
    if (_epics.isEmpty) {
      return _buildEmptyState(
          'No epics found. Define epics before breaking work into stories.');
    }

    return AgileBacklogTableView(
      rows: AgileBacklogTable.build(
        epics: _epics,
        featuresByEpic: _featuresByEpic,
        stories: _stories,
        query: _searchQuery,
      ),
      featuresWithoutStories: _searchQuery.trim().isEmpty
          ? AgileBacklogTable.featuresWithoutStories(
              epics: _epics,
              featuresByEpic: _featuresByEpic,
              stories: _stories,
            ).length
          : 0,
      sprintLabel: _sprintLabel,
      releaseLabel: _releaseLabel,
      emptyMessage: _searchQuery.trim().isNotEmpty
          ? 'No stories match your search.'
          : 'No stories in the backlog yet. Switch to Cards to add a story to a feature.',
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
          selectedColor: _kAccent.withValues(alpha: 0.12),
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
            else if (_searchQuery.trim().isNotEmpty)
              // Dropping into a filtered list would renumber against the wrong
              // neighbours, so dragging waits until the search is cleared.
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Clear the search to drag these stories into priority order.',
                    style: TextStyle(fontSize: 12, color: _kMuted),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: stories.length,
                    itemBuilder: (context, i) =>
                        _buildStoryCard(stories[i], feature),
                  ),
                ],
              )
            else
              // Drag to prioritise: the whole point of the backlog, per the
              // review ("drag them up and down to prioritize them").
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: stories.length,
                onReorder: (oldIndex, newIndex) =>
                    _reorderStories(feature, oldIndex, newIndex),
                itemBuilder: (context, i) => KeyedSubtree(
                  key: ValueKey('story-${stories[i].id}'),
                  child: _buildStoryCard(
                    stories[i],
                    feature,
                    dragHandle: ReorderableDragStartListener(
                      index: i,
                      child: const Tooltip(
                        message: 'Drag to prioritize',
                        child: Icon(Icons.drag_indicator,
                            size: 18, color: _kMuted),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCard(AgileTask story, Feature feature,
      {Widget? dragHandle}) {
    final titleCtrl = SpellCheckTextEditingController(text: story.userStory);
    final descCtrl = SpellCheckTextEditingController(text: story.taskDescription);
    final acCtrl = SpellCheckTextEditingController(text: story.acceptanceCriteria);
    final depCtrl =
        SpellCheckTextEditingController(text: story.dependencyTaskIds.join(', '));

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
                    color: const Color(0xFFFFC812).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('WBS linked',
                      style: TextStyle(fontSize: 11, color: Color(0xFFB8860B))),
                ),
              if (dragHandle != null) dragHandle,
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
              _featurePicker(story),
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
                  controller: SpellCheckTextEditingController(
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

  /// The feature this story belongs to. Required: a story that is under no
  /// feature cannot roll up to an epic, which is the gap the review found, so
  /// an unlinked story says so and offers the list to fix it.
  Widget _featurePicker(AgileTask story) {
    final options = _featureOptions;
    final linked = options.containsKey(story.featureId);
    return SizedBox(
      width: 320,
      child: DropdownButtonFormField<String>(
        key: ValueKey('story-feature-${story.id}'),
        initialValue: linked ? story.featureId : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Feature',
          border: const OutlineInputBorder(),
          errorText: linked ? null : 'Not under any feature',
          helperText: linked
              ? 'Every story sits under a feature so it can roll up to an epic.'
              : 'Pick the feature this story belongs to.',
        ),
        hint: const Text('Select a feature'),
        items: [
          for (final entry in options.entries)
            DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (featureId) {
          if (featureId == null) return;
          _linkStoryToFeature(story, featureId);
        },
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
        initialValue: items.contains(value) ? value : null,
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
