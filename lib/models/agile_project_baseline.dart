class AgileBaselineAssumption {
  AgileBaselineAssumption({
    String? id,
    this.category = '',
    this.impact = 'Medium',
    this.text = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  String category;
  String impact;
  String text;

  AgileBaselineAssumption copyWith({
    String? category,
    String? impact,
    String? text,
  }) {
    return AgileBaselineAssumption(
      id: id,
      category: category ?? this.category,
      impact: impact ?? this.impact,
      text: text ?? this.text,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'impact': impact,
        'text': text,
      };

  factory AgileBaselineAssumption.fromJson(Map<String, dynamic> json) {
    return AgileBaselineAssumption(
      id: json['id']?.toString(),
      category: json['category']?.toString() ?? '',
      impact: json['impact']?.toString() ?? 'Medium',
      text: json['text']?.toString() ?? '',
    );
  }
}

class AgileProjectBaseline {
  AgileProjectBaseline({
    this.status = 'Draft',
    this.targetReleaseLabel = '',
    this.targetReleaseDate,
    this.approverUserId = '',
    this.approverName = '',
    this.approverFallbackName = '',
    this.approvalDate,
    this.approvalNotes = '',
    this.capacityThresholdPointsPerSprint,
    this.definitionOfDone = '',
    this.changeControl = '',
    List<AgileBaselineAssumption>? assumptions,
  }) : assumptions = assumptions ?? <AgileBaselineAssumption>[];

  String status;
  String targetReleaseLabel;
  DateTime? targetReleaseDate;
  String approverUserId;
  String approverName;
  String approverFallbackName;
  DateTime? approvalDate;
  String approvalNotes;
  int? capacityThresholdPointsPerSprint;
  String definitionOfDone;
  String changeControl;
  List<AgileBaselineAssumption> assumptions;

  Map<String, dynamic> toJson() => {
        'status': status,
        'targetReleaseLabel': targetReleaseLabel,
        'targetReleaseDate': targetReleaseDate?.toIso8601String(),
        'approverUserId': approverUserId,
        'approverName': approverName,
        'approverFallbackName': approverFallbackName,
        'approvalDate': approvalDate?.toIso8601String(),
        'approvalNotes': approvalNotes,
        'capacityThresholdPointsPerSprint': capacityThresholdPointsPerSprint,
        'definitionOfDone': definitionOfDone,
        'changeControl': changeControl,
        'assumptions': assumptions.map((item) => item.toJson()).toList(),
      };

  factory AgileProjectBaseline.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) {
      final value = raw?.toString() ?? '';
      if (value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    int? parseInt(dynamic raw) {
      if (raw == null) return null;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString());
    }

    return AgileProjectBaseline(
      status: json['status']?.toString() ?? 'Draft',
      targetReleaseLabel: json['targetReleaseLabel']?.toString() ?? '',
      targetReleaseDate: parseDate(json['targetReleaseDate']),
      approverUserId: json['approverUserId']?.toString() ?? '',
      approverName: json['approverName']?.toString() ?? '',
      approverFallbackName: json['approverFallbackName']?.toString() ?? '',
      approvalDate: parseDate(json['approvalDate']),
      approvalNotes: json['approvalNotes']?.toString() ?? '',
      capacityThresholdPointsPerSprint:
          parseInt(json['capacityThresholdPointsPerSprint']),
      definitionOfDone: json['definitionOfDone']?.toString() ?? '',
      changeControl: json['changeControl']?.toString() ?? '',
      assumptions: (json['assumptions'] as List?)
              ?.map((item) => AgileBaselineAssumption.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList() ??
          <AgileBaselineAssumption>[],
    );
  }
}
