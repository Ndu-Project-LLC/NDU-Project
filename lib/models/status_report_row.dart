/// Model for a status report row in Progress Tracking
class StatusReportRow {
  final String id;
  String
      reportType; // Weekly Update, Stakeholder Brief, Executive Summary, Risk Report
  String stakeholder; // Who this report is for
  DateTime reportDate;
  String summary; // Prose description (no bullets)
  String keyWins; // "." bullet list
  String blockers; // "." bullet list
  String asks; // "." bullet list
  String followUps; // "." bullet list
  String notes; // Manual notes only, no AI generation
  String status; // Draft, Sent, Acknowledged

  StatusReportRow({
    String? id,
    this.reportType = '',
    this.stakeholder = '',
    DateTime? reportDate,
    this.summary = '',
    this.keyWins = '',
    this.blockers = '',
    this.asks = '',
    this.followUps = '',
    this.notes = '',
    this.status = 'Draft',
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        reportDate = reportDate ?? DateTime.now();

  StatusReportRow copyWith({
    String? reportType,
    String? stakeholder,
    DateTime? reportDate,
    String? summary,
    String? keyWins,
    String? blockers,
    String? asks,
    String? followUps,
    String? notes,
    String? status,
  }) {
    return StatusReportRow(
      id: id,
      reportType: reportType ?? this.reportType,
      stakeholder: stakeholder ?? this.stakeholder,
      reportDate: reportDate ?? this.reportDate,
      summary: summary ?? this.summary,
      keyWins: keyWins ?? this.keyWins,
      blockers: blockers ?? this.blockers,
      asks: asks ?? this.asks,
      followUps: followUps ?? this.followUps,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reportType': reportType,
        'stakeholder': stakeholder,
        'reportDate': reportDate.toIso8601String(),
        'summary': summary,
        'keyWins': keyWins,
        'blockers': blockers,
        'asks': asks,
        'followUps': followUps,
        'notes': notes,
        'status': status,
      };

  factory StatusReportRow.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return DateTime.now();
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return DateTime.now();
      }
    }

    return StatusReportRow(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      reportType: json['reportType']?.toString() ?? '',
      stakeholder: json['stakeholder']?.toString() ?? '',
      reportDate: parseDate(json['reportDate']?.toString()),
      summary: json['summary']?.toString() ?? '',
      keyWins: json['keyWins']?.toString() ?? '',
      blockers: json['blockers']?.toString() ?? '',
      asks: json['asks']?.toString() ?? '',
      followUps: json['followUps']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Draft',
    );
  }
}
