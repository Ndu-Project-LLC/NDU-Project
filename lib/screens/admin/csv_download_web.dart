// Stub implementation of the CSV download function. Used when compiling
// for non-web targets. The web override lives in `csv_download_web_html.dart`
// and is selected automatically by the conditional import in
// `admin_survey_responses_screen.dart`.
Future<bool> downloadCsv({
  required List<int> bytes,
  required String filename,
}) async {
  // Non-web targets have no browser to trigger a download against —
  // returning false lets the caller fall back to logging the CSV to the
  // debug console.
  return false;
}
