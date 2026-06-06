import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/notification_provider.dart';

/// Bottom Navigation Bar for Collaborator Mobile App
/// Uses lighter green color scheme
class CollabBottomNavBar extends ConsumerWidget {
  final String currentLocation;

  const CollabBottomNavBar({
    super.key,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notificationsState = ref.watch(notificationsProvider);
    final unreadCount = notificationsState.unreadCount;

    final isHome = currentLocation == '/home';
    final isChargingTasks = currentLocation == '/charging-station' || currentLocation.startsWith('/charging-station/');
    final isSwapStation = currentLocation == '/swap-station' || currentLocation.startsWith('/swap-station/');
    final isNotifications = currentLocation == '/notifications';
    final isProfile = currentLocation == '/profile' || currentLocation == '/profile/contracts';

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
        currentIndex: _getCurrentIndex(isHome, isChargingTasks, isSwapStation, isNotifications, isProfile),
        onTap: (index) => _onTap(context, index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Charging',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.battery_charging_full_outlined),
            activeIcon: Icon(Icons.battery_charging_full),
            label: 'Swap',
          ),
          BottomNavigationBarItem(
            icon: NotificationBadgeIcon(
              icon: Icons.notifications_outlined,
              badgeCount: unreadCount,
              showBadge: unreadCount > 0,
            ),
            activeIcon: NotificationBadgeIcon(
              icon: Icons.notifications,
              badgeCount: unreadCount,
              showBadge: unreadCount > 0,
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  int _getCurrentIndex(bool isHome, bool isChargingTasks, bool isSwapStation, bool isNotifications, bool isProfile) {
    if (isNotifications) return 3;
    if (isSwapStation) return 2;
    if (isChargingTasks) return 1;
    if (isProfile) return 4;
    if (isHome) return 0;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/charging-station');
        break;
      case 2:
        context.go('/swap-station');
        break;
      case 3:
        context.go('/notifications');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }
}

/// Badge icon widget for notifications
class NotificationBadgeIcon extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final bool showBadge;

  const NotificationBadgeIcon({
    super.key,
    required this.icon,
    required this.badgeCount,
    required this.showBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (showBadge)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                badgeCount > 99 ? '99+' : badgeCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
