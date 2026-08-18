// Web-only implementation of the CSV download function. Selected by the
// conditional import in `admin_survey_responses_screen.dart` when the
// `dart.library.html` import succeeds (i.e. when compiling for the web).
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> downloadCsv({
  required List<int> bytes,
  required String filename,
}) async {
  try {
    final blob = html.Blob(
      [Uint8List.fromList(bytes)],
      'text/csv;charset=utf-8',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (e) {
    return false;
  }
}
