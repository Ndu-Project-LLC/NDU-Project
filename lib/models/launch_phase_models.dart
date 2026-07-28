class LaunchScopeItem {
  final String id;
  String deliverable;
  String acceptanceCriteria;
  String status;
  String acceptanceDate;
  String notes;

  LaunchScopeItem({
    String? id,
    this.deliverable = '',
    this.acceptanceCriteria = '',
    this.status = 'Pending',
    this.acceptanceDate = '',
    this.notes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchScopeItem copyWith({
    String? deliverable,
    String? acceptanceCriteria,
    String? status,
    String? acceptanceDate,
    String? notes,
  }) {
    return LaunchScopeItem(
      id: id,
      deliverable: deliverable ?? this.deliverable,
      acceptanceCriteria: acceptanceCriteria ?? this.acceptanceCriteria,
      status: status ?? this.status,
      acceptanceDate: acceptanceDate ?? this.acceptanceDate,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'deliverable': deliverable,
        'acceptanceCriteria': acceptanceCriteria,
        'status': status,
        'acceptanceDate': acceptanceDate,
        'notes': notes,
      };

  factory LaunchScopeItem.fromJson(Map<String, dynamic> json) {
    return LaunchScopeItem(
      id: json['id']?.toString(),
      deliverable: json['deliverable']?.toString() ?? '',
      acceptanceCriteria: json['acceptanceCriteria']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      acceptanceDate: json['acceptanceDate']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class LaunchMilestone {
  final String id;
  String title;
  String plannedDate;
  String actualDate;
  String status;
  String notes;

  LaunchMilestone({
    String? id,
    this.title = '',
    this.plannedDate = '',
    this.actualDate = '',
    this.status = 'Pending',
    this.notes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchMilestone copyWith({
    String? title,
    String? plannedDate,
    String? actualDate,
    String? status,
    String? notes,
  }) {
    return LaunchMilestone(
      id: id,
      title: title ?? this.title,
      plannedDate: plannedDate ?? this.plannedDate,
      actualDate: actualDate ?? this.actualDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'plannedDate': plannedDate,
        'actualDate': actualDate,
        'status': status,
        'notes': notes,
      };

  factory LaunchMilestone.fromJson(Map<String, dynamic> json) {
    return LaunchMilestone(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      plannedDate: json['plannedDate']?.toString() ?? '',
      actualDate: json['actualDate']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class LaunchFollowUpItem {
  final String id;
  String title;
  String details;
  String owner;
  String status;

  LaunchFollowUpItem({
    String? id,
    this.title = '',
    this.details = '',
    this.owner = '',
    this.status = 'Open',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchFollowUpItem copyWith({
    String? title,
    String? details,
    String? owner,
    String? status,
  }) {
    return LaunchFollowUpItem(
      id: id,
      title: title ?? this.title,
      details: details ?? this.details,
      owner: owner ?? this.owner,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'details': details,
        'owner': owner,
        'status': status,
      };

  factory LaunchFollowUpItem.fromJson(Map<String, dynamic> json) {
    return LaunchFollowUpItem(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Open',
    );
  }
}

class LaunchTeamMember {
  final String id;
  String name;
  String role;
  String contact;
  String startDate;
  String releaseStatus;

  LaunchTeamMember({
    String? id,
    this.name = '',
    this.role = '',
    this.contact = '',
    this.startDate = '',
    this.releaseStatus = 'Active',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchTeamMember copyWith({
    String? name,
    String? role,
    String? contact,
    String? startDate,
    String? releaseStatus,
  }) {
    return LaunchTeamMember(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      contact: contact ?? this.contact,
      startDate: startDate ?? this.startDate,
      releaseStatus: releaseStatus ?? this.releaseStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'contact': contact,
        'startDate': startDate,
        'releaseStatus': releaseStatus,
      };

  factory LaunchTeamMember.fromJson(Map<String, dynamic> json) {
    return LaunchTeamMember(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      contact: json['contact']?.toString() ?? '',
      startDate: json['startDate']?.toString() ?? '',
      releaseStatus: json['releaseStatus']?.toString() ?? 'Active',
    );
  }
}

class LaunchHandoverItem {
  final String id;
  String category;
  String item;
  String owner;
  String dueDate;
  String status;

  LaunchHandoverItem({
    String? id,
    this.category = 'Documentation',
    this.item = '',
    this.owner = '',
    this.dueDate = '',
    this.status = 'Pending',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  static const categories = [
    'Documentation',
    'System Access',
    'Monitoring',
    'Training',
    'Runbooks',
    'Other',
  ];

  LaunchHandoverItem copyWith({
    String? category,
    String? item,
    String? owner,
    String? dueDate,
    String? status,
  }) {
    return LaunchHandoverItem(
      id: id,
      category: category ?? this.category,
      item: item ?? this.item,
      owner: owner ?? this.owner,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'item': item,
        'owner': owner,
        'dueDate': dueDate,
        'status': status,
      };

  factory LaunchHandoverItem.fromJson(Map<String, dynamic> json) {
    return LaunchHandoverItem(
      id: json['id']?.toString(),
      category: json['category']?.toString() ?? 'Documentation',
      item: json['item']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      dueDate: json['dueDate']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
    );
  }
}

class LaunchKnowledgeTransfer {
  final String id;
  String topic;
  String fromPerson;
  String toPerson;
  String method;
  String status;
  String artifacts;

  LaunchKnowledgeTransfer({
    String? id,
    this.topic = '',
    this.fromPerson = '',
    this.toPerson = '',
    this.method = '',
    this.status = 'Pending',
    this.artifacts = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchKnowledgeTransfer copyWith({
    String? topic,
    String? fromPerson,
    String? toPerson,
    String? method,
    String? status,
    String? artifacts,
  }) {
    return LaunchKnowledgeTransfer(
      id: id,
      topic: topic ?? this.topic,
      fromPerson: fromPerson ?? this.fromPerson,
      toPerson: toPerson ?? this.toPerson,
      method: method ?? this.method,
      status: status ?? this.status,
      artifacts: artifacts ?? this.artifacts,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'fromPerson': fromPerson,
        'toPerson': toPerson,
        'method': method,
        'status': status,
        'artifacts': artifacts,
      };

  factory LaunchKnowledgeTransfer.fromJson(Map<String, dynamic> json) {
    return LaunchKnowledgeTransfer(
      id: json['id']?.toString(),
      topic: json['topic']?.toString() ?? '',
      fromPerson: json['fromPerson']?.toString() ?? '',
      toPerson: json['toPerson']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      artifacts: json['artifacts']?.toString() ?? '',
    );
  }
}

class LaunchApproval {
  final String id;
  String stakeholder;
  String role;
  String status;
  String date;
  String notes;

  LaunchApproval({
    String? id,
    this.stakeholder = '',
    this.role = '',
    this.status = 'Pending',
    this.date = '',
    this.notes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchApproval copyWith({
    String? stakeholder,
    String? role,
    String? status,
    String? date,
    String? notes,
  }) {
    return LaunchApproval(
      id: id,
      stakeholder: stakeholder ?? this.stakeholder,
      role: role ?? this.role,
      status: status ?? this.status,
      date: date ?? this.date,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'stakeholder': stakeholder,
        'role': role,
        'status': status,
        'date': date,
        'notes': notes,
      };

  factory LaunchApproval.fromJson(Map<String, dynamic> json) {
    return LaunchApproval(
      id: json['id']?.toString(),
      stakeholder: json['stakeholder']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      date: json['date']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class LaunchContractItem {
  final String id;
  String contractName;
  String vendor;
  String contractRef;
  String value;
  String closeOutStatus;
  String notes;

  LaunchContractItem({
    String? id,
    this.contractName = '',
    this.vendor = '',
    this.contractRef = '',
    this.value = '',
    this.closeOutStatus = 'Open',
    this.notes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  static const closeOutStatuses = [
    'Open',
    'In Progress',
    'Closed',
    'Disputed',
  ];

  LaunchContractItem copyWith({
    String? contractName,
    String? vendor,
    String? contractRef,
    String? value,
    String? closeOutStatus,
    String? notes,
  }) {
    return LaunchContractItem(
      id: id,
      contractName: contractName ?? this.contractName,
      vendor: vendor ?? this.vendor,
      contractRef: contractRef ?? this.contractRef,
      value: value ?? this.value,
      closeOutStatus: closeOutStatus ?? this.closeOutStatus,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'contractName': contractName,
        'vendor': vendor,
        'contractRef': contractRef,
        'value': value,
        'closeOutStatus': closeOutStatus,
        'notes': notes,
      };

  factory LaunchContractItem.fromJson(Map<String, dynamic> json) {
    return LaunchContractItem(
      id: json['id']?.toString(),
      contractName: json['contractName']?.toString() ?? '',
      vendor: json['vendor']?.toString() ?? '',
      contractRef: json['contractRef']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      closeOutStatus: json['closeOutStatus']?.toString() ?? 'Open',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class LaunchCloseOutStep {
  final String id;
  String step;
  String contractRef;
  String status;
  String notes;

  LaunchCloseOutStep({
    String? id,
    this.step = '',
    this.contractRef = '',
    this.status = 'Pending',
    this.notes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchCloseOutStep copyWith({
    String? step,
    String? contractRef,
    String? status,
    String? notes,
  }) {
    return LaunchCloseOutStep(
      id: id,
      step: step ?? this.step,
      contractRef: contractRef ?? this.contractRef,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'step': step,
        'contractRef': contractRef,
        'status': status,
        'notes': notes,
      };

  factory LaunchCloseOutStep.fromJson(Map<String, dynamic> json) {
    return LaunchCloseOutStep(
      id: json['id']?.toString(),
      step: json['step']?.toString() ?? '',
      contractRef: json['contractRef']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class LaunchVendorItem {
  final String id;
  String vendorName;
  String contractRef;
  String accountStatus;
  String outstandingItems;
  String performanceRating;
  String notes;

  LaunchVendorItem({
    String? id,
    this.vendorName = '',
    this.contractRef = '',
    this.accountStatus = 'Active',
    this.outstandingItems = '',
    this.performanceRating = '',
    this.notes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchVendorItem copyWith({
    String? vendorName,
    String? contractRef,
    String? accountStatus,
    String? outstandingItems,
    String? performanceRating,
    String? notes,
  }) {
    return LaunchVendorItem(
      id: id,
      vendorName: vendorName ?? this.vendorName,
      contractRef: contractRef ?? this.contractRef,
      accountStatus: accountStatus ?? this.accountStatus,
      outstandingItems: outstandingItems ?? this.outstandingItems,
      performanceRating: performanceRating ?? this.performanceRating,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'vendorName': vendorName,
        'contractRef': contractRef,
        'accountStatus': accountStatus,
        'outstandingItems': outstandingItems,
        'performanceRating': performanceRating,
        'notes': notes,
      };

  factory LaunchVendorItem.fromJson(Map<String, dynamic> json) {
    return LaunchVendorItem(
      id: json['id']?.toString(),
      vendorName: json['vendorName']?.toString() ?? '',
      contractRef: json['contractRef']?.toString() ?? '',
      accountStatus: json['accountStatus']?.toString() ?? 'Active',
      outstandingItems: json['outstandingItems']?.toString() ?? '',
      performanceRating: json['performanceRating']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class LaunchAccessItem {
  final String id;
  String system;
  String vendor;
  String accessLevel;
  String revokedDate;
  String confirmedBy;
  String status;

  LaunchAccessItem({
    String? id,
    this.system = '',
    this.vendor = '',
    this.accessLevel = '',
    this.revokedDate = '',
    this.confirmedBy = '',
    this.status = 'Pending',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchAccessItem copyWith({
    String? system,
    String? vendor,
    String? accessLevel,
    String? revokedDate,
    String? confirmedBy,
    String? status,
  }) {
    return LaunchAccessItem(
      id: id,
      system: system ?? this.system,
      vendor: vendor ?? this.vendor,
      accessLevel: accessLevel ?? this.accessLevel,
      revokedDate: revokedDate ?? this.revokedDate,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'system': system,
        'vendor': vendor,
        'accessLevel': accessLevel,
        'revokedDate': revokedDate,
        'confirmedBy': confirmedBy,
        'status': status,
      };

  factory LaunchAccessItem.fromJson(Map<String, dynamic> json) {
    return LaunchAccessItem(
      id: json['id']?.toString(),
      system: json['system']?.toString() ?? '',
      vendor: json['vendor']?.toString() ?? '',
      accessLevel: json['accessLevel']?.toString() ?? '',
      revokedDate: json['revokedDate']?.toString() ?? '',
      confirmedBy: json['confirmedBy']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
    );
  }
}

class LaunchWarrantyItem {
  final String id;
  String item;
  String vendor;
  String warrantyType;
  String startDate;
  String expiryDate;
  String terms;
  String status;

  LaunchWarrantyItem({
    String? id,
    this.item = '',
    this.vendor = '',
    this.warrantyType = '',
    this.startDate = '',
    this.expiryDate = '',
    this.terms = '',
    this.status = 'Active',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchWarrantyItem copyWith({
    String? item,
    String? vendor,
    String? warrantyType,
    String? startDate,
    String? expiryDate,
    String? terms,
    String? status,
  }) {
    return LaunchWarrantyItem(
      id: id,
      item: item ?? this.item,
      vendor: vendor ?? this.vendor,
      warrantyType: warrantyType ?? this.warrantyType,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      terms: terms ?? this.terms,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item': item,
        'vendor': vendor,
        'warrantyType': warrantyType,
        'startDate': startDate,
        'expiryDate': expiryDate,
        'terms': terms,
        'status': status,
      };

  factory LaunchWarrantyItem.fromJson(Map<String, dynamic> json) {
    return LaunchWarrantyItem(
      id: json['id']?.toString(),
      item: json['item']?.toString() ?? '',
      vendor: json['vendor']?.toString() ?? '',
      warrantyType: json['warrantyType']?.toString() ?? '',
      startDate: json['startDate']?.toString() ?? '',
      expiryDate: json['expiryDate']?.toString() ?? '',
      terms: json['terms']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
    );
  }
}

class LaunchGapItem {
  final String id;
  String planned;
  String actual;
  String gapDescription;
  String gapStatus;
  String notes;

  LaunchGapItem({
    String? id,
    this.planned = '',
    this.actual = '',
    this.gapDescription = '',
    this.gapStatus = 'Met',
    this.notes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  static const gapStatuses = ['Met', 'Partial', 'Missed', 'Exceeded'];

  LaunchGapItem copyWith({
    String? planned,
    String? actual,
    String? gapDescription,
    String? gapStatus,
    String? notes,
  }) {
    return LaunchGapItem(
      id: id,
      planned: planned ?? this.planned,
      actual: actual ?? this.actual,
      gapDescription: gapDescription ?? this.gapDescription,
      gapStatus: gapStatus ?? this.gapStatus,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'planned': planned,
        'actual': actual,
        'gapDescription': gapDescription,
        'gapStatus': gapStatus,
        'notes': notes,
      };

  factory LaunchGapItem.fromJson(Map<String, dynamic> json) {
    return LaunchGapItem(
      id: json['id']?.toString(),
      planned: json['planned']?.toString() ?? '',
      actual: json['actual']?.toString() ?? '',
      gapDescription: json['gapDescription']?.toString() ?? '',
      gapStatus: json['gapStatus']?.toString() ?? 'Met',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class LaunchMilestoneVariance {
  final String id;
  String milestone;
  String plannedDate;
  String actualDate;
  String varianceDays;
  String status;

  LaunchMilestoneVariance({
    String? id,
    this.milestone = '',
    this.plannedDate = '',
    this.actualDate = '',
    this.varianceDays = '',
    this.status = 'On Track',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchMilestoneVariance copyWith({
    String? milestone,
    String? plannedDate,
    String? actualDate,
    String? varianceDays,
    String? status,
  }) {
    return LaunchMilestoneVariance(
      id: id,
      milestone: milestone ?? this.milestone,
      plannedDate: plannedDate ?? this.plannedDate,
      actualDate: actualDate ?? this.actualDate,
      varianceDays: varianceDays ?? this.varianceDays,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'milestone': milestone,
        'plannedDate': plannedDate,
        'actualDate': actualDate,
        'varianceDays': varianceDays,
        'status': status,
      };

  factory LaunchMilestoneVariance.fromJson(Map<String, dynamic> json) {
    return LaunchMilestoneVariance(
      id: json['id']?.toString(),
      milestone: json['milestone']?.toString() ?? '',
      plannedDate: json['plannedDate']?.toString() ?? '',
      actualDate: json['actualDate']?.toString() ?? '',
      varianceDays: json['varianceDays']?.toString() ?? '',
      status: json['status']?.toString() ?? 'On Track',
    );
  }
}

class LaunchBudgetVariance {
  final String id;
  String category;
  String plannedAmount;
  String actualAmount;
  String variance;
  String variancePercent;

  LaunchBudgetVariance({
    String? id,
    this.category = '',
    this.plannedAmount = '',
    this.actualAmount = '',
    this.variance = '',
    this.variancePercent = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchBudgetVariance copyWith({
    String? category,
    String? plannedAmount,
    String? actualAmount,
    String? variance,
    String? variancePercent,
  }) {
    return LaunchBudgetVariance(
      id: id,
      category: category ?? this.category,
      plannedAmount: plannedAmount ?? this.plannedAmount,
      actualAmount: actualAmount ?? this.actualAmount,
      variance: variance ?? this.variance,
      variancePercent: variancePercent ?? this.variancePercent,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'plannedAmount': plannedAmount,
        'actualAmount': actualAmount,
        'variance': variance,
        'variancePercent': variancePercent,
      };

  factory LaunchBudgetVariance.fromJson(Map<String, dynamic> json) {
    return LaunchBudgetVariance(
      id: json['id']?.toString(),
      category: json['category']?.toString() ?? '',
      plannedAmount: json['plannedAmount']?.toString() ?? '',
      actualAmount: json['actualAmount']?.toString() ?? '',
      variance: json['variance']?.toString() ?? '',
      variancePercent: json['variancePercent']?.toString() ?? '',
    );
  }
}

class LaunchCloseOutCheckItem {
  final String id;
  String category;
  String item;
  String status;
  String notes;

  LaunchCloseOutCheckItem({
    String? id,
    this.category = 'Deliverables',
    this.item = '',
    this.status = 'Pending',
    this.notes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  static const categories = [
    'Deliverables',
    'Contracts',
    'Vendors',
    'Team',
    'Documentation',
    'Finance',
  ];

  LaunchCloseOutCheckItem copyWith({
    String? category,
    String? item,
    String? status,
    String? notes,
  }) {
    return LaunchCloseOutCheckItem(
      id: id,
      category: category ?? this.category,
      item: item ?? this.item,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'item': item,
        'status': status,
        'notes': notes,
      };

  factory LaunchCloseOutCheckItem.fromJson(Map<String, dynamic> json) {
    return LaunchCloseOutCheckItem(
      id: json['id']?.toString(),
      category: json['category']?.toString() ?? 'Deliverables',
      item: json['item']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class LaunchArchiveItem {
  final String id;
  String repository;
  String documentType;
  String retentionPeriod;
  String accessChange;
  String status;

  LaunchArchiveItem({
    String? id,
    this.repository = '',
    this.documentType = '',
    this.retentionPeriod = '',
    this.accessChange = '',
    this.status = 'Pending',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchArchiveItem copyWith({
    String? repository,
    String? documentType,
    String? retentionPeriod,
    String? accessChange,
    String? status,
  }) {
    return LaunchArchiveItem(
      id: id,
      repository: repository ?? this.repository,
      documentType: documentType ?? this.documentType,
      retentionPeriod: retentionPeriod ?? this.retentionPeriod,
      accessChange: accessChange ?? this.accessChange,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'repository': repository,
        'documentType': documentType,
        'retentionPeriod': retentionPeriod,
        'accessChange': accessChange,
        'status': status,
      };

  factory LaunchArchiveItem.fromJson(Map<String, dynamic> json) {
    return LaunchArchiveItem(
      id: json['id']?.toString(),
      repository: json['repository']?.toString() ?? '',
      documentType: json['documentType']?.toString() ?? '',
      retentionPeriod: json['retentionPeriod']?.toString() ?? '',
      accessChange: json['accessChange']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
    );
  }
}

class LaunchCommunicationItem {
  final String id;
  String audience;
  String message;
  String channel;
  String sendDate;
  String status;

  LaunchCommunicationItem({
    String? id,
    this.audience = '',
    this.message = '',
    this.channel = '',
    this.sendDate = '',
    this.status = 'Planned',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchCommunicationItem copyWith({
    String? audience,
    String? message,
    String? channel,
    String? sendDate,
    String? status,
  }) {
    return LaunchCommunicationItem(
      id: id,
      audience: audience ?? this.audience,
      message: message ?? this.message,
      channel: channel ?? this.channel,
      sendDate: sendDate ?? this.sendDate,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'audience': audience,
        'message': message,
        'channel': channel,
        'sendDate': sendDate,
        'status': status,
      };

  factory LaunchCommunicationItem.fromJson(Map<String, dynamic> json) {
    return LaunchCommunicationItem(
      id: json['id']?.toString(),
      audience: json['audience']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      channel: json['channel']?.toString() ?? '',
      sendDate: json['sendDate']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Planned',
    );
  }
}

class LaunchOpsCostItem {
  final String id;
  String category;
  String monthlyCost;
  String annualCost;
  String notes;

  LaunchOpsCostItem({
    String? id,
    this.category = '',
    this.monthlyCost = '',
    this.annualCost = '',
    this.notes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchOpsCostItem copyWith({
    String? category,
    String? monthlyCost,
    String? annualCost,
    String? notes,
  }) {
    return LaunchOpsCostItem(
      id: id,
      category: category ?? this.category,
      monthlyCost: monthlyCost ?? this.monthlyCost,
      annualCost: annualCost ?? this.annualCost,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'monthlyCost': monthlyCost,
        'annualCost': annualCost,
        'notes': notes,
      };

  factory LaunchOpsCostItem.fromJson(Map<String, dynamic> json) {
    return LaunchOpsCostItem(
      id: json['id']?.toString(),
      category: json['category']?.toString() ?? '',
      monthlyCost: json['monthlyCost']?.toString() ?? '',
      annualCost: json['annualCost']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class LaunchFinancialMetric {
  final String id;
  String label;
  String value;
  String notes;

  LaunchFinancialMetric({
    String? id,
    this.label = '',
    this.value = '',
    this.notes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchFinancialMetric copyWith({
    String? label,
    String? value,
    String? notes,
  }) {
    return LaunchFinancialMetric(
      id: id,
      label: label ?? this.label,
      value: value ?? this.value,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'value': value,
        'notes': notes,
      };

  factory LaunchFinancialMetric.fromJson(Map<String, dynamic> json) {
    return LaunchFinancialMetric(
      id: json['id']?.toString(),
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class LaunchRootCauseItem {
  final String id;
  String gap;
  String rootCause;
  String impact;
  String correctiveAction;
  String status;

  LaunchRootCauseItem({
    String? id,
    this.gap = '',
    this.rootCause = '',
    this.impact = '',
    this.correctiveAction = '',
    this.status = 'Open',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchRootCauseItem copyWith({
    String? gap,
    String? rootCause,
    String? impact,
    String? correctiveAction,
    String? status,
  }) {
    return LaunchRootCauseItem(
      id: id,
      gap: gap ?? this.gap,
      rootCause: rootCause ?? this.rootCause,
      impact: impact ?? this.impact,
      correctiveAction: correctiveAction ?? this.correctiveAction,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'gap': gap,
        'rootCause': rootCause,
        'impact': impact,
        'correctiveAction': correctiveAction,
        'status': status,
      };

  factory LaunchRootCauseItem.fromJson(Map<String, dynamic> json) {
    return LaunchRootCauseItem(
      id: json['id']?.toString(),
      gap: json['gap']?.toString() ?? '',
      rootCause: json['rootCause']?.toString() ?? '',
      impact: json['impact']?.toString() ?? '',
      correctiveAction: json['correctiveAction']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Open',
    );
  }
}

class LaunchHighlightItem {
  final String id;
  String title;
  String details;
  String category;

  LaunchHighlightItem({
    String? id,
    this.title = '',
    this.details = '',
    this.category = 'Win',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  LaunchHighlightItem copyWith({
    String? title,
    String? details,
    String? category,
  }) {
    return LaunchHighlightItem(
      id: id,
      title: title ?? this.title,
      details: details ?? this.details,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'details': details,
        'category': category,
      };

  factory LaunchHighlightItem.fromJson(Map<String, dynamic> json) {
    return LaunchHighlightItem(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Win',
    );
  }
}

class LaunchClosureNotes {
  String notes;

  LaunchClosureNotes({this.notes = ''});

  Map<String, dynamic> toJson() => {'notes': notes};

  factory LaunchClosureNotes.fromJson(Map<String, dynamic> json) {
    return LaunchClosureNotes(notes: json['notes']?.toString() ?? '');
  }
}
