class EvmSnapshot {
  final String id;
  final DateTime snapshotDate;
  final String projectId;

  // EVM metrics at snapshot time
  final double budgetAtCompletion;
  final double plannedValue;
  final double earnedValue;
  final double actualCost;
  final double cpi;
  final double spi;
  final double cv;
  final double sv;
  final double eac;
  final double etc;
  final double vac;
  final double tcpii;

  // Context
  final int completedActivities;
  final int totalActivities;
  final String source; // 'auto_weekly' | 'auto_monthly' | 'manual'

  EvmSnapshot({
    String? id,
    required this.snapshotDate,
    required this.projectId,
    this.budgetAtCompletion = 0,
    this.plannedValue = 0,
    this.earnedValue = 0,
    this.actualCost = 0,
    this.cpi = 1.0,
    this.spi = 1.0,
    this.cv = 0,
    this.sv = 0,
    this.eac = 0,
    this.etc = 0,
    this.vac = 0,
    this.tcpii = 1.0,
    this.completedActivities = 0,
    this.totalActivities = 0,
    this.source = 'manual',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'snapshotDate': snapshotDate.toIso8601String(),
        'projectId': projectId,
        'budgetAtCompletion': budgetAtCompletion,
        'plannedValue': plannedValue,
        'earnedValue': earnedValue,
        'actualCost': actualCost,
        'cpi': cpi,
        'spi': spi,
        'cv': cv,
        'sv': sv,
        'eac': eac,
        'etc': etc,
        'vac': vac,
        'tcpii': tcpii,
        'completedActivities': completedActivities,
        'totalActivities': totalActivities,
        'source': source,
      };

  factory EvmSnapshot.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    int toInt(dynamic v) =>
        (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      if (v is DateTime) return v;
      return null;
    }

    return EvmSnapshot(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      snapshotDate: parseDate(json['snapshotDate']) ?? DateTime.now(),
      projectId: json['projectId']?.toString() ?? '',
      budgetAtCompletion: toDouble(json['budgetAtCompletion']),
      plannedValue: toDouble(json['plannedValue']),
      earnedValue: toDouble(json['earnedValue']),
      actualCost: toDouble(json['actualCost']),
      cpi: toDouble(json['cpi']),
      spi: toDouble(json['spi']),
      cv: toDouble(json['cv']),
      sv: toDouble(json['sv']),
      eac: toDouble(json['eac']),
      etc: toDouble(json['etc']),
      vac: toDouble(json['vac']),
      tcpii: toDouble(json['tcpii']),
      completedActivities: toInt(json['completedActivities']),
      totalActivities: toInt(json['totalActivities']),
      source: json['source']?.toString() ?? 'manual',
    );
  }
}
