import 'package:ndu_project/models/risk_log.dart';

/// The required sign-off on the Planning Risk Assessment, and the allowance the
/// section has to show before the risk table (Lusaka 27).
///
/// Owner, on the Planning Risk Assessment:
///
///   "I confirm that I have reviewed this with all the key stakeholders. And we
///    have estimated this number as accepted. So that needs to be required for
///    the risk assessment section. But this is a required section for sure."
///
///   "for the top risks like say the high [ones] … we're going to require them
///    to have either like two to five top risks … those top risks they can then
///    have the specific [mitigation] plan for those top risks that can be seen
///    immediately"
///
///   "that is also going to be the cost estimate from the risk perspective. So
///    it is like 0.6 percent of the budget and that cost estimate will be put
///    before [the risk table]"
///
/// The rule lives here, pure, so the screen, the Next button and the tests all
/// read one definition of "this section is done".
class RiskAssessmentSignoff {
  const RiskAssessmentSignoff({
    this.confirmed = false,
    this.reviewedOn = '',
    this.reviewCadence = '',
  });

  /// The sentence the reviewer ticks — the owner's words, verbatim.
  static const String confirmationSentence =
      'I confirm that I have reviewed this with all the key stakeholders.';

  /// How often the log gets reviewed. Recorded so the section can require a
  /// real, repeating review rather than a one-off tick.
  static const List<String> reviewCadences = [
    'Monthly',
    'Quarterly',
    'Semi-annual',
    'Annual',
  ];

  /// The owner asked for "like two to five top risks".
  static const int minimumTopRisks = 2;
  static const int maximumTopRisks = 5;

  /// The risk allowance: 0.6 % of the project budget.
  static const double riskAllowancePercentOfBudget = 0.006;
  static const String riskAllowanceLabel = '0.6% of budget';

  /// Nothing recorded yet.
  static const RiskAssessmentSignoff empty = RiskAssessmentSignoff();

  /// The reviewer has ticked [confirmationSentence].
  final bool confirmed;

  /// When the log was reviewed with the stakeholders.
  final String reviewedOn;

  /// One of [reviewCadences].
  final String reviewCadence;

  bool get hasReviewDate => reviewedOn.trim().isNotEmpty;
  bool get hasCadence => reviewCadence.trim().isNotEmpty;

  static const String confirmedKey =
      'planning_risk_assessment_signoff_confirmed';
  static const String reviewedOnKey =
      'planning_risk_assessment_signoff_reviewed_on';
  static const String cadenceKey =
      'planning_risk_assessment_signoff_cadence';

  /// Reads the sign-off back out of the planning notes map, so the gate needs
  /// no new model field.
  static RiskAssessmentSignoff fromPlanningNotes(Map<String, String> notes) {
    return RiskAssessmentSignoff(
      confirmed: (notes[confirmedKey] ?? '').trim().toLowerCase() == 'true',
      reviewedOn: notes[reviewedOnKey] ?? '',
      reviewCadence: notes[cadenceKey] ?? '',
    );
  }

  /// The same three values, ready to merge into the planning notes map.
  Map<String, String> toPlanningNotes() => {
        confirmedKey: confirmed ? 'true' : 'false',
        reviewedOnKey: reviewedOn.trim(),
        cadenceKey: reviewCadence.trim(),
      };

  RiskAssessmentSignoff copyWith({
    bool? confirmed,
    String? reviewedOn,
    String? reviewCadence,
  }) {
    return RiskAssessmentSignoff(
      confirmed: confirmed ?? this.confirmed,
      reviewedOn: reviewedOn ?? this.reviewedOn,
      reviewCadence: reviewCadence ?? this.reviewCadence,
    );
  }

  /// The worst [maximumTopRisks] risks: High before Medium before Low, ties
  /// left in log order, capped at five. The rest of the log still shows in the
  /// table — this is only the subset a reviewer signs off on.
  static List<RiskLogRow> topRisks(
    List<RiskLogRow> rows, {
    int max = maximumTopRisks,
  }) {
    int rank(RiskLogRow row) {
      switch (RiskLogRow.normalizeScale(row.riskLevel)) {
        case 'High':
          return 0;
        case 'Medium':
          return 1;
        default:
          return 2;
      }
    }

    final indexed = rows.asMap().entries.toList()
      ..sort((a, b) {
        final byRank = rank(a.value).compareTo(rank(b.value));
        return byRank != 0 ? byRank : a.key.compareTo(b.key);
      });
    final ordered = [for (final entry in indexed) entry.value];
    return ordered.length <= max ? ordered : ordered.sublist(0, max);
  }

  /// Top risks that still have no mitigation plan of their own.
  static List<RiskLogRow> topRisksMissingMitigation(List<RiskLogRow> rows) => [
        for (final row in topRisks(rows))
          if (row.mitigation.trim().isEmpty) row,
      ];

  /// Risks with anything recorded — a title or a description.
  static List<RiskLogRow> _populated(List<RiskLogRow> rows) => [
        for (final row in rows)
          if (row.title.trim().isNotEmpty || row.description.trim().isNotEmpty)
            row,
      ];

  /// The one thing still blocking the section, or null when it is complete.
  /// Ordered most-fundamental first, so the message is always actionable.
  String? blockerFor(List<RiskLogRow> rows) {
    if (!confirmed) {
      return 'Tick the stakeholder confirmation to complete this section.';
    }
    if (!hasReviewDate) {
      return 'Record the date the risks were reviewed with the stakeholders.';
    }
    if (!hasCadence) {
      return 'Record how often the risk log is reviewed.';
    }
    if (_populated(rows).length < minimumTopRisks) {
      return 'The risk log needs at least $minimumTopRisks risks before this '
          'section can be signed off.';
    }
    final missing = topRisksMissingMitigation(rows);
    if (missing.isNotEmpty) {
      return '${missing.length} top ${missing.length == 1 ? 'risk needs' : 'risks need'} '
          'a mitigation plan.';
    }
    return null;
  }

  /// Whether the section may be completed.
  bool isComplete(List<RiskLogRow> rows) => blockerFor(rows) == null;

  /// 0.6 % of [budget]; 0 when no budget is known yet.
  static double riskAllowanceFor(double budget) =>
      budget <= 0 ? 0 : budget * riskAllowancePercentOfBudget;
}
