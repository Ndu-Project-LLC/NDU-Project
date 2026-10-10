library;

/// The browser leg of the server-brokered OAuth flow.
///
/// A browser cannot exchange a confidential client's authorization code (the
/// secret would have to ship to the client, and the vendors block the call with
/// CORS), so on web the flow is: send the browser to the provider, come back
/// with `?code=…`, and let `functions/oauth-broker.js` redeem it. This file is
/// the thin platform seam that makes that possible — [redirectTo] navigates,
/// and the `current*`/`clearCallbackParameters` helpers read and tidy the
/// address bar on the way back.
///
/// On platforms without a browser (Android, iOS) the stub reports
/// `isAvailable == false`; those builds use `IntegrationOAuthService` and
/// flutter_appauth instead.
export 'web_oauth_flow_stub.dart'
    if (dart.library.js_interop) 'web_oauth_flow_web.dart';
