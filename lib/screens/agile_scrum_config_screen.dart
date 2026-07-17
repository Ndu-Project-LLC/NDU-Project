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

const List<String> _durationOptions = [
  '15 min',
  '30 min',
  '45 min',
  '1 hr',
  '1.5 hrs',
  '2 hrs',
  '3 hrs',
  '4 hrs',
];

String _defaultFor(String key) {
  switch (key) {
    case 'planning_duration':
      return '2 hrs';
    case 'daily_scrum_time':
      return '09:00';
    case 'daily_scrum_duration':
      return '15 min';
    case 'review_duration':
      return '1 hr';
    case 'retro_duration':
      return '1 hr';
    case 'refinement_duration':
      return '1 hr';
    default:
      return '';
  }
}

class _WorkingAgreement {
  String id;
  String category;
  String description;

  _WorkingAgreement({
    String? id,
    this.category = 'Communication',
    this.description = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
}

class AgileScrumConfigScreen extends StatefulWidget {
  const AgileScrumConfigScreen({super.key});

  @override
  State<AgileScrumConfigScreen> createState() => _AgileScrumConfigScreenState();
}

class _AgileScrumConfigScreenState extends State<AgileScrumConfigScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _selectedValues = {};
  final Map<String, TextEditingController> _agreementCtrls = {};
  final Map<String, TextEditingController> _agreementCatCtrls = {};
  List<_WorkingAgreement> _agreements = [];
  final Map<String, TextEditingController> _doaControllers = {};
  bool _isLoading = true;
  bool _isSaving = false;
  Timer? _autoSaveDebounce;

  static const List<_FieldConfig> _fields = [
    _FieldConfig(
        key: 'po', label: 'Product Owner', hint: 'Name of the Product Owner'),
    _FieldConfig(
        key: 'sm', label: 'Scrum Master', hint: 'Name of the Scrum Master'),
    _FieldConfig(
        key: 'team',
        label: 'Development Team',
        hint: 'Team composition and size'),
  ];

  static const List<_DoaField> _doaFields = [
    _DoaField(
        key: 'definitionOfReady',
        label: 'Definition of Ready',
        hint:
            'Conditions that must be met before a story can be taken into a sprint. E.g. clear acceptance criteria, estimated, dependencies identified, UX reviewed.'),
    _DoaField(
        key: 'definitionOfDone',
        label: 'Definition of Done',
        hint:
            'Conditions that must be met for a story to be considered complete. E.g. code reviewed, tested, documented, deployed to staging.'),
    _DoaField(
        key: 'teamValues',
        label: 'Team Values',
        hint:
            'Core team values and working norms. E.g. transparency, respect, continuous improvement, psychological safety.'),
    _DoaField(
        key: 'coreHours',
        label: 'Core Hours',
        hint:
            'Overlap hours when the full team is available. E.g. 10:00-15:00 ET.'),
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
    for (final key in [
      'planning_duration',
      'daily_scrum_time',
      'daily_scrum_duration',
      'review_duration',
      'retro_duration',
      'refinement_duration',
    ]) {
      _selectedValues[key] = _defaultFor(key);
    }
    for (final f in _doaFields) {
      _doaControllers[f.key] = TextEditingController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final c in _agreementCtrls.values) {
      c.dispose();
    }
    for (final c in _agreementCatCtrls.values) {
      c.dispose();
    }
    for (final c in _doaControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await AgileWireframeService.loadScrumConfig(pid);
      if (!mounted) return;
      for (final f in _fields) {
        _controllers[f.key]?.text = (data[f.key] as String?) ?? '';
      }
      for (final key in _selectedValues.keys.toList()) {
        _selectedValues[key] = (data[key] as String?) ?? _defaultFor(key);
      }
      for (final f in _doaFields) {
        _doaControllers[f.key]?.text = (data[f.key] as String?) ?? '';
      }
      final rawAgreements = data['workingAgreements'] as List?;
      if (rawAgreements != null) {
        _agreements = rawAgreements.map((e) {
          final m = e as Map<String, dynamic>;
          return _WorkingAgreement(
            id: m['id']?.toString(),
            category: m['category']?.toString() ?? 'Communication',
            description: m['description']?.toString() ?? '',
          );
        }).toList();
      } else {
        _agreements = [
          _WorkingAgreement(
              category: 'Communication',
              description: 'Daily standup at scheduled time'),
          _WorkingAgreement(
              category: 'Code Quality',
              description: 'All code must be peer reviewed'),
          _WorkingAgreement(
              category: 'Collaboration',
              description: 'Async communication via project channel'),
          _WorkingAgreement(
              category: 'Meeting',
              description: 'Arrive on time; keep discussions focused'),
        ];
      }
      _rebuildAgreementCtrls();
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _rebuildAgreementCtrls() {
    for (final c in _agreementCtrls.values) {
      c.dispose();
    }
    for (final c in _agreementCatCtrls.values) {
      c.dispose();
    }
    _agreementCtrls.clear();
    _agreementCatCtrls.clear();
    for (final a in _agreements) {
      _agreementCatCtrls[a.id] = TextEditingController(text: a.category);
      _agreementCtrls[a.id] = TextEditingController(text: a.description);
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
      final data = <String, dynamic>{};
      for (final f in _fields) {
        data[f.key] = _controllers[f.key]?.text ?? '';
      }
      for (final entry in _selectedValues.entries) {
        data[entry.key] = entry.value;
      }
      for (final f in _doaFields) {
        data[f.key] = _doaControllers[f.key]?.text ?? '';
      }
      for (final a in _agreements) {
        a.category = _agreementCatCtrls[a.id]?.text ?? a.category;
        a.description = _agreementCtrls[a.id]?.text ?? a.description;
      }
      data['workingAgreements'] = _agreements
          .map((a) => {
                'id': a.id,
                'category': a.category,
                'description': a.description,
              })
          .toList();
      await AgileWireframeService.saveScrumConfig(projectId: pid, data: data);
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  void _addAgreement() {
    setState(() {
      _agreements.add(_WorkingAgreement());
      _rebuildAgreementCtrls();
    });
    _scheduleAutoSave();
  }

  void _removeAgreement(int index) {
    final a = _agreements[index];
    _agreementCtrls.remove(a.id)?.dispose();
    _agreementCatCtrls.remove(a.id)?.dispose();
    setState(() => _agreements.removeAt(index));
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
                      'Agile Delivery Model - Scrum Configuration'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                        activeItemLabel:
                            'Agile Delivery Model - Scrum Configuration'),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: hp, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlanningPhaseHeader(
                          title: 'Scrum Configuration',
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                              context, 'agile_scrum_config'),
                          onForward: () => PlanningPhaseNavigation.goToNext(
                              context, 'agile_scrum_config'),
                          onExportPdf: _exportPdf,
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
                          _buildRolesSection(),
                          const SizedBox(height: 24),
                          _buildEventDurations(),
                          const SizedBox(height: 24),
                          _buildDefinitionOfAgreement(),
                          const SizedBox(height: 24),
                          _buildWorkingAgreements(),
                        ],
                        const SizedBox(height: 24),
                        LaunchPhaseNavigation(
                          backLabel: PlanningPhaseNavigation.backLabel(
                              'agile_scrum_config'),
                          nextLabel: PlanningPhaseNavigation.nextLabel(
                              'agile_scrum_config'),
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                              context, 'agile_scrum_config'),
                          onNext: () => PlanningPhaseNavigation.goToNext(
                              context, 'agile_scrum_config'),
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

  Widget _buildRolesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scrum Roles',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kHeadline)),
          const SizedBox(height: 12),
          ..._fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VoiceTextField(
                  controller: _controllers[f.key]!,
                  decoration: InputDecoration(
                    labelText: f.label,
                    hintText: f.hint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _scheduleAutoSave(),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEventDurations() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scrum Event Durations',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kHeadline)),
          const SizedBox(height: 4),
          const Text('Configure the duration and timing of each Scrum event.',
              style: TextStyle(fontSize: 13, color: _kMuted)),
          const SizedBox(height: 12),
          _buildDropdownField(
              'Sprint Planning', 'planning_duration', _durationOptions),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                    'Daily Scrum Time', 'daily_scrum_time', 'e.g. 09:00'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField('Daily Scrum Duration',
                    'daily_scrum_duration', _durationOptions),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDropdownField(
              'Sprint Review', 'review_duration', _durationOptions),
          const SizedBox(height: 12),
          _buildDropdownField(
              'Sprint Retrospective', 'retro_duration', _durationOptions),
          const SizedBox(height: 12),
          _buildDropdownField(
              'Backlog Refinement', 'refinement_duration', _durationOptions),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String key, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _kHeadline)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: options.contains(_selectedValues[key])
              ? _selectedValues[key]
              : options[0],
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _selectedValues[key] = v);
              _scheduleAutoSave();
            }
          },
        ),
      ],
    );
  }

  Widget _buildTextField(String label, String key, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _kHeadline)),
        const SizedBox(height: 6),
        VoiceTextField(
          controller:
              _controllers.putIfAbsent(key, () => TextEditingController()),
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: (_) {
            _selectedValues[key] = _controllers[key]?.text ?? '';
            _scheduleAutoSave();
          },
        ),
      ],
    );
  }

  Widget _buildDefinitionOfAgreement() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Definition of Agreement',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kHeadline)),
          const SizedBox(height: 4),
          const Text('Team-level agreements for quality and collaboration.',
              style: TextStyle(fontSize: 13, color: _kMuted)),
          const SizedBox(height: 12),
          ..._doaFields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VoiceTextField(
                  controller: _doaControllers[f.key]!,
                  decoration: InputDecoration(
                    labelText: f.label,
                    hintText: f.hint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 4,
                  onChanged: (_) => _scheduleAutoSave(),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildWorkingAgreements() {
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
              const Text('Working Agreements',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addAgreement,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._agreements
              .asMap()
              .entries
              .map((e) => _buildAgreementRow(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildAgreementRow(int index, _WorkingAgreement a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<String>(
              value: [
                'Communication',
                'Code Quality',
                'Collaboration',
                'Meeting'
              ].contains(_agreementCatCtrls[a.id]?.text)
                  ? _agreementCatCtrls[a.id]?.text
                  : 'Communication',
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'Communication',
                    child:
                        Text('Communication', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(
                    value: 'Code Quality',
                    child:
                        Text('Code Quality', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(
                    value: 'Collaboration',
                    child:
                        Text('Collaboration', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(
                    value: 'Meeting',
                    child: Text('Meeting', style: TextStyle(fontSize: 11))),
              ],
              onChanged: (v) {
                if (v != null) {
                  _agreementCatCtrls[a.id]?.text = v;
                  _scheduleAutoSave();
                  setState(() {});
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: VoiceTextField(
              controller: _agreementCtrls[a.id] ?? TextEditingController(),
              decoration: const InputDecoration(
                hintText: 'Agreement description',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (_) => _scheduleAutoSave(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
            onPressed: () => _removeAgreement(index),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Scrum Configuration',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName},
          {'Solution Title': projectData.solutionTitle},
        ]),
        PdfSection.text(
            'Notes',
            projectData.planningNotes['planning_agile_scrum_config_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}

class _FieldConfig {
  final String key;
  final String label;
  final String hint;
  const _FieldConfig(
      {required this.key, required this.label, required this.hint});
}

class _DoaField {
  final String key;
  final String label;
  final String hint;
  const _DoaField({required this.key, required this.label, required this.hint});
}
