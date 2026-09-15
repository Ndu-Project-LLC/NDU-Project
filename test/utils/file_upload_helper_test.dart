// Tests for the shared upload guard behind every "Add file" / "Add Document"
// in the app, including the change-request supporting documents the owner
// reported as broken (voice note, 2026-09-10: "as you create a change request,
// the document upload is not working").
//
// The upload itself needs Firebase, but the rules that decide whether a picked
// file may be sent at all are pure: wrong type, empty, or over the 25 MB cap
// `storage.rules` enforces. Those are covered here — they are what turns a
// silently rejected write into a message the user can act on.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/utils/file_upload_helper.dart';

void main() {
  group('validateSelection', () {
    test('accepts a document within the extension list and the size cap', () {
      expect(
        FileUploadHelper.validateSelection(
          fileName: 'vendor-quote.pdf',
          sizeBytes: 2048,
          allowedExtensions: FileUploadHelper.documentExtensions,
        ),
        isNull,
      );
    });

    test('rejects a file whose extension is not offered', () {
      final problem = FileUploadHelper.validateSelection(
        fileName: 'installer.exe',
        sizeBytes: 2048,
        allowedExtensions: FileUploadHelper.documentExtensions,
      );

      expect(problem, isNotNull);
      expect(problem, contains('Unsupported file type'));
      expect(problem, contains('.pdf'));
    });

    test('matches the extension case-insensitively', () {
      expect(
        FileUploadHelper.validateSelection(
          fileName: 'BOQ.XLSX',
          sizeBytes: 10,
          allowedExtensions: FileUploadHelper.documentExtensions,
        ),
        isNull,
      );
    });

    test('rejects a file with no extension when extensions are constrained',
        () {
      expect(
        FileUploadHelper.validateSelection(
          fileName: 'scan',
          sizeBytes: 10,
          allowedExtensions: FileUploadHelper.documentExtensions,
        ),
        contains('Unsupported file type'),
      );
    });

    test('rejects a file over the cap and states both sizes', () {
      final problem = FileUploadHelper.validateSelection(
        fileName: 'big.pdf',
        sizeBytes: 30 * 1024 * 1024,
        allowedExtensions: FileUploadHelper.documentExtensions,
      );

      expect(problem, contains('30.0 MB'));
      expect(problem, contains('25.0 MB'));
    });

    test('accepts a file exactly on the cap', () {
      expect(
        FileUploadHelper.validateSelection(
          fileName: 'exact.pdf',
          sizeBytes: FileUploadHelper.maxUploadBytes,
          allowedExtensions: FileUploadHelper.documentExtensions,
        ),
        isNull,
      );
    });

    test('honours a caller-supplied cap', () {
      expect(
        FileUploadHelper.validateSelection(
          fileName: 'photo.png',
          sizeBytes: 2 * 1024 * 1024,
          maxBytes: 1024 * 1024,
        ),
        contains('2.0 MB'),
      );
    });

    test('does not constrain the type when no list is given', () {
      expect(
        FileUploadHelper.validateSelection(
          fileName: 'anything.exe',
          sizeBytes: 10,
        ),
        isNull,
      );
    });

    test('rejects a nameless file', () {
      expect(
        FileUploadHelper.validateSelection(fileName: '   ', sizeBytes: 10),
        contains('no name'),
      );
    });
  });

  group('humanFileSize', () {
    test('renders bytes, kilobytes and megabytes', () {
      expect(FileUploadHelper.humanFileSize(512), '512 bytes');
      expect(FileUploadHelper.humanFileSize(2048), '2 KB');
      expect(FileUploadHelper.humanFileSize(3 * 1024 * 1024), '3.0 MB');
    });
  });

  group('the cap matches what Storage allows', () {
    test('is 25 MB — the limit storage.rules enforces', () {
      expect(FileUploadHelper.maxUploadBytes, 25 * 1024 * 1024);
    });
  });
}
