enum WorkItemType {
  epic,
  feature,
  userStory,
  bug,
  enhancement,
  technicalTask,
  spike,
  researchItem,
  complianceRequirement,
  infrastructureTask;

  String get label {
    switch (this) {
      case WorkItemType.epic: return 'Epic';
      case WorkItemType.feature: return 'Feature';
      case WorkItemType.userStory: return 'User Story';
      case WorkItemType.bug: return 'Bug';
      case WorkItemType.enhancement: return 'Enhancement';
      case WorkItemType.technicalTask: return 'Technical Task';
      case WorkItemType.spike: return 'Spike';
      case WorkItemType.researchItem: return 'Research Item';
      case WorkItemType.complianceRequirement: return 'Compliance Requirement';
      case WorkItemType.infrastructureTask: return 'Infrastructure Task';
    }
  }

  static WorkItemType fromString(String s) {
    return WorkItemType.values.firstWhere(
      (t) => t.name == s,
      orElse: () => WorkItemType.userStory,
    );
  }
}

enum CriterionCategory {
  businessObjective,
  functional,
  nonFunctional,
  security,
  performance,
  ux,
  compliance,
  accessibility,
  errorHandling,
  reporting,
  approval,
  documentation;

  String get label {
    switch (this) {
      case CriterionCategory.businessObjective: return 'Business Objective';
      case CriterionCategory.functional: return 'Functional Requirement';
      case CriterionCategory.nonFunctional: return 'Non-Functional Requirement';
      case CriterionCategory.security: return 'Security Requirement';
      case CriterionCategory.performance: return 'Performance Expectation';
      case CriterionCategory.ux: return 'User Experience Expectation';
      case CriterionCategory.compliance: return 'Compliance Requirement';
      case CriterionCategory.accessibility: return 'Accessibility Requirement';
      case CriterionCategory.errorHandling: return 'Error Handling';
      case CriterionCategory.reporting: return 'Reporting Requirement';
      case CriterionCategory.approval: return 'Approval Requirement';
      case CriterionCategory.documentation: return 'Documentation Requirement';
    }
  }

  static CriterionCategory fromString(String s) {
    return CriterionCategory.values.firstWhere(
      (c) => c.name == s,
      orElse: () => CriterionCategory.functional,
    );
  }
}

enum AcFormat {
  checklist,
  bdd,
  scenario;

  String get label {
    switch (this) {
      case AcFormat.checklist: return 'Checklist';
      case AcFormat.bdd: return 'Given / When / Then (BDD)';
      case AcFormat.scenario: return 'Scenario-Based';
    }
  }

  static AcFormat fromString(String s) {
    return AcFormat.values.firstWhere(
      (f) => f.name == s,
      orElse: () => AcFormat.checklist,
    );
  }
}

class AcceptanceCriterion {
  String id;
  String description;
  CriterionCategory category;
  bool isRequired;
  bool isMet;

  AcceptanceCriterion({
    String? id,
    this.description = '',
    this.category = CriterionCategory.functional,
    this.isRequired = true,
    this.isMet = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  AcceptanceCriterion copyWith({
    String? description,
    CriterionCategory? category,
    bool? isRequired,
    bool? isMet,
  }) {
    return AcceptanceCriterion(
      id: id,
      description: description ?? this.description,
      category: category ?? this.category,
      isRequired: isRequired ?? this.isRequired,
      isMet: isMet ?? this.isMet,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'category': category.name,
        'isRequired': isRequired,
        'isMet': isMet,
      };

  factory AcceptanceCriterion.fromJson(Map<String, dynamic> json) {
    return AcceptanceCriterion(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      description: json['description']?.toString() ?? '',
      category: CriterionCategory.fromString(json['category']?.toString() ?? ''),
      isRequired: json['isRequired'] == true,
      isMet: json['isMet'] == true,
    );
  }
}

class AcceptanceCriteriaTemplate {
  String id;
  String name;
  String description;
  WorkItemType workItemType;
  List<AcceptanceCriterion> criteria;
  AcFormat format;

  AcceptanceCriteriaTemplate({
    String? id,
    this.name = '',
    this.description = '',
    this.workItemType = WorkItemType.userStory,
    List<AcceptanceCriterion>? criteria,
    this.format = AcFormat.checklist,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        criteria = criteria ?? [];

  double get confidenceScore {
    if (criteria.isEmpty) return 0;
    final required = criteria.where((c) => c.isRequired).length;
    final filled = criteria.where((c) => c.description.trim().length >= 10).length;
    if (required == 0) return filled / criteria.length * 100;
    final requiredFilled = criteria
        .where((c) => c.isRequired && c.description.trim().length >= 10)
        .length;
    return (requiredFilled / required * 60) + (filled / criteria.length * 40);
  }

  List<String> get improvementSuggestions {
    final suggestions = <String>[];
    final emptyRequired =
        criteria.where((c) => c.isRequired && c.description.trim().isEmpty);
    for (final c in emptyRequired) {
      suggestions.add('Add "${c.category.label}" criterion (required but empty)');
    }
    final noSecurity = criteria.any((c) => c.category == CriterionCategory.security);
    if (!noSecurity) {
      suggestions.add('Consider adding a security requirement');
    }
    final noError = criteria.any((c) => c.category == CriterionCategory.errorHandling);
    if (!noError) {
      suggestions.add('Consider adding error handling criteria');
    }
    final short = criteria.where((c) => c.description.trim().isNotEmpty && c.description.trim().length < 10);
    for (final c in short) {
      suggestions.add('"${c.category.label}" criterion is too short — be more specific');
    }
    return suggestions;
  }

  AcceptanceCriteriaTemplate copyWith({
    String? name,
    String? description,
    WorkItemType? workItemType,
    List<AcceptanceCriterion>? criteria,
    AcFormat? format,
  }) {
    return AcceptanceCriteriaTemplate(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      workItemType: workItemType ?? this.workItemType,
      criteria: criteria ?? List.from(this.criteria),
      format: format ?? this.format,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'workItemType': workItemType.name,
        'criteria': criteria.map((c) => c.toJson()).toList(),
        'format': format.name,
      };

  factory AcceptanceCriteriaTemplate.fromJson(Map<String, dynamic> json) {
    return AcceptanceCriteriaTemplate(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      workItemType: WorkItemType.fromString(json['workItemType']?.toString() ?? ''),
      criteria: (json['criteria'] as List?)
              ?.map((e) =>
                  AcceptanceCriterion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      format: AcFormat.fromString(json['format']?.toString() ?? ''),
    );
  }
}

class AcceptanceCriteriaConfig {
  List<AcceptanceCriteriaTemplate> templates;
  bool aiGenerationEnabled;
  double confidenceScoreThreshold;

  AcceptanceCriteriaConfig({
    List<AcceptanceCriteriaTemplate>? templates,
    this.aiGenerationEnabled = true,
    this.confidenceScoreThreshold = 0.6,
  }) : templates = templates ?? [];

  Map<String, dynamic> toJson() => {
        'templates': templates.map((t) => t.toJson()).toList(),
        'aiGenerationEnabled': aiGenerationEnabled,
        'confidenceScoreThreshold': confidenceScoreThreshold,
      };

  factory AcceptanceCriteriaConfig.fromJson(Map<String, dynamic> json) {
    return AcceptanceCriteriaConfig(
      templates: (json['templates'] as List?)
              ?.map((e) =>
                  AcceptanceCriteriaTemplate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      aiGenerationEnabled: json['aiGenerationEnabled'] == true,
      confidenceScoreThreshold:
          (json['confidenceScoreThreshold'] as num?)?.toDouble() ?? 0.6,
    );
  }
}
