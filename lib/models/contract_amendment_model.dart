class ContractAmendment {
  final String id;
  final String contractId;
  final String amendmentNumber;
  final String title;
  final String description;
  final String status; // 'draft' | 'pending_approval' | 'approved' | 'executed' | 'rejected'
  final DateTime? approvalDate;
  final String? changeRequestId;

  // Deltas from the original contract
  final double scopeChangeCost;
  final int scheduleDelayDays;
  final String scopeDescription;

  final String approvedBy;
  final DateTime createdAt;

  ContractAmendment({
    String? id,
    required this.contractId,
    required this.amendmentNumber,
    this.title = '',
    this.description = '',
    this.status = 'draft',
    this.approvalDate,
    this.changeRequestId,
    this.scopeChangeCost = 0,
    this.scheduleDelayDays = 0,
    this.scopeDescription = '',
    this.approvedBy = '',
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'contractId': contractId,
        'amendmentNumber': amendmentNumber,
        'title': title,
        'description': description,
        'status': status,
        'approvalDate': approvalDate?.toIso8601String(),
        'changeRequestId': changeRequestId,
        'scopeChangeCost': scopeChangeCost,
        'scheduleDelayDays': scheduleDelayDays,
        'scopeDescription': scopeDescription,
        'approvedBy': approvedBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ContractAmendment.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      if (v is DateTime) return v;
      return null;
    }

    return ContractAmendment(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      contractId: json['contractId']?.toString() ?? '',
      amendmentNumber: json['amendmentNumber']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      approvalDate: parseDate(json['approvalDate']),
      changeRequestId: json['changeRequestId']?.toString(),
      scopeChangeCost: (json['scopeChangeCost'] is num)
          ? (json['scopeChangeCost'] as num).toDouble()
          : 0,
      scheduleDelayDays: (json['scheduleDelayDays'] is num)
          ? (json['scheduleDelayDays'] as num).toInt()
          : 0,
      scopeDescription: json['scopeDescription']?.toString() ?? '',
      approvedBy: json['approvedBy']?.toString() ?? '',
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}
