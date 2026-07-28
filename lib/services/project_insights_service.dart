import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProjectInsightsService {
  static CollectionReference<Map<String, dynamic>> get _projects =>
      FirebaseFirestore.instance.collection('projects');

  static Stream<StakeholderAlignmentOverview> streamStakeholderOverview(String projectId) {
    final doc = _projects
        .doc(projectId)
        .collection('stakeholderAlignment')
        .doc('overview');
    return doc.snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      return StakeholderAlignmentOverview(
        alignmentScore: data['alignmentScore']?.toString() ?? '',
        alignmentStatus: data['alignmentStatus']?.toString() ?? '',
        openDecisions: data['openDecisions']?.toString() ?? '',
        urgentNotes: data['urgentNotes']?.toString() ?? '',
        engagementCadence: data['engagementCadence']?.toString() ?? '',
        nextSync: data['nextSync']?.toString() ?? '',
        pulses: _parsePulses(data['pulses']),
        signals: _parseSignals(data['signals']),
      );
    });
  }

  static Stream<List<StakeholderMember>> streamStakeholders(String projectId) {
    final collection = _projects
        .doc(projectId)
        .collection('stakeholderAlignment')
        .doc('overview')
        .collection('stakeholders');
    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => StakeholderMember.fromJson(doc.data())).toList();
    });
  }

  static Stream<List<ScopeTrackingStat>> streamScopeStats(String projectId) {
    final doc = _projects.doc(projectId).collection('scopeTracking').doc('overview');
    return doc.snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      return _parseStats(data['stats']);
    });
  }

  static Stream<List<ScopeTrackingItem>> streamScopeItems(String projectId) {
    final collection = _projects.doc(projectId).collection('scopeTracking').doc('overview').collection('items');
    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ScopeTrackingItem.fromJson(doc.data())).toList();
    });
  }

  static Stream<List<OpsPlanStat>> streamOpsPlanStats(String projectId) {
    final doc = _projects.doc(projectId).collection('opsMaintenance').doc('overview');
    return doc.snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      return _parseOpsStats(data['stats']);
    });
  }

  static Stream<List<OpsPlanItem>> streamOpsPlans(String projectId) {
    final collection = _projects.doc(projectId).collection('opsMaintenance').doc('overview').collection('plans');
    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => OpsPlanItem.fromJson(doc.data())).toList();
    });
  }

  static Color _fromHex(String? value, {Color fallback = const Color(0xFF0EA5E9)}) {
    if (value == null || value.trim().isEmpty) return fallback;
    final hex = value.replaceFirst('#', '').padLeft(6, '0');
    final intColor = int.tryParse(hex, radix: 16);
    if (intColor == null) return fallback;
    return Color(intColor + 0xFF000000);
  }

  static List<StakeholderPulse> _parsePulses(dynamic raw) {
    if (raw is! Iterable) return const [];
    return raw.map((entry) => StakeholderPulse.fromJson(entry)).toList();
  }

  static List<StakeholderSignal> _parseSignals(dynamic raw) {
    if (raw is! Iterable) return const [];
    return raw.map((entry) => StakeholderSignal.fromJson(entry)).toList();
  }

  static List<ScopeTrackingStat> _parseStats(dynamic raw) {
    if (raw is! Iterable) return const [];
    return raw.map((entry) => ScopeTrackingStat.fromJson(entry)).toList();
  }

  static List<OpsPlanStat> _parseOpsStats(dynamic raw) {
    if (raw is! Iterable) return const [];
    return raw.map((entry) => OpsPlanStat.fromJson(entry)).toList();
  }
}

class StakeholderAlignmentOverview {
  StakeholderAlignmentOverview({
    required this.alignmentScore,
    required this.alignmentStatus,
    required this.openDecisions,
    required this.urgentNotes,
    required this.engagementCadence,
    required this.nextSync,
    required this.pulses,
    required this.signals,
  });

  final String alignmentScore;
  final String alignmentStatus;
  final String openDecisions;
  final String urgentNotes;
  final String engagementCadence;
  final String nextSync;
  final List<StakeholderPulse> pulses;
  final List<StakeholderSignal> signals;
}

class StakeholderPulse {
  const StakeholderPulse({
    required this.label,
    required this.value,
    required this.supporting,
    required this.color,
  });

  factory StakeholderPulse.fromJson(dynamic raw) {
    final map = raw is Map<String, dynamic> ? raw : const {};
    return StakeholderPulse(
      label: map['label']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      supporting: map['supporting']?.toString() ?? '',
      color: ProjectInsightsService._fromHex(map['color']),
    );
  }

  final String label;
  final String value;
  final String supporting;
  final Color color;
}

class StakeholderSignal {
  const StakeholderSignal({required this.title, required this.detail});

  factory StakeholderSignal.fromJson(dynamic raw) {
    final map = raw is Map<String, dynamic> ? raw : const {};
    return StakeholderSignal(
      title: map['title']?.toString() ?? '',
      detail: map['detail']?.toString() ?? '',
    );
  }

  final String title;
  final String detail;
}

class StakeholderMember {
  const StakeholderMember({
    required this.name,
    required this.role,
    required this.influence,
    required this.sentiment,
    required this.lastTouch,
    required this.nextSync,
  });

  factory StakeholderMember.fromJson(Map<String, dynamic> json) {
    return StakeholderMember(
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      influence: json['influence']?.toString() ?? '',
      sentiment: json['sentiment']?.toString() ?? '',
      lastTouch: json['lastTouch']?.toString() ?? '',
      nextSync: json['nextSync']?.toString() ?? '',
    );
  }

  final String name;
  final String role;
  final String influence;
  final String sentiment;
  final String lastTouch;
  final String nextSync;
}

class ScopeTrackingStat {
  const ScopeTrackingStat({
    required this.label,
    required this.value,
    required this.supporting,
    required this.color,
  });

  factory ScopeTrackingStat.fromJson(dynamic raw) {
    final map = raw is Map<String, dynamic> ? raw : const {};
    return ScopeTrackingStat(
      label: map['label']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      supporting: map['supporting']?.toString() ?? '',
      color: ProjectInsightsService._fromHex(map['color']),
    );
  }

  final String label;
  final String value;
  final String supporting;
  final Color color;
}

class ScopeTrackingItem {
  ScopeTrackingItem({
    required this.id,
    required this.title,
    required this.status,
    required this.variance,
    required this.owner,
    required this.nextReview,
  });

  factory ScopeTrackingItem.fromJson(Map<String, dynamic> json) {
    return ScopeTrackingItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      variance: json['variance']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      nextReview: json['nextReview']?.toString() ?? '',
    );
  }

  final String id;
  final String title;
  final String status;
  final String variance;
  final String owner;
  final String nextReview;
}

class OpsPlanStat {
  const OpsPlanStat({
    required this.label,
    required this.value,
    required this.supporting,
    required this.color,
  });

  factory OpsPlanStat.fromJson(dynamic raw) {
    final map = raw is Map<String, dynamic> ? raw : const {};
    return OpsPlanStat(
      label: map['label']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      supporting: map['supporting']?.toString() ?? '',
      color: ProjectInsightsService._fromHex(map['color']),
    );
  }

  final String label;
  final String value;
  final String supporting;
  final Color color;
}

class OpsPlanItem {
  OpsPlanItem({
    required this.id,
    required this.title,
    required this.team,
    required this.status,
    required this.due,
    required this.owner,
  });

  factory OpsPlanItem.fromJson(Map<String, dynamic> json) {
    return OpsPlanItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      team: json['team']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      due: json['due']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
    );
  }

  final String id;
  final String title;
  final String team;
  final String status;
  final String due;
  final String owner;
}
