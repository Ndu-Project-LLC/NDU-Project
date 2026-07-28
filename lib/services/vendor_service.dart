import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class VendorModel {
  final String id;
  final String projectId;
  final String name;
  final String category;
  final String criticality; // High, Medium, Low
  final String sla; // Service Level Agreement percentage
  final double slaPerformance; // 0.0 to 1.0 for progress bar/star rating
  final String leadTime; // e.g., "14 Days", "Immediate"
  final String requiredDeliverables; // SLA Terms with "." bullet format
  final String rating; // A, B, C, etc.
  final String status; // Active, Watch, At risk, Onboard
  final String nextReview; // Date string
  final String? contractId; // Link to contract
  final double onTimeDelivery; // 0.0 to 1.0
  final double incidentResponse; // 0.0 to 1.0
  final double qualityScore; // 0.0 to 1.0
  final double costAdherence; // 0.0 to 1.0
  final String? notes; // Prose, no bullets
  final String createdById;
  final String createdByEmail;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VendorModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.category,
    this.criticality = 'Medium',
    required this.sla,
    this.slaPerformance = 0.0,
    this.leadTime = '',
    this.requiredDeliverables = '',
    required this.rating,
    required this.status,
    required this.nextReview,
    this.contractId,
    required this.onTimeDelivery,
    required this.incidentResponse,
    required this.qualityScore,
    required this.costAdherence,
    this.notes,
    required this.createdById,
    required this.createdByEmail,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'name': name,
        'category': category,
        'criticality': criticality,
        'sla': sla,
        'slaPerformance': slaPerformance,
        'leadTime': leadTime,
        'requiredDeliverables': requiredDeliverables,
        'rating': rating,
        'status': status,
        'nextReview': nextReview,
        'contractId': contractId ?? '',
        'onTimeDelivery': onTimeDelivery,
        'incidentResponse': incidentResponse,
        'qualityScore': qualityScore,
        'costAdherence': costAdherence,
        'notes': notes ?? '',
        'createdById': createdById,
        'createdByEmail': createdByEmail,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static VendorModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    return VendorModel(
      id: doc.id,
      projectId: (data['projectId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      criticality: (data['criticality'] ?? 'Medium').toString(),
      sla: (data['sla'] ?? '0%').toString(),
      slaPerformance: parseDouble(data['slaPerformance']),
      leadTime: (data['leadTime'] ?? '').toString(),
      requiredDeliverables: (data['requiredDeliverables'] ?? '').toString(),
      rating: (data['rating'] ?? 'C').toString(),
      status: (data['status'] ?? 'Active').toString(),
      nextReview: (data['nextReview'] ?? '').toString(),
      contractId: data['contractId']?.toString(),
      onTimeDelivery: parseDouble(data['onTimeDelivery']),
      incidentResponse: parseDouble(data['incidentResponse']),
      qualityScore: parseDouble(data['qualityScore']),
      costAdherence: parseDouble(data['costAdherence']),
      notes: data['notes']?.toString(),
      createdById: (data['createdById'] ?? '').toString(),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }
}

class VendorService {
  static CollectionReference<Map<String, dynamic>> _vendorsCol(
          String projectId) =>
      FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('vendors');

  /// Create a new vendor
  static Future<String> createVendor({
    required String projectId,
    required String name,
    required String category,
    String criticality = 'Medium',
    required String sla,
    double slaPerformance = 0.0,
    String leadTime = '',
    String requiredDeliverables = '',
    required String rating,
    required String status,
    required String nextReview,
    String? contractId,
    required double onTimeDelivery,
    required double incidentResponse,
    required double qualityScore,
    required double costAdherence,
    String? notes,
    String? createdById,
    String? createdByEmail,
    String? createdByName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = createdById ?? user?.uid ?? '';
    final userEmail = createdByEmail ?? user?.email ?? '';
    final userName =
        createdByName ?? user?.displayName ?? userEmail.split('@').first;

    final payload = VendorModel(
      id: '',
      projectId: projectId,
      name: name,
      category: category,
      criticality: criticality,
      sla: sla,
      slaPerformance: slaPerformance,
      leadTime: leadTime,
      requiredDeliverables: requiredDeliverables,
      rating: rating,
      status: status,
      nextReview: nextReview,
      contractId: contractId,
      onTimeDelivery: onTimeDelivery,
      incidentResponse: incidentResponse,
      qualityScore: qualityScore,
      costAdherence: costAdherence,
      notes: notes,
      createdById: userId,
      createdByEmail: userEmail,
      createdByName: userName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap();

    final ref = await _vendorsCol(projectId).add(payload);
    return ref.id;
  }

  /// Update an existing vendor
  static Future<void> updateVendor({
    required String projectId,
    required String vendorId,
    String? name,
    String? category,
    String? criticality,
    String? sla,
    double? slaPerformance,
    String? leadTime,
    String? requiredDeliverables,
    String? rating,
    String? status,
    String? nextReview,
    String? contractId,
    double? onTimeDelivery,
    double? incidentResponse,
    double? qualityScore,
    double? costAdherence,
    String? notes,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updateData['name'] = name;
    if (category != null) updateData['category'] = category;
    if (criticality != null) updateData['criticality'] = criticality;
    if (sla != null) updateData['sla'] = sla;
    if (slaPerformance != null) updateData['slaPerformance'] = slaPerformance;
    if (leadTime != null) updateData['leadTime'] = leadTime;
    if (requiredDeliverables != null) {
      updateData['requiredDeliverables'] = requiredDeliverables;
    }
    if (rating != null) updateData['rating'] = rating;
    if (status != null) updateData['status'] = status;
    if (nextReview != null) updateData['nextReview'] = nextReview;
    if (contractId != null) updateData['contractId'] = contractId;
    if (onTimeDelivery != null) updateData['onTimeDelivery'] = onTimeDelivery;
    if (incidentResponse != null) {
      updateData['incidentResponse'] = incidentResponse;
    }
    if (qualityScore != null) updateData['qualityScore'] = qualityScore;
    if (costAdherence != null) updateData['costAdherence'] = costAdherence;
    if (notes != null) updateData['notes'] = notes;

    await _vendorsCol(projectId).doc(vendorId).update(updateData);
  }

  /// Delete a vendor
  static Future<void> deleteVendor({
    required String projectId,
    required String vendorId,
  }) async {
    await _vendorsCol(projectId).doc(vendorId).delete();
  }

  /// Stream all vendors for a project
  static Stream<List<VendorModel>> streamVendors(String projectId,
      {int limit = 50}) {
    return _vendorsCol(projectId).limit(limit).snapshots().map((snap) {
      final vendors = <VendorModel>[];
      for (final doc in snap.docs) {
        try {
          vendors.add(VendorModel.fromDoc(doc));
        } catch (e) {
          debugPrint('Skipping malformed vendor ${doc.id}: $e');
        }
      }
      vendors.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return vendors;
    });
  }

  static Future<bool> hasAnyVendors(String projectId) async {
    final snap = await _vendorsCol(projectId).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  /// Get a single vendor
  static Future<VendorModel?> getVendor({
    required String projectId,
    required String vendorId,
  }) async {
    final doc = await _vendorsCol(projectId).doc(vendorId).get();
    if (!doc.exists) return null;
    return VendorModel.fromDoc(doc);
  }
}
