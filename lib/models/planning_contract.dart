/// Planning-phase contract model for contract tracking with progress bar.
///
/// This is separate from [ContractModel] in contract_service.dart which is
/// the deeply-embedded execution-phase model. This model is for the
/// Planning Phase contract tracking view.
class PlanningContract {
  final String id;
  String title;
  String type; // 'Lump Sum' | 'T&M' | 'Cost-Plus' | 'FFP' | 'Other'
  String status; // 'Draft' | 'Negotiation' | 'Executed' | 'Active' | 'Almost Complete' | 'Closed Out'
  String contractorName;
  double estimatedValue;
  double actualValue;
  String startDate;
  String endDate;
  List<ContractPaymentMilestone> paymentMilestones;
  List<String> linkedWbsIds;
  List<String> linkedRequirements;
  String discipline;
  String notes;
  DateTime createdAt;
  DateTime updatedAt;

  PlanningContract({
    String? id,
    this.title = '',
    this.type = 'Lump Sum',
    this.status = 'Draft',
    this.contractorName = '',
    this.estimatedValue = 0,
    this.actualValue = 0,
    this.startDate = '',
    this.endDate = '',
    List<ContractPaymentMilestone>? paymentMilestones,
    List<String>? linkedWbsIds,
    List<String>? linkedRequirements,
    this.discipline = '',
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        paymentMilestones = paymentMilestones ?? [],
        linkedWbsIds = linkedWbsIds ?? [],
        linkedRequirements = linkedRequirements ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Compute progress (0-100) from payment milestones.
  /// If no milestones, derive from status string.
  double get progress {
    if (paymentMilestones.isNotEmpty) {
      final completed = paymentMilestones.where((m) => m.isCompleted).length;
      return (completed / paymentMilestones.length) * 100;
    }
    // Fallback: derive from status
    final s = status.toLowerCase();
    if (s.contains('closed') || s.contains('complete')) return 100;
    if (s.contains('almost')) return 85;
    if (s.contains('active') || s.contains('progress')) return 60;
    if (s.contains('executed')) return 40;
    if (s.contains('negotiation') || s.contains('pending')) return 20;
    return 0; // Draft or Not Started
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'status': status,
        'contractorName': contractorName,
        'estimatedValue': estimatedValue,
        'actualValue': actualValue,
        'startDate': startDate,
        'endDate': endDate,
        'paymentMilestones': paymentMilestones.map((m) => m.toJson()).toList(),
        'linkedWbsIds': linkedWbsIds,
        'linkedRequirements': linkedRequirements,
        'discipline': discipline,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PlanningContract.fromJson(Map<String, dynamic> json) {
    return PlanningContract(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Lump Sum',
      status: json['status']?.toString() ?? 'Draft',
      contractorName: json['contractorName']?.toString() ?? '',
      estimatedValue: json['estimatedValue'] is num
          ? (json['estimatedValue'] as num).toDouble()
          : 0,
      actualValue: json['actualValue'] is num
          ? (json['actualValue'] as num).toDouble()
          : 0,
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      paymentMilestones: (json['paymentMilestones'] as List?)
              ?.map((e) => ContractPaymentMilestone.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
      linkedWbsIds: (json['linkedWbsIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      linkedRequirements: (json['linkedRequirements'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      discipline: json['discipline']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  PlanningContract copyWith({
    String? title,
    String? type,
    String? status,
    String? contractorName,
    double? estimatedValue,
    double? actualValue,
    String? startDate,
    String? endDate,
    List<ContractPaymentMilestone>? paymentMilestones,
    List<String>? linkedWbsIds,
    List<String>? linkedRequirements,
    String? discipline,
    String? notes,
  }) {
    return PlanningContract(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      contractorName: contractorName ?? this.contractorName,
      estimatedValue: estimatedValue ?? this.estimatedValue,
      actualValue: actualValue ?? this.actualValue,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      paymentMilestones: paymentMilestones ?? this.paymentMilestones,
      linkedWbsIds: linkedWbsIds ?? this.linkedWbsIds,
      linkedRequirements: linkedRequirements ?? this.linkedRequirements,
      discipline: discipline ?? this.discipline,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class ContractPaymentMilestone {
  final String id;
  String title;
  double amount;
  String dueDate;
  bool isCompleted;
  String completedDate;
  String notes;

  ContractPaymentMilestone({
    String? id,
    this.title = '',
    this.amount = 0,
    this.dueDate = '',
    this.isCompleted = false,
    this.completedDate = '',
    this.notes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'dueDate': dueDate,
        'isCompleted': isCompleted,
        'completedDate': completedDate,
        'notes': notes,
      };

  factory ContractPaymentMilestone.fromJson(Map<String, dynamic> json) {
    return ContractPaymentMilestone(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      amount: json['amount'] is num
          ? (json['amount'] as num).toDouble()
          : 0,
      dueDate: json['dueDate']?.toString() ?? '',
      isCompleted: json['isCompleted'] == true,
      completedDate: json['completedDate']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is DateTime) return v;
  return DateTime.now();
}
