import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/models/app_content_model.dart';

/// Service to manage editable application content in Firestore
class AppContentService {
  static final _firestore = FirebaseFirestore.instance;
  static const _collectionName = 'app_content';

  /// Get all content items
  static Future<List<AppContent>> getAllContent() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).orderBy('category').orderBy('key').get();
      return snapshot.docs.map((doc) => AppContent.fromJson(doc.data(), doc.id)).toList();
    } catch (e) {
      debugPrint('Error fetching content: $e');
      return [];
    }
  }

  /// Get content by category
  static Future<List<AppContent>> getContentByCategory(String category) async {
    try {
      final snapshot = await _firestore.collection(_collectionName).where('category', isEqualTo: category).orderBy('key').get();
      return snapshot.docs.map((doc) => AppContent.fromJson(doc.data(), doc.id)).toList();
    } catch (e) {
      debugPrint('Error fetching content by category: $e');
      return [];
    }
  }

  /// Get content by key
  static Future<String?> getContentByKey(String key) async {
    try {
      final snapshot = await _firestore.collection(_collectionName).where('key', isEqualTo: key).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data()['value'];
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching content by key: $e');
      return null;
    }
  }

  /// Stream all content for real-time updates
  static Stream<List<AppContent>> watchContent() {
    return _firestore.collection(_collectionName).orderBy('category').orderBy('key').snapshots(includeMetadataChanges: false).map(
          (snapshot) => snapshot.docs.map((doc) => AppContent.fromJson(doc.data(), doc.id)).toList(),
        );
  }

  /// Stream content by category
  static Stream<List<AppContent>> watchContentByCategory(String category) {
    return _firestore.collection(_collectionName).where('category', isEqualTo: category).orderBy('key').snapshots(includeMetadataChanges: false).map(
          (snapshot) => snapshot.docs.map((doc) => AppContent.fromJson(doc.data(), doc.id)).toList(),
        );
  }

  /// Add new content item
  static Future<String?> addContent(AppContent content) async {
    try {
      final doc = await _firestore.collection(_collectionName).add(content.toJson());
      return doc.id;
    } catch (e) {
      debugPrint('Error adding content: $e');
      return null;
    }
  }

  /// Update existing content item
  static Future<bool> updateContent(String id, AppContent content) async {
    try {
      await _firestore.collection(_collectionName).doc(id).update(content.toJson());
      return true;
    } catch (e) {
      debugPrint('Error updating content: $e');
      return false;
    }
  }

  /// Delete content item
  static Future<bool> deleteContent(String id) async {
    try {
      await _firestore.collection(_collectionName).doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting content: $e');
      return false;
    }
  }

  /// Initialize default content (call once on first setup)
  static Future<void> initializeDefaultContent() async {
    try {
      final existing = await getAllContent();
      if (existing.isNotEmpty) return;

      final defaultContent = [
        AppContent(
          id: '',
          key: 'app_name',
          value: 'Ndu Project',
          category: 'general',
          description: 'Main application name',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        AppContent(
          id: '',
          key: 'welcome_message',
          value: 'Welcome to your project management workspace',
          category: 'general',
          description: 'Welcome message shown on home screen',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        AppContent(
          id: '',
          key: 'initiation_phase_title',
          value: 'Initiation Phase',
          category: 'phase_titles',
          description: 'Title for Initiation Phase',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        AppContent(
          id: '',
          key: 'planning_phase_title',
          value: 'Planning Phase',
          category: 'phase_titles',
          description: 'Title for Planning Phase',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        AppContent(
          id: '',
          key: 'design_phase_title',
          value: 'Design Phase',
          category: 'phase_titles',
          description: 'Title for Design Phase',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        AppContent(
          id: '',
          key: 'execution_phase_title',
          value: 'Execution Phase',
          category: 'phase_titles',
          description: 'Title for Execution Phase',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        AppContent(
          id: '',
          key: 'launch_phase_title',
          value: 'Launch Phase',
          category: 'phase_titles',
          description: 'Title for Launch Phase',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      for (final content in defaultContent) {
        await addContent(content);
      }
      debugPrint('Default content initialized successfully');
    } catch (e) {
      debugPrint('Error initializing default content: $e');
    }
  }
}
