import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/design_phase_models.dart';
import 'package:ndu_project/models/project_data_model.dart'; // Import for DesignDeliverablesData
import 'package:ndu_project/services/architecture_service.dart';

class DesignPhaseService {
  // Singleton instance
  static final DesignPhaseService instance = DesignPhaseService._();

  DesignPhaseService._();

  static const String _collectionPath = 'design_phase_sections';

  DocumentReference<Map<String, dynamic>> _projectDoc(String projectId) {
    return FirebaseFirestore.instance.collection('projects').doc(projectId);
  }

  DocumentReference<Map<String, dynamic>> _sectionDoc(
      String projectId, String section) {
    return _projectDoc(projectId).collection(_collectionPath).doc(section);
  }

  // --- Requirements Implementation (Design Specifications) ---

  Future<Map<String, dynamic>> loadRequirementsImplementation(
      String projectId) async {
    try {
      final doc =
          await _sectionDoc(projectId, 'requirements_implementation').get();
      return doc.data() ?? {};
    } catch (e) {
      debugPrint('Error loading requirements implementation: $e');
      return {};
    }
  }

  Future<void> saveRequirementsImplementation(
    String projectId, {
    required String notes,
    required List<RequirementRow> requirements,
    required List<RequirementChecklistItem> checklist,
    List<Map<String, dynamic>> documents = const [],
    String sectionApprovalStatus = 'Draft',
    String sectionApprovedBy = '',
    String sectionApprovalDate = '',
    String sectionApprovalNotes = '',
  }) async {
    try {
      await _sectionDoc(projectId, 'requirements_implementation').set({
        'notes': notes,
        'requirements': requirements.map((e) => e.toMap()).toList(),
        'checklist': checklist.map((e) => e.toMap()).toList(),
        'documents': documents,
        'sectionApprovalStatus': sectionApprovalStatus,
        'sectionApprovedBy': sectionApprovedBy,
        'sectionApprovalDate': sectionApprovalDate,
        'sectionApprovalNotes': sectionApprovalNotes,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving requirements implementation: $e');
      rethrow;
    }
  }

  // --- Auto-Sync Logic ---

  /// Syncs Scope items from Project Charter into Requirements.
  /// Returns the number of new items added.
  Future<int> syncRequirementsFromScope(String projectId) async {
    try {
      // 1. Fetch Project Charter / Scope
      final charterDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection(
              'planning_phase') // Assuming charter is here or similar path
          .doc('project_charter')
          .get();

      if (!charterDoc.exists) return 0;

      final charterData = charterDoc.data() ?? {};
      // Adjust field access based on actual Charter structure.
      // Assuming 'projectScope' list or similar.
      // If structure is different, we might need to look at 'front_end_planning' -> 'scope'
      // Let's assume a standard 'scopeItems' list for now, or check 'project_scope' collection if it exists.
      // Based on previous context, scope might be in 'project_charter' doc under 'scope' key.

      final dynamic scopeData = charterData['scope'];
      List<String> scopeItems = [];

      if (scopeData is List) {
        scopeItems = scopeData.map((e) => e.toString()).toList();
      } else if (scopeData is String) {
        // Maybe it's a markdown string? Split by bullets?
        // For now, let's look for a specific 'scopeItems' array if 'scope' isn't it.
      }

      // Fallback: Check if there is a specific 'scope' document in planning phase
      if (scopeItems.isEmpty) {
        final scopeDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .collection('planning_phase')
            .doc('project_scope')
            .get();

        if (scopeDoc.exists) {
          final data = scopeDoc.data();
          if (data != null && data['items'] is List) {
            scopeItems =
                (data['items'] as List).map((e) => e.toString()).toList();
          }
        }
      }

      if (scopeItems.isEmpty) return 0;

      // 2. Fetch Existing Requirements
      final reqDoc =
          await _sectionDoc(projectId, 'requirements_implementation').get();

      List<RequirementRow> existingReqs = [];
      if (reqDoc.exists) {
        final data = reqDoc.data();
        if (data != null && data['requirements'] != null) {
          existingReqs = (data['requirements'] as List)
              .map((e) => RequirementRow.fromMap(e as Map<String, dynamic>))
              .toList();
        }
      }

      // 3. Merge: Add scope items that don't exist as requirement titles
      int addedCount = 0;
      for (final item in scopeItems) {
        // Simple duplicate check by title
        final exists = existingReqs
            .any((r) => r.title.toLowerCase() == item.toLowerCase());
        if (!exists) {
          existingReqs.add(RequirementRow(
            requirementId: _buildRequirementId(existingReqs.length + 1),
            title: item,
            owner: 'Unassigned',
            definition: 'Imported from Project Scope',
            requirementType: _inferRequirementType(item),
            designArtifactLabel: _defaultArtifactLabel(item),
            designArtifactType: _inferRequirementType(item) == 'Non-Functional'
                ? 'PDF'
                : 'Figma',
            validationStatus: 'Unmapped',
            acceptanceCriteria:
                'Confirm the design package fully addresses the scope intent.',
            testMethod: _inferRequirementType(item) == 'Non-Functional'
                ? 'Compliance review'
                : 'Design walkthrough',
            sourceDocument: 'Project Scope',
            gapStatus: 'Pending Approval',
          ));
          addedCount++;
        }
      }

      if (addedCount > 0) {
        // 4. Save back
        await _sectionDoc(projectId, 'requirements_implementation').set({
          'requirements': existingReqs.map((e) => e.toMap()).toList(),
          // Preserve other fields
          'notes': reqDoc.exists ? reqDoc.get('notes') : '',
          'checklist': reqDoc.exists ? reqDoc.get('checklist') : [],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return addedCount;
    } catch (e) {
      debugPrint('Error syncing scope to requirements: $e');
      return 0;
    }
  }

  String _buildRequirementId(int index) =>
      'REQ-${index.toString().padLeft(3, '0')}';

  String _inferRequirementType(String text) {
    final normalized = text.toLowerCase();
    const nonFunctionalSignals = [
      'latency',
      'performance',
      'security',
      'capacity',
      'safety',
      'compliance',
      'availability',
      'privacy',
      'access',
      'network',
      'load',
    ];
    return nonFunctionalSignals.any(normalized.contains)
        ? 'Non-Functional'
        : 'Functional';
  }

  String _defaultArtifactLabel(String text) {
    final requirementType = _inferRequirementType(text);
    if (requirementType == 'Non-Functional') {
      return 'Control narrative / compliance pack';
    }
    return 'Primary flow wireframe';
  }

  // --- Technical Alignment ---

  Future<Map<String, dynamic>> loadTechnicalAlignment(String projectId) async {
    try {
      final doc = await _sectionDoc(projectId, 'technical_alignment').get();
      return doc.data() ?? {};
    } catch (e) {
      debugPrint('Error loading technical alignment: $e');
      return {};
    }
  }

  Future<void> saveTechnicalAlignment(
    String projectId, {
    required String notes,
    required List<ConstraintRow> constraints,
    required List<RequirementMappingRow> mappings,
    required List<DependencyDecisionRow> dependencies,
    List<Map<String, dynamic>> methodologyStandards = const [],
    List<Map<String, dynamic>> readinessGateItems = const [],
    List<Map<String, dynamic>> traceabilityItems = const [],
  }) async {
    try {
      final data = <String, dynamic>{
        'notes': notes,
        'constraints': constraints.map((e) => e.toMap()).toList(),
        'mappings': mappings.map((e) => e.toMap()).toList(),
        'dependencies': dependencies.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (methodologyStandards.isNotEmpty) {
        data['methodologyStandards'] = methodologyStandards;
      }
      if (readinessGateItems.isNotEmpty) {
        data['readinessGateItems'] = readinessGateItems;
      }
      if (traceabilityItems.isNotEmpty) {
        data['traceabilityItems'] = traceabilityItems;
      }
      await _sectionDoc(projectId, 'technical_alignment')
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving technical alignment: $e');
      rethrow;
    }
  }

  // --- Specialized Design ---

  Future<SpecializedDesignData> loadSpecializedDesign(String projectId) async {
    try {
      final doc = await _sectionDoc(projectId, 'specialized_design').get();
      if (doc.exists && doc.data() != null) {
        return SpecializedDesignData.fromMap(doc.data()!);
      }
      return SpecializedDesignData();
    } catch (e) {
      debugPrint('Error loading specialized design: $e');
      return SpecializedDesignData();
    }
  }

  Future<void> saveSpecializedDesign(
      String projectId, SpecializedDesignData data) async {
    try {
      final map = data.toMap();
      map['updatedAt'] = FieldValue.serverTimestamp();
      await _sectionDoc(projectId, 'specialized_design')
          .set(map, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving specialized design: $e');
      rethrow;
    }
  }

  // --- Design Deliverables ---

  Future<DesignDeliverablesData?> loadDesignDeliverables(
      String projectId) async {
    try {
      final doc = await _sectionDoc(projectId, 'design_deliverables').get();
      if (doc.exists && doc.data() != null) {
        return DesignDeliverablesData.fromMap(doc.data()!);
      }
      return null; // Return null to signal "no data found", allowing fallback
    } catch (e) {
      debugPrint('Error loading design deliverables: $e');
      return null;
    }
  }

  Future<void> saveDesignDeliverables(
      String projectId, DesignDeliverablesData data) async {
    try {
      final map = data.toJson(); // DesignDeliverablesData uses toJson/fromJson
      map['updatedAt'] = FieldValue.serverTimestamp();
      await _sectionDoc(projectId, 'design_deliverables')
          .set(map, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving design deliverables: $e');
      rethrow;
    }
  }

  // --- Progress Calculation ---

  // --- Readiness Engine (Progress Calculation) ---

  Future<DesignReadinessModel> getDesignProgress(String projectId) async {
    try {
      // 1. Fetch all component data
      final reqDoc =
          await _sectionDoc(projectId, 'requirements_implementation').get();
      final alignDoc =
          await _sectionDoc(projectId, 'technical_alignment').get();
      // Architecture check (check if nodes exist)
      final archData = await ArchitectureService.load(projectId);

      // 2. Calculate Component Scores
      final double reqScore = _calculateRequirementsProgress(reqDoc.data());
      final double alignScore = _calculateAlignmentProgress(alignDoc.data());
      final double archScore = _calculateArchitectureProgress(archData);

      // Risk Score - Placeholder for now (would check if risks are mitigated)
      // For now, assume if Alignment is done, Risks are partially addressed
      double riskScore = alignScore * 0.8;
      if (reqScore > 0.8) riskScore += 0.2;

      // 3. Identify Missing Items
      final missingItems = <String>[];
      if (reqScore < 1.0) missingItems.add('Req. Checklist incomplete');
      if (alignScore < 0.5) missingItems.add('Tech Alignment pending');
      if (archScore < 0.1) missingItems.add('Architecture Diagram missing');
      // Add more specific checks...

      // 4. Calculate Overall Weighted Score
      // Specs: 30%, Alignment: 30%, Arch: 20%, Risk: 20%
      final double overall = (reqScore * 0.3) +
          (alignScore * 0.3) +
          (archScore * 0.2) +
          (riskScore * 0.2);

      return DesignReadinessModel(
        specificationsScore: reqScore,
        alignmentScore: alignScore,
        architectureScore: archScore,
        riskScore: riskScore,
        overallScore: overall,
        missingItems: missingItems,
      );
    } catch (e) {
      debugPrint('Error calculating design readiness: $e');
      return DesignReadinessModel();
    }
  }

  double _calculateRequirementsProgress(Map<String, dynamic>? data) {
    if (data == null) return 0.0;
    final checklist = (data['checklist'] as List?) ?? [];
    if (checklist.isEmpty) return 0.0;

    int completed = 0;
    for (var item in checklist) {
      final status = item['status']?.toString();
      if (status == 'ready' ||
          status == 'validated' ||
          status == 'ChecklistStatus.ready') {
        completed++;
      }
    }
    return completed / checklist.length;
  }

  double _calculateAlignmentProgress(Map<String, dynamic>? data) {
    if (data == null) return 0.0;
    final constraints = (data['constraints'] as List?) ?? [];
    final mappings = (data['mappings'] as List?) ?? [];
    final dependencies = (data['dependencies'] as List?) ?? [];

    final totalItems =
        constraints.length + mappings.length + dependencies.length;
    if (totalItems == 0) return 0.0;

    int completed = 0;
    for (var item in constraints) {
      if (item['status'] == 'Aligned' || item['status'] == 'Validated') {
        completed++;
      }
    }
    for (var item in mappings) {
      if (item['status'] == 'Aligned') completed++;
    }
    for (var item in dependencies) {
      if (item['status'] == 'Resolved' || item['status'] == 'Aligned') {
        completed++;
      }
    }
    return completed / totalItems;
  }

  double _calculateArchitectureProgress(Map<String, dynamic>? data) {
    if (data == null) return 0.0;
    final nodes = (data['nodes'] as List?) ?? [];
    // Basic heuristic: If > 5 nodes, assume some meaningful architecture exists
    if (nodes.isEmpty) return 0.0;
    return (nodes.length / 10).clamp(0.0, 1.0);
  }

  Stream<Map<String, dynamic>> calculateOverallProgress(String projectId) {
    return Stream.fromFuture(_getOverallProgressMap(projectId))
        .handleError((error) {
      debugPrint('Error in calculateOverallProgress stream: $error');
      return {'progress': 0.0, 'completed': 0, 'total': 14};
    });
  }

  Future<Map<String, dynamic>> _getOverallProgressMap(String projectId) async {
    try {
      final readiness = await getDesignProgress(projectId);
      final totalSections = 14;
      final completedSections =
          (readiness.overallScore * totalSections).round();

      return {
        'progress': readiness.overallScore,
        'completed': completedSections,
        'total': totalSections,
      };
    } catch (e) {
      debugPrint('Error getting overall progress map: $e');
      return {'progress': 0.0, 'completed': 0, 'total': 14};
    }
  }
}
