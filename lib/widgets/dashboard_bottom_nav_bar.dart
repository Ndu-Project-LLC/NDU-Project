import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_router.dart';
import '../screens/portfolio_dashboard_screen.dart';
import '../screens/program_dashboard_mobile_screen.dart';

class _Tokens {
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const outlineVariant = Color(0xFFC0C6D6);
  static const primary = Color(0xFFB45309);
  static const primaryContainer = Color(0xFFD97706);
}

class DashboardBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onNavigate;

  const DashboardBottomNavBar({
    super.key,
    required this.currentIndex,
    this.onNavigate,
  });

  void _handleTap(BuildContext context, int index) {
    if (onNavigate != null) {
      onNavigate!(index);
      return;
    }
    switch (index) {
      case 0:
        context.go('/${AppRoutes.dashboard}');
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProgramDashboardMobileScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PortfolioDashboardScreen()),
        );
        break;
      case 3:
        context.go('/${AppRoutes.settings}?from=${AppRoutes.dashboard}');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Tokens.surfaceContainerLowest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(color: _Tokens.outlineVariant, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.folder, 'Projects', 0),
              _navItem(Icons.layers, 'Programs', 1),
              _navItem(Icons.account_tree, 'Portfolios', 2),
              _navItem(Icons.settings, 'Settings', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isActive = currentIndex == index;
    final color = isActive ? _Tokens.primary : const Color(0xFF5F5E5E);
    return Builder(builder: (context) {
      return GestureDetector(
        onTap: () => _handleTap(context, index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: isActive
              ? BoxDecoration(
                  color: _Tokens.primaryContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.05,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
