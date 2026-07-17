import 'package:flutter/material.dart';

import 'package:ndu_project/screens/front_end_planning_requirements_screen.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';
import 'package:ndu_project/widgets/content_text.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/front_end_planning_header.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';

import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/services/api_key_manager.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/widgets/proceed_confirmation_gate.dart';
import 'package:ndu_project/widgets/scroll_indicator_overlay.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

/// Front End Planning – Details (Scope, Assumptions, Constraints)
///
/// TODO: These sections NEED to be auto-generated using AI based on initial
/// project information (project type, description, goals, etc.). The AI should
/// generate intelligent suggestions for:
/// - Within Scope: Activities explicitly included (e.g., "erecting the building")
/// - Out of Scope: Activities explicitly excluded
/// - Assumptions: Conditions assumed true (e.g., "assuming rent, not purchase")
/// - Constraints: Fixed limitations (e.g., "budget cap", "regulatory requirements")
///
/// Users should be prompted to edit and add to the auto-generated lists.
/// This feature is highlighted in the requirements screenshots and needs implementation.
class FrontEndPlanningWorkspaceScreen extends StatefulWidget {
  const FrontEndPlanningWorkspaceScreen({
    super.key,
    this.initialNotes = '',
    this.initialSummary = '',
  });

  final String initialNotes;
  final String initialSummary;

  static void open(
    BuildContext context, {
    String initialNotes = '',
    String initialSummary = '',
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FrontEndPlanningWorkspaceScreen(
          initialNotes: initialNotes,
          initialSummary: initialSummary,
        ),
      ),
    );
  }

  @override
  State<FrontEndPlanningWorkspaceScreen> createState() =>
      _FrontEndPlanningWorkspaceScreenState();
}

class _FrontEndPlanningWorkspaceScreenState
    extends State<FrontEndPlanningWorkspaceScreen> {
  // We keep local controllers/lists to manage state before sync
  final ScrollController _contentScrollController = ScrollController();
  final TextEditingController _notesController = RichTextEditingController();

  // Note: We are migrating away from a big "Summary" text block to structured fields.
  // However, we'll keep the summary text for backward compatibility or as an "Executive Summary".
  final TextEditingController _summaryController = RichTextEditingController();

  // Structured Data Lists
  List<String> _withinScope = [];
  List<String> _outOfScope = [];
  List<String> _assumptions = [];
  List<String> _constraints = [];

  bool _isSyncReady = false;

  // AI Service
  final OpenAiServiceSecure _openAi = OpenAiServiceSecure();
  bool _isGenerating = false;
  final Map<String, List<List<String>>> _listUndoHistory =
      <String, List<List<String>>>{};
  static const int _maxUndoSnapshotsPerList = 20;

  List<String> _listForType(String type) {
    if (type == 'scope') return _withinScope;
    if (type == 'out') return _outOfScope;
    if (type == 'assumptions') return _assumptions;
    if (type == 'constraints') return _constraints;
    return const <String>[];
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _normalizeItemText(String input) {
    var value = input.replaceAll(RegExp(r'^\s*[-*]+\s*'), '');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }

  String _dedupeKey(String input) {
    final cleaned = _normalizeItemText(input).toLowerCase();
    return cleaned.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  List<String> _normalizeList(List<String> values) {
    final result = <String>[];
    final seen = <String>{};
    for (final raw in values) {
      final value = _normalizeItemText(raw);
      if (value.isEmpty) continue;
      final key = _dedupeKey(value);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(value);
    }
    return result;
  }

  void _pushUndoSnapshot(String type, List<String> previousItems) {
    final history = _listUndoHistory.putIfAbsent(type, () => <List<String>>[]);
    if (history.isNotEmpty && _listsEqual(history.last, previousItems)) {
      return;
    }
    history.add(List<String>.from(previousItems));
    if (history.length > _maxUndoSnapshotsPerList) {
      history.removeAt(0);
    }
  }

  bool _canUndo(String type) => (_listUndoHistory[type]?.isNotEmpty ?? false);

  void _undoListChange(String type) {
    final history = _listUndoHistory[type];
    if (history == null || history.isEmpty) return;
    final previous = history.removeLast();
    _updateList(type, previous, recordHistory: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Last change undone')),
    );
  }

  Future<void> _showAiGeneratedNotice() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('KAZ AI Suggestions Added'),
        content: const Text(
            'These were auto-generated by KAZ AI based on the defined project scope. Please review and refine them to ensure all relevant aspects of the project are accurately captured.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNextPressed() async {
    final data = ProjectDataHelper.getData(context);
    if (!data.frontEndPlanning.detailsConfirmed) {
      final confirmed = await showProceedWithoutReviewDialog(
        context,
        title: 'Please confirm you have reviewed and understood this step',
        message:
            'I confirm that I have reviewed all information on this page before proceeding.',
      );
      if (!confirmed || !mounted) return;

      final provider = ProjectDataHelper.getProvider(context);
      provider.updateField(
        (d) => d.copyWith(
          frontEndPlanning: ProjectDataHelper.updateFEPField(
            current: d.frontEndPlanning,
            detailsConfirmed: true,
          ),
        ),
      );
      provider.saveToFirebase(checkpoint: 'fep_details_confirmed');
    }

    await ProjectDataHelper.saveAndNavigate(
      context: context,
      checkpoint: 'fep_details_complete',
      saveInBackground: true,
      nextScreenBuilder: () => const FrontEndPlanningRequirementsScreen(),
      dataUpdater: (data) => data.copyWith(
        withinScope: _withinScope,
        outOfScope: _outOfScope,
        assumptions: _assumptions,
        constraints: _constraints,
        frontEndPlanning: ProjectDataHelper.updateFEPField(
          current: data.frontEndPlanning,
          summary: _summaryController.text,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    ApiKeyManager.initializeApiKey();
    _notesController.text = widget.initialNotes;
    _summaryController.text = widget.initialSummary;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final data = ProjectDataHelper.getData(context);
      _notesController.text = data.frontEndPlanning
          .summary; // We might use summary field for notes? Or check mapping.
      // Actually widget.initialNotes might be passed, but usually we load from provider.
      // Let's stick to loading from provider.
      // The previous code mapped `_notesController` to... wait, previous code didn't strictly sync back in a visible way in `initState`
      // except via `_syncToProvider` if listeners were attached.

      // Let's map consistent with `ProjectDataModel`:
      // `FrontEndPlanningData.summary` -> `_summaryController` ?
      // `ProjectDataModel.notes` (initiation) -> `_notesController` ?

      // The user wants "Details" page.
      // Let's rely on `ProjectDataHelper.getData` to source truth.
      final rawWithinScope = List<String>.from(data.withinScope);
      final rawOutOfScope = List<String>.from(data.outOfScope);
      final rawAssumptions = List<String>.from(data.assumptions);
      final rawConstraints = List<String>.from(data.constraints);

      _withinScope = _normalizeList(rawWithinScope);
      _outOfScope = _normalizeList(rawOutOfScope);
      _assumptions = _normalizeList(rawAssumptions);
      _constraints = _normalizeList(rawConstraints);

      // Legacy mapping if needed, or just use what we have
      if (_summaryController.text.isEmpty) {
        _summaryController.text = data.frontEndPlanning.summary;
      }

      final didNormalizeExistingLists =
          !_listsEqual(rawWithinScope, _withinScope) ||
              !_listsEqual(rawOutOfScope, _outOfScope) ||
              !_listsEqual(rawAssumptions, _assumptions) ||
              !_listsEqual(rawConstraints, _constraints);

      _isSyncReady = true;
      setState(() {});

      if (didNormalizeExistingLists) {
        _syncLists();
      }
    });
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    final fep = projectData.frontEndPlanning;
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Front End Planning Workspace',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
        ]),
        PdfSection.text('Notes', fep.requirementsNotes ?? 'No data recorded.'),
      ],
    );
  }

  @override
  void dispose() {
    _contentScrollController.dispose();
    _notesController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  void _syncLists() {
    if (!mounted || !_isSyncReady) return;
    final provider = ProjectDataHelper.getProvider(context);
    provider.updateField((data) => data.copyWith(
        withinScope: _withinScope,
        outOfScope: _outOfScope,
        assumptions: _assumptions,
        constraints: _constraints,
        frontEndPlanning: ProjectDataHelper.updateFEPField(
          current: data.frontEndPlanning,
          summary: _summaryController.text,
        )));
    // We intentionally don't auto-save to Firestore on every keystroke/add for lists
    // to avoid excessive writes, but we update provider.
    // The "Next" button or explicit Save should persist.
    // However, for consistency with other screens, we might want to save.
    // Let's trigger save on list modifications.
    provider.saveToFirebase(checkpoint: 'fep_details_lists');
  }

  void _updateList(String type, List<String> newList,
      {bool recordHistory = true}) {
    final normalizedList = _normalizeList(newList);
    final previousList = List<String>.from(_listForType(type));
    if (_listsEqual(previousList, normalizedList)) return;
    if (recordHistory) {
      _pushUndoSnapshot(type, previousList);
    }

    setState(() {
      if (type == 'scope') _withinScope = normalizedList;
      if (type == 'out') _outOfScope = normalizedList;
      if (type == 'assumptions') _assumptions = normalizedList;
      if (type == 'constraints') _constraints = normalizedList;
    });
    _syncLists();
  }

  Future<void> _generateList(String type, String sectionLabel) async {
    if (_isGenerating) return;

    // Capture messenger up front to avoid using context after awaits.
    final messenger = ScaffoldMessenger.of(context);
    final projectData = ProjectDataHelper.getData(context);

    // Check if list is not empty
    final currentList = List<String>.from(_listForType(type));

    if (currentList.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Generate additional items?'),
          content: const Text(
              'KAZ AI will suggest additional items and keep your existing list. Duplicate suggestions will be filtered out. Continue?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue')),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (!mounted) return;

    setState(() => _isGenerating = true);

    try {
      final existingItems = _normalizeList(currentList);
      final existingItemsContext =
          existingItems.take(10).map((entry) => '- $entry').join('\n');
      final contextStr = StringBuffer()
        ..writeln(ProjectDataHelper.buildFepContext(projectData,
            sectionLabel: 'Details - $sectionLabel'))
        ..writeln()
        ..writeln('Section-specific guidance:')
        ..writeln(
            '- Keep suggestions directly tied to this project and this section.')
        ..writeln(
            '- Avoid repeating existing items or introducing generic filler.')
        ..writeln(
            '- Keep phrasing concise and consistent with existing entries.');
      if (existingItemsContext.isNotEmpty) {
        contextStr
          ..writeln()
          ..writeln('Existing items:')
          ..writeln(existingItemsContext);
      }

      final items = await _openAi.generatePlanningItems(
        section: sectionLabel,
        context: contextStr.toString(),
      );

      if (!mounted) return;

      final prefersTitlePrefix =
          existingItems.any((entry) => entry.contains(':'));
      final generated = items
          .map((i) {
            final title = _normalizeItemText(i.title);
            final description = _normalizeItemText(i.description);
            if (description.isEmpty) return '';
            if (prefersTitlePrefix && title.isNotEmpty) {
              return '$title: $description';
            }
            return description;
          })
          .where((entry) => entry.isNotEmpty)
          .toList();

      final merged = _normalizeList([...currentList, ...generated]);
      final addedCount = merged.length - existingItems.length;
      _updateList(type, merged);

      messenger.showSnackBar(
        SnackBar(
            content: Text(addedCount > 0
                ? 'Added $addedCount new items for $sectionLabel'
                : 'No new unique items were generated for $sectionLabel')),
      );

      if (addedCount > 0) {
        await _showAiGeneratedNotice();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error generating items: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const AdminEditToggle(),
          SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DraggableSidebar(
                  openWidth: AppBreakpoints.sidebarWidth(context),
                  child:
                      const InitiationLikeSidebar(activeItemLabel: 'Details'),
                ),
                Expanded(
                  child: ScrollIndicatorOverlay(
                    controller: _contentScrollController,
                    child: SingleChildScrollView(
                      controller: _contentScrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FrontEndPlanningHeader(onExportPdf: _exportPdf),
                          const SizedBox(height: 24),

                          // Structured Cards Grid/Column
                          // We use a column of full-width cards or wrapped cards
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _ListEditorCard(
                                  title: 'Within Project Scope',
                                  items: _withinScope,
                                  icon: Icons.check_circle_outline,
                                  color: Colors.green,
                                  onGenerate: () =>
                                      _generateList('scope', 'Within Scope'),
                                  onUndo: () => _undoListChange('scope'),
                                  canUndo: _canUndo('scope'),
                                  onItemAdded: (val) => _updateList(
                                      'scope', [..._withinScope, val]),
                                  onItemDeleted: (index) {
                                    if (index < 0 ||
                                        index >= _withinScope.length) {
                                      return;
                                    }
                                    final l = [..._withinScope];
                                    l.removeAt(index);
                                    _updateList('scope', l);
                                  },
                                  onItemEdited: (index, val) {
                                    final l = [..._withinScope];
                                    l[index] = val;
                                    _updateList('scope', l);
                                  },
                                  onReorder: (oldIndex, newIndex) {
                                    if (newIndex > oldIndex) newIndex -= 1;
                                    final list = [..._withinScope];
                                    final item = list.removeAt(oldIndex);
                                    list.insert(newIndex, item);
                                    _updateList('scope', list);
                                  },
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _ListEditorCard(
                                  title: 'Out of Project Scope',
                                  items: _outOfScope,
                                  icon: Icons.cancel_presentation_outlined,
                                  color: Colors.red,
                                  onGenerate: () =>
                                      _generateList('out', 'Out of Scope'),
                                  onUndo: () => _undoListChange('out'),
                                  canUndo: _canUndo('out'),
                                  onItemAdded: (val) =>
                                      _updateList('out', [..._outOfScope, val]),
                                  onItemDeleted: (index) {
                                    if (index < 0 ||
                                        index >= _outOfScope.length) {
                                      return;
                                    }
                                    final l = [..._outOfScope];
                                    l.removeAt(index);
                                    _updateList('out', l);
                                  },
                                  onItemEdited: (index, val) {
                                    final l = [..._outOfScope];
                                    l[index] = val;
                                    _updateList('out', l);
                                  },
                                  onReorder: (oldIndex, newIndex) {
                                    if (newIndex > oldIndex) newIndex -= 1;
                                    final list = [..._outOfScope];
                                    final item = list.removeAt(oldIndex);
                                    list.insert(newIndex, item);
                                    _updateList('out', list);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _ListEditorCard(
                                  title: 'Project Assumptions',
                                  items: _assumptions,
                                  icon: Icons.lightbulb_outline,
                                  color: Colors.amber,
                                  onGenerate: () => _generateList(
                                      'assumptions', 'Assumptions'),
                                  onUndo: () => _undoListChange('assumptions'),
                                  canUndo: _canUndo('assumptions'),
                                  onItemAdded: (val) => _updateList(
                                      'assumptions', [..._assumptions, val]),
                                  onItemDeleted: (index) {
                                    if (index < 0 ||
                                        index >= _assumptions.length) {
                                      return;
                                    }
                                    final l = [..._assumptions];
                                    l.removeAt(index);
                                    _updateList('assumptions', l);
                                  },
                                  onItemEdited: (index, val) {
                                    final l = [..._assumptions];
                                    l[index] = val;
                                    _updateList('assumptions', l);
                                  },
                                  onReorder: (oldIndex, newIndex) {
                                    if (newIndex > oldIndex) newIndex -= 1;
                                    final list = [..._assumptions];
                                    final item = list.removeAt(oldIndex);
                                    list.insert(newIndex, item);
                                    _updateList('assumptions', list);
                                  },
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _ListEditorCard(
                                  title: 'Project Constraints',
                                  items: _constraints,
                                  icon: Icons.gavel_outlined,
                                  color: Colors.orange,
                                  onGenerate: () => _generateList(
                                      'constraints', 'Constraints'),
                                  onUndo: () => _undoListChange('constraints'),
                                  canUndo: _canUndo('constraints'),
                                  onItemAdded: (val) => _updateList(
                                      'constraints', [..._constraints, val]),
                                  onItemDeleted: (index) {
                                    if (index < 0 ||
                                        index >= _constraints.length) {
                                      return;
                                    }
                                    final l = [..._constraints];
                                    l.removeAt(index);
                                    _updateList('constraints', l);
                                  },
                                  onItemEdited: (index, val) {
                                    final l = [..._constraints];
                                    l[index] = val;
                                    _updateList('constraints', l);
                                  },
                                  onReorder: (oldIndex, newIndex) {
                                    if (newIndex > oldIndex) newIndex -= 1;
                                    final list = [..._constraints];
                                    final item = list.removeAt(oldIndex);
                                    list.insert(newIndex, item);
                                    _updateList('constraints', list);
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 24),

                          // Executive Summary Section (Legacy/Fallback)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: const [
                              EditableContentText(
                                contentKey: 'fep_workspace_summary_title',
                                fallback: 'Executive Summary',
                                category: 'front_end_planning',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87),
                              ),
                              SizedBox(width: 8),
                              EditableContentText(
                                contentKey: 'fep_workspace_summary_subtitle',
                                fallback:
                                    '(Brief high-level overview not captured above)',
                                category: 'front_end_planning',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _roundedField(
                            context,
                            controller: _summaryController,
                            hint: 'Enter executive summary...',
                            minLines: 6,
                            onChanged: (_) {
                              // Debounce save logic could be added here
                            },
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KazAiChatBubble(positioned: false),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _handleNextPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC812),
                    foregroundColor: const Color(0xFF111827),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                    elevation: 0,
                  ),
                  child: const Text('Next',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundedField(BuildContext context,
      {required TextEditingController controller,
      required String hint,
      int minLines = 1,
      Function(String)? onChanged}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          VoiceTextField(
            controller: controller,
            minLines: minLines,
            maxLines: null,
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }
}

class _ListEditorCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;
  final Color color;
  final Function(String) onItemAdded;
  final Function(int) onItemDeleted;
  final Function(int, String) onItemEdited;
  final VoidCallback? onGenerate;
  final VoidCallback? onUndo;
  final bool canUndo;
  final void Function(int oldIndex, int newIndex)? onReorder;

  const _ListEditorCard({
    required this.title,
    required this.items,
    required this.icon,
    required this.color,
    required this.onItemAdded,
    required this.onItemDeleted,
    required this.onItemEdited,
    this.onGenerate,
    this.onUndo,
    this.canUndo = false,
    this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(color: color.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color.withOpacity(0.8),
                  ),
                ),
                const Spacer(),
                if (onUndo != null) ...[
                  IconButton(
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    onPressed: canUndo ? onUndo : null,
                    color: canUndo ? color : const Color(0xFF9CA3AF),
                    tooltip: canUndo ? 'Undo last change' : 'Nothing to undo',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(right: 8),
                  ),
                ],
                if (onGenerate != null) ...[
                  IconButton(
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    onPressed: onGenerate,
                    color: color,
                    tooltip: 'Generate with AI',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(right: 8),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => _showAddDialog(context),
                  color: color,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No items identified yet.',
                  style: TextStyle(
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                      fontSize: 13),
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              itemCount: items.length,
              onReorder: onReorder ?? (oldIndex, newIndex) {},
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  key: ValueKey('$title-$index-$item'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle,
                          size: 6, color: Color(0xFFD1D5DB)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item,
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF374151))),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.drag_indicator,
                              size: 18, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 16, color: Color(0xFF9CA3AF)),
                        onPressed: () => _showEditDialog(context, index, item),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 16, color: Color(0xFFEF4444)),
                        onPressed: () => _confirmDelete(context, index, item),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, int index, String itemText) async {
    final preview =
        itemText.length > 120 ? '${itemText.substring(0, 120)}...' : itemText;
    final confirm = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Item?',
      itemLabel: preview,
    );
    if (confirm == true) {
      onItemDeleted(index);
    }
  }

  void _showAddDialog(BuildContext context) {
    final controller = RichTextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add to $title'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              VoiceTextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Enter item description...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                onItemAdded(value);
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          )
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _showEditDialog(BuildContext context, int index, String current) {
    final controller = RichTextEditingController(text: current);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit item in $title'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              VoiceTextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Enter item description...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                onItemEdited(index, value);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          )
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}
