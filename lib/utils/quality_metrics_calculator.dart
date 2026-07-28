import 'package:ndu_project/models/project_data_model.dart';

class QualityMetricsCalculator {
  static QualityComputedSnapshot computeSnapshot(
    QualityManagementData qualityData, {
    DateTime? now,
  }) {
    final DateTime referenceDate = now ?? DateTime.now();
    final allTasks = [...qualityData.qaTaskLog, ...qualityData.qcTaskLog];

    final statusTallies = <String, int>{
      'notStarted': 0,
      'inProgress': 0,
      'complete': 0,
      'blocked': 0,
    };
    final priorityTallies = <String, int>{
      'minimal': 0,
      'moderate': 0,
      'critical': 0,
    };

    for (final task in allTasks) {
      switch (task.status) {
        case QualityTaskStatus.notStarted:
          statusTallies['notStarted'] = (statusTallies['notStarted'] ?? 0) + 1;
          break;
        case QualityTaskStatus.inProgress:
          statusTallies['inProgress'] = (statusTallies['inProgress'] ?? 0) + 1;
          break;
        case QualityTaskStatus.complete:
          statusTallies['complete'] = (statusTallies['complete'] ?? 0) + 1;
          break;
        case QualityTaskStatus.blocked:
          statusTallies['blocked'] = (statusTallies['blocked'] ?? 0) + 1;
          break;
      }

      switch (task.priority) {
        case QualityTaskPriority.minimal:
          priorityTallies['minimal'] = (priorityTallies['minimal'] ?? 0) + 1;
          break;
        case QualityTaskPriority.moderate:
          priorityTallies['moderate'] = (priorityTallies['moderate'] ?? 0) + 1;
          break;
        case QualityTaskPriority.critical:
          priorityTallies['critical'] = (priorityTallies['critical'] ?? 0) + 1;
          break;
      }
    }

    final averageTaskCompletionPercent = allTasks.isEmpty
        ? 0.0
        : allTasks
                .map((t) => _clampPercent(t.percentComplete))
                .reduce((a, b) => a + b) /
            allTasks.length;

    final plannedAudits = qualityData.auditPlan.where((a) {
      return a.plannedDate.trim().isNotEmpty ||
          a.completedDate.trim().isNotEmpty ||
          a.result != AuditResultStatus.pending;
    }).toList();
    final completedAuditCount = plannedAudits.where((a) {
      return a.completedDate.trim().isNotEmpty ||
          a.result == AuditResultStatus.pass ||
          a.result == AuditResultStatus.conditional ||
          a.result == AuditResultStatus.fail;
    }).length;
    final plannedAuditsCompletionPercent = plannedAudits.isEmpty
        ? 0.0
        : (completedAuditCount / plannedAudits.length) * 100;

    final resolutionDurations = allTasks
        .where((task) => task.status == QualityTaskStatus.complete)
        .map((task) => _resolutionDays(task, referenceDate))
        .whereType<double>()
        .where((days) => days >= 0)
        .toList();

    final averageTimeToResolutionDays = resolutionDurations.isEmpty
        ? 0.0
        : resolutionDurations.reduce((a, b) => a + b) /
            resolutionDurations.length;

    final targetTimeToResolutionDays =
        qualityData.dashboardConfig.targetTimeToResolutionDays;

    final defectTrendData = _buildDefectTrend(qualityData, referenceDate);
    final satisfactionTrendData =
        _buildSatisfactionTrend(qualityData, referenceDate);

    return QualityComputedSnapshot(
      averageTimeToResolutionDays:
          _roundTo(averageTimeToResolutionDays, places: 2),
      targetTimeToResolutionDays: _roundTo(targetTimeToResolutionDays),
      averageTaskCompletionPercent:
          _roundTo(averageTaskCompletionPercent, places: 2),
      plannedAuditsCompletionPercent:
          _roundTo(plannedAuditsCompletionPercent, places: 2),
      statusTallies: statusTallies,
      priorityTallies: priorityTallies,
      defectTrendData: defectTrendData,
      satisfactionTrendData: satisfactionTrendData,
      generatedAt: referenceDate.toIso8601String(),
    );
  }

  static double _clampPercent(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    if (value < 0) return 0.0;
    if (value > 100) return 100.0;
    return value;
  }

  static double _roundTo(double value, {int places = 1}) {
    final factor =
        places <= 0 ? 1 : List.filled(places, 10).reduce((a, b) => a * b);
    return (value * factor).round() / factor;
  }

  static DateTime? _parseFlexibleDate(String raw, DateTime referenceDate) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final parsedIso = DateTime.tryParse(trimmed);
    if (parsedIso != null) return parsedIso;

    final mmdd = RegExp(r'^(\d{1,2})\/(\d{1,2})$').firstMatch(trimmed);
    if (mmdd != null) {
      final month = int.tryParse(mmdd.group(1) ?? '');
      final day = int.tryParse(mmdd.group(2) ?? '');
      if (month != null && day != null) {
        return DateTime(referenceDate.year, month, day);
      }
    }

    final mmddyy =
        RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{2}|\d{4})$').firstMatch(trimmed);
    if (mmddyy != null) {
      final month = int.tryParse(mmddyy.group(1) ?? '');
      final day = int.tryParse(mmddyy.group(2) ?? '');
      final yearRaw = int.tryParse(mmddyy.group(3) ?? '');
      if (month != null && day != null && yearRaw != null) {
        final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  static double? _resolutionDays(
    QualityTaskEntry task,
    DateTime referenceDate,
  ) {
    if (task.durationDays != null && task.durationDays! >= 0) {
      return task.durationDays!.toDouble();
    }

    final start = _parseFlexibleDate(task.startDate, referenceDate);
    final end = _parseFlexibleDate(
      task.resolvedDate?.trim().isNotEmpty == true
          ? task.resolvedDate!
          : task.endDate,
      referenceDate,
    );
    if (start == null || end == null) return null;
    return end.difference(start).inDays.toDouble().abs();
  }

  static List<double> _buildDefectTrend(
    QualityManagementData qualityData,
    DateTime referenceDate,
  ) {
    if (qualityData.metrics.defectTrendData.isNotEmpty) {
      return qualityData.metrics.defectTrendData;
    }

    final points = <double>[];
    for (int i = 5; i >= 0; i--) {
      final windowStart =
          DateTime(referenceDate.year, referenceDate.month - i, 1);
      final windowEnd =
          DateTime(referenceDate.year, referenceDate.month - i + 1, 1);

      final failedAudits = qualityData.auditPlan.where((audit) {
        if (audit.result != AuditResultStatus.fail) return false;
        final date = _parseFlexibleDate(
            audit.completedDate.isNotEmpty
                ? audit.completedDate
                : audit.plannedDate,
            referenceDate);
        if (date == null) return false;
        return !date.isBefore(windowStart) && date.isBefore(windowEnd);
      }).length;

      final blockedTasks =
          [...qualityData.qaTaskLog, ...qualityData.qcTaskLog].where((task) {
        if (task.status != QualityTaskStatus.blocked) return false;
        final date = _parseFlexibleDate(task.endDate, referenceDate) ??
            _parseFlexibleDate(task.startDate, referenceDate);
        if (date == null) return false;
        return !date.isBefore(windowStart) && date.isBefore(windowEnd);
      }).length;

      points.add((failedAudits + blockedTasks).toDouble());
    }
    return points;
  }

  static List<double> _buildSatisfactionTrend(
    QualityManagementData qualityData,
    DateTime referenceDate,
  ) {
    if (qualityData.metrics.satisfactionTrendData.isNotEmpty) {
      return qualityData.metrics.satisfactionTrendData;
    }

    final allTasks = [...qualityData.qaTaskLog, ...qualityData.qcTaskLog];
    final points = <double>[];
    for (int i = 5; i >= 0; i--) {
      final windowStart =
          DateTime(referenceDate.year, referenceDate.month - i, 1);
      final windowEnd =
          DateTime(referenceDate.year, referenceDate.month - i + 1, 1);

      final monthTasks = allTasks.where((task) {
        final date = _parseFlexibleDate(task.endDate, referenceDate) ??
            _parseFlexibleDate(task.startDate, referenceDate);
        if (date == null) return false;
        return !date.isBefore(windowStart) && date.isBefore(windowEnd);
      }).toList();

      if (monthTasks.isEmpty) {
        points.add(0);
        continue;
      }

      final avgCompletion = monthTasks
              .map((task) => _clampPercent(task.percentComplete))
              .reduce((a, b) => a + b) /
          monthTasks.length;
      points.add(_roundTo(avgCompletion / 20.0, places: 2));
    }

    return points;
  }
}
