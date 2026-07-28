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
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/compute_utils.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

const String _storageKey = 'ndu_cost_estimate_v1';
const String currentUserEmail = 'you@ndu.project';

class CostEstimateProvider extends ChangeNotifier {
  CostEstimate? _estimate;
  RBACRole _currentRole = RBACRole.admin;
  bool _setupComplete = false;

  CostEstimate? get estimate => _estimate;
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
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cost estimate: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'state': {
          'estimate': _estimate != null ? {'id': _estimate!.id, 'projectName': _estimate!.projectName, 'className': _estimate!.className.name, 'deliveryModel': _estimate!.deliveryModel.name, 'status': _estimate!.status.name, 'currency': _estimate!.currency} : null,
          'setupComplete': _setupComplete,
        },
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving cost estimate: $e');
    }
  }

  CostEstimate _estimateFromJson(Map<String, dynamic> json) {
    // Simplified deserialization — in production, use json_serializable
    return CostEstimate(
      id: json['id'] as String,
      projectId: json['projectId'] as String? ?? 'default',
      projectName: json['projectName'] as String,
      className: EstimateClass.values
          .byName(json['className'] as String? ?? 'class3'),
      deliveryModel: DeliveryModel.values
          .byName(json['deliveryModel'] as String? ?? 'waterfall'),
      status: EstimateStatus.values
          .byName(json['status'] as String? ?? 'draft'),
      currency: json['currency'] as String? ?? 'USD',
      lines: [],
      boe: emptyBOE(EstimateClass.values
          .byName(json['className'] as String? ?? 'class3')),
      totals: EstimateTotals.empty(),
      access: [],
      stakeholders: [],
      aiSuggestions: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
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
        ReviewApproval(
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
        ReviewApproval(
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
