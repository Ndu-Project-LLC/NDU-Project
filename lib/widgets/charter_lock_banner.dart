// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// charter_lock_banner.dart
//
// Reusable banner shown at the top of any Initiation Phase / Front End
// Planning sub-section page once the Project Charter has been approved.
//
// Per Task 14: once the charter is approved, the listed sub-section pages
// must be locked from editing. This banner makes the lock visible to the
// user (so they understand WHY fields are read-only) and provides an
// `applyLock` helper that wraps any editable subtree in an `AbsorbPointer`
// so taps on TextFields / IconButtons / form rows are silently ignored.
//
// Usage:
//   final locked = ProjectDataHelper.isCharterApproved(context, listen: true);
//   ...
//   CharterLockBanner(visible: locked),
//   CharterLockBanner.applyLock(locked: locked, child: editableForm),
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';

/// A thin amber banner that reads "Charter approved — section locked from
/// editing". Rendered at the top of a locked sub-section page so the user
/// understands why every field is read-only.
class CharterLockBanner extends StatelessWidget {
  const CharterLockBanner({
    super.key,
    required this.visible,
    this.message =
        'Charter approved — this section is locked from editing. '
        'Open the Project Charter page to request changes.',
  });

  final bool visible;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7C98E), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 16, color: Color(0xFF92580A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A4A00),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Wraps [child] in an [AbsorbPointer] when [locked] is true, so all
  /// taps on TextFields / IconButtons / Dropdowns inside the subtree are
  /// silently ignored. When [locked] is false, returns [child] untouched.
  ///
  /// Use this around the editable portion of each sub-section page so
  /// the user can still scroll/read the data but cannot modify it.
  static Widget applyLock({required bool locked, required Widget child}) {
    if (!locked) return child;
    return AbsorbPointer(absorbing: true, child: child);
  }
}
