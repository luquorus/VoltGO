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
    final notificationsState = ref.watch(notificationsProvider);
    final unreadCount = notificationsState.unreadCount;

    final isHome = currentLocation == '/home';
    final isChargingTasks = currentLocation == '/charging-station' || currentLocation.startsWith('/charging-station/');
    final isSwapStation = currentLocation == '/swap-station' || currentLocation.startsWith('/swap-station/');
    final isChangeRequests = currentLocation == '/change-requests' ||
        currentLocation.startsWith('/change-requests/');
    final isNotifications = currentLocation == '/notifications';
    final isProfile = currentLocation == '/profile' || currentLocation == '/profile/contracts';

    return NavigationBar(
      selectedIndex: _getCurrentIndex(
          isHome, isChargingTasks, isSwapStation, isChangeRequests, isNotifications, isProfile),
      onDestinationSelected: (index) => _onTap(context, index),
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        const NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: 'Charging',
        ),
        const NavigationDestination(
          icon: Icon(Icons.battery_charging_full_outlined),
          selectedIcon: Icon(Icons.battery_charging_full),
          label: 'Swap',
        ),
        const NavigationDestination(
          icon: Icon(Icons.edit_note_outlined),
          selectedIcon: Icon(Icons.edit_note),
          label: 'Requests',
        ),
        NavigationDestination(
          icon: NotificationBadgeIcon(
            icon: Icons.notifications_outlined,
            badgeCount: unreadCount,
            showBadge: unreadCount > 0,
          ),
          selectedIcon: NotificationBadgeIcon(
            icon: Icons.notifications,
            badgeCount: unreadCount,
            showBadge: unreadCount > 0,
          ),
          label: 'Notifications',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  int _getCurrentIndex(bool isHome, bool isChargingTasks, bool isSwapStation,
      bool isChangeRequests, bool isNotifications, bool isProfile) {
    if (isNotifications) return 4;
    if (isChangeRequests) return 3;
    if (isSwapStation) return 2;
    if (isChargingTasks) return 1;
    if (isProfile) return 5;
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
        context.go('/change-requests');
        break;
      case 4:
        context.go('/notifications');
        break;
      case 5:
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
          Transform.translate(
            offset: const Offset(10, -4),
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
