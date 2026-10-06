/// Whether the team states velocity per sprint or per week.
///
/// The review's input was the delivery model's cadence ("the other delivery
/// model, right? We said it was going to be two weeks"), and a per-week velocity
/// is the form that actually scales with it. Per-sprint stays the default
/// because that is what the field has always said.
enum VelocityBasis { perSprint, perWeek }

/// The capacity a cadence implies, derived rather than assumed.
class CapacityPlan {
  const CapacityPlan({
    required this.sprintLengthDays,
    required this.sprintWorkingDays,
    required this.meetingOverheadHours,
    required this.sprintHours,
    required this.focusFactor,
    required this.capacityPerSprint,
    required this.capacityPerWeek,
  });

  /// Length of the sprint, in days, as configured in the delivery model.
  final int sprintLengthDays;

  /// Weekdays available in the sprint.
  final int sprintWorkingDays;

  /// Meeting time lost across the whole sprint.
  final double meetingOverheadHours;

  /// Hours the sprint holds before availability and buffer are applied.
  final double sprintHours;

  /// The share of the sprint left for delivery work, 0–1.
  final double focusFactor;

  final double capacityPerSprint;
  final double capacityPerWeek;

  int get sprintWeeks => (sprintLengthDays / 7).round();

  /// What to show next to the numbers, e.g. "2-week sprint · 10 working days".
  String get cadenceLabel =>
      '$sprintWeeks-week sprint · $sprintWorkingDays working days';
}

/// The rules behind Capacity Planning.
///
/// Kept pure so the thing the review asked for — change the sprint length in the
/// delivery model and capacity recomputes — can be tested without Firestore.
class AgileCapacityModel {
  AgileCapacityModel._();

  /// Hours in a working day. Matches the 40-hour week the page has always
  /// assumed, now expressed per sprint instead of hardcoded.
  static const double hoursPerDay = 8;

  /// Used when the delivery model has no cadence saved: the two-week sprint the
  /// owner described.
  static const int fallbackSprintDays = 14;

  /// Length in days of a delivery-model `sprintLength` label such as
  /// `'2 Weeks'`. Blank, `'Kanban'`, or anything unparseable falls back to the
  /// two-week cadence rather than producing a zero-length sprint.
  static int sprintLengthDaysFor(String sprintLength) {
    final match =
        RegExp(r'(\d+)').firstMatch(sprintLength.trim().toLowerCase());
    if (match == null) return fallbackSprintDays;
    final weeks = int.tryParse(match.group(1) ?? '');
    if (weeks == null || weeks <= 0) return fallbackSprintDays;
    return weeks * 7;
  }

  /// A human label for a delivery-model cadence string.
  static String cadenceLabelFor(String sprintLength) {
    final days = sprintLengthDaysFor(sprintLength);
    if (days % 7 != 0) return '$days-day sprint';
    final weeks = days ~/ 7;
    return '$weeks-week sprint';
  }

  /// Derive the capacity numbers for one sprint under [sprintLengthDays].
  ///
  /// [leaveDays] and [holidayDays] are the days the page collects; they come off
  /// the working days before any other factor, so a planned holiday is visible
  /// in the number rather than silently absorbed.
  static CapacityPlan derive({
    int sprintLengthDays = fallbackSprintDays,
    int workingDaysPerWeek = 5,
    double availabilityPct = 80,
    double meetingOverheadHoursPerWeek = 4,
    double bufferPct = 15,
    double historicalVelocity = 30,
    VelocityBasis velocityBasis = VelocityBasis.perSprint,
    int leaveDays = 0,
    int holidayDays = 0,
  }) {
    final days =
        sprintLengthDays > 0 ? sprintLengthDays : fallbackSprintDays;
    final weeks = days / 7;
    final scheduledWorkingDays =
        (workingDaysPerWeek * weeks).round().clamp(0, 366);
    final lostDays = (leaveDays + holidayDays).clamp(0, scheduledWorkingDays);
    final sprintWorkingDays = scheduledWorkingDays - lostDays;
    final sprintHours = sprintWorkingDays * hoursPerDay;
    final meetingOverheadHours = meetingOverheadHoursPerWeek * weeks;

    // No hours means no focus to express; report zero rather than dividing.
    final double focusFactor;
    if (sprintHours <= 0) {
      focusFactor = 0;
    } else {
      final overheadFraction =
          (meetingOverheadHours / sprintHours).clamp(0.0, 1.0);
      final availability = (availabilityPct / 100).clamp(0.0, 1.0);
      final buffer = (bufferPct / 100).clamp(0.0, 1.0);
      focusFactor = availability * (1 - overheadFraction) * (1 - buffer);
    }

    final capacityPerSprint = velocityBasis == VelocityBasis.perSprint
        ? historicalVelocity * focusFactor
        : historicalVelocity * weeks * focusFactor;

    return CapacityPlan(
      sprintLengthDays: days,
      sprintWorkingDays: sprintWorkingDays,
      meetingOverheadHours: meetingOverheadHours,
      sprintHours: sprintHours,
      focusFactor: focusFactor,
      capacityPerSprint: capacityPerSprint,
      capacityPerWeek: weeks <= 0 ? 0 : capacityPerSprint / weeks,
    );
  }
}
