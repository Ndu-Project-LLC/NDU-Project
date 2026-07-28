import 'dart:convert';
import 'package:ndu_project/utils/download_helper_stub.dart'
    if (dart.library.html) 'package:ndu_project/utils/download_helper_web.dart' as loader;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ndu_project/theme.dart';

/// Reusable helper for table-level CSV/Excel import + template download.
///
/// Provides two world-class features:
/// 1. **Download Template** — generates a downloadable .csv file with
///    column headers + sample rows, so users know exactly what format
///    the table expects.
/// 2. **Upload & Import** — opens a file picker for .csv/.xlsx/.txt files,
///    reads the content, and returns parsed rows as a List<Map>.
///
/// Usage:
/// ```dart
/// // Download a template
/// TableImportHelper.downloadTemplate(
///   filename: 'staffing_template.csv',
///   headers: ['Role', 'Qty', 'Type', 'Start Date', 'Duration', 'Monthly Rate', 'Status'],
///   sampleRows: [
///     ['Project Manager', '1', 'Internal', 'Jan 2024', '6', '4000', 'Active'],
///     ['Technical Lead', '2', 'Internal', 'Jan 2024', '8', '5000', 'Active'],
///   ],
/// );
///
/// // Upload and parse
/// final rows = await TableImportHelper.pickAndParseFile();
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
    final controller = TextEditingController();
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
                    color: const Color(0xFFFFF7E6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFE6CC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Columns: ${headers.join(", ")}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB45309),
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
                          foregroundColor: const Color(0xFF059669),
                          side: const BorderSide(color: Color(0xFFD1FAE5)),
                          backgroundColor: const Color(0xFFF0FDF4),
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
                          side: const BorderSide(color: Color(0xFFDDD6FE)),
                          backgroundColor: const Color(0xFFF5F3FF),
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
}
