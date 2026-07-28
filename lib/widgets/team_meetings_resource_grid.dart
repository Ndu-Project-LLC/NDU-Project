import 'package:flutter/material.dart';
import 'package:ndu_project/models/meeting_row.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/auto_bullet_text_controller.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/utils/rich_text_editing_controller.dart';
import 'package:ndu_project/utils/table_import_helper.dart';
import 'package:ndu_project/widgets/text_formatting_toolbar.dart';
import 'dart:async';
import 'package:ndu_project/utils/web_utils_stub.dart'
    if (dart.library.html) 'package:ndu_project/utils/web_utils_web.dart' as web_utils;

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';

void _copyToClipboard(String text) {
  try {
    web_utils.copyToClipboard(text);
  } catch (_) {}
}

void _openUrlInNewTab(String url) {
  try {
    web_utils.openUrlInNewTab(url);
  } catch (_) {}
}
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
    final newMeeting = MeetingRow(
      meetingType: '',
      frequency: '',
      keyParticipants: [],
      durationHours: '',
      meetingObjective: '',
      actionItems: '',
      notes: '',
      status: 'Scheduled',
    );
    final updated = [..._meetings, newMeeting];
    widget.onMeetingsChanged(updated);
  }

  /// Shows the world-class import dialog for Meeting Cadence data.
  void _showImportDialog() async {
    final rows = await TableImportHelper.showImportDialog(
      context,
      tableTitle: 'Meeting Cadence',
      headers: ['Meeting Type', 'Frequency', 'Key Participants', 'Duration (hrs)', 'Meeting Objective', 'Status'],
      sampleRows: [
        ['Weekly Sync', 'Weekly', 'PM; Tech Lead', '1', 'Align on weekly priorities and blockers', 'Scheduled'],
        ['Stakeholder Update', 'Bi-Weekly', 'PM; Sponsor', '1', 'Provide sponsors with progress and risk updates', 'Scheduled'],
        ['Sprint Retrospective', 'Monthly', 'Dev Team', '2', 'Review what went well and what to improve', 'Completed'],
      ],
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

  /// Downloads a CSV template for Meeting Cadence.
  void _downloadTemplate() {
    TableImportHelper.downloadTemplate(
      filename: 'meeting_cadence_template.csv',
      headers: ['Meeting Type', 'Frequency', 'Key Participants', 'Duration (hrs)', 'Meeting Objective', 'Status'],
      sampleRows: [
        ['Weekly Sync', 'Weekly', 'PM; Tech Lead', '1', 'Align on weekly priorities and blockers', 'Scheduled'],
        ['Stakeholder Update', 'Bi-Weekly', 'PM; Sponsor', '1', 'Provide sponsors with progress and risk updates', 'Scheduled'],
        ['Sprint Retrospective', 'Monthly', 'Dev Team', '2', 'Review what went well and what to improve', 'Completed'],
      ],
    );
  }

  void _updateMeeting(int index, MeetingRow updatedMeeting) {
    final updated = List<MeetingRow>.from(_meetings);
    updated[index] = updatedMeeting;
    widget.onMeetingsChanged(updated);
  }

  Future<void> _removeMeeting(int index) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Meeting',
      itemLabel: _meetings[index].meetingType.isNotEmpty
          ? _meetings[index].meetingType
          : null,
    );
    if (!confirmed) return;
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
            color: Colors.black.withOpacity(0.04),
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
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4338CA),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    foregroundColor: const Color(0xFFD97706),
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.event_note_outlined,
                color: Color(0xFF9CA3AF), size: 32),
            const SizedBox(height: 12),
            const Text(
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
        // Table Header - dark navy (matching LaunchDataTable)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFF1F2937),
          ),
          child: Row(
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
        ...List.generate(_meetings.length, (index) {
          final meeting = _meetings[index];
          final isLast = index == _meetings.length - 1;
          return _MeetingRowWidget(
            meeting: meeting,
            availableRoles: _staffRoles,
            onChanged: (updated) => _updateMeeting(index, updated),
            onDelete: () => _removeMeeting(index),
            onRegenerate: () => _regenerateMeetingObjective(index),
            showDivider: !isLast,
          );
        }),
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
            color: Colors.black.withOpacity(0.02),
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
              color: const Color(0xFFEEF2FF),
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
          color: Color(0xFFFFFFFF),
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
    final meetingLinkController =
        TextEditingController(text: _meeting.meetingLink);
    final locationController =
        TextEditingController(text: _meeting.location);
    final organizerEmailController =
        TextEditingController(text: _meeting.organizerEmail);
    final attendeeEmailController = TextEditingController();

    var selectedParticipants = List<String>.from(_meeting.keyParticipants);
    var selectedMeetingType = _meeting.meetingType;
    var selectedFrequency = _meeting.frequency;
    var selectedStatus = _meeting.status;
    var selectedTime = _meeting.meetingTime;
    var attendeeEmails = List<String>.from(_meeting.attendeeEmails);
    var agendaItems = List<String>.from(_meeting.agendaItems);
    var reminderMinutes = _meeting.reminderMinutes;
    final agendaController = TextEditingController();

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Schedule Meeting', style: TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meeting Type
                  DropdownButtonFormField<String>(
                    value: selectedMeetingType.isEmpty
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
                    value:
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
                  const SizedBox(height: 16),
                  // ── Scheduling Section ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event, size: 16, color: Color(0xFF1D4ED8)),
                            const SizedBox(width: 6),
                            const Text('Schedule & Location',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1D4ED8))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Date + Time row
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.tryParse(
                                            nextDateController.text) ??
                                        DateTime.now(),
                                    firstDate: DateTime.now()
                                        .subtract(const Duration(days: 365)),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 730)),
                                  );
                                  if (picked != null) {
                                    final dateStr =
                                        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                    nextDateController.text = dateStr;
                                    setDialogState(() {});
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Date',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.calendar_today,
                                        size: 16),
                                  ),
                                  child: Text(
                                    nextDateController.text.isEmpty
                                        ? 'Select date'
                                        : nextDateController.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: nextDateController.text.isEmpty
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF111827),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final parts = selectedTime.split(':');
                                  final initial = TimeOfDay(
                                    hour: parts.length == 2
                                        ? int.tryParse(parts[0]) ?? 9
                                        : 9,
                                    minute: parts.length == 2
                                        ? int.tryParse(parts[1]) ?? 0
                                        : 0,
                                  );
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: initial,
                                  );
                                  if (picked != null) {
                                    final timeStr =
                                        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                    setDialogState(() => selectedTime = timeStr);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Time',
                                    isDense: true,
                                    prefixIcon:
                                        Icon(Icons.access_time, size: 16),
                                  ),
                                  child: Text(
                                    selectedTime.isEmpty
                                        ? 'Select time'
                                        : selectedTime,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: selectedTime.isEmpty
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF111827),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Meeting Link
                        VoiceTextField(
                          controller: meetingLinkController,
                          decoration: const InputDecoration(
                            labelText: 'Meeting Link (Zoom, Teams, Google Meet)',
                            hintText: 'https://zoom.us/j/...',
                            isDense: true,
                            prefixIcon: Icon(Icons.videocam, size: 16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Location
                        VoiceTextField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location / Room',
                            hintText: 'Conference Room A, Online, etc.',
                            isDense: true,
                            prefixIcon: Icon(Icons.location_on, size: 16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Reminder
                        DropdownButtonFormField<int>(
                          value: reminderMinutes,
                          decoration: const InputDecoration(
                            labelText: 'Reminder',
                            isDense: true,
                            prefixIcon:
                                Icon(Icons.notifications, size: 16),
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('No reminder')),
                            DropdownMenuItem(value: 5, child: Text('5 minutes before')),
                            DropdownMenuItem(value: 15, child: Text('15 minutes before')),
                            DropdownMenuItem(value: 30, child: Text('30 minutes before')),
                            DropdownMenuItem(value: 60, child: Text('1 hour before')),
                            DropdownMenuItem(value: 1440, child: Text('1 day before')),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => reminderMinutes = v ?? 30),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Collaborators Section ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.people, size: 16, color: Color(0xFF059669)),
                            const SizedBox(width: 6),
                            const Text('Invite Collaborators',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Organizer Email
                        VoiceTextField(
                          controller: organizerEmailController,
                          decoration: const InputDecoration(
                            labelText: 'Organizer Email',
                            hintText: 'organizer@company.com',
                            isDense: true,
                            prefixIcon: Icon(Icons.person_outline, size: 16),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        // Attendee Emails
                        const Text('Attendee Emails',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280))),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: attendeeEmailController,
                                decoration: const InputDecoration(
                                  hintText: 'email@company.com',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.email, size: 16),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                onFieldSubmitted: (v) {
                                  final email = v.trim();
                                  if (email.isNotEmpty &&
                                      email.contains('@') &&
                                      !attendeeEmails.contains(email)) {
                                    setDialogState(() {
                                      attendeeEmails.add(email);
                                      attendeeEmailController.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                final email =
                                    attendeeEmailController.text.trim();
                                if (email.isNotEmpty &&
                                    email.contains('@') &&
                                    !attendeeEmails.contains(email)) {
                                  setDialogState(() {
                                    attendeeEmails.add(email);
                                    attendeeEmailController.clear();
                                  });
                                }
                              },
                              icon: const Icon(Icons.add_circle,
                                  color: Color(0xFF059669)),
                            ),
                          ],
                        ),
                        if (attendeeEmails.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: attendeeEmails.map((email) {
                              return Chip(
                                label: Text(email,
                                    style: const TextStyle(fontSize: 11)),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () => setDialogState(
                                    () => attendeeEmails.remove(email)),
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                    color: Color(0xFFBBF7D0)),
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Agenda Items ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.format_list_numbered, size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            const Text('Agenda Items',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFD97706))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: agendaController,
                                decoration: const InputDecoration(
                                  hintText: 'Add agenda item...',
                                  isDense: true,
                                ),
                                onFieldSubmitted: (v) {
                                  if (v.trim().isNotEmpty) {
                                    setDialogState(() {
                                      agendaItems.add(v.trim());
                                      agendaController.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                if (agendaController.text.trim().isNotEmpty) {
                                  setDialogState(() {
                                    agendaItems.add(agendaController.text.trim());
                                    agendaController.clear();
                                  });
                                }
                              },
                              icon: const Icon(Icons.add_circle,
                                  color: Color(0xFFD97706)),
                            ),
                          ],
                        ),
                        if (agendaItems.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...agendaItems.asMap().entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Text('${entry.key + 1}.',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFD97706))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(entry.value,
                                        style:
                                            const TextStyle(fontSize: 12)),
                                  ),
                                  InkWell(
                                    onTap: () => setDialogState(() =>
                                        agendaItems.removeAt(entry.key)),
                                    child: const Icon(Icons.close,
                                        size: 14, color: Color(0xFF9CA3AF)),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Meeting Objective
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
                    value:
                        selectedStatus.isEmpty ? null : selectedStatus,
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
            // Copy Invite
            if (_meeting.meetingType.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  final updated = _meeting.copyWith(
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
                    meetingTime: selectedTime,
                    meetingLink: meetingLinkController.text.trim(),
                    location: locationController.text.trim(),
                    organizerEmail: organizerEmailController.text.trim(),
                    attendeeEmails: attendeeEmails,
                    reminderMinutes: reminderMinutes,
                    agendaItems: agendaItems,
                  );
                  _copyInviteToClipboard(context, updated);
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Invite'),
              ),
            // Add to Calendar
            if (nextDateController.text.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  final updated = _meeting.copyWith(
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
                    meetingTime: selectedTime,
                    meetingLink: meetingLinkController.text.trim(),
                    location: locationController.text.trim(),
                    organizerEmail: organizerEmailController.text.trim(),
                    attendeeEmails: attendeeEmails,
                    reminderMinutes: reminderMinutes,
                    agendaItems: agendaItems,
                  );
                  _openGoogleCalendar(context, updated);
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Add to Calendar'),
              ),
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
                  meetingTime: selectedTime,
                  meetingLink: meetingLinkController.text.trim(),
                  location: locationController.text.trim(),
                  organizerEmail: organizerEmailController.text.trim(),
                  attendeeEmails: attendeeEmails,
                  reminderMinutes: reminderMinutes,
                  agendaItems: agendaItems,
                ));
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _copyInviteToClipboard(BuildContext context, MeetingRow meeting) {
    final text = meeting.inviteText;
    _copyToClipboard(text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Meeting invitation copied to clipboard. Paste into email or chat.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _openGoogleCalendar(BuildContext context, MeetingRow meeting) {
    final url = meeting.googleCalendarUrl;
    _openUrlInNewTab(url);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening Google Calendar to create event...'),
        duration: Duration(seconds: 2),
      ),
    );
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
                                          size: 16,
                                          color: Color(0xFF6B7280)),
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
                                          size: 16,
                                          color: Color(0xFFEF4444)),
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
                        strokeWidth: 2, color: Color(0xFFD97706)),
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
          color: value.isEmpty
              ? const Color(0xFF9CA3AF)
              : const Color(0xFF111827),
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
