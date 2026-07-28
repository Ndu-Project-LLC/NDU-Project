/// Model for a staffing requirement row in the Staff Team Orchestration page
class StaffingRow {
  final String id;
  String role;
  int quantity;
  bool isInternal; // true = Internal, false = External
  String startDate;
  String durationMonths; // Duration in months (as string for flexibility)
  String monthlyCost; // Monthly rate per person (as string for flexibility)
  String roleDescription; // Prose description (no bullets)
  String skillRequirements; // Bullet list with "." separator
  String notes; // Manual notes only, no AI generation
  String status;

  StaffingRow({
    String? id,
    this.role = '',
    this.quantity = 1,
    this.isInternal = true,
    this.startDate = '',
    this.durationMonths = '',
    this.monthlyCost = '',
    this.roleDescription = '',
    this.skillRequirements = '',
    this.notes = '',
    this.status = 'Not Started',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  /// Calculate subtotal: quantity × duration × monthlyCost
  double get subtotal {
    final qty = quantity;
    final duration = double.tryParse(durationMonths.replaceAll(',', '')) ?? 0.0;
    final monthly =
        double.tryParse(monthlyCost.replaceAll(',', '').replaceAll('\$', '')) ??
            0.0;
    return qty * duration * monthly;
  }

  /// Format subtotal as currency string
  String get subtotalFormatted {
    final total = subtotal;
    if (total == 0.0) return '\$0';
    return '\$${total.toStringAsFixed(0)}';
  }

  StaffingRow copyWith({
    String? role,
    int? quantity,
    bool? isInternal,
    String? startDate,
    String? durationMonths,
    String? monthlyCost,
    String? roleDescription,
    String? skillRequirements,
    String? notes,
    String? status,
  }) {
    return StaffingRow(
      id: id,
      role: role ?? this.role,
      quantity: quantity ?? this.quantity,
      isInternal: isInternal ?? this.isInternal,
      startDate: startDate ?? this.startDate,
      durationMonths: durationMonths ?? this.durationMonths,
      monthlyCost: monthlyCost ?? this.monthlyCost,
      roleDescription: roleDescription ?? this.roleDescription,
      skillRequirements: skillRequirements ?? this.skillRequirements,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'quantity': quantity,
        'isInternal': isInternal,
        'startDate': startDate,
        'durationMonths': durationMonths,
        'monthlyCost': monthlyCost,
        'roleDescription': roleDescription,
        'skillRequirements': skillRequirements,
        'notes': notes,
        'status': status,
      };

  factory StaffingRow.fromJson(Map<String, dynamic> json) {
    return StaffingRow(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      role: json['role']?.toString() ?? '',
      quantity: json['quantity'] is int
          ? json['quantity'] as int
          : (json['quantity'] is num ? (json['quantity'] as num).toInt() : 1),
      isInternal: json['isInternal'] is bool
          ? json['isInternal'] as bool
          : (json['isInternal'] == 'true' || json['isInternal'] == true),
      startDate: json['startDate']?.toString() ?? '',
      durationMonths: json['durationMonths']?.toString() ?? '',
      monthlyCost: json['monthlyCost']?.toString() ?? '',
      roleDescription: json['roleDescription']?.toString() ?? '',
      skillRequirements: json['skillRequirements']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Not Started',
    );
  }
}
