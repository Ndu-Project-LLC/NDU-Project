import 'package:cloud_firestore/cloud_firestore.dart';

class ProgramModel {
  final String id;
  final String name;
  final List<String> projectIds;
  final String ownerId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProgramModel({
    required this.id,
    required this.name,
    required this.projectIds,
    required this.ownerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProgramModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      // Handle null data gracefully - return empty program
      return ProgramModel(
        id: doc.id,
        name: '',
        projectIds: const [],
        ownerId: '',
        status: 'Active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    
    return ProgramModel(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      projectIds: List<String>.from(data['projectIds'] ?? []),
      ownerId: data['ownerId']?.toString() ?? '',
      status: data['status']?.toString() ?? 'Active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'projectIds': projectIds,
        'ownerId': ownerId,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  ProgramModel copyWith({
    String? id,
    String? name,
    List<String>? projectIds,
    String? ownerId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ProgramModel(
        id: id ?? this.id,
        name: name ?? this.name,
        projectIds: projectIds ?? this.projectIds,
        ownerId: ownerId ?? this.ownerId,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
