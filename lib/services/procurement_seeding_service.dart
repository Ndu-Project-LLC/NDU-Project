import 'package:flutter/material.dart';
import 'package:ndu_project/models/planning_contracting_models.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/services/planning_contracting_service.dart';
import 'package:ndu_project/services/procurement_service.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

/// Seeds planning procurement data from contracting records.
class ProcurementSeedingService {
  ProcurementSeedingService._();

  static const String _seededFlagKey =
      'procurement_auto_seeded_from_contracting';

  static bool hasSeeded(ProjectDataModel data) {
    return data.planningNotes[_seededFlagKey] == 'true';
  }

  static Future<void> markSeeded(BuildContext context) async {
    await ProjectDataHelper.updateAndSave(
      context: context,
      checkpoint: 'procurement',
      dataUpdater: (data) => data.copyWith(
        planningNotes: {
          ...data.planningNotes,
          _seededFlagKey: 'true',
        },
      ),
      showSnackbar: false,
    );
  }

  static Future<int> seedFromContracting(
    BuildContext context, {
    bool force = false,
  }) async {
    final data = ProjectDataHelper.getData(context);
    final projectId = data.projectId ?? '';
    if (projectId.isEmpty) {
      debugPrint('Skipping procurement auto-seed: missing projectId.');
      return 0;
    }

    if (!force && hasSeeded(data)) {
      return 0;
    }

    final existingItems = await ProcurementService.streamItems(projectId).first;
    final existingSourceIds = existingItems
        .map((item) => item.contractId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final rfqs = await PlanningContractingService.streamRfqs(projectId).first;
    final contracts = await ProcurementService.streamContracts(projectId).first;

    var createdCount = 0;

    for (final rfq in rfqs) {
      if (!_shouldSeedRfq(rfq) || existingSourceIds.contains(rfq.id)) {
        continue;
      }

      final item = ProcurementItemModel(
        id: '',
        projectId: projectId,
        name: rfq.title.trim().isNotEmpty ? rfq.title.trim() : 'RFQ ${rfq.id}',
        description: rfq.scopeOfWork.trim(),
        category: _inferCategory(rfq.title, rfq.scopeOfWork),
        status: ProcurementItemStatus.planning,
        priority: _inferPriorityFromRfq(rfq),
        budget: 0.0,
        contractId: rfq.id,
        responsibleMember: '',
        notes: 'Auto-seeded from planning RFQ "${rfq.title}".',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ProcurementService.createItem(item);
      existingSourceIds.add(rfq.id);
      createdCount++;
    }

    for (final contract in contracts) {
      if (existingSourceIds.contains(contract.id)) {
        continue;
      }

      final item = ProcurementItemModel(
        id: '',
        projectId: projectId,
        name: contract.title.trim().isNotEmpty
            ? contract.title.trim()
            : 'Contract ${contract.id}',
        description: contract.description.trim(),
        category: _inferCategory(contract.title, contract.description),
        status: ProcurementItemStatus.planning,
        priority: _inferPriorityFromContract(contract),
        budget: contract.estimatedCost,
        contractId: contract.id,
        responsibleMember: contract.owner.trim(),
        notes: 'Auto-seeded from procurement contract "${contract.title}".',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ProcurementService.createItem(item);
      existingSourceIds.add(contract.id);
      createdCount++;
    }

    if (createdCount > 0 && context.mounted) {
      await markSeeded(context);
    }

    return createdCount;
  }

  static bool _shouldSeedRfq(PlanningRfq rfq) {
    final status = rfq.status.trim().toLowerCase();
    return status == 'closed' ||
        status == 'awarded' ||
        status == 'issued' ||
        status == 'in market' ||
        status == 'evaluation';
  }

  static String _inferCategory(String title, String description) {
    final haystack = '${title.toLowerCase()} ${description.toLowerCase()}';
    if (haystack.contains('software') ||
        haystack.contains('system') ||
        haystack.contains('network') ||
        haystack.contains('server') ||
        haystack.contains('it ')) {
      return 'IT Equipment';
    }
    if (haystack.contains('build') ||
        haystack.contains('construction') ||
        haystack.contains('facility') ||
        haystack.contains('civil')) {
      return 'Construction Services';
    }
    if (haystack.contains('furniture') ||
        haystack.contains('office') ||
        haystack.contains('workspace')) {
      return 'Office & Workspace';
    }
    if (haystack.contains('consult') ||
        haystack.contains('training') ||
        haystack.contains('professional')) {
      return 'Professional Services';
    }
    return 'General Procurement';
  }

  static ProcurementPriority _inferPriorityFromRfq(PlanningRfq rfq) {
    if (rfq.evaluationCriteria.length >= 5) {
      return ProcurementPriority.high;
    }
    final deadline = rfq.submissionDeadline;
    if (deadline != null) {
      final daysUntilDeadline = deadline.difference(DateTime.now()).inDays;
      if (daysUntilDeadline <= 14) {
        return ProcurementPriority.critical;
      }
    }
    if (rfq.invitedContractors.length >= 4) {
      return ProcurementPriority.high;
    }
    return ProcurementPriority.medium;
  }

  static ProcurementPriority _inferPriorityFromContract(ContractModel contract) {
    if (contract.estimatedCost >= 1000000) {
      return ProcurementPriority.critical;
    }
    if (contract.estimatedCost >= 250000) {
      return ProcurementPriority.high;
    }
    if (contract.status == ContractStatus.approved ||
        contract.status == ContractStatus.executed) {
      return ProcurementPriority.high;
    }
    return ProcurementPriority.medium;
  }
}
