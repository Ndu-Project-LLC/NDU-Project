/// Cost of Quality (CoQ) model for tracking prevention, appraisal,
/// internal failure, and external failure costs.
///
/// Embedded in [ProjectDataModel] and provides the quality cost data
/// that links to the Quality Management module.
class CostOfQualityData {
  List<CoQEntry> preventionCosts;
  List<CoQEntry> appraisalCosts;
  List<CoQEntry> internalFailureCosts;
  List<CoQEntry> externalFailureCosts;
  String notes;

  CostOfQualityData({
    List<CoQEntry>? preventionCosts,
    List<CoQEntry>? appraisalCosts,
    List<CoQEntry>? internalFailureCosts,
    List<CoQEntry>? externalFailureCosts,
    this.notes = '',
  })  : preventionCosts = preventionCosts ?? [],
        appraisalCosts = appraisalCosts ?? [],
        internalFailureCosts = internalFailureCosts ?? [],
        externalFailureCosts = externalFailureCosts ?? [];

  factory CostOfQualityData.empty() => CostOfQualityData();

  double get totalPrevention =>
      preventionCosts.fold(0, (sum, e) => sum + e.actualCost);
  double get totalAppraisal =>
      appraisalCosts.fold(0, (sum, e) => sum + e.actualCost);
  double get totalInternalFailure =>
      internalFailureCosts.fold(0, (sum, e) => sum + e.actualCost);
  double get totalExternalFailure =>
      externalFailureCosts.fold(0, (sum, e) => sum + e.actualCost);
  double get totalCoq =>
      totalPrevention + totalAppraisal + totalInternalFailure + totalExternalFailure;

  double get totalEstimatedPrevention =>
      preventionCosts.fold(0, (sum, e) => sum + e.estimatedCost);
  double get totalEstimatedAppraisal =>
      appraisalCosts.fold(0, (sum, e) => sum + e.estimatedCost);
  double get totalEstimatedInternalFailure =>
      internalFailureCosts.fold(0, (sum, e) => sum + e.estimatedCost);
  double get totalEstimatedExternalFailure =>
      externalFailureCosts.fold(0, (sum, e) => sum + e.estimatedCost);
  double get totalEstimatedCoq =>
      totalEstimatedPrevention +
      totalEstimatedAppraisal +
      totalEstimatedInternalFailure +
      totalEstimatedExternalFailure;

  Map<String, dynamic> toJson() => {
        'preventionCosts': preventionCosts.map((e) => e.toJson()).toList(),
        'appraisalCosts': appraisalCosts.map((e) => e.toJson()).toList(),
        'internalFailureCosts':
            internalFailureCosts.map((e) => e.toJson()).toList(),
        'externalFailureCosts':
            externalFailureCosts.map((e) => e.toJson()).toList(),
        'notes': notes,
      };

  factory CostOfQualityData.fromJson(Map<String, dynamic> json) {
    return CostOfQualityData(
      preventionCosts: (json['preventionCosts'] as List?)
              ?.map((e) => CoQEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      appraisalCosts: (json['appraisalCosts'] as List?)
              ?.map((e) => CoQEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      internalFailureCosts: (json['internalFailureCosts'] as List?)
              ?.map((e) => CoQEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      externalFailureCosts: (json['externalFailureCosts'] as List?)
              ?.map((e) => CoQEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes']?.toString() ?? '',
    );
  }

  CostOfQualityData copyWith({
    List<CoQEntry>? preventionCosts,
    List<CoQEntry>? appraisalCosts,
    List<CoQEntry>? internalFailureCosts,
    List<CoQEntry>? externalFailureCosts,
    String? notes,
  }) {
    return CostOfQualityData(
      preventionCosts: preventionCosts ?? this.preventionCosts,
      appraisalCosts: appraisalCosts ?? this.appraisalCosts,
      internalFailureCosts:
          internalFailureCosts ?? this.internalFailureCosts,
      externalFailureCosts:
          externalFailureCosts ?? this.externalFailureCosts,
      notes: notes ?? this.notes,
    );
  }
}

/// Individual Cost of Quality entry.
class CoQEntry {
  final String id;
  String description;
  String scope; // 'Internal' | '3rd Party' | 'Regulatory'
  String performerRole;
  String wbsReference;
  double estimatedCost;
  double actualCost;
  String frequency; // 'One-time' | 'Monthly' | 'Quarterly' | 'Annual'
  String status; // 'Planned' | 'In Progress' | 'Completed'
  String notes;
  DateTime createdAt;

  CoQEntry({
    String? id,
    this.description = '',
    this.scope = 'Internal',
    this.performerRole = '',
    this.wbsReference = '',
    this.estimatedCost = 0,
    this.actualCost = 0,
    this.frequency = 'One-time',
    this.status = 'Planned',
    this.notes = '',
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'scope': scope,
        'performerRole': performerRole,
        'wbsReference': wbsReference,
        'estimatedCost': estimatedCost,
        'actualCost': actualCost,
        'frequency': frequency,
        'status': status,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CoQEntry.fromJson(Map<String, dynamic> json) {
    return CoQEntry(
      id: json['id']?.toString(),
      description: json['description']?.toString() ?? '',
      scope: json['scope']?.toString() ?? 'Internal',
      performerRole: json['performerRole']?.toString() ?? '',
      wbsReference: json['wbsReference']?.toString() ?? '',
      estimatedCost: json['estimatedCost'] is num
          ? (json['estimatedCost'] as num).toDouble()
          : 0,
      actualCost: json['actualCost'] is num
          ? (json['actualCost'] as num).toDouble()
          : 0,
      frequency: json['frequency']?.toString() ?? 'One-time',
      status: json['status']?.toString() ?? 'Planned',
      notes: json['notes']?.toString() ?? '',
      createdAt: _parseDate(json['createdAt']),
    );
  }

  CoQEntry copyWith({
    String? description,
    String? scope,
    String? performerRole,
    String? wbsReference,
    double? estimatedCost,
    double? actualCost,
    String? frequency,
    String? status,
    String? notes,
  }) {
    return CoQEntry(
      id: id,
      description: description ?? this.description,
      scope: scope ?? this.scope,
      performerRole: performerRole ?? this.performerRole,
      wbsReference: wbsReference ?? this.wbsReference,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      actualCost: actualCost ?? this.actualCost,
      frequency: frequency ?? this.frequency,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is DateTime) return v;
  return DateTime.now();
}
