import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/utils/agile_ceremony_schedule.dart';

Map<AgileCeremony, AgileCeremonyEntry> _valid() => {
      AgileCeremony.sprintPlanning: const AgileCeremonyEntry(
          weekdays: {DateTime.monday}, durationMinutes: 120),
      AgileCeremony.dailyStandup: const AgileCeremonyEntry(
          weekdays: {1, 2, 3, 4, 5}, durationMinutes: 15),
      AgileCeremony.backlogGrooming: const AgileCeremonyEntry(
          weekdays: {DateTime.tuesday, DateTime.thursday}, durationMinutes: 60),
      AgileCeremony.sprintDemo: const AgileCeremonyEntry(
          weekdays: {DateTime.friday}, durationMinutes: 60),
      AgileCeremony.retrospective: const AgileCeremonyEntry(
          weekdays: {DateTime.friday}, durationMinutes: 60),
      AgileCeremony.blockersHub: const AgileCeremonyEntry(
          weekdays: {1, 2, 3, 4, 5}, durationMinutes: 60, enabled: false),
    };

void main() {
  group('duration caps', () {
    test('sprint planning is capped at 2 hours per sprint week', () {
      final rule = AgileCeremonyRules.ruleFor(AgileCeremony.sprintPlanning);
      expect(AgileCeremonyRules.maxMinutesFor(rule, 14), 240);
      expect(AgileCeremonyRules.maxMinutesFor(rule, 28), 480);
    });

    test('sprint demo is 2 hours for a standard 2-week sprint', () {
      final rule = AgileCeremonyRules.ruleFor(AgileCeremony.sprintDemo);
      expect(AgileCeremonyRules.maxMinutesFor(rule, 14), 120);
    });

    test('retrospective scales between 45 and 90 minutes', () {
      final rule = AgileCeremonyRules.ruleFor(AgileCeremony.retrospective);
      expect(AgileCeremonyRules.maxMinutesFor(rule, 7), 45);
      expect(AgileCeremonyRules.maxMinutesFor(rule, 14), 90);
      expect(AgileCeremonyRules.maxMinutesFor(rule, 42), 90);
    });
  });

  group('planCeremonySchedule', () {
    test('a default-style schedule is valid and totals per sprint', () {
      final plan = planCeremonySchedule(entries: _valid(), sprintDays: 14);
      expect(plan.isValid, isTrue, reason: plan.warnings.join('; '));
      // Planning 120 + stand-ups 5 days x 2 weeks x 15 + grooming 2 x 2 x 60
      // + demo 60 + retro 60; blockers hub is switched off.
      expect(plan.sprintMinutes[AgileCeremony.sprintPlanning], 120);
      expect(plan.sprintMinutes[AgileCeremony.dailyStandup], 150);
      expect(plan.sprintMinutes[AgileCeremony.backlogGrooming], 240);
      expect(plan.sprintMinutes.containsKey(AgileCeremony.blockersHub), isFalse);
      expect(plan.totalSprintMinutes, 630);
    });

    test('grooming must be 2 to 3 days a week', () {
      final entries = _valid()
        ..[AgileCeremony.backlogGrooming] = const AgileCeremonyEntry(
            weekdays: {DateTime.monday}, durationMinutes: 60);
      final plan = planCeremonySchedule(entries: entries, sprintDays: 14);
      expect(plan.isValid, isFalse);
      expect(plan.warnings.single, contains('Backlog Grooming'));
    });

    test('sprint planning recurs on exactly one day per sprint', () {
      final entries = _valid()
        ..[AgileCeremony.sprintPlanning] = const AgileCeremonyEntry(
            weekdays: {DateTime.monday, DateTime.wednesday},
            durationMinutes: 60);
      final plan = planCeremonySchedule(entries: entries, sprintDays: 14);
      expect(plan.warnings.single, contains('exactly 1 day'));
    });

    test('stand-up duration is fixed at 15 minutes', () {
      final entries = _valid()
        ..[AgileCeremony.dailyStandup] = const AgileCeremonyEntry(
            weekdays: {1, 2, 3, 4, 5}, durationMinutes: 30);
      final plan = planCeremonySchedule(entries: entries, sprintDays: 14);
      expect(plan.warnings.single, contains('Daily Stand-up'));
    });

    test('planning over the weekly cap is flagged', () {
      final entries = _valid()
        ..[AgileCeremony.sprintPlanning] = const AgileCeremonyEntry(
            weekdays: {DateTime.monday}, durationMinutes: 300);
      final plan = planCeremonySchedule(entries: entries, sprintDays: 14);
      expect(plan.warnings.single, contains('Sprint Planning'));
    });

    test('a required ceremony with no days is flagged', () {
      final entries = _valid()
        ..[AgileCeremony.sprintDemo] =
            const AgileCeremonyEntry(weekdays: {}, durationMinutes: 60);
      final plan = planCeremonySchedule(entries: entries, sprintDays: 14);
      expect(plan.warnings.single, contains('Sprint Demo'));
    });

    test('switching the optional blockers hub on adds its time', () {
      final entries = _valid()
        ..[AgileCeremony.blockersHub] = const AgileCeremonyEntry(
            weekdays: {1, 2, 3, 4, 5}, durationMinutes: 60);
      final plan = planCeremonySchedule(entries: entries, sprintDays: 14);
      expect(plan.isValid, isTrue);
      expect(plan.sprintMinutes[AgileCeremony.blockersHub], 600);
    });
  });

  group('AgileCeremonyEntry serialisation', () {
    test('round-trips weekdays, duration, and enabled', () {
      const entry = AgileCeremonyEntry(
          weekdays: {DateTime.friday, DateTime.monday},
          durationMinutes: 90,
          enabled: false);
      final restored = AgileCeremonyEntry.fromMap(entry.toMap());
      expect(restored.weekdays, {DateTime.monday, DateTime.friday});
      expect(restored.durationMinutes, 90);
      expect(restored.enabled, isFalse);
    });

    test('ignores weekday values outside 1..7', () {
      final restored = AgileCeremonyEntry.fromMap({
        'weekdays': [0, 3, 9, '5'],
        'durationMinutes': 15,
      });
      expect(restored.weekdays, {3, 5});
      expect(restored.enabled, isTrue);
    });
  });
}
