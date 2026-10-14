'use strict';

// Unit tests for the AI proxy router (functions/llm-router.js).
// Run with: npm test  (from functions/)

const { test } = require('node:test');
const assert = require('node:assert');

const {
  getLocalLlmConfig,
  buildOpenAiBody,
  buildLocalBody,
  forwardCompletion,
  DEFAULT_LOCAL_MODEL,
  DEFAULT_LOCAL_TIMEOUT_MS,
} = require('../llm-router.js');

test('getLocalLlmConfig returns null when LLM_SERVER_URL is unset', () => {
  assert.strictEqual(getLocalLlmConfig({}), null);
  assert.strictEqual(getLocalLlmConfig({ LLM_SERVER_URL: '   ' }), null);
});

test('getLocalLlmConfig parses url, token, model and strips trailing slashes', () => {
  const cfg = getLocalLlmConfig({
    LLM_SERVER_URL: 'http://10.0.0.5:8080/',
    LLM_SERVER_API_TOKEN: 'secret123',
    LLM_MODEL_NAME: 'qwen2.5:7b-instruct',
  });
  assert.strictEqual(cfg.url, 'http://10.0.0.5:8080/v1/chat/completions');
  assert.strictEqual(cfg.apiToken, 'secret123');
  assert.strictEqual(cfg.model, 'qwen2.5:7b-instruct');
  assert.strictEqual(cfg.timeoutMs, DEFAULT_LOCAL_TIMEOUT_MS);
});

test('getLocalLlmConfig falls back to defaults for model and timeout', () => {
  const cfg = getLocalLlmConfig({ LLM_SERVER_URL: 'http://localhost:8080' });
  assert.strictEqual(cfg.model, DEFAULT_LOCAL_MODEL);
  assert.strictEqual(cfg.apiToken, '');
  assert.strictEqual(cfg.timeoutMs, DEFAULT_LOCAL_TIMEOUT_MS);
});

test('getLocalLlmConfig honors an explicit timeout', () => {
  const cfg = getLocalLlmConfig({
    LLM_SERVER_URL: 'http://localhost:8080',
    LLM_SERVER_TIMEOUT_MS: '90000',
  });
  assert.strictEqual(cfg.timeoutMs, 90000);
});

test('buildOpenAiBody normalizes GPT-5.x params (max_completion_tokens, reasoning_effort)', () => {
  const body = buildOpenAiBody({
    model: 'gpt-5.6-terra',
    messages: [{ role: 'user', content: 'hi' }],
    max_tokens: 500,
    temperature: 0.3,
  });
  assert.strictEqual(body.model, 'gpt-5.6-terra');
  assert.strictEqual(body.max_completion_tokens, 500);
  assert.strictEqual(body.reasoning_effort, 'none');
  assert.strictEqual(body.stream, false);
  assert.strictEqual(body.messages.length, 1);
});

test('buildOpenAiBody keeps extra fields the client may send', () => {
  const body = buildOpenAiBody({
    messages: [{ role: 'user', content: 'hi' }],
    response_format: { type: 'json_object' },
    top_p: 0.9,
    frequency_penalty: 0.5,
  });
  assert.deepStrictEqual(body.response_format, { type: 'json_object' });
  assert.strictEqual(body.top_p, 0.9);
  assert.strictEqual(body.frequency_penalty, 0.5);
});

test('buildLocalBody maps model, uses max_tokens and drops OpenAI-only params', () => {
  const cfg = getLocalLlmConfig({
    LLM_SERVER_URL: 'http://x',
    LLM_MODEL_NAME: 'llama3.2:3b',
  });
  const body = buildLocalBody(
    {
      model: 'gpt-5.6-terra',
      messages: [{ role: 'user', content: 'hi' }],
      max_completion_tokens: 700,
      reasoning_effort: 'high',
      temperature: 0.5,
    },
    cfg,
  );
  assert.strictEqual(body.model, 'llama3.2:3b');
  assert.strictEqual(body.max_tokens, 700);
  assert.ok(!('reasoning_effort' in body));
  assert.ok(!('max_completion_tokens' in body));
  assert.strictEqual(body.stream, false);
});

test('buildLocalBody translates json_object response_format to format:json', () => {
  const cfg = getLocalLlmConfig({ LLM_SERVER_URL: 'http://x' });
  const body = buildLocalBody(
    {
      messages: [{ role: 'user', content: 'hi' }],
      response_format: { type: 'json_object' },
    },
    cfg,
  );
  assert.strictEqual(body.format, 'json');
  assert.ok(!('response_format' in body));
});

test('forwardCompletion posts to the upstream and parses the response', async () => {
  const fakeFetch = async (url, opts) => {
    assert.strictEqual(url, 'http://x/v1/chat/completions');
    assert.strictEqual(opts.method, 'POST');
    assert.strictEqual(opts.headers.authorization, 'Bearer tok');
    assert.strictEqual(JSON.parse(opts.body).model, 'm');
    return {
      status: 200,
      headers: { get: () => null },
      json: async () => ({ choices: [{ message: { content: 'ok' } }] }),
    };
  };

  const out = await forwardCompletion({
    url: 'http://x/v1/chat/completions',
    headers: { authorization: 'Bearer tok' },
    body: { model: 'm', messages: [] },
    timeoutMs: 1000,
    fetchImpl: fakeFetch,
  });
  assert.strictEqual(out.status, 200);
  assert.strictEqual(out.data.choices[0].message.content, 'ok');
});

test('forwardCompletion preserves Retry-After when the upstream sends it', async () => {
  const fakeFetch = async () => ({
    status: 429,
    headers: { get: (name) => (name === 'retry-after' ? '60' : null) },
    json: async () => ({ error: { message: 'busy' } }),
  });
  const out = await forwardCompletion({
    url: 'u',
    headers: {},
    body: {},
    timeoutMs: 1000,
    fetchImpl: fakeFetch,
  });
  assert.strictEqual(out.status, 429);
  assert.strictEqual(out.retryAfter, '60');
});

test('forwardCompletion returns a failed outcome when the request times out (abort)', async () => {
  const fakeFetch = async (url, opts) =>
    new Promise((resolve, reject) => {
      opts.signal.addEventListener('abort', () =>
        reject(Object.assign(new Error('aborted'), { name: 'AbortError' })),
      );
    });

  const out = await forwardCompletion({
    url: 'u',
    headers: {},
    body: {},
    timeoutMs: 50,
    fetchImpl: fakeFetch,
  });
  assert.strictEqual(out.status, 0);
  assert.ok(out.data && out.data.error, 'failed outcome carries an error detail');
});

test('forwardCompletion returns a failed outcome on network errors (so the proxy can fall back)', async () => {
  const out = await forwardCompletion({
    url: 'http://127.0.0.1:1',
    headers: {},
    body: {},
    timeoutMs: 1000,
    fetchImpl: async () => {
      throw new Error('connect ECONNREFUSED 127.0.0.1:1');
    },
  });
  assert.strictEqual(out.status, 0);
  assert.strictEqual(out.retryAfter, null);
  assert.ok(out.data && out.data.error);
});