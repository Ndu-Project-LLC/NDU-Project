import 'package:ndu_project/models/agile_release_plan.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/roadmap_sprint.dart';
import 'package:ndu_project/models/staffing_row.dart';
import 'package:ndu_project/utils/agile_capacity_model.dart';
import 'package:ndu_project/utils/agile_ceremony_schedule.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedule, milestone, cost, and calendar calculations for the agile delivery
/// model. Everything here is pure so it can be tested without Firestore or UI.

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysBetween(DateTime from, DateTime to) =>
    _dayOnly(to).difference(_dayOnly(from)).inDays;

bool _isDone(AgileTask story) => story.status.trim().toLowerCase() == 'done';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Sprints that have an end date, in planning order.
List<RoadmapSprint> _sortedSprints(List<RoadmapSprint> sprints) {
  final list = sprints.where((s) => s.endDate != null).toList()
    ..sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return (a.startDate ?? a.endDate!).compareTo(b.startDate ?? b.endDate!);
    });
  return list;
}

// ── Release milestones and red flags ─────────────────────────────────────────

enum RedFlagSeverity { warning, critical }

class RedFlag {
  final RedFlagSeverity severity;
  final String message;

  const RedFlag(this.severity, this.message);

  @override
  bool operator ==(Object other) =>
      other is RedFlag && other.severity == severity && other.message == message;

  @override
  int get hashCode => Object.hash(severity, message);
}

/// One release milestone: the stories (and therefore epics and features) that
/// must be complete by its date, when the plan finishes them, and any flags.
class ReleaseMilestoneStatus {
  final AgileReleasePlan release;
  final List<AgileTask> stories;
  final List<String> epicIds;
  final List<String> featureIds;
  final int totalPoints;
  final int unscheduledStories;

  /// End date of the last sprint holding a story for this release.
  final DateTime? plannedCompletion;

  /// Days the plan finishes after the release date (negative = early).
  final int? varianceDays;
  final List<RedFlag> flags;

  const ReleaseMilestoneStatus({
    required this.release,
    required this.stories,
    required this.epicIds,
    required this.featureIds,
    required this.totalPoints,
    required this.unscheduledStories,
    required this.plannedCompletion,
    required this.varianceDays,
    required this.flags,
  });
}

/// A story belongs to a release by its planned release when one is set;
/// otherwise by the release's feature list.
bool _storyBelongsToRelease(AgileTask story, AgileReleasePlan release) {
  if (story.plannedReleaseId.isNotEmpty) {
    return story.plannedReleaseId == release.id;
  }
  return release.featureIds.contains(story.featureId);
}

List<ReleaseMilestoneStatus> buildReleaseMilestones({
  required List<AgileReleasePlan> releases,
  required List<AgileTask> stories,
  required List<RoadmapSprint> sprints,
}) {
  final sprintEnd = <String, DateTime>{
    for (final s in sprints)
      if (s.endDate != null) s.id: _dayOnly(s.endDate!),
  };

  return releases.map((release) {
    final owned =
        stories.where((s) => _storyBelongsToRelease(s, release)).toList();
    final epicIds = <String>{
      ...release.epicIds,
      ...owned.map((s) => s.epicId).where((id) => id.isNotEmpty),
    }.toList();
    final featureIds = <String>{
      ...release.featureIds,
      ...owned.map((s) => s.featureId).where((id) => id.isNotEmpty),
    }.toList();

    DateTime? completion;
    var unscheduled = 0;
    for (final story in owned) {
      final end = sprintEnd[story.plannedSprintId];
      if (end == null) {
        unscheduled++;
        continue;
      }
      if (completion == null || end.isAfter(completion)) {
        completion = end;
      }
    }

    final releaseDate = release.releaseDate;
    final variance = (releaseDate != null && completion != null)
        ? _daysBetween(releaseDate, completion)
        : null;

    final flags = <RedFlag>[];
    if (owned.isEmpty) {
      flags.add(const RedFlag(
          RedFlagSeverity.warning, 'No stories are assigned to this release yet.'));
    }
    if (unscheduled > 0) {
      flags.add(RedFlag(
          RedFlagSeverity.warning,
          '$unscheduled ${unscheduled == 1 ? 'story has' : 'stories have'} '
          'no sprint, so the completion date is not yet known.'));
    }
    if (variance != null && variance > 0) {
      flags.add(RedFlag(
          RedFlagSeverity.critical,
          'Milestone at risk: the plan finishes $variance day'
          '${variance == 1 ? '' : 's'} after the release date.'));
    }

    return ReleaseMilestoneStatus(
      release: release,
      stories: owned,
      epicIds: epicIds,
      featureIds: featureIds,
      totalPoints: owned.fold(0, (sum, s) => sum + s.storyPoints),
      unscheduledStories: unscheduled,
      plannedCompletion: completion,
      varianceDays: variance,
      flags: flags,
    );
  }).toList();
}

/// Sprints whose planned points exceed their available capacity. Re-pointing
/// stories or reprioritising them into a full sprint shows up here.
List<RedFlag> buildSprintCapacityFlags({
  required List<AgileTask> stories,
  required List<RoadmapSprint> sprints,
}) {
  final flags = <RedFlag>[];
  for (final sprint in _sortedSprints(sprints)) {
    final available = (sprint.capacityPoints * sprint.focusFactor).round();
    if (available <= 0) continue;
    final planned = stories
        .where((s) => s.plannedSprintId == sprint.id)
        .fold<int>(0, (sum, s) => sum + s.storyPoints);
    if (planned > available) {
      final name =
          sprint.name.isNotEmpty ? sprint.name : 'Sprint ${sprint.order}';
      flags.add(RedFlag(
          RedFlagSeverity.warning,
          '$name is over capacity by ${planned - available} pts '
          '($planned planned, $available available).'));
    }
  }
  return flags;
}

// ── Velocity-based forecast ──────────────────────────────────────────────────

class VelocityForecast {
  /// Points per sprint used for the forecast.
  final double velocity;

  /// True when velocity comes from completed sprints; false when it falls back
  /// to planned capacity because no sprint has finished yet.
  final bool velocityIsObserved;
  final int totalPoints;
  final int donePoints;
  final int remainingPoints;

  /// End of the last sprint the plan allocates stories to.
  final DateTime? idealCompletion;

  /// End of the sprint the team reaches at the current velocity.
  final DateTime? forecastCompletion;

  /// Forecast minus ideal, in days (positive = later than planned).
  final int? varianceDays;
  final int? sprintsRemaining;

  const VelocityForecast({
    required this.velocity,
    required this.velocityIsObserved,
    required this.totalPoints,
    required this.donePoints,
    required this.remainingPoints,
    required this.idealCompletion,
    required this.forecastCompletion,
    required this.varianceDays,
    required this.sprintsRemaining,
  });
}

VelocityForecast buildVelocityForecast({
  required List<AgileTask> stories,
  required List<RoadmapSprint> sprints,
  required DateTime today,
}) {
  final sorted = _sortedSprints(sprints);
  final totalPoints = stories.fold<int>(0, (sum, s) => sum + s.storyPoints);
  final donePoints =
      stories.where(_isDone).fold<int>(0, (sum, s) => sum + s.storyPoints);
  final remaining = totalPoints - donePoints;
  final todayDay = _dayOnly(today);

  // Observed velocity: average points completed in sprints that have ended and
  // hold planned stories. Before any sprint ends, use planned capacity.
  final completedSprints = sorted
      .where((s) =>
          _dayOnly(s.endDate!).isBefore(todayDay) &&
          stories.any((st) => st.plannedSprintId == s.id))
      .toList();
  var velocity = 0.0;
  var observed = false;
  if (completedSprints.isNotEmpty) {
    var completedPoints = 0;
    for (final sprint in completedSprints) {
      completedPoints += stories
          .where((st) => st.plannedSprintId == sprint.id && _isDone(st))
          .fold<int>(0, (sum, st) => sum + st.storyPoints);
    }
    velocity = completedPoints / completedSprints.length;
    observed = true;
  } else {
    final capacities = sorted
        .map((s) => s.capacityPoints * s.focusFactor)
        .where((c) => c > 0)
        .toList();
    if (capacities.isNotEmpty) {
      velocity = capacities.reduce((a, b) => a + b) / capacities.length;
    }
  }

  DateTime? ideal;
  for (final sprint in sorted) {
    if (stories.any((st) => st.plannedSprintId == sprint.id)) {
      final end = _dayOnly(sprint.endDate!);
      if (ideal == null || end.isAfter(ideal)) ideal = end;
    }
  }

  int? sprintsRemaining;
  DateTime? forecast;
  if (remaining <= 0) {
    sprintsRemaining = 0;
    forecast = ideal;
  } else if (velocity > 0) {
    sprintsRemaining = (remaining / velocity).ceil();
    forecast = _forecastEnd(sorted, todayDay, sprintsRemaining);
  }

  return VelocityForecast(
    velocity: velocity,
    velocityIsObserved: observed,
    totalPoints: totalPoints,
    donePoints: donePoints,
    remainingPoints: remaining < 0 ? 0 : remaining,
    idealCompletion: ideal,
    forecastCompletion: forecast,
    varianceDays: (forecast != null && ideal != null)
        ? _daysBetween(ideal, forecast)
        : null,
    sprintsRemaining: sprintsRemaining,
  );
}

/// End date of the [count]-th sprint counting from the current one. Sprints
/// beyond the defined list are extended at the average sprint length.
DateTime _forecastEnd(List<RoadmapSprint> sorted, DateTime today, int count) {
  final lengths = sorted
      .where((s) => s.startDate != null)
      .map((s) => _daysBetween(s.startDate!, s.endDate!) + 1)
      .where((d) => d > 0)
      .toList();
  final sprintLength = lengths.isEmpty
      ? AgileCapacityModel.fallbackSprintDays
      : (lengths.reduce((a, b) => a + b) / lengths.length).round();

  var index = sorted.indexWhere((s) => !_dayOnly(s.endDate!).isBefore(today));
  if (index < 0) index = sorted.length;

  var end = sorted.isEmpty ? today : _dayOnly(sorted.last.endDate!);
  for (var k = 0; k < count; k++) {
    final pos = index + k;
    if (pos < sorted.length) {
      end = _dayOnly(sorted[pos].endDate!);
    } else {
      end = end.add(Duration(days: sprintLength));
    }
  }
  return end;
}

// ── Agile cost ───────────────────────────────────────────────────────────────

class ExternalCostItem {
  final String id;
  final String name;

  /// 'Contract' | 'Purchase' | 'SSHER' | 'Other'
  final String category;
  final double amount;

  const ExternalCostItem({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'amount': amount,
      };

  factory ExternalCostItem.fromMap(Map<String, dynamic> map) => ExternalCostItem(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        category: map['category']?.toString() ?? 'Other',
        amount: (map['amount'] as num?)?.toDouble() ??
            double.tryParse(map['amount']?.toString() ?? '') ??
            0,
      );
}

class AgileCostSummary {
  /// Team cost per month: quantity x monthly rate across staffing rows.
  final double monthlyBurn;

  /// Labour budget from the staffing rows.
  final double plannedLabor;

  /// Labour at the forecast schedule length (equals [plannedLabor] when no
  /// dates are known).
  final double forecastLabor;

  /// Labour change caused by the forecast moving past the ideal finish.
  final double scheduleDeltaLabor;
  final double externalCost;
  final double totalCost;
  final double? forecastMonths;

  const AgileCostSummary({
    required this.monthlyBurn,
    required this.plannedLabor,
    required this.forecastLabor,
    required this.scheduleDeltaLabor,
    required this.externalCost,
    required this.totalCost,
    required this.forecastMonths,
  });
}

double parseMoney(String raw) =>
    double.tryParse(raw.replaceAll(',', '').replaceAll('\$', '').trim()) ?? 0;

/// Cost follows the team and the schedule: team labour scales with how long the
/// schedule runs, and external items (contracts, purchases, SSHER) are added as
/// entered.
AgileCostSummary buildAgileCostSummary({
  required List<StaffingRow> staffing,
  required List<ExternalCostItem> externalCosts,
  DateTime? projectStart,
  DateTime? idealFinish,
  DateTime? forecastFinish,
}) {
  final burn = staffing.fold<double>(
      0, (sum, row) => sum + row.quantity * parseMoney(row.monthlyCost));
  final planned = staffing.fold<double>(0, (sum, row) => sum + row.subtotal);
  final external =
      externalCosts.fold<double>(0, (sum, item) => sum + item.amount);

  const daysPerMonth = 30.4375;
  double? forecastMonths;
  var forecastLabor = planned;
  var delta = 0.0;
  if (projectStart != null && forecastFinish != null && burn > 0) {
    forecastMonths = _daysBetween(projectStart, forecastFinish) / daysPerMonth;
    forecastLabor = burn * forecastMonths;
    if (idealFinish != null) {
      final idealMonths =
          _daysBetween(projectStart, idealFinish) / daysPerMonth;
      delta = forecastLabor - burn * idealMonths;
    }
  }

  return AgileCostSummary(
    monthlyBurn: burn,
    plannedLabor: planned,
    forecastLabor: forecastLabor,
    scheduleDeltaLabor: delta,
    externalCost: external,
    totalCost: forecastLabor + external,
    forecastMonths: forecastMonths,
  );
}

// ── Calendar export (iCalendar) ──────────────────────────────────────────────

/// Start time of each ceremony on its day, in minutes from midnight. Retro
/// follows the demo when both fall on the same day.
const Map<AgileCeremony, int> ceremonyStartMinute = {
  AgileCeremony.dailyStandup: 9 * 60,
  AgileCeremony.blockersHub: 9 * 60 + 15,
  AgileCeremony.sprintPlanning: 10 * 60,
  AgileCeremony.backlogGrooming: 11 * 60,
  AgileCeremony.sprintDemo: 14 * 60,
  AgileCeremony.retrospective: 15 * 60 + 30,
};

String _two(int v) => v.toString().padLeft(2, '0');

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${_two(d.month)}${_two(d.day)}';

String _utcStamp(DateTime d) {
  final u = d.toUtc();
  return '${_dateStr(u)}T${_two(u.hour)}${_two(u.minute)}${_two(u.second)}Z';
}

String _escapeIcs(String text) => text
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\r\n', '\n')
    .replaceAll('\n', '\\n');

bool _zonesLoaded = false;

/// The timezone database entry for an IANA [name]. Throws if the name is not
/// recognised, rather than silently exporting the wrong times.
tz.Location _location(String name) {
  if (name == 'UTC') return tz.UTC;
  if (!_zonesLoaded) {
    tzdata.initializeTimeZones();
    _zonesLoaded = true;
  }
  return tz.getLocation(name);
}

/// Builds an iCalendar file with each enabled ceremony on the days it recurs in
/// every sprint, plus all-day sprint boundaries and release milestones.
///
/// Ceremony times are wall-clock times in [timezoneName] (an IANA name such as
/// 'America/New_York'), converted to UTC so they land on the right instant
/// whatever timezone each attendee's calendar uses. Daylight saving is applied
/// per event. All-day events are dates and carry no timezone.
String buildCeremonyIcs({
  required List<RoadmapSprint> sprints,
  required Map<AgileCeremony, AgileCeremonyEntry> ceremonies,
  required DateTime stamp,
  String calendarName = 'Agile Ceremonies',
  String timezoneName = 'UTC',
  List<MapEntry<String, DateTime>> releaseMilestones = const [],
}) {
  final zone = _location(timezoneName);
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//NDU Project//Agile Ceremonies//EN',
    'CALSCALE:GREGORIAN',
    'X-WR-CALNAME:${_escapeIcs(calendarName)}',
    'X-WR-TIMEZONE:${_escapeIcs(timezoneName)}',
  ];
  final dtstamp = _utcStamp(stamp);

  void addEvent({
    required String uid,
    required String summary,
    required String description,
    required String dtstartLine,
    required String dtendLine,
  }) {
    lines
      ..add('BEGIN:VEVENT')
      ..add('UID:$uid@ndu-project')
      ..add('DTSTAMP:$dtstamp')
      ..add(dtstartLine)
      ..add(dtendLine)
      ..add('SUMMARY:${_escapeIcs(summary)}');
    if (description.isNotEmpty) {
      lines.add('DESCRIPTION:${_escapeIcs(description)}');
    }
    lines.add('END:VEVENT');
  }

  void addAllDay(String uid, String summary, DateTime day) {
    final start = _dayOnly(day);
    final end = start.add(const Duration(days: 1));
    addEvent(
      uid: uid,
      summary: summary,
      description: '',
      dtstartLine: 'DTSTART;VALUE=DATE:${_dateStr(start)}',
      dtendLine: 'DTEND;VALUE=DATE:${_dateStr(end)}',
    );
  }

  bool active(AgileCeremony c) {
    final entry = ceremonies[c];
    return entry != null && entry.enabled && entry.weekdays.isNotEmpty;
  }

  /// Last day in [days] whose weekday the ceremony recurs on, if any.
  DateTime? lastMatch(List<DateTime> days, AgileCeremony c) {
    DateTime? found;
    for (final day in days) {
      if (ceremonies[c]!.weekdays.contains(day.weekday)) found = day;
    }
    return found;
  }

  /// First day in [days] whose weekday the ceremony recurs on, if any.
  DateTime? firstMatch(List<DateTime> days, AgileCeremony c) {
    for (final day in days) {
      if (ceremonies[c]!.weekdays.contains(day.weekday)) return day;
    }
    return null;
  }

  void addCeremony(String uid, AgileCeremony ceremony, DateTime day,
      {int? startMinute}) {
    final rule = AgileCeremonyRules.ruleFor(ceremony);
    final entry = ceremonies[ceremony]!;
    final minute = startMinute ?? ceremonyStartMinute[ceremony]!;
    final start = tz.TZDateTime(
        zone, day.year, day.month, day.day, minute ~/ 60, minute % 60);
    final end = start.add(Duration(minutes: entry.durationMinutes));
    addEvent(
      uid: uid,
      summary: rule.label,
      description: rule.purpose,
      dtstartLine: 'DTSTART:${_utcStamp(start)}',
      dtendLine: 'DTEND:${_utcStamp(end)}',
    );
  }

  for (final sprint in _sortedSprints(sprints)) {
    final from = _dayOnly(sprint.startDate ?? sprint.endDate!);
    final to = _dayOnly(sprint.endDate!);
    final label =
        sprint.name.isNotEmpty ? sprint.name : 'Sprint ${sprint.order}';
    final key = sprint.id.isNotEmpty ? sprint.id : '${sprint.order}';

    addAllDay('sprint-start-$key', '$label starts', from);
    addAllDay('sprint-end-$key', '$label ends', to);

    final days = <DateTime>[];
    for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }

    final demoDay =
        active(AgileCeremony.sprintDemo) ? lastMatch(days, AgileCeremony.sprintDemo) : null;

    for (final ceremony in AgileCeremony.values) {
      if (!active(ceremony)) continue;
      final rule = AgileCeremonyRules.ruleFor(ceremony);
      if (rule.perSprint) {
        // Planning opens the sprint; demo and retro close it.
        final day = ceremony == AgileCeremony.sprintPlanning
            ? firstMatch(days, ceremony)
            : lastMatch(days, ceremony);
        if (day == null) continue;
        int? startMinute;
        if (ceremony == AgileCeremony.retrospective &&
            demoDay != null &&
            _sameDay(day, demoDay)) {
          startMinute = ceremonyStartMinute[AgileCeremony.sprintDemo]! +
              ceremonies[AgileCeremony.sprintDemo]!.durationMinutes;
        }
        addCeremony('${ceremony.name}-$key', ceremony, day,
            startMinute: startMinute);
      } else {
        for (final day in days) {
          if (ceremonies[ceremony]!.weekdays.contains(day.weekday)) {
            addCeremony('${ceremony.name}-$key-${_dateStr(day)}', ceremony, day);
          }
        }
      }
    }
  }

  for (final milestone in releaseMilestones) {
    addAllDay(
        'release-${_dateStr(milestone.value)}-${milestone.key.hashCode}',
        'Release: ${milestone.key}',
        milestone.value);
  }

  lines.add('END:VCALENDAR');
  return lines.join('\r\n');
}
