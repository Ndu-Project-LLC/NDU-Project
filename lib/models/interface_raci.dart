/// The Interface Management RACI matrix and its governance rows.
///
/// Owner, Lusaka 27, on the RACI & Governance tab:
///
///   "I'm not sure how this came about. So this information you detailed got
///    filled up from where, what's that information?" … "when did you assign
///    yourself to that?"
///
/// The answer the screen never gave: **nobody assigns anything to the matrix**.
/// Every row is one interface from the Interface Register and every letter is
/// read from that interface's own fields — R is its Party A (provider), A is its
/// Owner, C is its Party B (receiver). Informed has **no** field on
/// [InterfaceEntry], so it used to be filled with a hardcoded `'Team'` on every
/// row; it now says [kRaciNotSet], because inventing an answer is what made the
/// tab unreadable in the first place.
///
/// The mapping, the coverage counts and the governance rows live here so the
/// screen, and the test, state the same thing.
library;

import 'package:flutter/foundation.dart';

import 'package:ndu_project/models/project_data_model.dart';

/// What a RACI cell says when the interface has no value for it.
const String kRaciNotSet = 'Not set';

/// The four RACI roles.
enum RaciRole { responsible, accountable, consulted, informed }

extension RaciRoleInfo on RaciRole {
  /// `R` / `A` / `C` / `I`.
  String get letter {
    switch (this) {
      case RaciRole.responsible:
        return 'R';
      case RaciRole.accountable:
        return 'A';
      case RaciRole.consulted:
        return 'C';
      case RaciRole.informed:
        return 'I';
    }
  }

  /// What the role means, in the owner's words ("does the work").
  String get meaning {
    switch (this) {
      case RaciRole.responsible:
        return 'does the work';
      case RaciRole.accountable:
        return 'owns the outcome';
      case RaciRole.consulted:
        return 'provides input';
      case RaciRole.informed:
        return 'is kept up to date';
    }
  }

  /// The Interface Register field the matrix reads for this role. This is the
  /// answer to "where did that come from?".
  String get sourceField {
    switch (this) {
      case RaciRole.responsible:
        return 'Party A (provider)';
      case RaciRole.accountable:
        return 'Owner';
      case RaciRole.consulted:
        return 'Party B (receiver)';
      case RaciRole.informed:
        return 'not captured on the register yet';
    }
  }

  /// Whether the Interface Register stores this role at all.
  bool get isCaptured => this != RaciRole.informed;

  /// One line for the legend: `R — Party A (provider) does the work`. Kept short
  /// on purpose — the legend sits in a `Wrap`, so a long line wrapped inside
  /// its item is the difference between a tidy legend and an overflow.
  String get legendLine =>
      isCaptured ? '$letter — $sourceField $meaning' : '$letter — $sourceField';
}

/// One interface as it appears in the matrix and in the governance table.
///
/// Pure mapping from [InterfaceEntry], so the role assignment is unit-testable
/// without a widget tree.
@immutable
class InterfaceRaciRow {
  const InterfaceRaciRow({
    required this.number,
    required this.id,
    required this.name,
    required this.responsible,
    required this.accountable,
    required this.consulted,
    required this.informed,
    required this.cadence,
    required this.escalationPath,
    required this.lastSync,
    required this.status,
  });

  /// The 1-based row number, so a row can be referred to in a meeting.
  final int number;

  final String id;
  final String name;
  final String responsible;
  final String accountable;
  final String consulted;

  /// Always empty today — [InterfaceEntry] has no informed field.
  final String informed;

  final String cadence;
  final String escalationPath;
  final String lastSync;
  final String status;

  factory InterfaceRaciRow.fromEntry(InterfaceEntry entry, {required int number}) {
    final boundary = entry.boundary.trim();
    final status = entry.status.trim();
    return InterfaceRaciRow(
      number: number,
      id: entry.id,
      name: boundary.isEmpty ? 'Unnamed interface' : boundary,
      responsible: entry.partyA.trim(),
      accountable: entry.owner.trim(),
      consulted: entry.partyB.trim(),
      // There is no informed field on the register, so there is nothing to
      // show and nothing to invent.
      informed: '',
      cadence: entry.cadence.trim(),
      escalationPath: entry.escalationPath.trim(),
      lastSync: entry.lastSync.trim(),
      status: status.isEmpty ? 'Pending' : status,
    );
  }

  /// Maps every registered interface, numbered in register order.
  static List<InterfaceRaciRow> fromEntries(List<InterfaceEntry> entries) => <
      InterfaceRaciRow>[
    for (var i = 0; i < entries.length; i++)
      InterfaceRaciRow.fromEntry(entries[i], number: i + 1),
  ];

  /// The raw register value for [role], or `''` when it is blank.
  String rawValueFor(RaciRole role) {
    switch (role) {
      case RaciRole.responsible:
        return responsible;
      case RaciRole.accountable:
        return accountable;
      case RaciRole.consulted:
        return consulted;
      case RaciRole.informed:
        return informed;
    }
  }

  /// What the cell shows: the value, or [kRaciNotSet].
  String valueFor(RaciRole role) {
    final value = rawValueFor(role);
    return value.isEmpty ? kRaciNotSet : value;
  }

  bool isFilled(RaciRole role) => rawValueFor(role).isNotEmpty;

  /// Interfaces with no accountable owner are the ones that stall.
  bool get hasNoAccountable => accountable.isEmpty;

  bool get hasNoResponsible => responsible.isEmpty;

  bool get hasNoConsulted => consulted.isEmpty;

  /// Governance gaps: nobody to chase, no rhythm, never synced.
  bool get hasNoCadence => cadence.isEmpty;

  bool get isNeverSynced => lastSync.isEmpty;

  bool get hasGovernanceGap => hasNoAccountable || hasNoCadence || isNeverSynced;
}

/// How complete the matrix is, for the summary chips above it.
@immutable
class RaciCoverage {
  const RaciCoverage({
    required this.total,
    required this.missingResponsible,
    required this.missingAccountable,
    required this.missingConsulted,
    required this.missingCadence,
    required this.neverSynced,
  });

  final int total;
  final int missingResponsible;
  final int missingAccountable;
  final int missingConsulted;
  final int missingCadence;
  final int neverSynced;

  static const RaciCoverage empty = RaciCoverage(
    total: 0,
    missingResponsible: 0,
    missingAccountable: 0,
    missingConsulted: 0,
    missingCadence: 0,
    neverSynced: 0,
  );

  factory RaciCoverage.fromRows(List<InterfaceRaciRow> rows) {
    if (rows.isEmpty) return empty;
    var missingResponsible = 0;
    var missingAccountable = 0;
    var missingConsulted = 0;
    var missingCadence = 0;
    var neverSynced = 0;
    for (final row in rows) {
      if (row.hasNoResponsible) missingResponsible++;
      if (row.hasNoAccountable) missingAccountable++;
      if (row.hasNoConsulted) missingConsulted++;
      if (row.hasNoCadence) missingCadence++;
      if (row.isNeverSynced) neverSynced++;
    }
    return RaciCoverage(
      total: rows.length,
      missingResponsible: missingResponsible,
      missingAccountable: missingAccountable,
      missingConsulted: missingConsulted,
      missingCadence: missingCadence,
      neverSynced: neverSynced,
    );
  }

  /// How many cells across the matrix and its governance columns still need a
  /// value. Informed is excluded: the register has nowhere to put it.
  int get gaps =>
      missingResponsible +
      missingAccountable +
      missingConsulted +
      missingCadence +
      neverSynced;

  bool get hasGaps => gaps > 0;

  bool get isEmpty => total == 0;
}
