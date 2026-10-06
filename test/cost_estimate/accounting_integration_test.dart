// The Accounting screen's provider rows are real OAuth 2.0 connectors.
//
// Before this work, tapping a provider ran `await Future.delayed(1500ms)` and
// then declared itself "connected" — a fake. These tests pin down what the
// four providers in the picker (QuickBooks Online, Xero, Sage Intacct and
// SAP S/4HANA) actually do now:
//
//   1. each one maps onto a live OAuth configuration with the vendor's own
//      endpoints and scopes;
//   2. tapping one opens the credentials modal (redirect URI + client
//      credentials), and cancelling connects nothing;
//   3. completing it stores the granted scopes on the estimate and only then
//      shows the connection as live;
//   4. a stored connection is verified against the token store, and a
//      provider that is genuinely no longer authorised is cleared instead of
//      being shown as connected;
//   5. disconnect clears it again.
//
// The OAuth dance itself is replaced by the service's `connectOverride` /
// `statusOverride` seams, so no network, no Firebase and no platform plugin
// are involved.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/providers/cost_estimate_provider.dart';
import 'package:ndu_project/cost_estimate/screens/accounting_screen.dart';
import 'package:ndu_project/cost_estimate/services/accounting_integration_service.dart';
import 'package:ndu_project/services/integration_oauth_service.dart';

CostEstimateProvider seededProvider() {
  final provider = CostEstimateProvider();
  provider.setup(
    projectName: 'Lusaka 32 — Accounting',
    className: EstimateClass.class3,
    deliveryModel: DeliveryModel.waterfall,
    projectId: 'lusaka-32',
  );
  return provider;
}

/// Pumps the real [AccountingScreen] on a surface wide enough for its
/// two-column body, optionally seeding the estimate first.
Future<CostEstimateProvider> pumpAccounting(
  WidgetTester tester, {
  void Function(CostEstimateProvider provider)? seed,
}) async {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final provider = seededProvider();
  seed?.call(provider);

  await tester.pumpWidget(
    ChangeNotifierProvider<CostEstimateProvider>.value(
      value: provider,
      child: const MaterialApp(home: Scaffold(body: AccountingScreen())),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

/// A connected Xero record, as a completed authorisation leaves it.
const AccountingIntegration connectedXero = AccountingIntegration(
  provider: AccountingProvider.xero,
  connected: true,
  connectedAt: null,
  glMapping: [],
  accountLabel: 'Acme Ltd',
  scopes: ['accounting.transactions'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AccountingIntegrationService.connectOverride = null;
    AccountingIntegrationService.statusOverride = null;
    AccountingIntegrationService.renewOverride = null;
  });

  tearDown(() {
    AccountingIntegrationService.connectOverride = null;
    AccountingIntegrationService.statusOverride = null;
    AccountingIntegrationService.renewOverride = null;
  });

  group('provider connectors', () {
    test('every offered provider maps onto a real OAuth connector', () {
      const expected = {
        AccountingProvider.quickbooks: IntegrationProvider.quickBooks,
        AccountingProvider.xero: IntegrationProvider.xero,
        AccountingProvider.sage: IntegrationProvider.sage,
        AccountingProvider.sap: IntegrationProvider.sap,
      };

      expected.forEach((accounting, oauth) {
        expect(
          AccountingIntegrationService.oauthProviderFor(accounting),
          oauth,
          reason: '${accounting.label} must be wired to a real connector',
        );
        expect(
          AccountingIntegrationService.businessSystemFor(accounting),
          isNotNull,
          reason: '${accounting.label} must have a business-system record',
        );
        expect(
          AccountingIntegrationService.requiresTenantHost(accounting),
          accounting == AccountingProvider.sap,
        );
      });

      expect(
          AccountingIntegrationService.oauthProviderFor(AccountingProvider.none),
          isNull);
    });

    test('each provider authorises against its own vendor endpoints', () {
      final quickbooks = AccountingIntegrationService.configFor(
          AccountingProvider.quickbooks)!;
      expect(quickbooks.authorizationEndpoint,
          'https://appcenter.intuit.com/connect/oauth2');
      expect(quickbooks.tokenEndpoint,
          'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer');
      expect(quickbooks.scopes, contains('com.intuit.quickbooks.accounting'));

      final xero =
          AccountingIntegrationService.configFor(AccountingProvider.xero)!;
      expect(xero.authorizationEndpoint,
          'https://login.xero.com/identity/connect/authorize');
      expect(xero.tokenEndpoint, 'https://identity.xero.com/connect/token');
      expect(xero.scopes, contains('accounting.transactions'));

      final sage =
          AccountingIntegrationService.configFor(AccountingProvider.sage)!;
      expect(sage.authorizationEndpoint,
          'https://api.intacct.com/ia/api/v1/oauth2/authorize');
      expect(sage.tokenEndpoint,
          'https://api.intacct.com/ia/api/v1/oauth2/token');
      expect(sage.scopes, contains('offline_access'));

      // SAP S/4HANA authorises against the customer's own tenant.
      expect(
          AccountingIntegrationService.configFor(AccountingProvider.sap),
          isNull,
          reason: 'a tenant-scoped provider has no URL until the host is known');
      final sap = AccountingIntegrationService.configFor(
        AccountingProvider.sap,
        tenantHost: 'https://acme.authentication.sap.hana.ondemand.com/oauth/authorize',
      )!;
      expect(sap.authorizationEndpoint,
          'https://acme.authentication.sap.hana.ondemand.com/oauth/authorize');
      expect(sap.tokenEndpoint,
          'https://acme.authentication.sap.hana.ondemand.com/oauth/token');
      // The short subdomain form expands to the full tenant host.
      final shortHost = AccountingIntegrationService.configFor(
          AccountingProvider.sap, tenantHost: 'acme')!;
      expect(shortHost.tokenEndpoint,
          'https://acme.authentication.sap.hana.ondemand.com/oauth/token');
      // S/4HANA authorises through its client registration, not a scope list.
      expect(sap.scopes, isEmpty);
    });

    test('the redirect URI matches the one registered on the devices',
        () {
      expect(AccountingIntegrationService.redirectUri,
          'nduproject://oauth2redirect');
    });

    test('a connection round-trips through the estimate\'s storage', () {
      final writer = CostEstimateProvider();
      writer.setup(
        projectName: 'Accounting round-trip',
        className: EstimateClass.class3,
        deliveryModel: DeliveryModel.waterfall,
      );
      writer.updateAccounting(const AccountingIntegration(
        provider: AccountingProvider.sage,
        connected: true,
        connectedAt: null,
        glMapping: [
          AccountingGLMapping(
            category: CostCategory.labor,
            glCode: '5000',
            glName: 'Direct Labor',
          ),
        ],
        accountLabel: 'Acme Entity',
        scopes: ['openid', 'offline_access'],
      ));

      // Serialization contract used by the provider's save/load path.
      final decoded = jsonDecode(jsonEncode(
        writer.estimate!.accountingIntegration!.toJson(),
      )) as Map<String, dynamic>;
      final restored = AccountingIntegration.fromJson(decoded);
      expect(restored.provider, AccountingProvider.sage);
      expect(restored.connected, isTrue);
      expect(restored.accountLabel, 'Acme Entity');
      expect(restored.scopes, ['openid', 'offline_access']);
      expect(restored.glMapping.length, 1);
      expect(restored.glMapping.first.category, CostCategory.labor);
      expect(restored.glMapping.first.glCode, '5000');
    });
  });

  group('Accounting screen', () {
    testWidgets('offers the four providers as OAuth connections',
        (tester) async {
      await pumpAccounting(tester);

      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('Pick a provider below to connect'), findsOneWidget);
      for (final label in const [
        'QuickBooks Online',
        'Xero',
        'Sage Intacct',
        'SAP S/4HANA',
      ]) {
        expect(find.text(label), findsOneWidget, reason: '$label row');
      }
      expect(find.text('OAuth 2.0 · Secure connection'), findsNWidgets(4));
    });

    testWidgets('tapping a provider opens the credentials modal',
        (tester) async {
      await pumpAccounting(tester);

      await tester.tap(find.text('QuickBooks Online'));
      await tester.pumpAndSettle();

      expect(find.text('Connect QuickBooks Online'), findsOneWidget);
      final redirect = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(redirect.data, AccountingIntegrationService.redirectUri);
      expect(find.byType(TextField), findsNWidgets(2),
          reason: 'client ID + client secret');
      expect(
          find.textContaining('com.intuit.quickbooks.accounting'), findsOneWidget,
          reason: 'the requested scopes are shown before authorising');

      // Cancelling must connect nothing.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Connect QuickBooks Online'), findsNothing);
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('LIVE'), findsNothing);
    });

    testWidgets('a completed authorisation is what marks the provider live',
        (tester) async {
      String? capturedClientId;
      AccountingProvider? capturedProvider;
      AccountingIntegrationService.connectOverride =
          (provider, clientId, clientSecret, tenantHost) async {
        capturedProvider = provider;
        capturedClientId = clientId;
        return AccountingConnection(
          connected: true,
          connectedAt: DateTime(2026, 10, 1, 9, 30),
          scopes: const ['com.intuit.quickbooks.accounting'],
          accountLabel: provider.label,
        );
      };

      final provider = await pumpAccounting(tester);

      await tester.tap(find.text('QuickBooks Online'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'client-123');
      await tester.tap(find.text('Continue with QuickBooks Online'));
      await tester.pumpAndSettle();

      expect(capturedProvider, AccountingProvider.quickbooks);
      expect(capturedClientId, 'client-123',
          reason: 'the credentials from the modal reach the provider');

      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
      expect(find.text('OAuth 2.0 · Secure connection'), findsNothing,
          reason: 'the picker is replaced once connected');

      final record = provider.estimate!.accountingIntegration!;
      expect(record.provider, AccountingProvider.quickbooks);
      expect(record.connected, isTrue);
      expect(record.scopes, ['com.intuit.quickbooks.accounting']);
      expect(record.connectedAt, DateTime(2026, 10, 1, 9, 30));
    });

    testWidgets('a failed authorisation leaves the provider disconnected',
        (tester) async {
      AccountingIntegrationService.connectOverride =
          (provider, clientId, clientSecret, tenantHost) async =>
              const AccountingConnection(
        connected: false,
        message: 'access_denied',
      );

      final provider = await pumpAccounting(tester);

      await tester.tap(find.text('Xero'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'client-123');
      await tester.tap(find.text('Continue with Xero'));
      await tester.pumpAndSettle();

      expect(find.text('LIVE'), findsNothing);
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.textContaining('Could not connect Xero'), findsOneWidget);
      expect(provider.estimate!.accountingIntegration?.connected ?? false,
          isFalse);
    });

    testWidgets('SAP asks for its tenant host before authorising',
        (tester) async {
      String? capturedTenant;
      AccountingIntegrationService.connectOverride =
          (provider, clientId, clientSecret, tenantHost) async {
        capturedTenant = tenantHost;
        return AccountingConnection(
          connected: true,
          connectedAt: DateTime(2026, 10, 2, 8),
          scopes: const [],
          accountLabel: 'acme.authentication.sap.hana.ondemand.com',
        );
      };

      await pumpAccounting(tester);

      await tester.tap(find.text('SAP S/4HANA'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(3),
          reason: 'client ID + secret + tenant host');

      await tester.enterText(find.byType(TextField).at(0), 'client-123');
      await tester.enterText(find.byType(TextField).at(2), 'acme');
      await tester.tap(find.text('Continue with SAP S/4HANA'));
      await tester.pumpAndSettle();

      expect(capturedTenant, 'acme');
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.textContaining('acme.authentication.sap.hana.ondemand.com'),
          findsOneWidget);
    });

    testWidgets('a stored connection is verified against the token store',
        (tester) async {
      AccountingIntegrationService.statusOverride = (_) async =>
          const AccountingConnection(
            connected: true,
            scopes: ['accounting.transactions'],
            accountLabel: 'Acme Ltd',
          );

      await pumpAccounting(
        tester,
        seed: (provider) => provider.updateAccounting(connectedXero),
      );

      expect(find.text('Xero'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.textContaining('Acme Ltd'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
    });

    testWidgets('an unreadable store never clears a real connection',
        (tester) async {
      AccountingIntegrationService.statusOverride =
          (_) async => AccountingConnection.unknown;

      final provider = await pumpAccounting(
        tester,
        seed: (provider) => provider.updateAccounting(connectedXero),
      );

      expect(find.text('LIVE'), findsOneWidget);
      expect(provider.estimate!.accountingIntegration!.connected, isTrue,
          reason: 'a storage read failure must not delete the connection');
    });

    testWidgets('a provider that is no longer authorised is cleared',
        (tester) async {
      AccountingIntegrationService.statusOverride =
          (_) async => AccountingConnection.none;
      // A lapsed connection is renewed before it is cleared, so the scenario
      // has to say what the provider did with that renewal: refused.
      AccountingIntegrationService.renewOverride =
          (_) async => AccountingConnection.none;

      final provider = await pumpAccounting(
        tester,
        seed: (provider) => provider.updateAccounting(connectedXero),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('LIVE'), findsNothing);
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.textContaining('no longer authorised'), findsOneWidget);
      expect(provider.estimate!.accountingIntegration!.connected, isFalse,);
      expect(provider.estimate!.accountingIntegration!.provider,
          AccountingProvider.none);
    });

    testWidgets('disconnect clears the connection', (tester) async {
      AccountingIntegrationService.statusOverride = (_) async =>
          const AccountingConnection(connected: true, accountLabel: 'Acme Ltd');

      final provider = await pumpAccounting(
        tester,
        seed: (provider) => provider.updateAccounting(connectedXero),
      );
      expect(find.text('Disconnect'), findsOneWidget);

      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('LIVE'), findsNothing);
      expect(find.text('QuickBooks Online'), findsOneWidget,
          reason: 'the provider picker comes back');
      expect(provider.estimate!.accountingIntegration!.connected, isFalse);
    });
  });
}
