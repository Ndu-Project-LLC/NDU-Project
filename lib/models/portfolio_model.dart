import 'package:cloud_firestore/cloud_firestore.dart';

class PortfolioModel {
  final String id;
  final String name;
  final List<String> projectIds;
  final String ownerId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Portfolio manager's user ID (Firebase Auth uid). Empty string means
  /// no manager assigned. Displayed in the portfolio card alongside the
  /// project count so the user can see who's accountable.
  /// Populated from the registered users collection — see
  /// [PortfolioService.createPortfolio] and the create-portfolio modal.
  final String managerId;

  /// Portfolio manager's display name — denormalized at write time so
  /// the dashboard doesn't have to join against the users collection for
  /// every portfolio card. Stays in sync via [PortfolioService.assignManager].
  final String managerName;

  /// Portfolio manager's email — denormalized alongside [managerName] so
  /// the UI can show a "mailto:" link or contact chip without a join.
  final String managerEmail;

  const PortfolioModel({
    required this.id,
    required this.name,
    required this.projectIds,
    required this.ownerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.managerId = '',
    this.managerName = '',
    this.managerEmail = '',
  });

  factory PortfolioModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return PortfolioModel(
        id: doc.id,
        name: '',
        projectIds: const [],
        ownerId: '',
        status: 'Active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return PortfolioModel(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      projectIds: List<String>.from(data['projectIds'] ?? []),
      ownerId: data['ownerId']?.toString() ?? '',
      status: data['status']?.toString() ?? 'Active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      managerId: data['managerId']?.toString() ?? '',
      managerName: data['managerName']?.toString() ?? '',
      managerEmail: data['managerEmail']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'projectIds': projectIds,
        'ownerId': ownerId,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        if (managerId.isNotEmpty) 'managerId': managerId,
        if (managerName.isNotEmpty) 'managerName': managerName,
        if (managerEmail.isNotEmpty) 'managerEmail': managerEmail,
      };

  PortfolioModel copyWith({
    String? id,
    String? name,
    List<String>? projectIds,
    String? ownerId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? managerId,
    String? managerName,
    String? managerEmail,
  }) =>
      PortfolioModel(
        id: id ?? this.id,
        name: name ?? this.name,
        projectIds: projectIds ?? this.projectIds,
        ownerId: ownerId ?? this.ownerId,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        managerId: managerId ?? this.managerId,
        managerName: managerName ?? this.managerName,
        managerEmail: managerEmail ?? this.managerEmail,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PortfolioModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
