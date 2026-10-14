import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/utils/checkpoint_labels.dart';

void main() {
  group('friendlyCheckpointLabel', () {
    test('maps known checkpoint ids to their screen titles', () {
      expect(friendlyCheckpointLabel('fep_summary'), 'Front End Planning');
      expect(friendlyCheckpointLabel('business_case'), 'Business Case');
      expect(friendlyCheckpointLabel('design_management'), 'Design Management');
      expect(
        friendlyCheckpointLabel('work_breakdown_structure'),
        'Work Breakdown Structure',
      );
    });

    test('is case- and whitespace-insensitive for known ids', () {
      expect(friendlyCheckpointLabel('  FEP_Summary '), 'Front End Planning');
    });

    test('falls back to a title-cased, de-underscored label', () {
      expect(friendlyCheckpointLabel('some_new_checkpoint'),
          'Some New Checkpoint');
    });

    test('handles empty input', () {
      expect(friendlyCheckpointLabel(''), 'Starting up');
      expect(friendlyCheckpointLabel('   '), 'Starting up');
    });

    test('never returns a raw underscore-containing key', () {
      // The whole point: internal identifiers must not reach the UI verbatim.
      expect(friendlyCheckpointLabel('cost_estimate').contains('_'), isFalse);
    });
  });
}
