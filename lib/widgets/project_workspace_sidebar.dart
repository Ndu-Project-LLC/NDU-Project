import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/widgets/app_logo.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
const Color _kAccentColor = Color(0xFFFFC812);
const Color _kTextPrimary = Color(0xFF1A1D1F);
const Color _kTextSecondary = Color(0xFF6B7280);
const Color _kSurfaceBorder = Color(0xFFE4E7EC);

class ProjectWorkspaceSidebar extends StatefulWidget {
  const ProjectWorkspaceSidebar({super.key, this.activeLabel = 'Project Plan'});

  final String activeLabel;

  @override
  State<ProjectWorkspaceSidebar> createState() => _ProjectWorkspaceSidebarState();
}

class _ProjectWorkspaceSidebarState extends State<ProjectWorkspaceSidebar> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allItems = [
      _SidebarItemData(icon: Icons.home_outlined, label: 'Home'),
      _SidebarItemData(
        icon: Icons.shield_moon_outlined,
        label: 'SSHER',
        onTap: () => context.push('/ssher-stacked'),
      ),
      _SidebarItemData(icon: Icons.design_services_outlined, label: 'Design'),
      _SidebarItemData(icon: Icons.route_outlined, label: 'Execution Plan'),
      _SidebarItemData(icon: Icons.memory_outlined, label: 'Technology'),
      _SidebarItemData(icon: Icons.group_outlined, label: 'Team Management'),
      _SidebarItemData(icon: Icons.assignment_outlined, label: 'Contract'),
      _SidebarItemData(icon: Icons.shopping_bag_outlined, label: 'Procurement'),
      _SidebarItemData(icon: Icons.schedule_outlined, label: 'Schedule'),
      _SidebarItemData(icon: Icons.attach_money_outlined, label: 'Cost Estimate'),
      _SidebarItemData(icon: Icons.change_circle_outlined, label: 'Change Management'),
      _SidebarItemData(icon: Icons.account_tree_outlined, label: 'Project Plan'),
      _SidebarItemData(icon: Icons.groups_3_outlined, label: 'Stakeholder Management'),
      _SidebarItemData(icon: Icons.shield_outlined, label: 'Risk Assessment'),
      _SidebarItemData(icon: Icons.security_outlined, label: 'Security Management'),
      _SidebarItemData(icon: Icons.report_problem_outlined, label: 'Issue Management'),
      _SidebarItemData(
        icon: Icons.shield_moon_outlined,
        label: 'Project Controls',
        onTap: () => context.push('/project-controls'),
      ),
    ];

    final filteredItems = _searchQuery.isEmpty
        ? allItems
        : allItems.where((item) => item.label.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Container(
      width: 260,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppLogo(
            height: 56,
            width: 148,
          ),
          const SizedBox(height: 4),
          const Text(
            'Navigate. Deliver. Upgrade',
            style: TextStyle(color: _kTextSecondary, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.3),
          ),
          const SizedBox(height: 32),
          const CircleAvatar(
            radius: 34,
            backgroundColor: _kSurfaceBorder,
            child: Text('S', style: TextStyle(color: _kTextPrimary, fontSize: 26, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 14),
          // Brand banner above the "StackOne" label, spanning sidebar width
          RepaintBoundary(
            child: SizedBox(
              width: double.infinity,
              height: 96,
              child: Center(child: AppLogo(height: 64)),
            ),
          ),
          const SizedBox(height: 12),
          const Text('StackOne', style: TextStyle(color: _kTextPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('12 Members', style: TextStyle(color: _kTextSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          // Search bar
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kSurfaceBorder),
            ),
            child: VoiceTextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: _kTextPrimary, fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search menu...',
                hintStyle: TextStyle(color: _kTextSecondary.withOpacity(0.6), fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: _kTextSecondary.withOpacity(0.7), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: _kTextSecondary.withOpacity(0.7), size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, color: _kTextSecondary.withOpacity(0.4), size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'No results found',
                          style: TextStyle(color: _kTextSecondary.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isActive = item.label == widget.activeLabel;
                      return _SidebarItem(
                        icon: item.icon,
                        label: item.label,
                        isActive: isActive,
                        onTap: item.onTap,
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemCount: filteredItems.length,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItemData {
  _SidebarItemData({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.icon, required this.label, required this.isActive, this.onTap});
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = isActive ? _kAccentColor.withOpacity(0.18) : Colors.transparent;
    final borderColor = isActive ? _kAccentColor.withOpacity(0.35) : Colors.transparent;
    final iconColor = isActive ? _kAccentColor : const Color(0xFF6B7280);
    final labelColor = _kTextPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
      ),
    );
  }
}
