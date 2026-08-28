import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ndu_project/providers/project_data_provider.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';
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
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';

const Color _kBackground = Colors.white;
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kMuted = Color(0xFF6B7280);
const Color _kHeadline = Color(0xFF111827);

const List<String> _defaultColumns = [
  'Backlog',
  'Ready',
  'In Progress',
  'Code Review',
  'Testing',
  'Ready for Release',
  'Done',
];

const List<String> _cosOptions = [
  'Standard',
  'Expedite',
  'Fixed Date',
  'Intangible',
];

/// Monotonic unique-id source for serialized Kanban rows. The previous
/// fallback (`DateTime.now().microsecondsSinceEpoch`) produced IDENTICAL ids
/// when several rows were constructed inside the same microsecond, which
/// broke keyed rebuilds and blanked the page on rebuild.
int _kanbanRowIdCounter = 0;
String _nextKanbanRowId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_kanbanRowIdCounter++}';

class _KanbanColumn {
  String id;
  String name;
  int wipLimit;
  String entryCriteria;
  String exitCriteria;

  _KanbanColumn({
    String? id,
    this.name = '',
    this.wipLimit = 0,
    this.entryCriteria = '',
    this.exitCriteria = '',
  }) : id = id ?? _nextKanbanRowId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'wipLimit': wipLimit,
        'entryCriteria': entryCriteria,
        'exitCriteria': exitCriteria,
      };

  factory _KanbanColumn.fromJson(Map<String, dynamic> json) {
    return _KanbanColumn(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      wipLimit: (json['wipLimit'] as num?)?.toInt() ?? 0,
      entryCriteria: json['entryCriteria']?.toString() ?? '',
      exitCriteria: json['exitCriteria']?.toString() ?? '',
    );
  }
}

class _ClassOfService {
  String id;
  String name;
  int slaHours;
  String description;

  _ClassOfService({
    String? id,
    this.name = 'Standard',
    this.slaHours = 24,
    this.description = '',
  }) : id = id ?? _nextKanbanRowId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slaHours': slaHours,
        'description': description,
      };

  factory _ClassOfService.fromJson(Map<String, dynamic> json) {
    return _ClassOfService(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? 'Standard',
      slaHours: (json['slaHours'] as num?)?.toInt() ?? 24,
      description: json['description']?.toString() ?? '',
    );
  }
}

class AgileKanbanConfigScreen extends StatefulWidget {
  const AgileKanbanConfigScreen({super.key});

  @override
  State<AgileKanbanConfigScreen> createState() =>
      _AgileKanbanConfigScreenState();
}

class _AgileKanbanConfigScreenState extends State<AgileKanbanConfigScreen> {
  List<_KanbanColumn> _columns = [];
  List<_ClassOfService> _cosList = [];
  int _nextSprintReviewDays = 7;
  bool _enableSwimlanes = true;
  bool _isLoading = true;
  bool _isSaving = false;
  Timer? _autoSaveDebounce;

  // Controller for notes
  final TextEditingController _notesCtrl = TextEditingController();

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
    if (pid == null) {
      // No project context — show defaults instead of spinning forever.
      _applyDefaultConfig();
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Timeout guard: a stalled Firestore get() must never leave the
      // configuration page stuck on the loading spinner.
      final data = await AgileWireframeService.loadKanbanConfig(pid).timeout(
        const Duration(seconds: 12),
        onTimeout: () => <String, dynamic>{},
      );
      if (!mounted) return;
      final rawCols = data['columns'] as List?;
      if (rawCols != null && rawCols.isNotEmpty) {
        _columns = rawCols
            .map((e) => _KanbanColumn.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _applyDefaultConfig();
      }
      final rawCos = data['classesOfService'] as List?;
      if (rawCos != null && rawCos.isNotEmpty) {
        _cosList = rawCos
            .map((e) => _ClassOfService.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (_cosList.isEmpty) {
        _applyDefaultClassesOfService();
      }
      _nextSprintReviewDays =
          (data['nextSprintReviewDays'] as num?)?.toInt() ?? 7;
      _enableSwimlanes = data['enableSwimlanes'] as bool? ?? true;
      _notesCtrl.text = data['notes'] as String? ?? '';
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Default workflow columns (used when no saved config exists).
  void _applyDefaultConfig() {
    _columns = _defaultColumns
        .map((name) => _KanbanColumn(
              name: name,
              wipLimit: name == 'In Progress' ? 3 : 0,
            ))
        .toList();
    _applyDefaultClassesOfService();
  }

  /// Default classes of service with canonical SLA targets.
  void _applyDefaultClassesOfService() {
    _cosList = _cosOptions.map((name) {
      final sla = switch (name) {
        'Expedite' => 4,
        'Fixed Date' => 48,
        'Intangible' => 72,
        _ => 24,
      };
      return _ClassOfService(name: name, slaHours: sla);
    }).toList();
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
      await AgileWireframeService.saveKanbanConfig(
        projectId: pid,
        data: {
          'columns': _columns.map((c) => c.toJson()).toList(),
          'classesOfService': _cosList.map((c) => c.toJson()).toList(),
          'nextSprintReviewDays': _nextSprintReviewDays,
          'enableSwimlanes': _enableSwimlanes,
          'notes': _notesCtrl.text,
        },
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
                          _buildBoardSection(),
                          const SizedBox(height: 24),
                          _buildClassesOfService(),
                          const SizedBox(height: 24),
                          _buildSettingsSection(),
                          const SizedBox(height: 24),
                          _buildNotesSection(),
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

  /// Live Kanban Board — the same existing board widget used by the
  /// Kanban Board screen, driven by the workflow columns from the saved
  /// Kanban configuration.
  Widget _buildBoardSection() {
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
              const Text('Kanban Board',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('LIVE',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB8860B),
                        letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
              'Execution board using the workflow columns from the saved '
              'Kanban configuration. Drag stories between columns, then '
              'Save Board.',
              style: TextStyle(fontSize: 12, color: _kMuted)),
          const SizedBox(height: 16),
          const KanbanBoardPanel(),
        ],
      ),
    );
  }

  Widget _buildClassesOfService() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Classes of Service',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kHeadline)),
          const SizedBox(height: 8),
          const Text(
            'Configure service classes with SLA targets for different work item types.',
            style: TextStyle(fontSize: 13, color: _kMuted),
          ),
          const SizedBox(height: 12),
          ..._cosList.asMap().entries.map((e) => _buildCosRow(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildCosRow(int index, _ClassOfService cos) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: _cosOptions.contains(cos.name) ? cos.name : _cosOptions[0],
              decoration: const InputDecoration(
                labelText: 'Service Class',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              items: _cosOptions
                  .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(o, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => cos.name = v);
                  _scheduleAutoSave();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: VoiceTextField(
              controller: TextEditingController.fromValue(
                TextEditingValue(
                  text: cos.slaHours.toString(),
                  selection: const TextSelection.collapsed(offset: 999),
                ),
              ),
              decoration: const InputDecoration(
                labelText: 'SLA (hrs)',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 12),
              onChanged: (v) {
                cos.slaHours = int.tryParse(v) ?? 24;
                _scheduleAutoSave();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: VoiceTextField(
              controller: TextEditingController.fromValue(
                TextEditingValue(
                  text: cos.description,
                  selection:
                      TextSelection.collapsed(offset: cos.description.length),
                ),
              ),
              decoration: const InputDecoration(
                hintText: 'Description',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              style: const TextStyle(fontSize: 11),
              onChanged: (v) {
                cos.description = v;
                _scheduleAutoSave();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kHeadline)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Enable swimlanes',
                  style: TextStyle(fontSize: 13, color: _kHeadline)),
              const SizedBox(width: 12),
              Switch(
                value: _enableSwimlanes,
                onChanged: (v) {
                  setState(() => _enableSwimlanes = v);
                  _scheduleAutoSave();
                },
              ),
              const SizedBox(width: 24),
              const Text('Sprint review cadence (days)',
                  style: TextStyle(fontSize: 13, color: _kHeadline)),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                // Plain numeric field — no Open Editor button (it
                // overflowed the 100px box by 14px).
                child: TextField(
                  controller: TextEditingController.fromValue(
                    TextEditingValue(
                      text: _nextSprintReviewDays.toString(),
                      selection: const TextSelection.collapsed(offset: 999),
                    ),
                  ),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 12),
                  onChanged: (v) {
                    _nextSprintReviewDays = int.tryParse(v) ?? 7;
                    _scheduleAutoSave();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Additional Notes',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: _kHeadline)),
        const SizedBox(height: 8),
        VoiceTextField(
          controller: _notesCtrl,
          decoration: const InputDecoration(
            hintText: 'Flow policies, pull rules, SLA enforcement notes...',
            border: OutlineInputBorder(),
          ),
          minLines: 3,
          maxLines: 6,
          onChanged: (_) => _scheduleAutoSave(),
        ),
      ],
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
        PdfSection.text(
            'Notes',
            projectData.planningNotes['planning_agile_kanban_config_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}
