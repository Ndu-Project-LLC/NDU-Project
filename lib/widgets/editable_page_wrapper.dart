import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/admin_edit_toggle.dart';

/// Wrapper widget that adds admin edit toggle to any page
/// This is a convenience widget that wraps page content with the edit toggle
/// 
/// Usage:
/// ```dart
/// return Scaffold(
///   body: EditablePageWrapper(
///     child: // your page content
///   ),
/// );
/// ```
class EditablePageWrapper extends StatelessWidget {
  const EditablePageWrapper({
    super.key,
    required this.child,
    this.showEditToggle = true,
  });

  final Widget child;
  final bool showEditToggle;

  @override
  Widget build(BuildContext context) {
    if (!showEditToggle) return child;

    return Stack(
      children: [
        child,
        const AdminEditToggle(),
      ],
    );
  }
}
