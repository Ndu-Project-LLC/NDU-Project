import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin-managed hint configuration for a single screen/page.
class PageHintConfig {
  const PageHintConfig({
    required this.id,
    required this.pageId,
    required this.pageLabel,
    required this.title,
    required this.message,
    required this.category,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.description,
  });

  final String id;
  final String pageId;
  final String pageLabel;
  final String title;
  final String message;
  final String category;
  final String? description;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PageHintConfig.fromJson(Map<String, dynamic> json, String id) {
    final pageId = _readString(json['pageId'], fallback: id);
    return PageHintConfig(
      id: id,
      pageId: pageId,
      pageLabel: _readString(
        json['pageLabel'],
        fallback: _humanize(pageId),
      ),
      title: _readString(json['title']),
      message: _readString(json['message']),
      category: _readString(json['category'], fallback: 'General'),
      description: _readNullableString(json['description']),
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'pageId': pageId,
        'pageLabel': pageLabel,
        'title': title,
        'message': message,
        'category': category,
        'description': description,
        'enabled': enabled,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  PageHintConfig copyWith({
    String? id,
    String? pageId,
    String? pageLabel,
    String? title,
    String? message,
    String? category,
    String? description,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PageHintConfig(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      pageLabel: pageLabel ?? this.pageLabel,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _readNullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static String _humanize(String value) {
    final cleaned = value.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    if (cleaned.isEmpty) return 'Untitled Hint';
    return cleaned
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }
}
