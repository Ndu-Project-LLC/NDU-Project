import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ndu_project/utils/project_data_helper.dart';
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart' as loader;

// Re-export TableHelper for convenience
typedef _TH = pw.TableHelper;

// ─────────────────────────────────────────────────────────────────────────────
// Shared PDF Export Helper
//
// Provides reusable building blocks for generating PDF exports from any screen.
// Each screen can call [exportScreenPdf] with its title and content sections,
// or build a custom document using the lower-level helpers.
//
// Usage (minimal):
//   PdfExportHelper.exportScreenPdf(
//     context: context,
//     screenTitle: 'Change Management',
//     sections: [
//       PdfSection.text('Summary', 'No pending changes at this time.'),
//       PdfSection.table('Changes', headers: ['#','Title','Status'], rows: [...]),
//     ],
//   );
// ─────────────────────────────────────────────────────────────────────────────

/// A typed section that can be rendered inside a PDF page.
class PdfSection {
  final String title;
  final PdfSectionType type;
  final String? textBody;
  final List<String>? tableHeaders;
  final List<List<String>>? tableRows;
  final List<Map<String, String>>? keyValuePairs;

  const PdfSection._({
    required this.title,
    required this.type,
    this.textBody,
    this.tableHeaders,
    this.tableRows,
    this.keyValuePairs,
  });

  /// A plain-text body section.
  factory PdfSection.text(String title, String body) => PdfSection._(
        title: title,
        type: PdfSectionType.text,
        textBody: body,
      );

  /// A table section with headers and rows.
  factory PdfSection.table(
    String title, {
    required List<String> headers,
    required List<List<String>> rows,
  }) =>
      PdfSection._(
        title: title,
        type: PdfSectionType.table,
        tableHeaders: headers,
        tableRows: rows,
      );

  /// A key-value pair section.
  factory PdfSection.keyValue(String title, List<Map<String, String>> pairs) =>
      PdfSection._(
        title: title,
        type: PdfSectionType.keyValue,
        keyValuePairs: pairs,
      );
}

enum PdfSectionType { text, table, keyValue }

class PdfExportHelper {
  PdfExportHelper._();

  // ── Colour constants (PdfColor uses 0.0–1.0 range) ────────────────────
  static const PdfColor _grey600 = PdfColor.fromInt(0xFF757575);
  static const PdfColor _grey200 = PdfColor.fromInt(0xFFEEEEEE);

  // ── High-level: one-call export ────────────────────────────────────────

  /// Generates and downloads a PDF for the current screen.
  ///
  /// [context] is used to resolve the project name via ProjectDataHelper.
  /// [screenTitle] is the main heading of the document.
  /// [sections] is an ordered list of content sections to render.
  /// [filenamePrefix] overrides the default filename prefix (derived from
  ///   [screenTitle] if null).
  static Future<void> exportScreenPdf({
    required BuildContext context,
    required String screenTitle,
    required List<PdfSection> sections,
    String? filenamePrefix,
  }) async {
    try {
      final projectData = ProjectDataHelper.getData(context);
      final projectName = projectData.projectName;
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final prefix =
          filenamePrefix ?? screenTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      final filename = '${prefix}_${projectName.replaceAll(' ', '_')}_$stamp.pdf';

      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (_) => [
            // Title
            pw.Text(screenTitle,
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(
              '$projectName \u2014 Generated ${now.toLocal().toIso8601String()}',
              style: const pw.TextStyle(fontSize: 9, color: _grey600),
            ),
            pw.SizedBox(height: 16),
            // Sections
            ...sections.expand(_buildSection),
          ],
        ),
      );

      final bytes = await doc.save();
      loader.downloadFile(bytes, filename, mimeType: 'application/pdf');

      // Show success snackbar if context is still mounted
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF exported: $filename'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Low-level: build section widgets ───────────────────────────────────

  static List<pw.Widget> _buildSection(PdfSection section) {
    switch (section.type) {
      case PdfSectionType.text:
        return [
          _sectionTitle(section.title),
          pw.SizedBox(height: 6),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              section.textBody?.trim().isNotEmpty == true
                  ? section.textBody!.trim()
                  : 'No data recorded.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.SizedBox(height: 14),
        ];

      case PdfSectionType.table:
        final headers = section.tableHeaders ?? [];
        final rows = section.tableRows ?? [];
        return [
          _sectionTitle(section.title),
          pw.SizedBox(height: 6),
          if (rows.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('No data recorded.',
                  style: const pw.TextStyle(fontSize: 9)),
            )
          else
            _TH.fromTextArray(
              headers: headers,
              data: rows,
              headerStyle:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: _grey200),
              cellPadding: const pw.EdgeInsets.all(6),
            ),
          pw.SizedBox(height: 14),
        ];

      case PdfSectionType.keyValue:
        final pairs = section.keyValuePairs ?? [];
        return [
          _sectionTitle(section.title),
          pw.SizedBox(height: 6),
          if (pairs.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('No data recorded.',
                  style: const pw.TextStyle(fontSize: 9)),
            )
          else
            _TH.fromTextArray(
              headers: ['Field', 'Value'],
              data: pairs
                  .map((p) => [p.keys.first, p.values.first])
                  .toList(),
              headerStyle:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: _grey200),
              cellPadding: const pw.EdgeInsets.all(6),
            ),
          pw.SizedBox(height: 14),
        ];
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  static pw.Widget _sectionTitle(String title) {
    return pw.Text(title,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold));
  }

  /// Safely convert any dynamic value to a trimmed string.
  static String s(dynamic v) => (v ?? '').toString().trim();

  /// Safely convert or fall back.
  static String ns(dynamic v, String fb) => s(v).isEmpty ? fb : s(v);
}
