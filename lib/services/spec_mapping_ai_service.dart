import '../utils/design_planning_document.dart';

/// Result of AI mapping suggestion
class AiMappingSuggestion {
  final String sourceId; // Spec ID or Requirement ID
  final String sourceType; // 'specification' or 'requirement'
  final String targetId; // Suggested target ID
  final String targetType; // 'requirement', 'specification', or 'subscope'
  final String targetTitle; // Human-readable title
  final double confidence; // 0.0 to 1.0 confidence score
  final String reasoning; // Why AI suggests this mapping

  const AiMappingSuggestion({
    required this.sourceId,
    required this.sourceType,
    required this.targetId,
    required this.targetType,
    required this.targetTitle,
    required this.confidence,
    required this.reasoning,
  });

  @override
  String toString() =>
      'AiMappingSuggestion(sourceId: $sourceId, targetId: $targetId, confidence: ${confidence.toStringAsFixed(2)})';

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'sourceType': sourceType,
        'targetId': targetId,
        'targetType': targetType,
        'targetTitle': targetTitle,
        'confidence': confidence,
        'reasoning': reasoning,
      };

  /// Create from JSON
  factory AiMappingSuggestion.fromJson(Map<String, dynamic> json) =>
      AiMappingSuggestion(
        sourceId: json['sourceId'] ?? '',
        sourceType: json['sourceType'] ?? '',
        targetId: json['targetId'] ?? '',
        targetType: json['targetType'] ?? '',
        targetTitle: json['targetTitle'] ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        reasoning: json['reasoning'] ?? '',
      );
}

/// AI-powered specification mapping service
///
/// This service provides intelligent suggestions for mapping:
/// - Specifications to Requirements
/// - Specifications to Subscope/Work Packages
///
/// Uses keyword-based matching with confidence scoring.
/// Can be extended to use OpenAI API for more sophisticated analysis.
class SpecMappingAiService {
  /// Minimum confidence threshold for requirement mappings
  static const double _requirementConfidenceThreshold = 0.3;

  /// Minimum confidence threshold for subscope mappings
  static const double _subscopeConfidenceThreshold = 0.25;

  /// Maximum number of requirement suggestions to return
  static const int _maxRequirementSuggestions = 20;

  /// Maximum number of subscope suggestions to return
  static const int _maxSubscopeSuggestions = 15;

  /// Generate mapping suggestions for specifications to requirements
  ///
  /// Analyzes specifications that don't have attached requirements
  /// and suggests potential requirement matches based on keyword similarity.
  static Future<List<AiMappingSuggestion>> suggestRequirementMappings({
    required List<DesignSpecificationPlanRow> specifications,
    required List<dynamic> requirements, // DesignRequirementMapping or RequirementRow
  }) async {
    final List<AiMappingSuggestion> suggestions = [];

    for (final spec in specifications) {
      // Only suggest for specs without existing requirement mappings
      if (spec.attachedRequirementIds.isEmpty) {
        // Find potential requirement matches based on keywords
        for (final req in requirements) {
          final reqText = _extractRequirementText(req);
          final reqId = _extractRequirementId(req);

          if (reqText.isEmpty || reqId.isEmpty) continue;

          final double confidence = _calculateMatchConfidence(
            '${spec.title} ${spec.details}',
            reqText,
          );

          if (confidence > _requirementConfidenceThreshold) {
            suggestions.add(AiMappingSuggestion(
              sourceId: spec.id,
              sourceType: 'specification',
              targetId: reqId,
              targetType: 'requirement',
              targetTitle: reqText.length > 50
                  ? '${reqText.substring(0, 50)}...'
                  : reqText,
              confidence: confidence,
              reasoning:
                  'Keyword match detected between spec "${spec.title}" and requirement',
            ));
          }
        }
      }
    }

    // Sort by confidence descending and limit results
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));

    return suggestions.take(_maxRequirementSuggestions).toList();
  }

  /// Suggest subscope/work package assignments for specifications
  ///
  /// Analyzes specifications that aren't assigned to any work package
  /// and suggests potential matches based on discipline/area similarity.
  static Future<List<AiMappingSuggestion>> suggestSubscopeMappings({
    required List<DesignSpecificationPlanRow> specifications,
    required List<dynamic> workPackages, // WorkPackage objects
  }) async {
    final List<AiMappingSuggestion> suggestions = [];

    for (final spec in specifications) {
      // Only suggest for specs without existing work package assignments
      if (spec.wbsWorkPackageId.isEmpty) {
        for (final wp in workPackages) {
          final wpTitle = _extractWorkPackageTitle(wp);
          final wpId = _extractWorkPackageId(wp);

          if (wpTitle.isEmpty || wpId.isEmpty) continue;

          final double confidence = _calculateMatchConfidence(
            '${spec.discipline} ${spec.area} ${spec.specificationType}',
            '$wpTitle ${_extractWorkPackageDiscipline(wp)} ${_extractWorkPackageArea(wp)}',
          );

          if (confidence > _subscopeConfidenceThreshold) {
            suggestions.add(AiMappingSuggestion(
              sourceId: spec.id,
              sourceType: 'specification',
              targetId: wpId,
              targetType: 'subscope',
              targetTitle: wpTitle,
              confidence: confidence,
              reasoning:
                  'Discipline/area match: ${spec.discipline}/${spec.area}',
            ));
          }
        }
      }
    }

    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return suggestions.take(_maxSubscopeSuggestions).toList();
  }

  /// Calculate simple keyword match confidence between two texts
  ///
  /// Returns a value between 0.0 (no match) and 1.0 (perfect match).
  /// Uses word-level matching with minimum word length filter.
  static double _calculateMatchConfidence(String text1, String text2) {
    final words1 = text1.toLowerCase().split(RegExp(r'\s+'));
    final words2 = text2.toLowerCase().split(RegExp(r'\s+'));

    if (words1.isEmpty || words2.isEmpty) return 0.0;

    int matches = 0;
    for (final word in words1) {
      // Only consider words longer than 3 characters for meaningful matching
      if (word.length > 3 &&
          words2.any((w) => w.contains(word) || word.contains(w))) {
        matches++;
      }
    }

    return matches / words1.length;
  }

  /// Extract requirement text from various requirement object types
  static String _extractRequirementText(dynamic req) {
    if (req is DesignRequirementMapping) {
      return req.requirementText;
    }
    // Handle dynamic objects with possible text fields
    return (req.definition ?? req.title ?? req.description ?? req.text ?? '')
        .toString();
  }

  /// Extract requirement ID from various requirement object types
  static String _extractRequirementId(dynamic req) {
    if (req is DesignRequirementMapping) {
      return req.localId;
    }
    return (req.id ?? '').toString();
  }

  /// Extract work package title from various WP object types
  static String _extractWorkPackageTitle(dynamic wp) {
    return (wp.title ?? wp.name ?? wp.workPackageName ?? '').toString();
  }

  /// Extract work package ID from various WP object types
  static String _extractWorkPackageId(dynamic wp) {
    return (wp.id ?? wp.workPackageId ?? '').toString();
  }

  /// Extract discipline from work package object
  static String _extractWorkPackageDiscipline(dynamic wp) {
    return (wp.discipline ?? '').toString();
  }

  /// Extract area from work package object
  static String _extractWorkPackageArea(dynamic wp) {
    return (wp.area ?? wp.areaOrSystem ?? '').toString();
  }

  /// Analyze gaps and return warnings about unmapped items
  ///
  /// Checks for:
  /// - Specifications without requirement mappings
  /// - Specifications without subscope/package assignments
  /// - Requirements not linked to any specification
  static List<String> analyzeGaps({
    required List<DesignSpecificationPlanRow> specifications,
    required List<dynamic> requirements,
    required List<dynamic> workPackages,
  }) {
    final warnings = <String>[];

    // Check for specs without requirements
    final unmappedSpecs =
        specifications.where((s) => s.attachedRequirementIds.isEmpty).toList();
    if (unmappedSpecs.isNotEmpty) {
      warnings.add(
          '⚠️ ${unmappedSpecs.length} specification(s) not mapped to any requirement');
    }

    // Check for specs without subscope/packages
    final unscopedSpecs = specifications
        .where((s) => s.wbsWorkPackageId.isEmpty)
        .toList();
    if (unscopedSpecs.isNotEmpty) {
      warnings.add(
          '⚠️ ${unscopedSpecs.length} specification(s) not assigned to any scope package');
    }

    // Check for requirements without specs (if we have requirement data)
    final mappedReqIds =
        specifications.expand((s) => s.attachedRequirementIds).toSet();
    if (requirements.isNotEmpty) {
      final unmappedReqs = requirements.where((r) {
        final reqId = r is DesignRequirementMapping
            ? r.localId
            : (r.id ?? '').toString();
        return !mappedReqIds.contains(reqId);
      }).toList();
      if (unmappedReqs.isNotEmpty) {
        warnings.add(
            '⚠️ ${unmappedReqs.length} requirement(s) not linked to any specification');
      }
    }

    // Check for orphaned work packages (no specs assigned)
    if (workPackages.isNotEmpty) {
      final mappedWpIds =
          specifications.map((s) => s.wbsWorkPackageId).where((id) => id.isNotEmpty).toSet();
      final orphanedWps = workPackages.where((wp) {
        final wpId = _extractWorkPackageId(wp);
        return wpId.isNotEmpty && !mappedWpIds.contains(wpId);
      }).toList();
      if (orphanedWps.isNotEmpty) {
        warnings.add(
            'ℹ️ ${orphanedWps.length} work package(s) have no specifications assigned');
      }
    }

    return warnings;
  }

  /// Get mapping statistics summary
  static Map<String, dynamic> getMappingStatistics({
    required List<DesignSpecificationPlanRow> specifications,
    required List<dynamic> requirements,
  }) {
    final totalSpecs = specifications.length;
    final specsWithRequirements =
        specifications.where((s) => s.attachedRequirementIds.isNotEmpty).length;
    final specsWithPackages =
        specifications.where((s) => s.wbsWorkPackageId.isNotEmpty).length;
    final totalMappings =
        specifications.fold<int>(0, (sum, s) => sum + s.attachedRequirementIds.length);

    return {
      'totalSpecifications': totalSpecs,
      'specsWithRequirements': specsWithRequirements,
      'specsWithPackages': specsWithPackages,
      'specsWithoutRequirements': totalSpecs - specsWithRequirements,
      'specsWithoutPackages': totalSpecs - specsWithPackages,
      'totalRequirementMappings': totalMappings,
      'requirementCoveragePercent': totalSpecs > 0
          ? ((specsWithRequirements / totalSpecs) * 100).toStringAsFixed(1)
          : '0.0',
      'packageCoveragePercent': totalSpecs > 0
          ? ((specsWithPackages / totalSpecs) * 100).toStringAsFixed(1)
          : '0.0',
    };
  }

  /// Batch accept suggestions and return the updated specifications
  ///
  /// Applies accepted mappings to the specification list and returns
  /// the modified specifications.
  static List<DesignSpecificationPlanRow> applyAcceptedMappings({
    required List<DesignSpecificationPlanRow> specifications,
    required List<AiMappingSuggestion> acceptedSuggestions,
  }) {
    final updatedSpecs = { for (var spec in specifications) (spec as DesignSpecificationPlanRow).id : spec };

    for (final suggestion in acceptedSuggestions) {
      final spec = updatedSpecs[suggestion.sourceId];
      if (spec == null) continue;

      if (suggestion.targetType == 'requirement') {
        // Add requirement ID to spec's attached requirements
        if (!spec.attachedRequirementIds.contains(suggestion.targetId)) {
          updatedSpecs[suggestion.sourceId] = DesignSpecificationPlanRow(
            id: spec.id,
            title: spec.title,
            details: spec.details,
            specificationType: spec.specificationType,
            discipline: spec.discipline,
            area: spec.area,
            attachedRequirementIds: [
              ...spec.attachedRequirementIds,
              suggestion.targetId
            ],
            ruleType: spec.ruleType,
            sourceType: spec.sourceType,
            owner: spec.owner,
            status: spec.status,
            referenceLink: spec.referenceLink,
            wbsWorkPackageId: spec.wbsWorkPackageId,
            wbsWorkPackageTitle: spec.wbsWorkPackageTitle,
            uploadedFileName: spec.uploadedFileName,
            uploadedStoragePath: spec.uploadedStoragePath,
          );
        }
      } else if (suggestion.targetType == 'subscope') {
        // Update spec's work package assignment
        updatedSpecs[suggestion.sourceId] = DesignSpecificationPlanRow(
          id: spec.id,
          title: spec.title,
          details: spec.details,
          specificationType: spec.specificationType,
          discipline: spec.discipline,
          area: spec.area,
          attachedRequirementIds: spec.attachedRequirementIds,
          ruleType: spec.ruleType,
          sourceType: spec.sourceType,
          owner: spec.owner,
          status: spec.status,
          referenceLink: spec.referenceLink,
          wbsWorkPackageId: suggestion.targetId,
          wbsWorkPackageTitle: suggestion.targetTitle,
          uploadedFileName: spec.uploadedFileName,
          uploadedStoragePath: spec.uploadedStoragePath,
        );
      }
    }

    return updatedSpecs.values.toList();
  }
}
