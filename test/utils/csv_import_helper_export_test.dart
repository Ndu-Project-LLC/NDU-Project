import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/utils/csv_import_helper.dart';

const _columns = [
  CsvColumnSpec(key: 'title', label: 'Title', required: true),
  CsvColumnSpec(
    key: 'specificationType',
    label: 'Spec type',
    allowedValues: ['Code', 'Law', 'Standard'],
    defaultValue: 'Standard',
  ),
  CsvColumnSpec(key: 'owner', label: 'Owner'),
];

void main() {
  group('exportRows', () {
    test('writes the header row the template carries', () {
      final csv = CsvImportHelper.exportRows(
        _columns,
        [
          {'title': 'Eurocode 3', 'specificationType': 'Code', 'owner': 'A. Banda'},
        ],
      );

      final lines = csv.trim().split('\n');
      expect(lines.first, 'No.,Title,Spec type,Owner');
      expect(lines[1], '1,Eurocode 3,Code,A. Banda');
    });

    test('numbers rows by position, ignoring any number in the data', () {
      final csv = CsvImportHelper.exportRows(
        _columns,
        [
          {'title': 'First', 'owner': 'A'},
          {'title': 'Second', 'owner': 'B'},
        ],
      );
      final lines = csv.trim().split('\n');
      expect(lines[1].startsWith('1,'), isTrue);
      expect(lines[2].startsWith('2,'), isTrue);
    });

    test('escapes a value containing a comma or a quote', () {
      final csv = CsvImportHelper.exportRows(
        _columns,
        [
          {
            'title': 'Fire, life safety "Part B"',
            'specificationType': 'Code',
            'owner': 'A',
          },
        ],
      );
      final dataLine = csv.trim().split('\n')[1];
      expect(dataLine, contains('"Fire, life safety ""Part B"""'));
    });

    test('writes a blank cell for a missing key instead of throwing', () {
      final csv = CsvImportHelper.exportRows(_columns, [
        {'title': 'Only a title'},
      ]);
      expect(csv.trim().split('\n')[1], '1,Only a title,,');
    });

    test('exports just the header when there are no rows', () {
      final csv = CsvImportHelper.exportRows(_columns, const []);
      expect(csv.trim().split('\n').length, 1);
      expect(csv.trim(), 'No.,Title,Spec type,Owner');
    });

    test(
        'round-trips: an exported file imports back to the same values — the '
        'point of an import/export template', () {
      final rows = [
        {
          'title': 'Eurocode 3',
          'specificationType': 'Code',
          'owner': 'A. Banda',
        },
        {
          'title': 'BS 7671',
          'specificationType': 'Standard',
          'owner': 'C. Mwale',
        },
      ];

      final csv = CsvImportHelper.exportRows(_columns, rows);
      final result = CsvImportHelper.importFromText(csv, _columns);

      expect(result.isValid, isTrue);
      expect(result.rows.length, 2);
      expect(result.rows[0]['title'], 'Eurocode 3');
      expect(result.rows[0]['specificationType'], 'Code');
      expect(result.rows[1]['owner'], 'C. Mwale');
    });
  });
}
