// A lapsed accounting connection must be renewed, not dropped.
//
// Before this, an access token that expired made the screen clear the
// connection ("X is no longer authorised") even though the provider had issued
// a refresh token. These tests pin the new behaviour:
//
//   1. a live connection is never renewed (no needless round trip);
//   2. a lapsed token with a refresh token is renewed in place — the ledger
//      stays connected and only the expiry/scopes move;
//   3. a renewal the provider refuses reports the connection as lost, honestly;
//   4. an unreadable store still never deletes a real connection.
//
// The renewal transport itself (flutter_appauth on native, the broker on web) is
// replaced by the service seam, exactly like the connect flow.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/screens/accounting_screen.dart';
import 'package:ndu_project/cost_estimate/services/accounting_integration_service.dart';

/// An expired Xero connection: connected when it was made, lapsed since.
final AccountingIntegration expiredXero = AccountingIntegration(
  provider: AccountingProvider.xero,
  connected: true,
  connectedAt: DateTime(2026, 9, 1, 8),
  glMapping: const [],
  accountLabel: 'Acme Ltd',
  scopes: const ['accounting.transactions'],
  expiresAt: DateTime(2026, 9, 1, 9),
);

Future<CostEstimateProvider> pumpAccounting(
  WidgetTester tester, {
  required void Function(CostEstimateProvider provider) seed,
}) async {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final provider = CostEstimateProvider();
  provider.setup(
    projectName: 'Lusaka 32 — Renewal',
    className: EstimateClass.class3,
    deliveryModel: DeliveryModel.waterfall,
    projectId: 'lusaka-32',
  );
  seed(provider);

  await tester.pumpWidget(
    ChangeNotifierProvider<CostEstimateProvider>.value(
      value: provider,
      child: const MaterialApp(home: Scaffold(body: AccountingScreen())),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AccountingIntegrationService.statusOverride = null;
    AccountingIntegrationService.renewOverride = null;
  });

  tearDown(() {
    AccountingIntegrationService.statusOverride = null;
    AccountingIntegrationService.renewOverride = null;
  });

  group('renewal decision', () {
    test('a live connection is not renewed', () async {
      var renewed = false;
      AccountingIntegrationService.statusOverride = (_) async =>
          const AccountingConnection(connected: true, accountLabel: 'Acme Ltd');
      AccountingIntegrationService.renewOverride = (_) async {
        renewed = true;
        return AccountingConnection.none;
      };

      final result = await AccountingIntegrationService.loadAndRenew(
          AccountingProvider.xero);

      expect(result.connected, isTrue);
      expect(renewed, isFalse, reason: 'no round trip for a live token');
    });

    test('a lapsed token is renewed and keeps the ledger connected', () async {
      AccountingIntegrationService.statusOverride = (_) async =>
          const AccountingConnection(connected: false);
      AccountingIntegrationService.renewOverride = (_) async =>
          AccountingConnection(
        connected: true,
        connectedAt: DateTime(2026, 10, 6, 12),
        scopes: const ['accounting.transactions'],
        expiresAt: DateTime(2026, 10, 6, 13),
      );

      final result = await AccountingIntegrationService.loadAndRenew(
          AccountingProvider.xero);

      expect(result.connected, isTrue);
      expect(result.expiresAt, DateTime(2026, 10, 6, 13));
      expect(result.scopes, ['accounting.transactions']);
    });

    test('a refused renewal reports the connection as lost', () async {
      AccountingIntegrationService.statusOverride = (_) async =>
          const AccountingConnection(connected: false);
      AccountingIntegrationService.renewOverride =
          (_) async => AccountingConnection.none;

      final result = await AccountingIntegrationService.loadAndRenew(
          AccountingProvider.xero);

      expect(result.connected, isFalse);
      expect(result.verified, isTrue,
          reason: 'a refusal is a verified answer, so callers may clear');
    });

    test('an unreadable store is never treated as expired', () async {
      var renewed = false;
      AccountingIntegrationService.statusOverride =
          (_) async => AccountingConnection.unknown;
      AccountingIntegrationService.renewOverride = (_) async {
        renewed = true;
        return AccountingConnection.none;
      };

      final result = await AccountingIntegrationService.loadAndRenew(
          AccountingProvider.xero);

      expect(result.verified, isFalse);
      expect(renewed, isFalse);
    });
  });

  group('Accounting screen renewal', () {
    testWidgets('a lapsed connection that renews stays live',
        (tester) async {
      AccountingIntegrationService.statusOverride = (_) async =>
          const AccountingConnection(connected: false);
      AccountingIntegrationService.renewOverride = (_) async =>
          AccountingConnection(
        connected: true,
        connectedAt: DateTime(2026, 10, 6, 12),
        scopes: const ['accounting.transactions'],
        expiresAt: DateTime(2026, 10, 6, 13),
      );

      final provider = await pumpAccounting(
        tester,
        seed: (provider) => provider.updateAccounting(expiredXero),
      );

      expect(find.textContaining('GL codes map to Xero'), findsOneWidget,
          reason: 'the ledger must not drop just because the token aged out');
      expect(find.textContaining('no longer authorised'), findsNothing);
      expect(find.textContaining('session renewed'), findsOneWidget);

      final record = provider.estimate!.accountingIntegration!;
      expect(record.connected, isTrue);
      expect(record.provider, AccountingProvider.xero);
      // The mapping and the authorised account survive the renewal.
      expect(record.accountLabel, 'Acme Ltd');
      expect(record.expiresAt, DateTime(2026, 10, 6, 13));
    });

    testWidgets('a refused renewal clears the connection', (tester) async {
      AccountingIntegrationService.statusOverride = (_) async =>
          const AccountingConnection(connected: false);
      AccountingIntegrationService.renewOverride =
          (_) async => AccountingConnection.none;

      final provider = await pumpAccounting(
        tester,
        seed: (provider) => provider.updateAccounting(expiredXero),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('GL codes map to Xero'), findsNothing);
      expect(find.text('No accounting system is connected to your account yet.'),
          findsOneWidget);
      expect(find.textContaining('no longer authorised'), findsOneWidget);
      expect(provider.estimate!.accountingIntegration!.connected, isFalse);
      expect(provider.estimate!.accountingIntegration!.provider,
          AccountingProvider.none);
    });

    testWidgets('an unreadable store leaves the connection alone',
        (tester) async {
      AccountingIntegrationService.statusOverride =
          (_) async => AccountingConnection.unknown;

      final provider = await pumpAccounting(
        tester,
        seed: (provider) => provider.updateAccounting(expiredXero),
      );

      expect(find.textContaining('GL codes map to Xero'), findsOneWidget);
      expect(provider.estimate!.accountingIntegration!.connected, isTrue);
    });
  });
}
