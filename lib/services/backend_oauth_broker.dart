library;

/// Client half of the server-side OAuth broker (`functions/oauth-broker.js`).
///
/// QuickBooks Online, Xero, Sage Intacct and SAP S/4HANA are confidential
/// OAuth clients: the token exchange needs the client secret, and the vendors
/// block the call from a browser. So on web the client never sees the secret —
/// it sends the browser to the provider with a PKCE challenge, comes back with
/// `?code=…`, and asks the broker to redeem it:
///
///   1. [providerConfig]      — what the browser needs (public client id, scopes)
///   2. [beginConnect]        — store the PKCE verifier + state, then navigate
///   3. [completePendingConnect] — validate the callback, exchange via the broker,
///                                hand the tokens to [IntegrationOAuthService]
///
/// Native builds do not use this: flutter_appauth runs the whole dance in-app.

import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:ndu_project/services/integration_oauth_service.dart';
import 'package:ndu_project/services/oauth_pkce.dart';
import 'package:ndu_project/services/web_oauth_flow.dart' as browser;

/// Tokens the broker redeemed on this app's behalf.
class BrokerTokens {
  const BrokerTokens({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.scopes = const [],
  });

  factory BrokerTokens.fromMap(Map<dynamic, dynamic> map) {
    final expiresRaw = map['expiresAt']?.toString();
    final scopes = (map['scopes'] as List<dynamic>?) ?? const <dynamic>[];
    return BrokerTokens(
      accessToken: map['accessToken']?.toString() ?? '',
      refreshToken: map['refreshToken']?.toString(),
      expiresAt: expiresRaw == null ? null : DateTime.tryParse(expiresRaw),
      scopes: scopes.map((s) => s.toString()).toList(growable: false),
    );
  }

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final List<String> scopes;
}

/// The public half of a provider's OAuth configuration, as reported by the
/// broker. Never contains the client secret.
class BrokerProviderConfig {
  const BrokerProviderConfig({
    required this.provider,
    required this.label,
    required this.clientId,
    required this.authorizeUrl,
    required this.scopes,
    required this.requiresTenantHost,
    required this.configured,
  });

  factory BrokerProviderConfig.fromMap(Map<dynamic, dynamic> map) {
    final scopes = (map['scopes'] as List<dynamic>?) ?? const <dynamic>[];
    return BrokerProviderConfig(
      provider: map['provider']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      clientId: map['clientId']?.toString() ?? '',
      authorizeUrl: map['authorizeUrl']?.toString() ?? '',
      scopes: scopes.map((s) => s.toString()).toList(growable: false),
      requiresTenantHost: map['requiresTenantHost'] == true,
      configured: map['configured'] == true,
    );
  }

  final String provider;
  final String label;
  final String clientId;
  final String authorizeUrl;
  final List<String> scopes;
  final bool requiresTenantHost;

  /// Whether the server holds credentials for this provider.
  final bool configured;

  /// Ready to start a consent screen.
  bool get isReady => configured && clientId.isNotEmpty && authorizeUrl.isNotEmpty;

  String get displayLabel => label.isEmpty ? provider : label;
}

/// A connect attempt waiting for the provider to send the browser back.
class _PendingAttempt {
  const _PendingAttempt({
    required this.provider,
    required this.verifier,
    required this.state,
    required this.redirectUri,
    this.tenantHost,
  });

  factory _PendingAttempt.fromJson(Map<String, dynamic> json) => _PendingAttempt(
        provider: json['provider']?.toString() ?? '',
        verifier: json['verifier']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        redirectUri: json['redirectUri']?.toString() ?? '',
        tenantHost: json['tenantHost']?.toString(),
      );

  final String provider;
  final String verifier;
  final String state;
  final String redirectUri;
  final String? tenantHost;

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'verifier': verifier,
        'state': state,
        'redirectUri': redirectUri,
        'tenantHost': tenantHost,
      };
}

class BackendOAuthBroker {
  BackendOAuthBroker._();

  static final BackendOAuthBroker instance = BackendOAuthBroker._();

  static const String _pendingKey = 'oauth_broker_pending_attempt';

  /// Registered on the vendor apps for the hosted deployment; used when the app
  /// is not served over https (a local `flutter run -d chrome` origin the
  /// vendor has no redirect for).
  static const String fallbackRedirectUri =
      'https://nduproject.com/oauth/callback';

  /// Test seam for the two callable functions.
  @visibleForTesting
  static Future<Map<String, dynamic>> Function(
    String name,
    Map<String, dynamic> payload,
  )? callableOverride;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Whether this build completes the flow through the broker.
  static bool get isSupported => kIsWeb && browser.isAvailable;

  /// The redirect URI to register with the provider for this deployment.
  static String redirectUriForCurrentOrigin() {
    final origin = browser.currentOrigin();
    if (origin.startsWith('https://')) return '$origin/oauth/callback';
    return fallbackRedirectUri;
  }

  Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> payload) async {
    final override = callableOverride;
    if (override != null) return override(name, payload);
    final callable = FirebaseFunctions.instance.httpsCallable(name);
    final result = await callable.call<Map<String, dynamic>>(payload);
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// What the browser needs to start consent for [provider].
  Future<BrokerProviderConfig> providerConfig(String provider) async {
    final data = await _call('oauthProviderConfig', {'provider': provider});
    return BrokerProviderConfig.fromMap(data);
  }

  /// Stores the PKCE verifier and state, then navigates to the provider.
  ///
  /// On web this does not return: the browser leaves the app and the provider
  /// sends it back to the redirect URI, where [completePendingConnect] finishes
  /// the job. Throws when the provider is not configured server-side, so the
  /// screen can say so instead of navigating to a dead end.
  Future<void> beginConnect({
    required String provider,
    String? tenantHost,
  }) async {
    final config = await providerConfig(provider);
    if (!config.isReady) {
      throw StateError(
          '${config.displayLabel} is not configured on the server yet. Add its client credentials to the Cloud Functions environment.');
    }

    final redirectUri = redirectUriForCurrentOrigin();
    final pkce = generatePkce();
    final state = _newState();
    final authorizeUrl = buildAuthorizeUrl(
      authorizeUrl: applyTenantHost(config.authorizeUrl, tenantHost),
      clientId: config.clientId,
      redirectUri: redirectUri,
      state: state,
      codeChallenge: pkce.challenge,
      scopes: config.scopes,
    );

    await _writePending(_PendingAttempt(
      provider: provider,
      verifier: pkce.verifier,
      state: state,
      redirectUri: redirectUri,
      tenantHost: tenantHost,
    ));

    browser.redirectTo(authorizeUrl);
  }

  /// Whether a connect attempt is waiting for the provider's redirect.
  Future<bool> hasPendingAttempt() async => (await _readPending()) != null;

  /// Finishes the round trip started by [beginConnect].
  ///
  /// Returns null when there is nothing waiting, or when the browser has not
  /// come back from the provider yet. The provider name travels with the tokens
  /// because the app that returns from the redirect has not stored which
  /// provider it was connecting yet. Throws (with a user-facing message) when
  /// the provider refused, the state did not match, or the server rejected the
  /// exchange.
  Future<({String provider, BrokerTokens tokens})?> completePendingConnect() async {
    final pending = await _readPending();
    if (pending == null) return null;

    final callback = OAuthCallback.fromUrl(browser.currentUrl());
    if (callback.code == null && callback.error == null) return null;

    // The code is one-shot: clear it before anything async can fail, so a
    // reload cannot replay it.
    browser.clearCallbackParameters();

    final problem = validateCallback(callback, expectedState: pending.state);
    if (problem != null) {
      await _clearPending();
      throw StateError(problem);
    }

    try {
      final tokens = await exchangeCode(
        provider: pending.provider,
        code: callback.code!,
        codeVerifier: pending.verifier,
        redirectUri: pending.redirectUri,
        tenantHost: pending.tenantHost,
      );
      await _clearPending();
      return (provider: pending.provider, tokens: tokens);
    } catch (error) {
      await _clearPending();
      rethrow;
    }
  }

  /// Redeems an authorization code through the broker and stores the result.
  Future<BrokerTokens> exchangeCode({
    required String provider,
    required String code,
    required String codeVerifier,
    required String redirectUri,
    String? tenantHost,
  }) async {
    final data = await _call('oauthExchange', {
      'provider': provider,
      'code': code,
      'codeVerifier': codeVerifier,
      'redirectUri': redirectUri,
      'tenantHost': tenantHost,
    });
    final tokens = BrokerTokens.fromMap(data);
    if (tokens.accessToken.isEmpty) {
      throw StateError('The broker did not return an access token.');
    }
    await _store(provider, tokens);
    return tokens;
  }

  /// Renews an expired connection through the broker.
  Future<BrokerTokens> refresh({
    required String provider,
    required String refreshToken,
    String? tenantHost,
  }) async {
    final data = await _call('oauthRefresh', {
      'provider': provider,
      'refreshToken': refreshToken,
      'tenantHost': tenantHost,
    });
    final tokens = BrokerTokens.fromMap(data);
    if (tokens.accessToken.isEmpty) {
      throw StateError('The broker did not return an access token.');
    }
    await _store(provider, tokens);
    return tokens;
  }

  /// Hands the tokens to the shared token store, so the rest of the app reads a
  /// broker connection exactly like an in-app one.
  Future<void> _store(String provider, BrokerTokens tokens) async {
    final oauth = _integrationProviderFor(provider);
    if (oauth == null) {
      throw StateError('Unknown provider: $provider');
    }
    await IntegrationOAuthService.instance.saveTokens(
      provider: oauth,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresAt: tokens.expiresAt,
      scopes: tokens.scopes,
    );
  }

  static IntegrationProvider? _integrationProviderFor(String provider) {
    for (final candidate in IntegrationProvider.values) {
      if (candidate.name.toLowerCase() == provider.toLowerCase()) {
        return candidate;
      }
    }
    return null;
  }

  String _newState() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  // ── storage (never throws: a failed read simply means "nothing pending") ──

  Future<void> _writePending(_PendingAttempt attempt) async {
    try {
      await _storage.write(key: _pendingKey, value: jsonEncode(attempt.toJson()));
    } catch (error) {
      debugPrint('[BackendOAuthBroker] could not store the pending attempt: $error');
    }
  }

  Future<_PendingAttempt?> _readPending() async {
    try {
      final raw = await _storage.read(key: _pendingKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final attempt =
          _PendingAttempt.fromJson(Map<String, dynamic>.from(decoded));
      return attempt.provider.isEmpty ? null : attempt;
    } catch (error) {
      debugPrint('[BackendOAuthBroker] could not read the pending attempt: $error');
      return null;
    }
  }

  Future<void> _clearPending() async {
    try {
      await _storage.delete(key: _pendingKey);
    } catch (error) {
      debugPrint('[BackendOAuthBroker] could not clear the pending attempt: $error');
    }
  }
}
