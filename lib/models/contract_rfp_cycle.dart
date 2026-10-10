import 'package:flutter/foundation.dart';

/// The per-contract RFP cycle (Lusaka 27 planning review).
///
/// The owner asked for the award strategy, the contract type and the RFP cycle
/// to be set **per contract** — "the contract price is going to be by contract
/// basis … we can't have one story for the entire project" — and for a small
/// contract to be able to skip the cycle entirely ("they can elect to keep that
/// and say sole source or award … so they're not forced to go through the whole
/// process").
///
/// This module is pure: it holds the stage template with the owner's own
/// durations, converts a start date into dated stage windows, and validates the
/// cycle. It does not touch Firestore or the widget tree.
enum RfpCycleStage {
  /// "we are going to give two weeks to have this scope out to them"
  scopeOut('Scope out to bidders', 2),

  /// "we are going to send out the RFP" — a milestone, not a window.
  rfpIssued('RFP issued', 0),

  /// "we are going to give them four weeks to review and respond"
  bidderResponse('Bidder response window', 4),

  /// "one week for clarification"
  clarification('Clarification window', 1),

  /// "two weeks to review the contract and evaluate their responses"
  evaluation('Evaluation of responses', 2),

  /// "one week to give us all the documentation"
  documentation('Documentation', 1),

  /// "and then we are going to award the contract on this date"
  award('Contract award', 0);

  const RfpCycleStage(this.label, this.defaultWeeks);

  final String label;

  /// The owner's default duration for the stage, in weeks. Zero for the two
  /// milestone stages (`rfpIssued`, `award`).
  final int defaultWeeks;

  /// Milestones land on a single date rather than spanning a window.
  bool get isMilestone => defaultWeeks == 0;
}

/// Where a stage sits on the calendar.
@immutable
class RfpCycleWindow {
  const RfpCycleWindow({
    required this.stage,
    required this.start,
    required this.end,
  });

  final RfpCycleStage stage;
  final DateTime start;

  /// For a milestone this equals [start].
  final DateTime end;

  bool get isMilestone => stage.isMilestone;

  int get days => end.difference(start).inDays;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RfpCycleWindow &&
          other.stage == stage &&
          other.start == start &&
          other.end == end;

  @override
  int get hashCode => Object.hash(stage, start, end);

  @override
  String toString() => '${stage.name}: $start → $end';
}

/// Why a contract skipped the competitive cycle.
const List<String> kRfpCycleSkipReasons = <String>[
  'Sole Source',
  'Direct Award',
  'Small Value Contract',
  'Emergency',
  'Single Qualified Bidder',
];

/// The RFP cycle for one contract.
///
/// A contract either runs the full template (the default) or is [skipped] with a
/// [skipReason] because it is small enough that a competitive cycle is not worth
/// running. The award date is always known once the start date is set.
@immutable
class ContractRfpCycle {
  const ContractRfpCycle({
    required this.startDate,
    this.stageWeeks = kDefaultStageWeeks,
    this.skipped = false,
    this.skipReason = '',
  });

  /// The owner's template: 2 wk scope out, 4 wk response, 1 wk clarification,
  /// 2 wk evaluation, 1 wk documentation, then award. Ten weeks of work before
  /// award.
  static const Map<RfpCycleStage, int> kDefaultStageWeeks = <RfpCycleStage, int>{
    RfpCycleStage.scopeOut: 2,
    RfpCycleStage.bidderResponse: 4,
    RfpCycleStage.clarification: 1,
    RfpCycleStage.evaluation: 2,
    RfpCycleStage.documentation: 1,
  };

  /// The stages a user can adjust — the milestones are not resizable.
  static const List<RfpCycleStage> adjustableStages = <RfpCycleStage>[
    RfpCycleStage.scopeOut,
    RfpCycleStage.bidderResponse,
    RfpCycleStage.clarification,
    RfpCycleStage.evaluation,
    RfpCycleStage.documentation,
  ];

  /// The day the cycle opens: the start of "scope out to bidders".
  final DateTime startDate;

  /// Weeks for each adjustable stage; milestone stages are always zero.
  final Map<RfpCycleStage, int> stageWeeks;

  /// True when the contract is awarded without running the cycle.
  final bool skipped;

  /// Required when [skipped] is true; one of [kRfpCycleSkipReasons].
  final String skipReason;

  /// Starts a cycle on [startDate] using the owner's template.
  factory ContractRfpCycle.withDefaults(DateTime startDate) =>
      ContractRfpCycle(startDate: _dateOnly(startDate));

  /// Starts a cycle that lands its award on [awardDate] by back-planning the
  /// default template — used when a target award date already exists.
  factory ContractRfpCycle.backPlanFromAwardDate(DateTime awardDate) {
    final total = ContractRfpCycle(
      startDate: _dateOnly(awardDate),
    ).totalWeeks;
    return ContractRfpCycle(
      startDate: _dateOnly(awardDate).subtract(Duration(days: total * 7)),
    );
  }

  /// A skipped cycle: no windows, just a direct-award reason.
  factory ContractRfpCycle.skippedCycle({
    required DateTime startDate,
    required String reason,
  }) =>
      ContractRfpCycle(
        startDate: _dateOnly(startDate),
        skipped: true,
        skipReason: reason,
      );

  /// Weeks for [stage] — zero for milestones, whatever was set otherwise.
  int weeksFor(RfpCycleStage stage) {
    if (stage.isMilestone) return 0;
    return stageWeeks[stage] ?? stage.defaultWeeks;
  }

  /// Total weeks of work before the award date.
  int get totalWeeks =>
      adjustableStages.fold<int>(0, (sum, stage) => sum + weeksFor(stage));

  /// True when the cycle is skipped: no RFP is issued and the award is direct.
  bool get isSkipped => skipped;

  /// The dated windows, in order. Empty when the cycle is [skipped].
  ///
  /// Each window starts the day the previous one ended (inclusive ends, so the
  /// next stage starts the following day) and milestone stages collapse onto a
  /// single date.
  List<RfpCycleWindow> windows() {
    if (skipped) return const <RfpCycleWindow>[];
    final result = <RfpCycleWindow>[];
    var cursor = _dateOnly(startDate);
    for (final stage in RfpCycleStage.values) {
      final weeks = weeksFor(stage);
      if (stage.isMilestone) {
        result.add(RfpCycleWindow(stage: stage, start: cursor, end: cursor));
        continue;
      }
      final start = cursor;
      final end = start.add(Duration(days: weeks * 7 - 1));
      result.add(RfpCycleWindow(stage: stage, start: start, end: end));
      cursor = end.add(const Duration(days: 1));
    }
    return result;
  }

  /// The date the contract is awarded.
  ///
  /// For a skipped cycle the award sits on the start date (the next business
  /// decision, not a process), otherwise it is the `award` milestone — which is
  /// always the last window and equals start + [totalWeeks] weeks.
  DateTime get awardDate {
    if (skipped) return _dateOnly(startDate);
    return _dateOnly(startDate).add(Duration(days: totalWeeks * 7));
  }

  /// The date the RFP goes out to bidders: the `rfpIssued` milestone.
  DateTime get rfpIssuedDate {
    if (skipped) return _dateOnly(startDate);
    for (final window in windows()) {
      if (window.stage == RfpCycleStage.rfpIssued) return window.start;
    }
    return _dateOnly(startDate);
  }

  /// The bidder response deadline: the last day of the response window.
  DateTime get bidDueDate {
    if (skipped) return _dateOnly(startDate);
    for (final window in windows()) {
      if (window.stage == RfpCycleStage.bidderResponse) return window.end;
    }
    return awardDate;
  }

  /// A copy with one stage's duration changed, clamped to a sane 0–52 weeks.
  ContractRfpCycle withStageWeeks(RfpCycleStage stage, int weeks) {
    final next = Map<RfpCycleStage, int>.from(stageWeeks);
    next[stage] = weeks < 0 ? 0 : (weeks > 52 ? 52 : weeks);
    return ContractRfpCycle(
      startDate: startDate,
      stageWeeks: next,
      skipped: skipped,
      skipReason: skipReason,
    );
  }

  ContractRfpCycle withStartDate(DateTime value) => ContractRfpCycle(
        startDate: _dateOnly(value),
        stageWeeks: stageWeeks,
        skipped: skipped,
        skipReason: skipReason,
      );

  ContractRfpCycle asSkipped(String reason) => ContractRfpCycle(
        startDate: startDate,
        stageWeeks: stageWeeks,
        skipped: true,
        skipReason: reason,
      );

  ContractRfpCycle asCompetitive() => ContractRfpCycle(
        startDate: startDate,
        stageWeeks: stageWeeks,
      );

  /// One short line for a log row or a chip.
  String get summary {
    if (skipped) {
      return skipReason.trim().isEmpty
          ? 'Skipped'
          : 'Skipped — ${skipReason.trim()}';
    }
    return '$totalWeeks wk cycle · award ${formatCycleDate(awardDate)}';
  }

  /// `null` when the cycle is usable, otherwise what the user must fix.
  String? validate() {
    if (skipped) {
      if (skipReason.trim().isEmpty) {
        return 'Choose why this contract skips the RFP cycle.';
      }
      if (!kRfpCycleSkipReasons.contains(skipReason.trim())) {
        return 'Unknown skip reason: $skipReason';
      }
      return null;
    }
    if (totalWeeks < 1) {
      return 'The cycle needs at least one week of work before award.';
    }
    return null;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'startDate': _dateOnly(startDate).toIso8601String(),
        'stageWeeks': <String, int>{
          for (final entry in stageWeeks.entries)
            entry.key.name: weeksFor(entry.key),
        },
        'skipped': skipped,
        'skipReason': skipReason,
      };

  static ContractRfpCycle? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final start = _parseDate(map['startDate']);
    if (start == null) return null;
    final weeks = <RfpCycleStage, int>{};
    final rawWeeks = map['stageWeeks'];
    if (rawWeeks is Map) {
      for (final stage in adjustableStages) {
        final value = rawWeeks[stage.name];
        if (value is num) weeks[stage] = value.toInt();
      }
    }
    return ContractRfpCycle(
      startDate: _dateOnly(start),
      stageWeeks: weeks.isEmpty ? kDefaultStageWeeks : weeks,
      skipped: map['skipped'] == true,
      skipReason: (map['skipReason'] ?? '').toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContractRfpCycle &&
          other.startDate == startDate &&
          other.skipped == skipped &&
          other.skipReason == skipReason &&
          _sameWeeks(other.stageWeeks, stageWeeks);

  @override
  int get hashCode =>
      Object.hash(startDate, skipped, skipReason, totalWeeks);

  @override
  String toString() => 'ContractRfpCycle($summary)';
}

bool _sameWeeks(Map<RfpCycleStage, int> a, Map<RfpCycleStage, int> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
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

/// `MMM dd, yyyy` without pulling `intl` into a pure model used by tests.
String formatCycleDate(DateTime date) {
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
