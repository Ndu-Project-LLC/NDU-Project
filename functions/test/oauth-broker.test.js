'use strict';

// Unit tests for the accounting OAuth broker (functions/oauth-broker.js).
// Run with: npm test  (from functions/)

const { test } = require('node:test');
const assert = require('node:assert');

const {
  PROVIDERS,
  allowedRedirectUris,
  isAllowedRedirectUri,
  normalizeTenantHost,
  publicProviderConfig,
  endpointsFor,
  buildAuthorizationUrl,
  buildTokenRequest,
  exchangeCode,
  refreshAccessToken,
} = require('../oauth-broker.js');

const REDIRECT = 'https://nduproject.com/oauth/callback';

const ENV = {
  QUICKBOOKS_CLIENT_ID: 'qb-id',
  QUICKBOOKS_CLIENT_SECRET: 'qb-secret',
  XERO_CLIENT_ID: 'xero-id',
  XERO_CLIENT_SECRET: 'xero-secret',
  SAGE_CLIENT_ID: 'sage-id',
  SAGE_CLIENT_SECRET: 'sage-secret',
  SAP_CLIENT_ID: 'sap-id',
  SAP_CLIENT_SECRET: 'sap-secret',
};

/** A fetch stand-in that records the request and replies with `payload`. */
function fakeFetch(payload, { ok = true, status = 200 } = {}) {
  const calls = [];
  const impl = async (url, options) => {
    calls.push({ url, options });
    return {
      ok,
      status,
      text: async () => (typeof payload === 'string' ? payload : JSON.stringify(payload)),
    };
  };
  return { impl, calls };
}

// ── Registry ────────────────────────────────────────────────────────────────

test('the registry covers exactly the four accounting connectors', () => {
  assert.deepStrictEqual(
    Object.keys(PROVIDERS).sort(),
    ['quickbooks', 'sage', 'sap', 'xero']
  );
});

test('each provider pins its vendor endpoints and scopes', () => {
  // These literals must match lib/services/integration_oauth_service.dart.
  assert.strictEqual(
    PROVIDERS.quickbooks.authorizeUrl,
    'https://appcenter.intuit.com/connect/oauth2'
  );
  assert.strictEqual(
    PROVIDERS.quickbooks.tokenUrl,
    'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer'
  );
  assert.deepStrictEqual(PROVIDERS.quickbooks.scopes, [
    'com.intuit.quickbooks.accounting',
  ]);

  assert.strictEqual(
    PROVIDERS.xero.authorizeUrl,
    'https://login.xero.com/identity/connect/authorize'
  );
  assert.strictEqual(
    PROVIDERS.xero.tokenUrl,
    'https://identity.xero.com/connect/token'
  );
  assert.ok(PROVIDERS.xero.scopes.includes('accounting.transactions'));

  assert.strictEqual(
    PROVIDERS.sage.authorizeUrl,
    'https://api.intacct.com/ia/api/v1/oauth2/authorize'
  );
  assert.strictEqual(
    PROVIDERS.sage.tokenUrl,
    'https://api.intacct.com/ia/api/v1/oauth2/token'
  );

  // SAP is tenant-scoped and sends no scope parameter.
  assert.strictEqual(PROVIDERS.sap.requiresTenantHost, true);
  assert.deepStrictEqual(PROVIDERS.sap.scopes, []);
});

test('publicProviderConfig never exposes the client secret', () => {
  const config = publicProviderConfig('quickbooks', ENV);
  assert.strictEqual(config.clientId, 'qb-id');
  assert.strictEqual(config.configured, true);
  assert.strictEqual(config.requiresTenantHost, false);
  // The whole serialised payload must not contain the secret.
  assert.ok(!JSON.stringify(config).includes('qb-secret'));
  assert.strictEqual(config.clientSecret, undefined);
});

test('an unconfigured provider reports configured:false', () => {
  const config = publicProviderConfig('xero', { XERO_CLIENT_ID: 'xero-id' });
  assert.strictEqual(config.configured, false);
  assert.strictEqual(publicProviderConfig('netsuite', ENV), null);
});

// ── Tenant host handling ────────────────────────────────────────────────────

test('normalizeTenantHost accepts a bare subdomain, a host and a full URL', () => {
  assert.strictEqual(
    normalizeTenantHost('acme'),
    'acme.authentication.sap.hana.ondemand.com'
  );
  assert.strictEqual(
    normalizeTenantHost('acme.authentication.sap.hana.ondemand.com'),
    'acme.authentication.sap.hana.ondemand.com'
  );
  assert.strictEqual(
    normalizeTenantHost('https://acme.authentication.sap.hana.ondemand.com/oauth/authorize?x=1'),
    'acme.authentication.sap.hana.ondemand.com'
  );
  assert.strictEqual(normalizeTenantHost('   '), '');
});

test('endpointsFor substitutes the tenant and refuses to build without one', () => {
  const sap = endpointsFor('sap', 'acme');
  assert.strictEqual(sap.authorizeUrl, 'https://acme.authentication.sap.hana.ondemand.com/oauth/authorize');
  assert.strictEqual(sap.tokenUrl, 'https://acme.authentication.sap.hana.ondemand.com/oauth/token');
  assert.throws(() => endpointsFor('sap', ''), /tenant host/);
  // Non-tenant providers are unaffected.
  assert.strictEqual(
    endpointsFor('xero').tokenUrl,
    'https://identity.xero.com/connect/token'
  );
  assert.throws(() => endpointsFor('netsuite'), /Unsupported provider/);
});

// ── Authorization request ───────────────────────────────────────────────────

test('the authorization URL carries PKCE, state and the provider scopes', () => {
  const url = new URL(
    buildAuthorizationUrl({
      provider: 'quickbooks',
      clientId: 'qb-id',
      redirectUri: REDIRECT,
      state: 'state-123',
      codeChallenge: 'challenge-abc',
    })
  );
  assert.strictEqual(url.origin + url.pathname, 'https://appcenter.intuit.com/connect/oauth2');
  assert.strictEqual(url.searchParams.get('client_id'), 'qb-id');
  assert.strictEqual(url.searchParams.get('redirect_uri'), REDIRECT);
  assert.strictEqual(url.searchParams.get('response_type'), 'code');
  assert.strictEqual(url.searchParams.get('state'), 'state-123');
  assert.strictEqual(url.searchParams.get('code_challenge'), 'challenge-abc');
  assert.strictEqual(url.searchParams.get('code_challenge_method'), 'S256');
  assert.strictEqual(
    url.searchParams.get('scope'),
    'com.intuit.quickbooks.accounting'
  );
});

test('SAP authorization omits an empty scope parameter', () => {
  const url = new URL(
    buildAuthorizationUrl({
      provider: 'sap',
      clientId: 'sap-id',
      redirectUri: REDIRECT,
      state: 's',
      codeChallenge: 'c',
      tenantHost: 'acme',
    })
  );
  assert.strictEqual(
    url.origin + url.pathname,
    'https://acme.authentication.sap.hana.ondemand.com/oauth/authorize'
  );
  assert.strictEqual(url.searchParams.has('scope'), false);
});

test('authorization requires a client id and a redirect URI', () => {
  assert.throws(
    () => buildAuthorizationUrl({ provider: 'xero', redirectUri: REDIRECT }),
    /client id/
  );
  assert.throws(
    () => buildAuthorizationUrl({ provider: 'xero', clientId: 'x' }),
    /redirect URI/
  );
});

// ── Token exchange ──────────────────────────────────────────────────────────

test('the token request carries the code, verifier and redirect URI', () => {
  const request = buildTokenRequest({
    provider: 'quickbooks',
    code: 'auth-code',
    codeVerifier: 'verifier-1',
    redirectUri: REDIRECT,
    env: ENV,
  });
  assert.strictEqual(
    request.url,
    'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer'
  );
  const body = new URLSearchParams(request.body);
  assert.strictEqual(body.get('grant_type'), 'authorization_code');
  assert.strictEqual(body.get('code'), 'auth-code');
  assert.strictEqual(body.get('code_verifier'), 'verifier-1');
  assert.strictEqual(body.get('redirect_uri'), REDIRECT);
  assert.strictEqual(body.get('client_id'), 'qb-id');
  assert.strictEqual(body.get('client_secret'), 'qb-secret');
  assert.strictEqual(request.headers.Authorization, undefined);
});

test('providers that want basic auth send the secret in the header instead', () => {
  const request = buildTokenRequest({
    provider: 'xero',
    code: 'auth-code',
    redirectUri: REDIRECT,
    env: ENV,
  });
  const expected = 'Basic ' + Buffer.from('xero-id:xero-secret').toString('base64');
  assert.strictEqual(request.headers.Authorization, expected);
  // ...and not in the body.
  const body = new URLSearchParams(request.body);
  assert.strictEqual(body.get('client_secret'), null);
});

test('a provider without server credentials is refused, not guessed at', () => {
  assert.throws(
    () =>
      buildTokenRequest({
        provider: 'xero',
        code: 'c',
        redirectUri: REDIRECT,
        env: {},
      }),
    /not configured on the server/
  );
});

test('exchangeCode redeems the code and reports expiry from expires_in', async () => {
  const { impl, calls } = fakeFetch({
    access_token: 'access-1',
    refresh_token: 'refresh-1',
    expires_in: 3600,
    token_type: 'bearer',
    scope: 'com.intuit.quickbooks.accounting',
  });

  const before = Date.now();
  const tokens = await exchangeCode({
    provider: 'quickbooks',
    code: 'auth-code',
    codeVerifier: 'verifier-1',
    redirectUri: REDIRECT,
    env: ENV,
    fetchImpl: impl,
  });

  assert.strictEqual(calls.length, 1);
  assert.strictEqual(
    calls[0].url,
    'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer'
  );
  assert.strictEqual(tokens.accessToken, 'access-1');
  assert.strictEqual(tokens.refreshToken, 'refresh-1');
  assert.deepStrictEqual(tokens.scopes, ['com.intuit.quickbooks.accounting']);
  const expiresAt = Date.parse(tokens.expiresAt);
  assert.ok(expiresAt >= before + 3599 * 1000, 'expiry is derived from expires_in');
});

test('a vendor rejection surfaces the error code but not the request', async () => {
  const { impl } = fakeFetch(
    { error: 'invalid_grant', error_description: 'code already used' },
    { ok: false, status: 400 }
  );

  await assert.rejects(
    exchangeCode({
      provider: 'xero',
      code: 'auth-code',
      redirectUri: REDIRECT,
      env: ENV,
      fetchImpl: impl,
    }),
    (error) => {
      assert.match(error.message, /code already used/);
      assert.ok(!error.message.includes('xero-secret'), 'no secret in the error');
      return true;
    }
  );
});

test('an unregistered redirect URI is refused before any request is made', async () => {
  const { impl, calls } = fakeFetch({ access_token: 'x' });
  await assert.rejects(
    exchangeCode({
      provider: 'quickbooks',
      code: 'c',
      redirectUri: 'https://attacker.example/oauth/callback',
      env: ENV,
      fetchImpl: impl,
    }),
    /not registered/
  );
  assert.strictEqual(calls.length, 0, 'no token request escaped to the vendor');
});

test('the redirect allow-list only grows for local development on request', () => {
  const base = allowedRedirectUris({});
  assert.ok(base.includes(REDIRECT));
  assert.ok(!base.some((uri) => uri.startsWith('http://localhost')));

  const local = allowedRedirectUris({ OAUTH_ALLOW_LOCALHOST: 'true' });
  assert.ok(local.some((uri) => uri.startsWith('http://localhost')));

  const extra = allowedRedirectUris({
    OAUTH_ALLOWED_REDIRECT_URIS: 'https://app.example/cb, https://two.example/cb',
  });
  assert.ok(extra.includes('https://app.example/cb'));
  assert.ok(extra.includes('https://two.example/cb'));

  assert.strictEqual(isAllowedRedirectUri('https://evil.example/cb', {}), false);
  assert.strictEqual(isAllowedRedirectUri(REDIRECT, {}), true);
});

// ── Refresh ─────────────────────────────────────────────────────────────────

test('refreshAccessToken renews from the stored refresh token', async () => {
  const { impl, calls } = fakeFetch({
    access_token: 'access-2',
    expires_in: 1800,
    token_type: 'Bearer',
  });

  const tokens = await refreshAccessToken({
    provider: 'sage',
    refreshToken: 'refresh-1',
    env: ENV,
    fetchImpl: impl,
  });

  assert.strictEqual(calls[0].url, 'https://api.intacct.com/ia/api/v1/oauth2/token');
  const body = new URLSearchParams(calls[0].options.body);
  assert.strictEqual(body.get('grant_type'), 'refresh_token');
  assert.strictEqual(body.get('refresh_token'), 'refresh-1');
  assert.strictEqual(tokens.accessToken, 'access-2');
  // A provider that does not rotate the refresh token keeps the stored one.
  assert.strictEqual(tokens.refreshToken, 'refresh-1');
});

test('refreshAccessToken without a refresh token is a clear error', async () => {
  await assert.rejects(
    refreshAccessToken({ provider: 'sage', refreshToken: '', env: ENV }),
    /Missing refresh token/
  );
});
