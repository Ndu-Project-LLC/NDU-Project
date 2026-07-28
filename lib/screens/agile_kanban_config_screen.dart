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
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

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
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

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

  // Controllers for notes
  final TextEditingController _notesCtrl = TextEditingController();
  final Map<String, TextEditingController> _nameCtrls = {};
  final Map<String, TextEditingController> _entryCtrls = {};
  final Map<String, TextEditingController> _exitCtrls = {};

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
    for (final c in _nameCtrls.values) {
      c.dispose();
    }
    for (final c in _entryCtrls.values) {
      c.dispose();
    }
    for (final c in _exitCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await AgileWireframeService.loadKanbanConfig(pid);
      if (!mounted) return;
      final rawCols = data['columns'] as List?;
      if (rawCols != null && rawCols.isNotEmpty) {
        _columns = rawCols
            .map((e) => _KanbanColumn.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _columns = _defaultColumns
            .map((name) => _KanbanColumn(
                  name: name,
                  wipLimit: name == 'In Progress' ? 3 : 0,
                ))
            .toList();
      }
      final rawCos = data['classesOfService'] as List?;
      if (rawCols != null && rawCos != null && rawCos.isNotEmpty) {
        _cosList = rawCos
            .map((e) => _ClassOfService.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
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
      _nextSprintReviewDays =
          (data['nextSprintReviewDays'] as num?)?.toInt() ?? 7;
      _enableSwimlanes = data['enableSwimlanes'] as bool? ?? true;
      _notesCtrl.text = data['notes'] as String? ?? '';
      _rebuildCtrls();
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _rebuildCtrls() {
    for (final c in _nameCtrls.values) {
      c.dispose();
    }
    for (final c in _entryCtrls.values) {
      c.dispose();
    }
    for (final c in _exitCtrls.values) {
      c.dispose();
    }
    _nameCtrls.clear();
    _entryCtrls.clear();
    _exitCtrls.clear();
    for (final col in _columns) {
      _nameCtrls[col.id] = TextEditingController(text: col.name);
      _entryCtrls[col.id] = TextEditingController(text: col.entryCriteria);
      _exitCtrls[col.id] = TextEditingController(text: col.exitCriteria);
    }
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
      for (final col in _columns) {
        col.entryCriteria = _entryCtrls[col.id]?.text ?? '';
        col.exitCriteria = _exitCtrls[col.id]?.text ?? '';
      }
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

  void _addColumn() {
    setState(() {
      _columns.add(_KanbanColumn(name: 'New Column'));
      _rebuildCtrls();
    });
    _scheduleAutoSave();
  }

  void _removeColumn(int index) {
    if (_columns.length <= 2) return;
    final col = _columns[index];
    _nameCtrls.remove(col.id)?.dispose();
    _entryCtrls.remove(col.id)?.dispose();
    _exitCtrls.remove(col.id)?.dispose();
    setState(() => _columns.removeAt(index));
    _scheduleAutoSave();
  }

  void _moveColumn(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final col = _columns.removeAt(oldIndex);
      _columns.insert(newIndex, col);
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
                  activeItemLabel:
                      'Agile Delivery Model - Kanban Configuration'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
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
                          _buildColumnsSection(),
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

  Widget _buildColumnsSection() {
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
              const Text('Workflow Columns',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addColumn,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Column'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Define the workflow stages and WIP limits that the execution Kanban board will use. Drag to reorder.',
            style: TextStyle(fontSize: 13, color: _kMuted),
          ),
          const SizedBox(height: 12),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _columns.length,
            onReorder: _moveColumn,
            proxyDecorator: (child, index, animation) => Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: child,
            ),
            itemBuilder: (context, index) {
              final col = _columns[index];
              return Container(
                key: ValueKey(col.id),
                margin: const EdgeInsets.only(bottom: 8),
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
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle,
                              color: _kMuted, size: 20),
                        ),
                        const SizedBox(width: 8),
                        Text('${index + 1}.',
                            style:
                                const TextStyle(fontSize: 13, color: _kMuted)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: VoiceTextField(
                            controller:
                                _nameCtrls[col.id] ?? TextEditingController(),
                            decoration: const InputDecoration(
                              hintText: 'Column name',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                            onChanged: (v) {
                              col.name = v;
                              _scheduleAutoSave();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: VoiceTextField(
                            controller: TextEditingController.fromValue(
                              TextEditingValue(
                                text: col.wipLimit.toString(),
                                selection:
                                    const TextSelection.collapsed(offset: 999),
                              ),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'WIP',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                            ),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 12),
                            onChanged: (v) {
                              col.wipLimit = int.tryParse(v) ?? 0;
                              _scheduleAutoSave();
                            },
                          ),
                        ),
                        if (_columns.length > 2)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 16, color: Colors.red),
                            onPressed: () => _removeColumn(index),
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: VoiceTextField(
                            controller:
                                _entryCtrls[col.id] ?? TextEditingController(),
                            decoration: const InputDecoration(
                              hintText: 'Entry criteria',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              labelText: 'Entry',
                            ),
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            onChanged: (_) => _scheduleAutoSave(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: VoiceTextField(
                            controller:
                                _exitCtrls[col.id] ?? TextEditingController(),
                            decoration: const InputDecoration(
                              hintText: 'Exit criteria',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              labelText: 'Exit',
                            ),
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            onChanged: (_) => _scheduleAutoSave(),
                          ),
                        ),
                      ],
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
              value: _cosOptions.contains(cos.name) ? cos.name : _cosOptions[0],
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
                child: VoiceTextField(
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
