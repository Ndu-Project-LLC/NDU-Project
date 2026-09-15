import 'package:flutter/material.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
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

class LaunchEditableSection extends StatefulWidget {
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
  State<LaunchEditableSection> createState() => _LaunchEditableSectionState();
}

class _LaunchEditableSectionState extends State<LaunchEditableSection> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showTableView = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LaunchEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return widget.entries;
    final q = _searchQuery.toLowerCase();
    return widget.entries.where((e) =>
        e.title.toLowerCase().contains(q) ||
        e.details.toLowerCase().contains(q) ||
        (e.status?.toLowerCase().contains(q) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool useWideLayout = constraints.maxWidth >= 760;

        return ExecutionPanelShell(
          title: widget.title,
          subtitle: widget.description,
          trailing: ExecutionActionBar(
            compact: true,
            actions: [
              ...widget.actions,
              ExecutionActionItem(
                label: 'Import',
                icon: Icons.upload_file_outlined,
                tone: ExecutionActionTone.secondary,
                onPressed: () => _showImportForSection(context),
              ),
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
                onPressed: () => widget.onAdd(),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchAndToggle(),
              const SizedBox(height: 14),
              _showTableView ? _buildTable() : _buildCardList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAndToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Icon(Icons.search, size: 16, color: Color(0xFF9CA3AF)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Search entries...',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
            child: Text('${_filteredEntries.length} items', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ViewBtn(icon: Icons.table_chart_outlined, isActive: _showTableView, onTap: () => setState(() => _showTableView = true)),
                Container(width: 1, height: 26, color: const Color(0xFFE5E7EB)),
                _ViewBtn(icon: Icons.view_agenda_outlined, isActive: !_showTableView, onTap: () => setState(() => _showTableView = false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// CSV column specs for this section's table.
  List<CsvColumnSpec> _buildColumnSpecs() {
    return widget.showStatusChip
        ? const [
            CsvColumnSpec(key: 'item', label: 'Item', required: true, hint: 'Short title for the entry', sampleValue: 'Complete HR onboarding'),
            CsvColumnSpec(key: 'details', label: 'Details', hint: 'Longer description of the entry', sampleValue: 'Submit contracts and setup payroll'),
            CsvColumnSpec(key: 'status', label: 'Status', allowedValues: ['Planned', 'In Progress', 'Completed'], defaultValue: 'Planned', sampleValue: 'Planned'),
          ]
        : const [
            CsvColumnSpec(key: 'item', label: 'Item', required: true, hint: 'Short title for the entry', sampleValue: 'Complete HR onboarding'),
            CsvColumnSpec(key: 'details', label: 'Details', hint: 'Longer description of the entry', sampleValue: 'Submit contracts and setup payroll'),
          ];
  }

  void _showImportForSection(BuildContext context) async {
    final columns = _buildColumnSpecs();
    final rows = await TableImportHelper.showImportDialogSpec(context, tableTitle: widget.title, columns: columns);
    if (rows == null || rows.isEmpty) return;
    for (final parts in rows) {
      widget.onAdd();
    }
  }

  void _downloadTemplateForSection() {
    final columns = _buildColumnSpecs();
    TableImportHelper.downloadTemplateForTable(tableTitle: widget.title, columns: columns);
  }

  Widget _buildCardList() {
    final displayEntries = _filteredEntries;
    if (displayEntries.isEmpty) {
      return ExecutionEmptyState(
        icon: Icons.playlist_add_check_circle_outlined,
        title: _searchQuery.isNotEmpty ? 'No matching entries' : 'Nothing added yet',
        description: _searchQuery.isNotEmpty ? 'Try a different search term.' : widget.emptyLabel,
        actions: _searchQuery.isEmpty ? [
          FilledButton.icon(
            onPressed: widget.onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add first item'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ] : [],
      );
    }

    return Column(
      children: [
        for (int i = 0; i < displayEntries.length; i++) ...[
          _LaunchEntryCard(
            entry: displayEntries[i],
            showStatusChip: widget.showStatusChip,
            onEdit: widget.onEdit != null ? () => widget.onEdit!(i, displayEntries[i]) : null,
            onDuplicate: widget.onDuplicate != null ? () => widget.onDuplicate!(i) : null,
            onRemove: () => widget.onRemove(i),
          ),
          if (i != displayEntries.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildTable() {
    final displayEntries = _filteredEntries;
    const TextStyle cellStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827), height: 1.35);
    const TextStyle detailStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF4B5563), height: 1.45);

    final List<_TableColumn> columns = widget.showStatusChip
        ? [
            const _TableColumn(label: 'Item', flex: 4),
            const _TableColumn(label: 'Details', flex: 5),
            const _TableColumn(label: 'Status', flex: 3),
            _TableColumn(label: 'Actions', flex: widget.onEdit != null || widget.onDuplicate != null ? 2 : 1, align: TextAlign.center),
          ]
        : [
            const _TableColumn(label: 'Item', flex: 5),
            const _TableColumn(label: 'Details', flex: 6),
            _TableColumn(label: 'Actions', flex: widget.onEdit != null || widget.onDuplicate != null ? 2 : 1, align: TextAlign.center),
          ];

    if (displayEntries.isEmpty) {
      return ExecutionEmptyState(
        icon: Icons.playlist_add_check_circle_outlined,
        title: _searchQuery.isNotEmpty ? 'No matching entries' : 'Nothing added yet',
        description: _searchQuery.isNotEmpty ? 'Try a different search term.' : widget.emptyLabel,
      );
    }

    return Column(
      children: [
        // Yellow theme header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFD97706),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              for (final column in columns)
                Expanded(
                  flex: column.flex,
                  child: Text(
                    column.label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF), letterSpacing: 0.3),
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
              color: const Color(0xFFFFFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < displayEntries.length; i++) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    color: i.isEven ? Colors.white : const Color(0xFFF9FAFB),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: columns[0].flex,
                          child: Text(displayEntries[i].title, style: cellStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          flex: columns[1].flex,
                          child: Text(
                            displayEntries[i].details.isNotEmpty ? displayEntries[i].details : 'Not set',
                            style: detailStyle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.showStatusChip)
                          Expanded(
                            flex: columns[2].flex,
                            child: (displayEntries[i].status ?? '').trim().isNotEmpty
                                ? Align(alignment: Alignment.centerLeft, child: ExecutionStatusBadge(label: displayEntries[i].status!))
                                : const Text('Not set', style: detailStyle),
                          ),
                        Expanded(
                          flex: columns.last.flex,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: _SectionRowMenu(
                              onEdit: widget.onEdit != null ? () => widget.onEdit!(i, displayEntries[i]) : null,
                              onDuplicate: widget.onDuplicate != null ? () => widget.onDuplicate!(i) : null,
                              onDelete: () => widget.onRemove(i),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != displayEntries.length - 1)
                    const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── View Toggle Button ─────────────────────────────────────────────────────
class _ViewBtn extends StatelessWidget {
  const _ViewBtn({required this.icon, required this.isActive, required this.onTap});
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFC812) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 16, color: isActive ? Colors.white : const Color(0xFF6B7280)),
      ),
    );
  }
}

// ── Entry Card ─────────────────────────────────────────────────────────────
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
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.08),
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
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827), height: 1.3),
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF4B5563), height: 1.45),
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

// ── Row Action Menu ────────────────────────────────────────────────────────
enum _SectionRowAction { edit, duplicate, delete }

class _SectionRowMenu extends StatelessWidget {
  const _SectionRowMenu({required this.onDelete, this.onEdit, this.onDuplicate});

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
              child: _ActionMenuItem(icon: Icons.edit_outlined, label: 'Edit'),
            ),
          if (onDuplicate != null)
            const PopupMenuItem<_SectionRowAction>(
              value: _SectionRowAction.duplicate,
              child: _ActionMenuItem(icon: Icons.copy_all_outlined, label: 'Duplicate'),
            ),
          const PopupMenuItem<_SectionRowAction>(
            value: _SectionRowAction.delete,
            child: _ActionMenuItem(icon: Icons.delete_outline, label: 'Delete'),
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
            Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
            SizedBox(width: 6),
            Icon(Icons.more_horiz, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}

class _ActionMenuItem extends StatelessWidget {
  const _ActionMenuItem({required this.icon, required this.label});
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
      title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Table Column Definition ────────────────────────────────────────────────
class _TableColumn {
  const _TableColumn({required this.label, required this.flex, this.align = TextAlign.left});
  final String label;
  final int flex;
  final TextAlign align;
}

// ── Add/Edit Entry Dialog ──────────────────────────────────────────────────
Future<LaunchEntry?> showLaunchEntryDialog(
  BuildContext context, {
  String titleLabel = 'Title',
  String detailsLabel = 'Details',
  bool includeStatus = true,
  LaunchEntry? initialEntry,
}) {
  final TextEditingController titleController = TextEditingController(text: initialEntry?.title ?? '');
  final TextEditingController detailsController = TextEditingController(text: initialEntry?.details ?? '');
  final TextEditingController statusController = TextEditingController(text: initialEntry?.status ?? '');
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  const BorderSide neutralBorder = BorderSide(color: Color(0xFFE2E8F0));
  final InputDecoration fieldDecoration = InputDecoration(
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: neutralBorder),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: neutralBorder),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFDC2626))),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );

  return showExecutionEditorSheet<LaunchEntry>(
    context: context,
    title: initialEntry == null ? 'Add entry' : 'Edit entry',
    subtitle: 'Capture clear execution details with a title, supporting context, and an optional status.',
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
              if (value == null || value.trim().isEmpty) return 'Please enter a $titleLabel';
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
              decoration: fieldDecoration.copyWith(labelText: 'Status (optional)'),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      FilledButton.icon(
        onPressed: () {
          if (!formKey.currentState!.validate()) return;
          Navigator.of(context).pop(
            LaunchEntry(
              title: titleController.text.trim(),
              details: detailsController.text.trim(),
              status: includeStatus && statusController.text.trim().isNotEmpty ? statusController.text.trim() : null,
            ),
          );
        },
        icon: const Icon(Icons.check, size: 18),
        label: const Text('Save'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}
