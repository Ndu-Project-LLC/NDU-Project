import 'package:ndu_project/utils/agile_capacity_model.dart';

/// The recurring agile ceremonies the Sprint Cadence & Calendar page schedules.
enum AgileCeremony {
  sprintPlanning,
  dailyStandup,
  backlogGrooming,
  sprintDemo,
  retrospective,
  blockersHub,
}

/// Static rules for one ceremony: what it is for, how often it may recur, and
/// how long a single session may last.
class AgileCeremonyRule {
  final AgileCeremony ceremony;
  final String label;
  final String purpose;

  /// Allowed number of weekdays a ceremony may recur on per week (or, for
  /// per-sprint ceremonies, the number of days chosen for the sprint).
  final int minDaysPerWeek;
  final int maxDaysPerWeek;

  /// Allowed duration of one session, in minutes.
  final int minMinutes;
  final int maxMinutes;

  /// True for ceremonies that happen once per sprint rather than every week.
  final bool perSprint;

  /// True when the ceremony may be left out of the schedule entirely.
  final bool optional;

  const AgileCeremonyRule({
    required this.ceremony,
    required this.label,
    required this.purpose,
    required this.minDaysPerWeek,
    required this.maxDaysPerWeek,
    required this.minMinutes,
    required this.maxMinutes,
    this.perSprint = false,
    this.optional = false,
  });
}

/// The guardrails from the agile delivery model. Durations that scale with the
/// sprint are computed by [AgileCeremonyRules.maxMinutesFor].
class AgileCeremonyRules {
  AgileCeremonyRules._();

  /// Sprint planning is capped at 2 hours per week of sprint length.
  static const int sprintPlanningMaxMinutesPerWeek = 120;

  /// Stand-ups are a fixed 15 minutes on every work day.
  static const int standupMinutes = 15;

  /// Backlog grooming sessions run 1 to 2 hours, 2 to 3 times a week.
  static const int groomingMinMinutes = 60;
  static const int groomingMaxMinutes = 120;

  /// Sprint demos are capped at 2 hours for a standard 2-week sprint.
  static const int demoMaxMinutesPerWeek = 60;

  /// Retrospectives run 45 to 90 minutes, longer for longer sprints.
  static const int retroMinMinutes = 45;
  static const int retroMaxMinutes = 90;

  /// The blockers hub is optional and limited to one hour after stand-up.
  static const int blockersHubMinutes = 60;

  static const List<AgileCeremonyRule> all = [
    AgileCeremonyRule(
      ceremony: AgileCeremony.sprintPlanning,
      label: 'Sprint Planning',
      purpose: 'Define the sprint goal and select the backlog items to build.',
      minDaysPerWeek: 1,
      maxDaysPerWeek: 1,
      minMinutes: 30,
      maxMinutes: 120,
      perSprint: true,
    ),
    AgileCeremonyRule(
      ceremony: AgileCeremony.dailyStandup,
      label: 'Daily Stand-up',
      purpose:
          'Sync on progress, align on the day, and call out blockers (15 min).',
      minDaysPerWeek: 1,
      maxDaysPerWeek: 5,
      minMinutes: standupMinutes,
      maxMinutes: standupMinutes,
    ),
    AgileCeremonyRule(
      ceremony: AgileCeremony.backlogGrooming,
      label: 'Backlog Grooming',
      purpose:
          'Review, estimate, and prioritise upcoming stories so two sprints stay groomed.',
      minDaysPerWeek: 2,
      maxDaysPerWeek: 3,
      minMinutes: groomingMinMinutes,
      maxMinutes: groomingMaxMinutes,
    ),
    AgileCeremonyRule(
      ceremony: AgileCeremony.sprintDemo,
      label: 'Sprint Demo',
      purpose: 'Demonstrate completed work to stakeholders and gather feedback.',
      minDaysPerWeek: 1,
      maxDaysPerWeek: 1,
      minMinutes: 30,
      maxMinutes: 120,
      perSprint: true,
    ),
    AgileCeremonyRule(
      ceremony: AgileCeremony.retrospective,
      label: 'Retrospective',
      purpose:
          'Reflect on process and dynamics after the review; pick 1 to 3 items to steward next sprint.',
      minDaysPerWeek: 1,
      maxDaysPerWeek: 1,
      minMinutes: retroMinMinutes,
      maxMinutes: retroMaxMinutes,
      perSprint: true,
    ),
    AgileCeremonyRule(
      ceremony: AgileCeremony.blockersHub,
      label: 'Blockers Hub (optional)',
      purpose:
          'Optional hour right after stand-up for blockers that affect two or more people.',
      minDaysPerWeek: 1,
      maxDaysPerWeek: 5,
      minMinutes: blockersHubMinutes,
      maxMinutes: blockersHubMinutes,
      optional: true,
    ),
  ];

  static AgileCeremonyRule ruleFor(AgileCeremony ceremony) =>
      all.firstWhere((r) => r.ceremony == ceremony);

  /// Longest allowed single session for [rule] in a sprint of [sprintDays].
  static int maxMinutesFor(AgileCeremonyRule rule, int sprintDays) {
    final weeks = _sprintWeeks(sprintDays);
    switch (rule.ceremony) {
      case AgileCeremony.sprintPlanning:
        // Planning is one session per sprint, capped per week of sprint length.
        return sprintPlanningMaxMinutesPerWeek * weeks;
      case AgileCeremony.sprintDemo:
        return demoMaxMinutesPerWeek * weeks;
      case AgileCeremony.retrospective:
        return (retroMinMinutes * weeks).clamp(retroMinMinutes, retroMaxMinutes);
      default:
        return rule.maxMinutes;
    }
  }

  static int _sprintWeeks(int sprintDays) {
    final weeks = (sprintDays / 7).round();
    return weeks < 1 ? 1 : weeks;
  }
}

/// One ceremony as the team chose it: the weekdays it recurs on and how long
/// each session lasts. Weekdays use [DateTime] numbering (1 = Monday ... 7 =
/// Sunday).
class AgileCeremonyEntry {
  final Set<int> weekdays;
  final int durationMinutes;
  final bool enabled;

  const AgileCeremonyEntry({
    this.weekdays = const {},
    this.durationMinutes = 0,
    this.enabled = true,
  });

  AgileCeremonyEntry copyWith({
    Set<int>? weekdays,
    int? durationMinutes,
    bool? enabled,
  }) =>
      AgileCeremonyEntry(
        weekdays: weekdays ?? this.weekdays,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toMap() => {
        'weekdays': weekdays.toList()..sort(),
        'durationMinutes': durationMinutes,
        'enabled': enabled,
      };

  factory AgileCeremonyEntry.fromMap(Map<String, dynamic> map) {
    final rawDays = map['weekdays'];
    return AgileCeremonyEntry(
      weekdays: rawDays is List
          ? rawDays
              .map((e) => int.tryParse(e.toString()) ?? 0)
              .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
              .toSet()
          : <int>{},
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
      enabled: map['enabled'] as bool? ?? true,
    );
  }
}

/// Derived totals and guardrail warnings for a full ceremony schedule.
class AgileCeremonyPlan {
  /// Minutes per sprint, per ceremony, for enabled ceremonies only.
  final Map<AgileCeremony, int> sprintMinutes;

  /// Human-readable guardrail violations. Empty when the schedule is valid.
  final List<String> warnings;

  const AgileCeremonyPlan({required this.sprintMinutes, required this.warnings});

  int get totalSprintMinutes =>
      sprintMinutes.values.fold(0, (sum, m) => sum + m);

  bool get isValid => warnings.isEmpty;
}

/// Validates a schedule against [AgileCeremonyRules] and totals its time for a
/// sprint of [sprintDays].
AgileCeremonyPlan planCeremonySchedule({
  required Map<AgileCeremony, AgileCeremonyEntry> entries,
  required int sprintDays,
}) {
  final weeks = (sprintDays / 7).round().clamp(1, 1000);
  final minutes = <AgileCeremony, int>{};
  final warnings = <String>[];

  for (final rule in AgileCeremonyRules.all) {
    final entry = entries[rule.ceremony];
    if (entry == null || !entry.enabled) {
      if (!rule.optional && entry != null && !entry.enabled) {
        warnings.add('${rule.label} is required and cannot be switched off.');
      }
      continue;
    }
    final days = entry.weekdays.length;
    if (days == 0) {
      if (!rule.optional) {
        warnings.add('${rule.label}: choose at least one day.');
      }
      continue;
    }
    if (days < rule.minDaysPerWeek || days > rule.maxDaysPerWeek) {
      warnings.add(rule.minDaysPerWeek == rule.maxDaysPerWeek
          ? '${rule.label}: choose exactly ${rule.minDaysPerWeek} day(s).'
          : '${rule.label}: choose ${rule.minDaysPerWeek} to ${rule.maxDaysPerWeek} days.');
    }
    final maxMinutes = AgileCeremonyRules.maxMinutesFor(rule, sprintDays);
    final duration = entry.durationMinutes;
    if (duration < rule.minMinutes || duration > maxMinutes) {
      warnings.add(
          '${rule.label}: duration must be ${rule.minMinutes}–$maxMinutes min.');
    }

    // Per-sprint ceremonies happen once per sprint on each chosen day; the
    // recurring ones happen on each chosen day every week of the sprint.
    final occurrences = rule.perSprint ? days : days * weeks;
    minutes[rule.ceremony] = occurrences * duration;
  }

  return AgileCeremonyPlan(sprintMinutes: minutes, warnings: warnings);
}

/// Sprint length in days for the schedule, from the delivery model's cadence
/// label (for example `'2 Weeks'`). Falls back to two weeks.
int ceremonySprintDays(String deliveryModelSprintLength) =>
    AgileCapacityModel.sprintLengthDaysFor(deliveryModelSprintLength);
