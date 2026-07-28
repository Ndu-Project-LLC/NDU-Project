import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/models/app_content_model.dart';
import 'package:ndu_project/services/app_content_service.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider to manage editable app content across the application
class AppContentProvider extends ChangeNotifier {
  static const String _localOverridesKey = 'static_content_overrides';
  final Map<String, String> _contentCache = {};
  final Map<String, String> _localOverrides = {};
  bool _isLoading = false;
  String? _error;
  bool _isEditMode = false;
  bool _isStaticEditMode = false;
  Offset _editButtonPosition = const Offset(16, 170);
  bool _showEditButton =
      true; // false = button visible, true = button hidden (default: hidden)
  bool _isWatching = false; // Prevent multiple stream subscriptions
  StreamSubscription<List<AppContent>>? _contentSubscription;

  Map<String, String> get contentCache => Map.unmodifiable(_contentCache);
  Map<String, String> get localOverrides => Map.unmodifiable(_localOverrides);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEditMode => _isEditMode;
  bool get isStaticEditMode => _isStaticEditMode;
  Offset get editButtonPosition => _editButtonPosition;
  bool get showEditButton => _showEditButton;

  /// Toggle edit mode (admin only)
  void toggleEditMode() {
    if (!_ensureAdminEditing()) return;
    final next = !_isEditMode;
    _isEditMode = next;
    if (next && _isStaticEditMode) {
      _isStaticEditMode = false;
    }
    notifyListeners();
  }

  /// Set edit mode explicitly
  void setEditMode(bool enabled) {
    if (!_ensureAdminEditing()) return;
    if (_isEditMode != enabled) {
      _isEditMode = enabled;
      if (enabled && _isStaticEditMode) {
        _isStaticEditMode = false;
      }
      notifyListeners();
    }
  }

  /// Toggle local-only static edit mode (no backend writes).
  void toggleStaticEditMode() {
    if (!_ensureAdminEditing()) return;
    final next = !_isStaticEditMode;
    _isStaticEditMode = next;
    if (next && _isEditMode) {
      _isEditMode = false;
    }
    notifyListeners();
  }

  /// Set static edit mode explicitly.
  void setStaticEditMode(bool enabled) {
    if (!_ensureAdminEditing()) return;
    if (_isStaticEditMode != enabled) {
      _isStaticEditMode = enabled;
      if (enabled && _isEditMode) {
        _isEditMode = false;
      }
      notifyListeners();
    }
  }

  /// Update edit button position (only notifies when drag ends)
  void updateEditButtonPosition(Offset position) {
    _editButtonPosition = position;
    notifyListeners();
  }

  /// Toggle edit button visibility
  void toggleEditButtonVisibility() {
    if (!_ensureAdminEditing()) return;
    _showEditButton = !_showEditButton;
    notifyListeners();
  }

  /// Set edit button visibility explicitly
  void setEditButtonVisibility(bool visible) {
    if (!_ensureAdminEditing()) return;
    if (_showEditButton != visible) {
      _showEditButton = visible;
      notifyListeners();
    }
  }

  /// Get content value by key with optional fallback
  String getContent(String key, {String fallback = ''}) =>
      _contentCache[key] ?? fallback;

  /// Get content value considering local overrides and edit mode.
  String getDisplayContent(String key, {String fallback = ''}) {
    final localOverride = _localOverrides[key];

    if (_isStaticEditMode) {
      return localOverride ?? fallback;
    }

    if (localOverride != null && !_contentCache.containsKey(key)) {
      return localOverride;
    }

    return _contentCache[key] ?? fallback;
  }

  /// Whether a local override exists for a content key.
  bool hasLocalOverride(String key) => _localOverrides.containsKey(key);

  /// Load all content from Firestore
  Future<void> loadContent() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final content = await AppContentService.getAllContent();
      _contentCache.clear();
      for (final item in content) {
        _contentCache[item.key] = item.value;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Watch content for real-time updates
  void watchContent() {
    if (_isWatching) return; // Prevent multiple subscriptions
    _isWatching = true;

    _contentSubscription?.cancel();
    _contentSubscription = AppContentService.watchContent().listen(
      (content) {
        bool hasChanges = false;
        final newCache = <String, String>{};

        for (final item in content) {
          newCache[item.key] = item.value;
          if (_contentCache[item.key] != item.value) {
            hasChanges = true;
          }
        }

        // Only notify if content actually changed
        if (hasChanges || _contentCache.length != newCache.length) {
          _contentCache.clear();
          _contentCache.addAll(newCache);
          notifyListeners();
        }
      },
      onError: (e) {
        _error = e.toString();
        _isWatching = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _contentSubscription?.cancel();
    super.dispose();
  }

  /// Load local static overrides (device-only).
  Future<void> loadLocalOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localOverridesKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _localOverrides
          ..clear()
          ..addAll(decoded
              .map((key, value) => MapEntry(key, value?.toString() ?? '')));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading local overrides: $e');
    }
  }

  Future<void> _persistLocalOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(_localOverrides);
      await prefs.setString(_localOverridesKey, payload);
    } catch (e) {
      debugPrint('Error saving local overrides: $e');
    }
  }

  /// Save or update a local static override.
  Future<void> saveStaticOverride(String key, String value) async {
    _localOverrides[key] = value;
    await _persistLocalOverrides();
    notifyListeners();
  }

  /// Remove a local static override.
  Future<void> removeStaticOverride(String key) async {
    if (!_localOverrides.containsKey(key)) return;
    _localOverrides.remove(key);
    await _persistLocalOverrides();
    notifyListeners();
  }

  bool _ensureAdminEditing() {
    if (_canEdit()) return true;
    if (_isEditMode || _isStaticEditMode) {
      _isEditMode = false;
      _isStaticEditMode = false;
      notifyListeners();
    }
    return false;
  }

  bool _canEdit() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return UserService.isAdminEmail(user.email ?? '');
  }

  /// Update a specific content value
  Future<bool> updateContent(String id, AppContent content) async {
    try {
      final success = await AppContentService.updateContent(id, content);
      if (success) {
        _contentCache[content.key] = content.value;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Add new content
  Future<String?> addContent(AppContent content) async {
    try {
      final id = await AppContentService.addContent(content);
      if (id != null) {
        _contentCache[content.key] = content.value;
        notifyListeners();
      }
      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Delete content
  Future<bool> deleteContent(String id, String key) async {
    try {
      final success = await AppContentService.deleteContent(id);
      if (success) {
        _contentCache.remove(key);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
