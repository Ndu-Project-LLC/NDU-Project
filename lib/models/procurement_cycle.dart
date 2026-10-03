import 'package:flutter/foundation.dart';

/// The limited procurement cycle (Lusaka 27 follow-up).
///
/// The owner, on how procurement differs from contracting:
///
///   "It might not really have that whole cycle thing, but it might have like a
///    limited cycle — like we will identify a few … items, and we will get
///    their quotes, and then we will buy it. … it wouldn't really have that
///    whole contracting process, or something similar. So, I think we can do it
///    similar as well, both the user and us, just be consistent."
///
/// So: the same *shape* as the contract's RFP cycle (`contract_rfp_cycle.dart`)
/// — a start date, adjustable week counts per stage, dated windows, an
/// end-date — but three stages instead of seven. Pure module: no Firestore, no
/// widgets.
enum ProcurementCycleStage {
  /// The items are identified and listed for purchase.
  identify('Identify items', 1),

  /// Vendors are asked for quotes and the quotes come back.
  quote('Get quotes', 2),

  /// The purchase is made.
  purchase('Purchase', 0);

  const ProcurementCycleStage(this.label, this.defaultWeeks);

  final String label;

  /// The default duration in weeks; zero for the milestone stage.
  final int defaultWeeks;

  bool get isMilestone => defaultWeeks == 0;
}

/// Where a procurement stage sits on the calendar.
@immutable
class ProcurementCycleWindow {
  const ProcurementCycleWindow({
    required this.stage,
    required this.start,
    required this.end,
  });

  final ProcurementCycleStage stage;
  final DateTime start;

  /// For the milestone this equals [start].
  final DateTime end;

  bool get isMilestone => stage.isMilestone;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcurementCycleWindow &&
          other.stage == stage &&
          other.start == start &&
          other.end == end;

  @override
  int get hashCode => Object.hash(stage, start, end);

  @override
  String toString() => '${stage.name}: $start → $end';
}

/// The limited procurement cycle for a project's planned purchases.
///
/// The stages live in `ProcurementItemStatus` (`planning` → `rfqReview` →
/// `vendorSelection` → `ordered`), so the cycle's stage labels and the status
/// an item actually carries are two views of the same walk; this model owns
/// only the calendar.
@immutable
class ProcurementCycle {
  const ProcurementCycle({
    required this.startDate,
    this.stageWeeks = const {},
  });

  /// The day the cycle opens: the start of "identify items".
  final DateTime startDate;

  /// Weeks for each adjustable stage; the milestone is always zero.
  final Map<ProcurementCycleStage, int> stageWeeks;

  /// The stages a user can adjust.
  static const List<ProcurementCycleStage> adjustableStages =
      <ProcurementCycleStage>[
    ProcurementCycleStage.identify,
    ProcurementCycleStage.quote,
  ];

  /// The owner's template: 1 wk to identify, 2 wk for quotes, then purchase.
  static const Map<ProcurementCycleStage, int> kDefaultStageWeeks =
      <ProcurementCycleStage, int>{
    ProcurementCycleStage.identify: 1,
    ProcurementCycleStage.quote: 2,
  };

  /// Starts a cycle on [startDate] using the default template.
  factory ProcurementCycle.withDefaults(DateTime startDate) =>
      ProcurementCycle(startDate: _dateOnly(startDate));

  /// Weeks for [stage] — zero for the milestone, whatever was set otherwise.
  int weeksFor(ProcurementCycleStage stage) {
    if (stage.isMilestone) return 0;
    return stageWeeks[stage] ?? stage.defaultWeeks;
  }

  /// Total weeks before the purchase date.
  int get totalWeeks =>
      adjustableStages.fold<int>(0, (sum, stage) => sum + weeksFor(stage));

  /// The dated windows, in order. Each window starts the day after the
  /// previous one ended; the milestone collapses onto a single date.
  List<ProcurementCycleWindow> windows() {
    final result = <ProcurementCycleWindow>[];
    var cursor = _dateOnly(startDate);
    for (final stage in ProcurementCycleStage.values) {
      final weeks = weeksFor(stage);
      if (stage.isMilestone) {
        result
            .add(ProcurementCycleWindow(stage: stage, start: cursor, end: cursor));
        continue;
      }
      final start = cursor;
      final end = start.add(Duration(days: weeks * 7 - 1));
      result.add(ProcurementCycleWindow(stage: stage, start: start, end: end));
      cursor = end.add(const Duration(days: 1));
    }
    return result;
  }

  /// The date the purchase lands.
  DateTime get purchaseDate =>
      _dateOnly(startDate).add(Duration(days: totalWeeks * 7));

  /// A copy with one stage's duration changed, clamped to 0–52 weeks.
  ProcurementCycle withStageWeeks(ProcurementCycleStage stage, int weeks) {
    final next = Map<ProcurementCycleStage, int>.from(stageWeeks);
    next[stage] = weeks < 0 ? 0 : (weeks > 52 ? 52 : weeks);
    return ProcurementCycle(startDate: startDate, stageWeeks: next);
  }

  ProcurementCycle withStartDate(DateTime value) => ProcurementCycle(
        startDate: _dateOnly(value),
        stageWeeks: stageWeeks,
      );

  /// One short line for a card or chip.
  String get summary =>
      '$totalWeeks wk cycle · purchase ${formatProcurementCycleDate(purchaseDate)}';

  /// `null` when the cycle is usable, otherwise what the user must fix.
  String? validate() {
    if (totalWeeks < 1) {
      return 'The cycle needs at least one week before the purchase.';
    }
    return null;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'startDate': _dateOnly(startDate).toIso8601String(),
        'stageWeeks': <String, int>{
          for (final entry in stageWeeks.entries)
            entry.key.name: weeksFor(entry.key),
        },
      };

  static ProcurementCycle? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final start = _parseDate(map['startDate']);
    if (start == null) return null;
    final weeks = <ProcurementCycleStage, int>{};
    final rawWeeks = map['stageWeeks'];
    if (rawWeeks is Map) {
      for (final stage in adjustableStages) {
        final value = rawWeeks[stage.name];
        if (value is num) weeks[stage] = value.toInt();
      }
    }
    return ProcurementCycle(
      startDate: _dateOnly(start),
      stageWeeks: weeks.isEmpty ? kDefaultStageWeeks : weeks,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcurementCycle &&
          other.startDate == startDate &&
          _sameWeeks(other.stageWeeks, stageWeeks);

  @override
  int get hashCode => Object.hash(startDate, totalWeeks);

  @override
  String toString() => 'ProcurementCycle($summary)';
}

bool _sameWeeks(
    Map<ProcurementCycleStage, int> a, Map<ProcurementCycleStage, int> b) {
  for (final stage in ProcurementCycleStage.values) {
    final aWeeks = a[stage] ?? stage.defaultWeeks;
    final bWeeks = b[stage] ?? stage.defaultWeeks;
    if (aWeeks != bWeeks) return false;
  }
  return true;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString());
}

/// `MMM dd, yyyy` — the same shape the contract cycle prints, without pulling
/// `intl` into a pure model used by tests.
String formatProcurementCycleDate(DateTime date) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[date.month - 1];
  final day = date.day.toString().padLeft(2, '0');
  return '$month $day, ${date.year}';
}
