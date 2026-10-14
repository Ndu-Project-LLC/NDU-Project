library;

/// Stub used on every platform without a browser (see web_oauth_flow.dart).

import 'package:ndu_project/services/oauth_pkce.dart';

/// No browser here — native builds use flutter_appauth instead.
bool get isAvailable => false;

String currentOrigin() => '';

String currentUrl() => '';

/// Never reached: [isAvailable] is false, so callers take the native path.
void redirectTo(String url) {
  throw UnsupportedError(
      'This build cannot open a browser for OAuth; use the in-app connector.');
}

void clearCallbackParameters() {}

/// Kept so both implementations expose the same API.
List<String> get callbackParameterNames => OAuthCallback.parameterNames;
