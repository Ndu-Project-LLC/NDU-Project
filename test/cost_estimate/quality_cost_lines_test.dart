import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/cost_estimate/utils/quality_cost_lines.dart';
import 'package:ndu_project/models/cost_of_quality.dart';

CoQEntry _entry({
  String id = 'coq-1',
  String description = 'Code review',
  String scope = 'Internal',
  double estimatedCost = 0,
  double actualCost = 0,
}) {
  // Built through the model's own deserialiser, which is the same path a
  // captured entry takes on load.
  return CoQEntry.fromJson({
    'id': id,
    'description': description,
    'scope': scope,
    'estimatedCost': estimatedCost,
    'actualCost': actualCost,
  });
}

void main() {
  group('qualityEntryAmount', () {
    test('uses the estimate until an actual is recorded', () {
      expect(
        qualityEntryAmount(_entry(estimatedCost: 500)),
        500,
      );
    });

    test('actual wins once recorded — the estimate should show real spend', () {
      expect(
        qualityEntryAmount(_entry(estimatedCost: 500, actualCost: 750)),
        750,
      );
    });
  });

  group('collectQualityCostLines', () {
    test('returns nothing when the project has no Cost of Quality data', () {
      expect(collectQualityCostLines(data: null), isEmpty);
    });

    test('selects priced entries from all four categories, in report order',
        () {
      final data = CostOfQualityData(
        preventionCosts: [_entry(id: 'p1', description: 'Training',
            estimatedCost: 1000)],
        appraisalCosts: [_entry(id: 'a1', description: 'Inspection',
            estimatedCost: 400)],
        internalFailureCosts: [_entry(id: 'i1', description: 'Rework',
            estimatedCost: 250)],
        externalFailureCosts: [_entry(id: 'e1', description: 'Warranty claims',
            estimatedCost: 900)],
      );

      final lines = collectQualityCostLines(data: data);

      expect(lines.map((l) => l.category).toList(), [
        'Prevention',
        'Appraisal',
        'Internal Failure',
        'External Failure',
      ]);
      expect(lines.map((l) => l.description).toList(), [
        'Training',
        'Inspection',
        'Rework',
        'Warranty claims',
      ]);
    });

    test('skips unpriced entries rather than counting them as zero', () {
      final data = CostOfQualityData(
        preventionCosts: [
          _entry(id: 'p1', description: 'Unpriced idea'),
          _entry(id: 'p2', description: 'Priced', estimatedCost: 100),
        ],
      );

      final lines = collectQualityCostLines(data: data);

      expect(lines.length, 1);
      expect(lines.single.description, 'Priced');
    });

    test('skips unnamed entries', () {
      final data = CostOfQualityData(
        preventionCosts: [
          _entry(id: 'p1', description: '   ', estimatedCost: 100),
        ],
      );
      expect(collectQualityCostLines(data: data), isEmpty);
    });

    test('carries the entry id and scope so the line stays traceable', () {
      final data = CostOfQualityData(
        appraisalCosts: [
          _entry(
            id: 'coq-42',
            description: 'Third-party test',
            scope: '3rd Party',
            estimatedCost: 1200,
          ),
        ],
      );

      final line = collectQualityCostLines(data: data).single;
      expect(line.entryId, 'coq-42');
      expect(line.scope, '3rd Party');
      expect(line.total, 1200);
    });

    test('uses the actual amount when the entry has one', () {
      final data = CostOfQualityData(
        internalFailureCosts: [
          _entry(id: 'i1', description: 'Rework',
              estimatedCost: 100, actualCost: 375),
        ],
      );
      expect(collectQualityCostLines(data: data).single.total, 375);
    });

    test('maps to the quality cost category', () {
      expect(qualityCostCategory.name, 'quality');
    });
  });
}
