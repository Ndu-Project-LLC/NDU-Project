#!/usr/bin/env node
/**
 * Firestore rules drift check.
 *
 * Guards against the 2026-09-25 incident: another app's rules ("QuizPop") were
 * deployed over NDU's rules in Firebase project ndu-d3f60. Every NDU path fell
 * into their default-deny rule, so production logged
 * `cloud_firestore/permission-denied` for `users/...`, `projects`, onboarding
 * saves, etc. Nothing in this repo had changed — only the LIVE rules had.
 *
 * This script fetches the ruleset currently released to `cloud.firestore` via
 * the Firebase Rules API and compares it against `firestore.rules` in this
 * repo. It is strictly read-only: it never deploys or modifies anything.
 *
 * Usage:
 *   node scripts/check_firestore_rules_drift.js [--project <id>] [--file <path>]
 *
 * Auth:
 *   FIREBASE_TOKEN  refresh token (CI secret, same one the deploy workflow uses)
 *   otherwise the local `firebase login` session on this machine.
 *
 * Exit codes:
 *   0  live rules match the repo
 *   1  DRIFT — live rules differ from the repo (the bug this exists to catch)
 *   2  could not determine drift (auth failure, API error, missing files)
 */

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

const RELEASE_SERVICE = 'cloud.firestore';
const RULES_API = 'https://firebaserules.googleapis.com/v1';

function fail(code, message) {
  console.error(message);
  process.exit(code);
}

function argValue(flag) {
  const i = process.argv.indexOf(flag);
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : null;
}

function resolveProject() {
  const explicit = argValue('--project') || process.env.FIREBASE_PROJECT;
  if (explicit) return explicit;
  try {
    const rc = JSON.parse(
      fs.readFileSync(path.join(__dirname, '..', '.firebaserc'), 'utf8')
    );
    const project = rc.projects && (rc.projects.default || rc.projects.staging);
    if (project) return project;
  } catch (_) {
    /* fall through */
  }
  return 'ndu-d3f60';
}

function resolveRulesFile() {
  return (
    argValue('--file') ||
    process.env.RULES_FILE ||
    path.join(__dirname, '..', 'firestore.rules')
  );
}

/**
 * OAuth client credentials are public constants inside the firebase-tools
 * package (they ship in the npm tarball, not a secret). Resolve them from a
 * local install first, then from the global install — CI installs the CLI
 * globally with `npm install -g firebase-tools`.
 */
function loadFirebaseToolsApi() {
  const candidates = [];
  try {
    candidates.push(require.resolve('firebase-tools/lib/api'));
  } catch (_) {
    /* not installed locally */
  }
  try {
    const globalRoot = execSync('npm root -g', {
      stdio: ['ignore', 'pipe', 'ignore'],
    })
      .toString()
      .trim();
    candidates.push(path.join(globalRoot, 'firebase-tools', 'lib', 'api.js'));
  } catch (_) {
    /* npm not available */
  }
  for (const candidate of candidates) {
    try {
      // eslint-disable-next-line global-require
      const api = require(candidate);
      if (typeof api.clientId === 'function' && typeof api.clientSecret === 'function') {
        return api;
      }
    } catch (_) {
      /* try the next candidate */
    }
  }
  return null;
}

function oauthClient() {
  const api = loadFirebaseToolsApi();
  if (api) {
    return { clientId: api.clientId(), clientSecret: api.clientSecret() };
  }
  if (process.env.FIREBASE_CLIENT_ID && process.env.FIREBASE_CLIENT_SECRET) {
    return {
      clientId: process.env.FIREBASE_CLIENT_ID,
      clientSecret: process.env.FIREBASE_CLIENT_SECRET,
    };
  }
  return null;
}

function localSession() {
  try {
    const cfgPath = path.join(
      os.homedir(),
      '.config',
      'configstore',
      'firebase-tools.json'
    );
    const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
    return cfg.tokens || null;
  } catch (_) {
    return null;
  }
}

async function accessToken() {
  const ciToken = process.env.FIREBASE_TOKEN;
  const local = localSession();

  // Reuse the local access token while it is still valid.
  if (!ciToken && local && local.access_token && local.expires_at) {
    if (new Date(local.expires_at) > new Date(Date.now() + 60_000)) {
      return local.access_token;
    }
  }

  const refreshToken = ciToken || (local && local.refresh_token);
  if (!refreshToken) {
    const e = new Error(
      'No credentials. Set FIREBASE_TOKEN (CI) or run `firebase login` locally.'
    );
    e.auth = true;
    throw e;
  }

  const client = oauthClient();
  if (!client) {
    const e = new Error(
      'firebase-tools is not installed — run `npm install -g firebase-tools` ' +
        '(or set FIREBASE_CLIENT_ID / FIREBASE_CLIENT_SECRET).'
    );
    e.auth = true;
    throw e;
  }

  const res = await fetch('https://www.googleapis.com/oauth2/v3/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: client.clientId,
      client_secret: client.clientSecret,
    }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || typeof data.access_token !== 'string') {
    const e = new Error(
      `Could not refresh credentials (HTTP ${res.status}: ${data.error || 'unknown'}). ` +
        'The Firebase token may be expired — re-run `firebase login:ci`.'
    );
    e.auth = true;
    throw e;
  }
  return data.access_token;
}

async function fetchJson(url, token) {
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    const reason = (body.error && body.error.message) || `HTTP ${res.status}`;
    const e = new Error(`Firebase Rules API request failed: ${reason}`);
    e.auth = res.status === 401 || res.status === 403;
    throw e;
  }
  return body;
}

async function liveRules(project) {
  const token = await accessToken();
  const releases = await fetchJson(`${RULES_API}/projects/${project}/releases`, token);
  const release = (releases.releases || []).find(
    (r) => r.name === `projects/${project}/releases/${RELEASE_SERVICE}`
  );
  if (!release) {
    const e = new Error(
      `No ${RELEASE_SERVICE} rules release found in project ${project}.`
    );
    throw e;
  }
  const ruleset = await fetchJson(`${RULES_API}/${release.rulesetName}`, token);
  // rulesets.get returns { name, source: { files } } directly; some payloads
  // wrap it one level deeper under `ruleset`.
  const source =
    ruleset.source || (ruleset.ruleset && ruleset.ruleset.source) || null;
  const files = (source && source.files) || [];
  if (files.length === 0) {
    throw new Error(`Ruleset ${release.rulesetName} contains no source files.`);
  }
  return {
    content: files.map((f) => f.content).join('\n'),
    ruleset: release.rulesetName,
    deployedAt: release.updateTime || ruleset.createTime || 'unknown',
  };
}

function normalize(text) {
  return text.replace(/\r\n/g, '\n').replace(/\s+$/, '') + '\n';
}

function reportDrift(expected, actual) {
  const want = normalize(expected).split('\n');
  const got = normalize(actual).split('\n');
  const max = Math.max(want.length, got.length);
  const lines = [];
  let shown = 0;
  for (let i = 0; i < max && shown < 40; i++) {
    if (want[i] === got[i]) continue;
    if (want[i] !== undefined) {
      lines.push(`  - (repo)  ${i + 1}: ${want[i]}`);
      shown++;
    }
    if (got[i] !== undefined && shown < 40) {
      lines.push(`  + (live)  ${i + 1}: ${got[i]}`);
      shown++;
    }
  }
  console.error(lines.join('\n'));
}

(async () => {
  const project = resolveProject();
  const file = resolveRulesFile();

  let expected;
  try {
    expected = fs.readFileSync(file, 'utf8');
  } catch (e) {
    fail(2, `✖ Cannot read rules file ${file}: ${e.message}`);
  }

  let live;
  try {
    live = await liveRules(project);
  } catch (e) {
    fail(
      2,
      `✖ Unable to read live Firestore rules for ${project}: ${e.message}` +
        (e.auth ? '' : '\n  (This is a connectivity/API problem, NOT drift.)')
    );
  }

  if (normalize(expected) === normalize(live.content)) {
    console.log(
      `✅ Live Firestore rules in ${project} match ${path.relative(process.cwd(), file)}.`
    );
    console.log(`   ruleset ${live.ruleset} (released ${live.deployedAt})`);
    return;
  }

  console.error(
    `🚨 DRIFT DETECTED — live Firestore rules in ${project} do NOT match ${path.relative(process.cwd(), file)}.`
  );
  console.error(`   live ruleset: ${live.ruleset} (released ${live.deployedAt})`);
  console.error(
    '   If another app\'s rules were deployed over NDU\'s, every read/write ' +
      'outside that app\'s paths returns permission-denied in production.'
  );
  console.error('   First differences (- repo, + live):');
  reportDrift(expected, live.content);
  console.error(
    '\n   Fix: deploy the repo rules — Actions → "Deploy Firestore Rules (Production)" ' +
      '→ type `deploy` → approve, or run:\n     firebase deploy --only firestore:rules --project ' +
      project
  );
  process.exit(1);
})().catch((e) => fail(2, `✖ Drift check failed: ${e.message}`));
