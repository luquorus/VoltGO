import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

/// Bottom Navigation Bar for EV User Mobile App
class BottomNavBar extends StatelessWidget {
  final String currentLocation;

  const BottomNavBar({
    super.key,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHome = currentLocation == '/home';
    final isBookings = currentLocation.startsWith('/bookings') && currentLocation != '/bookings/create';
    final isLoyalty = currentLocation.startsWith('/loyalty');
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
        currentIndex: _getCurrentIndex(isHome, isBookings, isLoyalty, isProfile),
        onTap: (index) => _onTap(context, index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.map),
            activeIcon: FaIcon(FontAwesomeIcons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.calendar),
            activeIcon: FaIcon(FontAwesomeIcons.calendar),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.gift),
            activeIcon: FaIcon(FontAwesomeIcons.gift),
            label: 'Rewards',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.user),
            activeIcon: FaIcon(FontAwesomeIcons.user),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  int _getCurrentIndex(bool isHome, bool isBookings, bool isLoyalty, bool isProfile) {
    if (isHome) return 0;
    if (isBookings) return 1;
    if (isLoyalty) return 2;
    if (isProfile) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/bookings');
        break;
      case 2:
        context.go('/loyalty');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }
}
