import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/cost_estimate/utils/cost_descriptor_text.dart';

void main() {
  group('collapseDashRuns', () {
    test('collapses a doubled hyphen', () {
      expect(collapseDashRuns('Site -- Works'), 'Site — Works');
    });

    test('collapses a doubled em dash, spaced or not', () {
      expect(collapseDashRuns('PPE —— Gloves'), 'PPE — Gloves');
      expect(collapseDashRuns('PPE — — Gloves'), 'PPE — Gloves');
      expect(collapseDashRuns('PPE -- Gloves'), 'PPE — Gloves');
    });

    test('collapses a triple run in one pass', () {
      expect(collapseDashRuns('Site --- Works'), 'Site — Works');
    });

    test('collapses a mixed run of hyphen and en/em dash', () {
      expect(collapseDashRuns('Site -–— Works'), 'Site — Works');
    });

    test('leaves a single hyphen completely alone, so identifiers survive', () {
      for (final text in [
        'WP-04',
        'WP-01 - Electrical',
        'Level 1 - Project Schedule',
        'Sub-station upgrade',
      ]) {
        expect(collapseDashRuns(text), text, reason: text);
      }
    });

    test('is idempotent', () {
      final once = collapseDashRuns('PPE — — Gloves');
      expect(collapseDashRuns(once), once);
    });

    test('handles empty input', () {
      expect(collapseDashRuns(''), '');
    });
  });

  group('costDescriptorForDisplay', () {
    test('removes the doubled dash a join produces', () {
      // What the owner saw: a descriptor fragment already ending in a dash,
      // joined onto another one.
      expect(
        costDescriptorForDisplay('WP-04 — Electrical — — site works'),
        'WP-04 — Electrical — site works',
      );
    });

    test('tidies the whitespace the substitution leaves behind', () {
      expect(
        costDescriptorForDisplay('PPE  --  Gloves'),
        'PPE — Gloves',
      );
    });

    test('preserves newlines in a multi-line descriptor', () {
      expect(
        costDescriptorForDisplay('Electrical works\n- lighting\n- power'),
        'Electrical works\n- lighting\n- power',
      );
    });

    test('leaves a clean descriptor untouched', () {
      expect(
        costDescriptorForDisplay('Electrical works'),
        'Electrical works',
      );
    });

    test('handles empty input', () {
      expect(costDescriptorForDisplay(''), '');
    });
  });
}
