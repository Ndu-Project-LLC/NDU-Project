class ObsElement {
  final String id;
  String name;
  String parentObsId;
  String manager;
  String organization;
  String description;

  // ── P1.3: Organizational accountability fields (per Integrated Project Controls guide) ──
  /// Department or division name.
  String department;
  /// Role of this org unit within the project (e.g. 'Project Controls', 'Engineering Lead').
  String role;
  /// Responsibility statement — what this org unit is accountable for.
  String responsibility;
  /// Cost center code for financial tracking.
  String costCenter;
  /// Budget authority — maximum budget this unit can approve without escalation.
  double budgetAuthority;
  /// Capacity in FTE (full-time equivalent) available for this project.
  double capacityFte;
  /// Currently allocated FTE to this project.
  double allocatedFte;
  /// Availability percentage (0-1) = (capacityFte - allocatedFte) / capacityFte.
  /// Computed property below.

  // ── P1.4: Cross-references for WBS↔CBS↔OBS integration matrix ──
  /// WBS element ID cross-reference — links this org unit to its WBS node.
  String wbsId;
  /// CBS element ID cross-reference — links this org unit to its cost account.
  String cbsId;
  /// Control Account ID — links to the intersection of WBS + CBS for EVM rollup.
  String controlAccountId;

  // ── Hierarchy helpers ──
  /// Depth level in the OBS hierarchy (0 = root).
  int level;
  /// Full path from root (e.g. "1.2") for breadcrumb navigation.
  String path;
  /// Whether this element is active (soft delete support).
  bool isActive;

  ObsElement({
    String? id,
    this.name = '',
    this.parentObsId = '',
    this.manager = '',
    this.organization = '',
    this.description = '',
    this.department = '',
    this.role = '',
    this.responsibility = '',
    this.costCenter = '',
    this.budgetAuthority = 0,
    this.capacityFte = 0,
    this.allocatedFte = 0,
    this.wbsId = '',
    this.cbsId = '',
    this.controlAccountId = '',
    this.level = 0,
    this.path = '',
    this.isActive = true,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  /// Computed: availability = remaining capacity / total capacity (0-1).
  double get availability =>
      capacityFte > 0 ? (capacityFte - allocatedFte) / capacityFte : 0;

  /// Computed: utilization = allocatedFte / capacityFte (0-1+).
  double get utilization =>
      capacityFte > 0 ? allocatedFte / capacityFte : 0;

  /// Computed: is over-allocated.
  bool get isOverAllocated => allocatedFte > capacityFte;

  ObsElement copyWith({
    String? name,
    String? parentObsId,
    String? manager,
    String? organization,
    String? description,
    String? department,
    String? role,
    String? responsibility,
    String? costCenter,
    double? budgetAuthority,
    double? capacityFte,
    double? allocatedFte,
    String? wbsId,
    String? cbsId,
    String? controlAccountId,
    int? level,
    String? path,
    bool? isActive,
  }) {
    return ObsElement(
      id: id,
      name: name ?? this.name,
      parentObsId: parentObsId ?? this.parentObsId,
      manager: manager ?? this.manager,
      organization: organization ?? this.organization,
      description: description ?? this.description,
      department: department ?? this.department,
      role: role ?? this.role,
      responsibility: responsibility ?? this.responsibility,
      costCenter: costCenter ?? this.costCenter,
      budgetAuthority: budgetAuthority ?? this.budgetAuthority,
      capacityFte: capacityFte ?? this.capacityFte,
      allocatedFte: allocatedFte ?? this.allocatedFte,
      wbsId: wbsId ?? this.wbsId,
      cbsId: cbsId ?? this.cbsId,
      controlAccountId: controlAccountId ?? this.controlAccountId,
      level: level ?? this.level,
      path: path ?? this.path,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parentObsId': parentObsId,
        'manager': manager,
        'organization': organization,
        'description': description,
        'department': department,
        'role': role,
        'responsibility': responsibility,
        'costCenter': costCenter,
        'budgetAuthority': budgetAuthority,
        'capacityFte': capacityFte,
        'allocatedFte': allocatedFte,
        'wbsId': wbsId,
        'cbsId': cbsId,
        'controlAccountId': controlAccountId,
        'level': level,
        'path': path,
        'isActive': isActive,
      };

  factory ObsElement.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

    return ObsElement(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? '',
      parentObsId: json['parentObsId']?.toString() ?? '',
      manager: json['manager']?.toString() ?? '',
      organization: json['organization']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      responsibility: json['responsibility']?.toString() ?? '',
      costCenter: json['costCenter']?.toString() ?? '',
      budgetAuthority: toDouble(json['budgetAuthority']),
      capacityFte: toDouble(json['capacityFte']),
      allocatedFte: toDouble(json['allocatedFte']),
      wbsId: json['wbsId']?.toString() ?? '',
      cbsId: json['cbsId']?.toString() ?? '',
      controlAccountId: json['controlAccountId']?.toString() ?? '',
      level: (json['level'] is num) ? (json['level'] as num).toInt() : 0,
      path: json['path']?.toString() ?? '',
      isActive: json['isActive'] != false,
    );
  }
}
