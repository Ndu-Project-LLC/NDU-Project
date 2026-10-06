library;

/// Browser implementation of the web OAuth shim (see web_oauth_flow.dart).

import 'package:web/web.dart' as web;

import 'package:ndu_project/services/oauth_pkce.dart';

bool get isAvailable => true;

/// Scheme + host of the running app, used to derive the redirect URI.
String currentOrigin() => web.window.location.origin;

String currentUrl() => web.window.location.href;

/// Sends the browser to the provider's consent screen.
///
/// A full-page navigation (rather than a popup) because the providers are
/// registered against a redirect URI that lands back on the app itself, and a
/// popup would need a second return channel to hand the code back.
void redirectTo(String url) {
  web.window.location.assign(url);
}

/// Removes the OAuth parameters from the address bar once they have been read,
/// so a reload cannot replay a spent authorization code.
void clearCallbackParameters() {
  final uri = Uri.parse(web.window.location.href);
  final hasCallbackParams =
      uri.queryParameters.keys.any(OAuthCallback.parameterNames.contains);
  if (!hasCallbackParams) return;

  final remaining = Map<String, String>.from(uri.queryParameters)
    ..removeWhere((key, _) => OAuthCallback.parameterNames.contains(key));
  // Built by hand: Uri.replace cannot tell "no query" from "leave the query
  // alone", and leaving it alone is exactly what must not happen here.
  final query =
      remaining.isEmpty ? '' : '?${Uri(queryParameters: remaining).query}';
  final cleaned = '${uri.origin}${uri.path}$query';
  // replaceState keeps the history entry (no extra back-button step).
  web.window.history.replaceState(null, '', cleaned);
}

List<String> get callbackParameterNames => OAuthCallback.parameterNames;
