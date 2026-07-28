class ContractClaim {
  final String id;
  final String contractId;
  final String claimNumber;
  final String title;
  final String description;
  final String status; // 'draft' | 'submitted' | 'under_review' | 'approved' | 'rejected' | 'settled'
  final double claimAmount;
  final String justification;
  final String disputeResolution;
  final String? changeRequestId;
  final DateTime? submittedDate;
  final DateTime? resolvedDate;
  final String submittedBy;
  final String approvedBy;
  final DateTime createdAt;

  ContractClaim({
    String? id,
    required this.contractId,
    required this.claimNumber,
    this.title = '',
    this.description = '',
    this.status = 'draft',
    this.claimAmount = 0,
    this.justification = '',
    this.disputeResolution = '',
    this.changeRequestId,
    this.submittedDate,
    this.resolvedDate,
    this.submittedBy = '',
    this.approvedBy = '',
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'contractId': contractId,
        'claimNumber': claimNumber,
        'title': title,
        'description': description,
        'status': status,
        'claimAmount': claimAmount,
        'justification': justification,
        'disputeResolution': disputeResolution,
        'changeRequestId': changeRequestId,
        'submittedDate': submittedDate?.toIso8601String(),
        'resolvedDate': resolvedDate?.toIso8601String(),
        'submittedBy': submittedBy,
        'approvedBy': approvedBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ContractClaim.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      if (v is DateTime) return v;
      return null;
    }

    double toDouble(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

    return ContractClaim(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      contractId: json['contractId']?.toString() ?? '',
      claimNumber: json['claimNumber']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      claimAmount: toDouble(json['claimAmount']),
      justification: json['justification']?.toString() ?? '',
      disputeResolution: json['disputeResolution']?.toString() ?? '',
      changeRequestId: json['changeRequestId']?.toString(),
      submittedDate: parseDate(json['submittedDate']),
      resolvedDate: parseDate(json['resolvedDate']),
      submittedBy: json['submittedBy']?.toString() ?? '',
      approvedBy: json['approvedBy']?.toString() ?? '',
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}
