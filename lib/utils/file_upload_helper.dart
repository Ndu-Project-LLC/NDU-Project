import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Result of a successful file upload.
class UploadedFileResult {
  final String fileName;
  final String downloadUrl;
  final String storagePath;

  /// Size actually uploaded, so callers can record it with the attachment.
  final int sizeBytes;

  const UploadedFileResult({
    required this.fileName,
    required this.downloadUrl,
    required this.storagePath,
    this.sizeBytes = 0,
  });
}

/// Reusable helper for picking and uploading files to Firebase Storage.
///
/// Every document upload in the app goes through [pickAndUpload], which writes
/// to `projects/{projectId}/{folder}/{timestamp}_{fileName}` — the path
/// `storage.rules` grants project members.
///
/// Two failure modes used to make "Add file" / "Add Document" look broken
/// outright, and both are fixed here:
///
/// 1. **The bytes were read from the deprecated `PlatformFile.bytes` field.**
///    That field is only populated when `withData: true` survives down to the
///    platform implementation. On the paths where it does not — web blob picks,
///    larger files, platforms that ignore the flag — `bytes` comes back `null`,
///    the helper bailed out with "Unable to read selected file.", and the file
///    never left the machine. [PlatformFile.readAsBytes] is the supported API
///    and has real fallbacks (buffered stream → fetched web blob → the file at
///    `path`), so it is what this helper uses now, with `bytes` kept only as the
///    in-memory fast path.
/// 2. **Nothing checked the size before uploading.** Storage rules reject a
///    write above 25 MB, so an oversized file surfaced as a raw Firebase
///    `unauthorized` / `unknown` error. [validateSelection] now catches it
///    first and says how big the file actually is.
class FileUploadHelper {
  FileUploadHelper._();

  /// Hard cap on a single upload.
  ///
  /// Kept in step with the `request.resource.size < 25 * 1024 * 1024` guard in
  /// `storage.rules`: checking here turns a rejected write into an actionable
  /// message *before* the bytes are sent.
  static const int maxUploadBytes = 25 * 1024 * 1024;

  /// Allowed document extensions for "Add Document".
  static const List<String> documentExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'csv',
    'png',
    'jpg',
    'jpeg',
    'svg',
    'zip',
  ];

  /// Allowed design document extensions for "Add Tool".
  static const List<String> toolExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'csv',
    'png',
    'jpg',
    'jpeg',
    'svg',
    'fig',
    'sketch',
    'xd',
    'zip',
  ];

  /// Why a picked file cannot be uploaded, or `null` when it can.
  ///
  /// Pure and side-effect free so the rules can be tested without Firebase.
  /// Returns a message written for the person who picked the file, not for a
  /// log: it says what is wrong and what the limit is.
  static String? validateSelection({
    required String fileName,
    required int sizeBytes,
    List<String>? allowedExtensions,
    int maxBytes = maxUploadBytes,
  }) {
    final name = fileName.trim();
    if (name.isEmpty) {
      return 'That file has no name — pick it again.';
    }

    final allowed = allowedExtensions;
    if (allowed != null && allowed.isNotEmpty) {
      final extension = _extensionOf(name);
      if (extension.isEmpty || !allowed.contains(extension)) {
        return 'Unsupported file type. Allowed: '
            '${allowed.map((e) => '.$e').join(', ')}.';
      }
    }

    if (sizeBytes > maxBytes) {
      return 'That file is ${humanFileSize(sizeBytes)} — the limit is '
          '${humanFileSize(maxBytes)}.';
    }
    return null;
  }

  /// `1.4 MB` / `820 KB` / `12 bytes` — for limits and errors.
  static String humanFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes bytes';
  }

  /// Picks a file and uploads it to Firebase Storage.
  ///
  /// Returns `null` when the user cancels, is not authenticated, or the upload
  /// fails — showing a [SnackBar] on error when [context] is provided.
  static Future<UploadedFileResult?> pickAndUpload({
    required String folder,
    required String projectId,
    List<String>? allowedExtensions,
    BuildContext? context,
  }) async {
    // Resolve the messenger once, before any await. Holding a BuildContext
    // across an async gap and reading it afterwards is exactly how an upload
    // failure turns into a second, unrelated exception.
    final messenger =
        context == null ? null : ScaffoldMessenger.maybeOf(context);
    void notify(String message) {
      messenger?.showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      notify('Sign in is required before uploading files.');
      return null;
    }

    if (projectId.trim().isEmpty) {
      notify('Select a project before uploading files.');
      return null;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions ?? documentExtensions,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      final problem = validateSelection(
        fileName: file.name,
        sizeBytes: file.size,
        allowedExtensions: allowedExtensions ?? documentExtensions,
      );
      if (problem != null) {
        notify(problem);
        return null;
      }

      // `PlatformFile.readAsBytes()` is the supported reader: it returns the
      // already-buffered bytes when the platform provided them (the default on
      // web) and otherwise falls back to the read stream, the fetched web blob
      // URL, or the file at `path`. The deprecated `bytes` field it replaces is
      // null on those fallback paths, which is exactly why uploads failed here.
      final Uint8List bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        notify('That file is empty — nothing to upload.');
        return null;
      }
      if (bytes.length > maxUploadBytes) {
        notify('That file is ${humanFileSize(bytes.length)} — the limit is '
            '${humanFileSize(maxUploadBytes)}.');
        return null;
      }

      final safeName =
          file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final storagePath =
          'projects/${projectId.trim()}/$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final ref = FirebaseStorage.instance.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: _contentTypeForExtension(file.extension),
        cacheControl: 'private, max-age=0',
      );

      await ref.putData(bytes, metadata);
      final downloadUrl = await ref.getDownloadURL();

      return UploadedFileResult(
        fileName: file.name,
        downloadUrl: downloadUrl,
        storagePath: storagePath,
        sizeBytes: bytes.length,
      );
    } on FirebaseException catch (error) {
      notify(_describeUploadFailure(error, folder: folder));
      return null;
    } catch (error) {
      notify('Failed to upload file: $error');
      return null;
    }
  }

  /// Deletes a previously uploaded file from Firebase Storage.
  static Future<void> deleteUploadedFile(String? storagePath,
      {BuildContext? context}) async {
    if (storagePath == null || storagePath.isEmpty) return;
    final messenger =
        context == null ? null : ScaffoldMessenger.maybeOf(context);
    try {
      await FirebaseStorage.instance.ref(storagePath).delete();
    } catch (e) {
      messenger?.showSnackBar(SnackBar(
        content: Text('Failed to delete file: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// Turns a Storage rejection into the likely cause.
  ///
  /// `unauthorized` on this path is almost always the Storage rule, not the
  /// file — saying so (and naming the folder) saves a support round trip.
  static String _describeUploadFailure(FirebaseException error,
      {required String folder}) {
    final code = error.code;
    if (code == 'unauthorized' || code == 'permission-denied') {
      return 'Storage refused the upload. Your account needs project-member '
          'access to write to "$folder".';
    }
    if (code == 'canceled') {
      return 'The upload was cancelled.';
    }
    final message = (error.message ?? '').trim();
    return 'Failed to upload file: ${message.isEmpty ? code : message}';
  }

  static String _extensionOf(String fileName) {
    final index = fileName.lastIndexOf('.');
    if (index < 0 || index == fileName.length - 1) return '';
    return fileName.substring(index + 1).toLowerCase();
  }

  static String _contentTypeForExtension(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'svg':
        return 'image/svg+xml';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}
