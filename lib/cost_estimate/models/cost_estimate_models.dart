library;

/// NDU Project — Cost Estimate type system (Dart equivalent)
///
/// Mirrors the TypeScript types in the Next.js Cost Estimate module.
/// Every cost category, BOE field, and estimate class from the
/// Cost Estimating Guidance doc is represented as a first-class type.

enum EstimateClass {
  class5,
  class4,
  class3,
  class2,
  class1;

  String get label => switch (this) {
        EstimateClass.class5 => 'Class 5',
        EstimateClass.class4 => 'Class 4',
        EstimateClass.class3 => 'Class 3',
        EstimateClass.class2 => 'Class 2',
        EstimateClass.class1 => 'Class 1',
      };

  String get name => switch (this) {
        EstimateClass.class5 => 'Conceptual',
        EstimateClass.class4 => 'Feasibility',
        EstimateClass.class3 => 'Budget Authorization',
        EstimateClass.class2 => 'Control Estimate',
        EstimateClass.class1 => 'Definitive Estimate',
      };

  String get desc => switch (this) {
        EstimateClass.class5 => 'Order-of-magnitude, early idea stage',
        EstimateClass.class4 => 'Study / feasibility, limited definition',
        EstimateClass.class3 => 'Budget authorization, scope defined',
        EstimateClass.class2 => 'Control estimate, detailed scope',
        EstimateClass.class1 => 'Definitive estimate, full definition',
      };

  ({int low, int high}) get accuracy => switch (this) {
        EstimateClass.class5 => (low: -50, high: 100),
        EstimateClass.class4 => (low: -30, high: 50),
        EstimateClass.class3 => (low: -20, high: 30),
        EstimateClass.class2 => (low: -15, high: 20),
        EstimateClass.class1 => (low: -5, high: 10),
      };
}

enum DeliveryModel { waterfall, agile, hybrid }

extension DeliveryModelMeta on DeliveryModel {
  String get label => switch (this) {
        DeliveryModel.waterfall => 'Waterfall',
        DeliveryModel.agile => 'Agile',
        DeliveryModel.hybrid => 'Hybrid',
      };

  String get changeProcess => switch (this) {
        DeliveryModel.waterfall => 'Management of Change (MoC)',
        DeliveryModel.agile => 'Information note (no formal MoC)',
        DeliveryModel.hybrid =>
          'MoC for waterfall phases, info note for agile phases',
      };
}

enum EstimateStatus {
  draft,
  inReview,
  approved,
  baselined,
  variance,
  rebaselined;

  String get label => switch (this) {
        EstimateStatus.draft => 'Draft',
        EstimateStatus.inReview => 'In Review',
        EstimateStatus.approved => 'Approved',
        EstimateStatus.baselined => 'Baselined',
        EstimateStatus.variance => 'Variance',
        EstimateStatus.rebaselined => 'Re-baselined',
      };
}

enum RBACRole { viewer, editor, approver, admin }

extension RBACRoleMeta on RBACRole {
  String get label => switch (this) {
        RBACRole.viewer => 'Viewer',
        RBACRole.editor => 'Editor',
        RBACRole.approver => 'Approver',
        RBACRole.admin => 'Admin',
      };

  String get desc => switch (this) {
        RBACRole.viewer => 'Read-only access to the estimate',
        RBACRole.editor => 'Add/edit lines, BOE, run AI assistant',
        RBACRole.approver =>
          'Invite stakeholders, submit for review, approve baseline, re-baseline',
        RBACRole.admin =>
          'Full control including granting access to others',
      };
}

enum CostCategory {
  labor,
  materials,
  software,
  procurement,
  travelTraining,
  construction,
  projectTeam,
  overheads,
  ga,
  facilities,
  insuranceCompliance,
  ssher,
  quality,
  riskAllowance,
  contingency,
  mgmtReserve,
  escalation,
  taxes,
  financing,
  startup,
  warranty,
  decommissioning;

  String get label => switch (this) {
        CostCategory.labor => 'Labor',
        CostCategory.materials => 'Materials & Equipment',
        CostCategory.software => 'Software & Technology',
        CostCategory.procurement => 'Procurement & Vendor',
        CostCategory.travelTraining => 'Travel & Training',
        CostCategory.construction => 'Construction & Field',
        CostCategory.projectTeam => 'Project Team (PMO)',
        CostCategory.overheads => 'Organizational Overheads',
        CostCategory.ga => 'General & Administrative',
        CostCategory.facilities => 'Facilities & Infrastructure',
        CostCategory.insuranceCompliance => 'Insurance & Compliance',
        CostCategory.ssher =>
          'SSHER (Safety, Health, Env, Radiation)',
        CostCategory.quality => 'Quality Management',
        CostCategory.riskAllowance => 'Risk Allowances',
        CostCategory.contingency => 'Contingency',
        CostCategory.mgmtReserve => 'Management Reserve',
        CostCategory.escalation => 'Escalation & Inflation',
        CostCategory.taxes => 'Taxes & Duties',
        CostCategory.financing => 'Financing Costs',
        CostCategory.startup => 'Startup & Transition',
        CostCategory.warranty => 'Warranty & Closeout',
        CostCategory.decommissioning => 'Decommissioning & Disposal',
      };

  String get group => switch (this) {
        CostCategory.labor ||
        CostCategory.materials ||
        CostCategory.software ||
        CostCategory.procurement ||
        CostCategory.travelTraining ||
        CostCategory.construction =>
          'DIRECT',
        CostCategory.projectTeam ||
        CostCategory.overheads ||
        CostCategory.ga ||
        CostCategory.facilities ||
        CostCategory.insuranceCompliance =>
          'INDIRECT',
        CostCategory.ssher || CostCategory.quality => 'SHER_QUALITY',
        _ => 'ADDITIONAL',
      };

  String get icon => switch (this) {
        CostCategory.labor => 'engineering',
        CostCategory.materials => 'inventory_2',
        CostCategory.software => 'cloud',
        CostCategory.procurement => 'handshake',
        CostCategory.travelTraining => 'flight',
        CostCategory.construction => 'construction',
        CostCategory.projectTeam => 'groups',
        CostCategory.overheads => 'business',
        CostCategory.ga => 'account_balance',
        CostCategory.facilities => 'domain',
        CostCategory.insuranceCompliance => 'gavel',
        CostCategory.ssher => 'health_and_safety',
        CostCategory.quality => 'verified',
        CostCategory.riskAllowance => 'warning',
        CostCategory.contingency => 'shield',
        CostCategory.mgmtReserve => 'savings',
        CostCategory.escalation => 'trending_up',
        CostCategory.taxes => 'receipt_long',
        CostCategory.financing => 'credit_card',
        CostCategory.startup => 'rocket_launch',
        CostCategory.warranty => 'fact_check',
        CostCategory.decommissioning => 'delete',
      };
}

enum CostSourceType {
  historical,
  vendorQuote,
  industryBenchmark,
  marketIntel,
  expertJudgment,
  kazAI;

  String get label => switch (this) {
        CostSourceType.historical => 'Historical Project',
        CostSourceType.vendorQuote => 'Vendor Quotation',
        CostSourceType.industryBenchmark => 'Industry Benchmark',
        CostSourceType.marketIntel => 'Market Intelligence',
        CostSourceType.expertJudgment => 'Expert Judgment',
        CostSourceType.kazAI => 'KAZ AI (AI-generated)',
      };

  bool get isAI => this == CostSourceType.kazAI;

  String? get disclaimer => isAI
      ? '⚠️ AI-generated content — validate with a qualified Subject Matter Expert before baseline.'
      : null;
}

enum EstimationMethod {
  analogous,
  parametric,
  bottomUp,
  threePoint,
  expert,
  vendorBid;

  String get label => switch (this) {
        EstimationMethod.analogous => 'Analogous',
        EstimationMethod.parametric => 'Parametric',
        EstimationMethod.bottomUp => 'Bottom-Up',
        EstimationMethod.threePoint => 'Three-Point',
        EstimationMethod.expert => 'Expert Judgment',
        EstimationMethod.vendorBid => 'Vendor Bid Analysis',
      };

  String get accuracy => switch (this) {
        EstimationMethod.analogous => '±30–50%',
        EstimationMethod.parametric => '±15–30%',
        EstimationMethod.bottomUp => '±5–15%',
        _ => 'Varies',
      };

  String get desc => switch (this) {
        EstimationMethod.analogous => 'Uses historical projects',
        EstimationMethod.parametric =>
          'Uses measurable relationships (cost per unit)',
        EstimationMethod.bottomUp =>
          'Estimate each work package, aggregate',
        EstimationMethod.threePoint =>
          'Optimistic / Most likely / Pessimistic (O+4M+P)/6',
        EstimationMethod.expert =>
          'Leverages experienced personnel and SMEs',
        EstimationMethod.vendorBid =>
          'Uses supplier quotations and proposals',
      };
}

enum Confidence { low, med, high }

enum VarianceType { add, remove, change }

/// A single cost line in the estimate.
class CostLine {
  final String id;
  final CostCategory category;
  final String subCategory;
  final String description;
  final String? wbsRef;
  final double? quantity;
  final String? unit;
  final double? rate;
  final double total;
  final bool inSchedule;
  final CostSourceType basisSource;
  final String? basisReference;
  final bool aiGenerated;
  final Confidence? confidence;
  final VarianceType? varianceType;
  final double? varianceDelta;
  final double? varianceBaselineTotal;

  const CostLine({
    required this.id,
    required this.category,
    required this.subCategory,
    required this.description,
    this.wbsRef,
    this.quantity,
    this.unit,
    this.rate,
    required this.total,
    required this.inSchedule,
    required this.basisSource,
    this.basisReference,
    required this.aiGenerated,
    this.confidence,
    this.varianceType,
    this.varianceDelta,
    this.varianceBaselineTotal,
  });

  CostLine copyWith({
    String? id,
    CostCategory? category,
    String? subCategory,
    String? description,
    String? wbsRef,
    double? quantity,
    String? unit,
    double? rate,
    double? total,
    bool? inSchedule,
    CostSourceType? basisSource,
    String? basisReference,
    bool? aiGenerated,
    Confidence? confidence,
    VarianceType? varianceType,
    double? varianceDelta,
    double? varianceBaselineTotal,
  }) {
    return CostLine(
      id: id ?? this.id,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      description: description ?? this.description,
      wbsRef: wbsRef ?? this.wbsRef,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      rate: rate ?? this.rate,
      total: total ?? this.total,
      inSchedule: inSchedule ?? this.inSchedule,
      basisSource: basisSource ?? this.basisSource,
      basisReference: basisReference ?? this.basisReference,
      aiGenerated: aiGenerated ?? this.aiGenerated,
      confidence: confidence ?? this.confidence,
      varianceType: varianceType ?? this.varianceType,
      varianceDelta: varianceDelta ?? this.varianceDelta,
      varianceBaselineTotal:
          varianceBaselineTotal ?? this.varianceBaselineTotal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'subCategory': subCategory,
        'description': description,
        'wbsRef': wbsRef,
        'quantity': quantity,
        'unit': unit,
        'rate': rate,
        'total': total,
        'inSchedule': inSchedule,
        'basisSource': basisSource.name,
        'basisReference': basisReference,
        'aiGenerated': aiGenerated,
        'confidence': confidence?.name,
        'varianceType': varianceType?.name,
        'varianceDelta': varianceDelta,
        'varianceBaselineTotal': varianceBaselineTotal,
      };

  factory CostLine.fromJson(Map<String, dynamic> json) => CostLine(
        id: json['id'] as String,
        category: CostCategory.values
            .byName(json['category'] as String),
        subCategory: json['subCategory'] as String? ?? '',
        description: json['description'] as String,
        wbsRef: json['wbsRef'] as String?,
        quantity: (json['quantity'] as num?)?.toDouble(),
        unit: json['unit'] as String?,
        rate: (json['rate'] as num?)?.toDouble(),
        total: (json['total'] as num).toDouble(),
        inSchedule: json['inSchedule'] as bool? ?? true,
        basisSource: CostSourceType.values
            .byName(json['basisSource'] as String),
        basisReference: json['basisReference'] as String?,
        aiGenerated: json['aiGenerated'] as bool? ?? false,
        confidence: json['confidence'] != null
            ? Confidence.values.byName(json['confidence'] as String)
            : null,
        varianceType: json['varianceType'] != null
            ? VarianceType.values.byName(json['varianceType'] as String)
            : null,
        varianceDelta: (json['varianceDelta'] as num?)?.toDouble(),
        varianceBaselineTotal:
            (json['varianceBaselineTotal'] as num?)?.toDouble(),
      );
}

/// Basis of Estimate document.
class BasisOfEstimate {
  final String scopeBasis;
  final List<String> assumptions;
  final List<String> constraints;
  final List<String> exclusions;
  final List<BOEDataSource> dataSources;
  final List<EstimationMethod> methodology;
  final ({int low, int high}) accuracyRange;
  final String escalationAssumptions;

  const BasisOfEstimate({
    required this.scopeBasis,
    required this.assumptions,
    required this.constraints,
    required this.exclusions,
    required this.dataSources,
    required this.methodology,
    required this.accuracyRange,
    required this.escalationAssumptions,
  });

  BasisOfEstimate copyWith({
    String? scopeBasis,
    List<String>? assumptions,
    List<String>? constraints,
    List<String>? exclusions,
    List<BOEDataSource>? dataSources,
    List<EstimationMethod>? methodology,
    ({int low, int high})? accuracyRange,
    String? escalationAssumptions,
  }) {
    return BasisOfEstimate(
      scopeBasis: scopeBasis ?? this.scopeBasis,
      assumptions: assumptions ?? this.assumptions,
      constraints: constraints ?? this.constraints,
      exclusions: exclusions ?? this.exclusions,
      dataSources: dataSources ?? this.dataSources,
      methodology: methodology ?? this.methodology,
      accuracyRange: accuracyRange ?? this.accuracyRange,
      escalationAssumptions:
          escalationAssumptions ?? this.escalationAssumptions,
    );
  }
}

class BOEDataSource {
  final CostSourceType source;
  final String reference;
  final bool validated;

  const BOEDataSource({
    required this.source,
    required this.reference,
    required this.validated,
  });
}

/// Computed totals from cost lines.
class EstimateTotals {
  final double direct;
  final double indirect;
  final double sherQuality;
  final double riskAllowances;
  final double contingency;
  final double escalation;
  final double taxes;
  final double financing;
  final double startup;
  final double warranty;
  final double decommissioning;
  final double costBaseline;
  final double managementReserve;
  final double totalAuthorizedBudget;

  const EstimateTotals({
    required this.direct,
    required this.indirect,
    required this.sherQuality,
    required this.riskAllowances,
    required this.contingency,
    required this.escalation,
    required this.taxes,
    required this.financing,
    required this.startup,
    required this.warranty,
    required this.decommissioning,
    required this.costBaseline,
    required this.managementReserve,
    required this.totalAuthorizedBudget,
  });

  static EstimateTotals empty() => const EstimateTotals(
        direct: 0,
        indirect: 0,
        sherQuality: 0,
        riskAllowances: 0,
        contingency: 0,
        escalation: 0,
        taxes: 0,
        financing: 0,
        startup: 0,
        warranty: 0,
        decommissioning: 0,
        costBaseline: 0,
        managementReserve: 0,
        totalAuthorizedBudget: 0,
      );
}

/// Approver for the review flow.
class Approver {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool approved;
  final DateTime? approvedAt;

  const Approver({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.approved,
    this.approvedAt,
  });
}

/// Review & acceptance state.
class ReviewApproval {
  final List<Approver> requiredApprovers;
  final ReviewMeeting? meetingScheduled;
  final EmailDraft? emailDraft;
  final ({bool confirmed, String? by, DateTime? at}) acceptanceStep1;
  final ({bool confirmed, String? by, DateTime? at}) acceptanceStep2;

  const ReviewApproval({
    required this.requiredApprovers,
    this.meetingScheduled,
    this.emailDraft,
    required this.acceptanceStep1,
    required this.acceptanceStep2,
  });

  ReviewApproval copyWith({
    List<Approver>? requiredApprovers,
    ReviewMeeting? meetingScheduled,
    EmailDraft? emailDraft,
    ({bool confirmed, String? by, DateTime? at})? acceptanceStep1,
    ({bool confirmed, String? by, DateTime? at})? acceptanceStep2,
  }) {
    return ReviewApproval(
      requiredApprovers: requiredApprovers ?? this.requiredApprovers,
      meetingScheduled: meetingScheduled ?? this.meetingScheduled,
      emailDraft: emailDraft ?? this.emailDraft,
      acceptanceStep1: acceptanceStep1 ?? this.acceptanceStep1,
      acceptanceStep2: acceptanceStep2 ?? this.acceptanceStep2,
    );
  }
}

class ReviewMeeting {
  final DateTime date;
  final String title;
  final String calendarLink;
  final List<String> attendees;

  const ReviewMeeting({
    required this.date,
    required this.title,
    required this.calendarLink,
    required this.attendees,
  });
}

class EmailDraft {
  final List<String> to;
  final String subject;
  final String body;
  final DateTime? sentAt;

  const EmailDraft({
    required this.to,
    required this.subject,
    required this.body,
    this.sentAt,
  });
}

/// Baseline snapshot — frozen when the estimate is baselined.
class Baseline {
  final int version;
  final DateTime lockedAt;
  final String lockedBy;
  final BaselineSnapshot snapshot;
  final int rebaselineRemaining;
  final List<RebaselineRecord> rebaselineHistory;

  const Baseline({
    required this.version,
    required this.lockedAt,
    required this.lockedBy,
    required this.snapshot,
    required this.rebaselineRemaining,
    required this.rebaselineHistory,
  });
}

class BaselineSnapshot {
  final List<CostLine> lines;
  final EstimateTotals totals;
  final BasisOfEstimate boe;
  final EstimateClass className;
  final DeliveryModel deliveryModel;

  const BaselineSnapshot({
    required this.lines,
    required this.totals,
    required this.boe,
    required this.className,
    required this.deliveryModel,
  });
}

class RebaselineRecord {
  final int version;
  final String reason;
  final String? mocId;
  final String? agileInfoNote;
  final DateTime at;
  final String by;

  const RebaselineRecord({
    required this.version,
    required this.reason,
    this.mocId,
    this.agileInfoNote,
    required this.at,
    required this.by,
  });
}

/// Access grant (role-based access control).
class AccessGrant {
  final String userEmail;
  final RBACRole role;
  final String grantedBy;
  final DateTime grantedAt;

  const AccessGrant({
    required this.userEmail,
    required this.role,
    required this.grantedBy,
    required this.grantedAt,
  });
}

/// Stakeholder for the estimate development process.
class Stakeholder {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool sme;
  final bool includedInDevelopment;

  const Stakeholder({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.sme,
    required this.includedInDevelopment,
  });
}

/// Accounting integration config.
class AccountingIntegration {
  final AccountingProvider provider;
  final bool connected;
  final DateTime? connectedAt;
  final List<AccountingGLMapping> glMapping;

  const AccountingIntegration({
    required this.provider,
    required this.connected,
    this.connectedAt,
    required this.glMapping,
  });
}

enum AccountingProvider {
  quickbooks,
  xero,
  sage,
  sap,
  none;

  String get label => switch (this) {
        AccountingProvider.quickbooks => 'QuickBooks Online',
        AccountingProvider.xero => 'Xero',
        AccountingProvider.sage => 'Sage Intacct',
        AccountingProvider.sap => 'SAP S/4HANA',
        AccountingProvider.none => 'Not connected',
      };

  String get icon => switch (this) {
        AccountingProvider.quickbooks => 'account_balance',
        AccountingProvider.xero => 'cloud_done',
        AccountingProvider.sage => 'auto_graph',
        AccountingProvider.sap => 'corporate_fare',
        AccountingProvider.none => 'link_off',
      };
}

class AccountingGLMapping {
  final CostCategory category;
  final String glCode;
  final String glName;

  const AccountingGLMapping({
    required this.category,
    required this.glCode,
    required this.glName,
  });
}

/// AI suggestion for the estimate.
class AISuggestion {
  final String id;
  final String type; // 'FEED' | 'REDUCE' | 'MISSING'
  final String text;
  final String? detail;
  final bool applied;
  final bool dismissed;
  final DateTime createdAt;

  const AISuggestion({
    required this.id,
    required this.type,
    required this.text,
    this.detail,
    required this.applied,
    required this.dismissed,
    required this.createdAt,
  });
}

/// The full cost estimate.
class CostEstimate {
  final String id;
  final String projectId;
  final String projectName;
  final EstimateClass className;
  final DeliveryModel deliveryModel;
  final EstimateStatus status;
  final String currency;
  final List<CostLine> lines;
  final BasisOfEstimate boe;
  final EstimateTotals totals;
  final List<AccessGrant> access;
  final List<Stakeholder> stakeholders;
  final AccountingIntegration? accountingIntegration;
  final ReviewApproval? review;
  final Baseline? baseline;
  final List<AISuggestion> aiSuggestions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CostEstimate({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.className,
    required this.deliveryModel,
    required this.status,
    required this.currency,
    required this.lines,
    required this.boe,
    required this.totals,
    required this.access,
    required this.stakeholders,
    this.accountingIntegration,
    this.review,
    this.baseline,
    required this.aiSuggestions,
    required this.createdAt,
    required this.updatedAt,
  });

  CostEstimate copyWith({
    String? id,
    String? projectId,
    String? projectName,
    EstimateClass? className,
    DeliveryModel? deliveryModel,
    EstimateStatus? status,
    String? currency,
    List<CostLine>? lines,
    BasisOfEstimate? boe,
    EstimateTotals? totals,
    List<AccessGrant>? access,
    List<Stakeholder>? stakeholders,
    AccountingIntegration? accountingIntegration,
    ReviewApproval? review,
    Baseline? baseline,
    List<AISuggestion>? aiSuggestions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CostEstimate(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      className: className ?? this.className,
      deliveryModel: deliveryModel ?? this.deliveryModel,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      lines: lines ?? this.lines,
      boe: boe ?? this.boe,
      totals: totals ?? this.totals,
      access: access ?? this.access,
      stakeholders: stakeholders ?? this.stakeholders,
      accountingIntegration: accountingIntegration ?? this.accountingIntegration,
      review: review ?? this.review,
      baseline: baseline ?? this.baseline,
      aiSuggestions: aiSuggestions ?? this.aiSuggestions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
