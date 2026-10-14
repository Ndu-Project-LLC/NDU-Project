library;

/// PKCE and authorization-URL helpers for the browser OAuth flow.
///
/// Deliberately free of Flutter and platform imports so the exact request
/// shapes can be unit-tested (test/services/oauth_broker_test.dart). The server
/// half lives in `functions/oauth-broker.js`, which builds the mirror image of
/// these URLs.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A PKCE verifier and its S256 challenge (RFC 7636).
class PkcePair {
  const PkcePair({required this.verifier, required this.challenge});

  final String verifier;
  final String challenge;
}

/// The `{tenant}` placeholder used by tenant-scoped providers (SAP S/4HANA).
const String oauthTenantPlaceholder = '{tenant}';

/// Generates a PKCE pair.
///
/// [random] is injectable so a test can pin the output; production callers get
/// a cryptographically secure generator.
PkcePair generatePkce([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  final verifier = _base64UrlNoPadding(bytes);
  return PkcePair(verifier: verifier, challenge: challengeFor(verifier));
}

/// The S256 challenge for [verifier]: BASE64URL(SHA256(ASCII(verifier))).
String challengeFor(String verifier) {
  final digest = sha256.convert(utf8.encode(verifier));
  return _base64UrlNoPadding(digest.bytes);
}

String _base64UrlNoPadding(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// Expands the short subdomain form (`acme`) into the SAP tenant host, and
/// strips a full URL back to its host.
///
/// Mirrors `normalizeTenantHost` in `functions/oauth-broker.js` and
/// `IntegrationOAuthService.normalizeTenantHost`.
String normalizeTenantHost(String? raw) {
  var value = (raw ?? '').trim();
  if (value.isEmpty) return '';
  value = value.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
  for (final separator in const ['/', '?', '#']) {
    final index = value.indexOf(separator);
    if (index != -1) value = value.substring(0, index);
  }
  if (!value.contains('.') && !value.contains(':')) {
    return '$value.authentication.sap.hana.ondemand.com';
  }
  return value;
}

/// Substitutes the customer's tenant into a templated endpoint.
String applyTenantHost(String endpoint, String? tenantHost) {
  if (!endpoint.contains(oauthTenantPlaceholder)) return endpoint;
  final host = normalizeTenantHost(tenantHost);
  if (host.isEmpty) {
    throw StateError(
        'This provider connects to a customer-specific tenant: enter the tenant host.');
  }
  return endpoint.replaceAll(oauthTenantPlaceholder, host);
}

/// Builds the URL the browser is sent to for consent.
///
/// [scopes] is omitted entirely when empty: providers that authorise through
/// their client registration (SAP S/4HANA) reject an empty `scope=`.
String buildAuthorizeUrl({
  required String authorizeUrl,
  required String clientId,
  required String redirectUri,
  required String state,
  required String codeChallenge,
  List<String> scopes = const [],
}) {
  final base = Uri.parse(authorizeUrl);
  return base.replace(queryParameters: {
    ...base.queryParameters,
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'response_type': 'code',
    'state': state,
    if (codeChallenge.isNotEmpty) ...{
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    },
    if (scopes.isNotEmpty) 'scope': scopes.join(' '),
  }).toString();
}

/// The parameters a provider handed back on the redirect.
class OAuthCallback {
  const OAuthCallback({
    this.code,
    this.state,
    this.error,
    this.errorDescription,
    this.realmId,
  });

  final String? code;
  final String? state;
  final String? error;
  final String? errorDescription;

  /// Some providers (QuickBooks) return the company id alongside the code.
  final String? realmId;

  bool get isSuccess =>
      (code ?? '').isNotEmpty && (error ?? '').isEmpty;

  /// Reads the callback out of a URL's query string.
  ///
  /// The fragment is accepted too: providers are inconsistent about which half
  /// of the redirect they put the code in.
  factory OAuthCallback.fromUri(Uri uri) {
    Map<String, String> params = uri.queryParameters;
    if (params.isEmpty && uri.fragment.isNotEmpty) {
      params = Uri.splitQueryString(uri.fragment);
    }
    String? value(String key) {
      final raw = params[key];
      return (raw == null || raw.isEmpty) ? null : raw;
    }

    return OAuthCallback(
      code: value('code'),
      state: value('state'),
      error: value('error'),
      errorDescription: value('error_description'),
      realmId: value('realmId') ?? value('realm_id'),
    );
  }

  static OAuthCallback fromUrl(String url) =>
      OAuthCallback.fromUri(Uri.parse(url));

  /// The keys the callback contributes, so the address bar can be cleaned.
  static const List<String> parameterNames = [
    'code',
    'state',
    'error',
    'error_description',
    'realmId',
    'realm_id',
  ];
}

/// Checks a callback against the request that started it.
///
/// Returns null when the callback is good, otherwise a user-facing reason.
String? validateCallback(OAuthCallback callback, {required String expectedState}) {
  if (!callback.isSuccess) {
    final detail = callback.errorDescription ?? callback.error;
    return detail == null || detail.isEmpty
        ? 'The provider did not return an authorization code.'
        : 'The provider refused the request: $detail';
  }
  if (expectedState.isNotEmpty && callback.state != expectedState) {
    return 'This sign-in response does not belong to the request that started it — start again.';
  }
  return null;
}
