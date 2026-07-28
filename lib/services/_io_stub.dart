/// Web stub for dart:io — used by conditional import in
/// `lib/services/docx_import_service.dart` so the service file compiles
/// on the web target where dart:io is unavailable.
///
/// On web, [DocxImportService] always reads `PlatformFile.bytes` directly
/// from the [FilePicker] result, so this stub is never actually invoked.
/// It exists only to satisfy the analyzer and dart2js compiler.
library ndu_project.io_stub;

class File {
  // ignore: avoid_unused_constructor_parameters
  File(Object path);

  Future<List<int>> readAsBytes() {
    throw UnsupportedError('dart:io File is not available on web');
  }
}
