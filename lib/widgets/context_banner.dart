// Context Banner — a subtle, dismissible horizontal strip placed between the
// SectionNavigator and the tab content on each Planning Phase page.
//
// Renders a small light-gray card with an info icon and a horizontally
// scrollable row of label/value pairs summarising the upstream data the
// current page is drawing from (e.g. project name, WBS, cost estimate total).
//
// Each [ContextBannerItem] is rendered as `Label · value`. The user can
// dismiss the banner; the dismissed state is local to the widget instance
// (so re-mounting the page re-shows the banner).
//
// Light-mode design tokens (white cards, gold #FFC107 accent, 12px radius)
// are respected — the banner uses a subtle gray surface (#F9FAFB) with a
// 1px outline (#E4E7EC) and 8px radius (compact variant of the 12px token)
// so it does not visually compete with the white content cards beneath it.

import 'package:flutter/material.dart';
import 'package:ndu_project/theme.dart';
import 'package:ndu_project/services/planning_phase_context_service.dart';

/// Factory to build ContextBannerItems automatically from the
/// [PlanningPhaseContextService] for a given screen.
List<ContextBannerItem> buildContextBannerItemsFromService(
    String screenId) {
  final service = PlanningPhaseContextService.instance;
  final bannerData = service.buildBannerItems(screenId);

  return bannerData.map((item) {
    // Choose an icon based on the screen type
    IconData icon;
    switch (item.screenId) {
      case 'project_framework':
        icon = Icons.folder_open;
        break;
      case 'work_breakdown_structure':
        icon = Icons.account_tree;
        break;
      case 'project_goals_milestones':
        icon = Icons.flag;
        break;
      case 'requirements':
        icon = Icons.checklist;
        break;
      case 'quality_management':
        icon = Icons.verified;
        break;
      case 'design':
        icon = Icons.design_services;
        break;
      case 'technology':
        icon = Icons.memory;
        break;
      // Launch Phase icons
      case 'deliver_project_closure':
        icon = Icons.fact_check_outlined;
        break;
      case 'transition_to_prod_team':
        icon = Icons.send_outlined;
        break;
      case 'fat_mechanical_completion':
        icon = Icons.engineering;
        break;
      case 'contract_close_out':
        icon = Icons.handshake;
        break;
      case 'actual_vs_planned_gap_analysis':
        icon = Icons.compare_arrows_outlined;
        break;
      case 'commerce_viability':
        icon = Icons.verified_user_outlined;
        break;
      case 'financial_closeout':
        icon = Icons.account_balance_wallet;
        break;
      case 'summarize_account_risks':
        icon = Icons.insights;
        break;
      case 'benefits_realization':
        icon = Icons.trending_up;
        break;
      case 'demobilize_team':
        icon = Icons.groups_outlined;
        break;
      case 'project_close_out':
        icon = Icons.check_circle_outline;
        break;
      default:
        icon = Icons.arrow_right;
    }

    return ContextBannerItem(
      label: item.label,
      value: item.value,
      icon: icon,
      screenTitle: item.screenTitle,
    );
  }).toList();
}

/// A single label/value pair shown inside the context banner.
class ContextBannerItem {
  final String label;
  final String value;
  final IconData? icon;
  final String? screenTitle;

  const ContextBannerItem({
    required this.label,
    required this.value,
    this.icon,
    this.screenTitle,
  });
}

/// A subtle dismissible banner showing upstream project context.
///
/// Place this widget between the [SectionNavigator] and the tab content
/// inside each Planning Phase module screen (WBS, Cost Estimate, Schedule).
class ContextBanner extends StatefulWidget {
  /// The items to display in the banner. Each item renders as a chip with
  /// `Label · value` (or `Label: value` if you prefer — we use a middot for
  /// compactness). Pass an empty list to render nothing.
  final List<ContextBannerItem> items;

  /// Optional leading icon shown before the items. Defaults to `info_outline`.
  final IconData leadingIcon;

  /// Optional leading tooltip / accessibility label.
  final String semanticsLabel;

  /// Optional key used to persist the dismissed state across re-mounts within
  /// a single app session. If two banners share the same [storageKey], the
  /// dismissed state is shared. Defaults to `null` (no persistence — the
  /// banner re-appears when the page is re-mounted).
  final String? storageKey;

  /// Screen ID for automatic context fetching from PlanningPhaseContextService.
  /// When provided, items are automatically built from upstream screen contexts.
  final String? autoContextScreenId;

  const ContextBanner({
    super.key,
    required this.items,
    this.leadingIcon = Icons.info_outline,
    this.semanticsLabel = 'Context from prior planning pages',
    this.storageKey,
    this.autoContextScreenId,
  });

  /// Factory constructor that automatically fetches upstream context
  /// from the PlanningPhaseContextService for the given screen.
  factory ContextBanner.fromService({
    required String screenId,
    String? storageKey,
    IconData leadingIcon = Icons.info_outline,
  }) {
    final items = buildContextBannerItemsFromService(screenId);
    return ContextBanner(
      items: items,
      leadingIcon: leadingIcon,
      storageKey: storageKey ?? 'context_banner_$screenId',
      autoContextScreenId: screenId,
    );
  }

  @override
  State<ContextBanner> createState() => _ContextBannerState();
}

class _ContextBannerState extends State<ContextBanner> {
  /// In-memory store of dismissed banner keys for the current session.
  static final Set<String> _dismissedKeys = {};

  bool get _isDismissed =>
      widget.storageKey != null && _dismissedKeys.contains(widget.storageKey!);

  void _dismiss() {
    if (widget.storageKey != null) {
      setState(() => _dismissedKeys.add(widget.storageKey!));
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // When autoContextScreenId is set, fetch items fresh from the service
    // on every build. This handles the race condition where loadContexts()
    // completes after the initial widget construction.
    final items = widget.autoContextScreenId != null
        ? buildContextBannerItemsFromService(widget.autoContextScreenId!)
        : widget.items;

    if (items.isEmpty || _isDismissed) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        children: [
          Icon(widget.leadingIcon,
              size: 14, color: LightModeColors.accent.withValues(alpha: 0.9)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _buildItem(items[i]),
                    if (i < items.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          width: 1,
                          height: 12,
                          color: const Color(0xFFD1D5DB),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: _dismiss,
            borderRadius: BorderRadius.circular(10),
            child: Tooltip(
              message: 'Hide context banner',
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close,
                    size: 14, color: Colors.grey.shade600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(ContextBannerItem item) {
    const labelStyle = TextStyle(
      color: Color(0xFF6B7280),
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );

    final labelText = Text('${item.label}:', style: labelStyle);
    final labelWidget = (item.screenTitle?.isNotEmpty ?? false)
        ? Tooltip(message: item.screenTitle!, child: labelText)
        : labelText;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.icon != null) ...[
          Icon(item.icon, size: 12, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
        ],
        labelWidget,
        const SizedBox(width: 4),
        Tooltip(
          message: item.value,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              item.value,
              style: const TextStyle(
                color: Color(0xFF1A1D1F),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}
