/// Scope-impact picker for a change request, drawn from the live WBS.
///
/// Product rule (voice note, 2026-09-10):
///
/// > "on the scope impact, you should be able to choose which scope is attached
/// > to that change that you are making. So it's supposed to draw things that
/// > are also on the work breakdown structures."
///
/// Every change-request entry point in the app has to offer that — not just the
/// long-form Create CR tab. The register's one-tap "Quick CR", for one, shipped
/// with no scope picker at all, so a change raised that way could never say
/// which scope it touched even though the WBS knew.
///
/// This is that picker, shared: a searchable, multi-select chip list over the
/// project's real work breakdown structure (`wbsScopeLabels` walks the tree the
/// WBS module manages), with the empty state pointing at the WBS rather than
/// inventing scope. It never fabricates a representative package list.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/utils/wbs_scope_labels.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';

class ChangeRequestScopePicker extends StatefulWidget {
  const ChangeRequestScopePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.maxVisibleChips = 10,
    this.accent = const Color(0xFFD97706),
  });

  /// The labels currently attached to the change (mutated through [onChanged]).
  final Set<String> selected;

  /// Called with the new selection whenever the user toggles a package.
  final ValueChanged<Set<String>> onChanged;

  /// How many packages render as chips before the rest move behind a "More"
  /// dropdown. Searching shows every match, since the query already narrowed it.
  final int maxVisibleChips;

  final Color accent;

  @override
  State<ChangeRequestScopePicker> createState() =>
      _ChangeRequestScopePickerState();
}

class _ChangeRequestScopePickerState extends State<ChangeRequestScopePicker> {
  static const _border = Color(0xFFE4E7EC);
  static const _bg = Color(0xFFF9FAFB);
  static const _textPrimary = Color(0xFF1A1D1F);
  static const _textSecondary = Color(0xFF6B7280);

  final TextEditingController _searchCtrl = SpellCheckTextEditingController();

  /// Project whose WBS this picker has loaded — so switching project reloads
  /// instead of leaving another project's scope on screen.
  String? _loadedProjectId;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_ensureLoaded());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureLoaded() async {
    if (_loading || !mounted) return;
    WBSProvider provider;
    try {
      provider = context.read<WBSProvider>();
    } catch (_) {
      return; // No WBS provider in scope — the empty state stands.
    }

    final String projectId;
    try {
      projectId = (ProjectDataHelper.getData(context).projectId ?? '').trim();
    } catch (_) {
      return;
    }
    if (projectId.isEmpty || projectId == _loadedProjectId) return;

    _loading = true;
    try {
      await provider.ensureProjectLoaded(projectId);
      _loadedProjectId = projectId;
      if (mounted) setState(() {});
    } catch (_) {
      // The WBS is optional context for a change request — never block it.
    } finally {
      _loading = false;
    }
  }

  /// Packages offered, straight from the WBS tree. Empty when there is no WBS
  /// yet — callers show an empty state, they never get an invented list.
  List<String> get _options {
    try {
      return wbsScopeLabels(context.watch<WBSProvider>().wbs);
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final query = _searchCtrl.text.trim().toLowerCase();
    final matching = query.isEmpty
        ? options
        : options.where((o) => o.toLowerCase().contains(query)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'AFFECTED WORK PACKAGES (multi-select)',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            if (options.isNotEmpty)
              Text(
                'from the WBS · ${options.length} packages',
                style: const TextStyle(color: _textSecondary, fontSize: 10),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search work packages (e.g. electrical)',
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            filled: true,
            fillColor: _bg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            TextButton.icon(
              onPressed: options.isEmpty
                  ? null
                  : () => widget.onChanged({...widget.selected, ...options}),
              icon: const Icon(Icons.select_all, size: 14),
              label: const Text('Select all'),
              style: TextButton.styleFrom(
                foregroundColor: widget.accent,
                visualDensity: VisualDensity.compact,
              ),
            ),
            TextButton.icon(
              onPressed: widget.selected.isEmpty
                  ? null
                  : () => widget.onChanged(<String>{}),
              icon: const Icon(Icons.deselect, size: 14),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                foregroundColor: _textSecondary,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const Spacer(),
            Text(
              '${widget.selected.length} selected',
              style: TextStyle(
                color: widget.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (options.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No work packages yet. Build the WBS module first so this change '
              'can be attached to real scope.',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          )
        else if (matching.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No work packages match "$query".',
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
          )
        else
          _chips(matching, query.isNotEmpty),
      ],
    );
  }

  Widget _chips(List<String> matching, bool searching) {
    final showAll = searching || matching.length <= widget.maxVisibleChips;
    final visible =
        showAll ? matching : matching.take(widget.maxVisibleChips).toList();
    final hidden = showAll
        ? const <String>[]
        : matching.skip(widget.maxVisibleChips).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: visible.map(_chip).toList(growable: false),
        ),
        if (hidden.isNotEmpty) ...[
          const SizedBox(height: 8),
          _MorePackagesDropdown(
            hidden: hidden,
            selected: widget.selected,
            accent: widget.accent,
            onToggled: (label, on) {
              final next = {...widget.selected};
              if (on) {
                next.add(label);
              } else {
                next.remove(label);
              }
              widget.onChanged(next);
            },
          ),
        ],
      ],
    );
  }

  Widget _chip(String label) {
    final selected = widget.selected.contains(label);
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : _textPrimary,
        ),
      ),
      selected: selected,
      onSelected: (on) {
        final next = {...widget.selected};
        if (on) {
          next.add(label);
        } else {
          next.remove(label);
        }
        widget.onChanged(next);
      },
      selectedColor: widget.accent,
      checkmarkColor: Colors.white,
      backgroundColor: _bg,
      side: const BorderSide(color: _border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }
}

/// The remaining packages, behind a "More (N)" menu once the chip list would
/// take over the form.
class _MorePackagesDropdown extends StatelessWidget {
  const _MorePackagesDropdown({
    required this.hidden,
    required this.selected,
    required this.accent,
    required this.onToggled,
  });

  final List<String> hidden;
  final Set<String> selected;
  final Color accent;
  final void Function(String label, bool selected) onToggled;

  @override
  Widget build(BuildContext context) {
    final selectedHidden = hidden.where(selected.contains).length;
    return PopupMenuButton<String>(
      tooltip: 'Show the remaining work packages',
      onSelected: (label) => onToggled(label, !selected.contains(label)),
      itemBuilder: (context) => hidden
          .map((label) => PopupMenuItem<String>(
                value: label,
                child: Row(
                  children: [
                    Icon(
                      selected.contains(label)
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz, size: 16, color: accent),
            const SizedBox(width: 6),
            Text(
              selectedHidden > 0
                  ? 'More (${hidden.length}) · $selectedHidden selected'
                  : 'More (${hidden.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
