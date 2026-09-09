import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/utils/latest_phase_content.dart';

void main() {
  group('resolveLatestNonEmpty', () {
    test('later non-empty phase wins over earlier one', () {
      final resolved = resolveLatestNonEmpty([
        const PhaseContent(
            phase: 'Initiation', content: 'old tech list', order: 1),
        const PhaseContent(
            phase: 'Planning', content: 'planning carried it forward', order: 2),
      ]);
      expect(resolved.hasContent, isTrue);
      expect(resolved.sourcePhase, 'Planning');
      expect(resolved.content, 'planning carried it forward');
    });

    test('earlier phase is the latest version when no later phase has it', () {
      final resolved = resolveLatestNonEmpty([
        const PhaseContent(
            phase: 'Initiation', content: 'only ever in initiation', order: 1),
        const PhaseContent(phase: 'Planning', content: '', order: 2),
        const PhaseContent(phase: 'Design', content: '   ', order: 3),
      ]);
      expect(resolved.hasContent, isTrue);
      expect(resolved.sourcePhase, 'Initiation');
      expect(resolved.content, 'only ever in initiation');
    });

    test('placeholder dashes count as empty', () {
      final resolved = resolveLatestNonEmpty([
        const PhaseContent(phase: 'Initiation', content: '—', order: 1),
        const PhaseContent(phase: 'Planning', content: '-', order: 2),
      ]);
      expect(resolved.hasContent, isFalse);
    });

    test('empty everywhere resolves to no content', () {
      final resolved = resolveLatestNonEmpty([
        const PhaseContent(phase: 'Initiation', content: '', order: 1),
        const PhaseContent(phase: 'Planning', content: '  ', order: 2),
      ]);
      expect(resolved.hasContent, isFalse);
      expect(resolved.sourcePhase, isNull);
    });
  });

  group('buildLatestContextSummary', () {
    test('only the latest content per area is emitted, empties omitted', () {
      final summary = buildLatestContextSummary({
        'Technology': [
          const PhaseContent(
              phase: 'Initiation', content: 'legacy CRM notes', order: 1),
          const PhaseContent(
              phase: 'Planning', content: 'final platform decision', order: 2),
        ],
        'Requirements': [
          const PhaseContent(
              phase: 'Initiation', content: 'three windows per room', order: 1),
        ],
        'Empty topic': [
          const PhaseContent(phase: 'Initiation', content: '', order: 1),
        ],
      });
      expect(summary, contains('Technology (latest: Planning)'));
      expect(summary, contains('final platform decision'));
      // The stale initiation copy must NOT be re-emitted for a topic that
      // planning already carries.
      expect(summary, isNot(contains('legacy CRM notes')));
      expect(summary, contains('Requirements (latest: Initiation)'));
      expect(summary, isNot(contains('Empty topic')));
    });
  });
}
