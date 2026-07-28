// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

String? getCurrentHostname() {
  return html.window.location.hostname;
}

void openUrlInNewWindow(String url) {
  html.window.open(url, '_blank');
}

void openUrlInNewTab(String url) {
  html.window.open(url, '_blank');
}

void copyToClipboard(String text) {
  try {
    html.window.navigator.clipboard?.writeText(text);
  } catch (_) {
    // Fallback: use a temporary textarea + execCommand
    final textarea = html.TextAreaElement();
    textarea.value = text;
    html.document.body?.append(textarea);
    textarea.select();
    html.document.execCommand('copy');
    textarea.remove();
  }
}
