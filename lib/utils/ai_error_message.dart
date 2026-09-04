/// Converts a raw AI / OpenAI proxy exception into a short, human-readable,
/// actionable message for the UI.
///
/// Screens previously surfaced `error.toString()` verbatim — for a quota
/// error that dumped the full OpenAI 429 JSON payload into a red banner,
/// which reads like an app crash and offers no guidance. This helper maps
/// the common failure classes (billing/quota, network, authentication,
/// regional blocks, timeouts) to a concise message and falls back to a
/// single-line, length-limited summary for anything else. The full original
/// error is still available to callers for logging.
String aiErrorMessage(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();

  // Billing / quota exhaustion (OpenAI HTTP 429, insufficient_quota,
  // credit_balance_exhausted, "no credits remaining", …).
  if (raw.contains('429') ||
      lower.contains('insufficient_quota') ||
      lower.contains('credit_balance_exhausted') ||
      lower.contains('no credits') ||
      lower.contains('you have no credits') ||
      lower.contains('quota exceeded') ||
      lower.contains('billing')) {
    return 'AI is paused: the OpenAI account linked to this app has no '
        'credits remaining. Add credits at '
        'platform.openai.com/settings/organization/billing, then tap Retry. '
        'You can keep entering content manually in the meantime.';
  }

  // Network / proxy unavailability (CORS, fetch failures, connection
  // refused, 5xx, timeouts).
  if (lower.contains('failed to fetch') ||
      lower.contains('clientexception') ||
      lower.contains('xmlhttprequest') ||
      lower.contains('connection refused') ||
      lower.contains('socketexception') ||
      lower.contains('timeout') ||
      lower.contains('timed out') ||
      raw.contains(' 500 ') ||
      raw.contains(' 502 ') ||
      raw.contains(' 503 ') ||
      raw.contains(' 504 ')) {
    return 'AI assist is being set up. Please try again later or enter '
        'content manually.';
  }

  // Authentication failures (401, invalid key, signed-out sessions).
  if (lower.contains('401') ||
      lower.contains('invalid api key') ||
      lower.contains('authentication') ||
      lower.contains('api key not accepted')) {
    return 'AI authentication failed. Please sign out and sign back in, '
        'then try again.';
  }

  // Regional availability blocks.
  if (lower.contains('403') &&
      lower.contains('unsupported_country_region_territory')) {
    return 'AI is not available in your current region.';
  }

  // Anything else: collapse to a single line and keep it short so the UI
  // never shows a multi-line raw payload. The complete error is logged by
  // the caller.
  final singleLine = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  const maxLen = 200;
  return singleLine.length <= maxLen
      ? singleLine
      : '${singleLine.substring(0, maxLen - 3)}...';
}
