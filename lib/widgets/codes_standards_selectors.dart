import 'package:flutter/material.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

/// Codes / Standards / Specifications multi-select for requirement rows —
/// Lusaka 14.
///
/// A requirement names the code or standard it must satisfy ("ISO 9001",
/// "ISO/IEC 25010"). The options are the standards already captured in Quality
/// Management, so a requirement can only reference a standard the project
/// actually holds — the value is never free-typed. The stored value is the
/// standard's name; its source (the code) is shown beside it in the picker.
class CodesStandardsMultiSelect extends StatefulWidget {
  const CodesStandardsMultiSelect({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  /// The selected standard names.
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  @override
  State<CodesStandardsMultiSelect> createState() =>
      CodesStandardsMultiSelectState();
}

class CodesStandardsMultiSelectState extends State<CodesStandardsMultiSelect> {
  List<QualityStandard> _capturedStandards() {
    final standards =
        ProjectDataHelper.getData(context).qualityManagementData?.standards ??
            const <QualityStandard>[];
    return standards
        .where((standard) => standard.name.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _openPicker() async {
    final options = _capturedStandards();
    if (!mounted) return;
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No codes or standards captured yet — add them in Quality '
            'Management, then come back to map them to this requirement.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        final draft = List<String>.from(widget.selected);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Codes / Standards'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: options.isNotEmpty &&
                          options.every(
                              (o) => draft.contains(o.name.trim())),
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            draft
                              ..clear()
                              ..addAll(options.map((o) => o.name.trim()));
                          } else {
                            draft.clear();
                          }
                        });
                      },
                      title: const Text('Select all',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    ...options.map(
                      (standard) {
                        final value = standard.name.trim();
                        final source = standard.source.trim();
                        return CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: draft.contains(value),
                          title: Text(
                            value,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: source.isEmpty
                              ? null
                              : Text(
                                  source,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                if (!draft.contains(value)) draft.add(value);
                              } else {
                                draft.remove(value);
                              }
                            });
                          },
                        );
                      },
                    ),
                    if (options.any((o) => o.description.trim().isNotEmpty))
                      const Padding(
                        padding: EdgeInsets.only(top: 8, left: 4),
                        child: Text(
                          'Only standards captured in Quality Management are '
                          'offered here.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, draft),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = widget.selected.isNotEmpty;
    final label =
        hasSelection ? widget.selected.join(', ') : 'Select codes…';

    return InkWell(
      onTap: widget.enabled ? _openPicker : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasSelection
                ? const Color(0xFFFCD34D)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: hasSelection
                      ? const Color(0xFF111827)
                      : const Color(0xFF9CA3AF),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF6B7280),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
