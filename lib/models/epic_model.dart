class Epic {
  final String id;
  String title;
  String description;
  String theme;
  String status; // 'backlog' | 'active' | 'complete' | 'cancelled'
  String businessValue;
  int? startSprint;
  int? endSprint;
  String owner;
  double totalStoryPoints;
  double completedStoryPoints;

  // ── P3.3: WBS traceability for agile↔predictive bridge ──
  /// WBS element ID this epic maps to for hybrid project traceability.
  String wbsId;
  /// OBS element ID (responsible org unit).
  String obsId;
  /// CBS element ID (cost account).
  String cbsId;
  /// Control Account ID (WBS+OBS intersection for EVM rollup).
  String controlAccountId;
  /// List of feature IDs belonging to this epic.
  List<String> featureIds;

  Epic({
    String? id,
    this.title = '',
    this.description = '',
    this.theme = '',
    this.status = 'backlog',
    this.businessValue = '',
    this.startSprint,
    this.endSprint,
    this.owner = '',
    this.totalStoryPoints = 0,
    this.completedStoryPoints = 0,
    this.wbsId = '',
    this.obsId = '',
    this.cbsId = '',
    this.controlAccountId = '',
    List<String>? featureIds,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       featureIds = featureIds ?? [];

  Epic copyWith({
    String? title,
    String? description,
    String? theme,
    String? status,
    String? businessValue,
    int? startSprint,
    int? endSprint,
    String? owner,
    double? totalStoryPoints,
    double? completedStoryPoints,
    String? wbsId,
    String? obsId,
    String? cbsId,
    String? controlAccountId,
    List<String>? featureIds,
  }) {
    return Epic(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      theme: theme ?? this.theme,
      status: status ?? this.status,
      businessValue: businessValue ?? this.businessValue,
      startSprint: startSprint ?? this.startSprint,
      endSprint: endSprint ?? this.endSprint,
      owner: owner ?? this.owner,
      totalStoryPoints: totalStoryPoints ?? this.totalStoryPoints,
      completedStoryPoints: completedStoryPoints ?? this.completedStoryPoints,
      wbsId: wbsId ?? this.wbsId,
      obsId: obsId ?? this.obsId,
      cbsId: cbsId ?? this.cbsId,
      controlAccountId: controlAccountId ?? this.controlAccountId,
      featureIds: featureIds ?? List.from(this.featureIds),
    );
  }

  /// Computed: percent complete based on story points.
  double get percentComplete =>
      totalStoryPoints > 0 ? completedStoryPoints / totalStoryPoints : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'theme': theme,
        'status': status,
        'businessValue': businessValue,
        'startSprint': startSprint,
        'endSprint': endSprint,
        'owner': owner,
        'totalStoryPoints': totalStoryPoints,
        'completedStoryPoints': completedStoryPoints,
        'wbsId': wbsId,
        'obsId': obsId,
        'cbsId': cbsId,
        'controlAccountId': controlAccountId,
        'featureIds': featureIds,
      };

  factory Epic.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    int? toNullableInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return Epic(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      theme: json['theme']?.toString() ?? '',
      status: json['status']?.toString() ?? 'backlog',
      businessValue: json['businessValue']?.toString() ?? '',
      startSprint: toNullableInt(json['startSprint']),
      endSprint: toNullableInt(json['endSprint']),
      owner: json['owner']?.toString() ?? '',
      totalStoryPoints: toDouble(json['totalStoryPoints']),
      completedStoryPoints: toDouble(json['completedStoryPoints']),
      wbsId: json['wbsId']?.toString() ?? '',
      obsId: json['obsId']?.toString() ?? '',
      cbsId: json['cbsId']?.toString() ?? '',
      controlAccountId: json['controlAccountId']?.toString() ?? '',
      featureIds: (json['featureIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
