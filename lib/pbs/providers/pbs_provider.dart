library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ndu_project/pbs/models/pbs_models.dart';
import 'package:ndu_project/utils/project_scoped_storage.dart';
import 'package:ndu_project/utils/unique_id.dart';

/// Project-scoped storage key prefix — see [projectScopedPrefsKey].
///
/// Storage used to be one global entry (`ndu_pbs_v1`), so every project in the
/// workspace read back whichever project's PBS was saved last. Records under
/// that legacy key are now adopted once, by the project they belong to, and
/// then removed.
const String _storageKeyPrefix = 'ndu_pbs_v2';
const String _legacyStorageKey = 'ndu_pbs_v1';

class PBSProvider extends ChangeNotifier {
  PBS? _pbs;
  bool _setupComplete = false;
  bool _isLoadingFromStorage = true;

  /// Project whose PBS is currently held in [_pbs] (see [ensureProjectLoaded])
  /// — [unattributedProjectId] until one is loaded.
  String _activeProjectId = unattributedProjectId;

  PBS? get pbs => _pbs;
  bool get setupComplete => _setupComplete;
  bool get isLoadingFromStorage => _isLoadingFromStorage;

  /// The project whose PBS this provider currently holds.
  String get activeProjectId => _activeProjectId;

  PBSProvider() {
    _loadFromStorage();
  }

  String _storageKeyForProject(String projectId) =>
      projectScopedPrefsKey(_storageKeyPrefix, projectId);

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKeyForProject(_activeProjectId));
      if (raw != null) {
        _applyStoredState(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error loading PBS: $e');
    } finally {
      _isLoadingFromStorage = false;
      notifyListeners();
    }
  }

  /// Applies a decoded `{'state': {...}}` payload to this provider.
  void _applyStoredState(Map<String, dynamic> decoded) {
    final state = decoded['state'] as Map<String, dynamic>? ?? {};
    _setupComplete = state['setupComplete'] as bool? ?? false;
    final pbsJson = state['pbs'] as Map<String, dynamic>?;
    _pbs = pbsJson != null ? PBS.fromJson(pbsJson) : null;
  }

  /// Makes [projectId]'s own PBS the one in memory before any caller reads
  /// [pbs].
  ///
  /// Screens must call this on entry (and whenever the active project changes):
  /// storage is project-scoped, so without it the provider would keep showing
  /// the previously opened project's product breakdown. A legacy global record
  /// is adopted here — once — by the project it belongs to and then removed, so
  /// it can never appear inside another project.
  ///
  /// An empty [projectId] selects the [unattributedProjectId] scope rather than
  /// silently keeping another project's PBS on screen.
  Future<void> ensureProjectLoaded(
    String projectId, {
    String? projectName,
  }) async {
    final pid = projectId.trim().isEmpty
        ? unattributedProjectId
        : projectId.trim();

    // Wait for the constructor's bootstrap read so we don't race it.
    while (_isLoadingFromStorage) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    if (_activeProjectId == pid) return;

    // Reset before loading, so a missing/failed load can never leave the
    // previous project's PBS on screen.
    _activeProjectId = pid;
    _pbs = null;
    _setupComplete = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKeyForProject(pid));
      if (raw != null) {
        _applyStoredState(jsonDecode(raw) as Map<String, dynamic>);
        notifyListeners();
        return;
      }
      await _adoptLegacyRecord(prefs, pid, projectName);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading project-scoped PBS: $e');
    }
  }

  /// Adopts the pre-scoping global record ([_legacyStorageKey]) for [pid] when
  /// it belongs to that project, then moves it onto the project's own key and
  /// clears the legacy entry so it is claimed exactly once.
  Future<void> _adoptLegacyRecord(
    SharedPreferences prefs,
    String pid,
    String? projectName,
  ) async {
    final raw = prefs.getString(_legacyStorageKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final state = decoded['state'] as Map<String, dynamic>? ?? {};
    final pbsJson = state['pbs'] as Map<String, dynamic>?;
    if (pbsJson == null) return;
    if (!legacyRecordBelongsToProject(
      projectId: pid,
      projectName: projectName,
      legacyProjectId: pbsJson['projectId']?.toString(),
      legacyProjectName: pbsJson['projectName']?.toString(),
    )) {
      return;
    }

    _applyStoredState(decoded);
    final adopted = _pbs;
    if (adopted != null && adopted.projectId != pid) {
      final resolvedName = (projectName ?? '').trim();
      _pbs = adopted.copyWith(
        projectId: pid,
        projectName: resolvedName.isEmpty ? adopted.projectName : resolvedName,
      );
    }
    await _saveToStorage();
    await prefs.remove(_legacyStorageKey);
  }

  Future<void> _saveToStorage() async {
    // Snapshot the target key and payload BEFORE awaiting: a project switch that
    // lands while this write is in flight must not retarget it at another
    // project's key or serialise the wrong state.
    final key = _storageKeyForProject(_activeProjectId);
    final payload = jsonEncode({
      'state': {
        'pbs': _pbs?.toJson(),
        'setupComplete': _setupComplete,
      },
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, payload);
    } catch (e) {
      debugPrint('Error saving PBS: $e');
    }
  }

  /// Creates a new product breakdown for [projectId] and binds the provider to
  /// it, so it is persisted (and read back) under that project's own key —
  /// never the shared `default` scope.
  void initPBS(String projectId, String projectName) {
    _activeProjectId = projectId.trim().isEmpty
        ? unattributedProjectId
        : projectId.trim();
    _pbs = PBS(
      id: newId(),
      projectId: _activeProjectId,
      projectName: projectName,
      root: PBSNode(
        id: 'root',
        code: 'PBS.0',
        name: projectName,
        description: 'Product Breakdown for $projectName',
        productType: ProductType.system,
      ),
    );
    _setupComplete = true;
    notifyListeners();
    _saveToStorage();
  }

  void addNode(String parentId, PBSNode node) {
    if (_pbs == null) return;
    _pbs = _pbs!.copyWith(
      root: _addNodeRecursive(_pbs!.root, parentId, node),
    );
    notifyListeners();
    _saveToStorage();
  }

  PBSNode _addNodeRecursive(PBSNode node, String parentId, PBSNode newNode) {
    if (node.id == parentId) {
      return node.copyWith(
        children: [...node.children, newNode],
      );
    }
    return node.copyWith(
      children: node.children
          .map((c) => _addNodeRecursive(c, parentId, newNode))
          .toList(),
    );
  }

  void updateNode(String nodeId, PBSNode updated) {
    if (_pbs == null) return;
    _pbs = _pbs!.copyWith(
      root: _updateNodeRecursive(_pbs!.root, nodeId, updated),
    );
    notifyListeners();
    _saveToStorage();
  }

  PBSNode _updateNodeRecursive(PBSNode node, String nodeId, PBSNode updated) {
    if (node.id == nodeId) return updated;
    return node.copyWith(
      children: node.children
          .map((c) => _updateNodeRecursive(c, nodeId, updated))
          .toList(),
    );
  }

  void removeNode(String nodeId) {
    if (_pbs == null || nodeId == 'root') return;
    _pbs = _pbs!.copyWith(
      root: _removeNodeRecursive(_pbs!.root, nodeId),
    );
    notifyListeners();
    _saveToStorage();
  }

  PBSNode _removeNodeRecursive(PBSNode node, String nodeId) {
    return node.copyWith(
      children: node.children
          .where((c) => c.id != nodeId)
          .map((c) => _removeNodeRecursive(c, nodeId))
          .toList(),
    );
  }

  void clearPBS() {
    _pbs = null;
    _setupComplete = false;
    notifyListeners();
    _saveToStorage();
  }
}
