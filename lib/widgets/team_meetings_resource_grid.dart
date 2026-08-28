import 'package:flutter/material.dart';
import 'package:ndu_project/models/meeting_row.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/utils/table_import_helper.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'dart:async';

import 'package:ndu_project/widgets/voice_text_field.dart';

/// Specialized Resource Grid widget for Team Meetings page
/// Features: Summary cards, meeting planner table with role integration, AI agenda generation
class TeamMeetingsResourceGrid extends StatefulWidget {
  const TeamMeetingsResourceGrid({
    super.key,
    required this.meetings,
    required this.staffRoles, // Available roles from Staff Team
    required this.onMeetingsChanged,
  });

  final List<MeetingRow> meetings;
  final List<String> staffRoles; // List of role titles from Staff Team
  final ValueChanged<List<MeetingRow>> onMeetingsChanged;

  @override
  State<TeamMeetingsResourceGrid> createState() =>
      _TeamMeetingsResourceGridState();
}

class _TeamMeetingsResourceGridState extends State<TeamMeetingsResourceGrid> {
  List<MeetingRow> get _meetings => widget.meetings;
  List<String> get _staffRoles => widget.staffRoles;

  // Calculate summary metrics
  DateTime? get _nextScheduledSync {
    final dates = _meetings
        .where((m) => m.nextScheduledDate != null)
        .map((m) => DateTime.tryParse(m.nextScheduledDate!))
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.first;
  }

  double get _totalMeetingHours {
    return _meetings.fold(
        0.0, (sum, meeting) => sum + meeting.totalHoursPerPeriod);
  }

  double get _teamCoverage {
    final allRoles = _staffRoles.toSet();
    if (allRoles.isEmpty) return 0.0;

    final coveredRoles = <String>{};
    for (final meeting in _meetings) {
      coveredRoles.addAll(meeting.keyParticipants);
    }

    return (coveredRoles.length / allRoles.length) * 100;
  }

  void _addNewMeeting() {
    final typeCtrl = TextEditingController();
    final freqCtrl = TextEditingController(text: 'Weekly');
    final durationCtrl = TextEditingController(text: '1');
    final objectiveCtrl = TextEditingController();
    final actionItemsCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    List<String> selectedRoles = [];

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.event_note_outlined,
                    color: Color(0xFF4338CA), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Add Meeting',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('Meeting Type'),
                _DialogTextField(
                    controller: typeCtrl,
                    hint: 'e.g. Weekly Sync, Stakeholder Update'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Frequency'),
                          DropdownButtonFormField<String>(
                            initialValue: freqCtrl.text,
                            decoration: _dialogInputDecoration(),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Daily', child: Text('Daily')),
                              DropdownMenuItem(
                                  value: 'Weekly', child: Text('Weekly')),
                              DropdownMenuItem(
                                  value: 'Bi-Weekly',
                                  child: Text('Bi-Weekly')),
                              DropdownMenuItem(
                                  value: 'Monthly', child: Text('Monthly')),
                              DropdownMenuItem(
                                  value: 'Quarterly',
                                  child: Text('Quarterly')),
                            ],
                            onChanged: (v) {
                              if (v != null) setDialogState(() => freqCtrl.text = v);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Duration (hrs)'),
                          _DialogTextField(
                              controller: durationCtrl, hint: 'e.g. 1'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _FieldLabel('Key Participants'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _staffRoles.map((role) {
                    final selected = selectedRoles.contains(role);
                    return FilterChip(
                      label: Text(role,
                          style: TextStyle(
                              fontSize: 11,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF4B5563))),
                      selected: selected,
                      selectedColor: const Color(0xFF4338CA),
                      backgroundColor: const Color(0xFFF3F4F6),
                      checkmarkColor: Colors.white,
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) {
                            selectedRoles.add(role);
                          } else {
                            selectedRoles.remove(role);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const _FieldLabel('Meeting Objective'),
                _DialogTextField(
                    controller: objectiveCtrl,
                    hint: 'Short, actionable objective',
                    maxLines: 2),
                const SizedBox(height: 14),
                const _FieldLabel('Action Items'),
                _DialogTextField(
                    controller: actionItemsCtrl,
                    hint: 'Optional bullet list',
                    maxLines: 2),
                const SizedBox(height: 14),
                const _FieldLabel('Notes'),
                _DialogTextField(
                    controller: notesCtrl,
                    hint: 'Optional notes',
                    maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (typeCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Meeting type is required')),
                  );
                  return;
                }
                final newMeeting = MeetingRow(
                  meetingType: typeCtrl.text.trim(),
                  frequency: freqCtrl.text.trim(),
                  keyParticipants: selectedRoles,
                  durationHours: durationCtrl.text.trim(),
                  meetingObjective: objectiveCtrl.text.trim(),
                  actionItems: actionItemsCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                  status: 'Scheduled',
                );
                final updated = [..._meetings, newMeeting];
                widget.onMeetingsChanged(updated);
                Navigator.of(ctx).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
              ),
              child: const Text('Add Meeting'),
            ),
          ],
        ),
      ),
    );
  }

  /// CSV column specs for the Meeting Cadence table. These mirror the
  /// on-page table columns (Meeting Type | Frequency | Key Participants |
  /// Duration | Meeting Objective | Status) so the downloaded template
  /// matches what users see on screen.
  static const String _meetingTableTitle = 'Meeting Cadence';
  static const List<CsvColumnSpec> _meetingColumns = [
    CsvColumnSpec(
      key: 'meetingType',
      label: 'Meeting Type',
      required: true,
      hint: 'e.g. Weekly Sync, Stakeholder Update',
      sampleValue: 'Weekly Sync',
    ),
    CsvColumnSpec(
      key: 'frequency',
      label: 'Frequency',
      required: true,
      allowedValues: ['Daily', 'Weekly', 'Bi-Weekly', 'Monthly'],
      defaultValue: 'Weekly',
      sampleValue: 'Weekly',
    ),
    CsvColumnSpec(
      key: 'keyParticipants',
      label: 'Key Participants',
      hint: 'Semicolon-separated list of roles (e.g. PM; Tech Lead)',
      sampleValue: 'PM; Tech Lead',
    ),
    CsvColumnSpec(
      key: 'durationHours',
      label: 'Duration (hrs)',
      hint: 'Numeric hours',
      sampleValue: '1',
    ),
    CsvColumnSpec(
      key: 'meetingObjective',
      label: 'Meeting Objective',
      hint: 'One-sentence purpose of the meeting',
      sampleValue: 'Align on weekly priorities and blockers',
    ),
    CsvColumnSpec(
      key: 'status',
      label: 'Status',
      allowedValues: ['Scheduled', 'In Progress', 'Completed', 'Cancelled'],
      defaultValue: 'Scheduled',
      sampleValue: 'Scheduled',
    ),
  ];

  /// Shows the world-class import dialog for Meeting Cadence data. Uses
  /// the rich CsvColumnSpec so the template mirrors the on-page table
  /// columns exactly.
  void _showImportDialog() async {
    final rows = await TableImportHelper.showImportDialogSpec(
      context,
      tableTitle: _meetingTableTitle,
      columns: _meetingColumns,
    );

    if (rows == null || rows.isEmpty || !mounted) return;

    final newMeetings = <MeetingRow>[];
    for (final parts in rows) {
      newMeetings.add(MeetingRow(
        meetingType: parts.isNotEmpty ? parts[0] : '',
        frequency: parts.length > 1 ? parts[1] : '',
        keyParticipants: parts.length > 2 ? parts[2].split(';') : [],
        durationHours: parts.length > 3 ? parts[3] : '',
        meetingObjective: parts.length > 4 ? parts[4] : '',
        actionItems: '',
        notes: '',
        status: parts.length > 5 ? parts[5] : 'Scheduled',
      ));
    }

    if (newMeetings.isNotEmpty) {
      widget.onMeetingsChanged([..._meetings, ...newMeetings]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${newMeetings.length} meetings'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Downloads a CSV template for Meeting Cadence. Uses the rich
  /// CsvColumnSpec so the template includes hints, allowed values, and
  /// required-field markers — fully mirroring the on-page table.
  void _downloadTemplate() {
    TableImportHelper.downloadTemplateForTable(
      tableTitle: _meetingTableTitle,
      columns: _meetingColumns,
    );
  }

  void _updateMeeting(int index, MeetingRow updatedMeeting) {
    final updated = List<MeetingRow>.from(_meetings);
    updated[index] = updatedMeeting;
    widget.onMeetingsChanged(updated);
  }

  void _removeMeeting(int index) {
    final updated = List<MeetingRow>.from(_meetings);
    updated.removeAt(index);
    widget.onMeetingsChanged(updated);
  }

  Future<void> _regenerateMeetingObjective(int index) async {
    final meeting = _meetings[index];
    if (meeting.meetingType.isEmpty || meeting.keyParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select meeting type and participants first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final data = ProjectDataHelper.getData(context);
      final contextText = ProjectDataHelper.buildExecutivePlanContext(
        data,
        sectionLabel: 'Team Meetings',
      );

      final ai = OpenAiServiceSecure();
      final result = await ai.generateMeetingObjective(
        context: contextText,
        meetingType: meeting.meetingType,
        participantRoles: meeting.keyParticipants,
      );

      if (mounted) {
        final updated = meeting.copyWith(
          meetingObjective: result['objective'] ?? meeting.meetingObjective,
          actionItems: result['agenda'] ?? meeting.actionItems,
        );
        _updateMeeting(index, updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating meeting objective: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meeting Planner Table
        _buildMeetingPlanner(),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final nextSync = _nextScheduledSync;
    return Row(
      children: [
        Expanded(
            child: _SummaryCard(
          title: 'Next Scheduled Sync',
          value: nextSync != null
              ? '${nextSync.month}/${nextSync.day}/${nextSync.year}'
              : 'Not scheduled',
          icon: Icons.calendar_today_outlined,
        )),
        const SizedBox(width: 16),
        Expanded(
            child: _SummaryCard(
          title: 'Total Meeting Hours',
          value: '${_totalMeetingHours.toStringAsFixed(1)} hrs/month',
          icon: Icons.access_time_outlined,
        )),
        const SizedBox(width: 16),
        Expanded(
            child: _SummaryCard(
          title: 'Team Coverage',
          value: '${_teamCoverage.toStringAsFixed(0)}%',
          icon: Icons.people_outline,
        )),
      ],
    );
  }

  Widget _buildMeetingPlanner() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Meeting Cadence',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                // Import button
                OutlinedButton.icon(
                  onPressed: _showImportDialog,
                  icon: const Icon(Icons.upload_file_outlined, size: 14),
                  label: const Text('Import',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4338CA),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                // Template button
                OutlinedButton.icon(
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.download_outlined, size: 14),
                  label: const Text('Template',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _addNewMeeting,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    foregroundColor: const Color(0xFF4338CA),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          // Table
          if (_meetings.isEmpty) _buildEmptyState() else _buildTable(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_note_outlined,
                color: Color(0xFF9CA3AF), size: 32),
            SizedBox(height: 12),
            Text(
              'No meetings scheduled yet. Add details to get started.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    return Column(
      children: [
        // Table Header - light theme (matching project style)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
            border: Border(
              bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
          ),
          child: const Row(
            children: [
              _TableHeaderCell('Meeting Type', flex: 2),
              _TableHeaderCell('Frequency', flex: 2),
              _TableHeaderCell('Key Participants', flex: 3),
              _TableHeaderCell('Duration', flex: 1),
              _TableHeaderCell('Meeting Objective', flex: 4),
              _TableHeaderCell('Actions', flex: 1),
            ],
          ),
        ),
        // Table Rows
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _meetings.length,
          itemBuilder: (context, index) {
            final meeting = _meetings[index];
            final isLast = index == _meetings.length - 1;
            return RepaintBoundary(
              key: ValueKey('meeting_row_$index'),
              child: _MeetingRowWidget(
                meeting: meeting,
                availableRoles: _staffRoles,
                onChanged: (updated) => _updateMeeting(index, updated),
                onDelete: () => _removeMeeting(index),
                onRegenerate: () => _regenerateMeetingObjective(index),
                showDivider: !isLast,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF4338CA)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  const _TableHeaderCell(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.left,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _MeetingRowWidget extends StatefulWidget {
  const _MeetingRowWidget({
    required this.meeting,
    required this.availableRoles,
    required this.onChanged,
    required this.onDelete,
    required this.onRegenerate,
    required this.showDivider,
  });

  final MeetingRow meeting;
  final List<String> availableRoles;
  final ValueChanged<MeetingRow> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onRegenerate;
  final bool showDivider;

  @override
  State<_MeetingRowWidget> createState() => _MeetingRowWidgetState();
}

class _MeetingRowWidgetState extends State<_MeetingRowWidget> {
  late MeetingRow _meeting;
  bool _isHovering = false;
  bool _isRegenerating = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _meeting = widget.meeting;
  }

  @override
  void didUpdateWidget(_MeetingRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meeting != widget.meeting) {
      _meeting = widget.meeting;
    }
  }

  void _updateMeeting(MeetingRow updated) {
    setState(() => _meeting = updated);
    widget.onChanged(updated);
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final meetingTypeController =
        TextEditingController(text: _meeting.meetingType);
    final frequencyController = TextEditingController(text: _meeting.frequency);
    final durationController =
        TextEditingController(text: _meeting.durationHours);
    final objectiveController =
        RichTextEditingController(text: _meeting.meetingObjective);
    final actionItemsController =
        RichAutoBulletTextController(text: _meeting.actionItems);
    final notesController = RichTextEditingController(text: _meeting.notes);
    final nextDateController =
        TextEditingController(text: _meeting.nextScheduledDate ?? '');
    final statusController = TextEditingController(text: _meeting.status);

    var selectedParticipants = List<String>.from(_meeting.keyParticipants);
    var selectedMeetingType = _meeting.meetingType;
    var selectedFrequency = _meeting.frequency;
    var selectedStatus = _meeting.status;

    try {
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Edit Meeting', style: TextStyle(fontSize: 18)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meeting Type
                    DropdownButtonFormField<String>(
                      initialValue: selectedMeetingType.isEmpty
                          ? null
                          : selectedMeetingType,
                      decoration: const InputDecoration(
                        labelText: 'Meeting Type *',
                        isDense: true,
                      ),
                      items: const [
                        'Weekly Sync',
                        'Stakeholder Update',
                        'Technical Deep-Dive',
                        'Sprint Planning',
                        'Retrospective',
                        'Status Review',
                        'Risk Review',
                        'Other',
                      ]
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item,
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setDialogState(() {
                          selectedMeetingType = v ?? '';
                          meetingTypeController.text = v ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Frequency
                    DropdownButtonFormField<String>(
                      initialValue:
                          selectedFrequency.isEmpty ? null : selectedFrequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequency *',
                        isDense: true,
                      ),
                      items: const ['Daily', 'Weekly', 'Bi-Weekly', 'Monthly']
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item,
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setDialogState(() {
                          selectedFrequency = v ?? '';
                          frequencyController.text = v ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Key Participants
                    InkWell(
                      onTap: () async {
                        final updated = await _showParticipantDialog(
                            context, selectedParticipants);
                        if (updated != null) {
                          setDialogState(() => selectedParticipants = updated);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Key Participants *',
                                    style: TextStyle(
                                        fontSize: 12, color: Color(0xFF6B7280)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedParticipants.isEmpty
                                        ? 'Tap to select roles'
                                        : selectedParticipants.length == 1
                                            ? selectedParticipants.first
                                            : '${selectedParticipants.length} roles selected',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                size: 16, color: Color(0xFF9CA3AF)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Duration
                    VoiceTextField(
                      controller: durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration (Hours) *',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    // Next Scheduled Date
                    VoiceTextField(
                      controller: nextDateController,
                      decoration: const InputDecoration(
                        labelText: 'Next Scheduled Date (YYYY-MM-DD)',
                        hintText: '2024-01-15',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Meeting Objective
                    const SizedBox(height: 6),
                    VoiceTextField(
                      controller: objectiveController,
                      decoration: const InputDecoration(
                        labelText: 'Meeting Objective *',
                        hintText: 'Prose description (no bullets)',
                        isDense: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    // Action Items
                    const SizedBox(height: 6),
                    VoiceTextField(
                      controller: actionItemsController,
                      decoration: const InputDecoration(
                        labelText: 'Action Items',
                        hintText:
                            'Use "." bullet format (e.g., ". Item 1\n. Item 2")',
                        isDense: true,
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    // Notes
                    const SizedBox(height: 6),
                    VoiceTextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Manual notes only',
                        isDense: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    // Status
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus.isEmpty ? null : selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        isDense: true,
                      ),
                      items: const [
                        'Scheduled',
                        'In Progress',
                        'Completed',
                        'Cancelled'
                      ]
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item,
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setDialogState(() {
                          selectedStatus = v ?? 'Scheduled';
                          statusController.text = v ?? 'Scheduled';
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  _updateMeeting(_meeting.copyWith(
                    meetingType: selectedMeetingType,
                    frequency: selectedFrequency,
                    keyParticipants: selectedParticipants,
                    durationHours: durationController.text.trim(),
                    meetingObjective: objectiveController.text.trim(),
                    actionItems: actionItemsController.text.trim(),
                    notes: notesController.text.trim(),
                    nextScheduledDate: nextDateController.text.trim().isEmpty
                        ? null
                        : nextDateController.text.trim(),
                    status: selectedStatus,
                  ));
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      meetingTypeController.dispose();
      frequencyController.dispose();
      durationController.dispose();
      objectiveController.dispose();
      actionItemsController.dispose();
      notesController.dispose();
      nextDateController.dispose();
      statusController.dispose();
    }
  }

  Future<List<String>?> _showParticipantDialog(
      BuildContext context, List<String> currentSelection) async {
    final updatedSelection = List<String>.from(currentSelection);

    return showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            const Text('Select Participants', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 300,
          child: StatefulBuilder(
            builder: (context, setDialogState) => ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.availableRoles.length,
              itemBuilder: (context, index) {
                final role = widget.availableRoles[index];
                final isSelected = updatedSelection.contains(role);
                return CheckboxListTile(
                  title: Text(role, style: const TextStyle(fontSize: 13)),
                  value: isSelected,
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        if (!updatedSelection.contains(role)) {
                          updatedSelection.add(role);
                        }
                      } else {
                        updatedSelection.remove(role);
                      }
                    });
                  },
                  dense: true,
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(updatedSelection),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) =>
          Future.microtask(() => setState(() => _isHovering = true)),
      onExit: (_) =>
          Future.microtask(() => setState(() => _isHovering = false)),
      child: Container(
        color: _isEditing
            ? const Color(0xFFFFFDF5)
            : (_isHovering ? const Color(0xFFF9FAFB) : Colors.white),
        child: Column(
          children: [
            Container(
              decoration: _isEditing
                  ? const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Color(0xFFF59E0B), width: 3),
                      ),
                    )
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Meeting Type ──
                  Expanded(
                    flex: 2,
                    child: _isEditing
                        ? _DropdownCell(
                            value: _meeting.meetingType,
                            items: const [
                              'Weekly Sync',
                              'Stakeholder Update',
                              'Technical Deep-Dive',
                              'Sprint Planning',
                              'Retrospective',
                              'Status Review',
                              'Risk Review',
                              'Other',
                            ],
                            hint: 'Select type',
                            onChanged: (v) => _updateMeeting(
                                _meeting.copyWith(meetingType: v ?? '')),
                          )
                        : _ReadOnlyText(
                            value: _meeting.meetingType,
                            hint: '—',
                            bold: true,
                          ),
                  ),
                  // ── Frequency ──
                  Expanded(
                    flex: 2,
                    child: _isEditing
                        ? _DropdownCell(
                            value: _meeting.frequency,
                            items: const [
                              'Daily',
                              'Weekly',
                              'Bi-Weekly',
                              'Monthly'
                            ],
                            hint: 'Frequency',
                            onChanged: (v) => _updateMeeting(
                                _meeting.copyWith(frequency: v ?? '')),
                          )
                        : _ReadOnlyText(
                            value: _meeting.frequency,
                            hint: '—',
                          ),
                  ),
                  // ── Key Participants ──
                  Expanded(
                    flex: 3,
                    child: _isEditing
                        ? _MultiSelectCell(
                            selectedRoles: _meeting.keyParticipants,
                            availableRoles: widget.availableRoles,
                            onChanged: (roles) => _updateMeeting(
                                _meeting.copyWith(keyParticipants: roles)),
                          )
                        : _ReadOnlyText(
                            value: _meeting.keyParticipants.isEmpty
                                ? '—'
                                : '${_meeting.keyParticipants.length} roles',
                            hint: '—',
                          ),
                  ),
                  // ── Duration ──
                  Expanded(
                    flex: 1,
                    child: _isEditing
                        ? _EditableCell(
                            value: _meeting.durationHours,
                            hint: 'Hrs',
                            onChanged: (v) => _updateMeeting(
                                _meeting.copyWith(durationHours: v)),
                          )
                        : _ReadOnlyText(
                            value: _meeting.durationHours.isEmpty
                                ? ''
                                : '${_meeting.durationHours}h',
                            hint: '—',
                          ),
                  ),
                  // ── Meeting Objective ──
                  Expanded(
                    flex: 4,
                    child: _isEditing
                        ? _ObjectiveCell(
                            value: _meeting.meetingObjective,
                            hint: 'Meeting objective...',
                            onChanged: (v) => _updateMeeting(
                                _meeting.copyWith(meetingObjective: v)),
                            onRegenerate: () {
                              setState(() => _isRegenerating = true);
                              widget.onRegenerate();
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) {
                                  setState(() => _isRegenerating = false);
                                }
                              });
                            },
                            isRegenerating: _isRegenerating,
                          )
                        : _ReadOnlyText(
                            value: _meeting.meetingObjective
                                .replaceAll(RegExp(r'<[^>]*>'), '')
                                .trim(),
                            hint: '—',
                            maxLines: 2,
                          ),
                  ),
                  // ── Actions ──
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: _isEditing
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle_rounded,
                                      size: 18, color: Color(0xFF10B981)),
                                  onPressed: () {
                                    setState(() => _isEditing = false);
                                  },
                                  tooltip: 'Save',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 16, color: Color(0xFFEF4444)),
                                  onPressed: widget.onDelete,
                                  tooltip: 'Delete',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                ),
                              ],
                            )
                          : _isHovering
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 16, color: Color(0xFF6B7280)),
                                      onPressed: () {
                                        setState(() => _isEditing = true);
                                      },
                                      tooltip: 'Edit',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 32, minHeight: 32),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 16, color: Color(0xFFEF4444)),
                                      onPressed: widget.onDelete,
                                      tooltip: 'Delete',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 32, minHeight: 32),
                                    ),
                                  ],
                                )
                              : const SizedBox(width: 40),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.showDivider)
              const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          ],
        ),
      ),
    );
  }
}

class _DropdownCell extends StatelessWidget {
  const _DropdownCell({
    required this.value,
    required this.items,
    required this.hint,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final String hint;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value.isEmpty ? null : value,
      isDense: true,
      underline: const SizedBox(),
      hint: Text(hint,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item, style: const TextStyle(fontSize: 11)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _MultiSelectCell extends StatelessWidget {
  const _MultiSelectCell({
    required this.selectedRoles,
    required this.availableRoles,
    required this.onChanged,
  });

  final List<String> selectedRoles;
  final List<String> availableRoles;
  final ValueChanged<List<String>> onChanged;

  Future<void> _showMultiSelectDialog(BuildContext context) async {
    final updatedSelection = List<String>.from(selectedRoles);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            const Text('Select Participants', style: TextStyle(fontSize: 14)),
        content: SizedBox(
          width: 300,
          child: StatefulBuilder(
            builder: (context, setState) => ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: availableRoles.length,
              itemBuilder: (context, index) {
                final role = availableRoles[index];
                final isSelected = updatedSelection.contains(role);
                return CheckboxListTile(
                  title: Text(role, style: const TextStyle(fontSize: 12)),
                  value: isSelected,
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        if (!updatedSelection.contains(role)) {
                          updatedSelection.add(role);
                        }
                      } else {
                        updatedSelection.remove(role);
                      }
                    });
                  },
                  dense: true,
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              onChanged(updatedSelection);
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (availableRoles.isEmpty) {
      return const Center(
        child: Text(
          'No roles available',
          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
      );
    }

    return InkWell(
      onTap: () => _showMultiSelectDialog(context),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                selectedRoles.isEmpty
                    ? 'Select roles'
                    : selectedRoles.length == 1
                        ? selectedRoles.first
                        : '${selectedRoles.length} roles',
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }
}

class _EditableCell extends StatelessWidget {
  const _EditableCell({
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return VoiceTextField(
      controller: TextEditingController(text: value)
        ..selection = TextSelection.collapsed(offset: value.length),
      onChanged: onChanged,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 11, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
    );
  }
}

class _ObjectiveCell extends StatelessWidget {
  const _ObjectiveCell({
    required this.value,
    required this.hint,
    required this.onChanged,
    required this.onRegenerate,
    required this.isRegenerating,
  });

  final String value;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onRegenerate;
  final bool isRegenerating;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Regenerate button above field
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: IconButton(
            icon: isRegenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFFFFC812)),
                  )
                : const Icon(Icons.refresh, size: 16, color: Color(0xFF64748B)),
            onPressed: isRegenerating ? null : onRegenerate,
            tooltip: 'Regenerate objective',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ),
        // Text field
        VoiceTextField(
          controller: TextEditingController(text: value)
            ..selection = TextSelection.collapsed(offset: value.length),
          onChanged: onChanged,
          maxLines: 2,
          style: const TextStyle(fontSize: 11, color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

/// Read-only text widget for table cells when not in editing mode.
/// Displays plain text (no input fields, no borders, no icons).
class _ReadOnlyText extends StatelessWidget {
  const _ReadOnlyText({
    required this.value,
    required this.hint,
    this.bold = false,
    this.maxLines = 1,
  });

  final String value;
  final String hint;
  final bool bold;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        value.isEmpty ? hint : value,
        overflow: TextOverflow.ellipsis,
        maxLines: maxLines,
        softWrap: false,
        style: TextStyle(
          fontSize: 13,
          color:
              value.isEmpty ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

// ── Dialog helper widgets ──────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }
}

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.controller,
    this.hint = '',
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _dialogInputDecoration().copyWith(hintText: hint),
    );
  }
}

InputDecoration _dialogInputDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF4338CA), width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );
}
