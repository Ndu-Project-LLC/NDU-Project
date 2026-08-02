import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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
const Color _kAccent = Color(0xFFD97706);

class _LeaveEntry {
  String id;
  String person;
  DateTime startDate;
  DateTime endDate;

  _LeaveEntry({
    String? id,
    this.person = '',
    DateTime? startDate,
    DateTime? endDate,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        startDate = startDate ?? DateTime.now(),
        endDate = endDate ?? DateTime.now().add(const Duration(days: 1));
}

class _HolidayEntry {
  String id;
  String name;
  DateTime date;

  _HolidayEntry({
    String? id,
    this.name = '',
    DateTime? date,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        date = date ?? DateTime.now();
}

class AgileCapacityPlanningScreen extends StatefulWidget {
  const AgileCapacityPlanningScreen({super.key});

  @override
  State<AgileCapacityPlanningScreen> createState() =>
      _AgileCapacityPlanningScreenState();
}

class _AgileCapacityPlanningScreenState
    extends State<AgileCapacityPlanningScreen> {
  int _workingDays = 5;
  double _availability = 80;
  double _meetingOverhead = 4;
  double _buffer = 15;
  String _velocitySource = 'Estimated';
  double _historicalVelocity = 30;
  final TextEditingController _velocityNotesCtrl = TextEditingController();
  List<_LeaveEntry> _leaveEntries = [];
  List<_HolidayEntry> _holidays = [];
  bool _isLoading = true;
  bool _isSaving = false;
  Timer? _autoSaveDebounce;

  // Controllers for leave and holiday text fields
  final Map<String, TextEditingController> _leavePersonCtrls = {};
  final Map<String, TextEditingController> _holidayNameCtrls = {};

  double get _focusFactor {
    final overheadFraction = _meetingOverhead / 40;
    final bufferFraction = _buffer / 100;
    return (_availability / 100) *
        (1 - overheadFraction) *
        (1 - bufferFraction);
  }

  double get _effectiveCapacity {
    return _historicalVelocity * _focusFactor;
  }

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
    _velocityNotesCtrl.dispose();
    for (final c in _leavePersonCtrls.values) {
      c.dispose();
    }
    for (final c in _holidayNameCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final pid = _projectId;
    if (pid == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await AgileWireframeService.loadCapacityPlanning(pid);
      if (!mounted) return;
      setState(() {
        _workingDays = (data['workingDays'] as num?)?.toInt() ?? 5;
        _availability = (data['availability'] as num?)?.toDouble() ?? 80;
        _meetingOverhead = (data['meetingOverhead'] as num?)?.toDouble() ?? 4;
        _buffer = (data['buffer'] as num?)?.toDouble() ?? 15;
        _velocitySource = (data['velocitySource'] as String?) ?? 'Estimated';
        _historicalVelocity =
            (data['historicalVelocity'] as num?)?.toDouble() ?? 30;
        _velocityNotesCtrl.text = (data['velocityNotes'] as String?) ?? '';

        final rawLeave = data['leaveEntries'] as List?;
        if (rawLeave != null) {
          _leaveEntries = rawLeave.map((e) {
            final m = e as Map<String, dynamic>;
            return _LeaveEntry(
              id: m['id']?.toString(),
              person: m['person']?.toString() ?? '',
              startDate: (m['startDate'] as Timestamp?)?.toDate() ??
                  DateTime.tryParse(m['startDate']?.toString() ?? '') ??
                  DateTime.now(),
              endDate: (m['endDate'] as Timestamp?)?.toDate() ??
                  DateTime.tryParse(m['endDate']?.toString() ?? '') ??
                  DateTime.now().add(const Duration(days: 1)),
            );
          }).toList();
        }

        final rawHolidays = data['holidays'] as List?;
        if (rawHolidays != null) {
          _holidays = rawHolidays.map((e) {
            final m = e as Map<String, dynamic>;
            return _HolidayEntry(
              id: m['id']?.toString(),
              name: m['name']?.toString() ?? '',
              date: (m['date'] as Timestamp?)?.toDate() ??
                  DateTime.tryParse(m['date']?.toString() ?? '') ??
                  DateTime.now(),
            );
          }).toList();
        }
        _rebuildCtrls();
      });
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _rebuildCtrls() {
    for (final c in _leavePersonCtrls.values) {
      c.dispose();
    }
    for (final c in _holidayNameCtrls.values) {
      c.dispose();
    }
    _leavePersonCtrls.clear();
    _holidayNameCtrls.clear();
    for (final l in _leaveEntries) {
      _leavePersonCtrls[l.id] = TextEditingController(text: l.person);
    }
    for (final h in _holidays) {
      _holidayNameCtrls[h.id] = TextEditingController(text: h.name);
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
      for (final l in _leaveEntries) {
        l.person = _leavePersonCtrls[l.id]?.text ?? l.person;
      }
      for (final h in _holidays) {
        h.name = _holidayNameCtrls[h.id]?.text ?? h.name;
      }
      final data = <String, dynamic>{
        'workingDays': _workingDays,
        'availability': _availability,
        'meetingOverhead': _meetingOverhead,
        'buffer': _buffer,
        'velocitySource': _velocitySource,
        'historicalVelocity': _historicalVelocity,
        'velocityNotes': _velocityNotesCtrl.text,
        'leaveEntries': _leaveEntries
            .map((l) => {
                  'id': l.id,
                  'person': l.person,
                  'startDate': l.startDate.toIso8601String(),
                  'endDate': l.endDate.toIso8601String(),
                })
            .toList(),
        'holidays': _holidays
            .map((h) => {
                  'id': h.id,
                  'name': h.name,
                  'date': h.date.toIso8601String(),
                })
            .toList(),
      };
      await AgileWireframeService.saveCapacityPlanning(
          projectId: pid, data: data);
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _pickDateRange(
      BuildContext context, _LeaveEntry entry, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? entry.startDate : entry.endDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          entry.startDate = picked;
        } else {
          entry.endDate = picked;
        }
      });
      _scheduleAutoSave();
    }
  }

  Future<void> _pickHolidayDate(
      BuildContext context, _HolidayEntry entry) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: entry.date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => entry.date = picked);
      _scheduleAutoSave();
    }
  }

  void _addLeave() {
    setState(() {
      _leaveEntries.add(_LeaveEntry());
      _rebuildCtrls();
    });
    _scheduleAutoSave();
  }

  void _removeLeave(int index) {
    final l = _leaveEntries[index];
    _leavePersonCtrls.remove(l.id)?.dispose();
    setState(() => _leaveEntries.removeAt(index));
    _scheduleAutoSave();
  }

  void _addHoliday() {
    setState(() {
      _holidays.add(_HolidayEntry());
      _rebuildCtrls();
    });
    _scheduleAutoSave();
  }

  void _removeHoliday(int index) {
    final h = _holidays[index];
    _holidayNameCtrls.remove(h.id)?.dispose();
    setState(() => _holidays.removeAt(index));
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
                  activeItemLabel: 'Agile Delivery Model - Capacity Planning'),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileSidebarHamburger(
                    sidebar: const InitiationLikeSidebar(
                        activeItemLabel:
                            'Agile Delivery Model - Capacity Planning'),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: hp, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlanningPhaseHeader(
                          title: 'Capacity Planning',
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                              context, 'agile_capacity_planning'),
                          onForward: () => PlanningPhaseNavigation.goToNext(
                              context, 'agile_capacity_planning'),
                          onExportPdf: _exportPdf,
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          _buildFocusFactorCard(),
                          const SizedBox(height: 24),
                          _buildCapacityInputs(),
                          const SizedBox(height: 24),
                          _buildLeaveCalendar(),
                          const SizedBox(height: 24),
                          _buildHolidays(),
                          const SizedBox(height: 24),
                          _buildVelocitySection(),
                        ],
                        const SizedBox(height: 24),
                        LaunchPhaseNavigation(
                          backLabel: PlanningPhaseNavigation.backLabel(
                              'agile_capacity_planning'),
                          nextLabel: PlanningPhaseNavigation.nextLabel(
                              'agile_capacity_planning'),
                          onBack: () => PlanningPhaseNavigation.goToPrevious(
                              context, 'agile_capacity_planning'),
                          onNext: () => PlanningPhaseNavigation.goToNext(
                              context, 'agile_capacity_planning'),
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

  Widget _buildFocusFactorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kAccent.withOpacity(0.1), _kAccent.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text('Focus Factor & Effective Capacity',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _kHeadline)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStat('Availability', '${_availability.round()}%'),
              const SizedBox(width: 32),
              _buildStat('Meeting Overhead', '${_meetingOverhead.round()} hrs'),
              const SizedBox(width: 32),
              _buildStat('Buffer', '${_buffer.round()}%'),
              const SizedBox(width: 32),
              _buildStat('Focus Factor', '${(_focusFactor * 100).round()}%'),
              const SizedBox(width: 32),
              _buildStat('Est. Capacity', '${_effectiveCapacity.round()} pts'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: _kHeadline)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: _kMuted)),
      ],
    );
  }

  Widget _buildCapacityInputs() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Capacity Parameters',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kHeadline)),
          const SizedBox(height: 16),
          _buildSliderField(
              'Working days per week', _workingDays.toDouble(), 4, 6, 1, (v) {
            setState(() => _workingDays = v.round());
            _scheduleAutoSave();
          }),
          const SizedBox(height: 12),
          _buildSliderField('Team availability %', _availability, 50, 100, 5,
              (v) {
            setState(() => _availability = v);
            _scheduleAutoSave();
          }),
          const SizedBox(height: 12),
          _buildSliderField(
              'Meeting overhead (hrs/week)', _meetingOverhead, 0, 20, 1, (v) {
            setState(() => _meetingOverhead = v);
            _scheduleAutoSave();
          }),
          const SizedBox(height: 12),
          _buildSliderField('Buffer allocation %', _buffer, 0, 40, 5, (v) {
            setState(() => _buffer = v);
            _scheduleAutoSave();
          }),
        ],
      ),
    );
  }

  Widget _buildSliderField(String label, double value, double min, double max,
      double divisions, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kHeadline)),
            Text('${value.round()}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kAccent)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) / divisions).round(),
          activeColor: _kAccent,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildLeaveCalendar() {
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
              const Text('Leave Calendar',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addLeave,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Leave'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_leaveEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No leave entries. Add team member leave.',
                    style: TextStyle(color: _kMuted, fontSize: 13)),
              ),
            )
          else
            ..._leaveEntries
                .asMap()
                .entries
                .map((e) => _buildLeaveRow(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildLeaveRow(int index, _LeaveEntry entry) {
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
          SizedBox(
            width: 150,
            child: VoiceTextField(
              controller:
                  _leavePersonCtrls[entry.id] ?? TextEditingController(),
              decoration: const InputDecoration(
                hintText: 'Team member',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (_) => _scheduleAutoSave(),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _pickDateRange(context, entry, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: _kBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${entry.startDate.month}/${entry.startDate.day}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('→', style: TextStyle(fontSize: 12)),
          ),
          InkWell(
            onTap: () => _pickDateRange(context, entry, false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: _kBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${entry.endDate.month}/${entry.endDate.day}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
            onPressed: () => _removeLeave(index),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildHolidays() {
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
              const Text('Company Holidays',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kHeadline)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addHoliday,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Holiday'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_holidays.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No holidays added.',
                    style: TextStyle(color: _kMuted, fontSize: 13)),
              ),
            )
          else
            ..._holidays
                .asMap()
                .entries
                .map((e) => _buildHolidayRow(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildHolidayRow(int index, _HolidayEntry entry) {
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
          SizedBox(
            width: 180,
            child: VoiceTextField(
              controller:
                  _holidayNameCtrls[entry.id] ?? TextEditingController(),
              decoration: const InputDecoration(
                hintText: 'Holiday name',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (_) => _scheduleAutoSave(),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _pickHolidayDate(context, entry),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: _kBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${entry.date.month}/${entry.date.day}/${entry.date.year}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
            onPressed: () => _removeHoliday(index),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildVelocitySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Velocity Assumptions',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kHeadline)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Velocity source: ',
                  style: TextStyle(fontSize: 13, color: _kHeadline)),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Historical', label: Text('Historical')),
                  ButtonSegment(value: 'Estimated', label: Text('Estimated')),
                ],
                selected: {_velocitySource},
                onSelectionChanged: (v) {
                  setState(() => _velocitySource = v.first);
                  _scheduleAutoSave();
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          VoiceTextField(
            controller: TextEditingController.fromValue(
              TextEditingValue(
                text: _historicalVelocity.round().toString(),
                selection: const TextSelection.collapsed(offset: 999),
              ),
            ),
            decoration: const InputDecoration(
              labelText: 'Velocity (story points per sprint)',
              hintText: 'e.g. 30',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              _historicalVelocity = double.tryParse(v) ?? 30;
              _scheduleAutoSave();
            },
          ),
          const SizedBox(height: 12),
          VoiceTextField(
            controller: _velocityNotesCtrl,
            decoration: const InputDecoration(
              labelText: 'Velocity notes / assumptions',
              hintText: 'Basis for velocity estimate...',
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => _scheduleAutoSave(),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    final projectData = ProjectDataHelper.getData(context);
    await PdfExportHelper.exportScreenPdf(
      context: context,
      screenTitle: 'Capacity Planning',
      sections: [
        PdfSection.keyValue('Project Info', [
          {'Project Name': projectData.projectName},
          {'Solution Title': projectData.solutionTitle},
        ]),
        PdfSection.text(
            'Notes',
            projectData
                    .planningNotes['planning_agile_capacity_planning_notes'] ??
                'No data recorded.'),
      ],
    );
  }
}
