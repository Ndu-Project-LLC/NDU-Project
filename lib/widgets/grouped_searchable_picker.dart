import 'package:flutter/material.dart';

/// One heading plus the options listed under it.
class PickerSection {
  const PickerSection({required this.label, required this.options});

  /// Section heading, e.g. a discipline name.
  final String label;

  /// The options shown beneath [label], in display order.
  final List<String> options;
}

/// A dropdown replacement built for very long option lists.
///
/// The field shows the current value; tapping it opens a dialog with a search
/// box and every option grouped under its [PickerSection] heading. Typing
/// filters across all sections at once and hides headings that no longer
/// match, so a 600-entry list stays usable.
class GroupedSearchablePicker extends StatelessWidget {
  const GroupedSearchablePicker({
    super.key,
    required this.sections,
    required this.value,
    required this.onChanged,
    this.hintText = 'Select an option',
    this.fieldKey,
    this.menuHeight = 420,
  });

  /// Grouped options. Each option must be unique across all sections.
  final List<PickerSection> sections;

  /// Currently selected option, or null when nothing is selected yet.
  final String? value;

  final ValueChanged<String> onChanged;
  final String hintText;
  final Key? fieldKey;

  /// Preferred height of the scrollable option list inside the dialog; the
  /// list shrinks to fit a short screen.
  final double menuHeight;

  int get _optionCount =>
      sections.fold(0, (total, section) => total + section.options.length);

  Future<void> _open(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _GroupedSearchPickerDialog(
        sections: sections,
        selected: value,
        optionCount: _optionCount,
        searchHint: hintText,
        menuHeight: menuHeight,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final current = value;
    final hasValue = current != null && current.trim().isNotEmpty;
    final shown = hasValue ? current : hintText;

    return Semantics(
      button: true,
      label: shown,
      child: InkWell(
        key: fieldKey,
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.fromLTRB(12, 14, 8, 14),
            suffixIcon: Icon(Icons.arrow_drop_down),
          ),
          child: Text(
            shown,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color:
                  hasValue ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupedSearchPickerDialog extends StatefulWidget {
  const _GroupedSearchPickerDialog({
    required this.sections,
    required this.selected,
    required this.optionCount,
    required this.searchHint,
    required this.menuHeight,
  });

  final List<PickerSection> sections;
  final String? selected;
  final int optionCount;
  final String searchHint;
  final double menuHeight;

  @override
  State<_GroupedSearchPickerDialog> createState() =>
      _GroupedSearchPickerDialogState();
}

class _GroupedSearchPickerDialogState
    extends State<_GroupedSearchPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<PickerSection> _visible = widget.sections;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PickerSection> _filter(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return widget.sections;
    return [
      for (final section in widget.sections)
        if (section.options.any((o) => o.toLowerCase().contains(query)))
          PickerSection(
            label: section.label,
            options: section.options
                .where((o) => o.toLowerCase().contains(query))
                .toList(growable: false),
          ),
    ];
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      _visible = _filter(value);
    });
  }

  int get _matchCount =>
      _visible.fold(0, (total, section) => total + section.options.length);

  @override
  Widget build(BuildContext context) {
    final rows = <_PickerRow>[
      for (final section in _visible) ...[
        _PickerRow.header(section.label),
        for (final option in section.options) _PickerRow.option(option),
      ],
    ];

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.badge_outlined, color: Color(0xFFFFC812)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Select a role')),
          Text(
            '${widget.optionCount}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
      // The list takes whatever height the dialog can spare (capped at
      // menuHeight), so the picker never overflows a short screen.
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.menuHeight + 96),
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onQueryChanged('');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _query.isEmpty
                    ? '${widget.optionCount} options — type to filter'
                    : '$_matchCount of ${widget.optionCount} match "$_query"',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: rows.isEmpty
                    ? const Center(
                        child: Text(
                          'No roles match your search.',
                          style:
                              TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          if (row.header) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                              child: Text(
                                row.value.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            );
                          }
                          final isSelected = row.value == widget.selected;
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            selected: isSelected,
                            selectedTileColor: const Color(0xFFFFF4CC),
                            title: Text(
                              row.value,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check,
                                    size: 18, color: Color(0xFFD97706))
                                : null,
                            onTap: () => Navigator.of(context).pop(row.value),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _PickerRow {
  const _PickerRow.header(this.value) : header = true;
  const _PickerRow.option(this.value) : header = false;

  final String value;
  final bool header;
}
