import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/utils/download_helper.dart';
import 'package:ndu_project/widgets/csv_import_dialog.dart';

/// A compact "Import CSV / XLSX" button with a companion "Download Template"
/// button, designed for custom table sections.
///
/// Usage:
/// ```dart
/// CsvTableImportButton(
///   tableTitle: 'Execution Tools',
///   columns: [
///     CsvColumnSpec(key: 'tool', label: 'Execution Tool', required: true),
///     CsvColumnSpec(key: 'description', label: 'Description', required: true),
///   ],
///   onImport: (rows) {
///     for (final row in rows) {
///       // Add each row to your data source
///     }
///   },
/// )
/// ```
class CsvTableImportButton extends StatelessWidget {
  const CsvTableImportButton({
    super.key,
    required this.tableTitle,
    required this.columns,
    required this.onImport,
    this.compact = false,
  });

  /// Title shown in the CSV import dialog header
  final String tableTitle;

  /// Column specifications for CSV mapping and validation
  final List<CsvColumnSpec> columns;

  /// Callback with validated row data when user confirms import
  final ValueChanged<List<Map<String, String>>> onImport;

  /// When true, renders a smaller icon-only button (for tight spaces)
  final bool compact;

  void _downloadTemplate() {
    final csv = CsvImportHelper.generateTemplate(columns);
    final filename = CsvImportHelper.templateFilename(tableTitle);
    downloadFile(
      utf8.encode(csv),
      filename,
      mimeType: 'text/csv',
    );
  }

  @override
  Widget build(BuildContext context) {
    Future<void> handleImport() async {
      final result = await showCsvImportDialog(
        context,
        tableTitle: tableTitle,
        columns: columns,
      );
      if (result != null && result.isNotEmpty) {
        onImport(result);
      }
    }

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Import CSV/XLSX',
            child: IconButton.outlined(
              onPressed: handleImport,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFFD97706),
                side: const BorderSide(color: Color(0xFFFDE68A)),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(36, 36),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Download Template',
            child: IconButton.outlined(
              onPressed: _downloadTemplate,
              icon: const Icon(Icons.download, size: 18),
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFF4B5563),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(36, 36),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: handleImport,
          icon: const Icon(Icons.upload_file_outlined, size: 16),
          label: const Text('Import CSV/XLSX'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            foregroundColor: const Color(0xFFD97706),
            side: const BorderSide(color: Color(0xFFFDE68A)),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _downloadTemplate,
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Download Template'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            foregroundColor: const Color(0xFF4B5563),
            side: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
        ),
      ],
    );
  }
}
