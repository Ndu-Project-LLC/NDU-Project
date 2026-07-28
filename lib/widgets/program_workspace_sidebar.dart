import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/widgets/responsive.dart';
import 'package:ndu_project/widgets/app_logo.dart';

const Color kProgramSidebarAccentColor = Color(0xFFFFC812);
const Color kProgramSidebarTextPrimary = Color(0xFF1A1D1F);
const Color kProgramSidebarTextSecondary = Color(0xFF6B7280);
const Color kProgramSidebarSurfaceBorder = Color(0xFFE4E7EC);

/// Sidebar used across the Front End Planning workspaces.
class ProgramWorkspaceSidebar extends StatelessWidget {
  const ProgramWorkspaceSidebar({super.key, this.width});

  final double? width;

  @override
  Widget build(BuildContext context) {
    final items = [
      _SidebarItem(icon: Icons.home_outlined, label: 'Home', isActive: false, onTap: () {}),
      _SidebarItem(icon: Icons.shield_moon_outlined, label: 'SSHER', isActive: false, onTap: () {}),
      _SidebarItem(icon: Icons.design_services_outlined, label: 'Design', isActive: false, onTap: () {}),
      _SidebarItem(icon: Icons.route_outlined, label: 'Execution Plan', isActive: false, onTap: () {}),
      _SidebarItem(
        icon: Icons.memory_outlined,
        label: 'Technology',
        isActive: false,
        onTap: () {
          context.go('/${AppRoutes.fepTechnology}');
        },
      ),
      _SidebarItem(icon: Icons.group_outlined, label: 'Team Management', isActive: false, onTap: () {}),
      _SidebarItem(icon: Icons.assignment_outlined, label: 'Contract', isActive: false, onTap: () {}),
      _SidebarItem(icon: Icons.shopping_bag_outlined, label: 'Procurement', isActive: false, onTap: () {}),
      _SidebarItem(icon: Icons.schedule_outlined, label: 'Schedule', isActive: false, onTap: () {}),
      _SidebarItem(icon: Icons.attach_money_outlined, label: 'Cost Estimate', isActive: false, onTap: () {}),
      _SidebarItem(icon: Icons.change_circle_outlined, label: 'Change Management', isActive: false, onTap: () {}),
      _SidebarItem(icon: Icons.account_tree_outlined, label: 'Project Plan', isActive: true, onTap: () {}),
      _SidebarItem(icon: Icons.groups_3_outlined, label: 'Stakeholder Management', isActive: false, onTap: () {}),
      _SidebarItem(icon: Icons.shield_outlined, label: 'Risk Assessment', isActive: false, onTap: () {}),
      _SidebarItem(icon: Icons.report_problem_outlined, label: 'Issue Management', isActive: false, onTap: () {}),
    ];

    final resolvedWidth = width ?? AppBreakpoints.sidebarWidth(context);

    return SizedBox(
      width: resolvedWidth,
      child: Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: AppLogo(
              height: 48,
              semanticLabel: 'Go to dashboard',
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          const CircleAvatar(
            radius: 34,
            backgroundColor: kProgramSidebarSurfaceBorder,
            child: Text(
              'S',
              style: TextStyle(
                color: kProgramSidebarTextPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 96,
            child: Center(child: AppLogo(height: 64)),
          ),
          const SizedBox(height: 12),
          const Text(
            'StackOne',
            style: TextStyle(
              color: kProgramSidebarTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '12 Members',
            style: TextStyle(
              color: kProgramSidebarTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.separated(
              itemBuilder: (context, index) => items[index],
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemCount: items.length,
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.icon, required this.label, required this.isActive, this.onTap});

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = isActive ? kProgramSidebarAccentColor.withOpacity(0.18) : Colors.transparent;
    final borderColor = isActive ? kProgramSidebarAccentColor.withOpacity(0.35) : Colors.transparent;
    final iconColor = isActive ? kProgramSidebarAccentColor : const Color(0xFF6B7280);
    final labelColor = kProgramSidebarTextPrimary;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
