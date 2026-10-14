import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/stakeholder_provenance.dart';

SolutionStakeholderData _solution(String title) =>
    SolutionStakeholderData(solutionTitle: title);

void main() {
  group('resolveCarriedStakeholderSource', () {
    test('carries the preferred solution when its title matches', () {
      final source = resolveCarriedStakeholderSource(
        solutions: [_solution('Option A'), _solution('Option B')],
        preferredTitle: 'Option B',
      );

      expect(source.data?.solutionTitle, 'Option B');
      expect(source.matchedPreferred, isTrue);
      expect(source.carriedTitle, 'Option B');
    });

    test(
        'records that it fell back to a candidate — the hole that made the '
        'PM / Program Manager rows unverifiable', () {
      final source = resolveCarriedStakeholderSource(
        solutions: [_solution('Option A'), _solution('Option B')],
        preferredTitle: 'Option Z',
      );

      expect(source.data?.solutionTitle, 'Option A');
      expect(source.matchedPreferred, isFalse,
          reason: 'a silent substitution must not read as a match');
      expect(source.carriedTitle, 'Option A');
    });

    test('handles a project with no preferred solution selected yet', () {
      final source = resolveCarriedStakeholderSource(
        solutions: [_solution('Option A')],
        preferredTitle: null,
      );

      expect(source.matchedPreferred, isFalse);
      expect(source.carriedTitle, 'Option A');
      expect(source.data, isNotNull);
    });

    test('trims whitespace around the preferred title before matching', () {
      final source = resolveCarriedStakeholderSource(
        solutions: [_solution('Option B')],
        preferredTitle: '  Option B  ',
      );
      expect(source.matchedPreferred, isTrue);
    });

    test('matches on the trimmed solution title too', () {
      final source = resolveCarriedStakeholderSource(
        solutions: [_solution('  Option B ')],
        preferredTitle: 'Option B',
      );
      expect(source.matchedPreferred, isTrue);
    });

    test('returns an empty source when there are no solutions', () {
      final source = resolveCarriedStakeholderSource(
        solutions: const [],
        preferredTitle: 'Option B',
      );

      expect(source.data, isNull);
      expect(source.isEmpty, isTrue);
      expect(source.matchedPreferred, isFalse);
    });

    test('does not treat an empty preferred title as a match', () {
      final source = resolveCarriedStakeholderSource(
        solutions: [_solution('')],
        preferredTitle: '',
      );
      expect(source.matchedPreferred, isFalse);
    });
  });

  group('provenanceNote', () {
    test('states the preferred solution when the carry matched', () {
      final source = resolveCarriedStakeholderSource(
        solutions: [_solution('Option B')],
        preferredTitle: 'Option B',
      );
      expect(
        source.provenanceNote,
        'Carried from the preferred solution “Option B”',
      );
    });

    test('names both solutions when it did not match, so it is checkable', () {
      final source = resolveCarriedStakeholderSource(
        solutions: [_solution('Option A')],
        preferredTitle: 'Option Z',
      );
      expect(
        source.provenanceNote,
        'Carried from the solution “Option A” — not the preferred solution '
        '“Option Z”',
      );
    });

    test('says so when no preferred solution is selected yet', () {
      final source = resolveCarriedStakeholderSource(
        solutions: [_solution('Option A')],
        preferredTitle: '',
      );
      expect(
        source.provenanceNote,
        'Carried from the solution “Option A” — no preferred solution '
        'selected yet',
      );
    });

    test('says so when the preferred solution has no stakeholder entry', () {
      final source = resolveCarriedStakeholderSource(
        solutions: const [],
        preferredTitle: 'Option B',
      );
      expect(
        source.provenanceNote,
        'Carried from the Initiation Phase stakeholders — no entry for the '
        'preferred solution “Option B” yet',
      );
    });

    test('never claims a match it does not have', () {
      final source = resolveCarriedStakeholderSource(
        solutions: [_solution('Option A')],
        preferredTitle: 'Option Z',
      );
      // It may name the preferred solution, but only to say it is *not* the
      // one these rows came from.
      expect(source.provenanceNote, contains('not the preferred solution'));
      expect(
        source.provenanceNote,
        isNot(startsWith('Carried from the preferred solution')),
      );
    });
  });

  group('provenanceNoteMatches', () {
    test('detects a note that already records this source', () {
      final source = resolveCarriedStakeholderSource(
        solutions: [_solution('Option B')],
        preferredTitle: 'Option B',
      );
      expect(provenanceNoteMatches(source.provenanceNote, source), isTrue);
      expect(provenanceNoteMatches('something else', source), isFalse);
      expect(provenanceNoteMatches('', source), isFalse);
    });
  });
}
