import 'package:flutter/material.dart';

class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    required this.label,
    required this.value,
    required this.subLabel,
    required this.icon,
    required this.color,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final String subLabel;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEFF1F5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: card,
      ),
    );
  }
}

class DashboardStatLayout extends StatelessWidget {
  const DashboardStatLayout({
    required this.cards,
    required this.isStacked,
    this.horizontalSpacing = 20,
    this.verticalSpacing = 16,
    super.key,
  });

  final List<Widget> cards;
  final bool isStacked;
  final double horizontalSpacing;
  final double verticalSpacing;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isStacked) {
      return Column(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i != cards.length - 1) SizedBox(height: verticalSpacing),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) SizedBox(width: horizontalSpacing),
        ],
      ],
    );
  }
}
