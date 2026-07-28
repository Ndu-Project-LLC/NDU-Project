class BaselineVersion {
  final String id;
  final int versionNumber;
  final String label;
  final String description;
  final String author;
  final String approvedBy;
  final DateTime createdAt;

  // Point-in-time snapshot summaries
  final double scheduleVarianceDays;
  final double costVariance;
  final double budgetAtCompletion;
  final int totalActivities;
  final int completedActivities;
  final int totalWorkPackages;
  final String triggerSource; // 'manual' | 'change_request' | 'periodic'

  // ── P2.1: Full EVM snapshot data for baseline comparison ──
  /// Planned Value at snapshot time.
  final double plannedValue;
  /// Earned Value at snapshot time.
  final double earnedValue;
  /// Actual Cost at snapshot time.
  final double actualCost;
  /// CPI at snapshot time.
  final double cpi;
  /// SPI at snapshot time.
  final double spi;
  /// EAC at snapshot time.
  final double eac;
  /// ETC at snapshot time.
  final double etc;
  /// VAC at snapshot time.
  final double vac;
  /// CV at snapshot time.
  final double cv;
  /// SV at snapshot time.
  final double sv;
  /// TCPI at snapshot time.
  final double tcpii;

  // ── P2.1: Scope tracking at snapshot time ──
  /// Total scope items at snapshot.
  final int totalScopeItems;
  /// Scope items marked as baseline at snapshot.
  final int baselineScopeItems;
  /// Scope creep items (added after baseline) at snapshot.
  final int scopeCreepItems;
  /// Scope growth percentage at snapshot.
  final double scopeGrowthPercent;

  // ── P2.1: Structural snapshots for diff/restore ──
  /// JSON-serialized snapshot of ControlAccount data at baseline time.
  /// Each entry: { id, wbsId, obsId, cbsId, title, bac, earnedValue, actualCost, cpi, spi, eac }
  final List<Map<String, dynamic>> controlAccountSnapshots;

  /// JSON-serialized snapshot of WBS element IDs and titles at baseline time.
  /// Each entry: { id, wbsCode, title, parentId, status }
  final List<Map<String, dynamic>> wbsSnapshots;

  /// JSON-serialized snapshot of CBS element IDs and budget amounts at baseline time.
  /// Each entry: { id, code, name, parentCbsId, budgetAmount, committedAmount, spentAmount }
  final List<Map<String, dynamic>> cbsSnapshots;

  /// JSON-serialized snapshot of OBS element IDs and managers at baseline time.
  /// Each entry: { id, name, parentObsId, manager, role }
  final List<Map<String, dynamic>> obsSnapshots;

  /// JSON-serialized snapshot of ScheduleActivity IDs and dates at baseline time.
  /// Each entry: { id, title, startDate, dueDate, status, isCriticalPath }
  final List<Map<String, dynamic>> scheduleActivitySnapshots;

  /// JSON-serialized snapshot of WorkPackage IDs and costs at baseline time.
  /// Each entry: { id, title, budgetedCost, actualCost, status, percentComplete }
  final List<Map<String, dynamic>> workPackageSnapshots;

  /// Whether this is the currently active baseline version.
  final bool isCurrent;

  BaselineVersion({
    String? id,
    required this.versionNumber,
    required this.label,
    this.description = '',
    required this.author,
    this.approvedBy = '',
    DateTime? createdAt,
    this.scheduleVarianceDays = 0,
    this.costVariance = 0,
    this.budgetAtCompletion = 0,
    this.totalActivities = 0,
    this.completedActivities = 0,
    this.totalWorkPackages = 0,
    this.triggerSource = 'manual',
    // P2.1 EVM fields
    this.plannedValue = 0,
    this.earnedValue = 0,
    this.actualCost = 0,
    this.cpi = 1.0,
    this.spi = 1.0,
    this.eac = 0,
    this.etc = 0,
    this.vac = 0,
    this.cv = 0,
    this.sv = 0,
    this.tcpii = 0,
    // P2.1 scope fields
    this.totalScopeItems = 0,
    this.baselineScopeItems = 0,
    this.scopeCreepItems = 0,
    this.scopeGrowthPercent = 0,
    // P2.1 structural snapshots
    List<Map<String, dynamic>>? controlAccountSnapshots,
    List<Map<String, dynamic>>? wbsSnapshots,
    List<Map<String, dynamic>>? cbsSnapshots,
    List<Map<String, dynamic>>? obsSnapshots,
    List<Map<String, dynamic>>? scheduleActivitySnapshots,
    List<Map<String, dynamic>>? workPackageSnapshots,
    this.isCurrent = false,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now(),
        controlAccountSnapshots = controlAccountSnapshots ?? [],
        wbsSnapshots = wbsSnapshots ?? [],
        cbsSnapshots = cbsSnapshots ?? [],
        obsSnapshots = obsSnapshots ?? [],
        scheduleActivitySnapshots = scheduleActivitySnapshots ?? [],
        workPackageSnapshots = workPackageSnapshots ?? [];

  BaselineVersion copyWith({
    String? label,
    String? description,
    String? approvedBy,
    int? versionNumber,
    double? scheduleVarianceDays,
    double? costVariance,
    double? budgetAtCompletion,
    int? totalActivities,
    int? completedActivities,
    int? totalWorkPackages,
    String? triggerSource,
    double? plannedValue,
    double? earnedValue,
    double? actualCost,
    double? cpi,
    double? spi,
    double? eac,
    double? etc,
    double? vac,
    double? cv,
    double? sv,
    double? tcpii,
    int? totalScopeItems,
    int? baselineScopeItems,
    int? scopeCreepItems,
    double? scopeGrowthPercent,
    List<Map<String, dynamic>>? controlAccountSnapshots,
    List<Map<String, dynamic>>? wbsSnapshots,
    List<Map<String, dynamic>>? cbsSnapshots,
    List<Map<String, dynamic>>? obsSnapshots,
    List<Map<String, dynamic>>? scheduleActivitySnapshots,
    List<Map<String, dynamic>>? workPackageSnapshots,
    bool? isCurrent,
  }) {
    return BaselineVersion(
      id: id,
      versionNumber: versionNumber ?? this.versionNumber,
      label: label ?? this.label,
      description: description ?? this.description,
      author: author,
      approvedBy: approvedBy ?? this.approvedBy,
      createdAt: createdAt,
      scheduleVarianceDays:
          scheduleVarianceDays ?? this.scheduleVarianceDays,
      costVariance: costVariance ?? this.costVariance,
      budgetAtCompletion: budgetAtCompletion ?? this.budgetAtCompletion,
      totalActivities: totalActivities ?? this.totalActivities,
      completedActivities: completedActivities ?? this.completedActivities,
      totalWorkPackages: totalWorkPackages ?? this.totalWorkPackages,
      triggerSource: triggerSource ?? this.triggerSource,
      plannedValue: plannedValue ?? this.plannedValue,
      earnedValue: earnedValue ?? this.earnedValue,
      actualCost: actualCost ?? this.actualCost,
      cpi: cpi ?? this.cpi,
      spi: spi ?? this.spi,
      eac: eac ?? this.eac,
      etc: etc ?? this.etc,
      vac: vac ?? this.vac,
      cv: cv ?? this.cv,
      sv: sv ?? this.sv,
      tcpii: tcpii ?? this.tcpii,
      totalScopeItems: totalScopeItems ?? this.totalScopeItems,
      baselineScopeItems: baselineScopeItems ?? this.baselineScopeItems,
      scopeCreepItems: scopeCreepItems ?? this.scopeCreepItems,
      scopeGrowthPercent: scopeGrowthPercent ?? this.scopeGrowthPercent,
      controlAccountSnapshots:
          controlAccountSnapshots ?? this.controlAccountSnapshots,
      wbsSnapshots: wbsSnapshots ?? this.wbsSnapshots,
      cbsSnapshots: cbsSnapshots ?? this.cbsSnapshots,
      obsSnapshots: obsSnapshots ?? this.obsSnapshots,
      scheduleActivitySnapshots:
          scheduleActivitySnapshots ?? this.scheduleActivitySnapshots,
      workPackageSnapshots:
          workPackageSnapshots ?? this.workPackageSnapshots,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'versionNumber': versionNumber,
        'label': label,
        'description': description,
        'author': author,
        'approvedBy': approvedBy,
        'createdAt': createdAt.toIso8601String(),
        'scheduleVarianceDays': scheduleVarianceDays,
        'costVariance': costVariance,
        'budgetAtCompletion': budgetAtCompletion,
        'totalActivities': totalActivities,
        'completedActivities': completedActivities,
        'totalWorkPackages': totalWorkPackages,
        'triggerSource': triggerSource,
        'plannedValue': plannedValue,
        'earnedValue': earnedValue,
        'actualCost': actualCost,
        'cpi': cpi,
        'spi': spi,
        'eac': eac,
        'etc': etc,
        'vac': vac,
        'cv': cv,
        'sv': sv,
        'tcpii': tcpii,
        'totalScopeItems': totalScopeItems,
        'baselineScopeItems': baselineScopeItems,
        'scopeCreepItems': scopeCreepItems,
        'scopeGrowthPercent': scopeGrowthPercent,
        'controlAccountSnapshots': controlAccountSnapshots,
        'wbsSnapshots': wbsSnapshots,
        'cbsSnapshots': cbsSnapshots,
        'obsSnapshots': obsSnapshots,
        'scheduleActivitySnapshots': scheduleActivitySnapshots,
        'workPackageSnapshots': workPackageSnapshots,
        'isCurrent': isCurrent,
      };

  factory BaselineVersion.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      if (v is DateTime) return v;
      return null;
    }

    double toDouble(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    int toInt(dynamic v) =>
        (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    List<Map<String, dynamic>> parseSnapshotList(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
      return [];
    }

    return BaselineVersion(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      versionNumber: toInt(json['versionNumber']),
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      approvedBy: json['approvedBy']?.toString() ?? '',
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      scheduleVarianceDays: toDouble(json['scheduleVarianceDays']),
      costVariance: toDouble(json['costVariance']),
      budgetAtCompletion: toDouble(json['budgetAtCompletion']),
      totalActivities: toInt(json['totalActivities']),
      completedActivities: toInt(json['completedActivities']),
      totalWorkPackages: toInt(json['totalWorkPackages']),
      triggerSource: json['triggerSource']?.toString() ?? 'manual',
      plannedValue: toDouble(json['plannedValue']),
      earnedValue: toDouble(json['earnedValue']),
      actualCost: toDouble(json['actualCost']),
      cpi: toDouble(json['cpi']),
      spi: toDouble(json['spi']),
      eac: toDouble(json['eac']),
      etc: toDouble(json['etc']),
      vac: toDouble(json['vac']),
      cv: toDouble(json['cv']),
      sv: toDouble(json['sv']),
      tcpii: toDouble(json['tcpii']),
      totalScopeItems: toInt(json['totalScopeItems']),
      baselineScopeItems: toInt(json['baselineScopeItems']),
      scopeCreepItems: toInt(json['scopeCreepItems']),
      scopeGrowthPercent: toDouble(json['scopeGrowthPercent']),
      controlAccountSnapshots:
          parseSnapshotList(json['controlAccountSnapshots']),
      wbsSnapshots: parseSnapshotList(json['wbsSnapshots']),
      cbsSnapshots: parseSnapshotList(json['cbsSnapshots']),
      obsSnapshots: parseSnapshotList(json['obsSnapshots']),
      scheduleActivitySnapshots:
          parseSnapshotList(json['scheduleActivitySnapshots']),
      workPackageSnapshots: parseSnapshotList(json['workPackageSnapshots']),
      isCurrent: json['isCurrent'] == true,
    );
  }
}
