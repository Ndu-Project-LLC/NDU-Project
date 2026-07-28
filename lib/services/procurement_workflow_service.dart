import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ndu_project/models/procurement/procurement_workflow_step.dart';

class ProcurementWorkflowSnapshot {
  const ProcurementWorkflowSnapshot({
    required this.globalSteps,
    required this.scopeOverrides,
  });

  final List<ProcurementWorkflowStep> globalSteps;
  final Map<String, List<ProcurementWorkflowStep>> scopeOverrides;
}

class ProcurementWorkflowService {
  ProcurementWorkflowService._();

  static const String workflowCollectionName = 'procurement_workflows';
  static const String workflowGlobalDocId = 'global';

  static CollectionReference<Map<String, dynamic>> _workflowCollection(
    String projectId,
  ) {
    return FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection(workflowCollectionName);
  }

  static List<ProcurementWorkflowStep> cloneSteps(
    List<ProcurementWorkflowStep> steps,
  ) {
    return steps.map((step) => step.copyWith()).toList(growable: true);
  }

  static List<ProcurementWorkflowStep> parseWorkflowSteps(dynamic raw) {
    if (raw is! List) return const <ProcurementWorkflowStep>[];
    final steps = <ProcurementWorkflowStep>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        steps.add(ProcurementWorkflowStep.fromMap(entry));
      } else if (entry is Map) {
        steps.add(
          ProcurementWorkflowStep.fromMap(Map<String, dynamic>.from(entry)),
        );
      }
    }
    return steps;
  }

  static String scopeDocId(String scopeId) => 'scope_${scopeId.trim()}';

  /// Retries a Firestore operation up to [maxAttempts] times with exponential
  /// back-off.  This guards against the transient "INTERNAL ASSERTION FAILED"
  /// errors that the Firestore JS SDK (12.x) occasionally throws when its
  /// internal Watch state becomes temporarily inconsistent.
  static Future<T> _withRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
    String label = 'operation',
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e) {
        final isAssertionError = e.toString().contains('INTERNAL ASSERTION') ||
            e.toString().contains('Unexpected state');
        if (!isAssertionError || attempt == maxAttempts) rethrow;
        // Exponential back-off: 500 ms, 1 s, 2 s …
        final delay = Duration(milliseconds: 500 * (1 << (attempt - 1)));
        await Future<void>.delayed(delay);
      }
    }
    // Unreachable, but required for type-safety.
    throw StateError('$label failed after $maxAttempts attempts');
  }

  static Future<ProcurementWorkflowSnapshot> load(String projectId) async {
    return _withRetry(
      () => _loadInternal(projectId),
      label: 'ProcurementWorkflowService.load',
    );
  }

  static Future<ProcurementWorkflowSnapshot> _loadInternal(
    String projectId,
  ) async {
    final snapshot = await _workflowCollection(projectId).get();
    final scopeOverrides = <String, List<ProcurementWorkflowStep>>{};
    var globalSteps = const <ProcurementWorkflowStep>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final scopeIdFromDoc = (data['scopeId'] ?? '').toString().trim();
      final normalizedScope = scopeIdFromDoc.isNotEmpty
          ? scopeIdFromDoc
          : (doc.id == workflowGlobalDocId
              ? 'all'
              : doc.id.replaceFirst('scope_', '').trim());
      final steps = parseWorkflowSteps(data['steps']);

      if (normalizedScope == 'all') {
        globalSteps = steps;
        continue;
      }

      if (normalizedScope.isNotEmpty) {
        scopeOverrides[normalizedScope] = steps;
      }
    }

    return ProcurementWorkflowSnapshot(
      globalSteps: cloneSteps(globalSteps),
      scopeOverrides: scopeOverrides.map(
        (key, value) => MapEntry(key, cloneSteps(value)),
      ),
    );
  }

  static Future<void> save({
    required String projectId,
    required List<ProcurementWorkflowStep> globalSteps,
    required Map<String, List<ProcurementWorkflowStep>> scopeOverrides,
  }) async {
    return _withRetry(
      () => _saveInternal(
        projectId: projectId,
        globalSteps: globalSteps,
        scopeOverrides: scopeOverrides,
      ),
      label: 'ProcurementWorkflowService.save',
    );
  }

  static Future<void> _saveInternal({
    required String projectId,
    required List<ProcurementWorkflowStep> globalSteps,
    required Map<String, List<ProcurementWorkflowStep>> scopeOverrides,
  }) async {
    final collection = _workflowCollection(projectId);
    final existingSnapshot = await collection.get();
    final existingDocIds = existingSnapshot.docs.map((doc) => doc.id).toSet();
    final batch = FirebaseFirestore.instance.batch();

    final desiredPayloads = <String, Map<String, dynamic>>{
      workflowGlobalDocId: {
        'scopeId': 'all',
        'steps': globalSteps.map((step) => step.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    };

    for (final entry in scopeOverrides.entries) {
      final scopeId = entry.key.trim();
      if (scopeId.isEmpty) continue;
      desiredPayloads[scopeDocId(scopeId)] = {
        'scopeId': scopeId,
        'steps': entry.value.map((step) => step.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
    }

    for (final entry in desiredPayloads.entries) {
      batch.set(
        collection.doc(entry.key),
        entry.value,
        SetOptions(merge: true),
      );
    }

    for (final docId in existingDocIds) {
      if (!desiredPayloads.containsKey(docId)) {
        batch.delete(collection.doc(docId));
      }
    }

    await batch.commit();
  }
}
