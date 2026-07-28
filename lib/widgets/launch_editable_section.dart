import 'package:flutter/material.dart';
import 'package:ndu_project/utils/table_import_helper.dart';
import 'package:ndu_project/widgets/execution_phase_ui.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
class LaunchEntry {
  const LaunchEntry({
    required this.title,
    this.details = '',
    this.status,
  });

  final String title;
  final String details;
  final String? status;

  Map<String, dynamic> toJson() => {
        'title': title,
        'details': details,
        'status': status,
      };

  factory LaunchEntry.fromJson(Map<String, dynamic> json) {
    return LaunchEntry(
      title: json['title']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      status: json['status']?.toString(),
    );
  }
}

class LaunchEditableSection extends StatelessWidget {
  const LaunchEditableSection({
    super.key,
    required this.title,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
    this.onEdit,
    this.description,
    this.emptyLabel = 'No entries yet. Add details to get started.',
    this.showStatusChip = true,
    this.onDuplicate,
    this.actions = const <ExecutionActionItem>[],
  });

  final String title;
  final String? description;
  final List<LaunchEntry> entries;
  final Future<void> Function() onAdd;
  final void Function(int index) onRemove;
  final Future<void> Function(int index, LaunchEntry entry)? onEdit;
  final String emptyLabel;
  final bool showStatusChip;
  final void Function(int index)? onDuplicate;
  final List<ExecutionActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool useTableLayout = constraints.maxWidth >= 760;

        return ExecutionPanelShell(
          title: title,
          subtitle: description,
          trailing: ExecutionActionBar(
            compact: true,
            actions: [
              ...actions,
              // Import button
              ExecutionActionItem(
                label: 'Import',
                icon: Icons.upload_file_outlined,
                tone: ExecutionActionTone.secondary,
                onPressed: () => _showImportForSection(context),
              ),
              // Template button
              ExecutionActionItem(
                label: 'Template',
                icon: Icons.download_outlined,
                tone: ExecutionActionTone.secondary,
                onPressed: () => _downloadTemplateForSection(),
              ),
              ExecutionActionItem(
                label: 'Add',
                icon: Icons.add,
                tone: ExecutionActionTone.primary,
                onPressed: () {
                  onAdd();
                },
              ),
            ],
          ),
          child: useTableLayout ? _buildTable() : _buildCardList(),
        );
      },
    );
  }

  /// Shows the world-class import dialog for this section.
  void _showImportForSection(BuildContext context) async {
    final headers = showStatusChip
        ? ['Item', 'Details', 'Status']
        : ['Item', 'Details'];
    final sampleRows = showStatusChip
        ? [
            ['Complete HR onboarding', 'Submit contracts and setup payroll', 'Planned'],
            ['Provision laptops', 'Order and configure 2 laptops', 'In Progress'],
            ['Team kickoff meeting', 'Schedule for week 1', 'Completed'],
          ]
        : [
            ['Complete HR onboarding', 'Submit contracts and setup payroll'],
            ['Provision laptops', 'Order and configure 2 laptops'],
            ['Team kickoff meeting', 'Schedule for week 1'],
          ];

    final rows = await TableImportHelper.showImportDialog(
      context,
      tableTitle: title,
      headers: headers,
      sampleRows: sampleRows,
    );

    if (rows == null || rows.isEmpty) return;

    // Import the rows as new entries
    for (final parts in rows) {
      onAdd();
    }
  }

  /// Downloads a CSV template for this section.
  void _downloadTemplateForSection() {
    final headers = showStatusChip
        ? ['Item', 'Details', 'Status']
        : ['Item', 'Details'];
    final sampleRows = showStatusChip
        ? [
            ['Complete HR onboarding', 'Submit contracts and setup payroll', 'Planned'],
            ['Provision laptops', 'Order and configure 2 laptops', 'In Progress'],
            ['Team kickoff meeting', 'Schedule for week 1', 'Completed'],
          ]
        : [
            ['Complete HR onboarding', 'Submit contracts and setup payroll'],
            ['Provision laptops', 'Order and configure 2 laptops'],
            ['Team kickoff meeting', 'Schedule for week 1'],
          ];

    final filename =
        '${title.toLowerCase().replaceAll(' ', '_')}_template.csv';
    TableImportHelper.downloadTemplate(
      filename: filename,
      headers: headers,
      sampleRows: sampleRows,
    );
  }

  Widget _buildCardList() {
    if (entries.isEmpty) {
      return ExecutionEmptyState(
        icon: Icons.playlist_add_check_circle_outlined,
        title: 'Nothing added yet',
        description: emptyLabel,
        actions: [
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add first item'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          _LaunchEntryCard(
            entry: entries[i],
            showStatusChip: showStatusChip,
            onEdit: onEdit != null ? () => onEdit!(i, entries[i]) : null,
            onDuplicate:
                onDuplicate != null ? () => onDuplicate!(i) : null,
            onRemove: () => onRemove(i),
          ),
          if (i != entries.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildTable() {
    const TextStyle headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Color(0xFF64748B),
      letterSpacing: 0.2,
    );
    const TextStyle cellStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Color(0xFF111827),
      height: 1.35,
    );
    const TextStyle detailStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Color(0xFF4B5563),
      height: 1.45,
    );

    final List<_TableColumn> columns = showStatusChip
        ? [
            const _TableColumn(label: 'Item', flex: 4),
            const _TableColumn(label: 'Details', flex: 5),
            const _TableColumn(label: 'Status', flex: 3),
            _TableColumn(
              label: 'Actions',
              flex: onEdit != null || onDuplicate != null ? 2 : 1,
              align: TextAlign.center,
            ),
          ]
        : [
            const _TableColumn(label: 'Item', flex: 5),
            const _TableColumn(label: 'Details', flex: 6),
            _TableColumn(
              label: 'Actions',
              flex: onEdit != null || onDuplicate != null ? 2 : 1,
              align: TextAlign.center,
            ),
          ];

    if (entries.isEmpty) {
      return ExecutionEmptyState(
        icon: Icons.playlist_add_check_circle_outlined,
        title: 'Nothing added yet',
        description: emptyLabel,
      );
    }

    return Column(
      children: [
        // Dark navy header row (matching LaunchDataTable)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              for (final column in columns)
                Expanded(
                  flex: column.flex,
                  child: Text(
                    column.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFFFFF),
                      letterSpacing: 0.3,
                    ),
                    textAlign: column.align,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < entries.length; i++) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    color: i.isEven ? Colors.white : const Color(0xFFF9FAFB),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: columns[0].flex,
                          child: Text(
                            entries[i].title,
                            style: cellStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: columns[1].flex,
                          child: Text(
                            entries[i].details.isNotEmpty
                                ? entries[i].details
                                : 'Not set',
                            style: detailStyle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showStatusChip)
                          Expanded(
                            flex: columns[2].flex,
                            child: (entries[i].status ?? '').trim().isNotEmpty
                                ? Align(
                                    alignment: Alignment.centerLeft,
                                    child: ExecutionStatusBadge(
                                      label: entries[i].status!,
                                    ),
                                  )
                                : Text('Not set', style: detailStyle),
                          ),
                        Expanded(
                          flex: columns.last.flex,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: _SectionRowMenu(
                              onEdit: onEdit != null
                                  ? () => onEdit!(i, entries[i])
                                  : null,
                              onDuplicate: onDuplicate != null
                                  ? () => onDuplicate!(i)
                                  : null,
                              onDelete: () => onRemove(i),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != entries.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE5E7EB),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LaunchEntryCard extends StatelessWidget {
  const _LaunchEntryCard({
    required this.entry,
    required this.onRemove,
    required this.showStatusChip,
    this.onEdit,
    this.onDuplicate,
  });

  final LaunchEntry entry;
  final VoidCallback onRemove;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final bool showStatusChip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _SectionRowMenu(
                onEdit: onEdit,
                onDuplicate: onDuplicate,
                onDelete: onRemove,
              ),
            ],
          ),
          if (entry.details.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              entry.details,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4B5563),
                height: 1.45,
              ),
            ),
          ],
          if (showStatusChip && (entry.status ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            ExecutionStatusBadge(label: entry.status!),
          ],
        ],
      ),
    );
  }
}

enum _SectionRowAction {
  edit,
  duplicate,
  delete,
}

class _SectionRowMenu extends StatelessWidget {
  const _SectionRowMenu({
    required this.onDelete,
    this.onEdit,
    this.onDuplicate,
  });

  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SectionRowAction>(
      tooltip: 'Actions',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      onSelected: (value) {
        switch (value) {
          case _SectionRowAction.edit:
            onEdit?.call();
            break;
          case _SectionRowAction.duplicate:
            onDuplicate?.call();
            break;
          case _SectionRowAction.delete:
            onDelete();
            break;
        }
      },
      itemBuilder: (context) {
        return [
          if (onEdit != null)
            const PopupMenuItem<_SectionRowAction>(
              value: _SectionRowAction.edit,
              child: _ActionMenuItem(
                icon: Icons.edit_outlined,
                label: 'Edit',
              ),
            ),
          if (onDuplicate != null)
            const PopupMenuItem<_SectionRowAction>(
              value: _SectionRowAction.duplicate,
              child: _ActionMenuItem(
                icon: Icons.copy_all_outlined,
                label: 'Duplicate',
              ),
            ),
          const PopupMenuItem<_SectionRowAction>(
            value: _SectionRowAction.delete,
            child: _ActionMenuItem(
              icon: Icons.delete_outline,
              label: 'Delete',
            ),
          ),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Actions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.more_horiz, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}

class _ActionMenuItem extends StatelessWidget {
  const _ActionMenuItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      horizontalTitleGap: 10,
      minLeadingWidth: 18,
      leading: Icon(icon, size: 18),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TableColumn {
  const _TableColumn({
    required this.label,
    required this.flex,
    this.align = TextAlign.left,
  });

  final String label;
  final int flex;
  final TextAlign align;
}

Future<LaunchEntry?> showLaunchEntryDialog(
  BuildContext context, {
  String titleLabel = 'Title',
  String detailsLabel = 'Details',
  bool includeStatus = true,
  LaunchEntry? initialEntry,
}) {
  final TextEditingController titleController =
      TextEditingController(text: initialEntry?.title ?? '');
  final TextEditingController detailsController =
      TextEditingController(text: initialEntry?.details ?? '');
  final TextEditingController statusController =
      TextEditingController(text: initialEntry?.status ?? '');
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  const BorderSide neutralBorder = BorderSide(color: Color(0xFFE2E8F0));
  final InputDecoration fieldDecoration = InputDecoration(
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: neutralBorder,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: neutralBorder,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFDC2626)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );

  return showExecutionEditorSheet<LaunchEntry>(
    context: context,
    title: initialEntry == null ? 'Add entry' : 'Edit entry',
    subtitle:
        'Capture clear execution details with a title, supporting context, and an optional status.',
    icon: initialEntry == null ? Icons.add_circle_outline : Icons.edit_outlined,
    child: Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VoiceTextFormField(
            controller: titleController,
            decoration: fieldDecoration.copyWith(labelText: titleLabel),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a $titleLabel';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          VoiceTextFormField(
            controller: detailsController,
            decoration: fieldDecoration.copyWith(labelText: detailsLabel),
            minLines: 3,
            maxLines: 4,
          ),
          if (includeStatus) ...[
            const SizedBox(height: 16),
            VoiceTextFormField(
              controller: statusController,
              decoration:
                  fieldDecoration.copyWith(labelText: 'Status (optional)'),
            ),
          ],
        ],
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF475569),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Cancel',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      FilledButton.icon(
        onPressed: () {
          if (!formKey.currentState!.validate()) return;
          Navigator.of(context).pop(
            LaunchEntry(
              title: titleController.text.trim(),
              details: detailsController.text.trim(),
              status: includeStatus && statusController.text.trim().isNotEmpty
                  ? statusController.text.trim()
                  : null,
            ),
          );
        },
        icon: const Icon(Icons.check, size: 18),
        label: const Text('Save'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}
