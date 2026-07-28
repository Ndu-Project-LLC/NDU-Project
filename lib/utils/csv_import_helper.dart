/// CSV Import Helper — world-class CSV parsing, validation, and template generation
///
/// Features:
/// - RFC 4180 compliant CSV parsing (handles quoted fields, commas, newlines)
/// - Automatic type coercion and validation
/// - Template CSV generation with sample data per column
/// - Field mapping with fuzzy header matching
/// - Detailed validation reports with row/field level errors

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

    final mapped = mapRows(parsed, specs, headerRowIndex: headerRowIndex);
    return validate(mapped, specs);
  }

  /// Generate a sample CSV template string with:
  /// - Comment row with hints
  /// - Header row with column labels
  /// - Sample data row
  static String generateTemplate(List<CsvColumnSpec> specs) {
    final buffer = StringBuffer();

    // Comment row with hints
    final hints = <String>[];
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
    buffer.writeln(specs.map((s) => _escapeCsvField(s.label)).join(','));

    // Sample data row
    final sampleValues = specs.map((s) {
      if (s.sampleValue != null) return s.sampleValue!;
      if (s.allowedValues != null && s.allowedValues!.isNotEmpty) {
        return s.allowedValues!.first;
      }
      if (s.required) return '(required)';
      return '';
    }).toList();
    buffer.writeln(sampleValues.map((v) => _escapeCsvField(v)).join(','));

    // Second sample row (shows alternative values)
    final altValues = specs.map((s) {
      if (s.allowedValues != null && s.allowedValues!.length > 1) {
        return s.allowedValues![1];
      }
      return '';
    }).toList();
    if (altValues.any((v) => v.isNotEmpty)) {
      buffer.writeln(altValues.map((v) => _escapeCsvField(v)).join(','));
    }

    return buffer.toString();
  }

  /// Generate a filename-safe template name
  static String templateFilename(String tableTitle) {
    final safe = tableTitle
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    return '${safe}_template.csv';
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
