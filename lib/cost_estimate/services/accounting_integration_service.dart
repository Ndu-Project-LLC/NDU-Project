library;

/// Real OAuth wiring for the Cost Estimate's accounting connectors.
///
/// The four providers offered on the Accounting screen — QuickBooks Online,
/// Xero, Sage Intacct and SAP S/4HANA — each authorise through their own
/// OAuth 2.0 endpoints. This service is the single place that:
///
///  * maps an [AccountingProvider] onto the matching
///    [IntegrationProvider] configuration (endpoints, scopes, redirect URI);
///  * runs that flow through [IntegrationOAuthService], which keeps the
///    resulting tokens in platform secure storage;
///  * reports what is *actually* stored, so the screen never shows a
///    connection the provider did not grant;
///  * mirrors the connection into Firestore so the status is durable and
///    visible on another device.
///
/// The screen is a thin layer over this: it collects the client credentials
/// the customer registered in the provider's developer console and displays
/// the outcome.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:ndu_project/cost_estimate/models/cost_estimate_models.dart';
import 'package:ndu_project/services/backend_oauth_broker.dart';
import 'package:ndu_project/services/business_system_integration_service.dart';
import 'package:ndu_project/services/integration_oauth_service.dart';

/// The state of one accounting connection, as the platform store reports it.
///
/// [verified] is false when the answer could not be read (secure storage
/// unavailable, plugin missing on this platform). Callers must only treat
/// `connected == false` as "the connection is gone" when [verified] is true —
/// otherwise a transient read failure would silently delete a real
/// connection from the estimate.
class AccountingConnection {
  const AccountingConnection({
    required this.connected,
    this.connectedAt,
    this.scopes = const [],
    this.expiresAt,
    this.accountLabel,
    this.verified = true,
    this.message,
    this.pendingRedirect = false,
  });

  final bool connected;
  final DateTime? connectedAt;
  final List<String> scopes;
  final DateTime? expiresAt;

  /// Company/realm/tenant this token authorises, when known.
  final String? accountLabel;

  /// Whether the store was actually read.
  final bool verified;

  /// User-facing explanation when a connect attempt failed.
  final String? message;

  /// True when the flow handed the browser to the provider and the app is
  /// waiting for it to come back (web builds only).
  final bool pendingRedirect;

  /// The store could not be read — neither connected nor disconnected.
  static const AccountingConnection unknown =
      AccountingConnection(connected: false, verified: false);

  /// A verified, not-connected provider.
  static const AccountingConnection none = AccountingConnection(connected: false);
}

class AccountingIntegrationService {
  AccountingIntegrationService._();

  /// Accounting provider → OAuth provider configuration.
  static const Map<AccountingProvider, IntegrationProvider> _oauthProviders = {
    AccountingProvider.quickbooks: IntegrationProvider.quickBooks,
    AccountingProvider.xero: IntegrationProvider.xero,
    AccountingProvider.sage: IntegrationProvider.sage,
    AccountingProvider.sap: IntegrationProvider.sap,
  };

  /// Accounting provider → business-system record used for the Firestore mirror.
  static const Map<AccountingProvider, BusinessSystemProvider> _businessSystems = {
    AccountingProvider.quickbooks: BusinessSystemProvider.quickbooks,
    AccountingProvider.xero: BusinessSystemProvider.xero,
    AccountingProvider.sage: BusinessSystemProvider.sage,
    AccountingProvider.sap: BusinessSystemProvider.sap,
  };

  /// Test seam: replaces the real OAuth dance (see the e2e widget test).
  @visibleForTesting
  static Future<AccountingConnection> Function(
    AccountingProvider provider,
    String clientId,
    String? clientSecret,
    String? tenantHost,
  )? connectOverride;

  /// Test seam: replaces the secure-storage read behind [load].
  @visibleForTesting
  static Future<AccountingConnection> Function(AccountingProvider provider)?
      statusOverride;

  /// Test seam: replaces the renewal attempt in [loadAndRenew] for a provider
  /// whose access token has lapsed.
  @visibleForTesting
  static Future<AccountingConnection> Function(AccountingProvider provider)?
      renewOverride;

  /// How long the renewal probe may wait on secure storage before giving up and
  /// reporting the connection exactly as the store told us.
  static const Duration _renewalProbeTimeout = Duration(seconds: 3);

  /// Whether this build can run the in-app OAuth dance at all.
  static bool get supportsInAppConnect => IntegrationOAuthService.supportsInAppOAuth;

  /// Whether connections run through the server-side broker instead — true on
  /// the web build, where a confidential client's code cannot be exchanged in
  /// the browser (see `functions/oauth-broker.js`).
  static bool get usesServerBroker => BackendOAuthBroker.isSupported;

  /// Whether the user must paste OAuth client credentials. Not on web: the
  /// broker holds them server-side, so there is nothing for the user to enter.
  static bool get requiresClientCredentials => !usesServerBroker;

  /// The OAuth provider behind [provider], or null when it has no connector.
  static IntegrationProvider? oauthProviderFor(AccountingProvider provider) =>
      _oauthProviders[provider];

  /// The accounting provider behind an OAuth connector, or null.
  static AccountingProvider? accountingProviderFor(IntegrationProvider oauth) =>
      _accountingProviderNamed(oauth.name);

  /// The accounting provider whose OAuth connector has this name.
  static AccountingProvider? _accountingProviderNamed(String name) {
    for (final entry in _oauthProviders.entries) {
      if (entry.value.name.toLowerCase() == name.toLowerCase()) return entry.key;
    }
    return null;
  }

  /// The redirect URI that must be registered for this build: the app's own
  /// callback on web (where the broker redeems the code), the deep link on
  /// native builds.
  static String redirectUriForCurrentBuild() => usesServerBroker
      ? BackendOAuthBroker.redirectUriForCurrentOrigin()
      : IntegrationOAuthService.redirectUri;

  /// The business-system record behind [provider], or null.
  static BusinessSystemProvider? businessSystemFor(AccountingProvider provider) =>
      _businessSystems[provider];

  /// True when [provider]'s endpoints live on the customer's own tenant host
  /// (SAP S/4HANA) and therefore need one before connecting.
  static bool requiresTenantHost(AccountingProvider provider) {
    final oauth = _oauthProviders[provider];
    if (oauth == null) return false;
    return IntegrationOAuthService.instance.requiresTenantHost(oauth);
  }

  /// Endpoints and scopes for [provider], for display in the connect modal.
  ///
  /// Returns null for providers without a connector, and for tenant-scoped
  /// providers until [tenantHost] resolves.
  static IntegrationOAuthConfig? configFor(
    AccountingProvider provider, {
    String? tenantHost,
  }) {
    final oauth = _oauthProviders[provider];
    if (oauth == null) return null;
    try {
      return IntegrationOAuthService.instance
          .configFor(oauth, tenantHost: tenantHost);
    } on StateError {
      return null;
    }
  }

  /// The scopes [provider] will request (empty when it authorises through its
  /// client registration, as SAP S/4HANA does).
  static List<String> scopesFor(AccountingProvider provider) =>
      configFor(provider)?.scopes ?? const [];

  /// The redirect URI that must be registered in the provider's developer app.
  static String get redirectUri => IntegrationOAuthService.redirectUri;

  /// Reads what is stored for [provider] right now.
  static Future<AccountingConnection> load(AccountingProvider provider) async {
    final override = statusOverride;
    if (override != null) return override(provider);

    final oauth = _oauthProviders[provider];
    if (oauth == null) return AccountingConnection.none;
    try {
      final state = await IntegrationOAuthService.instance.loadState(oauth);
      return AccountingConnection(
        connected: state.connected,
        connectedAt: state.updatedAt,
        scopes: state.scopes,
        expiresAt: state.expiresAt,
      );
    } catch (error) {
      debugPrint('[AccountingIntegrationService] load failed: $error');
      return AccountingConnection.unknown;
    }
  }

  /// Reads the connection and renews it when only the access token has lapsed.
  ///
  /// This is the check the screen runs on entry: an expired token with a stored
  /// refresh token is renewed (the ledger stays connected), and only a genuine
  /// loss of authorisation reports as disconnected.
  static Future<AccountingConnection> loadAndRenew(
      AccountingProvider provider) async {
    final current = await load(provider);
    if (current.connected || !current.verified) return current;

    final override = renewOverride;
    if (override != null) return override(provider);

    final oauth = _oauthProviders[provider];
    if (oauth == null) return current;

    // Only worth a round trip when the provider issued a refresh token. Bounded,
    // because this runs while a screen is waiting: a secure-storage read that
    // never answers must not hold the connection status hostage.
    String? stored;
    try {
      stored = await IntegrationOAuthService.instance
          .refreshTokenFor(oauth)
          .timeout(_renewalProbeTimeout);
    } catch (error) {
      debugPrint('[AccountingIntegrationService] refresh token unavailable: $error');
      return current;
    }
    if (stored == null || stored.isEmpty) return current;
    return renew(provider);
  }

  /// Renews [provider]'s tokens.
  ///
  /// Returns a verified not-connected result when the provider refuses, so the
  /// caller reports the connection as lost rather than pretending it is live.
  static Future<AccountingConnection> renew(AccountingProvider provider) async {
    final oauth = _oauthProviders[provider];
    if (oauth == null) return AccountingConnection.none;

    if (usesServerBroker) {
      try {
        final refreshToken =
            await IntegrationOAuthService.instance.refreshTokenFor(oauth);
        if (refreshToken == null || refreshToken.isEmpty) {
          return AccountingConnection.none;
        }
        final tokens = await BackendOAuthBroker.instance.refresh(
          provider: oauth.name,
          refreshToken: refreshToken,
        );
        return AccountingConnection(
          connected: true,
          connectedAt: DateTime.now(),
          scopes: tokens.scopes,
          expiresAt: tokens.expiresAt,
        );
      } catch (error) {
        debugPrint('[AccountingIntegrationService] broker renew failed: $error');
        return AccountingConnection.none;
      }
    }

    try {
      final state = await IntegrationOAuthService.instance.refresh(oauth);
      if (!state.connected) return AccountingConnection.none;
      return AccountingConnection(
        connected: true,
        connectedAt: state.updatedAt ?? DateTime.now(),
        scopes: state.scopes,
        expiresAt: state.expiresAt,
      );
    } catch (error) {
      debugPrint('[AccountingIntegrationService] renew failed: $error');
      return AccountingConnection.none;
    }
  }

  /// Client credentials previously entered for [provider], so the modal can be
  /// reopened without retyping them.
  static Future<IntegrationClientConfig?> loadClientConfig(
      AccountingProvider provider) async {
    final oauth = _oauthProviders[provider];
    if (oauth == null) return null;
    try {
      return await IntegrationOAuthService.instance.loadClientConfig(oauth);
    } catch (error) {
      debugPrint('[AccountingIntegrationService] loadClientConfig failed: $error');
      return null;
    }
  }

  /// Runs [provider]'s real OAuth 2.0 flow.
  ///
  /// A connection is only reported as connected when the provider returned a
  /// usable access token; every other outcome carries a [AccountingConnection.message]
  /// explaining what went wrong.
  static Future<AccountingConnection> connect({
    required AccountingProvider provider,
    required String clientId,
    String? clientSecret,
    String? tenantHost,
  }) async {
    final override = connectOverride;
    if (override != null) {
      return override(provider, clientId, clientSecret, tenantHost);
    }

    final oauth = _oauthProviders[provider];
    if (oauth == null) {
      return AccountingConnection(
        connected: false,
        message: '${provider.label} has no OAuth connector.',
      );
    }

    // Web: the browser is sent to the provider and the app finishes the
    // exchange when it comes back (completePendingBrokerConnect).
    if (usesServerBroker) {
      try {
        await BackendOAuthBroker.instance.beginConnect(
          provider: oauth.name,
          tenantHost: tenantHost,
        );
        return const AccountingConnection(
          connected: false,
          verified: false,
          pendingRedirect: true,
          message: 'Continue in the provider tab to finish connecting.',
        );
      } catch (error) {
        return AccountingConnection(connected: false, message: _friendlyError(error));
      }
    }

    try {
      await IntegrationOAuthService.instance.saveClientConfig(
        provider: oauth,
        clientId: clientId,
        clientSecret: clientSecret,
        tenantHost: tenantHost,
      );
      final state = await IntegrationOAuthService.instance.connect(
        provider: oauth,
        clientId: clientId,
        clientSecret: clientSecret,
        tenantHost: tenantHost,
      );
      if (!state.connected) {
        return const AccountingConnection(
          connected: false,
          message: 'The provider did not return a usable access token.',
        );
      }
      return AccountingConnection(
        connected: true,
        connectedAt: state.updatedAt ?? DateTime.now(),
        scopes: state.scopes,
        expiresAt: state.expiresAt,
        accountLabel: _accountLabelFor(provider, tenantHost),
      );
    } catch (error) {
      return AccountingConnection(
        connected: false,
        message: _friendlyError(error),
      );
    }
  }

  /// Finishes a brokered connect that the provider has now redirected back.
  ///
  /// Returns null when nothing is waiting (the usual case). Throws with a
  /// user-facing message when the provider refused or the exchange failed.
  static Future<({AccountingProvider provider, AccountingConnection connection})?>
      completePendingBrokerConnect() async {
    if (!usesServerBroker) return null;
    try {
      final result = await BackendOAuthBroker.instance.completePendingConnect();
      if (result == null) return null;
      final provider = _accountingProviderNamed(result.provider);
      if (provider == null) return null;
      return (
        provider: provider,
        connection: AccountingConnection(
          connected: true,
          connectedAt: DateTime.now(),
          scopes: result.tokens.scopes,
          expiresAt: result.tokens.expiresAt,
        ),
      );
    } catch (error) {
      return (
        provider: AccountingProvider.none,
        connection: AccountingConnection(
          connected: false,
          message: _friendlyError(error),
        ),
      );
    }
  }

  /// True when a brokered connect attempt is waiting for the browser to return.
  static Future<bool> hasPendingBrokerConnect() =>
      usesServerBroker ? BackendOAuthBroker.instance.hasPendingAttempt() : Future.value(false);

  /// Clears the stored tokens for [provider]. Never throws: a disconnect the
  /// user asked for must not be blocked by a storage hiccup.
  static Future<void> disconnect(AccountingProvider provider) async {
    final oauth = _oauthProviders[provider];
    if (oauth == null) return;
    try {
      await IntegrationOAuthService.instance.disconnect(oauth);
    } catch (error) {
      debugPrint('[AccountingIntegrationService] disconnect failed: $error');
    }
  }

  /// Mirrors a connection into Firestore so the status survives a reinstall or
  /// a different device.
  ///
  /// Best effort by design: the tokens stay in secure storage (never written
  /// here) and secure storage remains the source of truth, so a project that
  /// is not yet backed by a Firestore document — or an offline device — is not
  /// an error the user needs to see.
  static Future<void> mirrorToCloud({
    required String projectId,
    required AccountingProvider provider,
    required AccountingConnection connection,
  }) async {
    final project = projectId.trim();
    final target = _businessSystems[provider];
    if (project.isEmpty || target == null || !connection.connected) return;

    final now = DateTime.now();
    String uid = '';
    String email = '';
    try {
      final user = FirebaseAuth.instance.currentUser;
      uid = user?.uid ?? '';
      email = user?.email ?? '';
    } catch (error) {
      debugPrint('[AccountingIntegrationService] auth unavailable: $error');
    }

    try {
      await BusinessSystemIntegrationService.saveForProject(
        project,
        BusinessSystemIntegration(
          provider: target,
          status: IntegrationStatus.connected,
          authMethod: AuthMethod.oauth,
          // Tokens deliberately stay in platform secure storage.
          accessToken: null,
          tokenExpiresAt: connection.expiresAt,
          autoSync: false,
          lastSyncAt: connection.connectedAt,
          scopes: connection.scopes,
          connectedById: uid,
          connectedByEmail: email,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } catch (error) {
      debugPrint('[AccountingIntegrationService] cloud mirror skipped: $error');
    }
  }

  /// Removes the Firestore mirror for [provider]. Best effort, like
  /// [mirrorToCloud].
  static Future<void> removeFromCloud({
    required String projectId,
    required AccountingProvider provider,
  }) async {
    final project = projectId.trim();
    final target = _businessSystems[provider];
    if (project.isEmpty || target == null) return;
    try {
      await BusinessSystemIntegrationService.deleteForProject(project, target);
    } catch (error) {
      debugPrint('[AccountingIntegrationService] cloud removal skipped: $error');
    }
  }

  /// Builds the [AccountingIntegration] record the estimate stores, carrying
  /// the existing GL mapping across a (re)connect.
  static AccountingIntegration toEstimateRecord({
    required AccountingProvider provider,
    required AccountingConnection connection,
    List<AccountingGLMapping> glMapping = const [],
  }) {
    return AccountingIntegration(
      provider: connection.connected ? provider : AccountingProvider.none,
      connected: connection.connected,
      connectedAt: connection.connected ? connection.connectedAt : null,
      glMapping: connection.connected ? glMapping : const [],
      accountLabel: connection.accountLabel,
      scopes: connection.scopes,
      expiresAt: connection.expiresAt,
    );
  }

  /// Clears the connection from the estimate (disconnect).
  static const AccountingIntegration disconnectedRecord = AccountingIntegration(
    provider: AccountingProvider.none,
    connected: false,
    glMapping: [],
  );

  static String _accountLabelFor(AccountingProvider provider, String? tenantHost) {
    if (provider == AccountingProvider.sap) {
      final host = IntegrationOAuthService.normalizeTenantHost(tenantHost);
      return host.isEmpty ? provider.label : host;
    }
    return provider.label;
  }

  /// Turns an exception into something a user can act on.
  static String _friendlyError(Object error) {
    final text = error is StateError ? error.message : error.toString();
    return text.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }
}
