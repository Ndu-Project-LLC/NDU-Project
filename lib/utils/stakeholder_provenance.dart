/// Stakeholder provenance — proving where a carried row came from.
///
/// Product rule (Lusaka 25 (copy) voice note, 2026-09-17): the owner wanted the
/// stakeholder rows that arrive pre-filled to **show that they were carried
/// from the preferred solution**, and singled out the PM / Program Manager rows
/// as the ones he could not verify.
///
/// They could not be verified because the code took the first solution when the
/// preferred solution's title did not match:
///
/// ```dart
/// solutionStakeholderData.firstWhere(
///   (s) => s.solutionTitle == preferredSolution?.title,
///   orElse: () => solutionStakeholderData.first,   // ← silent substitution
/// );
/// ```
///
/// A viewer reading "Auto-loaded from Initiation Phase" then had no way to tell
/// a row genuinely carried from the preferred solution from one quietly taken
/// off a different candidate — and no way to tell an empty preferred solution
/// from a populated one. The fallback is still useful (better to show the
/// candidates' stakeholders than nothing), so it is kept, but it is now
/// **reported** rather than disguised.
library;

import 'package:ndu_project/models/project_data_model.dart';

/// Which solution's stakeholders were carried, and whether that was the
/// solution the project actually chose.
class CarriedStakeholderSource {
  const CarriedStakeholderSource({
    required this.data,
    required this.preferredTitle,
    required this.carriedTitle,
    required this.matchedPreferred,
  });

  /// The solution stakeholder data that was carried, or null when there is none.
  final SolutionStakeholderData? data;

  /// Title of the project's preferred solution, empty when none is selected yet.
  final String preferredTitle;

  /// Title of the solution the data actually came from.
  final String carriedTitle;

  /// True only when the carried data is the preferred solution's own.
  final bool matchedPreferred;

  /// True when there is nothing to carry.
  bool get isEmpty => data == null;

  /// Where this data came from, stated plainly.
  ///
  /// Anything other than a match says so, because the point of the note is to
  /// be checkable — a silent substitution would read exactly like the real
  /// thing.
  String get provenanceNote {
    if (preferredTitle.isEmpty) {
      return carriedTitle.isEmpty
          ? 'Carried from the Initiation Phase stakeholders'
          : 'Carried from the solution “$carriedTitle” — no preferred '
              'solution selected yet';
    }
    if (matchedPreferred) {
      return 'Carried from the preferred solution “$preferredTitle”';
    }
    if (carriedTitle.isEmpty) {
      return 'Carried from the Initiation Phase stakeholders — no entry for '
          'the preferred solution “$preferredTitle” yet';
    }
    return 'Carried from the solution “$carriedTitle” — not the preferred '
        'solution “$preferredTitle”';
  }
}

/// Resolve which solution's stakeholders to carry, recording whether it is
/// genuinely the preferred solution's.
///
/// Prefers the entry whose title matches [preferredTitle]. Falls back to the
/// first solution so a project mid-selection still shows its candidates, but
/// records that the fallback happened. Returns an empty source when there are
/// no solutions at all.
CarriedStakeholderSource resolveCarriedStakeholderSource({
  required List<SolutionStakeholderData> solutions,
  required String? preferredTitle,
}) {
  final preferred = (preferredTitle ?? '').trim();

  SolutionStakeholderData? matched;
  if (preferred.isNotEmpty) {
    for (final solution in solutions) {
      if (solution.solutionTitle.trim() == preferred) {
        matched = solution;
        break;
      }
    }
  }

  final chosen = matched ?? (solutions.isNotEmpty ? solutions.first : null);

  return CarriedStakeholderSource(
    data: chosen,
    preferredTitle: preferred,
    carriedTitle: (chosen?.solutionTitle ?? '').trim(),
    matchedPreferred: matched != null,
  );
}

/// True when a row's existing provenance note already records this source, so
/// re-running the carry does not stack duplicate notes.
bool provenanceNoteMatches(String existingNote, CarriedStakeholderSource source) {
  return existingNote.trim() == source.provenanceNote;
}
