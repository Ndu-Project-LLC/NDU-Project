import 'package:ndu_project/models/cost_of_quality.dart';
import 'package:ndu_project/models/project_data_model.dart';

class CostOfQualityService {
  CostOfQualityService._();

  static const List<String> categories = [
    'Prevention',
    'Appraisal',
    'Internal Failure',
    'External Failure',
  ];

  static CostOfQualityData calculateSummary(CostOfQualityData data) {
    return CostOfQualityData(
      preventionCosts: List<CoQEntry>.from(data.preventionCosts),
      appraisalCosts: List<CoQEntry>.from(data.appraisalCosts),
      internalFailureCosts: List<CoQEntry>.from(data.internalFailureCosts),
      externalFailureCosts: List<CoQEntry>.from(data.externalFailureCosts),
      notes: data.notes,
    );
  }

  static Map<String, double> categoryTotals(CostOfQualityData data) {
    return {
      'Prevention': data.totalPrevention,
      'Appraisal': data.totalAppraisal,
      'Internal Failure': data.totalInternalFailure,
      'External Failure': data.totalExternalFailure,
      'Total': data.totalCoq,
      'Estimated Total': data.totalEstimatedCoq,
    };
  }

  static Map<String, double> scopeTotals(CostOfQualityData data) {
    final totals = <String, double>{
      'Internal': 0,
      '3rd Party': 0,
      'Regulatory': 0,
    };
    for (final entry in flattenEntries(data)) {
      final scope = _normalizeScope(entry.scope);
      totals[scope] = (totals[scope] ?? 0) + entry.actualCost;
    }
    return totals;
  }

  static List<CoQEntry> flattenEntries(CostOfQualityData data) {
    return [
      ...data.preventionCosts,
      ...data.appraisalCosts,
      ...data.internalFailureCosts,
      ...data.externalFailureCosts,
    ];
  }

  static List<Map<String, dynamic>> exportToCsvData(CostOfQualityData data) {
    final rows = <Map<String, dynamic>>[];
    for (final entry in data.preventionCosts) {
      rows.add(_entryToRow('Prevention', entry));
    }
    for (final entry in data.appraisalCosts) {
      rows.add(_entryToRow('Appraisal', entry));
    }
    for (final entry in data.internalFailureCosts) {
      rows.add(_entryToRow('Internal Failure', entry));
    }
    for (final entry in data.externalFailureCosts) {
      rows.add(_entryToRow('External Failure', entry));
    }
    return rows;
  }

  static CostOfQualityData importFromCsvData(List<Map<String, dynamic>> rows) {
    final prevention = <CoQEntry>[];
    final appraisal = <CoQEntry>[];
    final internalFailure = <CoQEntry>[];
    final externalFailure = <CoQEntry>[];

    for (final row in rows) {
      final entry = CoQEntry(
        description: row['description']?.toString() ?? '',
        scope: _normalizeScope(row['scope']?.toString() ?? 'Internal'),
        performerRole: row['performerRole']?.toString() ?? '',
        wbsReference: row['wbsReference']?.toString() ?? '',
        estimatedCost: _parseNum(row['estimatedCost']),
        actualCost: _parseNum(row['actualCost']),
        frequency: row['frequency']?.toString() ?? 'One-time',
        status: row['status']?.toString() ?? 'Planned',
        notes: row['notes']?.toString() ?? '',
      );

      final category = row['category']?.toString().toLowerCase() ?? '';
      if (category.contains('prevention')) {
        prevention.add(entry);
      } else if (category.contains('appraisal')) {
        appraisal.add(entry);
      } else if (category.contains('internal')) {
        internalFailure.add(entry);
      } else if (category.contains('external')) {
        externalFailure.add(entry);
      }
    }

    return CostOfQualityData(
      preventionCosts: prevention,
      appraisalCosts: appraisal,
      internalFailureCosts: internalFailure,
      externalFailureCosts: externalFailure,
    );
  }

  static String buildCoqContext(ProjectDataModel data) {
    final coq = data.costOfQualityData;
    final buf = StringBuffer();
    buf.writeln('Project: ${data.projectName}');
    buf.writeln('--- Cost of Quality Summary ---');

    if (coq == null) {
      buf.writeln('No Cost of Quality data available.');
      return buf.toString();
    }

    final totals = categoryTotals(coq);
    buf.writeln('Total Prevention Costs: ${totals['Prevention']}');
    buf.writeln('Total Appraisal Costs: ${totals['Appraisal']}');
    buf.writeln('Total Internal Failure Costs: ${totals['Internal Failure']}');
    buf.writeln('Total External Failure Costs: ${totals['External Failure']}');
    buf.writeln('Total CoQ: ${totals['Total']}');
    buf.writeln('Estimated CoQ: ${totals['Estimated Total']}');
    buf.writeln('');

    final scopes = scopeTotals(coq);
    buf.writeln('Scope split:');
    scopes.forEach((scope, value) {
      buf.writeln('  - $scope: $value');
    });
    buf.writeln('');

    void writeEntries(String label, List<CoQEntry> entries) {
      if (entries.isEmpty) return;
      buf.writeln('$label:');
      for (final e in entries) {
        buf.writeln(
            '  - ${e.description} (Scope: ${e.scope}, Status: ${e.status}, Actual: ${e.actualCost}, Estimated: ${e.estimatedCost}, WBS: ${e.wbsReference.isEmpty ? 'Unlinked' : e.wbsReference})');
      }
    }

    writeEntries('Prevention', coq.preventionCosts);
    writeEntries('Appraisal', coq.appraisalCosts);
    writeEntries('Internal Failure', coq.internalFailureCosts);
    writeEntries('External Failure', coq.externalFailureCosts);

    if (coq.notes.isNotEmpty) {
      buf.writeln('Notes: ${coq.notes}');
    }

    return buf.toString();
  }

  static List<CoQEntry> entriesForCategory(
    CostOfQualityData data,
    String category,
  ) {
    switch (category.toLowerCase()) {
      case 'prevention':
        return List<CoQEntry>.from(data.preventionCosts);
      case 'appraisal':
        return List<CoQEntry>.from(data.appraisalCosts);
      case 'internal failure':
      case 'internal_failure':
      case 'internal':
        return List<CoQEntry>.from(data.internalFailureCosts);
      case 'external failure':
      case 'external_failure':
      case 'external':
        return List<CoQEntry>.from(data.externalFailureCosts);
      default:
        return const [];
    }
  }

  static Map<String, dynamic> _entryToRow(String category, CoQEntry entry) {
    return {
      'category': category,
      'description': entry.description,
      'scope': _normalizeScope(entry.scope),
      'performerRole': entry.performerRole,
      'wbsReference': entry.wbsReference,
      'estimatedCost': entry.estimatedCost,
      'actualCost': entry.actualCost,
      'frequency': entry.frequency,
      'status': entry.status,
      'notes': entry.notes,
    };
  }

  static String _normalizeScope(String scope) {
    final normalized = scope.trim().toLowerCase();
    if (normalized.contains('reg')) return 'Regulatory';
    if (normalized.contains('3rd') ||
        normalized.contains('third') ||
        normalized.contains('party')) {
      return '3rd Party';
    }
    return 'Internal';
  }

  static double _parseNum(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final cleaned = v.replaceAll(',', '').replaceAll('4', '').trim();
      return double.tryParse(cleaned) ?? 0;
    }
    return 0;
  }
}
