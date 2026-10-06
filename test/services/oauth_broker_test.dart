// Tests for the server-brokered OAuth flow.
//
// The web build cannot exchange a confidential client's authorization code in
// the browser, so it hands the browser to the provider and lets
// functions/oauth-broker.js redeem the code. These tests pin the two halves of
// that contract the app owns: the PKCE/authorize request it sends, and the
// parsing/validation of what comes back. The server side is covered by
// functions/test/oauth-broker.test.js (npm test in functions/).
//
// What is NOT covered here: the real browser round trip against a live vendor,
// which needs registered client credentials.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/cost_estimate/services/accounting_integration_service.dart';
import 'package:ndu_project/services/backend_oauth_broker.dart';
import 'package:ndu_project/services/integration_oauth_service.dart';
import 'package:ndu_project/services/oauth_pkce.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => BackendOAuthBroker.callableOverride = null);

  group('PKCE', () {
    test('the S256 challenge matches the RFC 7636 test vector', () {
      // RFC 7636 Appendix B.
      expect(
        challengeFor('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('a generated pair is a valid verifier with its own challenge', () {
      final pair = generatePkce();
      // 32 random bytes, base64url, unpadded → 43 characters within the
      // 43-128 range the spec allows.
      expect(pair.verifier.length, 43);
      expect(RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(pair.verifier), isTrue);
      expect(pair.challenge, challengeFor(pair.verifier));
      expect(pair.challenge, isNot(pair.verifier));

      final other = generatePkce();
      expect(other.verifier, isNot(pair.verifier));
    });
  });

  group('tenant host', () {
    test('accepts a subdomain, a host and a full URL, like the broker does', () {
      expect(normalizeTenantHost('acme'),
          'acme.authentication.sap.hana.ondemand.com');
      expect(normalizeTenantHost('acme.authentication.sap.hana.ondemand.com'),
          'acme.authentication.sap.hana.ondemand.com');
      expect(
        normalizeTenantHost(
            'https://acme.authentication.sap.hana.ondemand.com/oauth/authorize?x=1'),
        'acme.authentication.sap.hana.ondemand.com',
      );
      expect(normalizeTenantHost('  '), '');
    });

    test('a templated endpoint needs a tenant, a fixed one does not', () {
      expect(
        applyTenantHost('https://{tenant}/oauth/token', 'acme'),
        'https://acme.authentication.sap.hana.ondemand.com/oauth/token',
      );
      expect(
        applyTenantHost('https://identity.xero.com/connect/token', null),
        'https://identity.xero.com/connect/token',
      );
      expect(() => applyTenantHost('https://{tenant}/oauth/token', ''),
          throwsA(isA<StateError>()));
    });
  });

  group('authorization request', () {
    test('carries PKCE, state and the scopes', () {
      final url = Uri.parse(buildAuthorizeUrl(
        authorizeUrl: 'https://appcenter.intuit.com/connect/oauth2',
        clientId: 'qb-id',
        redirectUri: 'https://nduproject.com/oauth/callback',
        state: 'state-1',
        codeChallenge: 'challenge-1',
        scopes: const ['com.intuit.quickbooks.accounting'],
      ));

      expect(url.origin + url.path, 'https://appcenter.intuit.com/connect/oauth2');
      expect(url.queryParameters['client_id'], 'qb-id');
      expect(url.queryParameters['redirect_uri'], 'https://nduproject.com/oauth/callback');
      expect(url.queryParameters['response_type'], 'code');
      expect(url.queryParameters['state'], 'state-1');
      expect(url.queryParameters['code_challenge'], 'challenge-1');
      expect(url.queryParameters['code_challenge_method'], 'S256');
      expect(url.queryParameters['scope'], 'com.intuit.quickbooks.accounting');
    });

    test('omits an empty scope, which SAP S/4HANA rejects', () {
      final url = Uri.parse(buildAuthorizeUrl(
        authorizeUrl: 'https://acme.authentication.sap.hana.ondemand.com/oauth/authorize',
        clientId: 'sap-id',
        redirectUri: 'https://nduproject.com/oauth/callback',
        state: 's',
        codeChallenge: 'c',
      ));
      expect(url.queryParameters.containsKey('scope'), isFalse);
    });

    test('keeps query parameters the endpoint already had', () {
      final url = Uri.parse(buildAuthorizeUrl(
        authorizeUrl: 'https://example.com/authorize?audience=api',
        clientId: 'id',
        redirectUri: 'https://nduproject.com/oauth/callback',
        state: 's',
        codeChallenge: 'c',
      ));
      expect(url.queryParameters['audience'], 'api');
      expect(url.queryParameters['client_id'], 'id');
    });
  });

  group('callback', () {
    test('reads the code out of the query string', () {
      final callback = OAuthCallback.fromUrl(
          'https://nduproject.com/oauth/callback?code=abc&state=state-1');
      expect(callback.code, 'abc');
      expect(callback.state, 'state-1');
      expect(callback.isSuccess, isTrue);
      expect(validateCallback(callback, expectedState: 'state-1'), isNull);
    });

    test('accepts parameters from the fragment too', () {
      final callback = OAuthCallback.fromUrl(
          'https://nduproject.com/oauth/callback#code=abc&state=s');
      expect(callback.code, 'abc');
    });

    test('reads the QuickBooks realm id when the provider sends one', () {
      final callback = OAuthCallback.fromUrl(
          'https://nduproject.com/oauth/callback?code=abc&state=s&realmId=913035');
      expect(callback.realmId, '913035');
    });

    test('a mismatched state is refused', () {
      final callback = OAuthCallback.fromUrl(
          'https://nduproject.com/oauth/callback?code=abc&state=other');
      expect(
        validateCallback(callback, expectedState: 'state-1'),
        contains('does not belong'),
      );
    });

    test('a provider refusal is surfaced with its reason', () {
      final callback = OAuthCallback.fromUrl(
          'https://nduproject.com/oauth/callback?error=access_denied&error_description=user%20refused');
      expect(callback.isSuccess, isFalse);
      final problem = validateCallback(callback, expectedState: 's');
      expect(problem, contains('user refused'));
    });

    test('no code at all is not treated as success', () {
      final callback = OAuthCallback.fromUrl('https://nduproject.com/oauth/callback');
      expect(callback.isSuccess, isFalse);
      expect(validateCallback(callback, expectedState: 's'), isNotNull);
    });
  });

  group('broker client', () {
    test('an unconfigured server provider is not ready, and never exposes a secret', () async {
      final calls = <String>[];
      BackendOAuthBroker.callableOverride = (name, payload) async {
        calls.add(name);
        return {
          'provider': 'quickbooks',
          'label': 'QuickBooks Online',
          'clientId': '',
          'authorizeUrl': 'https://appcenter.intuit.com/connect/oauth2',
          'scopes': const ['com.intuit.quickbooks.accounting'],
          'requiresTenantHost': false,
          'configured': false,
        };
      };

      final config = await BackendOAuthBroker.instance.providerConfig('quickbooks');
      expect(calls, ['oauthProviderConfig']);
      expect(config.provider, 'quickbooks');
      expect(config.displayLabel, 'QuickBooks Online');
      expect(config.requiresTenantHost, isFalse);
      expect(config.isReady, isFalse,
          reason: 'without server credentials there is nothing to connect to');
    });

    test('a configured provider reports the public client id and scopes', () async {
      BackendOAuthBroker.callableOverride = (name, payload) async => {
            'provider': 'xero',
            'label': 'Xero',
            'clientId': 'xero-public-id',
            'authorizeUrl': 'https://login.xero.com/identity/connect/authorize',
            'scopes': const ['openid', 'accounting.transactions', 'offline_access'],
            'requiresTenantHost': false,
            'configured': true,
          };

      final config = await BackendOAuthBroker.instance.providerConfig('xero');
      expect(config.isReady, isTrue);
      expect(config.clientId, 'xero-public-id');
      expect(config.scopes, contains('accounting.transactions'));
    });

    test('connecting to an unconfigured provider fails before navigating', () async {
      BackendOAuthBroker.callableOverride = (name, payload) async => {
            'provider': 'sage',
            'label': 'Sage Intacct',
            'clientId': '',
            'authorizeUrl': 'https://api.intacct.com/ia/api/v1/oauth2/authorize',
            'scopes': const <String>[],
            'requiresTenantHost': false,
            'configured': false,
          };

      await expectLater(
        BackendOAuthBroker.instance.beginConnect(provider: 'sage'),
        throwsA(isA<StateError>()),
      );
    });

    test('there is nothing to complete when no attempt is pending', () async {
      expect(await BackendOAuthBroker.instance.completePendingConnect(), isNull);
      expect(await BackendOAuthBroker.instance.hasPendingAttempt(), isFalse);
    });

    test('the broker is only used where a browser exists', () {
      // Tests run on the VM, so this build must take the native path.
      expect(BackendOAuthBroker.isSupported, isFalse);
      expect(BackendOAuthBroker.redirectUriForCurrentOrigin(),
          BackendOAuthBroker.fallbackRedirectUri);
    });
  });

  group('accounting service wiring', () {
    test('credentials are only asked for where the broker is unavailable', () {
      expect(AccountingIntegrationService.requiresClientCredentials,
          !AccountingIntegrationService.usesServerBroker);
    });

    test('the URI shown in the modal matches the build', () {
      expect(AccountingIntegrationService.redirectUriForCurrentBuild(),
          IntegrationOAuthService.redirectUri);
    });

    test('every connector maps back to its accounting provider', () {
      for (final provider in const [
        AccountingProvider.quickbooks,
        AccountingProvider.xero,
        AccountingProvider.sage,
        AccountingProvider.sap,
      ]) {
        final oauth = AccountingIntegrationService.oauthProviderFor(provider);
        expect(oauth, isNotNull);
        expect(AccountingIntegrationService.accountingProviderFor(oauth!), provider);
      }
    });

    test('completing a brokered connect is a no-op off the web build', () async {
      expect(await AccountingIntegrationService.completePendingBrokerConnect(), isNull);
      expect(await AccountingIntegrationService.hasPendingBrokerConnect(), isFalse);
    });
  });
}
