/// Technology Planning → cost roll-up.
///
/// Product rule (Lusaka 25 (copy) voice note, 2026-09-17): the Technology
/// Planning budget totals disagreed with the rows on screen — the owner read
/// **"270"** where the table said **"150/month"** — and asked for **"a total
/// per table, then a subtotal for the section, then the grand total across the
/// project duration … and it should land as one line in the Cost Estimate."**
///
/// Two real defects sat behind that complaint, and both are fixed here rather
/// than in the widget:
///
/// 1. **Wrong number.** The old parser grabbed the *first* number in the string.
///    `"3 licences @ $150/month"` therefore parsed as **3**, not 150 — a total
///    with no relationship to the price the user typed. [parseCostAmount] now
///    prefers the amount carrying a currency symbol and otherwise takes the
///    largest number, which is the price in every realistic `qty @ price` form.
/// 2. **Not a total.** The metric card showed only the one-time sum under the
///    heading "Total Technology Budget", so recurring spend vanished. The
///    roll-up below exposes one-time, recurring and a genuine grand total over
///    the project's months, which is what the headline should have said.
///
/// Pure and deterministic: no AI, no I/O, no widget imports — the same shape as
/// `ssher_cost_lines.dart` and `risk_cost_lines.dart`, so it can be tested and
/// reused by the Cost Estimate pull.
library;

/// How often an entered cost recurs.
enum CostPeriod {
  /// Paid once (hardware, licences bought outright, implementation).
  oneTime,

  /// Billed per month.
  monthly,

  /// Billed per year.
  annual,
}

/// One priced technology row, already normalised for summing.
class TechnologyCostLine {
  const TechnologyCostLine({
    required this.table,
    required this.name,
    required this.amount,
    required this.period,
    required this.raw,
  });

  /// The table the row came from — "Technology Inventory", "AI Integrations",
  /// "External Integrations" — so the roll-up can total per table as asked.
  final String table;

  /// Row label, for the unpriced/ambiguous diagnostics.
  final String name;

  /// The amount as parsed, in the entered period.
  final double amount;

  final CostPeriod period;

  /// The original string, kept so the UI can show what was interpreted.
  final String raw;

  /// What this row costs over [months] of project life.
  double totalOver(int months) {
    switch (period) {
      case CostPeriod.oneTime:
        return amount;
      case CostPeriod.monthly:
        return amount * months;
      case CostPeriod.annual:
        return amount * (months / 12);
    }
  }
}

/// Totals for one table, plus the section and project-wide figures.
class TechnologyCostRollup {
  const TechnologyCostRollup({
    required this.lines,
    required this.oneTime,
    required this.monthly,
    required this.annual,
    required this.months,
  });

  final List<TechnologyCostLine> lines;

  /// Sum of everything paid once.
  final double oneTime;

  /// Sum of all *monthly* bills, expressed per month.
  final double monthly;

  /// Sum of all *annual* bills, expressed per year.
  final double annual;

  /// Project duration the grand total is projected over.
  final int months;

  /// Recurring spend stated per month across the whole set.
  double get recurringPerMonth => monthly + annual / 12;

  /// Recurring spend for one year — the figure the old UI labelled
  /// "Annual Running Costs".
  double get recurringPerYear => recurringPerMonth * 12;

  /// The genuine total: one-time spend plus recurring spend projected across
  /// the project's duration.
  double get grandTotal => oneTime + recurringPerMonth * months;

  /// Tabled totals, in first-seen order, so the UI can show a total per table.
  Map<String, double> totalsByTable() {
    final out = <String, double>{};
    for (final line in lines) {
      out[line.table] = (out[line.table] ?? 0) + line.totalOver(months);
    }
    return out;
  }
}

/// Parse the amount out of a loosely typed cost string.
///
/// Preference order:
/// 1. A number sitting next to a currency symbol (`$150`, `150 GBP`, `€1,200`)
///    — the price, even when a quantity precedes it.
/// 2. Otherwise the largest number — in `qty @ price` form the price is the
///    larger of the two, and unlike "first" or "last" this cannot be thrown off
///    by a trailing note.
///
/// Returns 0 when nothing numeric remains, so an empty or placeholder value
/// never becomes a silent zero-cost line.
double parseCostAmount(String raw) {
  // Strip digit-grouping commas ("12,000" is one number), then treat any
  // remaining comma as a separator so a list never concatenates its members.
  final text = raw
      .replaceAllMapped(RegExp(r'(?<=\d),(?=\d\d\d\b)'), (m) => '')
      .replaceAll(',', ' ');
  final numbers = RegExp(r'\d+(?:\.\d+)?')
      .allMatches(text)
      .map((m) => (value: double.tryParse(m.group(0)!) ?? 0, start: m.start))
      .toList();
  if (numbers.isEmpty) return 0;

  const symbols = r'[$£€¥]';
  const codes = r'(?:USD|GBP|EUR|ZMW|ZAR|KES|NGN|AUD|CAD|JPY)';

  // A symbol immediately before the number: "$150", "£150".
  for (final n in numbers) {
    final before = text.substring(0, n.start).trimRight();
    if (before.isNotEmpty &&
        RegExp('$symbols\$').hasMatch(before.substring(before.length - 1))) {
      return n.value;
    }
  }
  // A symbol or code immediately after the number: "150 GBP", "150/mo $".
  for (final n in numbers) {
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(text.substring(n.start))!;
    final after = text.substring(n.start + match.end).trimLeft();
    final head = after.length > 6 ? after.substring(0, 6) : after;
    if (RegExp('^$symbols').hasMatch(after) ||
        RegExp('^$codes\\b', caseSensitive: false).hasMatch(head)) {
      return n.value;
    }
  }

  return numbers
      .map((n) => n.value)
      .reduce((a, b) => a > b ? a : b);
}

/// Work out whether an entered cost is one-time, monthly or annual.
///
/// Defaults to [CostPeriod.oneTime] when nothing says otherwise — the same
/// assumption the previous code made, so an unqualified "12000" keeps behaving
/// as it did.
CostPeriod detectCostPeriod(String raw) {
  final text = raw.toLowerCase();
  if (text.contains('/month') ||
      text.contains('per month') ||
      text.contains('monthly') ||
      text.contains('pcm') ||
      text.contains('/mo') ||
      text.contains('pm')) {
    return CostPeriod.monthly;
  }
  if (text.contains('/year') ||
      text.contains('per year') ||
      text.contains('yearly') ||
      text.contains('annual') ||
      text.contains('annum') ||
      text.contains('p.a.') ||
      text.contains('/yr')) {
    return CostPeriod.annual;
  }
  return CostPeriod.oneTime;
}

/// Build the roll-up from already-gathered rows.
///
/// Rows with no usable amount are skipped rather than counted as zero, so an
/// unpriced row is visibly absent from the totals instead of quietly deflating
/// them.
TechnologyCostRollup rollUpTechnologyCosts({
  required Iterable<({String table, String name, String cost})> items,
  required int months,
}) {
  final safeMonths = months <= 0 ? 12 : months;
  final lines = <TechnologyCostLine>[];

  for (final item in items) {
    final name = item.name.trim();
    if (name.isEmpty) continue;
    final amount = parseCostAmount(item.cost);
    if (amount <= 0) continue;
    lines.add(
      TechnologyCostLine(
        table: item.table.trim().isEmpty ? 'Other' : item.table.trim(),
        name: name,
        amount: amount,
        period: detectCostPeriod(item.cost),
        raw: item.cost,
      ),
    );
  }

  double sumOf(CostPeriod period) => lines
      .where((l) => l.period == period)
      .fold<double>(0, (acc, l) => acc + l.amount);

  return TechnologyCostRollup(
    lines: lines,
    oneTime: sumOf(CostPeriod.oneTime),
    monthly: sumOf(CostPeriod.monthly),
    annual: sumOf(CostPeriod.annual),
    months: safeMonths,
  );
}

/// Whole months between two project dates, inclusive of the starting month.
///
/// Used to project recurring technology spend across the project rather than
/// across an invented year. Returns 0 when the dates are missing or inverted,
/// and the caller is expected to fall back to [defaultProjectMonths] — the
/// screen states that fallback rather than hiding it.
int projectMonthsBetween(DateTime? start, DateTime? end) {
  if (start == null || end == null) return 0;
  if (end.isBefore(start)) return 0;
  // Distinct calendar months touched, which is how recurring bills land: any
  // part of a month is billed, so 20 Jan → 10 Feb is two months, not one.
  return (end.year - start.year) * 12 + (end.month - start.month) + 1;
}

/// The duration used when the project has no milestone dates yet.
///
/// Stated rather than silent: the UI labels the projected figure with the
/// number of months it used, so nobody has to guess where "across the project"
/// came from.
const int defaultProjectMonths = 12;
