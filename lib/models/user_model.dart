import 'package:cloud_firestore/cloud_firestore.dart';

/// User model with admin role support
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String? photoUrl;
  final bool isActive;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.isAdmin = false,
    required this.createdAt,
    this.lastLoginAt,
    this.photoUrl,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'isAdmin': isAdmin,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
        'photoUrl': photoUrl,
        'isActive': isActive,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      isAdmin: json['isAdmin'] ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (json['lastLoginAt'] as Timestamp?)?.toDate(),
      photoUrl: json['photoUrl'],
      isActive: json['isActive'] ?? true,
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? photoUrl,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      photoUrl: photoUrl ?? this.photoUrl,
      isActive: isActive ?? this.isActive,
    );
  }
}
