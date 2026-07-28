/// Personnel rate card model for tiered rates (Global, Regional, National, Local).
///
/// Rate cards are embedded in [ProjectDataModel] and provide the reference
/// rates that staffing forms can link to for automatic cost calculation.
class RateCard {
  final String id;
  String name;
  String tier; // 'Global' | 'Regional' | 'National' | 'Local'
  String effectiveDate;
  String expiryDate;
  List<RateTier> rates;
  String createdBy;
  String accessLevel; // 'Owner' | 'Admin' | 'Editor' — who can see/edit
  String notes;
  DateTime createdAt;
  DateTime updatedAt;

  RateCard({
    String? id,
    this.name = '',
    this.tier = 'National',
    this.effectiveDate = '',
    this.expiryDate = '',
    List<RateTier>? rates,
    this.createdBy = '',
    this.accessLevel = 'Admin',
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        rates = rates ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tier': tier,
        'effectiveDate': effectiveDate,
        'expiryDate': expiryDate,
        'rates': rates.map((r) => r.toJson()).toList(),
        'createdBy': createdBy,
        'accessLevel': accessLevel,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory RateCard.fromJson(Map<String, dynamic> json) {
    return RateCard(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      tier: json['tier']?.toString() ?? 'National',
      effectiveDate: json['effectiveDate']?.toString() ?? '',
      expiryDate: json['expiryDate']?.toString() ?? '',
      rates: (json['rates'] as List?)
              ?.map((e) => RateTier.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdBy: json['createdBy']?.toString() ?? '',
      accessLevel: json['accessLevel']?.toString() ?? 'Admin',
      notes: json['notes']?.toString() ?? '',
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  RateCard copyWith({
    String? name,
    String? tier,
    String? effectiveDate,
    String? expiryDate,
    List<RateTier>? rates,
    String? accessLevel,
    String? notes,
  }) {
    return RateCard(
      id: id,
      name: name ?? this.name,
      tier: tier ?? this.tier,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      expiryDate: expiryDate ?? this.expiryDate,
      rates: rates ?? this.rates,
      createdBy: createdBy,
      accessLevel: accessLevel ?? this.accessLevel,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Individual rate tier entry within a rate card.
class RateTier {
  final String id;
  String roleTitle;
  String discipline;
  double baseRate; // Monthly base rate
  String currency; // e.g. 'USD', 'EUR'
  double burdenMultiplier; // Overhead/burden multiplier (e.g. 1.35 = 35% burden)
  double escalationPercent; // Annual escalation percentage
  String grade; // Optional grade/level (e.g. 'Senior', 'Junior', 'Lead')
  String notes;

  RateTier({
    String? id,
    this.roleTitle = '',
    this.discipline = '',
    this.baseRate = 0,
    this.currency = 'USD',
    this.burdenMultiplier = 1.0,
    this.escalationPercent = 0,
    this.grade = '',
    this.notes = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  /// Total loaded rate = baseRate * burdenMultiplier
  double get loadedRate => baseRate * burdenMultiplier;

  Map<String, dynamic> toJson() => {
        'id': id,
        'roleTitle': roleTitle,
        'discipline': discipline,
        'baseRate': baseRate,
        'currency': currency,
        'burdenMultiplier': burdenMultiplier,
        'escalationPercent': escalationPercent,
        'grade': grade,
        'notes': notes,
      };

  factory RateTier.fromJson(Map<String, dynamic> json) {
    return RateTier(
      id: json['id']?.toString(),
      roleTitle: json['roleTitle']?.toString() ?? '',
      discipline: json['discipline']?.toString() ?? '',
      baseRate: json['baseRate'] is num
          ? (json['baseRate'] as num).toDouble()
          : 0,
      currency: json['currency']?.toString() ?? 'USD',
      burdenMultiplier: json['burdenMultiplier'] is num
          ? (json['burdenMultiplier'] as num).toDouble()
          : 1.0,
      escalationPercent: json['escalationPercent'] is num
          ? (json['escalationPercent'] as num).toDouble()
          : 0,
      grade: json['grade']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }

  RateTier copyWith({
    String? roleTitle,
    String? discipline,
    double? baseRate,
    String? currency,
    double? burdenMultiplier,
    double? escalationPercent,
    String? grade,
    String? notes,
  }) {
    return RateTier(
      id: id,
      roleTitle: roleTitle ?? this.roleTitle,
      discipline: discipline ?? this.discipline,
      baseRate: baseRate ?? this.baseRate,
      currency: currency ?? this.currency,
      burdenMultiplier: burdenMultiplier ?? this.burdenMultiplier,
      escalationPercent: escalationPercent ?? this.escalationPercent,
      grade: grade ?? this.grade,
      notes: notes ?? this.notes,
    );
  }
}

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is DateTime) return v;
  return DateTime.now();
}
