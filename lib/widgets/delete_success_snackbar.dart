import 'package:flutter/material.dart';

void showDeleteSuccessSnackBar(
  BuildContext context, {
  required String itemLabel,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$itemLabel deleted successfully.'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF111827),
      duration: const Duration(seconds: 3),
    ),
  );
}
