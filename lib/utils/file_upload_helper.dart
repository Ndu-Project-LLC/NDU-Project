import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Result of a successful file upload.
class UploadedFileResult {
  final String fileName;
  final String downloadUrl;
  final String storagePath;

  const UploadedFileResult({
    required this.fileName,
    required this.downloadUrl,
    required this.storagePath,
  });
}

/// Reusable helper for picking and uploading files to Firebase Storage.
class FileUploadHelper {
  FileUploadHelper._();

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

  /// Picks a file and uploads it to Firebase Storage.
  ///
  /// Returns `null` if the user cancels, is not authenticated, or the upload
  /// fails. Shows a [SnackBar] on error when [context] is provided.
  static Future<UploadedFileResult?> pickAndUpload({
    required String folder,
    required String projectId,
    List<String>? allowedExtensions,
    BuildContext? context,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showMessage(context, 'Sign in is required before uploading files.');
      return null;
    }

    if (projectId.trim().isEmpty) {
      _showMessage(context, 'Select a project before uploading files.');
      return null;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: allowedExtensions ?? documentExtensions,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      final Uint8List? bytes = file.bytes;

      if (bytes == null) {
        _showMessage(context, 'Unable to read selected file.');
        return null;
      }

      final safeName =
          file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final storagePath =
          'projects/${projectId.trim()}/$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final ref = FirebaseStorage.instance.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: _contentTypeForExtension(file.extension),
      );

      await ref.putData(bytes, metadata);
      final downloadUrl = await ref.getDownloadURL();

      return UploadedFileResult(
        fileName: file.name,
        downloadUrl: downloadUrl,
        storagePath: storagePath,
      );
    } on FirebaseException catch (error) {
      _showMessage(
          context, 'Failed to upload file: ${error.message ?? error.code}');
      return null;
    } catch (error) {
      _showMessage(context, 'Failed to upload file: $error');
      return null;
    }
  }

  /// Deletes a previously uploaded file from Firebase Storage.
  static Future<void> deleteUploadedFile(String? storagePath,
      {BuildContext? context}) async {
    if (storagePath == null || storagePath.isEmpty) return;
    try {
      await FirebaseStorage.instance.ref(storagePath).delete();
    } catch (e) {
      _showMessage(context, 'Failed to delete file: $e');
    }
  }

  static void _showMessage(BuildContext? context, String message) {
    if (context == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
