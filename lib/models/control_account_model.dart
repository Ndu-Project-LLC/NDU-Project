class ControlAccount {
  final String id;
  String wbsId;
  String obsId;
  String title;
  String description;
  String responsiblePerson;
  String status; // 'authorized' | 'active' | 'closed'

  /// P1.4: CBS element ID cross-reference — links this control account
  /// to its cost breakdown element for cost rollup.
  String cbsId;

  /// P1.4: List of change request IDs that have impacted this control account.
  List<String> affectedChangeRequestIds;

  double budgetAtCompletion;
  Map<String, double> plannedValueByPeriod; // periodKey '2026-05' -> PV

  /// P1.5: Per-period earned value breakdown for S-curve generation.
  Map<String, double> earnedValueByPeriod;
  /// P1.5: Per-period actual cost breakdown for S-curve generation.
  Map<String, double> actualCostByPeriod;

  double earnedValue;
  double actualCost;
  double cpi;
  double spi;
  double eac;
  double etc;
  double vac;
  /// Cost Variance (CV = EV - AC).
  double cv;
  /// Schedule Variance (SV = EV - PV).
  double sv;
  /// TCPI based on BAC (to-complete performance index).
  double tcpii;
  /// TCPI based on EAC.
  double tcpis;
  /// Risk adjustment factor (0-1) for risk-adjusted EAC.
  double riskAdjustment;

  DateTime? lastRecalculated;
  DateTime createdAt;
  DateTime? updatedAt;

  /// Baseline version ID — ties this control account to a specific baseline snapshot.
  String baselineVersionId;

  ControlAccount({
    String? id,
    this.wbsId = '',
    this.obsId = '',
    this.title = '',
    this.description = '',
    this.responsiblePerson = '',
    this.status = 'authorized',
    this.cbsId = '',
    List<String>? affectedChangeRequestIds,
    this.budgetAtCompletion = 0,
    Map<String, double>? plannedValueByPeriod,
    Map<String, double>? earnedValueByPeriod,
    Map<String, double>? actualCostByPeriod,
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
    this.tcpis = 0,
    this.riskAdjustment = 0,
    this.lastRecalculated,
    DateTime? createdAt,
    this.updatedAt,
    this.baselineVersionId = '',
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        plannedValueByPeriod = plannedValueByPeriod ?? {},
        earnedValueByPeriod = earnedValueByPeriod ?? {},
        actualCostByPeriod = actualCostByPeriod ?? {},
        affectedChangeRequestIds = affectedChangeRequestIds ?? [],
        createdAt = createdAt ?? DateTime.now();

  ControlAccount copyWith({
    String? wbsId,
    String? obsId,
    String? title,
    String? description,
    String? responsiblePerson,
    String? status,
    String? cbsId,
    List<String>? affectedChangeRequestIds,
    double? budgetAtCompletion,
    Map<String, double>? plannedValueByPeriod,
    Map<String, double>? earnedValueByPeriod,
    Map<String, double>? actualCostByPeriod,
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
    double? tcpis,
    double? riskAdjustment,
    DateTime? lastRecalculated,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? baselineVersionId,
  }) {
    return ControlAccount(
      id: id,
      wbsId: wbsId ?? this.wbsId,
      obsId: obsId ?? this.obsId,
      title: title ?? this.title,
      description: description ?? this.description,
      responsiblePerson: responsiblePerson ?? this.responsiblePerson,
      status: status ?? this.status,
      cbsId: cbsId ?? this.cbsId,
      affectedChangeRequestIds: affectedChangeRequestIds ?? List<String>.from(this.affectedChangeRequestIds),
      budgetAtCompletion: budgetAtCompletion ?? this.budgetAtCompletion,
      plannedValueByPeriod:
          plannedValueByPeriod ?? Map<String, double>.from(this.plannedValueByPeriod),
      earnedValueByPeriod:
          earnedValueByPeriod ?? Map<String, double>.from(this.earnedValueByPeriod),
      actualCostByPeriod:
          actualCostByPeriod ?? Map<String, double>.from(this.actualCostByPeriod),
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
      tcpis: tcpis ?? this.tcpis,
      riskAdjustment: riskAdjustment ?? this.riskAdjustment,
      lastRecalculated: lastRecalculated ?? this.lastRecalculated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      baselineVersionId: baselineVersionId ?? this.baselineVersionId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'wbsId': wbsId,
        'obsId': obsId,
        'title': title,
        'description': description,
        'responsiblePerson': responsiblePerson,
        'status': status,
        'cbsId': cbsId,
        'affectedChangeRequestIds': affectedChangeRequestIds,
        'budgetAtCompletion': budgetAtCompletion,
        'plannedValueByPeriod': plannedValueByPeriod
            .map((k, v) => MapEntry(k, v)),
        'earnedValueByPeriod': earnedValueByPeriod
            .map((k, v) => MapEntry(k, v)),
        'actualCostByPeriod': actualCostByPeriod
            .map((k, v) => MapEntry(k, v)),
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
        'tcpis': tcpis,
        'riskAdjustment': riskAdjustment,
        'lastRecalculated': lastRecalculated?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'baselineVersionId': baselineVersionId,
      };

  factory ControlAccount.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateField(String key) {
      final val = json[key];
      if (val == null) return null;
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val);
      }
      if (val is DateTime) return val;
      return null;
    }

    Map<String, double> parsePeriodMap(dynamic raw) {
      final map = <String, double>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          map[k.toString()] = (v is num) ? v.toDouble() : 0.0;
        });
      }
      return map;
    }

    double toDouble(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

    return ControlAccount(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      wbsId: json['wbsId']?.toString() ?? '',
      obsId: json['obsId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      responsiblePerson: json['responsiblePerson']?.toString() ?? '',
      status: json['status']?.toString() ?? 'authorized',
      cbsId: json['cbsId']?.toString() ?? '',
      affectedChangeRequestIds: (json['affectedChangeRequestIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      budgetAtCompletion: toDouble(json['budgetAtCompletion']),
      plannedValueByPeriod: parsePeriodMap(json['plannedValueByPeriod']),
      earnedValueByPeriod: parsePeriodMap(json['earnedValueByPeriod']),
      actualCostByPeriod: parsePeriodMap(json['actualCostByPeriod']),
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
      tcpis: toDouble(json['tcpis']),
      riskAdjustment: toDouble(json['riskAdjustment']),
      lastRecalculated: parseDateField('lastRecalculated'),
      createdAt: parseDateField('createdAt') ?? DateTime.now(),
      updatedAt: parseDateField('updatedAt'),
      baselineVersionId: json['baselineVersionId']?.toString() ?? '',
    );
  }
}
