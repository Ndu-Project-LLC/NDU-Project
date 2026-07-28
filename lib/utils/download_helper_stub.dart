void downloadFile(
  List<int> bytes,
  String filename, {
  String mimeType = 'application/octet-stream',
}) {
  throw UnsupportedError(
      'Cannot download file without a platform implementation');
}
