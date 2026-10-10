import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum IntegrationProvider {
  figma,
  miro,
  drawio,
  whiteboard,
  slack,
  microsoftTeams,
  microsoft365,
  quickBooks,
  xero,
  salesforce,
  hubSpot,

  // ── Accounting / ERP (see AccountingIntegrationService) ────────────────
  sage,
  sap,
}

class IntegrationAuthState {
  IntegrationAuthState({
    required this.connected,
    required this.hasToken,
    this.expiresAt,
    this.updatedAt,
    this.scopes = const [],
  });

  final bool connected;
  final bool hasToken;
  final DateTime? expiresAt;
  final DateTime? updatedAt;

  /// Scopes the provider actually granted (empty for records saved before
  /// scopes were persisted).
  final List<String> scopes;
}

class IntegrationClientConfig {
  const IntegrationClientConfig(
      {this.clientId, this.clientSecret, this.tenantHost});

  final String? clientId;
  final String? clientSecret;

  /// Tenant host for providers whose endpoints live on the customer's own
  /// subdomain (SAP S/4HANA). Null for every other provider.
  final String? tenantHost;
}

class IntegrationOAuthConfig {
  const IntegrationOAuthConfig({
    required this.provider,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.scopes,
    required this.redirectUri,
    this.requiresTenantHost = false,
  });

  final IntegrationProvider provider;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final List<String> scopes;
  final String redirectUri;

  /// True when the endpoints are templated with `{tenant}` and only resolve
  /// once the customer's tenant host is supplied (SAP S/4HANA).
  final bool requiresTenantHost;

  /// This config with `{tenant}` replaced by [tenantHost].
  IntegrationOAuthConfig withTenantHost(String tenantHost) {
    if (!requiresTenantHost) return this;
    return IntegrationOAuthConfig(
      provider: provider,
      authorizationEndpoint:
          authorizationEndpoint.replaceAll('{tenant}', tenantHost),
      tokenEndpoint: tokenEndpoint.replaceAll('{tenant}', tenantHost),
      scopes: scopes,
      redirectUri: redirectUri,
      requiresTenantHost: true,
    );
  }
}

class IntegrationOAuthService {
  IntegrationOAuthService._();
  static final IntegrationOAuthService instance = IntegrationOAuthService._();

  static const String redirectUri = 'nduproject://oauth2redirect';

  /// The `{tenant}` placeholder used by tenant-scoped providers.
  static const String tenantPlaceholder = '{tenant}';

  /// Whether this build can run the in-app OAuth dance.
  ///
  /// [FlutterAppAuth] is implemented for Android, iOS and macOS only. On web
  /// (and the remaining desktop targets) the browser cannot complete these
  /// confidential-client exchanges itself, so callers must not pretend a
  /// connection happened — see `AccountingIntegrationService`.
  static bool get supportsInAppOAuth {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  static const Map<IntegrationProvider, IntegrationOAuthConfig> _configs = {
    IntegrationProvider.figma: IntegrationOAuthConfig(
      provider: IntegrationProvider.figma,
      authorizationEndpoint: 'https://www.figma.com/oauth',
      tokenEndpoint: 'https://www.figma.com/api/oauth/token',
      scopes: ['files:read', 'files:write', 'comments:read'],
      redirectUri: redirectUri,
    ),
    IntegrationProvider.miro: IntegrationOAuthConfig(
      provider: IntegrationProvider.miro,
      authorizationEndpoint: 'https://miro.com/oauth/authorize',
      tokenEndpoint: 'https://api.miro.com/v1/oauth/token',
      scopes: ['boards:read', 'comments:read'],
      redirectUri: redirectUri,
    ),
    IntegrationProvider.drawio: IntegrationOAuthConfig(
      provider: IntegrationProvider.drawio,
      authorizationEndpoint: 'https://app.diagrams.net/oauth/authorize',
      tokenEndpoint: 'https://app.diagrams.net/oauth/token',
      scopes: ['diagrams:read'],
      redirectUri: redirectUri,
    ),
    IntegrationProvider.whiteboard: IntegrationOAuthConfig(
      provider: IntegrationProvider.whiteboard,
      authorizationEndpoint: 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
      tokenEndpoint: 'https://login.microsoftonline.com/common/oauth2/v2.0/token',
      scopes: ['offline_access', 'User.Read', 'Notes.Read'],
      redirectUri: redirectUri,
    ),
    IntegrationProvider.slack: IntegrationOAuthConfig(
      provider: IntegrationProvider.slack,
      authorizationEndpoint: 'https://slack.com/oauth/v2/authorize',
      tokenEndpoint: 'https://slack.com/api/oauth.v2.access',
      scopes: ['channels:read', 'chat:write', 'users:read'],
      redirectUri: redirectUri,
    ),
    IntegrationProvider.microsoftTeams: IntegrationOAuthConfig(
      provider: IntegrationProvider.microsoftTeams,
      authorizationEndpoint: 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
      tokenEndpoint: 'https://login.microsoftonline.com/common/oauth2/v2.0/token',
      scopes: ['offline_access', 'User.Read', 'Channel.ReadBasic.All', 'Chat.ReadWrite'],
      redirectUri: redirectUri,
    ),
    IntegrationProvider.microsoft365: IntegrationOAuthConfig(
      provider: IntegrationProvider.microsoft365,
      authorizationEndpoint: 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
      tokenEndpoint: 'https://login.microsoftonline.com/common/oauth2/v2.0/token',
      scopes: ['offline_access', 'User.Read', 'Files.ReadWrite', 'Sites.Read.All'],
      redirectUri: redirectUri,
    ),
    // ── Accounting ──────────────────────────────────────────────────────────
    IntegrationProvider.quickBooks: IntegrationOAuthConfig(
      provider: IntegrationProvider.quickBooks,
      authorizationEndpoint: 'https://appcenter.intuit.com/connect/oauth2',
      tokenEndpoint: 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer',
      scopes: ['com.intuit.quickbooks.accounting'],
      redirectUri: redirectUri,
    ),
    IntegrationProvider.xero: IntegrationOAuthConfig(
      provider: IntegrationProvider.xero,
      authorizationEndpoint: 'https://login.xero.com/identity/connect/authorize',
      tokenEndpoint: 'https://identity.xero.com/connect/token',
      scopes: ['openid', 'profile', 'email', 'accounting.transactions', 'offline_access'],
      redirectUri: redirectUri,
    ),
    // ── CRM ─────────────────────────────────────────────────────────────────
    IntegrationProvider.salesforce: IntegrationOAuthConfig(
      provider: IntegrationProvider.salesforce,
      authorizationEndpoint: 'https://login.salesforce.com/services/oauth2/authorize',
      tokenEndpoint: 'https://login.salesforce.com/services/oauth2/token',
      scopes: ['api', 'refresh_token'],
      redirectUri: redirectUri,
    ),
    IntegrationProvider.hubSpot: IntegrationOAuthConfig(
      provider: IntegrationProvider.hubSpot,
      authorizationEndpoint: 'https://app.hubspot.com/oauth/authorize',
      tokenEndpoint: 'https://api.hubapi.com/oauth/v1/token',
      scopes: ['crm.objects.contacts.read', 'crm.objects.deals.read'],
      redirectUri: redirectUri,
    ),
    // ── Accounting / ERP ────────────────────────────────────────────────────
    // Sage Intacct's OAuth 2.0 endpoints (REST API v1) are fixed and shared by
    // every customer.
    IntegrationProvider.sage: IntegrationOAuthConfig(
      provider: IntegrationProvider.sage,
      authorizationEndpoint: 'https://api.intacct.com/ia/api/v1/oauth2/authorize',
      tokenEndpoint: 'https://api.intacct.com/ia/api/v1/oauth2/token',
      scopes: ['openid', 'profile', 'email', 'offline_access'],
      redirectUri: redirectUri,
    ),
    // SAP S/4HANA OAuth 2.0 runs against the customer's own tenant, so the
    // host is supplied at connect time and substituted into the template.
    IntegrationProvider.sap: IntegrationOAuthConfig(
      provider: IntegrationProvider.sap,
      authorizationEndpoint: 'https://{tenant}/oauth/authorize',
      tokenEndpoint: 'https://{tenant}/oauth/token',
      // S/4HANA authorises through a communication arrangement on the OAuth
      // client itself, so no `scope` parameter is sent.
      scopes: [],
      redirectUri: redirectUri,
      requiresTenantHost: true,
    ),
  };

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  /// Whether [provider]'s endpoints only resolve once a tenant host is given.
  bool requiresTenantHost(IntegrationProvider provider) =>
      _configs[provider]?.requiresTenantHost ?? false;

  /// The OAuth configuration for [provider].
  ///
  /// Tenant-scoped providers (SAP S/4HANA) need [tenantHost]; a bare host,
  /// host:port, or full URL are all accepted. Throws [StateError] when the
  /// host is required and missing, so a half-built URL is never launched.
  IntegrationOAuthConfig configFor(
    IntegrationProvider provider, {
    String? tenantHost,
  }) {
    final config = _configs[provider]!;
    if (!config.requiresTenantHost) return config;
    final host = normalizeTenantHost(tenantHost);
    if (host.isEmpty) {
      throw StateError(
          '${provider.name} connects to a customer-specific tenant: enter the tenant host.');
    }
    return config.withTenantHost(host);
  }

  /// Reduces user input such as `https://acme.authentication.sap.hana
  /// .ondemand.com/oauth/` to the host `acme.authentication.sap.hana
  /// .ondemand.com`, and expands the short subdomain form (`acme`) to the same.
  /// Returns an empty string when nothing usable is left.
  static String normalizeTenantHost(String? raw) {
    var value = (raw ?? '').trim();
    if (value.isEmpty) return '';
    value = value.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    for (final separator in const ['/', '?', '#']) {
      final index = value.indexOf(separator);
      if (index != -1) value = value.substring(0, index);
    }
    // Accept `acme.authentication.sap.hana.ondemand.com` as well as the
    // short subdomain form `acme`.
    if (!value.contains('.') && !value.contains(':')) {
      return '$value.authentication.sap.hana.ondemand.com';
    }
    return value;
  }

  Future<IntegrationClientConfig> loadClientConfig(IntegrationProvider provider) async {
    final clientId = await _storage.read(key: _key(provider, 'client_id'));
    final clientSecret = await _storage.read(key: _key(provider, 'client_secret'));
    final tenantHost = await _storage.read(key: _key(provider, 'tenant_host'));
    return IntegrationClientConfig(
      clientId: clientId,
      clientSecret: clientSecret,
      tenantHost: tenantHost,
    );
  }

  Future<void> saveClientConfig({
    required IntegrationProvider provider,
    required String clientId,
    String? clientSecret,
    String? tenantHost,
  }) async {
    await _storage.write(key: _key(provider, 'client_id'), value: clientId.trim());
    if (clientSecret != null && clientSecret.trim().isNotEmpty) {
      await _storage.write(key: _key(provider, 'client_secret'), value: clientSecret.trim());
    }
    final host = normalizeTenantHost(tenantHost);
    if (host.isNotEmpty) {
      await _storage.write(key: _key(provider, 'tenant_host'), value: host);
    }
  }

  Future<IntegrationAuthState> loadState(IntegrationProvider provider) async {
    final accessToken = await _storage.read(key: _key(provider, 'access_token'));
    final expiresRaw = await _storage.read(key: _key(provider, 'expires_at'));
    final updatedRaw = await _storage.read(key: _key(provider, 'updated_at'));
    final scopesRaw = await _storage.read(key: _key(provider, 'scopes'));
    final expiresAt = expiresRaw == null ? null : DateTime.tryParse(expiresRaw);
    final updatedAt = updatedRaw == null ? null : DateTime.tryParse(updatedRaw);
    final hasToken = (accessToken ?? '').isNotEmpty;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now().subtract(const Duration(minutes: 1)));
    return IntegrationAuthState(
      connected: hasToken && !isExpired,
      hasToken: hasToken,
      expiresAt: expiresAt,
      updatedAt: updatedAt,
      scopes: splitScopes(scopesRaw),
    );
  }

  /// Parses the comma-separated scope string persisted with a connection.
  static List<String> splitScopes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  Future<IntegrationAuthState> connect({
    required IntegrationProvider provider,
    required String clientId,
    String? clientSecret,
    List<String>? scopesOverride,
    String? tenantHost,
  }) async {
    if (!supportsInAppOAuth) {
      throw StateError(
          'The in-app connector runs on the Android, iOS and macOS builds. '
          'This platform needs a server-side OAuth broker to complete the exchange.');
    }
    final config = configFor(provider, tenantHost: tenantHost);
    final scopes = scopesOverride == null || scopesOverride.isEmpty
        ? config.scopes
        : scopesOverride;
    final secret = (clientSecret ?? '').trim();
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId.trim(),
        config.redirectUri,
        serviceConfiguration: AuthorizationServiceConfiguration(
          authorizationEndpoint: config.authorizationEndpoint,
          tokenEndpoint: config.tokenEndpoint,
        ),
        // Providers that authorise through their client registration (SAP
        // S/4HANA) must not receive an empty `scope=` parameter.
        scopes: scopes.isEmpty ? null : scopes,
        clientSecret: secret.isEmpty ? null : secret,
      ),
    );

    final accessToken = result.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('The provider did not return an access token.');
    }
    await _storage.write(key: _key(provider, 'access_token'), value: accessToken);
    final refreshToken = result.refreshToken;
    if (refreshToken != null) {
      await _storage.write(key: _key(provider, 'refresh_token'), value: refreshToken);
    }
    final expiresAt = result.accessTokenExpirationDateTime;
    if (expiresAt != null) {
      await _storage.write(
        key: _key(provider, 'expires_at'),
        value: expiresAt.toIso8601String(),
      );
    }
    // The granted scopes are what the provider returned, falling back to the
    // requested set when it does not echo them back.
    final granted = (result.scopes == null || result.scopes!.isEmpty)
        ? scopes
        : result.scopes!;
    await _storage.write(
      key: _key(provider, 'scopes'),
      value: granted.join(','),
    );
    await _storage.write(key: _key(provider, 'updated_at'), value: DateTime.now().toIso8601String());
    return loadState(provider);
  }

  /// Stores tokens obtained outside [connect] — currently the web build, where
  /// the exchange is done by the server-side broker
  /// (`functions/oauth-broker.js`) because these vendors are confidential
  /// clients. Every connection is read back through [loadState], so a brokered
  /// connection behaves exactly like an in-app one.
  Future<void> saveTokens({
    required IntegrationProvider provider,
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    List<String> scopes = const [],
  }) async {
    await _storage.write(key: _key(provider, 'access_token'), value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _key(provider, 'refresh_token'), value: refreshToken);
    }
    if (expiresAt != null) {
      await _storage.write(
        key: _key(provider, 'expires_at'),
        value: expiresAt.toIso8601String(),
      );
    }
    await _storage.write(key: _key(provider, 'scopes'), value: scopes.join(','));
    await _storage.write(
      key: _key(provider, 'updated_at'),
      value: DateTime.now().toIso8601String(),
    );
  }

  /// The stored refresh token for [provider], if there is one.
  Future<String?> refreshTokenFor(IntegrationProvider provider) =>
      _storage.read(key: _key(provider, 'refresh_token'));

  /// Renews a stored connection from its refresh token.
  ///
  /// This is what keeps a connected ledger connected: a lapsed access token is
  /// renewed instead of the connection being dropped. Only the native builds do
  /// this in-app — a browser cannot hold the client secret, so the web build
  /// renews through the broker (`BackendOAuthBroker.refresh`).
  Future<IntegrationAuthState> refresh(
    IntegrationProvider provider, {
    String? tenantHost,
  }) async {
    if (!supportsInAppOAuth) {
      throw StateError(
          'This platform renews connections through the server-side broker.');
    }
    final refreshToken = await refreshTokenFor(provider);
    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('No refresh token was stored for this connection.');
    }
    final client = await loadClientConfig(provider);
    final clientId = (client.clientId ?? '').trim();
    if (clientId.isEmpty) {
      throw StateError('The OAuth client ID for this connection is missing.');
    }

    final config = configFor(provider, tenantHost: tenantHost);
    final secret = (client.clientSecret ?? '').trim();
    final result = await _appAuth.token(
      TokenRequest(
        clientId,
        config.redirectUri,
        clientSecret: secret.isEmpty ? null : secret,
        refreshToken: refreshToken,
        serviceConfiguration: AuthorizationServiceConfiguration(
          authorizationEndpoint: config.authorizationEndpoint,
          tokenEndpoint: config.tokenEndpoint,
        ),
      ),
    );

    final accessToken = result.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('The provider did not return a new access token.');
    }

    await saveTokens(
      provider: provider,
      accessToken: accessToken,
      // A provider that does not rotate the refresh token keeps the stored one.
      refreshToken: (result.refreshToken ?? '').isEmpty
          ? refreshToken
          : result.refreshToken,
      expiresAt: result.accessTokenExpirationDateTime,
      scopes: (result.scopes == null || result.scopes!.isEmpty)
          ? splitScopes(await _storage.read(key: _key(provider, 'scopes')))
          : result.scopes!,
    );
    return loadState(provider);
  }

  Future<void> disconnect(IntegrationProvider provider) async {
    final keys = [
      _key(provider, 'access_token'),
      _key(provider, 'refresh_token'),
      _key(provider, 'expires_at'),
      _key(provider, 'updated_at'),
      _key(provider, 'scopes'),
    ];
    for (final key in keys) {
      await _storage.delete(key: key);
    }
  }

  String _key(IntegrationProvider provider, String field) => 'integration_${provider.name}_$field';
}
