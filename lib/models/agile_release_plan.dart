class AgileReleasePlan {
  AgileReleasePlan({
    String? id,
    this.releaseLabel = '',
    this.releaseDate,
    this.releaseGoal = '',
    this.scope = '',
    this.status = 'Draft',
    this.version = '',
    this.piNumber,
    this.trainName = '',
    this.epicIds = const [],
    this.featureIds = const [],
    this.storyIds = const [],
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  String releaseLabel;
  DateTime? releaseDate;
  String releaseGoal;
  String scope;
  String status;
  String version;
  int? piNumber;
  String trainName;
  List<String> epicIds;
  List<String> featureIds;
  List<String> storyIds;

  AgileReleasePlan copyWith({
    String? releaseLabel,
    DateTime? releaseDate,
    String? releaseGoal,
    String? scope,
    String? status,
    String? version,
    int? piNumber,
    String? trainName,
    List<String>? epicIds,
    List<String>? featureIds,
    List<String>? storyIds,
  }) {
    return AgileReleasePlan(
      id: id,
      releaseLabel: releaseLabel ?? this.releaseLabel,
      releaseDate: releaseDate ?? this.releaseDate,
      releaseGoal: releaseGoal ?? this.releaseGoal,
      scope: scope ?? this.scope,
      status: status ?? this.status,
      version: version ?? this.version,
      piNumber: piNumber ?? this.piNumber,
      trainName: trainName ?? this.trainName,
      epicIds: epicIds ?? this.epicIds,
      featureIds: featureIds ?? this.featureIds,
      storyIds: storyIds ?? this.storyIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'releaseLabel': releaseLabel,
        'releaseDate': releaseDate?.toIso8601String(),
        'releaseGoal': releaseGoal,
        'scope': scope,
        'status': status,
        'version': version,
        'piNumber': piNumber,
        'trainName': trainName,
        'epicIds': epicIds,
        'featureIds': featureIds,
        'storyIds': storyIds,
      };

  factory AgileReleasePlan.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) {
      final value = raw?.toString() ?? '';
      if (value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    return AgileReleasePlan(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      releaseLabel: json['releaseLabel']?.toString() ?? '',
      releaseDate: parseDate(json['releaseDate']),
      releaseGoal: json['releaseGoal']?.toString() ?? '',
      scope: json['scope']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Draft',
      version: json['version']?.toString() ?? '',
      piNumber: json['piNumber'] as int?,
      trainName: json['trainName']?.toString() ?? '',
      epicIds:
          (json['epicIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      featureIds:
          (json['featureIds'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      storyIds:
          (json['storyIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
