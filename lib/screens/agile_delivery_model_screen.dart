import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/field_regenerate_undo_buttons.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

const Color _kBackground = Colors.white;
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);
const Color _kAccent = Color(0xFFD97706);

const List<String> _frameworkOptions = ['Scrum', 'Kanban', 'ScrumBan'];
const List<String> _sprintLengthOptions = ['1 Week', '2 Weeks', '3 Weeks', '4 Weeks'];
const List<String> _estimationOptions = [
  'Story Points (Fibonacci)',
  'Story Points (Modified Fibonacci)',
  'T-Shirt Sizes',
  'Ideal Days',
  'Ideal Hours',
  'Custom Scale',
];

class AgileDeliveryModelScreen extends StatefulWidget {
  const AgileDeliveryModelScreen({super.key});

  @override
  State<AgileDeliveryModelScreen> createState() =>
      _AgileDeliveryModelScreenState();
}

class _AgileDeliveryModelScreenState extends State<AgileDeliveryModelScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<String>> _fieldHistories = {};
  final Map<String, int> _fieldHistoryIndices = {};
  final Map<String, bool> _fieldIsAiGenerated = {};
  final Map<String, bool> _fieldIsRegenerating = {};

  // Structured fields
  String _selectedFramework = _frameworkOptions[0];
  String _selectedSprintLength = _sprintLengthOptions[1];
  String _selectedEstimationMethod = _estimationOptions[0];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGenerating = false;
  Timer? _autoSaveDebounce;

  static const int _savingIndicatorDuration = 1;

  static const List<_FieldConfig> _fields = [
    _FieldConfig(
      key: 'cadence',
      label: 'Sprint cadence & calendar',
      hint: 'Sprint length, ceremonies, and planning calendar.',
    ),
    _FieldConfig(
      key: 'release',
      label: 'Release strategy',
      hint: 'Release waves, branching, and approval gates.',
    ),
    _FieldConfig(
      key: 'backlog',
      label: 'Backlog governance',
      hint: 'Definition of Ready/Done, prioritization, and grooming cadence.',
      fullWidth: true,
    ),
    _FieldConfig(
      key: 'team',
      label: 'Team structure & roles',
      hint: 'Squad ownership, product roles, and cross-functional coverage.',
    ),
    _FieldConfig(
      key: 'metrics',
      label: 'Metrics & reporting',
      hint: 'Velocity, throughput, predictability, and quality measures.',
    ),
    _FieldConfig(
      key: 'risks',
      label: 'Impediment & risk handling',
      hint: 'Escalation process, dependency tracking, and blockers removal.',
      fullWidth: true,
    ),
  ];

  String? get _projectId {
    try {
      return ProjectDataInherited.maybeOf(context)?.projectData.projectId;
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      _controllers[f.key] = TextEditingController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await AgileWireframeService.loadDeliveryModel(pid);
      if (!mounted) return;
      for (final f in _fields) {
        final value = data[f.key] as String? ?? '';
        _controllers[f.key]?.text = value;
        if (value.isNotEmpty) _recordFieldHistory(f.key, value);
      }
      setState(() {
        _selectedFramework = data['framework'] as String? ?? _frameworkOptions[0];
        _selectedSprintLength =
            data['sprintLength'] as String? ?? _sprintLengthOptions[1];
        _selectedEstimationMethod =
            data['estimationMethod'] as String? ?? _estimationOptions[0];
      });
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce =
        Timer(const Duration(milliseconds: 500), () => _performSave());
  }

  Future<void> _performSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final pid = _projectId;
      if (pid == null) return;
      final data = <String, dynamic>{};
      for (final f in _fields) {
        data[f.key] = _controllers[f.key]?.text ?? '';
      }
      data['framework'] = _selectedFramework;
      data['sprintLength'] = _selectedSprintLength;
      data['estimationMethod'] = _selectedEstimationMethod;
      await AgileWireframeService.saveDeliveryModel(projectId: pid, data: data);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Saved'),
              duration: Duration(seconds: _savingIndicatorDuration)),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _generateWithAI() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isGenerating = true);
    try {
      final data = ProjectDataHelper.getData(context);
      final contextText =
          ProjectDataHelper.buildProjectContextScan(data, sectionLabel: 'Agile Delivery Model');
      if (contextText.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Not enough project context to generate. Fill in earlier sections first.')),
          );
        }
        return;
      }
      final openai = OpenAiServiceSecure();
      final result = await openai.generateCompletion(
        'Based on this project context, suggest a delivery model approach.\n\n'
        'Context:\n$contextText\n\n'
        'Return ONLY a valid JSON object with these exact keys:\n'
        '- "framework": "Scrum", "Kanban", or "ScrumBan"\n'
        '- "sprintLength": "1 Week", "2 Weeks", "3 Weeks", or "4 Weeks"\n'
        '- "estimationMethod": "Story Points (Fibonacci)", "T-Shirt Sizes", "Ideal Days", etc.\n'
        '- "cadence": Sprint cadence & calendar (2-3 sentences)\n'
        '- "release": Release strategy (2-3 sentences)\n'
        '- "backlog": Backlog governance (2-3 sentences)\n'
        '- "team": Team structure & roles (2-3 sentences)\n'
        '- "metrics": Metrics & reporting (2-3 sentences)\n'
        '- "risks": Impediment & risk handling (2-3 sentences)',
        maxTokens: 1200,
        temperature: 0.5,
      );
      final parsed = _parseAIResult(result);
      if (parsed.containsKey('framework')) {
        final fw = parsed['framework']!;
        if (_frameworkOptions.contains(fw)) {
          setState(() => _selectedFramework = fw);
        }
      }
      if (parsed.containsKey('sprintLength')) {
        final sl = parsed['sprintLength']!;
        if (_sprintLengthOptions.contains(sl)) {
          setState(() => _selectedSprintLength = sl);
        }
      }
      if (parsed.containsKey('estimationMethod')) {
        final em = parsed['estimationMethod']!;
        if (_estimationOptions.contains(em)) {
          setState(() => _selectedEstimationMethod = em);
        }
      }
      for (final entry in parsed.entries) {
        if (_controllers.containsKey(entry.key)) {
          _controllers[entry.key]?.text = entry.value;
          _recordFieldHistory(entry.key, entry.value, isAi: true);
        }
      }
      _performSave();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI generation failed: ${e.toString()}')),
        );
      }
    }
    if (mounted) setState(() => _isGenerating = false);
  }

  Map<String, String> _parseAIResult(String text) {
    try {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start == -1 || end == -1) return {};
      final jsonStr = text.substring(start, end + 1);
      final Map<String, dynamic> parsed =
          Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
      return parsed.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      return {};
    }
  }

  void _recordFieldHistory(String key, String value, {bool isAi = false}) {
    final history = _fieldHistories.putIfAbsent(key, () => []);
    final index = _fieldHistoryIndices.putIfAbsent(key, () => -1);
    if (index < history.length - 1) {
      history.removeRange(index + 1, history.length);
    }
    if (history.isEmpty || history.last != value) {
      history.add(value);
      _fieldHistoryIndices[key] = history.length - 1;
    }
    if (isAi) _fieldIsAiGenerated[key] = true;
  }

  bool _canUndoField(String key) {
    final idx = _fieldHistoryIndices[key] ?? -1;
    return idx > 0;
  }

  bool _canRedoField(String key) {
    final idx = _fieldHistoryIndices[key] ?? -1;
    final history = _fieldHistories[key] ?? [];
    return idx >= 0 && idx < history.length - 1;
  }

  void _undoField(String key) {
    if (!_canUndoField(key)) return;
    final history = _fieldHistories[key]!;
    final idx = _fieldHistoryIndices[key]!;
    final newIdx = idx - 1;
    _fieldHistoryIndices[key] = newIdx;
    _controllers[key]?.text = history[newIdx];
    _scheduleAutoSave();
  }

  void _redoField(String key) {
    if (!_canRedoField(key)) return;
    final history = _fieldHistories[key]!;
    final idx = _fieldHistoryIndices[key]!;
    final newIdx = idx + 1;
    _fieldHistoryIndices[key] = newIdx;
    _controllers[key]?.text = history[newIdx];
    _scheduleAutoSave();
  }

  Future<void> _regenerateField(String key, String label, String hint) async {
    setState(() => _fieldIsRegenerating[key] = true);
    try {
      final data = ProjectDataHelper.getData(context);
      final contextText =
          ProjectDataHelper.buildProjectContextScan(data, sectionLabel: label);
      final currentValue = _controllers[key]?.text ?? '';
      final openai = OpenAiServiceSecure();
      final result = await openai.generateCompletion(
        'Based on this project context, regenerate the "$label" section.\n\n'
        'Context:\n$contextText\n\n'
        'Current value:\n${currentValue.isEmpty ? "(empty)" : currentValue}\n\n'
        'Hint: $hint\n\n'
        'Provide 2-3 sentences of specific, actionable recommendations for this section. '
        'Return ONLY the text content (no JSON, no markdown headers).',
        maxTokens: 300,
        temperature: 0.6,
      );
      final cleaned = result.trim();
      if (cleaned.isNotEmpty) {
        _controllers[key]?.text = cleaned;
        _recordFieldHistory(key, cleaned, isAi: true);
        _scheduleAutoSave();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI regeneration failed: $e')),
        );
      }
    }
    if (mounted) setState(() => _fieldIsRegenerating[key] = false);
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
                  activeItemLabel: 'Agile Delivery Model - Delivery Model'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                        activeItemLabel:
                            'Agile Delivery Model - Delivery Model'),
                  ),
                  SingleChildScrollView(
                    padding:
                        EdgeInsets.symmetric(horizontal: hp, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlanningPhaseHeader(
                          title: 'Agile Delivery Model',
                          onBack: () =>
                              PlanningPhaseNavigation.goToPrevious(
                                  context, 'agile_delivery_model'),
                          onForward: () =>
                              PlanningPhaseNavigation.goToNext(
                                  context, 'agile_delivery_model'),
                          onExportPdf: _exportPdf,
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Define the agile delivery approach for this project.',
                                style: TextStyle(
                                    fontSize: 15, color: _kMuted),
                              ),
                            ),
                            if (!_isLoading) ...[
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: _isGenerating
                                    ? null
                                    : _generateWithAI,
                                icon: _isGenerating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2))
                                    : const Icon(Icons.auto_awesome,
                                        size: 18),
                                label: Text(_isGenerating
                                    ? 'Generating...'
                                    : 'AI Generate'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _kAccent,
                                  side: const BorderSide(color: _kAccent),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          if (_isSaving)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                  const SizedBox(width: 8),
                                  Text('Saving...',
                                      style: TextStyle(
                                          fontSize: 12, color: _kMuted)),
                                ],
                              ),
                            ),
                          _buildFrameworkSelector(),
                          const SizedBox(height: 20),
                          if (_selectedFramework != 'Kanban')
                            _buildSprintLengthSelector(),
                          if (_selectedFramework != 'Kanban')
                            const SizedBox(height: 20),
                          _buildEstimationSelector(),
                          const SizedBox(height: 24),
                          ..._fields.map((f) => _buildField(f)),
                        ],
                        const SizedBox(height: 24),
                        LaunchPhaseNavigation(
                          backLabel: PlanningPhaseNavigation.backLabel(
                              'agile_delivery_model'),
                          nextLabel: PlanningPhaseNavigation.nextLabel(
                              'agile_delivery_model'),
                          onBack: () =>
                              PlanningPhaseNavigation.goToPrevious(
                                  context, 'agile_delivery_model'),
                          onNext: () =>
                              PlanningPhaseNavigation.goToNext(
                                  context, 'agile_delivery_model'),
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

  Widget _buildFrameworkSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Delivery Framework',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kHeadline)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: _frameworkOptions
              .map((f) => ButtonSegment(value: f, label: Text(f)))
              .toList(),
          selected: {_selectedFramework},
          onSelectionChanged: (v) {
            setState(() => _selectedFramework = v.first);
            _scheduleAutoSave();
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _frameworkDescription(_selectedFramework),
          style: const TextStyle(fontSize: 12, color: _kMuted),
        ),
      ],
    );
  }

  String _frameworkDescription(String fw) {
    switch (fw) {
      case 'Scrum':
        return 'Time-boxed sprints with defined roles. Best for teams with clear requirements that can be planned in iterations.';
      case 'Kanban':
        return 'Continuous flow with WIP limits. Best for teams with variable priority or ongoing operational work.';
      case 'ScrumBan':
        return 'Hybrid: sprint cadence with Kanban flow. Best for teams needing structure but with unpredictable work items.';
      default:
        return '';
    }
  }

  Widget _buildSprintLengthSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sprint Length',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kHeadline)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: _sprintLengthOptions
              .map((s) => ButtonSegment(value: s, label: Text(s)))
              .toList(),
          selected: {_selectedSprintLength},
          onSelectionChanged: (v) {
            setState(() => _selectedSprintLength = v.first);
            _scheduleAutoSave();
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildEstimationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Estimation Method',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kHeadline)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _estimationOptions.contains(_selectedEstimationMethod)
              ? _selectedEstimationMethod
              : _estimationOptions[0],
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: _estimationOptions
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _selectedEstimationMethod = v);
              _scheduleAutoSave();
            }
          },
        ),
      ],
    );
  }

  Widget _buildField(_FieldConfig f) {
    final controller = _controllers[f.key];
    final isRegenerating = _fieldIsRegenerating[f.key] ?? false;
    final isAiGenerated = _fieldIsAiGenerated[f.key] ?? false;
    final hasContent = (controller?.text ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(f.label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kHeadline)),
              if (isAiGenerated)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 10, color: Color(0xFF0284C7)),
                      SizedBox(width: 3),
                      Text('AI',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7))),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 6),
          HoverableFieldControls(
            isAiGenerated: isAiGenerated,
            isLoading: isRegenerating,
            canUndo: _canUndoField(f.key),
            canRedo: _canRedoField(f.key),
            onUndo: () => _undoField(f.key),
            onRedo: () => _redoField(f.key),
            onRegenerate: () => _regenerateField(f.key, f.label, f.hint),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                minHeight: f.fullWidth ? 100 : 80,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: VoiceTextField(
                controller: controller,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF1F2937)),
                decoration: InputDecoration(
                  hintText: f.hint,
                  hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.all(14),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'KAZ AI',
                        icon: isRegenerating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.auto_awesome,
                                color: Color(0xFFF59E0B), size: 18),
                        onPressed: isRegenerating
                            ? null
                            : () => _regenerateField(
                                f.key, f.label, f.hint),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      ),
                      if (hasContent)
                        IconButton(
                          tooltip: 'Clear all content',
                          icon: const Icon(Icons.delete_sweep,
                              color: Color(0xFFEF4444), size: 18),
                          onPressed: () {
                            controller?.clear();
                            _recordFieldHistory(f.key, '');
                            _scheduleAutoSave();
                            setState(() {});
                          },
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                        ),
                    ],
                  ),
                ),
                minLines: f.fullWidth ? 4 : 3,
                maxLines: f.fullWidth ? 8 : 6,
                onChanged: (value) {
                  _recordFieldHistory(f.key, value);
                  _scheduleAutoSave();
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Agile Delivery Model',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
          {'Solution Title': projectData.solutionTitle ?? 'N/A'},
        ]),
        PdfSection.text('Notes',
            projectData.planningNotes[
                    'planning_agile_delivery_model_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}

class _FieldConfig {
  final String key;
  final String label;
  final String hint;
  final bool fullWidth;
  const _FieldConfig({
    required this.key,
    required this.label,
    required this.hint,
    this.fullWidth = false,
  });
}
