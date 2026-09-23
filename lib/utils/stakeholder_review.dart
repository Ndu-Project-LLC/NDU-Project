/// Which stakeholder rows are not yet actionable.
///
/// Product rule (Lusaka 25 (copy) voice note, 2026-09-17): **"we need to have an
/// actual name of the person"** and **"we put a pop-up that says they need to
/// ensure to review it … ensure that it's stakeholder name, organization and
/// title is currently reflected — so let's put the work on them to actually do
/// it."**
///
/// The owner's diagnosis of why the name goes missing is worth keeping: the
/// initiation phase lets a stakeholder be captured as an office rather than a
/// person — **"some people might put stakeholder on them and actually put the
/// name"** — so a row can arrive here holding an organisation with nobody
/// attached. That row cannot be engaged with, which is the whole point of the
/// register.
///
/// Pure and testable, like the other extract-and-verify helpers: it only reads
/// the entries and reports what is missing.
library;

import 'package:ndu_project/models/project_data_model.dart';

/// One field a stakeholder row is still missing.
enum StakeholderField { name, organization, role }

extension StakeholderFieldLabel on StakeholderField {
  /// How the field is described to the user.
  String get label => switch (this) {
        StakeholderField.name => 'name',
        StakeholderField.organization => 'organization',
        StakeholderField.role => 'title',
      };
}

/// A row with at least one empty field, and which fields are empty.
class StakeholderGap {
  final StakeholderEntry entry;
  final List<StakeholderField> missing;

  const StakeholderGap({required this.entry, required this.missing});

  /// True when the row has no person on it at all — the case the owner called
  /// out first, and the one that makes the register unusable.
  bool get hasNoPerson => missing.contains(StakeholderField.name);

  /// A short description for the prompt. Falls back to the organisation, then to
  /// a placeholder, so a row with no name is still identifiable in a list.
  String get describe {
    final name = entry.name.trim();
    if (name.isNotEmpty) return name;
    final org = entry.organization.trim();
    if (org.isNotEmpty) return '$org (no name)';
    return '(unnamed stakeholder)';
  }
}

/// The rows that still need work, in the order they were given.
///
/// A row with every field present is not a gap and is not returned. Whitespace
/// counts as empty: a field holding a space is not "reflected".
List<StakeholderGap> stakeholderGaps(Iterable<StakeholderEntry> entries) {
  final out = <StakeholderGap>[];

  for (final entry in entries) {
    final missing = <StakeholderField>[];
    if (entry.name.trim().isEmpty) missing.add(StakeholderField.name);
    if (entry.organization.trim().isEmpty) {
      missing.add(StakeholderField.organization);
    }
    if (entry.role.trim().isEmpty) missing.add(StakeholderField.role);
    if (missing.isEmpty) continue;
    out.add(StakeholderGap(entry: entry, missing: missing));
  }

  return out;
}

/// The single sentence shown at the top of the review prompt.
String stakeholderReviewSummary(int flagged, int total) {
  if (flagged == 0) return 'All stakeholders have a name, an organization and a title.';
  final rows = flagged == 1 ? 'stakeholder needs' : 'stakeholders need';
  return '$flagged of $total $rows a person, an organization or a title.';
}
