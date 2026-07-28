import 'package:flutter/material.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';
import 'package:ndu_project/services/epic_feature_service.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';

class AgileKanbanBoardScreen extends StatefulWidget {
  const AgileKanbanBoardScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgileKanbanBoardScreen()),
    );
  }

  @override
  State<AgileKanbanBoardScreen> createState() => _AgileKanbanBoardScreenState();
}

class _AgileKanbanBoardScreenState extends State<AgileKanbanBoardScreen> {
  static const Color _kAccent = Color(0xFFF59E0B);
  static const Color _kAccentLight = Color(0xFFFFC812);
  static const Color _kAccentBg = Color(0xFFFEF3C7);
  static const Color _kBackground = Color(0xFFF8FAFC);
  static const Color _kSurface = Colors.white;
  static const Color _kBorder = Color(0xFFE5E7EB);
  static const Color _kHeadline = Color(0xFF111827);
  static const Color _kMuted = Color(0xFF6B7280);

  bool _isLoading = true;
  bool _isSaving = false;
  List<_KanbanColumn> _columns = const [];
  Map<String, Feature> _featureById = {};
  Map<String, String> _epicTitleById = {};
  List<AgileTask> _stories = [];
  Map<String, List<AgileTask>> _storiesByColumn = {};

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    if (pid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final kanbanConfig = await AgileWireframeService.loadKanbanConfig(pid);
      final epics = await EpicFeatureService.loadEpics(pid);
      final featureById = <String, Feature>{};
      final epicTitleById = <String, String>{};
      for (final epic in epics) {
        epicTitleById[epic.id] = epic.title;
        final features = await EpicFeatureService.loadFeatures(pid, epic.id);
        for (final feature in features) {
          featureById[feature.id] = feature;
        }
      }
      final stories =
          await ExecutionPhaseService.loadAgileTasks(projectId: pid);
      final columns = _buildColumnsFromConfig(kanbanConfig);
      final grouped = {for (final c in columns) c.id: <AgileTask>[]};
      for (final story in stories) {
        final state = grouped.containsKey(story.workflowState)
            ? story.workflowState
            : columns.first.id;
        grouped[state]!.add(story);
      }
      if (!mounted) return;
      setState(() {
        _columns = columns;
        _featureById = featureById;
        _epicTitleById = epicTitleById;
        _stories = stories;
        _storiesByColumn = grouped;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Kanban load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_KanbanColumn> _buildColumnsFromConfig(Map<String, dynamic> data) {
    final rawCols = data['columns'] as List?;
    if (rawCols == null || rawCols.isEmpty) {
      return const [
        _KanbanColumn(
            id: 'backlog',
            title: 'Backlog',
            accent: Color(0xFF6B7280),
            wipLimit: 999),
        _KanbanColumn(
            id: 'ready',
            title: 'Ready',
            accent: Color(0xFFFBBF24),
            wipLimit: 8),
        _KanbanColumn(
            id: 'in_progress',
            title: 'In Progress',
            accent: _kAccent,
            wipLimit: 5),
        _KanbanColumn(
            id: 'in_review',
            title: 'In Review',
            accent: Color(0xFF8B5CF6),
            wipLimit: 3),
        _KanbanColumn(
            id: 'done',
            title: 'Done',
            accent: Color(0xFF10B981),
            wipLimit: 999),
      ];
    }
    return rawCols.asMap().entries.map((entry) {
      final item = Map<String, dynamic>.from(entry.value as Map);
      final name = item['name']?.toString() ?? 'Column';
      final id = _normalizeColumnId(name, fallback: 'column_${entry.key + 1}');
      return _KanbanColumn(
        id: id,
        title: name,
        accent: _accentForIndex(entry.key),
        wipLimit: (item['wipLimit'] as num?)?.toInt() ?? 999,
      );
    }).toList();
  }

  String _normalizeColumnId(String value, {required String fallback}) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? fallback : normalized;
  }

  Color _accentForIndex(int index) {
    const accents = [
      Color(0xFF6B7280),
      Color(0xFFFBBF24),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
      Color(0xFF10B981),
      Color(0xFF0EA5E9),
    ];
    return accents[index % accents.length];
  }

  Future<void> _saveData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isSaving = true);
    try {
      await ExecutionPhaseService.saveAgileTasks(
          projectId: pid, tasks: _stories);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kanban workflow saved'),
            duration: Duration(seconds: 2),
            backgroundColor: _kAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _moveStory(AgileTask story, String toColumn) {
    if (story.workflowState == toColumn) return;
    setState(() {
      _storiesByColumn[story.workflowState]
          ?.removeWhere((s) => s.id == story.id);
      final updated = story.copyWith(workflowState: toColumn);
      final index = _stories.indexWhere((s) => s.id == story.id);
      if (index != -1) _stories[index] = updated;
      _storiesByColumn.putIfAbsent(toColumn, () => []).add(updated);
    });
  }

  void _showMoveSheet(AgileTask story) {
    final currentCol = _columns.firstWhere(
      (c) => c.id == story.workflowState,
      orElse: () => _columns.first,
    );
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Move story',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const SizedBox(height: 4),
              Text(story.userStory,
                  style: const TextStyle(fontSize: 13, color: _kMuted)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _columns
                    .map((c) => ChoiceChip(
                          label: Text(c.title),
                          selected: c.id == currentCol.id,
                          selectedColor: c.accent.withOpacity(0.2),
                          onSelected: (_) {
                            Navigator.pop(ctx);
                            _moveStory(story, c.id);
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStoryDetail(AgileTask story) {
    final feature = _featureById[story.featureId];
    final epicTitle = _epicTitleById[story.epicId] ?? 'Unknown Epic';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            _priorityDot(story.priority),
            const SizedBox(width: 8),
            Text(story.id,
                style: const TextStyle(
                    fontSize: 14, color: _kMuted, fontWeight: FontWeight.w600)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(story.userStory,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const SizedBox(height: 12),
              Text(
                story.taskDescription.isNotEmpty
                    ? story.taskDescription
                    : 'No description provided.',
                style:
                    const TextStyle(fontSize: 13, color: _kMuted, height: 1.5),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metaChip(Icons.bolt, '${story.storyPoints} pts', _kAccent),
                  _metaChip(
                      Icons.person_outline,
                      story.assignedRole.isNotEmpty
                          ? story.assignedRole
                          : 'Unassigned',
                      const Color(0xFFD97706)),
                  _metaChip(
                      Icons.account_tree_outlined,
                      feature?.title.isNotEmpty == true
                          ? feature!.title
                          : 'Feature unlinked',
                      Colors.purple),
                  _metaChip(
                      Icons.layers_outlined,
                      epicTitle.isNotEmpty ? epicTitle : 'Epic unlinked',
                      Colors.teal),
                  _metaChip(
                      Icons.flag_outlined, story.readinessStatus, Colors.green),
                ],
              ),
              if (story.acceptanceCriteria.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Acceptance Criteria',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: _kHeadline)),
                const SizedBox(height: 6),
                Text(story.acceptanceCriteria,
                    style: const TextStyle(
                        fontSize: 13, color: _kMuted, height: 1.5)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: _kMuted))),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showMoveSheet(story);
            },
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: const Text('Move'),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFF59E0B);
      case 'medium':
        return const Color(0xFFFBBF24);
      case 'low':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _priorityDot(String p) {
    final c = _priorityColor(p);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: c.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 1)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double hp = isMobile ? 16 : 32;

    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DraggableSidebar(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: const InitiationLikeSidebar(
                  activeItemLabel: 'Agile Kanban Board'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel: 'Agile Kanban Board',
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: hp, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 20),
                        PlanningPhaseHeader(
                          title: 'Kanban Board',
                          showNavigationButtons: false,
                          breadcrumbPhase: 'Execution',
                          breadcrumbTitle: 'Agile Hub › Kanban Board',
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const _LoadingStrip()
                        else ...[
                          _buildSummaryBar(),
                          const SizedBox(height: 20),
                          _buildBoard(isMobile),
                          const SizedBox(height: 24),
                          _buildActionBar(),
                          const SizedBox(height: 64),
                        ],
                      ],
                    ),
                  ),
                  const Positioned(
                    right: 24,
                    bottom: 24,
                    child: KazAiChatBubble(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Image.asset('assets/images/Logo.png', height: 36),
        const SizedBox(width: 12),
        const Text('Ndu Project',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: _kHeadline)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccentBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kAccent.withOpacity(0.3)),
          ),
          child: const Text('KANBAN FLOW',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kAccent,
                  letterSpacing: 1.1)),
        ),
      ],
    );
  }

  Widget _buildSummaryBar() {
    final total = _stories.length;
    final inProgress = _storiesByColumn['in_progress']?.length ?? 0;
    final done = _storiesByColumn['done']?.length ?? 0;
    final pointsDone = (_storiesByColumn['done'] ?? [])
        .fold<int>(0, (a, c) => a + c.storyPoints);
    final pointsTotal = _stories.fold<int>(0, (a, c) => a + c.storyPoints);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kAccent, _kAccentLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
              child: _summaryCell('Total Stories', '$total', Icons.layers)),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
              child:
                  _summaryCell('In Progress', '$inProgress', Icons.flash_on)),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
              child: _summaryCell(
                  'Points Done', '$pointsDone / $pointsTotal', Icons.stars)),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
          Expanded(
              child: _summaryCell('Done', '$done', Icons.check_circle_outline)),
        ],
      ),
    );
  }

  Widget _summaryCell(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBoard(bool isMobile) {
    if (isMobile) {
      return Column(
        children: _columns
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildColumn(c),
                ))
            .toList(),
      );
    }
    return Container(
      height: 640,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: _columns
            .map((c) => Expanded(child: _buildColumn(c, inner: true)))
            .toList(),
      ),
    );
  }

  Widget _buildColumn(_KanbanColumn col, {bool inner = false}) {
    final stories = _storiesByColumn[col.id] ?? [];
    final wipExceeded = stories.length > col.wipLimit && col.wipLimit < 999;
    return Container(
      decoration: inner
          ? BoxDecoration(
              border: Border(
                  right: col.id != _columns.last.id
                      ? const BorderSide(color: _kBorder, width: 1)
                      : BorderSide.none),
            )
          : BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              color: col.accent.withOpacity(0.08),
              borderRadius: inner
                  ? null
                  : const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: col.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(col.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kHeadline)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: col.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${stories.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: col.accent)),
                ),
                const Spacer(),
                if (col.wipLimit < 999)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          wipExceeded
                              ? Icons.warning_amber_rounded
                              : Icons.check,
                          size: 12,
                          color: wipExceeded ? Colors.red : Colors.green),
                      const SizedBox(width: 2),
                      Text(
                        'WIP ${col.wipLimit}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: wipExceeded ? Colors.red : _kMuted),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (wipExceeded)
            Container(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('WIP limit exceeded — pull blocked',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.w600)),
            ),
          Expanded(
            child: DragTarget<AgileTask>(
              onAcceptWithDetails: (details) =>
                  _moveStory(details.data, col.id),
              builder: (ctx, candidate, rejected) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  child: ListView(
                    children: [
                      if (candidate.isNotEmpty)
                        Container(
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                              color: col.accent,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ...stories.map((story) => Draggable<AgileTask>(
                            data: story,
                            feedback: SizedBox(
                              width: 220,
                              child: Material(
                                elevation: 8,
                                borderRadius: BorderRadius.circular(10),
                                child: _buildCard(story, col),
                              ),
                            ),
                            childWhenDragging: Opacity(
                                opacity: 0.4, child: _buildCard(story, col)),
                            child: _buildCard(story, col),
                          )),
                      if (stories.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 24, horizontal: 12),
                          decoration: BoxDecoration(
                              border: Border.all(color: _kBorder),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Center(
                              child: Text('Drop stories here',
                                  style:
                                      TextStyle(fontSize: 12, color: _kMuted))),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AgileTask story, _KanbanColumn col) {
    final feature = _featureById[story.featureId];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showStoryDetail(story),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _priorityDot(story.priority),
                const SizedBox(width: 6),
                Text(story.id,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kMuted)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: _kAccentBg,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('${story.storyPoints}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _kAccent)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(story.userStory,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _kHeadline,
                    height: 1.3)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (feature != null && feature.title.isNotEmpty)
                  _smallTag(feature.title),
                if (story.readinessStatus.isNotEmpty)
                  _smallTag(story.readinessStatus),
                if (story.plannedSprintId.isNotEmpty)
                  _smallTag('Sprint planned'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: col.accent.withOpacity(0.2),
                  child: Text(
                    story.assignedRole.isNotEmpty
                        ? story.assignedRole
                            .split(' ')
                            .map((p) => p.isNotEmpty ? p[0] : '')
                            .take(2)
                            .join()
                        : '?',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: col.accent),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    story.assignedRole.isNotEmpty
                        ? story.assignedRole
                        : 'Unassigned',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: _kMuted),
                  ),
                ),
                Icon(Icons.drag_indicator, size: 14, color: _kMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(fontSize: 10, color: _kMuted)),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveData,
          icon: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined, size: 16),
          label: Text(_isSaving ? 'Saving…' : 'Save Board'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reload'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kAccent,
            side: const BorderSide(color: _kAccent),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const Spacer(),
        Text(
            'Board columns come from planning Kanban workflow configuration; cards come from the same AgileTask stories used by backlog planning and schedule import.',
            style: TextStyle(
                fontSize: 12, color: _kMuted, fontStyle: FontStyle.italic)),
      ],
    );
  }
}

class _KanbanColumn {
  final String id;
  final String title;
  final Color accent;
  final int wipLimit;

  const _KanbanColumn(
      {required this.id,
      required this.title,
      required this.accent,
      required this.wipLimit});
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFF59E0B)),
            SizedBox(height: 16),
            Text('Loading kanban board…',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
