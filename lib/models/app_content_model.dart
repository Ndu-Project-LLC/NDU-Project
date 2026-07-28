import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for managing editable application content
class AppContent {
  final String id;
  final String key;
  final String value;
  final String category;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppContent({
    required this.id,
    required this.key,
    required this.value,
    required this.category,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppContent.fromJson(Map<String, dynamic> json, String id) {
    return AppContent(
      id: id,
      key: json['key'] ?? '',
      value: json['value'] ?? '',
      category: json['category'] ?? 'general',
      description: json['description'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'category': category,
        'description': description,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  AppContent copyWith({
    String? id,
    String? key,
    String? value,
    String? category,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      AppContent(
        id: id ?? this.id,
        key: key ?? this.key,
        value: value ?? this.value,
        category: category ?? this.category,
        description: description ?? this.description,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
