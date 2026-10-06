// Lusaka 25 review, on the project requirement import:
//
//   "he gets the errors when he imports the Excel" … "you add the second tab
//    for definitions?" … "these tables have number, right? Number one, two,
//    three, four. So, the template should have the number too"
//
// So the downloaded template must (a) carry the same row numbering the table
// shows, (b) document every column on a second sheet, and (c) import back
// without error — the instruction row and the definitions sheet must not be
// read as data.

import 'dart:convert';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/utils/csv_import_helper.dart';
import 'package:ndu_project/utils/table_import_helper.dart';

const _columns = [
  CsvColumnSpec(
    key: 'description',
    label: 'Requirement',
    required: true,
    sampleValue: 'The system shall support user authentication',
  ),
  CsvColumnSpec(
    key: 'type',
    label: 'Type',
    allowedValues: ['Functional', 'Non-Functional'],
    defaultValue: 'Functional',
  ),
];

void main() {
  group('numbered template', () {
    test('the header row keeps the table numbering column', () {
      final template = CsvImportHelper.generateTemplate(_columns);
      final lines = const LineSplitter().convert(template);

      expect(lines.first.startsWith('#'), isTrue,
          reason: 'the hint row stays the first row');
      expect(lines[1], 'No.,Requirement,Type');
      expect(lines[2].startsWith('1,'), isTrue);
      expect(lines[3].startsWith('2,'), isTrue);
    });

    test('re-importing the downloaded template produces no errors', () {
      final template = CsvImportHelper.generateTemplate(_columns);
      final result = CsvImportHelper.importFromText(template, _columns);

      expect(result.hasErrors, isFalse);
      expect(result.rows, isNotEmpty);
      expect(result.rows.first['description'], isNotEmpty);
    });

    test('import tolerates blank spacer rows above the header', () {
      const csv = '\n\n# Requirement (required) | Type [Functional|Non-Functional]\n'
          'No.,Requirement,Type\n'
          '1,The system shall audit logins,Functional\n';
      final result = CsvImportHelper.importFromText(csv, _columns);

      expect(result.hasErrors, isFalse);
      expect(result.rows.single['description'], 'The system shall audit logins');
    });

    test('numbering can be turned off for callers that do not want it', () {
      final template = CsvImportHelper.generateTemplate(
        _columns,
        includeNumberColumn: false,
      );
      final lines = const LineSplitter().convert(template);

      expect(lines[1], 'Requirement,Type');
    });
  });

  group('definitions sheet', () {
    test('documents every column with its required/allowed values', () {
      final rows = CsvImportHelper.generateDefinitionRows(_columns);

      expect(rows.first, ['No.', 'Column', 'Required', 'Allowed values', 'Description', 'Example']);
      expect(rows, hasLength(_columns.length + 1));
      expect(rows[1][1], 'Requirement');
      expect(rows[1][2], 'Yes');
      expect(rows[2][1], 'Type');
      expect(rows[2][2], 'No');
      expect(rows[2][3], 'Functional, Non-Functional');
    });

    test('the Excel template ships both sheets', () {
      final bytes = TableImportHelper.buildExcelTemplate(
        tableTitle: 'Project Requirements',
        columns: _columns,
      );

      expect(bytes, isNotEmpty);
      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.keys, containsAll(['Data', 'Definitions']));

      final data = excel.tables['Data']!;
      expect(data.rows.first.first?.value?.toString(), 'No.');
      expect(data.rows[1].first?.value?.toString(), '1');
      expect(data.rows[2].first?.value?.toString(), '2');

      final definitions = excel.tables['Definitions']!;
      expect(definitions.rows.first.first?.value?.toString(), 'No.');
    });

    test('the Data sheet header maps cleanly through the importer', () {
      // Reproduces what the import dialog does with a picked .xlsx: read the
      // Data sheet, keep the header, and hand the rows to the importer.
      final bytes = TableImportHelper.buildExcelTemplate(
        tableTitle: 'Project Requirements',
        columns: _columns,
      );
      final sheet = Excel.decodeBytes(bytes).tables['Data']!;
      final csvLines = sheet.rows
          .map((row) =>
              row.map((cell) => cell?.value?.toString() ?? '').join(','))
          .join('\n');

      final result = CsvImportHelper.importFromText(csvLines, _columns);
      expect(result.hasErrors, isFalse);
      expect(result.rows, hasLength(2));
    });
  });
}
