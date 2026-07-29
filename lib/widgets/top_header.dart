import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ndu_project/services/user_service.dart';

/// A small circular icon button used for back/forward navigation arrows.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
      ),
    );
  }
}

/// A compact user avatar + role chip for the page header.
class UserChip extends StatelessWidget {
  const UserChip();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email ?? 'User';
    final email = user?.email ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage:
                user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            child: user?.photoURL == null
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          StreamBuilder<bool>(
            stream: UserService.watchAdminStatus(),
            builder: (context, snapshot) {
              final isAdmin =
                  snapshot.data ?? UserService.isAdminEmail(email);
              final role = isAdmin ? 'Admin' : 'Member';
              return Text(
                role,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Describes an action button to display in the [TopHeader].
class TopHeaderAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const TopHeaderAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

/// A shared page header row with back/forward navigation arrows, title,
/// optional action buttons, and a user chip.
///
/// Replaces duplicate private `_TopHeader` implementations across
/// Planning Phase subscreen files.
class TopHeader extends StatelessWidget {
  const TopHeader({
    required this.title,
    required this.onBack,
    this.onNext,
    this.actions = const [],
  });

  /// Page title displayed between the navigation arrows and action buttons.
  final String title;

  /// Callback for the back (left) arrow button.
  final VoidCallback onBack;

  /// Optional callback for the forward (right) arrow button.
  /// When null the arrow is hidden and layout is balanced.
  final VoidCallback? onNext;

  /// Optional action buttons (e.g. "Add Role", "Standard Roles").
  /// Displayed as yellow filled buttons between the title and [UserChip].
  final List<TopHeaderAction> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: onBack,
        ),
        const SizedBox(width: 12),
        if (onNext != null)
          CircleIconButton(
            icon: Icons.arrow_forward_ios_rounded,
            onTap: onNext,
          )
        else
          const SizedBox(width: 36), // balanced spacing when no forward arrow
        const SizedBox(width: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        if (actions.isNotEmpty) const SizedBox(width: 24),
        ...actions.asMap().entries.map((entry) => Padding(
              padding: EdgeInsets.only(right: entry.key < actions.length - 1 ? 12 : 0),
              child: _ActionButton(
                label: entry.value.label,
                icon: entry.value.icon,
                onPressed: entry.value.onPressed,
              ),
            )),
        const Spacer(),
        const SizedBox(width: 12),
        const UserChip(),
      ],
    );
  }
}

/// Internal yellow filled action button used by [TopHeader.actions].
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: const Color(0xFF1F2933),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}
