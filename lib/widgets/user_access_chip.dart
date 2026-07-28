import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/user_service.dart';

class UserAccessChip extends StatelessWidget {
  const UserAccessChip({super.key, this.compact = true, this.showCaret = true});

  final bool compact;
  final bool showCaret;

  String _initials(String name) {
    if (name.trim().isEmpty) return 'U';
    return name.trim()[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = FirebaseAuthService.displayNameOrEmail(fallback: 'User');
    final email = user?.email ?? '';
    final name = displayName.isNotEmpty ? displayName : (email.isNotEmpty ? email : 'User');
    final photoUrl = user?.photoURL ?? '';
    final avatarRadius = compact ? 14.0 : 16.0;
    final nameSize = compact ? 13.0 : 14.0;
    final roleSize = compact ? 12.0 : 12.0;
    final padding = compact ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    return StreamBuilder<bool>(
      stream: UserService.watchAdminStatus(),
      builder: (context, snapshot) {
        final isAdmin = snapshot.data ?? UserService.isAdminEmail(email);
        final role = isAdmin ? 'Admin' : 'Member';

        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: const Color(0xFFE5E7EB),
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Text(
                        _initials(name),
                        style: TextStyle(fontSize: nameSize, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(name, style: TextStyle(fontSize: nameSize, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(width: 8),
              Text(role, style: TextStyle(fontSize: roleSize, color: const Color(0xFF6B7280))),
              if (showCaret) ...[
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF9CA3AF)),
              ],
            ],
          ),
        );
      },
    );
  }
}
