// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

String? getCurrentHostname() {
  return html.window.location.hostname;
}

void openUrlInNewWindow(String url) {
  html.window.open(url, '_blank');
}

/// Rewrites the browser address bar to reflect the in-app screen, WITHOUT
/// touching the Flutter Navigator or the router.
///
/// Uses history.replaceState so no history entry is created and browser
/// back/forward behaviour is completely unchanged (the E2E defect was that
/// the URL stayed on /#/dashboard no matter how deep the user navigated into
/// a project — this gives users an accurate, copyable URL at all times while
/// keeping the zero-risk profile of the existing navigation stack).
void syncBrowserUrl(String path) {
  try {
    final safePath = path.startsWith('/') ? path : '/$path';
    final basePath = html.window.location.pathname ?? '/';
    final target = '$basePath#$safePath';
    if (html.window.location.href == target) return;
    html.window.history.replaceState(null, '', target);
  } catch (_) {
    // Address-bar sync is best-effort only — never let it break navigation.
  }
}
