import 'package:flutter/material.dart';
import 'package:ndu_project/widgets/initiation_like_sidebar.dart';
import 'package:ndu_project/widgets/kaz_ai_chat_bubble.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';

/// Bottom padding reserved for the floating chat bubble FAB
/// (the floating Save pill was removed per user request).
const double kFloatingBottomReservedHeight = 96.0;

class DesignPhaseStableShell extends StatelessWidget {
  const DesignPhaseStableShell({
    super.key,
    required this.activeLabel,
    required this.child,
    required this.onItemSelected,
    this.breadcrumbPhase,
    this.breadcrumbTitle,
    this.showExportPdf = true,
    this.showAiAssist = false,
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
                    // Pad child content so the floating Save pill +
                    // chat bubble FAB never overlap body content.
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: kFloatingBottomReservedHeight,
                        ),
                        child: child,
                      ),
                    ),
                    const KazAiChatBubble(positioned: true),
                    // Global Save pill removed per user request — auto-save
                    // keeps persistence working without it.
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
                  Expanded(
                    child: Stack(
                      children: [
                        // Pad child content so the floating Save pill +
                        // chat bubble FAB never overlap body content.
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: kFloatingBottomReservedHeight,
                            ),
                            child: child,
                          ),
                        ),
                        const KazAiChatBubble(positioned: true),
                        // Global Save pill removed per user request —
                        // auto-save keeps persistence working without it.
                      ],
                    ),
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
