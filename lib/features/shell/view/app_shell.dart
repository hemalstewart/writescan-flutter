import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _indexFromLocation(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/bots')) return 1;
    if (location.startsWith('/chat')) return 2;
    return 3;
  }

  String _routeFromIndex(int index) {
    switch (index) {
      case 0:
        return '/home';
      case 1:
        return '/bots';
      case 2:
        return '/chat';
      default:
        return '/more';
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final location = GoRouterState.of(context).uri.path;
    final index = _indexFromLocation(location);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: colors.brightness == Brightness.dark ? 0.3 : 0.1,
              ),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 68,
            selectedIndex: index,
            onDestinationSelected: (idx) => router.go(_routeFromIndex(idx)),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            backgroundColor: Colors.transparent,
            indicatorColor: colors.primary.withValues(alpha: 0.18),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: const Icon(Icons.smart_toy_outlined),
                selectedIcon: const Icon(Icons.smart_toy_rounded),
                label: 'AI Bots',
              ),
              NavigationDestination(
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: const Icon(Icons.chat_bubble_rounded),
                label: 'General',
              ),
              NavigationDestination(
                icon: const Icon(Icons.more_horiz_rounded),
                selectedIcon: const Icon(Icons.more_horiz),
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
