import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/models/design_phase_models.dart';
import 'package:ndu_project/models/project_data_model.dart' hide ScheduleActivity;
import 'package:ndu_project/schedule/providers/schedule_provider.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/wbs/models/wbs_models.dart';
import 'package:ndu_project/wbs/providers/wbs_provider.dart';
import 'package:ndu_project/wbs/screens/wbs_builder_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('resolvedProjectMethodology (Project Details source of truth)', () {
    test('defaults to waterfall', () {
      expect(
        ProjectDataHelper.resolvedProjectMethodology(ProjectDataModel()),
        ProjectMethodology.waterfall,
      );
    });

    test('reads overallFramework when design management is unset', () {
      final data = ProjectDataModel()..overallFramework = 'Agile';
      expect(
        ProjectDataHelper.resolvedProjectMethodology(data),
        ProjectMethodology.agile,
      );
    });

    test('design management methodology wins over overallFramework', () {
      final data = ProjectDataModel()
        ..overallFramework = 'Waterfall'
        ..designManagementData =
            DesignManagementData(methodology: ProjectMethodology.hybrid);
      expect(
        ProjectDataHelper.resolvedProjectMethodology(data),
        ProjectMethodology.hybrid,
      );
    });
  });

  group('WBS badge live update', () {
    testWidgets('badge switches from Waterfall to Agile when methodology syncs',
        (tester) async {
      final wbsProvider = WBSProvider();
      // Wide surface so the header action row doesn't overflow the default
      // 800x600 test viewport.
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // runAsync: platform-channel futures don't resolve in the fake-async
      // zone, so the storage load must happen outside it.
      await tester.runAsync(() => wbsProvider.ensureProjectLoaded('p1'));
      wbsProvider.setup(
        projectName: 'Chipata—Lundazi Road',
        framework: WBSFramework.waterfallDeliverable,
        methodology: ProjectMethodology.waterfall,
        projectId: 'p1',
      );
      // The advanced tree links cost lines via Firebase Auth, which is not
      // initialized in the test environment — use the Simple view, which
      // still renders the header badge under test.
      wbsProvider.setViewMode(true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<WBSProvider>.value(value: wbsProvider),
            ChangeNotifierProvider<CostEstimateProvider>(
              create: (_) => CostEstimateProvider(),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: WBSBuilderScreen())),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Initially Waterfall — matches the reported bug's "before" state.
      expect(find.text('Waterfall'), findsOneWidget);
      expect(find.textContaining('Waterfall — Deliverable-Based'),
          findsOneWidget);

      // Simulate what the WBS module screen does post-frame once Project
      // Details reports a different methodology.
      wbsProvider.syncMethodology(ProjectMethodology.agile);
      await tester.pump();
      await tester.pump();

      // The badge and framework label now reflect the new selection.
      expect(find.text('Agile'), findsOneWidget);
      expect(find.text('Waterfall'), findsNothing);
      expect(find.textContaining('Agile WBS'), findsOneWidget);
      // Level-1 label switches from Deliverable to Epic.
      expect(find.textContaining('Generate Epic'), findsOneWidget);
    });

    test('syncMethodology persists for the next module open', () async {
      final wbsProvider = WBSProvider();
      await wbsProvider.ensureProjectLoaded('p1');
      wbsProvider.setup(
        projectName: 'Chipata—Lundazi Road',
        framework: WBSFramework.waterfallDeliverable,
        methodology: ProjectMethodology.waterfall,
        projectId: 'p1',
      );
      wbsProvider.syncMethodology(ProjectMethodology.agile);
      // Let the async persist complete before reloading.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // A fresh provider (e.g. user reopens the WBS module) must load the
      // synced methodology from storage.
      final reloaded = WBSProvider();
      await reloaded.ensureProjectLoaded('p1');
      expect(reloaded.wbs, isNotNull);
      expect(reloaded.wbs!.methodology, ProjectMethodology.agile);
      expect(reloaded.wbs!.framework, WBSFramework.agile);
    });

    test('hybrid uses the agile breakdown (Epics/Features) with hybrid badge',
        () async {
      final wbsProvider = WBSProvider();
      await wbsProvider.ensureProjectLoaded('p1');
      wbsProvider.setup(
        projectName: 'Chipata—Lundazi Road',
        framework: WBSFramework.waterfallDeliverable,
        methodology: ProjectMethodology.waterfall,
        projectId: 'p1',
      );
      wbsProvider.syncMethodology(ProjectMethodology.hybrid);
      expect(wbsProvider.wbs!.methodology, ProjectMethodology.hybrid);
      // Epics and Features, not waterfall Deliverables.
      expect(wbsProvider.wbs!.framework, WBSFramework.agile);
      expect(wbsProvider.wbs!.framework.level1Label, 'Epic');
      expect(wbsProvider.wbs!.framework.level2Label, 'Feature');
      expect(wbsProvider.wbs!.framework.level3Label, 'User Story');
    });

    testWidgets(
        'hybrid badge shows Hybrid while the breakdown uses Epics/Features',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final wbsProvider = WBSProvider();
      await tester.runAsync(() => wbsProvider.ensureProjectLoaded('p1'));
      wbsProvider.setup(
        projectName: 'Chipata—Lundazi Road',
        framework: WBSFramework.waterfallDeliverable,
        methodology: ProjectMethodology.waterfall,
        projectId: 'p1',
      );
      wbsProvider.setViewMode(true); // avoid Firebase-backed cost linking
      // Project Details switched to Hybrid — module screen syncs post-frame.
      wbsProvider.syncMethodology(ProjectMethodology.hybrid);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<WBSProvider>.value(value: wbsProvider),
            ChangeNotifierProvider<CostEstimateProvider>(
              create: (_) => CostEstimateProvider(),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: WBSBuilderScreen())),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Hybrid badge, agile breakdown labels.
      expect(find.text('Hybrid'), findsOneWidget);
      expect(find.textContaining('Agile WBS'), findsOneWidget);
      expect(find.textContaining('Generate Epic'), findsOneWidget);
      expect(find.textContaining('Deliverable-Based'), findsNothing);
    });
  });

  group('Schedule delivery model sync', () {
    test('syncDeliveryModel updates basis in place and keeps activities',
        () {
      final provider = ScheduleProvider();
      provider.setup(projectName: 'P', deliveryModel: 'WATERFALL');
      provider.syncDeliveryModel('agile'); // case-insensitive normalization
      expect(provider.schedule!.basis.deliveryModel, 'AGILE');
      // No-op when already in sync.
      provider.syncDeliveryModel('AGILE');
      expect(provider.schedule!.basis.deliveryModel, 'AGILE');
    });

    testWidgets('schedule delivery-model badge updates live on sync',
        (tester) async {
      final scheduleProvider = ScheduleProvider();
      scheduleProvider.setup(
        projectName: 'Chipata—Lundazi Road',
        deliveryModel: 'WATERFALL',
      );

      // Mirrors the schedule builder header subtitle
      // (builder_screen.dart: '${schedule.basis.deliveryModel} delivery · …').
      await tester.pumpWidget(
        ChangeNotifierProvider<ScheduleProvider>.value(
          value: scheduleProvider,
          child: const MaterialApp(
            home: Scaffold(body: _ScheduleDeliveryModelBadge()),
          ),
        ),
      );
      expect(find.text('WATERFALL delivery'), findsOneWidget);

      // Project Details switches to Agile — schedule module screen calls
      // syncDeliveryModel post-frame; the badge must rebuild immediately.
      scheduleProvider.syncDeliveryModel('AGILE');
      await tester.pump();

      expect(find.text('AGILE delivery'), findsOneWidget);
      expect(find.text('WATERFALL delivery'), findsNothing);
    });

    test(
        'switching methodology in Project Details updates the schedule badge '
        'end-to-end (resolve → map → sync)', () {
      for (final entry in {
        'Agile': 'AGILE',
        'Hybrid': 'HYBRID',
        'Waterfall': 'WATERFALL',
      }.entries) {
        final provider = ScheduleProvider();
        provider.setup(projectName: 'P', deliveryModel: 'WATERFALL');

        // User picks the methodology on the Project Details screen —
        // captured as overallFramework on the central ProjectDataModel.
        final data = ProjectDataModel()..overallFramework = entry.key;

        // Exactly what the schedule module screen does on rebuild:
        final resolved = ProjectDataHelper.resolvedProjectMethodology(data);
        provider.syncDeliveryModel(
            ProjectDataHelper.deliveryModelForMethodology(resolved));

        expect(provider.schedule!.basis.deliveryModel, entry.value,
            reason: 'overallFramework ${entry.key} must drive the schedule '
                'badge');
      }
    });

    test(
        'design-management methodology (Project Details) wins over stale '
        'overallFramework', () {
      final provider = ScheduleProvider();
      provider.setup(projectName: 'P', deliveryModel: 'WATERFALL');

      final data = ProjectDataModel()
        ..overallFramework = 'Waterfall'
        ..designManagementData =
            DesignManagementData(methodology: ProjectMethodology.hybrid);
      final resolved = ProjectDataHelper.resolvedProjectMethodology(data);
      provider.syncDeliveryModel(
          ProjectDataHelper.deliveryModelForMethodology(resolved));

      expect(provider.schedule!.basis.deliveryModel, 'HYBRID');
    });
  });
}

/// Harness mirroring the methodology-dependent header text rendered by the
/// schedule builder screen.
class _ScheduleDeliveryModelBadge extends StatelessWidget {
  const _ScheduleDeliveryModelBadge();

  @override
  Widget build(BuildContext context) {
    final schedule = context.watch<ScheduleProvider>().schedule!;
    return Text('${schedule.basis.deliveryModel} delivery');
  }
}
