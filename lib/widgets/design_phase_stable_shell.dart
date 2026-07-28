import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';

class DesignPhaseStableShell extends StatelessWidget {
  const DesignPhaseStableShell({
    super.key,
    required this.activeLabel,
    required this.child,
    required this.onItemSelected,
    this.breadcrumbPhase,
    this.breadcrumbTitle,
    this.showExportPdf = true,
    this.showAiAssist = true,
    this.onExportPdf,
    this.onAiAssist,
  });

  final String activeLabel;
  final Widget child;
  final ValueChanged<String> onItemSelected;
  final String? breadcrumbPhase;
  final String? breadcrumbTitle;
  final bool showExportPdf;
  final bool showAiAssist;
  final VoidCallback? onExportPdf;
  final VoidCallback? onAiAssist;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);

    if (isMobile) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: Drawer(
          width: AppBreakpoints.sidebarWidth(context),
          child: SafeArea(
            child: InitiationLikeSidebar(
              activeItemLabel: activeLabel,
              showHeader: true,
            ),
          ),
        ),
        body: SafeArea(
          top: true,
          child: Column(
            children: [
              UnifiedPhaseHeader(
                title: activeLabel,
                breadcrumbPhase: breadcrumbPhase,
                breadcrumbTitle: breadcrumbTitle,
                showDrawerButton: true,
                showActivityLogAction: true,
                showExportPdf: showExportPdf,
                showAiAssist: showAiAssist,
                onExportPdf: onExportPdf,
                onAiAssist: onAiAssist,
              ),
              Expanded(
                child: Stack(
                  children: [
                    child,
                    const KazAiChatBubble(positioned: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: AppBreakpoints.sidebarWidth(context),
              child: InitiationLikeSidebar(
                activeItemLabel: activeLabel,
                showHeader: true,
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  UnifiedPhaseHeader(
                    title: activeLabel,
                    breadcrumbPhase: breadcrumbPhase,
                    breadcrumbTitle: breadcrumbTitle,
                    showDrawerButton: false,
                    showActivityLogAction: true,
                    showExportPdf: showExportPdf,
                    showAiAssist: showAiAssist,
                    onExportPdf: onExportPdf,
                    onAiAssist: onAiAssist,
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const KazAiChatBubble(positioned: false),
    );
  }
}
