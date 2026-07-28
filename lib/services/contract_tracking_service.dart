import 'package:ndu_project/models/planning_contract.dart';

class ContractTrackingService {
  ContractTrackingService._();

  static const List<String> statusLifecycle = [
    'Draft',
    'Negotiation',
    'Executed',
    'Active',
    'Almost Complete',
    'Closed Out',
  ];

  static String normalizeStatus(String status) {
    final normalized = status.trim().toLowerCase().replaceAll('_', ' ');
    if (normalized.isEmpty) return 'Draft';
    if (normalized.contains('negotiat')) return 'Negotiation';
    if (normalized.contains('almost')) return 'Almost Complete';
    if (normalized.contains('closed')) return 'Closed Out';
    if (normalized.contains('active') || normalized.contains('progress')) {
      return 'Active';
    }
    if (normalized.contains('execut')) return 'Executed';
    if (normalized.contains('draft') || normalized.contains('not started')) {
      return 'Draft';
    }
    return statusLifecycle.firstWhere(
      (value) => value.toLowerCase() == normalized,
      orElse: () => status,
    );
  }

  static double computeProgress(PlanningContract contract) {
    final milestoneProgress = _milestoneProgress(contract);
    if (milestoneProgress != null) return milestoneProgress;
    return _statusProgress(normalizeStatus(contract.status));
  }

  static double? _milestoneProgress(PlanningContract contract) {
    if (contract.paymentMilestones.isEmpty) return null;
    final totalAmount = contract.paymentMilestones.fold<double>(
      0,
      (sum, milestone) => sum + milestone.amount,
    );
    if (totalAmount > 0) {
      final completedAmount = contract.paymentMilestones
          .where((m) => m.isCompleted)
          .fold<double>(0, (sum, milestone) => sum + milestone.amount);
      return ((completedAmount / totalAmount) * 100).clamp(0, 100);
    }
    final completedCount =
        contract.paymentMilestones.where((m) => m.isCompleted).length;
    return ((completedCount / contract.paymentMilestones.length) * 100)
        .clamp(0, 100);
  }

  static double _statusProgress(String normalizedStatus) {
    switch (normalizedStatus) {
      case 'Draft':
        return 0;
      case 'Negotiation':
        return 20;
      case 'Executed':
        return 40;
      case 'Active':
        return 65;
      case 'Almost Complete':
        return 90;
      case 'Closed Out':
        return 100;
      default:
        return 0;
    }
  }

  static Map<String, int> getStatusCounts(List<PlanningContract> contracts) {
    final counts = <String, int>{
      for (final status in statusLifecycle) status: 0,
    };
    for (final c in contracts) {
      final status = normalizeStatus(c.status);
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  static Map<String, double> getProgressSummary(
      List<PlanningContract> contracts) {
    if (contracts.isEmpty) {
      return {
        'avgProgress': 0,
        'totalEstimatedValue': 0,
        'totalActualValue': 0,
        'contractCount': 0,
        'activeContracts': 0,
        'closedContracts': 0,
        'completionRatio': 0,
      };
    }

    final totalProgress =
        contracts.fold<double>(0, (sum, c) => sum + computeProgress(c));
    final totalEstimated =
        contracts.fold<double>(0, (sum, c) => sum + c.estimatedValue);
    final totalActual =
        contracts.fold<double>(0, (sum, c) => sum + c.actualValue);
    final activeContracts =
        contracts.where((c) => normalizeStatus(c.status) == 'Active').length;
    final closedContracts = contracts
        .where((c) => normalizeStatus(c.status) == 'Closed Out')
        .length;

    return {
      'avgProgress': totalProgress / contracts.length,
      'totalEstimatedValue': totalEstimated,
      'totalActualValue': totalActual,
      'contractCount': contracts.length.toDouble(),
      'activeContracts': activeContracts.toDouble(),
      'closedContracts': closedContracts.toDouble(),
      'completionRatio': closedContracts / contracts.length,
    };
  }

  static List<PlanningContract> filterByStatus(
      List<PlanningContract> contracts, String status) {
    final normalized = normalizeStatus(status);
    return contracts
        .where((c) => normalizeStatus(c.status) == normalized)
        .toList();
  }

  static List<PlanningContract> sortByProgress(
    List<PlanningContract> contracts, {
    bool descending = true,
  }) {
    final sorted = List<PlanningContract>.from(contracts);
    sorted.sort((a, b) {
      final comparison = computeProgress(a).compareTo(computeProgress(b));
      return descending ? -comparison : comparison;
    });
    return sorted;
  }

  static List<ContractPaymentMilestone> overdueMilestones(
    PlanningContract contract, {
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    return contract.paymentMilestones.where((milestone) {
      if (milestone.isCompleted) return false;
      final dueDate = DateTime.tryParse(milestone.dueDate);
      return dueDate != null && dueDate.isBefore(now);
    }).toList();
  }

  static bool isCloseOutCandidate(PlanningContract contract) {
    final normalized = normalizeStatus(contract.status);
    if (normalized == 'Closed Out') return true;
    if (contract.paymentMilestones.isNotEmpty) {
      return contract.paymentMilestones
          .every((milestone) => milestone.isCompleted);
    }
    return computeProgress(contract) >= 95;
  }
}
