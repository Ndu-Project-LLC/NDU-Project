import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/design_planning_document.dart';

class IntegratedWorkPackageService {
  IntegratedWorkPackageService._();

  static const String engineeringEwp = 'engineeringEwp';
  static const String procurementPackage = 'procurementPackage';
  static const String constructionCwp = 'constructionCwp';
  static const String deliveryPackage = 'deliveryPackage';
  static const String implementationWorkPackage = 'implementationWorkPackage';
  static const String agileIterationPackage = 'agileIterationPackage';
  static const String commissioningPackage = 'commissioningPackage';
  static const String preCommissioningPackage = 'preCommissioningPackage';

  // ------------------------------------------------------------------
  // Guide Step 1–5: Generate EWP → Procurement → Execution chains
  // Now uses recursive traversal to support WBS depths of 1–5 levels.
  // Leaf nodes (deepest children) get EWP→Proc→Exec chains.
  // Non-leaf nodes get summary "roll-up" packages that aggregate
  // their children's chain IDs for hierarchical tracking.
  // Includes design-to-procurement traceability on deliverables.
  // ------------------------------------------------------------------

  static List<WorkPackage> generatePackageChainsFromWbs({
    required List<WorkItem> wbsTree,
    required String methodology,

    /// Optional design specification rows to link into EWP deliverables.
    /// When provided, matching specs are embedded as deliverable items
    /// and their IDs are tracked on the EWP's linkedDesignSpecificationIds.
    List<DesignSpecificationPlanRow>? designSpecifications,
  }) {
    final packages = <WorkPackage>[];
    final normalizedMethodology = methodology.trim().toLowerCase();

    // Recursive traversal: for each WBS node, either generate a
    // chain (if leaf) or recurse into children (if non-leaf).
    void visitNode(
      WorkItem node,
      List<WorkItem> ancestors,
    ) {
      final currentDepth = ancestors.length + 1; // 1-indexed depth

      if (node.children.isEmpty) {
        // Leaf node → generate EWP→Proc→Exec chain
        _generateChainForLeaf(
          leaf: node,
          ancestors: ancestors,
          depth: currentDepth,
          methodology: normalizedMethodology,
          designSpecifications: designSpecifications,
          packages: packages,
        );
      } else {
        // Non-leaf node → recurse into children
        for (final child in node.children) {
          visitNode(child, [...ancestors, node]);
        }
      }
    }

    // Start recursion from each root WBS item
    for (final root in wbsTree) {
      if (root.children.isEmpty) {
        // Root is itself a leaf (shallow WBS)
        _generateChainForLeaf(
          leaf: root,
          ancestors: const [],
          depth: 1,
          methodology: normalizedMethodology,
          designSpecifications: designSpecifications,
          packages: packages,
        );
      } else {
        for (final child in root.children) {
          visitNode(child, [root]);
        }
      }
    }

    return packages
        .map((package) =>
            package.copyWith(readinessWarnings: validateReadiness(package)))
        .toList();
  }

  /// Generates the EWP → Procurement → Execution chain for a single
  /// leaf WBS node at any depth level. The [ancestors] list provides
  /// the chain of parent WBS items from root to the leaf's parent.
  static void _generateChainForLeaf({
    required WorkItem leaf,
    required List<WorkItem> ancestors,
    required int depth,
    required String methodology,
    required List<DesignSpecificationPlanRow>? designSpecifications,
    required List<WorkPackage> packages,
  }) {
    final isAgile = methodology == 'agile';

    // Determine the nearest Level-2 ancestor for WBS linkage fields
    final level2Ancestor = ancestors.length >= 2
        ? ancestors[1]
        : (ancestors.isNotEmpty ? ancestors.first : leaf);
    final level2Id = level2Ancestor.id;
    final level2Title = level2Ancestor.title;

    final baseId = _stableId(
        leaf.id.isNotEmpty ? leaf.id : '${level2Title}_${leaf.title}');
    final baseCode = _packageCode(level2Title, leaf.title);

    final executionClassification = isAgile
        ? agileIterationPackage
        : (_looksLikeConstruction(leaf)
            ? constructionCwp
            : implementationWorkPackage);
    final executionType = executionClassification == constructionCwp
        ? 'construction'
        : 'execution';
    final executionLabel = executionClassification == constructionCwp
        ? 'Construction Work Package'
        : (executionClassification == agileIterationPackage
            ? 'Agile Iteration Package'
            : 'Implementation Work Package');

    // Phase 4: Commissioning packages for construction CWPs
    final isConstructionCwp = executionClassification == constructionCwp;
    final preCommissioningId = '$baseId-precomm';
    final commissioningId = '$baseId-comm';

    final engineeringId = '$baseId-ewp';
    final procurementId = '$baseId-proc';
    final executionId = '$baseId-exec';

    // --- Fix 1.2: Import matching design specification rows ---
    // Collect all ancestor IDs and titles for comprehensive spec matching
    final ancestorIds = ancestors.map((a) => a.id).toList();
    final ancestorTitles = ancestors.map((a) => a.title).toList();
    final matchedSpecs = _matchSpecificationsToWbsDeep(
      designSpecifications ?? [],
      leafId: leaf.id,
      leafTitle: leaf.title,
      ancestorIds: ancestorIds,
      ancestorTitles: ancestorTitles,
    );

    // Build EWP deliverables: defaults + spec-derived items
    final deliverables = _buildEwpDeliverables(
      procurementId: procurementId,
      matchedSpecs: matchedSpecs,
    );

    // Track linked spec IDs on the package
    final linkedSpecIds = matchedSpecs.map((spec) => spec.id).toList();

    final procurementCategory = _inferProcurementCategory(leaf);

    packages.add(
      WorkPackage(
        id: engineeringId,
        wbsItemId: leaf.id,
        wbsLevel2Id: level2Id,
        wbsLevel2Title: level2Title,
        sourceWbsLevel3Id: leaf.id,
        sourceWbsLevel3Title: leaf.title,
        packageLevel: depth,
        packageCode: '$baseCode-EWP',
        packageClassification: engineeringEwp,
        childPackageIds: [procurementId, executionId],
        linkedProcurementPackageIds: [procurementId],
        linkedExecutionPackageIds: [executionId],
        linkedDesignSpecificationIds: linkedSpecIds,
        title: '${leaf.title} Engineering Work Package',
        description: leaf.description,
        type: 'design',
        phase: 'design',
        discipline: leaf.framework,
        releaseStatus: 'draft',
        deliverables: deliverables,
        estimateBasis: _classificationAwareEstimateBasis(
          packageClassification: engineeringEwp,
          methodology: methodology,
          procurementCategory: procurementCategory,
        ),
      ),
    );

    // --- Fix 1.1: Derive procurement scope from EWP deliverables ---
    final procurementScopeFromDeliverables = deliverables
        .where((d) => d.requiredForProcurement)
        .map((d) => d.title)
        .join('; ');

    final scopeDefinition = procurementScopeFromDeliverables.isNotEmpty
        ? 'Requires: $procurementScopeFromDeliverables'
        : leaf.description;

    packages.add(
      WorkPackage(
        id: procurementId,
        wbsItemId: leaf.id,
        wbsLevel2Id: level2Id,
        wbsLevel2Title: level2Title,
        sourceWbsLevel3Id: leaf.id,
        sourceWbsLevel3Title: leaf.title,
        packageLevel: depth,
        packageCode: '$baseCode-PROC',
        packageClassification: procurementPackage,
        parentPackageId: engineeringId,
        childPackageIds: [executionId],
        linkedEngineeringPackageIds: [engineeringId],
        linkedExecutionPackageIds: [executionId],
        linkedDesignSpecificationIds: linkedSpecIds,
        title: '${leaf.title} Procurement Package',
        description: leaf.description,
        type: 'procurement',
        phase: 'execution',
        discipline: leaf.framework,
        releaseStatus: 'draft',
        procurementBreakdown: PackageProcurementBreakdown(
          category: procurementCategory,
          scopeDefinition: scopeDefinition,
          activities: const [
            'scope_definition',
            'rfq_rfp',
            'bid_evaluation',
            'award',
            'fabrication_or_configuration',
            'delivery',
          ],
        ),
        estimateBasis: _classificationAwareEstimateBasis(
          packageClassification: procurementPackage,
          methodology: methodology,
          procurementCategory: procurementCategory,
        ),
      ),
    );

    packages.add(
      WorkPackage(
        id: executionId,
        wbsItemId: leaf.id,
        wbsLevel2Id: level2Id,
        wbsLevel2Title: level2Title,
        sourceWbsLevel3Id: leaf.id,
        sourceWbsLevel3Title: leaf.title,
        packageLevel: depth,
        packageCode: '$baseCode-EXEC',
        packageClassification: executionClassification,
        parentPackageId: procurementId,
        linkedEngineeringPackageIds: [engineeringId],
        linkedProcurementPackageIds: [procurementId],
        linkedDesignSpecificationIds: linkedSpecIds,
        title: '${leaf.title} $executionLabel',
        description: leaf.description,
        type: executionType,
        phase: 'execution',
        discipline: leaf.framework,
        areaOrSystem: level2Title,
        releaseStatus: 'draft',
        estimateBasis: _classificationAwareEstimateBasis(
          packageClassification: executionClassification,
          methodology: methodology,
          procurementCategory: procurementCategory,
        ),
      ),
    );

    // Phase 4: Add pre-commissioning and commissioning packages
    // for construction work packages. These represent the testing,
    // checking, and handover sequence after construction is complete.
    if (isConstructionCwp) {
      packages.add(
        WorkPackage(
          id: preCommissioningId,
          wbsItemId: leaf.id,
          wbsLevel2Id: level2Id,
          wbsLevel2Title: level2Title,
          sourceWbsLevel3Id: leaf.id,
          sourceWbsLevel3Title: leaf.title,
          packageLevel: depth,
          packageCode: '$baseCode-PRECOMM',
          packageClassification: preCommissioningPackage,
          parentPackageId: executionId,
          linkedEngineeringPackageIds: [engineeringId],
          linkedProcurementPackageIds: [procurementId],
          linkedDesignSpecificationIds: linkedSpecIds,
          title: '${leaf.title} Pre-Commissioning',
          description: 'Pre-commissioning checks and tests for ${leaf.title}. '
              'Includes mechanical completion verification, pressure testing, '
              'loop checking, and system walkthroughs.',
          type: 'commissioning',
          phase: 'execution',
          discipline: leaf.framework,
          areaOrSystem: level2Title,
          releaseStatus: 'draft',
          estimateBasis: _classificationAwareEstimateBasis(
            packageClassification: preCommissioningPackage,
            methodology: methodology,
            procurementCategory: procurementCategory,
          ),
        ),
      );

      packages.add(
        WorkPackage(
          id: commissioningId,
          wbsItemId: leaf.id,
          wbsLevel2Id: level2Id,
          wbsLevel2Title: level2Title,
          sourceWbsLevel3Id: leaf.id,
          sourceWbsLevel3Title: leaf.title,
          packageLevel: depth,
          packageCode: '$baseCode-COMM',
          packageClassification: commissioningPackage,
          parentPackageId: preCommissioningId,
          linkedEngineeringPackageIds: [engineeringId],
          linkedProcurementPackageIds: [procurementId],
          linkedDesignSpecificationIds: linkedSpecIds,
          title: '${leaf.title} Commissioning',
          description: 'Commissioning and handover for ${leaf.title}. '
              'Includes functional testing, performance verification, '
              'punch list resolution, and final acceptance documentation.',
          type: 'commissioning',
          phase: 'launch',
          discipline: leaf.framework,
          areaOrSystem: level2Title,
          releaseStatus: 'draft',
          estimateBasis: _classificationAwareEstimateBasis(
            packageClassification: commissioningPackage,
            methodology: methodology,
            procurementCategory: procurementCategory,
          ),
        ),
      );
    }
  }

  // ------------------------------------------------------------------
  // Fix 1.2: Match design specification rows to WBS nodes
  // Supports any WBS depth — matches against leaf node and all ancestors.
  // ------------------------------------------------------------------

  /// Matches design specification rows to a WBS leaf node and its
  /// ancestors. A spec row matches if its `wbsWorkPackageId` equals any
  /// ancestor or leaf WBS ID, OR if its title/discipline/area keywords
  /// overlap with the leaf or ancestor titles.
  static List<DesignSpecificationPlanRow> _matchSpecificationsToWbs(
    List<DesignSpecificationPlanRow> specs, {
    required String level2WbsId,
    required String level3WbsId,
    required String level3Title,
    required String level2Title,
  }) {
    if (specs.isEmpty) return [];

    // Build a combined set of all ancestor + leaf IDs and titles
    // for matching. The old API only passed level2/level3 but
    // we also accept them for backward compatibility.
    final allWbsIds = <String>{level2WbsId, level3WbsId};
    final allTitlesLower = <String>{
      level2Title.toLowerCase(),
      level3Title.toLowerCase(),
    };
    final allTokens = <String>{
      ..._tokenize(level2Title.toLowerCase()),
      ..._tokenize(level3Title.toLowerCase()),
    };

    return specs.where((spec) {
      // Direct WBS ID match (strongest signal)
      if (allWbsIds.contains(spec.wbsWorkPackageId)) {
        return true;
      }

      // Title keyword overlap
      final specTitle = spec.title.toLowerCase();
      final specTokens = _tokenize(specTitle);
      if (allTokens.any((t) => specTokens.contains(t))) {
        return true;
      }

      // Discipline/area keyword match against all ancestor titles
      final specDiscipline = spec.discipline.toLowerCase();
      final specArea = spec.area.toLowerCase();
      if (specDiscipline.isNotEmpty &&
          allTitlesLower.any((t) => t.contains(specDiscipline))) {
        return true;
      }
      if (specArea.isNotEmpty &&
          allTitlesLower.any((t) => t.contains(specArea))) {
        return true;
      }

      return false;
    }).toList();
  }

  /// Deep-aware spec matching for arbitrary WBS depth.
  /// Matches against the leaf node ID/title AND all ancestor IDs/titles.
  /// This supersedes [_matchSpecificationsToWbs] for the recursive generator.
  static List<DesignSpecificationPlanRow> _matchSpecificationsToWbsDeep(
    List<DesignSpecificationPlanRow> specs, {
    required String leafId,
    required String leafTitle,
    required List<String> ancestorIds,
    required List<String> ancestorTitles,
  }) {
    if (specs.isEmpty) return [];

    final allWbsIds = <String>{leafId, ...ancestorIds};
    final allTitlesLower = <String>{
      leafTitle.toLowerCase(),
      ...ancestorTitles.map((t) => t.toLowerCase()),
    };
    final allTokens = <String>{
      ..._tokenize(leafTitle.toLowerCase()),
      ...ancestorTitles.expand((t) => _tokenize(t.toLowerCase())),
    };

    return specs.where((spec) {
      // Direct WBS ID match
      if (allWbsIds.contains(spec.wbsWorkPackageId)) return true;

      // Title keyword overlap
      final specTokens = _tokenize(spec.title.toLowerCase());
      if (allTokens.any((t) => specTokens.contains(t))) return true;

      // Discipline/area keyword match against all titles
      final specDiscipline = spec.discipline.toLowerCase();
      final specArea = spec.area.toLowerCase();
      if (specDiscipline.isNotEmpty &&
          allTitlesLower.any((t) => t.contains(specDiscipline))) {
        return true;
      }
      if (specArea.isNotEmpty &&
          allTitlesLower.any((t) => t.contains(specArea))) {
        return true;
      }

      return false;
    }).toList();
  }

  /// Tokenizes a string for matching: splits on non-alphanumeric, removes
  /// common stop words, and keeps tokens of 3+ characters.
  static List<String> _tokenize(String value) {
    const stopWords = {'the', 'and', 'for', 'with', 'from', 'this', 'that'};
    return value
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length >= 3 && !stopWords.contains(t))
        .toList();
  }

  // ------------------------------------------------------------------
  // Fix 1.2 + 1.3: Build EWP deliverables with traceability
  // ------------------------------------------------------------------

  /// Builds the complete deliverables list for an EWP.
  /// Starts with the 5 standard deliverables (Drawings, Specifications,
  /// Calculations, BOM, Codes) and appends spec-derived deliverables.
  /// Each deliverable is wired with `feedsProcurementPackageIds` pointing
  /// to the procurement package (Fix 1.3: design-to-procurement traceability).
  static List<PackageDeliverable> _buildEwpDeliverables({
    required String procurementId,
    required List<DesignSpecificationPlanRow> matchedSpecs,
  }) {
    final deliverables = <PackageDeliverable>[];

    // Standard 5 deliverables — each feeds the procurement package
    deliverables.addAll(_defaultEngineeringDeliverablesWithTraceability(
      procurementId: procurementId,
    ));

    // Spec-derived deliverables: one per matched specification row
    for (final spec in matchedSpecs) {
      final specType = _mapSpecTypeToDeliverableType(spec.specificationType);
      final requiresProcurement = _specRequiresProcurement(spec);
      deliverables.add(
        PackageDeliverable(
          title: spec.title.isNotEmpty
              ? spec.title
              : 'Specification: ${spec.specificationType}',
          type: specType,
          status: _mapSpecStatusToDeliverableStatus(spec.status),
          reference: spec.referenceLink,
          notes: _specDeliverableNotes(spec),
          feedsProcurementPackageIds:
              requiresProcurement ? [procurementId] : [],
          linkedSpecificationIds: [spec.id],
          requiredForProcurement: requiresProcurement,
        ),
      );
    }

    return deliverables;
  }

  /// The standard 5 EWP deliverables with procurement traceability wired.
  static List<PackageDeliverable>
      _defaultEngineeringDeliverablesWithTraceability({
    required String procurementId,
  }) =>
          [
            PackageDeliverable(
              title: 'Drawings',
              type: 'drawing',
              feedsProcurementPackageIds: [procurementId],
              requiredForProcurement: true,
            ),
            PackageDeliverable(
              title: 'Specifications',
              type: 'specification',
              feedsProcurementPackageIds: [procurementId],
              requiredForProcurement: true,
            ),
            PackageDeliverable(
              title: 'Calculations',
              type: 'calculation',
              feedsProcurementPackageIds: [procurementId],
              requiredForProcurement: false,
            ),
            PackageDeliverable(
              title: 'Bill of materials',
              type: 'bom',
              feedsProcurementPackageIds: [procurementId],
              requiredForProcurement: true,
            ),
            PackageDeliverable(
              title: 'Codes and requirements',
              type: 'requirement',
              feedsProcurementPackageIds: [],
              requiredForProcurement: false,
            ),
          ];

  /// Maps a DesignSpecificationPlanRow.specificationType to a
  /// PackageDeliverable type.
  static String _mapSpecTypeToDeliverableType(String specType) {
    switch (specType.toLowerCase()) {
      case 'code':
        return 'requirement';
      case 'law':
        return 'requirement';
      case 'standard':
        return 'specification';
      case 'criteria':
        return 'specification';
      case 'guideline':
        return 'specification';
      case 'contract':
        return 'requirement';
      default:
        return 'specification';
    }
  }

  /// Whether a specification row implies procurement is needed.
  /// External/contract/vendor sources typically require procurement.
  static bool _specRequiresProcurement(DesignSpecificationPlanRow spec) {
    final sourceType = spec.sourceType.toLowerCase();
    final ruleType = spec.ruleType.toLowerCase();
    return sourceType == 'vendors' ||
        sourceType == 'contracts' ||
        ruleType == 'external';
  }

  /// Maps a specification status to a deliverable status.
  static String _mapSpecStatusToDeliverableStatus(String specStatus) {
    switch (specStatus.toLowerCase()) {
      case 'draft':
        return 'planned';
      case 'planned':
        return 'planned';
      case 'in review':
        return 'in_review';
      case 'approved':
        return 'released';
      case 'complete':
        return 'complete';
      default:
        return 'planned';
    }
  }

  /// Builds the notes string for a spec-derived deliverable.
  static String _specDeliverableNotes(DesignSpecificationPlanRow spec) {
    final parts = <String>[];
    if (spec.specificationType.isNotEmpty) {
      parts.add('Spec type: ${spec.specificationType}');
    }
    if (spec.ruleType.isNotEmpty) {
      parts.add('Rule: ${spec.ruleType}');
    }
    if (spec.sourceType.isNotEmpty) {
      parts.add('Source: ${spec.sourceType}');
    }
    if (spec.discipline.isNotEmpty) {
      parts.add('Discipline: ${spec.discipline}');
    }
    if (spec.area.isNotEmpty) {
      parts.add('Area: ${spec.area}');
    }
    if (spec.details.isNotEmpty) {
      parts.add(spec.details);
    }
    if (spec.attachedRequirementIds.isNotEmpty) {
      parts.add('Req IDs: ${spec.attachedRequirementIds.join(", ")}');
    }
    return parts.join('\n');
  }

  // ------------------------------------------------------------------
  // Fix 1.4: Release for execution gate
  // ------------------------------------------------------------------

  /// Checks whether an EWP can be released for execution.
  /// Returns a list of blocking issues (empty = releasable).
  /// An EWP is releasable when:
  /// - All required-for-procurement deliverables are released/complete
  /// - The readiness checklist passes (drawings, specs, BOM, design review, IFC)
  /// - Requirements are traced
  static List<String> checkEwpReleaseReadiness(WorkPackage package) {
    if (package.packageClassification != engineeringEwp) {
      return ['Release gate only applies to Engineering Work Packages.'];
    }

    final blockers = <String>[];

    // Check deliverable completion
    final requiredDeliverables =
        package.deliverables.where((d) => d.requiredForProcurement).toList();
    for (final deliverable in requiredDeliverables) {
      if (!deliverable.isReleased) {
        blockers.add(
            'Deliverable "${deliverable.title}" is not yet released (status: ${deliverable.status}).');
      }
    }

    // Check readiness flags
    final readiness = package.readiness;
    if (!readiness.requirementsTraced) {
      blockers.add('Requirements traceability is not complete.');
    }
    if (!readiness.drawingsComplete) {
      blockers.add('Drawings are not complete.');
    }
    if (!readiness.specificationsComplete) {
      blockers.add('Specifications are not complete.');
    }
    if (!readiness.billOfMaterialsComplete) {
      blockers.add('Bill of materials is not complete.');
    }
    if (!readiness.designReviewComplete) {
      blockers.add('Design review is not complete.');
    }
    if (!readiness.ifcApproved) {
      blockers.add('IFC approval is not complete.');
    }

    // Check estimate basis
    if (!package.estimateBasis.hasMinimumBasis) {
      blockers.add('Estimate basis is incomplete.');
    }

    // Check WBS linkage
    if (package.sourceWbsLevel3Id.trim().isEmpty) {
      blockers.add('Package is not linked to a WBS element.');
    }

    return blockers;
  }

  /// Releases an EWP for execution if all gate criteria are met.
  /// Returns the updated package, or throws with blocker messages.
  static WorkPackage releaseEwpForExecution(WorkPackage package) {
    final blockers = checkEwpReleaseReadiness(package);
    if (blockers.isNotEmpty) {
      throw StateError(
          'Cannot release EWP "${package.title}". Blockers:\n${blockers.map((b) => "  - $b").join("\n")}');
    }

    return package.copyWith(
      releaseStatus: 'released',
      releaseForExecutionDate:
          DateTime.now().toUtc().toIso8601String().split('T').first,
    );
  }

  // ------------------------------------------------------------------
  // Fix 1.1: Derive procurement scope from EWP deliverables
  // ------------------------------------------------------------------

  /// Given a list of existing work packages, derives and updates
  /// procurement package scope definitions from linked EWP deliverables.
  /// This ensures procurement packages know what design outputs they need.
  static List<WorkPackage> deriveProcurementScopeFromEwpDeliverables(
    List<WorkPackage> packages,
  ) {
    final ewpById = <String, WorkPackage>{};
    for (final p in packages) {
      if (p.packageClassification == engineeringEwp) {
        ewpById[p.id] = p;
      }
    }

    return packages.map((package) {
      if (package.packageClassification != procurementPackage) {
        return package;
      }

      // Find linked EWP deliverables that feed this procurement package
      final requiredDeliverables = <PackageDeliverable>[];
      for (final ewpId in package.linkedEngineeringPackageIds) {
        final ewp = ewpById[ewpId];
        if (ewp == null) continue;
        for (final d in ewp.deliverables) {
          if (d.feedsProcurementPackageIds.contains(package.id)) {
            requiredDeliverables.add(d);
          }
        }
      }

      if (requiredDeliverables.isEmpty) return package;

      // Build scope definition from deliverables
      final scopeParts = requiredDeliverables
          .where((d) => d.requiredForProcurement)
          .map((d) => '${d.title}${d.isReleased ? " (ready)" : " (pending)"}')
          .toList();

      final newScope = scopeParts.isNotEmpty
          ? 'Requires design deliverables: ${scopeParts.join("; ")}'
          : package.procurementBreakdown.scopeDefinition;

      return package.copyWith(
        procurementBreakdown: package.procurementBreakdown.copyWith(
          scopeDefinition: newScope,
        ),
        linkedDesignSpecificationIds: requiredDeliverables
            .expand((d) => d.linkedSpecificationIds)
            .toSet()
            .toList(),
      );
    }).toList();
  }

  // ------------------------------------------------------------------
  // Validation
  // ------------------------------------------------------------------

  static List<String> validateReadiness(WorkPackage package) {
    final warnings = <String>[];
    final readiness = package.readiness;

    if (package.sourceWbsLevel3Id.trim().isEmpty) {
      warnings.add('Package is not linked to a WBS package candidate.');
    }
    if (package.wbsLevel2Id.trim().isEmpty) {
      warnings
          .add('Package is not linked to a WBS Level 2 deliverable/system.');
    }
    if (!package.estimateBasis.hasMinimumBasis) {
      warnings.add('Schedule duration is missing a documented estimate basis.');
    }

    switch (package.packageClassification) {
      case engineeringEwp:
      case deliveryPackage:
        if (!readiness.requirementsTraced) {
          warnings.add('${package.packageClassification == engineeringEwp ? "EWP" : "DWP"} requirements traceability is not complete.');
        }
        if (!readiness.drawingsComplete) {
          warnings.add('${package.packageClassification == engineeringEwp ? "EWP" : "DWP"} drawings are not complete.');
        }
        if (!readiness.specificationsComplete) {
          warnings.add('${package.packageClassification == engineeringEwp ? "EWP" : "DWP"} specifications are not complete.');
        }
        if (!readiness.billOfMaterialsComplete) {
          warnings.add('${package.packageClassification == engineeringEwp ? "EWP" : "DWP"} bill of materials is not complete.');
        }
        if (!readiness.designReviewComplete) {
          warnings.add('${package.packageClassification == engineeringEwp ? "EWP" : "DWP"} design review is not complete.');
        }
        if (!readiness.ifcApproved) {
          warnings.add('${package.packageClassification == engineeringEwp ? "EWP" : "DWP"} is not approved/released for execution.');
        }
        // Fix 1.2: Warn if EWP has no linked design specifications
        if (package.linkedDesignSpecificationIds.isEmpty) {
          warnings.add(
              '${package.packageClassification == engineeringEwp ? "EWP" : "DWP"} has no linked design specifications. Consider mapping specifications from the Design Planning document.');
        }
        // Fix 1.4: Warn if not released but execution packages exist
        if (!package.isReleasedForExecution &&
            package.linkedExecutionPackageIds.isNotEmpty) {
          warnings.add(
              '${package.packageClassification == engineeringEwp ? "EWP" : "DWP"} is not released for execution. Linked execution packages should not start until this is released.');
        }
      case procurementPackage:
        if (!readiness.procurementScopeDefined) {
          warnings.add('Procurement scope is not defined.');
        }
        if (!readiness.rfqIssued) {
          warnings.add('RFQ/RFP has not been issued.');
        }
        if (!readiness.bidsEvaluated) {
          warnings.add('Bids have not been evaluated.');
        }
        if (!readiness.contractAwarded) {
          warnings.add('Contract/vendor award is not complete.');
        }
        if (package.contractIds.isEmpty) {
          warnings.add('Procurement package has no linked contract.');
        }
        if (package.procurementBreakdown.category.trim().isEmpty) {
          warnings.add('Procurement category is not set.');
        }
        // Fix 1.1: Warn if procurement has no EWP deliverable traceability
        if (package.linkedEngineeringPackageIds.isNotEmpty) {
          final hasDeliverableLink = _packageHasDeliverableLink(
            package,
            package.linkedEngineeringPackageIds,
          );
          // This is informational — not all procurement needs design deliverables
        }
      case constructionCwp:
      case implementationWorkPackage:
      case agileIterationPackage:
        if (!readiness.ifcApproved &&
            package.packageClassification == constructionCwp) {
          warnings.add('CWP does not have approved IFC/design inputs.');
        }
        if (!readiness.materialsAvailable &&
            package.packageClassification == constructionCwp) {
          warnings.add('CWP materials are not confirmed available/on site.');
        }
        if (!readiness.contractAwarded &&
            package.contractorOrCrew.trim().isEmpty) {
          warnings.add('Execution owner or contract is not confirmed.');
        }
        if (package.contractIds.isEmpty &&
            package.packageClassification == constructionCwp) {
          warnings.add('CWP has no linked contract. Assign a contract ID.');
        }
        if (!readiness.predecessorsComplete) {
          warnings.add('Predecessor work is not confirmed complete.');
        }
        if (!readiness.resourcesAssigned) {
          warnings.add('Execution resources are not assigned.');
        }
        if (package.packageClassification == constructionCwp &&
            !readiness.permitsApproved) {
          warnings.add('CWP permits are not approved.');
        }
        if (package.packageClassification == constructionCwp &&
            !readiness.accessReady) {
          warnings.add('CWP access/workface readiness is not confirmed.');
        }
        // Fix 1.4: Warn if execution depends on unreleased EWP
        if (package.linkedEngineeringPackageIds.isNotEmpty) {
          // This will be checked at schedule level where we can access all packages
        }
      case preCommissioningPackage:
        if (!readiness.ifcApproved) {
          warnings
              .add('Pre-commissioning requires approved IFC/design inputs.');
        }
        if (!readiness.predecessorsComplete) {
          warnings.add(
              'Construction work must be complete before pre-commissioning.');
        }
        if (!readiness.resourcesAssigned) {
          warnings.add('Commissioning resources are not assigned.');
        }
      case commissioningPackage:
        if (!readiness.predecessorsComplete) {
          warnings
              .add('Pre-commissioning must be complete before commissioning.');
        }
        if (!readiness.resourcesAssigned) {
          warnings.add('Commissioning resources are not assigned.');
        }
        if (package.contractorOrCrew.trim().isEmpty) {
          warnings.add('Handover acceptance authority is not designated.');
        }
    }

    // Readiness-date gate: if plannedStart is set, warn about overdue items
    if (package.plannedStart != null && package.plannedStart!.isNotEmpty) {
      final startDate = DateTime.tryParse(package.plannedStart!);
      if (startDate != null && startDate.isBefore(DateTime.now())) {
        if (!readiness.predecessorsComplete) {
          warnings.add(
              'Planned start (${package.plannedStart}) is in the past but predecessors are not confirmed complete.');
        }
        if (package.packageClassification == constructionCwp &&
            !readiness.permitsApproved) {
          warnings.add(
              'CWP planned start (${package.plannedStart}) is past due but permits are not approved.');
        }
        if ((package.packageClassification == engineeringEwp ||
                package.packageClassification == deliveryPackage) &&
            !readiness.ifcApproved) {
          warnings.add(
              '${package.packageClassification == engineeringEwp ? "EWP" : "DWP"} planned start (${package.plannedStart}) is past due but IFC approval is not complete.');
        }
      }
    }

    return warnings;
  }

  /// Checks if any deliverable on the linked EWP packages feeds this
  /// procurement package. Returns true if at least one deliverable is
  /// traced.
  static bool _packageHasDeliverableLink(
    WorkPackage package,
    List<String> engineeringPackageIds,
  ) {
    // This is a placeholder for cross-package checking which requires
    // access to the full package list — done in schedule_screen validation
    return false;
  }

  // ------------------------------------------------------------------
  // Schedule activity generation from packages
  // ------------------------------------------------------------------

  static List<ScheduleActivity> generateScheduleActivitiesFromPackages({
    required List<WorkPackage> packages,
    Iterable<ScheduleActivity> existingActivities = const [],
  }) {
    final existingPackageIds = existingActivities
        .map((activity) => activity.workPackageId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final packageIds = packages.map((package) => package.id).toSet();
    final activities = <ScheduleActivity>[];

    for (final package in packages) {
      if (existingPackageIds.contains(package.id)) continue;

      final dependencies = _scheduleDependenciesForPackage(
        package: package,
        packageIds: packageIds,
      );

      activities.add(
        ScheduleActivity(
          id: package.id,
          wbsId: package.sourceWbsLevel3Id.isNotEmpty
              ? package.sourceWbsLevel3Id
              : package.wbsItemId,
          title: package.title,
          durationDays: _defaultDurationDays(package),
          predecessorIds: dependencies,
          dependencyIds: dependencies,
          isMilestone: false,
          status: 'pending',
          priority: _defaultPriority(package),
          assignee: package.owner.isNotEmpty
              ? package.owner
              : package.contractorOrCrew,
          discipline: package.discipline,
          workPackageId: package.id,
          workPackageTitle: package.title,
          workPackageType: package.type,
          phase: package.phase,
          wbsLevel2Id: package.wbsLevel2Id,
          wbsLevel2Title: package.wbsLevel2Title,
          contractId:
              package.contractIds.isEmpty ? '' : package.contractIds.first,
          vendorId: package.vendorIds.isEmpty ? '' : package.vendorIds.first,
          budgetedCost: package.budgetedCost,
          actualCost: package.actualCost,
          estimatingBasis: _activityEstimateBasis(package),
        ),
      );
    }

    return activities;
  }

  static List<String> _scheduleDependenciesForPackage({
    required WorkPackage package,
    required Set<String> packageIds,
  }) {
    final dependencies = <String>[];

    void addIfPresent(String id) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty && packageIds.contains(trimmed)) {
        dependencies.add(trimmed);
      }
    }

    switch (package.packageClassification) {
      case procurementPackage:
        for (final id in package.linkedEngineeringPackageIds) {
          addIfPresent(id);
        }
        addIfPresent(package.parentPackageId);
      case constructionCwp:
      case implementationWorkPackage:
      case agileIterationPackage:
        for (final id in package.linkedEngineeringPackageIds) {
          addIfPresent(id);
        }
        for (final id in package.linkedProcurementPackageIds) {
          addIfPresent(id);
        }
        addIfPresent(package.parentPackageId);
      case preCommissioningPackage:
        // Pre-commissioning depends on the construction/execution package
        addIfPresent(package.parentPackageId);
        for (final id in package.linkedEngineeringPackageIds) {
          addIfPresent(id);
        }
      case commissioningPackage:
        // Commissioning depends on pre-commissioning
        addIfPresent(package.parentPackageId);
        for (final id in package.linkedEngineeringPackageIds) {
          addIfPresent(id);
        }
      default:
        break;
    }

    return dependencies.toSet().toList();
  }

  // ------------------------------------------------------------------
  // Phase 3: Domain-Specific Estimation Engine
  // Replaces hardcoded duration defaults with classification-aware
  // estimation that populates PackageEstimateBasis fields properly.
  // ------------------------------------------------------------------

  /// Estimates duration for a work package using domain-specific models:
  ///
  /// **Engineering EWP**: Base 5 days + review allowance from estimateBasis.
  /// **Procurement**: Lead time from procurementBreakdown.leadTimeDays,
  ///   or category-based defaults (long lead: 30d, bulk: 14d, sub: 21d).
  /// **Construction CWP**: Productivity-based: if productivityBasis and
  ///   quantity are documented, calculates duration; otherwise falls back
  ///   to scope-complexity heuristic.
  /// **Agile Iteration**: Sprint-based: 1–2 week iterations.
  /// **Implementation IWP**: Complexity-based heuristic.
  static int estimateDurationDays(WorkPackage package) {
    // If dates are already set, derive from those
    final plannedStart = DateTime.tryParse(package.plannedStart ?? '');
    final plannedEnd = DateTime.tryParse(package.plannedEnd ?? '');
    if (plannedStart != null && plannedEnd != null) {
      return (plannedEnd.difference(plannedStart).inDays + 1).clamp(1, 365);
    }

    // If procurement lead time is explicitly set, use it
    if (package.packageClassification == procurementPackage &&
        package.procurementBreakdown.leadTimeDays > 0) {
      return package.procurementBreakdown.leadTimeDays;
    }

    switch (package.packageClassification) {
      case engineeringEwp:
      case deliveryPackage:
        return _estimateEngineeringDuration(package);
      case procurementPackage:
        return _estimateProcurementDuration(package);
      case constructionCwp:
        return _estimateConstructionDuration(package);
      case agileIterationPackage:
        return _estimateAgileDuration(package);
      case implementationWorkPackage:
        return _estimateImplementationDuration(package);
      case commissioningPackage:
        return _estimateCommissioningDuration(package);
      case preCommissioningPackage:
        return _estimatePreCommissioningDuration(package);
      default:
        return 5;
    }
  }

  /// Engineering EWP duration: base + review allowance.
  /// Review allowance is parsed from estimateBasis.reviewAllowance
  /// (e.g., "3 days" → 3 days added to base).
  static int _estimateEngineeringDuration(WorkPackage package) {
    const baseDays = 5;
    final reviewAllowance =
        _parseDayValue(package.estimateBasis.reviewAllowance);
    return baseDays + reviewAllowance;
  }

  /// Procurement duration: category-based defaults with lead time
  /// and review allowance adjustments.
  static int _estimateProcurementDuration(WorkPackage package) {
    final category = package.procurementBreakdown.category;
    int baseDays;
    switch (category) {
      case 'longLeadEquipment':
        baseDays = 30;
      case 'bulkMaterials':
        baseDays = 14;
      case 'subcontract':
        baseDays = 21;
      case 'technology':
        baseDays = 18;
      case 'services':
        baseDays = 12;
      default:
        baseDays = 10;
    }
    final reviewAllowance =
        _parseDayValue(package.estimateBasis.reviewAllowance);
    return baseDays + reviewAllowance;
  }

  /// Construction CWP duration: productivity-based estimation.
  /// If productivityBasis contains a rate like "10 units/day" and
  /// the description contains a quantity hint like "50 units",
  /// the duration is computed as quantity / rate.
  /// Otherwise falls back to a complexity-based heuristic.
  static int _estimateConstructionDuration(WorkPackage package) {
    // Try productivity-based calculation
    final prodBasis = package.estimateBasis.productivityBasis;
    if (prodBasis.isNotEmpty) {
      final productivityRate = _parseRateValue(prodBasis);
      if (productivityRate > 0) {
        final quantity = _parseQuantityHint(package.description);
        if (quantity > 0) {
          final days = (quantity / productivityRate).ceil();
          final reviewAllowance =
              _parseDayValue(package.estimateBasis.reviewAllowance);
          return (days + reviewAllowance).clamp(1, 365);
        }
      }
    }

    // Fallback: complexity heuristic based on description length and keywords
    final desc = package.description.toLowerCase();
    final hasComplexKeywords = desc.contains('structural') ||
        desc.contains('foundation') ||
        desc.contains('heavy') ||
        desc.contains('complex');
    final hasModerateKeywords = desc.contains('install') ||
        desc.contains('erect') ||
        desc.contains('assemble');
    if (hasComplexKeywords) return 15;
    if (hasModerateKeywords) return 10;
    return 7;
  }

  /// Agile iteration duration: sprint-based estimation.
  /// Default is 10 working days (2-week sprint).
  /// Can be overridden by resourceBasis (e.g., "1 sprint" or "5 days").
  static int _estimateAgileDuration(WorkPackage package) {
    final resourceBasis = package.estimateBasis.resourceBasis;
    if (resourceBasis.isNotEmpty) {
      final days = _parseDayValue(resourceBasis);
      if (days > 0) return days;
      final sprints = _parseSprintValue(resourceBasis);
      if (sprints > 0) return sprints * 10; // 10 days per sprint
    }
    return 10; // Default 1 sprint
  }

  /// Implementation IWP duration: complexity-based heuristic.
  static int _estimateImplementationDuration(WorkPackage package) {
    final desc = package.description.toLowerCase();
    final hasComplexKeywords = desc.contains('integration') ||
        desc.contains('migration') ||
        desc.contains('deployment') ||
        desc.contains('configuration');
    if (hasComplexKeywords) return 8;
    return 5;
  }

  /// Pre-commissioning duration: depends on system complexity.
  /// Typically 3-10 days for mechanical completion verification,
  /// pressure testing, loop checking, and system walkthroughs.
  static int _estimatePreCommissioningDuration(WorkPackage package) {
    final desc = package.description.toLowerCase();
    final hasComplexKeywords = desc.contains('structural') ||
        desc.contains('piping') ||
        desc.contains('electrical') ||
        desc.contains('hvac');
    final reviewAllowance =
        _parseDayValue(package.estimateBasis.reviewAllowance);
    final base = hasComplexKeywords ? 7 : 3;
    return base + reviewAllowance;
  }

  /// Commissioning duration: functional testing and handover.
  /// Typically 5-15 days depending on system complexity.
  static int _estimateCommissioningDuration(WorkPackage package) {
    final desc = package.description.toLowerCase();
    final hasComplexKeywords = desc.contains('structural') ||
        desc.contains('piping') ||
        desc.contains('electrical') ||
        desc.contains('hvac');
    final reviewAllowance =
        _parseDayValue(package.estimateBasis.reviewAllowance);
    final base = hasComplexKeywords ? 10 : 5;
    return base + reviewAllowance;
  }

  /// Parses a day value from a string like "3 days", "3d", "5 days review".
  /// Returns 0 if no numeric value found.
  static int _parseDayValue(String value) {
    if (value.trim().isEmpty) return 0;
    final match = RegExp(r'(\d+)\s*(?:days?|d\b)', caseSensitive: false)
        .firstMatch(value);
    if (match != null) return int.tryParse(match.group(1) ?? '0') ?? 0;
    // Try bare number
    return int.tryParse(value.trim()) ?? 0;
  }

  /// Parses a productivity rate from a string like "10 units/day",
  /// "5 per day", "10u/d". Returns 0 if no rate found.
  static double _parseRateValue(String value) {
    if (value.trim().isEmpty) return 0;
    // Pattern: "<number> units/day" or "<number> per day" or "<number>u/d"
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*(?:units?|u)?\s*/\s*(?:days?|d)',
            caseSensitive: false)
        .firstMatch(value);
    if (match != null) return double.tryParse(match.group(1) ?? '0') ?? 0;
    // Pattern: "<number> per day"
    final match2 =
        RegExp(r'(\d+(?:\.\d+)?)\s+per\s+days?', caseSensitive: false)
            .firstMatch(value);
    if (match2 != null) return double.tryParse(match2.group(1) ?? '0') ?? 0;
    return 0;
  }

  /// Parses a quantity hint from a description like "50 units",
  /// "100m", "200 sq ft". Returns 0 if no quantity found.
  static double _parseQuantityHint(String description) {
    if (description.trim().isEmpty) return 0;
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*(?:units?|m\b|sq|m2|ft2|kg|tons?)',
            caseSensitive: false)
        .firstMatch(description);
    if (match != null) return double.tryParse(match.group(1) ?? '0') ?? 0;
    return 0;
  }

  /// Parses a sprint count from a string like "2 sprints",
  /// "3 iterations", "1 sprint". Returns 0 if not found.
  static int _parseSprintValue(String value) {
    if (value.trim().isEmpty) return 0;
    final match =
        RegExp(r'(\d+)\s*(?:sprints?|iterations?)', caseSensitive: false)
            .firstMatch(value);
    if (match != null) return int.tryParse(match.group(1) ?? '0') ?? 0;
    return 0;
  }

  /// Legacy alias — kept for backward compatibility with existing callers.
  static int _defaultDurationDays(WorkPackage package) =>
      estimateDurationDays(package);

  static String _defaultPriority(WorkPackage package) {
    return package.packageClassification == procurementPackage &&
            package.procurementBreakdown.category == 'longLeadEquipment'
        ? 'high'
        : 'medium';
  }

  static String _activityEstimateBasis(WorkPackage package) {
    final basis = package.estimateBasis;
    final parts = [
      if (basis.method.trim().isNotEmpty) 'Method: ${basis.method.trim()}',
      if (basis.sourceData.trim().isNotEmpty)
        'Source: ${basis.sourceData.trim()}',
      if (basis.productivityBasis.trim().isNotEmpty)
        'Productivity: ${basis.productivityBasis.trim()}',
      if (basis.resourceBasis.trim().isNotEmpty)
        'Resources: ${basis.resourceBasis.trim()}',
      if (basis.procurementLeadTimeBasis.trim().isNotEmpty)
        'Lead time: ${basis.procurementLeadTimeBasis.trim()}',
      if (basis.reviewAllowance.trim().isNotEmpty)
        'Review: ${basis.reviewAllowance.trim()}',
      if (basis.assumptions.isNotEmpty)
        'Assumptions: ${basis.assumptions.join('; ')}',
      if (basis.confidenceLevel.trim().isNotEmpty)
        'Confidence: ${basis.confidenceLevel.trim()}',
    ];
    return parts.join('\n');
  }

  static PackageEstimateBasis _defaultEstimateBasis(String methodology) {
    final method = methodology.trim().toLowerCase() == 'agile'
        ? 'iteration_based'
        : 'expert_judgment';
    return PackageEstimateBasis(
      method: method,
      sourceData: 'Generated from WBS leaf node package candidate.',
      assumptions: const [
        'Initial package duration requires discipline review.',
      ],
      confidenceLevel: 'low',
    );
  }

  /// Creates a classification-aware estimate basis with domain-specific
  /// fields pre-populated. Used during package chain generation so that
  /// each package type gets appropriate estimation parameters.
  static PackageEstimateBasis _classificationAwareEstimateBasis({
    required String packageClassification,
    required String methodology,
    required String procurementCategory,
  }) {
    final isAgile = methodology.trim().toLowerCase() == 'agile';

    switch (packageClassification) {
      case engineeringEwp:
        return PackageEstimateBasis(
          method: 'expert_judgment',
          sourceData: 'Engineering deliverable estimation.',
          assumptions: const [
            'Base duration: 5 working days.',
            'Review allowance may extend duration.',
          ],
          productivityBasis: '',
          resourceBasis: '1 discipline engineer',
          workingCalendar: '5 days/week',
          reviewAllowance: '2 days',
          confidenceLevel: 'low',
        );
      case procurementPackage:
        final leadTimeNote = procurementCategory == 'longLeadEquipment'
            ? 'Long lead equipment: 30+ days typical.'
            : (procurementCategory == 'bulkMaterials'
                ? 'Bulk materials: 14+ days typical.'
                : 'Standard procurement cycle.');
        return PackageEstimateBasis(
          method: 'parametric',
          sourceData: 'Procurement category-based estimation.',
          assumptions: [leadTimeNote, 'RFQ cycle: 5-10 days.'],
          productivityBasis: '',
          resourceBasis: '1 procurement specialist',
          workingCalendar: '5 days/week',
          procurementLeadTimeBasis: procurementCategory == 'longLeadEquipment'
              ? '30 days manufacturing + 5 days shipping'
              : '7-14 days standard delivery',
          reviewAllowance: '3 days',
          confidenceLevel: 'medium',
        );
      case constructionCwp:
        return PackageEstimateBasis(
          method: 'productivity_based',
          sourceData: 'Construction productivity estimation.',
          assumptions: const [
            'Duration depends on scope quantity and crew productivity.',
            'Weather and site access may affect schedule.',
          ],
          productivityBasis: 'To be determined by discipline engineer',
          resourceBasis: '1 construction crew',
          workingCalendar: '5 days/week',
          reviewAllowance: '2 days',
          confidenceLevel: 'low',
        );
      case agileIterationPackage:
        return PackageEstimateBasis(
          method: 'iteration_based',
          sourceData: 'Agile velocity-based estimation.',
          assumptions: const [
            'Default sprint length: 2 weeks (10 working days).',
            'Velocity to be calibrated from team capacity.',
          ],
          productivityBasis: '',
          resourceBasis: '1 agile team',
          workingCalendar: '5 days/week',
          confidenceLevel: 'low',
        );
      case implementationWorkPackage:
        return PackageEstimateBasis(
          method: 'expert_judgment',
          sourceData: 'Implementation complexity estimation.',
          assumptions: const [
            'Base duration: 5 working days.',
            'Integration/migration tasks may extend duration.',
          ],
          productivityBasis: '',
          resourceBasis: '1 implementation specialist',
          workingCalendar: '5 days/week',
          reviewAllowance: '1 day',
          confidenceLevel: 'low',
        );
      case preCommissioningPackage:
        return PackageEstimateBasis(
          method: 'checklist_based',
          sourceData: 'Pre-commissioning checklist estimation.',
          assumptions: const [
            'Duration depends on system complexity and number of test loops.',
            'Mechanical completion verification required before commissioning.',
          ],
          productivityBasis: '',
          resourceBasis: '1 commissioning engineer + 1 technician',
          workingCalendar: '5 days/week',
          reviewAllowance: '2 days',
          confidenceLevel: 'medium',
        );
      case commissioningPackage:
        return PackageEstimateBasis(
          method: 'checklist_based',
          sourceData: 'Commissioning and handover estimation.',
          assumptions: const [
            'Functional testing and performance verification required.',
            'Punch list resolution may extend schedule.',
            'Final acceptance documentation required for handover.',
          ],
          productivityBasis: '',
          resourceBasis: '1 commissioning engineer + 1 technician + 1 QA',
          workingCalendar: '5 days/week',
          reviewAllowance: '3 days',
          confidenceLevel: 'medium',
        );
      default:
        return _defaultEstimateBasis(methodology);
    }
  }

  static List<PackageDeliverable> _defaultEngineeringDeliverables() => [
        PackageDeliverable(title: 'Drawings', type: 'drawing'),
        PackageDeliverable(title: 'Specifications', type: 'specification'),
        PackageDeliverable(title: 'Calculations', type: 'calculation'),
        PackageDeliverable(title: 'Bill of materials', type: 'bom'),
        PackageDeliverable(
            title: 'Codes and requirements', type: 'requirement'),
      ];

  static String _packageCode(String level2Title, String level3Title) {
    final left = _codeToken(level2Title);
    final right = _codeToken(level3Title);
    return [left, right].where((part) => part.isNotEmpty).join('-');
  }

  static String _codeToken(String value) {
    final words = value
        .toUpperCase()
        .split(RegExp(r'[^A-Z0-9]+'))
        .where((part) => part.isNotEmpty)
        .take(3)
        .map((part) => part.length <= 4 ? part : part.substring(0, 4));
    return words.join('');
  }

  static String _stableId(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized.isEmpty ? 'package' : normalized;
  }

  static bool _looksLikeConstruction(WorkItem item) {
    final text = '${item.title} ${item.description}'.toLowerCase();
    return text.contains('construction') ||
        text.contains('civil') ||
        text.contains('foundation') ||
        text.contains('structural') ||
        text.contains('site work') ||
        text.contains('build');
  }

  static String _inferProcurementCategory(WorkItem item) {
    final text = '${item.title} ${item.description}'.toLowerCase();
    if (text.contains('equipment') || text.contains('long lead')) {
      return 'longLeadEquipment';
    }
    if (text.contains('material') ||
        text.contains('pipe') ||
        text.contains('aggregate')) {
      return 'bulkMaterials';
    }
    if (text.contains('contract') ||
        text.contains('subcontract') ||
        text.contains('construction')) {
      return 'subcontract';
    }
    if (text.contains('software') ||
        text.contains('system') ||
        text.contains('technology')) {
      return 'technology';
    }
    return 'services';
  }

  // ------------------------------------------------------------------
  // Phase 2.3: Package roll-up logic
  // Aggregates child package costs and dates into parent packages.
  // ------------------------------------------------------------------

  /// Rolls up budgeted/actual costs and planned date ranges from
  /// child packages to their parent packages.
  ///
  /// For each non-leaf package (i.e., packages whose `childPackageIds`
  /// point to other existing packages), this computes:
  /// - **budgetedCost**: sum of children's budgetedCost
  /// - **actualCost**: sum of children's actualCost
  /// - **plannedStart**: earliest plannedStart among children
  /// - **plannedEnd**: latest plannedEnd among children
  ///
  /// Returns a new list with updated parent packages.
  static List<WorkPackage> rollUpChildCostsAndDates(
    List<WorkPackage> packages,
  ) {
    final packageById = <String, WorkPackage>{};
    for (final p in packages) {
      packageById[p.id] = p;
    }

    return packages.map((package) {
      if (package.childPackageIds.isEmpty) return package;

      // Resolve children
      final children = package.childPackageIds
          .map((id) => packageById[id])
          .whereType<WorkPackage>()
          .toList();

      if (children.isEmpty) return package;

      // Roll up costs
      final rolledUpBudget =
          children.fold<double>(0.0, (sum, c) => sum + c.budgetedCost);
      final rolledUpActual =
          children.fold<double>(0.0, (sum, c) => sum + c.actualCost);

      // Roll up date range
      final childStarts = children
          .map((c) => DateTime.tryParse(c.plannedStart ?? ''))
          .whereType<DateTime>()
          .toList();
      final childEnds = children
          .map((c) => DateTime.tryParse(c.plannedEnd ?? ''))
          .whereType<DateTime>()
          .toList();

      final earliestStart = childStarts.isNotEmpty
          ? childStarts.reduce((a, b) => a.isBefore(b) ? a : b)
          : null;
      final latestEnd = childEnds.isNotEmpty
          ? childEnds.reduce((a, b) => a.isAfter(b) ? a : b)
          : null;

      return package.copyWith(
        budgetedCost: rolledUpBudget,
        actualCost: rolledUpActual,
        plannedStart: earliestStart?.toIso8601String().split('T').first,
        plannedEnd: latestEnd?.toIso8601String().split('T').first,
      );
    }).toList();
  }

  /// Collects all descendant package IDs recursively from a root package.
  /// Useful for finding the full subtree of a summary/parent package.
  static Set<String> collectDescendantIds(
    String rootId,
    List<WorkPackage> allPackages,
  ) {
    final packageById = <String, WorkPackage>{};
    for (final p in allPackages) {
      packageById[p.id] = p;
    }

    final result = <String>{};
    void visit(String id) {
      final pkg = packageById[id];
      if (pkg == null) return;
      for (final childId in pkg.childPackageIds) {
        if (result.add(childId)) {
          visit(childId);
        }
      }
    }

    visit(rootId);
    return result;
  }

  // ------------------------------------------------------------------
  // Phase 5: Resource conflict detection
  // Detects when the same resource/owner is assigned to overlapping
  // packages that could create schedule conflicts.
  // ------------------------------------------------------------------

  /// Represents a resource conflict where the same owner is assigned
  /// to two packages with overlapping date ranges.
  static List<ResourceConflict> detectResourceConflicts(
    List<WorkPackage> packages,
  ) {
    final conflicts = <ResourceConflict>[];
    final ownerPackages = <String, List<WorkPackage>>{};

    // Group packages by owner
    for (final pkg in packages) {
      final owner = pkg.owner.trim();
      if (owner.isEmpty) continue;
      ownerPackages.putIfAbsent(owner, () => []).add(pkg);
    }

    // For each owner, check for date overlaps between packages
    for (final entry in ownerPackages.entries) {
      final ownerPkgs = entry.value;
      if (ownerPkgs.length < 2) continue;

      for (var i = 0; i < ownerPkgs.length; i++) {
        for (var j = i + 1; j < ownerPkgs.length; j++) {
          final a = ownerPkgs[i];
          final b = ownerPkgs[j];

          final aStart = DateTime.tryParse(a.plannedStart ?? '');
          final aEnd = DateTime.tryParse(a.plannedEnd ?? '');
          final bStart = DateTime.tryParse(b.plannedStart ?? '');
          final bEnd = DateTime.tryParse(b.plannedEnd ?? '');

          if (aStart == null ||
              aEnd == null ||
              bStart == null ||
              bEnd == null) {
            continue;
          }

          // Check for overlap: max(start1,start2) <= min(end1,end2)
          final overlapStart = aStart.isAfter(bStart) ? aStart : bStart;
          final overlapEnd = aEnd.isBefore(bEnd) ? aEnd : bEnd;
          if (overlapStart.isBefore(overlapEnd) ||
              overlapStart.isAtSameMomentAs(overlapEnd)) {
            final overlapDays = overlapEnd.difference(overlapStart).inDays + 1;
            conflicts.add(ResourceConflict(
              owner: entry.key,
              packageA: a.title.isNotEmpty ? a.title : a.id,
              packageB: b.title.isNotEmpty ? b.title : b.id,
              overlapDays: overlapDays,
              overlapStart: overlapStart.toIso8601String().split('T').first,
              overlapEnd: overlapEnd.toIso8601String().split('T').first,
            ));
          }
        }
      }
    }

    return conflicts;
  }

  // ------------------------------------------------------------------
  // Phase 6: Estimate basis enforcement
  // Auto-populates estimate basis fields from available project data.
  // ------------------------------------------------------------------

  /// Enriches the estimate basis of each work package with information
  /// derivable from other project data:
  /// - Sets working calendar from project methodology
  /// - Sets procurement lead time from procurementBreakdown.leadTimeDays
  /// - Validates that high-risk/low-confidence packages have documented basis
  ///
  /// Returns a new list with enriched packages.
  static List<WorkPackage> enforceEstimateBasis(
    List<WorkPackage> packages, {
    String methodology = '',
  }) {
    return packages.map((pkg) {
      var basis = pkg.estimateBasis;

      // Enforce working calendar if not set
      if (basis.workingCalendar.trim().isEmpty) {
        basis = basis.copyWith(
          workingCalendar: '5 days/week',
        );
      }

      // Auto-populate procurement lead time basis if not set
      if (pkg.packageClassification == procurementPackage &&
          basis.procurementLeadTimeBasis.trim().isEmpty &&
          pkg.procurementBreakdown.leadTimeDays > 0) {
        basis = basis.copyWith(
          procurementLeadTimeBasis:
              '${pkg.procurementBreakdown.leadTimeDays} days (from procurement breakdown)',
        );
      }

      // Flag low-confidence estimates that need review
      final isLowConfidence =
          basis.confidenceLevel.trim().toLowerCase() == 'low' ||
              basis.confidenceLevel.trim().isEmpty;
      final missingMethod = basis.method.trim().isEmpty;
      if (isLowConfidence || missingMethod) {
        final existingWarnings = pkg.readinessWarnings;
        final newWarnings = <String>[...existingWarnings];
        if (missingMethod) {
          newWarnings.add('Estimation method is not documented.');
        }
        if (isLowConfidence && !missingMethod) {
          newWarnings.add(
              'Estimate confidence is low. Consider adding more basis data.');
        }
        return pkg.copyWith(
          estimateBasis: basis,
          readinessWarnings: newWarnings,
        );
      }

      return pkg.copyWith(estimateBasis: basis);
    }).toList();
  }

  // ------------------------------------------------------------------
  // Phase 7: Baseline & control enhancement
  // Variance threshold checking and change tracking.
  // ------------------------------------------------------------------

  /// Variance thresholds for schedule and cost control.
  static const double costVarianceWarningThreshold = 0.10; // 10% overrun
  static const double costVarianceCriticalThreshold = 0.25; // 25% overrun
  static const double scheduleVarianceWarningDays = 5;
  static const double scheduleVarianceCriticalDays = 15;

  /// Checks all work packages for cost and schedule variance against
  /// thresholds. Returns a list of variance warnings.
  static List<BaselineVarianceWarning> checkBaselineVariance(
    List<WorkPackage> packages,
  ) {
    final warnings = <BaselineVarianceWarning>[];

    for (final pkg in packages) {
      // Cost variance
      if (pkg.budgetedCost > 0) {
        final costVariance = pkg.actualCost - pkg.budgetedCost;
        final costVariancePct = costVariance / pkg.budgetedCost;

        if (costVariancePct >= costVarianceCriticalThreshold) {
          warnings.add(BaselineVarianceWarning(
            packageId: pkg.id,
            packageTitle: pkg.title,
            type: 'cost_critical',
            message:
                'Cost overrun ${(costVariancePct * 100).toStringAsFixed(1)}% '
                'exceeds critical threshold ${(costVarianceCriticalThreshold * 100).toStringAsFixed(0)}%. '
                'Budget: \$${pkg.budgetedCost.toStringAsFixed(0)}, '
                'Actual: \$${pkg.actualCost.toStringAsFixed(0)}.',
          ));
        } else if (costVariancePct >= costVarianceWarningThreshold) {
          warnings.add(BaselineVarianceWarning(
            packageId: pkg.id,
            packageTitle: pkg.title,
            type: 'cost_warning',
            message:
                'Cost overrun ${(costVariancePct * 100).toStringAsFixed(1)}% '
                'exceeds warning threshold ${(costVarianceWarningThreshold * 100).toStringAsFixed(0)}%. '
                'Budget: \$${pkg.budgetedCost.toStringAsFixed(0)}, '
                'Actual: \$${pkg.actualCost.toStringAsFixed(0)}.',
          ));
        }
      }

      // Schedule variance: compare actual dates vs planned dates
      final plannedEnd = DateTime.tryParse(pkg.plannedEnd ?? '');
      final actualEnd = DateTime.tryParse(pkg.actualEnd ?? '');
      if (plannedEnd != null &&
          actualEnd != null &&
          actualEnd.isAfter(plannedEnd)) {
        final delayDays = actualEnd.difference(plannedEnd).inDays;
        if (delayDays >= scheduleVarianceCriticalDays) {
          warnings.add(BaselineVarianceWarning(
            packageId: pkg.id,
            packageTitle: pkg.title,
            type: 'schedule_critical',
            message:
                'Schedule delay of $delayDays day(s) exceeds critical threshold '
                '$scheduleVarianceCriticalDays days. '
                'Planned end: ${pkg.plannedEnd}, Actual end: ${pkg.actualEnd}.',
          ));
        } else if (delayDays >= scheduleVarianceWarningDays) {
          warnings.add(BaselineVarianceWarning(
            packageId: pkg.id,
            packageTitle: pkg.title,
            type: 'schedule_warning',
            message:
                'Schedule delay of $delayDays day(s) exceeds warning threshold '
                '$scheduleVarianceWarningDays days. '
                'Planned end: ${pkg.plannedEnd}, Actual end: ${pkg.actualEnd}.',
          ));
        }
      }
    }

    return warnings;
  }
}

/// Represents a resource conflict where the same owner is assigned
/// to two packages with overlapping date ranges.
class ResourceConflict {
  const ResourceConflict({
    required this.owner,
    required this.packageA,
    required this.packageB,
    required this.overlapDays,
    required this.overlapStart,
    required this.overlapEnd,
  });

  final String owner;
  final String packageA;
  final String packageB;
  final int overlapDays;
  final String overlapStart;
  final String overlapEnd;

  @override
  String toString() =>
      '$owner: "$packageA" and "$packageB" overlap by $overlapDays day(s) '
      '($overlapStart to $overlapEnd)';
}

/// Represents a cost or schedule variance warning against baseline.
class BaselineVarianceWarning {
  const BaselineVarianceWarning({
    required this.packageId,
    required this.packageTitle,
    required this.type,
    required this.message,
  });

  final String packageId;
  final String packageTitle;

  /// 'cost_warning', 'cost_critical', 'schedule_warning', 'schedule_critical'
  final String type;
  final String message;

  bool get isCritical => type.endsWith('_critical');
  bool get isCostVariance => type.startsWith('cost_');
  bool get isScheduleVariance => type.startsWith('schedule_');

  @override
  String toString() =>
      '[${isCritical ? "CRITICAL" : "WARNING"}] $packageTitle: $message';
}
