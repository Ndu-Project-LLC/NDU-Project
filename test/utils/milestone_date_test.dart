// Lusaka 15: the milestone timeline must be chronological. FEP target dates are
// free text ("e.g. 2026-09-15 or Q3 2026"), so the timeline's ordering has to
// understand the month / quarter forms as well as ISO — otherwise those
// milestones parse as null and fall back to name order.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/utils/milestone_date.dart';

void main() {
  group('parseMilestoneDate', () {
    test('reads ISO dates, with or without a time', () {
      expect(parseMilestoneDate('2026-09-15'), DateTime(2026, 9, 15));
      expect(
        parseMilestoneDate('2026-09-15T00:00:00Z'),
        DateTime(2026, 9, 15),
      );
      expect(parseMilestoneDate('  2026-12-01  '), DateTime(2026, 12, 1));
    });

    test('reads year-month and month-year forms', () {
      expect(parseMilestoneDate('2026-12'), DateTime(2026, 12, 1));
      expect(parseMilestoneDate('2026/12'), DateTime(2026, 12, 1));
      expect(parseMilestoneDate('12/2026'), DateTime(2026, 12, 1));
      expect(parseMilestoneDate('02-2027'), DateTime(2027, 2, 1));
    });

    test('reads quarters', () {
      expect(parseMilestoneDate('Q3 2026'), DateTime(2026, 7, 1));
      expect(parseMilestoneDate('q1 2027'), DateTime(2027, 1, 1));
      expect(parseMilestoneDate('2027 Q1'), DateTime(2027, 1, 1));
      expect(parseMilestoneDate('3rd quarter 2026'), DateTime(2026, 7, 1));
      expect(parseMilestoneDate('quarter 4 2026'), DateTime(2026, 10, 1));
    });

    test('reads month names, with or without a day', () {
      expect(parseMilestoneDate('December 2026'), DateTime(2026, 12, 1));
      expect(parseMilestoneDate('December, 2026'), DateTime(2026, 12, 1));
      expect(parseMilestoneDate('Dec 15, 2026'), DateTime(2026, 12, 15));
      expect(parseMilestoneDate('15 Dec 2026'), DateTime(2026, 12, 15));
      expect(parseMilestoneDate('February 2027'), DateTime(2027, 2, 1));
    });

    test('reads a bare year', () {
      expect(parseMilestoneDate('2027'), DateTime(2027, 1, 1));
      expect(parseMilestoneDate('FY2027'), DateTime(2027, 1, 1));
    });

    test('a lone month name anchors to that month', () {
      final thisYear = DateTime.now().year;
      expect(parseMilestoneDate('December'), DateTime(thisYear, 12, 1));
    });

    test('returns null when the text is not a date', () {
      expect(parseMilestoneDate(''), isNull);
      expect(parseMilestoneDate('TBC'), isNull);
      expect(parseMilestoneDate('End of project'), isNull);
      // A month word inside prose is not a date.
      expect(parseMilestoneDate('May need review'), isNull);
    });

    test('resolves three-part numeric dates only when the order is known', () {
      // A part of 13+ can only be a day.
      expect(parseMilestoneDate('15/12/2026'), DateTime(2026, 12, 15));
      expect(parseMilestoneDate('12/15/2026'), DateTime(2026, 12, 15));
      // Both parts 12 or less: ambiguous, so anchor to the year.
      expect(parseMilestoneDate('01/02/2026'), DateTime(2026, 1, 1));
    });

    test('rejects out-of-range dates instead of rolling them over', () {
      expect(parseMilestoneDate('2026-13-01'), isNull);
      expect(parseMilestoneDate('2026-02-31'), isNull);
    });

    test('orders a mixed list chronologically', () {
      final raw = <String>[
        '2027-02-15', // Feb 2027
        'December 2026', // Dec 2026
        'Q3 2026', // Jul 2026
        'TBC', // undated last
        '2027', // Jan 2027
        '2026-09-15', // Sep 2026
      ];
      final sorted = raw.toList()
        ..sort((a, b) {
          final aDate = parseMilestoneDate(a);
          final bDate = parseMilestoneDate(b);
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });

      expect(sorted, <String>[
        'Q3 2026',
        '2026-09-15',
        'December 2026',
        '2027',
        '2027-02-15',
        'TBC',
      ]);
    });
  });
}
