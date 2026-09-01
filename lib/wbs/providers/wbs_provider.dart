/// WBS — ChangeNotifier-based state management (Dart equivalent)
///
/// Supports unlimited tree depth up to WBSFramework.maxDepth.
/// Now includes ProjectMethodology and per-node methodology tracking for hybrid projects.

library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart' hide EstimationMethod;
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/models/wbs_templates.dart';
import 'package:ndu_project/wbs/providers/wbs_cost_rollup.dart';
import 'package:ndu_project/wbs/services/wbs_firestore_service.dart';

const String _legacyStorageKey = 'ndu_wbs_v2';
const String _storageKeyPrefix = 'ndu_wbs_v2_project_';

class WBSProvider extends ChangeNotifier {
  WBS? _wbs;
  bool _setupComplete = false;
  bool _isLoadingFromStorage = true;
  bool _viewModeSimple = true;
  String _activeProjectId = 'default';

  /// Dedup guard for [ensureProjectLoaded] so concurrent callers (e.g. the
  /// auto-sync on page load and a manual "Sync from WBS" button press firing
  /// in the same frame) share a single underlying Firestore/SharedPreferences
  /// read instead of racing each other.
  Completer<void>? _projectLoadCompleter;
  String? _loadingProjectId;

  WBS? get wbs => _wbs;
  bool get setupComplete => _setupComplete;
  bool get isLoadingFromStorage => _isLoadingFromStorage;
  bool get viewModeSimple => _viewModeSimple;

  void setViewMode(bool simple) {
    _viewModeSimple = simple;
    notifyListeners();
    _saveToStorage();
  }

  String _storageKeyForProject(String projectId) =>
      '$_storageKeyPrefix${projectId.isEmpty ? 'default' : projectId}';

  WBSProvider() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_legacyStorageKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final state = data['state'] as Map<String, dynamic>? ?? {};
        _setupComplete = state['setupComplete'] as bool? ?? false;
        // View mode intentionally resets to Simple on every page load.
        if (state['wbs'] != null) {
          _wbs = _wbsFromJson(state['wbs'] as Map<String, dynamic>);
          _activeProjectId =
              _wbs?.projectId.isNotEmpty == true ? _wbs!.projectId : 'default';
        }
      }
    } catch (e) {
      debugPrint('Error loading WBS: $e');
    } finally {
      _isLoadingFromStorage = false;
      notifyListeners();
    }
  }

  /// Ensures the WBS tree for [projectId] is loaded into [_wbs] before any
  /// caller reads it. This is the entry point screens should call *before*
  /// inspecting [wbs] — otherwise the provider may still hold a stale WBS
  /// from a previously-active project (or `null` after a fresh app start with
  /// no legacy storage).
  ///
  /// Behaviour:
  /// - Awaits the initial legacy-storage load if it is still in flight
  ///   (so we don't return `null` while the constructor's async load is
  ///   pending).
  /// - If the currently-loaded WBS already belongs to [projectId], returns
  ///   immediately (no work, no notifyListeners).
  /// - Otherwise delegates to [_loadProjectScopedStorage], which first
  ///   tries Firestore, then falls back to project-scoped SharedPreferences,
  ///   and finally (via the legacy-storage fallback) to the legacy
  ///   `ndu_wbs_v2` entry if its `projectId` matches.
  ///
  /// Concurrent calls for the same [projectId] are coalesced via a
  /// [Completer] so we never issue duplicate Firestore reads.
  Future<void> ensureProjectLoaded(String projectId) async {
    final pid = projectId.isEmpty ? 'default' : projectId;

    // Wait for the constructor's initial load so we don't race with it.
    while (_isLoadingFromStorage) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    // Already loaded for this project? Fast-path.
    if (_activeProjectId == pid && _wbs != null && _wbs!.projectId == pid) {
      return;
    }

    // Coalesce concurrent loads for the same project.
    if (_loadingProjectId == pid && _projectLoadCompleter != null) {
      return _projectLoadCompleter!.future;
    }

    _loadingProjectId = pid;
    _projectLoadCompleter = Completer<void>();
    try {
      await _loadProjectScopedStorage(pid);
    } finally {
      _projectLoadCompleter!.complete();
      _projectLoadCompleter = null;
      _loadingProjectId = null;
    }
  }

  Future<void> _loadProjectScopedStorage(String projectId) async {
    // Try Firestore first (source of truth for cross-device sync) for any
    // real project ID. 'default' is the no-project fallback — skip Firestore
    // for it (there's no Firestore doc for 'default') and go straight to
    // legacy SharedPreferences fallback so existing single-project users
    // don't lose their WBS.
    if (projectId.isNotEmpty && projectId != 'default') {
      final firestoreWbs = await WbsFirestoreService.loadWBS(projectId);
      if (firestoreWbs != null) {
        _wbs = firestoreWbs;
        _setupComplete = true;
        _activeProjectId = projectId;
        notifyListeners();
        _saveToStorage();
        return;
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKeyForProject(projectId);
      final raw = prefs.getString(key);
      if (raw == null) {
        // No project-scoped WBS — try legacy as a migration fallback.
        // Only adopt the legacy WBS if its projectId matches the requested
        // project (so we never leak a different project's WBS into the
        // current project's context).
        final legacyRaw = prefs.getString(_legacyStorageKey);
        if (legacyRaw != null) {
          final legacyData = jsonDecode(legacyRaw) as Map<String, dynamic>;
          final legacyState =
              legacyData['state'] as Map<String, dynamic>? ?? {};
          if (legacyState['wbs'] != null) {
            final legacyWbs =
                _wbsFromJson(legacyState['wbs'] as Map<String, dynamic>);
            if (legacyWbs.projectId == projectId) {
              _wbs = legacyWbs;
              _setupComplete =
                  legacyState['setupComplete'] as bool? ?? false;
              // View mode intentionally resets to Simple on every page load.
              _activeProjectId = projectId;
              notifyListeners();
              return;
            }
          }
        }
        _wbs = null;
        _setupComplete = false;
        _activeProjectId = projectId;
        notifyListeners();
        return;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final state = data['state'] as Map<String, dynamic>? ?? {};
      _setupComplete = state['setupComplete'] as bool? ?? false;
      // View mode intentionally resets to Simple on every page load.
      _wbs = state['wbs'] != null
          ? _wbsFromJson(state['wbs'] as Map<String, dynamic>)
          : null;
      _activeProjectId = projectId;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading project-scoped WBS: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'state': {
          'wbs': _wbs != null ? _wbsToJson(_wbs!) : null,
          'setupComplete': _setupComplete,
        },
      };
      final key = _storageKeyForProject(_wbs?.projectId ?? _activeProjectId);
      await prefs.setString(key, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving WBS: $e');
    }
    _saveToFirestore();
  }

  Future<void> _saveToFirestore() async {
    final pid = _wbs?.projectId ?? _activeProjectId;
    if (pid.isEmpty || pid == 'default') return;
    if (_wbs == null) return;
    await WbsFirestoreService.saveWBS(pid, _wbs!);
  }

  WBS _wbsFromJson(Map<String, dynamic> json) {
    return WBS(
      id: json['id'] as String,
      projectId: json['projectId'] as String? ?? 'default',
      projectName: json['projectName'] as String,
      framework: WBSFramework.values
          .byName(json['framework'] as String? ?? 'waterfallDeliverable'),
      methodology: json['methodology'] != null
          ? ProjectMethodology.values.byName(json['methodology'] as String)
          : ProjectMethodology.waterfall,
      level0: _nodeFromJson(json['level0'] as Map<String, dynamic>),
      aiSuggestions: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  WBSNode _nodeFromJson(Map<String, dynamic> json) {
    return WBSNode(
      id: json['id'] as String,
      level: WBSLevel.values.byName(json['level'] as String? ?? 'level0'),
      code: json['code'] as String? ?? '0',
      name: json['name'] as String,
      description: json['description'] as String?,
      estimationMethod: json['estimationMethod'] != null
          ? EstimationMethod.values.byName(json['estimationMethod'] as String)
          : null,
      isWorkPackage: json['isWorkPackage'] as bool?,
      aiGenerated: json['aiGenerated'] as bool? ?? false,
      aiSource: json['aiSource'] != null
          ? AISource.values.byName(json['aiSource'] as String)
          : null,
      aiConfidence: json['aiConfidence'] != null
          ? AIConfidence.values.byName(json['aiConfidence'] as String)
          : null,
      methodology: json['methodology'] as String?,
      costLineIds: json['costLineIds'] != null
          ? (json['costLineIds'] as List<dynamic>).cast<String>()
          : null,
      // Cross-section linkage (WBS ↔ PC ↔ Schedule)
      controlAccountId: json['controlAccountId'] as String?,
      scheduleActivityId: json['scheduleActivityId'] as String?,
      percentComplete: (json['percentComplete'] as num?)?.toDouble(),
      actualCost: (json['actualCost'] as num?)?.toDouble(),
      plannedStart: json['plannedStart'] != null
          ? DateTime.tryParse(json['plannedStart'] as String)
          : null,
      plannedFinish: json['plannedFinish'] != null
          ? DateTime.tryParse(json['plannedFinish'] as String)
          : null,
      scheduleStatus: json['scheduleStatus'] as String?,
      // WBS Dictionary (Phase 1)
      deliverableDescription: json['deliverableDescription'] as String?,
      acceptanceCriteria: json['acceptanceCriteria'] != null
          ? (json['acceptanceCriteria'] as List<dynamic>).cast<String>()
          : null,
      workPackageDefinition: json['workPackageDefinition'] as String?,
      children: (json['children'] as List<dynamic>? ?? [])
          .map((c) => _nodeFromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> _wbsToJson(WBS wbs) => {
        'id': wbs.id,
        'projectId': wbs.projectId,
        'projectName': wbs.projectName,
        'framework': wbs.framework.name,
        if (wbs.methodology != ProjectMethodology.waterfall)
          'methodology': wbs.methodology.name,
        'level0': _nodeToJson(wbs.level0),
      };

  Map<String, dynamic> _nodeToJson(WBSNode node) => {
        'id': node.id,
        'level': node.level.name,
        'code': node.code,
        'name': node.name,
        if (node.description != null) 'description': node.description,
        if (node.estimationMethod != null)
          'estimationMethod': node.estimationMethod!.name,
        if (node.isWorkPackage != null) 'isWorkPackage': node.isWorkPackage,
        if (node.aiGenerated) 'aiGenerated': true,
        if (node.aiSource != null) 'aiSource': node.aiSource!.name,
        if (node.aiConfidence != null) 'aiConfidence': node.aiConfidence!.name,
        if (node.methodology != null) 'methodology': node.methodology,
        if (node.costLineIds != null && node.costLineIds!.isNotEmpty)
          'costLineIds': node.costLineIds,
        // Cross-section linkage (WBS ↔ PC ↔ Schedule)
        if (node.controlAccountId != null && node.controlAccountId!.isNotEmpty)
          'controlAccountId': node.controlAccountId,
        if (node.scheduleActivityId != null &&
            node.scheduleActivityId!.isNotEmpty)
          'scheduleActivityId': node.scheduleActivityId,
        if (node.percentComplete != null) 'percentComplete': node.percentComplete,
        if (node.actualCost != null) 'actualCost': node.actualCost,
        if (node.plannedStart != null)
          'plannedStart': node.plannedStart!.toIso8601String(),
        if (node.plannedFinish != null)
          'plannedFinish': node.plannedFinish!.toIso8601String(),
        if (node.scheduleStatus != null && node.scheduleStatus!.isNotEmpty)
          'scheduleStatus': node.scheduleStatus,
        // WBS Dictionary (Phase 1)
        if (node.deliverableDescription != null &&
            node.deliverableDescription!.isNotEmpty)
          'deliverableDescription': node.deliverableDescription,
        if (node.acceptanceCriteria != null &&
            node.acceptanceCriteria!.isNotEmpty)
          'acceptanceCriteria': node.acceptanceCriteria,
        if (node.workPackageDefinition != null &&
            node.workPackageDefinition!.isNotEmpty)
          'workPackageDefinition': node.workPackageDefinition,
        'children': node.children.map(_nodeToJson).toList(),
      };

  // ---- Setup ----

  void setup({
    required String projectName,
    required WBSFramework framework,
    ProjectMethodology methodology = ProjectMethodology.waterfall,
    String projectId = 'default',
  }) {
    // Don't overwrite if storage load hasn't completed yet
    if (_isLoadingFromStorage) return;
    // Don't overwrite if already set up
    if (_wbs != null && _setupComplete) {
      syncToProject(projectId, projectName);
      return;
    }
    _wbs = createEmptyWBS(
      projectId: projectId,
      projectName: projectName,
      framework: framework,
      methodology: methodology,
    );
    _setupComplete = true;
    notifyListeners();
    _saveToStorage();
  }

  /// Updates the WBS root node name to match the current project name.
  /// Called when the user switches projects so the WBS tree always reflects
  /// the active project, not a stale project from a previous session.
  void syncToProject(String projectId, String projectName) {
    if (_isLoadingFromStorage) return;

    if (_activeProjectId != projectId) {
      _activeProjectId = projectId;
      _loadProjectScopedStorage(projectId);
      return;
    }

    if (_wbs == null) return;

    if ((_wbs!.projectName != projectName && projectName.isNotEmpty) ||
        _wbs!.projectId != projectId) {
      _wbs = _wbs!.copyWith(
        projectId: projectId,
        projectName: projectName.isEmpty ? _wbs!.projectName : projectName,
        level0: _wbs!.level0.copyWith(
          name: projectName.isEmpty ? _wbs!.level0.name : projectName,
        ),
      );
      notifyListeners();
      _saveToStorage();
    }
  }

  void resetWBS() {
    _wbs = null;
    _setupComplete = false;
    notifyListeners();
    _saveToStorage();
  }

  /// Maps a project methodology to the default WBS framework used at setup.
  /// Agile and Hybrid both use the agile breakdown (Epic → Feature → Story
  /// → Task); Hybrid additionally allows per-node waterfall methodology.
  /// Pure Waterfall → Deliverable-Based waterfall.
  static WBSFramework frameworkForMethodology(ProjectMethodology methodology) {
    return methodology == ProjectMethodology.waterfall
        ? WBSFramework.waterfallDeliverable
        : WBSFramework.agile;
  }

  /// Re-syncs the WBS methodology/framework with the project's current
  /// Project Details selection (Waterfall / Agile / Hybrid). Existing nodes
  /// are kept intact — only the document-level methodology and framework
  /// (which drive the header badge and level labels) are updated.
  void syncMethodology(ProjectMethodology methodology) {
    if (_isLoadingFromStorage || _wbs == null) return;
    final framework = frameworkForMethodology(methodology);
    if (_wbs!.methodology == methodology && _wbs!.framework == framework) {
      return;
    }
    _wbs = _wbs!.copyWith(methodology: methodology, framework: framework);
    notifyListeners();
    _saveToStorage();
  }

  // ---- Node operations ----

  /// Add a child node at any level under [parentId].
  /// The new node's level is automatically determined as parentLevel + 1.
  /// Returns the new node's ID, or '' on failure.
  String addChildNode(String parentId, String name, [String? description]) {
    if (_wbs == null) return '';
    final parent = findNode(parentId);
    if (parent == null) return '';
    final parentDepth = parent.level.value;
    final newLevel = parentDepth + 1;
    final maxDepth = _wbs!.framework.maxDepth;

    if (newLevel > maxDepth) {
      debugPrint('Cannot add node: max depth ($maxDepth) reached');
      return '';
    }

    final id = newWBSId('node');
    final framework = _wbs!.framework;
    final newNode = WBSNode(
      id: id,
      level: WBSLevelMeta.fromInt(newLevel),
      code: '',
      name: name,
      description: description,
      aiGenerated: false,
      isWorkPackage: newLevel >= 3 && framework != WBSFramework.agile,
      estimationMethod: framework.suggestedEstimation(newLevel),
      methodology: parent.methodology, // inherit parent methodology
      children: [],
    );

    final updatedLevel0 = recalcCodes(_findAndUpdateNode(_wbs!.level0, parentId,
        (n) => n.copyWith(children: [...n.children, newNode])));
    _wbs = _wbs!.copyWith(
      level0: updatedLevel0,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
    return id;
  }

  /// Add multiple child nodes at once (from template).
  void addNodesFromTemplate(String parentId, List<TemplateNode> templates) {
    for (final t in templates) {
      final childId = addChildNode(parentId, t.name, t.description);
      for (final c in t.children) {
        if (childId.isNotEmpty) {
          addChildNode(childId, c.name, c.description);
        }
      }
    }
  }

  /// Add nodes from a flat list of names (used by KAZ AI generation).
  void addBulkNodes(String parentId, List<String> names) {
    for (final n in names) {
      if (n.trim().isNotEmpty) {
        addChildNode(parentId, n.trim());
      }
    }
  }

  /// Set the methodology for a specific node (for hybrid projects).
  void setNodeMethodology(String nodeId, String? methodology) {
    if (_wbs == null) return;
    final updatedLevel0 = _findAndUpdateNode(_wbs!.level0, nodeId, (n) {
      return n.copyWith(methodology: methodology);
    });
    _wbs = _wbs!.copyWith(
      level0: updatedLevel0,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  void updateNode(String id, WBSNode patch) {
    if (_wbs == null) return;
    final updatedLevel0 = recalcCodes(
        _findAndUpdateNode(_wbs!.level0, id, (n) => _mergeNode(n, patch)));
    _wbs = _wbs!.copyWith(
      level0: updatedLevel0,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  WBSNode _mergeNode(WBSNode original, WBSNode patch) {
    return original.copyWith(
      name: patch.name,
      description: patch.description,
      estimationMethod: patch.estimationMethod,
      isWorkPackage: patch.isWorkPackage,
      aiGenerated: patch.aiGenerated,
      aiSource: patch.aiSource,
      aiConfidence: patch.aiConfidence,
      aiReference: patch.aiReference,
      methodology: patch.methodology,
      // WBS Dictionary (Phase 1) — propagated through updateNode so the
      // UI can edit deliverableDescription / acceptanceCriteria /
      // workPackageDefinition in place without rebuilding the whole tree.
      deliverableDescription: patch.deliverableDescription,
      acceptanceCriteria: patch.acceptanceCriteria,
      workPackageDefinition: patch.workPackageDefinition,
    );
  }

  /// Convenience helper to update the WBS Dictionary entry for a specific
  /// work-package node. Used by the WBS Builder's dictionary editor panel.
  /// Passing `null` for a field clears it; passing an empty list for
  /// [acceptanceCriteria] clears the list.
  void updateWbsDictionary(
    String nodeId, {
    String? deliverableDescription,
    List<String>? acceptanceCriteria,
    String? workPackageDefinition,
  }) {
    if (_wbs == null) return;
    final updatedLevel0 = _findAndUpdateNode(_wbs!.level0, nodeId, (n) {
      return n.copyWith(
        deliverableDescription: deliverableDescription,
        acceptanceCriteria: acceptanceCriteria,
        workPackageDefinition: workPackageDefinition,
      );
    });
    _wbs = _wbs!.copyWith(
      level0: updatedLevel0,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  void removeNode(String id) {
    if (_wbs == null) return;
    if (_wbs!.level0.id == id) return; // Can't remove Level 0
    final updatedLevel0 = recalcCodes(_findAndRemoveNode(_wbs!.level0, id));
    _wbs = _wbs!.copyWith(
      level0: updatedLevel0,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  void moveNode(String id, bool directionUp) {
    if (_wbs == null) return;
    final updatedLevel0 = recalcCodes(_swapNode(_wbs!.level0, id, directionUp));
    _wbs = _wbs!.copyWith(
      level0: updatedLevel0,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  void linkCostLine(String nodeId, String costLineId) {
    if (_wbs == null) return;
    final updatedLevel0 = _findAndUpdateNode(_wbs!.level0, nodeId, (n) {
      final List<String> ids = [...(n.costLineIds ?? <String>[]), costLineId];
      return n.copyWith(costLineIds: ids);
    });
    _wbs = _wbs!.copyWith(
      level0: updatedLevel0,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  void unlinkCostLine(String nodeId, String costLineId) {
    if (_wbs == null) return;
    final updatedLevel0 = _findAndUpdateNode(_wbs!.level0, nodeId, (n) {
      final List<String> ids = (n.costLineIds ?? <String>[])
          .where((id) => id != costLineId)
          .toList();
      return n.copyWith(costLineIds: ids);
    });
    _wbs = _wbs!.copyWith(
      level0: updatedLevel0,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
  }

  // ---- Tree helpers ----

  WBSNode _findAndUpdateNode(
      WBSNode root, String id, WBSNode Function(WBSNode) updater) {
    if (root.id == id) return updater(root);
    return root.copyWith(
      children:
          root.children.map((c) => _findAndUpdateNode(c, id, updater)).toList(),
    );
  }

  WBSNode _findAndRemoveNode(WBSNode root, String id) {
    return root.copyWith(
      children: root.children
          .where((c) => c.id != id)
          .map((c) => _findAndRemoveNode(c, id))
          .toList(),
    );
  }

  WBSNode _swapNode(WBSNode root, String id, bool directionUp) {
    List<WBSNode> swap(List<WBSNode> arr) {
      final idx = arr.indexWhere((n) => n.id == id);
      if (idx >= 0) {
        if (directionUp && idx > 0) {
          final newArr = List<WBSNode>.from(arr);
          final temp = newArr[idx - 1];
          newArr[idx - 1] = newArr[idx];
          newArr[idx] = temp;
          return newArr;
        }
        if (!directionUp && idx < arr.length - 1) {
          final newArr = List<WBSNode>.from(arr);
          final temp = newArr[idx];
          newArr[idx] = newArr[idx + 1];
          newArr[idx + 1] = temp;
          return newArr;
        }
        return arr;
      }
      return arr.map((n) => n.copyWith(children: swap(n.children))).toList();
    }

    final idx = root.children.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      return root.copyWith(children: swap(root.children));
    }
    return root.copyWith(
      children:
          root.children.map((c) => _swapNode(c, id, directionUp)).toList(),
    );
  }

  WBSNode? findNode(String id) {
    WBSNode? find(WBSNode node) {
      if (node.id == id) return node;
      for (final c in node.children) {
        final found = find(c);
        if (found != null) return found;
      }
      return null;
    }

    return _wbs == null ? null : find(_wbs!.level0);
  }

  // ---- Cross-section rollups (cost / schedule / scope) ----

  /// Computes the canonical [WBSNodeCostRollup] for [node] using the given
  /// list of cost lines (typically `CostEstimateProvider.estimate.lines`).
  ///
  /// A cost line is considered linked to a node when EITHER:
  ///   - the node's `costLineIds` contains the line's `id` (canonical FK),
  ///     OR
  ///   - the line's `wbsRef` exactly equals the node's `code` (path string
  ///     like "G1" / "G1.2.3" — the legacy linkage written by AddLineDialog).
  ///
  /// Rolled-up totals include the node's direct lines PLUS every descendant
  /// node's rolled-up total. This is the single source of truth — callers
  /// should NOT re-walk the estimate to compute per-node totals.
  WBSNodeCostRollup computeCostRollup(
    WBSNode node,
    List<CostLine> allLines,
  ) {
    final directLines = allLines.where((l) {
      if ((node.costLineIds ?? const <String>[]).contains(l.id)) return true;
      final ref = (l.wbsRef ?? '').trim();
      return ref.isNotEmpty && ref == node.code;
    }).toList(growable: false);
    final directCost =
        directLines.fold<double>(0, (s, l) => s + _effectiveLineTotal(l));

    double childCost = 0;
    int childCount = 0;
    for (final c in node.children) {
      final r = computeCostRollup(c, allLines);
      childCost += r.rolledUpCost;
      childCount += r.rolledUpLineCount;
    }

    return WBSNodeCostRollup(
      node: node,
      directCost: directCost,
      rolledUpCost: directCost + childCost,
      directLineCount: directLines.length,
      rolledUpLineCount: directLines.length + childCount,
      directLines: directLines,
    );
  }

  /// Convenience wrapper: lookup a node by ID, then compute its rollup.
  /// Returns `null` if the WBS or node doesn't exist.
  WBSNodeCostRollup? getCostRollupForNodeId(
    String nodeId,
    List<CostLine> allLines,
  ) {
    final node = findNode(nodeId);
    if (node == null) return null;
    return computeCostRollup(node, allLines);
  }

  /// Returns cost rollups for every L1 child of the root (i.e. every
  /// "deliverable" in waterfall terminology). Each rollup includes that
  /// node's descendants. This is what the Cost by WBS tab iterates over.
  List<WBSNodeCostRollup> getCostRollupsForL1(List<CostLine> allLines) {
    if (_wbs == null) return const <WBSNodeCostRollup>[];
    return _wbs!.level0.children
        .map((n) => computeCostRollup(n, allLines))
        .toList(growable: false);
  }

  /// Effective contribution of a cost line to a rollup total — accounts
  /// for variance flags (added / removed / changed) so the WBS-side rollup
  /// stays consistent with `ComputeUtils.computeTotals` on the cost side.
  double _effectiveLineTotal(CostLine l) {
    if (l.varianceType == VarianceType.remove) {
      return -(l.varianceBaselineTotal ?? 0);
    }
    if (l.varianceType == VarianceType.change) {
      return l.varianceDelta ?? 0;
    }
    return l.total;
  }

  // ---- Initiation → WBS seeding ----

  /// Seeds the WBS with L1 deliverable nodes derived from the project's
  /// initiation-phase data. Pulls from, in priority order:
  ///   1. `projectGoals` — the "what we're delivering" statements
  ///   2. `keyMilestones` — fallback when goals are empty
  ///   3. `withinScopeItems` — last-resort scope-statement fallback
  ///
  /// Idempotent: candidate names that already exist as L1 children
  /// (matched case-insensitively on trimmed name) are skipped.
  ///
  /// Returns the number of NEW L1 nodes created.
  int seedFromInitiation(ProjectDataModel project) {
    if (_wbs == null) return 0;

    final existingNames = _wbs!.level0.children
        .map((n) => n.name.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();

    final candidates = <String>[];

    void addCandidate(String name) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return;
      final key = trimmed.toLowerCase();
      if (existingNames.contains(key)) return;
      candidates.add(trimmed);
      existingNames.add(key);
    }

    // 1. Project goals (preferred — these are the deliverable statements)
    for (final g in project.projectGoals) {
      addCandidate(g.name);
    }
    // 2. Key milestones (fallback — milestones are time-bound but still
    //    represent deliverables in many frameworks)
    if (candidates.isEmpty) {
      for (final m in project.keyMilestones) {
        addCandidate(m.name);
      }
    }
    // 3. Within-scope items (last resort — these are scope statements,
    //    not deliverables, but they're better than an empty WBS)
    if (candidates.isEmpty) {
      for (final s in project.withinScopeItems) {
        addCandidate(s.description);
      }
    }

    if (candidates.isEmpty) return 0;

    final newChildren = <WBSNode>[];
    for (final name in candidates) {
      final id = newWBSId('node');
      newChildren.add(WBSNode(
        id: id,
        level: WBSLevel.level1,
        code: '', // recalcCodes assigns G1, G2, …
        name: name,
        description: 'Seeded from initiation phase',
        aiGenerated: false,
        isWorkPackage: false,
        methodology: _wbs!.methodology.name, // inherit project methodology
        children: const [],
      ));
    }

    final updatedLevel0 = recalcCodes(_wbs!.level0.copyWith(
      children: [..._wbs!.level0.children, ...newChildren],
    ));
    _wbs = _wbs!.copyWith(
      level0: updatedLevel0,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
    return newChildren.length;
  }

  // ---- FEP Cost Estimate → WBS auto-linking ----

  /// Best-effort links cost lines from [ceProvider] to WBS nodes by
  /// matching:
  ///   1. EXACT CODE MATCH — the line's `wbsRef` (e.g. "G1.2") equals a
  ///      node's `code`. This is the strong signal.
  ///   2. NAME-IN-DESCRIPTION — the lowercase node name (≥ 4 chars) is
  ///      contained within the lowercase cost-line description. This is
  ///      the weak signal — only applied to lines that have no `wbsRef`.
  ///
  /// Idempotent: lines already linked to a node are not re-linked.
  /// Returns the number of NEW links created.
  int autoLinkCostLines(CostEstimateProvider ceProvider) {
    if (_wbs == null) return 0;
    final estimate = ceProvider.estimate;
    if (estimate == null) return 0;

    final lines = estimate.lines;
    if (lines.isEmpty) return 0;

    // Flatten the WBS tree (excluding L0 root).
    final allNodes = <WBSNode>[];
    void collect(WBSNode n) {
      if (n.level != WBSLevel.level0) allNodes.add(n);
      for (final c in n.children) {
        collect(c);
      }
    }

    collect(_wbs!.level0);

    // Code → node fast lookup.
    final byCode = <String, WBSNode>{
      for (final n in allNodes)
        if (n.code.isNotEmpty) n.code: n,
    };

    // Track existing (nodeId, lineId) links so we don't double-link.
    final existingLinks = <String>{};
    for (final n in allNodes) {
      for (final id in (n.costLineIds ?? const <String>[])) {
        existingLinks.add('${n.id}|$id');
      }
    }

    int newLinks = 0;
    // nodeId → list of lineIds to append.
    final additions = <String, List<String>>{};

    void tryLink(String nodeId, String lineId) {
      final key = '$nodeId|$lineId';
      if (existingLinks.contains(key)) return;
      additions.putIfAbsent(nodeId, () => []).add(lineId);
      existingLinks.add(key);
      newLinks++;
    }

    for (final line in lines) {
      final ref = (line.wbsRef ?? '').trim();

      // 1. Strong signal: wbsRef matches a node code.
      if (ref.isNotEmpty && byCode.containsKey(ref)) {
        tryLink(byCode[ref]!.id, line.id);
        continue;
      }

      // 2. Weak signal: node name appears in the line description.
      //    Skip lines that already have a wbsRef — those were explicitly
      //    set by the user and shouldn't be second-guessed.
      if (ref.isNotEmpty) continue;
      final descLower = line.description.toLowerCase();
      if (descLower.isEmpty) continue;

      for (final node in allNodes) {
        final nameLower = node.name.toLowerCase().trim();
        if (nameLower.length < 4) continue; // skip very short names
        if (descLower.contains(nameLower)) {
          tryLink(node.id, line.id);
          break; // link to the first matching node only
        }
      }
    }

    if (additions.isEmpty) return 0;

    // Apply additions by walking the tree once.
    WBSNode applyAdditions(WBSNode n) {
      final adds = additions[n.id];
      final newIds = (adds == null)
          ? (n.costLineIds ?? const <String>[])
          : [...(n.costLineIds ?? const <String>[]), ...adds];
      return n.copyWith(
        costLineIds: newIds,
        children: n.children.map(applyAdditions).toList(growable: false),
      );
    }

    final updatedLevel0 = applyAdditions(_wbs!.level0);
    _wbs = _wbs!.copyWith(
      level0: updatedLevel0,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    _saveToStorage();
    return newLinks;
  }
}
