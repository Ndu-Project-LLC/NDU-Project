/// Cross-cutting UX primitives introduced in Phase 1 of the application-wide
/// "tables / save / delete" hardening initiative.
///
/// This file provides THREE reusable building blocks that the rest of the
/// codebase can adopt incrementally, screen-by-screen:
///
/// 1. [ExpandableDataTable] — a scrollable DataTable where each row can be
///    tapped to expand an inline detail panel. Combines the existing
///    [ResponsiveDataTableWrapper] (horizontal + vertical scroll) with an
///    expand/collapse row affordance. Addresses the "all tables should be
///    scrollable AND expandable" requirement.
///
/// 2. [UnsavedChangesGuard] — a [PopScope] wrapper that intercepts page
///    navigation when there are unsaved changes, shows a "Save before
///    leaving?" dialog, and flushes any pending debounced save before
///    allowing the pop. Addresses the "manual save popup before leaving"
///    requirement.
///
/// 3. [confirmAndDelete] — a single helper that shows the existing
///    [showDeleteConfirmationDialog], executes the caller's delete callback,
///    and then shows a standardized success SnackBar confirming the item
///    was deleted. Addresses the "confirmation that the item has been
///    deleted" requirement.
///
/// Design intent: these primitives are opt-in. Existing screens continue to
/// work unchanged. Migration happens screen-by-screen in subsequent phases.

library;

import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/widgets/responsive_table_widgets.dart';
import 'package:ndu_project/widgets/wrapped_table_primitives.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 1. EXPANDABLE DATA TABLE
// ═══════════════════════════════════════════════════════════════════════════

/// A [DataTable] that is:
///   - horizontally scrollable (via [ResponsiveDataTableWrapper])
///   - vertically scrollable (optional, via [maxHeight])
///   - **row-expandable**: tapping the leading chevron on any row reveals an
///     inline detail panel returned by [rowDetailBuilder].
///
/// Use this anywhere you currently use `buildNduTableWithExpand` AND want to
/// give users the ability to drill into a row's details without leaving the
/// page. If [rowDetailBuilder] is null, the table behaves exactly like
/// [buildNduTableWithExpand] (scrollable + fullscreen-expand button only),
/// so this is a safe drop-in replacement.
///
/// The expand state is tracked by row index and is preserved across rebuilds
/// until the widget is disposed.
class ExpandableDataTable extends StatefulWidget {
  const ExpandableDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.title,
    this.rowDetailBuilder,
    this.columnSpacing = 18,
    this.horizontalMargin = 14,
    this.headingRowHeight = 52,
    this.dataRowMinHeight = 60,
    this.dataRowMaxHeight = 220,
    this.minWidth,
    this.maxHeight,
    this.showExpandButton = true,
    this.showRowExpanders = true,
    this.expandedRowColor,
  });

  /// Table columns. Pass the same value you would pass to [DataTable].
  final List<DataColumn> columns;

  /// Table rows. Pass the same value you would pass to [DataTable].
  ///
  /// Each row's [DataCell]s are rendered as-is. The expander chevron is
  /// prepended automatically as a non-data leading cell when
  /// [showRowExpanders] is true and [rowDetailBuilder] is non-null.
  final List<DataRow> rows;

  /// Title shown in the fullscreen dialog header.
  final String? title;

  /// If non-null, tapping a row's chevron expands an inline panel below
  /// the row. The builder receives the row index. Return null to indicate
  /// this row has no detail (no chevron is shown for that row).
  final Widget? Function(int index)? rowDetailBuilder;

  // Visual tokens — forwarded to the underlying DataTable.
  final double columnSpacing;
  final double horizontalMargin;
  final double headingRowHeight;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final double? minWidth;
  final double? maxHeight;
  final bool showExpandButton;

  /// Whether to show the leading chevron affordance on each row that has
  /// a non-null [rowDetailBuilder] result. Defaults to true. Set to false
  /// if you want to drive expansion some other way (e.g. tapping the whole
  /// row) — in that case use [ExpandableDataTableController] instead.
  final bool showRowExpanders;

  /// Background color applied to expanded detail panels. Defaults to a
  /// subtle surface tint.
  final Color? expandedRowColor;

  @override
  State<ExpandableDataTable> createState() => _ExpandableDataTableState();
}

class _ExpandableDataTableState extends State<ExpandableDataTable> {
  final Set<int> _expanded = {};

  bool _hasDetail(int index) {
    final builder = widget.rowDetailBuilder;
    if (builder == null) return false;
    return builder(index) != null;
  }

  Widget? _detail(int index) {
    return widget.rowDetailBuilder?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    // If no row-detail builder is provided, fall back to the plain
    // scrollable + fullscreen-expand table (identical to buildNduTableWithExpand).
    if (widget.rowDetailBuilder == null) {
      return buildNduTableWithExpand(
        context: context,
        columns: widget.columns,
        rows: widget.rows,
        title: widget.title,
        columnSpacing: widget.columnSpacing,
        horizontalMargin: widget.horizontalMargin,
        headingRowHeight: widget.headingRowHeight,
        dataRowMinHeight: widget.dataRowMinHeight,
        dataRowMaxHeight: widget.dataRowMaxHeight,
        minWidth: widget.minWidth,
        maxHeight: widget.maxHeight,
        showExpandButton: widget.showExpandButton,
      );
    }

    // Build a row-augmented DataTable where each expandable row carries an
    // expansion chevron in its first cell and, when expanded, renders the
    // detail widget directly below it inside the same scrollable viewport.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expandedBg = widget.expandedRowColor ??
        (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC));

    // We render the table as a custom scrollable column of rows so we can
    // interleave detail panels between data rows. This gives us full
    // control over expansion visuals while keeping the DataTable look.
    return _ExpandableTableRenderer(
      columns: widget.columns,
      rows: widget.rows,
      expanded: _expanded,
      hasDetail: _hasDetail,
      detailFor: _detail,
      onToggle: (i) => setState(() {
        if (_expanded.contains(i)) {
          _expanded.remove(i);
        } else {
          _expanded.add(i);
        }
      }),
      showRowExpanders: widget.showRowExpanders,
      showExpandButton: widget.showExpandButton,
      title: widget.title,
      columnSpacing: widget.columnSpacing,
      horizontalMargin: widget.horizontalMargin,
      headingRowHeight: widget.headingRowHeight,
      dataRowMinHeight: widget.dataRowMinHeight,
      dataRowMaxHeight: widget.dataRowMaxHeight,
      minWidth: widget.minWidth,
      maxHeight: widget.maxHeight,
      expandedRowColor: expandedBg,
      isDark: isDark,
      context: context,
    );
  }
}

/// Renders the expandable table body. Separated from the State to keep the
/// build method readable.
class _ExpandableTableRenderer extends StatelessWidget {
  const _ExpandableTableRenderer({
    required this.columns,
    required this.rows,
    required this.expanded,
    required this.hasDetail,
    required this.detailFor,
    required this.onToggle,
    required this.showRowExpanders,
    required this.showExpandButton,
    required this.title,
    required this.columnSpacing,
    required this.horizontalMargin,
    required this.headingRowHeight,
    required this.dataRowMinHeight,
    required this.dataRowMaxHeight,
    required this.minWidth,
    required this.maxHeight,
    required this.expandedRowColor,
    required this.isDark,
    required this.context,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final Set<int> expanded;
  final bool Function(int) hasDetail;
  final Widget? Function(int) detailFor;
  final ValueChanged<int> onToggle;
  final bool showRowExpanders;
  final bool showExpandButton;
  final String? title;
  final double columnSpacing;
  final double horizontalMargin;
  final double headingRowHeight;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final double? minWidth;
  final double? maxHeight;
  final Color expandedRowColor;
  final bool isDark;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    // Header row — sticky-feel via a wrapped Container with the heading
    // background. We replicate the buildNduDataTable heading styling.
    final headingColor =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFF5F8FC);
    final headingTextStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
      letterSpacing: 0.2,
    );
    final dataTextStyle = TextStyle(
      fontSize: 13,
      height: 1.45,
      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
    );
    final dividerColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    // Compute column widths: the leading expander column is fixed at 48px;
    // remaining columns share the available width proportionally using their
    // DataColumn.intrinsicWidth if set, otherwise flex 1.
    final hasExpanders = showRowExpanders &&
        List.generate(rows.length, (i) => i).any((i) => hasDetail(i));
    final leadingWidth = hasExpanders ? 48.0 : 0.0;
    final visibleColumns = columns;

    Widget buildHeader() {
      return Container(
        color: headingColor,
        height: headingRowHeight,
        padding: EdgeInsets.only(left: horizontalMargin, right: horizontalMargin),
        child: Row(
          children: [
            if (hasExpanders) SizedBox(width: leadingWidth),
            ...visibleColumns.map((c) => Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DefaultTextStyle(
                      style: headingTextStyle,
                      child: c.label,
                    ),
                  ),
                )),
          ],
        ),
      );
    }

    Widget buildRow(int index) {
      final row = rows[index];
      final isExpanded = expanded.contains(index);
      final canExpand = hasDetail(index);
      final rowBg = isExpanded
          ? expandedRowColor
          : (index.isOdd
              ? (isDark ? const Color(0xFF161B22) : const Color(0xFFFAFBFC))
              : Colors.transparent);

      return Column(
        children: [
          // Data row
          Container(
            color: rowBg,
            constraints: BoxConstraints(
              minHeight: dataRowMinHeight,
              maxHeight: isExpanded ? dataRowMaxHeight : dataRowMaxHeight,
            ),
            padding: EdgeInsets.only(
                left: horizontalMargin, right: horizontalMargin),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasExpanders)
                  SizedBox(
                    width: leadingWidth,
                    child: canExpand
                        ? IconButton(
                            icon: Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.keyboard_arrow_right_rounded,
                              size: 20,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            onPressed: () => onToggle(index),
                            tooltip: isExpanded ? 'Collapse' : 'Expand',
                          )
                        : const SizedBox.shrink(),
                  ),
                ...row.cells.asMap().entries.map((entry) {
                  final cell = entry.value;
                  return Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: DefaultTextStyle(
                        style: dataTextStyle,
                        child: cell.child,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // Expanded detail panel
          if (isExpanded && canExpand) ...[
            Container(
              width: double.infinity,
              color: expandedRowColor,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: detailFor(index) ?? const SizedBox.shrink(),
            ),
          ],
          // Divider
          Container(height: 0.8, color: dividerColor),
        ],
      );
    }

    // Build the scrollable body
    final tableBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildHeader(),
        ...List.generate(rows.length, buildRow),
      ],
    );

    // Wrap in horizontal + vertical scroll
    final scrollable = ResponsiveDataTableWrapper(
      minWidth: minWidth,
      maxHeight: maxHeight,
      child: tableBody,
    );

    // Wrap in fullscreen expand button if requested
    if (!showExpandButton) {
      return scrollable;
    }
    return FullScreenTableWrapper(
      title: title,
      child: scrollable,
      tableBuilder: (fsContext) => buildNduDataTable(
        context: fsContext,
        columns: columns,
        rows: rows,
        columnSpacing: columnSpacing + 6,
        horizontalMargin: horizontalMargin + 6,
        headingRowHeight: headingRowHeight + 8,
        dataRowMinHeight: dataRowMinHeight + 8,
        dataRowMaxHeight: dataRowMaxHeight + 80,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. UNSAVED CHANGES GUARD
// ═══════════════════════════════════════════════════════════════════════════

/// A [PopScope] wrapper that intercepts page-back navigation when there are
/// unsaved changes and prompts the user to save before leaving.
///
/// Usage:
/// ```dart
/// return UnsavedChangesGuard(
///   isDirty: () => _autoSaveTimer?.isActive ?? _hasUnsavedEdits,
///   onSave: () => _flushSaveNow(),   // must complete the save synchronously
///   child: MyScreenBody(...),
/// );
/// ```
///
/// Behaviour:
///   - When the user attempts to navigate back (system back button, app bar
///     back arrow, or programmatic `Navigator.pop`) AND [isDirty] returns
///     true, a dialog appears with three options: **Save**, **Don't save**,
///     and **Cancel**.
///   - **Save**: calls [onSave], awaits any Future it returns, then allows
///     the pop. Shows a "Changes saved" confirmation SnackBar after the pop.
///   - **Don't save**: allows the pop immediately without saving.
///   - **Cancel**: stays on the page (pop is prevented).
///
/// This is the application-wide primitive for the "manual save before
/// leaving a page" requirement. Screens with debounced auto-save should
/// wrap their body in this guard.
class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.isDirty,
    required this.onSave,
    this.title = 'Unsaved changes',
    this.message = 'You have unsaved changes. Would you like to save them before leaving?',
    this.saveLabel = 'Save',
    this.discardLabel = "Don't save",
    this.cancelLabel = 'Cancel',
    this.successMessage = 'Changes saved',
    required this.child,
  });

  /// Returns true if there are unsaved edits (e.g. a debounced save timer
  /// is still pending, or a local "dirty" flag is set).
  final bool Function() isDirty;

  /// Called when the user chooses "Save". Must flush any pending save
  /// synchronously (cancel the debounce timer and persist immediately).
  /// Can return a Future if the save is async — the guard awaits it
  /// before allowing the pop.
  final Future<void> Function() onSave;

  final String title;
  final String message;
  final String saveLabel;
  final String discardLabel;
  final String cancelLabel;
  final String successMessage;

  final Widget child;

  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  bool _isGuarding = true;

  Future<void> _handlePop(bool didPop, dynamic result) async {
    if (didPop) return;
    if (!_isGuarding) return;
    if (!widget.isDirty()) {
      // Nothing to save — allow the pop.
      Navigator.of(context).maybePop();
      return;
    }
    await _showSaveDialog();
  }

  Future<void> _showSaveDialog() async {
    final action = await showDialog<_SaveDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.save_outlined,
                  color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          widget.message,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_SaveDialogAction.cancel),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF4B5563)),
            child: Text(widget.cancelLabel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_SaveDialogAction.discard),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: Text(widget.discardLabel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_SaveDialogAction.save),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(widget.saveLabel),
          ),
        ],
      ),
    );

    switch (action) {
      case _SaveDialogAction.save:
        await widget.onSave();
        // Show success snackbar before popping
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(widget.successMessage),
                ],
              ),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        // Disable guard so the subsequent pop isn't intercepted
        _isGuarding = false;
        if (mounted) Navigator.of(context).maybePop();
        break;
      case _SaveDialogAction.discard:
        _isGuarding = false;
        if (mounted) Navigator.of(context).maybePop();
        break;
      case _SaveDialogAction.cancel:
      default:
        // Stay on page — do nothing.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handlePop(didPop, result),
      child: widget.child,
    );
  }
}

enum _SaveDialogAction { save, discard, cancel }

// ═══════════════════════════════════════════════════════════════════════════
// 3. CONFIRM-AND-DELETE HELPER
// ═══════════════════════════════════════════════════════════════════════════

/// Shows the standard delete-confirmation dialog, runs the caller's delete
/// callback, and then shows a success SnackBar confirming the item was
/// deleted.
///
/// This is the canonical "delete with confirmation + success feedback"
/// primitive. Every deletion in the app should route through this helper
/// so that users ALWAYS see (a) a pre-delete confirmation dialog and
/// (b) a post-delete success confirmation.
///
/// Usage:
/// ```dart
/// onDelete: () => confirmAndDelete(
///   context,
///   title: 'Delete work package',
///   itemLabel: workPackage.name,
///   deleteCallback: () => _provider.removeWorkPackage(workPackage.id),
///   successMessage: 'Work package "${workPackage.name}" deleted',
/// ),
/// ```
///
/// Returns true if the user confirmed and the delete ran, false if the user
/// cancelled.
Future<bool> confirmAndDelete(
  BuildContext context, {
  required String title,
  String? itemLabel,
  String? message,
  String confirmLabel = 'Delete',
  required Future<void> Function() deleteCallback,
  String? successMessage,
  Duration successDuration = const Duration(seconds: 3),
}) async {
  // 1. Pre-delete confirmation dialog
  final confirmed = await showDeleteConfirmationDialog(
    context,
    title: title,
    itemLabel: itemLabel,
    message: message,
    confirmLabel: confirmLabel,
  );
  if (!confirmed) return false;

  // 2. Execute the delete
  try {
    await deleteCallback();
  } catch (e) {
    // Show error snackbar if delete failed
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('Delete failed: $e')),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return false;
  }

  // 3. Post-delete success confirmation SnackBar
  final label = itemLabel?.trim() ?? '';
  final resolvedSuccess = successMessage ??
      (label.isEmpty
          ? 'Item deleted successfully'
          : '"$label" deleted successfully');

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(resolvedSuccess)),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: successDuration,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () =>
              ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }
  return true;
}

/// Variant of [confirmAndDelete] for batch deletions. Shows the count in the
/// success message and uses the batch delete confirmation dialog text.
Future<bool> confirmAndDeleteBatch(
  BuildContext context, {
  required int count,
  required String itemTypeLabel,
  required Future<void> Function() deleteCallback,
  String? successMessage,
}) async {
  if (count <= 0) return false;
  final plural = count == 1 ? itemTypeLabel : '${itemTypeLabel}s';
  return confirmAndDelete(
    context,
    title: 'Delete $count $plural?',
    message: 'This will permanently delete $count $plural. This action cannot be undone.',
    confirmLabel: 'Delete $count',
    deleteCallback: deleteCallback,
    successMessage:
        successMessage ?? '$count $plural deleted successfully',
  );
}
