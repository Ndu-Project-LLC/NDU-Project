import 'dart:convert';

import 'package:ndu_project/models/project_data_model.dart';

/// Monotonic counter used to generate unique IDs without relying on
/// `DateTime.now()` (which can produce duplicates in tight loops on
/// platforms with millisecond-resolution clocks).
int _uniqueIdCounter = 0;

String _nextUniqueId([String prefix = 'id']) {
  _uniqueIdCounter++;
  return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_$_uniqueIdCounter';
}

/// Kept for backward compatibility — delegates to [_nextUniqueId].
String _nextSpecRowId() => _nextUniqueId('spec_row');

/// Treat empty or whitespace-only IDs as null so constructors generate a
/// fresh unique ID — prevents duplicate-key crashes when expanding sections
/// that mount widgets keyed by [id].
String? _nonEmptyId(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return raw;
}

const String kDesignPlanningDocumentKey = 'planning_design_basis_document';
const String kDesignPlanningSummaryKey = 'planning_design_notes';
const String kDesignPlanningPlanKey = 'planning_design_plan';
const String kDesignPlanningArchitectureKey =
    'planning_design_architecture_basis';
const String kDesignPlanningUiUxKey = 'planning_design_uiux_basis';
const String kDesignPlanningTechnicalKey = 'planning_design_technical_basis';
const String kDesignPlanningValidationKey = 'planning_design_validation_basis';
const String kDesignPlanningHandoffKey = 'planning_design_handoff';

class DesignPlanningDocument {
  DesignPlanningDocument({
    this.version = 'v1.0',
    this.status = 'Draft',
    this.overviewSummary = '',
    this.designWhoAndOwnership = '',
    this.designExecutionApproach = '',
    this.designVendorContractInputs = '',
    this.designInterfacesAndConstraints = '',
    this.objectives = '',
    this.successCriteria = '',
    this.scope = '',
    this.outOfScope = '',
    this.architectureSummary = '',
    this.diagramReference = '',
    this.dataFlowSummary = '',
    this.uiUxSummary = '',
    this.designSystemNotes = '',
    this.technicalFrontend = '',
    this.technicalBackend = '',
    this.technicalData = '',
    this.validationSummary = '',
    this.governanceNotes = '',
    this.specConfigUnifiedTable = true,
    this.specConfigAllowNoLink = true,
    this.specConfigEnableFileUpload = true,
    this.specConfigSectionApproval = true,
    this.specConfigGateProgression = true,
    this.lastUpdatedIso = '',
    List<DesignRequirementMapping>? requirements,
    List<DesignSpecificationPlanRow>? specifications,
    List<DesignSpecificationDeviation>? deviations,
    List<DesignPlanningReferenceDoc>? specificationDocuments,
    List<DesignPlanningWorkItem>? modules,
    List<DesignPlanningWorkItem>? journeys,
    List<DesignPlanningWorkItem>? interfaces,
    List<DesignPlanningWorkItem>? integrations,
    List<String>? constraints,
    List<String>? assumptions,
    List<DesignRiskEntry>? risks,
    List<DesignDependencyEntry>? dependencies,
    List<DesignDecisionEntry>? decisions,
    List<DesignApprovalEntry>? approvals,
  })  : requirements = requirements ?? [],
        specifications = specifications ?? [],
        deviations = deviations ?? [],
        specificationDocuments = specificationDocuments ?? [],
        modules = modules ?? [],
        journeys = journeys ?? [],
        interfaces = interfaces ?? [],
        integrations = integrations ?? [],
        constraints = constraints ?? [],
        assumptions = assumptions ?? [],
        risks = risks ?? [],
        dependencies = dependencies ?? [],
        decisions = decisions ?? [],
        approvals = approvals ?? [];

  String version;
  String status;
  String overviewSummary;
  String designWhoAndOwnership;
  String designExecutionApproach;
  String designVendorContractInputs;
  String designInterfacesAndConstraints;
  String objectives;
  String successCriteria;
  String scope;
  String outOfScope;
  String architectureSummary;
  String diagramReference;
  String dataFlowSummary;
  String uiUxSummary;
  String designSystemNotes;
  String technicalFrontend;
  String technicalBackend;
  String technicalData;
  String validationSummary;
  String governanceNotes;
  bool specConfigUnifiedTable;
  bool specConfigAllowNoLink;
  bool specConfigEnableFileUpload;
  bool specConfigSectionApproval;
  bool specConfigGateProgression;
  String lastUpdatedIso;
  List<DesignRequirementMapping> requirements;
  List<DesignSpecificationPlanRow> specifications;
  List<DesignSpecificationDeviation> deviations;
  List<DesignPlanningReferenceDoc> specificationDocuments;
  List<DesignPlanningWorkItem> modules;
  List<DesignPlanningWorkItem> journeys;
  List<DesignPlanningWorkItem> interfaces;
  List<DesignPlanningWorkItem> integrations;
  List<String> constraints;
  List<String> assumptions;
  List<DesignRiskEntry> risks;
  List<DesignDependencyEntry> dependencies;
  List<DesignDecisionEntry> decisions;
  List<DesignApprovalEntry> approvals;

  factory DesignPlanningDocument.fromProjectData(ProjectDataModel data) {
    final raw = data.planningNotes[kDesignPlanningDocumentKey];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        return DesignPlanningDocument.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        // Fall back to seeded document when legacy/plain text is stored.
      }
    }
    return DesignPlanningDocument.seeded(data);
  }

  factory DesignPlanningDocument.seeded(ProjectDataModel data) {
    final framework = (data.overallFramework ?? '').trim();
    final frameworkLower = framework.toLowerCase();
    final goals = data.planningGoals
        .map((goal) => goal.title.trim())
        .where((value) => value.isNotEmpty)
        .take(5)
        .toList();
    final successCriteria = data.frontEndPlanning.successCriteriaItems
        .map((item) => item.description.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final requirementSeed = data.planningRequirementItems
        .map((item) => DesignRequirementMapping.fromPlanningItem(item, data))
        .toList();
    final requirementFallback = requirementSeed.isNotEmpty
        ? requirementSeed
        : data.frontEndPlanning.requirementItems
            .map((item) => DesignRequirementMapping.fromRequirementItem(item))
            .toList();
    final riskSeed = data.frontEndPlanning.riskRegisterItems
        .map((item) => DesignRiskEntry.fromRiskRegisterItem(item))
        .toList();
    final dependencySeed = data.interfaceEntries
        .map(
          (entry) => DesignDependencyEntry(
            name: entry.boundary.trim(),
            type: 'Interface',
            source: entry.owner.trim(),
            neededBy: entry.cadence.trim(),
            owner: entry.owner.trim(),
            status:
                entry.status.trim().isEmpty ? 'Planned' : entry.status.trim(),
            notes: entry.notes.trim(),
          ),
        )
        .where((entry) => entry.name.isNotEmpty)
        .toList();
    final approvalSeed = <DesignApprovalEntry>[
      if (data.charterProjectManagerName.trim().isNotEmpty)
        DesignApprovalEntry(
          reviewer: data.charterProjectManagerName.trim(),
          role: 'Project Manager',
          status: 'Pending',
        ),
      if (data.charterProjectSponsorName.trim().isNotEmpty)
        DesignApprovalEntry(
          reviewer: data.charterProjectSponsorName.trim(),
          role: 'Sponsor',
          status: 'Pending',
        ),
      if (data.charterReviewedBy.trim().isNotEmpty)
        DesignApprovalEntry(
          reviewer: data.charterReviewedBy.trim(),
          role: 'Reviewer',
          status: 'Pending',
        ),
    ];
    final frameworkModules = _seedModulesByFramework(frameworkLower);
    final frameworkValidation = _seedValidationByFramework(frameworkLower);
    final governanceSeed = _seedGovernanceByFramework(frameworkLower);
    final specificationsSeed = data.planningRequirementItems
        .map(
          (item) => DesignSpecificationPlanRow(
            title: item.plannedText.trim().isNotEmpty
                ? item.plannedText.trim()
                : item.notes.trim(),
            details: item.notes.trim(),
            area: item.priority.trim(),
            ruleType: 'Internal',
            specificationType:
                _inferSpecificationType(item, data, fallback: 'Standard'),
            sourceType: _inferSpecificationSourceType(item, data),
            owner: item.owner.trim(),
            status: item.status.trim().isEmpty ? 'Draft' : item.status.trim(),
            referenceLink: item.verificationMethod.trim(),
          ),
        )
        .where((row) => row.title.trim().isNotEmpty || row.details.isNotEmpty)
        .toList();
    final specificationDocumentSeed = <DesignPlanningReferenceDoc>[
      if (data.frontEndPlanning.contracts.trim().isNotEmpty)
        DesignPlanningReferenceDoc(
          title: 'Contracts Baseline',
          category: 'Contracts',
          notes: data.frontEndPlanning.contracts.trim(),
        ),
      if (data.frontEndPlanning.contractVendorQuotes.trim().isNotEmpty)
        DesignPlanningReferenceDoc(
          title: 'Vendor Quotes',
          category: 'Vendors',
          notes: data.frontEndPlanning.contractVendorQuotes.trim(),
        ),
      if (data.frontEndPlanning.procurement.trim().isNotEmpty)
        DesignPlanningReferenceDoc(
          title: 'Procurement Notes',
          category: 'Contracts',
          notes: data.frontEndPlanning.procurement.trim(),
        ),
    ];
    final deliverableModules = data.designDeliverablesData.register
        .map(
          (item) => DesignPlanningWorkItem(
            name: item.name,
            purpose: item.risk,
            owner: item.owner,
            status: item.status,
          ),
        )
        .where((item) => item.name.isNotEmpty)
        .toList();

    return DesignPlanningDocument(
      overviewSummary: [
        data.solutionDescription.trim(),
        data.businessCase.trim(),
      ].where((value) => value.isNotEmpty).join('\n\n'),
      designWhoAndOwnership: [
        if (data.charterProjectManagerName.trim().isNotEmpty)
          'Project Manager: ${data.charterProjectManagerName.trim()}',
        if (data.charterProjectSponsorName.trim().isNotEmpty)
          'Project Sponsor: ${data.charterProjectSponsorName.trim()}',
        if (data.charterReviewedBy.trim().isNotEmpty)
          'Reviewer: ${data.charterReviewedBy.trim()}',
        ...data.teamMembers
            .where((item) =>
                item.name.trim().isNotEmpty || item.role.trim().isNotEmpty)
            .take(6)
            .map((item) => [
                  if (item.name.trim().isNotEmpty) item.name.trim(),
                  if (item.role.trim().isNotEmpty) item.role.trim(),
                ].join(' - ')),
      ].where((value) => value.isNotEmpty).join('\n'),
      designExecutionApproach: [
        if (framework.isNotEmpty) 'Framework: $framework',
        if (data.projectObjective.trim().isNotEmpty)
          'Objective: ${data.projectObjective.trim()}',
        if (data.designManagementData != null)
          'Methodology: ${data.designManagementData!.methodology.name}',
        if (data.designManagementData != null)
          'Execution Strategy: ${data.designManagementData!.executionStrategy.name}',
        if (data.designManagementData != null &&
            data.designManagementData!.applicableStandards.isNotEmpty)
          'Standards: ${data.designManagementData!.applicableStandards.join(', ')}',
      ].where((value) => value.isNotEmpty).join('\n'),
      designVendorContractInputs: [
        if (data.frontEndPlanning.contracts.trim().isNotEmpty)
          'Contracts: ${data.frontEndPlanning.contracts.trim()}',
        if (data.frontEndPlanning.contractVendorQuotes.trim().isNotEmpty)
          'Vendor Quotes: ${data.frontEndPlanning.contractVendorQuotes.trim()}',
        if (data.frontEndPlanning.procurement.trim().isNotEmpty)
          'Procurement: ${data.frontEndPlanning.procurement.trim()}',
        if (data.contractors.isNotEmpty)
          'Contractors: ${data.contractors.map((item) => item.name.trim()).where((value) => value.isNotEmpty).join(', ')}',
        if (data.vendors.isNotEmpty)
          'Vendors: ${data.vendors.map((item) => item.name.trim()).where((value) => value.isNotEmpty).join(', ')}',
      ].where((value) => value.isNotEmpty).join('\n\n'),
      designInterfacesAndConstraints: [
        if (data.interfaceEntries.isNotEmpty)
          'Interfaces: ${data.interfaceEntries.map((item) => item.boundary.trim()).where((value) => value.isNotEmpty).join(', ')}',
        ...data.constraintItems
            .map((item) => item.description.trim())
            .where((value) => value.isNotEmpty)
            .take(5)
            .map((value) => 'Constraint: $value'),
        ...data.assumptionItems
            .map((item) => item.description.trim())
            .where((value) => value.isNotEmpty)
            .take(5)
            .map((value) => 'Assumption: $value'),
      ].where((value) => value.isNotEmpty).join('\n'),
      objectives: [
        if (data.projectObjective.trim().isNotEmpty)
          data.projectObjective.trim(),
        ...goals,
      ].join('\n'),
      successCriteria: successCriteria.join('\n'),
      scope: data.withinScopeItems
          .map((item) => item.description.trim())
          .where((value) => value.isNotEmpty)
          .join('\n'),
      outOfScope: data.outOfScopeItems
          .map((item) => item.description.trim())
          .where((value) => value.isNotEmpty)
          .join('\n'),
      architectureSummary: data.frontEndPlanning.infrastructure.trim(),
      uiUxSummary: data.frontEndPlanning.summary.trim(),
      designSystemNotes: data.frontEndPlanning.requirementsNotes.trim(),
      technicalFrontend: data.frontEndPlanning.technology.trim(),
      technicalBackend: data.technologyDefinitions
          .map((item) => item['name']?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .join(', '),
      technicalData: data.notes.trim(),
      validationSummary: data.planningRequirementsNotes.trim().isNotEmpty
          ? data.planningRequirementsNotes.trim()
          : frameworkValidation,
      governanceNotes: data.designDeliverablesData.approvals.isNotEmpty
          ? data.designDeliverablesData.approvals.join('\n')
          : governanceSeed,
      requirements: requirementFallback,
      specifications: specificationsSeed,
      specificationDocuments: specificationDocumentSeed,
      constraints: _splitLines([
        data.charterConstraints,
        ...data.constraintItems.map((item) => item.description),
      ].join('\n')),
      assumptions: _splitLines([
        data.charterAssumptions,
        ...data.assumptionItems.map((item) => item.description),
      ].join('\n')),
      risks: riskSeed,
      dependencies: dependencySeed,
      approvals: approvalSeed,
      modules:
          deliverableModules.isNotEmpty ? deliverableModules : frameworkModules,
    );
  }

  factory DesignPlanningDocument.fromJson(Map<String, dynamic> json) {
    return DesignPlanningDocument(
      version: json['version']?.toString() ?? 'v1.0',
      status: json['status']?.toString() ?? 'Draft',
      overviewSummary: json['overviewSummary']?.toString() ?? '',
      designWhoAndOwnership: json['designWhoAndOwnership']?.toString() ?? '',
      designExecutionApproach:
          json['designExecutionApproach']?.toString() ?? '',
      designVendorContractInputs:
          json['designVendorContractInputs']?.toString() ?? '',
      designInterfacesAndConstraints:
          json['designInterfacesAndConstraints']?.toString() ?? '',
      objectives: json['objectives']?.toString() ?? '',
      successCriteria: json['successCriteria']?.toString() ?? '',
      scope: json['scope']?.toString() ?? '',
      outOfScope: json['outOfScope']?.toString() ?? '',
      architectureSummary: json['architectureSummary']?.toString() ?? '',
      diagramReference: json['diagramReference']?.toString() ?? '',
      dataFlowSummary: json['dataFlowSummary']?.toString() ?? '',
      uiUxSummary: json['uiUxSummary']?.toString() ?? '',
      designSystemNotes: json['designSystemNotes']?.toString() ?? '',
      technicalFrontend: json['technicalFrontend']?.toString() ?? '',
      technicalBackend: json['technicalBackend']?.toString() ?? '',
      technicalData: json['technicalData']?.toString() ?? '',
      validationSummary: json['validationSummary']?.toString() ?? '',
      governanceNotes: json['governanceNotes']?.toString() ?? '',
      specConfigUnifiedTable: _readBool(
        json['specConfigUnifiedTable'],
        fallback: true,
      ),
      specConfigAllowNoLink: _readBool(
        json['specConfigAllowNoLink'],
        fallback: true,
      ),
      specConfigEnableFileUpload: _readBool(
        json['specConfigEnableFileUpload'],
        fallback: true,
      ),
      specConfigSectionApproval: _readBool(
        json['specConfigSectionApproval'],
        fallback: true,
      ),
      specConfigGateProgression: _readBool(
        json['specConfigGateProgression'],
        fallback: true,
      ),
      lastUpdatedIso: json['lastUpdatedIso']?.toString() ?? '',
      requirements: (json['requirements'] as List?)
              ?.map((item) => DesignRequirementMapping.fromJson(
                  item as Map<String, dynamic>))
              .toList() ??
          [],
      specifications: (json['specifications'] as List?)
              ?.map((item) => DesignSpecificationPlanRow.fromJson(
                  item as Map<String, dynamic>))
              .toList() ??
          [],
      deviations: (json['deviations'] as List?)
              ?.map((item) => DesignSpecificationDeviation.fromJson(
                  item as Map<String, dynamic>))
              .toList() ??
          [],
      specificationDocuments: (json['specificationDocuments'] as List?)
              ?.map((item) => DesignPlanningReferenceDoc.fromJson(
                  item as Map<String, dynamic>))
              .toList() ??
          [],
      modules: (json['modules'] as List?)
              ?.map((item) =>
                  DesignPlanningWorkItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      journeys: (json['journeys'] as List?)
              ?.map((item) =>
                  DesignPlanningWorkItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      interfaces: (json['interfaces'] as List?)
              ?.map((item) =>
                  DesignPlanningWorkItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      integrations: (json['integrations'] as List?)
              ?.map((item) =>
                  DesignPlanningWorkItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      constraints: (json['constraints'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          [],
      assumptions: (json['assumptions'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          [],
      risks: (json['risks'] as List?)
              ?.map((item) =>
                  DesignRiskEntry.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      dependencies: (json['dependencies'] as List?)
              ?.map((item) =>
                  DesignDependencyEntry.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      decisions: (json['decisions'] as List?)
              ?.map((item) =>
                  DesignDecisionEntry.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      approvals: (json['approvals'] as List?)
              ?.map((item) =>
                  DesignApprovalEntry.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'status': status,
        'overviewSummary': overviewSummary,
        'designWhoAndOwnership': designWhoAndOwnership,
        'designExecutionApproach': designExecutionApproach,
        'designVendorContractInputs': designVendorContractInputs,
        'designInterfacesAndConstraints': designInterfacesAndConstraints,
        'objectives': objectives,
        'successCriteria': successCriteria,
        'scope': scope,
        'outOfScope': outOfScope,
        'architectureSummary': architectureSummary,
        'diagramReference': diagramReference,
        'dataFlowSummary': dataFlowSummary,
        'uiUxSummary': uiUxSummary,
        'designSystemNotes': designSystemNotes,
        'technicalFrontend': technicalFrontend,
        'technicalBackend': technicalBackend,
        'technicalData': technicalData,
        'validationSummary': validationSummary,
        'governanceNotes': governanceNotes,
        'specConfigUnifiedTable': specConfigUnifiedTable,
        'specConfigAllowNoLink': specConfigAllowNoLink,
        'specConfigEnableFileUpload': specConfigEnableFileUpload,
        'specConfigSectionApproval': specConfigSectionApproval,
        'specConfigGateProgression': specConfigGateProgression,
        'lastUpdatedIso': lastUpdatedIso,
        'requirements': requirements.map((item) => item.toJson()).toList(),
        'specifications': specifications.map((item) => item.toJson()).toList(),
        'deviations': deviations.map((item) => item.toJson()).toList(),
        'specificationDocuments':
            specificationDocuments.map((item) => item.toJson()).toList(),
        'modules': modules.map((item) => item.toJson()).toList(),
        'journeys': journeys.map((item) => item.toJson()).toList(),
        'interfaces': interfaces.map((item) => item.toJson()).toList(),
        'integrations': integrations.map((item) => item.toJson()).toList(),
        'constraints': constraints,
        'assumptions': assumptions,
        'risks': risks.map((item) => item.toJson()).toList(),
        'dependencies': dependencies.map((item) => item.toJson()).toList(),
        'decisions': decisions.map((item) => item.toJson()).toList(),
        'approvals': approvals.map((item) => item.toJson()).toList(),
      };

  void touch() {
    lastUpdatedIso = DateTime.now().toIso8601String();
  }

  Map<String, String> toPlanningNotesPatch() {
    final encoded = jsonEncode(toJson());
    return {
      kDesignPlanningDocumentKey: encoded,
      kDesignPlanningSummaryKey: buildOverviewDigest(),
      kDesignPlanningPlanKey: buildExecutionHandoff(),
      kDesignPlanningArchitectureKey: buildArchitectureDigest(),
      kDesignPlanningUiUxKey: buildUiUxDigest(),
      kDesignPlanningTechnicalKey: buildTechnicalDigest(),
      kDesignPlanningValidationKey: validationSummary.trim(),
      kDesignPlanningHandoffKey: buildExecutionHandoff(),
    };
  }

  String buildOverviewDigest() {
    return [
      overviewSummary.trim(),
      if (designWhoAndOwnership.trim().isNotEmpty)
        'Responsibilities\n${designWhoAndOwnership.trim()}',
      if (designExecutionApproach.trim().isNotEmpty)
        'Design Execution Strategy:\n${designExecutionApproach.trim()}',
      if (designVendorContractInputs.trim().isNotEmpty)
        'Vendor & Contract Inputs:\n${designVendorContractInputs.trim()}',
      if (designInterfacesAndConstraints.trim().isNotEmpty)
        'Interfaces & Constraints:\n${designInterfacesAndConstraints.trim()}',
      if (objectives.trim().isNotEmpty) 'Objectives:\n${objectives.trim()}',
      if (successCriteria.trim().isNotEmpty)
        'Success Criteria:\n${successCriteria.trim()}',
    ].where((value) => value.isNotEmpty).join('\n\n');
  }

  String buildArchitectureDigest() {
    return [
      architectureSummary.trim(),
      if (modules.isNotEmpty)
        'Modules: ${modules.map((item) => item.name).where((value) => value.trim().isNotEmpty).join(', ')}',
      if (dataFlowSummary.trim().isNotEmpty)
        'Data Flow:\n${dataFlowSummary.trim()}',
    ].where((value) => value.isNotEmpty).join('\n\n');
  }

  String buildUiUxDigest() {
    return [
      uiUxSummary.trim(),
      if (journeys.isNotEmpty)
        'Journeys: ${journeys.map((item) => item.name).where((value) => value.trim().isNotEmpty).join(', ')}',
      if (interfaces.isNotEmpty)
        'Interfaces: ${interfaces.map((item) => item.name).where((value) => value.trim().isNotEmpty).join(', ')}',
      if (designSystemNotes.trim().isNotEmpty)
        'Design System:\n${designSystemNotes.trim()}',
    ].where((value) => value.isNotEmpty).join('\n\n');
  }

  String buildTechnicalDigest() {
    return [
      if (technicalFrontend.trim().isNotEmpty)
        'Frontend:\n${technicalFrontend.trim()}',
      if (technicalBackend.trim().isNotEmpty)
        'Backend:\n${technicalBackend.trim()}',
      if (technicalData.trim().isNotEmpty) 'Data:\n${technicalData.trim()}',
      if (integrations.isNotEmpty)
        'Integrations: ${integrations.map((item) => item.name).where((value) => value.trim().isNotEmpty).join(', ')}',
    ].where((value) => value.isNotEmpty).join('\n\n');
  }

  String buildExecutionHandoff() {
    return [
      if (requirements.isNotEmpty)
        'Mapped Requirements: ${requirements.where((item) => item.requirementText.trim().isNotEmpty).length}',
      if (modules.isNotEmpty)
        'Architecture Modules: ${modules.where((item) => item.name.trim().isNotEmpty).length}',
      if (journeys.isNotEmpty)
        'UI/UX Journeys: ${journeys.where((item) => item.name.trim().isNotEmpty).length}',
      if (integrations.isNotEmpty)
        'Technical Integrations: ${integrations.where((item) => item.name.trim().isNotEmpty).length}',
      if (approvals.isNotEmpty)
        'Approval Gates: ${approvals.where((item) => item.reviewer.trim().isNotEmpty).length}',
      if (validationSummary.trim().isNotEmpty) validationSummary.trim(),
    ].where((value) => value.isNotEmpty).join('\n');
  }

  List<PlanningRequirementItem> toPlanningRequirementItems() {
    return requirements
        .where(
          (item) =>
              item.requirementId.trim().isNotEmpty ||
              item.requirementText.trim().isNotEmpty ||
              item.designResponse.trim().isNotEmpty,
        )
        .map(
          (item) => PlanningRequirementItem(
            id: item.requirementId.trim().isEmpty
                ? item.localId
                : item.requirementId.trim(),
            sourceRequirementIds: item.requirementId.trim().isEmpty
                ? []
                : [item.requirementId.trim()],
            plannedText: item.designResponse.trim(),
            priority: item.designArea.trim(),
            owner: item.owner.trim(),
            acceptanceCriteria: item.acceptanceCriteria.trim(),
            verificationMethod: item.linkedArtifact.trim().isNotEmpty
                ? item.linkedArtifact.trim()
                : item.verificationMethod.trim(),
            status: item.status.trim().isEmpty ? 'Draft' : item.status.trim(),
            notes: item.requirementText.trim(),
          ),
        )
        .toList();
  }

  DesignDeliverablesData toDesignDeliverablesData(
      DesignDeliverablesData current) {
    final register = requirements
        .where((item) => item.designResponse.trim().isNotEmpty)
        .map(
          (item) => DesignDeliverableRegisterItem(
            name: item.designResponse.trim(),
            owner: item.owner.trim(),
            status: item.status.trim(),
            due: '',
            risk: item.designArea.trim(),
          ),
        )
        .toList();

    final approved = approvals
        .where((item) => item.status.toLowerCase() == 'approved')
        .length;
    final inReview = approvals
        .where((item) => item.status.toLowerCase() == 'in review')
        .length;
    final atRisk =
        risks.where((item) => item.status.toLowerCase() == 'open').length;

    return current.copyWith(
      approvals: approvals
          .where((item) => item.reviewer.trim().isNotEmpty)
          .map((item) => '${item.reviewer} (${item.role}) - ${item.status}')
          .toList(),
      dependencies: dependencies
          .where((item) => item.name.trim().isNotEmpty)
          .map((item) => item.name.trim())
          .toList(),
      handoffChecklist: _splitLines(validationSummary),
      register: register,
      metrics: DesignDeliverablesMetrics(
        active: register
            .where((item) => item.status.toLowerCase() == 'active')
            .length,
        inReview: inReview,
        approved: approved,
        atRisk: atRisk,
      ),
    );
  }

  List<PlanningDashboardItem> toScopeItems() {
    return _splitLines(scope)
        .map((value) => PlanningDashboardItem(description: value))
        .toList();
  }

  List<PlanningDashboardItem> toOutOfScopeItems() {
    return _splitLines(outOfScope)
        .map((value) => PlanningDashboardItem(description: value))
        .toList();
  }

  List<PlanningDashboardItem> toConstraintItems() {
    return constraints
        .where((value) => value.trim().isNotEmpty)
        .map((value) => PlanningDashboardItem(description: value.trim()))
        .toList();
  }

  List<PlanningDashboardItem> toAssumptionItems() {
    return assumptions
        .where((value) => value.trim().isNotEmpty)
        .map((value) => PlanningDashboardItem(description: value.trim()))
        .toList();
  }

  Map<String, String> toRiskMitigationPlans() {
    final output = <String, String>{};
    for (final risk in risks) {
      final name = risk.risk.trim();
      final mitigation = risk.mitigation.trim();
      if (name.isEmpty || mitigation.isEmpty) continue;
      output[name] = mitigation;
    }
    return output;
  }

  static List<String> _splitLines(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static List<DesignPlanningWorkItem> _seedModulesByFramework(
      String frameworkLower) {
    if (frameworkLower == 'agile') {
      return [
        DesignPlanningWorkItem(
          name: 'MVP Increment Design',
          purpose: 'Define sprint-ready architecture slices for MVP delivery',
          owner: 'Architecture Lead',
          status: 'Planned',
        ),
        DesignPlanningWorkItem(
          name: 'Backlog Design Refinement',
          purpose: 'Refine design detail per sprint cadence and review',
          owner: 'Product + Design',
          status: 'Planned',
        ),
      ];
    }
    if (frameworkLower == 'hybrid') {
      return [
        DesignPlanningWorkItem(
          name: 'Baseline Architecture Package',
          purpose: 'Define fixed core architecture and governance controls',
          owner: 'Architecture Lead',
          status: 'Planned',
        ),
        DesignPlanningWorkItem(
          name: 'Iterative Feature Design Stream',
          purpose: 'Plan incremental design updates for evolving scope',
          owner: 'Product + Engineering',
          status: 'Planned',
        ),
      ];
    }
    return [
      DesignPlanningWorkItem(
        name: 'Detailed System Design Baseline',
        purpose: 'Finalize complete design baseline before build execution',
        owner: 'Engineering Design Lead',
        status: 'Planned',
      ),
      DesignPlanningWorkItem(
        name: 'Design Sign-off Package',
        purpose: 'Consolidate reviews and approvals for phase-gate release',
        owner: 'PM + Governance',
        status: 'Planned',
      ),
    ];
  }

  static String _seedValidationByFramework(String frameworkLower) {
    if (frameworkLower == 'agile') {
      return [
        'Validate design acceptance criteria in each sprint review.',
        'Use incremental prototype feedback to confirm usability and fit.',
        'Review architectural impacts at sprint planning and retro checkpoints.',
      ].join('\n');
    }
    if (frameworkLower == 'hybrid') {
      return [
        'Validate baseline architecture at phase gates.',
        'Validate evolving feature designs during iteration cycles.',
        'Confirm traceability between gate approvals and sprint outcomes.',
      ].join('\n');
    }
    return [
      'Complete full design verification before build starts.',
      'Confirm requirements-to-design traceability for all scoped items.',
      'Obtain governance sign-off on architecture, UX, and technical specs.',
    ].join('\n');
  }

  static String _seedGovernanceByFramework(String frameworkLower) {
    if (frameworkLower == 'agile') {
      return 'Governance cadence: Sprint-level design reviews with rolling approvals.';
    }
    if (frameworkLower == 'hybrid') {
      return 'Governance cadence: Phase-gate approvals plus iteration-level design checkpoints.';
    }
    return 'Governance cadence: Formal phase-gate review and sign-off before execution.';
  }

  static bool _readBool(dynamic raw, {required bool fallback}) {
    if (raw is bool) return raw;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return fallback;
  }

  static String _inferSpecificationType(
    PlanningRequirementItem item,
    ProjectDataModel data, {
    required String fallback,
  }) {
    final sourceType = _inferSpecificationSourceType(item, data);
    if (sourceType == 'Regulatory') return 'Law';
    if (sourceType == 'Contracts' || sourceType == 'Vendors') {
      return 'Criteria';
    }

    final haystack = '${item.priority} ${item.notes} ${item.verificationMethod}'
        .toLowerCase();
    if (haystack.contains('code')) return 'Code';
    if (haystack.contains('law') ||
        haystack.contains('legal') ||
        haystack.contains('statut')) {
      return 'Law';
    }
    if (haystack.contains('criterion') || haystack.contains('criteria')) {
      return 'Criteria';
    }
    return fallback;
  }

  static String _inferSpecificationSourceType(
    PlanningRequirementItem item,
    ProjectDataModel data,
  ) {
    final haystack = '${item.priority} ${item.notes} ${item.verificationMethod}'
        .toLowerCase();
    if (haystack.contains('regulat') || haystack.contains('compliance')) {
      return 'Regulatory';
    }
    if (haystack.contains('contract') || haystack.contains('procurement')) {
      return 'Contracts';
    }
    if (haystack.contains('vendor') || haystack.contains('supplier')) {
      return 'Vendors';
    }
    if (haystack.contains('standard') || haystack.contains('iso')) {
      return 'Standards';
    }
    if (data.frontEndPlanning.contracts.trim().isNotEmpty) {
      return 'Contracts';
    }
    return 'Standards';
  }
}

class DesignRequirementMapping {
  DesignRequirementMapping({
    String? localId,
    this.requirementId = '',
    this.requirementText = '',
    this.designResponse = '',
    this.designArea = '',
    this.owner = '',
    this.status = 'Draft',
    this.linkedArtifact = '',
    this.acceptanceCriteria = '',
    this.verificationMethod = '',
  }) : localId = localId ?? _nextUniqueId();

  final String localId;
  String requirementId;
  String requirementText;
  String designResponse;
  String designArea;
  String owner;
  String status;
  String linkedArtifact;
  String acceptanceCriteria;
  String verificationMethod;

  factory DesignRequirementMapping.fromRequirementItem(RequirementItem item) {
    return DesignRequirementMapping(
      requirementId: item.id.trim(),
      requirementText: item.description.trim(),
      owner:
          item.person.trim().isNotEmpty ? item.person.trim() : item.role.trim(),
      designArea: item.discipline.trim(),
    );
  }

  factory DesignRequirementMapping.fromPlanningItem(
    PlanningRequirementItem item,
    ProjectDataModel data,
  ) {
    final sourceId = item.sourceRequirementIds.isNotEmpty
        ? item.sourceRequirementIds.first
        : item.id;
    final sourceRequirement = data.frontEndPlanning.requirementItems
        .where((entry) => entry.id.trim() == sourceId.trim())
        .cast<RequirementItem?>()
        .firstWhere((entry) => entry != null, orElse: () => null);
    return DesignRequirementMapping(
      requirementId: sourceId,
      requirementText:
          sourceRequirement?.description.trim() ?? item.notes.trim(),
      designResponse: item.plannedText.trim(),
      designArea: item.priority.trim(),
      owner: item.owner.trim(),
      status: item.status.trim().isEmpty ? 'Draft' : item.status.trim(),
      linkedArtifact: item.verificationMethod.trim(),
      acceptanceCriteria: item.acceptanceCriteria.trim(),
      verificationMethod: item.verificationMethod.trim(),
    );
  }

  factory DesignRequirementMapping.fromJson(Map<String, dynamic> json) {
    return DesignRequirementMapping(
      localId: json['localId']?.toString(),
      requirementId: json['requirementId']?.toString() ?? '',
      requirementText: json['requirementText']?.toString() ?? '',
      designResponse: json['designResponse']?.toString() ?? '',
      designArea: json['designArea']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Draft',
      linkedArtifact: json['linkedArtifact']?.toString() ?? '',
      acceptanceCriteria: json['acceptanceCriteria']?.toString() ?? '',
      verificationMethod: json['verificationMethod']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'requirementId': requirementId,
        'requirementText': requirementText,
        'designResponse': designResponse,
        'designArea': designArea,
        'owner': owner,
        'status': status,
        'linkedArtifact': linkedArtifact,
        'acceptanceCriteria': acceptanceCriteria,
        'verificationMethod': verificationMethod,
      };
}

class DesignPlanningWorkItem {
  DesignPlanningWorkItem({
    String? id,
    this.name = '',
    this.purpose = '',
    this.owner = '',
    this.status = 'Draft',
  }) : id = id ?? _nextUniqueId();

  final String id;
  String name;
  String purpose;
  String owner;
  String status;

  factory DesignPlanningWorkItem.fromJson(Map<String, dynamic> json) {
    return DesignPlanningWorkItem(
      id: _nonEmptyId(json['id']?.toString()),
      name: json['name']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Draft',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'purpose': purpose,
        'owner': owner,
        'status': status,
      };
}

class DesignSpecificationPlanRow {
  DesignSpecificationPlanRow({
    String? id,
    this.title = '',
    this.details = '',
    this.specificationType = 'Standard',
    this.discipline = '',
    this.area = '',
    List<String>? attachedRequirementIds,
    this.ruleType = 'Internal',
    this.sourceType = 'Standards',
    this.owner = '',
    this.status = 'Draft',
    this.referenceLink = '',
    this.wbsWorkPackageId = '',
    this.wbsWorkPackageTitle = '',
    this.uploadedFileName = '',
    this.uploadedStoragePath = '',
  })  : id = id ?? _nextSpecRowId(),
        attachedRequirementIds = attachedRequirementIds ?? [];

  final String id;
  String title;
  String details;
  String specificationType;
  String discipline;
  String area;
  List<String> attachedRequirementIds;
  String ruleType;
  String sourceType;
  String owner;
  String status;
  String referenceLink;
  String wbsWorkPackageId;
  String wbsWorkPackageTitle;
  String uploadedFileName;
  String uploadedStoragePath;

  factory DesignSpecificationPlanRow.fromJson(Map<String, dynamic> json) {
    final legacyDisciplineArea = json['disciplineArea']?.toString().trim() ??
        json['designArea']?.toString().trim() ??
        '';
    final parsedLegacy = _parseLegacyDisciplineArea(legacyDisciplineArea);
    return DesignSpecificationPlanRow(
      id: _nonEmptyId(json['id']?.toString()),
      title: json['title']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      specificationType: json['specificationType']?.toString() ??
          json['type']?.toString() ??
          'Standard',
      discipline: json['discipline']?.toString() ??
          parsedLegacy.$1 ??
          legacyDisciplineArea,
      area: json['area']?.toString() ??
          json['designArea']?.toString() ??
          parsedLegacy.$2 ??
          '',
      attachedRequirementIds: (json['attachedRequirementIds'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          (json['requirementIds'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      ruleType: json['ruleType']?.toString() ?? 'Internal',
      sourceType: json['sourceType']?.toString() ?? 'Standards',
      owner: json['owner']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Draft',
      referenceLink: json['referenceLink']?.toString() ?? '',
      wbsWorkPackageId: json['wbsWorkPackageId']?.toString() ??
          json['workPackageId']?.toString() ??
          '',
      wbsWorkPackageTitle: json['wbsWorkPackageTitle']?.toString() ??
          json['workPackageTitle']?.toString() ??
          '',
      uploadedFileName: json['uploadedFileName']?.toString() ?? '',
      uploadedStoragePath: json['uploadedStoragePath']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'details': details,
        'specificationType': specificationType,
        'discipline': discipline,
        'area': area,
        // Keep legacy key for backward compatibility with old readers.
        'disciplineArea': [discipline.trim(), area.trim()]
            .where((item) => item.isNotEmpty)
            .join(' / '),
        'attachedRequirementIds': attachedRequirementIds,
        'ruleType': ruleType,
        'sourceType': sourceType,
        'owner': owner,
        'status': status,
        'referenceLink': referenceLink,
        'wbsWorkPackageId': wbsWorkPackageId,
        'wbsWorkPackageTitle': wbsWorkPackageTitle,
        'uploadedFileName': uploadedFileName,
        'uploadedStoragePath': uploadedStoragePath,
      };

  static (String?, String?) _parseLegacyDisciplineArea(String raw) {
    if (raw.trim().isEmpty) return (null, null);
    final parts = raw
        .split(RegExp(r'\s*(/|\\||>|->)\s*'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.length < 2) return (raw.trim(), null);
    return (parts.first, parts.sublist(1).join(' / '));
  }
}

class DesignSpecificationDeviation {
  DesignSpecificationDeviation({
    String? id,
    this.specificationId = '',
    this.description = '',
  }) : id = id ?? _nextUniqueId();

  final String id;
  String specificationId;
  String description;

  factory DesignSpecificationDeviation.fromJson(Map<String, dynamic> json) {
    return DesignSpecificationDeviation(
      id: _nonEmptyId(json['id']?.toString()),
      specificationId: json['specificationId']?.toString() ??
          json['linkedSpecificationId']?.toString() ??
          '',
      description: json['description']?.toString() ??
          json['deviationText']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'specificationId': specificationId,
        'description': description,
      };
}

class DesignPlanningReferenceDoc {
  DesignPlanningReferenceDoc({
    String? id,
    this.title = '',
    this.category = 'Standards',
    List<String>? attachedRequirementIds,
    this.link = '',
    this.fileName = '',
    this.storagePath = '',
    this.notes = '',
  })  : id = id ?? _nextUniqueId(),
        attachedRequirementIds = attachedRequirementIds ?? [];

  final String id;
  String title;
  String category;
  List<String> attachedRequirementIds;
  String link;
  String fileName;
  String storagePath;
  String notes;

  factory DesignPlanningReferenceDoc.fromJson(Map<String, dynamic> json) {
    return DesignPlanningReferenceDoc(
      id: _nonEmptyId(json['id']?.toString()),
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Standards',
      attachedRequirementIds: (json['attachedRequirementIds'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          (json['requirementIds'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      link: json['link']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      storagePath: json['storagePath']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'attachedRequirementIds': attachedRequirementIds,
        'link': link,
        'fileName': fileName,
        'storagePath': storagePath,
        'notes': notes,
      };
}

class DesignRiskEntry {
  DesignRiskEntry({
    String? id,
    this.risk = '',
    this.impact = '',
    this.likelihood = '',
    this.mitigation = '',
    this.owner = '',
    this.status = 'Open',
  }) : id = id ?? _nextUniqueId();

  final String id;
  String risk;
  String impact;
  String likelihood;
  String mitigation;
  String owner;
  String status;

  factory DesignRiskEntry.fromRiskRegisterItem(RiskRegisterItem item) {
    return DesignRiskEntry(
      risk: item.riskName.trim(),
      impact: item.impactLevel.trim(),
      likelihood: item.likelihood.trim(),
      mitigation: item.mitigationStrategy.trim(),
      owner: item.owner.trim(),
      status: item.status.trim().isEmpty ? 'Open' : item.status.trim(),
    );
  }

  factory DesignRiskEntry.fromJson(Map<String, dynamic> json) {
    return DesignRiskEntry(
      id: _nonEmptyId(json['id']?.toString()),
      risk: json['risk']?.toString() ?? '',
      impact: json['impact']?.toString() ?? '',
      likelihood: json['likelihood']?.toString() ?? '',
      mitigation: json['mitigation']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Open',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'risk': risk,
        'impact': impact,
        'likelihood': likelihood,
        'mitigation': mitigation,
        'owner': owner,
        'status': status,
      };
}

class DesignDependencyEntry {
  DesignDependencyEntry({
    String? id,
    this.name = '',
    this.type = '',
    this.source = '',
    this.neededBy = '',
    this.owner = '',
    this.status = 'Planned',
    this.notes = '',
  }) : id = id ?? _nextUniqueId();

  final String id;
  String name;
  String type;
  String source;
  String neededBy;
  String owner;
  String status;
  String notes;

  factory DesignDependencyEntry.fromJson(Map<String, dynamic> json) {
    return DesignDependencyEntry(
      id: _nonEmptyId(json['id']?.toString()),
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      neededBy: json['neededBy']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Planned',
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'source': source,
        'neededBy': neededBy,
        'owner': owner,
        'status': status,
        'notes': notes,
      };
}

class DesignDecisionEntry {
  DesignDecisionEntry({
    String? id,
    this.decision = '',
    this.rationale = '',
    this.alternatives = '',
    this.owner = '',
    this.date = '',
    this.status = 'Open',
  }) : id = id ?? _nextUniqueId();

  final String id;
  String decision;
  String rationale;
  String alternatives;
  String owner;
  String date;
  String status;

  factory DesignDecisionEntry.fromJson(Map<String, dynamic> json) {
    return DesignDecisionEntry(
      id: _nonEmptyId(json['id']?.toString()),
      decision: json['decision']?.toString() ?? '',
      rationale: json['rationale']?.toString() ?? '',
      alternatives: json['alternatives']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Open',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'decision': decision,
        'rationale': rationale,
        'alternatives': alternatives,
        'owner': owner,
        'date': date,
        'status': status,
      };
}

class DesignApprovalEntry {
  DesignApprovalEntry({
    String? id,
    this.reviewer = '',
    this.role = '',
    this.status = 'Pending',
    this.comment = '',
  }) : id = id ?? _nextUniqueId();

  final String id;
  String reviewer;
  String role;
  String status;
  String comment;

  factory DesignApprovalEntry.fromJson(Map<String, dynamic> json) {
    return DesignApprovalEntry(
      id: _nonEmptyId(json['id']?.toString()),
      reviewer: json['reviewer']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      comment: json['comment']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reviewer': reviewer,
        'role': role,
        'status': status,
        'comment': comment,
      };
}
