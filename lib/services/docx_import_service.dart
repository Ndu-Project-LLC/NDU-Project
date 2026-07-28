import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart' as xml;

// Conditional import: dart:io on native targets, no-op stub on web.
// On web, PlatformFile.bytes is always populated so we never invoke this.
import 'dart:io'
    if (dart.library.html) 'package:ndu_project/services/_io_stub.dart'
    as io;

/// Result of a successful document import.
class DocxImportResult {
  /// Extracted plain text content.
  final String text;

  /// Number of words in the extracted text.
  final int wordCount;

  /// Number of characters in the extracted text.
  final int charCount;

  /// Original filename picked by the user.
  final String fileName;

  /// Lower-cased extension without dot, e.g. "docx", "doc", "txt".
  final String extension;

  const DocxImportResult({
    required this.text,
    required this.wordCount,
    required this.charCount,
    required this.fileName,
    required this.extension,
  });

  @override
  String toString() =>
      'DocxImportResult(fileName=$fileName, ext=$extension, words=$wordCount, chars=$charCount)';
}

/// Failure reason codes returned by [DocxImportService.pickAndExtract].
enum DocxImportFailure {
  cancelledByUser,
  noFileSelected,
  unsupportedType,
  fileTooLarge,
  emptyContent,
  parseError,
}

/// Result of [DocxImportService.pickAndExtract].
sealed class DocxImportOutcome {
  const DocxImportOutcome();
}

class DocxImportSuccess extends DocxImportOutcome {
  final DocxImportResult result;
  const DocxImportSuccess(this.result);
}

class DocxImportError extends DocxImportOutcome {
  final DocxImportFailure reason;
  final String? message;
  const DocxImportError(this.reason, [this.message]);
}

/// Service that lets the user pick a Word document (.docx or .doc) or any
/// supported text document (.txt, .md, .csv, .rtf) and extracts its plain-text
/// content for filling into a [TextField].
///
/// On web, [PlatformFile.bytes] is populated by file_picker and is the only
/// reliable way to read the file content (no file system path). On mobile
/// platforms, [PlatformFile.path] is used when available, falling back to
/// [PlatformFile.bytes].
///
/// The .docx parser uses the `archive` + `xml` packages (already available
/// transitively via `pdf`) to unzip the OOXML package and extract paragraph
/// text from `word/document.xml`.
///
/// The legacy .doc binary format cannot be parsed by `archive` (it is not a
/// ZIP). For .doc files we extract printable ASCII/Unicode runs from the raw
/// binary stream as a best-effort fallback.
class DocxImportService {
  DocxImportService._();

  /// Maximum file size accepted by the picker (10 MB).
  static const int maxFileBytes = 10 * 1024 * 1024;

  /// Allowed extensions (lower-cased, no leading dot).
  static const List<String> allowedExtensions = [
    'docx',
    'doc',
    'txt',
    'md',
    'markdown',
    'csv',
    'rtf',
  ];

  /// Human-readable description for the file picker dialog.
  static const String dialogTitle = 'Import document into text field';

  /// Picks a single file via [FilePicker] and extracts its text content.
  ///
  /// Returns:
  /// - [DocxImportSuccess] with the extracted text on success
  /// - [DocxImportError] with [DocxImportFailure.cancelledByUser] if the user
  ///   cancels the picker
  /// - [DocxImportError] with other failure codes for size/type/parse errors
  static Future<DocxImportOutcome> pickAndExtract(BuildContext context) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        dialogTitle: dialogTitle,
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: true, // ensure bytes are populated on web
      );
    } catch (e) {
      debugPrint('[DocxImportService] FilePicker error: $e');
      return DocxImportError(DocxImportFailure.parseError, e.toString());
    }

    if (result == null || result.files.isEmpty) {
      return const DocxImportError(DocxImportFailure.cancelledByUser);
    }

    final file = result.files.first;
    final fileName = file.name;
    final ext = _extensionOf(fileName);

    if (!allowedExtensions.contains(ext)) {
      return DocxImportError(
        DocxImportFailure.unsupportedType,
        'Only .docx, .doc, .txt, .md, .csv, .rtf files are supported. Got .$ext',
      );
    }

    final bytes = file.bytes;
    if (bytes == null) {
      // Native-only path — read from file.path
      if (file.path == null) {
        return const DocxImportError(
          DocxImportFailure.parseError,
          'Could not read the picked file (no bytes and no path).',
        );
      }
      try {
        final fileObj = io.File(file.path!);
        final rawBytes = await fileObj.readAsBytes();
        return _extractFromBytes(
            Uint8List.fromList(rawBytes), fileName, ext);
      } catch (e) {
        return DocxImportError(DocxImportFailure.parseError, e.toString());
      }
    }

    if (bytes.lengthInBytes > maxFileBytes) {
      return DocxImportError(
        DocxImportFailure.fileTooLarge,
        'File is ${(bytes.lengthInBytes / 1024 / 1024).toStringAsFixed(1)} MB. '
        'Maximum allowed is 10 MB.',
      );
    }

    return _extractFromBytes(bytes, fileName, ext);
  }

  /// Extracts text from the in-memory file bytes based on the file extension.
  static DocxImportOutcome _extractFromBytes(
    Uint8List bytes,
    String fileName,
    String ext,
  ) {
    String text;
    try {
      switch (ext) {
        case 'docx':
          text = _extractDocx(bytes);
          break;
        case 'doc':
          text = _extractLegacyDoc(bytes);
          break;
        case 'rtf':
          text = _extractRtf(bytes);
          break;
        case 'txt':
        case 'md':
        case 'markdown':
        case 'csv':
          text = utf8.decode(bytes, allowMalformed: true);
          break;
        default:
          return DocxImportError(
            DocxImportFailure.unsupportedType,
            'Unsupported extension: .$ext',
          );
      }
    } catch (e, st) {
      debugPrint('[DocxImportService] Extract error for .$ext: $e\n$st');
      return DocxImportError(
        DocxImportFailure.parseError,
        'Failed to parse .$ext file: $e',
      );
    }

    final cleaned = _normalizeWhitespace(text);
    if (cleaned.trim().isEmpty) {
      return const DocxImportError(
        DocxImportFailure.emptyContent,
        'No extractable text was found in this document. '
        'It may be a scanned image PDF or an empty file.',
      );
    }

    final wordCount = _countWords(cleaned);
    return DocxImportSuccess(DocxImportResult(
      text: cleaned,
      wordCount: wordCount,
      charCount: cleaned.length,
      fileName: fileName,
      extension: ext,
    ));
  }

  /// Extracts paragraph text from a .docx (OOXML) file.
  ///
  /// Strategy:
  /// 1. Decode the file as a ZIP archive
  /// 2. Locate `word/document.xml`
  /// 3. Parse XML and walk every `<w:p>` (paragraph), collecting the text of
  ///    every `<w:t>` (text run) inside. Join runs with no separator, join
  ///    paragraphs with a newline.
  static String _extractDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.findFile('word/document.xml');
    if (docFile == null) {
      throw StateError('Not a valid .docx file: missing word/document.xml');
    }
    final xmlContent =
        utf8.decode(docFile.content as List<int>, allowMalformed: true);
    final doc = xml.XmlDocument.parse(xmlContent);

    final buffer = StringBuffer();
    final paragraphs = doc.findAllElements('w:p', namespace: '*');
    for (final p in paragraphs) {
      final runs = p.findElements('w:r', namespace: '*');
      final lineBuffer = StringBuffer();
      for (final r in runs) {
        for (final t in r.findElements('w:t', namespace: '*')) {
          lineBuffer.write(t.innerText);
        }
        // `<w:tab/>` and `<w:br/>` are also valid runs but have no text —
        // skip them. They are rare in body text and ignoring them is safe
        // for a text-fill use case.
      }
      if (lineBuffer.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(lineBuffer);
      }
    }

    return buffer.toString();
  }

  /// Best-effort text extraction from a legacy binary .doc file.
  ///
  /// The .doc format (CFB/OLE2 compound document with a WordDocument stream)
  /// is not parseable by `archive`. We approximate by scanning the binary
  /// for printable ASCII and common Unicode runs. This is intentionally
  /// simple — full .doc parsing requires a dedicated library.
  static String _extractLegacyDoc(Uint8List bytes) {
    final buffer = StringBuffer();
    int i = 0;
    int runStart = -1;

    void flushRun(int end) {
      if (runStart >= 0 && end > runStart) {
        final slice = bytes.sublist(runStart, end);
        final decoded = utf8.decode(slice, allowMalformed: true);
        // Skip runs that are mostly garbage (control chars)
        final printable = decoded.replaceAll(
            RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
        if (printable.trim().isNotEmpty &&
            printable.length >= 3 &&
            RegExp(r'[A-Za-z]').hasMatch(printable)) {
          if (buffer.isNotEmpty) buffer.write('\n');
          buffer.write(printable.trim());
        }
      }
      runStart = -1;
    }

    while (i < bytes.length) {
      final b = bytes[i];
      final isPrintable = (b >= 0x20 && b <= 0x7E) || b == 0x09 || b == 0x0A;
      if (isPrintable) {
        if (runStart < 0) runStart = i;
      } else {
        if (runStart >= 0) flushRun(i);
      }
      i++;
    }
    flushRun(bytes.length);

    return buffer.toString();
  }

  /// Strips RTF control words and extracts the plain text payload.
  static String _extractRtf(Uint8List bytes) {
    final raw = utf8.decode(bytes, allowMalformed: true);
    var text = raw
        .replaceAll(RegExp(r'\\par[d]?'), '\n')
        .replaceAll(RegExp(r'\\line'), '\n')
        .replaceAll(RegExp(r"\\'[0-9a-fA-F]{2}"), '')
        .replaceAll(RegExp(r'\\[a-zA-Z]+-?\d* ?'), '')
        .replaceAll(RegExp(r'[{}]|\\[\\{}]'), '');
    return text;
  }

  /// Normalizes excessive whitespace produced by the XML walk.
  static String _normalizeWhitespace(String text) {
    final lines = text.split('\n');
    final out = <String>[];
    for (final line in lines) {
      final trimmed = line.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
      out.add(trimmed);
    }
    final joined = out.join('\n');
    return joined.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return RegExp(r'\S+').allMatches(text).length;
  }

  static String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }
}
