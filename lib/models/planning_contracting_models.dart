import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentMilestone {
  final String id;
  final String name;
  final String description;
  final double amount;
  final double percentOfContract;
  final double retentionPercent;
  final DateTime? dueDate;
  final String triggerCondition;
  final String status;

  const PaymentMilestone({
    required this.id,
    required this.name,
    this.description = '',
    this.amount = 0.0,
    this.percentOfContract = 0.0,
    this.retentionPercent = 0.0,
    this.dueDate,
    this.triggerCondition = '',
    this.status = 'Planned',
  });

  PaymentMilestone copyWith({
    String? id,
    String? name,
    String? description,
    double? amount,
    double? percentOfContract,
    double? retentionPercent,
    DateTime? dueDate,
    String? triggerCondition,
    String? status,
  }) {
    return PaymentMilestone(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      percentOfContract: percentOfContract ?? this.percentOfContract,
      retentionPercent: retentionPercent ?? this.retentionPercent,
      dueDate: dueDate ?? this.dueDate,
      triggerCondition: triggerCondition ?? this.triggerCondition,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'amount': amount,
      'percentOfContract': percentOfContract,
      'retentionPercent': retentionPercent,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'triggerCondition': triggerCondition,
      'status': status,
    };
  }

  static PaymentMilestone fromMap(Map<String, dynamic> map) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    return PaymentMilestone(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      amount: parseDouble(map['amount']),
      percentOfContract: parseDouble(map['percentOfContract']),
      retentionPercent: parseDouble(map['retentionPercent']),
      dueDate: parseTs(map['dueDate']),
      triggerCondition: (map['triggerCondition'] ?? '').toString(),
      status: (map['status'] ?? 'Planned').toString(),
    );
  }
}

class EvaluationCriteria {
  final String id;
  final String name;
  final String category;
  final double weight;

  EvaluationCriteria({
    String? id,
    required this.name,
    this.category = 'Technical',
    this.weight = 0.0,
  }) : id = id ?? _generateId(name);

  static String _generateId(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  EvaluationCriteria copyWith({
    String? id,
    String? name,
    String? category,
    double? weight,
  }) {
    return EvaluationCriteria(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      weight: weight ?? this.weight,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'weight': weight,
    };
  }

  static EvaluationCriteria fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    return EvaluationCriteria(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      category: (map['category'] ?? 'Technical').toString(),
      weight: parseDouble(map['weight']),
    );
  }
}

class EvaluationScore {
  final String vendorName;
  final String criteriaId;
  final double score;
  final String notes;

  const EvaluationScore({
    required this.vendorName,
    required this.criteriaId,
    this.score = 0.0,
    this.notes = '',
  });

  EvaluationScore copyWith({
    String? vendorName,
    String? criteriaId,
    double? score,
    String? notes,
  }) {
    return EvaluationScore(
      vendorName: vendorName ?? this.vendorName,
      criteriaId: criteriaId ?? this.criteriaId,
      score: score ?? this.score,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorName': vendorName,
      'criteriaId': criteriaId,
      'score': score,
      'notes': notes,
    };
  }

  static EvaluationScore fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    return EvaluationScore(
      vendorName: (map['vendorName'] ?? '').toString(),
      criteriaId: (map['criteriaId'] ?? '').toString(),
      score: parseDouble(map['score']),
      notes: (map['notes'] ?? '').toString(),
    );
  }
}

class VendorTechnicalScreening {
  final String vendorName;
  final String status;
  final String notes;

  const VendorTechnicalScreening({
    required this.vendorName,
    this.status = 'Pending',
    this.notes = '',
  });

  VendorTechnicalScreening copyWith({
    String? vendorName,
    String? status,
    String? notes,
  }) {
    return VendorTechnicalScreening(
      vendorName: vendorName ?? this.vendorName,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorName': vendorName,
      'status': status,
      'notes': notes,
    };
  }

  static VendorTechnicalScreening fromMap(Map<String, dynamic> map) {
    return VendorTechnicalScreening(
      vendorName: (map['vendorName'] ?? '').toString(),
      status: (map['status'] ?? 'Pending').toString(),
      notes: (map['notes'] ?? '').toString(),
    );
  }
}

class NegotiationItem {
  final String id;
  final String item;
  final String ourPosition;
  final String theirPosition;
  final String agreedPosition;
  final String status;

  const NegotiationItem({
    required this.id,
    required this.item,
    this.ourPosition = '',
    this.theirPosition = '',
    this.agreedPosition = '',
    this.status = 'Open',
  });

  NegotiationItem copyWith({
    String? id,
    String? item,
    String? ourPosition,
    String? theirPosition,
    String? agreedPosition,
    String? status,
  }) {
    return NegotiationItem(
      id: id ?? this.id,
      item: item ?? this.item,
      ourPosition: ourPosition ?? this.ourPosition,
      theirPosition: theirPosition ?? this.theirPosition,
      agreedPosition: agreedPosition ?? this.agreedPosition,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item': item,
      'ourPosition': ourPosition,
      'theirPosition': theirPosition,
      'agreedPosition': agreedPosition,
      'status': status,
    };
  }

  static NegotiationItem fromMap(Map<String, dynamic> map) {
    return NegotiationItem(
      id: (map['id'] ?? '').toString(),
      item: (map['item'] ?? '').toString(),
      ourPosition: (map['ourPosition'] ?? '').toString(),
      theirPosition: (map['theirPosition'] ?? '').toString(),
      agreedPosition: (map['agreedPosition'] ?? '').toString(),
      status: (map['status'] ?? 'Open').toString(),
    );
  }
}

class PlanningRfq {
  final String id;
  final String projectId;
  final String title;
  final String scopeOfWork;
  final String linkedScopeId;
  final List<String> invitedContractors;
  final List<EvaluationCriteria> evaluationCriteria;
  final DateTime? submissionDeadline;
  final DateTime? prebidMeetingDate;
  final String status;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlanningRfq({
    required this.id,
    required this.projectId,
    required this.title,
    this.scopeOfWork = '',
    this.linkedScopeId = '',
    this.invitedContractors = const [],
    this.evaluationCriteria = const [],
    this.submissionDeadline,
    this.prebidMeetingDate,
    this.status = 'Draft',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  PlanningRfq copyWith({
    String? id,
    String? projectId,
    String? title,
    String? scopeOfWork,
    String? linkedScopeId,
    List<String>? invitedContractors,
    List<EvaluationCriteria>? evaluationCriteria,
    DateTime? submissionDeadline,
    DateTime? prebidMeetingDate,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlanningRfq(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      scopeOfWork: scopeOfWork ?? this.scopeOfWork,
      linkedScopeId: linkedScopeId ?? this.linkedScopeId,
      invitedContractors: invitedContractors ?? this.invitedContractors,
      evaluationCriteria: evaluationCriteria ?? this.evaluationCriteria,
      submissionDeadline: submissionDeadline ?? this.submissionDeadline,
      prebidMeetingDate: prebidMeetingDate ?? this.prebidMeetingDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'title': title,
      'scopeOfWork': scopeOfWork,
      'linkedScopeId': linkedScopeId,
      'invitedContractors': invitedContractors,
      'evaluationCriteria': evaluationCriteria.map((e) => e.toMap()).toList(),
      'submissionDeadline': submissionDeadline != null
          ? Timestamp.fromDate(submissionDeadline!)
          : null,
      'prebidMeetingDate': prebidMeetingDate != null
          ? Timestamp.fromDate(prebidMeetingDate!)
          : null,
      'status': status,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static PlanningRfq fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    List<String> parseStringList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    List<EvaluationCriteria> parseCriteria(dynamic v) {
      if (v is! List) return [];
      return v
          .whereType<Map>()
          .map((e) => EvaluationCriteria.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    return PlanningRfq(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      scopeOfWork: (data['scopeOfWork'] ?? '').toString(),
      linkedScopeId: (data['linkedScopeId'] ?? '').toString(),
      invitedContractors: parseStringList(data['invitedContractors']),
      evaluationCriteria: parseCriteria(data['evaluationCriteria']),
      submissionDeadline: parseTs(data['submissionDeadline']),
      prebidMeetingDate: parseTs(data['prebidMeetingDate']),
      status: (data['status'] ?? 'Draft').toString(),
      notes: (data['notes'] ?? '').toString(),
      createdAt:
          parseTs(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          parseTs(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ContractBudgetBreakdown {
  final double baseContractValue;
  final double contingencyAmount;
  final double contingencyPercent;
  final double taxFeeEstimate;
  final double totalBudget;
  final double committed;
  final double expended;

  const ContractBudgetBreakdown({
    this.baseContractValue = 0.0,
    this.contingencyAmount = 0.0,
    this.contingencyPercent = 0.0,
    this.taxFeeEstimate = 0.0,
    this.totalBudget = 0.0,
    this.committed = 0.0,
    this.expended = 0.0,
  });

  ContractBudgetBreakdown copyWith({
    double? baseContractValue,
    double? contingencyAmount,
    double? contingencyPercent,
    double? taxFeeEstimate,
    double? totalBudget,
    double? committed,
    double? expended,
  }) {
    return ContractBudgetBreakdown(
      baseContractValue: baseContractValue ?? this.baseContractValue,
      contingencyAmount: contingencyAmount ?? this.contingencyAmount,
      contingencyPercent: contingencyPercent ?? this.contingencyPercent,
      taxFeeEstimate: taxFeeEstimate ?? this.taxFeeEstimate,
      totalBudget: totalBudget ?? this.totalBudget,
      committed: committed ?? this.committed,
      expended: expended ?? this.expended,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'baseContractValue': baseContractValue,
      'contingencyAmount': contingencyAmount,
      'contingencyPercent': contingencyPercent,
      'taxFeeEstimate': taxFeeEstimate,
      'totalBudget': totalBudget,
      'committed': committed,
      'expended': expended,
    };
  }

  static ContractBudgetBreakdown fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    return ContractBudgetBreakdown(
      baseContractValue: parseDouble(map['baseContractValue']),
      contingencyAmount: parseDouble(map['contingencyAmount']),
      contingencyPercent: parseDouble(map['contingencyPercent']),
      taxFeeEstimate: parseDouble(map['taxFeeEstimate']),
      totalBudget: parseDouble(map['totalBudget']),
      committed: parseDouble(map['committed']),
      expended: parseDouble(map['expended']),
    );
  }
}
