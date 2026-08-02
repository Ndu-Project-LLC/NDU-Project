library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ndu_project/pbs/models/pbs_models.dart';

const String _storageKey = 'ndu_pbs_v1';

class PBSProvider extends ChangeNotifier {
  PBS? _pbs;
  bool _setupComplete = false;
  bool _isLoadingFromStorage = true;

  PBS? get pbs => _pbs;
  bool get setupComplete => _setupComplete;
  bool get isLoadingFromStorage => _isLoadingFromStorage;

  PBSProvider() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final state = data['state'] as Map<String, dynamic>? ?? {};
        _setupComplete = state['setupComplete'] as bool? ?? false;
        if (state['pbs'] != null) {
          _pbs = PBS.fromJson(state['pbs'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('Error loading PBS: $e');
    } finally {
      _isLoadingFromStorage = false;
      notifyListeners();
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'state': {
          'pbs': _pbs?.toJson(),
          'setupComplete': _setupComplete,
        },
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving PBS: $e');
    }
  }

  void initPBS(String projectId, String projectName) {
    _pbs = PBS(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      projectId: projectId,
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
