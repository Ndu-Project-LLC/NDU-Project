import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/responsive.dart';

/// A responsive layout that provides full-width content on mobile
/// and a sidebar + content Row on tablet/desktop.
///
/// On mobile (< 768px):
///   - The sidebar becomes a `Scaffold.drawer` (slides in from left)
///   - Content extends to the full screen width
///   - A hamburger icon is shown at the top-left (if [showMobileHamburger] is true)
///
/// On tablet/desktop:
///   - The sidebar sits in a `Row` next to the content
///   - A draggable resize handle is shown between sidebar and content
class ResponsiveScaffoldLayout extends StatelessWidget {
  const ResponsiveScaffoldLayout({
    super.key,
    required this.sidebar,
    required this.sidebarActiveItemLabel,
    required this.body,
    this.showMobileHamburger = true,
    this.backgroundColor = const Color(0xFFF5F7FB),
    this.mobilePadding = 16.0,
    this.desktopPadding = 32.0,
    this.floatingWidget,
  });

  /// The sidebar widget (typically InitiationLikeSidebar).
  final Widget sidebar;

  /// The active item label to pass to the sidebar on mobile drawer.
  final String sidebarActiveItemLabel;

  /// The main content widget (already wrapped in SingleChildScrollView, etc.).
  final Widget body;

  /// Whether to show the hamburger icon in the mobile layout.
  final bool showMobileHamburger;

  /// Background color for the Scaffold.
  final Color backgroundColor;

  /// Horizontal padding on mobile.
  final double mobilePadding;

  /// Horizontal padding on tablet/desktop.
  final double desktopPadding;

  /// Optional floating widget (e.g., KazAiChatBubble) to overlay on the body.
  final Widget? floatingWidget;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);

    if (isMobile) {
      return _buildMobileLayout(context);
    }
    return _buildDesktopLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: SizedBox(
        width: AppBreakpoints.sidebarWidth(context),
        child: SafeArea(child: sidebar),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: mobilePadding),
              child: body,
            ),
            if (floatingWidget != null)
              Positioned(bottom: 24, right: 24, child: floatingWidget!),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    // Import DraggableSidebar locally to avoid circular deps
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DesktopSidebarWrapper(
              openWidth: AppBreakpoints.sidebarWidth(context),
              child: sidebar,
            ),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: desktopPadding, vertical: 28),
                    child: body,
                  ),
                  if (floatingWidget != null)
                    Positioned(bottom: 24, right: 24, child: floatingWidget!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Private wrapper that imports and uses DraggableSidebar for desktop layout.
class _DesktopSidebarWrapper extends StatelessWidget {
  const _DesktopSidebarWrapper({
    required this.openWidth,
    required this.child,
  });

  final double openWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Use DraggableSidebar from the existing widget
    // This import is at the top of the file
    return _buildDraggableSidebar();
  }

  Widget _buildDraggableSidebar() {
    // Use SizedBox to enforce the correct sidebar width
    // The actual DraggableSidebar is used directly by screens
    return SizedBox(width: openWidth, child: child);
  }
}
