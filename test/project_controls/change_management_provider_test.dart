import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/project_controls/models/change_management_models.dart';
import 'package:ndu_project/project_controls/providers/change_management_provider.dart';

/// Advances a CR through every intermediate approval step so the next
/// approveStep call is the FINAL one (where the drawdown decision is made).
void _approveAllButLast(ChangeManagementProvider provider, String crId) {
  var current = provider.changeRequests.firstWhere((c) => c.id == crId);
  while (current.currentStepIndex < current.approvalSteps.length - 1) {
    provider.approveStep(current.id);
    current = provider.changeRequests.firstWhere((c) => c.id == crId);
  }
}

String _createSimpleCr(ChangeManagementProvider provider,
    {double? initialCostEstimate}) {
  return provider.createChangeRequest(
    title: 'Test change',
    description: 'Change for testing',
    changeType: CMChangeType.scope,
    priority: CMPriority.medium,
    businessJustification: 'Required for test',
    initialCostEstimate: initialCostEstimate,
  );
}

void main() {
  group('approveStep drawdown decision (Lusaka 22)', () {
    test('final approval draws from ONLY the chosen reserve', () {
      final provider = ChangeManagementProvider();
      final beforeContingency = provider.remainingContingency;
      final beforeReserve = provider.remainingReserve;

      final crId = _createSimpleCr(provider, initialCostEstimate: 80000);
      _approveAllButLast(provider, crId);

      provider.approveStep(
        crId,
        reserveSource: CMReserveSource.managementReserve,
        drawdownAmount: 80000,
      );

      final updated =
          provider.changeRequests.firstWhere((c) => c.id == crId);
      expect(updated.status, CMStatus.approved);
      expect(updated.drawdownReserve, CMReserveSource.managementReserve);
      expect(updated.drawdownAmount, 80000);
      // Only the management reserve moved — contingency untouched.
      expect(provider.remainingContingency, beforeContingency);
      expect(provider.remainingReserve, beforeReserve - 80000);
    });

    test('contingency drawdown moves only contingency', () {
      final provider = ChangeManagementProvider();
      final beforeContingency = provider.remainingContingency;
      final beforeReserve = provider.remainingReserve;

      final crId = _createSimpleCr(provider, initialCostEstimate: 30000);
      _approveAllButLast(provider, crId);

      provider.approveStep(
        crId,
        reserveSource: CMReserveSource.contingency,
        drawdownAmount: 30000,
      );

      final updated =
          provider.changeRequests.firstWhere((c) => c.id == crId);
      expect(updated.drawdownReserve, CMReserveSource.contingency);
      expect(provider.remainingContingency, beforeContingency - 30000);
      expect(provider.remainingReserve, beforeReserve);
    });

    test('drawdown is clamped to the remaining reserve', () {
      final provider = ChangeManagementProvider();
      final crId = _createSimpleCr(provider, initialCostEstimate: 999999999);
      _approveAllButLast(provider, crId);

      final remainingBefore = provider.remainingContingency;
      provider.approveStep(
        crId,
        reserveSource: CMReserveSource.contingency,
        drawdownAmount: 999999999,
      );

      final updated =
          provider.changeRequests.firstWhere((c) => c.id == crId);
      // The drawdown is clamped to what was available at approval time.
      expect(updated.drawdownAmount, remainingBefore);
      // The chosen reserve is fully drawn down; the other reserve is untouched.
      expect(provider.remainingContingency, 0);
      expect(provider.remainingReserve, provider.totalReserve);
    });
  });

  group('closeCR actual vs estimate (Lusaka 22)', () {
    test('records actual cost so the variance is computable', () {
      final provider = ChangeManagementProvider();
      final crId = _createSimpleCr(provider, initialCostEstimate: 10000);
      _approveAllButLast(provider, crId);
      provider.approveStep(crId);
      provider.implementCR(crId);
      provider.closeCR(crId, actualCost: 12500);

      final updated =
          provider.changeRequests.firstWhere((c) => c.id == crId);
      expect(updated.status, CMStatus.closed);
      expect(updated.actualCost, 12500);
      expect(updated.initialCostEstimate, 10000);
      // Variance = 12500 - 10000.
      expect((updated.actualCost ?? 0) - (updated.initialCostEstimate ?? 0),
          2500);
    });
  });

  group('deliverables list (Lusaka 22)', () {
    test('createChangeRequest stores the impacted deliverables list', () {
      final provider = ChangeManagementProvider();
      final crId = provider.createChangeRequest(
        title: 'Deliverables change',
        description: 'Adds and modifies deliverables',
        changeType: CMChangeType.scope,
        priority: CMPriority.medium,
        businessJustification: 'Scope addition',
        affectedWorkPackages: const ['WP-2.1 Structural Steel'],
        deliverables: const [
          CMImpactedDeliverable(
            id: 'd1',
            name: 'Vendor contract',
            action: DeliverableAction.add,
            notes: 'Quote ref Q-1042',
          ),
          CMImpactedDeliverable(
            id: 'd2',
            name: 'Structural drawings',
            action: DeliverableAction.modify,
          ),
        ],
      );

      final cr = provider.changeRequests.firstWhere((c) => c.id == crId);
      expect(cr.deliverables, hasLength(2));
      expect(cr.deliverables[0].action, DeliverableAction.add);
      expect(cr.deliverables[1].action, DeliverableAction.modify);
      expect(cr.affectedWorkPackages, contains('WP-2.1 Structural Steel'));
    });
  });
}