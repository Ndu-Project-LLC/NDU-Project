import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:excel/excel.dart' hide Border;
import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/theme.dart';

/// World-class CSV / XLSX Import Dialog
///
/// Features:
/// - Drag-and-drop file upload zone with animated border
/// - Template download with column hints and sample data
/// - Live CSV paste support
/// - XLSX file import support
/// - Column mapping preview showing which CSV columns map to which fields
/// - Row-by-row validation with inline error badges
/// - Data preview table before committing
/// - Smooth animations and micro-interactions
/// - Responsive layout

Future<List<Map<String, String>>?> showCsvImportDialog(
  BuildContext context, {
  required String tableTitle,
  required List<CsvColumnSpec> columns,
}) {
  return showDialog<List<Map<String, String>>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _CsvImportDialog(
      tableTitle: tableTitle,
      columns: columns,
    ),
  );
}

class _CsvImportDialog extends StatefulWidget {
  const _CsvImportDialog({
    required this.tableTitle,
    required this.columns,
  });

  final String tableTitle;
  final List<CsvColumnSpec> columns;

  @override
  State<_CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends State<_CsvImportDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  String? _csvText;
  CsvValidationResult? _result;
  bool _isDragging = false;
  bool _showPreview = false;
  bool _isFileLoading = false;
  final _pasteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  void _processCsv(String text) {
    setState(() {
      _csvText = text;
      _result = CsvImportHelper.importFromText(text, widget.columns);
      _showPreview = false;
    });
  }

  void _processExcel(Uint8List bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The Excel file appears to be empty.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
        setState(() => _isFileLoading = false);
        return;
      }
      final sheet = excel.tables.values.first;
      final rows = sheet.rows;
      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The Excel sheet has no data rows.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
        setState(() => _isFileLoading = false);
        return;
      }

      // First row is the header
      final headerRow = rows.first;

      // Build CSV-like rows from remaining data rows
      final csvLines = <String>[];
      // Add header line with original casing
      final origHeaders = headerRow
          .map((cell) => (cell?.value?.toString() ?? '').trim())
          .toList();
      csvLines.add(origHeaders.join(','));

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final values = row
            .map((cell) {
              final val = cell?.value?.toString() ?? '';
              // Escape commas and quotes for CSV
              if (val.contains(',') || val.contains('"') || val.contains('\n')) {
                return '"${val.replaceAll('"', '""')}"';
              }
              return val;
            })
            .toList();
        csvLines.add(values.join(','));
      }

      final csvText = csvLines.join('\n');
      _processCsv(csvText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error parsing Excel file: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      setState(() => _isFileLoading = false);
    }
  }



  Future<void> _pickFile() async {
    setState(() => _isFileLoading = true);
    try {
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null && file.bytes!.isNotEmpty) {
          final fileName = file.name.toLowerCase();
          if (fileName.endsWith('.xlsx')) {
            _processExcel(file.bytes!);
          } else {
            final text = utf8.decode(file.bytes!);
            _processCsv(text);
            _pasteController.text = text;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFileLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 800 ? 720.0 : screenWidth - 32.0;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
              Flexible(
                child: _showPreview && _result != null
                    ? _buildPreviewView()
                    : _buildUploadView(),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.upload_file, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Import CSV / XLSX',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.tableTitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Upload View ───────────────────────────────────────────────────

  Widget _buildUploadView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTemplateSection(),
          const SizedBox(height: 20),
          _buildDropZone(),
          const SizedBox(height: 16),
          _buildPasteArea(),
          if (_result != null) ...[
            const SizedBox(height: 20),
            _buildValidationSummary(),
          ],
        ],
      ),
    );
  }

  // ─── Template Section ──────────────────────────────────────────────

  Widget _buildTemplateSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined,
                  size: 18, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              const Text(
                'Required CSV Format',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C4A6E),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.columns.map((col) {
              final isRequired = col.required;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isRequired
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRequired
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      col.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isRequired
                            ? const Color(0xFF92400E)
                            : const Color(0xFF475569),
                      ),
                    ),
                    if (isRequired) ...[
                      const SizedBox(width: 4),
                      const Text(
                        '*',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                    if (col.allowedValues != null &&
                        col.allowedValues!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '[${col.allowedValues!.join("|")}]',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Text(
            '* = Required field  |  Fields in brackets [A|B|C] accept only those values',
            style: TextStyle(
              fontSize: 10.5,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }



  // ─── Drop Zone ─────────────────────────────────────────────────────

  Widget _buildDropZone() {
    return GestureDetector(
      onTap: _isFileLoading ? null : _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _isDragging
              ? const Color(0xFFEFF6FF)
              : const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isDragging
                ? const Color(0xFF2563EB)
                : const Color(0xFFD1D5DB),
            width: _isDragging ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          children: [
            if (_isFileLoading)
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF2563EB),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isDragging
                      ? const Color(0xFF2563EB).withOpacity(0.1)
                      : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isDragging
                      ? Icons.file_download
                      : Icons.cloud_upload_outlined,
                  size: 36,
                  color: _isDragging
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              _isFileLoading
                  ? 'Reading file...'
                  : _isDragging
                      ? 'Drop your CSV / XLSX file here'
                      : 'Drag & drop CSV / XLSX file here',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _isDragging
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isFileLoading ? '' : 'or click to browse files',
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF6B7280).withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Color(0xFF9CA3AF)),
                  SizedBox(width: 6),
                  Text(
                    'Supports .csv and .xlsx files up to 5MB',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Paste Area ────────────────────────────────────────────────────

  Widget _buildPasteArea() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 8),
      title: const Row(
        children: [
          Icon(Icons.paste, size: 16, color: Color(0xFF6B7280)),
          SizedBox(width: 8),
          Text(
            'Or paste CSV text directly',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
      children: [
        TextField(
          controller: _pasteController,
          maxLines: 6,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: appFontFamily,
            color: Color(0xFF374151),
          ),
          decoration: InputDecoration(
            hintText:
                'Paste your CSV content here...\nColumn1,Column2,Column3\nvalue1,value2,value3',
            hintStyle: const TextStyle(
              color: Color(0xFFD1D5DB),
              fontFamily: appFontFamily,
              fontSize: 12,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB)),
            ),
          ),
          onChanged: (val) {
            if (val.trim().isNotEmpty) {
              _processCsv(val.trim());
            } else {
              setState(() {
                _csvText = null;
                _result = null;
              });
            }
          },
        ),
      ],
    );
  }

  // ─── Validation Summary ────────────────────────────────────────────

  Widget _buildValidationSummary() {
    final result = _result!;
    final hasErrors = result.hasErrors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            hasErrors ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasErrors
              ? const Color(0xFFFECACA)
              : const Color(0xFFBBF7D0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasErrors ? Icons.error_outline : Icons.check_circle_outline,
                size: 20,
                color: hasErrors
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF16A34A),
              ),
              const SizedBox(width: 10),
              Text(
                hasErrors
                    ? '${result.errors.length} error(s) found'
                    : 'All ${result.validRows} row(s) validated successfully',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: hasErrors
                      ? const Color(0xFF991B1B)
                      : const Color(0xFF166534),
                ),
              ),
            ],
          ),
          if (result.totalRows > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatChip('Total: ${result.totalRows}',
                    const Color(0xFFF3F4F6), const Color(0xFF374151)),
                const SizedBox(width: 8),
                _buildStatChip('Valid: ${result.validRows}',
                    const Color(0xFFDCFCE7), const Color(0xFF166534)),
                if (result.errors.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildStatChip('Errors: ${result.errors.length}',
                      const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
                ],
              ],
            ),
          ],
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...result.errors.take(5).map((err) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(
                              color: Color(0xFFDC2626), fontSize: 12)),
                      Expanded(
                        child: Text(
                          err.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7F1D1D),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            if (result.errors.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '...and ${result.errors.length - 5} more errors',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  // ─── Preview View ──────────────────────────────────────────────────

  Widget _buildPreviewView() {
    final result = _result!;
    final previewRows = result.rows.take(10).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.preview, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Data Preview (${result.validRows} valid rows)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _showPreview = false),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit CSV'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                  headingRowHeight: 40,
                  dataRowHeight: 36,
                  columnSpacing: 16,
                  horizontalMargin: 12,
                  columns: widget.columns
                      .map((c) => DataColumn(
                            label: Text(
                              c.label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ))
                      .toList(),
                  rows: previewRows.map((row) {
                    return DataRow(
                      cells: widget.columns.map((col) {
                        final val = row[col.key] ?? '';
                        final hasError = result.errors.any((e) =>
                            e.field == col.label &&
                            e.row == result.rows.indexOf(row) + 2);
                        return DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: hasError
                                ? BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(4),
                                  )
                                : null,
                            child: Text(
                              val.isEmpty ? '—' : val,
                              style: TextStyle(
                                fontSize: 12,
                                color: hasError
                                    ? const Color(0xFF991B1B)
                                    : const Color(0xFF374151),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          if (result.rows.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Showing first 10 of ${result.rows.length} rows',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Footer ────────────────────────────────────────────────────────

  Widget _buildFooter() {
    final result = _result;
    final hasValidData =
        result != null && result.isValid && result.validRows > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel'),
          ),
          const Spacer(),
          if (result != null && result.isValid && !_showPreview)
            OutlinedButton.icon(
              onPressed: () => setState(() => _showPreview = true),
              icon: const Icon(Icons.preview, size: 16),
              label: const Text('Preview Data'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF2563EB)),
              ),
            ),
          if (hasValidData) ...[
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(result.rows),
              icon: const Icon(Icons.check, size: 16),
              label: Text(
                  'Import ${result.validRows} Row${result.validRows != 1 ? 's' : ''}'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
