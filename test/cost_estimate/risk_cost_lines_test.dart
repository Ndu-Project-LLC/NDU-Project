import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/cost_estimate/utils/risk_cost_lines.dart';

void main() {
  group('parseRiskAmount', () {
    test('parses plain numbers', () {
      const twelve = 12;
      expect(parseRiskAmount('12'), twelve);
      expect(parseRiskAmount('12500.50'), 12500.5);
    });

    test('parses loosely typed money', () {
      expect(parseRiskAmount('12,000'), 12000);
      expect(parseRiskAmount(r'$12,000'), 12000);
      expect(parseRiskAmount('12 000'), 12000);
    });

    test('returns 0 for blank or non-numeric', () {
      expect(parseRiskAmount(''), 0);
      expect(parseRiskAmount('   '), 0);
      expect(parseRiskAmount('n/a'), 0);
    });
  });

  group('collectRiskCostLines', () {
    final exposure = defaultMatrixCellExposure;

    test('stated amount wins over the matrix cell', () {
      final lines = collectRiskCostLines(
        risks: [
          {
            'id': 'R-001',
            'description': 'Budget overrun risk',
            'probability': 'High',
            'impact': 'High',
            'score': '120000',
            'status': 'Open',
          },
        ],
        matrixCellExposure: exposure,
      );
      expect(lines, hasLength(1));
      expect(lines.single.total, 120000);
      expect(lines.single.riskId, 'R-001');
    });

    test('matrix cell defaults when no amount is stated', () {
      final lines = collectRiskCostLines(
        risks: [
          {
            'id': 'R-002',
            'description': 'Vendor delay',
            'probability': 'Medium',
            'impact': 'High',
            'score': '',
            'status': 'Open',
          },
          {
            'id': 'R-003',
            'description': 'Minor rework',
            'probability': 'Low',
            'impact': 'Low',
            'score': '',
            'status': 'Monitoring',
          },
        ],
        matrixCellExposure: exposure,
      );
      expect(lines, hasLength(2));
      expect(lines[0].total, exposure['Medium']!['High']);
      expect(lines[1].total, exposure['Low']!['Low']);
    });

    test('closed risks are skipped, open-ish statuses kept', () {
      final lines = collectRiskCostLines(
        risks: [
          {
            'description': 'Done risk',
            'probability': 'High',
            'impact': 'High',
            'score': '9000',
            'status': 'Closed',
          },
          {
            'description': 'Cancelled risk',
            'probability': 'High',
            'impact': 'High',
            'score': '9000',
            'status': 'cancelled',
          },
          {
            'description': 'Live risk',
            'probability': 'High',
            'impact': 'High',
            'score': '9000',
            'status': 'In Progress',
          },
        ],
        matrixCellExposure: exposure,
      );
      expect(lines, hasLength(1));
      expect(lines.single.description, 'Live risk');
    });

    test('blank descriptions are skipped', () {
      final lines = collectRiskCostLines(
        risks: [
          {
            'description': '',
            'probability': 'High',
            'impact': 'High',
            'score': '9000',
            'status': 'Open',
          },
        ],
        matrixCellExposure: exposure,
      );
      expect(lines, isEmpty);
    });

    test('risk with zero exposure (Low×Low default only) is still included',
        () {
      // defaultMatrixCellExposure has no zero cells, so a normalised Low×Low
      // risk yields the Low/Low value.
      final lines = collectRiskCostLines(
        risks: [
          {
            'description': 'Typo risk',
            'probability': 'low',
            'impact': 'low',
            'score': '',
            'status': 'Open',
          },
        ],
        matrixCellExposure: exposure,
      );
      expect(lines, hasLength(1));
      expect(lines.single.total, exposure['Low']!['Low']);
    });

    test('levels are normalised case-insensitively', () {
      final lines = collectRiskCostLines(
        risks: [
          {
            'description': 'Case test',
            'probability': 'HIGH',
            'impact': 'high',
            'score': '',
            'status': 'Open',
          },
        ],
        matrixCellExposure: exposure,
      );
      expect(lines.single.total, exposure['High']!['High']);
    });
  });
}
