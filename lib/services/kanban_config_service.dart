import 'package:flutter/foundation.dart';
import 'package:ndu_project/services/agile_wireframe_service.dart';

class KanbanConfigService {
  KanbanConfigService._();

  static const List<String> simpleTemplate = [
    'To Do',
    'In Progress',
    'Done',
  ];

  static const List<String> softwareTemplate = [
    'Backlog',
    'Ready',
    'In Progress',
    'Code Review',
    'Testing',
    'Ready for Release',
    'Done',
  ];

  static String normalizeStatus(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('-', ' ');
    switch (normalized) {
      case 'todo':
      case 'to do':
      case 'to-do':
      case 'backlog':
      case 'ready':
        return 'To Do';
      case 'in progress':
      case 'inprogress':
      case 'in-progress':
        return 'In Progress';
      case 'code review':
        return 'Code Review';
      case 'testing':
      case 'qa':
        return 'Testing';
      case 'ready for release':
      case 'release ready':
        return 'Ready for Release';
      case 'done':
      case 'complete':
      case 'completed':
        return 'Done';
      default:
        return value.trim().isEmpty ? 'To Do' : value.trim();
    }
  }

  static Future<List<String>> loadWorkflowColumns(String projectId) async {
    try {
      final data = await AgileWireframeService.loadKanbanConfig(projectId);
      final raw = data['columns'];
      if (raw is List && raw.isNotEmpty) {
        final names = raw
            .whereType<Map>()
            .map((item) => item['name']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .map(normalizeStatus)
            .toList();
        if (names.isNotEmpty) return names;
      }
    } catch (error) {
      debugPrint('KanbanConfigService.loadWorkflowColumns error: $error');
    }
    return List<String>.from(simpleTemplate);
  }

  static List<String> alignStatusesToWorkflow(
    List<String> configuredColumns,
  ) {
    final normalized = configuredColumns
        .map(normalizeStatus)
        .where((value) => value.isNotEmpty)
        .toList();
    if (normalized.isEmpty) return List<String>.from(simpleTemplate);
    return normalized.toSet().toList();
  }

  static String coerceTaskStatus(
    String status,
    List<String> configuredColumns,
  ) {
    final normalizedConfigured = alignStatusesToWorkflow(configuredColumns);
    final normalizedStatus = normalizeStatus(status);
    if (normalizedConfigured.contains(normalizedStatus)) {
      return normalizedStatus;
    }
    return normalizedConfigured.first;
  }
}
