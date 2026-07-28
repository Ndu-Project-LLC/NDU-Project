import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ndu_project/services/project_service.dart';

/// Service to track and restore the last visited page for each project.
/// Firestore is the primary source of truth; SharedPreferences is used as fallback for backward compatibility.
class ProjectNavigationService {
  ProjectNavigationService._();
  static final ProjectNavigationService instance = ProjectNavigationService._();

  static const String _keyPrefix = 'project_last_page_';
  Future<SharedPreferences>? _prefsFuture;

  Future<SharedPreferences> _prefs() {
    _prefsFuture ??= SharedPreferences.getInstance();
    return _prefsFuture!;
  }

  /// Warm up shared preferences early to reduce navigation checkpoint latency.
  Future<void> warmUp() async {
    await _prefs();
  }

  /// Save the last visited route for a project locally only.
  /// This is intentionally fast and avoids any network calls.
  Future<void> saveLastPageLocal(String projectId, String routeName) async {
    try {
      final prefs = await _prefs();
      await prefs.setString('$_keyPrefix$projectId', routeName);
    } catch (e) {
      debugPrint('ProjectNavigationService: Error saving local last page: $e');
    }
  }

  /// Save the last visited route for a project
  /// Writes to both Firestore (primary) and SharedPreferences (for offline support)
  Future<void> saveLastPage(String projectId, String routeName) async {
    try {
      // Primary: Save to Firestore
      await ProjectService.updateCheckpoint(
        projectId: projectId,
        checkpointRoute: routeName,
      );
      
      // Secondary: Save to SharedPreferences for offline support
      try {
        final prefs = await _prefs();
        await prefs.setString('$_keyPrefix$projectId', routeName);
      } catch (e) {
        debugPrint('ProjectNavigationService: Error saving to SharedPreferences: $e');
      }
      
      if (kDebugMode) {
        debugPrint('ProjectNavigationService: Saved last page for $projectId -> $routeName');
      }
    } catch (e) {
      debugPrint('ProjectNavigationService: Error saving last page: $e');
      // Fallback to SharedPreferences only if Firestore fails
      try {
        final prefs = await _prefs();
        await prefs.setString('$_keyPrefix$projectId', routeName);
      } catch (e2) {
        debugPrint('ProjectNavigationService: Error saving to SharedPreferences fallback: $e2');
      }
    }
  }

  /// Get the last visited route for a project
  /// Reads from Firestore first (primary source), falls back to SharedPreferences for backward compatibility
  /// Returns 'initiation' as default if no previous route is saved
  Future<String> getLastPage(String projectId) async {
    try {
      // Primary: Read from Firestore
      final projectRecord = await ProjectService.getProjectById(projectId);
      if (projectRecord != null && projectRecord.checkpointRoute.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('ProjectNavigationService: Retrieved from Firestore for $projectId -> ${projectRecord.checkpointRoute}');
        }
        return projectRecord.checkpointRoute;
      }
      
      // Fallback: Read from SharedPreferences (for backward compatibility)
      final prefs = await _prefs();
      final lastPage = prefs.getString('$_keyPrefix$projectId');
      if (kDebugMode) {
        debugPrint('ProjectNavigationService: Retrieved from SharedPreferences for $projectId -> ${lastPage ?? 'initiation (default)'}');
      }
      return lastPage ?? 'initiation';
    } catch (e) {
      debugPrint('ProjectNavigationService: Error getting last page: $e');
      // Final fallback to SharedPreferences
      try {
        final prefs = await _prefs();
        final lastPage = prefs.getString('$_keyPrefix$projectId');
        return lastPage ?? 'initiation';
      } catch (e2) {
        debugPrint('ProjectNavigationService: Error getting from SharedPreferences fallback: $e2');
        return 'initiation';
      }
    }
  }

  /// Clear the saved page for a project (useful when deleting a project)
  Future<void> clearLastPage(String projectId) async {
    try {
      final prefs = await _prefs();
      await prefs.remove('$_keyPrefix$projectId');
      if (kDebugMode) {
        debugPrint('ProjectNavigationService: Cleared last page for $projectId');
      }
    } catch (e) {
      debugPrint('ProjectNavigationService: Error clearing last page: $e');
    }
  }
}
