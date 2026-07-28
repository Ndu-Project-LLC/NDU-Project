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
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

const Color _kBackground = Colors.white;
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);
const Color _kAccent = Color(0xFFD97706);

const List<String> _defaultDoRItems = [
  'Story written and described',
  'Acceptance criteria defined',
  'Dependencies identified',
  'Designs/UX available (if applicable)',
  'Business approval obtained',
  'Estimated (story points or size)',
  'Test approach identified',
  'Edge cases documented',
];

const List<String> _defaultDoDItems = [
  'Code complete',
  'Peer reviewed',
  'Unit tests pass',
  'Integration tests pass',
  'Acceptance criteria met',
  'Documentation updated',
  'Deployed to staging',
  'Product Owner approved',
];

const List<String> _defaultWorkingAgreements = [
  'Core hours: 9am-3pm team overlap',
  'Daily standup at 9:15am (15 min max)',
  'Slack for async communication, email for formal',
  'Code reviews within 24 hours',
  'Documentation in project wiki',
  'Meetings start on time, end on time',
  'No meeting Wednesdays (focus time)',
];

class _ChecklistItem {
  final String id;
  String label;
  bool checked;
  _ChecklistItem({
    String? id,
    this.label = '',
    this.checked = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
}

class AgileBacklogGovernanceScreen extends StatefulWidget {
  const AgileBacklogGovernanceScreen({super.key});

  @override
  State<AgileBacklogGovernanceScreen> createState() =>
      _AgileBacklogGovernanceScreenState();
}

class _AgileBacklogGovernanceScreenState
    extends State<AgileBacklogGovernanceScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<String>> _fieldHistories = {};
  final Map<String, int> _fieldHistoryIndices = {};
  final Map<String, bool> _fieldIsAiGenerated = {};
  final Map<String, bool> _fieldIsRegenerating = {};

  List<_ChecklistItem> _doRItems = [];
  List<_ChecklistItem> _doDItems = [];
  List<_ChecklistItem> _waItems = [];

  bool _showDoRChecklist = false;
  bool _showDoDChecklist = false;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGenerating = false;
  Timer? _autoSaveDebounce;

  static const List<_FieldConfig> _fields = [
    _FieldConfig(
      key: 'prioritization_framework',
      label: 'Prioritization Framework',
      hint:
          'How backlog items are prioritized. e.g. MoSCoW (Must/Should/Could/Won\'t), WSJF, RICE, or custom approach.',
    ),
    _FieldConfig(
      key: 'refinement_cadence',
      label: 'Refinement Cadence',
      hint:
          'How often backlog refinement occurs. e.g. Weekly 1-hour session mid-sprint, or continuous async refinement.',
    ),
    _FieldConfig(
      key: 'estimation_framework',
      label: 'Estimation Framework',
      hint:
          'How effort is estimated. e.g. Story points (Fibonacci 1,2,3,5,8,13), T-shirt sizes (S/M/L/XL), or Ideal hours.',
    ),
    _FieldConfig(
      key: 'ownership',
      label: 'Backlog Ownership',
      hint:
          'Who owns the backlog. e.g. Product Owner owns prioritization, Tech Lead owns technical refinement, Team owns estimation.',
    ),
    _FieldConfig(
      key: 'grooming_rules',
      label: 'Grooming Rules & Policies',
      hint:
          'Rules for backlog hygiene. e.g. Max age of items, WIP limits, splitting rules, stale item policy.',
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

  List<Map<String, dynamic>> _checklistToJson(List<_ChecklistItem> items) {
    return items.map((i) => {'id': i.id, 'label': i.label, 'checked': i.checked}).toList();
  }

  List<_ChecklistItem> _checklistFromJson(List? raw) {
    if (raw == null) return [];
    return raw.map((e) {
      final m = e as Map<String, dynamic>;
      return _ChecklistItem(
        id: m['id']?.toString(),
        label: m['label']?.toString() ?? '',
        checked: m['checked'] == true,
      );
    }).toList();
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await AgileWireframeService.loadBacklogGovernance(pid);
      if (!mounted) return;
      final hasContent = data.values.any((v) => v is String && v.trim().isNotEmpty);
      if (!hasContent) {
        final dm = await AgileWireframeService.loadDeliveryModel(pid);
        final backlogText = dm['backlog'] as String? ?? '';
        if (backlogText.isNotEmpty) {
          for (final f in _fields) {
            final val = data[f.key];
            if (val == null || (val is String && val.isEmpty)) {
              _controllers[f.key]?.text = backlogText;
              _recordFieldHistory(f.key, backlogText);
            }
          }
        }
      } else {
        for (final f in _fields) {
          final value = data[f.key] as String? ?? '';
          _controllers[f.key]?.text = value;
          if (value.isNotEmpty) {
            _recordFieldHistory(f.key, value);
          }
        }
      }
      setState(() {
        _doRItems = _checklistFromJson(data['dor_checklist'] as List?);
        _doDItems = _checklistFromJson(data['dod_checklist'] as List?);
        _waItems = _checklistFromJson(data['working_agreements'] as List?);
        if (_doRItems.isEmpty) {
          _doRItems = _defaultDoRItems.map((l) => _ChecklistItem(label: l)).toList();
        }
        if (_doDItems.isEmpty) {
          _doDItems = _defaultDoDItems.map((l) => _ChecklistItem(label: l)).toList();
        }
        if (_waItems.isEmpty) {
          _waItems = _defaultWorkingAgreements.map((l) => _ChecklistItem(label: l)).toList();
        }
        _showDoRChecklist = data['dor_use_checklist'] as bool? ?? false;
        _showDoDChecklist = data['dod_use_checklist'] as bool? ?? false;
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
      data['dor_checklist'] = _checklistToJson(_doRItems);
      data['dod_checklist'] = _checklistToJson(_doDItems);
      data['working_agreements'] = _checklistToJson(_waItems);
      data['dor_use_checklist'] = _showDoRChecklist;
      data['dod_use_checklist'] = _showDoDChecklist;
      await AgileWireframeService.saveBacklogGovernance(
          projectId: pid, data: data);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Saved'), duration: Duration(seconds: 1)),
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
      final projectData = ProjectDataHelper.getData(context);
      final contextText = ProjectDataHelper.buildProjectContextScan(
          projectData, sectionLabel: 'Backlog Governance');
      final openai = OpenAiServiceSecure();
      final result = await openai.generateCompletion(
        'Based on this project context, suggest backlog governance rules.\n\n'
        'Context:\n$contextText\n\n'
        'For each area provide 2-3 sentences:\n'
        '- prioritization_framework\n'
        '- refinement_cadence\n'
        '- estimation_framework\n'
        '- ownership\n'
        '- grooming_rules\n\n'
        'Also suggest 4-6 definition_of_ready items as a JSON array.\n'
        'Also suggest 4-6 definition_of_done items as a JSON array.\n'
        'Also suggest 4-6 working_agreements as a JSON array.\n\n'
        'Return as a JSON object with keys: prioritization_framework, refinement_cadence, '
        'estimation_framework, ownership, grooming_rules, dor_items, dod_items, working_agreements.',
        maxTokens: 1500,
        temperature: 0.5,
      );
      final parsed = _parseAIResult(result);
      for (final entry in parsed.entries) {
        if (_controllers.containsKey(entry.key)) {
          _controllers[entry.key]?.text = entry.value;
          _recordFieldHistory(entry.key, entry.value, isAi: true);
        }
      }
      if (parsed.containsKey('dor_items')) {
        final items = _parseStringList(parsed['dor_items']!);
        if (items.isNotEmpty) {
          setState(() {
            _doRItems =
                items.map((l) => _ChecklistItem(label: l)).toList();
          });
        }
      }
      if (parsed.containsKey('dod_items')) {
        final items = _parseStringList(parsed['dod_items']!);
        if (items.isNotEmpty) {
          setState(() {
            _doDItems =
                items.map((l) => _ChecklistItem(label: l)).toList();
          });
        }
      }
      if (parsed.containsKey('working_agreements')) {
        final items = _parseStringList(parsed['working_agreements']!);
        if (items.isNotEmpty) {
          setState(() {
            _waItems =
                items.map((l) => _ChecklistItem(label: l)).toList();
          });
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

  List<String> _parseStringList(String raw) {
    try {
      final start = raw.indexOf('[');
      final end = raw.lastIndexOf(']');
      if (start == -1 || end == -1) return [];
      final jsonStr = raw.substring(start, end + 1);
      final list = jsonDecode(jsonStr) as List;
      return list.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
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

  bool _canUndoField(String key) => (_fieldHistoryIndices[key] ?? -1) > 0;

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

  Future<void> _regenerateField(
      String key, String label, String hint) async {
    setState(() => _fieldIsRegenerating[key] = true);
    try {
      final data = ProjectDataHelper.getData(context);
      final contextText = ProjectDataHelper.buildProjectContextScan(
          data, sectionLabel: label);
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
                  activeItemLabel:
                      'Agile Delivery Model - Backlog Governance'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                        activeItemLabel:
                            'Agile Delivery Model - Backlog Governance'),
                  ),
                  SingleChildScrollView(
                    padding:
                        EdgeInsets.symmetric(horizontal: hp, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlanningPhaseHeader(
                          title: 'Backlog Governance',
                          onBack: () =>
                              PlanningPhaseNavigation.goToPrevious(
                                  context, 'agile_backlog_governance'),
                          onForward: () =>
                              PlanningPhaseNavigation.goToNext(
                                  context, 'agile_backlog_governance'),
                          onExportPdf: _exportPdf,
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Define the rules, criteria, and processes for managing the product backlog.',
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
                                  side:
                                      const BorderSide(color: _kAccent),
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
                          _buildDoRSection(),
                          const SizedBox(height: 20),
                          _buildDoDSection(),
                          const SizedBox(height: 20),
                          ..._fields.map((f) => _buildField(f)),
                          const SizedBox(height: 20),
                          _buildWorkingAgreementsSection(),
                        ],
                        const SizedBox(height: 24),
                        LaunchPhaseNavigation(
                          backLabel: PlanningPhaseNavigation.backLabel(
                              'agile_backlog_governance'),
                          nextLabel: PlanningPhaseNavigation.nextLabel(
                              'agile_backlog_governance'),
                          onBack: () =>
                              PlanningPhaseNavigation.goToPrevious(
                                  context, 'agile_backlog_governance'),
                          onNext: () =>
                              PlanningPhaseNavigation.goToNext(
                                  context, 'agile_backlog_governance'),
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

  Widget _buildDoRSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Definition of Ready',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              Switch(
                value: _showDoRChecklist,
                onChanged: (v) {
                  setState(() => _showDoRChecklist = v);
                  _scheduleAutoSave();
                },
              ),
              const SizedBox(width: 4),
              const Text('Checklist mode',
                  style: TextStyle(fontSize: 12, color: _kMuted)),
            ],
          ),
          const SizedBox(height: 8),
          if (_showDoRChecklist) ...[
            ..._doRItems.asMap().entries.map((e) => _buildChecklistRow(
                  e.value,
                  (checked) {
                    setState(() => e.value.checked = checked);
                    _scheduleAutoSave();
                  },
                  (label) {
                    setState(() => e.value.label = label);
                    _scheduleAutoSave();
                  },
                  () async {
                    final confirmed = await showDeleteConfirmationDialog(
                      context,
                      title: 'Delete Definition of Ready Item',
                      itemLabel: e.value.label.isNotEmpty ? e.value.label : null,
                    );
                    if (!confirmed) return;
                    setState(() => _doRItems.removeAt(e.key));
                    _scheduleAutoSave();
                  },
                )),
            TextButton.icon(
              onPressed: () {
                setState(() =>
                    _doRItems.add(_ChecklistItem(label: '')));
                _scheduleAutoSave();
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add item'),
            ),
          ] else
            _buildExistingField('definition_of_ready',
                'Criteria a backlog item must meet before it can be pulled into a sprint.'),
        ],
      ),
    );
  }

  Widget _buildDoDSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Definition of Done',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              Switch(
                value: _showDoDChecklist,
                onChanged: (v) {
                  setState(() => _showDoDChecklist = v);
                  _scheduleAutoSave();
                },
              ),
              const SizedBox(width: 4),
              const Text('Checklist mode',
                  style: TextStyle(fontSize: 12, color: _kMuted)),
            ],
          ),
          const SizedBox(height: 8),
          if (_showDoDChecklist) ...[
            ..._doDItems.asMap().entries.map((e) => _buildChecklistRow(
                  e.value,
                  (checked) {
                    setState(() => e.value.checked = checked);
                    _scheduleAutoSave();
                  },
                  (label) {
                    setState(() => e.value.label = label);
                    _scheduleAutoSave();
                  },
                  () async {
                    final confirmed = await showDeleteConfirmationDialog(
                      context,
                      title: 'Delete Definition of Done Item',
                      itemLabel: e.value.label.isNotEmpty ? e.value.label : null,
                    );
                    if (!confirmed) return;
                    setState(() => _doDItems.removeAt(e.key));
                    _scheduleAutoSave();
                  },
                )),
            TextButton.icon(
              onPressed: () {
                setState(() =>
                    _doDItems.add(_ChecklistItem(label: '')));
                _scheduleAutoSave();
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add item'),
            ),
          ] else
            _buildExistingField('definition_of_done',
                'Quality gate criteria for work to be considered complete.'),
        ],
      ),
    );
  }

  Widget _buildChecklistRow(
    _ChecklistItem item,
    ValueChanged<bool> onChecked,
    ValueChanged<String> onLabelChanged,
    Future<void> Function() onDelete,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Checkbox(
            value: item.checked,
            onChanged: (v) => onChecked(v ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Expanded(
            child: VoiceTextField(
              controller: TextEditingController.fromValue(
                TextEditingValue(
                  text: item.label,
                  selection:
                      TextSelection.collapsed(offset: item.label.length),
                ),
              ),
              decoration: const InputDecoration(
                hintText: 'Criteria description',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: onLabelChanged,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 16, color: Colors.red),
            onPressed: () async => onDelete(),
            constraints:
                const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildExistingField(String key, String hint) {
    final controller = _controllers[key];
    final hasContent = (controller?.text ?? '').isNotEmpty;
    return VoiceTextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: hasContent
            ? IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.delete_sweep,
                    color: Color(0xFFEF4444), size: 16),
                onPressed: () {
                  controller?.clear();
                  _recordFieldHistory(key, '');
                  _scheduleAutoSave();
                  setState(() {});
                },
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              )
            : null,
      ),
      minLines: 3,
      maxLines: 5,
      onChanged: (value) {
        _recordFieldHistory(key, value);
        _scheduleAutoSave();
        setState(() {});
      },
    );
  }

  Widget _buildWorkingAgreementsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Working Agreements',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _kHeadline)),
          const SizedBox(height: 4),
          const Text("Team norms for communication, collaboration, and process.",
              style: TextStyle(fontSize: 12, color: _kMuted)),
          const SizedBox(height: 12),
          ..._waItems.asMap().entries.map((e) => _buildChecklistRow(
                e.value,
                (checked) {
                  setState(() => e.value.checked = checked);
                  _scheduleAutoSave();
                },
                (label) {
                  setState(() => e.value.label = label);
                  _scheduleAutoSave();
                },
                () async {
                  final confirmed = await showDeleteConfirmationDialog(
                    context,
                    title: 'Delete Working Agreement',
                    itemLabel: e.value.label.isNotEmpty ? e.value.label : null,
                  );
                  if (!confirmed) return;
                  setState(() => _waItems.removeAt(e.key));
                  _scheduleAutoSave();
                },
              )),
          TextButton.icon(
            onPressed: () {
              setState(() => _waItems.add(_ChecklistItem(label: '')));
              _scheduleAutoSave();
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add agreement'),
          ),
        ],
      ),
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
                    color: const Color(0xFFFFF7E6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 10, color: Color(0xFFD97706)),
                      SizedBox(width: 3),
                      Text('AI',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706))),
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
            onRegenerate: () =>
                _regenerateField(f.key, f.label, f.hint),
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
      screenTitle: 'Agile Backlog Governance',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
          {'Solution Title': projectData.solutionTitle ?? 'N/A'},
        ]),
        PdfSection.text('Notes',
            projectData.planningNotes[
                    'planning_agile_backlog_governance_notes'] ??
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
