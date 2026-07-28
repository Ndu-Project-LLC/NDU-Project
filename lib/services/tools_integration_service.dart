import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/services/integration_oauth_service.dart';

/// Model for tool integration configuration
class ToolIntegrationModel {
  final String id;
  final String projectId;
  final IntegrationProvider provider;
  final String name;
  final String subtitle;
  final String scopes;
  final String features;
  final String status; // 'Connected', 'Degraded - retrying', etc.
  final String? mapsTo;
  final String? autoHandoff;
  final String? autoSummary;
  final String? autoTranscribe;
  final String? syncMode; // 'scheduled', 'manual', etc.
  final String? lastSync;
  final String? errorInfo;
  final String? events;
  final String? sessions;
  final String createdById;
  final String createdByEmail;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ToolIntegrationModel({
    required this.id,
    required this.projectId,
    required this.provider,
    required this.name,
    required this.subtitle,
    required this.scopes,
    required this.features,
    required this.status,
    this.mapsTo,
    this.autoHandoff,
    this.autoSummary,
    this.autoTranscribe,
    this.syncMode,
    this.lastSync,
    this.errorInfo,
    this.events,
    this.sessions,
    required this.createdById,
    required this.createdByEmail,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'provider': provider.name,
        'name': name,
        'subtitle': subtitle,
        'scopes': scopes,
        'features': features,
        'status': status,
        'mapsTo': mapsTo ?? '',
        'autoHandoff': autoHandoff ?? '',
        'autoSummary': autoSummary ?? '',
        'autoTranscribe': autoTranscribe ?? '',
        'syncMode': syncMode ?? '',
        'lastSync': lastSync ?? '',
        'errorInfo': errorInfo ?? '',
        'events': events ?? '',
        'sessions': sessions ?? '',
        'createdById': createdById,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static ToolIntegrationModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    IntegrationProvider parseProvider(String name) {
      switch (name.toLowerCase()) {
        case 'figma':
          return IntegrationProvider.figma;
        case 'miro':
          return IntegrationProvider.miro;
        case 'drawio':
          return IntegrationProvider.drawio;
        case 'whiteboard':
          return IntegrationProvider.whiteboard;
        default:
          return IntegrationProvider.figma;
      }
    }

    return ToolIntegrationModel(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      provider: parseProvider((data['provider'] ?? 'figma').toString()),
      name: (data['name'] ?? '').toString(),
      subtitle: (data['subtitle'] ?? '').toString(),
      scopes: (data['scopes'] ?? '').toString(),
      features: (data['features'] ?? '').toString(),
      status: (data['status'] ?? 'Connected').toString(),
      mapsTo: data['mapsTo']?.toString(),
      autoHandoff: data['autoHandoff']?.toString(),
      autoSummary: data['autoSummary']?.toString(),
      autoTranscribe: data['autoTranscribe']?.toString(),
      syncMode: data['syncMode']?.toString(),
      lastSync: data['lastSync']?.toString(),
      errorInfo: data['errorInfo']?.toString(),
      events: data['events']?.toString(),
      sessions: data['sessions']?.toString(),
      createdById: (data['createdById'] ?? '').toString(),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }
}

class ToolsIntegrationService {
  static CollectionReference<Map<String, dynamic>> _integrationsCol(String projectId) =>
      FirebaseFirestore.instance.collection('projects').doc(projectId).collection('tool_integrations');

  static Future<String> createIntegration({
    required String projectId,
    required IntegrationProvider provider,
    required String name,
    required String subtitle,
    required String scopes,
    required String features,
    required String status,
    String? mapsTo,
    String? autoHandoff,
    String? autoSummary,
    String? autoTranscribe,
    String? syncMode,
    String? lastSync,
    String? errorInfo,
    String? events,
    String? sessions,
    String? createdById,
    String? createdByEmail,
    String? createdByName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';
    final userEmail = createdByEmail ?? user?.email ?? '';
    final userName = createdByName ?? user?.displayName ?? userEmail.split('@').first;

    final payload = ToolIntegrationModel(
      id: '',
      projectId: projectId,
      provider: provider,
      name: name,
      subtitle: subtitle,
      scopes: scopes,
      features: features,
      status: status,
      mapsTo: mapsTo,
      autoHandoff: autoHandoff,
      autoSummary: autoSummary,
      autoTranscribe: autoTranscribe,
      syncMode: syncMode,
      lastSync: lastSync,
      errorInfo: errorInfo,
      events: events,
      sessions: sessions,
      createdById: userId,
      createdByEmail: userEmail,
      createdByName: userName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _integrationsCol(projectId).add(payload);
    return ref.id;
  }

  static Future<void> updateIntegration({
    required String projectId,
    required String integrationId,
    String? name,
    String? subtitle,
    String? scopes,
    String? features,
    String? status,
    String? mapsTo,
    String? autoHandoff,
    String? autoSummary,
    String? autoTranscribe,
    String? syncMode,
    String? lastSync,
    String? errorInfo,
    String? events,
    String? sessions,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updateData['name'] = name;
    if (subtitle != null) updateData['subtitle'] = subtitle;
    if (scopes != null) updateData['scopes'] = scopes;
    if (features != null) updateData['features'] = features;
    if (status != null) updateData['status'] = status;
    if (mapsTo != null) updateData['mapsTo'] = mapsTo;
    if (autoHandoff != null) updateData['autoHandoff'] = autoHandoff;
    if (autoSummary != null) updateData['autoSummary'] = autoSummary;
    if (autoTranscribe != null) updateData['autoTranscribe'] = autoTranscribe;
    if (syncMode != null) updateData['syncMode'] = syncMode;
    if (lastSync != null) updateData['lastSync'] = lastSync;
    if (errorInfo != null) updateData['errorInfo'] = errorInfo;
    if (events != null) updateData['events'] = events;
    if (sessions != null) updateData['sessions'] = sessions;

    await _integrationsCol(projectId).doc(integrationId).update(updateData);
  }

  static Future<void> deleteIntegration({
    required String projectId,
    required String integrationId,
  }) async {
    await _integrationsCol(projectId).doc(integrationId).delete();
  }

  static Stream<List<ToolIntegrationModel>> streamIntegrations(String projectId, {int limit = 50}) {
    return _integrationsCol(projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ToolIntegrationModel.fromDoc).toList());
  }
}
