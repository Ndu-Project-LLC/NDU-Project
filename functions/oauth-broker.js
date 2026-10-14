'use strict';

/**
 * Server-side OAuth 2.0 broker for the accounting connectors.
 *
 * Why this exists: QuickBooks Online, Xero, Sage Intacct and SAP S/4HANA are
 * all confidential clients — the token exchange needs the client secret, and
 * the vendors do not allow the exchange from a browser. The Flutter web build
 * therefore cannot complete the flow on its own (the mobile/desktop builds use
 * flutter_appauth directly). This module holds the secret, performs the
 * exchange, and hands back only the tokens.
 *
 * The provider registry below MIRRORS `lib/services/integration_oauth_service.dart`.
 * Change one and the other must change with it — both test suites pin the same
 * literal URLs and scopes so drift fails a test rather than shipping silently.
 *
 * Credentials are configuration, never code:
 *   firebase functions:secrets:set QUICKBOOKS_CLIENT_SECRET
 *   (plus <PROVIDER>_CLIENT_ID, which is not secret, via functions/.env)
 */

/** Providers this broker will talk to, keyed by the app's provider name. */
const PROVIDERS = {
  quickbooks: {
    label: 'QuickBooks Online',
    authorizeUrl: 'https://appcenter.intuit.com/connect/oauth2',
    tokenUrl: 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer',
    scopes: ['com.intuit.quickbooks.accounting'],
    clientIdEnv: 'QUICKBOOKS_CLIENT_ID',
    clientSecretEnv: 'QUICKBOOKS_CLIENT_SECRET',
    // Intuit wants the client credentials in the token request body.
    tokenAuth: 'body',
    // The callback carries the company (realm) id.
    realmParam: 'realmId',
  },
  xero: {
    label: 'Xero',
    authorizeUrl: 'https://login.xero.com/identity/connect/authorize',
    tokenUrl: 'https://identity.xero.com/connect/token',
    scopes: [
      'openid',
      'profile',
      'email',
      'accounting.transactions',
      'offline_access',
    ],
    clientIdEnv: 'XERO_CLIENT_ID',
    clientSecretEnv: 'XERO_CLIENT_SECRET',
    tokenAuth: 'basic',
  },
  sage: {
    label: 'Sage Intacct',
    authorizeUrl: 'https://api.intacct.com/ia/api/v1/oauth2/authorize',
    tokenUrl: 'https://api.intacct.com/ia/api/v1/oauth2/token',
    scopes: ['openid', 'profile', 'email', 'offline_access'],
    clientIdEnv: 'SAGE_CLIENT_ID',
    clientSecretEnv: 'SAGE_CLIENT_SECRET',
    tokenAuth: 'body',
  },
  sap: {
    label: 'SAP S/4HANA',
    // SAP authorises against the customer's own tenant.
    authorizeUrl: 'https://{tenant}/oauth/authorize',
    tokenUrl: 'https://{tenant}/oauth/token',
    scopes: [],
    clientIdEnv: 'SAP_CLIENT_ID',
    clientSecretEnv: 'SAP_CLIENT_SECRET',
    tokenAuth: 'body',
    requiresTenantHost: true,
  },
};

/**
 * Redirect URIs the app is allowed to hand back to. Kept as an allow-list so a
 * tampered client cannot make the broker post a code (and its response) to an
 * attacker-controlled URL.
 */
const DEFAULT_REDIRECT_URIS = [
  'https://nduproject.com/oauth/callback',
  'https://www.nduproject.com/oauth/callback',
  'https://admin.nduproject.com/oauth/callback',
  'https://staging.admin.nduproject.com/oauth/callback',
  'https://ndu-d3f60.web.app/oauth/callback',
  'https://ndu-d3f60.firebaseapp.com/oauth/callback',
];

function allowedRedirectUris(env = process.env) {
  const configured = String(env.OAUTH_ALLOWED_REDIRECT_URIS || '')
    .split(',')
    .map((uri) => uri.trim())
    .filter(Boolean);
  const list = DEFAULT_REDIRECT_URIS.concat(configured);
  // Local development (flutter run -d chrome).
  if (env.OAUTH_ALLOW_LOCALHOST === 'true') {
    list.push('http://localhost:8080/oauth/callback');
    list.push('http://127.0.0.1:8080/oauth/callback');
  }
  return list;
}

function isAllowedRedirectUri(redirectUri, env = process.env) {
  const value = String(redirectUri || '').trim();
  if (!value) return false;
  return allowedRedirectUris(env).includes(value);
}

/**
 * Reduces the tenant input to a bare host, defensively.
 *
 * Mirrors `IntegrationOAuthService.normalizeTenantHost` in the Flutter app: a
 * short subdomain expands to the SAP tenant host, and a full URL is stripped
 * back to its host. Returns '' when nothing usable is left, so a caller can
 * never build `https:///oauth/token`.
 */
function normalizeTenantHost(raw) {
  let value = String(raw || '').trim();
  if (!value) return '';
  value = value.replace(/^https?:\/\//i, '');
  for (const separator of ['/', '?', '#']) {
    const index = value.indexOf(separator);
    if (index !== -1) value = value.slice(0, index);
  }
  if (!value.includes('.') && !value.includes(':')) {
    return `${value}.authentication.sap.hana.ondemand.com`;
  }
  return value;
}

/** Provider registry entry, or null for an unknown provider name. */
function providerFor(provider) {
  return PROVIDERS[String(provider || '').toLowerCase()] || null;
}

function clientIdFor(provider, env = process.env) {
  const entry = providerFor(provider);
  if (!entry) return '';
  return String(env[entry.clientIdEnv] || '').trim();
}

function clientSecretFor(provider, env = process.env) {
  const entry = providerFor(provider);
  if (!entry) return '';
  return String(env[entry.clientSecretEnv] || '').trim();
}

/** True when both halves of the provider's client credentials are configured. */
function isProviderConfigured(provider, env = process.env) {
  return Boolean(clientIdFor(provider, env) && clientSecretFor(provider, env));
}

/**
 * What the client is told about a provider: the public client id, the
 * authorize endpoint and the scopes. Never the secret.
 */
function publicProviderConfig(provider, env = process.env) {
  const entry = providerFor(provider);
  if (!entry) return null;
  return {
    provider: String(provider).toLowerCase(),
    label: entry.label,
    clientId: clientIdFor(provider, env),
    authorizeUrl: entry.authorizeUrl,
    scopes: entry.scopes.slice(),
    requiresTenantHost: entry.requiresTenantHost === true,
    configured: isProviderConfigured(provider, env),
    realmParam: entry.realmParam || null,
  };
}

/** Endpoints for a provider, with the SAP tenant substituted in. */
function endpointsFor(provider, tenantHost) {
  const entry = providerFor(provider);
  if (!entry) {
    throw new Error(`Unsupported provider: ${provider}`);
  }
  if (!entry.requiresTenantHost) {
    return { authorizeUrl: entry.authorizeUrl, tokenUrl: entry.tokenUrl };
  }
  const host = normalizeTenantHost(tenantHost);
  if (!host) {
    throw new Error(`${entry.label} needs the tenant host.`);
  }
  return {
    authorizeUrl: entry.authorizeUrl.replace('{tenant}', host),
    tokenUrl: entry.tokenUrl.replace('{tenant}', host),
  };
}

/**
 * Builds the URL the browser is sent to for consent (PKCE, S256).
 *
 * `state` and `codeChallenge` are generated by the client and echoed back
 * unchanged.
 */
function buildAuthorizationUrl({
  provider,
  clientId,
  redirectUri,
  state,
  codeChallenge,
  tenantHost,
  scopes,
}) {
  const entry = providerFor(provider);
  if (!entry) throw new Error(`Unsupported provider: ${provider}`);
  if (!clientId) throw new Error('Missing OAuth client id.');
  if (!redirectUri) throw new Error('Missing redirect URI.');

  const { authorizeUrl } = endpointsFor(provider, tenantHost);
  const url = new URL(authorizeUrl);
  url.searchParams.set('client_id', clientId);
  url.searchParams.set('redirect_uri', redirectUri);
  url.searchParams.set('response_type', 'code');
  if (state) url.searchParams.set('state', state);
  if (codeChallenge) {
    url.searchParams.set('code_challenge', codeChallenge);
    url.searchParams.set('code_challenge_method', 'S256');
  }
  const requested = Array.isArray(scopes) && scopes.length ? scopes : entry.scopes;
  // Providers that authorise through their client registration (SAP S/4HANA)
  // must not receive an empty `scope=` parameter.
  if (requested.length) url.searchParams.set('scope', requested.join(' '));
  return url.toString();
}

/** The HTTP request that redeems an authorization code. */
function buildTokenRequest({
  provider,
  code,
  codeVerifier,
  redirectUri,
  tenantHost,
  env = process.env,
}) {
  const entry = providerFor(provider);
  if (!entry) throw new Error(`Unsupported provider: ${provider}`);
  if (!code) throw new Error('Missing authorization code.');

  const clientId = clientIdFor(provider, env);
  const clientSecret = clientSecretFor(provider, env);
  if (!clientId || !clientSecret) {
    throw new Error(`${entry.label} is not configured on the server.`);
  }

  const { tokenUrl } = endpointsFor(provider, tenantHost);
  const body = new URLSearchParams();
  body.set('grant_type', 'authorization_code');
  body.set('code', code);
  body.set('redirect_uri', redirectUri);
  if (codeVerifier) body.set('code_verifier', codeVerifier);

  const headers = {
    'Content-Type': 'application/x-www-form-urlencoded',
    Accept: 'application/json',
  };

  if (entry.tokenAuth === 'basic') {
    headers.Authorization =
      'Basic ' + Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
  } else {
    body.set('client_id', clientId);
    body.set('client_secret', clientSecret);
  }

  return { url: tokenUrl, headers, body: body.toString() };
}

/**
 * Redeems an authorization code and returns the tokens.
 *
 * `fetchImpl` is injected so the exchange is unit-testable without a network
 * call. Errors are sanitised: a vendor message is surfaced, but the request
 * (which carries the client secret) and the tokens are never included.
 */
async function exchangeCode({
  provider,
  code,
  codeVerifier,
  redirectUri,
  tenantHost,
  env = process.env,
  fetchImpl = globalThis.fetch,
}) {
  if (!isAllowedRedirectUri(redirectUri, env)) {
    throw new Error('Redirect URI is not registered for this app.');
  }
  const request = buildTokenRequest({
    provider,
    code,
    codeVerifier,
    redirectUri,
    tenantHost,
    env,
  });

  const response = await fetchImpl(request.url, {
    method: 'POST',
    headers: request.headers,
    body: request.body,
  });

  const text = await response.text();
  let payload = {};
  try {
    payload = text ? JSON.parse(text) : {};
  } catch (_) {
    payload = {};
  }

  if (!response.ok || !payload.access_token) {
    // Vendors report e.g. {"error":"invalid_grant"}. Pass the error code (never
    // the request body) back so the user gets something actionable.
    const detail =
      payload.error_description || payload.error || `HTTP ${response.status}`;
    throw new Error(`The provider rejected the exchange: ${detail}`);
  }

  const expiresIn = Number(payload.expires_in);
  return {
    accessToken: payload.access_token,
    refreshToken: payload.refresh_token || null,
    scopes: typeof payload.scope === 'string'
      ? payload.scope.split(' ').filter(Boolean)
      : [],
    expiresAt: Number.isFinite(expiresIn) && expiresIn > 0
      ? new Date(Date.now() + expiresIn * 1000).toISOString()
      : null,
    tokenType: payload.token_type || 'Bearer',
  };
}

/**
 * Renews an access token from a stored refresh token.
 *
 * Same contract as [exchangeCode]: the secret stays here and only the tokens
 * travel back.
 */
async function refreshAccessToken({
  provider,
  refreshToken,
  tenantHost,
  env = process.env,
  fetchImpl = globalThis.fetch,
}) {
  const entry = providerFor(provider);
  if (!entry) throw new Error(`Unsupported provider: ${provider}`);
  if (!refreshToken) throw new Error('Missing refresh token.');

  const clientId = clientIdFor(provider, env);
  const clientSecret = clientSecretFor(provider, env);
  if (!clientId || !clientSecret) {
    throw new Error(`${entry.label} is not configured on the server.`);
  }

  const { tokenUrl } = endpointsFor(provider, tenantHost);
  const body = new URLSearchParams();
  body.set('grant_type', 'refresh_token');
  body.set('refresh_token', refreshToken);

  const headers = {
    'Content-Type': 'application/x-www-form-urlencoded',
    Accept: 'application/json',
  };
  if (entry.tokenAuth === 'basic') {
    headers.Authorization =
      'Basic ' + Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
  } else {
    body.set('client_id', clientId);
    body.set('client_secret', clientSecret);
  }

  const response = await fetchImpl(tokenUrl, {
    method: 'POST',
    headers,
    body: body.toString(),
  });

  const text = await response.text();
  let payload = {};
  try {
    payload = text ? JSON.parse(text) : {};
  } catch (_) {
    payload = {};
  }

  if (!response.ok || !payload.access_token) {
    const detail =
      payload.error_description || payload.error || `HTTP ${response.status}`;
    throw new Error(`The provider rejected the refresh: ${detail}`);
  }

  const expiresIn = Number(payload.expires_in);
  return {
    accessToken: payload.access_token,
    refreshToken: payload.refresh_token || refreshToken,
    scopes: typeof payload.scope === 'string'
      ? payload.scope.split(' ').filter(Boolean)
      : [],
    expiresAt: Number.isFinite(expiresIn) && expiresIn > 0
      ? new Date(Date.now() + expiresIn * 1000).toISOString()
      : null,
    tokenType: payload.token_type || 'Bearer',
  };
}

module.exports = {
  PROVIDERS,
  DEFAULT_REDIRECT_URIS,
  allowedRedirectUris,
  isAllowedRedirectUri,
  normalizeTenantHost,
  providerFor,
  clientIdFor,
  clientSecretFor,
  isProviderConfigured,
  publicProviderConfig,
  endpointsFor,
  buildAuthorizationUrl,
  buildTokenRequest,
  exchangeCode,
  refreshAccessToken,
};
