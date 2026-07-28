import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/routing/app_router.dart';

/// Adaptive bottom navigation for mobile devices
class MobileBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const MobileBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFFFFD700),
      unselectedItemColor: Colors.grey.shade600,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.folder_outlined),
          activeIcon: Icon(Icons.folder),
          label: 'Projects',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.timeline_outlined),
          activeIcon: Icon(Icons.timeline),
          label: 'Timeline',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people),
          label: 'Team',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}

/// Adaptive navigation wrapper that shows different navigation based on screen size
class AdaptiveNavigation extends StatefulWidget {
  final Widget child;
  final int currentIndex;

  const AdaptiveNavigation({
    super.key,
    required this.child,
    this.currentIndex = 0,
  });

  @override
  State<AdaptiveNavigation> createState() => _AdaptiveNavigationState();
}

class _AdaptiveNavigationState extends State<AdaptiveNavigation> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
  }

  void _onNavigationTap(int index) {
    setState(() => _currentIndex = index);

    // Navigate based on index
    switch (index) {
      case 0:
        context.go('/${AppRoutes.dashboard}');
        break;
      case 1:
        // Projects list (to be implemented)
        context.go('/${AppRoutes.dashboard}');
        break;
      case 2:
        // Timeline view (to be implemented)
        context.go('/${AppRoutes.dashboard}');
        break;
      case 3:
        // Team management (to be implemented)
        context.go('/${AppRoutes.dashboard}');
        break;
      case 4:
        context.go('/${AppRoutes.settings}');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Mobile: Bottom navigation (< 600px)
    if (screenWidth < 600) {
      return Scaffold(
        body: SafeArea(
          top: true,
          child: widget.child,
        ),
        bottomNavigationBar: MobileBottomNav(
          currentIndex: _currentIndex,
          onTap: _onNavigationTap,
        ),
      );
    }

    // Tablet: Navigation rail (600px - 1200px)
    if (screenWidth < 1200) {
      return Scaffold(
        body: SafeArea(
          top: true,
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: _onNavigationTap,
                labelType: NavigationRailLabelType.all,
                selectedIconTheme: const IconThemeData(
                  color: Color(0xFFFFD700),
                ),
                selectedLabelTextStyle: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.w700,
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: Text('Dashboard'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder),
                    label: Text('Projects'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.timeline_outlined),
                    selectedIcon: Icon(Icons.timeline),
                    label: Text('Timeline'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people),
                    label: Text('Team'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: Text('Settings'),
                  ),
                ],
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: widget.child),
            ],
          ),
        ),
      );
    }

    // Desktop: Full sidebar (>= 1200px)
    // For now, just show the child (existing desktop navigation)
    return widget.child;
  }
}
