#!/usr/bin/env node
'use strict';

/**
 * Minimal token gate in front of Ollama's OpenAI-compatible API.
 *
 * The Oracle Always-Free VM has no firewall between its public IP and this
 * container's published port, so Ollama itself must never be exposed. This
 * gate is the only public entry point:
 *
 *   Flutter app -> Firebase openaiProxy -> http://<vm-ip>:8080/v1/chat/completions
 *                                        -> gate (Bearer token check) -> Ollama:11434
 *
 * It accepts exactly the OpenAI Chat Completions shape the app already sends
 * and translates the few OpenAI-specific fields (model, max_completion_tokens,
 * response_format, reasoning_effort) into what Ollama understands.
 *
 * Zero runtime dependencies — Node built-ins only.
 */

const http = require('http');
const crypto = require('crypto');

const PORT = Number(process.env.PORT || 8080);
const HOST = process.env.HOST || '0.0.0.0';
const LLM_API_TOKEN = process.env.LLM_API_TOKEN || '';
const ALLOW_LOCAL_AUTH = process.env.LLM_ALLOW_LOCAL_AUTH === 'true';
const OLLAMA_HOST = (process.env.OLLAMA_HOST || 'http://ollama:11434').replace(/\/+$/, '');
const LLM_MODEL = (process.env.LLM_MODEL || '').trim();
const TIMEOUT_MS = Number(process.env.LLM_TIMEOUT_MS || 240000);

/** Constant-time string comparison to avoid trivial token-timing leaks. */
function safeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

function isAuthorized(req) {
  if (ALLOW_LOCAL_AUTH) {
    // Local development receives the Firebase ID token from the Flutter app.
    // This mode is only intended for a loopback-bound server and must never
    // be enabled on a public deployment.
    return typeof req.headers.authorization === 'string' &&
      req.headers.authorization.startsWith('Bearer ') &&
      req.headers.authorization.length > 'Bearer '.length;
  }
  if (!LLM_API_TOKEN) return false;
  return safeEqual(req.headers.authorization || '', `Bearer ${LLM_API_TOKEN}`);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

function json(res, status, obj) {
  res.statusCode = status;
  res.setHeader('content-type', 'application/json');
  res.end(JSON.stringify(obj));
}

function setCorsHeaders(req, res) {
  const origin = req.headers.origin;
  if (origin === 'http://localhost:3000' ||
      origin === 'http://localhost:5000' ||
      origin === 'http://localhost:8080' ||
      origin === 'http://127.0.0.1:3000' ||
      origin === 'http://127.0.0.1:5000' ||
      origin === 'http://127.0.0.1:8080') {
    res.setHeader('access-control-allow-origin', origin);
    res.setHeader('vary', 'Origin');
  }
  res.setHeader('access-control-allow-methods', 'GET, POST, OPTIONS');
  res.setHeader('access-control-allow-headers', 'Content-Type, Authorization');
}

/** Translates an OpenAI-style completion payload to Ollama's dialect. */
function translatePayload(payload) {
  if (LLM_MODEL) payload.model = LLM_MODEL;
  if (payload.max_completion_tokens != null) {
    payload.max_tokens = payload.max_completion_tokens;
    delete payload.max_completion_tokens;
  }
  if (payload.response_format && payload.response_format.type === 'json_object') {
    payload.format = 'json';
    delete payload.response_format;
  }
  delete payload.reasoning_effort;
  delete payload.stream;
  return payload;
}

async function forwardToOllama(req, res, path, method) {
  let payload = {};
  if (method === 'POST') {
    try {
      const raw = await readBody(req);
      if (raw.trim()) payload = JSON.parse(raw);
    } catch {
      return json(res, 400, { error: 'Invalid JSON body' });
    }
    payload = translatePayload(payload);
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const upstream = await fetch(`${OLLAMA_HOST}${path}`, {
      method,
      headers: method === 'POST' ? { 'content-type': 'application/json' } : {},
      body: method === 'POST' ? JSON.stringify(payload) : undefined,
      signal: controller.signal,
    });
    const text = await upstream.text();
    res.statusCode = upstream.status;
    res.setHeader('content-type', upstream.headers.get('content-type') || 'application/json');
    res.end(text);
  } catch (err) {
    console.error(`Upstream request to ${OLLAMA_HOST}${path} failed:`, err.message);
    json(res, 502, { error: 'Upstream LLM unavailable', message: err.message });
  } finally {
    clearTimeout(timer);
  }
}

const server = http.createServer((req, res) => {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') {
    res.statusCode = 204;
    res.end();
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const path = url.pathname;

  // Unauthenticated liveness probe for uptime monitoring / health checks.
  if (path === '/healthz' && req.method === 'GET') {
    return json(res, 200, { status: 'ok' });
  }

  if (path === '/v1/models' && req.method === 'GET') {
    if (!isAuthorized(req)) return json(res, 401, { error: 'Unauthorized' });
    return forwardToOllama(req, res, '/v1/models', 'GET');
  }

  if (path === '/v1/chat/completions' && req.method === 'POST') {
    if (!isAuthorized(req)) return json(res, 401, { error: 'Unauthorized' });
    return forwardToOllama(req, res, '/v1/chat/completions', 'POST');
  }

  return json(res, 404, { error: 'Not found' });
});

server.listen(PORT, HOST, () => {
  console.log(`LLM auth gate listening on ${HOST}:${PORT} -> ${OLLAMA_HOST}`);
  if (ALLOW_LOCAL_AUTH) {
    console.warn('WARNING: local auth mode enabled; bind this server to loopback only.');
  } else if (!LLM_API_TOKEN) {
    console.warn('WARNING: LLM_API_TOKEN is not set — every /v1 request will be rejected.');
  }
});