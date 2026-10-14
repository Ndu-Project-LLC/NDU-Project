// The program dashboard's "Business systems" card is the roll-up of every
// connected CRM / ERP / accounting system in a program.
//
// Systems get connected in two different places, and the card has to show
// both:
//
//   * the program's own connect screen
//     (`programs/{programId}/businessIntegrations/{providerName}`), and
//   * the module connectors — the Cost Estimate's QuickBooks Online / Xero /
//     Sage / SAP accounting providers — which are recorded against one
//     project (`projects/{projectId}/businessIntegrations/{providerName}`).
//
// Before this, the card only read the program scope, so an accounting
// connection made on a cost estimate never showed up here. These tests pin
// down the merge: both scopes appear, one row per provider, and the most
// recently written record wins when a provider is recorded in both.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/services/business_system_integration_service.dart';
import 'package:ndu_project/widgets/aggregated_business_systems_card.dart';

/// A connected record, as the connect flow leaves it.
BusinessSystemIntegration connected(
  BusinessSystemProvider provider, {
  DateTime? updatedAt,
  DateTime? lastSyncAt,
}) {
  return BusinessSystemIntegration.disconnected(
    provider,
    'uid-1',
    'owner@example.com',
  ).copyWith(
    status: IntegrationStatus.connected,
    lastSyncAt: lastSyncAt,
    updatedAt: updatedAt,
  );
}

/// A disconnected (or never-connected) record.
BusinessSystemIntegration disconnectedAt(
  BusinessSystemProvider provider,
  DateTime updatedAt,
) {
  return BusinessSystemIntegration.disconnected(
    provider,
    'uid-1',
    'owner@example.com',
  ).copyWith(updatedAt: updatedAt);
}

Future<void> pumpCard(
  WidgetTester tester, {
  String programId = 'program-1',
  List<String>? projectIds = const ['project-1'],
}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: AggregatedBusinessSystemsCard(
          programId: programId,
          projectIds: projectIds,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BusinessSystemIntegrationService.loadAllOverride = null;
    BusinessSystemIntegrationService.projectIntegrationsOverride = null;
  });

  tearDown(() {
    BusinessSystemIntegrationService.loadAllOverride = null;
    BusinessSystemIntegrationService.projectIntegrationsOverride = null;
  });

  group('mergeByProvider', () {
    test('keeps one record per provider', () {
      final merged = BusinessSystemIntegrationService.mergeByProvider(
        [
          disconnectedAt(BusinessSystemProvider.salesforce, DateTime(2026, 1, 1)),
        ],
        [
          connected(BusinessSystemProvider.quickbooks,
              updatedAt: DateTime(2026, 2, 1)),
        ],
      );

      expect(merged.map((i) => i.provider).toSet(), {
        BusinessSystemProvider.salesforce,
        BusinessSystemProvider.quickbooks,
      });
    });

    test('the most recently written record of a provider wins', () {
      // Program scope connected in March…
      final program = connected(BusinessSystemProvider.xero,
          updatedAt: DateTime(2026, 3, 1));
      // …project scope disconnected in January.
      final project = disconnectedAt(
          BusinessSystemProvider.xero, DateTime(2026, 1, 1));

      final stale = BusinessSystemIntegrationService.mergeByProvider(
          [program], [project]);
      expect(stale.single.status, IntegrationStatus.connected,
          reason: 'the January record must not overwrite the March one');

      // …and the other way round, the newer project record wins.
      final fresh = BusinessSystemIntegrationService.mergeByProvider(
        [disconnectedAt(BusinessSystemProvider.xero, DateTime(2026, 1, 1))],
        [connected(BusinessSystemProvider.xero,
            updatedAt: DateTime(2026, 3, 1))],
      );
      expect(fresh.single.status, IntegrationStatus.connected);
    });

    test('an unknown project list reads nothing', () async {
      expect(
        await BusinessSystemIntegrationService.loadAllForProjects(const []),
        isEmpty,
      );
    });
  });

  group('roll-up card', () {
    testWidgets('shows a connection made on a project, not just the program',
        (tester) async {
      List<String>? requestedProjects;

      // The program's own connect screen recorded a CRM system…
      BusinessSystemIntegrationService.loadAllOverride = (_) async => [
            connected(BusinessSystemProvider.salesforce,
                lastSyncAt: DateTime.now()),
          ];
      // …and the Cost Estimate connected Xero for one of its projects.
      BusinessSystemIntegrationService.projectIntegrationsOverride =
          (projectIds) async {
        requestedProjects = projectIds;
        return [
          connected(BusinessSystemProvider.xero, lastSyncAt: DateTime.now()),
        ];
      };

      await pumpCard(tester, projectIds: const ['project-1', 'project-2']);

      expect(requestedProjects, ['project-1', 'project-2'],
          reason: 'the card must ask for the program\'s own projects');
      expect(find.text('Salesforce'), findsOneWidget);
      expect(find.text('Xero'), findsOneWidget,
          reason: 'an accounting connection made on a project is part of the '
              'program roll-up');
      expect(find.text('CRM · 1'), findsOneWidget);
      expect(find.text('Accounting · 1'), findsOneWidget);
      expect(find.text('ERP · 0'), findsOneWidget);
      expect(find.text('No business systems connected'), findsNothing);
    });

    testWidgets('a provider connected on a project appears once',
        (tester) async {
      BusinessSystemIntegrationService.loadAllOverride = (_) async => [
            disconnectedAt(BusinessSystemProvider.quickbooks,
                DateTime(2026, 1, 1)),
          ];
      BusinessSystemIntegrationService.projectIntegrationsOverride =
          (_) async => [
                connected(BusinessSystemProvider.quickbooks,
                    updatedAt: DateTime(2026, 2, 1),
                    lastSyncAt: DateTime.now()),
              ];

      await pumpCard(tester);

      expect(find.text('QuickBooks Online'), findsOneWidget,
          reason: 'one row per provider, not one per scope');
      expect(find.text('Accounting · 1'), findsOneWidget);
    });

    testWidgets('a project disconnect removes the program-level row',
        (tester) async {
      // Connected at program level in January, disconnected on the project in
      // March — the newer record is the truth.
      BusinessSystemIntegrationService.loadAllOverride = (_) async => [
            connected(BusinessSystemProvider.sap,
                updatedAt: DateTime(2026, 1, 1)),
          ];
      BusinessSystemIntegrationService.projectIntegrationsOverride =
          (_) async => [
                disconnectedAt(BusinessSystemProvider.sap, DateTime(2026, 3, 1)),
              ];

      await pumpCard(tester);

      expect(find.text('SAP'), findsNothing);
      expect(find.text('Accounting · 1'), findsNothing,
          reason: 'a disconnected system is not counted as connected');
      expect(find.text('No business systems connected'), findsOneWidget);
    });

    testWidgets('empty state when nothing is connected anywhere',
        (tester) async {
      BusinessSystemIntegrationService.loadAllOverride = (_) async => [];
      BusinessSystemIntegrationService.projectIntegrationsOverride =
          (_) async => [];

      await pumpCard(tester);

      expect(find.text('No business systems connected'), findsOneWidget);
      expect(find.text('Connect a system'), findsOneWidget);
    });
  });
}
