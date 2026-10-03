import 'package:flutter/material.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/feature_model.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';
import 'package:ndu_project/services/epic_feature_service.dart';
import 'package:ndu_project/services/execution_phase_service.dart';
import 'package:ndu_project/services/kanban_config_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:go_router/go_router.dart';

/// Embeddable, live Kanban board — the SAME board used by the
/// Kanban Board screen (workflow columns from the saved Kanban
/// workflow configuration, cards from the AgileTask stories).
/// Rendered standalone on /agile-kanban-board and embedded under
/// the Kanban Workflow Configuration page.
class KanbanBoardPanel extends StatefulWidget {
  const KanbanBoardPanel({
    super.key,
    this.boardHeight = kKanbanBoardHeight,
    this.stories,
  });

  /// Stories to render instead of loading them from the project.
  ///
  /// Production callers leave this null and the board loads its own cards.
  /// A test (or a preview) can pass a list to drive the board without
  /// Firestore; the columns then come from the board's own defaults.
  final List<AgileTask>? stories;

  /// Height of the desktop board area (the row of columns); on a narrow window
  /// the columns stack and this is ignored.
  ///
  /// The Kanban Board screen keeps [kKanbanBoardHeight]. The Kanban
  /// Configuration page embeds the same panel as a **preview**, so it passes a
  /// smaller height — Lusaka 27: *"I feel like it's covering the entire page"*
  /// — and the board no longer takes the configuration page over.
  final double boardHeight;

  @override
  State<KanbanBoardPanel> createState() => _KanbanBoardPanelState();
}

/// The desktop board area when the board **is** the page (the Kanban Board
/// screen), and the preview height when it is embedded in configuration.
const double kKanbanBoardHeight = 640;
const double kKanbanBoardPreviewHeight = 320;

class AgileKanbanBoardScreen extends StatefulWidget {
  const AgileKanbanBoardScreen({super.key});

  static void open(BuildContext context) {
    context.push('/agile-kanban-board');
  }

  @override
  State<AgileKanbanBoardScreen> createState() =>
      _AgileKanbanBoardScreenState();
}

class _KanbanBoardPanelState extends State<KanbanBoardPanel> {
  static const Color _kAccent = Color(0xFFF59E0B);
  static const Color _kAccentLight = Color(0xFFFFC812);
  static const Color _kAccentBg = Color(0xFFFEF3C7);
  static const Color _kBackground = Colors.white;
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
    final injected = widget.stories;
    if (injected != null) {
      final columns = _buildColumnsFromConfig(const {});
      if (mounted) {
        setState(() {
          _columns = columns;
          _stories = List<AgileTask>.of(injected);
          _storiesByColumn = _groupStories(columns, injected);
          _isLoading = false;
        });
      }
      return;
    }

    final pid = _projectId;
    if (pid == null) {
      // No project context — still show the default workflow columns so the
      // embedded board renders an (empty) board instead of a blank 640px box.
      if (mounted) {
        setState(() {
          _columns = _buildColumnsFromConfig(const {});
          _isLoading = false;
        });
      }
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
      // The load heals duplicate story ids; writing that repair back here (and
      // only here, where the user is looking at the board) means the stored
      // payload is fixed rather than re-healed on every open.
      final stories = await ExecutionPhaseService.loadAgileTasks(
          projectId: pid, persistRepairs: true);
      final columns = _buildColumnsFromConfig(kanbanConfig);
      final grouped = _groupStories(columns, stories);
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

  /// Groups [stories] into [columns] by workflow state, with an unrecognised
  /// (or empty) state landing in the first column, as the board renders it.
  Map<String, List<AgileTask>> _groupStories(
      List<_KanbanColumn> columns, List<AgileTask> stories) {
    final grouped = {for (final c in columns) c.id: <AgileTask>[]};
    for (final story in stories) {
      final state = grouped.containsKey(story.workflowState)
          ? story.workflowState
          : columns.first.id;
      grouped[state]!.add(story);
    }
    return grouped;
  }

  List<_KanbanColumn> _buildColumnsFromConfig(Map<String, dynamic> data) {
    // The configuration page reads and writes these same columns through
    // KanbanConfigService, so both the saved shape and the fallback come from
    // there — the board cannot drift from what the user configured.
    final configured = KanbanConfigService.columnsFromConfig(data);
    final columns = configured.isEmpty
        ? KanbanConfigService.defaultColumns
        : configured;
    return [
      for (final entry in columns.asMap().entries)
        _KanbanColumn(
          id: KanbanConfigService.columnIdFor(entry.value.name,
              fallback: 'column_${entry.key + 1}'),
          title: entry.value.name,
          accent: _accentForIndex(entry.key),
          wipLimit: entry.value.wipLimit,
        ),
    ];
  }

  Color _accentForIndex(int index) {
    const accents = [
      Color(0xFF6B7280),
      Color(0xFFFFC812),
      Color(0xFFF59E0B),
      Color(0xFFB8860B),
      Color(0xFFEF4444),
      Color(0xFF10B981),
      Color(0xFFFFC812),
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
    // Columns can be transiently empty while board config re-syncs; never
    // throw "Bad state: No element" from a tap handler.
    if (_columns.isEmpty) return;
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
                          selectedColor: c.accent.withValues(alpha: 0.2),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
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
                      const Color(0xFFFFC812)),
                  _metaChip(
                      Icons.account_tree_outlined,
                      feature?.title.isNotEmpty == true
                          ? feature!.title
                          : 'Feature unlinked',
                      const Color(0xFFB8860B)),
                  _metaChip(
                      Icons.layers_outlined,
                      epicTitle.isNotEmpty ? epicTitle : 'Epic unlinked',
                      const Color(0xFFD97706)),
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
        return const Color(0xFFFFC812);
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
              color: c.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 1)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);

    if (_isLoading) return const _LoadingStrip();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryBar(),
        const SizedBox(height: 20),
        _buildBoard(isMobile),
        const SizedBox(height: 24),
        _buildActionBar(),
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Image.asset('assets/images/Logo.png',
            height: 36,
            cacheWidth: (MediaQuery.devicePixelRatioOf(context) * 150).round()),
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
            border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
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
          Container(
              width: 1, height: 36, color: Colors.white.withValues(alpha: 0.3)),
          Expanded(
              child:
                  _summaryCell('In Progress', '$inProgress', Icons.flash_on)),
          Container(
              width: 1, height: 36, color: Colors.white.withValues(alpha: 0.3)),
          Expanded(
              child: _summaryCell(
                  'Points Done', '$pointsDone / $pointsTotal', Icons.stars)),
          Container(
              width: 1, height: 36, color: Colors.white.withValues(alpha: 0.3)),
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
                color: Colors.white.withValues(alpha: 0.85),
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
      height: widget.boardHeight,
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
      key: ValueKey('kanban_column_${col.id}'),
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
              color: col.accent.withValues(alpha: 0.08),
              borderRadius: inner
                  ? null
                  : const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            // The column name is what the header is for, so it is given every
            // pixel the badges do not need. It used to sit in a Flexible next
            // to a Spacer, and those two share the free space equally — the
            // name could only ever use half the room it had, which is what cut
            // "In Progress" down to "In Pr…" while the header looked half
            // empty. When a column really is too narrow for the name and both
            // badges, the header stacks instead of shortening the name.
            child: LayoutBuilder(
              builder: (context, header) {
                final name = Text(
                  col.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline),
                );

                final dot = Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: col.accent, shape: BoxShape.circle),
                );

                final countBadge = Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: col.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${stories.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: col.accent)),
                );

                final wipBadge = col.wipLimit < 999
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              wipExceeded
                                  ? Icons.warning_amber_rounded
                                  : Icons.check,
                              size: 12,
                              color:
                                  wipExceeded ? Colors.red : Colors.green),
                          const SizedBox(width: 2),
                          Text(
                            'WIP ${col.wipLimit}',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: wipExceeded ? Colors.red : _kMuted),
                          ),
                        ],
                      )
                    : null;

                // The widest column name ("In Progress") plus the dot, the
                // count badge and the WIP badge need about this much room. Below
                // it the name would be cut short, so the header stacks instead.
                if (header.maxWidth < 200) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          dot,
                          const SizedBox(width: 8),
                          countBadge,
                          if (wipBadge != null) ...[
                            const SizedBox(width: 8),
                            wipBadge,
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Tooltip(message: col.title, child: name),
                    ],
                  );
                }

                return Row(
                  children: [
                    dot,
                    const SizedBox(width: 8),
                    // Expanded, not a Flexible beside a Spacer: the name takes
                    // all the leftover width, so it is only shortened when the
                    // column genuinely has nothing left to give.
                    Expanded(
                      child: Tooltip(message: col.title, child: name),
                    ),
                    const SizedBox(width: 6),
                    countBadge,
                    if (wipBadge != null) ...[
                      const SizedBox(width: 8),
                      wipBadge,
                    ],
                  ],
                );
              },
            ),
          ),
          if (wipExceeded)
            Container(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
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
                      ...stories.map((story) => RepaintBoundary(
                            key: ValueKey('kanban_card_${story.id}'),
                            child: Draggable<AgileTask>(
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
                            ),
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
              color: Colors.black.withValues(alpha: 0.04),
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
                  backgroundColor: col.accent.withValues(alpha: 0.2),
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
                const Icon(Icons.drag_indicator, size: 14, color: _kMuted),
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
          color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(fontSize: 10, color: _kMuted)),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const Spacer(),
        // Flexible so the note wraps on narrow widths instead of
        // overflowing the row.
        const Expanded(
          flex: 3,
          child: Text(
              'Board columns come from planning Kanban workflow configuration; cards come from the same AgileTask stories used by backlog planning and schedule import.',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12,
                  color: _kMuted,
                  fontStyle: FontStyle.italic)),
        ),
      ],
    );
  }
}

/// Full-screen route shell for the Kanban board (sidebar + header) that
/// embeds the same [KanbanBoardPanel] used on the configuration page.
class _AgileKanbanBoardScreenState extends State<AgileKanbanBoardScreen> {
  static const Color _kScreenBackground = Colors.white;
  static const Color _kScreenAccent = Color(0xFFF59E0B);
  static const Color _kScreenAccentBg = Color(0xFFFEF3C7);
  static const Color _kScreenHeadline = Color(0xFF111827);

  String? get _projectId => ProjectDataHelper.getData(context).projectId;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = AppBreakpoints.isMobile(context);
    final double hp = isMobile ? 16 : 32;

    return Scaffold(
      backgroundColor: _kScreenBackground,
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
                  const MobileSidebarHamburger(
                    sidebar: InitiationLikeSidebar(
                      activeItemLabel: 'Agile Kanban Board',
                    ),
                  ),
                  SingleChildScrollView(
                    padding:
                        EdgeInsets.symmetric(horizontal: hp, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 20),
                        const PlanningPhaseHeader(
                          title: 'Kanban Board',
                          showNavigationButtons: false,
                          breadcrumbPhase: 'Execution',
                          breadcrumbTitle: 'Agile Hub \u203a Kanban Board',
                        ),
                        const SizedBox(height: 24),
                        const KanbanBoardPanel(),
                        const SizedBox(height: 64),
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
        Image.asset('assets/images/Logo.png',
            height: 36,
            cacheWidth:
                (MediaQuery.devicePixelRatioOf(context) * 150).round()),
        const SizedBox(width: 12),
        const Text('Ndu Project',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kScreenHeadline)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kScreenAccentBg,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: _kScreenAccent.withValues(alpha: 0.3)),
          ),
          child: const Text('KANBAN FLOW',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kScreenAccent,
                  letterSpacing: 1.1)),
        ),
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
