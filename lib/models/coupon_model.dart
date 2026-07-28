import 'package:cloud_firestore/cloud_firestore.dart';

/// Coupon model for discount management across payment platforms
class CouponModel {
  final String id;
  final String code;
  final String description;
  final double discountPercent; // 0-100
  final double? discountAmount; // Fixed amount discount (optional)
  final DateTime validFrom;
  final DateTime validUntil;
  final int? maxUses; // null = unlimited
  final int currentUses;
  final bool isActive;
  final List<String> applicableTiers; // 'project', 'program', 'portfolio', or empty for all
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  CouponModel({
    required this.id,
    required this.code,
    required this.description,
    required this.discountPercent,
    this.discountAmount,
    required this.validFrom,
    required this.validUntil,
    this.maxUses,
    this.currentUses = 0,
    this.isActive = true,
    this.applicableTiers = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  bool get isValid {
    final now = DateTime.now();
    return isActive &&
        now.isAfter(validFrom) &&
        now.isBefore(validUntil) &&
        (maxUses == null || currentUses < maxUses!);
  }

  int get remainingUses => maxUses == null ? -1 : maxUses! - currentUses;

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code.toUpperCase(),
    'description': description,
    'discountPercent': discountPercent,
    'discountAmount': discountAmount,
    'validFrom': Timestamp.fromDate(validFrom),
    'validUntil': Timestamp.fromDate(validUntil),
    'maxUses': maxUses,
    'currentUses': currentUses,
    'isActive': isActive,
    'applicableTiers': applicableTiers,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'createdBy': createdBy,
  };

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      description: json['description'] ?? '',
      discountPercent: (json['discountPercent'] ?? 0).toDouble(),
      discountAmount: json['discountAmount']?.toDouble(),
      validFrom: (json['validFrom'] as Timestamp?)?.toDate() ?? DateTime.now(),
      validUntil: (json['validUntil'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 30)),
      maxUses: json['maxUses'],
      currentUses: json['currentUses'] ?? 0,
      isActive: json['isActive'] ?? true,
      applicableTiers: List<String>.from(json['applicableTiers'] ?? []),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: json['createdBy'] ?? '',
    );
  }

  CouponModel copyWith({
    String? id,
    String? code,
    String? description,
    double? discountPercent,
    double? discountAmount,
    DateTime? validFrom,
    DateTime? validUntil,
    int? maxUses,
    int? currentUses,
    bool? isActive,
    List<String>? applicableTiers,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return CouponModel(
      id: id ?? this.id,
      code: code ?? this.code,
      description: description ?? this.description,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      maxUses: maxUses ?? this.maxUses,
      currentUses: currentUses ?? this.currentUses,
      isActive: isActive ?? this.isActive,
      applicableTiers: applicableTiers ?? this.applicableTiers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
