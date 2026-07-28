String? getCurrentHostname() {
  return null;
}

void openUrlInNewWindow(String url) {
  // No-op on non-web platforms or where dart:html is not available
}

void openUrlInNewTab(String url) {
  // No-op on non-web platforms
}

void copyToClipboard(String text) {
  // No-op on non-web platforms
}
