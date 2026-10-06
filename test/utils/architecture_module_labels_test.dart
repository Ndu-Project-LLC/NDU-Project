import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/utils/architecture_module_labels.dart';
import 'package:ndu_project/utils/design_planning_document.dart';

void main() {
  group('architectureModuleLabel', () {
    test('leads with the module name so the row is not just an ordinal', () {
      final module = DesignPlanningWorkItem(name: 'Payments service');
      expect(
        architectureModuleLabel(module, 1),
        'Module 2 — Payments service',
      );
    });

    test('flags an unnamed row instead of showing a bare number', () {
      expect(
        architectureModuleLabel(DesignPlanningWorkItem(), 0),
        'Module 1 (unnamed)',
      );
    });

    test('treats whitespace-only names as unnamed', () {
      expect(
        architectureModuleLabel(DesignPlanningWorkItem(name: '   '), 2),
        'Module 3 (unnamed)',
      );
    });

    test('trims the name it shows', () {
      expect(
        architectureModuleLabel(
            DesignPlanningWorkItem(name: '  Reporting layer '), 0),
        'Module 1 — Reporting layer',
      );
    });

    test('keeps the number as a position cue', () {
      expect(architectureModuleLabel(null, 4), 'Module 5 (unnamed)');
    });
  });

  group('architectureModuleNeedsName', () {
    test('is true only for a missing or blank name', () {
      expect(architectureModuleNeedsName(DesignPlanningWorkItem()), isTrue);
      expect(
        architectureModuleNeedsName(DesignPlanningWorkItem(name: '  ')),
        isTrue,
      );
      expect(
        architectureModuleNeedsName(DesignPlanningWorkItem(name: 'API')),
        isFalse,
      );
      expect(architectureModuleNeedsName(null), isTrue);
    });
  });

  group('architectureModuleExplainer', () {
    test('explains what a module is and that the numbers are not a ranking',
        () {
      expect(architectureModuleExplainer, contains('separable part'));
      expect(architectureModuleExplainer, contains('not a ranking'));
    });
  });
}
