import 'package:flutter/material.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/navigation_context_service.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/services/project_service.dart';
import 'package:ndu_project/screens/admin/admin_users_screen.dart';
import 'package:ndu_project/screens/admin/admin_hints_screen.dart';
import 'package:ndu_project/screens/admin_content_screen.dart';
import 'package:ndu_project/screens/admin/admin_projects_screen.dart';
import 'package:ndu_project/screens/home_screen.dart';
import 'package:ndu_project/widgets/app_logo.dart';

import 'package:ndu_project/screens/admin/admin_coupons_screen.dart';
import 'package:ndu_project/screens/admin/admin_subscription_lookup_screen.dart';
import 'package:ndu_project/screens/admin/admin_pricing_config_screen.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';

const Color _adminBackgroundColor = Color(0xFFFFFFFF);
const Color _adminSurfaceColor = Colors.white;
const Color _adminBorderColor = Color(0xFFE5E7EB);
const Color _adminAccentColor = Color(0xFFFFC107);
const Color _adminAccentStrongColor = Color(0xFFB45309);
const Color _adminAccentForegroundColor = Color(0xFF111827);
const Color _adminTextPrimaryColor = Color(0xFF111827);
const Color _adminTextSecondaryColor = Color(0xFF6B7280);

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Record admin dashboard context for logo navigation
    NavigationContextService.instance
        .setLastAdminDashboard(AppRoutes.adminHome);
    return Scaffold(
      backgroundColor: _adminBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings,
                color: _adminAccentColor, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Admin Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _adminTextPrimaryColor,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: UnifiedProfileMenu(compact: true),
          ),
        ],
      ),
      body: SafeArea(
        top: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(context),
              const SizedBox(height: 28),
              _buildStatsGrid(),
              const SizedBox(height: 32),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _adminTextPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildQuickActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _adminSurfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _adminBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;
          return Wrap(
            spacing: 24,
            runSpacing: 20,
            alignment: WrapAlignment.spaceBetween,
            children: [
              SizedBox(
                width:
                    isCompact ? double.infinity : constraints.maxWidth * 0.58,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _adminSurfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _adminBorderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const AppLogo(
                              height: 44,
                              width: 170,
                              enableTapToDashboard: false),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _adminAccentColor.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Admin Console',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _adminAccentForegroundColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'System Overview',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: _adminTextPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Monitor usage, manage critical systems, and keep projects moving forward in real time.',
                      style: TextStyle(
                        fontSize: 15,
                        color: _adminTextSecondaryColor,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: const [
                        _HeroPill(icon: Icons.bolt, label: 'Live metrics'),
                        _HeroPill(icon: Icons.security, label: 'Admin secured'),
                        _HeroPill(
                            icon: Icons.cloud_done, label: 'Realtime sync'),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width:
                    isCompact ? double.infinity : constraints.maxWidth * 0.34,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Today',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54)),
                    const SizedBox(height: 8),
                    _HeroStatTile(
                      title: 'Active sessions',
                      value: 'Realtime',
                      subtitle: 'Monitoring system health',
                      accent: _adminAccentStrongColor,
                    ),
                    const SizedBox(height: 12),
                    _HeroStatTile(
                      title: 'Last refresh',
                      value: 'Just now',
                      subtitle: 'All services healthy',
                      accent: _adminAccentStrongColor,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid() {
    return FutureBuilder<Map<String, int>>(
      future: _loadStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data ??
            {'users': 0, 'activeUsers': 0, 'admins': 0, 'projects': 0};

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 800;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  title: 'Total Users',
                  value: stats['users'].toString(),
                  icon: Icons.people,
                  color: _adminAccentColor,
                  width: isMobile
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 48) / 4,
                ),
                _StatCard(
                  title: 'Active Users',
                  value: stats['activeUsers'].toString(),
                  icon: Icons.person_outline,
                  color: _adminAccentColor,
                  width: isMobile
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 48) / 4,
                ),
                _StatCard(
                  title: 'Admins',
                  value: stats['admins'].toString(),
                  icon: Icons.admin_panel_settings,
                  color: _adminAccentColor,
                  width: isMobile
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 48) / 4,
                ),
                _StatCard(
                  title: 'Total Projects',
                  value: stats['projects'].toString(),
                  icon: Icons.folder,
                  color: _adminAccentColor,
                  width: isMobile
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 48) / 4,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, int>> _loadStats() async {
    final users = await UserService.getTotalUserCount();
    final activeUsers = await UserService.getActiveUserCount();
    final admins = await UserService.getAdminUserCount();
    final projects = await ProjectService.getTotalProjectCount();

    return {
      'users': users,
      'activeUsers': activeUsers,
      'admins': admins,
      'projects': projects,
    };
  }

  Widget _buildQuickActions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        final cardWidth =
            isMobile ? constraints.maxWidth : (constraints.maxWidth - 48) / 4;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _ActionCard(
              title: 'Executive Dashboard',
              description:
                  'Real-time pulse across every project, program, and portfolio',
              icon: Icons.dashboard_customize_outlined,
              color: _adminAccentColor,
              onTap: () => HomeScreen.open(context),
              width: cardWidth,
            ),
            _ActionCard(
              title: 'User Management',
              description: 'View and manage all users, roles, and permissions',
              icon: Icons.people,
              color: _adminAccentColor,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
              width: cardWidth,
            ),
            _ActionCard(
              title: 'Content Management',
              description: 'Edit app content, labels, and system messages',
              icon: Icons.edit_document,
              color: _adminAccentColor,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminContentScreen())),
              width: cardWidth,
            ),
            _ActionCard(
              title: 'Project Overview',
              description: 'View all projects across the platform',
              icon: Icons.folder_open,
              color: _adminAccentColor,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminProjectsScreen())),
              width: cardWidth,
            ),
            _ActionCard(
              title: 'Coupon Management',
              description:
                  'Create and manage discount coupons for Stripe, PayPal, and Paystack',
              icon: Icons.local_offer,
              color: _adminAccentColor,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminCouponsScreen())),
              width: cardWidth,
            ),
            _ActionCard(
              title: 'Subscription Pricing',
              description:
                  'Edit base prices, max users, and per-role add-on pricing for all 4 tiers',
              icon: Icons.attach_money,
              color: _adminAccentColor,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminPricingConfigScreen())),
              width: cardWidth,
            ),
            _ActionCard(
              title: 'Subscription Lookup',
              description:
                  'Search users and manage their subscriptions, trials, and access',
              icon: Icons.search,
              color: _adminAccentColor,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminSubscriptionLookupScreen())),
              width: cardWidth,
            ),
            _ActionCard(
              title: 'Hints',
              description:
                  'Control per-screen hint visibility, rewrite onboarding copy, and replay guidance flows',
              icon: Icons.tips_and_updates_outlined,
              color: _adminAccentColor,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminHintsScreen())),
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _adminSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _adminBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _adminAccentStrongColor, size: 20),
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: _adminTextPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _adminTextPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _adminAccentColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Live',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _adminAccentForegroundColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Updated just now',
                style: TextStyle(fontSize: 11, color: _adminTextSecondaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.width,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _adminSurfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _adminBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _adminAccentColor.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: _adminAccentStrongColor, size: 24),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _adminAccentColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Manage',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _adminAccentForegroundColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _adminTextPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: _adminTextSecondaryColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Open',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _adminAccentStrongColor,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward,
                  color: _adminAccentStrongColor,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _adminSurfaceColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _adminBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _adminAccentStrongColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _adminTextPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatTile extends StatelessWidget {
  const _HeroStatTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _adminSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _adminBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _adminTextSecondaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: accent)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style:
                const TextStyle(fontSize: 12, color: _adminTextSecondaryColor),
          ),
        ],
      ),
    );
  }
}
