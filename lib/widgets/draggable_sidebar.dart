import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/responsive.dart';

/// Sidebar wrapper with a draggable handle to collapse or expand it.
///
/// On mobile (< 768px), this widget takes **zero horizontal space** and renders
/// nothing in the layout. Use [MobileSidebarHamburger] as a floating overlay
/// in a Stack, or use [Scaffold.drawer] with [MobileSidebarDrawer] instead.
///
/// On tablet/desktop, the sidebar sits in a Row with a draggable resize handle.
class DraggableSidebar extends StatefulWidget {
  const DraggableSidebar({
    super.key,
    required this.child,
    required this.openWidth,
    this.collapsedWidth = 0,
    this.animationDuration = const Duration(milliseconds: 220),
  });

  final Widget child;
  final double openWidth;
  final double collapsedWidth;
  final Duration animationDuration;

  @override
  State<DraggableSidebar> createState() => _DraggableSidebarState();
}

class _DraggableSidebarState extends State<DraggableSidebar> {
  // Shared width across all DraggableSidebar instances so the collapsed/expanded
  // state persists when navigating between screens.
  static double? _sharedWidth;

  late double _currentWidth = widget.openWidth;
  bool _dragging = false;

  double get _snapThreshold => (widget.openWidth + widget.collapsedWidth) / 2;
  bool get _isCollapsed => _currentWidth <= widget.collapsedWidth + 1;

  @override
  void didUpdateWidget(covariant DraggableSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openWidth != widget.openWidth ||
        oldWidget.collapsedWidth != widget.collapsedWidth) {
      final double baseWidth = (_sharedWidth ?? _currentWidth);
      _currentWidth = baseWidth
          .clamp(widget.collapsedWidth, widget.openWidth);
      _sharedWidth = _currentWidth;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentWidth = (_sharedWidth ?? widget.openWidth)
        .clamp(widget.collapsedWidth, widget.openWidth);
  }

  void _toggleSidebar() {
    setState(() {
      _currentWidth = _isCollapsed ? widget.openWidth : widget.collapsedWidth;
      _dragging = false;
      _sharedWidth = _currentWidth;
    });
  }

  void _handleDragUpdate(double delta) {
    if (delta == 0) return;
    setState(() {
      _dragging = true;
      _currentWidth = (_currentWidth + delta)
          .clamp(widget.collapsedWidth, widget.openWidth);
      _sharedWidth = _currentWidth;
    });
  }

  void _handleDragEnd() {
    setState(() {
      _currentWidth =
          _currentWidth > _snapThreshold ? widget.openWidth : widget.collapsedWidth;
      _dragging = false;
      _sharedWidth = _currentWidth;
    });
  }

  void _openMobileMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height * 0.92;
        return SafeArea(
          child: SizedBox(
            height: height,
            child: widget.child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // On mobile: take zero horizontal space so content extends full-width.
    // Use MobileSidebarHamburger or Scaffold.drawer instead.
    if (AppBreakpoints.isMobile(context)) {
      return const SizedBox.shrink();
    }

    final bool collapsed = _isCollapsed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: _dragging ? Duration.zero : widget.animationDuration,
          curve: Curves.easeOutCubic,
          width: _currentWidth,
          child: IgnorePointer(
            ignoring: collapsed,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: collapsed ? 0 : 1,
              child: widget.child,
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _toggleSidebar,
          onHorizontalDragStart: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _dragging = true);
          }),
          onHorizontalDragUpdate: (details) =>
              WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _handleDragUpdate(details.primaryDelta ?? 0);
          }),
          onHorizontalDragEnd: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _handleDragEnd();
          }),
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: Tooltip(
              message: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
              child: Container(
                width: 32,
                height: double.infinity,
                alignment: Alignment.center,
                child: Container(
                  width: 28,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      collapsed ? Icons.chevron_right : Icons.chevron_left,
                      size: 20,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A floating hamburger button for mobile screens that opens a bottom sheet
/// with the sidebar content. Place this as a positioned overlay in a Stack.
///
/// Example:
/// ```dart
/// Stack(
///   children: [
///     // Full-width content
///     SingleChildScrollView(...),
///     // Floating hamburger overlay (mobile only)
///     const MobileSidebarHamburger(),
///     const KazAiChatBubble(),
///   ],
/// )
/// ```
class MobileSidebarHamburger extends StatelessWidget {
  const MobileSidebarHamburger({
    super.key,
    required this.sidebar,
  });

  /// The sidebar widget to show in the bottom sheet.
  final Widget sidebar;

  @override
  Widget build(BuildContext context) {
    // Only show on mobile
    if (!AppBreakpoints.isMobile(context)) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) {
                  final height = MediaQuery.sizeOf(context).height * 0.92;
                  return SafeArea(
                    child: SizedBox(
                      height: height,
                      child: sidebar,
                    ),
                  );
                },
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.menu, color: Color(0xFF374151), size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

/// A drawer widget for mobile screens. Use with Scaffold.drawer.
///
/// Example:
/// ```dart
/// Scaffold(
///   drawer: MobileSidebarDrawer(
///     sidebar: InitiationLikeSidebar(activeItemLabel: 'Quality Management'),
///   ),
///   body: ...,
/// )
/// ```
class MobileSidebarDrawer extends StatelessWidget {
  const MobileSidebarDrawer({
    super.key,
    required this.sidebar,
  });

  final Widget sidebar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppBreakpoints.sidebarWidth(context),
      child: sidebar,
    );
  }
}
