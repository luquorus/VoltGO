import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom Navigation Bar for Collaborator Mobile App
/// Uses lighter green color scheme
class CollabBottomNavBar extends StatelessWidget {
  final String currentLocation;

  const CollabBottomNavBar({
    super.key,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isChargingTasks = currentLocation == '/tasks' || currentLocation.startsWith('/tasks/');
    final isBatterySwap = currentLocation == '/battery-swap' || currentLocation.startsWith('/battery-swap/');
    final isProfile = currentLocation == '/profile';

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _getCurrentIndex(isChargingTasks, isBatterySwap, isProfile),
        onTap: (index) => _onTap(context, index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Charging',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.battery_charging_full_outlined),
            activeIcon: Icon(Icons.battery_charging_full),
            label: 'Swap',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  int _getCurrentIndex(bool isChargingTasks, bool isBatterySwap, bool isProfile) {
    if (isBatterySwap) return 1;
    if (isChargingTasks) return 0;
    if (isProfile) return 2;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/tasks');
        break;
      case 1:
        context.go('/battery-swap');
        break;
      case 2:
        context.go('/profile');
        break;
    }
  }
}
