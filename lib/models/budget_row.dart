/// Model for a budget row in Progress Tracking.
///
/// P3.4: Added CBS/OBS/ControlAccount linkage for budget↔cost account
/// traceability, enabling budget rows to roll up into CBS hierarchy and
/// contribute to control account EVM calculations.
class BudgetRow {
  final String id;
  String category; // e.g., "Contracts", "Staffing", "Tools", etc.
  double plannedAmount;
  double actualAmount;
  String period; // e.g., "Q1 2024", "Monthly", etc.
  String notes; // Manual notes only, no AI generation

  // ── P3.4: CBS linkage for cost account traceability ──
  /// CBS element ID — links this budget row to its cost breakdown element.
  String cbsId;
  /// OBS element ID — links this budget row to the responsible org unit.
  String obsId;
  /// Control Account ID — links to WBS+OBS intersection for EVM rollup.
  String controlAccountId;
  /// WBS element ID — links this budget row to the work element.
  String wbsId;
  /// Cost type classification: 'direct' | 'indirect' | 'contingency' | 'management_reserve'
  String costType;
  /// Commitment status: 'uncommitted' | 'committed' | 'spent' | 'closed'
  String commitmentStatus;

  BudgetRow({
    String? id,
    this.category = '',
    this.plannedAmount = 0.0,
    this.actualAmount = 0.0,
    this.period = '',
    this.notes = '',
    this.cbsId = '',
    this.obsId = '',
    this.controlAccountId = '',
    this.wbsId = '',
    this.costType = 'direct',
    this.commitmentStatus = 'uncommitted',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  /// Calculate variance (actual - planned)
  double get variance => actualAmount - plannedAmount;

  /// Calculate variance percentage
  double get variancePercent {
    if (plannedAmount == 0) return 0.0;
    return (variance / plannedAmount) * 100;
  }

  /// Calculate earned value based on commitment status.
  /// Committed amounts count as earned for EVM purposes.
  double get earnedValue {
    switch (commitmentStatus) {
      case 'spent':
        return actualAmount;
      case 'committed':
        return plannedAmount * 0.5; // 50/50 rule for committed
      default:
        return 0;
    }
  }

  /// Calculate remaining commitment (planned minus actual).
  double get remainingCommitment => plannedAmount - actualAmount;

  BudgetRow copyWith({
    String? category,
    double? plannedAmount,
    double? actualAmount,
    String? period,
    String? notes,
    String? cbsId,
    String? obsId,
    String? controlAccountId,
    String? wbsId,
    String? costType,
    String? commitmentStatus,
  }) {
    return BudgetRow(
      id: id,
      category: category ?? this.category,
      plannedAmount: plannedAmount ?? this.plannedAmount,
      actualAmount: actualAmount ?? this.actualAmount,
      period: period ?? this.period,
      notes: notes ?? this.notes,
      cbsId: cbsId ?? this.cbsId,
      obsId: obsId ?? this.obsId,
      controlAccountId: controlAccountId ?? this.controlAccountId,
      wbsId: wbsId ?? this.wbsId,
      costType: costType ?? this.costType,
      commitmentStatus: commitmentStatus ?? this.commitmentStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'plannedAmount': plannedAmount,
        'actualAmount': actualAmount,
        'period': period,
        'notes': notes,
        'cbsId': cbsId,
        'obsId': obsId,
        'controlAccountId': controlAccountId,
        'wbsId': wbsId,
        'costType': costType,
        'commitmentStatus': commitmentStatus,
      };

  factory BudgetRow.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    return BudgetRow(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      category: json['category']?.toString() ?? '',
      plannedAmount: parseDouble(json['plannedAmount']),
      actualAmount: parseDouble(json['actualAmount']),
      period: json['period']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      cbsId: json['cbsId']?.toString() ?? '',
      obsId: json['obsId']?.toString() ?? '',
      controlAccountId: json['controlAccountId']?.toString() ?? '',
      wbsId: json['wbsId']?.toString() ?? '',
      costType: json['costType']?.toString() ?? 'direct',
      commitmentStatus: json['commitmentStatus']?.toString() ?? 'uncommitted',
    );
  }
}
