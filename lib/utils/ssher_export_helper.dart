import 'dart:convert';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart' as loader;

class SsherExportHelper {
  static String entriesToCsv(List<SsherEntry> entries, {String? categoryTitle}) {
    final buffer = StringBuffer();
    
    // Header
    if (categoryTitle != null) {
      buffer.writeln('Category: $categoryTitle');
      buffer.writeln();
    }
    
    buffer.writeln('#,Department,Team Member,Concern,Risk Level,Mitigation Strategy');
    
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final row = [
        '${i + 1}',
        _escapeCsv(e.department),
        _escapeCsv(e.teamMember),
        _escapeCsv(e.concern),
        _escapeCsv(e.riskLevel),
        _escapeCsv(e.mitigation),
      ];
      buffer.writeln(row.join(','));
    }
    
    return buffer.toString();
  }

  static String allEntriesToCsv(Map<String, List<SsherEntry>> categoryMap) {
    final buffer = StringBuffer();
    buffer.writeln('SSHER Export - All Categories');
    buffer.writeln();

    categoryMap.forEach((category, entries) {
      buffer.writeln(entriesToCsv(entries, categoryTitle: category));
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    });

    return buffer.toString();
  }

  /// Produces a Cost Summary CSV that is import-ready for the Cost Estimate
  /// module. Columns mirror the Cost Estimate line-item schema so that the
  /// file can be re-imported as cost line items.
  static String costSummaryToCsv(List<SsherEntry> entries) {
    final buffer = StringBuffer();

    // Header row — matches Cost Estimate import schema
    buffer.writeln(
        'Category,SubCategory,Description,Quantity,Unit,Rate,Total,Currency,Frequency,In Schedule,Basis Source,Basis Reference,Confidence,Linked Risks,Linked Staffing,Linked Requirements,Source SSHER Id');

    for (final e in entries) {
      final cost = double.tryParse(
              e.estimatedCost.replaceAll(',', '').replaceAll('\$', '')) ??
          0.0;
      final categoryLabel = _categoryLabel(e.category);
      final subCategory = e.department.isNotEmpty
          ? e.department
          : categoryLabel;
      final description = e.concern.isNotEmpty
          ? '${e.concern} — ${e.mitigation}'
          : 'SSHER item';
      final unit = e.costUnit.isNotEmpty ? e.costUnit : 'lump sum';
      final row = [
        _escapeCsv('SSHER'), // Category column will use the CostCategory.ssher label downstream
        _escapeCsv('$categoryLabel: $subCategory'),
        _escapeCsv(description),
        '1',
        _escapeCsv(unit),
        cost.toStringAsFixed(2),
        cost.toStringAsFixed(2),
        e.costCurrency,
        e.costFrequency,
        'true',
        'expertJudgment',
        _escapeCsv('Imported from SSHER Hub'),
        'med',
        _escapeCsv(e.linkedRiskIds.join('; ')),
        _escapeCsv(e.linkedStaffingRoleIds.join('; ')),
        _escapeCsv(e.linkedRequirementIds.join('; ')),
        e.id,
      ];
      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }

  static String _categoryLabel(String categoryKey) {
    switch (categoryKey.toLowerCase()) {
      case 'safety':
        return 'Safety';
      case 'security':
        return 'Security';
      case 'health':
        return 'Health';
      case 'environment':
        return 'Environment';
      case 'regulatory':
        return 'Regulatory';
      default:
        return categoryKey;
    }
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static Future<void> downloadCsv(String csvContent, String filename) async {
    final bytes = utf8.encode(csvContent);
    loader.downloadFile(bytes, filename);
  }

  static Future<void> exportToPdf(List<SsherEntry> entries, {required String categoryTitle}) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('SSHER Export - $categoryTitle', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['#', 'Department', 'Team Member', 'Concern', 'Risk Level', 'Mitigation Strategy'],
            data: List<List<String>>.generate(
              entries.length,
              (index) => [
                '${index + 1}',
                entries[index].department,
                entries[index].teamMember,
                entries[index].concern,
                entries[index].riskLevel,
                entries[index].mitigation,
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'ssher_${categoryTitle.toLowerCase()}.pdf',
    );
  }

  static Future<void> exportAllToPdf(Map<String, List<SsherEntry>> categoryMap) async {
    final doc = pw.Document();

    categoryMap.forEach((category, entries) {
      if (entries.isEmpty) return;
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('SSHER Export - $category', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headers: ['#', 'Department', 'Team Member', 'Concern', 'Risk Level', 'Mitigation Strategy'],
              data: List<List<String>>.generate(
                entries.length,
                (index) => [
                  '${index + 1}',
                  entries[index].department,
                  entries[index].teamMember,
                  entries[index].concern,
                  entries[index].riskLevel,
                  entries[index].mitigation,
                ],
              ),
            ),
          ],
        ),
      );
    });

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'ssher_all_categories.pdf',
    );
  }

  /// Exports the SSHER Cost Summary as a PDF with a totals table.
  static Future<void> exportCostSummaryToPdf(List<SsherEntry> entries) async {
    final doc = pw.Document();
    final byCategory = <String, double>{};
    double grandTotal = 0;
    for (final e in entries) {
      final cost = double.tryParse(
              e.estimatedCost.replaceAll(',', '').replaceAll('\$', '')) ??
          0.0;
      byCategory[e.category] = (byCategory[e.category] ?? 0) + cost;
      grandTotal += cost;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('SSHER Cost Summary',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
              'Grand Total: ${entries.isNotEmpty ? entries.first.costCurrency : 'USD'} ${grandTotal.toStringAsFixed(2)}',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Header(level: 1, child: pw.Text('Category Totals')),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Category', 'Total'],
            data: byCategory.entries
                .map((e) => [
                      e.key[0].toUpperCase() + e.key.substring(1),
                      e.value.toStringAsFixed(2),
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Header(level: 1, child: pw.Text('Line Items')),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: [
              '#',
              'Category',
              'Item',
              'Department',
              'Amount',
              'Currency',
              'Frequency'
            ],
            data: List<List<String>>.generate(
              entries.length,
              (index) => [
                '${index + 1}',
                entries[index].category,
                entries[index].concern,
                entries[index].department,
                (double.tryParse(entries[index].estimatedCost
                            .replaceAll(',', '')
                            .replaceAll('\$', '')) ??
                        0.0)
                    .toStringAsFixed(2),
                entries[index].costCurrency,
                entries[index].costFrequency,
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'ssher_cost_summary.pdf',
    );
  }
}
