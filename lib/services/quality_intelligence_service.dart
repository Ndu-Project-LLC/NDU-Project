import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/quality_metrics_calculator.dart';
import 'package:ndu_project/models/acceptance_criteria.dart';

/// Quality Intelligence Service
/// 
/// Provides AI-powered quality management intelligence for the KAZ AI assistant.
/// Analyzes project data to identify gaps, risks, and recommend improvements
/// with full best-practice rationale.
class QualityIntelligenceService {
  // ── Quality Standards Database ──────────────────────────────────────────
  
  static const Map<String, List<String>> _standardsByIndustry = {
    'software': [
      'ISO/IEC 25010 - Software Quality Model (SQuaRE)',
      'ISO/IEC 25012 - Data Quality',
      'ISO/IEC 29119 - Software Testing',
      'IEEE 829 - Test Documentation',
      'CMMI-DEV Maturity Levels 2-5',
      'ISTQB Software Testing Standards',
      'OWASP Top 10 Security Standards',
      'PCI-DSS (if payment handling)',
      'GDPR Compliance (if EU data)',
      'SOC 2 Type II Controls',
    ],
    'construction': [
      'ISO 9001:2015 - Quality Management Systems',
      'ISO 45001 - Occupational Health & Safety',
      'ISO 14001 - Environmental Management',
      'ACI 318 - Building Code Requirements',
      'AISC 360 - Structural Steel Buildings',
      'ASHRAE Standards - HVAC Systems',
      'NEC - Electrical Installation',
      'LEED Certification Requirements',
      'OSHA Construction Standards',
      'Six Sigma Process Control',
    ],
    'healthcare': [
      'ISO 13485 - Medical Device QMS',
      'FDA 21 CFR Part 820 - Medical Devices',
      'HIPAA Privacy & Security Rules',
      'Joint Commission Standards',
      'GxP / GMP Manufacturing',
      'IEC 62304 - Medical Device Software',
      'HL7 FHIR Interoperability',
      'Clinical Data Interchange Standards',
      'CAP Accreditation Requirements',
      'Patient Safety Goals (NPSG)',
    ],
    'manufacturing': [
      'IATF 16949 - Automotive QMS',
      'ISO/TS 16949 - Quality Management',
      'AS9100D - Aerospace Quality',
      'Six Sigma DMAIC Methodology',
      'TPM - Total Productive Maintenance',
      '5S Workplace Organization',
      'SPC - Statistical Process Control',
      'FMEA - Failure Mode Effects Analysis',
      'PPAP - Production Part Approval',
      'MSA - Measurement System Analysis',
    ],
    'finance': [
      'SOX - Sarbanes-Oxley Compliance',
      'Basel III/IV Banking Regulations',
      'PCI-DSS Payment Security',
      'GDPR Data Protection',
      'COBIT IT Governance Framework',
      'ISO 27001 Information Security',
      'NERC CIP Critical Infrastructure',
      'FINRA Compliance Rules',
      'AML/KYC Anti-Money Laundering',
      'CCPA Consumer Privacy (California)',
    ],
    'energy': [
      'ISO 50001 - Energy Management',
      'OSHA PSM - Process Safety Management',
      'API Standards (Oil & Gas)',
      'NELEC - Nuclear Electric',
      'IEEE 1471 - Energy Systems',
      'IEC 61850 - Power Automation',
      'NERC Reliability Standards',
      'EPA Clean Air Act Compliance',
      'HSE Management Systems',
      'LOTO Lockout/Tagout Procedures',
    ],
    'default': [
      'ISO 9001:2015 - Quality Management Systems',
      'ISO 10006 - Quality in Projects',
      'PMBOK Quality Management Knowledge Area',
      'PRINCE2 Quality Theme',
      'Six Sigma Methodology',
      'Total Quality Management (TQM)',
      'Plan-Do-Check-Act (PDCA) Cycle',
      'Cost of Quality Framework',
      'Root Cause Analysis Methods',
      'Continuous Improvement (Kaizen)',
    ],
  };

  static const Map<String, List<String>> _activitiesByProjectType = {
    'waterfall': [
      'Requirements Reviews (Phase Gate)',
      'Design Inspections & Walkthroughs',
      'Code/Document Peer Reviews',
      'Unit Testing with Coverage Metrics',
      'Integration Test Planning & Execution',
      'System Testing (Functional/Non-functional)',
      'User Acceptance Testing (UAT)',
      'Regression Testing Suites',
      'Performance/Load Testing',
      'Security Penetration Testing',
      'Test Traceability Matrix Maintenance',
      'Defect Triage & Root Cause Analysis',
      'Quality Gates at Phase Boundaries',
      'Configuration Audits',
      'Documentation Reviews',
    ],
    'agile': [
      'Definition of Done (DoD) Enforcement',
      'Sprint Backlog Refinement (Grooming)',
      'Pair Programming Sessions',
      'Code Review / Pull Request Process',
      'Automated Unit Testing (TDD/BDD)',
      'Continuous Integration (CI) Pipelines',
      'Automated Regression Suites',
      'Sprint Retrospectives (Quality Focus)',
      'Story Acceptance Criteria Validation',
      'Technical Debt Tracking & Reduction',
      'Definition of Ready (DoR) Checks',
      'Burndown Chart Quality Metrics',
      'Velocity Stability Monitoring',
      'Spike/Research Quality Outputs',
      'Increment Demonstrations',
    ],
    'hybrid': [
      'Phase-Based Quality Gates with Agile Sprints',
      'Release Train Integration Testing',
      'Architecture Decision Records (ADR) Review',
      'Cross-Team Coordination Quality Checks',
      'Dependency Risk Assessments',
      'Integration Points Validation',
      'Feature Flag Quality Assurance',
      'Environment Parity Verification',
      'Rollback Procedure Testing',
      'Compliance Checkpoint Audits',
    ],
    'default': [
      'Stakeholder Requirement Sign-off',
      'Deliverable Quality Checklists',
      'Peer Review Processes',
      'Testing Strategy Development',
      'Risk-Based Testing Prioritization',
      'Issue Escalation Procedures',
      'Lessons Learned Capture',
      'Continuous Improvement Workshops',
      'Supplier/Vendor Quality Audits',
      'Customer Feedback Loops',
    ],
  };

  // ── Analysis Methods ───────────────────────────────────────────────────

  /// Generate comprehensive quality intelligence analysis
  /// Returns structured recommendations with rationale
  static QualityIntelligenceReport generateFullReport({
    required ProjectDataModel projectData,
    required QualityManagementData qualityData,
  }) {
    final report = QualityIntelligenceReport(
      generatedAt: DateTime.now(),
      projectName: projectData.projectName ?? 'Untitled Project',
      projectType: _resolveProjectType(projectData),
      industry: projectData.projectIndustry?.toLowerCase() ?? 'default',
      methodology: _resolveMethodology(projectData),
    );

    // Run all analyses
    report.missingRequirements = _identifyMissingRequirements(projectData, qualityData);
    report.recommendedActivities = _recommendActivities(projectData, qualityData);
    report.recommendedStandards = _recommendStandards(projectData);
    report.acceptanceCriteriaGaps = _detectAcceptanceCriteriaGaps(projectData, qualityData);
    report.qualityRisks = _identifyQualityRisks(projectData, qualityData);
    report.recommendedKpis = _recommendKpis(projectData, qualityData);
    report.reworkSources = _identifyReworkSources(projectData, qualityData);

    return report;
  }

  /// Identify missing quality requirements based on project characteristics
  static List<QualityRecommendation> _identifyMissingRequirements(
    ProjectDataModel projectData,
    QualityManagementData qualityData,
  ) {
    final missing = <QualityRecommendation>[];
    final existingTargets = qualityData.targets.map((t) => t.category.toLowerCase()).toSet();
    final existingObjectives = qualityData.objectives.map((o) => o.area.toLowerCase()).toSet();

    // Check for essential quality target categories
    final requiredCategories = _getRequiredCategories(projectData);
    
    for (final category in requiredCategories) {
      if (!existingTargets.any((e) => e.contains(category.toLowerCase()))) {
        missing.add(QualityRecommendation(
          id: 'missing_target_$category',
          type: RecommendationType.missingRequirement,
          title: 'Missing Quality Target: ${_formatCategory(category)}',
          description: 'Your quality plan lacks specific targets for $_formatCategory(category). '
              'This area is critical for your project type.',
          priority: _getCategoryPriority(category),
          rationale: _getCategoryRationale(category, projectData),
          suggestedAction: "Add a measurable quality target for $category "
              "(e.g., '${_suggestTargetExample(category)}')",
          supportingData: {
            'category': category,
            'existingCategories': existingTargets.toList(),
            'projectType': _resolveProjectType(projectData),
            'industry': projectData.projectIndustry ?? 'Unknown',
          },
        ));
      }
    }

    // Check for missing QA techniques based on project complexity
    if (qualityData.qaTechniques.isEmpty) {
      missing.add(QualityRecommendation(
        id: 'missing_qa_techniques',
        type: RecommendationType.missingRequirement,
        title: 'No QA Techniques Defined',
        description: 'Your quality plan does not specify any Quality Assurance (QA) techniques. '
            'QA techniques are proactive measures to prevent defects.',
        priority: Priority.critical,
        rationale: 'Without defined QA techniques, the team lacks guidance on how to '
            'prevent defects before they occur. Industry data shows that every \$1 spent on '
            'prevention saves \$4-\$10 in correction costs (Cost of Quality principle).',
        suggestedAction: 'Add QA techniques such as peer reviews, code inspections, '
            'requirements walkthroughs, or design reviews based on your project phase.',
        supportingData: {
          'currentQATechniquesCount': '0',
          'recommendedMinimum': _getMinQATechniques(projectData).toString(),
        },
      ));
    }

    // Check for missing QC techniques
    if (qualityData.qcTechniques.isEmpty) {
      missing.add(QualityRecommendation(
        id: 'missing_qc_techniques',
        type: RecommendationType.missingRequirement,
        title: 'No QC Techniques Defined',
        description: 'Your quality plan does not specify any Quality Control (QC) techniques. '
            'QC techniques are reactive measures to detect defects.',
        priority: Priority.critical,
        rationale: 'QC techniques provide the feedback loop needed to verify that '
            'deliverables meet requirements. Without them, defects may reach stakeholders '
            'undetected until late stages when correction is most expensive.',
        suggestedAction: 'Add QC techniques such as testing, inspections, audits, '
            'or reviews tailored to your deliverables.',
        supportingData: {
          'currentQCTechniquesCount': '0',
          'recommendedMinimum': _getMinQCTechniques(projectData).toString(),
        },
      ));
    }

    // Check for empty quality plan
    if (qualityData.qualityPlan.trim().isEmpty || qualityData.qualityPlan.length < 50) {
      missing.add(QualityRecommendation(
        id: 'incomplete_quality_plan',
        type: RecommendationType.missingRequirement,
        title: 'Quality Plan Incomplete or Missing',
        description: 'The quality plan document appears to be minimal or empty. '
            'A comprehensive quality plan is foundational to project success.',
        priority: Priority.critical,
        rationale: 'According to PMBOK 6th Edition and ISO 10006, a quality plan should '
            'define quality policies, objectives, responsibilities, procedures, and resources. '
            'Projects without documented quality plans have 40% higher defect rates (PMI research).',
        suggestedAction: 'Develop a comprehensive quality plan covering: quality policy, '
            'objectives, team responsibilities, key processes, documentation standards, '
            'and measurement criteria.',
        supportingData: {
          'planLength': qualityData.qualityPlan.length.toString(),
          'recommendedLength': '500+ characters',
        },
      ));
    }

    return missing;
  }

  /// Recommend quality activities based on project type and methodology
  static List<QualityRecommendation> _recommendActivities(
    ProjectDataModel projectData,
    QualityManagementData qualityData,
  ) {
    final recommendations = <QualityRecommendation>[];
    final methodology = _resolveMethodology(projectData);
    final currentActivities = <String>{};
    
    for (final technique in [...qualityData.qaTechniques, ...qualityData.qcTechniques]) {
      currentActivities.add(technique.name.toLowerCase());
    }

    final recommendedActivities = _activitiesByProjectType[methodology] ?? 
        _activitiesByProjectType['default']!;

    int recommendedCount = 0;
    for (final activity in recommendedActivities) {
      final activityLower = activity.toLowerCase();
      // Simple matching to see if similar activity exists
      final hasSimilar = currentActivities.any((existing) => 
          _wordsOverlap(activityLower, existing) > 0.3);
      
      if (!hasSimilar && recommendedCount < 5) { // Limit to top 5 new recommendations
        recommendations.add(QualityRecommendation(
          id: 'activity_${activity.hashCode}',
          type: RecommendationType.recommendedActivity,
          title: 'Consider Adding: $activity',
          description: 'This activity is highly recommended for $methodology projects '
              'but was not found in your current quality approach.',
          priority: _isCoreActivity(activity) ? Priority.high : Priority.medium,
          rationale: _getActivityRationale(activity, methodology),
          suggestedAction: 'Add "$activity" to your QA/QC techniques list with clear '
              'ownership, frequency, and expected outcomes.',
          supportingData: {
            'methodology': methodology,
            'activity': activity,
            'similarExisting': currentActivities.where((e) => 
                _wordsOverlap(activityLower, e) > 0.1).toList(),
          },
        ));
        recommendedCount++;
      }
    }

    return recommendations;
  }

  /// Recommend applicable standards based on industry and project type
  static List<QualityRecommendation> _recommendStandards(ProjectDataModel projectData) {
    final recommendations = <QualityRecommendation>[];
    final industry = projectData.projectIndustry?.toLowerCase() ?? 'default';
    final currentStandards = <String>{}; // Would come from qualityData.standards

    final applicableStandards = _standardsByIndustry[industry] ?? 
        _standardsByIndustry['default']!;

    int addedCount = 0;
    for (final standard in applicableStandards) {
      final standardLower = standard.toLowerCase();
      final hasStandard = currentStandards.any((s) => 
          _wordsOverlap(standardLower, s.toLowerCase()) > 0.4);

      if (!hasStandard && addedCount < 4) { // Limit recommendations
        final isCritical = standard.contains('ISO') || standard.contains('FDA') || 
                          standard.contains('SOX') || standard.contains('HIPAA');
        
        recommendations.add(QualityRecommendation(
          id: 'standard_${standard.hashCode}',
          type: RecommendationType.recommendedStandard,
          title: 'Applicable Standard: $standard',
          description: '$standard is relevant to your industry ($industry) and should be '
              'considered for compliance or best-practice alignment.',
          priority: isCritical ? Priority.high : Priority.medium,
          rationale: _getStandardRationale(standard, industry),
          suggestedAction: hasStandard 
              ? 'Review current alignment with $standard'
              : 'Evaluate applicability of $standard and create a compliance gap analysis',
          supportingData: {
            'industry': industry,
            'standard': standard,
            'complianceLevel': 'recommended',
          },
        ));
        addedCount++;
      }
    }

    return recommendations;
  }

  /// Detect gaps in acceptance criteria
  static List<QualityRecommendation> _detectAcceptanceCriteriaGaps(
    ProjectDataModel projectData,
    QualityManagementData qualityData,
  ) {
    final gaps = <QualityRecommendation>[];

    // Analyze acceptance criteria from agile screens if available
    // This would integrate with AcceptanceCriteriaTemplate data
    
    // Common acceptance criteria categories that should be covered
    final criticalCategories = [
      CriterionCategory.functional,
      CriterionCategory.performance,
      CriterionCategory.security,
      CriterionCategory.errorHandling,
      CriterionCategory.compliance,
    ];

    // Check for common gaps
    if (qualityData.objectives.isEmpty) {
      gaps.add(QualityRecommendation(
        id: 'gap_no_quality_objectives',
        type: RecommendationType.acceptanceGap,
        title: 'No Quality Objectives Defined',
        description: 'Quality objectives translate organizational goals into measurable '
            'quality targets. Without them, quality efforts lack direction.',
        priority: Priority.critical,
        rationale: 'ISO 9001:2015 Clause 6.2 requires organizations to establish quality '
            'objectives at relevant functions and levels. SMART quality objectives improve '
            'project success rates by 28% (ASQ research).',
        suggestedAction: 'Define 3-5 SMART quality objectives aligned with project goals. '
            'Examples: "Achieve 95% first-pass yield on code reviews", '
            '"Maintain test coverage above 80%", "Zero critical defects in UAT".',
        supportingData: {
          'objectiveCount': '0',
          'recommendedRange': '3-5',
        },
      ));
    }

    // Check audit plan completeness
    final plannedAudits = qualityData.auditPlan.where((a) => 
        a.plannedDate.isNotEmpty && a.result == AuditResultStatus.pending).length;
    final completedAudits = qualityData.auditPlan.where((a) => 
        a.result != AuditResultStatus.pending && a.result != null).length;

    if (plannedAudits == 0 && completedAudits == 0) {
      gaps.add(QualityRecommendation(
        id: 'gap_no_audit_plan',
        type: RecommendationType.acceptanceGap,
        title: 'No Quality Audit Plan Defined',
        description: 'Audits provide independent assessment of quality process effectiveness. '
            'An audit plan schedules regular quality assessments.',
        priority: Priority.high,
        rationale: 'ISO 9001:2015 Clause 9.2 requires internal audits at planned intervals. '
            'Organizations with regular audit programs detect process deviations 60% earlier '
            '(Quality Progress study).',
        suggestedAction: 'Create an audit plan covering: process audits, product audits, '
            'and supplier audits. Schedule at least quarterly for active projects.',
        supportingData: {
          'plannedAudits': plannedAudits.toString(),
          'completedAudits': completedAudits.toString(),
          'recommendedFrequency': 'Quarterly minimum',
        },
      ));
    }

    // Check for missing review cadence
    if (qualityData.reviewCadence.trim().isEmpty) {
      gaps.add(QualityRecommendation(
        id: 'gap_no_review_cadence',
        type: RecommendationType.acceptanceGap,
        title: 'Quality Review Cadence Not Defined',
        description: 'Regular quality reviews ensure continuous monitoring and early issue detection.',
        priority: Priority.high,
        rationale: 'Projects with defined review cadences have 35% fewer escaped defects '
            '(Capgemini QuEST study). Regular reviews create accountability and feedback loops.',
        suggestedAction: 'Define review cadence for each quality activity: daily standups for '
            'issues, weekly metrics review, monthly quality gate assessments, quarterly audits.',
        supportingData: {
          'reviewCadenceDefined': 'false',
          'recommendedCadence': 'Weekly metrics + Monthly gates + Quarterly audits',
        },
      ));
    }

    // Check task completion patterns for potential gaps
    final allTasks = [...qualityData.qaTaskLog, ...qualityData.qcTaskLog];
    if (allTasks.isNotEmpty) {
      final blockedTasks = allTasks.where((t) => t.status == QualityTaskStatus.blocked).length;
      final notStartedTasks = allTasks.where((t) => t.status == QualityTaskStatus.notStarted).length;
      
      if (blockedTasks > 0) {
        gaps.add(QualityRecommendation(
          id: 'gap_blocked_tasks',
          type: RecommendationType.acceptanceGap,
          title: '$blockedTasks Quality Task(s) Blocked',
          description: 'Blocked quality tasks indicate process impediments that need resolution.',
          priority: blockedTasks > 2 ? Priority.critical : Priority.high,
          rationale: 'Blocked tasks represent waste in the quality process. Each blocked task '
              'delays quality feedback and may mask underlying issues. The average cost of a '
              'blocked quality task is 2.3x the original estimate when finally resolved.',
          suggestedAction: 'Conduct a root cause analysis on blocked tasks. Common causes: '
              'resource constraints, unclear requirements, tool/access issues, dependencies.',
          supportingData: {
            'blockedCount': blockedTasks.toString(),
            'totalTasks': allTasks.length.toString(),
            'blockedPercentage': ((blockedTasks / allTasks.length) * 100).toStringAsFixed(1),
          },
        ));
      }

      if (notStartedTasks > allTasks.length * 0.3) {
        gaps.add(QualityRecommendation(
          id: 'gap_not_started_tasks',
          type: RecommendationType.acceptanceGap,
          title: '${(notStartedTasks * 100 / allTasks.length).round()}% of Quality Tasks Not Started',
          description: 'A significant portion of planned quality activities have not begun.',
          priority: Priority.medium,
          rationale: 'Late-started quality activities compress the testing/verification window, '
              'increasing defect escape risk by up to 45% (IBM Systems Sciences study).',
          suggestedAction: 'Prioritize starting quality tasks early. Consider parallel execution '
              'or phased approach to avoid end-of-project quality crunch.',
          supportingData: {
            'notStartedCount': notStartedTasks.toString(),
            'totalTasks': allTasks.length.toString(),
            'notStartedPercentage': ((notStartedTasks / allTasks.length) * 100).toStringAsFixed(1),
          },
        ));
      }
    }

    return gaps;
  }

  /// Identify quality risks and likely sources of rework
  static List<QualityRecommendation> _identifyQualityRisks(
    ProjectDataModel projectData,
    QualityManagementData qualityData,
  ) {
    final risks = <QualityRecommendation>[];

    // Analyze risk register items related to quality
    final riskItems = projectData.frontEndPlanning.riskRegisterItems;
    final qualityRelatedRisks = riskItems.where((r) => 
        _isQualityRelated(r.riskName) || _isQualityRelated(r.description)).toList();

    if (qualityRelatedRisks.isEmpty && riskItems.isNotEmpty) {
      risks.add(QualityRecommendation(
        id: 'risk_no_quality_risks',
        type: RecommendationType.qualityRisk,
        title: 'No Quality-Specific Risks Identified',
        description: 'Your risk register contains ${riskItems.length} risk(s), but none appear '
            'to specifically address quality-related concerns.',
        priority: Priority.high,
        rationale: 'Quality risks often manifest as schedule overruns, cost overruns, or '
            'stakeholder dissatisfaction. Proactive identification allows mitigation planning. '
            'Studies show that 67% of project failures trace back to unidentified quality issues.',
        suggestedAction: 'Add quality-specific risks such as: requirements creep impact on quality, '
            'insufficient testing time, skill gaps in quality practices, vendor quality issues, '
            'technical debt accumulation, or scope-quality tradeoffs.',
        supportingData: {
          'totalRisks': riskItems.length.toString(),
          'qualityRisksIdentified': '0',
          'recommendedQualityRisks': ['Insufficient test coverage', 'Requirements ambiguity', 
              'Technical debt', 'Resource constraints for QA', 'Vendor quality'].join(', '),
        },
      ));
    }

    // High-impact quality risks from the register
    for (final risk in qualityRelatedRisks) {
      if (risk.impactLevel == 'High' || risk.impactLevel == 'Critical') {
        risks.add(QualityRecommendation(
          id: 'risk_${risk.id}',
          type: RecommendationType.qualityRisk,
          title: 'High-Impact Quality Risk: ${risk.riskName}',
          description: risk.description.isNotEmpty ? risk.description : 
              'This risk may significantly impact project quality outcomes.',
          priority: risk.impactLevel == 'Critical' ? Priority.critical : Priority.high,
          rationale: 'High-impact quality risks require dedicated mitigation strategies. '
              'The cost of mitigating quality risks early is typically 10x less than addressing '
              'quality failures in production.',
          suggestedAction: 'Review and strengthen mitigation strategies for this risk. '
              'Consider: contingency buffers, additional reviews, enhanced testing, or '
              'alternative approaches.',
          supportingData: {
            'riskId': risk.id,
            'impactLevel': risk.impactLevel,
            'likelihood': risk.likelihood,
            'mitigation': risk.mitigationStrategy ?? 'Not defined',
          },
        ));
      }
    }

    // Calculate and analyze quality metrics snapshot
    final snapshot = QualityMetricsCalculator.computeSnapshot(qualityData);
    
    // Check if average time to resolution exceeds target
    if (snapshot.averageTimeToResolutionDays > 0 && 
        snapshot.targetTimeToResolutionDays > 0 &&
        snapshot.averageTimeToResolutionDays > snapshot.targetTimeToResolutionDays) {
      final overrunRatio = snapshot.averageTimeToResolutionDays / snapshot.targetTimeToResolutionDays;
      risks.add(QualityRecommendation(
        id: 'metric_resolution_time',
        type: RecommendationType.qualityRisk,
        title: 'Quality Issue Resolution Time Exceeds Target by ${overrunRatio.toStringAsFixed(1)}x',
        description: 'Average time to resolve quality issues is ${snapshot.averageTimeToResolutionDays.toStringAsFixed(1)} days '
            'against a target of ${snapshot.targetTimeToResolutionDays.toStringAsFixed(1)} days.',
        priority: overrunRatio > 2 ? Priority.critical : Priority.high,
        rationale: 'Extended resolution times indicate process inefficiencies, resource constraints, '
            'or complex issues requiring systemic improvement. Slow resolution cascades into schedule delays.',
        suggestedAction: 'Analyze blocked tasks, identify bottlenecks, consider escalation path '
            'improvements, or add dedicated resources for quality issue resolution.',
        supportingData: {
          'actualDays': snapshot.averageTimeToResolutionDays.toStringAsFixed(1),
          'targetDays': snapshot.targetTimeToResolutionDays.toStringAsFixed(1),
          'overrunPercent': ((overrunRatio - 1) * 100).toStringAsFixed(0),
        },
      ));
    }

    // Check audit pass rate
    if (snapshot.plannedAuditsCompletionPercent > 0 && 
        snapshot.plannedAuditsCompletionPercent < 80) {
      risks.add(QualityRecommendation(
        id: 'metric_audit_completion',
        type: RecommendationType.qualityRisk,
        title: 'Audit Completion Rate Below Target: ${snapshot.plannedAuditsCompletionPercent.toStringAsFixed(0)}%',
        description: 'Only ${snapshot.plannedAuditsCompletionPercent.toStringAsFixed(0)}% of planned audits have been completed.',
        priority: Priority.high,
        rationale: 'Low audit completion rates reduce visibility into process health. Undetected '
            'process deviations compound over time, leading to systemic quality issues.',
        suggestedAction: 'Prioritize completing scheduled audits. If resource-constrained, focus on '
            'high-risk areas and consider risk-based audit sampling.',
        supportingData: {
          'completionRate': snapshot.plannedAuditsCompletionPercent.toStringAsFixed(1),
          'targetRate': '90%+',
        },
      ));
    }

    return risks;
  }

  /// Identify likely sources of rework
  static List<QualityRecommendation> _identifyReworkSources(
    ProjectDataModel projectData,
    QualityManagementData qualityData,
  ) {
    final reworkSources = <QualityRecommendation>[];

    // Analyze corrective actions for patterns
    if (qualityData.correctiveActions.isNotEmpty) {
      final openActions = qualityData.correctiveActions.where((a) => 
          a.status != 'Closed' && a.status != 'Completed').length;
      
      if (openActions > 3) {
        reworkSources.add(QualityRecommendation(
          id: 'rework_open_corrective_actions',
          type: RecommendationType.reworkSource,
          title: '$openActions Open Corrective Actions (Potential Rework Source)',
          description: 'Multiple open corrective actions suggest recurring issues that may require '
              'systemic fixes rather than individual corrections.',
          priority: openActions > 5 ? Priority.high : Priority.medium,
          rationale: 'Open corrective actions represent known issues requiring attention. When they '
              'accumulate, it often indicates: insufficient root cause analysis, resource constraints, '
              'or systemic process weaknesses. Each open action has ~15% probability of causing rework.',
          suggestedAction: 'Prioritize closing corrective actions. For recurring issues, conduct a '
              'thorough root cause analysis (5 Whys, Fishbone Diagram) and implement permanent fixes.',
          supportingData: {
            'openActions': openActions.toString(),
            'totalActions': qualityData.correctiveActions.length.toString(),
          },
        ));
      }
    }

    // Analyze quality change log for volatility
    if (qualityData.qualityChangeLog.length > 5) {
      final recentChanges = qualityData.qualityChangeLog.where((c) {
        if (c.changeDate.isEmpty) return false;
        final date = DateTime.tryParse(c.changeDate);
        if (date == null) return false;
        return date.isAfter(DateTime.now().subtract(const Duration(days: 30)));
      }).length;

      if (recentChanges > 5) {
        reworkSources.add(QualityRecommendation(
          id: 'rework_high_change_rate',
          type: RecommendationType.reworkSource,
          title: '$recentChanges Quality Changes in Last 30 Days (Instability Indicator)',
          description: 'Frequent changes to quality processes or baselines may indicate scope creep, '
              'requirement instability, or planning deficiencies—all rework drivers.',
          priority: Priority.medium,
          rationale: 'High change velocity correlates with rework rates. Each quality baseline change '
              'has a 20-30% probability of requiring rework of affected deliverables. Stable baselines '
              'reduce rework by up to 40% (PMI Pulse of the Profession).',
          suggestedAction: 'Review recent changes for patterns. Strengthen change control process: '
              'impact analysis before approval, stakeholder sign-off, communication of changes.',
          supportingData: {
            'recentChanges': recentChanges.toString(),
            'changeRate': 'high',
            'threshold': '5 per month',
          },
        ));
      }
    }

    // Common rework sources based on project characteristics
    final methodology = _resolveMethodology(projectData);
    
    if (methodology == 'agile') {
      // Check for technical debt indicators
      reworkSources.add(QualityRecommendation(
        id: 'rework_agile_technical_debt',
        type: RecommendationType.reworkSource,
        title: 'Agile Technical Debt Accumulation Risk',
        description: 'Agile projects can accumulate technical debt when velocity pressure compromises '
            'quality practices. This becomes a significant rework source.',
        priority: Priority.medium,
        rationale: 'Studies show that agile teams under schedule pressure defer ~25% of quality '
            'activities, creating technical debt that requires 1.5-2x effort to address later. '
            '"Undo ratio" for technical debt averages 1.8x (Martin Fowler).',
        suggestedAction: 'Track technical debt explicitly. Allocate 15-20% of sprint capacity to '
            'debt reduction. Include "pay down debt" stories in backlog. Monitor undo ratio.',
        supportingData: {
          'methodology': methodology,
          'estimatedDebtRatio': '15-25%',
          'undoRatio': '1.8x average',
        },
      ));
    }

    // Generic rework source: requirements
    reworkSources.add(QualityRecommendation(
      id: 'rework_requirements_volatility',
      type: RecommendationType.reworkSource,
      title: 'Requirements Volatility (Common Rework Source)',
      description: 'Changes to requirements after development begins are the #1 cause of rework '
          'across all project types, accounting for 40-50% of rework effort.',
      priority: Priority.medium,
      rationale: 'Boehm\'s Cost of Change curve shows that requirements changes cost 10-100x more '
          'to address after implementation than during design. Each requirement change has cascade '
              'effects on design, code, tests, and documentation.',
      suggestedAction: 'Strengthen requirements engineering: formal sign-off process, impact analysis '
          'for changes, traceability matrix maintenance, change control board for significant changes.',
      supportingData: {
        'reworkContribution': '40-50%',
        'costMultiplier': '10-100x post-implementation',
        'source': 'Boehm\'s Cost of Change Curve',
      },
    ));

    return reworkSources;
  }

  /// Recommend quality KPIs based on project context
  static List<QualityRecommendation> _recommendKpis(
    ProjectDataModel projectData,
    QualityManagementData qualityData,
  ) {
    final kpis = <QualityRecommendation>[];
    // QualityManagementData has no customKpis field — derive existing KPI
    // names from the three fixed QualityMetrics so the recommender can
    // still dedupe against the user's current state.
    final existingKpiNames = <String>{
      'defect density',
      'customer satisfaction',
      'on-time delivery',
    };

    // Essential KPIs for any project
    final essentialKpis = [
      _KpiTemplate(
        name: 'First Pass Yield (FPY)',
        description: 'Percentage of work items that pass quality checks without rework',
        target: '85-95%',
        rationale: 'FPY is the gold standard efficiency metric. Higher FPY means less rework, '
            'lower cost, faster delivery. World-class organizations achieve 95%+ FPY.',
        calculation: '(Items passing first time / Total items inspected) × 100',
      ),
      _KpiTemplate(
        name: 'Defect Escape Rate',
        description: 'Percentage of defects found by customers vs. internal testing',
        target: '<5%',
        rationale: 'Defect escape rate measures testing effectiveness. Each escaped defect '
            'costs 5-10x more to fix than internally detected ones. Target: <5% for mature orgs.',
        calculation: '(Customer-found defects / Total defects found) × 100',
      ),
      _KpiTemplate(
        name: 'Test Coverage',
        description: 'Percentage of code/functionality covered by automated tests',
        target: '80%+',
        rationale: 'Test coverage correlates with defect detection capability. 80%+ coverage '
            'is industry standard; critical systems may require 90%+. Below 70% indicates risk.',
        calculation: '(Covered lines / Total executable lines) × 100',
      ),
      _KpiTemplate(
        name: 'Quality Cost Ratio',
        description: 'Prevention + Appraisal costs vs. Failure costs as % of total quality cost',
        target: '60-70% on PA activities',
        rationale: 'Mature quality organizations spend 60-70% on prevention/apraisal (good costs) '
            'and only 30-40% on failure (bad costs). Low PA spending predicts higher failure costs.',
        calculation: '(PA Costs / Total Quality Costs) × 100',
      ),
      _KpiTemplate(
        name: 'Mean Time to Resolution (MTTR)',
        description: 'Average time to resolve quality issues from detection to closure',
        target: '<5 days for normal, <1 day for critical',
        rationale: 'Fast resolution prevents defect propagation and reduces schedule impact. '
            'MTTR trends reveal process health—increasing MTTR signals growing inefficiency.',
        calculation: 'Sum(resolution times) / Number of resolved issues',
      ),
      _KpiTemplate(
        name: 'Audit Finding Closure Rate',
        description: 'Percentage of audit findings closed within target timeframe',
        target: '>90% within deadline',
        rationale: 'Audit closure rate demonstrates organizational discipline and commitment to '
            'improvement. Low closure rates undermine audit value and may indicate resistance.',
        calculation: '(Findings closed on-time / Total findings) × 100',
      ),
    ];

    for (final kpi in essentialKpis) {
      final exists = existingKpiNames.any((name) => 
          _wordsOverlap(kpi.name.toLowerCase(), name) > 0.4);
      
      if (!exists) {
        kpis.add(QualityRecommendation(
          id: 'kpi_${kpi.name.hashCode}',
          type: RecommendationType.recommendedKpi,
          title: 'Recommended KPI: ${kpi.name}',
          description: kpi.description,
          priority: _isEssentialKpi(kpi.name) ? Priority.high : Priority.medium,
          rationale: kpi.rationale,
          suggestedAction: 'Create KPI "${kpi.name}" with target: ${kpi.target}. '
              'Calculation: ${kpi.calculation}',
          supportingData: {
            'target': kpi.target,
            'calculation': kpi.calculation,
            'category': _categorizeKpi(kpi.name),
          },
        ));
      }
    }

    // Industry-specific KPIs
    final industry = projectData.projectIndustry?.toLowerCase() ?? '';
    if (industry.contains('software') || industry.contains('tech')) {
      kpis.add(QualityRecommendation(
        id: 'kpi_code_churn',
        type: RecommendationType.recommendedKpi,
        title: 'Industry KPI: Code Churn Rate',
        description: 'Percentage of code modified within a release cycle (instability indicator)',
        priority: Priority.low,
        rationale: 'High churn (>20%) indicates unstable codebase requiring frequent changes, '
            'which increases defect introduction risk. Google and Microsoft studies show correlation '
            'between churn and defect density.',
        suggestedAction: 'Track lines added/deleted per file per sprint. Investigate files with '
            'consistently high churn for potential refactoring or better ownership.',
        supportingData: {
          'target': '<20% churn per release',
          'industry': 'software',
        },
      ));
    }

    if (industry.contains('construction') || industry.contains('manufacturing')) {
      kpis.add(QualityRecommendation(
        id: 'kpi_rework_rate',
        type: RecommendationType.recommendedKpi,
        title: 'Industry KPI: Rework Rate (%)',
        description: 'Percentage of work that must be redone to meet quality standards',
        priority: Priority.high,
        rationale: 'Construction industry average rework rate is 5-12% of project cost. Best-in-class '
            'achieve <3%. Each 1% reduction in rework directly improves profit margin.',
        suggestedAction: 'Track rework hours by category: design errors, workmanship, material substitution, '
            'coordination issues. Target root causes, not symptoms.',
        supportingData: {
          'target': '<5% (best-in-class <3%)',
          'industryAverage': '5-12%',
          'industry': 'construction/manufacturing',
        },
      ));
    }

    return kpis;
  }

  // ── Helper Methods ───────────────────────────────────────────────────────

  static String _resolveProjectType(ProjectDataModel data) {
    final methodology = _resolveMethodology(data);
    final industry = data.projectIndustry?.toLowerCase() ?? '';
    
    if (methodology == 'agile') return 'agile_software';
    if (methodology == 'waterfall') return 'traditional';
    if (methodology == 'hybrid') return 'hybrid';
    if (industry.contains('software') || industry.contains('tech')) return 'software';
    if (industry.contains('construction')) return 'construction';
    if (industry.contains('healthcare') || industry.contains('medical')) return 'healthcare';
    if (industry.contains('manufacturing')) return 'manufacturing';
    if (industry.contains('finance') || industry.contains('banking')) return 'finance';
    if (industry.contains('energy') || industry.contains('oil') || industry.contains('gas')) return 'energy';
    return 'general';
  }

  static String _resolveMethodology(ProjectDataModel data) {
    // Check various fields for methodology indication
    final methodology = data.methodology?.toLowerCase() ?? '';
    if (methodology.contains('agile') || methodology.contains('scrum') || methodology.contains('kanban')) {
      return 'agile';
    }
    if (methodology.contains('waterfall') || methodology.contains('traditional')) {
      return 'waterfall';
    }
    if (methodology.contains('hybrid') || methodology.contains('mixed')) {
      return 'hybrid';
    }
    // Default based on project characteristics
    return 'default';
  }

  static List<String> _getRequiredCategories(ProjectDataModel data) {
    final base = ['functional', 'performance', 'reliability'];
    final industry = data.projectIndustry?.toLowerCase() ?? '';
    
    if (industry.contains('software') || industry.contains('tech')) {
      return [...base, 'security', 'usability', 'maintainability'];
    }
    if (industry.contains('healthcare') || industry.contains('medical')) {
      return [...base, 'safety', 'compliance', 'traceability'];
    }
    if (industry.contains('finance')) {
      return [...base, 'security', 'compliance', 'auditability'];
    }
    return [...base, 'compliance', 'customer_satisfaction'];
  }

  static String _formatCategory(String category) {
    return category.replaceAll('_', ' ').split(' ').map((word) => 
        word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  static Priority _getCategoryPriority(String category) {
    final critical = ['security', 'safety', 'compliance', 'performance'];
    if (critical.any((c) => category.toLowerCase().contains(c))) {
      return Priority.critical;
    }
    return Priority.high;
  }

  static String _getCategoryRationale(String category, ProjectDataModel data) {
    final rationales = {
      'functional': 'Functional quality ensures the product meets stated requirements and user needs. '
          'According to ISO 25010, functional suitability is a core quality characteristic.',
      'performance': 'Performance quality affects user satisfaction and system reliability. '
          'Slow or unreliable systems drive user abandonment—47% of users expect 2-second load times.',
      'reliability': 'Reliability directly impacts operational costs and user trust. '
          'Each 9 of availability (99.9% → 99.99%) reduces downtime by 90%.',
      'security': 'Security breaches average \$4.45M cost (IBM 2023). Proactive security quality '
          'prevents 80% of common vulnerabilities (OWASP).',
      'safety': 'Safety-critical failures can be catastrophic. IEC 61508 requires systematic safety '
          'integrity levels for safety-related systems.',
      'compliance': 'Non-compliance can result in legal penalties, market access restrictions, '
          'and reputational damage. Regulatory fines average \$4.3M for serious violations.',
    };
    return rationales[category.toLowerCase()] ?? 
        'This quality dimension is important for delivering a successful product that meets stakeholder expectations.';
  }

  static String _suggestTargetExample(String category) {
    final examples = {
      'functional': 'Achieve 95% requirements traceability coverage',
      'performance': 'Response time < 2 seconds for 95th percentile',
      'reliability': '99.9% uptime availability (8.76 hrs downtime/year max)',
      'security': 'Zero CRITICAL/HIGH vulnerabilities in production scans',
      'safety': 'Zero safety incidents; 100% safety check completion',
      'compliance': '100% audit finding closure within 30 days',
    };
    return examples[category.toLowerCase()] ?? 
        'Establish measurable target for ${_formatCategory(category)}';
  }

  static bool _isCoreActivity(String activity) {
    final coreKeywords = ['review', 'testing', 'inspection', 'audit', 'acceptance', 'coverage'];
    return coreKeywords.any((k) => activity.toLowerCase().contains(k));
  }

  static String _getActivityRationale(String activity, String methodology) {
    if (activity.contains('Testing') || activity.contains('test')) {
      return 'Testing verifies that deliverables meet requirements. Studies show that testing finds '
          '~30% of defects, with automation increasing coverage and consistency. ';
    }
    if (activity.contains('Review') || activity.contains('peer')) {
      return 'Peer reviews are one of the most cost-effective quality techniques, finding 60-75% of '
          'defects at a fraction of testing costs (IBM/Fujitsu studies). ';
    }
    if (activity.contains('Automated') || activity.contains('CI')) {
      return 'Automation provides consistent, repeatable quality checks. CI/CD reduces defect escape '
          'rate by 35% and accelerates feedback loops from days to minutes. ';
    }
    return 'This activity supports quality objectives by providing systematic verification and '
        'feedback. ';
  }

  static String _getStandardRationale(String standard, String industry) {
    if (standard.contains('ISO 9001')) {
      return 'ISO 9001:2015 is the world\'s leading quality management standard with over 1 million '
          'certifications globally. It provides a framework for consistent quality delivery and '
          'continuous improvement.';
    }
    if (standard.contains('CMMI')) {
      return 'CMMI provides process maturity benchmarks. Organizations at Maturity Level 3+ have '
          '23% lower defect rates and 29% better schedule performance (SEI research).';
    }
    if (standard.contains('SOC 2')) {
      return 'SOC 2 demonstrates security controls to customers and partners. Required by enterprise '
          'customers in technology sector; builds trust and accelerates sales cycles.';
    }
    return 'This standard represents recognized best practices for your industry. Adoption demonstrates '
        'commitment to quality and may be required by customers or regulators.';
  }

  static bool _isQualityRelated(String text) {
    final qualityKeywords = [
      'quality', 'defect', 'bug', 'error', 'test', 'review', 'audit', 'inspection',
      'compliance', 'standard', 'specification', 'requirement', 'acceptance',
      'validation', 'verification', 'rework', 'correction', 'non-conformance'
    ];
    final lower = text.toLowerCase();
    return qualityKeywords.any((k) => lower.contains(k));
  }

  static double _wordsOverlap(String text1, String text2) {
    final words1 = text1.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    final words2 = text2.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    if (words1.isEmpty || words2.isEmpty) return 0.0;
    final intersection = words1.intersection(words2);
    return intersection.length / (words1.length + words2.length - intersection.length);
  }

  static int _getMinQATechniques(ProjectDataModel data) {
    final size = data.teamMembers.length;
    if (size > 20) return 5;
    if (size > 10) return 4;
    if (size > 5) return 3;
    return 2;
  }

  static int _getMinQCTechniques(ProjectDataModel data) {
    return _getMinQATechniques(data); // Same logic for now
  }

  static bool _isEssentialKpi(String name) {
    final essential = ['First Pass Yield', 'Defect Escape Rate', 'Test Coverage', 'Quality Cost Ratio'];
    return essential.any((e) => name.contains(e));
  }

  static String _categorizeKpi(String name) {
    if (name.contains('Yield') || name.contains('Escape')) return 'Effectiveness';
    if (name.contains('Coverage')) return 'Verification';
    if (name.contains('Cost')) return 'Financial';
    if (name.contains('Time') || name.contains('Resolution')) return 'Efficiency';
    if (name.contains('Audit') || name.contains('Closure')) return 'Governance';
    return 'General';
  }

  /// Build a context summary for AI chat integration
  static String buildAiContextSummary(QualityIntelligenceReport report) {
    final buffer = StringBuffer();
    buffer.writeln('## Quality Intelligence Summary');
    buffer.writeln('**Project**: ${report.projectName}');
    buffer.writeln('**Type**: ${report.projectType} | **Industry**: ${report.industry}');
    buffer.writeln('**Generated**: ${report.generatedAt.toIso8601String()}');
    buffer.writeln('');

    if (report.missingRequirements.isNotEmpty) {
      buffer.writeln('### ⚠️ Missing Requirements (${report.missingRequirements.length})');
      for (final req in report.missingRequirements.take(3)) {
        buffer.writeln('- **${req.title}**: ${req.suggestedAction}');
      }
      buffer.writeln('');
    }

    if (report.qualityRisks.isNotEmpty) {
      buffer.writeln('### 🚨 Quality Risks (${report.qualityRisks.length})');
      for (final risk in report.qualityRisks.take(3)) {
        buffer.writeln('- **${risk.title}** [${risk.priority.name}]');
      }
      buffer.writeln('');
    }

    if (report.acceptanceCriteriaGaps.isNotEmpty) {
      buffer.writeln('### 📊 Gaps Detected (${report.acceptanceCriteriaGaps.length})');
      for (final gap in report.acceptanceCriteriaGaps.take(3)) {
        buffer.writeln('- **${gap.title}**');
      }
      buffer.writeln('');
    }

    buffer.writeln('### ✅ Recommendations Summary');
    buffer.writeln('- Activities to consider: ${report.recommendedActivities.length}');
    buffer.writeln('- Standards to evaluate: ${report.recommendedStandards.length}');
    buffer.writeln('- KPIs to implement: ${report.recommendedKpis.length}');
    buffer.writeln('- Rework sources identified: ${report.reworkSources.length}');

    return buffer.toString();
  }
}

// ── Data Models ────────────────────────────────────────────────────────────

enum Priority { low, medium, high, critical }

enum RecommendationType {
  missingRequirement,
  recommendedActivity,
  recommendedStandard,
  acceptanceGap,
  qualityRisk,
  recommendedKpi,
  reworkSource,
}

class QualityRecommendation {
  final String id;
  final RecommendationType type;
  final String title;
  final String description;
  final Priority priority;
  final String rationale;
  final String suggestedAction;
  final Map<String, dynamic> supportingData;

  const QualityRecommendation({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.rationale,
    required this.suggestedAction,
    this.supportingData = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'description': description,
    'priority': priority.name,
    'rationale': rationale,
    'suggestedAction': suggestedAction,
    'supportingData': supportingData,
  };

  factory QualityRecommendation.fromJson(Map<String, dynamic> json) =>
      QualityRecommendation(
        id: json['id'] ?? '',
        type: RecommendationType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => RecommendationType.missingRequirement,
        ),
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        priority: Priority.values.firstWhere(
          (p) => p.name == json['priority'],
          orElse: () => Priority.medium,
        ),
        rationale: json['rationale'] ?? '',
        suggestedAction: json['suggestedAction'] ?? '',
        supportingData: json['supportingData'] ?? {},
      );
}

class QualityIntelligenceReport {
  final DateTime generatedAt;
  final String projectName;
  final String projectType;
  final String industry;
  final String methodology;

  final List<QualityRecommendation> missingRequirements;
  final List<QualityRecommendation> recommendedActivities;
  final List<QualityRecommendation> recommendedStandards;
  final List<QualityRecommendation> acceptanceCriteriaGaps;
  final List<QualityRecommendation> qualityRisks;
  final List<QualityRecommendation> recommendedKpis;
  final List<QualityRecommendation> reworkSources;

  const QualityIntelligenceReport({
    required this.generatedAt,
    required this.projectName,
    required this.projectType,
    required this.industry,
    required this.methodology,
    this.missingRequirements = const [],
    this.recommendedActivities = const [],
    this.recommendedStandards = const [],
    this.acceptanceCriteriaGaps = const [],
    this.qualityRisks = const [],
    this.recommendedKpis = const [],
    this.reworkSources = const [],
  });

  int get totalFindings => 
      missingRequirements.length + 
      recommendedActivities.length + 
      recommendedStandards.length +
      acceptanceCriteriaGaps.length + 
      qualityRisks.length + 
      recommendedKpis.length + 
      reworkSources.length;

  List<QualityRecommendation> get allRecommendations => [
        ...missingRequirements,
        ...recommendedActivities,
        ...recommendedStandards,
        ...acceptanceCriteriaGaps,
        ...qualityRisks,
        ...recommendedKpis,
        ...reworkSources,
      ];

  List<QualityRecommendation> get criticalItems =>
      allRecommendations.where((r) => r.priority == Priority.critical).toList();

  List<QualityRecommendation> get highPriorityItems =>
      allRecommendations.where((r) => r.priority == Priority.high).toList();

  Map<String, int> get findingsByType => {
    'Missing Requirements': missingRequirements.length,
    'Recommended Activities': recommendedActivities.length,
    'Recommended Standards': recommendedStandards.length,
    'Gaps Detected': acceptanceCriteriaGaps.length,
    'Quality Risks': qualityRisks.length,
    'Recommended KPIs': recommendedKpis.length,
    'Rework Sources': reworkSources.length,
  };

  Map<String, int> get findingsByPriority => {
    'Critical': allRecommendations.where((r) => r.priority == Priority.critical).length,
    'High': allRecommendations.where((r) => r.priority == Priority.high).length,
    'Medium': allRecommendations.where((r) => r.priority == Priority.medium).length,
    'Low': allRecommendations.where((r) => r.priority == Priority.low).length,
  };

  Map<String, dynamic> toJson() => {
    'generatedAt': generatedAt.toIso8601String(),
    'projectName': projectName,
    'projectType': projectType,
    'industry': industry,
    'methodology': methodology,
    'missingRequirements': missingRequirements.map((r) => r.toJson()).toList(),
    'recommendedActivities': recommendedActivities.map((r) => r.toJson()).toList(),
    'recommendedStandards': recommendedStandards.map((r) => r.toJson()).toList(),
    'acceptanceCriteriaGaps': acceptanceCriteriaGaps.map((r) => r.toJson()).toList(),
    'qualityRisks': qualityRisks.map((r) => r.toJson()).toList(),
    'recommendedKpis': recommendedKpis.map((r) => r.toJson()).toList(),
    'reworkSources': reworkSources.map((r) => r.toJson()).toList(),
  };
}

class _KpiTemplate {
  final String name;
  final String description;
  final String target;
  final String rationale;
  final String calculation;

  const _KpiTemplate({
    required this.name,
    required this.description,
    required this.target,
    required this.rationale,
    required this.calculation,
  });
}
