/// Model for a design component in Detailed Design / Design Specifications page.
///
/// Aligns with IEEE 1016-2009 (Software Design Description), ISO/IEC/IEEE 12207,
/// and industry best practices for waterfall, hybrid, and agile methodologies.
class DesignComponent {
  final String id;

  /// Auto-assigned specification identifier, e.g. "DS-001"
  String specId;

  /// Human-readable name of the design element
  String componentName;

  /// Specification type per IEEE 1016 decomposition:
  /// Architecture, Interface, Data, Component, Security, NFR, Infrastructure, UI/UX
  String specificationType;

  /// Category alias (kept for backward compatibility, maps to specificationType)
  String category;

  /// Detailed specification text (supports "." bullet format)
  String specificationDetails;

  /// Integration point or upstream/downstream system connection
  String integrationPoint;

  /// MoSCoW priority: Must Have, Should Have, Could Have, Won't Have
  String priority;

  /// Methodology-specific phase label:
  /// Waterfall: "Baseline", "Detailed Design", "Build Ready"
  /// Hybrid: "Architecture Baseline", "Iteration 1..N", "Stabilization"
  /// Agile: "Sprint 1..N", "Backlog", "Enabler"
  String methodologyPhase;

  /// Owner role or team responsible (e.g., "Architecture", "Engineering", "Security")
  String owner;

  /// Traceability link to originating requirement ID (e.g., "REQ-001")
  String traceability;

  /// Lifecycle status: Draft, In Review, Reviewed, Approved, Baseline, Superseded
  String status;

  /// Free-form design notes / rationale (prose, no bullets)
  String designNotes;

  DesignComponent({
    String? id,
    this.specId = '',
    this.componentName = '',
    this.specificationType = 'Component',
    this.category = 'Backend',
    this.specificationDetails = '',
    this.integrationPoint = '',
    this.priority = 'Should Have',
    this.methodologyPhase = 'Baseline',
    this.owner = '',
    this.traceability = '',
    this.status = 'Draft',
    this.designNotes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  DesignComponent copyWith({
    String? specId,
    String? componentName,
    String? specificationType,
    String? category,
    String? specificationDetails,
    String? integrationPoint,
    String? priority,
    String? methodologyPhase,
    String? owner,
    String? traceability,
    String? status,
    String? designNotes,
  }) {
    return DesignComponent(
      id: id,
      specId: specId ?? this.specId,
      componentName: componentName ?? this.componentName,
      specificationType: specificationType ?? this.specificationType,
      category: category ?? this.category,
      specificationDetails: specificationDetails ?? this.specificationDetails,
      integrationPoint: integrationPoint ?? this.integrationPoint,
      priority: priority ?? this.priority,
      methodologyPhase: methodologyPhase ?? this.methodologyPhase,
      owner: owner ?? this.owner,
      traceability: traceability ?? this.traceability,
      status: status ?? this.status,
      designNotes: designNotes ?? this.designNotes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'specId': specId,
        'componentName': componentName,
        'specificationType': specificationType,
        'category': category,
        'specificationDetails': specificationDetails,
        'integrationPoint': integrationPoint,
        'priority': priority,
        'methodologyPhase': methodologyPhase,
        'owner': owner,
        'traceability': traceability,
        'status': status,
        'designNotes': designNotes,
      };

  factory DesignComponent.fromJson(Map<String, dynamic> json) {
    return DesignComponent(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      specId: json['specId']?.toString() ?? '',
      componentName: json['componentName']?.toString() ?? '',
      specificationType:
          json['specificationType']?.toString() ?? json['category']?.toString() ?? 'Component',
      category: json['category']?.toString() ?? 'Backend',
      specificationDetails: json['specificationDetails']?.toString() ?? '',
      integrationPoint: json['integrationPoint']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'Should Have',
      methodologyPhase: json['methodologyPhase']?.toString() ?? 'Baseline',
      owner: json['owner']?.toString() ?? '',
      traceability: json['traceability']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Draft',
      designNotes: json['designNotes']?.toString() ?? '',
    );
  }

  // ── Specification type constants ──
  static const List<String> specificationTypes = [
    'Architecture',
    'Interface',
    'Data',
    'Component',
    'Security',
    'NFR',
    'Infrastructure',
    'UI/UX',
  ];

  // ── MoSCoW priority constants ──
  static const List<String> priorities = [
    'Must Have',
    'Should Have',
    'Could Have',
    'Won\'t Have',
  ];

  // ── Lifecycle status constants ──
  static const List<String> statuses = [
    'Draft',
    'In Review',
    'Reviewed',
    'Approved',
    'Baseline',
    'Superseded',
  ];

  // ── Methodology phase presets ──
  static const List<String> waterfallPhases = [
    'Baseline',
    'Detailed Design',
    'Build Ready',
    'Construction',
  ];

  static const List<String> hybridPhases = [
    'Architecture Baseline',
    'Iteration 1',
    'Iteration 2',
    'Iteration 3',
    'Stabilization',
  ];

  static const List<String> agilePhases = [
    'Backlog',
    'Sprint 1',
    'Sprint 2',
    'Sprint 3',
    'Enabler',
    'Hardening',
  ];

  // ── Owner roles ──
  static const List<String> ownerRoles = [
    'Architecture',
    'Engineering',
    'Security',
    'Data',
    'Infrastructure',
    'UI/UX',
    'Product',
    'QA',
    'DevOps',
  ];
}
