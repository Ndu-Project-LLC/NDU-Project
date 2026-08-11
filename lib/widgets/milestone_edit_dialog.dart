import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';

const _kAccentColor = Color(0xFFFFC107);
const _kPrimaryText = Color(0xFF1E293B);
const _kSecondaryText = Color(0xFF64748B);
const _kBorderColor = Color(0xFFE2E8F0);

const _breakdownOptions = [
  'Deliverable',
  'Discipline',
  'Functional Area',
  'Region / Site',
  'Phase',
];

/// Returns the saved [Milestone] on save, the string `'deleted'` on delete,
/// or `null` on cancel.
Future<dynamic> showMilestoneEditDialog({
  required BuildContext context,
  Milestone? existing,
  bool isAgile = false,
}) {
  return showDialog<dynamic>(
    context: context,
    builder: (_) => MilestoneEditDialog(
      existing: existing,
      isAgile: isAgile,
    ),
  );
}

class MilestoneEditDialog extends StatefulWidget {
  final Milestone? existing;
  final bool isAgile;

  const MilestoneEditDialog({
    super.key,
    this.existing,
    this.isAgile = false,
  });

  @override
  State<MilestoneEditDialog> createState() => _MilestoneEditDialogState();
}

class _MilestoneEditDialogState extends State<MilestoneEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _refsCtrl;
  late final TextEditingController _commentsCtrl;
  late final bool _isNew;
  late String _breakdownType;
  late String _dueDate;
  final DateFormat _displayFmt = DateFormat('MMM d, y');
  final DateFormat _storageFmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _isNew = existing == null;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _refsCtrl = TextEditingController(text: existing?.references ?? '');
    _commentsCtrl = TextEditingController(text: existing?.comments ?? '');
    _dueDate = existing?.dueDate ?? '';
    _breakdownType = _initBreakdownType(existing?.discipline ?? '');
  }

  String _initBreakdownType(String discipline) {
    if (discipline.isEmpty) return _breakdownOptions.first;
    final match = _breakdownOptions.firstWhere(
      (o) => o.toLowerCase() == discipline.trim().toLowerCase(),
      orElse: () => '',
    );
    return match.isNotEmpty ? match : discipline;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _refsCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_dueDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      setState(() => _dueDate = _storageFmt.format(picked));
    }
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Milestone name is required')),
      );
      return;
    }

    final milestone = widget.existing ?? Milestone(name: '', discipline: '');
    milestone.name = name;
    milestone.discipline = widget.isAgile ? 'Epic' : _breakdownType;
    milestone.dueDate = _dueDate;
    milestone.references = _refsCtrl.text.trim();
    milestone.comments = _commentsCtrl.text.trim();

    final provider = ProjectDataHelper.getProvider(context);
    provider.updateField((data) {
      final milestones = List<Milestone>.from(data.keyMilestones);
      if (_isNew) {
        milestones.add(milestone);
      } else {
        final idx = milestones.indexWhere((m) => m.id == milestone.id);
        if (idx >= 0) milestones[idx] = milestone;
      }
      return data.copyWith(keyMilestones: milestones);
    });
    provider.saveToFirebase(checkpoint: 'project_goals_milestones');

    Navigator.of(context).pop(milestone);
  }

  Future<void> _delete() async {
    if (_isNew) return;
    final milestoneName = widget.existing?.name.trim().isEmpty == true
        ? 'Untitled milestone'
        : widget.existing!.name.trim();
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Milestone?',
      itemLabel: milestoneName,
    );
    if (!confirmed) return;

    final id = widget.existing!.id;
    final provider = ProjectDataHelper.getProvider(context);
    provider.updateField((data) {
      final milestones = List<Milestone>.from(data.keyMilestones)
        ..removeWhere((m) => m.id == id);
      final planningGoals = data.planningGoals.map((g) {
        final ids = List<String>.from(g.milestoneIds)..remove(id);
        return PlanningGoal(
          id: g.id,
          goalNumber: g.goalNumber,
          title: g.title,
          description: g.description,
          targetYear: g.targetYear,
          priority: g.priority,
          milestoneIds: ids,
          milestones: g.milestones,
        );
      }).toList();
      return data.copyWith(
        keyMilestones: milestones,
        planningGoals: planningGoals,
      );
    });
    provider.saveToFirebase(checkpoint: 'project_goals_milestones');

    if (mounted) Navigator.of(context).pop('deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField(
                      label: 'Milestone Name',
                      child: VoiceTextField(
                        controller: _nameCtrl,
                        decoration: _inputDecoration('Enter milestone name'),
                        style:
                            const TextStyle(fontSize: 14, color: _kPrimaryText),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      label: 'Due Date',
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: _kBorderColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 16, color: _kSecondaryText),
                              const SizedBox(width: 8),
                              Text(
                                _dueDate.isEmpty
                                    ? 'Select date'
                                    : _displayFmt
                                        .format(DateTime.parse(_dueDate)),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _dueDate.isEmpty
                                      ? _kSecondaryText
                                      : _kPrimaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!widget.isAgile) ...[
                      const SizedBox(height: 16),
                      _buildField(
                        label: 'Breakdown Type',
                        child: DropdownButtonFormField<String>(
                          value: _breakdownType,
                          items: _breakdownOptions
                              .map((o) => DropdownMenuItem(
                                  value: o,
                                  child: Text(o,
                                      style: const TextStyle(
                                          fontSize: 14, color: _kPrimaryText))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _breakdownType = v);
                          },
                          decoration: _inputDecoration(null).copyWith(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          style: const TextStyle(
                              fontSize: 14, color: _kPrimaryText),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: _kAccentColor),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Milestones are organized by Epic (derived from project goals).',
                                style: TextStyle(
                                    fontSize: 12, color: _kPrimaryText),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildField(
                      label: 'References',
                      child: TextField(
                        controller: _refsCtrl,
                        decoration: _inputDecoration(
                            'Links, document IDs, or references'),
                        style:
                            const TextStyle(fontSize: 14, color: _kPrimaryText),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      label: 'Comments',
                      child: TextField(
                        controller: _commentsCtrl,
                        maxLines: 3,
                        decoration:
                            _inputDecoration('Additional notes or context'),
                        style:
                            const TextStyle(fontSize: 14, color: _kPrimaryText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorderColor)),
      ),
      child: Row(
        children: [
          Icon(
            _isNew ? Icons.add_circle_outline : Icons.edit_outlined,
            size: 20,
            color: _kAccentColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isNew ? 'Create Milestone' : 'Edit Milestone',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _kPrimaryText),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close, size: 20, color: _kSecondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _kBorderColor)),
      ),
      child: Row(
        children: [
          if (!_isNew)
            TextButton.icon(
              onPressed: _delete,
              icon:
                  const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              label: const Text('Delete',
                  style: TextStyle(color: Colors.red, fontSize: 13)),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 13, color: _kSecondaryText)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check, size: 18),
            label: Text(_isNew ? 'Add Milestone' : 'Save Changes',
                style: const TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentColor,
              foregroundColor: _kPrimaryText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _kSecondaryText)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kSecondaryText, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kAccentColor, width: 1.5),
      ),
      isDense: true,
    );
  }
}
