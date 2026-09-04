library;

/// Cost Estimate — ChangeNotifier-based state management (Dart equivalent)
///
/// Mirrors the Zustand store in the Next.js module.
/// Persists to SharedPreferences as JSON.
///
/// The `setup()` method reads the project name from
/// [ProjectDataHelper.lastKnownProjectName] when the caller passes an empty
/// or default `'My Project'` name — this lets the Cost Estimate inherit the
/// project name captured during the Initiation Phase without needing a
/// [BuildContext].

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

const String _storageKey = 'ndu_cost_estimate_v1';
const String _legacyOwnerEmail = 'you@ndu.project';

/// The authenticated owner's real email address.
///
/// Firebase normally exposes it directly on [User.email]. The provider-data
/// fallback also covers accounts whose email is attached to the identity
/// provider but has not been copied onto the top-level user record.
String get currentUserEmail {
  final User? user;
  try {
    user = FirebaseAuth.instance.currentUser;
  } catch (_) {
    // Firebase not initialized (e.g. tests) — fall back to empty identity.
    return '';
  }
  final primaryEmail = user?.email?.trim() ?? '';
  if (primaryEmail.isNotEmpty) return primaryEmail;

  for (final identity in user?.providerData ?? const <UserInfo>[]) {
    final providerEmail = identity.email?.trim() ?? '';
    if (providerEmail.isNotEmpty) return providerEmail;
  }

  return '';
}

class CostEstimateProvider extends ChangeNotifier {
  CostEstimate? _estimate;
  RBACRole _currentRole = RBACRole.admin;
  bool _setupComplete = false;

  CostEstimate? get estimate {
    _syncAuthenticatedOwner();
    return _estimate;
  }

  RBACRole get currentRole => _currentRole;
  bool get setupComplete => _setupComplete;

  CostEstimateProvider() {
    _loadFromStorage();
  }

  // ---- Persistence ----

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final state = data['state'] as Map<String, dynamic>? ?? {};
        _setupComplete = state['setupComplete'] as bool? ?? false;
        if (state['estimate'] != null) {
          _estimate = _estimateFromJson(
              state['estimate'] as Map<String, dynamic>);
          _syncAuthenticatedOwner();
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cost estimate: $e');
    }
  }

  /// Replaces the former demo identity with the authenticated owner and
  /// restores the owner's access grant when loading older saved estimates.
  void _syncAuthenticatedOwner() {
    final estimate = _estimate;
    final String ownerEmail;
    try {
      ownerEmail = currentUserEmail;
    } catch (_) {
      return;
    }
    if (estimate == null || ownerEmail.isEmpty) return;

    var changed = false;
    var hasOwnerAccess = false;
    final normalizedAccess = <AccessGrant>[];

    for (final grant in estimate.access) {
      final isLegacyOwner = grant.userEmail.trim().toLowerCase() ==
          _legacyOwnerEmail.toLowerCase();
      final resolvedEmail = isLegacyOwner ? ownerEmail : grant.userEmail;
      final resolvedGrantedBy = grant.grantedBy.trim().toLowerCase() ==
              _legacyOwnerEmail.toLowerCase()
          ? ownerEmail
          : grant.grantedBy;

      if (resolvedEmail.toLowerCase() == ownerEmail.toLowerCase()) {
        hasOwnerAccess = true;
      }
      if (isLegacyOwner || resolvedGrantedBy != grant.grantedBy) {
        changed = true;
      }

      normalizedAccess.add(AccessGrant(
        userEmail: resolvedEmail,
        role: grant.role,
        grantedBy: resolvedGrantedBy,
        grantedAt: grant.grantedAt,
      ));
    }

    if (!hasOwnerAccess) {
      changed = true;
      normalizedAccess.insert(
        0,
        AccessGrant(
          userEmail: ownerEmail,
          role: RBACRole.admin,
          grantedBy: ownerEmail,
          grantedAt: DateTime.now(),
        ),
      );
    }

    if (changed) {
      _estimate = estimate.copyWith(
        access: normalizedAccess,
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'state': {
          'estimate': _estimate != null
              ? {
                  'id': _estimate!.id,
                  'projectId': _estimate!.projectId,
                  'projectName': _estimate!.projectName,
                  'className': _estimate!.className.name,
                  'deliveryModel': _estimate!.deliveryModel.name,
                  'status': _estimate!.status.name,
                  'currency': _estimate!.currency,
                  // Phase 0 fix — persist the full estimate state so the
                  // Project Controls BAC seeding (syncFromCostEstimate)
                  // and the WBS ↔ Cost linkage survive an app restart.
                  // Previously only metadata was saved → silent data loss.
                  'lines': _estimate!.lines
                      .map((l) => l.toJson())
                      .toList(growable: false),
                  'totals': _estimate!.totals.toJson(),
                  'access': _estimate!.access
                      .map((g) => g.toJson())
                      .toList(growable: false),
                  // BOE + stakeholders are real estimate content — persist
                  // them too so assumptions/constraints/exclusions and the
                  // stakeholder list survive a save/load round-trip.
                  'boe': _estimate!.boe.toJson(),
                  'stakeholders': _estimate!.stakeholders
                      .map((s) => s.toJson())
                      .toList(growable: false),
                  'createdAt': _estimate!.createdAt.toIso8601String(),
                  'updatedAt': _estimate!.updatedAt.toIso8601String(),
                }
              : null,
          'setupComplete': _setupComplete,
        },
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving cost estimate: $e');
    }
  }

  CostEstimate _estimateFromJson(Map<String, dynamic> json) {
    // Phase 0 fix — full deserialization including cost lines, totals,
    // and access grants. Defaults gracefully for legacy records that
    // were saved before these fields were persisted.
    final linesJson = json['lines'] as List<dynamic>?;
    final lines = linesJson != null
        ? linesJson
            .map((l) => CostLine.fromJson(l as Map<String, dynamic>))
            .toList(growable: false)
        : <CostLine>[];

    final totalsJson = json['totals'] as Map<String, dynamic>?;
    final totals = totalsJson != null
        ? EstimateTotals.fromJson(totalsJson)
        : EstimateTotals.empty();

    final accessJson = json['access'] as List<dynamic>?;
    final access = accessJson != null
        ? accessJson
            .map((g) => AccessGrant.fromJson(g as Map<String, dynamic>))
            .toList(growable: false)
        : <AccessGrant>[];

    // Restore the BOE and stakeholder list when present (records saved
    // before these were persisted fall back to the class defaults).
    final className = _parseEstimateClass(json['className'] as String?);
    final boeJson = json['boe'] as Map<String, dynamic>?;
    BasisOfEstimate boe;
    try {
      boe = boeJson != null
          ? BasisOfEstimate.fromJson(boeJson)
          : emptyBOE(className);
    } catch (_) {
      // A corrupt BOE block must never prevent the estimate from loading.
      boe = emptyBOE(className);
    }
    final stakeholdersJson = json['stakeholders'] as List<dynamic>?;
    List<Stakeholder> stakeholders;
    try {
      stakeholders = stakeholdersJson != null
          ? stakeholdersJson
              .map((s) => Stakeholder.fromJson(s as Map<String, dynamic>))
              .toList(growable: false)
          : <Stakeholder>[];
    } catch (_) {
      stakeholders = <Stakeholder>[];
    }

    return CostEstimate(
      id: json['id'] as String,
      projectId: json['projectId'] as String? ?? 'default',
      projectName: json['projectName'] as String,
      className: className,
      deliveryModel: DeliveryModel.values
          .byName(json['deliveryModel'] as String? ?? 'waterfall'),
      status: EstimateStatus.values
          .byName(json['status'] as String? ?? 'draft'),
      currency: json['currency'] as String? ?? 'USD',
      lines: lines,
      boe: boe,
      totals: totals,
      access: access,
      stakeholders: stakeholders,
      aiSuggestions: [],
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Tolerant [EstimateClass] parse for persisted records.
  ///
  /// Legacy/current saves store the class using `EstimateClass.name` — but
  /// that getter is overridden to return the human label (e.g.
  /// `'Budget Authorization'`), NOT the Dart enum identifier (`'class3'`).
  /// `EstimateClass.values.byName` only understands identifiers, so strict
  /// parsing threw and the WHOLE estimate failed to reload (silent data
  /// loss on every cold start). Accept both representations and fall back
  /// to Class 3 when the value is unrecognized.
  static EstimateClass _parseEstimateClass(String? raw) {
    if (raw == null || raw.trim().isEmpty) return EstimateClass.class3;
    final trimmed = raw.trim();
    try {
      return EstimateClass.values.byName(trimmed);
    } catch (_) {
      // Fall through to display-name matching.
    }
    for (final c in EstimateClass.values) {
      if (c.name == trimmed) return c;
    }
    return EstimateClass.class3;
  }

  // ---- Setup ----

  /// Set up a fresh empty Cost Estimate.
  ///
  /// If [projectName] is empty or the literal default `'My Project'`, this
  /// tries to fall back to [ProjectDataHelper.lastKnownProjectName] (which is
  /// captured from the central [ProjectDataModel] during the Initiation
  /// Phase). This lets the Cost Estimate inherit the project name without
  /// needing a [BuildContext].
  void setup({
    required String projectName,
    required EstimateClass className,
    required DeliveryModel deliveryModel,
  }) {
    final resolvedName = _resolveProjectName(projectName);
    _estimate = createEmptyEstimate(
      projectId: 'default',
      projectName: resolvedName,
      className: className,
      deliveryModel: deliveryModel,
      userEmail: currentUserEmail,
    );
    _setupComplete = true;
    _currentRole = RBACRole.admin;
    notifyListeners();
    _saveToStorage();
  }

  /// Import [CostEstimateItem] objects from the central project data model
  /// as [CostLine] objects in this cost estimate. This auto-populates the
  /// Cost by WBS tab from the Initial Cost Estimate screen.
  ///
  /// Returns `true` if lines were imported (estimate was previously empty).
  bool importFromProjectCostEstimateItems(
      List<CostEstimateItem> costEstimateItems) {
    final estimate = _estimate;
    if (estimate == null) return false;
    if (estimate.lines.isNotEmpty) return false;
    if (costEstimateItems.isEmpty) return false;

    final importedLines = <CostLine>[];
    for (final item in costEstimateItems) {
      // Only import items with a positive amount
      if (item.amount <= 0) continue;

      // Build a descriptive sub-category from phase + work package info
      final subParts = <String>[];
      if (item.phase.isNotEmpty) subParts.add(item.phase);
      if (item.workPackageTitle.isNotEmpty) subParts.add(item.workPackageTitle);

      importedLines.add(CostLine(
        id: 'imported_${item.id}',
        category: _mapCostTypeToCategory(item.costType),
        subCategory: subParts.join(' / '),
        description: item.title,
        wbsRef: item.wbsItemId.isNotEmpty
            ? item.wbsItemId
            : (item.workPackageTitle.isNotEmpty ? item.workPackageTitle : null),
        quantity: item.quantity > 0 ? item.quantity.toDouble() : null,
        unit: item.unitOfMeasure.isNotEmpty ? item.unitOfMeasure : null,
        rate: item.unitRate > 0 ? item.unitRate : null,
        total: item.amount,
        inSchedule: item.scheduleActivityId.isNotEmpty,
        basisSource: _mapEstimatingMethodToSourceType(item.estimatingMethod),
        basisReference: item.estimatingBasis.isNotEmpty
            ? item.estimatingBasis
            : (item.notes.isNotEmpty ? item.notes : null),
        aiGenerated: item.source == 'ai_generated',
      ));
    }

    if (importedLines.isEmpty) return false;

    // Recompute totals from the imported lines — the dashboard KPIs read
    // `estimate.totals`, so lines alone would leave Cost Baseline at $0.
    final totals = ComputeUtils.computeTotals(importedLines);
    _estimate = estimate.copyWith(
      lines: importedLines,
      totals: totals,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
    return true;
  }

  /// Map a costType string from CostEstimateItem to a CostCategory enum.
  CostCategory _mapCostTypeToCategory(String costType) {
    switch (costType.toLowerCase()) {
      case 'labor':
        return CostCategory.labor;
      case 'materials':
        return CostCategory.materials;
      case 'software':
        return CostCategory.software;
      case 'procurement':
        return CostCategory.procurement;
      case 'travel' || 'training':
        return CostCategory.travelTraining;
      case 'construction':
        return CostCategory.construction;
      case 'team' || 'project_team':
        return CostCategory.projectTeam;
      case 'overhead' || 'overheads':
        return CostCategory.overheads;
      case 'ga' || 'general':
        return CostCategory.ga;
      case 'facilities':
        return CostCategory.facilities;
      case 'indirect':
        return CostCategory.overheads;
      default:
        return CostCategory.materials;
    }
  }

  /// Map estimatingMethod string to CostSourceType enum.
  CostSourceType _mapEstimatingMethodToSourceType(String method) {
    switch (method.toLowerCase()) {
      case 'vendor_quote' || 'vendor':
        return CostSourceType.vendorQuote;
      case 'historical':
        return CostSourceType.historical;
      case 'published_index' || 'benchmark':
        return CostSourceType.industryBenchmark;
      case 'expert_judgment' || 'expert':
        return CostSourceType.expertJudgment;
      default:
        return CostSourceType.historical;
    }
  }

  // ---- Scheduled purchases → Cost Estimate ----

  /// True when [line] already represents a scheduled purchase described by
  /// [candidate] — either through the explicit activity link
  /// (`costLineId == candidate.activityCostLineId`) or through an identical
  /// in-schedule line (same WBS ref AND same description).
  static bool isPurchaseLine(
      ScheduledPurchaseCandidate candidate, CostLine line) {
    if (candidate.activityCostLineId != null &&
        candidate.activityCostLineId!.isNotEmpty &&
        line.id == candidate.activityCostLineId) {
      return true;
    }
    final ref = (candidate.wbsRef ?? '').trim();
    final title = candidate.title.trim();
    if (ref.isNotEmpty) {
      return (line.wbsRef ?? '').trim() == ref &&
          line.description.trim() == title &&
          line.inSchedule;
    }
    return line.description.trim() == title &&
        line.inSchedule &&
        (line.wbsRef ?? '').trim().isEmpty;
  }

  /// Whether any existing line already represents [candidate].
  bool isScheduledPurchaseRepresented(ScheduledPurchaseCandidate candidate) {
    final estimate = _estimate;
    if (estimate == null) return false;
    return estimate.lines
        .any((l) => isPurchaseLine(candidate, l));
  }

  /// Pull scheduled purchases into the Cost Estimate as procurement cost
  /// lines. CORE functionality: no AI involved — this is plain data movement
  /// from the Schedule (which already holds the purchase work packages) into
  /// the estimate, exactly as the product owner described in the 2026-09-03
  /// voice note ("where there was a cost and go buy CPE or buy this … you put
  /// them into the cost estimate").
  ///
  /// Pulled lines are created with an explicit link to their schedule
  /// activity via the returned [ScheduledPurchasePullResult.addedByActivityId]
  /// map so callers can stamp `ScheduleActivity.costLineId` afterwards.
  /// Lines start at $0 (quantity 1, lump sum) because the schedule does not
  /// store money — the user prices each one in the Cost Estimate Builder /
  /// Cost-by-WBS view, where they show up as "not yet priced".
  ///
  /// Idempotent: purchases already represented in the estimate (linked by
  /// activity costLineId, or same WBS ref + description) are never duplicated.
  ScheduledPurchasePullResult pullScheduledPurchases(
      List<ScheduledPurchaseCandidate> candidates) {
    final estimate = _estimate;
    if (estimate == null || candidates.isEmpty) {
      return ScheduledPurchasePullResult.empty;
    }

    final newLines = [...estimate.lines];
    final addedByActivityId = <String, String>{};
    var alreadyInEstimate = 0;

    for (final candidate in candidates) {
      final existingCostLineId =
          (candidate.activityCostLineId ?? '').trim();
      // Linked to an existing line? Skip.
      if (existingCostLineId.isNotEmpty &&
          estimate.lines.any((l) => l.id == existingCostLineId)) {
        alreadyInEstimate++;
        continue;
      }
      // Already represented by an identical in-schedule line? Skip.
      if (estimate.lines.any((l) => isPurchaseLine(candidate, l))) {
        alreadyInEstimate++;
        continue;
      }

      final title = candidate.title.trim().isEmpty
          ? 'Scheduled purchase'
          : candidate.title.trim();
      final line = CostLine(
        id: newId('line'),
        category: CostCategory.procurement,
        subCategory: 'Scheduled purchase',
        description: title,
        wbsRef:
            (candidate.wbsRef ?? '').trim().isEmpty
                ? null
                : candidate.wbsRef!.trim(),
        quantity: 1,
        unit: 'lump',
        rate: null,
        total: 0,
        inSchedule: true,
        basisSource: CostSourceType.historical,
        aiGenerated: false,
      );
      newLines.add(line);
      addedByActivityId[candidate.activityId] = line.id;
    }

    if (addedByActivityId.isEmpty) {
      return ScheduledPurchasePullResult(
        pulled: 0,
        alreadyInEstimate: alreadyInEstimate,
        addedByActivityId: const {},
      );
    }

    final totals = ComputeUtils.computeTotals(newLines);
    _estimate = estimate.copyWith(
      lines: newLines,
      totals: totals,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
    return ScheduledPurchasePullResult(
      pulled: addedByActivityId.length,
      alreadyInEstimate: alreadyInEstimate,
      addedByActivityId: addedByActivityId,
    );
  }

  /// Pick the best project name: the explicit one if it's been customised,
  /// otherwise [ProjectDataHelper.lastKnownProjectName] (if captured), else
  /// the literal `'My Project'` default.
  String _resolveProjectName(String projectName) {
    final trimmed = projectName.trim();
    if (trimmed.isNotEmpty && trimmed != 'My Project') return trimmed;
    final cached = ProjectDataHelper.lastKnownProjectName;
    if (cached != null && cached.trim().isNotEmpty) return cached;
    return trimmed.isEmpty ? 'My Project' : trimmed;
  }

  /// Build a compact summary of the current cost estimate that other modules
  /// (e.g. the Schedule) can surface in their context banners / AI prompts.
  ///
  /// Returns an empty string when no estimate has been set up yet.
  String getContextScan() {
    final estimate = _estimate;
    if (estimate == null) return '';
    final buf = StringBuffer();
    buf.writeln('Cost Estimate');
    buf.writeln('-------------');
    buf.writeln('Project: ${estimate.projectName}');
    buf.writeln('Class: ${estimate.className.label}');
    buf.writeln('Delivery model: ${estimate.deliveryModel.label}');
    buf.writeln('Status: ${estimate.status.label}');
    buf.writeln('Currency: ${estimate.currency}');
    final total = estimate.lines.fold<double>(0,
        (s, l) => s + _effectiveLineTotalForContextScan(l));
    buf.writeln(
        'Total: ${total.toStringAsFixed(2)} ${estimate.currency}');
    buf.writeln('Lines: ${estimate.lines.length}');
    if (estimate.lines.isNotEmpty) {
      final sorted = [...estimate.lines]
        ..sort((a, b) => _effectiveLineTotalForContextScan(b)
            .compareTo(_effectiveLineTotalForContextScan(a)));
      final top = sorted.take(5).toList();
      buf.writeln('Top cost lines:');
      for (final l in top) {
        final wbsRef = (l.wbsRef ?? '').trim();
        final refSuffix = wbsRef.isEmpty ? '' : ' [WBS: $wbsRef]';
        buf.writeln(
            '- ${l.category.label} · ${l.description}$refSuffix · ${_effectiveLineTotalForContextScan(l).toStringAsFixed(2)} ${estimate.currency}');
      }
    }
    return buf.toString().trim();
  }

  /// Effective line total mirroring [ComputeUtils] logic — used by
  /// [getContextScan] to keep variance-aware totals consistent.
  double _effectiveLineTotalForContextScan(CostLine l) {
    if (l.varianceType == VarianceType.remove) {
      return -(l.varianceBaselineTotal ?? 0);
    }
    if (l.varianceType == VarianceType.change) {
      return l.varianceDelta ?? 0;
    }
    return l.total;
  }

  void resetEstimate() {
    _estimate = null;
    _setupComplete = false;
    notifyListeners();
    _saveToStorage();
  }

  // ---- Lines ----

  String addLine(CostLine line) {
    if (_estimate == null) return line.id;
    final recalcLine = ComputeUtils.recalcLineTotal(line);
    final lines = [..._estimate!.lines, recalcLine];
    final totals = ComputeUtils.computeTotals(lines);
    _estimate = _estimate!.copyWith(
      lines: lines,
      totals: totals,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
    return line.id;
  }

  void updateLine(String id, CostLine patch) {
    if (_estimate == null) return;
    final isBaselined = _estimate!.status == EstimateStatus.baselined ||
        _estimate!.status == EstimateStatus.rebaselined;
    List<CostLine> lines = _estimate!.lines.map((l) {
      if (l.id != id) return l;
      final updated = ComputeUtils.recalcLineTotal(l.copyWith(
        category: patch.category,
        subCategory: patch.subCategory,
        description: patch.description,
        wbsRef: patch.wbsRef,
        quantity: patch.quantity,
        unit: patch.unit,
        rate: patch.rate,
        total: patch.total,
        inSchedule: patch.inSchedule,
        basisSource: patch.basisSource,
        basisReference: patch.basisReference,
        confidence: patch.confidence,
      ));
      if (isBaselined &&
          (patch.total != l.total ||
              patch.quantity != l.quantity ||
              patch.rate != l.rate)) {
        return updated.copyWith(
          varianceType: VarianceType.change,
          varianceBaselineTotal: l.total,
          varianceDelta: updated.total - l.total,
        );
      }
      return updated;
    }).toList();
    final totals = ComputeUtils.computeTotals(lines);
    _estimate = _estimate!.copyWith(
      lines: lines,
      totals: totals,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  void removeLine(String id) {
    if (_estimate == null) return;
    final isBaselined = _estimate!.status == EstimateStatus.baselined ||
        _estimate!.status == EstimateStatus.rebaselined;
    List<CostLine> lines;
    if (isBaselined) {
      lines = _estimate!.lines.map((l) {
        if (l.id == id) {
          return l.copyWith(
            varianceType: VarianceType.remove,
            varianceBaselineTotal: l.total,
            varianceDelta: -l.total,
          );
        }
        return l;
      }).toList();
    } else {
      lines = _estimate!.lines.where((l) => l.id != id).toList();
    }
    final totals = ComputeUtils.computeTotals(lines);
    _estimate = _estimate!.copyWith(
      lines: lines,
      totals: totals,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  // ---- BOE ----

  void updateBOE(BasisOfEstimate patch) {
    if (_estimate == null) return;
    _estimate = _estimate!.copyWith(
      boe: patch,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  /// Ensure non-destructive seeding of estimate content from the central
  /// ProjectDataModel. This uses real project data (core stakeholders,
  /// assumptions/constraints/exclusions) when the estimate has empty
  /// corresponding sections. No synthetic or placeholder values are created.
  void ensureSeededFromProjectData(ProjectDataModel data) {
    if (_estimate == null) return;
    var changed = false;

    // 1) Stakeholders — pull from project-level CoreStakeholdersData
    try {
      if ((_estimate!.stakeholders.isEmpty) &&
          data.coreStakeholdersData != null) {
        final core = data.coreStakeholdersData!;
        final names = <String>{};
        for (final s in core.solutionStakeholderData) {
          for (final field in [
            s.notableStakeholders,
            s.internalStakeholders,
            s.externalStakeholders
          ]) {
            if (field.trim().isEmpty) continue;
            final parts = field.split(RegExp(r'[,;\n]'));
            for (final p in parts) {
              final n = p.trim();
              if (n.isNotEmpty) names.add(n);
            }
          }
        }
        if (names.isNotEmpty) {
          final stakeholders = names
              .map((n) => Stakeholder(
                    id: newId('sh'),
                    name: n,
                    email: '',
                    role: '',
                    sme: false,
                    includedInDevelopment: true,
                  ))
              .toList();
          _estimate = _estimate!.copyWith(
            stakeholders: stakeholders,
            updatedAt: DateTime.now(),
          );
          changed = true;
        }
      }
    } catch (_) {}

    // 2) BOE — import project-level assumptions/constraints/exclusions
    try {
      final boe = _estimate!.boe;
      final hasAssumptions = boe.assumptions.isNotEmpty;
      final hasConstraints = boe.constraints.isNotEmpty;
      final hasExclusions = boe.exclusions.isNotEmpty;
      if ((!hasAssumptions || !hasConstraints || !hasExclusions) &&
          (data.assumptions.isNotEmpty || data.constraints.isNotEmpty || data.outOfScope.isNotEmpty)) {
        final newBoe = boe.copyWith(
          assumptions: hasAssumptions ? boe.assumptions : data.assumptions,
          constraints: hasConstraints ? boe.constraints : data.constraints,
          exclusions: hasExclusions ? boe.exclusions : data.outOfScope,
        );
        _estimate = _estimate!.copyWith(
          boe: newBoe,
          updatedAt: DateTime.now(),
        );
        changed = true;
      }
    } catch (_) {}

    // 3) Review — if no explicit approvers but stakeholders with emails exist,
    // create approver records from real stakeholder emails (non-destructive).
    try {
      final review = _estimate!.review;
      final hasApprovers = review != null && review.requiredApprovers.isNotEmpty;
      final stakeholdersWithEmail = _estimate!.stakeholders.where((s) => s.email.trim().isNotEmpty).toList();
      if (!hasApprovers && stakeholdersWithEmail.isNotEmpty) {
        final approvers = stakeholdersWithEmail.map((s) => Approver(
              id: newId('ap'),
              name: s.name,
              email: s.email,
              role: s.role,
              approved: false,
              approvedAt: null,
            )).toList();
        final newReview = (review ?? const ReviewApproval(requiredApprovers: [], acceptanceStep1: (confirmed: false, by: null, at: null), acceptanceStep2: (confirmed: false, by: null, at: null))).copyWith(
          requiredApprovers: approvers,
        );
        _estimate = _estimate!.copyWith(
          review: newReview,
          updatedAt: DateTime.now(),
        );
        changed = true;
      }
    } catch (_) {}

    if (changed) {
      notifyListeners();
      _saveToStorage();
    }
  }

  // ---- Stakeholders ----

  void addStakeholder(Stakeholder s) {
    if (_estimate == null) return;
    _estimate = _estimate!.copyWith(
      stakeholders: [..._estimate!.stakeholders, s],
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  void removeStakeholder(String id) {
    if (_estimate == null) return;
    _estimate = _estimate!.copyWith(
      stakeholders:
          _estimate!.stakeholders.where((s) => s.id != id).toList(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  // ---- Access ----

  void grantAccess(String email, RBACRole role) {
    if (_estimate == null) return;
    final existing =
        _estimate!.access.indexWhere((a) => a.userEmail == email);
    final now = DateTime.now();
    List<AccessGrant> access;
    if (existing >= 0) {
      access = _estimate!.access.asMap().map((i, a) => MapEntry(
          i,
          i == existing
              ? AccessGrant(
                  userEmail: email,
                  role: role,
                  grantedBy: currentUserEmail,
                  grantedAt: now,
                )
              : a)).values.toList();
    } else {
      access = [
        ..._estimate!.access,
        AccessGrant(
          userEmail: email,
          role: role,
          grantedBy: currentUserEmail,
          grantedAt: now,
        ),
      ];
    }
    _estimate = _estimate!.copyWith(
      access: access,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  void revokeAccess(String email) {
    if (_estimate == null) return;
    _estimate = _estimate!.copyWith(
      access: _estimate!.access.where((a) => a.userEmail != email).toList(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  void setCurrentRole(RBACRole role) {
    _currentRole = role;
    notifyListeners();
  }

  // ---- Accounting ----

  void updateAccounting(AccountingIntegration patch) {
    if (_estimate == null) return;
    _estimate = _estimate!.copyWith(
      accountingIntegration: AccountingIntegration(
        provider: patch.provider,
        connected: patch.connected,
        connectedAt: patch.connectedAt,
        glMapping: patch.glMapping,
      ),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  // ---- Review & Acceptance ----

  void submitForReview() {
    if (_estimate == null) return;
    _estimate = _estimate!.copyWith(
      status: EstimateStatus.inReview,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  void updateReview(ReviewApproval patch) {
    if (_estimate == null) return;
    _estimate = _estimate!.copyWith(
      review: patch,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  void setAcceptanceStep1(bool confirmed) {
    if (_estimate == null) return;
    final review = _estimate!.review ??
        const ReviewApproval(
          requiredApprovers: [],
          acceptanceStep1: (confirmed: false, by: null, at: null),
          acceptanceStep2: (confirmed: false, by: null, at: null),
        );
    _estimate = _estimate!.copyWith(
      review: review.copyWith(
        acceptanceStep1: (
          confirmed: confirmed,
          by: confirmed ? currentUserEmail : null,
          at: confirmed ? DateTime.now() : null,
        ),
      ),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  void setAcceptanceStep2(bool confirmed) {
    if (_estimate == null) return;
    final review = _estimate!.review ??
        const ReviewApproval(
          requiredApprovers: [],
          acceptanceStep1: (confirmed: false, by: null, at: null),
          acceptanceStep2: (confirmed: false, by: null, at: null),
        );
    _estimate = _estimate!.copyWith(
      review: review.copyWith(
        acceptanceStep2: (
          confirmed: confirmed,
          by: confirmed ? currentUserEmail : null,
          at: confirmed ? DateTime.now() : null,
        ),
      ),
      status: confirmed ? EstimateStatus.approved : _estimate!.status,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  // ---- Baseline ----

  void lockBaseline() {
    if (_estimate == null) return;
    final now = DateTime.now();
    final baseline = Baseline(
      version: 1,
      lockedAt: now,
      lockedBy: currentUserEmail,
      snapshot: BaselineSnapshot(
        lines: List.from(_estimate!.lines),
        totals: _estimate!.totals,
        boe: _estimate!.boe,
        className: _estimate!.className,
        deliveryModel: _estimate!.deliveryModel,
      ),
      rebaselineRemaining: 2,
      rebaselineHistory: [],
    );
    _estimate = _estimate!.copyWith(
      status: EstimateStatus.baselined,
      baseline: baseline,
      updatedAt: now,
    );
    notifyListeners();
    _saveToStorage();
  }

  bool rebaseline({
    required String reason,
    String? mocId,
    String? agileInfoNote,
  }) {
    if (_estimate == null || _estimate!.baseline == null) return false;
    if (_estimate!.baseline!.rebaselineRemaining <= 0) return false;
    final now = DateTime.now();
    final newVersion = _estimate!.baseline!.version + 1;
    final record = RebaselineRecord(
      version: newVersion,
      reason: reason,
      mocId: mocId,
      agileInfoNote: agileInfoNote,
      at: now,
      by: currentUserEmail,
    );
    final baseline = Baseline(
      version: newVersion,
      lockedAt: now,
      lockedBy: currentUserEmail,
      snapshot: BaselineSnapshot(
        lines: List.from(_estimate!.lines),
        totals: _estimate!.totals,
        boe: _estimate!.boe,
        className: _estimate!.className,
        deliveryModel: _estimate!.deliveryModel,
      ),
      rebaselineRemaining: _estimate!.baseline!.rebaselineRemaining - 1,
      rebaselineHistory: [
        ..._estimate!.baseline!.rebaselineHistory,
        record,
      ],
    );
    // Clear variance flags on lines
    final lines = _estimate!.lines
        .map((l) => l.copyWith(
              varianceType: null,
              varianceDelta: null,
              varianceBaselineTotal: null,
            ))
        .toList();
    _estimate = _estimate!.copyWith(
      status: EstimateStatus.rebaselined,
      baseline: baseline,
      lines: lines,
      updatedAt: now,
    );
    notifyListeners();
    _saveToStorage();
    return true;
  }
}

/// Lightweight description of a purchase already scheduled in the Schedule
/// module that the Cost Estimate should carry. Constructed by the Schedule
/// UI from its activities (see `lib/schedule/utils/schedule_purchase_cost.dart`)
/// — no schedule-model dependency here keeps the provider import-safe.
class ScheduledPurchaseCandidate {
  /// `ScheduleActivity.id` — used to stamp `ScheduleActivity.costLineId` after
  /// the pull so repeat pulls stay idempotent.
  final String activityId;

  /// `ScheduleActivity.name` — becomes the cost-line description.
  final String title;

  /// `ScheduleActivity.wbsCode` — links the line to the same WBS node the
  /// scheduled work package is attached to.
  final String? wbsRef;

  /// `ScheduleActivity.costLineId` when the activity is already linked.
  final String? activityCostLineId;

  const ScheduledPurchaseCandidate({
    required this.activityId,
    required this.title,
    this.wbsRef,
    this.activityCostLineId,
  });
}

/// Result of [CostEstimateProvider.pullScheduledPurchases].
class ScheduledPurchasePullResult {
  /// Number of new procurement cost lines created.
  final int pulled;

  /// Purchases that were already represented — nothing created for them.
  final int alreadyInEstimate;

  /// `ScheduleActivity.id` → new `CostLine.id` for every line created, so the
  /// caller can stamp the activity's `costLineId` and keep future pulls
  /// idempotent.
  final Map<String, String> addedByActivityId;

  const ScheduledPurchasePullResult({
    required this.pulled,
    required this.alreadyInEstimate,
    required this.addedByActivityId,
  });

  static const empty = ScheduledPurchasePullResult(
    pulled: 0,
    alreadyInEstimate: 0,
    addedByActivityId: <String, String>{},
  );
}
