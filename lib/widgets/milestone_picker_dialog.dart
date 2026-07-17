import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/project_data_model.dart';

/// Reusable dialog for selecting FEP milestones to link to an item.
///
/// Shows all available milestones with checkboxes.
/// Returns the selected list of milestone IDs, or null if cancelled.
class MilestonePickerDialog extends StatefulWidget {
  final String title;
  final List<Milestone> allMilestones;
  final List<String> selectedIds;

  const MilestonePickerDialog({
    super.key,
    required this.title,
    required this.allMilestones,
    required this.selectedIds,
  });

  @override
  State<MilestonePickerDialog> createState() => _MilestonePickerDialogState();
}

class _MilestonePickerDialogState extends State<MilestonePickerDialog> {
  late final Set<String> _selected;
  final DateFormat _dateFormat = DateFormat('MMM d, y');

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedIds);
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.trim().isEmpty ? 'No date' : raw.trim();
    return _dateFormat.format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<Milestone>.from(widget.allMilestones)
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a.dueDate);
        final bDate = DateTime.tryParse(b.dueDate);
        if (aDate == null && bDate == null) return a.name.compareTo(b.name);
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.flag_outlined,
                    size: 20, color: Color(0xFFFFC107)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Milestone list
          Flexible(
            child: sorted.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No milestones available. Add them in Front End Planning > Milestone.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final milestone = sorted[index];
                      final selected =
                          _selected.contains(milestone.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selected.add(milestone.id);
                            } else {
                              _selected.remove(milestone.id);
                            }
                          });
                        },
                        dense: true,
                        activeColor: const Color(0xFFFFC107),
                        title: Text(
                          milestone.name.trim().isEmpty
                              ? 'Untitled milestone'
                              : milestone.name.trim(),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B)),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(milestone.dueDate),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B)),
                            ),
                            if (milestone.discipline.trim().isNotEmpty)
                              Text(
                                milestone.discipline.trim(),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selected.toList()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: const Color(0xFF1E293B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
