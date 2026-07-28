/// Model for a stakeholder alignment item in Stakeholder Alignment page
class StakeholderAlignmentItem {
  final String id;
  String stakeholderName; // Pre-populated from Core Stakeholders
  String stakeholderRole; // Pre-populated from Core Stakeholders
  String alignmentStatus; // Aligned, Neutral, Concerned, Resistent
  String keyInterest; // ROI, Security, Ease of Use, etc.
  String
      feedbackSummary; // Prose (no bullets), blank by default, manual input only
  String engagementStrategy; // "." bullet format for agreed outcomes/next steps
  DateTime? lastEngagementDate; // Date picker

  StakeholderAlignmentItem({
    String? id,
    this.stakeholderName = '',
    this.stakeholderRole = '',
    this.alignmentStatus = 'Neutral',
    this.keyInterest = '',
    this.feedbackSummary = '',
    this.engagementStrategy = '',
    this.lastEngagementDate,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  StakeholderAlignmentItem copyWith({
    String? stakeholderName,
    String? stakeholderRole,
    String? alignmentStatus,
    String? keyInterest,
    String? feedbackSummary,
    String? engagementStrategy,
    DateTime? lastEngagementDate,
  }) {
    return StakeholderAlignmentItem(
      id: id,
      stakeholderName: stakeholderName ?? this.stakeholderName,
      stakeholderRole: stakeholderRole ?? this.stakeholderRole,
      alignmentStatus: alignmentStatus ?? this.alignmentStatus,
      keyInterest: keyInterest ?? this.keyInterest,
      feedbackSummary: feedbackSummary ?? this.feedbackSummary,
      engagementStrategy: engagementStrategy ?? this.engagementStrategy,
      lastEngagementDate: lastEngagementDate ?? this.lastEngagementDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'stakeholderName': stakeholderName,
        'stakeholderRole': stakeholderRole,
        'alignmentStatus': alignmentStatus,
        'keyInterest': keyInterest,
        'feedbackSummary': feedbackSummary,
        'engagementStrategy': engagementStrategy,
        'lastEngagementDate': lastEngagementDate?.toIso8601String(),
      };

  factory StakeholderAlignmentItem.fromJson(Map<String, dynamic> json) {
    return StakeholderAlignmentItem(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      stakeholderName: json['stakeholderName']?.toString() ?? '',
      stakeholderRole: json['stakeholderRole']?.toString() ?? '',
      alignmentStatus: json['alignmentStatus']?.toString() ?? 'Neutral',
      keyInterest: json['keyInterest']?.toString() ?? '',
      feedbackSummary: json['feedbackSummary']?.toString() ?? '',
      engagementStrategy: json['engagementStrategy']?.toString() ?? '',
      lastEngagementDate: json['lastEngagementDate'] != null
          ? DateTime.tryParse(json['lastEngagementDate'].toString())
          : null,
    );
  }
}
