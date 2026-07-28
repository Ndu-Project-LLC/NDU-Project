class ProcurementWorkflowStep {
  const ProcurementWorkflowStep({
    required this.id,
    required this.name,
    required this.duration,
    required this.unit,
  });

  final String id;
  final String name;
  final int duration;
  final String unit;

  ProcurementWorkflowStep copyWith({
    String? id,
    String? name,
    int? duration,
    String? unit,
  }) {
    return ProcurementWorkflowStep(
      id: id ?? this.id,
      name: name ?? this.name,
      duration: duration ?? this.duration,
      unit: unit ?? this.unit,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'duration': duration,
        'unit': unit,
      };

  factory ProcurementWorkflowStep.fromMap(Map<String, dynamic> map) {
    final rawId = (map['id'] ?? '').toString().trim();
    final rawName = (map['name'] ?? map['stage'] ?? '').toString().trim();
    final rawDuration = map['duration'];
    var parsedDuration = 1;
    if (rawDuration is num) {
      parsedDuration = rawDuration.toInt();
    } else {
      parsedDuration = int.tryParse(rawDuration?.toString() ?? '') ?? 1;
    }
    if (parsedDuration < 1) parsedDuration = 1;
    final rawUnit = (map['unit'] ?? '').toString().trim().toLowerCase();
    final parsedUnit = rawUnit == 'month' ? 'month' : 'week';

    return ProcurementWorkflowStep(
      id: rawId.isEmpty ? 'wf_${DateTime.now().microsecondsSinceEpoch}' : rawId,
      name: rawName.isEmpty ? 'Untitled Step' : rawName,
      duration: parsedDuration,
      unit: parsedUnit,
    );
  }
}
