import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a procurement item
enum ProcurementItemStatus {
  planning,
  rfqReview,
  vendorSelection,
  ordered,
  delivered,
  cancelled
}

/// Priority of a procurement item
enum ProcurementPriority { low, medium, high, critical }

/// Status of a strategy
enum StrategyStatus { draft, active, complete }

/// Status of an RFQ
enum RfqStatus {
  draft,
  review, // Internal review
  inMarket, // Sent to vendors
  evaluation, // Evaluating responses
  awarded,
  closed
}

/// Status of a Purchase Order
enum PurchaseOrderStatus {
  draft,
  awaitingApproval,
  issued,
  inTransit,
  received,
  cancelled
}

/// Represents a timeline event for an item
class ProcurementEvent {
  final String title;
  final String description;
  final String subtext;
  final DateTime date;
  final String status; // 'completed', 'pending', 'issue'

  const ProcurementEvent({
    required this.title,
    required this.description,
    required this.subtext,
    required this.date,
    this.status = 'completed',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'subtext': subtext,
        'date': Timestamp.fromDate(date),
        'status': status,
      };

  factory ProcurementEvent.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return ProcurementEvent(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      subtext: json['subtext'] ?? '',
      date: parseDate(json['date']),
      status: json['status'] ?? 'completed',
    );
  }
}

/// Main Procurement Item Model
class ProcurementItemModel {
  final String id;
  final String projectId;
  final String name;
  final String description;
  final String category; // e.g., 'IT Equipment', 'Construction'
  final ProcurementItemStatus status;
  final ProcurementPriority priority;
  final double budget;
  final double spent; // Actual spend
  final DateTime? estimatedDelivery;
  final DateTime? actualDelivery;
  final double progress; // 0.0 to 1.0
  final String? vendorId; // Link to VendorCollection
  final String? contractId; // Link to ContractCollection
  final List<ProcurementEvent> events; // Tracking history
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String projectPhase; // e.g. "Planning", "Execution"
  final String responsibleMember;
  final String comments;
  final String currencyCode; // Multi-currency support

  // Schedule linkage fields
  final String? linkedWbsId; // Links to ScheduleActivity.wbsId
  final String? linkedMilestoneId; // Links to ScheduleActivity.id
  final DateTime? requiredByDate; // Derived from milestone, manual override

  // Vendor comparison weighting
  final VendorWeighting? vendorWeighting;

  const ProcurementItemModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.description,
    required this.category,
    this.status = ProcurementItemStatus.planning,
    this.priority = ProcurementPriority.medium,
    this.budget = 0.0,
    this.spent = 0.0,
    this.estimatedDelivery,
    this.actualDelivery,
    this.progress = 0.0,
    this.vendorId,
    this.contractId,
    this.events = const [],
    this.notes = '',
    this.projectPhase = 'Planning',
    this.responsibleMember = '',
    this.comments = '',
    this.currencyCode = 'USD',
    this.linkedWbsId,
    this.linkedMilestoneId,
    this.requiredByDate,
    this.vendorWeighting,
    required this.createdAt,
    required this.updatedAt,
  });

  ProcurementItemModel copyWith({
    String? id,
    String? projectId,
    String? name,
    String? description,
    String? category,
    ProcurementItemStatus? status,
    ProcurementPriority? priority,
    double? budget,
    double? spent,
    DateTime? estimatedDelivery,
    DateTime? actualDelivery,
    double? progress,
    String? vendorId,
    String? contractId,
    List<ProcurementEvent>? events,
    String? notes,
    String? projectPhase,
    String? responsibleMember,
    String? comments,
    String? currencyCode,
    String? linkedWbsId,
    String? linkedMilestoneId,
    DateTime? requiredByDate,
    VendorWeighting? vendorWeighting,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProcurementItemModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      budget: budget ?? this.budget,
      spent: spent ?? this.spent,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      actualDelivery: actualDelivery ?? this.actualDelivery,
      progress: progress ?? this.progress,
      vendorId: vendorId ?? this.vendorId,
      contractId: contractId ?? this.contractId,
      events: events ?? this.events,
      notes: notes ?? this.notes,
      projectPhase: projectPhase ?? this.projectPhase,
      responsibleMember: responsibleMember ?? this.responsibleMember,
      comments: comments ?? this.comments,
      currencyCode: currencyCode ?? this.currencyCode,
      linkedWbsId: linkedWbsId ?? this.linkedWbsId,
      linkedMilestoneId: linkedMilestoneId ?? this.linkedMilestoneId,
      requiredByDate: requiredByDate ?? this.requiredByDate,
      vendorWeighting: vendorWeighting ?? this.vendorWeighting,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'name': name,
        'description': description,
        'category': category,
        'status': status.name,
        'priority': priority.name,
        'budget': budget,
        'spent': spent,
        'estimatedDelivery': estimatedDelivery != null
            ? Timestamp.fromDate(estimatedDelivery!)
            : null,
        'actualDelivery':
            actualDelivery != null ? Timestamp.fromDate(actualDelivery!) : null,
        'progress': progress,
        'vendorId': vendorId,
        'contractId': contractId,
        'events': events.map((e) => e.toJson()).toList(),
        'notes': notes,
        'projectPhase': projectPhase,
        'responsibleMember': responsibleMember,
        'comments': comments,
        'currencyCode': currencyCode,
        'linkedWbsId': linkedWbsId,
        'linkedMilestoneId': linkedMilestoneId,
        'requiredByDate': requiredByDate != null
            ? Timestamp.fromDate(requiredByDate!)
            : null,
        'vendorWeighting': vendorWeighting?.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static ProcurementItemModel fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime? parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    DateTime guaranteedDate(dynamic v) {
      return parseDate(v) ?? DateTime.now();
    }

    return ProcurementItemModel(
      id: doc.id,
      projectId: data['projectId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      status: ProcurementItemStatus.values.firstWhere(
          (e) => e.name == (data['status'] ?? 'planning'),
          orElse: () => ProcurementItemStatus.planning),
      priority: ProcurementPriority.values.firstWhere(
          (e) => e.name == (data['priority'] ?? 'medium'),
          orElse: () => ProcurementPriority.medium),
      budget: (data['budget'] as num?)?.toDouble() ?? 0.0,
      spent: (data['spent'] as num?)?.toDouble() ?? 0.0,
      estimatedDelivery: parseDate(data['estimatedDelivery']),
      actualDelivery: parseDate(data['actualDelivery']),
      progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
      vendorId: data['vendorId'],
      contractId: data['contractId'],
      events: (data['events'] as List?)
              ?.map((e) => ProcurementEvent.fromJson(e))
              .toList() ??
          [],
      notes: data['notes'] ?? '',
      projectPhase: data['projectPhase'] ?? 'Planning',
      responsibleMember: data['responsibleMember'] ?? '',
      comments: data['comments'] ?? '',
      currencyCode: data['currencyCode'] ?? 'USD',
      linkedWbsId: data['linkedWbsId'],
      linkedMilestoneId: data['linkedMilestoneId'],
      requiredByDate: parseDate(data['requiredByDate']),
      vendorWeighting: data['vendorWeighting'] != null
          ? VendorWeighting.fromMap(
              Map<String, dynamic>.from(data['vendorWeighting']))
          : null,
      createdAt: guaranteedDate(data['createdAt']),
      updatedAt: guaranteedDate(data['updatedAt']),
    );
  }
}

/// Vendor weighting configuration for per-item comparison
class VendorWeighting {
  final double priceWeight; // Default 0.4
  final double qualityWeight; // Default 0.3
  final double deliveryWeight; // Default 0.2
  final double serviceWeight; // Default 0.1

  const VendorWeighting({
    this.priceWeight = 0.4,
    this.qualityWeight = 0.3,
    this.deliveryWeight = 0.2,
    this.serviceWeight = 0.1,
  });

  VendorWeighting copyWith({
    double? priceWeight,
    double? qualityWeight,
    double? deliveryWeight,
    double? serviceWeight,
  }) {
    return VendorWeighting(
      priceWeight: priceWeight ?? this.priceWeight,
      qualityWeight: qualityWeight ?? this.qualityWeight,
      deliveryWeight: deliveryWeight ?? this.deliveryWeight,
      serviceWeight: serviceWeight ?? this.serviceWeight,
    );
  }

  Map<String, dynamic> toMap() => {
        'priceWeight': priceWeight,
        'qualityWeight': qualityWeight,
        'deliveryWeight': deliveryWeight,
        'serviceWeight': serviceWeight,
      };

  factory VendorWeighting.fromMap(Map<String, dynamic> map) {
    return VendorWeighting(
      priceWeight: (map['priceWeight'] as num?)?.toDouble() ?? 0.4,
      qualityWeight: (map['qualityWeight'] as num?)?.toDouble() ?? 0.3,
      deliveryWeight: (map['deliveryWeight'] as num?)?.toDouble() ?? 0.2,
      serviceWeight: (map['serviceWeight'] as num?)?.toDouble() ?? 0.1,
    );
  }

  double calculateScore({
    required double priceScore,
    required double qualityScore,
    required double deliveryScore,
    required double serviceScore,
  }) {
    return (priceScore * priceWeight) +
        (qualityScore * qualityWeight) +
        (deliveryScore * deliveryWeight) +
        (serviceScore * serviceWeight);
  }

  bool get isValid =>
      (priceWeight + qualityWeight + deliveryWeight + serviceWeight)
          .abs() <= 1.01;
}

/// Status of a contract
enum ContractStatus {
  draft,
  // ignore: constant_identifier_names
  under_review,
  approved,
  executed,
  expired,
  terminated
}

/// Contract Model for specific contracted work
class ContractModel {
  final String id;
  final String projectId;
  final String title; // "Item" in the table
  final String description;
  final String contractorName;
  final double estimatedCost;
  final String duration;
  final ContractStatus status; // Upgraded from String
  final DateTime? startDate; // Added
  final DateTime? endDate; // Added
  final String owner; // Added owner field
  final DateTime createdAt;

  const ContractModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.contractorName,
    this.estimatedCost = 0.0,
    this.duration = '',
    this.status = ContractStatus.draft,
    this.startDate,
    this.endDate,
    required this.owner,
    required this.createdAt,
  });

  ContractModel copyWith({
    String? id,
    String? projectId,
    String? title,
    String? description,
    String? contractorName,
    double? estimatedCost,
    String? duration,
    ContractStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? owner,
    DateTime? createdAt,
  }) {
    return ContractModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      contractorName: contractorName ?? this.contractorName,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      owner: owner ?? this.owner,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'title': title,
        'description': description,
        'contractorName': contractorName,
        'estimatedCost': estimatedCost,
        'duration': duration,
        'status': status.name,
        'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'owner': owner,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static ContractModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ContractModel(
      id: doc.id,
      projectId: data['projectId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      contractorName: data['contractorName'] ?? '',
      estimatedCost: (data['estimatedCost'] as num?)?.toDouble() ?? 0.0,
      duration: data['duration'] ?? '',
      status: ContractStatus.values.firstWhere(
          (e) => e.name == (data['status'] ?? 'draft'),
          orElse: () => ContractStatus.draft),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      owner: data['owner'] ?? 'Unassigned',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Procurement Strategy Model
class ProcurementStrategyModel {
  final String id;
  final String projectId;
  final String title;
  final String category;
  final String description;
  final StrategyStatus status;
  final int itemCount; // Cached count or manual entry
  final DateTime createdAt;

  const ProcurementStrategyModel({
    required this.id,
    required this.projectId,
    required this.title,
    this.category = '',
    required this.description,
    this.status = StrategyStatus.draft,
    this.itemCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'title': title,
        'category': category,
        'description': description,
        'status': status.name,
        'itemCount': itemCount,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static ProcurementStrategyModel fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawStatus =
        (data['status'] ?? 'draft').toString().trim().toLowerCase();
    final normalizedStatus = rawStatus == 'archived' ? 'complete' : rawStatus;
    return ProcurementStrategyModel(
      id: doc.id,
      projectId: data['projectId'] ?? '',
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      status: StrategyStatus.values.firstWhere(
          (e) => e.name == normalizedStatus,
          orElse: () => StrategyStatus.draft),
      itemCount: (data['itemCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Request for Quote (RFQ) Model
class RfqModel {
  final String id;
  final String projectId;
  final String title;
  final String category;
  final String owner;
  final DateTime dueDate;
  final int invitedCount;
  final int responseCount;
  final double budget;
  final RfqStatus status;
  final ProcurementPriority priority;
  final DateTime createdAt;

  const RfqModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.category,
    this.owner = '',
    required this.dueDate,
    this.invitedCount = 0,
    this.responseCount = 0,
    this.budget = 0.0,
    this.status = RfqStatus.draft,
    this.priority = ProcurementPriority.medium,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'title': title,
        'category': category,
        'owner': owner,
        'dueDate': Timestamp.fromDate(dueDate),
        'invitedCount': invitedCount,
        'responseCount': responseCount,
        'budget': budget,
        'status': status.name,
        'priority': priority.name,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static RfqModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return RfqModel(
      id: doc.id,
      projectId: data['projectId'] ?? '',
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      owner: data['owner'] ?? '',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      invitedCount: (data['invitedCount'] as num?)?.toInt() ?? 0,
      responseCount: (data['responseCount'] as num?)?.toInt() ?? 0,
      budget: (data['budget'] as num?)?.toDouble() ?? 0.0,
      status: RfqStatus.values.firstWhere(
          (e) => e.name == (data['status'] ?? 'draft'),
          orElse: () => RfqStatus.draft),
      priority: ProcurementPriority.values.firstWhere(
          (e) => e.name == (data['priority'] ?? 'medium'),
          orElse: () => ProcurementPriority.medium),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Purchase Order (PO) Model
class PurchaseOrderModel {
  final String id;
  final String poNumber; // Separate generic ID from user-facing PO#
  final String projectId;
  final String vendorName; // Cached name for display
  final String? vendorId; // Link
  final String category;
  final String owner;
  final DateTime orderedDate;
  final DateTime expectedDate;
  final double amount;
  final double progress;
  final PurchaseOrderStatus status;
  final DateTime createdAt;
  final String currencyCode; // Multi-currency support

  // Approval workflow fields
  final String? approverId;
  final String? approverName;
  final DateTime? approvalDate;
  final String approvalStatus; // 'draft', 'pending', 'approved', 'rejected', 'escalated'
  final String? rejectionReason;
  final String? approverComments;
  final int escalationDays; // Configurable per PO
  final String? escalationTargetId;

  const PurchaseOrderModel({
    required this.id,
    required this.poNumber,
    required this.projectId,
    required this.vendorName,
    this.vendorId,
    required this.category,
    this.owner = '',
    required this.orderedDate,
    required this.expectedDate,
    this.amount = 0.0,
    this.progress = 0.0,
    this.status = PurchaseOrderStatus.draft,
    required this.createdAt,
    this.currencyCode = 'USD',
    this.approverId,
    this.approverName,
    this.approvalDate,
    this.approvalStatus = 'draft',
    this.rejectionReason,
    this.approverComments,
    this.escalationDays = 3,
    this.escalationTargetId,
  });

  PurchaseOrderModel copyWith({
    String? id,
    String? poNumber,
    String? projectId,
    String? vendorName,
    String? vendorId,
    String? category,
    String? owner,
    DateTime? orderedDate,
    DateTime? expectedDate,
    double? amount,
    double? progress,
    PurchaseOrderStatus? status,
    DateTime? createdAt,
    String? currencyCode,
    String? approverId,
    String? approverName,
    DateTime? approvalDate,
    String? approvalStatus,
    String? rejectionReason,
    String? approverComments,
    int? escalationDays,
    String? escalationTargetId,
  }) {
    return PurchaseOrderModel(
      id: id ?? this.id,
      poNumber: poNumber ?? this.poNumber,
      projectId: projectId ?? this.projectId,
      vendorName: vendorName ?? this.vendorName,
      vendorId: vendorId ?? this.vendorId,
      category: category ?? this.category,
      owner: owner ?? this.owner,
      orderedDate: orderedDate ?? this.orderedDate,
      expectedDate: expectedDate ?? this.expectedDate,
      amount: amount ?? this.amount,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      currencyCode: currencyCode ?? this.currencyCode,
      approverId: approverId ?? this.approverId,
      approverName: approverName ?? this.approverName,
      approvalDate: approvalDate ?? this.approvalDate,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      approverComments: approverComments ?? this.approverComments,
      escalationDays: escalationDays ?? this.escalationDays,
      escalationTargetId: escalationTargetId ?? this.escalationTargetId,
    );
  }

  Map<String, dynamic> toMap() => {
        'poNumber': poNumber,
        'projectId': projectId,
        'vendorName': vendorName,
        'vendorId': vendorId,
        'category': category,
        'owner': owner,
        'orderedDate': Timestamp.fromDate(orderedDate),
        'expectedDate': Timestamp.fromDate(expectedDate),
        'amount': amount,
        'progress': progress,
        'status': status.name,
        'currencyCode': currencyCode,
        'approverId': approverId,
        'approverName': approverName,
        'approvalDate': approvalDate != null
            ? Timestamp.fromDate(approvalDate!)
            : null,
        'approvalStatus': approvalStatus,
        'rejectionReason': rejectionReason,
        'approverComments': approverComments,
        'escalationDays': escalationDays,
        'escalationTargetId': escalationTargetId,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static PurchaseOrderModel fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    String parseString(dynamic value, {String fallback = ''}) {
      if (value == null) return fallback;
      final text = value.toString().trim();
      return text.isEmpty ? fallback : text;
    }

    double parseDouble(dynamic value, {double fallback = 0.0}) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
        return double.tryParse(cleaned) ?? fallback;
      }
      return fallback;
    }

    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      if (value is int) {
        final isSeconds = value > 0 && value < 1000000000000;
        return DateTime.fromMillisecondsSinceEpoch(
            isSeconds ? value * 1000 : value);
      }
      if (value is double) {
        final intValue = value.toInt();
        final isSeconds = intValue > 0 && intValue < 1000000000000;
        return DateTime.fromMillisecondsSinceEpoch(
            isSeconds ? intValue * 1000 : intValue);
      }
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      return parseDate(value);
    }

    double parseProgress(dynamic value) {
      final raw = parseDouble(value, fallback: 0.0);
      if (raw.isNaN || !raw.isFinite) {
        return 0.0;
      }
      if (raw > 1.0 && raw <= 100.0) {
        return raw / 100.0;
      }
      if (raw < 0) return 0.0;
      if (raw > 1.0) return 1.0;
      return raw;
    }

    PurchaseOrderStatus parseStatus(dynamic value) {
      final normalized = parseString(value, fallback: 'draft')
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z]'), '');
      switch (normalized) {
        case 'awaitingapproval':
          return PurchaseOrderStatus.awaitingApproval;
        case 'issued':
          return PurchaseOrderStatus.issued;
        case 'intransit':
          return PurchaseOrderStatus.inTransit;
        case 'received':
          return PurchaseOrderStatus.received;
        case 'cancelled':
          return PurchaseOrderStatus.cancelled;
        case 'draft':
        default:
          return PurchaseOrderStatus.draft;
      }
    }

    return PurchaseOrderModel(
      id: doc.id,
      poNumber: parseString(data['poNumber']) != ''
          ? parseString(data['poNumber'])
          : (parseString(data['id']) != ''
              ? parseString(data['id'])
              : (doc.id.length > 6
                  ? doc.id.substring(0, 6).toUpperCase()
                  : doc.id)),
      projectId: parseString(data['projectId']),
      vendorName: parseString(data['vendorName']),
      vendorId: parseString(data['vendorId']),
      category: parseString(data['category']),
      owner: parseString(data['owner']),
      orderedDate: parseDate(data['orderedDate']),
      expectedDate: parseDate(data['expectedDate']),
      amount: parseDouble(data['amount']),
      progress: parseProgress(data['progress']),
      status: parseStatus(data['status']),
      createdAt: parseDate(data['createdAt']),
      currencyCode: parseString(data['currencyCode'], fallback: 'USD'),
      approverId: parseString(data['approverId']),
      approverName: parseString(data['approverName']),
      approvalDate: parseNullableDate(data['approvalDate']),
      approvalStatus: parseString(data['approvalStatus'], fallback: 'draft'),
      rejectionReason: parseString(data['rejectionReason']),
      approverComments: parseString(data['approverComments']),
      escalationDays: (data['escalationDays'] as num?)?.toInt() ?? 3,
      escalationTargetId: parseString(data['escalationTargetId']),
    );
  }
}

/// Extensions for PurchaseOrderModel approval workflow
extension PurchaseOrderApprovalExtension on PurchaseOrderModel {
  /// Check if PO is overdue for approval
  bool get isPendingApproval =>
      approvalStatus == 'pending' &&
      approvalDate != null &&
      DateTime.now().isAfter(
          approvalDate!.add(Duration(days: escalationDays)));

  /// Check if PO has been escalated
  bool get isEscalated => approvalStatus == 'escalated';

  /// Get display-friendly approval status
  String get approvalStatusDisplay {
    if (isEscalated) return 'Escalated';
    if (approvalStatus == 'pending' && isPendingApproval) return 'Overdue';
    switch (approvalStatus) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      case 'escalated':
        return 'Escalated';
      default:
        return 'Draft';
    }
  }

  /// Get days since approval request
  int get daysSinceRequest {
    if (approvalDate == null) return 0;
    return DateTime.now().difference(approvalDate!).inDays;
  }

  /// Get days until escalation deadline
  int? get daysUntilEscalation {
    if (approvalDate == null || approvalStatus != 'pending') return null;
    final deadline = approvalDate!.add(Duration(days: escalationDays));
    final days = deadline.difference(DateTime.now()).inDays;
    return days > 0 ? days : 0;
  }
}

/// Extensions for ProcurementItemModel budget calculations
extension ProcurementItemBudgetExtension on ProcurementItemModel {
  /// Calculate committed amount from linked POs
  double committedAmount(List<PurchaseOrderModel> allPos) {
    return allPos
        .where((po) =>
            po.vendorId != null &&
            po.status == PurchaseOrderStatus.issued &&
            po.approvalStatus == 'approved')
        .fold(0.0, (runningTotal, po) => runningTotal + po.amount);
  }

  /// Get remaining budget after committed and spent
  double remainingBudget(List<PurchaseOrderModel> allPos) {
    final committed = committedAmount(allPos);
    return budget - spent - committed;
  }

  /// Get variance percentage (positive = over budget)
  double variancePercent(List<PurchaseOrderModel> allPos) {
    if (budget == 0) return 0.0;
    final committed = committedAmount(allPos);
    return ((spent + committed - budget) / budget * 100);
  }

  /// Get budget status category
  String budgetStatus(List<PurchaseOrderModel> allPos) {
    final variance = variancePercent(allPos);
    if (variance > 10) return 'over';
    if (variance > -10) return 'within';
    return 'under';
  }

  /// Check if item is overdue based on requiredByDate
  bool get isOverdue {
    if (requiredByDate == null) return false;
    return DateTime.now().isAfter(requiredByDate!) &&
        status != ProcurementItemStatus.delivered;
  }

  /// Check if item is approaching deadline (within 7 days)
  bool get isApproachingDeadline {
    if (requiredByDate == null) return false;
    final daysUntil = requiredByDate!.difference(DateTime.now()).inDays;
    return daysUntil >= 0 && daysUntil <= 7 &&
        status != ProcurementItemStatus.delivered;
  }

  /// Get WBS element name if linked
  String get linkedWbsName => linkedWbsId ?? 'Not linked';

  /// Get milestone name if linked
  String get linkedMilestoneName => linkedMilestoneId ?? 'Not linked';
}

/// String extension for capitalizing first letter
extension StringCapitalize on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
