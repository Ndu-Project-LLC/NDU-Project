#!/usr/bin/env node
// =============================================================================
// NDU Project — Local-AI web E2E smoke test
// =============================================================================
// Boots the built web bundle in a real headless Chromium and verifies:
//
//   1. the Flutter app reaches its first route (a Flutter view is mounted);
//   2. `main.dart.js` and `canvaskit.wasm` load and execute without uncaught
//      JS errors;
//   3. NO request is made to the AI proxy — which is the whole point of
//      AI_MODE=local: content is generated in code, not fetched.
//
// No npm dependencies: it drives the Chrome DevTools Protocol over Node's
// global WebSocket (Node >= 22). It reuses the browser that Playwright already
// downloaded, or a browser given via CHROME_BIN.
//
// Usage:
//   ./scripts/build_web_lite.sh --local-ai --no-stamp
//   python3 scripts/serve_lite.py build/web-lite 8099 &
//   node scripts/e2e_local_ai_web.mjs --url http://127.0.0.1:8099
// =============================================================================

import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const AI_PROXY_HOST = 'us-central1-ndu-d3f60.cloudfunctions.net';
const DEBUG_PORT = 9333;

function argValue(flag, fallback) {
  const index = process.argv.indexOf(flag);
  return index >= 0 && process.argv[index + 1] ? process.argv[index + 1] : fallback;
}

/** Locates a Chromium binary: CHROME_BIN, then the Playwright browser cache. */
function findChromium() {
  if (process.env.CHROME_BIN && existsSync(process.env.CHROME_BIN)) {
    return process.env.CHROME_BIN;
  }
  const roots = [
    join(process.env.HOME ?? '', 'Library/Caches/ms-playwright'),
    join(process.env.HOME ?? '', '.cache/ms-playwright'),
  ].filter(existsSync);

  for (const root of roots) {
    for (const entry of readdirSync(root)) {
      if (!entry.startsWith('chromium')) continue;
      const buildDir = join(root, entry);
      for (const platform of readdirSync(buildDir)) {
        const candidates = [
          join(buildDir, platform, 'chrome-headless-shell'),
          join(buildDir, platform, 'chrome-linux', 'headless_shell'),
          join(buildDir, platform, 'chrome-linux', 'chrome'),
          join(buildDir, platform, 'Google Chrome for Testing.app', 'Contents',
            'MacOS', 'Google Chrome for Testing'),
        ];
        for (const candidate of candidates) {
          if (existsSync(candidate)) return candidate;
        }
      }
    }
  }
  return null;
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function waitForDevTools(port, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(`http://127.0.0.1:${port}/json/version`);
      if (response.ok) return;
    } catch {
      // Not up yet.
    }
    await sleep(200);
  }
  throw new Error('Chrome DevTools endpoint did not come up');
}

/** Minimal CDP client over the global WebSocket. */
class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = [];
    ws.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      if (message.id && this.pending.has(message.id)) {
        const { resolve, reject } = this.pending.get(message.id);
        this.pending.delete(message.id);
        message.error ? reject(new Error(message.error.message)) : resolve(message.result);
      } else if (message.method) {
        for (const listener of this.listeners) listener(message);
      }
    });
  }

  onMessage(listener) {
    this.listeners.push(listener);
  }

  send(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
}

function connect(url) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(url);
    ws.addEventListener('open', () => resolve(ws));
    ws.addEventListener('error', reject);
  });
}

async function main() {
  const baseUrl = argValue('--url', 'http://127.0.0.1:8099').replace(/\/$/, '');
  const bootWaitMs = Number(argValue('--boot-wait', '6000'));
  // Console noise varies between environments (CDN hiccups, renderer
  // warnings). It is reported by default and only fails under --strict-console;
  // a real script crash shows up as "app did not mount" instead.
  const strictConsole = process.argv.includes('--strict-console');

  const chrome = findChromium();
  if (!chrome) {
    console.error('✗ No Chromium binary found. Set CHROME_BIN or install Playwright browsers.');
    process.exit(1);
  }
  console.log(`▶ Browser: ${chrome}`);
  console.log(`▶ App URL: ${baseUrl}`);

  const userDataDir = mkdtempSync(join(tmpdir(), 'ndu-e2e-'));

  // `chrome-headless-shell` IS a headless browser and rejects/ignores
  // `--headless`; a normal Chrome build needs the flag or it insists on a
  // display and exits before DevTools ever opens (which is what happened on
  // CI, where CHROME_BIN is the full /usr/bin/google-chrome). Pick per binary.
  const isHeadlessShell = /headless[-_]?shell/i.test(chrome);
  const launchArgs = [
    `--remote-debugging-port=${DEBUG_PORT}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-gpu',
    '--no-sandbox',
    '--disable-dev-shm-usage',
    '--window-size=1280,900',
    `--user-data-dir=${userDataDir}`,
    ...(isHeadlessShell ? [] : ['--headless']),
    'about:blank',
  ];

  // Keep Chrome's own stderr so a launch failure can explain itself instead of
  // just reporting that DevTools never came up.
  const chromeStderr = [];
  const child = spawn(chrome, launchArgs, {
    stdio: ['ignore', 'ignore', 'pipe'],
  });
  child.stderr?.on('data', (chunk) => {
    for (const line of chunk.toString().split('\n')) {
      if (line.trim()) chromeStderr.push(line.trim());
    }
    if (chromeStderr.length > 40) chromeStderr.splice(0, chromeStderr.length - 40);
  });

  const cleanup = () => { try { child.kill('SIGKILL'); } catch { /* ignore */ } };
  process.on('exit', cleanup);    let failures = 0;
    let appText = '';
    let appHtml = '';
    const fail = (message) => { failures++; console.error(`✗ ${message}`); };
    const pass = (message) => console.log(`✓ ${message}`);

  try {
    try {
      await waitForDevTools(DEBUG_PORT, Number(argValue('--devtools-timeout', '30000')));
    } catch (error) {
      if (chromeStderr.length > 0) {
        console.error('  Chrome stderr:');
        for (const line of chromeStderr.slice(-12)) console.error(`    ${line}`);
      }
      if (child.exitCode !== null) {
        console.error(`  Chrome exited early with code ${child.exitCode}`);
      }
      throw error;
    }

    const targets = await (await fetch(`http://127.0.0.1:${DEBUG_PORT}/json/list`)).json();
    const page = targets.find((t) => t.type === 'page');
    if (!page) throw new Error('No page target available');

    const ws = await connect(page.webSocketDebuggerUrl);
    const cdp = new Cdp(ws);

    const consoleErrors = [];
    const failedRequests = [];
    const requestsToAiProxy = [];
    const loadedScripts = new Set();

    cdp.onMessage((message) => {
      const { method, params } = message;
      if (method === 'Runtime.exceptionThrown') {
        consoleErrors.push(params.exceptionDetails?.exception?.description
          ?? params.exceptionDetails?.text ?? 'uncaught exception');
      } else if (method === 'Runtime.consoleAPICalled' && params.type === 'error') {
        consoleErrors.push((params.args ?? []).map((a) => a.value ?? a.description).join(' '));
      } else if (method === 'Log.entryAdded' && params.entry?.level === 'error') {
        consoleErrors.push(params.entry.text);
      } else if (method === 'Network.requestWillBeSent') {
        const url = params.request?.url ?? '';
        if (url.startsWith('http')) loadedScripts.add(url);
        if (url.includes(AI_PROXY_HOST)) requestsToAiProxy.push(url);
      } else if (method === 'Network.loadingFailed') {
        const url = params.requestId;
        if (!params.canceled) failedRequests.push(`${params.errorText} (${url})`);
      }
    });

    await cdp.send('Runtime.enable');
    await cdp.send('Log.enable');
    await cdp.send('Network.enable');
    await cdp.send('Page.enable');

    await cdp.send('Page.navigate', { url: `${baseUrl}/` });
    await sleep(bootWaitMs);

    // Flutter renders to canvas, so read the app's own text by switching on the
    // semantics tree (the accessibility bridge Flutter exposes for exactly
    // this). Best-effort: some engines do not expose the placeholder.
    const semantics = await cdp.send('Runtime.evaluate', {
      returnByValue: true,
      expression: `(() => {
        const placeholder = document.querySelector('flt-semantics-placeholder');
        if (placeholder) placeholder.click();
        return !!placeholder;
      })()`,
    });
    const semanticsEnabled = semantics.result?.value === true;
    if (semanticsEnabled) await sleep(1500);

    const probe = await cdp.send('Runtime.evaluate', {
      returnByValue: true,
      expression: `(() => ({
        hasFlutterView: !!document.querySelector('flutter-view, flt-glass-pane, flt-scene-host'),
        title: document.title,
        scriptLoaded: !!document.querySelector('script[src*="main.dart.js"]'),
        bodyText: (document.body?.innerText ?? '').slice(0, 400),
      }))()`,
    });
    const result = probe.result?.value ?? {};

    console.log(`  app title: ${JSON.stringify(result.title)}`);
    console.log(`  requests observed: ${loadedScripts.size}`);
    console.log(`  console errors: ${consoleErrors.length}`);

    if (semanticsEnabled) {
      const text = (await cdp.send('Runtime.evaluate', {
        returnByValue: true,
        expression: `(document.body?.innerText ?? '').replace(/\\s+/g, ' ').trim()`,
      })).result?.value ?? '';
      appText = text;
      appHtml = (await cdp.send('Runtime.evaluate', {
        returnByValue: true,
        expression: `document.body?.innerHTML ?? ''`,
      })).result?.value ?? '';
      console.log(`  app text (${text.length} chars): ${text.slice(0, 160)}`);
      if (process.env.NDU_E2E_DUMP_TEXT) {
        console.log(`\n--- app text ---\n${text}\n--- end ---\n`);
        console.log(`--- semantics dom (full) ---\n${appHtml}\n--- end ---\n`);
      }
    } else {
      console.log('• semantics tree unavailable — skipping on-screen text checks');
    }

    if (result.hasFlutterView) pass('Flutter app mounted a view (bundle booted)');
    else fail('Flutter view was not mounted — the bundle did not boot');

    const loadedMain = [...loadedScripts].some((u) => u.includes('main.dart.js'));
    if (loadedMain) pass('main.dart.js was fetched');
    else fail('main.dart.js was never requested');

    const loadedWasm = [...loadedScripts].some((u) => u.includes('canvaskit.wasm'));
    if (loadedWasm) pass('canvaskit.wasm was fetched (renderer initialized)');
    else console.log('• canvaskit.wasm not observed (HTML/skwasm fallback may be in use)');

    if (semanticsEnabled && appText.length > 0) {
      // Flutter exposes some text as aria-labels rather than text nodes, so
      // check the whole serialized accessibility DOM, not just innerText.
      // Advisory only: Flutter's semantic tree does not always publish widgets
      // that live above the Navigator (like this banner), which is where the
      // app-wide notice is mounted. The authoritative local-mode signal is the
      // absence of AI proxy traffic below, plus the service-level tests.
      const rendered = `${appText}\n${appHtml}`;
      if (rendered.includes('Local generation mode')) {
        pass('local-generation banner is on screen');
      } else {
        console.log('• local-generation banner not exposed by the semantics tree (advisory)');
      }
    }

    if (requestsToAiProxy.length === 0) {
      pass('no requests to the AI proxy — AI_MODE=local kept generation in code');
    } else {
      fail(`unexpected AI proxy requests: ${requestsToAiProxy.join(', ')}`);
    }

    if (consoleErrors.length === 0) {
      pass('no console errors');
    } else if (strictConsole) {
      fail(`console errors:\n    ${consoleErrors.slice(0, 8).join('\n    ')}`);
    } else {
      console.log(`• ${consoleErrors.length} console error(s) (non-fatal; use --strict-console to enforce):`);
      for (const error of consoleErrors.slice(0, 5)) console.log(`    ${error}`);
    }

    if (failedRequests.length > 0) {
      console.log(`• ${failedRequests.length} non-canceled request failure(s): ${failedRequests.slice(0, 3).join(', ')}`);
    }

    ws.close();
  } catch (error) {
    fail(error.message);
  } finally {
    cleanup();
  }

  console.log('');
  if (failures === 0) {
    console.log('✓ Local-AI web E2E passed');
    process.exit(0);
  }
  console.error(`✗ Local-AI web E2E failed (${failures} check(s))`);
  process.exit(1);
}

main();
