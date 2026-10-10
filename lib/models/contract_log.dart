import 'package:flutter/foundation.dart';

import 'package:ndu_project/models/contract_rfp_cycle.dart';
import 'package:ndu_project/services/contract_service.dart';

/// One column of the contract log.
@immutable
class ContractLogColumn {
  const ContractLogColumn(this.key, this.label);

  final String key;
  final String label;
}

/// The contract log columns, in order (Lusaka 27).
///
/// The owner asked for the table first — "that table needs to be here, as a
/// default view … this is where they have to go through the process of building
/// it out" — showing the contract's own name, scope and potential value (not an
/// "FEP scope input"), and the strategy/type **per contract**.
const List<ContractLogColumn> contractLogColumns = <ContractLogColumn>[
  ContractLogColumn('number', '#'),
  ContractLogColumn('name', 'Contract'),
  ContractLogColumn('scope', 'Scope'),
  ContractLogColumn('value', 'Potential Value'),
  ContractLogColumn('awardStrategy', 'Award Strategy'),
  ContractLogColumn('contractType', 'Type'),
  ContractLogColumn('cycle', 'RFP Cycle'),
  ContractLogColumn('awardDate', 'Award Date'),
  ContractLogColumn('status', 'Status'),
];

/// A contract as it appears in the log table.
///
/// Pure mapping from [ContractModel] so the row rules are unit-testable without
/// a widget tree.
@immutable
class ContractLogRow {
  const ContractLogRow({
    required this.number,
    required this.id,
    required this.name,
    required this.scope,
    required this.value,
    required this.awardStrategy,
    required this.contractType,
    required this.cycleSummary,
    required this.awardDate,
    required this.status,
    this.linkedFepScopeId,
    this.hasRfpCycle = false,
  });

  /// The 1-based row number the owner asked every table to carry.
  final int number;

  final String id;
  final String name;
  final String scope;
  final double value;
  final String awardStrategy;
  final String contractType;

  /// The RFP cycle in one line, or `Not set`.
  final String cycleSummary;

  /// The target award date, or null when it is not known yet.
  final DateTime? awardDate;

  final String status;

  /// The FEP scope this contract was created from, when there is one.
  final String? linkedFepScopeId;

  /// Whether a cycle (competitive or skipped) has been recorded.
  final bool hasRfpCycle;

  /// Builds a row from a contract. [number] is the 1-based row position.
  factory ContractLogRow.fromContract(
    ContractModel contract, {
    required int number,
  }) {
    final cycle = contract.rfpCycle;
    return ContractLogRow(
      number: number,
      id: contract.id,
      name: contract.name.trim().isEmpty ? 'Untitled contract' : contract.name.trim(),
      scope: (contract.packageSummary ?? '').trim().isNotEmpty
          ? contract.packageSummary!.trim()
          : contract.scope.trim().isEmpty
              ? contract.description.trim()
              : contract.scope.trim(),
      value: contract.estimatedValue,
      awardStrategy: (contract.awardStrategy ?? '').trim().isEmpty
          ? 'Not set'
          : contract.awardStrategy!.trim(),
      contractType: contract.contractType.trim().isEmpty
          ? 'Not set'
          : contract.contractType.trim(),
      cycleSummary: cycle == null ? 'Not set' : cycle.summary,
      awardDate: cycle?.awardDate ?? contract.targetAwardDate,
      status: contract.status.trim().isEmpty ? 'Not Started' : contract.status.trim(),
      linkedFepScopeId: contract.linkedFepScopeId,
      hasRfpCycle: cycle != null,
    );
  }

  /// A contract needs a strategy and a cycle before it can go to market.
  bool get isReadyForMarket =>
      hasRfpCycle &&
      awardStrategy != 'Not set' &&
      contractType != 'Not set';

  String valueFor(String key) {
    switch (key) {
      case 'number':
        return number.toString();
      case 'name':
        return name;
      case 'scope':
        return scope;
      case 'value':
        return value > 0 ? formatContractValue(value) : 'TBD';
      case 'awardStrategy':
        return awardStrategy;
      case 'contractType':
        return contractType;
      case 'cycle':
        return cycleSummary;
      case 'awardDate':
        return awardDate == null ? 'TBD' : formatCycleDate(awardDate!);
      case 'status':
        return status;
    }
    return '';
  }

  /// Free-text search over the row.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return <String>[
      name,
      scope,
      awardStrategy,
      contractType,
      cycleSummary,
      status,
      valueFor('value'),
      valueFor('awardDate'),
    ].any((field) => field.toLowerCase().contains(q));
  }

  /// Header labels in column order — what the PDF export prints.
  static List<String> get columnLabels =>
      <String>[for (final column in contractLogColumns) column.label];

  /// This row's values in column order — what the PDF export prints.
  List<String> get values =>
      <String>[for (final column in contractLogColumns) valueFor(column.key)];
}

/// The Contract Log exactly as the PDF export prints it: [ContractLogRow.columnLabels]
/// as the header and one numbered row per contract, in column order — so the
/// table a user sees and the table they download are built from the same thing.
List<String> contractLogExportHeaders() => ContractLogRow.columnLabels;

List<List<String>> contractLogExportRows(List<ContractModel> contracts) =>
    <List<String>>[
      for (var i = 0; i < contracts.length; i++)
        ContractLogRow.fromContract(contracts[i], number: i + 1).values,
    ];

/// `1,234,567` — the same grouping the contracting screen uses.
String formatContractValue(double value) {
  final rounded = value.round();
  return rounded.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => ',',
      );
}
