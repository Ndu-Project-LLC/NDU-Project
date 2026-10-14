// Web-only implementation of the CSV download function. Selected by the
// conditional import in `admin_survey_responses_screen.dart` when the
// `dart.library.html` import succeeds (i.e. when compiling for the web).
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<bool> downloadCsv({
  required List<int> bytes,
  required String filename,
}) async {
  try {
    final blob = web.Blob(
      <web.BlobPart>[Uint8List.fromList(bytes).toJS].toJS,
      web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..setAttribute('download', filename)
      ..style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
    return true;
  } catch (e) {
    return false;
  }
}
