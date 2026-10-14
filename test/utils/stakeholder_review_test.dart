// Lusaka 25 (copy) review, on the stakeholder register:
//
//   "we need to have an actual name of the person"
//   "I don't know what the owner is … I would say we need to change one of these
//    to be … the contact person"
//   "some people might put stakeholder on them and actually put the name"
//   "we put a pop-up that says they need to ensure to review it … ensure that
//    it's stakeholder name, organization and title is currently reflected"
//
// The prompt is only useful if it points at the right rows, so the detector is
// tested directly. Two failure modes matter: a row that is fine must never be
// flagged (the owner's complaint was being nagged about rows that were already
// correct), and a row holding an organisation but nobody's name must always be
// flagged — that is the row the whole ask is about, because it has no one to
// contact.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/stakeholder_review.dart';

int _seq = 0;

StakeholderEntry _entry({
  String name = 'A. Banda',
  String organization = 'Ndu Holdings',
  String role = 'Programme Director',
}) {
  final now = DateTime.now();
  return StakeholderEntry(
    id: 'sh-${_seq++}',
    name: name,
    organization: organization,
    role: role,
    influence: 'High',
    interest: 'High',
    channel: 'Email',
    contactInfo: '',
    owner: '',
    notes: '',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('which rows need review', () {
    test('a complete row is not flagged', () {
      expect(stakeholderGaps([_entry()]), isEmpty);
      expect(stakeholderReviewSummary(0, 1),
          contains('All stakeholders have a name'));
    });

    test('a row with an organisation but no person is flagged as having no one', () {
      // The exact row the owner was staring at: an office on the register with
      // nobody to contact.
      final gaps = stakeholderGaps([
        _entry(name: '', organization: 'Financial Budget Office', role: ''),
      ]);

      expect(gaps, hasLength(1));
      expect(gaps.single.hasNoPerson, isTrue);
      expect(gaps.single.missing, contains(StakeholderField.name));
      // Still identifiable in the list, even with no name.
      expect(gaps.single.describe, contains('Financial Budget Office'));
    });

    test('a missing title alone is still a gap', () {
      final gaps = stakeholderGaps([_entry(role: '')]);

      expect(gaps, hasLength(1));
      expect(gaps.single.hasNoPerson, isFalse);
      expect(gaps.single.missing, [StakeholderField.role]);
    });

    test('a missing organization alone is still a gap', () {
      expect(stakeholderGaps([_entry(organization: '')]).single.missing,
          [StakeholderField.organization]);
    });

    test('whitespace is not "reflected"', () {
      final gaps = stakeholderGaps([_entry(name: '   ', role: '\t')]);

      expect(gaps, hasLength(1));
      expect(gaps.single.missing,
          containsAll([StakeholderField.name, StakeholderField.role]));
    });

    test('only the incomplete rows come back', () {
      final entries = [
        _entry(),
        _entry(name: ''),
        _entry(role: ''),
        _entry(name: 'C. Mwale'),
      ];

      final gaps = stakeholderGaps(entries);

      expect(gaps, hasLength(2));
      expect(gaps.map((g) => g.hasNoPerson).toList(), [true, false]);
    });

    test('an empty register asks nothing of the user', () {
      expect(stakeholderGaps(const []), isEmpty);
    });
  });

  group('the prompt copy', () {
    test('counts the flagged rows out of the total', () {
      expect(stakeholderReviewSummary(2, 12),
          '2 of 12 stakeholders need a person, an organization or a title.');
    });

    test('speaks about a single row in the singular', () {
      expect(stakeholderReviewSummary(1, 3),
          '1 of 3 stakeholder needs a person, an organization or a title.');
    });
  });
}
