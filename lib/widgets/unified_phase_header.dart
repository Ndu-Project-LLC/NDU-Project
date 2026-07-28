import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/screens/project_activities_log_screen.dart';
import 'package:ndu_project/screens/settings_screen.dart';
import 'package:ndu_project/services/auth_nav.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/utils/pdf_export_helper.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/utils/ai_assist_helper.dart';
import 'package:ndu_project/widgets/responsive.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand design tokens (matching the HTML source / Material You spec)
// ─────────────────────────────────────────────────────────────────────────────
class _Tokens {
  static const background = Color(0xFFF7F9FB);
  static const surface = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF191C1E);
  static const onSurfaceVariant = Color(0xFF414754);
  static const outline = Color(0xFF717786);
  static const outlineVariant = Color(0xFFC0C6D6);
  static const primary = Color(0xFFB45309);
  static const tertiaryFixedDim = Color(0xFFFABD00);
  static const tertiary = Color(0xFF755700);
}

class UnifiedPhaseHeader extends StatelessWidget {
  const UnifiedPhaseHeader({
    super.key,
    required this.title,
    this.scaffoldKey,
    this.onBackPressed,
    this.onForwardPressed,
    this.trailingActions = const <Widget>[],
    this.showActivityLogAction = true,
    this.onOpenActivityLog,
    this.backgroundColor = Colors.white,
    this.showDrawerButton = true,
    this.breadcrumbPhase,
    this.breadcrumbTitle,
    this.showExportPdf = false,
    this.showAiAssist = false,
    this.onExportPdf,
    this.onAiAssist,
  });

  final String title;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final VoidCallback? onBackPressed;
  final VoidCallback? onForwardPressed;
  final List<Widget> trailingActions;
  final bool showActivityLogAction;
  final VoidCallback? onOpenActivityLog;
  final Color backgroundColor;
  final bool showDrawerButton;

  /// Optional phase label for the breadcrumb bar (e.g. "Planning Phase").
  /// Falls back to "Phase" if not provided.
  final String? breadcrumbPhase;

  /// Optional page title for the breadcrumb bar (e.g. "Risk Assessment").
  /// Falls back to [title] if not provided.
  final String? breadcrumbTitle;

  /// Show Export PDF button in the header.
  final bool showExportPdf;

  /// Show AI Assist button in the header.
  final bool showAiAssist;

  /// Callback for Export PDF button.
  final VoidCallback? onExportPdf;

  /// Callback for AI Assist button.
  final VoidCallback? onAiAssist;

  void _openDrawer(BuildContext context) {
    HapticFeedback.selectionClick();
    if (scaffoldKey?.currentState != null) {
      scaffoldKey!.currentState!.openDrawer();
    } else {
      final scaffold = Scaffold.maybeOf(context);
      if (scaffold != null && scaffold.hasDrawer) {
        scaffold.openDrawer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);

    if (isMobile) {
      return _buildMobileHeader(context);
    }
    return _buildDesktopHeader(context);
  }

  // ─── Mobile: Top bar + breadcrumb bar (matching the screenshot) ─────────
  Widget _buildMobileHeader(BuildContext context) {
    final phaseLabel = breadcrumbPhase ?? 'Phase';
    final pageLabel = breadcrumbTitle ?? title;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Top app bar: hamburger | NDUPROJECT | bell + chat ────────────
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: _Tokens.surface,
            border: Border(
              bottom: BorderSide(color: _Tokens.outlineVariant.withOpacity(0.5)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Left: Hamburger menu
                if (showDrawerButton)
                  IconButton(
                    icon: const Icon(Icons.menu, color: _Tokens.onSurface, size: 24),
                    tooltip: 'Open menu',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    onPressed: () => _openDrawer(context),
                  ),
                const Spacer(),
                // Center: NDUPROJECT brand
                const Text(
                  'NDUPROJECT',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _Tokens.onSurface,
                    letterSpacing: -0.01,
                  ),
                ),
                const Spacer(),
                // Right: Notification bell
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded,
                      color: _Tokens.onSurface, size: 22),
                  tooltip: 'Notifications',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  onPressed: () {
                    // Placeholder for notification action
                  },
                ),
                const SizedBox(width: 4),
                // Right: Yellow chat "C" button
                GestureDetector(
                  onTap: () => KazAiChatBubble.openChat(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: _Tokens.tertiaryFixedDim,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'C',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Breadcrumb bar: back | Phase > Page | forward ─────────────────
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: _Tokens.surface,
            border: Border(
              bottom: BorderSide(color: _Tokens.outlineVariant.withOpacity(0.5)),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // Back navigation
              _BreadcrumbNavButton(
                icon: Icons.chevron_left_rounded,
                onTap: onBackPressed ?? () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 4),
              // Breadcrumb text
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        phaseLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _Tokens.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: _Tokens.outline,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        pageLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _Tokens.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Forward navigation
              _BreadcrumbNavButton(
                icon: Icons.chevron_right_rounded,
                onTap: onForwardPressed,
                enabled: onForwardPressed != null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Desktop: original layout (back/forward | title | activity log + profile) ─
  Widget _buildDesktopHeader(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 16),
            tooltip: 'Back',
            onPressed: onBackPressed ?? () => context.pop(),
          ),
          if (onForwardPressed != null)
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              tooltip: 'Forward',
              onPressed: onForwardPressed,
            ),
          const Spacer(),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D3748),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
          if (showExportPdf)
            _HeaderActionChip(
              icon: Icons.picture_as_pdf_outlined,
              label: 'Export PDF',
              onTap: onExportPdf ??
                  () {
                    PdfExportHelper.exportScreenPdf(
                      context: context,
                      screenTitle: title,
                      sections: [
                        PdfSection.text(title, 'Project section export from Ndu Project.'),
                      ],
                    );
                  },
            ),
          if (showExportPdf) const SizedBox(width: 8),
          if (showAiAssist)
            _AiAssistChip(
              label: 'AI Assist',
              onTap: onAiAssist ??
                  () {
                    AiAssistHelper.generateForSection(context, sectionLabel: title);
                  },
            ),
          if (showAiAssist) const SizedBox(width: 8),
          if (showActivityLogAction)
            _ActivityLogAction(
              compact: false,
              onTap: onOpenActivityLog ??
                  () => ProjectActivitiesLogScreen.open(context),
            ),
          if (showActivityLogAction) const SizedBox(width: 12),
          ...trailingActions,
          if (trailingActions.isNotEmpty) const SizedBox(width: 12),
          const UnifiedProfileMenu(compact: true),
        ],
      ),
    );
  }
}

// ─── Breadcrumb nav button (back/forward chevron) ─────────────────────────
class _BreadcrumbNavButton extends StatelessWidget {
  const _BreadcrumbNavButton({
    required this.icon,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _Tokens.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? _Tokens.outlineVariant
                : _Tokens.outlineVariant.withOpacity(0.3),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? _Tokens.onSurfaceVariant
              : _Tokens.outlineVariant.withOpacity(0.4),
        ),
      ),
    );
  }
}

// ─── Legacy circle nav button (kept for backward compatibility) ───────────
class _CircleNavButton extends StatelessWidget {
  const _CircleNavButton({
    required this.icon,
    required this.iconSize,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final double iconSize;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFE2E8F0),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: enabled ? const Color(0xFF374151) : const Color(0xFFCBD5E0),
        ),
      ),
    );
  }
}

// ─── UnifiedScaffoldAppBar — AppBar wrapper for screens needing Scaffold.appBar ─
class UnifiedScaffoldAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const UnifiedScaffoldAppBar({
    super.key,
    this.backgroundColor,
    this.title,
    this.onMenuTap,
    this.showActivityLogAction = true,
    this.onOpenActivityLog,
  });

  final Color? backgroundColor;
  final String? title;
  final VoidCallback? onMenuTap;
  final bool showActivityLogAction;
  final VoidCallback? onOpenActivityLog;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    final isMobile = AppBreakpoints.isMobile(context);

    return AppBar(
      backgroundColor: bg,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF374151)),
          tooltip: 'Open menu',
          onPressed: onMenuTap ?? () {
            final scaffold = Scaffold.maybeOf(context);
            if (scaffold != null && scaffold.hasDrawer) {
              scaffold.openDrawer();
            }
          },
        ),
      ),
      title: title == null
          ? null
          : Text(
              title!,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
      centerTitle: true,
      actions: [
        if (showActivityLogAction)
          Padding(
            padding: EdgeInsets.only(right: isMobile ? 8 : 10),
            child: _ActivityLogAction(
              compact: isMobile,
              onTap: onOpenActivityLog ??
                  () => ProjectActivitiesLogScreen.open(context),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(right: isMobile ? 8 : 12),
          child: const UnifiedProfileMenu(compact: true),
        ),
      ],
    );
  }
}

// ─── Unified profile menu (avatar + popup) ────────────────────────────────
class UnifiedProfileMenu extends StatelessWidget {
  const UnifiedProfileMenu({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    final displayName = () {
      try {
        return FirebaseAuthService.displayNameOrEmail(fallback: 'Unknown User');
      } catch (_) {
        return 'Unknown User';
      }
    }();
    final email = user?.email?.trim() ?? '';
    final avatarInitial = displayName.trim().isNotEmpty
        ? displayName.trim().characters.first.toUpperCase()
        : 'U';
    final photoUrl = user?.photoURL;
    Stream<bool> adminStatusStream;
    try {
      adminStatusStream = UserService.watchAdminStatus();
    } catch (_) {
      adminStatusStream = Stream<bool>.value(UserService.isAdminEmail(email));
    }

    final avatar = photoUrl != null && photoUrl.isNotEmpty
        ? CircleAvatar(
            radius: compact ? 16 : 20,
            backgroundImage: NetworkImage(photoUrl),
            backgroundColor: const Color(0xFFD97706),
          )
        : Container(
            width: compact ? 32 : 40,
            height: compact ? 32 : 40,
            decoration: const BoxDecoration(
              color: const Color(0xFFD97706),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              avatarInitial,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 13 : 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          );

    final label = Material(
      color: Colors.transparent,
      child: compact
          ? avatar
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                const SizedBox(width: 10),
                StreamBuilder<bool>(
                  stream: adminStatusStream,
                  builder: (context, snapshot) {
                    final isAdmin =
                        snapshot.data ?? UserService.isAdminEmail(email);
                    final role = isAdmin ? 'Admin' : 'Member';
                    final emailIsDuplicate =
                        email.isNotEmpty && displayName == email;
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          if (!emailIsDuplicate)
                            Text(
                              email.isEmpty ? 'No email' : email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          Text(
                            role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );

    return PopupMenuButton<String>(
      tooltip: 'Profile actions',
      onSelected: (value) {
        if (value == 'settings') {
          SettingsScreen.open(context);
        } else if (value == 'logout') {
          AuthNav.signOutAndExit(context);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'settings',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_outlined),
            title: Text('Logout'),
          ),
        ),
      ],
      child: label,
    );
  }
}

// ─── Activity log action button ───────────────────────────────────────────
class _ActivityLogAction extends StatelessWidget {
  const _ActivityLogAction({
    required this.compact,
    required this.onTap,
  });

  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Project Activity Log',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD873)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.fact_check_outlined,
                size: 18,
                color: Color(0xFFB45309),
              ),
              if (!compact) ...[
                const SizedBox(width: 6),
                const Text(
                  'Activity Log',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Export PDF header action chip ─────────────────────────────────────────
class _HeaderActionChip extends StatelessWidget {
  const _HeaderActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC7D2FE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF4154F1)),
              const SizedBox(width: 6),
              const Text(
                'Export PDF',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4154F1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── AI Assist header action chip ─────────────────────────────────────────
class _AiAssistChip extends StatelessWidget {
  const _AiAssistChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF4154F1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
