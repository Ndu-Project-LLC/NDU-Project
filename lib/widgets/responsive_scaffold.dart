import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/draggable_sidebar.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';
import 'package:ndu_project/widgets/activity_log_app_bar_button.dart';

/// A responsive scaffold that adapts sidebar behavior based on screen size.
/// - Desktop/Tablet: Shows sidebar in a Row layout with draggable handle
/// - Mobile: Hides sidebar and uses a Drawer, with a menu button in the app bar
///
/// When [appBarTitle] is provided, a [UnifiedPhaseHeader] is automatically
/// prepended to the body on mobile, giving users a hamburger menu, navigation
/// arrows, title and profile avatar – matching the "Risk Mitigation" header
/// pattern used throughout the app.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.body,
    this.activeItemLabel,
    this.backgroundColor,
    this.floatingActionButton,
    this.showSidebar = true,
    this.appBarTitle,
    this.onBackPressed,
    this.onForwardPressed,
    this.breadcrumbPhase,
    this.breadcrumbTitle,
  });

  /// The main content of the screen
  final Widget body;

  /// Label for the active sidebar item (for highlighting)
  final String? activeItemLabel;

  /// Background color for the scaffold
  final Color? backgroundColor;

  /// Optional FAB or floating widget (e.g., KazAiChatBubble)
  final Widget? floatingActionButton;

  /// Whether to show the sidebar at all (useful for screens that don't need it)
  final bool showSidebar;

  /// When set, a [UnifiedPhaseHeader] is automatically prepended to the body
  /// on mobile viewports. This provides the hamburger menu, back/forward
  /// navigation, title and profile avatar. Leave null if the body already
  /// contains its own navigation header.
  final String? appBarTitle;

  /// Optional back-navigation callback passed through to [UnifiedPhaseHeader].
  final VoidCallback? onBackPressed;

  /// Optional forward-navigation callback passed through to [UnifiedPhaseHeader].
  final VoidCallback? onForwardPressed;

  /// Optional breadcrumb phase label passed through to [UnifiedPhaseHeader].
  final String? breadcrumbPhase;

  /// Optional breadcrumb page title passed through to [UnifiedPhaseHeader].
  final String? breadcrumbTitle;

  /// Build the body, optionally wrapping it with a navigation header on mobile.
  Widget _wrapBody(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    if (!isMobile || appBarTitle == null) return body;

    return Column(
      children: [
        UnifiedPhaseHeader(
          title: appBarTitle!,
          breadcrumbPhase: breadcrumbPhase,
          breadcrumbTitle: breadcrumbTitle,
          onBackPressed: onBackPressed,
          onForwardPressed: onForwardPressed,
        ),
        Expanded(child: body),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final bgColor = backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

    final wrappedBody = _wrapBody(context);

    if (isMobile) {
      return _MobileScaffold(
        body: wrappedBody,
        activeItemLabel: activeItemLabel,
        backgroundColor: bgColor,
        floatingActionButton: floatingActionButton,
        showSidebar: showSidebar,
      );
    }

    return _DesktopScaffold(
      body: wrappedBody,
      activeItemLabel: activeItemLabel,
      backgroundColor: bgColor,
      floatingActionButton: floatingActionButton,
      showSidebar: showSidebar,
    );
  }
}

class _MobileScaffold extends StatelessWidget {
  const _MobileScaffold({
    required this.body,
    this.activeItemLabel,
    required this.backgroundColor,
    this.floatingActionButton,
    required this.showSidebar,
  });

  final Widget body;
  final String? activeItemLabel;
  final Color backgroundColor;
  final Widget? floatingActionButton;
  final bool showSidebar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: showSidebar
          ? Drawer(
              width: AppBreakpoints.sidebarWidth(context),
              child: SafeArea(
                child: InitiationLikeSidebar(
                  activeItemLabel: activeItemLabel,
                  showHeader: true,
                ),
              ),
            )
          : null,
      body: SafeArea(
        top: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: body,
            ),
            // NOTE: Activity Log button removed from here — it's already
            // rendered by PlanningPhaseHeader/UnifiedPhaseHeader. Having
            // both caused a duplicate Activity Log button on every screen.
            if (floatingActionButton != null)
              Positioned(
                bottom: 24,
                right: 24,
                child: floatingActionButton!,
              ),
          ],
        ),
      ),
    );
  }
}

class _DesktopScaffold extends StatelessWidget {
  const _DesktopScaffold({
    required this.body,
    this.activeItemLabel,
    required this.backgroundColor,
    this.floatingActionButton,
    required this.showSidebar,
  });

  final Widget body;
  final String? activeItemLabel;
  final Color backgroundColor;
  final Widget? floatingActionButton;
  final bool showSidebar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSidebar)
              DraggableSidebar(
                openWidth: AppBreakpoints.sidebarWidth(context),
                child: InitiationLikeSidebar(activeItemLabel: activeItemLabel),
              ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: body,
                  ),
                  // NOTE: Activity Log button removed from here — it's
                  // already rendered by PlanningPhaseHeader/
                  // UnifiedPhaseHeader. Having both caused a duplicate
                  // Activity Log button on every screen.
                  if (floatingActionButton != null)
                    Positioned(
                      bottom: 24,
                      right: 24,
                      child: floatingActionButton!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget for responsive grid layouts in content areas.
/// Automatically switches between multi-column and single-column layouts.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.desktopColumns = 3,
    this.tabletColumns = 2,
    this.mobileColumns = 1,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  final List<Widget> children;
  final int desktopColumns;
  final int tabletColumns;
  final int mobileColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final isTablet = AppBreakpoints.isTablet(context);

    int columns;
    if (isMobile) {
      columns = mobileColumns;
    } else if (isTablet) {
      columns = tabletColumns;
    } else {
      columns = desktopColumns;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = spacing * (columns - 1);
        final itemWidth = (constraints.maxWidth - totalSpacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}

/// Helper widget for responsive row/column layouts.
/// Shows children in a Row on larger screens, Column on mobile.
class ResponsiveRowOrColumn extends StatelessWidget {
  const ResponsiveRowOrColumn({
    super.key,
    required this.children,
    this.rowMainAxisAlignment = MainAxisAlignment.start,
    this.rowCrossAxisAlignment = CrossAxisAlignment.start,
    this.columnMainAxisAlignment = MainAxisAlignment.start,
    this.columnCrossAxisAlignment = CrossAxisAlignment.stretch,
    this.rowSpacing = 16,
    this.columnSpacing = 16,
  });

  final List<Widget> children;
  final MainAxisAlignment rowMainAxisAlignment;
  final CrossAxisAlignment rowCrossAxisAlignment;
  final MainAxisAlignment columnMainAxisAlignment;
  final CrossAxisAlignment columnCrossAxisAlignment;
  final double rowSpacing;
  final double columnSpacing;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);

    if (isMobile) {
      return Column(
        mainAxisAlignment: columnMainAxisAlignment,
        crossAxisAlignment: columnCrossAxisAlignment,
        children: _insertSpacing(children, columnSpacing, isRow: false),
      );
    }

    return Row(
      mainAxisAlignment: rowMainAxisAlignment,
      crossAxisAlignment: rowCrossAxisAlignment,
      children: _insertSpacing(children, rowSpacing, isRow: true),
    );
  }

  List<Widget> _insertSpacing(List<Widget> widgets, double spacing, {required bool isRow}) {
    if (widgets.isEmpty) return widgets;

    final result = <Widget>[];
    for (int i = 0; i < widgets.length; i++) {
      if (isRow) {
        result.add(Expanded(child: widgets[i]));
      } else {
        result.add(widgets[i]);
      }
      if (i < widgets.length - 1) {
        result.add(SizedBox(
          width: isRow ? spacing : 0,
          height: isRow ? 0 : spacing,
        ));
      }
    }
    return result;
  }
}
