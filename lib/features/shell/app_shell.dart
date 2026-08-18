import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/offline_banner.dart';

/// The five top-level destinations.
const _destinations = <({IconData icon, IconData selectedIcon, String label})>[
  (
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: 'Home',
  ),
  (
    icon: Icons.people_outline_rounded,
    selectedIcon: Icons.people_rounded,
    label: 'Clients',
  ),
  (
    icon: Icons.add_circle_outline_rounded,
    selectedIcon: Icons.add_circle_rounded,
    label: 'Add',
  ),
  (
    icon: Icons.history_rounded,
    selectedIcon: Icons.history_rounded,
    label: 'Activity',
  ),
  (
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    label: 'Settings',
  ),
];

/// Navigation frame around the five tabs.
///
/// A bottom bar on phones, putting everything within thumb reach for one-handed
/// use, and a side rail from tablet width up, where a bottom bar would strand
/// the controls far from the content.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Below this, the bottom bar; at or above it, the rail.
  static const _railBreakpoint = 700.0;

  void _goToBranch(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the current tab pops back to its root, the platform-standard
      // behaviour people expect from a tab bar.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= _railBreakpoint;

    final content = Column(
      children: [
        const OfflineBanner(),
        Expanded(child: navigationShell),
      ],
    );

    if (!useRail) {
      return Scaffold(
        body: content,
        bottomNavigationBar: _BottomBar(
          currentIndex: navigationShell.currentIndex,
          onSelected: _goToBranch,
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _Rail(
            currentIndex: navigationShell.currentIndex,
            onSelected: _goToBranch,
            extended: width >= 1100,
          ),
          VerticalDivider(width: 1, color: context.colors.hairline),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.hairline)),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onSelected,
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
              tooltip: destination.label,
            ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.currentIndex,
    required this.onSelected,
    required this.extended,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onSelected,
      extended: extended,
      labelType: extended ? null : NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 36),
            if (extended) ...[
              const SizedBox(width: 10),
              Text('Balance Book', style: context.text.titleSmall),
            ],
          ],
        ),
      ),
      destinations: [
        for (final destination in _destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}
