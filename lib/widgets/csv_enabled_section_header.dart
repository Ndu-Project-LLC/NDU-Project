import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/csv_table_import_button.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';

/// Reusable section header with CSV Import / Download Template functionality.
///
/// This widget encapsulates the common pattern found across NDU Project screens:
/// ```dart
/// Row(
///   mainAxisSize: MainAxisSize.min,
///   children: [
///     CsvTableImportButton(...),
///     SizedBox(width: 8),
///     // Optional add button
///   ],
/// )
/// ```
///
/// ## Usage Patterns
///
/// ### Pattern 1: In _PanelShell trailing (compact mode)
/// ```dart
/// _PanelShell(
///   title: 'My Table',
///   subtitle: 'Table description',
///   trailing: CsvEnabledSectionHeader(
///     tableTitle: 'My Data',
///     columns: _myColumns,
///     onImport: _handleImport,
///     onAdd: _showAddDialog,
///     addLabel: 'Add item',
///     compact: true,
///   ),
///   child: // table content
/// )
/// ```
///
/// ### Pattern 2: Standalone header row (full mode)
/// ```dart
/// CsvEnabledSectionHeader(
///   tableTitle: 'Risk Register',
///   columns: _riskColumns,
///   onImport: _handleImport,
///   onAdd: _showAddDialog,
///   addLabel: 'Add Risk',
///   compact: false,
/// )
/// ```
///
/// ### Pattern 3: CSV import only (no add button)
/// ```dart
/// CsvEnabledSectionHeader(
///   tableTitle: 'Best Practices',
///   columns: _bpColumns,
///   onImport: _handleImport,
/// )
/// ```
class CsvEnabledSectionHeader extends StatelessWidget {
  const CsvEnabledSectionHeader({
    super.key,
    required this.tableTitle,
    required this.columns,
    required this.onImport,
    this.onAdd,
    this.addLabel = 'Add',
    this.compact = false,
    this.addIcon = Icons.add_rounded,
    this.addButtonStyle,
    this.spacing = 8.0,
  });

  /// Title shown in the CSV import dialog header
  final String tableTitle;

  /// Column specifications for CSV mapping and validation
  final List<CsvColumnSpec> columns;

  /// Callback with validated row data when user confirms import
  final ValueChanged<List<Map<String, String>>> onImport;

  /// Optional callback for the "Add" button
  final VoidCallback? onAdd;

  /// Label for the add button (default: 'Add')
  final String addLabel;

  /// When true, renders icon-only buttons (for tight spaces like _PanelShell.trailing)
  ///
  /// Use `compact: true` when placing inside `_PanelShell.trailing` or narrow headers.
  /// Use `compact: false` for standalone section headers with more space.
  final bool compact;

  /// Icon for the add button (default: Icons.add_rounded)
  final IconData addIcon;

  /// Custom style for the add button (overrides default)
  final ButtonStyle? addButtonStyle;

  /// Spacing between CSV buttons and add button (default: 8.0)
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      // CSV Import + Download Template buttons
      CsvTableImportButton(
        compact: compact,
        tableTitle: tableTitle,
        columns: columns,
        onImport: onImport,
      ),
      
      // Optional Add button
      if (onAdd != null) ...[
        SizedBox(width: spacing),
        _buildAddButton(),
      ],
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildAddButton() {
    if (compact) {
      // Compact mode: Icon button matching _PanelShell trailing style
      return IconButton.outlined(
        onPressed: onAdd,
        icon: Icon(addIcon, size: 18),
        style: IconButton.styleFrom(
          foregroundColor: const Color(0xFF4154F1),
          side: const BorderSide(color: Color(0xFFFEF3C7)),
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(36, 36),
        ),
        tooltip: addLabel,
      );
    }

    // Full mode: Outlined button matching standalone header style
    final defaultStyle = OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF4154F1),
      side: const BorderSide(color: Color(0xFFFEF3C7)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

    return OutlinedButton.icon(
      onPressed: onAdd,
      icon: Icon(addIcon, size: 16),
      label: Text(addLabel),
      style: addButtonStyle ?? defaultStyle,
    );
  }
}

/// Extension to easily create a CsvEnabledSectionHeader from an existing
/// CsvTableImportButton usage with minimal code changes.
///
/// Example migration:
/// Before:
/// ```dart
/// Row(
///   mainAxisSize: MainAxisSize.min,
///   children: [
///     CsvTableImportButton(tableTitle: 'X', columns: c, onImport: f),
///     SizedBox(width: 8),
///     TextButton.icon(onPressed: a, icon: Icon(Icons.add), label: Text('Add')),
///   ],
/// )
/// ```
///
/// After:
/// ```dart
/// CsvEnabledSectionHeader(
///   tableTitle: 'X',
///   columns: c,
///   onImport: f,
///   onAdd: a,
///   addLabel: 'Add',
/// )
/// ```
extension CsvEnabledHeaderExtension on CsvEnabledSectionHeader {
  /// Creates a copy with only the CSV import (no add button)
  CsvEnabledSectionHeader copyWithoutAdd() {
    return CsvEnabledSectionHeader(
      tableTitle: tableTitle,
      columns: columns,
      onImport: onImport,
      compact: compact,
      spacing: spacing,
    );
  }

  /// Creates a copy with a different add button configuration
  CsvEnabledSectionHeader copyWithAdd({
    VoidCallback? onAdd,
    String? addLabel,
    IconData? addIcon,
  }) {
    return CsvEnabledSectionHeader(
      tableTitle: tableTitle,
      columns: columns,
      onImport: onImport,
      onAdd: onAdd ?? this.onAdd,
      addLabel: addLabel ?? this.addLabel,
      addIcon: addIcon ?? this.addIcon,
      compact: compact,
      spacing: spacing,
    );
  }
}
