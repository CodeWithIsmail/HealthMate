import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      // Five destinations leave ~72dp each, so a label that grows with the
      // system font wraps mid-word ("Connection/s"). The icons carry the
      // meaning and TalkBack still announces the destination in full, so the
      // labels are capped here rather than allowed to reflow the bar.
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Reports'),
            NavigationDestination(icon: Icon(Icons.show_chart), selectedIcon: Icon(Icons.show_chart), label: 'Trends'),
            // "Connections" is too long for the slot; the screen itself keeps
            // that title.
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Sharing'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
      floatingActionButton: navigationShell.currentIndex == 0 || navigationShell.currentIndex == 1
          ? FloatingActionButton(
              onPressed: () => context.push('/capture'),
              tooltip: 'Add a report',
              child: const Icon(Icons.add_a_photo_outlined),
            )
          : null,
    );
  }
}
