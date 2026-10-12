/// Tolerant parsing of a milestone Target Date.
///
/// Front End Planning stores a milestone's target date as free text — the form
/// hints it as "e.g. 2026-09-15 or Q3 2026" — so people write month and quarter
/// forms as often as ISO dates. A bare `DateTime.tryParse` returns null for
/// everything except ISO (and rolls month 13 over into the next year), and the
/// Goals & Milestones timeline then fell back to sorting those milestones by
/// name, which is why the owner called it out:
///
///   "the milestone timeline … usually, it should be chronological where you
///    know, okay, starting from December, 2026. This is the first milestone.
///    Next milestone is February, 2027 …"
///
/// [parseMilestoneDate] understands the formats the field actually receives so
/// the timeline can be ordered by date. It never guesses which of two numeric
/// parts is the day: a three-part date is only resolved when one side is 13+,
/// and an ambiguous one (`01/02/2026`) anchors to its year rather than to an
/// arbitrary day.
library;

const Map<String, int> _kMonthNumbers = <String, int>{
  'january': 1,
  'jan': 1,
  'february': 2,
  'feb': 2,
  'march': 3,
  'mar': 3,
  'april': 4,
  'apr': 4,
  'may': 5,
  'june': 6,
  'jun': 6,
  'july': 7,
  'jul': 7,
  'august': 8,
  'aug': 8,
  'september': 9,
  'sept': 9,
  'sep': 9,
  'october': 10,
  'oct': 10,
  'november': 11,
  'nov': 11,
  'december': 12,
  'dec': 12,
};

/// `2026-09-15`, `2026/09/15`, `2026.09.15`, optionally with a time after `T`.
final RegExp _kFullDate =
    RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:[t ].*)?$');

/// `2026-09` — year first, so it is unambiguous.
final RegExp _kYearMonth = RegExp(r'^(\d{4})[-/.](\d{1,2})$');

/// `09/2026` — the four-digit side identifies the year.
final RegExp _kMonthYear = RegExp(r'^(\d{1,2})[-/.](\d{4})$');

/// `15/12/2026` or `12/15/2026` — resolved only when a part is 13 or more.
final RegExp _kThreePartDate = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$');

final RegExp _kMonthName = RegExp(
  r'\b(' + _kMonthNumbers.keys.join('|') + r')\b',
);
final RegExp _kQuarter = RegExp(r'\bq([1-4])\b');
final RegExp _kQuarterWord = RegExp(
  r'\b(?:quarter\s*([1-4])|([1-4])(?:st|nd|rd|th)?\s+quarter)\b',
);
final RegExp _kDayNumber = RegExp(
  r'(?:^|[^\d])(\d{1,2})(?:st|nd|rd|th)?(?:[^\d]|$)',
);
final RegExp _kYear = RegExp(r'(?:^|[^\d])(\d{4})(?:[^\d]|$)');

/// Parses a milestone target date, or returns null when the text carries no
/// readable date at all.
///
/// Supported: `2026-09-15` (and `/` or `.` separators, with an optional time),
/// `2026-09` / `09/2026`, quarters (`Q3 2026`, `2027 Q1`, `3rd quarter 2026`),
/// month names with an optional day (`December 2026`, `Dec 15, 2026`,
/// `15 Dec 2026`) and a bare year (`2027`).
///
/// Values that name a month, quarter or year only anchor to the first day of
/// that period, which is enough to order them.
DateTime? parseMilestoneDate(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final normalized = text
      .toLowerCase()
      .replaceAll(RegExp(r'[.,]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // 2026-09-15 (optionally with a time). Validated here rather than through
  // DateTime.tryParse, which rolls "2026-13-01" into 2027-01-01.
  final full = _kFullDate.firstMatch(normalized);
  if (full != null) {
    return _build(
        int.parse(full.group(1)!), int.parse(full.group(2)!), int.parse(full.group(3)!));
  }

  // 2026-09
  final yearMonth = _kYearMonth.firstMatch(normalized);
  if (yearMonth != null) {
    return _build(
        int.parse(yearMonth.group(1)!), int.parse(yearMonth.group(2)!), 1);
  }

  // 09/2026
  final monthYear = _kMonthYear.firstMatch(normalized);
  if (monthYear != null) {
    return _build(
        int.parse(monthYear.group(2)!), int.parse(monthYear.group(1)!), 1);
  }

  // 15/12/2026 or 12/15/2026. A part of 13+ can only be a day, so the order is
  // known; when both parts are 12 or less the text is ambiguous and is anchored
  // to its year instead of guessing.
  final threePart = _kThreePartDate.firstMatch(normalized);
  if (threePart != null) {
    final first = int.parse(threePart.group(1)!);
    final second = int.parse(threePart.group(2)!);
    final year = int.parse(threePart.group(3)!);
    if (first > 12 && second <= 12) return _build(year, second, first);
    if (second > 12 && first <= 12) return _build(year, first, second);
    return DateTime(year, 1, 1);
  }

  final yearMatch = _kYear.firstMatch(normalized);
  final year = yearMatch == null ? null : int.parse(yearMatch.group(1)!);

  // A quarter of a year: "Q3 2026", "2027 Q1", "3rd quarter 2026".
  final quarterMatch = _kQuarter.firstMatch(normalized) ??
      _kQuarterWord.firstMatch(normalized);
  if (quarterMatch != null && year != null) {
    final quarterIndex =
        int.parse(quarterMatch.group(1) ?? quarterMatch.group(2)!);
    return DateTime(year, (quarterIndex - 1) * 3 + 1, 1);
  }

  // A month name, with or without a day and year: "December 2026",
  // "Dec 15, 2026", "15 Dec 2026".
  final monthMatch = _kMonthName.firstMatch(normalized);
  if (monthMatch != null) {
    final month = _kMonthNumbers[monthMatch.group(1)!]!;
    if (year == null) {
      // Only a lone month name ("December") is treated as a date. Anything
      // else that merely contains a month word ("May need review") is not.
      return normalized == monthMatch.group(1)
          ? DateTime(DateTime.now().year, month, 1)
          : null;
    }
    final dayMatch = _kDayNumber.firstMatch(normalized);
    final day = dayMatch == null ? 1 : int.parse(dayMatch.group(1)!);
    return _build(year, month, day);
  }

  // A bare year: "2027", "FY2027".
  if (year != null) return DateTime(year, 1, 1);

  return null;
}

/// Builds a date, rejecting out-of-range values instead of letting [DateTime]
/// roll them into the next period (`2026-13-01` must not become January 2027,
/// `2026-02-31` must not become March 3).
DateTime? _build(int year, int month, int day) {
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > 31) return null;
  final candidate = DateTime(year, month, day);
  if (candidate.month != month || candidate.day != day) return null;
  return candidate;
}
