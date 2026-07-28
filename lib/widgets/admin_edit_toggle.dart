import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/providers/app_content_provider.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:provider/provider.dart';

/// Floating button that allows admins to toggle content edit mode
/// Only visible to users whose email is from @nduproject.com or in the additional admin list
/// The button is draggable and can be repositioned anywhere on the screen
/// Position state is persisted across all pages via AppContentProvider
class AdminEditToggle extends StatefulWidget {
  const AdminEditToggle({super.key});

  static bool isAdmin() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      return UserService.isAdminEmail(user.email ?? '');
    } catch (_) {
      // If Firebase is unavailable (for example in widget tests), hide the toggle.
      return false;
    }
  }

  @override
  State<AdminEditToggle> createState() => _AdminEditToggleState();
}

class _AdminEditToggleState extends State<AdminEditToggle> {
  Offset? _dragPosition;

  @override
  Widget build(BuildContext context) {
    // Only show for admin users
    if (!AdminEditToggle.isAdmin()) return const SizedBox.shrink();

    // Use Selector to only rebuild when specific values change
    return Selector<AppContentProvider,
        ({bool isEditMode, Offset position, bool showButton})>(
      selector: (_, provider) => (
        isEditMode: provider.isEditMode,
        position: provider.editButtonPosition,
        showButton: provider.showEditButton,
      ),
      builder: (context, data, _) {
        final size = MediaQuery.of(context).size;
        // Use local drag position during drag, otherwise use provider position
        final position = _dragPosition ?? data.position;

        // Hide button if toggle is enabled (showEditButton = true means hide)
        if (data.showButton) return const SizedBox.shrink();

        return Positioned(
          left: position.dx,
          bottom: position.dy,
          child: GestureDetector(
            onPanUpdate: (details) =>
                WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              // Use latest live position (not closure-captured value) to avoid
              // stale position bugs when multiple events arrive in the same frame.
              final currentPos = _dragPosition ?? data.position;
              double newX = currentPos.dx + details.delta.dx;
              double newY = currentPos.dy - details.delta.dy;

              // Constrain to screen bounds (with padding)
              const padding = 16.0;
              newX = newX.clamp(padding, size.width - 200);
              newY = newY.clamp(padding, size.height - 100);

              // Update local state during drag (no provider rebuild)
              setState(() => _dragPosition = Offset(newX, newY));
            }),
            onPanEnd: (_) =>
                WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              // Save final position to provider
              if (_dragPosition != null) {
                context
                    .read<AppContentProvider>()
                    .updateEditButtonPosition(_dragPosition!);
                setState(() => _dragPosition = null);
              }
            }),
            child: FloatingActionButton.extended(
              onPressed: () =>
                  context.read<AppContentProvider>().toggleEditMode(),
              backgroundColor: data.isEditMode ? Colors.red : const Color(0xFFD97706),
              icon: Icon(data.isEditMode ? Icons.close : Icons.edit),
              label: Text(data.isEditMode ? 'Exit Edit Mode' : 'Edit Content'),
              tooltip: data.isEditMode
                  ? 'Exit edit mode'
                  : 'Enable edit mode to modify content',
            ),
          ),
        );
      },
    );
  }
}
