import 'package:flutter/material.dart';
import 'package:ndu_project/services/subscription_pricing_service.dart';

/// Selector widget that lets the user pick how many additional users of
/// each role they want to add on top of the tier's [includedUsers].
///
/// Shows a live cost breakdown and a running total. Calls [onChanged]
/// whenever the selection changes so the parent (typically the payment
/// dialog) can recompute the total price.
///
/// The Basic Project tier doesn't allow add-ons — pass a tier with
/// [includedUsers] == [maxUsers] and the widget renders a friendly note
/// instead of the selector.
class AddonUsersSelector extends StatefulWidget {
  const AddonUsersSelector({
    super.key,
    required this.tier,
    required this.currencySymbol,
    required this.selection,
    required this.onChanged,
  });

  final TierPricingConfig tier;
  final String currencySymbol;
  final AddonUserSelection selection;
  final ValueChanged<AddonUserSelection> onChanged;

  @override
  State<AddonUsersSelector> createState() => _AddonUsersSelectorState();
}

class _AddonUsersSelectorState extends State<AddonUsersSelector> {
  void _increment(PricingRoleId role) {
    final current = widget.selection.counts[role] ?? 0;
    final totalSelected = widget.selection.total;
    final remainingSlots = widget.tier.maxUsers - widget.tier.includedUsers;
    if (totalSelected >= remainingSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Max add-on users reached (${remainingSlots} for ${widget.tier.label}).'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    widget.onChanged(widget.selection.copyWith({role: current + 1}));
  }

  void _decrement(PricingRoleId role) {
    final current = widget.selection.counts[role] ?? 0;
    if (current <= 0) return;
    widget.onChanged(widget.selection.copyWith({role: current - 1}));
  }

  @override
  Widget build(BuildContext context) {
    // No add-ons allowed on this tier
    if (widget.tier.maxUsers <= widget.tier.includedUsers) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF64748B), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${widget.tier.label} is single-user only. '
                'Upgrade to add more seats.',
                style: const TextStyle(
                    color: Color(0xFF64748B), fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    final remainingSlots =
        widget.tier.maxUsers - widget.tier.includedUsers;
    final addonMonthly = widget.selection.monthlyAddonCost(widget.tier);
    final totalUsers = widget.tier.includedUsers + widget.selection.total;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.group_add, size: 18, color: Color(0xFF0F172A)),
              const SizedBox(width: 8),
              const Text(
                'Add users',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                '$totalUsers / ${widget.tier.maxUsers} users',
                style: TextStyle(
                  fontSize: 12,
                  color: totalUsers > widget.tier.maxUsers
                      ? Colors.red.shade700
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.tier.includedUsers} seat${widget.tier.includedUsers == 1 ? '' : 's'} included. '
            'Add up to $remainingSlots more.',
            style: const TextStyle(
                color: Color(0xFF64748B), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          // Per-role rows
          for (final role in PricingRoleId.values)
            if (widget.tier.addonPricePerRole.containsKey(role) ||
                role == PricingRoleId.guest)
              _roleRow(role),
          const SizedBox(height: 12),
          // Addon total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Text(
                  'Add-on total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.currencySymbol}${addonMonthly.toStringAsFixed(2)} / mo',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleRow(PricingRoleId role) {
    final count = widget.selection.counts[role] ?? 0;
    final price = widget.tier.addonPricePerRole[role] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _roleLabel(role),
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                Text(
                  price == 0
                      ? 'Free'
                      : '${widget.currencySymbol}${price.toStringAsFixed(2)} / user / mo',
                  style: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 11.5),
                ),
              ],
            ),
          ),
          // Stepper
          Row(
            children: [
              _stepperButton(
                icon: Icons.remove,
                onPressed: count > 0 ? () => _decrement(role) : null,
              ),
              Container(
                width: 36,
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              _stepperButton(
                icon: Icons.add,
                onPressed: () => _increment(role),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepperButton(
      {required IconData icon, required VoidCallback? onPressed}) {
    return IconButton(
      icon: Icon(icon, size: 16),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      style: IconButton.styleFrom(
        backgroundColor: onPressed == null
            ? const Color(0xFFF1F5F9)
            : const Color(0xFFE2E8F0),
        foregroundColor:
            onPressed == null ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A),
      ),
    );
  }

  String _roleLabel(PricingRoleId r) {
    switch (r) {
      case PricingRoleId.owner:
        return 'Owner';
      case PricingRoleId.admin:
        return 'Admin';
      case PricingRoleId.editor:
        return 'Editor';
      case PricingRoleId.user:
        return 'User';
      case PricingRoleId.guest:
        return 'Guest';
    }
  }
}
