class Feature {
  final String id;
  String title;
  String description;
  String epicId;
  String status; // 'backlog' | 'active' | 'complete' | 'cancelled'
  String priority; // 'critical' | 'high' | 'medium' | 'low'
  double storyPointEstimate;

  // ── P3.3: WBS traceability for agile↔predictive bridge ──
  /// WBS element ID this feature maps to for hybrid traceability.
  String wbsId;

  /// OBS element ID (responsible org unit).
  String obsId;

  /// CBS element ID (cost account for budget tracking).
  String cbsId;

  /// Control Account ID (WBS+OBS intersection for EVM rollup).
  String controlAccountId;

  /// List of scope tracking item IDs linked to this feature.
  List<String> scopeTrackingItemIds;

  /// Sprint this feature is assigned to.
  String? sprintId;

  /// Weight (0-1) for weighted completion rollup within the epic.
  double weight;

  /// Physical percent complete (0-1) for this feature.
  double percentComplete;

  Feature({
    String? id,
    this.title = '',
    this.description = '',
    this.epicId = '',
    this.status = 'backlog',
    this.priority = 'medium',
    this.storyPointEstimate = 0,
    this.wbsId = '',
    this.obsId = '',
    this.cbsId = '',
    this.controlAccountId = '',
    this.sprintId,
    List<String>? scopeTrackingItemIds,
    this.weight = 0,
    this.percentComplete = 0,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        scopeTrackingItemIds = scopeTrackingItemIds ?? [];

  Feature copyWith({
    String? title,
    String? description,
    String? epicId,
    String? status,
    String? priority,
    double? storyPointEstimate,
    String? wbsId,
    String? obsId,
    String? cbsId,
    String? controlAccountId,
    String? sprintId,
    List<String>? scopeTrackingItemIds,
    double? weight,
    double? percentComplete,
  }) {
    return Feature(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      epicId: epicId ?? this.epicId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      storyPointEstimate: storyPointEstimate ?? this.storyPointEstimate,
      wbsId: wbsId ?? this.wbsId,
      obsId: obsId ?? this.obsId,
      cbsId: cbsId ?? this.cbsId,
      controlAccountId: controlAccountId ?? this.controlAccountId,
      sprintId: sprintId ?? this.sprintId,
      scopeTrackingItemIds:
          scopeTrackingItemIds ?? List.from(this.scopeTrackingItemIds),
      weight: weight ?? this.weight,
      percentComplete: percentComplete ?? this.percentComplete,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'epicId': epicId,
        'status': status,
        'priority': priority,
        'storyPointEstimate': storyPointEstimate,
        'wbsId': wbsId,
        'obsId': obsId,
        'cbsId': cbsId,
        'controlAccountId': controlAccountId,
        'sprintId': sprintId,
        'scopeTrackingItemIds': scopeTrackingItemIds,
        'weight': weight,
        'percentComplete': percentComplete,
      };

  factory Feature.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

    return Feature(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      epicId: json['epicId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'backlog',
      priority: json['priority']?.toString() ?? 'medium',
      storyPointEstimate: toDouble(json['storyPointEstimate']),
      wbsId: json['wbsId']?.toString() ?? '',
      obsId: json['obsId']?.toString() ?? '',
      cbsId: json['cbsId']?.toString() ?? '',
      controlAccountId: json['controlAccountId']?.toString() ?? '',
      sprintId: json['sprintId']?.toString(),
      scopeTrackingItemIds: (json['scopeTrackingItemIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      weight: toDouble(json['weight']),
      percentComplete: toDouble(json['percentComplete']).clamp(0, 1),
    );
  }
}
