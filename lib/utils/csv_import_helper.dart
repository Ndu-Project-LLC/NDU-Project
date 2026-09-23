/// CSV Import Helper — world-class CSV parsing, validation, and template generation
///
/// Features:
/// - RFC 4180 compliant CSV parsing (handles quoted fields, commas, newlines)
/// - Automatic type coercion and validation
/// - Template CSV generation with sample data per column
/// - Field mapping with fuzzy header matching
/// - Detailed validation reports with row/field level errors
library;

/// Describes a column that can be imported from CSV
class CsvColumnSpec {
  const CsvColumnSpec({
    required this.key,
    required this.label,
    this.hint,
    this.required = false,
    this.allowedValues,
    this.sampleValue,
    this.defaultValue,
  });

  /// Internal key used to map CSV data to model fields
  final String key;

  /// Human-readable label shown in UI and CSV headers
  final String label;

  /// Hint text shown in the template header comment
  final String? hint;

  /// Whether this field is required for import
  final bool required;

  /// Allowed values for dropdown/enums (e.g. ['Pending','In Progress','Complete'])
  final List<String>? allowedValues;

  /// Sample value to include in the template
  final String? sampleValue;

  /// Default value when the CSV field is empty
  final String? defaultValue;

  /// Generate the CSV header name (uses label)
  String get csvHeader => label;
}

/// Result of CSV import validation
class CsvValidationResult {
  CsvValidationResult({
    required this.rows,
    required this.errors,
    required this.warnings,
    required this.totalRows,
    required this.validRows,
  });

  /// Parsed row data as List of Map<columnKey, stringValue>
  final List<Map<String, String>> rows;

  /// Validation errors — each has row index and message
  final List<CsvValidationError> errors;

  /// Non-fatal warnings
  final List<CsvValidationError> warnings;

  /// Total rows parsed (excluding header)
  final int totalRows;

  /// Rows that passed validation
  final int validRows;

  bool get hasErrors => errors.isNotEmpty;
  bool get isValid => errors.isEmpty;
}

class CsvValidationError {
  const CsvValidationError({
    required this.row,
    required this.field,
    required this.message,
    this.severity = CsvValidationSeverity.error,
  });

  final int row; // 1-based row number
  final String field;
  final String message;
  final CsvValidationSeverity severity;

  @override
  String toString() => 'Row $row, "$field": $message';
}

enum CsvValidationSeverity { error, warning }

/// Core CSV import helper
class CsvImportHelper {
  /// Parse CSV text into rows of string values.
  /// Handles:
  /// - Quoted fields with embedded commas, newlines, and double-quotes
  /// - Trailing newlines
  /// - BOM markers
  static List<List<String>> parseCsv(String text) {
    // Strip BOM if present
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }

    final rows = <List<String>>[];
    var currentRow = <String>[];
    final fieldBuffer = StringBuffer();
    var inQuotes = false;
    var i = 0;

    while (i < text.length) {
      final ch = text[i];

      if (inQuotes) {
        if (ch == '"') {
          // Double-quote inside quoted field = escaped quote
          if (i + 1 < text.length && text[i + 1] == '"') {
            fieldBuffer.write('"');
            i += 2;
            continue;
          }
          // Closing quote
          inQuotes = false;
          i++;
          continue;
        }
        fieldBuffer.write(ch);
        i++;
      } else {
        if (ch == '"') {
          inQuotes = true;
          i++;
        } else if (ch == ',') {
          currentRow.add(fieldBuffer.toString().trim());
          fieldBuffer.clear();
          i++;
        } else if (ch == '\r') {
          // Handle \r\n or bare \r
          currentRow.add(fieldBuffer.toString().trim());
          fieldBuffer.clear();
          rows.add(currentRow);
          currentRow = [];
          if (i + 1 < text.length && text[i + 1] == '\n') {
            i += 2;
          } else {
            i++;
          }
        } else if (ch == '\n') {
          currentRow.add(fieldBuffer.toString().trim());
          fieldBuffer.clear();
          rows.add(currentRow);
          currentRow = [];
          i++;
        } else {
          fieldBuffer.write(ch);
          i++;
        }
      }
    }

    // Flush last field and row
    if (fieldBuffer.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(fieldBuffer.toString().trim());
      rows.add(currentRow);
    }

    // Remove completely empty trailing rows
    while (rows.isNotEmpty && rows.last.every((f) => f.isEmpty)) {
      rows.removeLast();
    }

    return rows;
  }

  /// Map parsed CSV rows to structured data using column specs.
  /// Returns mapped rows with column keys.
  static List<Map<String, String>> mapRows(
    List<List<String>> rows,
    List<CsvColumnSpec> specs, {
    int headerRowIndex = 0,
  }) {
    if (rows.isEmpty) return [];

    final headerRow = rows[headerRowIndex];
    final columnIndexMap = _buildColumnIndexMap(headerRow, specs);

    final mappedRows = <Map<String, String>>[];
    for (var r = headerRowIndex + 1; r < rows.length; r++) {
      final row = rows[r];
      final mapped = <String, String>{};

      for (final spec in specs) {
        final colIdx = columnIndexMap[spec.key];
        if (colIdx != null && colIdx < row.length) {
          var val = row[colIdx].trim();
          if (val.isEmpty && spec.defaultValue != null) {
            val = spec.defaultValue!;
          }
          mapped[spec.key] = val;
        } else if (spec.defaultValue != null) {
          mapped[spec.key] = spec.defaultValue!;
        } else {
          mapped[spec.key] = '';
        }
      }
      mappedRows.add(mapped);
    }

    return mappedRows;
  }

  /// Validate mapped rows against column specs.
  static CsvValidationResult validate(
    List<Map<String, String>> rows,
    List<CsvColumnSpec> specs,
  ) {
    final errors = <CsvValidationError>[];
    final warnings = <CsvValidationError>[];
    var validCount = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      var rowValid = true;

      for (final spec in specs) {
        final val = row[spec.key] ?? '';

        // Required check
        if (spec.required && val.isEmpty) {
          errors.add(CsvValidationError(
            row: i + 2, // 1-based, skip header
            field: spec.label,
            message: '"${spec.label}" is required',
          ));
          rowValid = false;
          continue;
        }

        // Allowed values check
        if (val.isNotEmpty &&
            spec.allowedValues != null &&
            spec.allowedValues!.isNotEmpty) {
          final match = spec.allowedValues!.any(
            (av) => av.toLowerCase() == val.toLowerCase(),
          );
          if (!match) {
            errors.add(CsvValidationError(
              row: i + 2,
              field: spec.label,
              message:
                  '"$val" is not valid. Allowed: ${spec.allowedValues!.join(', ')}',
            ));
            rowValid = false;
          }
        }
      }

      if (rowValid) validCount++;
    }

    return CsvValidationResult(
      rows: rows,
      errors: errors,
      warnings: warnings,
      totalRows: rows.length,
      validRows: validCount,
    );
  }

  /// Leading rows that are comments rather than data. `generateTemplate`
  /// writes a `# …` hint row above the header, so a user who fills in the
  /// downloaded template and re-uploads it unchanged must not have that hint
  /// row read as the header.
  static bool _isCommentRow(List<String> row) {
    for (final field in row) {
      final trimmed = field.trim();
      if (trimmed.isEmpty) continue;
      return trimmed.startsWith('#');
    }
    return false;
  }

  /// Index of the first row that is not a comment and not blank.
  static int _firstDataRowIndex(List<List<String>> rows, int from) {
    var index = from;
    while (index < rows.length &&
        (rows[index].every((f) => f.trim().isEmpty) ||
            _isCommentRow(rows[index]))) {
      index++;
    }
    return index;
  }

  /// Full import pipeline: parse → map → validate
  static CsvValidationResult importFromText(
    String csvText,
    List<CsvColumnSpec> specs, {
    int headerRowIndex = 0,
  }) {
    final parsed = parseCsv(csvText);
    if (parsed.isEmpty) {
      return CsvValidationResult(
        rows: [],
        errors: [
          const CsvValidationError(
            row: 0,
            field: '',
            message: 'CSV file is empty',
          ),
        ],
        warnings: [],
        totalRows: 0,
        validRows: 0,
      );
    }

    if (parsed.length <= headerRowIndex) {
      return CsvValidationResult(
        rows: [],
        errors: [
          CsvValidationError(
            row: 0,
            field: '',
            message: 'CSV must have at least ${headerRowIndex + 1} row(s) for headers',
          ),
        ],
        warnings: [],
        totalRows: 0,
        validRows: 0,
      );
    }

    // Tolerate the template's own hint row(s) and any blank spacer rows the
    // user left above the header.
    final header = headerRowIndex == 0
        ? _firstDataRowIndex(parsed, 0)
        : headerRowIndex;

    final mapped = mapRows(parsed, specs, headerRowIndex: header);
    return validate(mapped, specs);
  }

  /// Label of the row-number column every table shows on page and every
  /// template therefore carries, so a row can be traced from the sheet back
  /// to the table.
  static const String numberColumnLabel = 'No.';

  /// Generate a sample CSV template string with:
  /// - Comment row with hints
  /// - Header row with column labels (prefixed by the row-number column)
  /// - Sample data row
  static String generateTemplate(
    List<CsvColumnSpec> specs, {
    bool includeNumberColumn = true,
  }) {
    final buffer = StringBuffer();

    // Comment row with hints
    final hints = <String>[
      if (includeNumberColumn) '$numberColumnLabel (do not change)',
    ];
    for (final spec in specs) {
      var hint = spec.label;
      if (spec.required) hint += ' (required)';
      if (spec.allowedValues != null && spec.allowedValues!.isNotEmpty) {
        hint += ' [${spec.allowedValues!.join("|")}]';
      }
      if (spec.hint != null) hint += ' — ${spec.hint}';
      hints.add(hint);
    }
    buffer.writeln('# ${hints.join(' | ')}');

    // Header row
    final headers = <String>[
      if (includeNumberColumn) numberColumnLabel,
      ...specs.map((s) => s.label),
    ];
    buffer.writeln(headers.map(_escapeCsvField).join(','));

    // Sample data row
    final sampleValues = <String>[
      if (includeNumberColumn) '1',
      ...primarySampleValues(specs),
    ];
    buffer.writeln(sampleValues.map(_escapeCsvField).join(','));

    // Second sample row (shows alternative values), only when it adds
    // information.
    if (hasAlternateSampleRow(specs)) {
      final altValues = <String>[
        if (includeNumberColumn) '2',
        ...alternateSampleValues(specs),
      ];
      buffer.writeln(altValues.map(_escapeCsvField).join(','));
    }

    return buffer.toString();
  }

  /// Serialise the table's current rows into a CSV an import will accept.
  ///
  /// Writes the same header row the template carries (labels, prefixed by the
  /// row-number column) so an exported file can be edited in a spreadsheet and
  /// imported straight back — no hint/comment row, since that is guidance for a
  /// human filling in a blank template, not data.
  ///
  /// The row number is regenerated from position rather than trusted from the
  /// data, so the export stays consistent even if somebody edited the numbers.
  static String exportRows(
    List<CsvColumnSpec> specs,
    List<Map<String, String>> rows, {
    bool includeNumberColumn = true,
  }) {
    final buffer = StringBuffer();

    final headers = <String>[
      if (includeNumberColumn) numberColumnLabel,
      ...specs.map((s) => s.label),
    ];
    buffer.writeln(headers.map(_escapeCsvField).join(','));

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final values = <String>[
        if (includeNumberColumn) '${i + 1}',
        ...specs.map((s) => row[s.key] ?? ''),
      ];
      buffer.writeln(values.map(_escapeCsvField).join(','));
    }

    return buffer.toString();
  }

  /// Sample values for the template's first data row.
  static List<String> primarySampleValues(List<CsvColumnSpec> specs) {
    return specs.map((s) {
      if (s.sampleValue != null) return s.sampleValue!;
      if (s.allowedValues != null && s.allowedValues!.isNotEmpty) {
        return s.allowedValues!.first;
      }
      if (s.required) return '(required)';
      return '';
    }).toList();
  }

  /// Sample values for the template's second data row.
  ///
  /// Required columns repeat their first-row value instead of going blank:
  /// the owner reported import errors on our own template, and a blank
  /// required cell in the example row is exactly what produced them.
  static List<String> alternateSampleValues(List<CsvColumnSpec> specs) {
    final primary = primarySampleValues(specs);
    return [
      for (var i = 0; i < specs.length; i++)
        if (specs[i].allowedValues != null && specs[i].allowedValues!.length > 1)
          specs[i].allowedValues![1]
        else
          specs[i].required ? primary[i] : '',
    ];
  }

  /// True when the second sample row would differ from the first.
  static bool hasAlternateSampleRow(List<CsvColumnSpec> specs) {
    final primary = primarySampleValues(specs);
    final alternate = alternateSampleValues(specs);
    for (var i = 0; i < specs.length; i++) {
      if (primary[i] != alternate[i]) return true;
    }
    return false;
  }

  /// Rows for the template's second sheet.
  ///
  /// The owner asked for a definitions tab so the import cannot fail on
  /// instruction text: sheet 1 (`Data`) is the only sheet the importer reads,
  /// and this sheet documents every column — what it is, whether it is
  /// required, and which values are accepted.
  ///
  /// First row is the header row.
  static List<List<String>> generateDefinitionRows(
      List<CsvColumnSpec> specs) {
    return [
      const ['No.', 'Column', 'Required', 'Allowed values', 'Description', 'Example'],
      for (var i = 0; i < specs.length; i++)
        [
          '${i + 1}',
          specs[i].label,
          specs[i].required ? 'Yes' : 'No',
          specs[i].allowedValues?.join(', ') ?? 'Any',
          specs[i].hint ?? '',
          specs[i].sampleValue ??
              (specs[i].allowedValues?.isNotEmpty ?? false
                  ? specs[i].allowedValues!.first
                  : ''),
        ],
    ];
  }

  /// Generate a filename-safe template name
  static String templateFilename(String tableTitle) {
    return '${_safeTableName(tableTitle)}_template.csv';
  }

  /// Filename-safe template name for the Excel (two-sheet) template.
  static String excelTemplateFilename(String tableTitle) {
    return '${_safeTableName(tableTitle)}_template.xlsx';
  }

  /// Name of the sheet holding importable rows, so an importer can find it
  /// even when the workbook has a definitions sheet in front of it.
  static const String dataSheetName = 'Data';

  /// Name of the sheet documenting the columns.
  static const String definitionsSheetName = 'Definitions';

  static String _safeTableName(String tableTitle) {
    return tableTitle
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  // ─── Private helpers ────────────────────────────────────────────────

  /// Build mapping from spec key to column index in the CSV header.
  /// Uses fuzzy matching: exact label match first, then case-insensitive,
  /// then key match.
  static Map<String, int> _buildColumnIndexMap(
    List<String> headerRow,
    List<CsvColumnSpec> specs,
  ) {
    final map = <String, int>{};
    final headerLower =
        headerRow.map((h) => h.trim().toLowerCase()).toList();

    for (final spec in specs) {
      // Exact match
      var idx = headerRow.indexWhere((h) => h.trim() == spec.label);
      if (idx != -1) {
        map[spec.key] = idx;
        continue;
      }

      // Case-insensitive match
      idx = headerLower.indexOf(spec.label.toLowerCase());
      if (idx != -1) {
        map[spec.key] = idx;
        continue;
      }

      // Key match (for power users)
      idx = headerLower.indexOf(spec.key.toLowerCase());
      if (idx != -1) {
        map[spec.key] = idx;
        continue;
      }

      // Fuzzy: contains match
      idx = headerLower.indexWhere(
          (h) => h.contains(spec.label.toLowerCase()) || spec.label.toLowerCase().contains(h));
      if (idx != -1) {
        map[spec.key] = idx;
      }
    }

    return map;
  }

  /// Escape a CSV field value (wrap in quotes if it contains comma, quote, or newline)
  static String _escapeCsvField(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
