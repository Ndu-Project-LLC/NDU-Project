import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/models/epic_model.dart';
import 'package:ndu_project/models/feature_model.dart';

void main() {
  group('Feature Generation Tests', () {
    test('Feature model should initialize with default values', () {
      final feature = Feature(epicId: 'test-epic-id');
      
      expect(feature.epicId, equals('test-epic-id'));
      expect(feature.title, isEmpty);
      expect(feature.description, isEmpty);
      expect(feature.priority, equals('medium'));
      expect(feature.storyPointEstimate, equals(0));
    });

    test('Feature model should support priority levels', () {
      final criticalFeature = Feature(
        epicId: 'test-epic-id',
        priority: 'critical',
      );
      final highFeature = Feature(
        epicId: 'test-epic-id',
        priority: 'high',
      );
      final mediumFeature = Feature(
        epicId: 'test-epic-id',
        priority: 'medium',
      );
      final lowFeature = Feature(
        epicId: 'test-epic-id',
        priority: 'low',
      );

      expect(criticalFeature.priority, equals('critical'));
      expect(highFeature.priority, equals('high'));
      expect(mediumFeature.priority, equals('medium'));
      expect(lowFeature.priority, equals('low'));
    });

    test('Epic model should initialize with default values', () {
      final epic = Epic(title: 'Test Epic');
      
      expect(epic.title, equals('Test Epic'));
      expect(epic.description, isEmpty);
      expect(epic.theme, isEmpty);
      expect(epic.businessValue, isEmpty);
      expect(epic.totalStoryPoints, equals(0));
      expect(epic.status, equals('backlog'));
    });

    test('Feature generation should parse JSON correctly', () {
      // Simulate AI response parsing
      const jsonResponse = '[{"title":"User Authentication","description":"Implement secure user authentication system","priority":"high","storyPointEstimate":8},{"title":"Dashboard UI","description":"Create responsive dashboard interface","priority":"medium","storyPointEstimate":5}]';

      // This simulates the _parseFeatureGeneration method
      final data = _extractJsonArray(jsonResponse);
      expect(data, isNotNull);
      expect(data!.length, equals(2));

      final features = data.map<Feature>((json) {
        if (json is Map) {
          return Feature(
            title: (json['title'] ?? '').toString(),
            description: (json['description'] ?? '').toString(),
            priority: (json['priority'] ?? 'medium').toString(),
            storyPointEstimate:
                double.tryParse((json['storyPointEstimate'] ?? '0').toString()) ?? 0,
          );
        }
        return Feature(title: 'Generated Feature');
      }).toList();

      expect(features[0].title, equals('User Authentication'));
      expect(features[0].priority, equals('high'));
      expect(features[0].storyPointEstimate, equals(8.0));

      expect(features[1].title, equals('Dashboard UI'));
      expect(features[1].priority, equals('medium'));
      expect(features[1].storyPointEstimate, equals(5.0));
    });

    test('Feature generation should handle empty response', () {
      const emptyResponse = 'No features generated';
      final data = _extractJsonArray(emptyResponse);
      expect(data, isNull);
    });

    test('Feature generation should handle malformed JSON', () {
      const malformedJson = '[{"title": "Test", "priority":}]';
      final data = _extractJsonArray(malformedJson);
      expect(data, isNull);
    });

    test('Multiple features should be parseable from AI response', () {
      final List<Map<String, dynamic>> jsonList = [
        {
          'title': 'User Login',
          'description': 'Allow users to log in with email and password',
          'priority': 'high',
          'storyPointEstimate': 5,
        },
        {
          'title': 'User Registration',
          'description': 'Allow new users to create accounts',
          'priority': 'medium',
          'storyPointEstimate': 3,
        },
        {
          'title': 'Password Reset',
          'description': 'Allow users to reset forgotten passwords',
          'priority': 'low',
          'storyPointEstimate': 2,
        },
      ];

      final features = jsonList.map<Feature>((json) {
        return Feature(
          title: json['title']?.toString() ?? '',
          description: json['description']?.toString() ?? '',
          priority: json['priority']?.toString() ?? 'medium',
          storyPointEstimate: (json['storyPointEstimate'] as num?)?.toDouble() ?? 0,
        );
      }).toList();

      expect(features.length, equals(3));
      expect(features[0].title, equals('User Login'));
      expect(features[1].title, equals('User Registration'));
      expect(features[2].title, equals('Password Reset'));
    });
  });
}

List<dynamic>? _extractJsonArray(String text) {
  final start = text.indexOf('[');
  final end = text.lastIndexOf(']');
  if (start == -1 || end == -1) return null;
  try {
    final result = _parseJson(text.substring(start, end + 1));
    return result;
  } catch (e) {
    return null;
  }
}

List<dynamic>? _parseJson(String json) {
  try {
    final result = jsonDecode(json);
    if (result is List) return result;
    return null;
  } catch (e) {
    return null;
  }
}
