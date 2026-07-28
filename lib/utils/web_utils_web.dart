// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

String? getCurrentHostname() {
  return html.window.location.hostname;
}

void openUrlInNewWindow(String url) {
  html.window.open(url, '_blank');
}
