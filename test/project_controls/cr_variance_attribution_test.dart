import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/project_controls/models/project_controls_models.dart';
import 'package:ndu_project/project_controls/models/change_management_models.dart'
    as cm;
import 'package:ndu_project/project_controls/providers/project_controls_provider.dart';
import 'package:ndu_project/project_controls/utils/cr_variance_attribution.dart';

WorkPackageControl wp(String id, String code, String name) =>
    WorkPackageControl(
      id: id,
      wbsCode: code,
      name: name,
      scopeDescription: '',
      deliverables: const [],
      acceptanceCriteria: const [],
      priority: 'High',
      status: 'In Progress',
      originalBudget: 100000,
      currentBudget: 100000,
      committedCost: 0,
      actualCost: 0,
      earnedValue: 0,
      plannedValue: 0,
      progressMethod: ProgressMethod.physicalPercent,
    );

cm.CMChangeRequest cr(
  String id,
  String crNumber, {
  cm.CMStatus status = cm.CMStatus.approved,
  int? scheduleDaysImpact,
  List<String> affectedWorkPackages = const [],
  List<cm.ImplementationTask> implementationTasks = const [],
}) =>
    cm.CMChangeRequest(
      id: id,
      crNumber: crNumber,
      title: 'Accelerate Steel Delivery',
      description: 'Bring steel delivery forward',
      changeType: cm.CMChangeType.schedule,
      priority: cm.CMPriority.high,
      status: status,
      submittedBy: 'you@ndu.project',
      dateSubmitted: DateTime(2026, 8, 1),
      businessJustification: 'Customer requested earlier handover',
      impact: const cm.FullImpactAssessment(),
      approvalSteps: const [],
      affectedRegisters: const [],
      affectedBaselines: const [],
      affectedWorkPackages: affectedWorkPackages,
      scheduleDaysImpact: scheduleDaysImpact,
      implementationTasks: implementationTasks,
    );

void main() {
  group('attributeScheduleVarianceToChangeRequest (provider upsert)', () {
    test('creates a variance when none exists, with the CR attribution', () {
      final provider = ProjectControlsProvider();
      provider.attributeScheduleVarianceToChangeRequest(
        'wp_1',
        crNumber: 'CR-2026-003',
        reason: 'CR-2026-003: Accelerate Steel Delivery (+14d schedule)',
      );

      final variances = provider.state.scheduleVariances;
      expect(variances, hasLength(1));
      final sv = variances.first;
      expect(sv.workPackageId, 'wp_1');
      expect(sv.changeRequestNumber, 'CR-2026-003');
      expect(sv.delayReason, contains('CR-2026-003'));
      expect(sv.compressionStrategy, CompressionStrategy.none);
    });

    test('updates an existing variance keeping dates and strategy', () {
      final provider = ProjectControlsProvider();
      provider.addScheduleVariance(ScheduleVariance(
        workPackageId: 'wp_1',
        plannedStart: DateTime(2026, 8, 1),
        plannedFinish: DateTime(2026, 10, 1),
        floatDays: 2,
        delayReason: 'Vendor late',
        compressionStrategy: CompressionStrategy.fastTrack,
      ));

      provider.attributeScheduleVarianceToChangeRequest(
        'wp_1',
        crNumber: 'CR-2026-004',
        reason: 'CR-2026-004: Add Fire Suppression (+7d schedule)',
      );

      final sv = provider.state.scheduleVariances.single;
      expect(sv.changeRequestNumber, 'CR-2026-004');
      expect(sv.plannedStart, DateTime(2026, 8, 1));
      expect(sv.plannedFinish, DateTime(2026, 10, 1));
      expect(sv.floatDays, 2);
      expect(sv.compressionStrategy, CompressionStrategy.fastTrack);
      // User-entered reason kept, CR number appended.
      expect(sv.delayReason, contains('Vendor late'));
      expect(sv.delayReason, contains('CR-2026-004'));
    });

    test('re-stamping the same CR does not duplicate the number', () {
      final provider = ProjectControlsProvider();
      const reason = 'CR-2026-003: Accelerate Steel Delivery (+14d schedule)';
      provider.attributeScheduleVarianceToChangeRequest('wp_1',
          crNumber: 'CR-2026-003', reason: reason);
      provider.attributeScheduleVarianceToChangeRequest('wp_1',
          crNumber: 'CR-2026-003', reason: reason);

      final sv = provider.state.scheduleVariances.single;
      expect(sv.changeRequestNumber, 'CR-2026-003');
      expect('CR-2026-003'.allMatches(sv.delayReason).length, 1);
      expect(provider.state.scheduleVariances, hasLength(1));
    });
  });

  group('varianceReasonFor', () {
    test('composes CR number, title and schedule impact', () {
      final reason = varianceReasonFor(cr('a', 'CR-2026-003',
          scheduleDaysImpact: 14));
      expect(reason, 'CR-2026-003: Accelerate Steel Delivery (+14d schedule)');
    });

    test('no schedule impact → no suffix', () {
      final reason = varianceReasonFor(cr('b', 'CR-2026-004'));
      expect(reason, 'CR-2026-004: Accelerate Steel Delivery');
    });
  });

  group('changeRequestAffectsWorkPackage', () {
    test('matches by WBS code contained in affectedWorkPackages', () {
      final wpc = wp('wp_1', 'G2.1', 'Steel Structure');
      final request =
          cr('a', 'CR-2026-003', affectedWorkPackages: const ['G2.1 Steel Beams']);
      expect(changeRequestAffectsWorkPackage(request, wpc), isTrue);
    });

    test('matches by exact work-package name', () {
      final wpc = wp('wp_2', 'G3.1', 'HVAC Re-Design');
      final request =
          cr('a', 'CR-2026-003', affectedWorkPackages: const ['HVAC Re-Design']);
      expect(changeRequestAffectsWorkPackage(request, wpc), isTrue);
    });

    test('matches by implementation task id', () {
      final wpc = wp('wp_9', 'G4.2', 'Controls Programming');
      final request = cr('a', 'CR-2026-003', implementationTasks: const [
        cm.ImplementationTask(
            id: 't1', workPackageId: 'wp_9', workPackageName: 'Controls Programming'),
      ]);
      expect(changeRequestAffectsWorkPackage(request, wpc), isTrue);
    });

    test('rejects unrelated work packages', () {
      final wpc = wp('wp_1', 'G1.1', 'Site Clearing');
      final request = cr('a', 'CR-2026-003',
          affectedWorkPackages: const ['G5.3 Interior Finishes']);
      expect(changeRequestAffectsWorkPackage(request, wpc), isFalse);
    });
  });

  group('syncCrVarianceAttribution', () {
    test('stamps approved CRs onto matching work packages', () {
      final provider = ProjectControlsProvider();
      provider.addWorkPackage(wp('wp_1', 'G2.1', 'Steel Structure'));
      provider.addWorkPackage(wp('wp_2', 'G3.1', 'HVAC Re-Design'));
      provider.addWorkPackage(wp('wp_3', 'G9.1', 'Landscaping'));

      final stamped = syncCrVarianceAttribution(
        changeRequests: [
          cr('a', 'CR-2026-003',
              scheduleDaysImpact: 14,
              affectedWorkPackages: const ['G2.1 Steel Beams', 'HVAC Re-Design']),
        ],
        provider: provider,
      );

      expect(stamped, 2);
      final byWp = {
        for (final sv in provider.state.scheduleVariances) sv.workPackageId: sv,
      };
      expect(byWp['wp_1']?.changeRequestNumber, 'CR-2026-003');
      expect(byWp['wp_2']?.changeRequestNumber, 'CR-2026-003');
      expect(byWp['wp_3']?.changeRequestNumber, isNull,
          reason: 'landscaping is not affected');
    });

    test('ignores draft/submitted CRs — impact is live only when approved', () {
      final provider = ProjectControlsProvider();
      provider.addWorkPackage(wp('wp_1', 'G2.1', 'Steel Structure'));

      final stamped = syncCrVarianceAttribution(
        changeRequests: [
          cr('a', 'CR-2026-003',
              status: cm.CMStatus.draft,
              affectedWorkPackages: const ['G2.1 Steel Beams']),
          cr('b', 'CR-2026-004',
              status: cm.CMStatus.submitted,
              affectedWorkPackages: const ['G2.1 Steel Beams']),
        ],
        provider: provider,
      );

      expect(stamped, 0);
      expect(provider.state.scheduleVariances, isEmpty);
    });

    test('re-running is idempotent', () {
      final provider = ProjectControlsProvider();
      provider.addWorkPackage(wp('wp_1', 'G2.1', 'Steel Structure'));
      final requests = [
        cr('a', 'CR-2026-003',
            affectedWorkPackages: const ['G2.1 Steel Beams']),
      ];

      syncCrVarianceAttribution(changeRequests: requests, provider: provider);
      final second = syncCrVarianceAttribution(
          changeRequests: requests, provider: provider);

      expect(second, 1);
      expect(provider.state.scheduleVariances, hasLength(1));
    });
  });
}