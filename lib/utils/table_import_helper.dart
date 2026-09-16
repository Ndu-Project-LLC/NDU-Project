import 'dart:convert';
import 'dart:typed_data';
import 'package:ndu_project/utils/download_helper_stub.dart'
    if (dart.library.html) 'package:ndu_project/utils/download_helper_web.dart' as loader;
import 'package:ndu_project/utils/csv_import_helper.dart';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/widgets/spell_check/spell_checking_text_controller.dart';

/// Reusable helper for table-level CSV/Excel import + template download.
///
/// Provides two world-class features:
/// 1. **Download Template** — generates a downloadable .csv file with
///    column headers + sample rows, so users know exactly what format
///    the table expects.
/// 2. **Upload & Import** — opens a file picker for .csv/.xlsx/.txt files,
///    reads the content, and returns parsed rows as a List<Map>.
///
/// Usage (rich CsvColumnSpec — preferred for new code):
/// ```dart
/// TableImportHelper.downloadTemplateSpec(
///   filename: 'coverage_matrix_template.csv',
///   columns: [
///     CsvColumnSpec(key: 'area', label: 'Role/Area', required: true,
///         hint: 'e.g. Product, Engineering', sampleValue: 'Product'),
///     CsvColumnSpec(key: 'status', label: 'Status',
///         allowedValues: ['On track','At risk','In review','Blocked'],
///         defaultValue: 'On track'),
///   ],
/// );
/// ```
///
/// Usage (legacy simple headers — still supported):
/// ```dart
/// TableImportHelper.downloadTemplate(
///   filename: 'staffing_template.csv',
///   headers: ['Role', 'Qty', 'Type', 'Start Date', 'Duration', 'Monthly Rate', 'Status'],
///   sampleRows: [
///     ['Project Manager', '1', 'Internal', 'Jan 2024', '6', '4000', 'Active'],
///     ['Technical Lead', '2', 'Internal', 'Jan 2024', '8', '5000', 'Active'],
///   ],
/// );
/// ```
class TableImportHelper {
  TableImportHelper._();

  /// Generates a CSV string from headers + sample rows.
  static String generateCsv({
    required List<String> headers,
    required List<List<String>> sampleRows,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));
    for (final row in sampleRows) {
      buffer.writeln(row.join(','));
    }
    return buffer.toString();
  }

  /// Triggers a browser download of a .csv template file with the given
  /// headers and sample rows. On web, this creates a Blob and clicks a
  /// hidden download link.
  static void downloadTemplate({
    required String filename,
    required List<String> headers,
    required List<List<String>> sampleRows,
  }) {
    final csv = generateCsv(headers: headers, sampleRows: sampleRows);
    final bytes = utf8.encode(csv);
    loader.downloadFile(bytes, filename, mimeType: 'text/csv');
    debugPrint('[TableImportHelper] Template downloaded: $filename');
  }

  // ─── Rich CsvColumnSpec-based variants (preferred) ──────────────────────

  /// Generates a rich CSV template string from [CsvColumnSpec] columns.
  /// The template includes:
  /// - A leading comment row with hints (required flag, allowed values, hint)
  /// - A header row matching each column's [CsvColumnSpec.label]
  /// - A sample data row using [CsvColumnSpec.sampleValue] (or the first
  ///   allowed value, or '(required)' if required)
  /// - A second sample row showing an alternative allowed value (if any)
  ///
  /// The generated template mirrors the on-page table column structure
  /// exactly, so users can fill it in and re-upload with confidence.
  static String generateCsvFromSpec(List<CsvColumnSpec> columns) {
    return CsvImportHelper.generateTemplate(columns);
  }

  /// Generates a filename-safe template name from a table title.
  static String templateFilenameFromTitle(String tableTitle) {
    return CsvImportHelper.templateFilename(tableTitle);
  }

  /// Triggers a browser download of a CSV template built from rich
  /// [CsvColumnSpec] columns. This is the preferred download method for
  /// new code because it produces a template with hints, allowed values,
  /// and required-field markers — fully mirroring the on-page table.
  static void downloadTemplateSpec({
    required String filename,
    required List<CsvColumnSpec> columns,
  }) {
    final csv = generateCsvFromSpec(columns);
    final bytes = utf8.encode(csv);
    loader.downloadFile(bytes, filename, mimeType: 'text/csv');
    debugPrint(
        '[TableImportHelper] Spec template downloaded: $filename (${columns.length} columns)');
  }

  /// Convenience wrapper: downloads the two-sheet Excel template for a named
  /// table, deriving the filename from [tableTitle].
  static void downloadExcelTemplateForTable({
    required String tableTitle,
    required List<CsvColumnSpec> columns,
  }) {
    downloadExcelTemplate(tableTitle: tableTitle, columns: columns);
  }

  /// Convenience wrapper that derives the filename from [tableTitle] and
  /// downloads the template using [CsvColumnSpec] columns.
  static void downloadTemplateForTable({
    required String tableTitle,
    required List<CsvColumnSpec> columns,
  }) {
    downloadTemplateSpec(
      filename: templateFilenameFromTitle(tableTitle),
      columns: columns,
    );
  }

  // ─── Excel (two-sheet) template ─────────────────────────────────────────
  //
  // The owner asked for a definitions tab on the downloaded template so the
  // import cannot trip over its own instructions:
  //
  //   "you add the second tab for definitions?" … "under when they import the
  //    Excel, it does not give them error" (Lusaka 25)
  //
  // Sheet 1 `Data` holds the numbered rows the importer reads. Sheet 2
  // `Definitions` documents each column. Importers must only read the Data
  // sheet — `CsvImportHelper.dataSheetName` / `definitionsSheetName` name the
  // two so a reader can find them whatever order the workbook came in.

  /// Builds a `.xlsx` template with a numbered `Data` sheet and a
  /// `Definitions` sheet documenting every column.
  static Uint8List buildExcelTemplate({
    required String tableTitle,
    required List<CsvColumnSpec> columns,
  }) {
    final excel = Excel.createExcel();

    // The default sheet is created as 'Sheet1' — rename it to the data sheet.
    final dataSheet = excel[CsvImportHelper.dataSheetName];
    excel.delete(excel.getDefaultSheet()!);

    final headerStyle = CellStyle(bold: true);
    final headers = <String>[
      CsvImportHelper.numberColumnLabel,
      ...columns.map((c) => c.label),
    ];
    for (var c = 0; c < headers.length; c++) {
      final cell = dataSheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = headerStyle;
    }

    // Two numbered sample rows, matching the hints column-generation used by
    // the CSV template so users have something concrete to overwrite. The
    // second row is only written when it adds information, and it repeats the
    // required columns so the example rows validate on import.
    final samples = <List<String>>[
      ['1', ...CsvImportHelper.primarySampleValues(columns)],
      if (CsvImportHelper.hasAlternateSampleRow(columns))
        ['2', ...CsvImportHelper.alternateSampleValues(columns)],
    ];
    for (var r = 0; r < samples.length; r++) {
      for (var c = 0; c < samples[r].length; c++) {
        dataSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
            .value = TextCellValue(samples[r][c]);
      }
    }

    final definitionsSheet = excel[CsvImportHelper.definitionsSheetName];
    final definitionRows = CsvImportHelper.generateDefinitionRows(columns);
    for (var r = 0; r < definitionRows.length; r++) {
      for (var c = 0; c < definitionRows[r].length; c++) {
        final cell = definitionsSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        );
        cell.value = TextCellValue(definitionRows[r][c]);
        if (r == 0) cell.cellStyle = headerStyle;
      }
    }

    debugPrint(
        '[TableImportHelper] Excel template built for "$tableTitle" (${columns.length} columns)');
    return Uint8List.fromList(excel.encode() ?? const []);
  }

  /// Downloads the two-sheet Excel template ([buildExcelTemplate]).
  static void downloadExcelTemplate({
    required String tableTitle,
    required List<CsvColumnSpec> columns,
  }) {
    final filename = CsvImportHelper.excelTemplateFilename(tableTitle);
    loader.downloadFile(
      buildExcelTemplate(tableTitle: tableTitle, columns: columns),
      filename,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    debugPrint('[TableImportHelper] Excel template downloaded: $filename');
  }

  /// Opens a file picker for .csv/.xlsx/.txt files, reads the content,
  /// and returns parsed rows as a List of Lists (each inner list = one row's
  /// comma-separated values).
  ///
  /// Returns null if the user cancels or the file can't be read.
  static Future<List<List<String>>?> pickAndParseFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Import data from file',
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;

    String content;
    try {
      content = utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      debugPrint('[TableImportHelper] Failed to decode file: $e');
      return null;
    }

    return parseCsv(content);
  }

  /// Parses a CSV string into a list of rows (each row = list of string values).
  /// Skips empty lines. Optionally skips the first row if it matches the
  /// headers (auto-detect: if first row contains non-numeric values that
  /// match common header patterns).
  static List<List<String>> parseCsv(String content, {bool skipHeader = true}) {
    final lines = content.trim().split(RegExp(r'[\r\n]+'));
    final rows = <List<String>>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Skip header row if it looks like one (first row, contains alphabetic
      // values in most columns that aren't numbers)
      if (skipHeader && i == 0) {
        final parts = line.split(',').map((s) => s.trim()).toList();
        final nonNumericCount =
            parts.where((p) => double.tryParse(p) == null).length;
        if (nonNumericCount > parts.length / 2) {
          continue; // skip header
        }
      }

      final parts = line.split(',').map((s) => s.trim()).toList();
      rows.add(parts);
    }

    return rows;
  }

  /// Shows a world-class import dialog with:
  /// - Download Excel/CSV Template button
  /// - Upload file button (.csv/.xlsx/.txt)
  /// - Paste CSV text area
  /// - Format guide with sample data
  /// - Load Sample button
  ///
  /// Returns the parsed rows, or null if the user cancels.
  static Future<List<List<String>>?> showImportDialog(
    BuildContext context, {
    required String tableTitle,
    required List<String> headers,
    required List<List<String>> sampleRows,
  }) async {
    final controller = SpellCheckTextEditingController();
    final filename = '${tableTitle.toLowerCase().replaceAll(' ', '_')}_template.csv';

    return showDialog<List<List<String>>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.upload_file, size: 22, color: Color(0xFF4338CA)),
              const SizedBox(width: 10),
              Text('Import $tableTitle'),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Format guide ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFEF3C7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFFFFC812)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Columns: ${headers.join(", ")}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Download + Upload buttons ──
                Row(
                  children: [
                    // Download Template
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          downloadTemplate(
                            filename: filename,
                            headers: headers,
                            sampleRows: sampleRows,
                          );
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Template downloaded. Fill it in and upload below.'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download Template',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB45309),
                          side: const BorderSide(color: Color(0xFFFFC812)),
                          backgroundColor: const Color(0xFFFFF8E1),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Upload File
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final rows = await pickAndParseFile();
                          if (rows != null && rows.isNotEmpty) {
                            controller.text =
                                rows.map((r) => r.join(',')).join('\n');
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Loaded ${rows.length} rows from file'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('Upload File',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4338CA),
                          side: const BorderSide(color: Color(0xFFFEF3C7)),
                          backgroundColor: const Color(0xFFFFF8E1),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Sample CSV ──
                const Text(
                  'Sample data:',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    '${headers.join(",")}\n${sampleRows.map((r) => r.join(",")).join("\n")}',
                    style: const TextStyle(
                        fontSize: 11, fontFamily: appFontFamily, color: Color(0xFF374151)),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Paste area ──
                const Text(
                  'Or paste CSV data below:',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: '${headers.join(",")}\n...',
                    hintStyle: const TextStyle(fontSize: 11, fontFamily: appFontFamily),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.text =
                    '${headers.join(",")}\n${sampleRows.map((r) => r.join(",")).join("\n")}';
              },
              child: const Text('Load Sample'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final rows = parseCsv(controller.text);
                Navigator.pop(ctx, rows);
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Import'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Rich-spec variant of [showImportDialog]. Builds the dialog from
  /// [CsvColumnSpec] columns so the template includes hints, allowed
  /// values, and required-field markers. The returned rows are positioned
  /// in the same order as [columns] — i.e. row[i] corresponds to
  /// columns[i].
  ///
  /// This is the preferred entry point for new code because it mirrors
  /// the on-page table's column structure exactly.
  static Future<List<List<String>>?> showImportDialogSpec(
    BuildContext context, {
    required String tableTitle,
    required List<CsvColumnSpec> columns,
  }) {
    final headers = columns.map((c) => c.label).toList();
    final sampleRows = <List<String>>[
      columns.map((c) {
        if (c.sampleValue != null && c.sampleValue!.isNotEmpty) {
          return c.sampleValue!;
        }
        if (c.allowedValues != null && c.allowedValues!.isNotEmpty) {
          return c.allowedValues!.first;
        }
        if (c.required) return '(required)';
        return '';
      }).toList(),
    ];
    // Second sample row with alternative allowed value (if any).
    final altRow = columns.map((c) {
      if (c.allowedValues != null && c.allowedValues!.length > 1) {
        return c.allowedValues![1];
      }
      return '';
    }).toList();
    if (altRow.any((v) => v.isNotEmpty)) {
      sampleRows.add(altRow);
    }
    return showImportDialog(
      context,
      tableTitle: tableTitle,
      headers: headers,
      sampleRows: sampleRows,
    );
  }
}
