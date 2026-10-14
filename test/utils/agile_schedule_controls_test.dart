import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/models/agile_release_plan.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/roadmap_sprint.dart';
import 'package:ndu_project/models/staffing_row.dart';
import 'package:ndu_project/utils/agile_ceremony_schedule.dart';
import 'package:ndu_project/utils/agile_schedule_controls.dart';
import 'package:timezone/timezone.dart' as tz;

RoadmapSprint _sprint(String id, int order, DateTime start, DateTime end,
        {int capacity = 0, double focus = 1}) =>
    RoadmapSprint(
      id: id,
      name: 'Sprint $order',
      order: order,
      startDate: start,
      endDate: end,
      capacityPoints: capacity,
      focusFactor: focus,
    );

AgileTask _story(String id,
        {int points = 3,
        String status = 'To-Do',
        String sprint = '',
        String release = '',
        String feature = '',
        String epic = ''}) =>
    AgileTask(
      id: id,
      storyPoints: points,
      status: status,
      plannedSprintId: sprint,
      plannedReleaseId: release,
      featureId: feature,
      epicId: epic,
    );

void main() {
  // Two-week sprints: 1 = Jan 5–18, 2 = Jan 19–Feb 1, 3 = Feb 2–15.
  final s1 = _sprint('s1', 1, DateTime(2027, 1, 5), DateTime(2027, 1, 18),
      capacity: 10);
  final s2 = _sprint('s2', 2, DateTime(2027, 1, 19), DateTime(2027, 2, 1),
      capacity: 10);
  final s3 = _sprint('s3', 3, DateTime(2027, 2, 2), DateTime(2027, 2, 15),
      capacity: 10);
  final sprints = [s1, s2, s3];

  group('release milestones', () {
    test('a release finished before its date has no flags', () {
      final release = AgileReleasePlan(
          id: 'r1', releaseLabel: 'R1', releaseDate: DateTime(2027, 2, 20));
      final out = buildReleaseMilestones(
        releases: [release],
        stories: [_story('a', sprint: 's1', release: 'r1', epic: 'E1')],
        sprints: sprints,
      );
      expect(out.single.flags, isEmpty);
      expect(out.single.varianceDays, lessThan(0));
      expect(out.single.epicIds, ['E1']);
    });

    test('a plan that finishes after the release date is critical', () {
      final release = AgileReleasePlan(
          id: 'r1', releaseLabel: 'R1', releaseDate: DateTime(2027, 1, 18));
      final out = buildReleaseMilestones(
        releases: [release],
        stories: [_story('a', sprint: 's2', release: 'r1')],
        sprints: sprints,
      );
      final flags = out.single.flags;
      expect(flags.single.severity, RedFlagSeverity.critical);
      expect(out.single.varianceDays, 14);
    });

    test('unscheduled stories are flagged as a warning', () {
      final release = AgileReleasePlan(
          id: 'r1', releaseLabel: 'R1', releaseDate: DateTime(2027, 3, 1));
      final out = buildReleaseMilestones(
        releases: [release],
        stories: [
          _story('a', sprint: 's1', release: 'r1'),
          _story('b', release: 'r1'),
        ],
        sprints: sprints,
      );
      expect(out.single.unscheduledStories, 1);
      expect(out.single.flags.single.severity, RedFlagSeverity.warning);
    });

    test('a story without a release link belongs via its feature', () {
      final release = AgileReleasePlan(
          id: 'r1', releaseLabel: 'R1', releaseDate: DateTime(2027, 3, 1))
        ..featureIds = ['F1'];
      final out = buildReleaseMilestones(
        releases: [release],
        stories: [_story('a', sprint: 's1', feature: 'F1')],
        sprints: sprints,
      );
      expect(out.single.stories.map((s) => s.id), ['a']);
      expect(out.single.featureIds, contains('F1'));
    });

    test('an empty release is flagged', () {
      final release = AgileReleasePlan(id: 'r1', releaseLabel: 'R1');
      final out = buildReleaseMilestones(
        releases: [release],
        stories: const [],
        sprints: sprints,
      );
      expect(out.single.flags.single.message, contains('No stories'));
    });
  });

  test('sprints over capacity are flagged, with the overage', () {
    final flags = buildSprintCapacityFlags(
      stories: [
        _story('a', points: 8, sprint: 's1'),
        _story('b', points: 5, sprint: 's1'),
      ],
      sprints: sprints,
    );
    expect(flags.single.message, contains('over capacity by 3 pts'));
  });

  group('velocity forecast', () {
    test('uses planned capacity before any sprint has ended', () {
      final forecast = buildVelocityForecast(
        stories: [
          _story('a', points: 10, sprint: 's1'),
          _story('b', points: 10, sprint: 's2'),
        ],
        sprints: sprints,
        today: DateTime(2027, 1, 6),
      );
      expect(forecast.velocityIsObserved, isFalse);
      expect(forecast.velocity, 10);
      expect(forecast.idealCompletion, DateTime(2027, 2, 1));
      // 20 points at 10 per sprint: two sprints from the current one (s1).
      expect(forecast.sprintsRemaining, 2);
      expect(forecast.forecastCompletion, DateTime(2027, 2, 1));
      expect(forecast.varianceDays, 0);
    });

    test('observed velocity comes from completed sprints and moves the date',
        () {
      final stories = [
        _story('a', points: 4, status: 'Done', sprint: 's1'),
        _story('b', points: 4, status: 'Done', sprint: 's1'),
        _story('c', points: 5, sprint: 's2'),
        _story('d', points: 5, sprint: 's3'),
      ];
      final forecast = buildVelocityForecast(
        stories: stories,
        sprints: sprints,
        today: DateTime(2027, 1, 25),
      );
      expect(forecast.velocityIsObserved, isTrue);
      expect(forecast.velocity, 8);
      expect(forecast.remainingPoints, 10);
      // 10 points at 8 per sprint = 2 sprints from s2.
      expect(forecast.sprintsRemaining, 2);
      expect(forecast.forecastCompletion, DateTime(2027, 2, 15));
      expect(forecast.idealCompletion, DateTime(2027, 2, 15));
    });

    test('a finished project forecasts no remaining sprints', () {
      final forecast = buildVelocityForecast(
        stories: [_story('a', points: 3, status: 'Done', sprint: 's1')],
        sprints: sprints,
        today: DateTime(2027, 1, 25),
      );
      expect(forecast.sprintsRemaining, 0);
      expect(forecast.remainingPoints, 0);
    });
  });

  group('agile cost', () {
    final team = [
      StaffingRow(
          role: 'Dev', quantity: 2, monthlyCost: '5,000', durationMonths: '2'),
      StaffingRow(
          role: 'QA', quantity: 1, monthlyCost: '\$4,000', durationMonths: '2'),
    ];

    test('team burn is quantity times monthly rate', () {
      final cost = buildAgileCostSummary(
          staffing: team, externalCosts: const []);
      expect(cost.monthlyBurn, 14000);
      // 2 devs x 2 months x 5,000 + 1 QA x 2 months x 4,000.
      expect(cost.plannedLabor, 28000);
      expect(cost.forecastLabor, cost.plannedLabor);
      expect(cost.scheduleDeltaLabor, 0);
    });

    test('a schedule running past the ideal finish adds labour cost', () {
      final cost = buildAgileCostSummary(
        staffing: team,
        externalCosts: const [
          ExternalCostItem(
              id: 'x1', name: 'Vendor', category: 'Contract', amount: 2000),
        ],
        projectStart: DateTime(2027, 1, 1),
        idealFinish: DateTime(2027, 4, 1),
        forecastFinish: DateTime(2027, 5, 1),
      );
      // One month of extra burn: 14000 x (30 days / 30.4375).
      expect(cost.scheduleDeltaLabor, closeTo(14000 * 30 / 30.4375, 0.01));
      expect(cost.externalCost, 2000);
      expect(cost.totalCost, closeTo(cost.forecastLabor + 2000, 0.01));
    });

    test('external items round-trip through their map form', () {
      const item = ExternalCostItem(
          id: 'p1', name: 'Licence', category: 'Purchase', amount: 750.5);
      final back = ExternalCostItem.fromMap(item.toMap());
      expect(back.name, 'Licence');
      expect(back.category, 'Purchase');
      expect(back.amount, 750.5);
    });
  });

  group('calendar export', () {
    final ceremonies = {
      AgileCeremony.sprintPlanning: const AgileCeremonyEntry(
          weekdays: {DateTime.monday}, durationMinutes: 120),
      AgileCeremony.dailyStandup: const AgileCeremonyEntry(
          weekdays: {1, 2, 3, 4, 5}, durationMinutes: 15),
      AgileCeremony.backlogGrooming: const AgileCeremonyEntry(
          weekdays: {DateTime.tuesday}, durationMinutes: 60),
      AgileCeremony.sprintDemo: const AgileCeremonyEntry(
          weekdays: {DateTime.friday}, durationMinutes: 60),
      AgileCeremony.retrospective: const AgileCeremonyEntry(
          weekdays: {DateTime.friday}, durationMinutes: 60),
      AgileCeremony.blockersHub: const AgileCeremonyEntry(
          weekdays: {1, 2, 3, 4, 5}, durationMinutes: 60, enabled: false),
    };

    List<String> events(String ics) => ics
        .split('\r\n')
        .where((l) => l == 'BEGIN:VEVENT')
        .toList();

    String summaryLine(String ics, String summary) => ics
        .split('\r\n')
        .firstWhere((l) => l == 'SUMMARY:$summary', orElse: () => '');

    test('is a CRLF iCalendar file with the right event counts', () {
      // s1 Tue Jan 5 – Mon Jan 18 2027: 10 workdays (stand-ups), 2 Tuesdays
      // (grooming), 2 Fridays (demo and retro on the last), 2 Mondays
      // (planning on the first). Blockers hub is off.
      final ics = buildCeremonyIcs(
        sprints: [s1],
        ceremonies: ceremonies,
        stamp: DateTime.utc(2027, 1, 1, 12),
      );
      expect(ics.startsWith('BEGIN:VCALENDAR\r\n'), isTrue);
      expect(ics.endsWith('END:VCALENDAR'), isTrue);

      // 2 sprint boundaries + 1 planning + 10 stand-ups + 2 grooming +
      // 1 demo + 1 retro.
      expect(events(ics).length, 2 + 1 + 10 + 2 + 1 + 1);
    });

    test('planning is on the first chosen day, demo and retro on the last',
        () {
      final ics = buildCeremonyIcs(
        sprints: [s1],
        ceremonies: ceremonies,
        stamp: DateTime.utc(2027, 1, 1, 12),
      );
      expect(ics, contains('UID:sprintPlanning-s1@ndu-project'));
      // First Monday in Sprint 1 is Jan 11; last Friday is Jan 15. Default
      // zone is UTC, so these are the local times written as UTC instants.
      expect(ics, contains('DTSTART:20270111T100000Z'));
      expect(ics, contains('DTSTART:20270115T140000Z'));
    });

    test('retro starts after the demo when they fall on the same day', () {
      final ics = buildCeremonyIcs(
        sprints: [s1],
        ceremonies: ceremonies,
        stamp: DateTime.utc(2027, 1, 1, 12),
      );
      // Demo 14:00 for 60 min, so retro starts at 15:00 on Jan 15.
      expect(ics, contains('DTSTART:20270115T150000Z'));
    });

    test('times are converted from the configured timezone to UTC', () {
      // New York is UTC-5 in January: 10:00 local planning is 15:00 UTC.
      final ics = buildCeremonyIcs(
        sprints: [s1],
        ceremonies: ceremonies,
        stamp: DateTime.utc(2027, 1, 1, 12),
        timezoneName: 'America/New_York',
      );
      expect(ics, contains('DTSTART:20270111T150000Z'));
      expect(ics, contains('DTEND:20270111T170000Z'));
      expect(ics, contains('X-WR-TIMEZONE:America/New_York'));
    });

    test('daylight saving applies to each event date', () {
      // Sprint 4 is in July. New York is UTC-4 then, so the 09:00 stand-up
      // is 13:00 UTC, not the January offset of 14:00.
      final summer = _sprint(
          's4', 4, DateTime(2027, 7, 5), DateTime(2027, 7, 18));
      final ics = buildCeremonyIcs(
        sprints: [summer],
        ceremonies: ceremonies,
        stamp: DateTime.utc(2027, 1, 1, 12),
        timezoneName: 'America/New_York',
      );
      expect(ics, contains('DTSTART:20270705T130000Z'));
    });

    test('an unknown timezone is rejected rather than exported wrongly', () {
      expect(
        () => buildCeremonyIcs(
          sprints: [s1],
          ceremonies: ceremonies,
          stamp: DateTime.utc(2027, 1, 1, 12),
          timezoneName: 'Mars/Olympus',
        ),
        throwsA(isA<tz.LocationNotFoundException>()),
      );
    });

    test('disabled ceremonies are not exported', () {
      final ics = buildCeremonyIcs(
        sprints: [s1],
        ceremonies: ceremonies,
        stamp: DateTime.utc(2027, 1, 1, 12),
      );
      expect(summaryLine(ics, 'Blockers Hub (optional)'), isEmpty);
    });

    test('release milestones are added as all-day events with escaped text',
        () {
      final ics = buildCeremonyIcs(
        sprints: [s1],
        ceremonies: ceremonies,
        stamp: DateTime.utc(2027, 1, 1, 12),
        releaseMilestones: [
          MapEntry('Launch, phase 1; beta', DateTime(2027, 2, 1)),
        ],
      );
      expect(ics, contains('DTSTART;VALUE=DATE:20270201'));
      expect(ics, contains(r'SUMMARY:Release: Launch\, phase 1\; beta'));
    });
  });
}
