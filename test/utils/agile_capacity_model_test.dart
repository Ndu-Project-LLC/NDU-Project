// The review's ask: "ideally, I just want to be able to be updating this thing"
// — capacity tied to the delivery model's cadence ("we said it was going to be
// two weeks") rather than a hardcoded two weeks. These tests pin the part that
// makes the cadence real: changing the sprint length changes the numbers.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/utils/agile_capacity_model.dart';

void main() {
  group('reading the delivery model cadence', () {
    test('weeks parse to days', () {
      expect(AgileCapacityModel.sprintLengthDaysFor('1 Week'), 7);
      expect(AgileCapacityModel.sprintLengthDaysFor('2 Weeks'), 14);
      expect(AgileCapacityModel.sprintLengthDaysFor('3 Weeks'), 21);
      expect(AgileCapacityModel.sprintLengthDaysFor('4 Weeks'), 28);
    });

    test('a missing or non-weekly cadence falls back to two weeks', () {
      expect(AgileCapacityModel.sprintLengthDaysFor(''), 14);
      expect(AgileCapacityModel.sprintLengthDaysFor('Kanban'),
          AgileCapacityModel.fallbackSprintDays);
      expect(AgileCapacityModel.sprintLengthDaysFor('0 Weeks'), 14,
          reason: 'a zero-length sprint is not a cadence');
    });

    test('the label reads back the same cadence', () {
      expect(AgileCapacityModel.cadenceLabelFor('2 Weeks'), '2-week sprint');
      expect(AgileCapacityModel.cadenceLabelFor(''), '2-week sprint');
    });
  });

  group('changing the sprint length recomputes capacity', () {
    test('working days and hours follow the cadence', () {
      final oneWeek = AgileCapacityModel.derive(sprintLengthDays: 7);
      final twoWeeks = AgileCapacityModel.derive(sprintLengthDays: 14);

      expect(oneWeek.sprintWorkingDays, 5);
      expect(twoWeeks.sprintWorkingDays, 10);
      expect(oneWeek.sprintHours, 40);
      expect(twoWeeks.sprintHours, 80);
      expect(twoWeeks.cadenceLabel, '2-week sprint · 10 working days');
    });

    test('a per-week velocity scales with the cadence', () {
      final oneWeek = AgileCapacityModel.derive(
        sprintLengthDays: 7,
        velocityBasis: VelocityBasis.perWeek,
      );
      final twoWeeks = AgileCapacityModel.derive(
        sprintLengthDays: 14,
        velocityBasis: VelocityBasis.perWeek,
      );

      expect(twoWeeks.capacityPerSprint,
          closeTo(oneWeek.capacityPerSprint * 2, 0.001),
          reason: 'twice the sprint is twice the per-week velocity');
      expect(twoWeeks.capacityPerWeek,
          closeTo(oneWeek.capacityPerWeek, 0.001),
          reason: 'the weekly rate is a property of the team, not the sprint');
    });

    test('a per-sprint velocity does not change with the cadence', () {
      final oneWeek = AgileCapacityModel.derive(sprintLengthDays: 7);
      final twoWeeks = AgileCapacityModel.derive(sprintLengthDays: 14);

      expect(oneWeek.capacityPerSprint, closeTo(twoWeeks.capacityPerSprint, 0.001),
          reason: 'the team already stated the number per sprint');
      expect(twoWeeks.capacityPerWeek,
          lessThan(oneWeek.capacityPerWeek),
          reason: 'the same points spread over a longer sprint is a slower week');
    });
  });

  group('the factors applied to the sprint', () {
    test('leave and holidays come off the working days first', () {
      final plan = AgileCapacityModel.derive(
        sprintLengthDays: 14,
        leaveDays: 2,
        holidayDays: 1,
      );

      expect(plan.sprintWorkingDays, 7);
      expect(plan.sprintHours, 56);
    });

    test('meeting overhead is spread across the whole sprint', () {
      final oneWeek = AgileCapacityModel.derive(
        sprintLengthDays: 7,
        meetingOverheadHoursPerWeek: 4,
      );
      final twoWeeks = AgileCapacityModel.derive(
        sprintLengthDays: 14,
        meetingOverheadHoursPerWeek: 4,
      );

      expect(oneWeek.meetingOverheadHours, 4);
      expect(twoWeeks.meetingOverheadHours, 8);
      expect(twoWeeks.focusFactor, closeTo(oneWeek.focusFactor, 0.001),
          reason: 'hours and overhead grow together, so the share is stable');
    });

    test('a sprint with no hours has no capacity instead of dividing by zero',
        () {
      final plan = AgileCapacityModel.derive(
        sprintLengthDays: 7,
        leaveDays: 5,
      );

      expect(plan.sprintWorkingDays, 0);
      expect(plan.focusFactor, 0);
      expect(plan.capacityPerSprint, 0);
    });
  });
}
