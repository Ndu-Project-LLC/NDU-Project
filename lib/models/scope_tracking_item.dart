class ScopeTrackingItem {
  final String id;
  String scopeItem;
  String implementationStatus;
  String owner;
  String verificationMethod;
  String verificationSteps;
  String trackingNotes;

  String wbsId;
  String requirementId;
  String scheduleActivityId;
  String scopeType;
  DateTime? plannedStartDate;
  DateTime? plannedEndDate;
  DateTime? actualStartDate;
  DateTime? actualEndDate;
  List<String> dependencies;
  String changeRequestId;
  bool isBaseline;

  // ── P1.4: Cross-references for full project controls traceability ──
  /// CBS element ID — links this scope item to its cost account.
  String cbsId;
  /// OBS element ID — links this scope item to the responsible org unit.
  String obsId;
  /// Control Account ID — links to the WBS+OBS intersection for EVM rollup.
  String controlAccountId;
  /// Baseline version ID — which baseline this scope item belongs to.
  String baselineVersionId;
  /// Epic ID — links this scope item to an agile epic for hybrid traceability.
  String epicId;
  /// Feature ID — links this scope item to an agile feature for hybrid traceability.
  String featureId;
  /// Relative weight (0-1) for weighted scope completion rollup.
  double weight;
  /// Physical percent complete (0-1) for this scope item.
  double percentComplete;

  ScopeTrackingItem({
    String? id,
    this.scopeItem = '',
    this.implementationStatus = 'Not Started',
    this.owner = '',
    this.verificationMethod = '',
    this.verificationSteps = '',
    this.trackingNotes = '',
    this.wbsId = '',
    this.requirementId = '',
    this.scheduleActivityId = '',
    this.scopeType = 'predictive',
    this.plannedStartDate,
    this.plannedEndDate,
    this.actualStartDate,
    this.actualEndDate,
    List<String>? dependencies,
    this.changeRequestId = '',
    this.isBaseline = false,
    this.cbsId = '',
    this.obsId = '',
    this.controlAccountId = '',
    this.baselineVersionId = '',
    this.epicId = '',
    this.featureId = '',
    this.weight = 0,
    this.percentComplete = 0,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        dependencies = dependencies ?? [];

  ScopeTrackingItem copyWith({
    String? scopeItem,
    String? implementationStatus,
    String? owner,
    String? verificationMethod,
    String? verificationSteps,
    String? trackingNotes,
    String? wbsId,
    String? requirementId,
    String? scheduleActivityId,
    String? scopeType,
    DateTime? plannedStartDate,
    DateTime? plannedEndDate,
    DateTime? actualStartDate,
    DateTime? actualEndDate,
    List<String>? dependencies,
    String? changeRequestId,
    bool? isBaseline,
    String? cbsId,
    String? obsId,
    String? controlAccountId,
    String? baselineVersionId,
    String? epicId,
    String? featureId,
    double? weight,
    double? percentComplete,
  }) {
    return ScopeTrackingItem(
      id: id,
      scopeItem: scopeItem ?? this.scopeItem,
      implementationStatus: implementationStatus ?? this.implementationStatus,
      owner: owner ?? this.owner,
      verificationMethod: verificationMethod ?? this.verificationMethod,
      verificationSteps: verificationSteps ?? this.verificationSteps,
      trackingNotes: trackingNotes ?? this.trackingNotes,
      wbsId: wbsId ?? this.wbsId,
      requirementId: requirementId ?? this.requirementId,
      scheduleActivityId: scheduleActivityId ?? this.scheduleActivityId,
      scopeType: scopeType ?? this.scopeType,
      plannedStartDate: plannedStartDate ?? this.plannedStartDate,
      plannedEndDate: plannedEndDate ?? this.plannedEndDate,
      actualStartDate: actualStartDate ?? this.actualStartDate,
      actualEndDate: actualEndDate ?? this.actualEndDate,
      dependencies: dependencies ?? List<String>.from(this.dependencies),
      changeRequestId: changeRequestId ?? this.changeRequestId,
      isBaseline: isBaseline ?? this.isBaseline,
      cbsId: cbsId ?? this.cbsId,
      obsId: obsId ?? this.obsId,
      controlAccountId: controlAccountId ?? this.controlAccountId,
      baselineVersionId: baselineVersionId ?? this.baselineVersionId,
      epicId: epicId ?? this.epicId,
      featureId: featureId ?? this.featureId,
      weight: weight ?? this.weight,
      percentComplete: percentComplete ?? this.percentComplete,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'scopeItem': scopeItem,
        'implementationStatus': implementationStatus,
        'owner': owner,
        'verificationMethod': verificationMethod,
        'verificationSteps': verificationSteps,
        'trackingNotes': trackingNotes,
        'wbsId': wbsId,
        'requirementId': requirementId,
        'scheduleActivityId': scheduleActivityId,
        'scopeType': scopeType,
        'plannedStartDate': plannedStartDate?.toIso8601String(),
        'plannedEndDate': plannedEndDate?.toIso8601String(),
        'actualStartDate': actualStartDate?.toIso8601String(),
        'actualEndDate': actualEndDate?.toIso8601String(),
        'dependencies': dependencies,
        'changeRequestId': changeRequestId,
        'isBaseline': isBaseline,
        'cbsId': cbsId,
        'obsId': obsId,
        'controlAccountId': controlAccountId,
        'baselineVersionId': baselineVersionId,
        'epicId': epicId,
        'featureId': featureId,
        'weight': weight,
        'percentComplete': percentComplete,
      };

  factory ScopeTrackingItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateField(String? key) {
      final val = json[key];
      if (val == null) return null;
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    return ScopeTrackingItem(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      scopeItem: json['scopeItem']?.toString() ?? '',
      implementationStatus:
          json['implementationStatus']?.toString() ?? 'Not Started',
      owner: json['owner']?.toString() ?? '',
      verificationMethod: json['verificationMethod']?.toString() ?? '',
      verificationSteps: json['verificationSteps']?.toString() ?? '',
      trackingNotes: json['trackingNotes']?.toString() ?? '',
      wbsId: json['wbsId']?.toString() ?? '',
      requirementId: json['requirementId']?.toString() ?? '',
      scheduleActivityId: json['scheduleActivityId']?.toString() ?? '',
      scopeType: json['scopeType']?.toString() ?? 'predictive',
      plannedStartDate: parseDateField('plannedStartDate'),
      plannedEndDate: parseDateField('plannedEndDate'),
      actualStartDate: parseDateField('actualStartDate'),
      actualEndDate: parseDateField('actualEndDate'),
      dependencies: (json['dependencies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      changeRequestId: json['changeRequestId']?.toString() ?? '',
      isBaseline: json['isBaseline'] == true,
      cbsId: json['cbsId']?.toString() ?? '',
      obsId: json['obsId']?.toString() ?? '',
      controlAccountId: json['controlAccountId']?.toString() ?? '',
      baselineVersionId: json['baselineVersionId']?.toString() ?? '',
      epicId: json['epicId']?.toString() ?? '',
      featureId: json['featureId']?.toString() ?? '',
      weight: (json['weight'] is num) ? (json['weight'] as num).toDouble() : 0,
      percentComplete: (json['percentComplete'] is num)
          ? (json['percentComplete'] as num).toDouble().clamp(0, 1)
          : 0,
    );
  }
}
