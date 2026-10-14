'use strict';

/**
 * Request routing for the KAZ AI proxy.
 *
 * The app's Cloud Function can serve completions from a self-hosted LLM
 * (Ollama on the Oracle Always-Free VM, see llm-server/) first and fall back
 * to OpenAI when that server is down. All helpers here are pure (no Firebase
 * imports) so they can be unit-tested with `node --test`.
 *
 * Upstream selection, read from process.env:
 *   - LLM_SERVER_URL         base URL of the self-hosted server
 *                            (e.g. http://203.0.113.10:8080)
 *   - LLM_SERVER_API_TOKEN   Bearer token the gate requires (Firebase secret)
 *   - LLM_MODEL_NAME         model to request on the self-hosted server
 *                            (defaults to qwen2.5:7b-instruct)
 *   - LLM_SERVER_TIMEOUT_MS  per-request timeout for the local server
 *                            (defaults to 240000)
 */

const OPENAI_URL = 'https://api.openai.com/v1/chat/completions';
const DEFAULT_OPENAI_MODEL = 'gpt-5.6-terra';
const DEFAULT_LOCAL_MODEL = 'qwen2.5:7b-instruct';
// Local-generation budget. Must stay comfortably below the client-side
// request timeouts (90-180s in lib/services/openai_service_secure.dart and
// lib/widgets/kaz_ai_chat_bubble.dart) so that when the VM is unreachable
// the OpenAI fallback response still lands before the client gives up.
const DEFAULT_LOCAL_TIMEOUT_MS = 60000;

/**
 * Returns the self-hosted LLM configuration, or null when LLM_SERVER_URL is
 * not set (proxy then runs in OpenAI-only mode, preserving old behavior).
 */
function getLocalLlmConfig(env = process.env) {
  const url = (env.LLM_SERVER_URL || '').trim().replace(/\/+$/, '');
  if (!url) return null;
  return {
    url: `${url}/v1/chat/completions`,
    apiToken: (env.LLM_SERVER_API_TOKEN || '').trim(),
    model: (env.LLM_MODEL_NAME || '').trim() || DEFAULT_LOCAL_MODEL,
    timeoutMs: Number(env.LLM_SERVER_TIMEOUT_MS) || DEFAULT_LOCAL_TIMEOUT_MS,
  };
}

/**
 * Body for OpenAI. Kept as-is from the original proxy: GPT-5.x models reject
 * max_tokens and only accept sampling params when reasoning effort is 'none',
 * so we normalize to max_completion_tokens + reasoning_effort.
 */
function buildOpenAiBody(payload) {
  const body = {
    model: payload.model || DEFAULT_OPENAI_MODEL,
    messages: payload.messages || [],
    temperature: payload.temperature ?? 0.7,
    max_completion_tokens: payload.max_completion_tokens ?? payload.max_tokens ?? 2000,
    reasoning_effort: payload.reasoning_effort || 'none',
    stream: false,
  };
  copyOptionalFields(payload, body);
  return body;
}

/**
 * Body for the self-hosted server (Ollama OpenAI-compatible endpoint).
 * Maps OpenAI-specific fields to Ollama's dialect: the configured local
 * model replaces the client's model name, max_completion_tokens becomes
 * max_tokens, json_object response_format becomes format:'json', and
 * OpenAI-only params (reasoning_effort, stream) are dropped.
 */
function buildLocalBody(payload, config) {
  const body = {
    model: config.model,
    messages: payload.messages || [],
    temperature: payload.temperature ?? 0.7,
    max_tokens: payload.max_completion_tokens ?? payload.max_tokens ?? 2000,
    stream: false,
  };
  if (payload.response_format && payload.response_format.type === 'json_object') {
    body.format = 'json';
  } else {
    copyOptionalFields(payload, body);
  }
  return body;
}

function copyOptionalFields(payload, body) {
  if (payload.response_format) body.response_format = payload.response_format;
  if (payload.top_p != null) body.top_p = payload.top_p;
  if (payload.frequency_penalty != null) body.frequency_penalty = payload.frequency_penalty;
  if (payload.presence_penalty != null) body.presence_penalty = payload.presence_penalty;
}

/**
 * POSTs a completion request to an upstream and returns a normalized result.
 * `fetchImpl` is injectable for tests.
 */
async function forwardCompletion({ url, headers, body, timeoutMs, fetchImpl = fetch }) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetchImpl(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    const data = await response.json().catch(() => null);
    return {
      status: response.status,
      data,
      retryAfter: response.headers.get('retry-after'),
    };
  } catch (error) {
    // Network failure (connection refused, DNS lookup failure, or the
    // request timeout aborting the fetch). Return a failed outcome instead
    // of throwing — the caller treats a non-2xx as "try the next upstream",
    // so this is what lets the proxy fall back to OpenAI when the
    // self-hosted VM is unreachable. Without this, every AI request 500s
    // while the VM is down.
    return {
      status: 0,
      data: { error: error?.message || String(error) },
      retryAfter: null,
    };
  } finally {
    clearTimeout(timer);
  }
}

module.exports = {
  OPENAI_URL,
  DEFAULT_OPENAI_MODEL,
  DEFAULT_LOCAL_MODEL,
  DEFAULT_LOCAL_TIMEOUT_MS,
  getLocalLlmConfig,
  buildOpenAiBody,
  buildLocalBody,
  forwardCompletion,
};