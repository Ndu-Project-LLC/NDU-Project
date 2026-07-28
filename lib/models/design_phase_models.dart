import 'package:ndu_project/wbs/models/wbs_models.dart' show ProjectMethodology;
export 'package:ndu_project/wbs/models/wbs_models.dart' show ProjectMethodology;

// Enums
enum ChecklistStatus { ready, inReview, pending }

// Requirements Implementation Models
class RequirementRow {
  RequirementRow({
    String? id,
    required this.title,
    required this.owner,
    required this.definition,
    this.requirementId = '',
    this.requirementType = 'Functional',
    this.ruleType = 'Internal',
    this.sourceType = 'Standard',
    this.designArtifactLabel = '',
    this.designArtifactType = 'Figma',
    this.designArtifactUrl = '',
    this.artifactStoragePath = '',
    this.artifactFileName = '',
    this.artifactMimeType = '',
    this.artifactSizeBytes = 0,
    this.validationStatus = 'Unmapped',
    this.acceptanceCriteria = '',
    this.testMethod = '',
    this.sourceDocument = '',
    this.isOutOfScope = false,
    this.conflictNote = '',
    this.conflictImpact = 'Low',
    this.gapStatus = 'Pending Approval',
  }) : id = (id == null || id.trim().isEmpty) ? _generateId() : id;

  String id;
  String title;
  String owner;
  String definition;
  String requirementId;
  String requirementType;
  String ruleType;
  String sourceType;
  String designArtifactLabel;
  String designArtifactType;
  String designArtifactUrl;
  String artifactStoragePath;
  String artifactFileName;
  String artifactMimeType;
  int artifactSizeBytes;
  String validationStatus;
  String acceptanceCriteria;
  String testMethod;
  String sourceDocument;
  bool isOutOfScope;
  String conflictNote;
  String conflictImpact;
  String gapStatus;

  RequirementRow copyWith({
    String? title,
    String? owner,
    String? definition,
    String? requirementId,
    String? requirementType,
    String? ruleType,
    String? sourceType,
    String? designArtifactLabel,
    String? designArtifactType,
    String? designArtifactUrl,
    String? artifactStoragePath,
    String? artifactFileName,
    String? artifactMimeType,
    int? artifactSizeBytes,
    String? validationStatus,
    String? acceptanceCriteria,
    String? testMethod,
    String? sourceDocument,
    bool? isOutOfScope,
    String? conflictNote,
    String? conflictImpact,
    String? gapStatus,
  }) {
    return RequirementRow(
      id: id,
      title: title ?? this.title,
      owner: owner ?? this.owner,
      definition: definition ?? this.definition,
      requirementId: requirementId ?? this.requirementId,
      requirementType: requirementType ?? this.requirementType,
      ruleType: ruleType ?? this.ruleType,
      sourceType: sourceType ?? this.sourceType,
      designArtifactLabel: designArtifactLabel ?? this.designArtifactLabel,
      designArtifactType: designArtifactType ?? this.designArtifactType,
      designArtifactUrl: designArtifactUrl ?? this.designArtifactUrl,
      artifactStoragePath: artifactStoragePath ?? this.artifactStoragePath,
      artifactFileName: artifactFileName ?? this.artifactFileName,
      artifactMimeType: artifactMimeType ?? this.artifactMimeType,
      artifactSizeBytes: artifactSizeBytes ?? this.artifactSizeBytes,
      validationStatus: validationStatus ?? this.validationStatus,
      acceptanceCriteria: acceptanceCriteria ?? this.acceptanceCriteria,
      testMethod: testMethod ?? this.testMethod,
      sourceDocument: sourceDocument ?? this.sourceDocument,
      isOutOfScope: isOutOfScope ?? this.isOutOfScope,
      conflictNote: conflictNote ?? this.conflictNote,
      conflictImpact: conflictImpact ?? this.conflictImpact,
      gapStatus: gapStatus ?? this.gapStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'owner': owner,
      'definition': definition,
      'requirementId': requirementId,
      'requirementType': requirementType,
      'ruleType': ruleType,
      'sourceType': sourceType,
      'designArtifactLabel': designArtifactLabel,
      'designArtifactType': designArtifactType,
      'designArtifactUrl': designArtifactUrl,
      'artifactStoragePath': artifactStoragePath,
      'artifactFileName': artifactFileName,
      'artifactMimeType': artifactMimeType,
      'artifactSizeBytes': artifactSizeBytes,
      'validationStatus': validationStatus,
      'acceptanceCriteria': acceptanceCriteria,
      'testMethod': testMethod,
      'sourceDocument': sourceDocument,
      'isOutOfScope': isOutOfScope,
      'conflictNote': conflictNote,
      'conflictImpact': conflictImpact,
      'gapStatus': gapStatus,
    };
  }

  factory RequirementRow.fromMap(Map<String, dynamic> map) {
    return RequirementRow(
      id: map['id']?.toString(),
      title: map['title']?.toString() ?? '',
      owner: map['owner']?.toString() ?? '',
      definition: map['definition']?.toString() ?? '',
      requirementId: map['requirementId']?.toString() ??
          map['requirement_id']?.toString() ??
          '',
      requirementType: map['requirementType']?.toString() ??
          map['requirement_type']?.toString() ??
          'Functional',
      ruleType: map['ruleType']?.toString() ??
          map['rule_type']?.toString() ??
          'Internal',
      sourceType: map['sourceType']?.toString() ??
          map['source_type']?.toString() ??
          'Standard',
      designArtifactLabel: map['designArtifactLabel']?.toString() ??
          map['design_artifact_label']?.toString() ??
          '',
      designArtifactType: map['designArtifactType']?.toString() ??
          map['design_artifact_type']?.toString() ??
          'Figma',
      designArtifactUrl: map['designArtifactUrl']?.toString() ??
          map['design_artifact_url']?.toString() ??
          '',
      artifactStoragePath: map['artifactStoragePath']?.toString() ??
          map['artifact_storage_path']?.toString() ??
          '',
      artifactFileName: map['artifactFileName']?.toString() ??
          map['artifact_file_name']?.toString() ??
          '',
      artifactMimeType: map['artifactMimeType']?.toString() ??
          map['artifact_mime_type']?.toString() ??
          '',
      artifactSizeBytes: map['artifactSizeBytes'] is num
          ? (map['artifactSizeBytes'] as num).toInt()
          : int.tryParse(map['artifactSizeBytes']?.toString() ?? '') ?? 0,
      validationStatus: map['validationStatus']?.toString() ??
          map['validation_status']?.toString() ??
          'Unmapped',
      acceptanceCriteria: map['acceptanceCriteria']?.toString() ??
          map['acceptance_criteria']?.toString() ??
          '',
      testMethod: map['testMethod']?.toString() ??
          map['verificationMethod']?.toString() ??
          map['test_method']?.toString() ??
          '',
      sourceDocument: map['sourceDocument']?.toString() ??
          map['source_document']?.toString() ??
          '',
      isOutOfScope: map['isOutOfScope'] == true ||
          map['outOfScope'] == true ||
          map['out_of_scope'] == true,
      conflictNote: map['conflictNote']?.toString() ??
          map['conflict_note']?.toString() ??
          '',
      conflictImpact: map['conflictImpact']?.toString() ??
          map['conflict_impact']?.toString() ??
          'Low',
      gapStatus: map['gapStatus']?.toString() ??
          map['gap_status']?.toString() ??
          'Pending Approval',
    );
  }

  static String _generateId() =>
      DateTime.now().microsecondsSinceEpoch.toString();
}

class RequirementChecklistItem {
  String title;
  String description;
  ChecklistStatus status;
  String? owner;

  RequirementChecklistItem({
    required this.title,
    required this.description,
    required this.status,
    this.owner,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'status': status.name,
      'owner': owner,
    };
  }

  factory RequirementChecklistItem.fromMap(Map<String, dynamic> map) {
    return RequirementChecklistItem(
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      status: ChecklistStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ChecklistStatus.pending,
      ),
      owner: map['owner']?.toString(),
    );
  }
}

// Technical Alignment Models
class ConstraintRow {
  ConstraintRow({
    required this.constraint,
    required this.guardrail,
    required this.owner,
    required this.status,
  });

  String constraint;
  String guardrail;
  String owner;
  String status;

  Map<String, dynamic> toMap() {
    return {
      'constraint': constraint,
      'guardrail': guardrail,
      'owner': owner,
      'status': status,
    };
  }

  factory ConstraintRow.fromMap(Map<String, dynamic> map) {
    return ConstraintRow(
      constraint: map['constraint']?.toString() ?? '',
      guardrail: map['guardrail']?.toString() ?? '',
      owner: map['owner']?.toString() ?? '',
      status: map['status']?.toString() ?? 'Draft',
    );
  }
}

class RequirementMappingRow {
  RequirementMappingRow({
    required this.requirement,
    required this.approach,
    required this.status,
  });

  String requirement;
  String approach;
  String status;

  Map<String, dynamic> toMap() {
    return {
      'requirement': requirement,
      'approach': approach,
      'status': status,
    };
  }

  factory RequirementMappingRow.fromMap(Map<String, dynamic> map) {
    return RequirementMappingRow(
      requirement: map['requirement']?.toString() ?? '',
      approach: map['approach']?.toString() ?? '',
      status: map['status']?.toString() ?? 'Draft',
    );
  }
}

class DependencyDecisionRow {
  DependencyDecisionRow({
    required this.item,
    required this.detail,
    required this.owner,
    required this.status,
  });

  String item;
  String detail;
  String owner;
  String status;

  Map<String, dynamic> toMap() {
    return {
      'item': item,
      'detail': detail,
      'owner': owner,
      'status': status,
    };
  }

  factory DependencyDecisionRow.fromMap(Map<String, dynamic> map) {
    return DependencyDecisionRow(
      item: map['item']?.toString() ?? '',
      detail: map['detail']?.toString() ?? '',
      owner: map['owner']?.toString() ?? '',
      status: map['status']?.toString() ?? 'Draft',
    );
  }
}

// Specialized Design Models
class SecurityPatternRow {
  SecurityPatternRow({
    required this.pattern,
    required this.decision,
    required this.owner,
    required this.status,
  });

  String pattern;
  String decision;
  String owner;
  String status;

  Map<String, dynamic> toMap() => {
        'pattern': pattern,
        'decision': decision,
        'owner': owner,
        'status': status,
      };

  factory SecurityPatternRow.fromMap(Map<String, dynamic> map) {
    return SecurityPatternRow(
      pattern: map['pattern']?.toString() ?? '',
      decision: map['decision']?.toString() ?? '',
      owner: map['owner']?.toString() ?? '',
      status: map['status']?.toString() ?? 'Draft',
    );
  }
}

class PerformancePatternRow {
  PerformancePatternRow({
    required this.hotspot,
    required this.focus,
    required this.sla,
    required this.status,
  });

  String hotspot;
  String focus;
  String sla;
  String status;

  Map<String, dynamic> toMap() => {
        'hotspot': hotspot,
        'focus': focus,
        'sla': sla,
        'status': status,
      };

  factory PerformancePatternRow.fromMap(Map<String, dynamic> map) {
    return PerformancePatternRow(
      hotspot: map['hotspot']?.toString() ?? '',
      focus: map['focus']?.toString() ?? '',
      sla: map['sla']?.toString() ?? '',
      status: map['status']?.toString() ?? 'Draft',
    );
  }
}

class IntegrationFlowRow {
  IntegrationFlowRow({
    required this.flow,
    required this.owner,
    required this.system,
    required this.status,
  });

  String flow;
  String owner;
  String system;
  String status;

  Map<String, dynamic> toMap() => {
        'flow': flow,
        'owner': owner,
        'system': system,
        'status': status,
      };

  factory IntegrationFlowRow.fromMap(Map<String, dynamic> map) {
    return IntegrationFlowRow(
      flow: map['flow']?.toString() ?? '',
      owner: map['owner']?.toString() ?? '',
      system: map['system']?.toString() ?? '',
      status: map['status']?.toString() ?? 'Draft',
    );
  }
}

class SpecializedDesignData {
  String notes;
  List<SecurityPatternRow> securityPatterns;
  List<PerformancePatternRow> performancePatterns;
  List<IntegrationFlowRow> integrationFlows;

  SpecializedDesignData({
    this.notes = '',
    this.securityPatterns = const [],
    this.performancePatterns = const [],
    this.integrationFlows = const [],
  });

  Map<String, dynamic> toMap() => {
        'notes': notes,
        'securityPatterns': securityPatterns.map((e) => e.toMap()).toList(),
        'performancePatterns':
            performancePatterns.map((e) => e.toMap()).toList(),
        'integrationFlows': integrationFlows.map((e) => e.toMap()).toList(),
      };

  factory SpecializedDesignData.fromMap(Map<String, dynamic> map) {
    return SpecializedDesignData(
      notes: map['notes']?.toString() ?? '',
      securityPatterns: (map['securityPatterns'] as List?)
              ?.map(
                  (e) => SecurityPatternRow.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      performancePatterns: (map['performancePatterns'] as List?)
              ?.map((e) =>
                  PerformancePatternRow.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      integrationFlows: (map['integrationFlows'] as List?)
              ?.map(
                  (e) => IntegrationFlowRow.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// --- Enterprise Design Models ---

enum ExecutionStrategy { inHouse, contracted, hybrid }

enum ProjectIndustry {
  generic,
  software,
  construction,
  manufacturing,
  marketing
}

class DesignReadinessModel {
  final double specificationsScore;
  final double alignmentScore;
  final double architectureScore;
  final double riskScore;
  final double overallScore;
  final List<String> missingItems;

  DesignReadinessModel({
    this.specificationsScore = 0.0,
    this.alignmentScore = 0.0,
    this.architectureScore = 0.0,
    this.riskScore = 0.0,
    this.overallScore = 0.0,
    this.missingItems = const [],
  });

  Map<String, dynamic> toMap() => {
        'specificationsScore': specificationsScore,
        'alignmentScore': alignmentScore,
        'architectureScore': architectureScore,
        'riskScore': riskScore,
        'overallScore': overallScore,
        'missingItems': missingItems,
      };

  factory DesignReadinessModel.fromMap(Map<String, dynamic> map) {
    return DesignReadinessModel(
      specificationsScore: (map['specificationsScore'] ?? 0).toDouble(),
      alignmentScore: (map['alignmentScore'] ?? 0).toDouble(),
      architectureScore: (map['architectureScore'] ?? 0).toDouble(),
      riskScore: (map['riskScore'] ?? 0).toDouble(),
      overallScore: (map['overallScore'] ?? 0).toDouble(),
      missingItems: List<String>.from(map['missingItems'] ?? []),
    );
  }
}

class DesignManagementData {
  // Core Strategy
  ProjectMethodology methodology;
  ExecutionStrategy executionStrategy;
  ProjectIndustry industry;
  List<String> applicableStandards;

  // Readiness
  DesignReadinessModel readiness;

  // Inherited Context (from Planning)
  List<String> inheritedRisks;
  List<String> inheritedConstraints;
  List<String> inheritedScope;

  // Design Specifics
  SpecializedDesignData specializedDesign;

  // Legacy Fields for Backward Compatibility
  List<DesignSpecification> specifications;
  List<DesignDocument> documents;
  List<DesignToolLink> tools;

  // Old progress fields for backward compatibility (mapped to readiness)
  double get specificationsProgress => readiness.specificationsScore;
  double get alignmentProgress => readiness.alignmentScore;

  DesignManagementData({
    this.methodology = ProjectMethodology.waterfall,
    this.executionStrategy = ExecutionStrategy.inHouse,
    this.industry = ProjectIndustry.generic,
    this.applicableStandards = const [],
    DesignReadinessModel? readiness,
    this.inheritedRisks = const [],
    this.inheritedConstraints = const [],
    this.inheritedScope = const [],
    SpecializedDesignData? specializedDesign,
    List<DesignSpecification>? specifications,
    List<DesignDocument>? documents,
    List<DesignToolLink>? tools,
  })  : readiness = readiness ?? DesignReadinessModel(),
        specializedDesign = specializedDesign ?? SpecializedDesignData(),
        specifications = specifications ?? [],
        documents = documents ?? [],
        tools = tools ?? [];

  DesignManagementData copyWith({
    ProjectMethodology? methodology,
    ExecutionStrategy? executionStrategy,
    ProjectIndustry? industry,
    List<String>? applicableStandards,
    DesignReadinessModel? readiness,
    List<String>? inheritedRisks,
    List<String>? inheritedConstraints,
    List<String>? inheritedScope,
    SpecializedDesignData? specializedDesign,
    List<DesignSpecification>? specifications,
    List<DesignDocument>? documents,
    List<DesignToolLink>? tools,
  }) {
    return DesignManagementData(
      methodology: methodology ?? this.methodology,
      executionStrategy: executionStrategy ?? this.executionStrategy,
      industry: industry ?? this.industry,
      applicableStandards: applicableStandards ?? this.applicableStandards,
      readiness: readiness ?? this.readiness,
      inheritedRisks: inheritedRisks ?? this.inheritedRisks,
      inheritedConstraints: inheritedConstraints ?? this.inheritedConstraints,
      inheritedScope: inheritedScope ?? this.inheritedScope,
      specializedDesign: specializedDesign ?? this.specializedDesign,
      specifications: specifications ?? this.specifications,
      documents: documents ?? this.documents,
      tools: tools ?? this.tools,
    );
  }

  Map<String, dynamic> toJson() => {
        'methodology': methodology.name,
        'executionStrategy': executionStrategy.name,
        'industry': industry.name,
        'applicableStandards': applicableStandards,
        'readiness': readiness.toMap(),
        'inheritedRisks': inheritedRisks,
        'inheritedConstraints': inheritedConstraints,
        'inheritedScope': inheritedScope,
        'specializedDesign': specializedDesign.toMap(),
        'specifications': specifications.map((e) => e.toJson()).toList(),
        'documents': documents.map((e) => e.toJson()).toList(),
        'tools': tools.map((e) => e.toJson()).toList(),
      };

  factory DesignManagementData.fromJson(Map<String, dynamic> json) {
    return DesignManagementData(
      methodology: ProjectMethodology.values.firstWhere(
        (e) => e.name == json['methodology'],
        orElse: () => ProjectMethodology.waterfall,
      ),
      executionStrategy: ExecutionStrategy.values.firstWhere(
        (e) => e.name == json['executionStrategy'],
        orElse: () => ExecutionStrategy.inHouse,
      ),
      industry: ProjectIndustry.values.firstWhere(
        (e) => e.name == json['industry'],
        orElse: () => ProjectIndustry.generic,
      ),
      applicableStandards: List<String>.from(json['applicableStandards'] ?? []),
      readiness: json['readiness'] != null
          ? DesignReadinessModel.fromMap(json['readiness'])
          : DesignReadinessModel(),
      inheritedRisks: List<String>.from(json['inheritedRisks'] ?? []),
      inheritedConstraints:
          List<String>.from(json['inheritedConstraints'] ?? []),
      inheritedScope: List<String>.from(json['inheritedScope'] ?? []),
      specializedDesign: json['specializedDesign'] != null
          ? SpecializedDesignData.fromMap(json['specializedDesign'])
          : SpecializedDesignData(),
      specifications: (json['specifications'] as List?)
              ?.map((e) => DesignSpecification.fromJson(e))
              .toList() ??
          [],
      documents: (json['documents'] as List?)
              ?.map((e) => DesignDocument.fromJson(e))
              .toList() ??
          [],
      tools: (json['tools'] as List?)
              ?.map((e) => DesignToolLink.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class DesignSpecification {
  String id;
  String description;
  String status; // 'Defined', 'Validated', 'Implemented'

  DesignSpecification({
    String? id,
    this.description = '',
    this.status = 'Defined',
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'status': status,
      };

  factory DesignSpecification.fromJson(Map<String, dynamic> json) {
    return DesignSpecification(
      id: json['id']?.toString(),
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Defined',
    );
  }
}

class DesignDocument {
  String id;
  String title;
  String type; // 'Input', 'Output', or 'Reference'
  String? url;
  String? notes;
  String? uploadedFileName;
  String? uploadedStoragePath;

  DesignDocument({
    String? id,
    this.title = '',
    this.type = 'Output',
    this.url,
    this.notes,
    this.uploadedFileName,
    this.uploadedStoragePath,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  bool get hasUploadedFile =>
      uploadedFileName != null && uploadedFileName!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'url': url,
        'notes': notes,
        'uploadedFileName': uploadedFileName,
        'uploadedStoragePath': uploadedStoragePath,
      };

  factory DesignDocument.fromJson(Map<String, dynamic> json) {
    return DesignDocument(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Output',
      url: json['url']?.toString(),
      notes: json['notes']?.toString(),
      uploadedFileName: json['uploadedFileName']?.toString(),
      uploadedStoragePath: json['uploadedStoragePath']?.toString(),
    );
  }
}

class DesignToolLink {
  String id;
  String name;
  String url;
  bool isInternal;
  String? uploadedFileName;
  String? uploadedStoragePath;

  DesignToolLink({
    String? id,
    this.name = '',
    this.url = '',
    this.isInternal = false,
    this.uploadedFileName,
    this.uploadedStoragePath,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  bool get hasUploadedFile =>
      uploadedFileName != null && uploadedFileName!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'isInternal': isInternal,
        'uploadedFileName': uploadedFileName,
        'uploadedStoragePath': uploadedStoragePath,
      };

  factory DesignToolLink.fromJson(Map<String, dynamic> json) {
    return DesignToolLink(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      isInternal: json['isInternal'] == true,
      uploadedFileName: json['uploadedFileName']?.toString(),
      uploadedStoragePath: json['uploadedStoragePath']?.toString(),
    );
  }
}

// Legacy DTO for backward compatibility if needed,
// allows screens to use old DesignPhaseProgress class name temporarily.
typedef DesignPhaseProgress = DesignReadinessModel;
