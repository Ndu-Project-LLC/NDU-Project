import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/program_workspace_sidebar.dart';
import 'package:ndu_project/widgets/responsive.dart';

/// Responsive scaffold for ProgramWorkspaceSidebar-based screens.
/// - Desktop/Tablet: persistent sidebar
/// - Mobile: sidebar in a Drawer with a menu AppBar
class ProgramWorkspaceScaffold extends StatelessWidget {
  const ProgramWorkspaceScaffold({
    super.key,
    required this.body,
    this.backgroundColor,
    this.floatingActionButton,
    this.showSidebar = true,
  });

  final Widget body;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final bool showSidebar;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final bgColor = backgroundColor ?? const Color(0xFFF7F8FC);

    if (isMobile) {
      return Scaffold(
        backgroundColor: bgColor,
        drawer: showSidebar
            ? Drawer(
                width: AppBreakpoints.sidebarWidth(context),
                child: const SafeArea(child: ProgramWorkspaceSidebar()),
              )
            : null,
        body: SafeArea(
          top: true,
          child: Stack(
            children: [
              body,
              if (floatingActionButton != null) floatingActionButton!,
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSidebar) const ProgramWorkspaceSidebar(),
            Expanded(
              child: Stack(
                children: [
                  body,
                  if (floatingActionButton != null) floatingActionButton!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
