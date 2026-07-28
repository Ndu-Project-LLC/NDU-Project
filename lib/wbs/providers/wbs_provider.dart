/// WBS — ChangeNotifier-based state management (Dart equivalent)
///
/// Supports unlimited tree depth up to WBSFramework.maxDepth.
/// Now includes ProjectMethodology and per-node methodology tracking for hybrid projects.

library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/models/wbs_templates.dart';

const String _legacyStorageKey = 'ndu_wbs_v2';
const String _storageKeyPrefix = 'ndu_wbs_v2_project_';

class WBSProvider extends ChangeNotifier {
  WBS? _wbs;
  bool _setupComplete = false;
  bool _isLoadingFromStorage = true;
  WBSViewMode _viewMode = WBSViewMode.advanced;
  String _activeProjectId = 'default';

  WBS? get wbs => _wbs;
  bool get setupComplete => _setupComplete;
  bool get isLoadingFromStorage => _isLoadingFromStorage;
  WBSViewMode get viewMode => _viewMode;

  void setViewMode(WBSViewMode mode) {
    _viewMode = mode;
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
        _viewMode = state['viewMode'] != null
          ? WBSViewMode.values.firstWhere(
              (m) => m.name == state['viewMode'],
              orElse: () => WBSViewMode.advanced,
            )
          : WBSViewMode.advanced;
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

  Future<void> _loadProjectScopedStorage(String projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKeyForProject(projectId);
      final raw = prefs.getString(key);
      if (raw == null) {
        _wbs = null;
        _setupComplete = false;
        _activeProjectId = projectId;
        notifyListeners();
        return;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final state = data['state'] as Map<String, dynamic>? ?? {};
      _setupComplete = state['setupComplete'] as bool? ?? false;
      _viewMode = state['viewMode'] != null
          ? WBSViewMode.values.firstWhere(
              (m) => m.name == state['viewMode'],
              orElse: () => _viewMode,
            )
          : _viewMode;
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
          'viewMode': _viewMode.name,
        },
      };
      final key = _storageKeyForProject(_wbs?.projectId ?? _activeProjectId);
      await prefs.setString(key, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving WBS: $e');
    }
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
    );
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
}
