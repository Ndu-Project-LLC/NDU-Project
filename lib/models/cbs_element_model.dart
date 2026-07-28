class CbsElement {
  final String id;
  String code;
  String name;
  String parentCbsId;
  String costCategory;
  String costType;
  String description;

  // ── P1.2: Financial fields for cost rollup (per Integrated Project Controls guide) ──
  /// Budgeted amount for this CBS element.
  double budgetAmount;
  /// Committed amount (under contract or purchase order).
  double committedAmount;
  /// Actually spent/incurred amount.
  double spentAmount;
  /// Contingency reserve allocated to this element.
  double contingencyAmount;
  /// Whether this element is flagged as management reserve.
  bool isManagementReserve;
  /// Currency code (e.g. 'USD', 'EUR', 'GBP').
  String currency;

  // ── P1.4: Cross-references for WBS↔CBS↔OBS integration matrix ──
  /// WBS element ID cross-reference — links this cost account to its WBS node.
  String wbsId;
  /// OBS element ID cross-reference — links this cost account to the responsible org unit.
  String obsId;
  /// Control Account ID — links to the intersection of WBS + OBS for EVM rollup.
  String controlAccountId;

  // ── Hierarchy helpers ──
  /// Depth level in the CBS hierarchy (0 = root).
  int level;
  /// Full path from root (e.g. "1.2.3") for breadcrumb navigation.
  String path;
  /// Whether this element is active (soft delete support).
  bool isActive;
  /// Whether this element has been baselined.
  bool isBaselined;

  CbsElement({
    String? id,
    this.code = '',
    this.name = '',
    this.parentCbsId = '',
    this.costCategory = '',
    this.costType = '',
    this.description = '',
    this.budgetAmount = 0,
    this.committedAmount = 0,
    this.spentAmount = 0,
    this.contingencyAmount = 0,
    this.isManagementReserve = false,
    this.currency = 'USD',
    this.wbsId = '',
    this.obsId = '',
    this.controlAccountId = '',
    this.level = 0,
    this.path = '',
    this.isActive = true,
    this.isBaselined = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  /// Computed: remaining budget = budgetAmount - spentAmount.
  double get remainingBudget => budgetAmount - spentAmount;

  /// Computed: commitment utilization = committedAmount / budgetAmount (0-1+).
  double get commitmentUtilization =>
      budgetAmount > 0 ? committedAmount / budgetAmount : 0;

  /// Computed: spending efficiency = spentAmount / committedAmount (0-1+).
  double get spendingEfficiency =>
      committedAmount > 0 ? spentAmount / committedAmount : 0;

  /// Computed: cost variance = budgetAmount - spentAmount.
  double get costVariance => budgetAmount - spentAmount;

  /// Computed: cost performance index = spentAmount > 0 ? (budgetAmount * %complete) / spentAmount : 1.0.
  /// Note: For true CPI, EV must be supplied externally from linked Control Account.
  double get costPerformanceIndex => spentAmount > 0 ? budgetAmount / spentAmount : 1.0;

  CbsElement copyWith({
    String? code,
    String? name,
    String? parentCbsId,
    String? costCategory,
    String? costType,
    String? description,
    double? budgetAmount,
    double? committedAmount,
    double? spentAmount,
    double? contingencyAmount,
    bool? isManagementReserve,
    String? currency,
    String? wbsId,
    String? obsId,
    String? controlAccountId,
    int? level,
    String? path,
    bool? isActive,
    bool? isBaselined,
  }) {
    return CbsElement(
      id: id,
      code: code ?? this.code,
      name: name ?? this.name,
      parentCbsId: parentCbsId ?? this.parentCbsId,
      costCategory: costCategory ?? this.costCategory,
      costType: costType ?? this.costType,
      description: description ?? this.description,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      committedAmount: committedAmount ?? this.committedAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      contingencyAmount: contingencyAmount ?? this.contingencyAmount,
      isManagementReserve: isManagementReserve ?? this.isManagementReserve,
      currency: currency ?? this.currency,
      wbsId: wbsId ?? this.wbsId,
      obsId: obsId ?? this.obsId,
      controlAccountId: controlAccountId ?? this.controlAccountId,
      level: level ?? this.level,
      path: path ?? this.path,
      isActive: isActive ?? this.isActive,
      isBaselined: isBaselined ?? this.isBaselined,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'parentCbsId': parentCbsId,
        'costCategory': costCategory,
        'costType': costType,
        'description': description,
        'budgetAmount': budgetAmount,
        'committedAmount': committedAmount,
        'spentAmount': spentAmount,
        'contingencyAmount': contingencyAmount,
        'isManagementReserve': isManagementReserve,
        'currency': currency,
        'wbsId': wbsId,
        'obsId': obsId,
        'controlAccountId': controlAccountId,
        'level': level,
        'path': path,
        'isActive': isActive,
        'isBaselined': isBaselined,
      };

  factory CbsElement.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

    return CbsElement(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      parentCbsId: json['parentCbsId']?.toString() ?? '',
      costCategory: json['costCategory']?.toString() ?? '',
      costType: json['costType']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      budgetAmount: toDouble(json['budgetAmount']),
      committedAmount: toDouble(json['committedAmount']),
      spentAmount: toDouble(json['spentAmount']),
      contingencyAmount: toDouble(json['contingencyAmount']),
      isManagementReserve: json['isManagementReserve'] == true,
      currency: json['currency']?.toString() ?? 'USD',
      wbsId: json['wbsId']?.toString() ?? '',
      obsId: json['obsId']?.toString() ?? '',
      controlAccountId: json['controlAccountId']?.toString() ?? '',
      level: (json['level'] is num) ? (json['level'] as num).toInt() : 0,
      path: json['path']?.toString() ?? '',
      isActive: json['isActive'] != false,
      isBaselined: json['isBaselined'] == true,
    );
  }
}
