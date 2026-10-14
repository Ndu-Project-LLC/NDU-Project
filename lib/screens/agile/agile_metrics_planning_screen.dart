import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/planning_phase_navigation.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/launch_phase_navigation.dart';
import 'package:ndu_project/widgets/planning_phase_header.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/agile_metrics_catalog.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';

const Color _kBackground = Colors.white;
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);
const Color _kAccent = Color(0xFFD97706);

class _MetricGroup {
  final String category;
  final List<_MetricItem> metrics;

  const _MetricGroup({required this.category, required this.metrics});
}

class _MetricItem {
  final String key;
  final String label;
  final String description;
  bool selected;

  _MetricItem({
    required this.key,
    required this.label,
    required this.description,
  }) : selected = false;
}

/// The metric list lives in [AgileMetricsCatalog] so the dashboard reports the
/// same set this page defines, instead of the two drifting apart. Grouped here
/// for display only.
List<_MetricGroup> _catalogGroups() => [
      for (final category in AgileMetricsCatalog.categories)
        _MetricGroup(
          category: category,
          metrics: [
            for (final metric in AgileMetricsCatalog.inCategory(category))
              _MetricItem(
                key: metric.key,
                label: metric.label,
                description: metric.description,
              ),
          ],
        ),
    ];

class AgileMetricsPlanningScreen extends StatefulWidget {
  const AgileMetricsPlanningScreen({super.key});

  @override
  State<AgileMetricsPlanningScreen> createState() =>
      _AgileMetricsPlanningScreenState();
}

class _AgileMetricsPlanningScreenState
    extends State<AgileMetricsPlanningScreen> {
  late List<_MetricGroup> _groups;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGenerating = false;
  Timer? _autoSaveDebounce;
  final TextEditingController _notesCtrl = SpellCheckTextEditingController();

  String? get _projectId {
    try {
      return ProjectDataInherited.maybeOf(context)?.projectData.projectId;
    } catch (e) {
      return null;
    }
  }

  List<_MetricItem> get _allMetrics =>
      _groups.expand((g) => g.metrics).toList();

  int get _selectedCount => _allMetrics.where((m) => m.selected).length;

  @override
  void initState() {
    super.initState();
    _groups = _catalogGroups();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await AgileWireframeService.loadMetricsConfig(pid);
      if (!mounted) return;
      // Pre-select the default tracked set when the project has never chosen,
      // so the dashboard has metrics to report without anyone ticking boxes —
      // the review's "nobody's choosing".
      final selected = (data['selectedMetrics'] as List?)
              ?.map((e) => e.toString().trim())
              .where((key) => key.isNotEmpty)
              .toList() ??
          const <String>[];
      final keys = selected.isEmpty
          ? AgileMetricsCatalog.defaultTrackedKeys
          : selected.toSet();
      for (final m in _allMetrics) {
        m.selected = keys.contains(m.key);
      }
      _notesCtrl.text = data['notes'] as String? ?? '';
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
      final selected =
          _allMetrics.where((m) => m.selected).map((m) => m.key).toList();
      await AgileWireframeService.saveMetricsConfig(
        projectId: pid,
        // Built by the service so the keys Metrics Planning writes are declared
        // in one place and checked against Backlog Governance's.
        data: AgileWireframeService.metricsConfigData(
          selectedMetrics: selected,
          notes: _notesCtrl.text,
        ),
      );
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
    setState(() => _isGenerating = true);
    try {
      final projectData = ProjectDataHelper.getData(context);
      final contextText = ProjectDataHelper.buildProjectContextScan(projectData,
          sectionLabel: 'Agile Metrics');
      final openai = OpenAiServiceSecure();
      final result = await openai.generateCompletion(
        'Based on this project context, recommend which agile metrics to track.\n\n'
        'Context:\n$contextText\n\n'
        'Available metrics keys: velocity, throughput, burndown, burnup, escaped_defects, '
        'defect_density, rework, lead_time, cycle_time, work_item_aging, sprint_predictability, '
        'commitment_reliability, delivery_confidence, value_delivered, feature_adoption, customer_satisfaction.\n\n'
        'Return ONLY a JSON array of the recommended metric keys (e.g. ["velocity","burndown","lead_time"]).',
        maxTokens: 300,
        temperature: 0.5,
      );
      final parsed = _parseAIResult(result);
      if (parsed.isNotEmpty && mounted) {
        for (final m in _allMetrics) {
          m.selected = parsed.contains(m.key);
        }
        setState(() {});
        _performSave();
      }
    } catch (e) {
      debugPrint('AI error: $e');
    }
    if (mounted) setState(() => _isGenerating = false);
  }

  List<String> _parseAIResult(String text) {
    try {
      final start = text.indexOf('[');
      final end = text.lastIndexOf(']');
      if (start == -1 || end == -1) return [];
      final jsonStr = text.substring(start, end + 1);
      final list = jsonDecode(jsonStr) as List;
      return list.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  void _toggleAll(bool selected) {
    setState(() {
      for (final m in _allMetrics) {
        m.selected = selected;
      }
    });
    _scheduleAutoSave();
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
                  activeItemLabel: 'Agile Delivery Model - Metrics Planning'),
            ),
            Expanded(
              child: Stack(
                children: [
                  const MobileSidebarHamburger(
                    sidebar: InitiationLikeSidebar(
                        activeItemLabel:
                            'Agile Delivery Model - Metrics Planning'),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: hp, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlanningPhaseHeader(
                          title: 'Agile Metrics Planning',
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                              context, 'agile_metrics_planning'),
                          onForward: () => PlanningPhaseNavigation.goToNext(
                              context, 'agile_metrics_planning'),
                          onExportPdf: _exportPdf,
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'These are the metrics the execution dashboard reports. '
                                  'A default tracking set is already selected — adjust it '
                                  'and the dashboard follows.',
                                  style: TextStyle(
                                      fontSize: 15, color: _kMuted),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed:
                                    _isGenerating ? null : _generateWithAI,
                                icon: _isGenerating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.auto_awesome, size: 18),
                                label: Text(_isGenerating
                                    ? 'Generating...'
                                    : 'AI Recommend'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _kAccent,
                                  side: const BorderSide(color: _kAccent),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('Additional Notes',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _kHeadline)),
                          const SizedBox(height: 8),
                          VoiceTextField(
                            controller: _notesCtrl,
                            decoration: const InputDecoration(
                              hintText:
                                  'Target values, measurement approach, reporting cadence...',
                              border: OutlineInputBorder(),
                            ),
                            minLines: 3,
                            maxLines: 6,
                            onChanged: (_) => _scheduleAutoSave(),
                          ),
                          const SizedBox(height: 16),
                          if (_isSaving)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                  SizedBox(width: 8),
                                  Text('Saving...',
                                      style: TextStyle(
                                          fontSize: 12, color: _kMuted)),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              Text(
                                  '$_selectedCount / ${_allMetrics.length} selected',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _kHeadline)),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _toggleAll(true),
                                child: const Text('Select All',
                                    style: TextStyle(fontSize: 12)),
                              ),
                              TextButton(
                                onPressed: () => _toggleAll(false),
                                child: const Text('Clear All',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._groups.map((g) => _buildMetricGroup(g)),
                        ],
                        const SizedBox(height: 24),
                        LaunchPhaseNavigation(
                          backLabel: PlanningPhaseNavigation.backLabel(
                              'agile_metrics_planning'),
                          nextLabel: PlanningPhaseNavigation.nextLabel(
                              'agile_metrics_planning'),
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                              context, 'agile_metrics_planning'),
                          onNext: () => PlanningPhaseNavigation.goToNext(
                              context, 'agile_metrics_planning'),
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

  Widget _buildMetricGroup(_MetricGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.category,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kHeadline,
            ),
          ),
          const SizedBox(height: 8),
          ...group.metrics.map((m) => _buildMetricRow(m)),
        ],
      ),
    );
  }

  Widget _buildMetricRow(_MetricItem metric) {
    return InkWell(
      onTap: () {
        setState(() => metric.selected = !metric.selected);
        _scheduleAutoSave();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: metric.selected,
                onChanged: (v) {
                  setState(() => metric.selected = v ?? false);
                  _scheduleAutoSave();
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kHeadline,
                    ),
                  ),
                  Text(
                    metric.description,
                    style: const TextStyle(fontSize: 12, color: _kMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Agile Metrics Planning',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName.isEmpty ? 'N/A' : projectData.projectName},
          {'Solution Title': projectData.solutionTitle.isEmpty ? 'N/A' : projectData.solutionTitle},
        ]),
        PdfSection.text(
            'Notes',
            projectData
                    .planningNotes['planning_agile_metrics_planning_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}
