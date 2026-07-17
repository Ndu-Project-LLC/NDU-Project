class RoadmapSprint {
  final String id;
  String name;
  DateTime? startDate;
  DateTime? endDate;
  String goal;
  int order;
  String createdById;
  String createdByEmail;
  String createdByName;
  int capacityPoints;
  double focusFactor;
  String squadName;

  RoadmapSprint({
    String? id,
    this.name = '',
    this.startDate,
    this.endDate,
    this.goal = '',
    this.order = 0,
    this.createdById = '',
    this.createdByEmail = '',
    this.createdByName = '',
    this.capacityPoints = 0,
    this.focusFactor = 1,
    this.squadName = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  String get dateRangeLabel {
    if (startDate == null && endDate == null) return '';
    final start = startDate != null
        ? '${startDate!.month.toString().padLeft(2, '0')}/${startDate!.day.toString().padLeft(2, '0')}'
        : '?';
    final end = endDate != null
        ? '${endDate!.month.toString().padLeft(2, '0')}/${endDate!.day.toString().padLeft(2, '0')}'
        : '?';
    return '$start – $end';
  }

  int get durationInDays {
    if (startDate == null || endDate == null) return 14;
    return endDate!.difference(startDate!).inDays;
  }

  RoadmapSprint copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    String? goal,
    int? order,
    int? capacityPoints,
    double? focusFactor,
    String? squadName,
  }) {
    return RoadmapSprint(
      id: id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      goal: goal ?? this.goal,
      order: order ?? this.order,
      createdById: createdById,
      createdByEmail: createdByEmail,
      createdByName: createdByName,
      capacityPoints: capacityPoints ?? this.capacityPoints,
      focusFactor: focusFactor ?? this.focusFactor,
      squadName: squadName ?? this.squadName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'goal': goal,
        'order': order,
        'createdById': createdById,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
        'capacityPoints': capacityPoints,
        'focusFactor': focusFactor,
        'squadName': squadName,
      };

  factory RoadmapSprint.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null;
      }
    }

    int parseInt(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 1;
    }

    return RoadmapSprint(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? '',
      startDate: parseDate(json['startDate']?.toString()),
      endDate: parseDate(json['endDate']?.toString()),
      goal: json['goal']?.toString() ?? '',
      order: parseInt(json['order']),
      createdById: json['createdById']?.toString() ?? '',
      createdByEmail: json['createdByEmail']?.toString() ?? '',
      createdByName: json['createdByName']?.toString() ?? '',
      capacityPoints: parseInt(json['capacityPoints']),
      focusFactor: parseDouble(json['focusFactor']),
      squadName: json['squadName']?.toString() ?? '',
    );
  }
}
