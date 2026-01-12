import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/bottom_nav_bar.dart';

/// Custom FloatingActionButtonLocation that positions FAB above the bottom navigation bar
class _CustomFloatingActionButtonLocation extends FloatingActionButtonLocation {
  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    // Position at the end (right side)
    final double endX = scaffoldGeometry.scaffoldSize.width - 
        scaffoldGeometry.floatingActionButtonSize.width - 
        16.0; // 16px padding from edge
    
    // Position above the bottom navigation bar with extra spacing
    // Bottom nav bar is typically 56-80px high (use 80px to be safe)
    const double bottomNavHeight = 80.0;
    final double fabHeight = scaffoldGeometry.floatingActionButtonSize.height;
    const double extraSpacing = 16.0; // Extra space above navigation bar
    final double bottomY = scaffoldGeometry.scaffoldSize.height - 
        bottomNavHeight - 
        fabHeight - 
        extraSpacing;
    
    return Offset(endX, bottomY);
  }

  @override
  String toString() => 'FloatingActionButtonLocation.customEndDocked';
}

/// Main Scaffold with Bottom Navigation Bar
/// Wraps screens that should show bottom navigation
class MainScaffold extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool showBottomNav;
  final FloatingActionButton? floatingActionButton;

  const MainScaffold({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.showBottomNav = true,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.path;

    return Scaffold(
      appBar: title != null
          ? AppBar(
              title: Text(title!),
              actions: actions,
            )
          : null,
      body: child,
      bottomNavigationBar: showBottomNav ? BottomNavBar(currentLocation: currentLocation) : null,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButton != null && showBottomNav
          ? _CustomFloatingActionButtonLocation()
          : FloatingActionButtonLocation.endFloat,
    );
  }
}

