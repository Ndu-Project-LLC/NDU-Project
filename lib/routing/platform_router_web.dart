// Web implementation of sessionStorage accessor.
// Imported only on web platforms via the conditional import in
// platform_router.dart.
import 'dart:html' as html;

String? readSessionStorage(String key) {
  try {
    return html.window.sessionStorage[key];
  } catch (_) {
    return null;
  }
}

void removeSessionStorage(String key) {
  try {
    html.window.sessionStorage.remove(key);
  } catch (_) {}
}
