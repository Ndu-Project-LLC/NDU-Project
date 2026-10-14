import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/utils/sidebar_label_match.dart';

void main() {
  group('normalizeSidebarLabel', () {
    test('strips a numeric step prefix', () {
      expect(normalizeSidebarLabel('3. Benefits Realization'),
          'Benefits Realization');
      expect(normalizeSidebarLabel('12) Team Meetings'), 'Team Meetings');
    });

    test('leaves an unnumbered label alone', () {
      expect(normalizeSidebarLabel('Design Planning'), 'Design Planning');
    });
  });

  group('parentSectionLabel', () {
    test('takes the section before the first separator', () {
      expect(
        parentSectionLabel('Design Planning - Design Specifications'),
        'Design Planning',
      );
    });

    test('stops at the first separator on a doubly scoped label', () {
      expect(
        parentSectionLabel('Project Plan - Level 1 - Project Schedule'),
        'Project Plan',
      );
    });

    test('returns null when there is no separator', () {
      expect(parentSectionLabel('Design Planning'), isNull);
      expect(parentSectionLabel(' - Leading'), isNull);
    });
  });

  group('sidebarLabelMatches', () {
    test('matches exactly', () {
      expect(
        sidebarLabelMatches(
          activeLabel: 'Design Planning',
          itemLabel: 'Design Planning',
        ),
        isTrue,
      );
    });

    test(
        'highlights the section for a sub-page — the regression the owner '
        'reported as "the sidebar highlight does not follow me"', () {
      for (final subPage in [
        'Design Planning - Project Overview',
        'Design Planning - Design Overview',
        'Design Planning - Design Specifications',
        'Design Planning - Deviations',
        'Design Planning - Requirements Mapping',
        'Design Planning - Architecture Basis',
        'Design Planning - UI/UX Basis',
        'Design Planning - Technical Basis',
        'Design Planning - Constraints & Assumptions',
        'Design Planning - Risks & Mitigation',
        'Design Planning - Dependencies',
        'Design Planning - Decision Log',
        'Design Planning - Validation',
        'Design Planning - Approvals',
        'Design Planning - Work Packages',
      ]) {
        expect(
          sidebarLabelMatches(
            activeLabel: subPage,
            itemLabel: 'Design Planning',
          ),
          isTrue,
          reason: subPage,
        );
      }
    });

    test('tolerates a numeric step prefix on either side', () {
      expect(
        sidebarLabelMatches(
          activeLabel: '9. Benefits Realization',
          itemLabel: 'Benefits Realization',
        ),
        isTrue,
      );
      expect(
        sidebarLabelMatches(
          activeLabel: 'Benefits Realization',
          itemLabel: '9. Benefits Realization',
        ),
        isTrue,
      );
    });

    test('is case-insensitive', () {
      expect(
        sidebarLabelMatches(
          activeLabel: 'design planning',
          itemLabel: 'Design Planning',
        ),
        isTrue,
      );
    });

    test('does not highlight an unrelated section', () {
      expect(
        sidebarLabelMatches(
          activeLabel: 'Design Planning - Deviations',
          itemLabel: 'Technology Planning',
        ),
        isFalse,
      );
      expect(
        sidebarLabelMatches(
          activeLabel: 'Design Planning',
          itemLabel: 'Design Deliverables',
        ),
        isFalse,
      );
    });

    test('a real item beats its parent section', () {
      // If the sidebar ever lists the sub-page itself, that item is the one
      // that should light up.
      expect(
        sidebarLabelMatches(
          activeLabel: 'Project Close Out - Summarized Form',
          itemLabel: 'Project Close Out - Summarized Form',
        ),
        isTrue,
      );
    });

    test('a label that merely contains a dash is not treated as a parent',
        () {
      // "Level 1 - Project Schedule" has no matching "Level 1" section, so
      // nothing should highlight from the parent rule.
      expect(
        sidebarLabelMatches(
          activeLabel: 'Project Plan - Level 1 - Project Schedule',
          itemLabel: 'Level 1 - Project Schedule',
        ),
        isFalse,
      );
      // It still resolves to the Project Plan section it lives in.
      expect(
        sidebarLabelMatches(
          activeLabel: 'Project Plan - Level 1 - Project Schedule',
          itemLabel: 'Project Plan',
        ),
        isTrue,
      );
    });
  });
}
