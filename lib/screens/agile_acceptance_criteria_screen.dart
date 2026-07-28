import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ndu_project/models/acceptance_criteria.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/ac_confidence_score.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
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

class AgileAcceptanceCriteriaScreen extends StatefulWidget {
  const AgileAcceptanceCriteriaScreen({super.key});

  @override
  State<AgileAcceptanceCriteriaScreen> createState() =>
      _AgileAcceptanceCriteriaScreenState();
}

class _AgileAcceptanceCriteriaScreenState
    extends State<AgileAcceptanceCriteriaScreen> {
  AcceptanceCriteriaConfig _config = AcceptanceCriteriaConfig();
  String? _selectedTemplateId;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGenerating = false;
  Timer? _autoSaveDebounce;

  // Per-template detail fields for the selected template
  final TextEditingController _templateNameCtrl = TextEditingController();
  final TextEditingController _templateDescCtrl = TextEditingController();
  WorkItemType _selectedWorkItemType = WorkItemType.userStory;
  AcFormat _selectedFormat = AcFormat.checklist;

  // Controllers for criteria editing
  final Map<String, TextEditingController> _criterionCtrls = {};
  final Map<String, TextEditingController> _chipCtrls = {};

  String? get _projectId {
    try {
      return ProjectDataInherited.maybeOf(context)?.projectData.projectId;
    } catch (e) {
      return null;
    }
  }

  List<AcceptanceCriteriaTemplate> get _templates => _config.templates;
  List<AcceptanceCriteriaTemplate> get _filteredTemplates {
    return _templates.where((t) => t.workItemType == _selectedWorkItemType).toList();
  }

  AcceptanceCriteriaTemplate? get _selectedTemplate {
    if (_selectedTemplateId == null) return null;
    try {
      return _templates.firstWhere((t) => t.id == _selectedTemplateId);
    } catch (_) {
      return null;
    }
  }

  set _selectedTemplate(AcceptanceCriteriaTemplate? t) {
    setState(() {
      _selectedTemplateId = t?.id;
      if (t != null) {
        _templateNameCtrl.text = t.name;
        _templateDescCtrl.text = t.description;
        _selectedWorkItemType = t.workItemType;
        _selectedFormat = t.format;
      } else {
        _templateNameCtrl.clear();
        _templateDescCtrl.clear();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _templateNameCtrl.dispose();
    _templateDescCtrl.dispose();
    for (final c in _criterionCtrls.values) {
      c.dispose();
    }
    for (final c in _chipCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isLoading = true);
    try {
      final config = await AgileWireframeService.loadAcceptanceCriteria(pid);
      if (!mounted) return;
      setState(() {
        _config = config;
        if (_selectedTemplateId == null && _templates.isNotEmpty) {
          final first = _templates.first;
          _selectedTemplateId = first.id;
          _selectedWorkItemType = first.workItemType;
          _templateNameCtrl.text = first.name;
          _templateDescCtrl.text = first.description;
          _selectedFormat = first.format;
        }
        _isLoading = false;
      });
      if (_templates.isEmpty && !_isGenerating) {
        _generateDefaultTemplates();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 500), () => _performSave());
  }

  Future<void> _performSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await AgileWireframeService.saveAcceptanceCriteria(
        projectId: _projectId!,
        config: _config,
      );
    } catch (e) {
      debugPrint('Error saving AC: $e');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  void _syncSelectedTemplate() {
    final t = _selectedTemplate;
    if (t == null) return;
    t.name = _templateNameCtrl.text;
    t.description = _templateDescCtrl.text;
    t.workItemType = _selectedWorkItemType;
    t.format = _selectedFormat;
    _scheduleAutoSave();
  }

  void _addTemplate() {
    final template = AcceptanceCriteriaTemplate(
      name: 'New ${_selectedWorkItemType.label} Template',
      workItemType: _selectedWorkItemType,
      criteria: [
        AcceptanceCriterion(
          description: '',
          category: CriterionCategory.functional,
        ),
        AcceptanceCriterion(
          description: '',
          category: CriterionCategory.nonFunctional,
        ),
      ],
    );
    setState(() {
      _config.templates.add(template);
      _selectedTemplate = template;
    });
    _scheduleAutoSave();
  }

  Future<void> _deleteTemplate() async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Template',
      itemLabel: _selectedTemplate?.name,
    );
    if (!confirmed) return;
    final t = _selectedTemplate;
    if (t == null) return;
    final idx = _templates.indexWhere((x) => x.id == t.id);
    setState(() {
      _config.templates.removeAt(idx);
      if (_templates.isNotEmpty) {
        final next = idx < _templates.length ? _templates[idx] : _templates.last;
        _selectedTemplate = next;
      } else {
        _selectedTemplate = null;
      }
    });
    _scheduleAutoSave();
  }

  void _addCriterion() {
    final t = _selectedTemplate;
    if (t == null) return;
    setState(() {
      t.criteria.add(AcceptanceCriterion(
        category: CriterionCategory.functional,
      ));
    });
    _scheduleAutoSave();
  }

  Future<void> _deleteCriterion(int index) async {
    final t = _selectedTemplate;
    if (t == null || index >= t.criteria.length) return;
    final c = t.criteria[index];
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Criterion',
      itemLabel: c.description.isNotEmpty ? c.description : null,
    );
    if (!confirmed) return;
    _criterionCtrls.remove(c.id);
    setState(() {
      t.criteria.removeAt(index);
    });
    _scheduleAutoSave();
  }

  TextEditingController _ctrlForCriterion(AcceptanceCriterion c) {
    if (!_criterionCtrls.containsKey(c.id)) {
      _criterionCtrls[c.id] = TextEditingController(text: c.description);
      _criterionCtrls[c.id]!.addListener(() {
        c.description = _criterionCtrls[c.id]!.text;
      });
    }
    return _criterionCtrls[c.id]!;
  }

  Future<void> _generateDefaultTemplates() async {
    setState(() => _isGenerating = true);
    try {
      final pid = _projectId;
      if (pid == null) return;
      final projectData = ProjectDataHelper.getData(context);
      final contextText = ProjectDataHelper.buildProjectContextScan(
        projectData,
        sectionLabel: 'Acceptance Criteria Templates',
      );
      final openai = OpenAiServiceSecure();
      final result = await openai.generateCompletion(
        'Based on this project context, suggest 3-5 acceptance criteria templates.\n\n'
        'Context:\n$contextText\n\n'
        'For each template provide: name, description, workItemType (one of: epic, feature, userStory), '
        'and 3-6 criteria with description and category (one of: businessObjective, functional, nonFunctional, '
        'security, performance, ux, compliance, accessibility, errorHandling, reporting, approval, documentation).\n\n'
        'Return ONLY valid JSON array of objects with keys: name, description, workItemType, '
        'criteria (array of {description, category}).',
        maxTokens: 1500,
        temperature: 0.5,
      );
      final parsed = _parseTemplates(result);
      if (parsed.isNotEmpty && mounted) {
        setState(() => _config.templates = parsed);
        if (_templates.isNotEmpty) {
          _selectedTemplate = _templates.first;
        }
        _performSave();
      }
    } catch (e) {
      debugPrint('AI template generation error: $e');
    }
    if (mounted) setState(() => _isGenerating = false);
  }

  List<AcceptanceCriteriaTemplate> _parseTemplates(String text) {
    try {
      final start = text.indexOf('[');
      final end = text.lastIndexOf(']');
      if (start == -1 || end == -1) return [];
      final jsonStr = text.substring(start, end + 1);
      final list = jsonDecode(jsonStr) as List;
      return list.map<AcceptanceCriteriaTemplate>((e) {
        final m = e as Map<String, dynamic>;
        final rawCriteria = m['criteria'] as List? ?? [];
        return AcceptanceCriteriaTemplate(
          name: (m['name'] ?? '').toString(),
          description: (m['description'] ?? '').toString(),
          workItemType: WorkItemType.fromString(
              (m['workItemType'] ?? 'userStory').toString()),
          criteria: rawCriteria.map<AcceptanceCriterion>((c) {
            final cm = c as Map<String, dynamic>;
            return AcceptanceCriterion(
              description: (cm['description'] ?? '').toString(),
              category: CriterionCategory.fromString(
                  (cm['category'] ?? 'functional').toString()),
            );
          }).toList(),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _generateAcFromContext() async {
    final t = _selectedTemplate;
    if (t == null) return;
    setState(() => _isGenerating = true);
    try {
      final projectData = ProjectDataHelper.getData(context);
      final contextText = ProjectDataHelper.buildProjectContextScan(
        projectData,
        sectionLabel: 'Acceptance Criteria: ${t.name}',
      );
      final openai = OpenAiServiceSecure();
      final result = await openai.generateCompletion(
        'Based on this project context, suggest acceptance criteria for "${t.name}".\n\n'
        'Context:\n$contextText\n\n'
        'Return ONLY a valid JSON array of objects with keys: description, category '
        '(one of: businessObjective, functional, nonFunctional, security, performance, '
        'ux, compliance, accessibility, errorHandling, reporting, approval, documentation).\n\n'
        'Provide 4-8 specific, measurable criteria.',
        maxTokens: 1000,
        temperature: 0.5,
      );
      final parsed = _parseCriteria(result);
      if (parsed.isNotEmpty && mounted) {
        setState(() => t.criteria = parsed);
        _scheduleAutoSave();
      }
    } catch (e) {
      debugPrint('AI AC generation error: $e');
    }
    if (mounted) setState(() => _isGenerating = false);
  }

  List<AcceptanceCriterion> _parseCriteria(String text) {
    try {
      final start = text.indexOf('[');
      final end = text.lastIndexOf(']');
      if (start == -1 || end == -1) return [];
      final jsonStr = text.substring(start, end + 1);
      final list = jsonDecode(jsonStr) as List;
      return list.map<AcceptanceCriterion>((e) {
        final m = e as Map<String, dynamic>;
        return AcceptanceCriterion(
          description: (m['description'] ?? '').toString(),
          category: CriterionCategory.fromString(
              (m['category'] ?? 'functional').toString()),
        );
      }).toList();
    } catch (e) {
      return [];
    }
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
                    'Agile Delivery Model - Acceptance Criteria Planning',
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                      activeItemLabel:
                          'Agile Delivery Model - Acceptance Criteria Planning',
                    ),
                  ),
                  SingleChildScrollView(
                    padding:
                        EdgeInsets.symmetric(horizontal: hp, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlanningPhaseHeader(
                          title: 'Acceptance Criteria Planning',
                          onBack: () =>
                              PlanningPhaseNavigation.goToPrevious(
                                  context, 'agile_acceptance_criteria'),
                          onForward: () =>
                              PlanningPhaseNavigation.goToNext(
                                  context, 'agile_acceptance_criteria'),
                          onExportPdf: _exportPdf,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Define acceptance criteria templates, configure criteria per work item type, and score readiness for execution.',
                          style:
                              TextStyle(fontSize: 15, color: _kMuted),
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
                          _buildWorkItemTypeSelector(),
                          const SizedBox(height: 16),
                          _buildTemplateList(),
                          const SizedBox(height: 16),
                          if (_selectedTemplate != null) ...[
                            _buildTemplateEditor(),
                            const SizedBox(height: 16),
                            _buildFormatSelector(),
                            const SizedBox(height: 16),
                            _buildCriteriaList(),
                            const SizedBox(height: 16),
                            _buildConfidenceCard(),
                          ],
                        ],
                        const SizedBox(height: 24),
                        LaunchPhaseNavigation(
                          backLabel: PlanningPhaseNavigation.backLabel(
                              'agile_acceptance_criteria'),
                          nextLabel: PlanningPhaseNavigation.nextLabel(
                              'agile_acceptance_criteria'),
                          onBack: () =>
                              PlanningPhaseNavigation.goToPrevious(
                                  context, 'agile_acceptance_criteria'),
                          onNext: () =>
                              PlanningPhaseNavigation.goToNext(
                                  context, 'agile_acceptance_criteria'),
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

  Widget _buildWorkItemTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Work Item Type',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kHeadline)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: WorkItemType.values.map((type) {
              final selected = type == _selectedWorkItemType;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(type.label,
                      style: TextStyle(
                          fontSize: 12,
                          color: selected ? Colors.white : _kHeadline)),
                  selected: selected,
                  selectedColor: _kAccent,
                  onSelected: (v) {
                    setState(() => _selectedWorkItemType = type);
                    _syncSelectedTemplate();
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateList() {
    final filtered = _filteredTemplates;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                const Text('Templates',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kHeadline)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _isGenerating ? null : _generateDefaultTemplates,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 14),
                  label: Text(_isGenerating ? '...' : 'AI',
                      style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kAccent,
                    side: const BorderSide(color: _kAccent),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _addTemplate,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No templates for this work item type.',
                    style: TextStyle(color: _kMuted, fontSize: 13)),
              ),
            )
          else
            ...filtered.map((t) => _buildTemplateTile(t)),
        ],
      ),
    );
  }

  Widget _buildTemplateTile(AcceptanceCriteriaTemplate t) {
    final selected = t.id == _selectedTemplateId;
    return InkWell(
      onTap: () => setState(() {
        _selectedTemplate = t;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _kAccent.withOpacity(0.06)
              : Colors.transparent,
          border: Border(
            top: BorderSide(color: _kBorder, width: 0.5),
            left: BorderSide(
              color: selected ? _kAccent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.name.isNotEmpty ? t.name : 'Untitled Template',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kHeadline),
                  ),
                  if (t.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(t.description,
                          style: const TextStyle(
                              fontSize: 11, color: _kMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AcConfidenceScore(template: t, compact: true),
            const SizedBox(width: 8),
            Text('${t.criteria.length}',
                style: const TextStyle(
                    fontSize: 11, color: _kMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateEditor() {
    final t = _selectedTemplate;
    if (t == null) return const SizedBox.shrink();
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
              const Text('Template Details',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.red),
                onPressed: _deleteTemplate,
                tooltip: 'Delete template',
                constraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          VoiceTextField(
            controller: _templateNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Template Name',
              hintText: 'e.g. Standard User Story AC',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _syncSelectedTemplate(),
          ),
          const SizedBox(height: 12),
          VoiceTextField(
            controller: _templateDescCtrl,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'When to use this template',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
            onChanged: (_) => _syncSelectedTemplate(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isGenerating
                    ? null
                    : _generateAcFromContext,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(_isGenerating
                    ? 'Generating...'
                    : 'AI Generate Criteria'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kAccent,
                  side: const BorderSide(color: _kAccent),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _addCriterion,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Criterion'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Row(
      children: [
        const Text('Format: ',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kHeadline)),
        const SizedBox(width: 8),
        ...AcFormat.values.map((fmt) {
          final selected = fmt == _selectedFormat;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(fmt.label,
                  style: TextStyle(
                      fontSize: 11,
                      color: selected ? Colors.white : _kHeadline)),
              selected: selected,
              selectedColor: _kAccent,
              onSelected: (v) {
                setState(() => _selectedFormat = fmt);
                _syncSelectedTemplate();
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCriteriaList() {
    final t = _selectedTemplate;
    if (t == null) return const SizedBox.shrink();
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
              const Text('Criteria',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const SizedBox(width: 8),
              Text('${t.criteria.length} items',
                  style: const TextStyle(
                      fontSize: 12, color: _kMuted)),
            ],
          ),
          const SizedBox(height: 12),
          if (t.criteria.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No criteria defined.',
                    style: TextStyle(color: _kMuted, fontSize: 13)),
              ),
            )
          else
            ...t.criteria.asMap().entries.map(
                (e) => _buildCriterionRow(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildCriterionRow(int index, AcceptanceCriterion c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<CriterionCategory>(
                    value: c.category,
                    decoration: const InputDecoration(
                      hintText: 'Category',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                    items: CriterionCategory.values
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat.label,
                                  style: const TextStyle(fontSize: 11)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => c.category = v);
                        _scheduleAutoSave();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: Row(
                    children: [
                      Checkbox(
                        value: c.isRequired,
                        onChanged: (v) {
                          setState(() => c.isRequired = v ?? true);
                          _scheduleAutoSave();
                        },
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('Req',
                          style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.red),
                  onPressed: () => _deleteCriterion(index),
                  constraints: const BoxConstraints(
                      minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            VoiceTextField(
              controller: _ctrlForCriterion(c),
              decoration: InputDecoration(
                hintText: 'Describe the acceptance criterion...',
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                suffixIcon: c.description.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.delete_sweep,
                            color: Color(0xFFEF4444), size: 16),
                        onPressed: () {
                          _criterionCtrls[c.id]?.clear();
                          _scheduleAutoSave();
                          setState(() {});
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 28, minHeight: 28),
                      )
                    : null,
              ),
              minLines: 1,
              maxLines: 3,
              onChanged: (_) => _scheduleAutoSave(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceCard() {
    final t = _selectedTemplate;
    if (t == null) return const SizedBox.shrink();
    return AcConfidenceScore(template: t);
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Acceptance Criteria Planning',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName ?? 'N/A'},
          {'Solution Title': projectData.solutionTitle ?? 'N/A'},
        ]),
        PdfSection.text('Notes',
            projectData.planningNotes[
                    'planning_agile_acceptance_criteria_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}
