import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum IntegrationProvider { figma, miro, drawio, whiteboard }

class IntegrationAuthState {
  IntegrationAuthState({
    required this.connected,
    required this.hasToken,
    this.expiresAt,
    this.updatedAt,
  });

  final bool connected;
  final bool hasToken;
  final DateTime? expiresAt;
  final DateTime? updatedAt;
}

class IntegrationClientConfig {
  const IntegrationClientConfig({this.clientId, this.clientSecret});

  final String? clientId;
  final String? clientSecret;
}

class IntegrationOAuthConfig {
  const IntegrationOAuthConfig({
    required this.provider,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.scopes,
    required this.redirectUri,
  });

  final IntegrationProvider provider;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final List<String> scopes;
  final String redirectUri;
}

class IntegrationOAuthService {
  IntegrationOAuthService._();
  static final IntegrationOAuthService instance = IntegrationOAuthService._();

  static const String redirectUri = 'nduproject://oauth2redirect';

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
  };

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  IntegrationOAuthConfig configFor(IntegrationProvider provider) => _configs[provider]!;

  Future<IntegrationClientConfig> loadClientConfig(IntegrationProvider provider) async {
    final clientId = await _storage.read(key: _key(provider, 'client_id'));
    final clientSecret = await _storage.read(key: _key(provider, 'client_secret'));
    return IntegrationClientConfig(clientId: clientId, clientSecret: clientSecret);
  }

  Future<void> saveClientConfig({
    required IntegrationProvider provider,
    required String clientId,
    String? clientSecret,
  }) async {
    await _storage.write(key: _key(provider, 'client_id'), value: clientId);
    if (clientSecret != null) {
      await _storage.write(key: _key(provider, 'client_secret'), value: clientSecret);
    }
  }

  Future<IntegrationAuthState> loadState(IntegrationProvider provider) async {
    final accessToken = await _storage.read(key: _key(provider, 'access_token'));
    final expiresRaw = await _storage.read(key: _key(provider, 'expires_at'));
    final updatedRaw = await _storage.read(key: _key(provider, 'updated_at'));
    final expiresAt = expiresRaw == null ? null : DateTime.tryParse(expiresRaw);
    final updatedAt = updatedRaw == null ? null : DateTime.tryParse(updatedRaw);
    final hasToken = (accessToken ?? '').isNotEmpty;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now().subtract(const Duration(minutes: 1)));
    return IntegrationAuthState(
      connected: hasToken && !isExpired,
      hasToken: hasToken,
      expiresAt: expiresAt,
      updatedAt: updatedAt,
    );
  }

  Future<IntegrationAuthState> connect({
    required IntegrationProvider provider,
    required String clientId,
    String? clientSecret,
    List<String>? scopesOverride,
  }) async {
    final config = _configs[provider]!;
    final scopes = (scopesOverride == null || scopesOverride.isEmpty) ? config.scopes : scopesOverride;
    final secret = (clientSecret ?? '').trim();
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        config.redirectUri,
        serviceConfiguration: AuthorizationServiceConfiguration(
          authorizationEndpoint: config.authorizationEndpoint,
          tokenEndpoint: config.tokenEndpoint,
        ),
        scopes: scopes,
        clientSecret: secret.isEmpty ? null : secret,
      ),
    );

    await _storage.write(key: _key(provider, 'access_token'), value: result.accessToken);
    await _storage.write(key: _key(provider, 'refresh_token'), value: result.refreshToken);
    if (result.accessTokenExpirationDateTime != null) {
      await _storage.write(
        key: _key(provider, 'expires_at'),
        value: result.accessTokenExpirationDateTime!.toIso8601String(),
      );
    }
    await _storage.write(key: _key(provider, 'updated_at'), value: DateTime.now().toIso8601String());
    return loadState(provider);
  }

  Future<void> disconnect(IntegrationProvider provider) async {
    final keys = [
      _key(provider, 'access_token'),
      _key(provider, 'refresh_token'),
      _key(provider, 'expires_at'),
      _key(provider, 'updated_at'),
    ];
    for (final key in keys) {
      await _storage.delete(key: key);
    }
  }

  String _key(IntegrationProvider provider, String field) => 'integration_${provider.name}_$field';
}
