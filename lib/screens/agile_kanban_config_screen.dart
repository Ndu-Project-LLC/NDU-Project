import 'package:flutter/material.dart';
import 'package:ndu_project/services/kanban_config_service.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/screens/agile_kanban_board_screen.dart'
    show KanbanBoardPanel;
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

const Color _kBackground = Colors.white;
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);
const Color _kAccent = Color(0xFFB8860B);
const Color _kAccentBg = Color(0xFFFEF3C7);

/// Kanban workflow configuration.
///
/// The review that produced this page asked for two things: the columns the
/// project actually saved (not a static mock of them), and a plain statement of
/// what a user may change here versus what the board owns. So the page is split
/// into the columns you edit and the rules that are fixed.
class AgileKanbanConfigScreen extends StatefulWidget {
  const AgileKanbanConfigScreen({super.key});

  @override
  State<AgileKanbanConfigScreen> createState() =>
      _AgileKanbanConfigScreenState();
}

class _AgileKanbanConfigScreenState extends State<AgileKanbanConfigScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDirty = false;
  List<_ColumnDraft> _drafts = const [];

  String? get _projectId {
    try {
      return ProjectDataHelper.getData(context).projectId;
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
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    // With no project open the board still renders the built-in workflow, so
    // show those same columns rather than an empty page.
    final columns = pid == null
        ? List<KanbanColumnConfig>.from(KanbanConfigService.defaultColumns)
        : await KanbanConfigService.loadColumns(pid);
    if (!mounted) return;
    setState(() {
      _drafts = [
        for (final column in columns)
          _ColumnDraft(
            column: column,
            onChanged: _markDirty,
          ),
      ];
      _isLoading = false;
      _isDirty = false;
    });
  }

  void _markDirty() {
    if (_isDirty) return;
    setState(() => _isDirty = true);
  }

  List<KanbanColumnConfig> get _draftColumns => [
        for (final draft in _drafts)
          KanbanColumnConfig(
            name: draft.name.text.trim(),
            wipLimit: KanbanConfigService.parseWipLimit(draft.wip.text),
          ),
      ];

  void _addColumn() {
    setState(() {
      _drafts = [
        ..._drafts,
        _ColumnDraft(
          column: const KanbanColumnConfig(name: 'New Column'),
          onChanged: _markDirty,
        ),
      ];
      _isDirty = true;
    });
  }

  void _removeColumn(int index) {
    if (_drafts.length <= 1) return;
    setState(() {
      final removed = _drafts.removeAt(index);
      removed.dispose();
      _isDirty = true;
    });
  }

  void _moveColumn(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _drafts.length) return;
    setState(() {
      final draft = _drafts.removeAt(index);
      _drafts.insert(target, draft);
      _isDirty = true;
    });
  }

  Future<void> _saveWorkflow() async {
    final pid = _projectId;
    if (pid == null) {
      _snack('Open a project before saving the workflow.');
      return;
    }
    final blank = <int>[
      for (var i = 0; i < _drafts.length; i++)
        if (_drafts[i].name.text.trim().isEmpty) i + 1,
    ];
    if (blank.isNotEmpty) {
      _snack('Column ${blank.join(', ')} needs a name.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await KanbanConfigService.saveColumns(
        projectId: pid,
        columns: _draftColumns,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isDirty = false;
      });
      _snack('Kanban workflow saved.');
    } catch (error) {
      debugPrint('AgileKanbanConfigScreen save error: $error');
      if (!mounted) return;
      setState(() => _isSaving = false);
      _snack('Could not save the workflow. Please try again.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
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
                      'Agile Delivery Model - Kanban Configuration'),
            ),
            Expanded(
              child: Stack(
                children: [
                  const MobileSidebarHamburger(
                    sidebar: InitiationLikeSidebar(
                        activeItemLabel:
                            'Agile Delivery Model - Kanban Configuration'),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: hp, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlanningPhaseHeader(
                          title: 'Kanban Workflow Configuration',
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                              context, 'agile_kanban_config'),
                          onForward: () => PlanningPhaseNavigation.goToNext(
                              context, 'agile_kanban_config'),
                          onExportPdf: _exportPdf,
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          _buildEditableColumnsSection(),
                          const SizedBox(height: 24),
                          _buildLockedSection(),
                          const SizedBox(height: 24),
                          _buildBoardSection(),
                          const SizedBox(height: 24),
                        ],
                        const SizedBox(height: 24),
                        LaunchPhaseNavigation(
                          backLabel: PlanningPhaseNavigation.backLabel(
                              'agile_kanban_config'),
                          nextLabel: PlanningPhaseNavigation.nextLabel(
                              'agile_kanban_config'),
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                              context, 'agile_kanban_config'),
                          onNext: () => PlanningPhaseNavigation.goToNext(
                              context, 'agile_kanban_config'),
                        ),
                        const SizedBox(height: 40),
                      ],
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

  /// The columns, with the one control that matters here: what they are, what
  /// order they come in, and how much work each one holds.
  Widget _buildEditableColumnsSection() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Workflow Columns',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kHeadline)),
              ),
              _badge(
                label: 'YOURS TO CHANGE',
                background: _kAccentBg,
                foreground: _kAccent,
              ),
              if (_isDirty) ...[
                const SizedBox(width: 8),
                _badge(
                  label: 'UNSAVED',
                  background: const Color(0xFFFEE2E2),
                  foreground: const Color(0xFFB91C1C),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          const Text(
              'Rename a column, move it up or down, set how many cards it may '
              'hold, or add and remove columns. What you save here is the '
              'workflow every Kanban board in this project renders.',
              style: TextStyle(fontSize: 12, color: _kMuted)),
          const SizedBox(height: 16),
          for (var i = 0; i < _drafts.length; i++) ...[
            _buildColumnRow(i),
            if (i != _drafts.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('kanban-add-column'),
                onPressed: _addColumn,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add column'),
              ),
              FilledButton.icon(
                key: const ValueKey('kanban-save-config'),
                onPressed: (_isSaving || _projectId == null)
                    ? null
                    : _saveWorkflow,
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: const Text('Save workflow'),
              ),
              if (_projectId == null)
                const Text('Open a project to save.',
                    style: TextStyle(fontSize: 12, color: _kMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColumnRow(int index) {
    final draft = _drafts[index];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            child: Text('${index + 1}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _kMuted)),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              key: ValueKey('kanban-column-name-$index'),
              controller: draft.name,
              decoration: const InputDecoration(
                labelText: 'Column name',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            // Listens to its own field so the resolved limit updates as the
            // user types, without rebuilding the board below on every
            // keystroke.
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: draft.wip,
              builder: (context, value, _) => TextField(
                key: ValueKey('kanban-column-wip-$index'),
                controller: draft.wip,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'WIP limit',
                  hintText: 'No limit',
                  helperText: KanbanConfigService.wipLimitLabel(
                      KanbanConfigService.parseWipLimit(value.text)),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Move column ${index + 1} up',
            onPressed: index == 0 ? null : () => _moveColumn(index, -1),
            icon: const Icon(Icons.arrow_upward, size: 18),
          ),
          IconButton(
            tooltip: 'Move column ${index + 1} down',
            onPressed:
                index == _drafts.length - 1 ? null : () => _moveColumn(index, 1),
            icon: const Icon(Icons.arrow_downward, size: 18),
          ),
          IconButton(
            tooltip: 'Remove column ${index + 1}',
            onPressed:
                _drafts.length <= 1 ? null : () => _removeColumn(index),
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }

  /// What the board owns. Stated on the page because the review found the
  /// previous read-only cards looked like configuration the user could not do.
  Widget _buildLockedSection() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Fixed on Every Kanban Board',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kHeadline)),
              ),
              _badge(
                label: 'LOCKED',
                background: const Color(0xFFE5E7EB),
                foreground: const Color(0xFF374151),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
              'These are not configuration — they are how the board behaves, '
              'and they are the same on every screen that shows it.',
              style: TextStyle(fontSize: 12, color: _kMuted)),
          const SizedBox(height: 12),
          for (final rule in _lockedRules) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.lock_outline, size: 14, color: _kMuted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(rule,
                        style: const TextStyle(fontSize: 12, color: _kMuted)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const List<String> _lockedRules = [
    'A card\'s state is derived from its column name — renaming a column '
        're-states every card in it.',
    'Cards move between columns by dragging them on the board; this page only '
        'defines the columns.',
    'A column at its WIP limit blocks further pulls until a card leaves it.',
    'Renaming or removing a column re-homes its cards to the first column, '
        'because their old state no longer exists.',
    'One workflow per project: the same columns drive the board wherever the '
        'Execution phase opens it.',
  ];

  /// Live Kanban Board — the same existing board widget used by the
  /// Kanban Board screen, driven by the workflow columns from the saved
  /// Kanban configuration.
  Widget _buildBoardSection() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Kanban Board',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              _badge(
                label: 'LIVE',
                background: _kAccentBg,
                foreground: _kAccent,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
              'Shows the columns saved above. Drag stories between columns, '
              'then Save Board.',
              style: TextStyle(fontSize: 12, color: _kMuted)),
          const SizedBox(height: 16),
          const KanbanBoardPanel(),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }

  Widget _badge({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: foreground,
              letterSpacing: 0.8)),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Kanban Configuration',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName},
          {'Solution Title': projectData.solutionTitle},
        ]),
        PdfSection.keyValue('Workflow Columns', [
          for (final column in _draftColumns)
            {
              column.name: 'WIP limit: '
                  '${KanbanConfigService.wipLimitLabel(column.wipLimit)}',
            },
        ]),
        PdfSection.text(
            'Notes',
            projectData.planningNotes['planning_agile_kanban_config_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}

/// Editable state for one workflow column.
class _ColumnDraft {
  _ColumnDraft({required KanbanColumnConfig column, VoidCallback? onChanged})
      : name = TextEditingController(text: column.name),
        wip = TextEditingController(
          text: KanbanConfigService.isUnlimited(column.wipLimit)
              ? ''
              : '${column.wipLimit}',
        ) {
    name.addListener(() => onChanged?.call());
    wip.addListener(() => onChanged?.call());
  }

  final TextEditingController name;
  final TextEditingController wip;

  void dispose() {
    name.dispose();
    wip.dispose();
  }
}
