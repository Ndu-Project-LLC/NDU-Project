// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// dashboard_header.dart
//
// Shared hero header band for the world-class project dashboards.
//
// Used by:
//   - ProjectDashboardScreen        (/dashboard, Standard plan → "Project workspace overview")
//   - RegularProjectDashboardScreen (/regular-project-dashboard, Basic plan → "Regular Projects workspace")
//
// Renders the signature yellow→gold→amber gradient command band with:
//   • Top row: back button, breadcrumb chip, spacer, Activity button, KAZ AI pill, avatar+logout
//   • Greeting line: time-aware ("Good morning/afternoon/evening, $firstName") + plan badge (BASIC/PRO PLAN)
//   • Sub-line: workspace mode title + user email
//   • CTA row: Create Project / Create Regular Project, Create Program, Create Portfolio, Billing
//     (the three secondary CTAs are auto-hidden on Basic plan, mirroring the existing UX)
//
// Visual tokens (colors, radii, gradients) come from [DashboardPalette] / [DashboardPaletteScope]
// so the header stays in sync with whichever dashboard invokes it.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/screens/project_activities_log_screen.dart';
import 'package:ndu_project/services/firebase_auth_service.dart';
import 'package:ndu_project/utils/dashboard_palette.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';

/// World-class gradient header band shared by the Project and Regular Project
/// dashboards. Renders the full hero command band: navigation row, greeting +
/// plan badge, mode title + email, and the four primary CTAs (Create Project,
/// Create Program, Create Portfolio, Billing).
///
/// The band auto-adapts to the active plan tier through [DashboardPaletteScope]:
///   • Basic plan → bright-yellow "Runway" palette, "BASIC PLAN" badge,
///     "Regular Projects · Basic plan workspace" subtitle, "Create Regular
///     Project" CTA, and Create Program / Create Portfolio are hidden.
///   • Standard plan → rich-gold "Command Center" palette, "PRO PLAN" badge,
///     "Project workspace overview · Standard plan" subtitle, "Create Project"
///     CTA, and all four CTAs are shown.
class DashboardHeader extends StatefulWidget {
  const DashboardHeader({
    super.key,
    required this.onAddProject,
    required this.isBasicPlan,
    this.crumbLabel,
    this.billingRoute,
  });

  /// Primary CTA — opens the project creation flow (Initiation phase).
  final VoidCallback onAddProject;

  /// Whether the active tier is the Basic plan (Regular Projects) or the
  /// Standard plan (Project workspace).
  final bool isBasicPlan;

  /// Optional override for the breadcrumb chip's text. Defaults to
  /// "Project workspace overview".
  final String? crumbLabel;

  /// Optional override for the route the Billing CTA navigates to. Defaults
  /// to the settings screen with `from=dashboard`.
  final String? billingRoute;

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> {
  // ── Navigation handlers ────────────────────────────────────────────────────
  void _navigateToProgram() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go('/${AppRoutes.programDashboard}');
      }
    });
  }

  void _navigateToPortfolio() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go('/${AppRoutes.portfolioDashboard}');
      }
    });
  }

  void _navigateToBilling() {
    if (!mounted) return;
    final route = widget.billingRoute ??
        '/${AppRoutes.settings}?from=${AppRoutes.dashboard}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(route);
      }
    });
  }

  Future<void> _handleLogout() async {
    if (!mounted) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirm Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && mounted) {
      try {
        await FirebaseAuthService.signOut();
        if (mounted) {
          context.go('/');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final palette = DashboardPaletteScope.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final rawDisplayName =
        FirebaseAuthService.displayNameOrEmail(fallback: 'User');
    // If the "display name" is actually an email (no display name set),
    // extract the local part for the greeting and show the full email
    // as a smaller secondary line. This fixes the visual hierarchy issue
    // where the email was competing with the greeting for prominence.
    final isEmail = rawDisplayName.contains('@');
    final displayName =
        isEmail ? rawDisplayName.split('@').first : rawDisplayName;
    final emailLine = isEmail ? rawDisplayName : (user?.email ?? '');
    final firstName = displayName.split(' ').first;
    final initials = _initials(isEmail ? displayName : rawDisplayName);
    final photoUrl = user?.photoURL;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final modeTitle = widget.isBasicPlan
        ? 'Regular Projects · Basic plan workspace'
        : 'Project workspace overview · Standard plan';
    final crumbText = widget.crumbLabel ?? 'Project workspace overview';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.deepBand,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.primaryDeep.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HeaderGridPainter())),
          Positioned(
            right: -70,
            top: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeaderBandAction(
                      icon: Icons.arrow_back_rounded,
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    _crumb(crumbText),
                    const Spacer(),
                    _HeaderBandAction(
                      icon: Icons.fact_check_outlined,
                      label: 'Activity',
                      onTap: () => ProjectActivitiesLogScreen.open(context),
                    ),
                    const SizedBox(width: 8),
                    _kazAiBandPill(),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _handleLogout,
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
                        decoration: BoxDecoration(
                          color: palette.ink.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                              color: palette.ink.withValues(alpha: 0.18)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _avatar(initials, photoUrl),
                            const SizedBox(width: 8),
                            Icon(Icons.logout_rounded,
                                size: 14,
                                color: palette.ink.withValues(alpha: 0.7)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compactHeader = constraints.maxWidth < 900;
                    final greetingBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$greeting, $firstName',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: palette.ink,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _planBadge(palette),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          modeTitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: palette.ink.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (emailLine.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            emailLine,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.55),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    );
                    final ctaRow = Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: widget.onAddProject,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.ink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded,
                                  size: 18, color: palette.primary),
                              const SizedBox(width: 6),
                              Text(widget.isBasicPlan
                                  ? 'Create Regular Project'
                                  : 'Create Project'),
                            ],
                          ),
                        ),
                        if (!widget.isBasicPlan)
                          _bandOutlineCta(
                            label: 'Create Program',
                            onPressed: _navigateToProgram,
                            icon: Icons.layers_outlined,
                          ),
                        if (!widget.isBasicPlan)
                          _bandOutlineCta(
                            label: 'Create Portfolio',
                            onPressed: _navigateToPortfolio,
                            icon: Icons.account_tree_outlined,
                          ),
                        _bandOutlineCta(
                          label: 'Billing',
                          onPressed: _navigateToBilling,
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ],
                    );
                    if (compactHeader) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          greetingBlock,
                          const SizedBox(height: 16),
                          ctaRow,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: greetingBlock),
                        const SizedBox(width: 20),
                        Flexible(child: ctaRow),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Private builders (mirror the original inline helpers) ──────────────────

  Widget _crumb(String label) {
    final palette = DashboardPaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: palette.ink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.ink.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.view_quilt_outlined,
              size: 14, color: palette.ink.withValues(alpha: 0.75)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
        ],
      ),
    );
  }

  /// KAZ AI brand pill on the header band — opens the KAZ AI copilot chat.
  Widget _kazAiBandPill() {
    final palette = DashboardPaletteScope.of(context);
    return InkWell(
      onTap: () => KazAiChatBubble.openChat(context),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
        decoration: BoxDecoration(
          color: palette.ink,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: palette.ink.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFC812), Color(0xFFFF9800)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 12, color: Color(0xFF1C1C1C)),
            ),
            const SizedBox(width: 6),
            Text(
              'KAZ AI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: palette.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String initials, String? photoUrl) {
    final palette = DashboardPaletteScope.of(context);
    const size = 28.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.primarySoft,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: palette.primaryDeep,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: palette.primaryDeep,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _planBadge(DashboardPalette palette) {
    // Subtle translucent outline badge — sits quietly on the dark
    // header band without competing with the greeting for prominence.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isBasicPlan ? Icons.star_outline : Icons.workspace_premium,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            widget.isBasicPlan ? 'BASIC PLAN' : 'PRO PLAN',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bandOutlineCta({
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
  }) {
    final palette = DashboardPaletteScope.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.ink,
        backgroundColor: palette.ink.withValues(alpha: 0.08),
        side: BorderSide(color: palette.ink.withValues(alpha: 0.28)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Icon(icon ?? Icons.keyboard_arrow_right_rounded, size: 18),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return trimmed[0].toUpperCase();
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ── Decorative grid for the dark command band ─────────────────────────────
class _HeaderGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.6;
    const spacing = 30.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Small pill action used on the yellow header band ───────────────────────
class _HeaderBandAction extends StatelessWidget {
  const _HeaderBandAction({required this.icon, this.label, required this.onTap});

  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardPaletteScope.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: palette.ink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.ink.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: palette.ink.withValues(alpha: 0.75)),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(label!,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: palette.ink)),
            ],
          ],
        ),
      ),
    );
  }
}
